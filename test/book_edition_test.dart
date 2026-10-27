import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book_edition.dart';

void main() {
  test('Edition details keep page count and unique nonblank publishers', () {
    final edition = BookEdition.fromJson({
      'number_of_pages': 424,
      'publishers': [
        ' Pegasus Yayınları ',
        '',
        null,
        42,
        'Pegasus Yayınları',
        'Diğer yayınevi',
      ],
    });
    expect(edition.pageCount, 424);
    expect(edition.publishers, ['Pegasus Yayınları', 'Diğer yayınevi']);
  });

  test('Missing or malformed edition data remains optional', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'number_of_pages': 0, 'publishers': null},
      {'number_of_pages': -1, 'publishers': 42},
      {
        'number_of_pages': 'unknown',
        'publishers': [' ', null],
      },
    ]) {
      final edition = BookEdition.fromJson(data);
      expect(edition.pageCount, isNull);
      expect(edition.publishers, isEmpty);
      expect(edition.isbn, isNull);
    }
  });

  test(
    'ISBN-13 is preferred and normalized after invalid entries are skipped',
    () {
      final edition = BookEdition.fromJson({
        'isbn_13': [
          null,
          9786052997420,
          '',
          '9786052997421',
          ' 978-605-299-742-0 ',
        ],
        'isbn_10': ['6052997427'],
      });
      expect(edition.isbn, '9786052997420');
    },
  );

  test(
    'ISBN-10 fallback preserves leading zero and normalizes its X check digit',
    () {
      final edition = BookEdition.fromJson({
        'isbn_13': ['9786052997421'],
        'isbn_10': ['6052997420', ' 0-8044-2957-x '],
      });
      expect(edition.isbn, '080442957X');
      expect(
        BookEdition.fromJson({
          'isbn_10': ['6052997427'],
        }).isbn,
        '6052997427',
      );
    },
  );

  test('Missing, malformed and incorrect ISBN check digits are ignored', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'isbn_13': '9786052997420', 'isbn_10': 6052997427},
      {
        'isbn_13': [null, true, ''],
        'isbn_10': [],
      },
      {
        'isbn_13': [
          '9786052997421',
          '978605299742X',
          '978605299742',
          '1234567890128',
        ],
        'isbn_10': ['6052997420', 'X80442957X', '080442957', '080442957XX'],
      },
    ]) {
      expect(BookEdition.fromJson(data).isbn, isNull);
    }
  });
}
