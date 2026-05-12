import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/social_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppColors.onSurface)),
        ),
        data: (user) => ListView(
          children: [
            _ProfileHeader(
              displayName: user?.displayName ?? 'Guest',
              email: user?.email ?? '',
              photoUrl: user?.photoUrl,
            ),
            const Divider(color: AppColors.surfaceVariant, height: 1),
            const _SectionHeader('Learning'),
            _InfoTile(
              icon: Icons.school,
              label: 'HSK Level',
              value: 'HSK ${user?.hskLevel ?? 1}',
              valueColor: AppColors.forHskLevel(user?.hskLevel ?? 1),
            ),
            _InfoTile(
              icon: Icons.auto_stories,
              label: 'Words Learned',
              value: '${user?.learnedWords.length ?? 0}',
            ),
            _InfoTile(
              icon: Icons.local_fire_department,
              label: 'Current Streak',
              value: '${user?.stats.currentStreak ?? 0} days',
            ),
            const Divider(color: AppColors.surfaceVariant, height: 1),
            const _SectionHeader('Subscription'),
            _InfoTile(
              icon: subscription.isPremium ? Icons.star : Icons.star_border,
              label: 'Plan',
              value: subscription.isPremium ? 'Premium' : 'Free',
              valueColor:
                  subscription.isPremium ? AppColors.premiumGold : null,
              onTap: subscription.isPremium
                  ? null
                  : () => context.push('/subscription'),
              trailing: subscription.isPremium
                  ? null
                  : const Icon(Icons.chevron_right,
                      color: AppColors.onSurfaceMuted),
            ),
            _InfoTile(
              icon: Icons.auto_awesome,
              label: 'AI Credits',
              value: '${user?.aiCredits ?? 0}',
            ),
            const Divider(color: AppColors.surfaceVariant, height: 1),
            const _SectionHeader('Legal'),
            _InfoTile(
              icon: Icons.description,
              label: 'Terms of Service',
              onTap: () => context.push('/legal/terms'),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceMuted),
            ),
            _InfoTile(
              icon: Icons.privacy_tip,
              label: 'Privacy Policy',
              onTap: () => context.push('/legal/privacy'),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceMuted),
            ),
            const Divider(color: AppColors.surfaceVariant, height: 1),
            if (kDebugMode) ...[
              const _SectionHeader('Developer'),
              _InfoTile(
                icon: Icons.admin_panel_settings,
                label: 'Admin Panel',
                onTap: () => context.push('/admin'),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.onSurfaceMuted),
              ),
              const Divider(color: AppColors.surfaceVariant, height: 1),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.wrongAnswer),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.wrongAnswer),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.wrongAnswer),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _confirmSignOut(context, ref),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.onSurface)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.wrongAnswer)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(socialRepositoryProvider).updateOnlineStatus(false);
      } catch (_) {}
      await Supabase.instance.client.auth.signOut();
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage:
                (photoUrl != null && !photoUrl!.startsWith('data:'))
                    ? NetworkImage(photoUrl!)
                    : null,
            child: (photoUrl == null || photoUrl!.startsWith('data:'))
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.onSurfaceMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.onSurfaceMuted, size: 22),
      title: Text(label,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 15)),
      trailing: trailing ??
          (value != null
              ? Text(
                  value!,
                  style: TextStyle(
                    color: valueColor ?? AppColors.onSurfaceMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null),
      onTap: onTap,
    );
  }
}
