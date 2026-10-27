import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'book.dart';
import 'book_cover.dart';
import 'book_detail_page.dart';

void main() {
  runApp(const IzApp());
}

class IzApp extends StatelessWidget {
  const IzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BookSearchPage(),
    );
  }
}

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({super.key, this.dio});

  final Dio? dio;

  @override
  State<BookSearchPage> createState() {
    return _BookSearchPageState();
  }
}

enum _SearchMode { book, author }

enum _SearchSort {
  relevance('En ilgili', null),
  newest('İlk yayın: en yeni', 'new'),
  oldest('İlk yayın: en eski', 'old');

  const _SearchSort(this.label, this.parameter);

  final String label;
  final String? parameter;
}

class _BookSearchPageState extends State<BookSearchPage> {
  static const pageSize = 5;
  final TextEditingController searchController = TextEditingController();
  final CancelToken cancelToken = CancelToken();
  late final Dio dio;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  int nextOffset = 0;
  String activeQuery = '';
  _SearchMode activeMode = _SearchMode.book;
  String? loadMoreError;
  bool hasSearched = false;
  String? inputError;
  String? errorMessage;
  List<Book> books = [];
  _SearchMode searchMode = _SearchMode.book;
  _SearchSort searchSort = _SearchSort.relevance;

  bool get isAuthorSearch => searchMode == _SearchMode.author;
  bool get isBusy => isLoading || isLoadingMore;

  @override
  void initState() {
    super.initState();
    dio =
        widget.dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
  }

  @override
  void dispose() {
    cancelToken.cancel();
    if (widget.dio == null) {
      dio.close(force: true);
    }
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchBooks({
    bool loadMore = false,
    bool repeatSearch = false,
  }) async {
    if (isBusy || (loadMore && !hasMore)) return;

    final useActiveSearch = loadMore || repeatSearch;
    final query = useActiveSearch ? activeQuery : searchController.text.trim();
    final mode = useActiveSearch ? activeMode : searchMode;
    final offset = loadMore ? nextOffset : 0;
    if (query.isEmpty) {
      setState(() {
        inputError = isAuthorSearch ? 'Bir yazar adı yaz' : 'Bir kitap adı yaz';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      loadMoreError = null;
      if (loadMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
        hasSearched = true;
        inputError = null;
        errorMessage = null;
        books = [];
        hasMore = false;
        nextOffset = 0;
        activeQuery = query;
        activeMode = mode;
      }
    });

    try {
      final response = await dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {
          (mode == _SearchMode.author ? 'author' : 'q'): query,
          'limit': pageSize,
          'offset': offset,
          if (searchSort != _SearchSort.relevance) 'sort': searchSort.parameter,
          'fields':
              'key,title,subtitle,author_name,first_publish_year,'
              'edition_count,cover_i,editions,editions.key,editions.title,'
              'editions.subtitle',
        },
        cancelToken: cancelToken,
      );

      final decoded = response.data;
      final docs = decoded['docs'];

      final List<Book> loadedBooks = docs.map<Book>((bookJson) {
        return Book.fromJson(bookJson);
      }).toList();
      final total = decoded['numFound'] ?? decoded['num_found'];
      final totalResults = total is int && total >= 0 ? total : null;

      if (!mounted) return;
      setState(() {
        books = loadMore ? [...books, ...loadedBooks] : loadedBooks;
        nextOffset = offset + loadedBooks.length;
        hasMore =
            loadedBooks.isNotEmpty &&
            (totalResults != null
                ? nextOffset < totalResults
                : loadedBooks.length == pageSize);
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        if (loadMore) {
          loadMoreError = searchErrorMessage(e);
        } else {
          errorMessage = searchErrorMessage(e);
        }
      });

      debugPrint('Hata detayı: $e');
    }
  }

  void changeSort(_SearchSort? sort) {
    if (isBusy || sort == null || sort == searchSort) return;
    setState(() => searchSort = sort);
    if (hasSearched) searchBooks(repeatSearch: true);
  }

  void clearSearch({_SearchMode? mode}) {
    if (isBusy) return;
    searchController.clear();
    setState(() {
      if (mode != null) searchMode = mode;
      books = [];
      hasSearched = false;
      inputError = null;
      errorMessage = null;
      loadMoreError = null;
      hasMore = false;
      nextOffset = 0;
      activeQuery = '';
    });
  }

  String searchErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Arama uzun sürdü. Lütfen tekrar dene.';
        case DioExceptionType.connectionError:
          return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
        case DioExceptionType.badResponse:
          if (error.response?.statusCode == 429) {
            return 'Çok sık arama yapıldı. Biraz bekleyip tekrar dene.';
          }
          if ((error.response?.statusCode ?? 0) >= 500) {
            return 'Kitap servisi şu an yanıt veremiyor. Daha sonra tekrar dene.';
          }
        default:
          break;
      }
    }
    return 'Kitaplar yüklenemedi. Lütfen tekrar dene.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İZ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<_SearchMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SearchMode.book,
                      label: Text('Kitap'),
                    ),
                    ButtonSegment(
                      value: _SearchMode.author,
                      label: Text('Yazar'),
                    ),
                  ],
                  selected: {searchMode},
                  onSelectionChanged: isBusy
                      ? null
                      : (selection) => clearSearch(mode: selection.single),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      enabled: !isBusy,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: isAuthorSearch ? 'Yazar adı' : 'Kitap adı',
                        hintText: isAuthorSearch
                            ? 'Örn. Sabahattin Ali'
                            : 'Örn. Suç ve Ceza',
                        border: const OutlineInputBorder(),
                        errorText: inputError,
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Aramayı temizle',
                                onPressed: isBusy ? null : clearSearch,
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onChanged: (_) {
                        setState(() => inputError = null);
                      },
                      onSubmitted: (_) => searchBooks(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isBusy ? null : searchBooks,
                    child: const Text('Kitap Ara'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Tooltip(
                message: 'Sonuçları sırala',
                child: DropdownButton<_SearchSort>(
                  value: searchSort,
                  isExpanded: true,
                  icon: const Icon(Icons.sort),
                  items: [
                    for (final sort in _SearchSort.values)
                      DropdownMenuItem(value: sort, child: Text(sort.label)),
                  ],
                  onChanged: isBusy ? null : changeSort,
                ),
              ),
            ),
            Expanded(child: buildResults()),
          ],
        ),
      ),
    );
  }

  Widget buildResults() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => searchBooks(repeatSearch: true),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (books.isEmpty) {
      return Center(
        child: Text(
          hasSearched
              ? 'Kitap bulunamadı'
              : isAuthorSearch
              ? 'Aramak için bir yazar adı yaz'
              : 'Aramak için bir kitap adı yaz',
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (loadMoreError != null) ...[
                        Text(loadMoreError!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton(
                        onPressed: () => searchBooks(loadMore: true),
                        child: Text(
                          loadMoreError == null
                              ? 'Daha fazla göster'
                              : 'Devamını tekrar dene',
                        ),
                      ),
                    ],
                  ),
          );
        }
        final book = books[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => BookDetailPage(book: book),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  BookCover(book: book),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (book.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            book.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          book.authors.isNotEmpty
                              ? book.authors[0]
                              : 'Yazar bilinmiyor',
                        ),
                        Text(
                          book.firstPublishYear != null
                              ? 'İlk yayın: ${book.firstPublishYear}'
                              : 'Yayın yılı bilinmiyor',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
