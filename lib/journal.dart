import 'book.dart';
import 'movie.dart';

enum MediaType {
  book('Kitap'),
  film('Film'),
  series('Dizi'),
  theatre('Tiyatro');

  const MediaType(this.label);
  final String label;
}

enum JournalStatus {
  planned('Listemde'),
  active('Devam eden'),
  done('Tamamlanan');

  const JournalStatus(this.label);
  final String label;
}

String localDay(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

DateTime dayDate(DateTime date) => DateTime(date.year, date.month, date.day);

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.creator,
    required this.type,
    this.status = JournalStatus.planned,
    this.progress = 0,
    this.total,
    this.rating = 0,
    this.note = '',
    this.season,
    this.venue = '',
    this.eventDate,
    this.reminderAt,
    this.book,
    this.movie,
  });

  final String id, title, creator, note;
  final MediaType type;
  final JournalStatus status;
  final int progress, rating;
  final int? total;
  final int? season;
  final String venue;
  final DateTime? eventDate, reminderAt;
  final Book? book;
  final Movie? movie;

  static String movieId(Movie movie) => 'movie:tmdb:${movie.id}';
  static String catalogId(Movie item, MediaType type) =>
      'catalog:${type.name}:${item.id}';
  factory JournalEntry.fromMovie(Movie movie) => JournalEntry(
    id: movieId(movie),
    title: movie.title,
    creator: movie.directors.join(', '),
    type: MediaType.film,
    movie: movie,
  );

  factory JournalEntry.fromCatalog(Movie item, MediaType type) {
    if (type == MediaType.film) return JournalEntry.fromMovie(item);
    if (type == MediaType.book) {
      throw const FormatException('Kitap katalog kaydı film modeli kullanamaz');
    }
    return JournalEntry(
      id: catalogId(item, type),
      title: item.title,
      creator: item.directors.join(', '),
      type: type,
      movie: item,
    );
  }

  static String bookId(Book book) =>
      'book:${book.workKey ?? book.editionKey ?? '${book.title.trim().toLowerCase()}|${book.authors.join(',').trim().toLowerCase()}'}';

  factory JournalEntry.fromBook(Book book, {int? total}) => JournalEntry(
    id: bookId(book),
    title: book.title,
    creator: book.authors.join(', '),
    type: MediaType.book,
    book: book,
    total: total,
  );

  bool get tracksProgress => type == MediaType.book || type == MediaType.series;
  String get unit => type == MediaType.series ? 'bölüm' : 'sayfa';
  String get statusLabel => switch ((type, status)) {
    (MediaType.book, JournalStatus.planned) => 'Okuyacağım',
    (MediaType.book, JournalStatus.active) => 'Okuyorum',
    (MediaType.book, JournalStatus.done) => 'Okudum',
    (MediaType.theatre, JournalStatus.planned) => 'Gideceğim',
    (_, JournalStatus.planned) => 'İzleyeceğim',
    (_, JournalStatus.active) => 'İzliyorum',
    (_, JournalStatus.done) => 'İzledim',
  };
  String get progressLabel =>
      total == null ? '$progress $unit' : '$progress / $total $unit';

  JournalEntry edit({
    required JournalStatus status,
    required int progress,
    required int? total,
    required int rating,
    required String note,
    int? season,
    String? venue,
    DateTime? eventDate,
    DateTime? reminderAt,
    bool clearEventDate = false,
    bool clearReminder = false,
  }) => JournalEntry(
    id: id,
    title: title,
    creator: creator,
    type: type,
    book: book,
    movie: movie,
    status: status,
    progress: progress,
    total: total,
    rating: rating,
    note: note.trim(),
    season: season ?? this.season,
    venue: venue?.trim() ?? this.venue,
    eventDate: clearEventDate ? null : eventDate ?? this.eventDate,
    reminderAt: clearReminder ? null : reminderAt ?? this.reminderAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'creator': creator,
    'type': type.name,
    'status': status.name,
    'progress': progress,
    'total': total,
    'rating': rating,
    'note': note,
    if (season != null) 'season': season,
    if (venue.isNotEmpty) 'venue': venue,
    if (eventDate != null) 'eventDate': eventDate!.toIso8601String(),
    if (reminderAt != null) 'reminderAt': reminderAt!.toIso8601String(),
    if (movie != null) 'movie': movie!.toJson(),
    if (book case final source?)
      'book': {
        'title': source.title,
        'author_name': source.authors,
        'key': source.workKey,
        'first_publish_year': source.firstPublishYear,
        'edition_count': source.editionCount,
        'cover_i': source.coverId,
        'subtitle': source.subtitle,
        'editions': {
          'docs': [
            if (source.editionKey != null) {'key': source.editionKey},
          ],
        },
      },
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final entry = JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      creator: json['creator'] as String,
      type: MediaType.values.byName(json['type'] as String),
      status: JournalStatus.values.byName(json['status'] as String),
      progress: json['progress'] as int,
      total: json['total'] as int?,
      rating: json['rating'] as int,
      note: json['note'] as String,
      season: json['season'] as int?,
      venue: json['venue'] as String? ?? '',
      eventDate: _date(json['eventDate']),
      reminderAt: _date(json['reminderAt']),
      book: json['book'] == null
          ? null
          : Book.fromJson(Map<String, dynamic>.from(json['book'] as Map)),
      movie: json['movie'] == null
          ? null
          : Movie.fromJson(Map<String, dynamic>.from(json['movie'] as Map)),
    );
    entry.validate();
    return entry;
  }

  void validate() {
    if ((movie != null &&
            (type == MediaType.book ||
                (type == MediaType.film
                    ? id != movieId(movie!) && id != catalogId(movie!, type)
                    : id != catalogId(movie!, type)))) ||
        id.isEmpty ||
        title.trim().isEmpty ||
        progress < 0 ||
        (total != null && (total! <= 0 || progress > total!)) ||
        rating < 0 ||
        rating > 5 ||
        note.length > 2000 ||
        (season != null && (type != MediaType.series || season! <= 0)) ||
        venue.length > 200 ||
        (venue.isNotEmpty && type != MediaType.theatre) ||
        (eventDate != null && type != MediaType.theatre)) {
      throw const FormatException('Geçersiz günlük kaydı');
    }
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

class JournalActivity {
  const JournalActivity({
    required this.entryId,
    required this.day,
    required this.kind,
    required this.text,
  });
  final String entryId, day, kind, text;
  String get id => '$day|$entryId|$kind';
  Map<String, String> toJson() => {
    'entryId': entryId,
    'day': day,
    'kind': kind,
    'text': text,
  };
  factory JournalActivity.fromJson(Map<String, dynamic> json) {
    final activity = JournalActivity(
      entryId: json['entryId'] as String,
      day: json['day'] as String,
      kind: json['kind'] as String,
      text: json['text'] as String,
    );
    final parsed = DateTime.tryParse(activity.day);
    if (parsed == null ||
        localDay(parsed) != activity.day ||
        !['progress', 'status', 'note'].contains(activity.kind)) {
      throw const FormatException('Geçersiz takvim kaydı');
    }
    return activity;
  }
}
