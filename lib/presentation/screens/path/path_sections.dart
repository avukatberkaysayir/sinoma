import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/video_segment_model.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../home/inline_player_section.dart';

// Duolingo palette (kept local to this file).
const _green = Color(0xFF58CC02);
const _bg = Color(0xFF131F2A);
const _panel = Color(0xFF1C2A35);

// ── Video center (free watch) ─────────────────────────────────────────────────

class VideoCenter extends ConsumerWidget {
  final bool tr;
  const VideoCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class VideoFiltersRight extends ConsumerWidget {
  final bool tr;
  const VideoFiltersRight({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hsk = ref.watch(selectedHskFilterProvider);
    final life = ref.watch(selectedLifeCategoryProvider);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr ? 'Filtreler' : 'Filters',
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const _Label('HSK'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var h = 1; h <= 6; h++)
                _Chip(label: 'HSK $h', selected: hsk.contains(h), onTap: () => toggleHsk(h)),
            ]),
            const SizedBox(height: 18),
            _Label(tr ? 'KONU' : 'TOPIC'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in LifeCategory.values)
                _Chip(
                    label: LifeCategory.labelFor(c.name, isTr: tr),
                    selected: life.contains(c.name),
                    onTap: () => toggleLife(c.name)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Leaderboard ───────────────────────────────────────────────────────────────

class LeaderboardCenter extends ConsumerWidget {
  final bool tr;
  const LeaderboardCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    return board.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _green)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
      data: (users) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Text(tr ? 'Yakut Ligi' : 'Ruby League',
                      style: const TextStyle(
                          color: _green, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(tr ? 'Bu haftanın puan sıralaması' : "This week's ranking",
                      style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 20),
                  for (var i = 0; i < users.length; i++)
                    _LeaderRow(rank: i + 1, user: users[i], isMe: users[i]['id'] == myUid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> user;
  final bool isMe;
  const _LeaderRow({required this.rank, required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = (user['display_name'] as String?)?.trim();
    final score = ((user['stats'] as Map?)?['totalScore'] as num?)?.toInt() ?? 0;
    final photo = user['photo_url'] as String?;
    final medal = rank == 1
        ? const Color(0xFFFFC800)
        : rank == 2
            ? const Color(0xFFB8C4CC)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? _green.withValues(alpha: 0.15) : _panel,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: _green) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: TextStyle(color: medal, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: _bg,
            backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
            child: photo?.isNotEmpty == true
                ? null
                : const Icon(Icons.person, color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name?.isNotEmpty == true ? name! : 'Öğrenci',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.diamond_rounded, color: Color(0xFF1CB0F6), size: 16),
          const SizedBox(width: 4),
          Text('$score',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Quests ────────────────────────────────────────────────────────────────────

class QuestsCenter extends ConsumerWidget {
  final bool tr;
  const QuestsCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(pathMetaProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8A5CF6), Color(0xFFCE82FF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr ? 'Tekrar hoş geldin!' : 'Welcome back!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                          tr
                              ? 'Görevleri tamamlayarak ilerle!'
                              : 'Complete quests to progress!',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(tr ? 'Günlük Görevler' : 'Daily quests',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _QuestRow(
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFFC800),
                    label: tr ? 'Bir faz tamamla' : 'Complete one phase'),
                const SizedBox(height: 10),
                _QuestRow(
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF9600),
                    label: tr
                        ? 'Seriyi sürdür (${meta.streak} gün)'
                        : 'Keep your streak (${meta.streak} days)'),
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
  const _QuestRow({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
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

// ── More ──────────────────────────────────────────────────────────────────────

class MoreCenter extends ConsumerWidget {
  final bool tr;
  const MoreCenter({super.key, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      final router = GoRouter.of(context);
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      router.go('/');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _MoreRow(
                    icon: Icons.settings_rounded,
                    label: tr ? 'Ayarlar' : 'Settings',
                    onTap: () => context.go('/settings')),
                _MoreRow(
                    icon: Icons.workspace_premium_rounded,
                    label: tr ? 'Abonelik' : 'Subscription',
                    onTap: () => context.go('/subscription')),
                _MoreRow(
                    icon: Icons.menu_book_rounded,
                    label: tr ? 'Şartlar' : 'Terms',
                    onTap: () => context.go('/legal/terms')),
                _MoreRow(
                    icon: Icons.privacy_tip_rounded,
                    label: tr ? 'Gizlilik' : 'Privacy',
                    onTap: () => context.go('/legal/privacy')),
                _MoreRow(
                    icon: Icons.logout_rounded,
                    label: tr ? 'Çıkış Yap' : 'Log out',
                    color: const Color(0xFFFF4B4B),
                    onTap: logout),
              ],
            ),
          ),
        ),
      ],
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _green : _bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _green : const Color(0xFF3A4A54)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
