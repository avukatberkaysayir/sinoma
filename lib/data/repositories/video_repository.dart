import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/video_segment_model.dart';

class VideoRepository {
  final FirebaseFirestore _firestore;

  VideoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<VideoSegmentModel>> loadSegmentsForLevel(int hskLevel) async {
    final snap = await _firestore
        .collection('videos')
        .where('hskLevel', isLessThanOrEqualTo: hskLevel + 1)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snap.docs.map(VideoSegmentModel.fromFirestore).toList();
  }

  Future<VideoSegmentModel?> loadSegment(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) return null;
    return VideoSegmentModel.fromFirestore(doc);
  }

  Future<List<VideoSegmentModel>> loadSegmentsForGame(int hskLevel, {int limit = 10}) async {
    final snap = await _firestore
        .collection('videos')
        .where('hskLevel', isEqualTo: hskLevel)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();

    final segments = snap.docs.map(VideoSegmentModel.fromFirestore).toList()..shuffle();
    return segments;
  }
}
