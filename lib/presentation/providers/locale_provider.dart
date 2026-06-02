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
  String get subtitlesOn           => _isTr ? 'Altyazılı'          : 'Subtitles On';
  String get subtitlesOff          => _isTr ? 'Altyazısız'         : 'Subtitles Off';

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
  String get businessLife   => _isTr ? 'İş'                 : 'Business';
  String get childrenLife   => _isTr ? 'Çocuk'              : 'Children';
  String get levelSection   => _isTr ? 'Adım'               : 'Level';
  String get grammarSection => _isTr ? 'Gramer Kuralları'   : 'Grammar Patterns';
  String get retryBtn       => _isTr ? 'Tekrar Dene'        : 'Retry';
  String get noVideosLevel  => _isTr ? 'Seviyenizde video bulunamadı.' : 'No videos at your level.';
  String get noVideosFilter => _isTr ? 'Seçili filtrelere uygun video yok.' : 'No videos match filters.';

  // ── Home screen stats ────────────────────────────────────────────────────────
  String get statsWatched   => _isTr ? 'izlendi'  : 'watched';
  String get statsPoints    => _isTr ? 'puan'     : 'points';
  String get statsDays      => _isTr ? 'gün'      : 'days';
  String get searchHint     => _isTr ? 'Ara…'     : 'Search…';

  // ── Games section ────────────────────────────────────────────────────────────
  String get gamesTitle         => _isTr ? 'Oyunlar'                                    : 'Games';
  String get gamesSubtitle      => _isTr ? 'Kendini sına ve arkadaşlarınla yarış'        : 'Test yourself and compete with friends';
  String get duelSubtitle       => _isTr ? 'Gerçek zamanlı 1v1 soru yarışması — 6 kategori' : 'Real-time 1v1 quiz — 6 categories';
  String get duelDetail         => _isTr ? '10 tur • 10s süre • 3 can'                  : '10 rounds • 10s each • 3 lives';
  String get hanziBuildSubtitle => _isTr ? 'Kökenlerden karakter yeniden oluştur'        : 'Reconstruct characters from radicals';
  String get hanziBuildDetail   => _isTr ? '10 kelime • 20s süre • ipuçları mevcut'     : '10 words • 20s each • hints available';

  // ── Hub screen ──────────────────────────────────────────────────────────────
  String get hubDictionary  => _isTr ? 'Sözlük'   : 'Dictionary';
  String get hubSocial      => _isTr ? 'Sosyal'   : 'Social';
  String get hubGames       => _isTr ? 'Oyun'     : 'Games';

  // ── Top bar ──────────────────────────────────────────────────────────────────
  String get userFallback   => _isTr ? 'Kullanıcı'        : 'User';
  String get scoreLabel     => _isTr ? 'Skor'             : 'Score';
  String get hskLevelTest   => _isTr ? 'HSK Seviye Testi' : 'HSK Level Test';
  String get settingsLabel  => _isTr ? 'Ayarlar'          : 'Settings';
  String get adminPanel     => _isTr ? 'Admin Paneli'     : 'Admin Panel';
  String get darkTheme      => _isTr ? 'Koyu Tema'        : 'Dark Theme';
  String get signOut        => _isTr ? 'Çıkış Yap'        : 'Sign Out';
  String get loginBtn       => _isTr ? 'Giriş Yap'        : 'Log In';
  String get signUpBtn      => _isTr ? 'Kayıt Ol'         : 'Sign Up';

  // ── Auth dialog ──────────────────────────────────────────────────────────────
  String get emailLabel          => _isTr ? 'E-posta'          : 'Email';
  String get passwordLabel       => _isTr ? 'Şifre'            : 'Password';
  String get googleSignIn        => _isTr ? 'Google ile Giriş' : 'Sign in with Google';
  String get authSubmitLogin     => _isTr ? 'Giriş Yap'        : 'Log In';
  String get authSubmitRegister  => _isTr ? 'Hesap Oluştur'    : 'Create Account';
  String get verifyEmailTitle    => _isTr ? 'E-postanı doğrula'         : 'Verify your email';
  String get verifyEmailBody     => _isTr ? 'Doğrulama bağlantısı gönderildi. Gelen kutunuzu kontrol edin.'
                                          : 'A verification link has been sent. Check your inbox.';

  // ── Profile screen ───────────────────────────────────────────────────────────
  String get profilePhoto       => _isTr ? 'Profil Fotoğrafı'    : 'Profile Photo';
  String get changePhoto        => _isTr ? 'Fotoğrafı Değiştir'  : 'Change Photo';
  String get photoSelected      => _isTr ? 'Fotoğraf seçildi ✓'  : 'Photo selected ✓';
  String get profileSection     => _isTr ? 'Profil'               : 'Profile';
  String get firstName          => _isTr ? 'Ad'                   : 'First Name';
  String get lastName           => _isTr ? 'Soyad'                : 'Last Name';
  String get selectHint         => _isTr ? 'Seçiniz'              : 'Select';
  String get dateOfBirth        => _isTr ? 'Doğum Tarihi'         : 'Date of Birth';
  String get genderLabel        => _isTr ? 'Cinsiyet'             : 'Gender';
  String get male               => _isTr ? 'Erkek'                : 'Male';
  String get female             => _isTr ? 'Kadın'                : 'Female';
  String get otherGender        => _isTr ? 'Diğer'                : 'Other';
  String get languageLabel      => _isTr ? 'Dil'                  : 'Language';
  String get saveChanges        => _isTr ? 'Değişiklikleri Kaydet': 'Save Changes';
  String get profileSaved       => _isTr ? 'Profil kaydedildi.'   : 'Profile saved.';
  String get saveError          => _isTr ? 'Kayıt hatası: '       : 'Save error: ';
  String get accountSection     => _isTr ? 'Hesap'                : 'Account';
  String get darkThemeToggle    => _isTr ? 'Karanlık Tema'        : 'Dark Theme';
  String get deleteAccount      => _isTr ? 'Hesabı Sil'           : 'Delete Account';
  String get passwordSection    => _isTr ? 'Şifre'                : 'Password';
  String get currentPassword    => _isTr ? 'Mevcut Şifre'         : 'Current Password';
  String get newPassword        => _isTr ? 'Yeni Şifre'           : 'New Password';
  String get confirmPassword    => _isTr ? 'Yeni Şifre Tekrar'    : 'Confirm Password';
  String get updatePassword     => _isTr ? 'Şifreyi Güncelle'     : 'Update Password';
  String get passwordUpdated    => _isTr ? 'Şifre güncellendi.'   : 'Password updated.';
  String get fillAllPassFields  => _isTr ? 'Tüm şifre alanlarını doldurun.'   : 'Fill in all password fields.';
  String get passwordMismatch   => _isTr ? 'Yeni şifreler eşleşmiyor.'        : 'New passwords don\'t match.';
  String get passwordTooShort   => _isTr ? 'Şifre en az 6 karakter olmalıdır.': 'Password must be at least 6 characters.';
  String get guestCannotEdit    => _isTr ? 'Misafir kullanıcılar profil düzenleyemez.' : 'Guest users cannot edit their profile.';
  String get signUpOrIn         => _isTr ? 'Hesap Oluştur / Giriş Yap' : 'Sign Up / Sign In';
  String get cancel             => _isTr ? 'İptal'   : 'Cancel';
  String get signOutConfirmMsg  => _isTr ? 'Hesabınızdan çıkmak istediğinizden emin misiniz?'
                                         : 'Are you sure you want to sign out?';
  String get deleteAccountMsg   => _isTr ? 'Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.'
                                         : 'Your account and all your data will be permanently deleted. This action cannot be undone.';
}
