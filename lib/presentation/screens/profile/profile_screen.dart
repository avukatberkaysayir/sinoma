import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:web/web.dart' as web;

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

// ── File-level photo cache ─────────────────────────────────────────────────────
// Survives State recreation (locale change causes full tree rebuild in SinomaApp).
// Same data URL → always same Uint8List reference → MemoryImage never reloads.
final Map<String, Uint8List> _photoByteCache = {};
var _lastKnownPhotoUrl = ''; // last non-empty URL seen, for null-user frames

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
  final _usernameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _currPassCtrl    = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  Uint8List? _pendingPhotoBytes;
  DateTime?  _birthday;
  String?    _gender;
  String     _motherTongue        = 'tr';
  bool?      _pendingDark; // theme pick, applied with "Değişiklikleri Kaydet"
  bool       _notificationsEnabled = true;
  bool       _saving               = false;
  bool       _passSaving           = false;
  bool       _initialized          = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
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
    _usernameCtrl.text   = user.username;
    _emailCtrl.text      = user.email;
    _birthday            = user.birthday;
    _gender              = user.gender.isEmpty ? null : user.gender;
    // Mirror whatever language the app is currently running in (the landing
    // pick) — never a hardcoded default.
    final current = ref.read(localeProvider).languageCode;
    _motherTongue = kSupportedUiLanguages.contains(current)
        ? current
        : (kSupportedUiLanguages.contains(user.motherTongue)
            ? user.motherTongue
            : 'tr');
    _notificationsEnabled = user.notificationsEnabled;
    _initialized = true;
  }

  // ── Photo picker ─────────────────────────────────────────────────────────────
  //
  // Must be synchronous up to input.click() so the browser treats it as a
  // direct user-gesture. Element must be in the DOM or the click is blocked.

  void _pickPhoto() {
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/jpeg,image/png,image/webp';
    input.style.display = 'none';
    web.document.body!.append(input);
    input.addEventListener(
      'change',
      (web.Event _) {
        final file = input.files?.item(0);
        input.remove();
        if (file == null) return;
        _readAndPreviewFile(file);
      }.toJS,
    );
    input.click();
  }

  Future<void> _readAndPreviewFile(web.File file) async {
    final completer = Completer<String?>();
    final reader = web.FileReader();
    reader.addEventListener(
      'load',
      (web.Event _) {
        debugPrint('[Photo] FileReader onLoad');
        final result = reader.result;
        completer.complete(result != null ? (result as JSString).toDart : null);
      }.toJS,
    );
    reader.addEventListener(
      'error',
      (web.Event _) {
        debugPrint('[Photo] FileReader error');
        completer.complete(null);
      }.toJS,
    );
    reader.readAsDataURL(file);
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
    final l10n = AppL10n.fromCode(ref.read(localeProvider).languageCode);
    setState(() => _saving = true);
    try {
      if (_pendingPhotoBytes != null) {
        final dataUrl = await _makeThumbnailDataUrl(_pendingPhotoBytes!);
        await ref.read(userRepositoryProvider).updatePhotoUrl(uid, dataUrl);
        if (mounted) setState(() => _pendingPhotoBytes = null);
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
      // Public handle: lowercase slug, unique in DB (constraint errors snack).
      final uname = _usernameCtrl.text.trim().toLowerCase();
      if (uname.isNotEmpty) {
        await ref.read(userRepositoryProvider).updateUsername(uid, uname);
      }
      ref.invalidate(currentUserProvider);

      // Theme and UI language only take effect on save — the form above the
      // button is a draft until it's confirmed.
      if (_pendingDark != null) {
        await ref.read(themeModeProvider.notifier).setDark(_pendingDark!);
        _pendingDark = null;
      }
      if (ref.read(localeProvider).languageCode != _motherTongue &&
          kSupportedUiLanguages.contains(_motherTongue)) {
        final code = _motherTongue;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(localeProvider.notifier).setLocale(Locale(code));
        });
      }

      if (mounted) _snack(l10n.profileSaved, success: true);
    } catch (e) {
      if (mounted) _snack('${l10n.saveError}$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Password save ─────────────────────────────────────────────────────────────

  Future<void> _savePassword() async {
    final l10n    = AppL10n.fromCode(ref.read(localeProvider).languageCode);
    final current = _currPassCtrl.text.trim();
    final next    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _snack(l10n.fillAllPassFields); return;
    }
    if (next != confirm) { _snack(l10n.passwordMismatch); return; }
    if (next.length < 6) { _snack(l10n.passwordTooShort); return; }
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
        _snack(l10n.passwordUpdated, success: true);
      }
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _passSaving = false);
    }
  }

  // ── Account actions ───────────────────────────────────────────────────────────

  Future<void> _confirmSignOut() async {
    final l10n = AppL10n.fromCode(ref.read(localeProvider).languageCode);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: l10n.signOut,
        message: l10n.signOutConfirmMsg,
        confirmLabel: l10n.signOut,
        danger: true,
      ),
    );
    if (ok != true || !mounted) return;
    final router = GoRouter.of(context); // stays valid across the later await
    try {
      await ref.read(socialRepositoryProvider).updateOnlineStatus(false);
    } catch (_) {}
    await Supabase.instance.client.auth.signOut();
    router.go('/');
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
    final isAdmin   = ref.watch(isAdminProvider);
    final l10n      = AppL10n.fromCode(ref.watch(localeProvider).languageCode);

    if (user != null) {
      _initFromUser(user);
      if (user.photoUrl.isNotEmpty) _lastKnownPhotoUrl = user.photoUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.surface, // Duolingo bg, matches the path
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
                  title: l10n.profilePhoto,
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
                                  child: Icon(Icons.camera_alt,
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
                                    ? l10n.photoSelected
                                    : l10n.changePhoto,
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
                          Text(
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
                  title: l10n.profileSection,
                  child: isGuest
                      ? _GuestNotice(l10n: l10n)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(child: _Field(label: l10n.firstName, controller: _firstNameCtrl)),
                                const SizedBox(width: 12),
                                Expanded(child: _Field(label: l10n.lastName,  controller: _lastNameCtrl)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _Field(
                                label: l10n.usernameLabel,
                                controller: _usernameCtrl),
                            const SizedBox(height: 14),
                            _Field(label: 'Email', controller: _emailCtrl, readOnly: true),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateField(
                                    label: l10n.dateOfBirth,
                                    hint:  l10n.selectHint,
                                    value: _birthday,
                                    onPicked: (d) => setState(() => _birthday = d),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DropdownField<String?>(
                                    label: l10n.genderLabel,
                                    value: _gender,
                                    items: [
                                      DropdownMenuItem(value: null,     child: Text(l10n.selectHint)),
                                      DropdownMenuItem(value: 'male',   child: Text(l10n.male)),
                                      DropdownMenuItem(value: 'female', child: Text(l10n.female)),
                                      DropdownMenuItem(value: 'other',  child: Text(l10n.otherGender)),
                                    ],
                                    onChanged: (v) => setState(() => _gender = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _DropdownField<String>(
                              label: l10n.languageLabel,
                              value: kSupportedUiLanguages.contains(_motherTongue)
                                  ? _motherTongue
                                  : 'tr',
                              items: const [
                                DropdownMenuItem(value: 'tr', child: Text('Türkçe 🇹🇷')),
                                DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                                DropdownMenuItem(value: 'ko', child: Text('한국어 🇰🇷')),
                                DropdownMenuItem(value: 'ja', child: Text('日本語 🇯🇵')),
                                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt 🇻🇳')),
                                DropdownMenuItem(value: 'ru', child: Text('Русский 🇷🇺')),
                                DropdownMenuItem(value: 'id', child: Text('Bahasa 🇮🇩')),
                                DropdownMenuItem(value: 'th', child: Text('ภาษาไทย 🇹🇭')),
                                DropdownMenuItem(value: 'es', child: Text('Español 🇪🇸')),
                                DropdownMenuItem(value: 'pt', child: Text('Português 🇧🇷')),
                              ],
                              // Applied with "Değişiklikleri Kaydet" — nothing
                              // changes app-wide until the save button confirms.
                              onChanged: (v) =>
                                  setState(() => _motherTongue = v ?? 'tr'),
                            ),
                          ],
                        ),
                ),

                if (!isGuest) ...[
                  const SizedBox(height: 16),

                  // ── Theme (applies on save, like everything above) ───────
                  _ProfileCard(
                    title: l10n.themeSection,
                    child: Builder(builder: (context) {
                      final pickDark = _pendingDark ?? isDark;
                      return Row(
                        children: [
                          Icon(
                              pickDark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              size: 18,
                              color: AppColors.onSurfaceMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                pickDark
                                    ? l10n.darkThemeToggle
                                    : l10n.lightThemeToggle,
                                style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 14)),
                          ),
                          Switch(
                            value: pickDark,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) =>
                                setState(() => _pendingDark = v),
                          ),
                        ],
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // ── Save button ──────────────────────────────────────────
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF58CC02), // Duolingo green
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(l10n.saveChanges,
                            style: const TextStyle(fontSize: 15)),
                  ),
                ],

                // ── Password card (email users only) ───────────────────────
                if (!isGuest && _hasEmailProvider) ...[
                  const SizedBox(height: 16),
                  _ProfileCard(
                    title: l10n.passwordSection,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        _Field(label: l10n.currentPassword, controller: _currPassCtrl, obscure: true),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _Field(label: l10n.newPassword,     controller: _newPassCtrl,     obscure: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _Field(label: l10n.confirmPassword, controller: _confirmPassCtrl, obscure: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _passSaving ? null : _savePassword,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            child: _passSaving
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(l10n.updatePassword),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Hesap card ─────────────────────────────────────────────
                const SizedBox(height: 16),
                _ProfileCard(
                  title: l10n.accountSection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      if (isAdmin) ...[
                        _ActionRow(
                          icon: Icons.admin_panel_settings,
                          label: 'Admin Paneli',
                          onTap: () => context.go('/admin'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _ActionRow(
                        icon: Icons.logout,
                        label: l10n.signOut,
                        onTap: _confirmSignOut,
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

    // In-session preview: bytes from picker (before save).
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

    // Use live URL when available; fall back to file-level global so the photo
    // survives any transient null user emission AND State recreation caused by
    // SinomaApp rebuilding on locale change.
    final photoUrl = (user?.photoUrl.isNotEmpty == true)
        ? user!.photoUrl
        : _lastKnownPhotoUrl;

    if (photoUrl.isEmpty) return _initialsCircle(initials);

    if (photoUrl.startsWith('data:')) {
      try {
        // putIfAbsent guarantees the same Uint8List instance for the same URL
        // so MemoryImage never considers it "new" and never reloads/blanks.
        final bytes = _photoByteCache.putIfAbsent(photoUrl, () {
          final b64 =
              photoUrl.contains(',') ? photoUrl.split(',').last : photoUrl;
          return base64Decode(b64);
        });
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

    // Legacy: plain HTTPS URL (old uploads).
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
        color: AppColors.surfaceVariant, // Duolingo panel
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(
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
            style: TextStyle(
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
                borderSide: BorderSide(color: AppColors.surface)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.surface)),
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
  final String hint;
  final DateTime? value;
  final void Function(DateTime) onPicked;
  const _DateField(
      {required this.label, required this.hint, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final text = value != null ? DateFormat('dd/MM/yyyy').format(value!) : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
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
                    text.isEmpty ? hint : text,
                    style: TextStyle(
                        color: text.isEmpty
                            ? AppColors.onSurfaceMuted
                            : AppColors.onSurface,
                        fontSize: 14),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
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
            style: TextStyle(
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
              TextStyle(color: AppColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.surface)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.surface)),
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
  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.onSurface;
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
  final AppL10n l10n;
  const _GuestNotice({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.person_outline, size: 40, color: AppColors.onSurfaceMuted),
        const SizedBox(height: 10),
        Text(
          l10n.guestCannotEdit,
          style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => GoRouter.of(context).go('/onboarding'),
          icon: const Icon(Icons.login),
          label: Text(l10n.signUpOrIn),
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
      title:   Text(title,   style: TextStyle(color: AppColors.onSurface)),
      content: Text(message, style: TextStyle(color: AppColors.onSurfaceMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppL10n.of(context).cancel),
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
