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
    }
  });
}
