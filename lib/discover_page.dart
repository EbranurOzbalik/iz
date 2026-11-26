import 'package:flutter/material.dart';

import 'book_search_page.dart';
import 'journal.dart';
import 'journal_cover.dart';
import 'journal_entry_page.dart';
import 'journal_store.dart';
import 'movie.dart';
import 'movie_catalog.dart';
import 'movie_widgets.dart';
import 'reminder_service.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.store,
    this.movies,
    this.reminders,
  });
  final JournalStore store;
  final MovieCatalog? movies;
  final ReminderService? reminders;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  MediaType selected = MediaType.book;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mediaChoice(MediaType.book, 'Kitaplar'),
                  _mediaChoice(MediaType.film, 'Filmler'),
                  _mediaChoice(MediaType.series, 'Diziler'),
                  _mediaChoice(MediaType.theatre, 'Tiyatro'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: MediaType.values.indexOf(selected),
            children: [
              BookSearchPage(
                onSaveBook: widget.store.addBook,
                isBookSaved: (book) =>
                    widget.store.find(JournalEntry.bookId(book)) != null,
              ),
              MovieSearchPage(
                store: widget.store,
                catalog: widget.movies,
                reminders: widget.reminders,
              ),
              MovieSearchPage(
                store: widget.store,
                catalog: widget.movies,
                type: MediaType.series,
                reminders: widget.reminders,
              ),
              MovieSearchPage(
                store: widget.store,
                catalog: widget.movies,
                type: MediaType.theatre,
                reminders: widget.reminders,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mediaChoice(MediaType type, String label) => ChoiceChip(
    avatar: Icon(mediaIcon(type), size: 18),
    label: Text(label),
    selected: selected == type,
    showCheckmark: false,
    onSelected: (_) => setState(() => selected = type),
  );
}

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({
    super.key,
    required this.store,
    this.catalog,
    this.type = MediaType.film,
    this.reminders,
  });
  final JournalStore store;
  final MovieCatalog? catalog;
  final MediaType type;
  final ReminderService? reminders;
  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final query = TextEditingController();
  MovieLocale locale = MovieLocale.turkish;
  late final MovieCatalog catalog = widget.catalog ?? IzMovieCatalog();
  CatalogKind get kind => switch (widget.type) {
    MediaType.film => CatalogKind.film,
    MediaType.series => CatalogKind.series,
    MediaType.theatre => CatalogKind.theatre,
    MediaType.book => throw StateError('Kitap bu kataloğu kullanmaz'),
  };
  String get label => widget.type.label;
  @override
  void dispose() {
    query.dispose();
    if (widget.catalog == null) (catalog as IzMovieCatalog).dispose();
    super.dispose();
  }

  void openMovie(Movie movie) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MovieDetailPage(
        movie: movie,
        catalog: catalog,
        locale: locale,
        kind: kind,
        typeLabel: label,
        onSave: (item) =>
            widget.store.save(JournalEntry.fromCatalog(item, widget.type)),
        isSaved: (item) =>
            widget.store.find(
              widget.type == MediaType.film
                  ? JournalEntry.movieId(item)
                  : JournalEntry.catalogId(item, widget.type),
            ) !=
            null,
      ),
    ),
  );
  Future<void> manualEntry() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalEntryPage(
          store: widget.store,
          initialType: widget.type,
          movies: catalog,
        ),
      ),
    );
    if (!mounted || id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JournalEntryPage(
          store: widget.store,
          entryId: id,
          reminders: widget.reminders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(catalog.isConfigured ? '$label keşfet' : '$label günlüğün'),
    ),
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (catalog.isConfigured) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MovieLanguageSelector(
                        value: locale,
                        catalogLabel: label,
                        onChanged: (value) => setState(() => locale = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: query,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: '$label adı',
                          hintText: switch (widget.type) {
                            MediaType.film => 'Örn. Yıldızlararası',
                            MediaType.series => 'Örn. Breaking Bad',
                            MediaType.theatre => 'Örn. Hamlet',
                            MediaType.book => '',
                          },
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '$label aramasını temizle',
                                  onPressed: () => setState(query.clear),
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      MovieSuggestions(
                        query: query.text,
                        locale: locale,
                        catalog: catalog,
                        kind: kind,
                        onSelected: openMovie,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Icon(
                  widget.type == MediaType.series
                      ? Icons.tv_outlined
                      : widget.type == MediaType.theatre
                      ? Icons.theater_comedy_outlined
                      : Icons.local_movies_outlined,
                  size: 56,
                ),
                const SizedBox(height: 20),
                Text(
                  'Sende iz bırakan ${label.toLowerCase()} eserleri.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '$label kayıtlarını, puanını ve sende kalan notları günlüğünde sakla.',
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: manualEntry,
                icon: const Icon(Icons.edit_outlined),
                label: Text(switch (widget.type) {
                  MediaType.film => 'Filmi elle ekle',
                  MediaType.series => 'Diziyi elle ekle',
                  MediaType.theatre => 'Tiyatroyu elle ekle',
                  MediaType.book => 'Kitabı elle ekle',
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
