import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';

// ── Section enum ──────────────────────────────────────────────────────────────

enum _Section {
  profile,
  myPlaylists,
  subscriptions,
  myObservationGroups,
  myObservers,
  stats,
  scoresRankings,
}

extension _SectionLabel on _Section {
  String get label => switch (this) {
        _Section.profile              => 'Profil',
        _Section.myPlaylists          => 'Oynatma Listelerim',
        _Section.subscriptions        => 'Abonelikler',
        _Section.myObservationGroups  => 'Gözlem Gruplarım',
        _Section.myObservers          => 'Gözlemcilerim',
        _Section.stats                => 'İstatistikler',
        _Section.scoresRankings       => 'Puanlar & Sıralamalar',
      };
}

// ── Profile Screen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _Section _section          = _Section.profile;
  bool _playlistsExpanded    = true;
  bool _observationsExpanded = true;
  bool _uploadingPhoto       = false;

  void _select(_Section s) => setState(() => _section = s);

  Future<void> _pickAndUploadPhoto() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext  = picked.name.toLowerCase();
      final mime = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final fileName = ext.endsWith('.png') ? 'avatar.png' : 'avatar.jpg';

      final storageRef =
          FirebaseStorage.instance.ref('users/$uid/$fileName');
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: mime),
      );
      final url = await storageRef.getDownloadURL();
      await ref.read(userRepositoryProvider).updatePhotoUrl(uid, url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı güncellendi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Çıkış Yap',
        message: 'Hesabınızdan çıkmak istediğinizden emin misiniz?',
        confirmLabel: 'Çıkış Yap',
        danger: true,
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(socialRepositoryProvider).updateOnlineStatus(false);
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/language');
  }

  Future<void> _confirmDeleteAccount() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Hesabı Sil',
        message:
            'Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.',
        confirmLabel: 'Hesabı Sil',
        danger: true,
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(userRepositoryProvider).deleteAccount(uid);
      if (mounted) context.go('/language');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        _showError('Güvenlik için lütfen önce tekrar giriş yapın.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_section.label),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide)
                _Sidebar(
                  selected: _section,
                  playlistsExpanded: _playlistsExpanded,
                  observationsExpanded: _observationsExpanded,
                  onSelect: _select,
                  onTogglePlaylists: () => setState(
                      () => _playlistsExpanded = !_playlistsExpanded),
                  onToggleObservations: () => setState(
                      () => _observationsExpanded = !_observationsExpanded),
                  onSignOut: _confirmSignOut,
                  onDeleteAccount: _confirmDeleteAccount,
                  onAvatarTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  uploadingPhoto: _uploadingPhoto,
                ),
              Expanded(
                child: _buildContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() => switch (_section) {
        _Section.profile => const _ProfileFormContent(key: ValueKey('profile')),
        _Section.stats   => _StatsContent(),
        _Section.scoresRankings => const _ComingSoonContent(
            icon: Icons.leaderboard_outlined,
            label: 'Puanlar & Sıralamalar'),
        _Section.myPlaylists => const _ComingSoonContent(
            icon: Icons.playlist_play_outlined,
            label: 'Oynatma Listelerim'),
        _Section.subscriptions => const _ComingSoonContent(
            icon: Icons.subscriptions_outlined,
            label: 'Abonelikler'),
        _Section.myObservationGroups => const _ComingSoonContent(
            icon: Icons.group_outlined,
            label: 'Gözlem Gruplarım'),
        _Section.myObservers => const _ComingSoonContent(
            icon: Icons.visibility_outlined,
            label: 'Gözlemcilerim'),
      };
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final _Section selected;
  final bool playlistsExpanded;
  final bool observationsExpanded;
  final void Function(_Section) onSelect;
  final VoidCallback onTogglePlaylists;
  final VoidCallback onToggleObservations;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final VoidCallback? onAvatarTap;
  final bool uploadingPhoto;

  const _Sidebar({
    required this.selected,
    required this.playlistsExpanded,
    required this.observationsExpanded,
    required this.onSelect,
    required this.onTogglePlaylists,
    required this.onToggleObservations,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.onAvatarTap,
    this.uploadingPhoto = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProvider);
    final hskLevel   = ref.watch(currentHskLevelProvider);
    final isDark     = ref.watch(themeModeProvider) == ThemeMode.dark;

    final user = userAsync.valueOrNull;
    final initials = _buildInitials(
      user?.displayName ?? '',
      user?.lastName ?? '',
    );

    return Container(
      width: 280,
      color: AppColors.surfaceVariant,
      child: Column(
        children: [
          // ── User card ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            color: AppColors.surface,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        backgroundImage: (user?.photoUrl.isNotEmpty == true)
                            ? NetworkImage(user!.photoUrl)
                            : null,
                        child: uploadingPhoto
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : (user?.photoUrl.isEmpty ?? true)
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                      ),
                      if (!uploadingPhoto)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surfaceVariant, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null
                            ? '${user.displayName} ${user.lastName}'.trim()
                            : 'Misafir',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HSK $hskLevel  •  ${_formatScore(user?.stats.totalScore ?? 0)} puan',
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Nav items ─────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  active: selected == _Section.profile,
                  onTap: () => onSelect(_Section.profile),
                ),

                // Playlists expandable
                _NavExpandable(
                  icon: Icons.format_list_bulleted,
                  label: 'Oynatma Listeleri',
                  expanded: playlistsExpanded,
                  onToggle: onTogglePlaylists,
                  children: [
                    _NavSubItem(
                      label: 'Oynatma Listelerim',
                      active: selected == _Section.myPlaylists,
                      onTap: () => onSelect(_Section.myPlaylists),
                    ),
                    _NavSubItem(
                      label: 'Abonelikler',
                      active: selected == _Section.subscriptions,
                      onTap: () => onSelect(_Section.subscriptions),
                    ),
                  ],
                ),

                // Observations expandable
                _NavExpandable(
                  icon: Icons.group_outlined,
                  label: 'Gözlemler',
                  expanded: observationsExpanded,
                  onToggle: onToggleObservations,
                  children: [
                    _NavSubItem(
                      label: 'Gözlem Gruplarım',
                      active: selected == _Section.myObservationGroups,
                      onTap: () => onSelect(_Section.myObservationGroups),
                    ),
                    _NavSubItem(
                      label: 'Gözlemcilerim',
                      active: selected == _Section.myObservers,
                      onTap: () => onSelect(_Section.myObservers),
                    ),
                  ],
                ),

                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'İstatistikler',
                  active: selected == _Section.stats,
                  onTap: () => onSelect(_Section.stats),
                ),
                _NavItem(
                  icon: Icons.emoji_events_outlined,
                  label: 'Puanlar & Sıralamalar',
                  active: selected == _Section.scoresRankings,
                  onTap: () => onSelect(_Section.scoresRankings),
                ),

                const Divider(color: AppColors.surface, height: 24),

                // Dark theme toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.dark_mode_outlined,
                          size: 20, color: AppColors.onSurfaceMuted),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Karanlık Tema',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch(
                        value: isDark,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) =>
                            ref.read(themeModeProvider.notifier).toggleTheme(),
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.surface, height: 16),

                _NavItem(
                  icon: Icons.delete_outline,
                  label: 'Hesabı Sil',
                  iconColor: AppColors.wrongAnswer,
                  labelColor: AppColors.wrongAnswer,
                  onTap: onDeleteAccount,
                ),
                _NavItem(
                  icon: Icons.logout,
                  label: 'Çıkış Yap',
                  iconColor: AppColors.wrongAnswer,
                  labelColor: AppColors.wrongAnswer,
                  onTap: onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildInitials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }

  String _formatScore(int score) {
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
    return '$score';
  }
}

// ── Sidebar nav widgets ───────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : (iconColor ?? AppColors.onSurfaceMuted);
    final textColor = active
        ? AppColors.primary
        : (labelColor ?? AppColors.onSurface);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: active
            ? BoxDecoration(
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
                color: AppColors.primary.withValues(alpha: 0.07),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavExpandable extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _NavExpandable({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}

class _NavSubItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavSubItem({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.only(left: 50, right: 16, top: 10, bottom: 10),
        decoration: active
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.onSurfaceMuted,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Profile Form Content ──────────────────────────────────────────────────────

class _ProfileFormContent extends ConsumerStatefulWidget {
  const _ProfileFormContent({super.key});

  @override
  ConsumerState<_ProfileFormContent> createState() =>
      _ProfileFormContentState();
}

class _ProfileFormContentState
    extends ConsumerState<_ProfileFormContent> {
  final _formKey        = GlobalKey<FormState>();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _currPassCtrl   = TextEditingController();
  final _newPassCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  DateTime? _birthday;
  String?   _gender;
  String    _motherTongue        = 'tr';
  bool      _notificationsEnabled = true;
  bool      _profileSaving        = false;
  bool      _passSaving           = false;
  bool      _initialized          = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(UserModel user) {
    if (_initialized) return;
    _firstNameCtrl.text  = user.displayName;
    _lastNameCtrl.text   = user.lastName;
    _birthday            = user.birthday;
    _gender              = user.gender.isEmpty ? null : user.gender;
    _motherTongue        = user.motherTongue;
    _notificationsEnabled = user.notificationsEnabled;
    _initialized = true;
  }

  int _profileCompletion(UserModel? user) {
    if (user == null) return 0;
    var pct = 0;
    if (user.displayName.isNotEmpty) pct += 20;
    if (user.lastName.isNotEmpty)    pct += 20;
    if (user.birthday != null)       pct += 20;
    if (user.gender.isNotEmpty)      pct += 20;
    if (user.photoUrl.isNotEmpty)    pct += 20;
    return pct;
  }

  Future<void> _saveProfile(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _profileSaving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfileDetails(
            uid: uid,
            displayName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            birthday: _birthday,
            gender: _gender ?? '',
            motherTongue: _motherTongue,
            notificationsEnabled: _notificationsEnabled,
          );
      if (mounted) {
        _initialized = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  Future<void> _savePassword() async {
    final current = _currPassCtrl.text.trim();
    final next    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _snack('Tüm şifre alanlarını doldurun.');
      return;
    }
    if (next != confirm) {
      _snack('Yeni şifreler eşleşmiyor.');
      return;
    }
    if (next.length < 6) {
      _snack('Şifre en az 6 karakter olmalıdır.');
      return;
    }

    setState(() => _passSaving = true);
    try {
      await ref.read(userRepositoryProvider).changePassword(
            currentPassword: current,
            newPassword: next,
          );
      if (mounted) {
        _currPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _snack('Şifre güncellendi.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(_authError(e));
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _passSaving = false);
    }
  }

  String _authError(FirebaseAuthException e) => switch (e.code) {
        'wrong-password'       => 'Mevcut şifre hatalı.',
        'invalid-credential'   => 'Mevcut şifre hatalı.',
        'too-many-requests'    => 'Çok fazla deneme. Lütfen bekleyin.',
        _                      => e.message ?? e.code,
      };

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool get _hasEmailProvider =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  @override
  Widget build(BuildContext context) {
    final isGuest  = ref.watch(isGuestProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user     = userAsync.valueOrNull;

    if (user != null) _initFromUser(user);

    final completion = _profileCompletion(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Profile card ────────────────────────────────────────────────
          _SectionCard(
            header: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 20, color: AppColors.onSurface),
                const SizedBox(width: 8),
                const Text(
                  'Profil',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _CompletionBadge(pct: completion),
              ],
            ),
            child: isGuest
                ? _GuestNotice()
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Name + Last Name
                        _FormRow(children: [
                          _FormField(
                            label: 'Ad',
                            controller: _firstNameCtrl,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ad gerekli'
                                : null,
                          ),
                          _FormField(
                            label: 'Soyad',
                            controller: _lastNameCtrl,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // Birthday + Gender
                        _FormRow(children: [
                          _DateField(
                            label: 'Doğum Tarihi',
                            value: _birthday,
                            onPicked: (d) => setState(() => _birthday = d),
                          ),
                          _DropdownField<String?>(
                            label: 'Cinsiyet',
                            value: _gender,
                            items: const [
                              DropdownMenuItem(
                                  value: null,
                                  child: Text('Seçiniz')),
                              DropdownMenuItem(
                                  value: 'male', child: Text('Erkek')),
                              DropdownMenuItem(
                                  value: 'female', child: Text('Kadın')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Diğer')),
                            ],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // Mother tongue + Notifications
                        _FormRow(children: [
                          _DropdownField<String>(
                            label: 'Ana Dil',
                            value: _motherTongue,
                            items: const [
                              DropdownMenuItem(
                                  value: 'tr', child: Text('Türkçe')),
                              DropdownMenuItem(
                                  value: 'en', child: Text('İngilizce')),
                              DropdownMenuItem(
                                  value: 'vi', child: Text('Vietnamca')),
                              DropdownMenuItem(
                                  value: 'zh', child: Text('Çince')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Diğer')),
                            ],
                            onChanged: (v) =>
                                setState(() => _motherTongue = v ?? 'tr'),
                          ),
                          _DropdownField<bool>(
                            label: 'Bildirim almak ister misiniz?',
                            value: _notificationsEnabled,
                            items: const [
                              DropdownMenuItem(
                                  value: true, child: Text('Evet')),
                              DropdownMenuItem(
                                  value: false, child: Text('Hayır')),
                            ],
                            onChanged: (v) => setState(
                                () => _notificationsEnabled = v ?? true),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _profileSaving
                                ? null
                                : () => _saveProfile(user?.uid ?? ''),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(140, 44),
                            ),
                            child: _profileSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Kaydet'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // ── Password card (email users only) ────────────────────────────
          if (!isGuest && _hasEmailProvider)
            _SectionCard(
              header: const Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 20, color: AppColors.onSurface),
                  SizedBox(width: 8),
                  Text(
                    'Şifre',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _FormField(
                    label: 'Mevcut Şifre',
                    controller: _currPassCtrl,
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  _FormRow(children: [
                    _FormField(
                      label: 'Yeni Şifre',
                      controller: _newPassCtrl,
                      obscure: true,
                    ),
                    _FormField(
                      label: 'Yeni Şifre Tekrar',
                      controller: _confirmPassCtrl,
                      obscure: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _passSaving ? null : _savePassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(140, 44),
                      ),
                      child: _passSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Kaydet'),
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

// ── Stats Content ─────────────────────────────────────────────────────────────

class _StatsContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user      = userAsync.valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _SectionCard(
        header: const Row(
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 20, color: AppColors.onSurface),
            SizedBox(width: 8),
            Text(
              'İstatistikler',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _FormRow(children: [
              _StatCard(
                  icon: Icons.emoji_events,
                  label: 'Toplam Puan',
                  value: _fmt(user?.stats.totalScore ?? 0)),
              _StatCard(
                  icon: Icons.local_fire_department,
                  label: 'Mevcut Seri',
                  value: '${user?.stats.currentStreak ?? 0} gün'),
            ]),
            const SizedBox(height: 12),
            _FormRow(children: [
              _StatCard(
                  icon: Icons.play_circle_outline,
                  label: 'İzlenen Video',
                  value: '${user?.stats.videosWatched ?? 0}'),
              _StatCard(
                  icon: Icons.quiz_outlined,
                  label: 'Cevaplanan Soru',
                  value: '${user?.stats.questionsAnswered ?? 0}'),
            ]),
            const SizedBox(height: 12),
            _FormRow(children: [
              _StatCard(
                  icon: Icons.auto_stories_outlined,
                  label: 'Öğrenilen Kelime',
                  value: '${user?.learnedWords.length ?? 0}'),
              _StatCard(
                  icon: Icons.auto_awesome,
                  label: 'AI Kredisi',
                  value: '${user?.aiCredits ?? 0}'),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12,
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

// ── Coming Soon Content ───────────────────────────────────────────────────────

class _ComingSoonContent extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonContent({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu özellik yakında eklenecek.',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

// ── Form helpers ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget header;
  final Widget child;

  const _SectionCard({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 4),
          const Divider(color: AppColors.surface, height: 16),
          child,
        ],
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  final int pct;
  const _CompletionBadge({required this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Profil Tamamlandı',
          style: TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 100,
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation(
                    pct == 100 ? Colors.green : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '%$pct',
              style: TextStyle(
                color: pct == 100 ? Colors.green : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormRow extends StatelessWidget {
  final List<Widget> children;
  const _FormRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: children[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      },
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.surfaceVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.surfaceVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPicked;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? DateFormat('dd/MM/yyyy').format(value!)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(2000),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context)
                      .colorScheme
                      .copyWith(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text.isEmpty ? 'Seçiniz' : text,
                    style: TextStyle(
                      color: text.isEmpty
                          ? AppColors.onSurfaceMuted
                          : AppColors.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.onSurfaceMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surfaceVariant,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.surfaceVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.surfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.person_outline,
              size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          const Text(
            'Misafir kullanıcılar profil düzenleyemez.',
            style: TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => GoRouter.of(context).go('/onboarding'),
            icon: const Icon(Icons.login),
            label: const Text('Hesap Oluştur / Giriş Yap'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceVariant,
      title: Text(title,
          style: const TextStyle(color: AppColors.onSurface)),
      content: Text(message,
          style: const TextStyle(color: AppColors.onSurfaceMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: danger ? AppColors.wrongAnswer : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
