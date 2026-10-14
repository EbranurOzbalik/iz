class Book {
  String title;
  List<String> authors;
  int? firstPublishYear;
  int? editionCount;
  final int? coverId;

  Book({
    required this.title,
    required this.authors,
    this.firstPublishYear,
    this.editionCount,
    this.coverId,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'],
      authors: List<String>.from(json['author_name'] ?? []),
      firstPublishYear: json['first_publish_year'],
      editionCount: json['edition_count'],
      coverId: json['cover_i'] is int ? json['cover_i'] as int : null,
    );
  }

  String? get coverUrl {
    if (coverId == null || coverId! <= 0) return null;
    return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg?default=false';
  }
}
