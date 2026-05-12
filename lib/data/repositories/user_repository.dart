import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class UserRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Stream<UserModel?> watchCurrentUser() {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return Stream.value(null);
    return _db
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : UserModel.fromMap(rows.first));
  }

  Future<UserModel?> loadUser(String uid) async {
    final data =
        await _db.from('users').select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Future<void> createUser(UserModel user) async {
    await _db.from('users').upsert(user.toMap());
  }

  Future<void> updateUserStats(String uid, UserStats stats) async {
    await _db.from('users').update({'stats': stats.toMap()}).eq('id', uid);
  }

  Future<void> markWordLearned(String uid, String wordId) async {
    final data = await _db
        .from('users')
        .select('learned_words')
        .eq('id', uid)
        .single();
    final words = List<String>.from(data['learned_words'] ?? []);
    if (!words.contains(wordId)) {
      words.add(wordId);
      await _db.from('users').update({'learned_words': words}).eq('id', uid);
    }
  }

  Future<void> updateHskLevel(String uid, int newLevel) async {
    await _db.from('users').update({'hsk_level': newLevel}).eq('id', uid);
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    await _db.from('users').update({'display_name': newName}).eq('id', uid);
    await _db.auth.updateUser(UserAttributes(data: {'display_name': newName}));
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
    await _db.from('users').update({
      'display_name': displayName,
      'last_name': lastName,
      if (birthday != null) 'birthday': birthday.toIso8601String(),
      'gender': gender,
      'mother_tongue': motherTongue,
      'notifications_enabled': notificationsEnabled,
    }).eq('id', uid);
    await _db.auth.updateUser(UserAttributes(data: {'display_name': displayName}));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _db.auth.currentUser;
    if (user?.email == null) throw Exception('Not authenticated');
    await _db.auth.signInWithPassword(
      email: user!.email!,
      password: currentPassword,
    );
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _db.from('users').update({'photo_url': photoUrl}).eq('id', uid);
  }

  Future<void> deleteAccount(String uid) async {
    await _db.from('users').delete().eq('id', uid);
    await _db.auth.signOut();
  }
}
