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

  // ── Learning-path progress (users.path_progress jsonb) ──────────────────────

  Future<Map<String, dynamic>> loadPathProgress() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return {};
    final data = await _db
        .from('users')
        .select('path_progress')
        .eq('id', uid)
        .maybeSingle();
    final p = data?['path_progress'];
    return p is Map ? Map<String, dynamic>.from(p) : {};
  }

  Future<void> savePhaseResult(
    String phaseKey, {
    required int correct,
    required int total,
    required bool done,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final current = await loadPathProgress();
    final prev = current[phaseKey] as Map?;
    // Keep the best score; never un-complete a finished phase.
    final bestCorrect = (prev?['correct'] as int?) ?? 0;
    current[phaseKey] = {
      'correct': correct > bestCorrect ? correct : bestCorrect,
      'total': total,
      'done': done || (prev?['done'] == true),
    };
    current['__meta'] = _updatedMeta(current['__meta'], wrong: total - correct);
    await _db.from('users').update({'path_progress': current}).eq('id', uid);
  }

  // Apply heart loss (per wrong answer, with 4h refill) + daily streak bump.
  static const int _maxHearts = 5;
  static const int _refillMins = 4 * 60;

  Map<String, dynamic> _updatedMeta(dynamic raw, {required int wrong}) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final now = DateTime.now();

    // Live hearts (apply refill since heartsTs), then subtract wrong answers.
    var hearts = (m['hearts'] as int?) ?? _maxHearts;
    final ts = DateTime.tryParse((m['heartsTs'] as String?) ?? '');
    if (hearts < _maxHearts && ts != null) {
      hearts = (hearts + now.difference(ts).inMinutes ~/ _refillMins)
          .clamp(0, _maxHearts);
    }
    final newHearts = (hearts - (wrong < 0 ? 0 : wrong)).clamp(0, _maxHearts);
    m['hearts'] = newHearts;
    // Reset the refill clock only when hearts drop below full.
    if (newHearts < _maxHearts) {
      m['heartsTs'] = now.toIso8601String();
    } else {
      m.remove('heartsTs');
    }

    // Daily streak.
    String dayKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final today = dayKey(now);
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final last = m['lastActive'] as String?;
    if (last == today) {
      m['streak'] = (m['streak'] as int?) ?? 1;
    } else if (last == yesterday) {
      m['streak'] = ((m['streak'] as int?) ?? 0) + 1;
    } else {
      m['streak'] = 1;
    }
    m['lastActive'] = today;
    return m;
  }

  // Top users by total score — for the leaderboard ("Puan Tabloları").
  Future<List<Map<String, dynamic>>> loadLeaderboard({int limit = 25}) async {
    final data = await _db
        .from('users')
        .select('id,display_name,photo_url,stats')
        .limit(300);
    final list = List<Map<String, dynamic>>.from(data);
    int score(Map<String, dynamic> u) =>
        ((u['stats'] as Map?)?['totalScore'] as num?)?.toInt() ?? 0;
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list.take(limit).toList();
  }

  // Refill hearts to full (free, for now) — Mağaza > Canları Yenile.
  Future<void> refillHearts() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final pp = await loadPathProgress();
    final m = pp['__meta'] is Map
        ? Map<String, dynamic>.from(pp['__meta'] as Map)
        : <String, dynamic>{};
    m['hearts'] = _maxHearts;
    m.remove('heartsTs');
    pp['__meta'] = m;
    await _db.from('users').update({'path_progress': pp}).eq('id', uid);
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
    // auth.updateUser() deliberately omitted: it triggers onAuthStateChange →
    // GoRouter rebuild → WebSocket reconnect → stream briefly emits null → photo disappears.
    // displayName is read from the users table, not auth metadata.
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
