import 'package:dio/dio.dart';
import 'package:iz/book.dart';
import 'package:iz/book_discovery.dart';
import 'package:iz/journal_store.dart';

class StubBookDiscovery implements BookDiscoverySource {
  Future<List<Book>> Function(CancelToken)? onPopular;
  Future<List<Book>> Function(BookTopic, CancelToken)? onRecommendations;
  int popularCalls = 0;
  final topicCalls = <BookTopic, int>{};

  @override
  Future<List<Book>> popular(CancelToken token) async {
    popularCalls++;
    return onPopular == null ? [] : await onPopular!(token);
  }

  @override
  Future<List<Book>> recommendations(BookTopic topic, CancelToken token) async {
    topicCalls.update(topic, (count) => count + 1, ifAbsent: () => 1);
    return onRecommendations == null
        ? []
        : await onRecommendations!(topic, token);
  }
}

class MemoryJournalStorage implements JournalStorage {
  String? data;
  bool failWrites = false;
  int writes = 0;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Disk unavailable');
    writes++;
    data = value;
  }
}
