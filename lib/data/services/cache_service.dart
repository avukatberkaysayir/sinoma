import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/dictionary_model.dart';
import '../models/video_segment_model.dart';

class CacheService {
  static const _boxDictionary = 'dictionary_cache';
  static const _boxVideoFeed = 'video_feed_cache';

  late final Box<String> _dictBox;
  late final Box<String> _feedBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();
  }

  Future<void> openBoxes() async {
    _dictBox = await Hive.openBox<String>(_boxDictionary);
    _feedBox = await Hive.openBox<String>(_boxVideoFeed);
  }

  // ── Dictionary ────────────────────────────────────────────────

  Future<void> cacheWord(DictionaryModel word) async {
    final json = jsonEncode({'id': word.wordId, ...word.toCacheMap()});
    await _dictBox.put(word.wordId, json);
  }

  DictionaryModel? loadCachedWord(String wordId) {
    final raw = _dictBox.get(wordId);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DictionaryModel.fromCache(wordId, map);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheWords(List<DictionaryModel> words) async {
    for (final w in words) {
      await cacheWord(w);
    }
  }

  List<DictionaryModel> loadCachedWordsForIds(List<String> ids) {
    return ids
        .map(loadCachedWord)
        .whereType<DictionaryModel>()
        .toList();
  }

  // ── Video Feed ────────────────────────────────────────────────

  Future<void> cacheVideoFeed(
      int hskLevel, List<VideoSegmentModel> segments) async {
    final list = segments
        .map((s) => {'id': s.videoId, ...s.toCacheMap()})
        .toList();
    await _feedBox.put('hsk_$hskLevel', jsonEncode(list));
  }

  List<VideoSegmentModel>? loadCachedVideoFeed(int hskLevel) {
    final raw = _feedBox.get('hsk_$hskLevel');
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) {
            final map = item as Map<String, dynamic>;
            final id = map['id'] as String? ?? '';
            return VideoSegmentModel.fromCache(id, map);
          })
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheVideoSegment(VideoSegmentModel segment) async {
    final json = jsonEncode({'id': segment.videoId, ...segment.toCacheMap()});
    await _feedBox.put('seg_${segment.videoId}', json);
  }

  VideoSegmentModel? loadCachedSegment(String videoId) {
    final raw = _feedBox.get('seg_$videoId');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return VideoSegmentModel.fromCache(videoId, map);
    } catch (_) {
      return null;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _dictBox.clear();
    await _feedBox.clear();
  }
}
