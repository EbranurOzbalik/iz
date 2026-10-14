import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/book_cover.dart';
import 'package:iz/book_detail_page.dart';

void main() {
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

      expect(find.text(book.title), findsOneWidget);
      expect(find.text('Yazar bilinmiyor'), findsOneWidget);
      expect(find.text('Bilinmiyor'), findsNWidgets(2));
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
