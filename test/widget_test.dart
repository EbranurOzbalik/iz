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

  void returnBooks(List<Map<String, dynamic>> docs) {
    pending
        .removeAt(0)
        .resolve(Response(requestOptions: requests.last, data: {'docs': docs}));
  }

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
    expect(requests.single.queryParameters, {
      'q': 'Kürk Mantolu Madonna',
      'limit': 5,
    });

    const longTitle =
        'Kürk Mantolu Madonna: Açıklamalı ve Genişletilmiş Özel Baskı';
    returnBooks([
      {
        'title': longTitle,
        'author_name': ['Sabahattin Ali'],
        'first_publish_year': 1943,
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text(longTitle), findsOneWidget);
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
    expect(find.text('Kitaplar yüklenemedi'), findsOneWidget);

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
    expect(find.text('Kitaplar yüklenemedi'), findsNothing);
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
}
