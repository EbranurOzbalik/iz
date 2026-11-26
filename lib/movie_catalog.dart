import 'package:dio/dio.dart';

import 'movie.dart';

abstract interface class MovieCatalog {
  bool get isConfigured;
  Future<List<Movie>> featured(
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
    int offset = 0,
  });
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  });
  Future<Movie> details(
    int id,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  });
}

class IzMovieCatalog implements MovieCatalog {
  IzMovieCatalog({
    Dio? dio,
    String baseUrl = const String.fromEnvironment('IZ_MOVIE_API_URL'),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
             ),
           ),
       _ownsDio = dio == null,
       _baseUri = _validBaseUri(baseUrl);

  final Dio _dio;
  final bool _ownsDio;
  final Uri? _baseUri;

  static Uri? _validBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || uri.query.isNotEmpty) return null;
    final local = {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
    if (uri.scheme != 'https' && !(local && uri.scheme == 'http')) return null;
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), ''));
  }

  @override
  bool get isConfigured => _baseUri != null;

  Future<Response<dynamic>> _get(
    String path,
    Map<String, dynamic> query,
    CancelToken token,
  ) {
    if (_baseUri == null) {
      throw StateError('İZ kültür kataloğu yapılandırılmadı');
    }
    return _dio.getUri(
      _baseUri.replace(path: '${_baseUri.path}$path', queryParameters: query),
      options: Options(
        headers: {'Accept': 'application/json'},
        followRedirects: false,
      ),
      cancelToken: token,
    );
  }

  @override
  Future<List<Movie>> featured(
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
    int offset = 0,
  }) async {
    final response = await _get('/v1/${kind.path}/featured', {
      'lang': locale == MovieLocale.english ? 'en' : 'tr',
      'offset': offset,
    }, token);
    return _parseResults(response.data);
  }

  List<Movie> _parseResults(dynamic data) {
    if (data is! Map || data['results'] is! List) {
      throw const FormatException('Katalog yanıtı okunamadı');
    }
    final movies = <Movie>[];
    final seen = <int>{};
    for (final row in data['results'] as List) {
      if (row is! Map<String, dynamic>) continue;
      try {
        final movie = Movie.fromIzApi(row);
        if (seen.add(movie.id)) movies.add(movie);
      } on FormatException {
        continue;
      }
    }
    return movies;
  }

  @override
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    if (query.trim().length < 2) return [];
    final response = await _get('/v1/${kind.path}/search', {
      'q': query.trim(),
      'lang': locale == MovieLocale.english ? 'en' : 'tr',
    }, token);
    return _parseResults(response.data);
  }

  @override
  Future<Movie> details(
    int id,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    if (id <= 0) throw const FormatException('Geçersiz film');
    final response = await _get('/v1/${kind.path}/$id', {
      'lang': locale == MovieLocale.english ? 'en' : 'tr',
    }, token);
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Film bilgisi okunamadı');
    }
    final movie = Movie.fromIzApi(response.data, detailsLoaded: true);
    if (movie.id != id) throw const FormatException('Film bilgisi eşleşmedi');
    return movie;
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
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
  Future<List<Movie>> featured(
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
    int offset = 0,
  }) async => [];

  @override
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    if (kind != CatalogKind.film) return [];
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
  Future<Movie> details(
    int id,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    if (kind != CatalogKind.film) {
      throw const FormatException('Bu katalog türü desteklenmiyor');
    }
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
