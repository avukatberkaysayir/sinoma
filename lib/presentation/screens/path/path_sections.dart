import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cities.dart';
import '../../../core/utils/web_sfx.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/sfx_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../home/inline_player_section.dart';
import 'phase_runner_screen.dart';

// Accent + theme-aware surfaces (ink ↔ rice paper via AppColors).
const _green = Color(0xFF2EC4B6);
Color get _bg => AppColors.surface;
Color get _panel => AppColors.surfaceVariant;

// ── Video center (free watch) ─────────────────────────────────────────────────

class VideoCenter extends ConsumerWidget {
  final bool tr;
  const VideoCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the HSK test covers this page, unmount the player entirely — its
    // iframe lives fixed over the document body and would keep playing on top.
    if (ref.watch(practiceSuspendedProvider)) return const SizedBox.shrink();
    final feed = ref.watch(filteredVideoFeedProvider);
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _green)),
      error: (e, _) =>
          Center(child: Text('$e', style: TextStyle(color: AppColors.text54))),
      data: (segs) {
        if (segs.isEmpty) {
          return Center(
            child: Text(AppL10n.fromCode(ref.watch(localeProvider).languageCode).noVideosFiltered,
                style: TextStyle(color: AppColors.text54, fontSize: 15)),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: InlinePlayerSection(segments: segs),
            ),
          ),
        );
      },
    );
  }
}

class VideoFiltersRight extends ConsumerStatefulWidget {
  final bool tr;
  const VideoFiltersRight({super.key, required this.tr});

  @override
  ConsumerState<VideoFiltersRight> createState() => _VideoFiltersRightState();
}

class _VideoFiltersRightState extends ConsumerState<VideoFiltersRight> {
  String? _openGroup; // accordion: one group open at a time

  void _toggleGroup(String id) =>
      setState(() => _openGroup = _openGroup == id ? null : id);

  Future<void> _startHskTest() async {
    ref.read(practiceSuspendedProvider.notifier).state = true;
    try {
      await context.push('/hsk-test');
    } finally {
      if (mounted) {
        ref.read(practiceSuspendedProvider.notifier).state = false;
        // The saved level drives both the practice feed and the Öğren unlocks.
        ref.invalidate(currentUserProvider);
        ref.invalidate(videoFeedProvider);
        ref.invalidate(pathProgressProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final hsk = ref.watch(selectedHskFilterProvider);
    final life = ref.watch(selectedLifeCategoryProvider);
    final playlists = ref.watch(myPlaylistsProvider).valueOrNull ?? const [];
    final selPlaylist = ref.watch(selectedPlaylistProvider);
    final userLevel =
        ref.watch(currentUserProvider).valueOrNull?.hskLevel ?? 1;

    void toggleHsk(int h) {
      final n = Set<int>.from(hsk);
      n.contains(h) ? n.remove(h) : n.add(h);
      ref.read(selectedHskFilterProvider.notifier).state = n;
      ref.invalidate(videoFeedProvider);
    }

    void toggleLife(String c) {
      final n = Set<String>.from(life);
      n.contains(c) ? n.remove(c) : n.add(c);
      ref.read(selectedLifeCategoryProvider.notifier).state = n;
      ref.invalidate(videoFeedProvider);
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _startHskTest,
                icon: const Icon(Icons.quiz_rounded, size: 20),
                label: Text(AppL10n.of(context).startHskTest,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Just the current level — same size/format as the group headers.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('HSK $userLevel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _green,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 16),
            // LISTELERIM stands on its own, ABOVE the filters.
            _FilterGroup(
              id: 'playlists',
              label: AppL10n.of(context).myPlaylists,
              open: _openGroup == 'playlists',
              activeCount: selPlaylist != null ? 1 : 0,
              onToggle: _toggleGroup,
              children: [
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      AppL10n.of(context).noListsRail,
                      style: TextStyle(
                          color: AppColors.text38, fontSize: 12),
                    ),
                  )
                else
                  for (final p in playlists) ...[
                    _FilterItem(
                      label: '${p['name'] ?? ''} (${p['count'] ?? 0})',
                      selected: selPlaylist == p['id'],
                      onTap: () {
                        ref.read(selectedPlaylistProvider.notifier).state =
                            selPlaylist == p['id']
                                ? null
                                : p['id'] as String;
                      },
                    ),
                    if (selPlaylist == p['id'])
                      _PlaylistVideoList(playlistId: p['id'] as String),
                  ],
              ],
            ),
            const SizedBox(height: 12),
            Text(AppL10n.of(context).filters,
                style: TextStyle(
                    color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _FilterGroup(
              id: 'hsk',
              label: 'HSK',
              open: _openGroup == 'hsk',
              activeCount: hsk.length,
              onToggle: _toggleGroup,
              children: [
                for (var h = 1; h <= 6; h++)
                  _FilterItem(
                    label: 'HSK $h',
                    selected: hsk.contains(h),
                    onTap: () => toggleHsk(h),
                  ),
              ],
            ),
            _FilterGroup(
              id: 'life',
              label: AppL10n.of(context).topicGroup,
              open: _openGroup == 'life',
              activeCount: life.length,
              onToggle: _toggleGroup,
              children: [
                for (final c in LifeCategory.values)
                  _FilterItem(
                    label: LifeCategory.labelFor(c.name, isTr: tr),
                    selected: life.contains(c.name),
                    onTap: () => toggleLife(c.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// The selected playlist's clips: static thumb + title + HSK; 10 rows visible,
// the rest scroll.
class _PlaylistVideoList extends ConsumerWidget {
  final String playlistId;
  const _PlaylistVideoList({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows =
        ref.watch(playlistVideosProvider(playlistId)).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    const rowH = 48.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: rowH * 10),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final v = rows[i];
          final yt = v['youtube_id'] as String? ?? '';
          return SizedBox(
            height: rowH,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: yt.isEmpty
                      ? Container(
                          width: 64, height: 38, color: _bg,
                          child: Icon(Icons.movie_outlined,
                              size: 16, color: AppColors.text38))
                      : Image.network(
                          'https://img.youtube.com/vi/$yt/default.jpg',
                          width: 64,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 64, height: 38, color: _bg),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (v['transcription'] as String? ?? '')
                        .replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('HSK ${v['hsk_level'] ?? '-'}',
                      style: const TextStyle(
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// One collapsible filter group (accordion row + its option list).
class _FilterGroup extends StatelessWidget {
  final String id;
  final String label;
  final bool open;
  final int activeCount;
  final void Function(String) onToggle;
  final List<Widget> children;
  const _FilterGroup({
    required this.id,
    required this.label,
    required this.open,
    required this.activeCount,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: activeCount > 0 ? _green : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onToggle(id),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                  if (activeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$activeCount',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.text54, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(color: AppColors.border, height: 1),
                      ...children,
                      const SizedBox(height: 6),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// One selectable row inside a filter group (check-style, multi-select).
class _FilterItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterItem(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: selected ? _green.withValues(alpha: 0.12) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: selected
                  ? const Icon(Icons.check_rounded, size: 15, color: _green)
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? _green : AppColors.text70,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leaderboard ───────────────────────────────────────────────────────────────

class LeaderboardCenter extends ConsumerStatefulWidget {
  final bool tr;
  const LeaderboardCenter({super.key, required this.tr});

  @override
  ConsumerState<LeaderboardCenter> createState() => _LeaderboardCenterState();
}

class _LeaderboardCenterState extends ConsumerState<LeaderboardCenter> {
  int _tab = 0; // 0 = Ligim, 1 = Arkadaşlarım, 2 = Elmas Ligi
  String? _viewUid; // a league member's public profile fills the centre

  void _openFriendSearch() {
    showDialog(
        context: context,
        builder: (_) => _FriendSearchDialog(tr: widget.tr));
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final myUid = Supabase.instance.client.auth.currentUser?.id;

    if (_viewUid != null) {
      return _PublicProfileView(
        uid: _viewUid!,
        tr: tr,
        onBack: () => setState(() => _viewUid = null),
      );
    }

    Widget tabChip(int i, String label, IconData icon) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? _green.withValues(alpha: 0.15) : _panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on ? _green : AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: on ? _green : AppColors.text54),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: on ? _green : AppColors.text70,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // All 12 zodiac tiers, scrollable (5 in view): reached tiers
                // show their animal, the rest sit matte like locked units.
                const _LeagueStrip(),
                const SizedBox(height: 16),
                Row(children: [
                  tabChip(0, AppL10n.of(context).myLeague,
                      Icons.shield_rounded),
                  const SizedBox(width: 8),
                  tabChip(1, AppL10n.of(context).friendsTab,
                      Icons.group_rounded),
                  const SizedBox(width: 8),
                  tabChip(2, AppL10n.of(context).dragonTab,
                      Icons.diamond_rounded),
                ]),
                const SizedBox(height: 20),
                if (_tab == 0)
                  _LeagueTab(
                      tr: tr,
                      myUid: myUid,
                      onMember: (uid) => setState(() => _viewUid = uid)),
                if (_tab == 1)
                  _FriendsTab(
                      tr: tr, myUid: myUid, onSearch: _openFriendSearch),
                if (_tab == 2) _DiamondsTab(tr: tr, myUid: myUid),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Public profile (league member tap-through) ────────────────────────────────
// Fills the leaderboard centre; back returns to the league list. Friend
// add/remove lives HERE rather than in a popup.

class _PublicProfileView extends ConsumerStatefulWidget {
  final String uid;
  final bool tr;
  final VoidCallback onBack;
  const _PublicProfileView(
      {required this.uid, required this.tr, required this.onBack});

  @override
  ConsumerState<_PublicProfileView> createState() =>
      _PublicProfileViewState();
}

class _PublicProfileViewState extends ConsumerState<_PublicProfileView> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  bool? _isFriend;
  bool _requestSent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(userRepositoryProvider)
        .loadPublicProfile(widget.uid)
        .then((p) {
      if (mounted) {
        setState(() {
          _p = p;
          _loading = false;
        });
      }
    });
  }

  Future<void> _toggleFriend() async {
    if (_busy) return;
    final was = _isFriend ?? false;
    setState(() => _busy = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      if (was) {
        setState(() => _isFriend = false);
        await repo.removeFriend(widget.uid);
        ref.invalidate(friendsLeaderboardProvider);
      } else {
        // Consent-based: a request goes out; the friendship starts when the
        // other side accepts it from their profile.
        setState(() => _requestSent = true);
        await repo.sendFriendRequest(widget.uid);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    _isFriend ??= (ref.watch(friendsLeaderboardProvider).valueOrNull ??
            const [])
        .any((f) => f['id'] == widget.uid);

    Widget statTile(IconData icon, Color color, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text54, fontSize: 11)),
              ],
            ),
          ),
        ]),
      );
    }

    final p = _p;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.text70, size: 26),
            tooltip: l10n.myLeague,
            onPressed: widget.onBack,
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: _green)),
          )
        else if (p == null)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
                child: Text(l10n.failedLbl,
                    style: TextStyle(color: AppColors.text54))),
          )
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Builder(builder: (context) {
                final photo = p['photo_url'] as String? ?? '';
                final name = (p['display_name'] as String?)?.trim() ?? '';
                final username = p['username'] as String? ?? '';
                final lg = ((p['league'] as num?)?.toInt() ?? 1)
                    .clamp(1, kLeagueCount);
                final created = DateTime.tryParse(
                    p['created_at'] as String? ?? '');
                return Column(
                  children: [
                    // Seal-ringed avatar, same identity as the own profile.
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFE0442C), width: 3),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD4A33D), width: 1),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: _bg,
                          backgroundImage:
                              photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty
                              ? Icon(Icons.person,
                                  color: AppColors.text38, size: 44)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(name.isNotEmpty ? name : l10n.studentFallback,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    if (username.isNotEmpty)
                      Text('@$username',
                          style: TextStyle(
                              color: AppColors.text54, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (created != null)
                      Text(l10n.joinedOn(created.month, created.year),
                          style: TextStyle(
                              color: AppColors.text38, fontSize: 12)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          _busy || _requestSent ? null : _toggleFriend,
                      icon: Icon(
                          _isFriend == true
                              ? Icons.person_remove_outlined
                              : (_requestSent
                                  ? Icons.hourglass_top_rounded
                                  : Icons.person_add_alt_1_rounded),
                          size: 18),
                      label: Text(_isFriend == true
                          ? l10n.removeLbl
                          : (_requestSent
                              ? l10n.requestSent
                              : l10n.addLbl)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isFriend == true || _requestSent
                            ? AppColors.locked
                            : _green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(
                        child: statTile(
                            Icons.school_rounded,
                            const Color(0xFF2EC4B6),
                            'HSK',
                            'HSK ${p['hsk_level'] ?? 1}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: statTile(
                            Icons.shield_rounded,
                            kLeagueColors[lg - 1],
                            l10n.myLeague,
                            '${kLeagueEmojis[lg - 1]} ${l10n.leagueName(lg)}'),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: statTile(
                            Icons.bolt_rounded,
                            const Color(0xFFFFC800),
                            l10n.leagueHowTitle,
                            '${p['weekly_score'] ?? 0}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: statTile(
                            Icons.diamond_rounded,
                            const Color(0xFF1CB0F6),
                            l10n.dragonTab,
                            '${p['diamonds'] ?? 0}'),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    statTile(Icons.emoji_events_rounded,
                        const Color(0xFFD4A33D), l10n.statsPoints,
                        '${p['total_score'] ?? 0}'),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ── League strip: the whole 12-tier zodiac ladder ─────────────────────────────
// Horizontal, 5 tiers per view. Tiers you have reached (≤ current league)
// show their animal in full colour; the ones ahead are matte with a lock —
// the same visual language as locked path units.

class _LeagueStrip extends ConsumerStatefulWidget {
  const _LeagueStrip();

  @override
  ConsumerState<_LeagueStrip> createState() => _LeagueStripState();
}

class _LeagueStripState extends ConsumerState<_LeagueStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Page by five tiers — the arrows are the only way to move on devices
  // without horizontal wheel/drag affordance.
  void _page(int dir, double itemW) {
    final target = (_scroll.offset + dir * itemW * 5)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final rows = ref.watch(leagueGroupProvider).valueOrNull ?? const [];
    final lg = rows.isEmpty
        ? 1
        : ((rows.firstWhere((r) => r['id'] == myUid,
                        orElse: () => rows.first)['league'] as num?)
                    ?.toInt() ??
                1)
            .clamp(1, kLeagueCount);
    final l10n = AppL10n.of(context);

    return SizedBox(
      height: 96,
      child: LayoutBuilder(builder: (context, c) {
        const arrowW = 34.0;
        final itemW = (c.maxWidth - 2 * arrowW) / 5; // five tiers per view
        Widget arrow(IconData icon, int dir) => SizedBox(
              width: arrowW,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(icon, color: AppColors.text54, size: 26),
                onPressed: () => _page(dir, itemW),
              ),
            );
        final list = ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: kLeagueCount,
          itemBuilder: (_, i) {
            final tier = i + 1;
            final reached = tier <= lg;
            final current = tier == lg;
            final color = kLeagueColors[i];
            return SizedBox(
              width: itemW,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current
                              ? color.withValues(alpha: 0.18)
                              : Colors.transparent,
                          border: Border.all(
                              color: current
                                  ? color
                                  : (reached
                                      ? color.withValues(alpha: 0.55)
                                      : AppColors.locked),
                              width: current ? 2.5 : 1.5),
                        ),
                        child: reached
                            ? Text(kLeagueEmojis[i],
                                style: const TextStyle(fontSize: 26))
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 26, //
                                  0.2126, 0.7152, 0.0722, 0, 30, //
                                  0.2126, 0.7152, 0.0722, 0, 28, //
                                  0, 0, 0, 0.55, 0,
                                ]),
                                child: Text(kLeagueEmojis[i],
                                    style: const TextStyle(fontSize: 26)),
                              ),
                      ),
                      if (!reached)
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: Text('🔒', style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(l10n.leagueName(tier),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: current
                              ? color
                              : (reached ? AppColors.text70 : AppColors.text38),
                          fontSize: 11,
                          fontWeight:
                              current ? FontWeight.w800 : FontWeight.w600)),
                ],
              ),
            );
          },
        );
        return Row(children: [
          arrow(Icons.chevron_left_rounded, -1),
          Expanded(child: list),
          arrow(Icons.chevron_right_rounded, 1),
        ]);
      }),
    );
  }
}

// ── Ligim: the 30-user weekly cohort ──────────────────────────────────────────

class _LeagueTab extends ConsumerWidget {
  final bool tr;
  final String? myUid;
  final void Function(String uid)? onMember;
  const _LeagueTab({required this.tr, required this.myUid, this.onMember});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(leagueGroupProvider);
    return group.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _green)),
      error: (e, _) => Center(
          child:
              Text('$e', style: TextStyle(color: AppColors.text54))),
      data: (rows) {
        final lg = rows.isEmpty
            ? 1
            : ((rows.firstWhere((r) => r['id'] == myUid,
                            orElse: () => rows.first)['league'] as num?)
                        ?.toInt() ??
                    1)
                .clamp(1, kLeagueCount);
        final color = kLeagueColors[lg - 1];
        final size = rows.length;
        return Column(
          children: [
            Text(kLeagueEmojis[lg - 1],
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Text(
                '${AppL10n.of(context).leagueOf(AppL10n.of(context).leagueName(lg))}  ·  $lg/$kLeagueCount',
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(AppL10n.of(context).leagueRules,
                style:
                    TextStyle(color: AppColors.text54, fontSize: 13)),
            const SizedBox(height: 20),
            for (var i = 0; i < rows.length; i++)
              _RankRow(
                rank: i + 1,
                name: _rowName(context, rows[i]),
                sub: '@${rows[i]['username'] ?? ''}',
                photo: rows[i]['photo_url'] as String?,
                score: (rows[i]['weekly'] as num?)?.toInt() ?? 0,
                scoreIcon: Icons.bolt_rounded,
                scoreColor: const Color(0xFFFFC800),
                isMe: rows[i]['id'] == myUid,
                zone: i < 6
                    ? _RankZone.up
                    : (size > 12 && i >= size - 6)
                        ? _RankZone.down
                        : _RankZone.mid,
                onTap: rows[i]['id'] == myUid
                    ? null
                    : () => onMember?.call(rows[i]['id'] as String),
              ),
          ],
        );
      },
    );
  }
}

String _rowName(BuildContext context, Map<String, dynamic> r) {
  final n = (r['display_name'] as String?)?.trim();
  return n?.isNotEmpty == true
      ? n!
      : (r['username'] as String? ?? AppL10n.of(context).studentFallback);
}

// ── Arkadaşlarım ──────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final bool tr;
  final String? myUid;
  final VoidCallback onSearch;
  const _FriendsTab(
      {required this.tr, required this.myUid, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsLeaderboardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.person_search_rounded, size: 20),
          label: Text(AppL10n.of(context).findFriends,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        friends.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _green)),
          error: (e, _) => Text('$e',
              style: TextStyle(color: AppColors.text54)),
          data: (rows) => rows.length <= 1
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    AppL10n.of(context).noFriendsYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.text54, fontSize: 13),
                  ),
                )
              : Column(children: [
                  for (var i = 0; i < rows.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: _rowName(context, rows[i]),
                      sub: '@${rows[i]['username'] ?? ''}',
                      photo: rows[i]['photo_url'] as String?,
                      score: (rows[i]['score'] as num?)?.toInt() ?? 0,
                      scoreIcon: Icons.diamond_rounded,
                      scoreColor: const Color(0xFF1CB0F6),
                      isMe: rows[i]['id'] == myUid,
                      zone: _RankZone.mid,
                      onRemove: rows[i]['id'] == myUid
                          ? null
                          : () async {
                              await ref
                                  .read(userRepositoryProvider)
                                  .removeFriend(rows[i]['id'] as String);
                              ref.invalidate(friendsLeaderboardProvider);
                            },
                    ),
                ]),
        ),
      ],
    );
  }
}

// ── Elmas Ligi (global diamond ranking) ───────────────────────────────────────

class _DiamondsTab extends ConsumerWidget {
  final bool tr;
  final String? myUid;
  const _DiamondsTab({required this.tr, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(diamondsLeaderboardProvider);
    return Column(
      children: [
        const Icon(Icons.diamond_rounded, color: Color(0xFF7DE3F4), size: 44),
        const SizedBox(height: 6),
        Text(AppL10n.of(context).zhuangyuanTitle,
            style: const TextStyle(
                color: Color(0xFF7DE3F4),
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppL10n.of(context).zhuangyuanDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text54, fontSize: 13)),
        const SizedBox(height: 20),
        rows.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _green)),
          error: (e, _) =>
              Text('$e', style: TextStyle(color: AppColors.text54)),
          data: (list) => list.isEmpty
              ? Text(AppL10n.of(context).noDiamondsYet,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.text54, fontSize: 13))
              : Column(children: [
                  for (var i = 0; i < list.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: _rowName(context, list[i]),
                      sub: '@${list[i]['username'] ?? ''}',
                      photo: list[i]['photo_url'] as String?,
                      score: (list[i]['diamonds'] as num?)?.toInt() ?? 0,
                      scoreIcon: Icons.diamond_rounded,
                      scoreColor: const Color(0xFF7DE3F4),
                      isMe: list[i]['id'] == myUid,
                      zone: _RankZone.mid,
                    ),
                ]),
        ),
      ],
    );
  }
}

// ── Shared rank row ───────────────────────────────────────────────────────────

enum _RankZone { up, mid, down }

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String sub;
  final String? photo;
  final int score;
  final IconData scoreIcon;
  final Color scoreColor;
  final bool isMe;
  final _RankZone zone;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  const _RankRow({
    required this.rank,
    required this.name,
    required this.sub,
    required this.photo,
    required this.score,
    required this.scoreIcon,
    required this.scoreColor,
    required this.isMe,
    required this.zone,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = switch (zone) {
      _RankZone.up => _green,
      _RankZone.down => const Color(0xFFFF4B4B),
      _RankZone.mid => AppColors.text38,
    };
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? _green.withValues(alpha: 0.15) : _panel,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: _green) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                style: TextStyle(
                    color: zoneColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          if (zone != _RankZone.mid)
            Icon(
                zone == _RankZone.up
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: zoneColor,
                size: 22)
          else
            const SizedBox(width: 22),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 15,
            backgroundColor: _bg,
            backgroundImage:
                photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
            child: photo?.isNotEmpty == true
                ? null
                : Icon(Icons.person, color: AppColors.text38, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(sub,
                    style: TextStyle(
                        color: AppColors.text38, fontSize: 11)),
              ],
            ),
          ),
          Icon(scoreIcon, color: scoreColor, size: 15),
          const SizedBox(width: 4),
          Text('$score',
              style: TextStyle(
                  color: AppColors.text70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.person_remove_outlined,
                  color: AppColors.text38, size: 17),
              onPressed: onRemove,
            ),
        ],
      ),
        ),
      ),
    );
  }
}

// ── Friend search dialog ──────────────────────────────────────────────────────

class _FriendSearchDialog extends ConsumerStatefulWidget {
  final bool tr;
  const _FriendSearchDialog({required this.tr});

  @override
  ConsumerState<_FriendSearchDialog> createState() =>
      _FriendSearchDialogState();
}

class _FriendSearchDialogState extends ConsumerState<_FriendSearchDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _busy = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _busy = true);
      try {
        final r = await ref.read(userRepositoryProvider).searchUsers(v);
        if (mounted) setState(() => _results = r);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  Future<void> _toggleFriend(Map<String, dynamic> u) async {
    final repo = ref.read(userRepositoryProvider);
    final isFriend = u['is_friend'] == true;
    if (isFriend) {
      setState(() => u['is_friend'] = false);
      await repo.removeFriend(u['id'] as String);
      ref.invalidate(friendsLeaderboardProvider);
    } else {
      // Consent-based: only a REQUEST goes out; they become friends when
      // the other side accepts.
      setState(() => u['request_sent'] = true);
      await repo.sendFriendRequest(u['id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(AppL10n.of(context).findFriends,
          style: TextStyle(color: AppColors.text, fontSize: 18)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    AppL10n.of(context).typeUsername,
                hintStyle: TextStyle(color: AppColors.text38),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.text38, size: 18),
                filled: true,
                fillColor: _bg,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _green))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final u in _results)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: _bg,
                                backgroundImage: (u['photo_url']
                                            as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? NetworkImage(
                                        u['photo_url'] as String)
                                    : null,
                                child: (u['photo_url'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? null
                                    : Icon(Icons.person,
                                        color: AppColors.text38,
                                        size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_rowName(context, u),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: AppColors.text,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w700)),
                                    Text('@${u['username'] ?? ''}',
                                        style: TextStyle(
                                            color: AppColors.text38,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: u['request_sent'] == true
                                    ? null
                                    : () => _toggleFriend(u),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: u['is_friend'] == true
                                      ? AppColors.text54
                                      : _green,
                                  side: BorderSide(
                                      color: u['is_friend'] == true ||
                                              u['request_sent'] == true
                                          ? AppColors.text24
                                          : _green),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                child: Text(
                                    u['is_friend'] == true
                                        ? AppL10n.of(context).removeLbl
                                        : (u['request_sent'] == true
                                            ? AppL10n.of(context).requestSent
                                            : AppL10n.of(context).addLbl),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      if (_results.isEmpty &&
                          _ctrl.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                              AppL10n.of(context).noResultsLbl,
                              style: TextStyle(
                                  color: AppColors.text38, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppL10n.of(context).closeLabel),
        ),
      ],
    );
  }
}


// ── Quests ────────────────────────────────────────────────────────────────────

// ── Daily quests ──────────────────────────────────────────────────────────────
// 3 quests per day, picked DETERMINISTICALLY from (uid + date): stable all day,
// different every day and per user. Progress comes from today's answer_stats
// row; a finished quest's chest pays +20 gold once (claimReward is idempotent).

class _QuestDef {
  final String id;
  final IconData icon;
  final Color color;
  final List<int> targets;
  final String Function(int n, AppL10n l) label;
  final int Function(int total, int correct, int points) metric;
  const _QuestDef(
      this.id, this.icon, this.color, this.targets, this.label, this.metric);
}

final List<_QuestDef> _kQuestPool = [
  _QuestDef('points', Icons.bolt_rounded, const Color(0xFFFFC800),
      const [20, 40, 60, 80],
      (n, l) => l.questEarnPoints(n),
      (t, c, p) => p),
  _QuestDef('answer', Icons.check_circle_outline_rounded,
      const Color(0xFF1CB0F6), const [5, 10, 15],
      (n, l) => l.questAnswerN(n),
      (t, c, p) => t),
  _QuestDef('correct', Icons.track_changes_rounded, const Color(0xFF58CC02),
      const [3, 5, 8],
      (n, l) => l.questCorrectN(n),
      (t, c, p) => c),
  _QuestDef('streak', Icons.local_fire_department_rounded,
      const Color(0xFFFF9600), const [1],
      (n, l) => l.questKeepStreak,
      (t, c, p) => t > 0 ? 1 : 0),
];

class QuestsCenter extends ConsumerWidget {
  final bool tr;
  const QuestsCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final now = DateTime.now();
    final dayKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    // Deterministic daily pick: same all day, reshuffles at midnight.
    final rng = Random(Object.hash(uid, dayKey));
    final pool = List<_QuestDef>.from(_kQuestPool)..shuffle(rng);
    final picked = pool.take(3).toList();
    final targets = [
      for (final q in picked) q.targets[rng.nextInt(q.targets.length)]
    ];

    // Today's progress.
    final rows = ref.watch(dailyAnswerStatsProvider).valueOrNull ?? const [];
    final todayIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final today = rows.firstWhere(
        (r) => '${r['day']}'.startsWith(todayIso),
        orElse: () => const {});
    final t = (today['total'] as num?)?.toInt() ?? 0;
    final c = (today['correct'] as num?)?.toInt() ?? 0;
    final p = (today['points'] as num?)?.toInt() ?? 0;

    final progress = ref.watch(pathProgressProvider).valueOrNull ?? const {};
    final rewards = progress['__rewards'];
    bool claimed(String qid) =>
        rewards is Map && rewards['q.$dayKey.$qid'] == true;
    final doneCount = [
      for (var i = 0; i < picked.length; i++)
        if (picked[i].metric(t, c, p) >= targets[i]) 1
    ].length;

    final hoursLeft =
        DateTime(now.year, now.month, now.day + 1).difference(now).inHours;

    Future<void> claim(String qid) async {
      final ok = await ref
          .read(userRepositoryProvider)
          .claimReward('q.$dayKey.$qid');
      if (!ok || !context.mounted) return;
      ref.invalidate(pathProgressProvider);
      ref.invalidate(currentUserProvider);
      WebSfx.gong();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
              AppL10n.of(context).hongbaoToast)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero banner (our palette + mascot).
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1B6E68), Color(0xFF2EC4B6)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fixed white: the banner gradient stays dark
                            // teal in both themes.
                            Text(AppL10n.of(context).teaHouseTitle,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(AppL10n.of(context).teaHouseSub(doneCount),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      Image.asset('assets/mascot/mascot.png',
                          width: 72, height: 72, fit: BoxFit.contain),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(AppL10n.of(context).todaysOrders,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.schedule_rounded,
                        color: Color(0xFFFFC800), size: 15),
                    const SizedBox(width: 4),
                    Text(AppL10n.of(context).hoursLeftLbl(hoursLeft),
                        style: const TextStyle(
                            color: Color(0xFFFFC800),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < picked.length; i++) ...[
                  _QuestRow(
                    icon: picked[i].icon,
                    color: picked[i].color,
                    label: picked[i].label(targets[i], AppL10n.of(context)),
                    current: picked[i].metric(t, c, p),
                    target: targets[i],
                    claimed: claimed(picked[i].id),
                    onClaim: picked[i].metric(t, c, p) >= targets[i] &&
                            !claimed(picked[i].id)
                        ? () => claim(picked[i].id)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int current;
  final int target;
  final bool claimed;
  final VoidCallback? onClaim;
  const _QuestRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.current,
    required this.target,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final done = current >= target;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              BrushBar(
                value: (current / target).clamp(0.0, 1.0),
                color: color,
                height: 14,
                label: '${current.clamp(0, target)} / $target',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Hongbao (red envelope) reward instead of a chest icon.
        claimed
            ? const Icon(Icons.check_circle_rounded,
                color: Color(0xFF3FB58E), size: 30)
            : IconButton(
                onPressed: onClaim,
                tooltip: done ? '+20' : null,
                icon: Opacity(
                  opacity: done ? 1 : 0.3,
                  child: const Text('🧧', style: TextStyle(fontSize: 26)),
                ),
              ),
      ]),
    );
  }
}

// ── Brush-stroke progress bar ─────────────────────────────────────────────────
// An ink line being filled by a calligraphy stroke: rounded start, tapered
// "wet tip" end — our replacement for the stock progress bar.
class BrushBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final String? label;
  const BrushBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 12,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Faint ink track.
          Container(
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: v <= 0 ? 0.001 : v,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withValues(alpha: 0.65),
                  color,
                ]),
                // Asymmetric caps: clean start, tapered brush tip.
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(height / 2),
                  bottomLeft: Radius.circular(height / 2),
                  topRight: Radius.circular(height * 0.9),
                  bottomRight: Radius.circular(height * 0.25),
                ),
              ),
            ),
          ),
          if (label != null)
            Positioned.fill(
              child: Center(
                child: Text(label!,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shop ──────────────────────────────────────────────────────────────────────

class ShopCenter extends ConsumerWidget {
  final bool tr;
  const ShopCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(pathMetaProvider);
    final full = meta.hearts >= kMaxHearts;

    Future<void> refill() async {
      await ref.read(userRepositoryProvider).refillHearts();
      ref.invalidate(pathProgressProvider);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppL10n.of(context).heartsTitle,
                    style: TextStyle(
                        color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ShopRow(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF4B4B),
                  title: AppL10n.of(context).refillHearts,
                  subtitle:
                      AppL10n.of(context).refillSub(meta.hearts, kMaxHearts),
                  actionLabel: full ? AppL10n.of(context).fullLbl : AppL10n.of(context).refillLbl,
                  onAction: full ? null : refill,
                ),
                const SizedBox(height: 10),
                _ShopRow(
                  icon: Icons.all_inclusive_rounded,
                  color: const Color(0xFF1CB0F6),
                  title: AppL10n.of(context).unlimitedHearts,
                  subtitle: AppL10n.of(context).premiumSub,
                  actionLabel: 'PREMIUM',
                  onAction: () => context.go('/subscription'),
                ),
                const SizedBox(height: 24),
                Text(AppL10n.of(context).powerUps,
                    style: TextStyle(
                        color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ShopRow(
                  icon: Icons.ac_unit_rounded,
                  color: const Color(0xFF1CB0F6),
                  title: AppL10n.of(context).streakFreeze,
                  subtitle: AppL10n.of(context).streakFreezeSub,
                  actionLabel: AppL10n.of(context).soonLbl,
                  onAction: null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  const _ShopRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: AppColors.text54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: BorderSide(color: onAction == null ? AppColors.text24 : _green),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ── Settings ("Tercihler") ────────────────────────────────────────────────────

class SettingsCenter extends ConsumerWidget {
  final bool tr;
  const SettingsCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final lang = ref.watch(localeProvider).languageCode;

    Future<void> logout() async {
      final router = GoRouter.of(context);
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      router.go('/');
    }

    Future<void> deleteAccount() async {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _panel,
          title: Text(AppL10n.of(context).deleteForever,
              style: TextStyle(color: AppColors.text)),
          content: Text(AppL10n.of(context).deleteForeverMsg,
              style: TextStyle(color: AppColors.text70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppL10n.of(context).giveUp)),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppL10n.of(context).deleteLbl,
                    style: const TextStyle(color: Color(0xFFFF4B4B)))),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final router = GoRouter.of(context);
      try {
        await ref.read(userRepositoryProvider).deleteAccount(uid);
        router.go('/');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppL10n.of(context).preferences,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _GroupLabel(AppL10n.of(context).appearance),
                _ToggleRow(
                  label: isDark
                      ? AppL10n.of(context).darkThemeToggle
                      : AppL10n.of(context).lightThemeToggle,
                  value: isDark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
                _LangRow(
                  tr: tr,
                  lang: lang,
                  onSelect: (c) =>
                      ref.read(localeProvider.notifier).setLocale(Locale(c)),
                ),
                const SizedBox(height: 20),
                _GroupLabel(AppL10n.of(context).accountLbl),
                _MoreRow(
                    icon: Icons.workspace_premium_rounded,
                    label: AppL10n.of(context).subscriptionLbl,
                    onTap: () => context.go('/subscription')),
                _MoreRow(
                    icon: Icons.logout_rounded,
                    label: AppL10n.of(context).logoutLbl,
                    onTap: logout),
                _MoreRow(
                    icon: Icons.delete_forever_rounded,
                    label: AppL10n.of(context).deleteForever,
                    color: const Color(0xFFFF4B4B),
                    onTap: deleteAccount),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsRight extends StatelessWidget {
  final bool tr;
  final VoidCallback onProfile;
  final VoidCallback onPrefs;
  const SettingsRight(
      {super.key,
      required this.tr,
      required this.onProfile,
      required this.onPrefs});

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
      final router = GoRouter.of(context);
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      router.go('/');
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LinkCard(title: AppL10n.of(context).accountLbl, links: [
              (AppL10n.of(context).preferences, onPrefs),
              (AppL10n.of(context).navProfile, onProfile),
              (AppL10n.of(context).privacySettings,
                  () => context.go('/legal/privacy')),
            ]),
            const SizedBox(height: 16),
            _LinkCard(title: AppL10n.of(context).subscriptionLbl, links: [
              (AppL10n.of(context).choosePlan,
                  () => context.go('/subscription')),
            ]),
            const SizedBox(height: 16),
            _LinkCard(title: AppL10n.of(context).supportLbl, links: [
              (AppL10n.of(context).helpCenter,
                  () => context.go('/legal/terms')),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: InkWell(
                onTap: logout,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(AppL10n.of(context).logoutCaps,
                        style: const TextStyle(
                            color: Color(0xFF1CB0F6),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> links;
  const _LinkCard({required this.title, required this.links});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final l in links)
            InkWell(
              onTap: l.$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.$1,
                    style: const TextStyle(
                        color: Color(0xFF1CB0F6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: AppColors.text, fontSize: 15)),
        ),
        Switch(
            value: value, activeThumbColor: _green, onChanged: onChanged),
      ]),
    );
  }
}

class _LangRow extends StatelessWidget {
  final bool tr;
  final String lang;
  final void Function(String) onSelect;
  const _LangRow(
      {required this.tr, required this.lang, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    Widget chip(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => onSelect(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? _green : _bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : AppColors.text60,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Text(AppL10n.fromCode(lang).appLanguage,
              style: TextStyle(color: AppColors.text, fontSize: 15)),
        ),
        chip('tr', 'TR'),
        const SizedBox(width: 8),
        chip('en', 'EN'),
        const SizedBox(width: 8),
        chip('ko', '한국어'),
        const SizedBox(width: 8),
        chip('ja', '日本語'),
        const SizedBox(width: 8),
        chip('id', 'Indonesia'),
        const SizedBox(width: 8),
        chip('vi', 'Tiếng Việt'),
        const SizedBox(width: 8),
        chip('th', 'ภาษาไทย'),
      ]),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MoreRow(
      {required this.icon, required this.label, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Icon(icon, color: c, size: 24),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: AppColors.text38),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Generic right info card ───────────────────────────────────────────────────

class RightInfoCard extends StatelessWidget {
  final bool tr;
  final String title;
  final String body;
  const RightInfoCard(
      {super.key, required this.tr, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(body,
                style: TextStyle(color: AppColors.text70, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ── Badges (rozetler) ─────────────────────────────────────────────────────────
// Achievement ladder themed on the Three Kingdoms + Chinese mythology. Each
// badge is a seal stamp: the figure's signature character inside a tier ring
// (bronze → silver → gold → vermilion legend). Earned = inked; locked = faded.

class _BadgeDef {
  final String id; // l10n figure key
  final String zh; // seal character(s)
  final int threshold;
  const _BadgeDef(this.id, this.zh, this.threshold);
}

const _kBadgeTierColors = [
  Color(0xFFB0795A), // bronze
  Color(0xFFB8C4CC), // silver
  Color(0xFFD4A33D), // gold
  Color(0xFFE0442C), // vermilion legend
];

// Sages (watch minutes) — the strategists.
const _kBadgesWatch = [
  _BadgeDef('xushu', '徐', 10),
  _BadgeDef('pangtong', '庞', 100),
  _BadgeDef('zhugeliang', '亮', 1000),
  _BadgeDef('jiangziya', '姜', 5000),
];
// Warriors (correct answers).
const _kBadgesCorrect = [
  _BadgeDef('zhaoyun', '赵', 50),
  _BadgeDef('guanyu', '关', 250),
  _BadgeDef('lvbu', '吕', 1000),
  _BadgeDef('nezha', '吒', 5000),
];
// Rulers (units finished).
const _kBadgesUnits = [
  _BadgeDef('liubei', '刘', 1),
  _BadgeDef('sunquan', '孙', 5),
  _BadgeDef('caocao', '曹', 12),
  _BadgeDef('pangu', '盘', 24),
];
// Legends (HSK levels finished).
const _kBadgesLevels = [
  _BadgeDef('zhangfei', '张', 1),
  _BadgeDef('zhouyu', '周', 2),
  _BadgeDef('simayi', '司', 4),
  _BadgeDef('nuwa', '娲', 6),
];

class BadgesRight extends ConsumerWidget {
  final bool tr;
  const BadgesRight({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final life = ref.watch(lifetimeStatsProvider).valueOrNull ?? const {};
    final watchMin = ((life['watch_seconds'] ?? 0) / 60).floor();
    final correct = life['correct'] ?? 0;

    // Units/levels from path progress: a unit counts when every playable
    // phase is done; a level counts when all its units with content are done.
    final topics = ref.watch(curriculumProvider).valueOrNull ?? const [];
    final progress = ref.watch(pathProgressProvider).valueOrNull ?? const {};
    var unitsDone = 0;
    var levelsDone = 0;
    for (final t in topics) {
      var levelHadContent = false;
      var levelAllDone = true;
      for (final s in t.steps) {
        final playable = s.phases.where((p) => p.hasVideos).toList();
        if (playable.isEmpty) continue;
        levelHadContent = true;
        final done = playable.every((p) => progress.phase(p.key).done);
        if (done) {
          unitsDone++;
        } else {
          levelAllDone = false;
        }
      }
      if (levelHadContent && levelAllDone) levelsDone++;
    }

    Widget seal(_BadgeDef b, int tier, int value, String cond) {
      final earned = value >= b.threshold;
      final color = _kBadgeTierColors[tier];
      // Classic portrait of the figure (PD art from Wikimedia, bundled);
      // the signature seal character is the fallback if art is missing.
      Widget portrait = Image.asset(
        'assets/badges/${b.id}.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(b.zh,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
        ),
      );
      if (!earned) {
        portrait = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 20, //
            0.2126, 0.7152, 0.0722, 0, 24, //
            0.2126, 0.7152, 0.0722, 0, 22, //
            0, 0, 0, 1, 0,
          ]),
          child: portrait,
        );
      }
      return Tooltip(
        message: '${l10n.badgeFigure(b.id)} — $cond',
        child: Opacity(
          opacity: earned ? 1 : 0.38,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: earned
                    ? color.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2.5),
              ),
              child: portrait,
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 62,
              child: Text(l10n.badgeFigure(b.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.text54, fontSize: 9)),
            ),
          ]),
        ),
      );
    }

    Widget category(String title, List<_BadgeDef> defs, int value,
        String Function(int) condOf) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < defs.length; i++)
                seal(defs[i], i, value, condOf(defs[i].threshold)),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.badgesTitle,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(l10n.badgesSub,
                  style: TextStyle(
                      color: AppColors.text54, fontSize: 11, height: 1.4)),
              const SizedBox(height: 16),
              category(l10n.badgeCatSages, _kBadgesWatch, watchMin,
                  l10n.badgeWatchCond),
              category(l10n.badgeCatWarriors, _kBadgesCorrect, correct,
                  l10n.badgeCorrectCond),
              category(l10n.badgeCatRulers, _kBadgesUnits, unitsDone,
                  l10n.badgeUnitsCond),
              category(l10n.badgeCatLegends, _kBadgesLevels, levelsDone,
                  l10n.badgeLevelsCond),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile view (read-only) ──────────────────────────────────────────────────

class ProfileView extends ConsumerWidget {
  final bool tr;
  final VoidCallback onEdit;
  const ProfileView({super.key, required this.tr, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // stableCurrentUserProvider keeps the last good photoUrl through the
    // loading transients that fire on every section switch — without it the
    // avatar flashes empty when navigating between home tabs.
    final user = ref.watch(stableCurrentUserProvider) ??
        ref.watch(currentUserProvider).valueOrNull;
    final meta = ref.watch(pathMetaProvider);
    if (user == null) {
      return Center(
        child: Text(AppL10n.of(context).pleaseSignIn,
            style: TextStyle(color: AppColors.text54, fontSize: 15)),
      );
    }
    final name = [user.displayName, user.lastName]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    final username = user.username.isNotEmpty
        ? user.username
        : (user.email.contains('@')
            ? user.email.split('@').first
            : user.email);
    final d = user.createdAt;
    final joined = AppL10n.of(context).joinedOn(d.month, d.year);
    final sfxOn = ref.watch(sfxEnabledProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: seal-ringed avatar beside the name block — no banner
                // (the old navy gradient is gone); reads like a passport page.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Vermilion seal ring with a thin gold inner line.
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFE0442C),
                                    width: 3),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFD4A33D),
                                      width: 1),
                                ),
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor: _bg,
                                  backgroundImage: user.photoUrl.isNotEmpty
                                      ? NetworkImage(user.photoUrl)
                                      : null,
                                  child: user.photoUrl.isEmpty
                                      ? Icon(Icons.person,
                                          color: AppColors.text38, size: 44)
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -6,
                              bottom: -2,
                              child: Material(
                                color: const Color(0xFF161E1D),
                                shape: CircleBorder(
                                    side: BorderSide(
                                        color: AppColors.border)),
                                child: IconButton(
                                  iconSize: 16,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.edit,
                                      color: AppColors.text70),
                                  tooltip: AppL10n.of(context).editTip,
                                  onPressed: onEdit,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(name.isNotEmpty ? name : username,
                                  style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800)),
                            ),
                            // Sound effects on/off — applies app-wide.
                            IconButton(
                              icon: Icon(
                                  sfxOn
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_off_rounded,
                                  color: sfxOn
                                      ? const Color(0xFF2EC4B6)
                                      : AppColors.text38,
                                  size: 22),
                              tooltip: sfxOn
                                  ? AppL10n.of(context).soundOffTip
                                  : AppL10n.of(context).soundOnTip,
                              onPressed: () => ref
                                  .read(sfxEnabledProvider.notifier)
                                  .toggle(),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text('@$username',
                              style: TextStyle(
                                  color: AppColors.text54, fontSize: 14)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.calendar_today_rounded,
                                color: AppColors.text38, size: 14),
                            const SizedBox(width: 6),
                            Text(joined,
                                style: TextStyle(
                                    color: AppColors.text54, fontSize: 13)),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('HSK ${user.hskLevel}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          // Brush-stroke divider in gold, a quiet Chinese
                          // accent under the identity block.
                          Container(
                            height: 2,
                            width: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(colors: [
                                const Color(0xFFD4A33D),
                                const Color(0xFFD4A33D)
                                    .withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 240,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _ProfileFriendRequests(),
                          const SizedBox(height: 10),
                          _ProfileFriends(tr: tr),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // "Continue where you left off" → opens the current phase lesson.
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      final topics = ref.read(curriculumProvider).valueOrNull;
                      final progress =
                          ref.read(pathProgressProvider).valueOrNull ?? const {};
                      final phase = topics == null
                          ? null
                          : currentPhaseFor(topics, progress,
                              ref.read(currentHskLevelProvider));
                      if (phase != null) {
                        ref
                            .read(selectedTopicHskProvider.notifier)
                            .state = phase.hsk;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PhaseRunnerScreen(
                            phase: phase,
                            title:
                                'L${phase.hsk} · ${AppL10n.of(context).phaseLbl} ${phase.phaseIndex + 1}',
                          ),
                        ));
                      } else {
                        context.go('/learn');
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(AppL10n.of(context).startCaps,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(AppL10n.of(context).statistics,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFFF9600),
                        value: '${meta.streak}',
                        label: AppL10n.of(context).dayStreakLbl),
                    _StatCard(
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFFFFC800),
                        value: '${user.stats.totalScore}',
                        label: AppL10n.of(context).totalXpLbl),
                    _StatCard(
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFFFF4B4B),
                        value: '${meta.hearts}',
                        label: AppL10n.of(context).heartsLbl),
                    _StatCard(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF1CB0F6),
                        value: '${user.stats.questionsAnswered}',
                        label: AppL10n.of(context).answeredLbl),
                  ],
                ),
                const SizedBox(height: 24),
                Text(AppL10n.of(context).passportTitle,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ProfilePassport(tr: tr),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Right rail of the Profile section — rank, MANAGEABLE playlists (create +
// delete right here) and daily stats, top-aligned (moved out of the centre).
class ProfileListsRight extends ConsumerStatefulWidget {
  final bool tr;
  const ProfileListsRight({super.key, required this.tr});

  @override
  ConsumerState<ProfileListsRight> createState() => _ProfileListsRightState();
}

class _ProfileListsRightState extends ConsumerState<ProfileListsRight> {
  final _newListCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _newListCtrl.dispose();
    super.dispose();
  }

  Future<void> _createList() async {
    final name = _newListCtrl.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await ref.read(videoRepositoryProvider).createPlaylist(name);
      _newListCtrl.clear();
      ref.invalidate(myPlaylistsProvider);
    } catch (e) {
      // Surface the real failure — a silent catch made "nothing happens"
      // impossible to diagnose.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final score = ref.watch(stableCurrentUserProvider)?.stats.totalScore ??
        ref.watch(currentUserProvider).valueOrNull?.stats.totalScore ??
        0;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        );

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(AppL10n.of(context).scoresRanking),
            _ProfileRank(tr: tr, score: score),
            const SizedBox(height: 20),
            header(AppL10n.of(context).myListsTitle),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newListCtrl,
                  maxLength: 60,
                  style: TextStyle(
                      color: AppColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: AppL10n.of(context).newListHint,
                    hintStyle: TextStyle(
                        color: AppColors.text38, fontSize: 12),
                    counterText: '',
                    filled: true,
                    fillColor: _panel,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _createList(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _creating ? null : _createList,
                style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12)),
                child: const Icon(Icons.add_rounded, size: 18),
              ),
            ]),
            const SizedBox(height: 10),
            _ProfilePlaylists(tr: tr),
            const SizedBox(height: 20),
            header(AppL10n.of(context).streakTitle),
            const _ProfileStreak(),
          ],
        ),
      ),
    );
  }
}

// ── Bobo hero (post-login dashboard) ──────────────────────────────────────────
// Our mascot has a name and a voice: a day-rotating greeting / chengyu.

const List<(String zh, String tr, String en, String ko, String ja, String id, String vi, String th)> _kBoboLines = [
  ('加油!', 'Bugün de birlikte çalışalım mı?', 'Shall we practise together today?', '오늘도 같이 공부해 볼까요?', '今日も一緒に勉強しましょうか？', 'Belajar bareng lagi hari ini, yuk?', 'Hôm nay cùng học nữa nhé?', 'วันนี้เรามาเรียนด้วยกันไหม?'),
  ('熟能生巧', 'Pratik mükemmelleştirir — bir klip daha?', 'Practice makes perfect — one more clip?', '연습이 실력을 만들어요 — 한 클립 더 어때요?', '習うより慣れろ — もう1本いかがですか？', 'Latihan membuat sempurna — satu klip lagi?', 'Có công mài sắt có ngày nên kim — thêm một clip nhé?', 'ฝึกฝนบ่อย ๆ ย่อมเชี่ยวชาญ — ดูอีกคลิปไหม?'),
  ('好久不见!', 'Seni görmek güzel! Kaldığın yerden devam edelim.', 'Good to see you! Let\'s pick up where you left off.', '다시 만나서 반가워요! 멈췄던 곳부터 이어가요.', 'お久しぶりです！続きから始めましょう。', 'Senang bertemu lagi! Lanjut dari tempat terakhirmu.', 'Rất vui được gặp lại! Tiếp tục từ chỗ bạn dừng nhé.', 'ดีใจที่ได้เจอกันอีก! มาต่อจากที่ค้างไว้กันเถอะ'),
  ('滴水穿石', 'Damlaya damlaya göl olur. Günde 5 dakika yeter!', 'Drop by drop fills the lake. 5 minutes a day!', '낙숫물이 바위를 뚫어요. 하루 5분이면 충분해요!', '点滴石を穿つ。1日5分で十分です！', 'Sedikit demi sedikit lama-lama menjadi bukit. 5 menit sehari cukup!', 'Nước chảy đá mòn. Mỗi ngày 5 phút là đủ!', 'น้ำหยดลงหินทุกวันหินยังกร่อน วันละ 5 นาทีก็พอ!'),
  ('你最棒!', 'Serini koru, ben buradayım 🏮', 'Keep your streak — I\'m right here 🏮', '스트릭을 지켜요, 제가 곁에 있을게요 🏮', '連続記録を守りましょう、私がついています 🏮', 'Jaga rentetanmu — aku di sini 🏮', 'Giữ chuỗi của bạn nhé, mình luôn ở đây 🏮', 'รักษาสถิติต่อเนื่องไว้นะ ฉันอยู่ตรงนี้ 🏮'),
  ('一起学吧!', 'Bugünkü çayevi siparişlerine baktın mı? 🧧', 'Checked today\'s tea house orders? 🧧', '오늘 찻집 주문은 확인했나요? 🧧', '今日の茶館の注文は確認しましたか？ 🧧', 'Sudah cek pesanan kedai teh hari ini? 🧧', 'Đã xem đơn hàng quán trà hôm nay chưa? 🧧', 'ดูออร์เดอร์ร้านน้ำชาวันนี้หรือยัง? 🧧'),
  ('万事开头难', 'Her işin başı zordur — başlamak yeter.', 'Every beginning is hard — just start.', '시작이 반이에요 — 일단 시작해 봐요.', '何事も始めが難しい — まず始めましょう。', 'Setiap awal itu sulit — mulai saja dulu.', 'Vạn sự khởi đầu nan — cứ bắt đầu thôi.', 'การเริ่มต้นทุกอย่างนั้นยาก — แค่เริ่มก็พอ'),
];

class _BoboHero extends StatelessWidget {
  final bool tr;
  const _BoboHero({required this.tr});

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime.utc(2026)).inDays;
    final line = _kBoboLines[day % _kBoboLines.length];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF143B37), Color(0xFF1B6E68)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Image.asset('assets/mascot/mascot.png',
              width: 110, height: 110, fit: BoxFit.contain),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1414).withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.$1,
                      style: const TextStyle(
                          color: Color(0xFFD4A33D),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final lang = Localizations.maybeLocaleOf(context)
                            ?.languageCode ??
                        'en';
                    final text = lang == 'tr'
                        ? line.$2
                        : (lang == 'ko'
                            ? line.$4
                            : (lang == 'ja'
                                ? line.$5
                                : (lang == 'id'
                                    ? line.$6
                                    : (lang == 'vi'
                                        ? line.$7
                                        : (lang == 'th' ? line.$8 : line.$3)))));
                    // Fixed white: the speech bubble stays dark ink in both
                    // themes.
                    return Text(text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35));
                  }),
                  const SizedBox(height: 6),
                  const Text('— Bobo 🦆',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile: passport / stamp book ────────────────────────────────────────────
// Every fully completed unit earns the city's red seal stamp.

class _ProfilePassport extends ConsumerWidget {
  final bool tr;
  const _ProfilePassport({required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(curriculumProvider).valueOrNull ?? const [];
    final progress = ref.watch(pathProgressProvider).valueOrNull ?? const {};
    final stamps = <(String name, int hsk)>[];
    for (final t in topics) {
      for (final s in t.steps) {
        final playable = s.phases.where((p) => p.hasVideos).toList();
        if (playable.isEmpty) continue;
        if (playable.every((p) => progress.phase(p.key).done)) {
          stamps.add((
            cityNameFor(
                cityForUnit(s.hsk, s.index),
                Localizations.maybeLocaleOf(context)?.languageCode ??
                    (tr ? 'tr' : 'en')),
            s.hsk,
          ));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: stamps.isEmpty
          ? Text(AppL10n.of(context).passportEmpty,
              style: TextStyle(color: AppColors.text54, fontSize: 13))
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < stamps.length; i++)
                  Transform.rotate(
                    angle: (i.isEven ? -1 : 1) * 0.08,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE0442C), width: 2),
                        color: const Color(0xFFE0442C)
                            .withValues(alpha: 0.10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(stamps[i].$1,
                              style: const TextStyle(
                                  color: Color(0xFFE0442C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          Text('L${stamps[i].$2}',
                              style: const TextStyle(
                                  color: Color(0xFFE0442C),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Profile: incoming friend requests ─────────────────────────────────────────
// Sits ABOVE "Arkadaşlarım": every pending request with accept / decline.

final incomingFriendRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadIncomingFriendRequests();
});

class _ProfileFriendRequests extends ConsumerWidget {
  const _ProfileFriendRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final reqs =
        ref.watch(incomingFriendRequestsProvider).valueOrNull ?? const [];

    Future<void> act(String fromUid, bool accept) async {
      final repo = ref.read(userRepositoryProvider);
      if (accept) {
        await repo.acceptFriendRequest(fromUid);
        ref.invalidate(friendsLeaderboardProvider);
      } else {
        await repo.declineFriendRequest(fromUid);
      }
      ref.invalidate(incomingFriendRequestsProvider);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.friendRequests,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (reqs.isEmpty)
            Text(l10n.noRequests,
                style: TextStyle(color: AppColors.text38, fontSize: 11))
          else
            for (final r in reqs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: _bg,
                    backgroundImage:
                        (r['photo_url'] as String?)?.isNotEmpty == true
                            ? NetworkImage(r['photo_url'] as String)
                            : null,
                    child: (r['photo_url'] as String?)?.isNotEmpty == true
                        ? null
                        : Icon(Icons.person,
                            color: AppColors.text38, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        (r['display_name'] as String?)?.trim().isNotEmpty ==
                                true
                            ? r['display_name'] as String
                            : '@${r['username'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.text, fontSize: 12)),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: l10n.acceptLbl,
                    icon: const Icon(Icons.check_circle_rounded,
                        color: _green, size: 22),
                    onPressed: () => act(r['from_uid'] as String, true),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: l10n.declineRequest,
                    icon: Icon(Icons.cancel_rounded,
                        color: AppColors.text38, size: 22),
                    onPressed: () => act(r['from_uid'] as String, false),
                  ),
                ]),
              ),
        ],
      ),
    );
  }
}

// ── Profile: friends (next to the name block) ─────────────────────────────────
// Max 5 rows visible, the rest scroll; tapping opens a mini profile.

class _ProfileFriends extends ConsumerWidget {
  final bool tr;
  const _ProfileFriends({required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final rows = (ref.watch(friendsLeaderboardProvider).valueOrNull ?? const [])
        .where((r) => r['id'] != myUid)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppL10n.of(context).myFriendsTitle,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              AppL10n.of(context).noFriendsHint,
              style: TextStyle(color: AppColors.text38, fontSize: 11),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 5 * 40),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final f = rows[i];
                  final photo = f['photo_url'] as String?;
                  return InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _FriendProfileDialog(friend: f, tr: tr),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 40,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: _bg,
                          backgroundImage: photo?.isNotEmpty == true
                              ? NetworkImage(photo!)
                              : null,
                          child: photo?.isNotEmpty == true
                              ? null
                              : Icon(Icons.person,
                                  color: AppColors.text38, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_rowName(context, f),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.text24, size: 16),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendProfileDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> friend;
  final bool tr;
  const _FriendProfileDialog({required this.friend, required this.tr});

  @override
  ConsumerState<_FriendProfileDialog> createState() =>
      _FriendProfileDialogState();
}

class _FriendProfileDialogState extends ConsumerState<_FriendProfileDialog> {
  bool? _isFriend;
  bool _requestSent = false;
  bool _busy = false;

  Future<void> _toggle() async {
    final uid = widget.friend['id'] as String?;
    if (uid == null || _busy) return;
    final repo = ref.read(userRepositoryProvider);
    final was = _isFriend ?? false;
    setState(() => _busy = true);
    try {
      if (was) {
        setState(() => _isFriend = false);
        await repo.removeFriend(uid);
        ref.invalidate(friendsLeaderboardProvider);
      } else {
        setState(() => _requestSent = true);
        await repo.sendFriendRequest(uid);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final photo = friend['photo_url'] as String?;
    _isFriend ??= (ref.watch(friendsLeaderboardProvider).valueOrNull ??
            const [])
        .any((f) => f['id'] == friend['id']);
    return AlertDialog(
      backgroundColor: _panel,
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _bg,
              backgroundImage:
                  photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
              child: photo?.isNotEmpty == true
                  ? null
                  : Icon(Icons.person, color: AppColors.text38, size: 36),
            ),
            const SizedBox(height: 10),
            Text(_rowName(context, friend),
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text('@${friend['username'] ?? ''}',
                style: TextStyle(color: AppColors.text54, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded,
                    color: Color(0xFF1CB0F6), size: 18),
                const SizedBox(width: 6),
                Text('${friend['score'] ?? 0} ${AppL10n.of(context).pointsLbl}',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _busy || _requestSent ? null : _toggle,
          icon: Icon(
              _isFriend == true
                  ? Icons.person_remove_outlined
                  : (_requestSent
                      ? Icons.hourglass_top_rounded
                      : Icons.person_add_alt_1_rounded),
              size: 18,
              color: _isFriend == true || _requestSent
                  ? AppColors.text54
                  : _green),
          label: Text(
              _isFriend == true
                  ? AppL10n.of(context).removeLbl
                  : (_requestSent
                      ? AppL10n.of(context).requestSent
                      : AppL10n.of(context).addLbl),
              style: TextStyle(
                  color: _isFriend == true || _requestSent
                      ? AppColors.text54
                      : _green)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppL10n.of(context).closeLabel),
        ),
      ],
    );
  }
}

// ── Profile: playlists (VoScreen "My Playlists") ──────────────────────────────
// Tapping a list expands it inline with its clips; tapping a clip opens the
// Practice tab with that list selected.

class _ProfilePlaylists extends ConsumerStatefulWidget {
  final bool tr;
  const _ProfilePlaylists({required this.tr});

  @override
  ConsumerState<_ProfilePlaylists> createState() => _ProfilePlaylistsState();
}

class _ProfilePlaylistsState extends ConsumerState<_ProfilePlaylists> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(myPlaylistsProvider).valueOrNull ?? const [];
    if (lists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          AppL10n.of(context).noListsProfile,
          style: TextStyle(color: AppColors.text54, fontSize: 13),
        ),
      );
    }

    Future<void> remove(String id) async {
      await ref.read(videoRepositoryProvider).deletePlaylist(id);
      if (ref.read(selectedPlaylistProvider) == id) {
        ref.read(selectedPlaylistProvider.notifier).state = null;
      }
      ref.invalidate(myPlaylistsProvider);
      ref.invalidate(videoFeedProvider);
    }

    void openInPractice(String id) {
      ref.read(selectedPlaylistProvider.notifier).state = id;
      ref.invalidate(videoFeedProvider);
      context.go('/video');
    }

    return Column(
      children: [
        for (final p in lists)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _expandedId =
                    _expandedId == p['id'] ? null : p['id'] as String?),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_play_rounded,
                          color: _green, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p['name'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(
                          AppL10n.of(context).videosCount(
                              (p['count'] as num?)?.toInt() ?? 0),
                          style: TextStyle(
                              color: AppColors.text54, fontSize: 12)),
                      Icon(
                          _expandedId == p['id']
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.text38,
                          size: 20),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppColors.text38, size: 18),
                        tooltip: AppL10n.of(context).deleteListTip,
                        onPressed: () => remove(p['id'] as String),
                      ),
                    ],
                  ),
                ),
              ),
              if (_expandedId == p['id'])
                _PlaylistClips(
                  playlistId: p['id'] as String,
                  onOpen: () => openInPractice(p['id'] as String),
                ),
            ]),
          ),
      ],
    );
  }
}

// The expanded clip list of one playlist.
class _PlaylistClips extends ConsumerWidget {
  final String playlistId;
  final VoidCallback onOpen;
  const _PlaylistClips({required this.playlistId, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vids =
        ref.watch(playlistVideosProvider(playlistId)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: AppColors.text12, height: 12),
          if (vids == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green))),
            )
          else if (vids.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(AppL10n.of(context).noVideosInSet,
                  style:
                      TextStyle(color: AppColors.text38, fontSize: 12)),
            )
          else ...[
            for (final v in vids)
              InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.text54, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          (v['transcription'] as String? ?? '')
                              .replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.text70, fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                    Text('HSK ${v['hsk_level'] ?? 1}',
                        style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Profile: streak milestones ────────────────────────────────────────────────
// Current daily streak + the milestone ladder (1 week / 1 month / 100 days /
// 6 months). Reached milestones light up like lanterns.

class _ProfileStreak extends ConsumerWidget {
  const _ProfileStreak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final streak = ref.watch(pathMetaProvider).streak;
    final milestones = [
      (7, l10n.streakWeek),
      (30, l10n.streakMonth),
      (100, l10n.streak100),
      (180, l10n.streak6Months),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🏮', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Text(l10n.streakDays(streak),
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(l10n.streakHint,
              style: TextStyle(color: AppColors.text54, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (days, label) in milestones)
                Builder(builder: (context) {
                  final reached = streak >= days;
                  return Opacity(
                    opacity: reached ? 1 : 0.4,
                    child: Column(children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: reached
                              ? const Color(0xFFE0442C)
                                  .withValues(alpha: 0.14)
                              : Colors.transparent,
                          border: Border.all(
                              color: reached
                                  ? const Color(0xFFE0442C)
                                  : AppColors.locked,
                              width: 2),
                        ),
                        child: Text(reached ? '🏮' : '🔒',
                            style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 4),
                      Text(label,
                          style: TextStyle(
                              color: reached
                                  ? AppColors.text70
                                  : AppColors.text38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ]),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}
// ── Profile: global rank (VoScreen "Scores & Rankings") ───────────────────────

class _ProfileRank extends ConsumerWidget {
  final bool tr;
  final int score;
  const _ProfileRank({required this.tr, required this.score});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(userRankProvider).valueOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFFC800), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppL10n.of(context).globalRank,
                    style: TextStyle(
                        color: AppColors.text54, fontSize: 12)),
                Text(rank != null ? '#$rank' : '—',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.diamond_rounded,
              color: Color(0xFF1CB0F6), size: 18),
          const SizedBox(width: 6),
          Text('$score',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text54, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Home dashboard (post-login welcome) ───────────────────────────────────────

class HomeDashboard extends ConsumerWidget {
  final bool tr;
  final VoidCallback onStart;
  const HomeDashboard({super.key, required this.tr, required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim().split(' ').first
        : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero: Bobo the platypus greets with a day-rotating line
              // (a chengyu or a nudge) in a speech bubble.
              _BoboHero(tr: tr),
              const SizedBox(height: 28),
              Text(
                AppL10n.of(context).welcomeName(name),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                AppL10n.of(context).continueLearning,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text60, fontSize: 15),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(AppL10n.of(context).startCaps,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
