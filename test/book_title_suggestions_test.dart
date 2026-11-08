import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book_title_suggestions.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_entry_page.dart';
import 'package:iz/journal_store.dart';

import 'journal_test_support.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  late List<RequestInterceptorHandler> pending;
  late JournalStore store;

  setUp(() async {
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
    store = JournalStore(storage: MemoryJournalStorage());
    await store.load();
  });
  tearDown(() {
    dio.close(force: true);
    store.dispose();
  });

  Future<void> openForm(
    WidgetTester tester, {
    MediaType type = MediaType.book,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddJournalEntryPage(store: store, initialType: type, dio: dio),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeTitle(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField).first, text);
    await tester.pump();
  }

  Future<void> waitForSearch(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 1));
  }

  void respond(int index, Object data) => pending[index].resolve(
    Response(requestOptions: requests[index], data: data),
  );

  Map<String, Object> results(String title, {bool edition = false}) => {
    'docs': [
      {
        'key': '/works/OL1W',
        'title': title,
        'author_name': ['Fyodor Dostoyevski'],
        if (edition)
          'editions': {
            'docs': [
              <String, Object>{'key': '/books/OL2M', 'title': title},
            ],
          },
      },
    ],
  };

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'Typing waits briefly, cancels stale searches and lists only the latest title',
    (tester) async {
      await openForm(tester);
      await typeTitle(tester, 'İ');
      await waitForSearch(tester);
      expect(requests, isEmpty);
      await typeTitle(tester, 'İnsan');
      await tester.pump(const Duration(milliseconds: 200));
      await typeTitle(tester, 'İnsancıklar');
      await waitForSearch(tester);
      expect(requests, hasLength(1));
      expect(requests[0].queryParameters['title'], 'İnsancıklar');
      expect(requests[0].queryParameters['lang'], 'tr');
      expect(requests[0].queryParameters['language'], 'tur');
      await typeTitle(tester, 'Martı');
      expect(requests[0].cancelToken!.isCancelled, isTrue);
      respond(0, results('Eski sonuç'));
      await waitForSearch(tester);
      respond(1, results('Martı kitabı'));
      await tester.pumpAndSettle();
      expect(find.text('Martı kitabı'), findsOneWidget);
      expect(find.text('Eski sonuç'), findsNothing);
      await typeTitle(tester, '');
      await tester.pumpAndSettle();
      expect(find.text('Martı kitabı'), findsNothing);
      expect(requests, hasLength(2));
    },
  );

  testWidgets(
    'Language changes cancel old suggestions and invalidate the selected edition',
    (tester) async {
      await openForm(tester);
      await typeTitle(tester, 'Dune');
      await waitForSearch(tester);
      await tapVisible(tester, find.text('İngilizce'));
      expect(requests[0].cancelToken!.isCancelled, isTrue);
      respond(0, results('Türkçe eski sonuç'));
      await waitForSearch(tester);
      expect(requests[1].queryParameters['title'], 'Dune');
      expect(requests[1].queryParameters['language'], 'eng');
      expect(requests[1].queryParameters['lang'], 'en');
      respond(1, results('Dune English edition'));
      await tester.pumpAndSettle();
      expect(find.text('Türkçe eski sonuç'), findsNothing);
      await tapVisible(tester, find.text('Dune English edition'));
      expect(find.text('Kitap seçildi'), findsOneWidget);
      await tapVisible(tester, find.text('Türkçe'));
      expect(find.text('Kitap seçildi'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      await waitForSearch(tester);
      expect(requests[2].queryParameters['language'], 'tur');
      respond(2, {'docs': []});
      await tester.pumpAndSettle();
      expect(
        find.text('Eşleşen kitap bulunamadı. Bilgileri elle ekleyebilirsin.'),
        findsOneWidget,
      );
      expect(store.entries, isEmpty);
    },
  );

  testWidgets(
    'Selection fills author and saves catalog identity, cover and page count',
    (tester) async {
      await openForm(tester);
      await typeTitle(tester, 'İnsancıklar');
      await waitForSearch(tester);
      final response = results('İnsancıklar — seçilecek baskı', edition: true);
      final work = (response['docs'] as List).first as Map;
      work['cover_i'] = 999;
      ((work['editions']['docs'] as List).first as Map)['cover_i'] = 123;
      respond(0, response);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('İnsancıklar — seçilecek baskı'));
      expect(find.text('Kitap seçildi'), findsOneWidget);
      expect(find.byType(BookTitleSuggestions), findsNothing);
      final creator = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(creator.controller!.text, 'Fyodor Dostoyevski');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).readOnly,
        isTrue,
      );
      await tapVisible(tester, find.text('Arşivime ekle'));
      expect(requests[1].path, 'https://openlibrary.org/books/OL2M.json');
      respond(1, {'number_of_pages': 176});
      await tester.pumpAndSettle();
      final entry = store.entries.single;
      expect(entry.id, 'book:/works/OL1W');
      expect(entry.creator, 'Fyodor Dostoyevski');
      expect(entry.book!.coverId, 123);
      expect(entry.book!.editionKey, '/books/OL2M');
      expect(entry.total, 176);
      expect(store.activities, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Editing a selected title drops the previous book metadata', (
    tester,
  ) async {
    await openForm(tester);
    await typeTitle(tester, 'İnsan');
    await waitForSearch(tester);
    respond(0, results('İnsancıklar'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('İnsancıklar'));
    await typeTitle(tester, 'Kendi kitabım');
    expect(find.text('Kitap seçildi'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      isEmpty,
    );
    await waitForSearch(tester);
    respond(1, {'docs': []});
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Kendi yazarım');
    await tapVisible(tester, find.text('Arşivime ekle'));
    await tester.pumpAndSettle();
    expect(store.entries.single.book, isNull);
    expect(store.entries.single.title, 'Kendi kitabım');
    expect(store.entries.single.creator, 'Kendi yazarım');
  });

  testWidgets(
    'Retry preserves the typed title and edition failure still allows saving',
    (tester) async {
      await openForm(tester);
      await typeTitle(tester, 'İnsancıklar');
      await waitForSearch(tester);
      pending[0].reject(
        DioException(
          requestOptions: requests[0],
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Tekrar dene'));
      expect(requests[1].queryParameters['title'], 'İnsancıklar');
      respond(1, results('İnsancıklar baskısı', edition: true));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('İnsancıklar baskısı'));
      (store.storage as MemoryJournalStorage).failWrites = true;
      await tapVisible(tester, find.text('Arşivime ekle'));
      pending[2].reject(
        DioException(
          requestOptions: requests[2],
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      expect(find.text('Kitap seçildi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      (store.storage as MemoryJournalStorage).failWrites = false;
      await tapVisible(tester, find.text('Arşivime ekle'));
      respond(3, {});
      await tester.pumpAndSettle();
      expect(store.entries.single.book!.workKey, '/works/OL1W');
      expect(store.entries.single.total, isNull);
    },
  );

  testWidgets('Changing media type and leaving the form cancels book lookup', (
    tester,
  ) async {
    await openForm(tester);
    await typeTitle(tester, 'İnsan');
    await waitForSearch(tester);
    await tapVisible(tester, find.byType(DropdownButtonFormField<MediaType>));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Film').last);
    await tester.pumpAndSettle();
    expect(requests[0].cancelToken!.isCancelled, isTrue);
    expect(find.byType(BookTitleSuggestions), findsNothing);
    await typeTitle(tester, 'Perfect Days');
    await waitForSearch(tester);
    expect(requests, hasLength(1));
    respond(0, results('Geç gelen kitap'));
    await tester.pumpAndSettle();
    expect(find.text('Geç gelen kitap'), findsNothing);
    await tapVisible(tester, find.byType(DropdownButtonFormField<MediaType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap').last);
    await tester.pump();
    await waitForSearch(tester);
    expect(requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(requests[1].cancelToken!.isCancelled, isTrue);
    respond(1, results('Başka geç gelen kitap'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inline results remain selectable with keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openForm(tester);
    await typeTitle(tester, 'İnsan');
    await waitForSearch(tester);
    respond(0, results('İnsancıklar uzun bir baskı adı'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('İnsancıklar uzun bir baskı adı'));
    expect(find.text('Kitap seçildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
