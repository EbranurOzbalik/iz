import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'book.dart';
import 'book_cover.dart';
import 'book_discovery.dart';
import 'journal.dart';

class BookDiscoverySection extends StatefulWidget {
  const BookDiscoverySection({
    super.key,
    this.source,
    required this.savedBookIds,
    required this.onOpenBook,
  });
  final BookDiscoverySource? source;
  final Set<String> savedBookIds;
  final ValueChanged<Book> onOpenBook;

  @override
  State<BookDiscoverySection> createState() => _BookDiscoverySectionState();
}

class _ShelfState {
  List<Book> books = [];
  bool loading = false;
  bool loaded = false;
  String? error;
}

class _BookDiscoverySectionState extends State<BookDiscoverySection> {
  late final source = widget.source ?? OpenLibraryDiscovery();
  final token = CancelToken();
  final popular = _ShelfState();
  final topics = <BookTopic, _ShelfState>{};
  BookTopic selectedTopic = BookTopic.fiction;

  @override
  void initState() {
    super.initState();
    loadPopular();
    loadTopic(selectedTopic);
  }

  @override
  void dispose() {
    token.cancel();
    if (widget.source == null) (source as OpenLibraryDiscovery).dispose();
    super.dispose();
  }

  Future<void> load(
    _ShelfState shelf,
    Future<List<Book>> Function() request,
  ) async {
    if (shelf.loading) return;
    setState(() {
      shelf.loading = true;
      shelf.error = null;
    });
    try {
      final books = await request();
      if (!mounted) return;
      setState(() {
        shelf.books = books;
        shelf.loaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => shelf.error =
            error is DioException && error.response?.statusCode == 429
            ? 'Kitap servisi yoğun. Biraz sonra tekrar dene.'
            : 'Bu raf yüklenemedi. Bağlantını kontrol edip tekrar deneyebilirsin.',
      );
    } finally {
      if (mounted) setState(() => shelf.loading = false);
    }
  }

  void loadPopular() => load(popular, () => source.popular(token));
  void loadTopic(BookTopic topic) => load(
    topics.putIfAbsent(topic, _ShelfState.new),
    () => source.recommendations(topic, token),
  );
  void selectTopic(BookTopic topic) {
    setState(() => selectedTopic = topic);
    if (topics[topic] == null) loadTopic(topic);
  }

  Widget shelf({
    required String id,
    required String title,
    required String subtitle,
    required _ShelfState state,
    required VoidCallback reload,
    Widget? filters,
    bool excludeSaved = false,
  }) {
    final books = state.books
        .where(
          (book) =>
              !excludeSaved ||
              !widget.savedBookIds.contains(JournalEntry.bookId(book)),
        )
        .take(12)
        .toList();
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '$title rafını yenile',
                onPressed: state.loading ? null : reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (filters != null) ...[const SizedBox(height: 12), filters],
          const SizedBox(height: 16),
          if (state.loading) ...[
            Semantics(
              label: '$title yükleniyor',
              child: const LinearProgressIndicator(),
            ),
            const SizedBox(height: 12),
          ],
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.error!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    onPressed: state.loading ? null : reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          if (books.isNotEmpty)
            bookRow(books, id)
          else if (state.loaded && !state.loading && state.error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                excludeSaved && state.books.isNotEmpty
                    ? 'Bu raftaki kitaplar zaten arşivinde. Başka bir tür keşfedebilirsin.'
                    : 'Bu rafta şu an kitap bulunamadı.',
              ),
            ),
        ],
      ),
    );
  }

  Widget bookRow(List<Book> books, String id) {
    final scale = MediaQuery.textScalerOf(context);
    final height =
        168 +
        14 +
        scale.scale(14) * 1.6 * 2 +
        4 +
        scale.scale(12) * 1.6 * 2 +
        8 +
        scale.scale(11) * 1.6 +
        12;
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: PageStorageKey('shelf-$id'),
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final book = books[index];
          final saved = widget.savedBookIds.contains(JournalEntry.bookId(book));
          return SizedBox(
            width: 132,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onOpenBook(book),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: BookCover(book: book, width: 112, height: 168),
                    ),
                    const SizedBox(height: 14),
                    Tooltip(
                      message: book.title,
                      excludeFromSemantics: true,
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.authors.isEmpty
                          ? 'Yazar bilinmiyor'
                          : book.authors.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    if (saved)
                      Text(
                        'Arşivinde',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      shelf(
        id: 'popular-books',
        title: 'Popüler kitaplar',
        subtitle: 'Open Library · Bu hafta',
        state: popular,
        reload: loadPopular,
      ),
      shelf(
        id: 'recommended-${selectedTopic.name}',
        title: 'Keşfetmen için',
        subtitle: 'Türüne göre · Türkçe baskısı olan kitaplar',
        state: topics[selectedTopic]!,
        reload: () => loadTopic(selectedTopic),
        excludeSaved: true,
        filters: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: BookTopic.values
              .map(
                (topic) => ChoiceChip(
                  label: Text(topic.label),
                  selected: topic == selectedTopic,
                  onSelected: (_) => selectTopic(topic),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}
