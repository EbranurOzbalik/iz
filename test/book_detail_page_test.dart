import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/book_cover.dart';
import 'package:iz/book_detail_page.dart';

void main() {
  group('Edition details', () {
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

    Future<void> openDetails(WidgetTester tester) async {
      final book = Book.fromJson({
        'title': 'Akıl',
        'author_name': ['Daniel J. Siegel'],
        'first_publish_year': 2019,
        'edition_count': 1,
        'editions': {
          'docs': [
            {
              'key': '/books/OL35376310M',
              'subtitle': 'İnsan Olmanın Özüne Yolculuk',
            },
          ],
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: BookDetailPage(book: book, dio: dio),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }

    void returnEdition(Map<String, dynamic> data) {
      pending
          .removeAt(0)
          .resolve(Response(requestOptions: requests.last, data: data));
    }

    testWidgets(
      'Loads the matched edition while keeping book details visible',
      (tester) async {
        await openDetails(tester);
        expect(find.text('Akıl'), findsOneWidget);
        expect(find.text('İnsan Olmanın Özüne Yolculuk'), findsOneWidget);
        expect(find.text('Yükleniyor…'), findsNWidgets(2));
        expect(
          requests.single.path,
          'https://openlibrary.org/books/OL35376310M.json',
        );

        returnEdition({
          'number_of_pages': 424,
          'publishers': ['Pegasus Yayınları'],
        });
        await tester.pumpAndSettle();
        expect(find.text('Sayfa sayısı'), findsOneWidget);
        expect(find.text('424'), findsOneWidget);
        expect(find.text('Yayınevi'), findsOneWidget);
        expect(find.text('Pegasus Yayınları'), findsOneWidget);
        expect(find.text('Yükleniyor…'), findsNothing);
        expect(requests, hasLength(1));
      },
    );

    testWidgets('Missing and invalid page counts are shown as unknown', (
      tester,
    ) async {
      for (final count in [null, 0, -1, 'invalid', 424.5]) {
        await openDetails(tester);
        returnEdition({'number_of_pages': count});
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Sayfa sayısı'),
            matching: find.text('Bilinmiyor'),
          ),
          findsOneWidget,
        );
        expect(find.text('Yüklenemedi'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
      'Failed page count request can be retried without losing details',
      (tester) async {
        await openDetails(tester);
        pending
            .removeAt(0)
            .reject(
              DioException(
                requestOptions: requests.last,
                type: DioExceptionType.receiveTimeout,
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('Yüklenemedi'), findsNWidgets(2));
        expect(find.text('Akıl'), findsOneWidget);

        await tester.tap(find.byTooltip('Baskı bilgilerini tekrar yükle'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('Yükleniyor…'), findsNWidgets(2));
        expect(requests, hasLength(2));
        returnEdition({
          'number_of_pages': 424,
          'publishers': ['Pegasus Yayınları'],
        });
        await tester.pumpAndSettle();
        expect(find.text('424'), findsOneWidget);
        expect(find.text('Pegasus Yayınları'), findsOneWidget);
        expect(find.text('Yüklenemedi'), findsNothing);
      },
    );

    testWidgets('Leaving details cancels an unfinished page count request', (
      tester,
    ) async {
      await openDetails(tester);
      final token = requests.single.cancelToken!;
      await tester.pumpWidget(const SizedBox());
      expect(token.isCancelled, isTrue);
      returnEdition({'number_of_pages': 424});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'Missing metadata remains readable on a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final book = Book(
        title: 'Kürk Mantolu Madonna: Açıklamalı ve Genişletilmiş Özel Baskı',
        authors: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: BookDetailPage(book: book),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(book.title), findsOneWidget);
      expect(find.text('Yazar bilinmiyor'), findsOneWidget);
      expect(find.text('Sayfa sayısı'), findsOneWidget);
      expect(find.text('Bilinmiyor'), findsNWidgets(4));
      expect(find.bySemanticsLabel('Kapak görseli yok'), findsOneWidget);
      expect(tester.getSize(find.byType(BookCover)), const Size(120, 180));

      await tester.ensureVisible(find.text('Baskı sayısı'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Baskı sayısı')).bottom,
        lessThanOrEqualTo(480),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
