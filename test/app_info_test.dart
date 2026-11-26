import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:iz/app_info_page.dart';
import 'package:iz/discover_page.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_store.dart';
import 'package:iz/release_config.dart';

import 'journal_test_support.dart';
import 'movie_test_support.dart';

void main() {
  late MemoryJournalStorage storage;
  late JournalStore store;
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'İZ',
      packageName: 'com.ebranurozbalik.iz',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    storage = MemoryJournalStorage();
    store = JournalStore(storage: storage);
    await store.load();
    await store.save(
      const JournalEntry(
        id: 'test-film',
        title: 'Perfect Days',
        creator: 'Wim Wenders',
        type: MediaType.film,
        note: 'Bir not',
        rating: 4,
      ),
    );
  });
  tearDown(() => store.dispose());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('Clearing persists an empty journal and activity history', () async {
    await store.clear();
    final reopened = JournalStore(storage: storage);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.entries, isEmpty);
    expect(reopened.activities, isEmpty);
    expect(reopened.loadError, isNull);
  });

  test(
    'Failed clear preserves the complete journal on disk and in memory',
    () async {
      final previous = storage.data;
      storage.failWrites = true;
      await expectLater(store.clear(), throwsStateError);
      expect(storage.data, previous);
      expect(store.entries.single.note, 'Bir not');
      expect(store.activities, isNotEmpty);
      expect(store.busy, isFalse);
    },
  );

  testWidgets(
    'Privacy is available offline and version uses package metadata',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: AppInfoPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Sürüm 1.0.0 (1)'), findsOneWidget);
      await tap(tester, find.text('Gizlilik politikası'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Cihazındaki kayıtlar'), findsOneWidget);
      expect(find.text('Saklama, silme ve güvenlik'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancel deletion retains data; confirmation clears and disables button',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: AppInfoPage(store: store)));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Tüm kayıtlarımı sil'));
      await tap(tester, find.text('Vazgeç'));
      expect(store.entries, hasLength(1));
      await tap(tester, find.text('Tüm kayıtlarımı sil'));
      await tap(tester, find.text('Tümünü sil'));
      expect(store.entries, isEmpty);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('Deletion error offers retry without losing records', (
    tester,
  ) async {
    storage.failWrites = true;
    await tester.pumpWidget(MaterialApp(home: AppInfoPage(store: store)));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Tüm kayıtlarımı sil'));
    await tap(tester, find.text('Tümünü sil'));
    expect(store.entries, hasLength(1));
    expect(
      find.text(
        'Kayıtlar silinemedi. Günlüğün korundu; tekrar deneyebilirsin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Help stays usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(home: AppInfoPage(store: store)));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Tüm kayıtlarımı sil'));
    expect(find.text('Bütün izlerin silinsin mi?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Unconfigured films show manual entry, without an unusable search',
    (tester) async {
      final catalog = FakeMovieCatalog()..isConfigured = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MovieSearchPage(store: store, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Film bilgilerinin dili'), findsNothing);
      await tap(tester, find.text('Filmi elle ekle'));
      expect(find.text('Yeni bir iz'), findsOneWidget);
      expect(find.text('Film bilgilerinin dili'), findsNothing);
      expect(catalog.searches, isEmpty);
    },
  );

  test('Release contact links reject malformed configuration', () {
    expect(const ReleaseConfig().privacyUri, isNull);
    expect(
      const ReleaseConfig(privacyPolicyUrl: 'http://example.com').privacyUri,
      isNull,
    );
    expect(
      const ReleaseConfig(supportEmail: 'not-an-email').supportUri,
      isNull,
    );
    expect(
      const ReleaseConfig(
        privacyPolicyUrl: 'https://example.com/privacy',
      ).privacyUri!.host,
      'example.com',
    );
    expect(
      const ReleaseConfig(supportEmail: 'support@example.com').supportUri!.path,
      'support@example.com',
    );
  });
}
