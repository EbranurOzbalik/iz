import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book.dart';
import 'book_cover.dart';
import 'book_detail_page.dart';
import 'book_edition.dart';
import 'book_language.dart';
import 'book_title_suggestions.dart';
import 'journal.dart';
import 'journal_cover.dart';
import 'journal_store.dart';
import 'movie.dart';
import 'movie_catalog.dart';
import 'movie_poster.dart';
import 'movie_widgets.dart';
import 'tmdb_attribution.dart';
import 'reminder_service.dart';

class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({
    super.key,
    required this.store,
    this.initialType = MediaType.film,
    this.dio,
    this.movies,
  });
  final JournalStore store;
  final MediaType initialType;
  final Dio? dio;
  final MovieCatalog? movies;
  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final creator = TextEditingController();
  late MediaType type = widget.initialType;
  BookLanguage bookLanguage = BookLanguage.turkish;
  late final dio =
      widget.dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
  final editionToken = CancelToken();
  late final MovieCatalog movieCatalog =
      widget.movies ?? IzMovieCatalog(dio: dio);
  MovieLocale movieLocale = MovieLocale.turkish;
  CancelToken? movieToken;
  Movie? selectedMovie;
  bool movieLoading = false;
  String? movieError;
  Book? selectedBook;
  bool saving = false;

  bool get usesCatalog => type != MediaType.book;
  CatalogKind get catalogKind => switch (type) {
    MediaType.film => CatalogKind.film,
    MediaType.series => CatalogKind.series,
    MediaType.theatre => CatalogKind.theatre,
    MediaType.book => throw StateError('Kitap kültür kataloğunu kullanmaz'),
  };
  @override
  void dispose() {
    editionToken.cancel();
    movieToken?.cancel();
    if (widget.dio == null) dio.close(force: true);
    title.dispose();
    creator.dispose();
    super.dispose();
  }

  void clearSelection() {
    if (selectedBook != null || selectedMovie != null) creator.clear();
    selectedBook = null;
    selectedMovie = null;
    movieToken?.cancel();
    movieLoading = false;
    movieError = null;
  }

  void selectBook(Book book) {
    FocusScope.of(context).unfocus();
    setState(() {
      clearSelection();
      selectedBook = book;
      title.text = book.title;
      creator.text = book.authors.join(', ');
    });
  }

  Future<void> selectMovie(Movie movie) async {
    FocusScope.of(context).unfocus();
    movieToken?.cancel();
    final token = CancelToken();
    movieToken = token;
    setState(() {
      selectedMovie = movie;
      selectedBook = null;
      title.text = movie.title;
      creator.text = movie.directors.join(', ');
      movieLoading = !movie.detailsLoaded;
      movieError = null;
    });
    if (movie.detailsLoaded) return;
    try {
      final detailed = await movieCatalog.details(
        movie.id,
        movieLocale,
        token,
        kind: catalogKind,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        selectedMovie = detailed;
        title.text = detailed.title;
        creator.text = detailed.directors.join(', ');
      });
    } catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() => movieError = movieErrorMessage(error));
    } finally {
      if (mounted && !token.isCancelled) setState(() => movieLoading = false);
    }
  }

  Future<int?> pageCount(Book book) async {
    if (book.editionUrl == null) return null;
    try {
      final response = await dio.get(
        book.editionUrl!,
        cancelToken: editionToken,
      );
      if (response.data is Map<String, dynamic>) {
        return BookEdition.fromJson(response.data).pageCount;
      }
    } catch (_) {
      // Missing edition details must not prevent saving a selected book.
    }
    return null;
  }

  Future<void> save() async {
    if (saving || movieLoading || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final book = selectedBook;
    final movie = selectedMovie;
    final entry = book != null
        ? JournalEntry.fromBook(book)
        : movie != null
        ? JournalEntry.fromCatalog(movie, type)
        : JournalEntry(
            id: 'manual:${type.name}:${jsonEncode([title.text.trim().toLowerCase(), creator.text.trim().toLowerCase()])}',
            title: title.text.trim(),
            creator: creator.text.trim(),
            type: type,
          );
    try {
      if (widget.store.find(entry.id) == null) {
        if (book != null) {
          final pages = await pageCount(book);
          if (!mounted) return;
          await widget.store.addBook(book, pages);
        } else {
          await widget.store.save(entry);
        }
      }
      if (mounted) Navigator.pop(context, entry.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kaydedilemedi. Yazdıkların burada; tekrar deneyebilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni bir iz')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bir hikâyeye yer aç.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<MediaType>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tür'),
                    items: MediaType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            if (value != type) clearSelection();
                            type = value!;
                          }),
                  ),
                  const SizedBox(height: 16),
                  if (type == MediaType.book) ...[
                    BookLanguageSelector(
                      value: bookLanguage,
                      onChanged: saving
                          ? null
                          : (value) => setState(() {
                              if (value == bookLanguage) return;
                              clearSelection();
                              bookLanguage = value;
                            }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (usesCatalog && movieCatalog.isConfigured) ...[
                    MovieLanguageSelector(
                      value: movieLocale,
                      catalogLabel: type.label,
                      onChanged: saving
                          ? null
                          : (locale) => setState(() {
                              if (locale == movieLocale) return;
                              clearSelection();
                              movieLocale = locale;
                            }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: title,
                    enabled: !saving,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: '${type.label} adı'),
                    onChanged: (_) => setState(clearSelection),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Bir eser adı yaz'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (type == MediaType.book && !saving)
                    if (selectedBook case final book?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BookCover(book: book, width: 54, height: 81),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kitap seçildi',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                      Text(book.title),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          clearSelection();
                                          title.clear();
                                        }),
                                        child: const Text('Seçimi kaldır'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      BookTitleSuggestions(
                        query: title.text,
                        dio: dio,
                        language: bookLanguage,
                        onSelected: selectBook,
                      ),
                  if (usesCatalog && !saving) ...[
                    if (selectedMovie case final movie?)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MoviePoster(movie: movie, width: 54),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${type.label} seçildi',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                        ),
                                        Text(movie.title),
                                        Text(movie.summary),
                                        TextButton(
                                          onPressed: () => setState(() {
                                            clearSelection();
                                            title.clear();
                                          }),
                                          child: const Text('Seçimi kaldır'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (movieLoading) const LinearProgressIndicator(),
                              if (movieError != null) ...[
                                Text(movieError!),
                                TextButton(
                                  onPressed: () => selectMovie(movie),
                                  child: const Text('Bilgileri tekrar yükle'),
                                ),
                              ],
                              const MovieAttribution(),
                            ],
                          ),
                        ),
                      )
                    else
                      MovieSuggestions(
                        query: title.text,
                        locale: movieLocale,
                        catalog: movieCatalog,
                        kind: catalogKind,
                        onSelected: selectMovie,
                      ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: creator,
                    enabled: !saving,
                    readOnly: selectedBook != null || selectedMovie != null,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: switch (type) {
                        MediaType.book => 'Yazar (isteğe bağlı)',
                        MediaType.film => 'Yönetmen (isteğe bağlı)',
                        MediaType.series =>
                          'Yönetmen veya senarist (isteğe bağlı)',
                        MediaType.theatre =>
                          'Yazar, yönetmen veya topluluk (isteğe bağlı)',
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: saving || movieLoading ? null : save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(saving ? 'Kaydediliyor…' : 'Arşivime ekle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class JournalEntryPage extends StatefulWidget {
  const JournalEntryPage({
    super.key,
    required this.store,
    required this.entryId,
    this.reminders,
  });
  final JournalStore store;
  final String entryId;
  final ReminderService? reminders;
  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  final form = GlobalKey<FormState>();
  late final JournalEntry entry = widget.store.find(widget.entryId)!;
  late final note = TextEditingController(text: entry.note);
  late final progress = TextEditingController(text: '${entry.progress}');
  late final total = TextEditingController(text: entry.total?.toString() ?? '');
  late final season = TextEditingController(
    text: entry.season?.toString() ?? '',
  );
  late final venue = TextEditingController(text: entry.venue);
  late DateTime? eventDate = entry.eventDate;
  late DateTime? reminderAt = entry.reminderAt;
  late JournalStatus status = entry.status;
  late int rating = entry.rating;
  bool saving = false;

  @override
  void dispose() {
    note.dispose();
    progress.dispose();
    total.dispose();
    season.dispose();
    venue.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final limit = int.tryParse(total.text.trim());
    var value = int.tryParse(progress.text.trim()) ?? 0;
    var updatedStatus = status;
    if (entry.tracksProgress) {
      if (status == JournalStatus.done && limit != null) value = limit;
      if (value > 0 && limit == value) updatedStatus = JournalStatus.done;
      if (value > 0 && updatedStatus == JournalStatus.planned) {
        updatedStatus = JournalStatus.active;
      }
    }
    setState(() => saving = true);
    try {
      await widget.store.save(
        entry.edit(
          status: updatedStatus,
          progress: value,
          total: limit,
          rating: rating,
          note: note.text,
          season: int.tryParse(season.text.trim()),
          venue: venue.text,
          eventDate: eventDate,
          reminderAt: reminderAt,
          clearEventDate: eventDate == null,
          clearReminder: reminderAt == null,
        ),
      );
      final updated = widget.store.find(entry.id)!;
      var reminderReady = true;
      if (widget.reminders case final reminders?) {
        if (updated.reminderAt == null) {
          await reminders.cancel(updated.id);
        } else {
          reminderReady = await reminders.schedule(updated);
        }
      }
      if (!mounted) return;
      if (!reminderReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kayıt tamamlandı; bildirim izni verilmediği için hatırlatıcı kurulamadı.',
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      showSaveError();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void showSaveError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kaydedilemedi. Yazdıkların burada; tekrar deneyebilirsin.',
          ),
        ),
      );
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arşivinden çıkarılsın mı?'),
        content: Text(
          '${entry.title} için notların, puanın ve takvim kayıtların silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.store.remove(entry.id);
      await widget.reminders?.cancel(entry.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      showSaveError();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String dateLabel(DateTime value, {bool time = false}) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    return time
        ? '$date · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}'
        : date;
  }

  Future<DateTime?> pickDateTime(
    DateTime? initial, {
    bool withTime = false,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: withTime ? dayDate(now) : DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted || !withTime) return date;
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.type.label),
        actions: [
          IconButton(
            tooltip: 'Arşivimden çıkar',
            onPressed: saving ? null : remove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: JournalCover(entry: entry, width: 120),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      entry.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (entry.creator.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(entry.creator, textAlign: TextAlign.center),
                      ),
                    if (entry.movie case final movie?) ...[
                      if (movie.summary.isNotEmpty)
                        Text(movie.summary, textAlign: TextAlign.center),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text('${entry.type.label} bilgileri'),
                              ),
                              body: SafeArea(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: MovieInfo(movie: movie),
                                ),
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline),
                        label: Text('${entry.type.label} bilgileri'),
                      ),
                    ],
                    if (entry.book case final book?)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => BookDetailPage(book: book),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Kitap ve baskı bilgileri'),
                      ),
                    const SizedBox(height: 28),
                    Text(
                      'Sende kalan.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<JournalStatus>(
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Günlüğündeki yeri',
                      ),
                      items: JournalStatus.values
                          .where(
                            (s) =>
                                entry.type != MediaType.theatre ||
                                s != JournalStatus.active,
                          )
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                entry
                                    .edit(
                                      status: value,
                                      progress: entry.progress,
                                      total: entry.total,
                                      rating: entry.rating,
                                      note: entry.note,
                                    )
                                    .statusLabel,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => status = value!),
                    ),
                    if (entry.tracksProgress) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: progress,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: entry.type == MediaType.book
                              ? 'Geldiğin sayfa'
                              : 'İzlediğin bölüm sayısı',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          final limit = int.tryParse(total.text);
                          if (parsed == null || parsed < 0) {
                            return '0 veya daha büyük bir sayı yaz';
                          }
                          if (limit != null && parsed > limit) {
                            return 'İlerleme toplamı aşamaz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: total,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Toplam ${entry.unit} (isteğe bağlı)',
                        ),
                        validator: (value) =>
                            value == null ||
                                value.isEmpty ||
                                (int.tryParse(value) ?? 0) > 0
                            ? null
                            : '0’dan büyük bir sayı yaz',
                      ),
                      if (entry.type == MediaType.series) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: season,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Bulunduğun sezon (isteğe bağlı)',
                          ),
                          validator: (value) =>
                              value == null ||
                                  value.isEmpty ||
                                  (int.tryParse(value) ?? 0) > 0
                              ? null
                              : '0’dan büyük bir sayı yaz',
                        ),
                      ],
                    ],
                    if (entry.type == MediaType.theatre) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: venue,
                        enabled: !saving,
                        maxLength: 200,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Sahne veya mekân (isteğe bağlı)',
                        ),
                      ),
                      _DateTile(
                        icon: Icons.theater_comedy_outlined,
                        title: 'Gösterim tarihi',
                        value: eventDate == null ? null : dateLabel(eventDate!),
                        onTap: saving
                            ? null
                            : () async {
                                final value = await pickDateTime(eventDate);
                                if (value != null && mounted) {
                                  setState(() => eventDate = value);
                                }
                              },
                        onClear: eventDate == null || saving
                            ? null
                            : () => setState(() => eventDate = null),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: rating,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Puanın'),
                      items: List.generate(
                        6,
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 0 ? 'Henüz puan vermedim' : '$value / 5',
                          ),
                        ),
                      ),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => rating = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: note,
                      enabled: !saving,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Aklında ne kaldı?',
                        hintText: 'Bir sahne, bir cümle, bir his…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Bana hatırlat',
                      value: reminderAt == null
                          ? null
                          : dateLabel(reminderAt!, time: true),
                      onTap: saving
                          ? null
                          : () async {
                              final value = await pickDateTime(
                                reminderAt,
                                withTime: true,
                              );
                              if (value != null && mounted) {
                                setState(() => reminderAt = value);
                              }
                            },
                      onClear: reminderAt == null || saving
                          ? null
                          : () => setState(() => reminderAt = null),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        saving ? 'Kaydediliyor…' : 'Günlüğüme kaydet',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap, onClear;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value ?? 'Tarih seçilmedi'),
      onTap: onTap,
      trailing: value == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: 'Tarihi kaldır',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
    ),
  );
}
