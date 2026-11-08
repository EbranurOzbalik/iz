import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'book.dart';
import 'book_cover.dart';
import 'book_discovery.dart';
import 'book_language.dart';

class BookTitleSuggestions extends StatefulWidget {
  const BookTitleSuggestions({
    super.key,
    required this.query,
    required this.dio,
    required this.onSelected,
    required this.language,
  });

  final String query;
  final Dio dio;
  final ValueChanged<Book> onSelected;
  final BookLanguage language;

  @override
  State<BookTitleSuggestions> createState() => _BookTitleSuggestionsState();
}

class _BookTitleSuggestionsState extends State<BookTitleSuggestions> {
  late final catalog = OpenLibraryDiscovery(dio: widget.dio);
  Timer? debounce;
  CancelToken? request;
  List<Book> books = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(BookTitleSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim() != widget.query.trim() ||
        oldWidget.language != widget.language) {
      schedule();
    }
  }

  void schedule() {
    debounce?.cancel();
    request?.cancel();
    books = [];
    error = null;
    loading = widget.query.trim().length >= 2;
    if (loading) {
      debounce = Timer(const Duration(milliseconds: 450), search);
    }
  }

  Future<void> search() async {
    debounce?.cancel();
    request?.cancel();
    final token = CancelToken();
    request = token;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await catalog.searchTitle(
        widget.query,
        token,
        language: widget.language,
      );
      if (!mounted || token.isCancelled) return;
      setState(() => books = result);
    } catch (failure) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        error = failure is DioException && failure.response?.statusCode == 429
            ? 'Kitap servisi yoğun. Biraz sonra tekrar deneyebilirsin.'
            : 'Kitaplar aranamadı. Tekrar deneyebilir veya elle ekleyebilirsin.';
      });
    } finally {
      if (mounted && !token.isCancelled) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    request?.cancel();
    catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().length < 2) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Kitap bulmak için en az 2 harf yaz.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Kitaplar aranıyor…'),
          ] else if (error != null) ...[
            Text(error!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: search,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ),
          ] else if (books.isEmpty)
            const Text(
              'Eşleşen kitap bulunamadı. Bilgileri elle ekleyebilirsin.',
            )
          else ...[
            Text(
              'Eşleşen kitaplar',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final book in books)
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => widget.onSelected(book),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BookCover(book: book, width: 44, height: 66),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book.authors.isEmpty
                                    ? 'Yazar bilinmiyor'
                                    : book.authors.join(', '),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.add_circle_outline, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
