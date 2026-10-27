class BookEdition {
  const BookEdition({this.pageCount, this.publishers = const [], this.isbn});

  final int? pageCount;
  final List<String> publishers;
  final String? isbn;

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
      isbn: _readIsbn(json['isbn_13'], 13) ?? _readIsbn(json['isbn_10'], 10),
    );
  }

  static String? _readIsbn(Object? values, int length) {
    if (values is! List) return null;
    final pattern = length == 13
        ? RegExp(r'^97[89][0-9]{10}$')
        : RegExp(r'^[0-9]{9}[0-9X]$');
    for (final value in values.whereType<String>()) {
      final isbn = value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
      if (!pattern.hasMatch(isbn)) continue;

      // ISBN-13 and ISBN-10 use different check digit weights.
      var sum = 0;
      for (var i = 0; i < length; i++) {
        final digit = isbn[i] == 'X' ? 10 : int.parse(isbn[i]);
        final weight = length == 13 ? (i.isEven ? 1 : 3) : 10 - i;
        sum += digit * weight;
      }
      if (sum % (length == 13 ? 10 : 11) == 0) return isbn;
    }
    return null;
  }
}
