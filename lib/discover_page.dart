import 'package:flutter/material.dart';

import 'book_search_page.dart';
import 'journal.dart';
import 'journal_entry_page.dart';
import 'journal_store.dart';
import 'movie.dart';
import 'movie_catalog.dart';
import 'movie_widgets.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.store, this.movies});
  final JournalStore store;
  final MovieCatalog? movies;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool films = false;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Kitaplar'),
                selected: !films,
                onSelected: (_) => setState(() => films = false),
              ),
              ChoiceChip(
                label: const Text('Filmler'),
                selected: films,
                onSelected: (_) => setState(() => films = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: films ? 1 : 0,
            children: [
              BookSearchPage(
                onSaveBook: widget.store.addBook,
                isBookSaved: (book) =>
                    widget.store.find(JournalEntry.bookId(book)) != null,
              ),
              MovieSearchPage(store: widget.store, catalog: widget.movies),
            ],
          ),
        ),
      ],
    ),
  );
}

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key, required this.store, this.catalog});
  final JournalStore store;
  final MovieCatalog? catalog;
  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final query = TextEditingController();
  MovieLocale locale = MovieLocale.turkish;
  late final MovieCatalog catalog = widget.catalog ?? TmdbMovieCatalog();
  @override
  void dispose() {
    query.dispose();
    if (widget.catalog == null) (catalog as TmdbMovieCatalog).dispose();
    super.dispose();
  }

  void openMovie(Movie movie) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MovieDetailPage(
        movie: movie,
        catalog: catalog,
        locale: locale,
        onSave: widget.store.addMovie,
        isSaved: (movie) =>
            widget.store.find(JournalEntry.movieId(movie)) != null,
      ),
    ),
  );
  Future<void> manualEntry() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalEntryPage(
          store: widget.store,
          initialType: MediaType.film,
          movies: catalog,
        ),
      ),
    );
    if (!mounted || id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JournalEntryPage(store: widget.store, entryId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Film keşfet')),
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MovieLanguageSelector(
                value: locale,
                onChanged: (value) => setState(() => locale = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Film adı',
                  hintText: 'Örn. Yıldızlararası',
                  suffixIcon: query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Film aramasını temizle',
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
                onSelected: openMovie,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: manualEntry,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Filmi elle ekle'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
