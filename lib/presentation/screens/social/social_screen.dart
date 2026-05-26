import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/game_request_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../providers/user_provider.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isWide(context);

    if (isWide) {
      return Scaffold(
        body: ConstrainedPage(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 3, child: _FeedTab()),
              const VerticalDivider(width: 1, color: AppColors.surface),
              Expanded(
                flex: 2,
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: TabBar(
                              indicatorColor: AppColors.primary,
                              tabs: [
                                Tab(text: 'Leaderboard'),
                                Tab(text: 'Friends'),
                              ],
                            ),
                          ),
                          _IncomingRequestsBadge(),
                        ],
                      ),
                      const Expanded(
                        child: TabBarView(
                          children: [
                            _LeaderboardTab(),
                            _FriendsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Feed'),
                    Tab(text: 'Leaderboard'),
                    Tab(text: 'Friends'),
                  ],
                ),
              ),
              _IncomingRequestsBadge(),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _FeedTab(),
                _LeaderboardTab(),
                _FriendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incoming Requests Badge ────────────────────────────────────────────────────

class _IncomingRequestsBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.sports_esports_outlined),
          tooltip: 'Game Challenges',
          onPressed: () => _showRequestsSheet(context, ref, requests),
        ),
        if (requests.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  void _showRequestsSheet(
      BuildContext context, WidgetRef ref, List<GameRequestModel> requests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceVariant,
      builder: (_) => _RequestsSheet(requests: requests),
    );
  }
}

class _RequestsSheet extends ConsumerWidget {
  final List<GameRequestModel> requests;
  const _RequestsSheet({required this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No pending game challenges')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final req = requests[i];
        return ListTile(
          leading: const Icon(Icons.sports_esports, color: AppColors.primary),
          title: Text('Challenge from ${req.fromUid.substring(0, 8)}…'),
          subtitle: Text('HSK ${req.hskLevel}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: AppColors.correctAnswer),
                onPressed: () {
                  ref
                      .read(socialActionsProvider.notifier)
                      .respondToChallenge(req.requestId, true);
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: AppColors.wrongAnswer),
                onPressed: () {
                  ref
                      .read(socialActionsProvider.notifier)
                      .respondToChallenge(req.requestId, false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Feed Tab ──────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.user.id ?? '';

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'Follow other learners to see their posts here.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PostCard(post: posts[i], currentUid: uid),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: AppColors.primary,
                onPressed: () => _showCreatePostSheet(context, ref),
                child: const Icon(Icons.edit),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePostSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceVariant,
      builder: (_) => const _CreatePostSheet(),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final PostModel post;
  final String currentUid;
  const _PostCard({required this.post, required this.currentUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = post.hasLiked(currentUid);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PostTypeIcon(type: post.postType),
              const SizedBox(width: 8),
              Text(
                post.authorId.substring(0, 8),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(post.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, style: const TextStyle(color: AppColors.onSurface)),
          if (post.metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MetadataChips(metadata: post.metadata),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => ref
                    .read(socialActionsProvider.notifier)
                    .toggleLike(post.postId),
                child: Row(
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: liked ? AppColors.primary : AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likeCount}',
                      style: const TextStyle(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _PostTypeIcon extends StatelessWidget {
  final PostType type;
  const _PostTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      PostType.achievement => (Icons.emoji_events, AppColors.premiumGold),
      PostType.score => (Icons.leaderboard, AppColors.primary),
      PostType.challenge => (Icons.sports_esports, Colors.blue),
      PostType.text => (Icons.chat_bubble_outline, AppColors.onSurfaceMuted),
    };
    return Icon(icon, size: 16, color: color);
  }
}

class _MetadataChips extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _MetadataChips({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final chips = metadata.entries.take(3).map((e) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${e.key}: ${e.value}',
          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
        ),
      );
    }).toList();

    return Wrap(spacing: 6, children: chips);
  }
}

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet();

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(socialActionsProvider.notifier).createPost(content: text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share with the community',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'What did you learn today?',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab();

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  int? _selectedHsk;

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(leaderboardProvider(_selectedHsk));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.user.id ?? '';

    return Column(
      children: [
        _HskFilterBar(
          selected: _selectedHsk,
          onSelect: (lvl) => setState(() => _selectedHsk = lvl),
        ),
        Expanded(
          child: board.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (users) => ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              itemBuilder: (_, i) => _LeaderboardRow(
                rank: i + 1,
                user: users[i],
                isCurrentUser: users[i].uid == currentUid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HskFilterBar extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onSelect;
  const _HskFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
            selectedColor: AppColors.primary.withValues(alpha: 0.3),
          ),
          ...List.generate(6, (i) => i + 1).map((lvl) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text('HSK $lvl'),
                  selected: selected == lvl,
                  onSelected: (_) => onSelect(selected == lvl ? null : lvl),
                  selectedColor: AppColors.forHskLevel(lvl).withValues(alpha: 0.3),
                ),
              )),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final UserModel user;
  final bool isCurrentUser;
  const _LeaderboardRow({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppColors.primary, width: 1)
            : null,
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surface,
            backgroundImage:
                user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            child: user.photoUrl.isEmpty
                ? Text(user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName.isEmpty ? 'Learner' : user.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (user.isOnline) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.correctAnswer,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'HSK ${user.hskLevel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.forHskLevel(user.hskLevel),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${user.stats.totalScore}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.premiumGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      const medals = ['🥇', '🥈', '🥉'];
      return Text(medals[rank - 1], style: const TextStyle(fontSize: 20));
    }
    return SizedBox(
      width: 28,
      child: Text(
        '#$rank',
        style: const TextStyle(
          color: AppColors.onSurfaceMuted,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Friends Tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab();

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final searchResults = ref.watch(userSearchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search learners…',
            onChanged: (q) {
              if (q.isEmpty) {
                setState(() => _searching = false);
                ref.read(userSearchProvider.notifier).clear();
              } else {
                setState(() => _searching = true);
                ref.read(userSearchProvider.notifier).search(q);
              }
            },
            leading: const Icon(Icons.search),
            trailing: [
              if (_searching)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searching = false);
                    ref.read(userSearchProvider.notifier).clear();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: _searching
              ? _SearchResultsList(results: searchResults, currentUser: currentUser)
              : _FollowingList(currentUser: currentUser),
        ),
      ],
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final AsyncValue<List<UserModel>> results;
  final UserModel? currentUser;
  const _SearchResultsList({required this.results, required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Search error: $e')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) => _UserTile(
            user: users[i],
            isFollowing:
                currentUser?.following.contains(users[i].uid) ?? false,
            currentHskLevel: currentUser?.hskLevel ?? 1,
          ),
        );
      },
    );
  }
}

class _FollowingList extends ConsumerWidget {
  final UserModel? currentUser;
  const _FollowingList({required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentUser == null || currentUser!.following.isEmpty) {
      return const Center(
        child: Text(
          'Search for learners above\nto follow them.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return FutureBuilder<List<UserModel?>>(
      future: Future.wait(
        currentUser!.following.take(30).map(
              (uid) => ref.read(userRepositoryProvider).loadUser(uid),
            ),
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = (snap.data ?? []).whereType<UserModel>().toList();
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) => _UserTile(
            user: users[i],
            isFollowing: true,
            currentHskLevel: currentUser?.hskLevel ?? 1,
          ),
        );
      },
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  final bool isFollowing;
  final int currentHskLevel;
  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.currentHskLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(socialActionsProvider.notifier);

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surface,
            backgroundImage:
                user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            child: user.photoUrl.isEmpty
                ? Text(user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?')
                : null,
          ),
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.correctAnswer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(user.displayName.isEmpty ? 'Learner' : user.displayName),
      subtitle: Row(
        children: [
          Text(
            'HSK ${user.hskLevel}',
            style: TextStyle(color: AppColors.forHskLevel(user.hskLevel)),
          ),
          const SizedBox(width: 8),
          Text(
            '${user.stats.totalScore} pts',
            style: const TextStyle(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFollowing && user.isOnline)
            IconButton(
              icon: const Icon(Icons.sports_esports, color: AppColors.primary),
              tooltip: 'Challenge to Duel',
              onPressed: () => _sendChallenge(context, ref, actions),
            ),
          TextButton(
            onPressed: () => isFollowing
                ? actions.unfollowUser(user.uid)
                : actions.followUser(user.uid),
            child: Text(isFollowing ? 'Unfollow' : 'Follow'),
          ),
        ],
      ),
    );
  }

  void _sendChallenge(
      BuildContext context, WidgetRef ref, SocialActionsNotifier actions) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Challenge ${user.displayName}?'),
        content: Text(
          'Send a Mandarin Duel challenge at HSK $currentHskLevel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              actions.challengeUser(user.uid, currentHskLevel);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Challenge sent to ${user.displayName}!'),
                ),
              );
            },
            child: const Text('Send Challenge'),
          ),
        ],
      ),
    );
  }
}
