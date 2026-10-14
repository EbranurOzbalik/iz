import 'package:flutter/material.dart';

import 'book.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 60,
    this.height = 90,
  });

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = book.coverUrl;
    final colors = Theme.of(context).colorScheme;

    Widget placeholder(String label) {
      return Semantics(
        image: true,
        label: label,
        child: Center(
          child: Icon(Icons.menu_book_outlined, color: colors.onSurfaceVariant),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: url == null
              ? placeholder('Kapak görseli yok')
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  semanticLabel: '${book.title} kitap kapağı',
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        return frame == null
                            ? placeholder('Kapak yükleniyor')
                            : child;
                      },
                  errorBuilder: (context, error, stackTrace) {
                    return placeholder('Kapak görseli yüklenemedi');
                  },
                ),
        ),
      ),
    );
  }
}
