import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/book_cover.dart';

void main() {
  testWidgets('Books without covers show a sized accessible placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: BookCover(
            book: Book(title: 'Dune', authors: []),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Kapak görseli yok'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(BookCover)), const Size(60, 90));
  });

  testWidgets('A failed cover request shows a placeholder without crashing', (
    tester,
  ) async {
    // Flutter widget tests return HTTP 400 for network images by default.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: BookCover(
              book: Book(title: 'Dune', authors: [], coverId: 258027),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final completed = Completer<void>();
      final stream = image.image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, synchronousCall) => completed.complete(),
        onError: (Object error, StackTrace? stackTrace) => completed.complete(),
      );
      stream.addListener(listener);
      await completed.future;
      stream.removeListener(listener);
    });
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Kapak görseli yüklenemedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
