class Book {
  String title;
  List<String> authors;
  int? firstPublishYear;
  int? editionCount;
  final int? coverId;
  final String? subtitle;
  final String? editionKey;

  Book({
    required this.title,
    required this.authors,
    this.firstPublishYear,
    this.editionCount,
    this.coverId,
    this.subtitle,
    this.editionKey,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final editions = json['editions'];
    final editionDocs = editions is Map ? editions['docs'] : null;
    final matchedEdition = editionDocs is List && editionDocs.isNotEmpty
        ? editionDocs.first
        : null;

    return Book(
      title: json['title'],
      authors: List<String>.from(json['author_name'] ?? []),
      firstPublishYear: json['first_publish_year'],
      editionCount: json['edition_count'],
      coverId: json['cover_i'] is int ? json['cover_i'] as int : null,
      editionKey: matchedEdition is Map && matchedEdition['key'] is String
          ? matchedEdition['key'] as String
          : null,
      subtitle:
          _readSubtitle(json['subtitle']) ??
          (matchedEdition is Map
              ? _readSubtitle(matchedEdition['subtitle'])
              : null),
    );
  }

  static String? _readSubtitle(Object? value) {
    if (value is! String) return null;
    final subtitle = value.trim();
    return subtitle.isEmpty ? null : subtitle;
  }

  String? get coverUrl {
    if (coverId == null || coverId! <= 0) return null;
    return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg?default=false';
  }

  String? get editionUrl {
    final key = editionKey;
    if (key == null || !RegExp(r'^/books/OL[0-9]+M$').hasMatch(key)) {
      return null;
    }
    return 'https://openlibrary.org$key.json';
  }
}
