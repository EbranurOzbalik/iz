import 'package:dio/dio.dart';
import 'package:iz/movie.dart';
import 'package:iz/movie_catalog.dart';

const testMovie = Movie(
  id: 157336,
  title: 'Yıldızlararası',
  originalTitle: 'Interstellar',
  year: 2014,
);
const detailedTestMovie = Movie(
  id: 157336,
  title: 'Yıldızlararası',
  originalTitle: 'Interstellar',
  year: 2014,
  runtime: 169,
  directors: ['Christopher Nolan'],
  genres: ['Bilim Kurgu'],
  overview: 'Bir uzay yolculuğu.',
  detailsLoaded: true,
);

class FakeMovieCatalog implements MovieCatalog {
  @override
  bool isConfigured = true;
  final searches = <({String query, MovieLocale locale, CancelToken token})>[];
  final detailRequests = <CancelToken>[];
  Future<List<Movie>> Function(String, MovieLocale, CancelToken)? onSearch;
  Future<Movie> Function(int, MovieLocale, CancelToken)? onDetails;
  @override
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token,
  ) async {
    searches.add((query: query, locale: locale, token: token));
    return onSearch == null
        ? [testMovie]
        : await onSearch!(query, locale, token);
  }

  @override
  Future<Movie> details(int id, MovieLocale locale, CancelToken token) async {
    detailRequests.add(token);
    return onDetails == null
        ? detailedTestMovie
        : await onDetails!(id, locale, token);
  }
}
