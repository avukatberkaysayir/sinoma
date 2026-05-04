import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<UserModel?> watchCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
  }

  Future<UserModel?> loadUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore());
  }

  Future<void> updateUserStats(String uid, UserStats stats) async {
    await _firestore.collection('users').doc(uid).update({
      'stats': stats.toMap(),
    });
  }

  Future<void> markWordLearned(String uid, String wordId) async {
    await _firestore.collection('users').doc(uid).update({
      'learnedWords': FieldValue.arrayUnion([wordId]),
    });
  }

  Future<void> updateHskLevel(String uid, int newLevel) async {
    await _firestore.collection('users').doc(uid).update({'hskLevel': newLevel});
  }
}
