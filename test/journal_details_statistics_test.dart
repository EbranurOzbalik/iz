import 'package:flutter_test/flutter_test.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_statistics_page.dart';

void main() {
  test('Dizi ve tiyatro ayrıntıları kayıt döngüsünde korunur', () {
    final reminder = DateTime(2027, 2, 3, 19, 30);
    final theatre = JournalEntry(
      id: 'theatre:1',
      title: 'Hamlet',
      creator: 'Topluluk',
      type: MediaType.theatre,
      venue: 'Şehir Tiyatroları',
      eventDate: DateTime(2027, 2, 4),
      reminderAt: reminder,
    );
    final restored = JournalEntry.fromJson(theatre.toJson());
    expect(restored.venue, 'Şehir Tiyatroları');
    expect(restored.eventDate, DateTime(2027, 2, 4));
    expect(restored.reminderAt, reminder);

    final series = const JournalEntry(
      id: 'series:1',
      title: 'Bir Dizi',
      creator: '',
      type: MediaType.series,
      season: 3,
      progress: 18,
      total: 24,
    );
    expect(JournalEntry.fromJson(series.toJson()).season, 3);
  });

  test('İstatistikler arşiv ve etkinliklerden doğru hesaplanır', () {
    final entries = [
      const JournalEntry(
        id: 'b',
        title: 'Kitap',
        creator: '',
        type: MediaType.book,
        status: JournalStatus.done,
        rating: 4,
      ),
      const JournalEntry(
        id: 's',
        title: 'Dizi',
        creator: '',
        type: MediaType.series,
        status: JournalStatus.active,
        rating: 2,
      ),
    ];
    const activities = [
      JournalActivity(
        entryId: 'b',
        day: '2026-11-13',
        kind: 'note',
        text: 'Not',
      ),
      JournalActivity(
        entryId: 's',
        day: '2026-11-14',
        kind: 'progress',
        text: 'Bölüm',
      ),
    ];
    final stats = JournalStatistics(entries, activities);
    expect(stats.total, 2);
    expect(stats.completed, 1);
    expect(stats.active, 1);
    expect(stats.averageRating, 3);
    expect(stats.activityDays, 2);
    expect(stats.byType[MediaType.series], 1);
  });
}
