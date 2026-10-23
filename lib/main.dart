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

class _BookSearchPageState extends State<BookSearchPage> {
  final TextEditingController searchController = TextEditingController();
  final CancelToken cancelToken = CancelToken();
  late final Dio dio;

  bool isLoading = false;
  bool hasSearched = false;
  String? inputError;
  String? errorMessage;
  List<Book> books = [];

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

  Future<void> searchBooks() async {
    if (isLoading) return;

    final query = searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        inputError = 'Bir kitap adı yaz';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      hasSearched = true;
      inputError = null;
      errorMessage = null;
      books = [];
    });

    try {
      final response = await dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {
          'q': query,
          'limit': 5,
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

      if (!mounted) return;
      setState(() {
        books = loadedBooks;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = searchErrorMessage(e);
      });

      debugPrint('Hata detayı: $e');
    }
  }

  void clearSearch() {
    if (isLoading) return;
    searchController.clear();
    setState(() {
      books = [];
      hasSearched = false;
      inputError = null;
      errorMessage = null;
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
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Kitap adı',
                        hintText: 'Örn. Suç ve Ceza',
                        border: const OutlineInputBorder(),
                        errorText: inputError,
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Aramayı temizle',
                                onPressed: isLoading ? null : clearSearch,
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
                    onPressed: isLoading ? null : searchBooks,
                    child: const Text('Kitap Ara'),
                  ),
                ],
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
                onPressed: searchBooks,
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
          hasSearched ? 'Kitap bulunamadı' : 'Aramak için bir kitap adı yaz',
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
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
