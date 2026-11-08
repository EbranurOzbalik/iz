import 'package:dio/dio.dart';

import 'book.dart';
import 'book_language.dart';
import 'journal.dart';

enum BookTopic {
  fiction('Roman', 'fiction'),
  scienceFiction('Bilim kurgu', 'science_fiction'),
  psychology('Psikoloji', 'psychology');

  const BookTopic(this.label, this.subject);
  final String label, subject;
}

abstract interface class BookDiscoverySource {
  Future<List<Book>> popular(CancelToken cancelToken);
  Future<List<Book>> recommendations(BookTopic topic, CancelToken cancelToken);
}

class OpenLibraryDiscovery implements BookDiscoverySource {
  OpenLibraryDiscovery({Dio? dio})
    : _ownsDio = dio == null,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _dio;
  final bool _ownsDio;

  Future<List<Book>> searchTitle(
    String title,
    CancelToken cancelToken, {
    BookLanguage language = BookLanguage.turkish,
  }) async {
    final response = await _dio.get(
      'https://openlibrary.org/search.json',
      queryParameters: {
        'title': title.trim(),
        'language': language.code,
        'lang': language.locale,
        'limit': 5,
        'fields':
            'key,title,subtitle,author_name,first_publish_year,edition_count,'
            'cover_i,editions,editions.key,editions.title,editions.subtitle,editions.cover_i',
      },
      cancelToken: cancelToken,
    );
    return _books(response.data, 'docs', matchEdition: true);
  }

  @override
  Future<List<Book>> popular(CancelToken cancelToken) async {
    final response = await _dio.get(
      'https://openlibrary.org/trending/weekly.json',
      queryParameters: {'limit': 12},
      cancelToken: cancelToken,
    );
    return _books(response.data, 'works');
  }

  @override
  Future<List<Book>> recommendations(
    BookTopic topic,
    CancelToken cancelToken,
  ) async {
    final response = await _dio.get(
      'https://openlibrary.org/search.json',
      queryParameters: {
        'q': 'language:tur AND subject:${topic.subject} AND cover_i:[1 TO *]',
        'lang': 'tr',
        'sort': 'readinglog',
        'limit': 24,
        'fields':
            'key,title,subtitle,author_name,first_publish_year,edition_count,'
            'cover_i,editions,editions.key,editions.title,editions.subtitle,editions.cover_i',
      },
      cancelToken: cancelToken,
    );
    return _books(response.data, 'docs');
  }

  // Both feeds return works with an optional best-matching edition. Keep the
  // work ID for archive deduplication, but display that edition's title/cover.
  List<Book> _books(Object? data, String field, {bool matchEdition = false}) {
    if (data is! Map || data[field] is! List) {
      throw const FormatException('Kitap rafı yanıtı okunamadı');
    }
    final docs = data[field] as List;
    final result = <Book>[];
    final seen = <String>{};
    for (final value in docs) {
      if (value is! Map) continue;
      final editions = value['editions'];
      final editionDocs = editions is Map ? editions['docs'] : null;
      final edition =
          editionDocs is List &&
              editionDocs.isNotEmpty &&
              editionDocs.first is Map
          ? editionDocs.first as Map
          : null;
      String? text(Object? value) =>
          value is String && value.trim().isNotEmpty ? value.trim() : null;
      final title = text(edition?['title']) ?? text(value['title']);
      if (title == null) continue;
      final rawKey = text(value['key']);
      final workId = rawKey == null
          ? null
          : RegExp(r'^(?:/works/)?(OL\d+W)$').firstMatch(rawKey)?.group(1);
      final authors = value['author_name'];
      final cover = edition?['cover_i'];
      final book = Book.fromJson({
        'key': workId == null ? null : '/works/$workId',
        'title': title,
        'subtitle': text(edition?['subtitle']) ?? text(value['subtitle']),
        'author_name': authors is List
            ? authors
                  .whereType<String>()
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList()
            : <String>[],
        'cover_i': cover is int && cover > 0 ? cover : value['cover_i'],
        'first_publish_year': value['first_publish_year'] is int
            ? value['first_publish_year']
            : null,
        'edition_count': value['edition_count'] is int
            ? value['edition_count']
            : null,
        'editions': editions,
      }, preferMatchedEdition: matchEdition);
      if (seen.add(JournalEntry.bookId(book))) result.add(book);
    }
    if (docs.isNotEmpty && result.isEmpty) {
      throw const FormatException('Kitap rafı yanıtı eksik');
    }
    return result;
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
}
