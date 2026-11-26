import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book_discovery.dart';
import 'package:iz/book_language.dart';

void main() {
  late Dio dio;
  late OpenLibraryDiscovery source;
  late List<RequestOptions> requests;
  Object? payload;

  setUp(() {
    requests = [];
    dio = Dio();
    source = OpenLibraryDiscovery(dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(Response(requestOptions: request, data: payload));
        },
      ),
    );
  });
  tearDown(() => dio.close(force: true));

  test(
    'Title search restricts language and uses the matching edition cover',
    () async {
      for (final language in BookLanguage.values) {
        payload = {
          'docs': [
            {
              'key': '/works/OL1W',
              'title': 'Original title',
              'cover_i': 1,
              'editions': {
                'docs': [
                  {
                    'key': '/books/OL2M',
                    'title': '${language.label} baskı',
                    'cover_i': 2,
                  },
                ],
              },
            },
          ],
        };
        final books = await source.searchTitle(
          ' Dune ',
          CancelToken(),
          language: language,
        );
        expect(requests.last.queryParameters['title'], 'Dune');
        expect(requests.last.queryParameters['language'], language.code);
        expect(requests.last.queryParameters['lang'], language.locale);
        expect(books.single.title, '${language.label} baskı');
        expect(books.single.coverId, 2);
        expect(books.single.editionKey, '/books/OL2M');
      }
    },
  );

  test(
    'Weekly popularity uses work IDs and removes duplicate records',
    () async {
      payload = {
        'docs': [
          {
            'key': 'OL1W',
            'title': 'First',
            'author_name': [' Author ', 'Author', 5],
          },
          {'key': '/works/OL1W', 'title': 'Another edition'},
          null,
          {'key': '/works/OL2W', 'title': 'Second', 'cover_i': 'invalid'},
        ],
      };
      final books = await source.popular(CancelToken());
      expect(requests.single.path, 'https://openlibrary.org/search.json');
      expect(requests.single.queryParameters['limit'], 24);
      expect(requests.single.queryParameters['offset'], 0);
      expect(requests.single.queryParameters['q'], contains('language:tur'));
      expect(books.map((book) => book.title), ['First', 'Second']);
      expect(books.first.workKey, '/works/OL1W');
      expect(books.first.authors, ['Author']);
      expect(books.last.coverUrl, isNull);
    },
  );

  test(
    'Recommendations request Turkish editions and preserve edition details',
    () async {
      payload = {
        'docs': [
          {
            'key': '/works/OL3W',
            'title': 'English title',
            'cover_i': 10,
            'first_publish_year': 1950,
            'editions': {
              'docs': [
                {
                  'key': '/books/OL4M',
                  'title': ' Türkçe başlık ',
                  'subtitle': ' Alt başlık ',
                  'cover_i': 20,
                },
              ],
            },
          },
        ],
      };
      final books = await source.recommendations(
        BookTopic.scienceFiction,
        CancelToken(),
      );
      final query = requests.single.queryParameters;
      expect(requests.single.path, 'https://openlibrary.org/search.json');
      expect(query['q'], contains('language:tur'));
      expect(query['q'], contains('subject:science_fiction'));
      expect(query['lang'], 'tr');
      expect(query['sort'], 'readinglog');
      expect(books.single.title, 'Türkçe başlık');
      expect(books.single.subtitle, 'Alt başlık');
      expect(books.single.coverId, 20);
      expect(books.single.firstPublishYear, 1950);
      expect(books.single.workKey, '/works/OL3W');
      expect(
        books.single.editionUrl,
        'https://openlibrary.org/books/OL4M.json',
      );
    },
  );

  test(
    'Malformed feeds report errors while an empty feed stays valid',
    () async {
      for (final invalid in [
        null,
        '<html>offline</html>',
        {'docs': {}},
        {
          'docs': [
            null,
            {'title': ' '},
          ],
        },
      ]) {
        payload = invalid;
        await expectLater(source.popular(CancelToken()), throwsFormatException);
      }
      payload = {'docs': []};
      expect(await source.popular(CancelToken()), isEmpty);
    },
  );

  test('A cancelled request never reaches the service', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      source.popular(token),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(requests, isEmpty);
  });
}
