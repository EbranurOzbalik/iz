import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_entry_page.dart';
import 'package:iz/journal_store.dart';
import 'package:iz/main.dart';
import 'package:iz/catalog_discovery_section.dart';
import 'package:iz/discover_page.dart';
import 'package:iz/movie.dart';
import 'package:iz/movie_poster.dart';
import 'package:iz/movie_widgets.dart';

import 'journal_test_support.dart';
import 'movie_test_support.dart';

void main() {
  late FakeMovieCatalog catalog;
  late JournalStore store;
  setUp(() async {
    catalog = FakeMovieCatalog();
    store = JournalStore(storage: MemoryJournalStorage());
    await store.load();
  });
  tearDown(() => store.dispose());
  Future<void> form(
    WidgetTester tester, {
    MediaType initialType = MediaType.film,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddJournalEntryPage(
          store: store,
          movies: catalog,
          initialType: initialType,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextFormField).first, query);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('Film and series language headings are not repeated', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieSearchPage(store: store, catalog: catalog),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Film bilgilerinin dili'), findsOneWidget);
    expect(find.text('Film bilgilerinin dili bilgilerinin dili'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: MovieSearchPage(
          store: store,
          catalog: catalog,
          type: MediaType.series,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dizi bilgilerinin dili'), findsOneWidget);
    expect(find.text('Dizi bilgilerinin dili bilgilerinin dili'), findsNothing);
  });

  testWidgets(
    'Inline movie selection fills director and saves complete movie metadata',
    (tester) async {
      await form(tester);
      await search(tester, 'Interstellar');
      await tester.pumpAndSettle();
      expect(catalog.searches.single.query, 'Interstellar');
      expect(catalog.searches.single.locale, MovieLocale.turkish);
      await tap(tester, find.text('Yıldızlararası'));
      await tester.pumpAndSettle();
      expect(find.text('Film seçildi'), findsOneWidget);
      expect(find.text('2014 · 169 dk'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'Christopher Nolan',
      );
      await tap(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.entries.single.id, JournalEntry.movieId(testMovie));
      expect(store.entries.single.movie!.runtime, 169);
      expect(store.entries.single.creator, 'Christopher Nolan');
      expect(store.activities, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Language change cancels prior results without mixing films', (
    tester,
  ) async {
    final pending = Completer<List<Movie>>();
    catalog.onSearch = (_, locale, _) async => locale == MovieLocale.turkish
        ? await pending.future
        : [const Movie(id: 2, title: 'English movie')];
    await form(tester);
    await search(tester, 'Interstellar');
    await tap(tester, find.text('İngilizce'));
    expect(catalog.searches.single.token.isCancelled, isTrue);
    pending.complete([testMovie]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('English movie'), findsOneWidget);
    expect(find.text('Yıldızlararası'), findsNothing);
    expect(catalog.searches.last.locale, MovieLocale.english);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Changing media type cancels movie details and clears selected metadata',
    (tester) async {
      final pending = Completer<Movie>();
      catalog.onDetails = (_, _, _) => pending.future;
      await form(tester);
      await search(tester, 'Interstellar');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yıldızlararası'));
      await tap(tester, find.byType(DropdownButtonFormField<MediaType>));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Tiyatro').last);
      await tester.pumpAndSettle();
      expect(catalog.detailRequests.single.isCancelled, isTrue);
      pending.complete(detailedTestMovie);
      await tester.pumpAndSettle();
      expect(find.text('Film seçildi'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Missing configuration makes no request and manual entry remains usable',
    (tester) async {
      catalog.isConfigured = false;
      await form(tester);
      await search(tester, 'Perfect Days');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Film adını ve istersen yaratıcı bilgisini yazarak arşivine ekleyebilirsin.',
        ),
        findsOneWidget,
      );
      expect(catalog.searches, isEmpty);
      await tester.enterText(find.byType(TextFormField).last, 'Wim Wenders');
      await tap(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.entries.single.movie, isNull);
      expect(store.entries.single.title, 'Perfect Days');
      expect(store.entries.single.creator, 'Wim Wenders');
    },
  );

  testWidgets(
    'Detail and save failures preserve selected film and can be retried',
    (tester) async {
      var attempts = 0;
      catalog.onDetails = (_, _, _) async {
        if (++attempts == 1) throw StateError('offline');
        return detailedTestMovie;
      };
      await form(tester);
      await search(tester, 'Interstellar');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yıldızlararası'));
      await tester.pumpAndSettle();
      expect(find.text('Film seçildi'), findsOneWidget);
      await tap(tester, find.text('Bilgileri tekrar yükle'));
      await tester.pumpAndSettle();
      expect(find.text('2014 · 169 dk'), findsOneWidget);
      (store.storage as MemoryJournalStorage).failWrites = true;
      await tap(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      expect(find.text('Film seçildi'), findsOneWidget);
      (store.storage as MemoryJournalStorage).failWrites = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.entries.single.movie!.runtime, 169);
    },
  );

  testWidgets(
    'Discover films open details, save once, and show source attribution',
    (tester) async {
      await tester.pumpWidget(
        IzApp(store: store, discovery: StubBookDiscovery(), movies: catalog),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keşfet'));
      await tester.pumpAndSettle();
      expect(find.text('Diziler'), findsOneWidget);
      expect(find.text('Tiyatro'), findsOneWidget);
      await tester.tap(find.text('Filmler'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Interstellar');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yıldızlararası'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailPage), findsOneWidget);
      expect(find.text('Yönetmen: Christopher Nolan'), findsOneWidget);
      await tap(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.entries, hasLength(1));
      expect(find.text('Arşivimde'), findsOneWidget);
      await tap(tester, find.text('Film bilgileri ve görsel kaynağı'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutDialog), findsOneWidget);
      expect(find.textContaining('İZ Katalog API'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Film form and missing poster fit narrow screens at large text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await form(tester);
      await search(tester, 'Interstellar');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yıldızlararası'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Arşivime ekle'));
      expect(find.byType(MoviePoster), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Series use the İZ series catalog and keep episode tracking', (
    tester,
  ) async {
    await form(tester, initialType: MediaType.series);
    await search(tester, 'Interstellar');
    await tester.pumpAndSettle();
    expect(catalog.searches.single.kind, CatalogKind.series);
    await tap(tester, find.text('Yıldızlararası'));
    await tester.pumpAndSettle();
    expect(catalog.detailKinds.single, CatalogKind.series);
    expect(find.text('Dizi seçildi'), findsOneWidget);
    await tap(tester, find.text('Arşivime ekle'));
    await tester.pumpAndSettle();
    expect(store.entries.single.type, MediaType.series);
    expect(store.entries.single.id, 'catalog:series:157336');
    expect(store.entries.single.tracksProgress, isTrue);
  });

  testWidgets('Theatre uses the İZ theatre catalog', (tester) async {
    await form(tester, initialType: MediaType.theatre);
    await search(tester, 'Hamlet');
    await tester.pumpAndSettle();
    expect(catalog.searches.single.kind, CatalogKind.theatre);
    await tap(tester, find.text('Yıldızlararası'));
    await tester.pumpAndSettle();
    expect(find.text('Tiyatro seçildi'), findsOneWidget);
    await tap(tester, find.text('Arşivime ekle'));
    await tester.pumpAndSettle();
    expect(store.entries.single.type, MediaType.theatre);
    expect(store.entries.single.id, 'catalog:theatre:157336');
  });

  testWidgets(
    'Theatre recommendations refresh and archive without duplicate actions',
    (tester) async {
      const refreshed = Movie(id: 980000001, title: 'Yeni tiyatro oyunu');
      var calls = 0;
      catalog.onFeatured = (_, _, _) async =>
          calls++ == 0 ? [testMovie] : [refreshed];
      final saved = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogDiscoverySection(
              catalog: catalog,
              type: MediaType.theatre,
              savedIds: saved,
              onSave: (item, type) async {
                final entry = JournalEntry.fromCatalog(item, type);
                await store.save(entry);
                saved.add(entry.id);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yıldızlararası'), findsOneWidget);
      await tester.tap(find.byTooltip('Tiyatro önerileri listesini yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni tiyatro oyunu'), findsOneWidget);
      expect(find.text('Yıldızlararası'), findsNothing);
      expect(catalog.featuredOffsets, [0, 12]);

      await tester.tap(find.text('Arşive ekle'));
      await tester.pumpAndSettle();
      expect(store.entries, hasLength(1));
      expect(store.entries.single.id, 'catalog:theatre:980000001');
      expect(find.text('Arşivinde'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Arşivinde'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
