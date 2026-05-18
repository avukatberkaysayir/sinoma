import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/social_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';

// ── Profile Screen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _firstNameCtrl   = TextEditingController();
  final _lastNameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _currPassCtrl    = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  Uint8List? _pendingPhotoBytes;
  DateTime?  _birthday;
  String?    _gender;
  String     _motherTongue        = 'tr';
  bool       _notificationsEnabled = true;
  bool       _saving               = false;
  bool       _passSaving           = false;
  bool       _initialized          = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(UserModel user) {
    if (_initialized) return;
    _firstNameCtrl.text  = user.displayName;
    _lastNameCtrl.text   = user.lastName;
    _emailCtrl.text      = user.email;
    _birthday            = user.birthday;
    _gender              = user.gender.isEmpty ? null : user.gender;
    _motherTongue        = user.motherTongue == 'en' ? 'en' : 'tr';
    _notificationsEnabled = user.notificationsEnabled;
    _initialized = true;

    // Sync app locale to the user's saved language (e.g. fresh browser)
    final code = _motherTongue;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(localeProvider).languageCode != code) {
        ref.read(localeProvider.notifier).setLocale(Locale(code));
      }
    });
  }

  // ── Photo picker ─────────────────────────────────────────────────────────────
  //
  // Must be synchronous up to input.click() so the browser treats it as a
  // direct user-gesture. Element must be in the DOM or the click is blocked.

  void _pickPhoto() {
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp'
      ..style.display = 'none';
    html.document.body!.append(input);
    input.onChange.listen((_) async {
      final file = input.files?.first;
      input.remove();
      if (file == null) return;
      await _readAndPreviewFile(file);
    });
    input.click();
  }

  Future<void> _readAndPreviewFile(html.File file) async {
    final completer = Completer<String?>();
    final reader   = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoad.listen((_) {
      debugPrint('[Photo] FileReader onLoad');
      completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) {
      debugPrint('[Photo] FileReader error: ${reader.error}');
      completer.complete(null);
    });
    final dataUrl = await completer.future;
    if (dataUrl == null || !mounted) {
      debugPrint('[Photo] dataUrl null, aborting');
      return;
    }
    try {
      final bytes = base64Decode(dataUrl.split(',').last);
      setState(() => _pendingPhotoBytes = bytes);
      debugPrint('[Photo] loaded ${bytes.length} bytes');
    } catch (e) {
      debugPrint('[Photo] decode error: $e');
    }
  }

  // Resize to 256×256 PNG, return as base64 data URL stored in Supabase.
  Future<String> _makeThumbnailDataUrl(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 256,
      targetHeight: 256,
    );
    final frame    = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    final pngBytes = byteData!.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }

  // ── Save (photo + profile together) ──────────────────────────────────────────

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      if (_pendingPhotoBytes != null) {
        final dataUrl = await _makeThumbnailDataUrl(_pendingPhotoBytes!);
        await ref.read(userRepositoryProvider).updatePhotoUrl(uid, dataUrl);
        ref.invalidate(currentUserProvider);
      }

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
        _snack('Profil kaydedildi.', success: true);
      }
    } catch (e) {
      if (mounted) _snack('Kayıt hatası: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Password save ─────────────────────────────────────────────────────────────

  Future<void> _savePassword() async {
    final current = _currPassCtrl.text.trim();
    final next    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _snack('Tüm şifre alanlarını doldurun.');
      return;
    }
    if (next != confirm) { _snack('Yeni şifreler eşleşmiyor.'); return; }
    if (next.length < 6) { _snack('Şifre en az 6 karakter olmalıdır.'); return; }
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
        _snack('Şifre güncellendi.', success: true);
      }
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _passSaving = false);
    }
  }

  // ── Account actions ───────────────────────────────────────────────────────────

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
    await Supabase.instance.client.auth.signOut();
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
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool success = false, bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error
          ? Colors.red.shade800
          : success
              ? Colors.green.shade800
              : null,
      duration: Duration(seconds: error ? 8 : 3),
    ));
  }

  bool get _hasEmailProvider {
    final identities =
        Supabase.instance.client.auth.currentUser?.identities ?? [];
    return identities.any((i) => i.provider == 'email');
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isGuest   = ref.watch(isGuestProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user      = userAsync.valueOrNull;
    final isDark    = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (user != null) _initFromUser(user);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Profil Fotoğrafı card ──────────────────────────────────
                _ProfileCard(
                  title: 'Profil Fotoğrafı',
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isGuest ? null : _pickPhoto,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            children: [
                              _buildAvatar(user),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.surface, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 13,
                                      color: AppColors.onSurfaceMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isGuest)
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: Text(
                                _pendingPhotoBytes != null
                                    ? 'Fotoğraf seçildi ✓'
                                    : 'Fotoğrafı Değiştir',
                                style: TextStyle(
                                  color: _pendingPhotoBytes != null
                                      ? Colors.green
                                      : AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Text(
                            'JPG, PNG — max 5MB',
                            style: TextStyle(
                                color: AppColors.onSurfaceMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Profil card ────────────────────────────────────────────
                _ProfileCard(
                  title: 'Profil',
                  child: isGuest
                      ? _GuestNotice()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                    child: _Field(
                                        label: 'Ad',
                                        controller: _firstNameCtrl)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _Field(
                                        label: 'Soyad',
                                        controller: _lastNameCtrl)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              label: 'Email',
                              controller: _emailCtrl,
                              readOnly: true,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateField(
                                    label: 'Doğum Tarihi',
                                    value: _birthday,
                                    onPicked: (d) =>
                                        setState(() => _birthday = d),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DropdownField<String?>(
                                    label: 'Cinsiyet',
                                    value: _gender,
                                    items: const [
                                      DropdownMenuItem(
                                          value: null,
                                          child: Text('Seçiniz')),
                                      DropdownMenuItem(
                                          value: 'male',
                                          child: Text('Erkek')),
                                      DropdownMenuItem(
                                          value: 'female',
                                          child: Text('Kadın')),
                                      DropdownMenuItem(
                                          value: 'other',
                                          child: Text('Diğer')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _gender = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _DropdownField<String>(
                              label: 'Dil',
                              value: _motherTongue == 'en' ? 'en' : 'tr',
                              items: const [
                                DropdownMenuItem(
                                    value: 'tr', child: Text('Türkçe 🇹🇷')),
                                DropdownMenuItem(
                                    value: 'en', child: Text('English 🇬🇧')),
                              ],
                              onChanged: (v) {
                                final code = v ?? 'tr';
                                setState(() => _motherTongue = code);
                                ref.read(localeProvider.notifier)
                                    .setLocale(Locale(code));
                              },
                            ),
                          ],
                        ),
                ),

                if (!isGuest) ...[
                  const SizedBox(height: 16),

                  // ── Save button ──────────────────────────────────────────
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Değişiklikleri Kaydet',
                            style: TextStyle(fontSize: 15)),
                  ),
                ],

                // ── Password card (email users only) ───────────────────────
                if (!isGuest && _hasEmailProvider) ...[
                  const SizedBox(height: 16),
                  _ProfileCard(
                    title: 'Şifre',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        _Field(
                            label: 'Mevcut Şifre',
                            controller: _currPassCtrl,
                            obscure: true),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                                child: _Field(
                                    label: 'Yeni Şifre',
                                    controller: _newPassCtrl,
                                    obscure: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _Field(
                                    label: 'Yeni Şifre Tekrar',
                                    controller: _confirmPassCtrl,
                                    obscure: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _passSaving ? null : _savePassword,
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            child: _passSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Şifreyi Güncelle'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Hesap card ─────────────────────────────────────────────
                const SizedBox(height: 16),
                _ProfileCard(
                  title: 'Hesap',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.dark_mode_outlined,
                              size: 18, color: AppColors.onSurfaceMuted),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Karanlık Tema',
                                style: TextStyle(
                                    color: AppColors.onSurface, fontSize: 14)),
                          ),
                          Switch(
                            value: isDark,
                            activeThumbColor: AppColors.primary,
                            onChanged: (_) =>
                                ref.read(themeModeProvider.notifier).toggleTheme(),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.surface, height: 20),
                      _ActionRow(
                        icon: Icons.logout,
                        label: 'Çıkış Yap',
                        onTap: _confirmSignOut,
                      ),
                      const SizedBox(height: 4),
                      _ActionRow(
                        icon: Icons.delete_outline,
                        label: 'Hesabı Sil',
                        color: AppColors.wrongAnswer,
                        onTap: _confirmDeleteAccount,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel? user) {
    final initials = _initials(user?.displayName ?? '', user?.lastName ?? '');

    // In-session preview: bytes from picker (before save)
    if (_pendingPhotoBytes != null) {
      return ClipOval(
        child: Image.memory(
          _pendingPhotoBytes!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    final photoUrl = user?.photoUrl ?? '';
    if (photoUrl.isNotEmpty) {
      // Base64 data URL stored in Firestore — no network request needed
      if (photoUrl.startsWith('data:')) {
        final b64 = photoUrl.contains(',') ? photoUrl.split(',').last : photoUrl;
        try {
          final bytes = base64Decode(b64);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        } catch (_) {
          return _initialsCircle(initials);
        }
      }
      // Legacy: plain HTTPS URL (old uploads)
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(initials),
        ),
      );
    }

    return _initialsCircle(initials);
  }

  Widget _initialsCircle(String initials) => Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }
}

// ── Card wrapper ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ProfileCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool readOnly;

  const _Field({
    required this.label,
    required this.controller,
    this.obscure  = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          readOnly: readOnly,
          style: TextStyle(
              color: readOnly ? AppColors.onSurfaceMuted : AppColors.onSurface,
              fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly
                ? AppColors.surface.withValues(alpha: 0.5)
                : AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surface)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surface)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── Date picker field ─────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPicked;
  const _DateField(
      {required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final text = value != null ? DateFormat('dd/MM/yyyy').format(value!) : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(2000),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx)
                        .colorScheme
                        .copyWith(primary: AppColors.primary)),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface),
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
                        fontSize: 14),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppColors.onSurfaceMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dropdown field ────────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surfaceVariant,
          style:
              const TextStyle(color: AppColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surface)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surface)),
          ),
        ),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(color: c, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Guest notice ──────────────────────────────────────────────────────────────

class _GuestNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.person_outline,
            size: 40, color: AppColors.onSurfaceMuted),
        const SizedBox(height: 10),
        const Text(
          'Misafir kullanıcılar profil düzenleyemez.',
          style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => GoRouter.of(context).go('/onboarding'),
          icon: const Icon(Icons.login),
          label: const Text('Hesap Oluştur / Giriş Yap'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ],
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────

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
      title:   Text(title,   style: const TextStyle(color: AppColors.onSurface)),
      content: Text(message, style: const TextStyle(color: AppColors.onSurfaceMuted)),
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
                color: danger ? AppColors.wrongAnswer : AppColors.primary),
          ),
        ),
      ],
    );
  }
}
