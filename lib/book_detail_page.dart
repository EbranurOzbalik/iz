import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'book.dart';
import 'book_cover.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.book, this.dio});

  final Book book;
  final Dio? dio;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final CancelToken cancelToken = CancelToken();
  late final Dio dio;
  late Future<int?> pageCount;

  @override
  void initState() {
    super.initState();
    dio =
        widget.dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
    pageCount = loadPageCount();
  }

  Future<int?> loadPageCount() async {
    final url = widget.book.editionUrl;
    if (url == null) return null;

    final response = await dio.get(url, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid edition response');
    }
    final count = data['number_of_pages'];
    return count is int && count > 0 ? count : null;
  }

  @override
  void dispose() {
    cancelToken.cancel();
    if (widget.dio == null) dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
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
                  FutureBuilder<int?>(
                    future: pageCount,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState != ConnectionState.done;
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('Sayfa sayısı'),
                        subtitle: Text(
                          isLoading
                              ? 'Yükleniyor…'
                              : snapshot.hasError
                              ? 'Yüklenemedi'
                              : snapshot.data?.toString() ?? 'Bilinmiyor',
                        ),
                        trailing: !isLoading && snapshot.hasError
                            ? IconButton(
                                tooltip: 'Sayfa sayısını tekrar yükle',
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    pageCount = loadPageCount();
                                  });
                                },
                              )
                            : null,
                      );
                    },
                  ),
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
