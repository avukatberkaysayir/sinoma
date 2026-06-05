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
    final user = ref.watch(currentUserProvider).valueOrNull;
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
                Text(name.isNotEmpty ? name : username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('@$username',
                    style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Text(joined,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          : currentPhaseFor(topics, progress);
                      if (phase != null) {
                        ref
                            .read(selectedTopicHskProvider.notifier)
                            .state = phase.hsk;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PhaseRunnerScreen(
                            phase: phase,
                            title:
                                'HSK ${phase.hsk} · ${tr ? 'Faz' : 'Phase'} ${phase.phaseIndex + 1}',
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
