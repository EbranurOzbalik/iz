class Book {
  String title;
  List<String> authors;
  int? firstPublishYear;
  int? editionCount;
  final int? coverId;
  final String? subtitle;
  final String? editionKey;
  final String? workKey;

  Book({
    required this.title,
    required this.authors,
    this.firstPublishYear,
    this.editionCount,
    this.coverId,
    this.subtitle,
    this.editionKey,
    this.workKey,
  });

  factory Book.fromJson(
    Map<String, dynamic> json, {
    bool preferMatchedEdition = false,
  }) {
    final editions = json['editions'];
    final editionDocs = editions is Map ? editions['docs'] : null;
    final matchedEdition = editionDocs is List && editionDocs.isNotEmpty
        ? editionDocs.first
        : null;
    final displayEdition = preferMatchedEdition && matchedEdition is Map
        ? matchedEdition
        : null;
    final editionTitle = _readSubtitle(displayEdition?['title']);
    final cover = displayEdition == null
        ? json['cover_i']
        : displayEdition['cover_i'];

    return Book(
      title: editionTitle ?? json['title'],
      workKey: json['key'] is String ? json['key'] as String : null,
      authors: List<String>.from(json['author_name'] ?? []),
      firstPublishYear: json['first_publish_year'],
      editionCount: json['edition_count'],
      coverId: cover is int ? cover : null,
      editionKey: matchedEdition is Map && matchedEdition['key'] is String
          ? matchedEdition['key'] as String
          : null,
      subtitle:
          _readSubtitle(displayEdition?['subtitle']) ??
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
