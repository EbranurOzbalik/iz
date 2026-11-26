import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/book_detail_page.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_calendar.dart';
import 'package:iz/journal_entry_page.dart';
import 'package:iz/journal_store.dart';
import 'package:iz/main.dart';

import 'journal_test_support.dart';

void main() {
  Future<JournalStore> createStore() async {
    final store = JournalStore(
      storage: MemoryJournalStorage(),
      clock: () => DateTime(2026, 11, 5),
    );
    addTearDown(store.dispose);
    await store.load();
    return store;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Android zero-size startup waits for the first usable surface', (
    tester,
  ) async {
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await createStore();
    await tester.pumpWidget(
      IzApp(store: store, discovery: StubBookDiscovery()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(393, 852);
    await tester.pumpAndSettle();
    expect(find.text('İlk hikâyen burada başlayacak.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A new journal has no fabricated activity and works at large text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await createStore();
      await tester.pumpWidget(
        IzApp(store: store, discovery: StubBookDiscovery()),
      );
      await tester.pumpAndSettle();
      expect(find.text('İlk hikâyen burada başlayacak.'), findsOneWidget);
      await tester.ensureVisible(find.text('İz takvimin'));
      await tester.pumpAndSettle();
      expect(store.activities, isEmpty);
      expect(
        tester.getTopLeft(find.text('İz takvimin')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('İlk hikâyen burada başlayacak.')).dy,
        ),
      );
      await tapVisible(tester, find.byKey(const ValueKey('day-2026-10-28')));
      expect(find.text('Bu gün için henüz bir kayıt yok.'), findsOneWidget);
      await tapVisible(tester, find.text('28 Eki 2026'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Adding a film, leaving a note and reopening restores the journal',
    (tester) async {
      final store = await createStore();
      await tester.pumpWidget(
        IzApp(store: store, discovery: StubBookDiscovery()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eser ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Perfect Days');
      await tester.enterText(find.byType(TextFormField).last, 'Wim Wenders');
      await tapVisible(tester, find.text('Arşivime ekle'));
      expect(find.byType(JournalEntryPage), findsOneWidget);
      expect(store.entries.single.type, MediaType.film);
      expect(store.activities, isEmpty);
      await tester.enterText(
        find.byType(TextFormField).last,
        'Küçük anlar da saklamaya değer.',
      );
      await tapVisible(tester, find.text('Günlüğüme kaydet'));
      expect(store.entries.single.note, 'Küçük anlar da saklamaya değer.');
      expect(store.activities, hasLength(1));
      final calendar = find.byType(JournalCalendar);
      await tester.ensureVisible(calendar);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(calendar).dy,
        greaterThan(tester.getBottomLeft(find.text('Arşivinden')).dy),
      );
      await tapVisible(tester, find.byKey(const ValueKey('day-2026-11-05')));
      expect(find.text('Sende kalanları not ettin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final restored = JournalStore(storage: store.storage);
      addTearDown(restored.dispose);
      await tester.pumpWidget(
        IzApp(store: restored, discovery: StubBookDiscovery()),
      );
      await tester.pumpAndSettle();
      expect(restored.entries.single.note, 'Küçük anlar da saklamaya değer.');
      expect(restored.activities, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Entry editing keeps the draft on write failure and validates progress',
    (tester) async {
      final store = await createStore();
      const entry = JournalEntry(
        id: 'book',
        title: 'Martı',
        creator: 'Richard Bach',
        type: MediaType.book,
        total: 112,
      );
      await store.save(entry);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEntryPage(store: store, entryId: entry.id),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '120');
      await tapVisible(tester, find.text('Günlüğüme kaydet'));
      expect(find.text('İlerleme toplamı aşamaz'), findsOneWidget);
      await tester.enterText(fields.at(0), '20');
      await tester.enterText(fields.last, 'Yarım kalmasın.');
      (store.storage as MemoryJournalStorage).failWrites = true;
      await tapVisible(tester, find.text('Günlüğüme kaydet'));
      expect(find.text('Yarım kalmasın.'), findsOneWidget);
      expect(store.entries.single.progress, 0);
      expect(store.activities, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Book detail saves edition page count and supports retry', (
    tester,
  ) async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(requestOptions: request, data: {'number_of_pages': 112}),
        ),
      ),
    );
    var attempts = 0;
    var saved = false;
    int? savedPages;
    final book = Book(
      title: 'Martı',
      authors: ['Richard Bach'],
      workKey: '/works/OL1W',
      editionKey: '/books/OL1M',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailPage(
          book: book,
          dio: dio,
          isBookSaved: (_) => saved,
          onSaveBook: (value, pages) async {
            attempts++;
            if (attempts == 1) throw StateError('No storage');
            saved = true;
            savedPages = pages;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Arşivime ekle'));
    expect(find.text('Arşive eklenemedi. Lütfen tekrar dene.'), findsOneWidget);
    await tapVisible(tester, find.text('Arşivime ekle'));
    expect(savedPages, 112);
    expect(find.text('Arşivimde'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
