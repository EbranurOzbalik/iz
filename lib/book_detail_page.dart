import 'package:flutter/material.dart';

import 'book.dart';
import 'book_cover.dart';

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kitap detayı')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  BookCover(book: book, width: 120, height: 180),
                  const SizedBox(height: 24),
                  Text(
                    book.title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  if (book.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.subtitle!,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    book.authors.isNotEmpty
                        ? book.authors.join(', ')
                        : 'Yazar bilinmiyor',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('İlk yayın yılı'),
                    subtitle: Text(
                      book.firstPublishYear?.toString() ?? 'Bilinmiyor',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_books_outlined),
                    title: const Text('Baskı sayısı'),
                    subtitle: Text(
                      book.editionCount?.toString() ?? 'Bilinmiyor',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Kaynak: Open Library', style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
