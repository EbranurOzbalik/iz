import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/main.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  late List<RequestInterceptorHandler> pending;

  setUp(() {
    requests = [];
    pending = [];
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          pending.add(handler);
        },
      ),
    );
  });

  tearDown(() => dio.close(force: true));

  Future<void> openSearch(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BookSearchPage(dio: dio)));
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.tap(find.text('Kitap Ara'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  void returnBooks(List<Map<String, dynamic>> docs, {int? total}) {
    pending
        .removeAt(0)
        .resolve(
          Response(
            requestOptions: requests.last,
            data: {'docs': docs, 'numFound': total},
          ),
        );
  }

  Future<void> loadMore(WidgetTester tester, {bool retry = false}) async {
    final button = find.text(
      retry ? 'Devamını tekrar dene' : 'Daha fazla göster',
    );
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> selectSort(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Sonuçları sırala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'Sorting restarts the submitted search and keeps its order across pages',
    (tester) async {
      await openSearch(tester);
      await search(tester, 'Dune');
      expect(requests.single.queryParameters.containsKey('sort'), isFalse);
      returnBooks([
        {'title': 'İlgili sonuç'},
      ], total: 3);
      await tester.pumpAndSettle();
      await loadMore(tester);
      returnBooks([
        {'title': 'İkinci ilgili sonuç'},
      ], total: 3);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Henüz aranmayan taslak');
      await selectSort(tester, 'İlk yayın: en yeni');
      expect(requests.last.queryParameters['q'], 'Dune');
      expect(requests.last.queryParameters['sort'], 'new');
      expect(requests.last.queryParameters['offset'], 0);
      expect(find.text('İlgili sonuç'), findsNothing);
      expect(find.text('İkinci ilgili sonuç'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Henüz aranmayan taslak',
      );
      expect(
        tester
            .widget<DropdownButton<dynamic>>(
              find.byWidgetPredicate((widget) => widget is DropdownButton),
            )
            .onChanged,
        isNull,
      );
      returnBooks([
        {'title': 'En yeni kitap', 'first_publish_year': 2020},
      ], total: 2);
      await tester.pumpAndSettle();
      await loadMore(tester);
      expect(requests.last.queryParameters['q'], 'Dune');
      expect(requests.last.queryParameters['sort'], 'new');
      expect(requests.last.queryParameters['offset'], 1);
      returnBooks([
        {'title': 'Daha eski kitap', 'first_publish_year': 1965},
      ], total: 2);
      await tester.pumpAndSettle();
      expect(find.text('En yeni kitap'), findsOneWidget);
      expect(find.text('Daha eski kitap'), findsOneWidget);
      expect(find.text('Daha fazla göster'), findsNothing);

      await selectSort(tester, 'En ilgili');
      expect(requests.last.queryParameters.containsKey('sort'), isFalse);
      expect(requests.last.queryParameters['offset'], 0);
      expect(requests.last.queryParameters['q'], 'Dune');
      returnBooks([], total: 0);
      await tester.pumpAndSettle();
      expect(find.text('Kitap bulunamadı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sort selection works before searching and survives retries and clearing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openSearch(tester);
      await selectSort(tester, 'İlk yayın: en eski');
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.text('Yazar'));
      await tester.pumpAndSettle();
      await search(tester, 'Sabahattin Ali');
      expect(requests.single.queryParameters['author'], 'Sabahattin Ali');
      expect(requests.single.queryParameters['sort'], 'old');
      pending.removeAt(0).reject(DioException(requestOptions: requests.last));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Yeni taslak');
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.last.queryParameters['author'], 'Sabahattin Ali');
      expect(requests.last.queryParameters['sort'], 'old');
      returnBooks([
        {'title': 'Kuyucaklı Yusuf', 'first_publish_year': 1937},
      ], total: 1);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsNothing);
      await selectSort(tester, 'İlk yayın: en yeni');
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      await search(tester, 'Yaşar Kemal');
      expect(requests.last.queryParameters['author'], 'Yaşar Kemal');
      expect(requests.last.queryParameters['sort'], 'new');
      expect(requests.last.queryParameters['offset'], 0);
      returnBooks([], total: 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'More results append to the original query and stop at the total',
    (tester) async {
      await openSearch(tester);
      await search(tester, 'Dune');
      expect(requests.single.queryParameters['offset'], 0);
      returnBooks([
        {'title': 'Dune'},
      ], total: 2);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Yeni sorgu');
      await loadMore(tester);
      expect(find.text('Dune'), findsOneWidget);
      expect(requests.last.queryParameters['q'], 'Dune');
      expect(requests.last.queryParameters['offset'], 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      returnBooks([
        {'title': 'Dune Messiah'},
      ], total: 2);
      await tester.pumpAndSettle();
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Dune Messiah'), findsOneWidget);
      expect(find.text('Daha fazla göster'), findsNothing);
      await search(tester, 'Başka kitap');
      expect(requests.last.queryParameters['offset'], 0);
      returnBooks([
        {'title': 'Başka kitap'},
      ], total: 1);
      await tester.pumpAndSettle();
      expect(find.text('Dune Messiah'), findsNothing);
    },
  );

  testWidgets(
    'A failed author continuation preserves books and retries the same offset',
    (tester) async {
      await openSearch(tester);
      await tester.tap(find.text('Yazar'));
      await tester.pumpAndSettle();
      await search(tester, 'Sabahattin Ali');
      returnBooks([
        {'title': 'Kuyucaklı Yusuf'},
      ], total: 2);
      await tester.pumpAndSettle();
      await loadMore(tester);
      pending.removeAt(0).reject(DioException(requestOptions: requests.last));
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsOneWidget);
      expect(find.text('Devamını tekrar dene'), findsOneWidget);
      await loadMore(tester, retry: true);
      expect(requests.last.queryParameters['author'], 'Sabahattin Ali');
      expect(requests.last.queryParameters.containsKey('q'), isFalse);
      expect(requests.last.queryParameters['offset'], 1);
      returnBooks([
        {'title': 'İçimizdeki Şeytan'},
      ], total: 2);
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsOneWidget);
      expect(find.text('İçimizdeki Şeytan'), findsOneWidget);
      expect(find.text('Devamını tekrar dene'), findsNothing);
    },
  );

  testWidgets(
    'An empty continuation stops paging and disposal cancels a pending page',
    (tester) async {
      await openSearch(tester);
      await search(tester, 'Dune');
      returnBooks([
        {'title': 'Dune'},
      ], total: 10);
      await tester.pumpAndSettle();
      await loadMore(tester);
      returnBooks([], total: 10);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Card), matching: find.text('Dune')),
        findsOneWidget,
      );
      expect(find.text('Daha fazla göster'), findsNothing);

      await search(tester, 'Dune');
      returnBooks([
        {'title': 'Dune'},
      ], total: 10);
      await tester.pumpAndSettle();
      await loadMore(tester);
      final token = requests.last.cancelToken!;
      await tester.pumpWidget(const SizedBox());
      expect(token.isCancelled, isTrue);
      returnBooks([
        {'title': 'Dune Messiah'},
      ], total: 10);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Blank searches show guidance without making a request', (
    tester,
  ) async {
    await openSearch(tester);
    expect(find.text('Aramak için bir kitap adı yaz'), findsOneWidget);
    expect(find.text('Kitap bulunamadı'), findsNothing);

    await search(tester, '   ');
    expect(find.text('Bir kitap adı yaz'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Bir kitap adı yaz'), findsNothing);
  });

  testWidgets('Typed queries are trimmed and new searches replace old books', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openSearch(tester);
    await search(tester, '  Kürk Mantolu Madonna  ');
    expect(requests.single.path, 'https://openlibrary.org/search.json');
    expect(requests.single.queryParameters['q'], 'Kürk Mantolu Madonna');
    expect(requests.single.queryParameters['limit'], 5);
    expect(
      (requests.single.queryParameters['fields'] as String).split(','),
      containsAll([
        'title',
        'subtitle',
        'author_name',
        'first_publish_year',
        'edition_count',
        'cover_i',
        'editions',
        'editions.key',
        'editions.subtitle',
      ]),
    );

    const longTitle =
        'Kürk Mantolu Madonna: Açıklamalı ve Genişletilmiş Özel Baskı';
    const longSubtitle =
        'Eserin yazılış sürecine ve edebiyat tarihindeki yerine dair açıklamalar';
    returnBooks([
      {
        'title': longTitle,
        'subtitle': longSubtitle,
        'author_name': ['Sabahattin Ali'],
        'first_publish_year': 1943,
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text(longTitle), findsOneWidget);
    expect(find.text(longSubtitle), findsOneWidget);
    expect(find.text('Sabahattin Ali'), findsOneWidget);
    expect(find.text('İlk yayın: 1943'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await search(tester, 'Dune');
    expect(requests.last.queryParameters['q'], 'Dune');
    returnBooks([
      {'title': 'Dune'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text(longTitle), findsNothing);
    expect(find.text(longSubtitle), findsNothing);
    expect(find.text('Yazar bilinmiyor'), findsOneWidget);
    expect(find.text('Yayın yılı bilinmiyor'), findsOneWidget);
  });

  testWidgets('Keyboard search shows loading then an empty result message', (
    tester,
  ) async {
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'Bulunmayan kitap');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.clear))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    returnBooks([]);
    await tester.pumpAndSettle();
    expect(find.text('Kitap bulunamadı'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('A failed request can be retried successfully', (tester) async {
    await openSearch(tester);
    await search(tester, 'Dune');
    pending
        .removeAt(0)
        .reject(
          DioException(
            requestOptions: requests.last,
            type: DioExceptionType.connectionTimeout,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Arama uzun sürdü. Lütfen tekrar dene.'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests, hasLength(2));
    expect(requests.last.queryParameters['q'], 'Dune');
    returnBooks([
      {
        'title': 'Dune',
        'author_name': ['Frank Herbert'],
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Frank Herbert'), findsOneWidget);
    expect(find.text('Arama uzun sürdü. Lütfen tekrar dene.'), findsNothing);
    expect(find.text('Tekrar dene'), findsNothing);
  });

  testWidgets('Leaving the page during a search cancels it safely', (
    tester,
  ) async {
    await openSearch(tester);
    await search(tester, 'Dune');
    final token = requests.single.cancelToken!;

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(token.isCancelled, isTrue);
    returnBooks([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Clearing removes the query, old results and errors without a request',
    (tester) async {
      await openSearch(tester);
      expect(find.byTooltip('Aramayı temizle'), findsNothing);
      await search(tester, 'Dune');
      returnBooks([
        {'title': 'Dune'},
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Dune'), findsNothing);
      expect(find.text('Aramak için bir kitap adı yaz'), findsOneWidget);
      expect(find.byTooltip('Aramayı temizle'), findsNothing);
      expect(requests, hasLength(1));

      await search(tester, 'Dune');
      pending.removeAt(0).reject(DioException(requestOptions: requests.last));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsNothing);
      expect(find.text('Aramak için bir kitap adı yaz'), findsOneWidget);
      expect(requests, hasLength(2));

      await search(tester, '   ');
      expect(find.text('Bir kitap adı yaz'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Bir kitap adı yaz'), findsNothing);
      expect(requests, hasLength(2));
    },
  );

  testWidgets('Search failures give relevant guidance on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSearch(tester);

    final cases = [
      (
        DioExceptionType.receiveTimeout,
        null,
        'Arama uzun sürdü. Lütfen tekrar dene.',
      ),
      (
        DioExceptionType.connectionError,
        null,
        'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
      ),
      (
        DioExceptionType.badResponse,
        429,
        'Çok sık arama yapıldı. Biraz bekleyip tekrar dene.',
      ),
      (
        DioExceptionType.badResponse,
        503,
        'Kitap servisi şu an yanıt veremiyor. Daha sonra tekrar dene.',
      ),
      (
        DioExceptionType.unknown,
        null,
        'Kitaplar yüklenemedi. Lütfen tekrar dene.',
      ),
    ];
    for (final (type, statusCode, message) in cases) {
      await search(tester, 'Dune');
      pending
          .removeAt(0)
          .reject(
            DioException(
              requestOptions: requests.last,
              type: type,
              response: statusCode == null
                  ? null
                  : Response(
                      requestOptions: requests.last,
                      statusCode: statusCode,
                    ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Author search uses the author filter and switching modes resets results',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openSearch(tester);
      await tester.tap(find.text('Yazar'));
      await tester.pumpAndSettle();
      expect(find.text('Aramak için bir yazar adı yaz'), findsOneWidget);
      await search(tester, '   ');
      expect(find.text('Bir yazar adı yaz'), findsOneWidget);
      expect(requests, isEmpty);

      await tester.enterText(find.byType(TextField), '  Sabahattin Ali  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.single.queryParameters['author'], 'Sabahattin Ali');
      expect(requests.single.queryParameters.containsKey('q'), isFalse);
      await tester.tap(find.text('Kitap'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
        'Yazar adı',
      );
      returnBooks([
        {
          'title': 'Kuyucaklı Yusuf',
          'author_name': ['Sabahattin Ali'],
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsOneWidget);

      await tester.tap(find.text('Kuyucaklı Yusuf'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
        'Yazar adı',
      );
      expect(requests, hasLength(1));

      await tester.tap(find.text('Kitap'));
      await tester.pumpAndSettle();
      expect(find.text('Kuyucaklı Yusuf'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Aramak için bir kitap adı yaz'), findsOneWidget);
      await search(tester, 'Dune');
      expect(requests.last.queryParameters['q'], 'Dune');
      expect(requests.last.queryParameters.containsKey('author'), isFalse);
      returnBooks([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Retry and clear keep the selected author search mode', (
    tester,
  ) async {
    await openSearch(tester);
    await tester.tap(find.text('Yazar'));
    await tester.pumpAndSettle();
    await search(tester, 'Sabahattin Ali');
    pending.removeAt(0).reject(DioException(requestOptions: requests.last));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(requests.last.queryParameters['author'], 'Sabahattin Ali');
    expect(requests.last.queryParameters.containsKey('q'), isFalse);
    returnBooks([]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Aramak için bir yazar adı yaz'), findsOneWidget);
    expect(requests, hasLength(2));
  });

  testWidgets('Opening book details and returning preserves search results', (
    tester,
  ) async {
    await openSearch(tester);
    await search(tester, 'Çöl');
    returnBooks([
      {
        'title': 'Dune',
        'author_name': ['Frank Herbert', 'İkinci yazar'],
        'first_publish_year': 1965,
        'edition_count': 120,
      },
      {'title': 'Başka bir kitap'},
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dune'));
    await tester.pumpAndSettle();
    expect(find.text('Kitap detayı'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Frank Herbert, İkinci yazar'), findsOneWidget);
    expect(find.text('1965'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Başka bir kitap'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kitap detayı'), findsNothing);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Başka bir kitap'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Çöl',
    );
    expect(requests, hasLength(1));
  });

  testWidgets(
    'Matching edition subtitle explains results on cards and details',
    (tester) async {
      await openSearch(tester);
      await search(tester, 'insan olmanın');
      returnBooks([
        {
          'title': 'Akıl',
          'author_name': ['Daniel J. Siegel'],
          'editions': {
            'docs': [
              {'title': 'Akıl', 'subtitle': 'İnsan Olmanın Özüne Yolculuk'},
            ],
          },
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('İnsan Olmanın Özüne Yolculuk'), findsOneWidget);

      await tester.tap(find.text('Akıl'));
      await tester.pumpAndSettle();
      expect(find.text('Kitap detayı'), findsOneWidget);
      expect(find.text('İnsan Olmanın Özüne Yolculuk'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('İnsan Olmanın Özüne Yolculuk'), findsOneWidget);
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
