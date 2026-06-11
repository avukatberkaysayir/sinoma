import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/video_segment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../home/inline_player_section.dart';
import 'phase_runner_screen.dart';

// Duolingo palette (kept local to this file).
const _green = Color(0xFF2EC4B6);
const _bg = Color(0xFF131F2A);
const _panel = Color(0xFF1C2A35);

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
          Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
      data: (segs) {
        if (segs.isEmpty) {
          return Center(
            child: Text(tr ? 'Filtreyle eşleşen video yok.' : 'No videos match.',
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
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
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF24333D))),
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
                label: Text(tr ? 'HSK TESTİNE BAŞLA' : 'START HSK TEST',
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
                border: Border.all(color: const Color(0xFF2C3B45)),
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
              label: tr ? 'LİSTELERİM' : 'MY LISTS',
              open: _openGroup == 'playlists',
              activeCount: selPlaylist != null ? 1 : 0,
              onToggle: _toggleGroup,
              children: [
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      tr
                          ? 'Henüz listen yok — player altındaki "Listeye Ekle" ile oluştur.'
                          : 'No lists yet — use "Add to Playlist" under the player.',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
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
            Text(tr ? 'Filtreler' : 'Filters',
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
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
              label: tr ? 'KONU' : 'TOPIC',
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
                          child: const Icon(Icons.movie_outlined,
                              size: 16, color: Colors.white38))
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
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
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
            color: activeCount > 0 ? _green : const Color(0xFF2C3B45)),
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
                        style: const TextStyle(
                            color: Colors.white,
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
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54, size: 20),
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
                      const Divider(color: Color(0xFF2C3B45), height: 1),
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
                      color: selected ? _green : Colors.white70,
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

  void _openFriendSearch() {
    showDialog(
        context: context,
        builder: (_) => _FriendSearchDialog(tr: widget.tr));
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final myUid = Supabase.instance.client.auth.currentUser?.id;

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
                  color: on ? _green : const Color(0xFF2C3B45)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: on ? _green : Colors.white54),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: on ? _green : Colors.white70,
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
                Row(children: [
                  tabChip(0, tr ? 'Ligim' : 'My League',
                      Icons.shield_rounded),
                  const SizedBox(width: 8),
                  tabChip(1, tr ? 'Arkadaşlarım' : 'Friends',
                      Icons.group_rounded),
                  const SizedBox(width: 8),
                  tabChip(2, tr ? 'Elmas Ligi' : 'Diamond Rank',
                      Icons.diamond_rounded),
                ]),
                const SizedBox(height: 20),
                if (_tab == 0) _LeagueTab(tr: tr, myUid: myUid),
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

// ── Ligim: the 30-user weekly cohort ──────────────────────────────────────────

class _LeagueTab extends ConsumerWidget {
  final bool tr;
  final String? myUid;
  const _LeagueTab({required this.tr, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(leagueGroupProvider);
    return group.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _green)),
      error: (e, _) => Center(
          child:
              Text('$e', style: const TextStyle(color: Colors.white54))),
      data: (rows) {
        final lg = rows.isEmpty
            ? 1
            : ((rows.firstWhere((r) => r['id'] == myUid,
                            orElse: () => rows.first)['league'] as num?)
                        ?.toInt() ??
                    1)
                .clamp(1, 10);
        final color = kLeagueColors[lg - 1];
        final size = rows.length;
        return Column(
          children: [
            Icon(Icons.shield_rounded, color: color, size: 44),
            const SizedBox(height: 6),
            Text(
                tr
                    ? '${kLeagueNames[lg - 1]} Ligi  ·  $lg/10'
                    : '${kLeagueNames[lg - 1]} League  ·  $lg/10',
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                tr
                    ? 'Bu haftanın sıralaması — ilk 6 yükselir, son 6 düşer'
                    : "This week's ranking — top 6 promote, bottom 6 demote",
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            for (var i = 0; i < rows.length; i++)
              _RankRow(
                rank: i + 1,
                name: _rowName(rows[i]),
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
              ),
          ],
        );
      },
    );
  }
}

String _rowName(Map<String, dynamic> r) {
  final n = (r['display_name'] as String?)?.trim();
  return n?.isNotEmpty == true ? n! : (r['username'] as String? ?? 'Öğrenci');
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
          label: Text(tr ? 'ARKADAŞ ARA' : 'FIND FRIENDS',
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
              style: const TextStyle(color: Colors.white54)),
          data: (rows) => rows.length <= 1
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    tr
                        ? 'Henüz arkadaşın yok — kullanıcı adıyla arayıp ekleyebilirsin.'
                        : 'No friends yet — search by username and add them.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                )
              : Column(children: [
                  for (var i = 0; i < rows.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: _rowName(rows[i]),
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
        Text(tr ? 'Elmas Sıralaması' : 'Diamond Ranking',
            style: const TextStyle(
                color: Color(0xFF7DE3F4),
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            tr
                ? 'Elmas Ligi\'nde geçirilen her hafta +1 elmas; dışında kalınan her hafta −1.'
                : 'Each week in the Diamond League earns +1 diamond; each week outside costs −1.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 20),
        rows.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _green)),
          error: (e, _) =>
              Text('$e', style: const TextStyle(color: Colors.white54)),
          data: (list) => list.isEmpty
              ? Text(
                  tr
                      ? 'Henüz elmas kazanan yok — Elmas Ligi\'ne ilk ulaşan sen ol!'
                      : 'No diamonds earned yet — be the first to reach the Diamond League!',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13))
              : Column(children: [
                  for (var i = 0; i < list.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: _rowName(list[i]),
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
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = switch (zone) {
      _RankZone.up => _green,
      _RankZone.down => const Color(0xFFFF4B4B),
      _RankZone.mid => Colors.white38,
    };
    return Container(
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
                : const Icon(Icons.person, color: Colors.white38, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(sub,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Icon(scoreIcon, color: scoreColor, size: 15),
          const SizedBox(width: 4),
          Text('$score',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.person_remove_outlined,
                  color: Colors.white38, size: 17),
              onPressed: onRemove,
            ),
        ],
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
    setState(() => u['is_friend'] = !isFriend);
    if (isFriend) {
      await repo.removeFriend(u['id'] as String);
    } else {
      await repo.addFriend(u['id'] as String);
    }
    ref.invalidate(friendsLeaderboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(tr ? 'Arkadaş Ara' : 'Find Friends',
          style: const TextStyle(color: Colors.white, fontSize: 18)),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    tr ? 'Kullanıcı adı yaz…' : 'Type a username…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white38, size: 18),
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
                                    : const Icon(Icons.person,
                                        color: Colors.white38,
                                        size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_rowName(u),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w700)),
                                    Text('@${u['username'] ?? ''}',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _toggleFriend(u),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: u['is_friend'] == true
                                      ? Colors.white54
                                      : _green,
                                  side: BorderSide(
                                      color: u['is_friend'] == true
                                          ? Colors.white24
                                          : _green),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                child: Text(
                                    u['is_friend'] == true
                                        ? (tr ? 'Çıkar' : 'Remove')
                                        : (tr ? 'Ekle' : 'Add'),
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
                              tr ? 'Sonuç yok' : 'No results',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13)),
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
          child: Text(tr ? 'Kapat' : 'Close'),
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
  final String Function(int n, bool tr) label;
  final int Function(int total, int correct, int points) metric;
  const _QuestDef(
      this.id, this.icon, this.color, this.targets, this.label, this.metric);
}

final List<_QuestDef> _kQuestPool = [
  _QuestDef('points', Icons.bolt_rounded, const Color(0xFFFFC800),
      const [20, 40, 60, 80],
      (n, tr) => tr ? '$n puan kazan' : 'Earn $n points',
      (t, c, p) => p),
  _QuestDef('answer', Icons.check_circle_outline_rounded,
      const Color(0xFF1CB0F6), const [5, 10, 15],
      (n, tr) => tr ? '$n soru cevapla' : 'Answer $n questions',
      (t, c, p) => t),
  _QuestDef('correct', Icons.track_changes_rounded, const Color(0xFF58CC02),
      const [3, 5, 8],
      (n, tr) => tr ? '$n doğru cevap ver' : 'Get $n correct answers',
      (t, c, p) => c),
  _QuestDef('streak', Icons.local_fire_department_rounded,
      const Color(0xFFFF9600), const [1],
      (n, tr) =>
          tr ? 'Seriyi sürdür (bugün 1 soru)' : 'Keep the streak (1 today)',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content:
              Text(tr ? '🪙 Görev ödülü: +20 altın!' : '🪙 Quest reward: +20 gold!')));
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
                            Text(
                                tr
                                    ? 'Görevlerle birlikte ödül kazan!'
                                    : 'Earn rewards with quests!',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                                tr
                                    ? 'Bugün 3 görevin $doneCount tanesini tamamladın.'
                                    : 'You completed $doneCount of 3 quests today.',
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
                      child: Text(tr ? 'Günlük Görevler' : 'Daily Quests',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.schedule_rounded,
                        color: Color(0xFFFFC800), size: 15),
                    const SizedBox(width: 4),
                    Text(tr ? '$hoursLeft SAAT' : '$hoursLeft HOURS',
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
                    label: picked[i].label(targets[i], tr),
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (current / target).clamp(0.0, 1.0),
                      minHeight: 14,
                      backgroundColor: const Color(0xFF37464F),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Text('${current.clamp(0, target)} / $target',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        claimed
            ? const Icon(Icons.check_circle_rounded,
                color: Color(0xFF58CC02), size: 30)
            : IconButton(
                onPressed: onClaim,
                tooltip: done ? '+20' : null,
                icon: Icon(Icons.redeem_rounded,
                    size: 30,
                    color: done
                        ? const Color(0xFFFFC800)
                        : Colors.white24),
              ),
      ]),
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
                Text(tr ? 'Canlar' : 'Hearts',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ShopRow(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF4B4B),
                  title: tr ? 'Canları Yenile' : 'Refill hearts',
                  subtitle: tr
                      ? 'Canlarını tekrar doldur (${meta.hearts}/$kMaxHearts)'
                      : 'Refill your hearts (${meta.hearts}/$kMaxHearts)',
                  actionLabel: full ? (tr ? 'TAM' : 'FULL') : (tr ? 'YENİLE' : 'REFILL'),
                  onAction: full ? null : refill,
                ),
                const SizedBox(height: 10),
                _ShopRow(
                  icon: Icons.all_inclusive_rounded,
                  color: const Color(0xFF1CB0F6),
                  title: tr ? 'Sınırsız Can' : 'Unlimited hearts',
                  subtitle: tr
                      ? 'Premium ile canın hiç tükenmesin'
                      : 'Never run out with Premium',
                  actionLabel: 'PREMIUM',
                  onAction: () => context.go('/subscription'),
                ),
                const SizedBox(height: 24),
                Text(tr ? 'Güçlendiriciler' : 'Power-ups',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ShopRow(
                  icon: Icons.ac_unit_rounded,
                  color: const Color(0xFF1CB0F6),
                  title: tr ? 'Seri Dondurma' : 'Streak freeze',
                  subtitle: tr
                      ? 'Bir gün ara verince serin bozulmasın (yakında)'
                      : 'Protect your streak for a day (soon)',
                  actionLabel: tr ? 'YAKINDA' : 'SOON',
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
        border: Border.all(color: const Color(0xFF2C3B45)),
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
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: BorderSide(color: onAction == null ? Colors.white24 : _green),
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
          title: Text(tr ? 'Hesabı Kalıcı Sil' : 'Delete account',
              style: const TextStyle(color: Colors.white)),
          content: Text(
              tr
                  ? 'Hesabın ve tüm verilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.'
                  : 'Your account and all data will be permanently deleted. This cannot be undone.',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr ? 'Vazgeç' : 'Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr ? 'Sil' : 'Delete',
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
                Text(tr ? 'Tercihler' : 'Preferences',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _GroupLabel(tr ? 'Görünüm' : 'Appearance'),
                _ToggleRow(
                  label: tr ? 'Karanlık mod' : 'Dark mode',
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
                _GroupLabel(tr ? 'Hesap' : 'Account'),
                _MoreRow(
                    icon: Icons.workspace_premium_rounded,
                    label: tr ? 'Abonelik' : 'Subscription',
                    onTap: () => context.go('/subscription')),
                _MoreRow(
                    icon: Icons.logout_rounded,
                    label: tr ? 'Çıkış Yap' : 'Log out',
                    onTap: logout),
                _MoreRow(
                    icon: Icons.delete_forever_rounded,
                    label: tr ? 'Hesabı Kalıcı Sil' : 'Delete account',
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
  const SettingsRight({super.key, required this.tr, required this.onProfile});

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
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF24333D))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LinkCard(title: tr ? 'Hesap' : 'Account', links: [
              (tr ? 'Tercihler' : 'Preferences', () {}),
              (tr ? 'Profil' : 'Profile', onProfile),
              (tr ? 'Gizlilik ayarları' : 'Privacy settings',
                  () => context.go('/legal/privacy')),
            ]),
            const SizedBox(height: 16),
            _LinkCard(title: tr ? 'Abonelik' : 'Subscription', links: [
              (tr ? 'Bir plan seç' : 'Choose a plan',
                  () => context.go('/subscription')),
            ]),
            const SizedBox(height: 16),
            _LinkCard(title: tr ? 'Destek' : 'Support', links: [
              (tr ? 'Yardım Merkezi' : 'Help Center',
                  () => context.go('/legal/terms')),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C3B45)),
              ),
              child: InkWell(
                onTap: logout,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(tr ? 'OTURUMU KAPAT' : 'LOG OUT',
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
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
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
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
                  color: on ? Colors.white : Colors.white60,
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(tr ? 'Uygulama dili' : 'App language',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
        chip('tr', 'TR'),
        const SizedBox(width: 8),
        chip('en', 'EN'),
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
    final c = color ?? Colors.white;
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
              border: Border.all(color: const Color(0xFF2C3B45)),
            ),
            child: Row(children: [
              Icon(icon, color: c, size: 24),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF24333D))),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C3B45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(body,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ── Profile view (read-only) ──────────────────────────────────────────────────

const List<String> _trMonths = [
  '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

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
        child: Text(tr ? 'Giriş yapın' : 'Please sign in',
            style: const TextStyle(color: Colors.white54, fontSize: 15)),
      );
    }
    final name = [user.displayName, user.lastName]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    final username = user.email.contains('@')
        ? user.email.split('@').first
        : user.email;
    final d = user.createdAt;
    final joined = tr
        ? '${_trMonths[d.month]} ${d.year} tarihinde katıldı'
        : 'Joined ${d.month}/${d.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner + photo
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF26314F), Color(0xFF101626)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: _bg,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person,
                                  color: Colors.white38, size: 48)
                              : null,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black26,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                            tooltip: tr ? 'Düzenle' : 'Edit',
                            onPressed: onEdit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isNotEmpty ? name : username,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('@$username',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Colors.white38, size: 14),
                            const SizedBox(width: 6),
                            Text(joined,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 13)),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: _ProfileFriends(tr: tr)),
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
                                'L${phase.hsk} · ${tr ? 'Faz' : 'Phase'} ${phase.phaseIndex + 1}',
                          ),
                        ));
                      } else {
                        context.go('/learn');
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(tr ? 'BAŞLA' : 'START',
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
                Text(tr ? 'İstatistikler' : 'Statistics',
                    style: const TextStyle(
                        color: Colors.white,
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
                        label: tr ? 'Günlük seri' : 'Day streak'),
                    _StatCard(
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFFFFC800),
                        value: '${user.stats.totalScore}',
                        label: tr ? 'Toplam Puan' : 'Total XP'),
                    _StatCard(
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFFFF4B4B),
                        value: '${meta.hearts}',
                        label: tr ? 'Can' : 'Hearts'),
                    _StatCard(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF1CB0F6),
                        value: '${user.stats.questionsAnswered}',
                        label: tr ? 'Cevaplanan' : 'Answered'),
                  ],
                ),
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
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        );

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF24333D))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(tr ? 'Puan ve Sıralama' : 'Scores & Ranking'),
            _ProfileRank(tr: tr, score: score),
            const SizedBox(height: 20),
            header(tr ? 'Listelerim' : 'My Lists'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newListCtrl,
                  maxLength: 60,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: tr ? 'Yeni liste adı…' : 'New list name…',
                    hintStyle: const TextStyle(
                        color: Colors.white38, fontSize: 12),
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
            header(tr ? 'Günlük İstatistikler' : 'Daily Stats'),
            _ProfileDailyStats(tr: tr),
          ],
        ),
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr ? 'Arkadaşlarım' : 'My Friends',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              tr
                  ? 'Henüz arkadaşın yok — Puan Tabloları > Arkadaş Ara.'
                  : 'No friends yet — Leaderboards > Find Friends.',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
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
                              : const Icon(Icons.person,
                                  color: Colors.white38, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_rowName(f),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white24, size: 16),
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

class _FriendProfileDialog extends StatelessWidget {
  final Map<String, dynamic> friend;
  final bool tr;
  const _FriendProfileDialog({required this.friend, required this.tr});

  @override
  Widget build(BuildContext context) {
    final photo = friend['photo_url'] as String?;
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
                  : const Icon(Icons.person, color: Colors.white38, size: 36),
            ),
            const SizedBox(height: 10),
            Text(_rowName(friend),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text('@${friend['username'] ?? ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded,
                    color: Color(0xFF1CB0F6), size: 18),
                const SizedBox(width: 6),
                Text('${friend['score'] ?? 0} ${tr ? 'puan' : 'points'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr ? 'Kapat' : 'Close'),
        ),
      ],
    );
  }
}

// ── Profile: playlists (VoScreen "My Playlists") ──────────────────────────────

class _ProfilePlaylists extends ConsumerWidget {
  final bool tr;
  const _ProfilePlaylists({required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(myPlaylistsProvider).valueOrNull ?? const [];
    if (lists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2C3B45)),
        ),
        child: Text(
          tr
              ? 'Henüz listen yok — Alıştırma sekmesinde "Listeye Ekle" ile oluşturabilirsin.'
              : 'No lists yet — create one with "Add to Playlist" in Practice.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
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

    return Column(
      children: [
        for (final p in lists)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2C3B45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.playlist_play_rounded,
                    color: _green, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${p['count'] ?? 0} video',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 18),
                  tooltip: tr ? 'Listeyi sil' : 'Delete list',
                  onPressed: () => remove(p['id'] as String),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Profile: daily stats (VoScreen "Stats") ───────────────────────────────────

class _ProfileDailyStats extends ConsumerWidget {
  final bool tr;
  const _ProfileDailyStats({required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(dailyAnswerStatsProvider).valueOrNull ?? const [];

    Widget cell(String s, {Color? c, bool bold = false}) => Expanded(
          child: Text(s,
              style: TextStyle(
                  color: c ?? Colors.white70,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        );

    String fmtDay(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: rows.isEmpty
          ? Text(
              tr
                  ? 'Henüz istatistik yok — soru cevapladıkça burada birikecek.'
                  : 'No stats yet — they build up as you answer questions.',
              style: const TextStyle(color: Colors.white54, fontSize: 13))
          : Column(
              children: [
                Row(children: [
                  cell(tr ? 'Tarih' : 'Date', c: _green, bold: true),
                  cell(tr ? 'Toplam' : 'Total', c: _green, bold: true),
                  cell(tr ? 'Doğru' : 'Success', c: _green, bold: true),
                  cell(tr ? 'Yanlış' : 'Fail', c: _green, bold: true),
                ]),
                const Divider(color: Colors.white12, height: 18),
                for (final r in rows) ...[
                  Row(children: [
                    cell(fmtDay('${r['day']}')),
                    cell('${r['total']}'),
                    cell('${r['correct']}',
                        c: const Color(0xFF58CC02)),
                    cell(
                        '${((r['total'] as num?) ?? 0).toInt() - ((r['correct'] as num?) ?? 0).toInt()}',
                        c: const Color(0xFFFF4B4B)),
                  ]),
                  const SizedBox(height: 8),
                ],
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
        border: Border.all(color: const Color(0xFF2C3B45)),
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
                Text(tr ? 'Genel Sıralama' : 'Global Rank',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                Text(rank != null ? '#$rank' : '—',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.diamond_rounded,
              color: Color(0xFF1CB0F6), size: 18),
          const SizedBox(width: 6),
          Text('$score',
              style: const TextStyle(
                  color: Colors.white,
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
        border: Border.all(color: const Color(0xFF2C3B45)),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
              // Hero visual
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF58CC02), Color(0xFF1CB0F6)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF58CC02).withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                          top: 18,
                          left: 20,
                          child: Icon(Icons.auto_awesome,
                              color: Colors.white70, size: 26)),
                      const Positioned(
                          bottom: 20,
                          right: 26,
                          child: Icon(Icons.auto_awesome,
                              color: Colors.white54, size: 20)),
                      const Positioned(
                          top: 40,
                          right: 40,
                          child: Icon(Icons.star_rounded,
                              color: Colors.white38, size: 22)),
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                name != null
                    ? (tr ? 'Hoş geldin, $name!' : 'Welcome, $name!')
                    : (tr ? 'Hoş geldin!' : 'Welcome!'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                tr
                    ? 'Öğrenmeye kaldığın yerden devam et.'
                    : 'Continue learning where you left off.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(tr ? 'BAŞLA' : 'START',
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
