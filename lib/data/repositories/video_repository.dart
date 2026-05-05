import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/video_segment_model.dart';
import '../services/cache_service.dart';

class VideoRepository {
  final FirebaseFirestore _firestore;
  final CacheService _cache;

  VideoRepository({FirebaseFirestore? firestore, required CacheService cache})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _cache = cache;

  Future<List<VideoSegmentModel>> loadSegmentsForLevel(int hskLevel) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('hskLevel', isLessThanOrEqualTo: hskLevel + 1)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final segments = snap.docs.map(VideoSegmentModel.fromFirestore).toList();
      await _cache.cacheVideoFeed(hskLevel, segments);
      return segments;
    } catch (_) {
      return _cache.loadCachedVideoFeed(hskLevel) ?? [];
    }
  }

  Future<VideoSegmentModel?> loadSegment(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return null;
      final segment = VideoSegmentModel.fromFirestore(doc);
      await _cache.cacheVideoSegment(segment);
      return segment;
    } catch (_) {
      return _cache.loadCachedSegment(videoId);
    }
  }

  Future<List<VideoSegmentModel>> loadSegmentsByCategory(
    int hskLevel,
    String quizCategory,
  ) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('hskLevel', isLessThanOrEqualTo: hskLevel + 1)
          .where('isActive', isEqualTo: true)
          .where('quizCategory', isEqualTo: quizCategory)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snap.docs.map(VideoSegmentModel.fromFirestore).toList();
    } catch (_) {
      final all = _cache.loadCachedVideoFeed(hskLevel) ?? [];
      return all.where((v) => v.quizCategory.name == quizCategory).toList();
    }
  }

  Future<List<VideoSegmentModel>> loadSegmentsForGame(int hskLevel,
      {int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('hskLevel', isEqualTo: hskLevel)
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      final segments =
          snap.docs.map(VideoSegmentModel.fromFirestore).toList()..shuffle();
      return segments;
    } catch (_) {
      final cached = _cache.loadCachedVideoFeed(hskLevel) ?? [];
      return (cached..shuffle()).take(limit).toList();
    }
  }
}
