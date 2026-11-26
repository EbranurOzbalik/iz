import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book.dart';
import 'journal.dart';
import 'movie.dart';

abstract interface class JournalStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesJournalStorage implements JournalStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'iz.journal.v1';
  @override
  Future<String?> read() => _preferences.getString(_key);
  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}

class JournalStore extends ChangeNotifier {
  JournalStore({required this.storage, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final JournalStorage storage;
  final DateTime Function() clock;
  List<JournalEntry> _entries = [];
  List<JournalActivity> _activities = [];
  List<JournalEntry> get entries => List.unmodifiable(_entries);
  List<JournalActivity> get activities => List.unmodifiable(_activities);
  bool loaded = false;
  bool busy = false;
  String? loadError;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    loadError = null;
    _changed();
    try {
      final source = await storage.read();
      if (source != null) {
        final json = jsonDecode(source) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Desteklenmeyen günlük sürümü');
        }
        final entries = (json['entries'] as List)
            .map(
              (e) => JournalEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final activities = (json['activities'] as List)
            .map(
              (e) =>
                  JournalActivity.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final ids = entries.map((e) => e.id).toSet();
        if (ids.length != entries.length ||
            activities.any((e) => !ids.contains(e.entryId))) {
          throw const FormatException('Tutarsız günlük kayıtları');
        }
        _entries = entries;
        _activities = activities;
      }
      loaded = true;
    } catch (_) {
      loadError =
          'Günlüğün açılamadı. Kayıtlarını koruduk; tekrar deneyebilirsin.';
    } finally {
      busy = false;
      _changed();
    }
  }

  JournalEntry? find(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> addBook(Book book, int? total) async {
    final entry = JournalEntry.fromBook(book, total: total);
    if (find(entry.id) != null) return;
    await save(entry);
  }

  Future<void> addMovie(Movie movie) async {
    final entry = JournalEntry.fromMovie(movie);
    if (find(entry.id) != null) return;
    await save(entry);
  }

  Future<void> save(JournalEntry entry) async {
    entry.validate();
    final previous = find(entry.id);
    final activities = [..._activities];
    final day = localDay(clock());
    void record(String kind, String text) {
      final activity = JournalActivity(
        entryId: entry.id,
        day: day,
        kind: kind,
        text: text,
      );
      activities.removeWhere((e) => e.id == activity.id);
      activities.add(activity);
    }

    if (entry.tracksProgress && entry.progress != (previous?.progress ?? 0)) {
      record(
        'progress',
        '${entry.progress}. ${entry.unit}${entry.type == MediaType.book ? 'ya geldin' : 'ü izledin'}',
      );
    }
    if (entry.status != (previous?.status ?? JournalStatus.planned)) {
      record('status', entry.statusLabel);
    }
    if (entry.note != (previous?.note ?? '') ||
        entry.rating != (previous?.rating ?? 0)) {
      record(
        'note',
        entry.note.isEmpty
            ? 'Puanını güncelledin'
            : 'Sende kalanları not ettin',
      );
    }
    final entries = previous == null
        ? [..._entries, entry]
        : _entries.map((e) => e.id == entry.id ? entry : e).toList();
    await _commit(entries, activities);
  }

  Future<void> remove(String id) => _commit(
    _entries.where((e) => e.id != id).toList(),
    _activities.where((e) => e.entryId != id).toList(),
  );

  Future<void> clear() => _commit([], []);

  Future<void> _commit(
    List<JournalEntry> entries,
    List<JournalActivity> activities,
  ) async {
    if (!loaded || loadError != null || busy) {
      throw StateError('Günlük şu an kaydedilemiyor');
    }
    busy = true;
    _changed();
    try {
      await storage.write(
        jsonEncode({
          'version': 1,
          'entries': entries.map((e) => e.toJson()).toList(),
          'activities': activities.map((e) => e.toJson()).toList(),
        }),
      );
      _entries = entries;
      _activities = activities;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
