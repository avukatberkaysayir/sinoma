import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/locale_provider.dart';

// Duo palette — matches /home.
const _bg = Color(0xFF0E1414);
const _panel = Color(0xFF161E1D);
const _accent = Color(0xFF2EC4B6);

// Each language ONLY in its own tongue (no translated subtitle). Live ones
// first in launch order (TR → EN → KO; every new language is appended after
// Korean). Upcoming next on the roadmap: Spanish, then French (no German
// planned). Tapping an upcoming language falls back to EN.
const List<(String flag, String name, String code, bool live)> _kLanguages = [
  ('🇹🇷', 'Türkçe', 'tr', true),
  ('🇬🇧', 'English', 'en', true),
  ('🇰🇷', '한국어', 'ko', true),
  ('🇯🇵', '日本語', 'ja', true),
  ('🇻🇳', 'Tiếng Việt', 'vi', true),
  ('🇷🇺', 'Русский', 'ru', true),
  ('🇮🇩', 'Bahasa', 'id', true),
  ('🇹🇭', 'ภาษาไทย', 'th', true),
  ('🇪🇸', 'Español', 'es', false),
  ('🇫🇷', 'Français', 'fr', false),
];

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String? _selected;

  Future<void> _confirm() async {
    if (_selected == null) return;
    // Upcoming languages fall back to English until their UI ships.
    final code =
        kSupportedUiLanguages.contains(_selected) ? _selected! : 'en';
    await ref.read(localeProvider.notifier).setLocale(Locale(code));
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    const rowH = 64.0;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  Image.asset('assets/mascot/mascot.png',
                      width: 84, height: 84, fit: BoxFit.contain),
                  const SizedBox(height: 8),
                  const Text('Sinoma',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30,
                          color: _accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 24),
                  const Text('Dil Seçin / Choose Language',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  // 5 rows visible; the rest scroll.
                  SizedBox(
                    height: rowH * 5,
                    child: ListView.builder(
                      itemCount: _kLanguages.length,
                      itemBuilder: (_, i) {
                        final (flag, name, code, _) = _kLanguages[i];
                        final sel = _selected == code;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: sel
                                ? _accent.withValues(alpha: 0.14)
                                : _panel,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  setState(() => _selected = code),
                              child: Container(
                                height: rowH - 8,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: sel
                                          ? _accent
                                          : const Color(0xFF263230),
                                      width: sel ? 2 : 1),
                                ),
                                child: Row(children: [
                                  Text(flag,
                                      style:
                                          const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(name,
                                        style: TextStyle(
                                            color: sel
                                                ? _accent
                                                : Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  Icon(
                                      sel
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: sel
                                          ? _accent
                                          : Colors.white24,
                                      size: 22),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: _selected != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: FilledButton(
                      onPressed: _selected == null ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _selected == 'tr'
                            ? 'Devam Et'
                            : (_selected == 'ko'
                                ? '계속하기'
                                : (_selected == 'ja'
                                    ? '次へ'
                                    : (_selected == 'id'
                                    ? 'Lanjut'
                                    : (_selected == 'vi' ? 'Tiếp tục' : (_selected == 'th' ? 'ต่อไป' : (_selected == 'ru' ? 'Продолжить' : 'Continue')))))),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
