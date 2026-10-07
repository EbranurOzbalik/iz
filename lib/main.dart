import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'book.dart';

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
  const BookSearchPage({super.key});

  @override
  State<BookSearchPage> createState() {
    return _BookSearchPageState();
  }
}

class _BookSearchPageState extends State<BookSearchPage> {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  bool isLoading = false;
  String? errorMessage;
  List<Book> books = [];

  Future<void> searchBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {
          'q': 'Suç ve Ceza',
          'limit': 5,
        },
      );

      final decoded = response.data;
      final docs = decoded['docs'];

      final List<Book> loadedBooks = docs.map<Book>((bookJson) {
        return Book.fromJson(bookJson);
      }).toList();

      setState(() {
        books = loadedBooks;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Kitaplar yüklenemedi';
      });

      print('Hata detayı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İZ'),
      ),

      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )

          : errorMessage != null
          ? Center(
        child: Text(errorMessage!),
      )

          : books.isNotEmpty
          ? ListView.builder(
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 90,
                  ),

                  const SizedBox(width: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title),

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
                ],
              ),
            ),
          );
        },
      )

          : Center(
        child: ElevatedButton(
          onPressed: searchBooks,
          child: const Text('Kitapları Getir'),
        ),
      ),
    );
  }
}