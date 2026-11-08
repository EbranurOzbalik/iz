import 'package:dio/dio.dart';

import 'movie.dart';

abstract interface class MovieCatalog {
  bool get isConfigured;
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token,
  );
  Future<Movie> details(int id, MovieLocale locale, CancelToken token);
}

class TmdbMovieCatalog implements MovieCatalog {
  TmdbMovieCatalog({
    Dio? dio,
    String token = const String.fromEnvironment('TMDB_READ_ACCESS_TOKEN'),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
             ),
           ),
       _ownsDio = dio == null,
       _token = token.trim();

  final Dio _dio;
  final bool _ownsDio;
  final String _token;
  @override
  bool get isConfigured => _token.isNotEmpty;

  Future<Response<dynamic>> _get(
    String path,
    Map<String, dynamic> query,
    CancelToken token,
  ) {
    if (!isConfigured) throw StateError('Film kataloğu yapılandırılmadı');
    return _dio.get(
      'https://api.themoviedb.org/3$path',
      queryParameters: query,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        followRedirects: false,
      ),
      cancelToken: token,
    );
  }

  @override
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token,
  ) async {
    if (query.trim().length < 2) return [];
    final response = await _get('/search/movie', {
      'query': query.trim(),
      'language': locale.code,
      'include_adult': false,
      'page': 1,
    }, token);
    final data = response.data;
    if (data is! Map || data['results'] is! List) {
      throw const FormatException('Film yanıtı okunamadı');
    }
    final rows = data['results'] as List;
    final movies = <Movie>[];
    final seen = <int>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic> || row['adult'] == true) continue;
      try {
        final movie = Movie.fromApi(row);
        if (seen.add(movie.id)) movies.add(movie);
      } on FormatException {
        continue;
      }
    }
    return movies;
  }

  @override
  Future<Movie> details(int id, MovieLocale locale, CancelToken token) async {
    if (id <= 0) throw const FormatException('Geçersiz film');
    final response = await _get('/movie/$id', {
      'language': locale.code,
      'append_to_response': 'credits',
    }, token);
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Film bilgisi okunamadı');
    }
    final movie = Movie.fromApi(response.data, detailsLoaded: true);
    if (movie.id != id) throw const FormatException('Film bilgisi eşleşmedi');
    return movie;
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
}

String movieErrorMessage(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return 'Film kataloğuna erişilemiyor. Daha sonra tekrar deneyebilirsin.';
    }
    if (error.response?.statusCode == 429) {
      return 'Film servisi yoğun. Biraz sonra tekrar dene.';
    }
  }
  return 'Film bilgileri yüklenemedi. Bağlantını kontrol edip tekrar deneyebilirsin.';
}
