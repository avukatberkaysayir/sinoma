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

  Future<void> updateDisplayName(String uid, String newName) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'displayName': newName});
    await _auth.currentUser?.updateDisplayName(newName);
  }

  Future<void> updateProfileDetails({
    required String uid,
    required String displayName,
    required String lastName,
    required DateTime? birthday,
    required String gender,
    required String motherTongue,
    required bool notificationsEnabled,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'displayName': displayName,
      'lastName': lastName,
      if (birthday != null) 'birthday': Timestamp.fromDate(birthday),
      'gender': gender,
      'motherTongue': motherTongue,
      'notificationsEnabled': notificationsEnabled,
    });
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not authenticated');
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'photoUrl': photoUrl});
    await _auth.currentUser?.updatePhotoURL(photoUrl);
  }

  Future<void> deleteAccount(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
    await _auth.currentUser?.delete();
  }
}
