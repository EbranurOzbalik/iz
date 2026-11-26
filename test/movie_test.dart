import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/movie.dart';
import 'package:iz/movie_catalog.dart';

Map<String, dynamic> filmData({
  int id = 157336,
  String title = 'Yıldızlararası',
}) => {
  'id': id,
  'title': title,
  'original_title': 'Interstellar',
  'overview': 'Bir uzay yolculuğu.',
  'poster_path': '/poster.jpg',
  'release_date': '2014-11-07',
  'runtime': 169,
  'genres': [
    {'name': 'Bilim Kurgu'},
  ],
  'credits': {
    'crew': [
      {'job': 'Director', 'name': ' Christopher Nolan '},
      {'job': 'Director', 'name': 'Christopher Nolan'},
      {'job': 'Writer', 'name': 'Başka kişi'},
    ],
  },
};

void main() {
  test('Movie parsing retains poster, release year and only directors', () {
    final movie = Movie.fromApi(filmData(), detailsLoaded: true);
    expect(movie.id, 157336);
    expect(movie.title, 'Yıldızlararası');
    expect(movie.originalTitle, 'Interstellar');
    expect(movie.year, 2014);
    expect(movie.runtime, 169);
    expect(movie.directors, ['Christopher Nolan']);
    expect(movie.genres, ['Bilim Kurgu']);
    expect(movie.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(movie.detailsLoaded, isTrue);
    final restored = Movie.fromJson(movie.toJson());
    expect(restored.toJson(), movie.toJson());
  });

  test('Incomplete metadata has safe fallbacks and rejects invalid IDs', () {
    final movie = Movie.fromApi({
      'id': 1,
      'title': 'Film',
      'release_date': '',
      'runtime': 0,
    });
    expect(movie.year, isNull);
    expect(movie.runtime, isNull);
    expect(movie.directors, isEmpty);
    for (final poster in [
      null,
      '../secret',
      'https://example.com/poster.jpg',
      '/a.jpg?x=1',
    ]) {
      expect(Movie(id: 1, title: 'Film', posterPath: poster).posterUrl, isNull);
    }
    for (final data in [
      {'id': 0, 'title': 'Film'},
      {'id': 1, 'title': ' '},
      {'title': 'Film'},
    ]) {
      expect(() => Movie.fromApi(data), throwsFormatException);
    }
  });

  test('Biletsa theatre posters are accepted without trusting other hosts', () {
    const poster = 'https://biletsa.com/api/dosya/oyun.jpg';
    expect(
      const Movie(id: 980000001, title: 'Oyun', posterPath: poster).posterUrl,
      poster,
    );
    expect(
      const Movie(
        id: 980000001,
        title: 'Oyun',
        posterPath: 'https://example.com/oyun.jpg',
      ).posterUrl,
      isNull,
    );
  });

  group('İZ Katalog API requests', () {
    late Dio dio;
    late IzMovieCatalog catalog;
    late List<RequestOptions> requests;
    Object? payload;

    setUp(() {
      requests = [];
      dio = Dio();
      catalog = IzMovieCatalog(dio: dio, baseUrl: 'https://api.iz.example/');
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
      'search uses only the İZ endpoint and parses open-data sources',
      () async {
        payload = {
          'results': [
            {
              'id': 42,
              'title': 'Örnek Film',
              'original_title': 'Example Film',
              'overview': 'Açıklama',
              'poster_url':
                  'https://commons.wikimedia.org/wiki/Special:Redirect/file/Poster.jpg?width=500',
              'poster_attribution_url':
                  'https://commons.wikimedia.org/wiki/File:Poster.jpg',
              'source_url': 'https://www.wikidata.org/wiki/Q42',
              'year': 2024,
              'runtime': 123,
              'directors': ['Yönetmen'],
              'genres': ['Drama'],
            },
          ],
        };
        final movies = await catalog.search(
          ' Örnek ',
          MovieLocale.turkish,
          CancelToken(),
        );
        expect(movies, hasLength(1));
        expect(
          movies.single.posterUrl,
          startsWith('https://commons.wikimedia.org/'),
        );
        expect(movies.single.sourceUrl, 'https://www.wikidata.org/wiki/Q42');
        expect(requests.single.uri.host, 'api.iz.example');
        expect(requests.single.uri.path, '/v1/movies/search');
        expect(requests.single.uri.queryParameters, {
          'q': 'Örnek',
          'lang': 'tr',
        });
      },
    );

    test(
      'details and URL validation keep traffic on the configured API',
      () async {
        payload = {'id': 42, 'title': 'Film'};
        final movie = await catalog.details(
          42,
          MovieLocale.english,
          CancelToken(),
        );
        expect(movie.detailsLoaded, isTrue);
        expect(requests.single.uri.path, '/v1/movies/42');
        expect(requests.single.uri.queryParameters, {'lang': 'en'});
        expect(
          IzMovieCatalog(dio: dio, baseUrl: 'http://example.com').isConfigured,
          isFalse,
        );
        expect(
          IzMovieCatalog(
            dio: dio,
            baseUrl: 'http://10.0.2.2:8787',
          ).isConfigured,
          isTrue,
        );
      },
    );
  });

  group('TMDB requests', () {
    late Dio dio;
    late TmdbMovieCatalog catalog;
    late List<RequestOptions> requests;
    Object? payload;
    setUp(() {
      requests = [];
      dio = Dio();
      catalog = TmdbMovieCatalog(dio: dio, token: 'test-only-token');
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
      'Search sends movie-only queries and locale, filters invalid and duplicate items',
      () async {
        payload = {
          'results': [
            filmData(),
            filmData(),
            null,
            {'id': 0, 'title': 'Invalid'},
            {...filmData(id: 8), 'adult': true},
          ],
        };
        final results = await catalog.search(
          ' Interstellar ',
          MovieLocale.english,
          CancelToken(),
        );
        expect(results, hasLength(1));
        expect(
          requests.single.path,
          'https://api.themoviedb.org/3/search/movie',
        );
        expect(requests.single.queryParameters, {
          'query': 'Interstellar',
          'language': 'en-US',
          'include_adult': false,
          'page': 1,
        });
        expect(
          requests.single.headers['Authorization'],
          'Bearer test-only-token',
        );
        expect(requests.single.queryParameters.containsKey('api_key'), isFalse);
        expect(requests.single.followRedirects, isFalse);
      },
    );

    test(
      'Details fetch credits together and reject a mismatched movie',
      () async {
        payload = filmData();
        final movie = await catalog.details(
          157336,
          MovieLocale.turkish,
          CancelToken(),
        );
        expect(
          requests.single.path,
          'https://api.themoviedb.org/3/movie/157336',
        );
        expect(
          requests.single.queryParameters['append_to_response'],
          'credits',
        );
        expect(requests.single.queryParameters['language'], 'tr-TR');
        expect(movie.directors, ['Christopher Nolan']);
        expect(movie.detailsLoaded, isTrue);
        payload = filmData(id: 2);
        await expectLater(
          catalog.details(157336, MovieLocale.turkish, CancelToken()),
          throwsFormatException,
        );
      },
    );

    test('Missing configuration and short queries make no request', () async {
      final unavailable = TmdbMovieCatalog(dio: dio, token: '');
      expect(unavailable.isConfigured, isFalse);
      await expectLater(
        unavailable.search('Film', MovieLocale.turkish, CancelToken()),
        throwsStateError,
      );
      expect(
        await catalog.search('F', MovieLocale.turkish, CancelToken()),
        isEmpty,
      );
      expect(requests, isEmpty);
    });

    test(
      'Malformed service data is not treated as an empty successful search',
      () async {
        payload = '<html>Error</html>';
        await expectLater(
          catalog.search('Film', MovieLocale.turkish, CancelToken()),
          throwsFormatException,
        );
        payload = {'results': []};
        expect(
          await catalog.search('Film', MovieLocale.turkish, CancelToken()),
          isEmpty,
        );
      },
    );
  });
}
