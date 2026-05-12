import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';

// ── Hub Screen ────────────────────────────────────────────────────────────────

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const _SinomaTopBar(),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language,
                      size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                const Text(
                  '普通话学院',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = (constraints.maxWidth - 16) / 2;
                    final cardSize = size.clamp(120.0, 240.0);
                    return Center(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _HubCard(
                            size: cardSize,
                            icon: Icons.play_circle_outline,
                            label: 'Video',
                            color: AppColors.primary,
                            onTap: () => context.go('/home'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.menu_book_outlined,
                            label: 'Sözlük',
                            color: const Color(0xFF2196F3),
                            onTap: () => context.go('/dictionary/search'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.group_outlined,
                            label: 'Sosyal',
                            color: const Color(0xFF4CAF50),
                            onTap: () => context.go('/social'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.sports_esports_outlined,
                            label: 'Oyun',
                            color: const Color(0xFF9C27B0),
                            onTap: () => context.go('/games'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _SinomaTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _SinomaTopBar();

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final user = ref.watch(currentUserProvider).valueOrNull;
      final hskLevel = ref.watch(currentHskLevelProvider);
      final isAdmin = ref.watch(isAdminProvider);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return _buildBar(context, ref, user, hskLevel, isAdmin, isDark);
    });
  }

  Widget _buildBar(BuildContext context, WidgetRef ref, user, int hskLevel,
      bool isAdmin, bool isDark) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariant : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _LogoSection(hskLevel: hskLevel),
          const Spacer(),
          if (user != null) ...[
            _StatChip(
              icon: Icons.bolt_rounded,
              color: const Color(0xFFFF6B35),
              value: '${user.stats.currentStreak}',
              label: 'Streak',
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.play_circle_outline,
              color: AppColors.primary,
              value: '${user.stats.videosWatched}',
              label: 'Video',
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.star_outline_rounded,
              color: const Color(0xFFFFC107),
              value: _fmtScore(user.stats.totalScore),
              label: 'Skor',
            ),
          ],
          const Spacer(),
          _ProfileDropdown(user: user, isAdmin: isAdmin),
        ],
      ),
    );
  }

  static String _fmtScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return '$s';
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  final int hskLevel;
  const _LogoSection({required this.hskLevel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.language, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sinoma',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '普通话学院',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Dropdown ──────────────────────────────────────────────────────────

class _ProfileDropdown extends ConsumerStatefulWidget {
  final UserModel? user;
  final bool isAdmin;

  const _ProfileDropdown({required this.user, required this.isAdmin});

  @override
  ConsumerState<_ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends ConsumerState<_ProfileDropdown> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final entry = OverlayEntry(
      builder: (_) => _DropdownOverlay(
        link: _layerLink,
        user: widget.user,
        isAdmin: widget.isAdmin,
        onClose: _close,
      ),
    );
    Overlay.of(context).insert(entry);
    setState(() {
      _overlay = entry;
      _isOpen = true;
    });
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isOpen
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user, radius: 16),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Kullanıcı',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Skor: ${_fmtScore(user?.stats.totalScore ?? 0)}',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return '$s';
  }
}

// ── User Avatar (reusable) ────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double radius;

  const UserAvatar({super.key, required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl ?? '';
    final initials = _initials(
        user?.displayName ?? '', user?.lastName ?? '');

    ImageProvider? img;
    if (photoUrl.startsWith('http')) {
      img = NetworkImage(photoUrl);
    } else if (photoUrl.startsWith('data:image')) {
      try {
        img = MemoryImage(base64Decode(photoUrl.split(',').last));
      } catch (_) {}
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundImage: img,
      child: img == null
          ? Text(
              initials,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  static String _initials(String first, String last) {
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    final result = a + b;
    return result.isEmpty ? '?' : result;
  }
}

// ── Dropdown Overlay ──────────────────────────────────────────────────────────

class _DropdownOverlay extends ConsumerWidget {
  final LayerLink link;
  final UserModel? user;
  final bool isAdmin;
  final VoidCallback onClose;

  const _DropdownOverlay({
    required this.link,
    required this.user,
    required this.isAdmin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Material(
            color: Colors.transparent,
            child: _DropdownCard(
              user: user,
              isAdmin: isAdmin,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownCard extends ConsumerWidget {
  final UserModel? user;
  final bool isAdmin;
  final VoidCallback onClose;

  const _DropdownCard({
    required this.user,
    required this.isAdmin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF1E2030) : Colors.white;
    final divColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  UserAvatar(user: user, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Kullanıcı',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: divColor),

            _DropdownItem(
              icon: Icons.person_outline_rounded,
              label: 'Profil',
              isDark: isDark,
              onTap: () {
                onClose();
                final uid = user?.uid;
                if (uid != null) context.push('/profile/$uid');
              },
            ),
            _DropdownItem(
              icon: Icons.quiz_outlined,
              label: 'HSK Seviye Testi',
              isDark: isDark,
              onTap: () {
                onClose();
                context.push('/hsk-test');
              },
            ),
            _DropdownItem(
              icon: Icons.settings_outlined,
              label: 'Ayarlar',
              isDark: isDark,
              onTap: () {
                onClose();
                context.push('/settings');
              },
            ),

            if (isAdmin) ...[
              Divider(height: 1, thickness: 1, color: divColor),
              _DropdownItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Paneli',
                isDark: isDark,
                onTap: () {
                  onClose();
                  context.push('/admin');
                },
              ),
            ],

            Divider(height: 1, thickness: 1, color: divColor),

            // Dark theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode_outlined,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Koyu Tema',
                      style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isDark,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggleTheme(),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: divColor),

            _DropdownItem(
              icon: Icons.logout_rounded,
              label: 'Çıkış Yap',
              color: Colors.red.shade400,
              isDark: isDark,
              onTap: () async {
                onClose();
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/onboarding');
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;

  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.color ??
        (widget.isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87);
    final hoverBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 14),
              Text(widget.label,
                  style: TextStyle(color: fg, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hub Card ──────────────────────────────────────────────────────────────────

class _HubCard extends StatefulWidget {
  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.18)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovered ? widget.color : Colors.transparent,
              width: 2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 48, color: widget.color),
              const SizedBox(height: 14),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hovered ? widget.color : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
