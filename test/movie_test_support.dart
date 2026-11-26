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
  final searches =
      <
        ({
          String query,
          MovieLocale locale,
          CancelToken token,
          CatalogKind kind,
        })
      >[];
  final detailRequests = <CancelToken>[];
  final detailKinds = <CatalogKind>[];
  Future<List<Movie>> Function(String, MovieLocale, CancelToken)? onSearch;
  Future<Movie> Function(int, MovieLocale, CancelToken)? onDetails;
  Future<List<Movie>> Function(MovieLocale, CancelToken, CatalogKind)?
  onFeatured;
  final featuredKinds = <CatalogKind>[];
  final featuredOffsets = <int>[];
  @override
  Future<List<Movie>> featured(
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
    int offset = 0,
  }) async {
    featuredKinds.add(kind);
    featuredOffsets.add(offset);
    return onFeatured == null
        ? [testMovie]
        : await onFeatured!(locale, token, kind);
  }

  @override
  Future<List<Movie>> search(
    String query,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    searches.add((query: query, locale: locale, token: token, kind: kind));
    return onSearch == null
        ? [testMovie]
        : await onSearch!(query, locale, token);
  }

  @override
  Future<Movie> details(
    int id,
    MovieLocale locale,
    CancelToken token, {
    CatalogKind kind = CatalogKind.film,
  }) async {
    detailRequests.add(token);
    detailKinds.add(kind);
    return onDetails == null
        ? detailedTestMovie
        : await onDetails!(id, locale, token);
  }
}
