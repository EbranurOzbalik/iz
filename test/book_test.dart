import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';

void main() {
  test('Search data includes metadata and a usable cover URL', () {
    final book = Book.fromJson({
      'title': 'Dune',
      'author_name': ['Frank Herbert'],
      'first_publish_year': 1965,
      'edition_count': 120,
      'cover_i': 258027,
    });

    expect(book.title, 'Dune');
    expect(book.authors, ['Frank Herbert']);
    expect(book.firstPublishYear, 1965);
    expect(book.editionCount, 120);
    expect(
      book.coverUrl,
      'https://covers.openlibrary.org/b/id/258027-M.jpg?default=false',
    );
  });

  test(
    'Missing or invalid cover IDs leave the book usable without a cover',
    () {
      for (final coverId in [null, -1, 0, 'invalid']) {
        final book = Book.fromJson({
          'title': 'Kapaksız kitap',
          'cover_i': coverId,
        });
        expect(book.title, 'Kapaksız kitap');
        expect(book.authors, isEmpty);
        expect(book.coverUrl, isNull);
      }
    },
  );
}
