class BookEdition {
  const BookEdition({this.pageCount, this.publishers = const []});

  final int? pageCount;
  final List<String> publishers;

  factory BookEdition.fromJson(Map<String, dynamic> json) {
    final count = json['number_of_pages'];
    final publishers = json['publishers'];
    return BookEdition(
      pageCount: count is int && count > 0 ? count : null,
      publishers: publishers is List
          ? publishers
                .whereType<String>()
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList(growable: false)
          : const [],
    );
  }
}
