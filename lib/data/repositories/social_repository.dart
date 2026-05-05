import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/game_request_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class SocialRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SocialRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Feed ────────────────────────────────────────────────────────────────────

  Stream<List<PostModel>> watchFeed(List<String> followingIds) {
    if (followingIds.isEmpty) return Stream.value([]);
    final ids = followingIds.take(30).toList();
    return _firestore
        .collection('posts')
        .where('authorId', whereIn: ids)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromFirestore).toList());
  }

  String generatePostId() => _firestore.collection('posts').doc().id;

  Future<void> createPost(PostModel post) async {
    await _firestore.collection('posts').doc(post.postId).set(post.toFirestore());
  }

  Future<void> toggleLike(String postId) async {
    if (_uid.isEmpty) return;
    final ref = _firestore.collection('posts').doc(postId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final likes = List<String>.from(snap.data()?['likes'] ?? []);
    if (likes.contains(_uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([_uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([_uid])});
    }
  }

  // ── Follow / Unfollow ───────────────────────────────────────────────────────

  Future<void> followUser(String targetUid) async {
    if (_uid.isEmpty || _uid == targetUid) return;
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(_uid), {
      'following': FieldValue.arrayUnion([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers': FieldValue.arrayUnion([_uid]),
    });
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    if (_uid.isEmpty) return;
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(_uid), {
      'following': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers': FieldValue.arrayRemove([_uid]),
    });
    await batch.commit();
  }

  // ── User Search ─────────────────────────────────────────────────────────────

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    // Firestore prefix query: displayName >= q AND displayName < q + ''
    final snap = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$q')
        .limit(20)
        .get();
    return snap.docs
        .map(UserModel.fromFirestore)
        .where((u) => u.uid != _uid)
        .toList();
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────────

  Future<List<UserModel>> loadLeaderboard({int? hskLevel, int limit = 20}) async {
    Query<Map<String, dynamic>> q = _firestore.collection('users');
    if (hskLevel != null) q = q.where('hskLevel', isEqualTo: hskLevel);
    final snap = await q
        .orderBy('stats.totalScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  // ── Online Status ────────────────────────────────────────────────────────────

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_uid.isEmpty) return;
    await _firestore.collection('users').doc(_uid).update({'isOnline': isOnline});
  }

  // ── Game Requests ────────────────────────────────────────────────────────────

  Future<void> sendGameRequest(String toUid, int hskLevel) async {
    if (_uid.isEmpty || _uid == toUid) return;
    final ref = _firestore.collection('gameRequests').doc();
    final request = GameRequestModel(
      requestId: ref.id,
      fromUid: _uid,
      toUid: toUid,
      hskLevel: hskLevel,
      status: GameRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    await ref.set(request.toFirestore());
  }

  Future<void> respondToGameRequest(String requestId, bool accepted) async {
    await _firestore.collection('gameRequests').doc(requestId).update({
      'status': accepted ? GameRequestStatus.accepted.name : GameRequestStatus.declined.name,
    });
  }

  Stream<List<GameRequestModel>> watchIncomingRequests() {
    if (_uid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('gameRequests')
        .where('toUid', isEqualTo: _uid)
        .where('status', isEqualTo: GameRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GameRequestModel.fromFirestore).toList());
  }
}
