enum MovieLocale {
  turkish('Türkçe', 'tr-TR'),
  english('İngilizce', 'en-US');

  const MovieLocale(this.label, this.code);
  final String label, code;
}

class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.overview = '',
    this.posterPath,
    this.year,
    this.runtime,
    this.directors = const [],
    this.genres = const [],
    this.detailsLoaded = false,
  });

  final int id;
  final String title, originalTitle, overview;
  final String? posterPath;
  final int? year, runtime;
  final List<String> directors, genres;
  final bool detailsLoaded;

  String? get posterUrl =>
      posterPath != null &&
          RegExp(r'^/[A-Za-z0-9_-]+\.(jpg|png|webp)$').hasMatch(posterPath!)
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;
  String get summary => [
    if (year != null) '$year',
    if (runtime != null) '$runtime dk',
  ].join(' · ');

  static String _text(Object? value) => value is String ? value.trim() : '';
  static List<String> _names(Object? values) => values is List
      ? values
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
      : [];

  factory Movie.fromApi(
    Map<String, dynamic> data, {
    bool detailsLoaded = false,
  }) {
    final id = data['id'];
    final title = _text(data['title']);
    if (id is! int || id <= 0 || title.isEmpty) {
      throw const FormatException('Geçersiz film kaydı');
    }
    final credits = data['credits'];
    final crew = credits is Map ? credits['crew'] : null;
    final genres = data['genres'];
    final runtime = data['runtime'];
    final date = DateTime.tryParse(_text(data['release_date']));
    return Movie(
      id: id,
      title: title,
      originalTitle: _text(data['original_title']),
      overview: _text(data['overview']),
      posterPath: data['poster_path'] is String ? data['poster_path'] : null,
      year: date?.year,
      runtime: runtime is int && runtime > 0 ? runtime : null,
      directors: crew is List
          ? _names(
              crew
                  .whereType<Map>()
                  .where((person) => person['job'] == 'Director')
                  .map((person) => person['name'])
                  .toList(),
            )
          : [],
      genres: genres is List
          ? _names(
              genres.whereType<Map>().map((genre) => genre['name']).toList(),
            )
          : [],
      detailsLoaded: detailsLoaded,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'originalTitle': originalTitle,
    'overview': overview,
    'posterPath': posterPath,
    'year': year,
    'runtime': runtime,
    'directors': directors,
    'genres': genres,
    'detailsLoaded': detailsLoaded,
  };

  factory Movie.fromJson(Map<String, dynamic> data) {
    final movie = Movie(
      id: data['id'] as int,
      title: data['title'] as String,
      originalTitle: data['originalTitle'] as String? ?? '',
      overview: data['overview'] as String? ?? '',
      posterPath: data['posterPath'] as String?,
      year: data['year'] as int?,
      runtime: data['runtime'] as int?,
      directors: _names(data['directors']),
      genres: _names(data['genres']),
      detailsLoaded: data['detailsLoaded'] == true,
    );
    if (movie.id <= 0 ||
        movie.title.trim().isEmpty ||
        (movie.runtime != null && movie.runtime! <= 0)) {
      throw const FormatException('Geçersiz film kaydı');
    }
    return movie;
  }
}
