import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'journal.dart';
import 'movie.dart';
import 'movie_catalog.dart';
import 'movie_poster.dart';

class CatalogDiscoverySection extends StatefulWidget {
  const CatalogDiscoverySection({
    super.key,
    required this.catalog,
    required this.type,
    required this.savedIds,
    required this.onSave,
    this.locale = MovieLocale.turkish,
  });

  final MovieCatalog catalog;
  final MediaType type;
  final Set<String> savedIds;
  final Future<void> Function(Movie item, MediaType type) onSave;
  final MovieLocale locale;

  @override
  State<CatalogDiscoverySection> createState() =>
      _CatalogDiscoverySectionState();
}

class _CatalogDiscoverySectionState extends State<CatalogDiscoverySection> {
  final token = CancelToken();
  List<Movie> items = [];
  bool loading = false;
  bool loaded = false;
  bool failed = false;
  int offset = 0;

  CatalogKind get kind => switch (widget.type) {
    MediaType.film => CatalogKind.film,
    MediaType.series => CatalogKind.series,
    MediaType.theatre => CatalogKind.theatre,
    MediaType.book => throw StateError('Kitap bu kataloğu kullanmaz'),
  };

  String get title => switch (widget.type) {
    MediaType.film => 'Öne çıkan filmler',
    MediaType.series => 'Öne çıkan diziler',
    MediaType.theatre => 'Tiyatro önerileri',
    MediaType.book => '',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    token.cancel();
    super.dispose();
  }

  Future<void> load({bool next = false}) async {
    if (loading || !widget.catalog.isConfigured) return;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final requestedOffset = next ? offset + 12 : offset;
      final result = await widget.catalog.featured(
        widget.locale,
        token,
        kind: kind,
        offset: requestedOffset,
      );
      if (!mounted) return;
      setState(() {
        items = result;
        offset = requestedOffset;
        loaded = true;
      });
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save(Movie item) async {
    await widget.onSave(item, widget.type);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.title} arşivine eklendi.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.catalog.isConfigured) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('featured-${widget.type.name}'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'İZ Katalog · Senin için',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '$title listesini yenile',
                onPressed: loading ? null : () => load(next: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading) const LinearProgressIndicator(),
          if (failed)
            TextButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Öneriler yüklenemedi. Tekrar dene'),
            ),
          if (loaded && items.isEmpty) const Text('Henüz öneri bulunamadı.'),
          if (items.isNotEmpty)
            SizedBox(
              height: 306,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final saved = widget.savedIds.contains(
                    JournalEntry.catalogId(item, widget.type),
                  );
                  return SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MoviePoster(movie: item, width: 112),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (item.year != null) Text('${item.year}'),
                        const Spacer(),
                        TextButton(
                          onPressed: saved ? null : () => save(item),
                          child: Text(saved ? 'Arşivinde' : 'Arşive ekle'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
