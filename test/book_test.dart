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

  test('Subtitle is read from the matching edition and trimmed', () {
    final book = Book.fromJson({
      'title': 'Akıl',
      'editions': {
        'docs': [
          {'title': 'Akıl', 'subtitle': '  İnsan Olmanın Özüne Yolculuk  '},
        ],
      },
    });

    expect(book.title, 'Akıl');
    expect(book.subtitle, 'İnsan Olmanın Özüne Yolculuk');
  });

  test('Work subtitle takes priority with blank values falling back', () {
    for (final subtitle in ['  Ana alt başlık  ', '   ']) {
      final book = Book.fromJson({
        'title': 'Kitap',
        'subtitle': subtitle,
        'editions': {
          'docs': [
            {'subtitle': 'Baskı alt başlığı'},
          ],
        },
      });
      expect(
        book.subtitle,
        subtitle.trim().isEmpty ? 'Baskı alt başlığı' : 'Ana alt başlık',
      );
    }
  });

  test('Missing and malformed subtitle data can be omitted safely', () {
    for (final fields in <Map<String, dynamic>>[
      {},
      {'subtitle': '   '},
      {'subtitle': 123},
      {'editions': 'invalid'},
      {
        'editions': {'docs': []},
      },
      {
        'editions': {'docs': 'invalid'},
      },
      {
        'editions': {
          'docs': [null],
        },
      },
      {
        'editions': {
          'docs': [
            {'subtitle': 123},
          ],
        },
      },
    ]) {
      final book = Book.fromJson({'title': 'Kitap', ...fields});
      expect(book.subtitle, isNull);
    }
  });
}
