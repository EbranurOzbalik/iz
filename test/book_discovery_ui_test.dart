import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/book_detail_page.dart';
import 'package:iz/book_discovery.dart';
import 'package:iz/book_discovery_section.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_calendar.dart';
import 'package:iz/journal_store.dart';
import 'package:iz/main.dart';

import 'journal_test_support.dart';

Book book(String title, int id) =>
    Book(title: title, authors: ['Yazar'], workKey: '/works/OL${id}W');

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Widget shelves(StubBookDiscovery source, {Set<String> saved = const {}}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookDiscoverySection(
            source: source,
            savedBookIds: saved,
            onOpenBook: (_) {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('One failed shelf does not block the other and can be retried', (
    tester,
  ) async {
    final source = StubBookDiscovery();
    source.onPopular = (_) async {
      if (source.popularCalls == 1) throw StateError('offline');
      return [book('Popüler eser', 1)];
    };
    source.onRecommendations = (_, _) async => [book('Önerilen eser', 2)];
    await tester.pumpWidget(shelves(source));
    await tester.pumpAndSettle();
    expect(find.text('Önerilen eser'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    await tapVisible(tester, find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Popüler eser'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsNothing);
    source.onPopular = (_) async => throw StateError('offline again');
    await tapVisible(tester, find.byTooltip('Popüler kitaplar rafını yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Popüler eser'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(source.topicCalls[BookTopic.fiction], 1);
  });

  testWidgets(
    'Late responses stay in their own topic and switching reuses results',
    (tester) async {
      final pending = {
        for (final topic in BookTopic.values) topic: Completer<List<Book>>(),
      };
      final source = StubBookDiscovery()
        ..onRecommendations = (topic, _) => pending[topic]!.future;
      await tester.pumpWidget(shelves(source));
      await tester.pump();
      await tapVisible(tester, find.text('Bilim kurgu'));
      await tapVisible(tester, find.text('Psikoloji'));
      pending[BookTopic.psychology]!.complete([book('Psikoloji kitabı', 3)]);
      await tester.pump();
      pending[BookTopic.scienceFiction]!.complete([
        book('Bilim kurgu kitabı', 2),
      ]);
      pending[BookTopic.fiction]!.complete([book('Roman kitabı', 1)]);
      await tester.pumpAndSettle();
      expect(find.text('Psikoloji kitabı'), findsOneWidget);
      expect(find.text('Bilim kurgu kitabı'), findsNothing);
      await tapVisible(tester, find.text('Bilim kurgu'));
      await tester.pumpAndSettle();
      expect(find.text('Bilim kurgu kitabı'), findsOneWidget);
      expect(source.topicCalls.values, everyElement(1));
      expect(source.popularCalls, 1);
    },
  );

  testWidgets('Disposing the page cancels outstanding requests safely', (
    tester,
  ) async {
    final pending = Completer<List<Book>>();
    CancelToken? token;
    final source = StubBookDiscovery()
      ..onPopular = (value) {
        token = value;
        return pending.future;
      };
    await tester.pumpWidget(shelves(source));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(token!.isCancelled, isTrue);
    pending.complete([book('Geç gelen kitap', 1)]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Shelf details save to archive, hide saved recommendations and retain state across filters',
    (tester) async {
      final selected = book('Raf kitabı', 1);
      final source = StubBookDiscovery();
      source.onPopular = (_) async => [selected];
      source.onRecommendations = (_, _) async => [selected];
      final store = JournalStore(storage: MemoryJournalStorage());
      addTearDown(store.dispose);
      await store.load();
      await tester.pumpWidget(IzApp(store: store, discovery: source));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Raf kitabı').first);
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailPage), findsOneWidget);
      await tapVisible(tester, find.text('Arşivime ekle'));
      await tester.pumpAndSettle();
      expect(store.find(JournalEntry.bookId(selected)), isNotNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final recommended = find.byKey(const ValueKey('recommended-fiction'));
      expect(
        find.descendant(of: recommended, matching: find.text('Raf kitabı')),
        findsNothing,
      );
      expect(find.text('Arşivinde'), findsOneWidget);
      final calendar = find.byType(JournalCalendar);
      expect(
        tester.getTopLeft(calendar).dy,
        greaterThan(tester.getBottomLeft(recommended).dy),
      );
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Film').first);
      await tester.pumpAndSettle();
      expect(find.text('Popüler kitaplar'), findsNothing);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Tümü').first);
      await tester.pumpAndSettle();
      expect(find.text('Popüler kitaplar'), findsOneWidget);
      expect(source.popularCalls, 1);
      expect(source.topicCalls[BookTopic.fiction], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Populated shelves fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final selected = book('Uzun başlıklı bir kitap ve uzun bir alt başlık', 1);
    final source = StubBookDiscovery();
    source.onPopular = (_) async => [selected, book('İkinci kitap', 2)];
    source.onRecommendations = (_, _) async => [selected];
    await tester.pumpWidget(
      shelves(source, saved: {JournalEntry.bookId(selected)}),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keşfetmen için'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bu raftaki kitaplar zaten arşivinde. Başka bir tür keşfedebilirsin.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
