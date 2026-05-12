import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_request_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class SocialRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid => _db.auth.currentUser?.id ?? '';

  // ── Feed ────────────────────────────────────────────────────────────────────

  Stream<List<PostModel>> watchFeed(List<String> followingIds) {
    if (followingIds.isEmpty) return Stream.value([]);

    final controller = StreamController<List<PostModel>>.broadcast();
    final ids = followingIds.take(30).toList();

    Future<void> load() async {
      try {
        final data = await _db
            .from('posts')
            .select()
            .inFilter('author_id', ids)
            .order('timestamp', ascending: false)
            .limit(30);
        if (!controller.isClosed) {
          controller.add(data.map(PostModel.fromMap).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    load();

    final channel = _db
        .channel('posts-feed-${_uid.hashCode}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (_) => load(),
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  String generatePostId() {
    final rand = Random.secure();
    final bytes = List.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> createPost(PostModel post) async {
    await _db.from('posts').upsert(post.toMap());
  }

  Future<void> toggleLike(String postId) async {
    if (_uid.isEmpty) return;
    final data = await _db
        .from('posts')
        .select('likes')
        .eq('id', postId)
        .single();
    final likes = List<String>.from(data['likes'] ?? []);
    if (likes.contains(_uid)) {
      likes.remove(_uid);
    } else {
      likes.add(_uid);
    }
    await _db.from('posts').update({'likes': likes}).eq('id', postId);
  }

  // ── Follow / Unfollow ───────────────────────────────────────────────────────

  Future<void> followUser(String targetUid) async {
    if (_uid.isEmpty || _uid == targetUid) return;
    final myData = await _db
        .from('users')
        .select('following')
        .eq('id', _uid)
        .single();
    final myFollowing = List<String>.from(myData['following'] ?? []);
    if (!myFollowing.contains(targetUid)) {
      myFollowing.add(targetUid);
      await _db.from('users').update({'following': myFollowing}).eq('id', _uid);
    }
    final theirData = await _db
        .from('users')
        .select('followers')
        .eq('id', targetUid)
        .single();
    final theirFollowers = List<String>.from(theirData['followers'] ?? []);
    if (!theirFollowers.contains(_uid)) {
      theirFollowers.add(_uid);
      await _db
          .from('users')
          .update({'followers': theirFollowers})
          .eq('id', targetUid);
    }
  }

  Future<void> unfollowUser(String targetUid) async {
    if (_uid.isEmpty) return;
    final myData = await _db
        .from('users')
        .select('following')
        .eq('id', _uid)
        .single();
    final myFollowing = List<String>.from(myData['following'] ?? []);
    myFollowing.remove(targetUid);
    await _db.from('users').update({'following': myFollowing}).eq('id', _uid);

    final theirData = await _db
        .from('users')
        .select('followers')
        .eq('id', targetUid)
        .single();
    final theirFollowers = List<String>.from(theirData['followers'] ?? []);
    theirFollowers.remove(_uid);
    await _db
        .from('users')
        .update({'followers': theirFollowers})
        .eq('id', targetUid);
  }

  // ── User Search ─────────────────────────────────────────────────────────────

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _db
        .from('users')
        .select()
        .ilike('display_name', '${query.trim()}%')
        .limit(20);
    return data
        .map(UserModel.fromMap)
        .where((u) => u.uid != _uid)
        .toList();
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────────

  Future<List<UserModel>> loadLeaderboard(
      {int? hskLevel, int limit = 20}) async {
    var query = _db.from('users').select();
    if (hskLevel != null) query = query.eq('hsk_level', hskLevel);
    final data = await query.limit(limit * 2);
    final users = data.map(UserModel.fromMap).toList()
      ..sort((a, b) => b.stats.totalScore.compareTo(a.stats.totalScore));
    return users.take(limit).toList();
  }

  // ── Online Status ────────────────────────────────────────────────────────────

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_uid.isEmpty) return;
    await _db.from('users').update({'is_online': isOnline}).eq('id', _uid);
  }

  // ── Game Requests ────────────────────────────────────────────────────────────

  Future<void> sendGameRequest(String toUid, int hskLevel) async {
    if (_uid.isEmpty || _uid == toUid) return;
    final request = GameRequestModel(
      requestId: generatePostId(),
      fromUid: _uid,
      toUid: toUid,
      hskLevel: hskLevel,
      status: GameRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    await _db.from('game_requests').upsert(request.toMap());
  }

  Future<void> respondToGameRequest(String requestId, bool accepted) async {
    await _db.from('game_requests').update({
      'status': accepted
          ? GameRequestStatus.accepted.name
          : GameRequestStatus.declined.name,
    }).eq('id', requestId);
  }

  Stream<List<GameRequestModel>> watchIncomingRequests() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db
        .from('game_requests')
        .stream(primaryKey: ['id'])
        .eq('to_uid', _uid)
        .map((rows) => rows
            .where((r) => r['status'] == GameRequestStatus.pending.name)
            .map(GameRequestModel.fromMap)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }
}
