import 'package:flutter_test/flutter_test.dart';
import 'package:iz/journal.dart';
import 'package:iz/journal_store.dart';
import 'package:iz/movie.dart';

import 'journal_test_support.dart';

void main() {
  test(
    'Movie IDs deduplicate translations and metadata survives edits and reload',
    () async {
      final storage = MemoryJournalStorage();
      final store = JournalStore(storage: storage);
      addTearDown(store.dispose);
      await store.load();
      const movie = Movie(
        id: 157336,
        title: 'Yıldızlararası',
        originalTitle: 'Interstellar',
        overview: 'Bir uzay yolculuğu.',
        posterPath: '/poster.jpg',
        year: 2014,
        runtime: 169,
        directors: ['Christopher Nolan'],
        genres: ['Bilim Kurgu'],
        detailsLoaded: true,
      );
      await store.addMovie(movie);
      await store.addMovie(const Movie(id: 157336, title: 'Interstellar'));
      expect(store.entries, hasLength(1));
      expect(store.activities, isEmpty);
      final entry = store.entries.single;
      expect(entry.id, 'movie:tmdb:157336');
      expect(entry.type, MediaType.film);
      expect(entry.tracksProgress, isFalse);
      await store.save(
        entry.edit(
          status: JournalStatus.done,
          progress: 0,
          total: null,
          rating: 5,
          note: 'Son sahne.',
        ),
      );
      final restored = JournalStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.entries.single.movie!.toJson(), movie.toJson());
      expect(restored.entries.single.creator, 'Christopher Nolan');
      expect(restored.entries.single.rating, 5);
      expect(restored.entries.single.note, 'Son sahne.');
      expect(restored.activities, hasLength(2));
      expect(restored.entries.single.statusLabel, 'İzledim');
      expect(
        JournalEntry.fromJson({...entry.toJson()}..remove('movie')).movie,
        isNull,
      );
    },
  );
}
