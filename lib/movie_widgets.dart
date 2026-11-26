import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'movie.dart';
import 'movie_catalog.dart';
import 'movie_poster.dart';
import 'tmdb_attribution.dart';

class MovieLanguageSelector extends StatelessWidget {
  const MovieLanguageSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.catalogLabel = 'Film',
  });
  final MovieLocale value;
  final ValueChanged<MovieLocale>? onChanged;
  final String catalogLabel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$catalogLabel bilgilerinin dili',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final locale in MovieLocale.values)
            ChoiceChip(
              label: Text(locale.label),
              selected: locale == value,
              onSelected: onChanged == null ? null : (_) => onChanged!(locale),
            ),
        ],
      ),
    ],
  );
}

class MovieSuggestions extends StatefulWidget {
  const MovieSuggestions({
    super.key,
    required this.query,
    required this.locale,
    required this.catalog,
    required this.onSelected,
    this.kind = CatalogKind.film,
  });
  final String query;
  final MovieLocale locale;
  final MovieCatalog catalog;
  final ValueChanged<Movie> onSelected;
  final CatalogKind kind;
  String get kindLabel => switch (kind) {
    CatalogKind.film => 'film',
    CatalogKind.series => 'dizi',
    CatalogKind.theatre => 'tiyatro eseri',
  };
  @override
  State<MovieSuggestions> createState() => _MovieSuggestionsState();
}

class _MovieSuggestionsState extends State<MovieSuggestions> {
  String get kindLabel => widget.kindLabel;
  Timer? timer;
  CancelToken? token;
  List<Movie> movies = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(MovieSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim() != widget.query.trim() ||
        oldWidget.locale != widget.locale ||
        oldWidget.kind != widget.kind ||
        oldWidget.catalog != widget.catalog) {
      schedule();
    }
  }

  void schedule() {
    timer?.cancel();
    token?.cancel();
    movies = [];
    error = null;
    loading = widget.catalog.isConfigured && widget.query.trim().length >= 2;
    if (loading) timer = Timer(const Duration(milliseconds: 500), search);
  }

  Future<void> search() async {
    timer?.cancel();
    token?.cancel();
    final request = CancelToken();
    token = request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.catalog.search(
        widget.query,
        widget.locale,
        request,
        kind: widget.kind,
      );
      if (!mounted || request.isCancelled) return;
      setState(() => movies = result);
    } catch (failure) {
      if (!mounted || request.isCancelled) return;
      setState(() => error = movieErrorMessage(failure));
    } finally {
      if (mounted && !request.isCancelled) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    token?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.catalog.isConfigured) {
      return Text(
        '${kindLabel[0].toUpperCase()}${kindLabel.substring(1)} adını ve '
        'istersen yaratıcı bilgisini yazarak arşivine ekleyebilirsin.',
      );
    }
    if (widget.query.trim().length < 2) {
      return Text('$kindLabel bulmak için en az 2 harf yaz.');
    }
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 8),
          Text(
            '${kindLabel[0].toUpperCase()}${kindLabel.substring(1)} aranıyor…',
          ),
        ],
      );
    }
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!),
          TextButton.icon(
            onPressed: search,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      );
    }
    if (movies.isEmpty) {
      return Text(
        'Eşleşen $kindLabel bulunamadı. Başka bir ad deneyebilir veya elle ekleyebilirsin.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Eşleşen sonuçlar', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final movie in movies)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => widget.onSelected(movie),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoviePoster(movie: movie, width: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (movie.originalTitle.isNotEmpty &&
                              movie.originalTitle != movie.title)
                            Text(movie.originalTitle),
                          const SizedBox(height: 4),
                          Text(
                            movie.year == null
                                ? 'Yıl bilinmiyor'
                                : '${movie.year}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ),
        const MovieAttribution(),
      ],
    );
  }
}

class MovieInfo extends StatelessWidget {
  const MovieInfo({super.key, required this.movie});
  final Movie movie;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: MoviePoster(movie: movie, width: 130)),
      const SizedBox(height: 20),
      Text(
        movie.title,
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      if (movie.originalTitle.isNotEmpty && movie.originalTitle != movie.title)
        Text(movie.originalTitle, textAlign: TextAlign.center),
      if (movie.summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(movie.summary, textAlign: TextAlign.center),
        ),
      if (movie.directors.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Yönetmen: ${movie.directors.join(', ')}',
            textAlign: TextAlign.center,
          ),
        ),
      if (movie.genres.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(movie.genres.join(' · '), textAlign: TextAlign.center),
        ),
      const SizedBox(height: 20),
      Text(
        movie.overview.isEmpty
            ? 'Bu film için özet bulunamadı.'
            : movie.overview,
      ),
      MovieAttribution(movie: movie),
    ],
  );
}

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.movie,
    required this.catalog,
    this.locale = MovieLocale.turkish,
    this.kind = CatalogKind.film,
    this.typeLabel = 'Film',
    this.onSave,
    this.isSaved,
  });
  final Movie movie;
  final MovieCatalog catalog;
  final MovieLocale locale;
  final CatalogKind kind;
  final String typeLabel;
  final Future<void> Function(Movie)? onSave;
  final bool Function(Movie)? isSaved;
  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Movie movie = widget.movie;
  final token = CancelToken();
  bool loading = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (!movie.detailsLoaded && widget.catalog.isConfigured) load();
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final detailed = await widget.catalog.details(
        movie.id,
        widget.locale,
        token,
        kind: widget.kind,
      );
      if (mounted) setState(() => movie = detailed);
    } catch (failure) {
      if (mounted) setState(() => error = movieErrorMessage(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || loading || widget.onSave == null) return;
    setState(() => saving = true);
    var message = '${widget.typeLabel} arşivine eklendi';
    try {
      await widget.onSave!(movie);
    } catch (_) {
      message = 'Arşive eklenemedi. Lütfen tekrar dene.';
    }
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.isSaved?.call(movie) ?? false;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.typeLabel} detayı')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MovieInfo(movie: movie),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                      onPressed: load,
                      child: const Text('Bilgileri tekrar yükle'),
                    ),
                  ],
                  if (widget.onSave != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving || loading || saved ? null : save,
                      icon: Icon(
                        saved
                            ? Icons.bookmark_added
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        saved
                            ? 'Arşivimde'
                            : saving
                            ? 'Kaydediliyor…'
                            : 'Arşivime ekle',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
