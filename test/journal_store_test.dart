import 'package:flutter_test/flutter_test.dart';
import 'package:iz/book.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_store.dart';

import 'journal_test_support.dart';

void main() {
  late MemoryJournalStorage storage;
  late JournalStore store;
  late DateTime now;
  const movie = JournalEntry(
    id: 'movie-1',
    title: 'Perfect Days',
    creator: 'Wim Wenders',
    type: MediaType.film,
  );
  setUp(() async {
    storage = MemoryJournalStorage();
    now = DateTime(2026, 11, 5, 23, 59);
    store = JournalStore(storage: storage, clock: () => now);
    await store.load();
  });
  tearDown(() => store.dispose());

  test('Books survive a new store and are deduplicated by work', () async {
    final book = Book(
      title: 'Martı',
      authors: ['Richard Bach'],
      workKey: '/works/OL1W',
      editionKey: '/books/OL1M',
      coverId: 42,
      subtitle: 'Bir hikâye',
    );
    await store.addBook(book, 112);
    await store.addBook(
      Book(
        title: 'Martı',
        authors: ['Richard Bach'],
        workKey: '/works/OL1W',
        editionKey: '/books/OL2M',
      ),
      120,
    );
    expect(store.entries, hasLength(1));
    expect(store.activities, isEmpty);
    final restored = JournalStore(storage: storage);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.entries.single.total, 112);
    expect(restored.entries.single.book!.coverId, 42);
    expect(
      restored.entries.single.book!.editionUrl,
      'https://openlibrary.org/books/OL1M.json',
    );
    expect(restored.entries.single.book!.workKey, '/works/OL1W');
  });

  test(
    'Notes count once per local day and unchanged saves add nothing',
    () async {
      await store.save(movie);
      expect(store.activities, isEmpty);
      final note = movie.edit(
        status: JournalStatus.planned,
        progress: 0,
        total: null,
        rating: 4,
        note: 'Bir sahne.',
      );
      await store.save(note);
      await store.save(note);
      await store.save(
        note.edit(
          status: note.status,
          progress: 0,
          total: null,
          rating: 5,
          note: 'Başka bir sahne.',
        ),
      );
      expect(store.activities, hasLength(1));
      expect(store.activities.single.day, '2026-11-05');
      now = DateTime(2026, 11, 6, 0, 1);
      await store.save(note);
      expect(store.activities, hasLength(2));
      expect(store.activities.last.day, '2026-11-06');
    },
  );

  test(
    'Progress is validated and repeated updates share a calendar record',
    () async {
      const book = JournalEntry(
        id: 'book',
        title: 'Martı',
        creator: '',
        type: MediaType.book,
        total: 112,
      );
      await store.save(book);
      for (final value in [10, 20, 40]) {
        await store.save(
          book.edit(
            status: JournalStatus.active,
            progress: value,
            total: 112,
            rating: 0,
            note: '',
          ),
        );
      }
      expect(store.activities.where((e) => e.kind == 'progress'), hasLength(1));
      expect(
        store.activities.firstWhere((e) => e.kind == 'progress').text,
        '40. sayfaya geldin',
      );
      await expectLater(
        store.save(
          book.edit(
            status: JournalStatus.active,
            progress: 113,
            total: 112,
            rating: 0,
            note: '',
          ),
        ),
        throwsFormatException,
      );
      expect(store.entries.single.progress, 40);
    },
  );

  test('A failed write retains both the saved entry and calendar', () async {
    await store.save(movie);
    final saved = storage.data;
    storage.failWrites = true;
    await expectLater(
      store.save(
        movie.edit(
          status: JournalStatus.done,
          progress: 0,
          total: null,
          rating: 5,
          note: 'Silinmemeli',
        ),
      ),
      throwsStateError,
    );
    expect(storage.data, saved);
    expect(store.entries.single.note, isEmpty);
    expect(store.activities, isEmpty);
    expect(store.busy, isFalse);
    storage.failWrites = false;
    await store.save(
      movie.edit(
        status: JournalStatus.done,
        progress: 0,
        total: null,
        rating: 5,
        note: 'Tekrar',
      ),
    );
    expect(store.entries.single.note, 'Tekrar');
  });

  test('Corrupt storage is not overwritten and can be retried', () async {
    storage.data = '{broken';
    final broken = JournalStore(storage: storage);
    addTearDown(broken.dispose);
    await broken.load();
    expect(broken.loaded, isFalse);
    expect(broken.loadError, isNotNull);
    await expectLater(broken.save(movie), throwsStateError);
    expect(storage.data, '{broken');
    storage.data = null;
    await broken.load();
    await broken.save(movie);
    expect(broken.entries, hasLength(1));
  });

  test('Removing an entry removes only its own activity', () async {
    await store.save(
      movie.edit(
        status: JournalStatus.done,
        progress: 0,
        total: null,
        rating: 5,
        note: 'Film',
      ),
    );
    const other = JournalEntry(
      id: 'other',
      title: 'Hamlet',
      creator: '',
      type: MediaType.theatre,
      note: 'Sahne',
    );
    await store.save(other);
    await store.remove(movie.id);
    expect(store.entries.single.id, 'other');
    expect(store.activities.single.entryId, 'other');
  });
}
