import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([Locale? initial]) : super(initial ?? const Locale('tr'));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null) state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  Future<bool> hasSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kLocaleKey);
  }
}

// ── Inline translations (TR / EN) ─────────────────────────────────────────────

class AppL10n {
  final String languageCode;
  const AppL10n._(this.languageCode);

  static AppL10n of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'tr';
    return AppL10n._(code);
  }

  static AppL10n fromCode(String code) => AppL10n._(code);

  bool get _isTr => languageCode == 'tr';

  // ── Language screen ─────────────────────────────────────────────────────────
  String get chooseLanguage        => _isTr ? 'Dil Seçin'          : 'Choose Language';
  String get continueBtn           => _isTr ? 'Devam Et'           : 'Continue';
  String get languageSubtitle      => _isTr ? 'İstediğin zaman ayarlardan değiştirebilirsin'
                                             : 'You can change this anytime in settings';

  // ── Home ────────────────────────────────────────────────────────────────────
  String get learn                 => _isTr ? 'Öğren'              : 'Learn';
  String get games                 => _isTr ? 'Oyunlar'            : 'Games';
  String get community             => _isTr ? 'Topluluk'           : 'Community';
  String get filters               => _isTr ? 'Filtreler'          : 'Filters';
  String get resetAll              => _isTr ? 'Temizle'            : 'Reset All';
  String get grammarPatterns       => _isTr ? '文法  GRAMER'        : '文法  GRAMMAR';
  String get sentenceLength        => _isTr ? '字数  CÜMLE UZUNLUĞU': '字数  SENTENCE LENGTH';
  String get allCategories         => _isTr ? '全部  Tümü'         : '全部  All';
  String get noVideos              => _isTr ? 'Bu seviyede video yok.' : 'No videos at your level.';
  String get noVideosFiltered      => _isTr ? 'Filtreyle eşleşen video yok.' : 'No videos match filters.';
  String get retry                 => _isTr ? 'Tekrar Dene'        : 'Retry';
  String get failedToLoad          => _isTr ? 'Videolar yüklenemedi' : 'Failed to load videos';

  // ── HSK levels ──────────────────────────────────────────────────────────────
  String hskLabel(int level) => 'HSK $level';
  String hskSublabel(int level) => switch (level) {
    1 => _isTr ? 'Başlangıç'       : 'Beginner',
    2 => _isTr ? 'Temel'           : 'Elementary',
    3 => _isTr ? 'Orta'            : 'Intermediate',
    4 => _isTr ? 'Orta-İleri'      : 'Upper-Intermediate',
    5 => _isTr ? 'İleri'           : 'Advanced',
    6 => _isTr ? 'Uzman'           : 'Expert',
    _ => '',
  };

  // ── Sidebar ──────────────────────────────────────────────────────────────────
  String get videoTab       => _isTr ? 'Video'     : 'Video';
  String get dictionaryTab  => _isTr ? 'Sözlük'    : 'Dictionary';
  String get socialTab      => _isTr ? 'Sosyal'     : 'Social';
  String get gamesTab       => _isTr ? 'Oyun'       : 'Games';

  // ── Home filter panel ────────────────────────────────────────────────────────
  String get filterAll      => _isTr ? 'Tümü'              : 'All';
  String get filterActive   => _isTr ? 'Filtre aktif'       : 'Filter active';
  String get filterLabel    => _isTr ? 'Filtrele'           : 'Filter';
  String get lifeSection    => _isTr ? 'Hayat'              : 'Life';
  String get dailyLife      => _isTr ? 'Günlük Hayat'       : 'Daily Life';
  String get levelSection   => _isTr ? 'Adım'               : 'Level';
  String get grammarSection => _isTr ? 'Gramer Kuralları'   : 'Grammar Patterns';
  String get retryBtn       => _isTr ? 'Tekrar Dene'        : 'Retry';
  String get noVideosLevel  => _isTr ? 'Seviyenizde video bulunamadı.' : 'No videos at your level.';
  String get noVideosFilter => _isTr ? 'Seçili filtrelere uygun video yok.' : 'No videos match filters.';
}
