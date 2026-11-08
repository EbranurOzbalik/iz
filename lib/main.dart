import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'iz_theme.dart';
import 'book_discovery.dart';
import 'journal_shell.dart';
import 'journal_store.dart';
import 'movie_catalog.dart';

export 'book_search_page.dart';

void main() => runApp(const IzApp());

class IzApp extends StatefulWidget {
  const IzApp({super.key, this.store, this.discovery, this.movies});
  final JournalStore? store;
  final BookDiscoverySource? discovery;
  final MovieCatalog? movies;
  @override
  State<IzApp> createState() => _IzAppState();
}

class _IzAppState extends State<IzApp> {
  late final store =
      widget.store ?? JournalStore(storage: PreferencesJournalStorage());
  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'İZ',
    theme: izTheme(Brightness.light),
    darkTheme: izTheme(Brightness.dark),
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: JournalShell(
      store: store,
      discovery: widget.discovery,
      movies: widget.movies,
    ),
  );
}
