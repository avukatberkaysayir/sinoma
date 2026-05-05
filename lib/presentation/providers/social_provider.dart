import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/game_request_model.dart';
import '../../data/models/post_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/social_repository.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

// ── Feed ──────────────────────────────────────────────────────────────────────

final feedProvider = StreamProvider<List<PostModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(socialRepositoryProvider).watchFeed(user.following);
});

// ── Leaderboard ───────────────────────────────────────────────────────────────

final leaderboardProvider =
    FutureProvider.family<List<UserModel>, int?>((ref, hskLevel) {
  return ref.watch(socialRepositoryProvider).loadLeaderboard(hskLevel: hskLevel);
});

// ── Incoming Game Requests ────────────────────────────────────────────────────

final incomingRequestsProvider = StreamProvider<List<GameRequestModel>>((ref) {
  return ref.watch(socialRepositoryProvider).watchIncomingRequests();
});

// ── User Search ───────────────────────────────────────────────────────────────

class UserSearchNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  UserSearchNotifier(this._repo) : super(const AsyncValue.data([]));

  final SocialRepository _repo;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.searchUsers(query));
  }

  void clear() => state = const AsyncValue.data([]);
}

final userSearchProvider =
    StateNotifierProvider.autoDispose<UserSearchNotifier, AsyncValue<List<UserModel>>>(
  (ref) => UserSearchNotifier(ref.watch(socialRepositoryProvider)),
);

// ── Social Actions ────────────────────────────────────────────────────────────

class SocialActionsNotifier extends StateNotifier<void> {
  SocialActionsNotifier(this._repo, this._ref) : super(null);

  final SocialRepository _repo;
  final Ref _ref;

  Future<void> createPost({
    required String content,
    PostType postType = PostType.text,
    Map<String, dynamic> metadata = const {},
  }) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final post = PostModel(
      postId: _repo.generatePostId(),
      authorId: uid,
      content: content,
      likes: [],
      postType: postType,
      metadata: metadata,
      timestamp: DateTime.now(),
    );
    await _repo.createPost(post);
  }

  Future<void> toggleLike(String postId) => _repo.toggleLike(postId);

  Future<void> followUser(String uid) => _repo.followUser(uid);

  Future<void> unfollowUser(String uid) => _repo.unfollowUser(uid);

  Future<void> challengeUser(String toUid, int hskLevel) =>
      _repo.sendGameRequest(toUid, hskLevel);

  Future<void> respondToChallenge(String requestId, bool accepted) =>
      _repo.respondToGameRequest(requestId, accepted);
}

final socialActionsProvider =
    StateNotifierProvider<SocialActionsNotifier, void>(
  (ref) => SocialActionsNotifier(
    ref.watch(socialRepositoryProvider),
    ref,
  ),
);
