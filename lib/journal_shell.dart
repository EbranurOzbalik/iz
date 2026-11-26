import 'package:flutter/material.dart';

import 'book.dart';
import 'book_detail_page.dart';
import 'book_discovery.dart';
import 'book_discovery_section.dart';
import 'book_language.dart';
import 'book_search_page.dart';
import 'journal.dart';
import 'journal_calendar.dart';
import 'journal_cover.dart';
import 'journal_entry_page.dart';
import 'journal_store.dart';
import 'journal_statistics_page.dart';
import 'discover_page.dart';
import 'movie_catalog.dart';
import 'movie.dart';
import 'app_info_page.dart';
import 'catalog_discovery_section.dart';
import 'reminder_service.dart';

class JournalShell extends StatefulWidget {
  const JournalShell({
    super.key,
    required this.store,
    this.discovery,
    this.movies,
    this.reminders,
  });
  final JournalStore store;
  final BookDiscoverySource? discovery;
  final MovieCatalog? movies;
  final ReminderService? reminders;
  @override
  State<JournalShell> createState() => _JournalShellState();
}

class _JournalShellState extends State<JournalShell>
    with WidgetsBindingObserver {
  int tab = 0;
  MediaType? category;
  JournalStatus? archiveStatus;
  BookLanguage recommendationLanguage = BookLanguage.turkish;
  late final MovieCatalog catalog = widget.movies ?? IzMovieCatalog();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.store.loaded) widget.store.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.movies == null) (catalog as IzMovieCatalog).dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> addEntry() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalEntryPage(
          store: widget.store,
          initialType: category ?? MediaType.film,
          movies: catalog,
        ),
      ),
    );
    if (id != null && mounted) openEntry(id);
  }

  void openEntry(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => JournalEntryPage(
        store: widget.store,
        entryId: id,
        reminders: widget.reminders,
      ),
    ),
  );

  void openBook(Book book) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (detailContext) => BookDetailPage(
        book: book,
        onSaveBook: widget.store.addBook,
        isBookSaved: (book) =>
            widget.store.find(JournalEntry.bookId(book)) != null,
        onSearchAuthor: (author) => Navigator.push(
          detailContext,
          MaterialPageRoute<void>(
            builder: (_) => BookSearchPage(
              initialAuthor: author,
              onSaveBook: widget.store.addBook,
              isBookSaved: (book) =>
                  widget.store.find(JournalEntry.bookId(book)) != null,
            ),
          ),
        ),
      ),
    ),
  );

  Widget categories() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      ChoiceChip(
        label: const Text('Tümü'),
        selected: category == null,
        onSelected: (_) => setState(() => category = null),
      ),
      for (final type in MediaType.values)
        ChoiceChip(
          avatar: Icon(mediaIcon(type), size: 16),
          label: Text(type.label),
          selected: category == type,
          showCheckmark: false,
          onSelected: (_) => setState(() => category = type),
        ),
    ],
  );

  Widget pageBody(List<Widget> children, {required String key}) =>
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: PageStorageKey(key),
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 420 ? 16 : 24,
            8,
            constraints.maxWidth < 420 ? 16 : 24,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      );

  Widget home() {
    final entries = widget.store.entries
        .where((e) => category == null || e.type == category)
        .toList();
    final active = entries
        .where((e) => e.status == JournalStatus.active)
        .toList();
    final colors = Theme.of(context).colorScheme;
    return pageBody([
      const SizedBox(height: 12),
      Text('Bugün sende', style: Theme.of(context).textTheme.headlineLarge),
      Text(
        'ne kaldı?',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: colors.primary,
        ),
      ),
      const SizedBox(height: 24),
      categories(),
      const SizedBox(height: 14),
      Text('Öneri dili', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          for (final language in BookLanguage.values)
            ChoiceChip(
              label: Text(language.label),
              selected: recommendationLanguage == language,
              onSelected: (_) =>
                  setState(() => recommendationLanguage = language),
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (active.isNotEmpty) ...[
        Text(
          'Kaldığın yerden',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          color: colors.secondaryContainer.withValues(alpha: .55),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openEntry(active.first.id),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JournalCover(entry: active.first, width: 80),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.first.type.label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          active.first.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (active.first.creator.isNotEmpty)
                          Text(active.first.creator),
                        const SizedBox(height: 16),
                        if (active.first.tracksProgress) ...[
                          if (active.first.total case final total?)
                            LinearProgressIndicator(
                              value: active.first.progress / total,
                            ),
                          const SizedBox(height: 8),
                          Text(active.first.progressLabel),
                        ] else
                          Text(active.first.statusLabel),
                        const SizedBox(height: 6),
                        Text(
                          'İz bırak →',
                          style: TextStyle(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
      Visibility(
        key: ValueKey('discovery-shelves-${recommendationLanguage.name}'),
        visible: category == null || category == MediaType.book,
        maintainState: true,
        child: BookDiscoverySection(
          key: ValueKey('book-discovery-${recommendationLanguage.name}'),
          source: widget.discovery,
          language: recommendationLanguage,
          savedBookIds: widget.store.entries.map((e) => e.id).toSet(),
          onOpenBook: openBook,
        ),
      ),
      for (final type in [MediaType.film, MediaType.series, MediaType.theatre])
        if ((category == null || category == type) && catalog.isConfigured)
          CatalogDiscoverySection(
            key: ValueKey(
              'catalog-shelf-${type.name}-${recommendationLanguage.name}',
            ),
            catalog: catalog,
            type: type,
            locale: recommendationLanguage == BookLanguage.english
                ? MovieLocale.english
                : MovieLocale.turkish,
            savedIds: widget.store.entries.map((entry) => entry.id).toSet(),
            onSave: (item, type) =>
                widget.store.save(JournalEntry.fromCatalog(item, type)),
          ),
      if (entries.isEmpty) ...[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                mediaIcon(category ?? MediaType.book),
                size: 32,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'İlk hikâyen burada başlayacak.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bir kitap bul veya izlediğin bir eseri ekle. Sende kalanları günlüğünde sakla.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: category != null && category != MediaType.book
                    ? addEntry
                    : () => setState(() => tab = 1),
                child: Text(
                  category != null && category != MediaType.book
                      ? '${category!.label} ekle'
                      : 'Kitap keşfet',
                ),
              ),
              if (category == null || category == MediaType.book)
                TextButton.icon(
                  onPressed: addEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Eser ekle'),
                ),
            ],
          ),
        ),
      ] else ...[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Arşivinden',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton(
              onPressed: () => setState(() => tab = 2),
              child: const Text('Tümünü gör'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        coverGrid(entries.reversed.take(4).toList()),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: addEntry,
          icon: const Icon(Icons.add),
          label: const Text('Yeni bir iz ekle'),
        ),
      ],
      JournalCalendar(
        entries: widget.store.entries,
        activities: widget.store.activities,
        today: widget.store.clock(),
        onOpenEntry: openEntry,
      ),
    ], key: 'journal-home');
  }

  Widget coverGrid(List<JournalEntry> entries) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 22
          ? 1
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 20,
        children: [
          for (final entry in entries)
            SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openEntry(entry.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: JournalCover(
                          entry: entry,
                          width: (width * .66).clamp(64, 120),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${entry.type.label} · ${entry.statusLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (entry.rating > 0)
                      Text(
                        '${entry.rating} / 5 ★',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget archive() {
    final entries = widget.store.entries
        .where(
          (e) =>
              (category == null || e.type == category) &&
              (archiveStatus == null || e.status == archiveStatus),
        )
        .toList()
        .reversed
        .toList();
    return pageBody([
      const SizedBox(height: 12),
      Text(
        'Biriktirdiğin izler.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      Text('${widget.store.entries.length} eser arşivinde'),
      const SizedBox(height: 20),
      categories(),
      const SizedBox(height: 16),
      DropdownButtonFormField<JournalStatus?>(
        initialValue: archiveStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Durum'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Tüm durumlar')),
          ...JournalStatus.values.map(
            (s) => DropdownMenuItem(value: s, child: Text(s.label)),
          ),
        ],
        onChanged: (value) => setState(() => archiveStatus = value),
      ),
      const SizedBox(height: 24),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Bu rafta henüz bir izin yok.'),
        )
      else
        coverGrid(entries),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Eser ekle'),
      ),
    ], key: 'journal-archive');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      // Android can emit a zero-size frame before its surface is ready.
      // Wait for real dimensions before laying out the archive and calendar.
      if (MediaQuery.sizeOf(context).isEmpty) return const SizedBox.shrink();
      final store = widget.store;
      if (store.loadError != null || !store.loaded) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: store.loadError == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(store.loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: store.busy ? null : store.load,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: tab == 1
            ? null
            : AppBar(
                title: Row(
                  children: [
                    Text(
                      'iz',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (MediaQuery.sizeOf(context).width >= 520) ...[
                      const SizedBox(width: 16),
                      Text(
                        'hikâyeler geçer, izleri kalır.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'İstatistiklerim',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => JournalStatisticsPage(
                          entries: store.entries,
                          activities: store.activities,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart_rounded),
                  ),
                  IconButton(
                    tooltip: 'Yardım ve gizlilik',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AppInfoPage(store: store),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    tooltip: 'Eser ekle',
                    onPressed: store.busy ? null : addEntry,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
        body: SafeArea(
          top: tab != 1,
          child: IndexedStack(
            index: tab,
            children: [
              home(),
              DiscoverPage(
                store: store,
                movies: catalog,
                reminders: widget.reminders,
              ),
              archive(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Günlüğüm',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Keşfet',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'Arşivim',
            ),
          ],
        ),
      );
    },
  );
}
