import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';

class SocialRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SocialRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<List<PostModel>> watchFeed(List<String> followingIds) {
    if (followingIds.isEmpty) return Stream.value([]);

    // Firestore 'in' query supports up to 30 values.
    final ids = followingIds.take(30).toList();

    return _firestore
        .collection('posts')
        .where('authorId', whereIn: ids)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromFirestore).toList());
  }

  Future<void> createPost(PostModel post) async {
    await _firestore
        .collection('posts')
        .doc(post.postId)
        .set(post.toFirestore());
  }

  Future<void> toggleLike(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _firestore.collection('posts').doc(postId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final likes = List<String>.from(snap.data()?['likes'] ?? []);
    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> followUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == targetUid) return;

    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'following': FieldValue.arrayUnion([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers': FieldValue.arrayUnion([uid]),
    });
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'following': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers': FieldValue.arrayRemove([uid]),
    });
    await batch.commit();
  }
}
