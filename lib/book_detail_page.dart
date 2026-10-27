import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book.dart';
import 'book_cover.dart';
import 'book_edition.dart';

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
  late Future<BookEdition?> editionDetails;
  bool isCopying = false;

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
    editionDetails = loadEditionDetails();
  }

  Future<BookEdition?> loadEditionDetails() async {
    final url = widget.book.editionUrl;
    if (url == null) return null;

    final response = await dio.get(url, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid edition response');
    }
    return BookEdition.fromJson(data);
  }

  Future<void> copyBookInfo() {
    final book = widget.book;
    final text = [
      book.title,
      if (book.subtitle != null && book.subtitle!.trim().isNotEmpty)
        book.subtitle!.trim(),
      if (book.authors.isNotEmpty) book.authors.join(', '),
    ].join('\n');
    return copyText(text, 'Kitap bilgisi kopyalandı');
  }

  Future<void> copyText(String text, String successMessage) async {
    if (isCopying) return;
    setState(() => isCopying = true);
    var message = successMessage;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      message = 'Kopyalanamadı. Lütfen tekrar dene.';
    }
    if (!mounted) return;
    setState(() => isCopying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      appBar: AppBar(
        title: const Text('Kitap detayı'),
        actions: [
          IconButton(
            tooltip: 'Kitap bilgisini kopyala',
            onPressed: isCopying ? null : copyBookInfo,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
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
                  FutureBuilder<BookEdition?>(
                    future: editionDetails,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState != ConnectionState.done;
                      final status = isLoading
                          ? 'Yükleniyor…'
                          : snapshot.hasError
                          ? 'Yüklenemedi'
                          : 'Bilinmiyor';
                      final publishers = snapshot.data?.publishers ?? [];
                      final isbn = snapshot.data?.isbn;
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: const Text('Sayfa sayısı'),
                            subtitle: Text(
                              snapshot.data?.pageCount?.toString() ?? status,
                            ),
                            trailing: !isLoading && snapshot.hasError
                                ? IconButton(
                                    tooltip: 'Baskı bilgilerini tekrar yükle',
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () {
                                      setState(() {
                                        editionDetails = loadEditionDetails();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          ListTile(
                            leading: const Icon(Icons.business_outlined),
                            title: const Text('Yayınevi'),
                            subtitle: Text(
                              publishers.isNotEmpty
                                  ? publishers.join(', ')
                                  : status,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.numbers),
                            title: const Text('ISBN'),
                            subtitle: Text(isbn ?? status),
                            trailing: isbn == null
                                ? null
                                : IconButton(
                                    tooltip: 'ISBN numarasını kopyala',
                                    onPressed: isCopying
                                        ? null
                                        : () =>
                                              copyText(isbn, 'ISBN kopyalandı'),
                                    icon: const Icon(Icons.copy_outlined),
                                  ),
                          ),
                        ],
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
