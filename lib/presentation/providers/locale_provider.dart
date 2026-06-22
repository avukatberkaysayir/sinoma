import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

// UI languages the app actually ships.
const kSupportedUiLanguages = ['tr', 'en', 'ko', 'ja', 'id', 'vi', 'th', 'ru', 'es', 'pt', 'fr', 'ar'];

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([Locale? initial]) : super(initial ?? const Locale('tr'));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null && kSupportedUiLanguages.contains(code)) {
      state = Locale(code);
    }
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

// ── Inline translations (TR / EN / KO / JA / ID / VI / TH) ───────────────────
// Korean 해요체; Japanese 丁寧語; Indonesian/Vietnamese/Thai standard polite
// register — written as a native product would phrase it, not literal. Thai is
// written in Thai script (อักษรไทย), neutral-polite (no gendered final particle).

class AppL10n {
  final String languageCode;
  const AppL10n._(this.languageCode);

  static AppL10n of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'tr';
    return AppL10n._(code);
  }

  static AppL10n fromCode(String code) => AppL10n._(code);

  bool get _isTr => languageCode == 'tr';
  bool get _isKo => languageCode == 'ko';
  bool get _isJa => languageCode == 'ja';
  bool get _isId => languageCode == 'id';
  bool get _isVi => languageCode == 'vi';
  bool get _isTh => languageCode == 'th';
  bool get _isRu => languageCode == 'ru';
  bool get _isEs => languageCode == 'es';
  bool get _isPt => languageCode == 'pt';
  bool get _isFr => languageCode == 'fr';
  bool get _isAr => languageCode == 'ar';

  // Wrap an Arabic label in a Unicode RTL isolate (U+2067 … U+2069) so it reads
  // right-to-left with numbers/Latin in the correct place, WITHOUT flipping any
  // layout: the app stays LTR (nav, cards, rows keep their positions) and only
  // the text run itself is bidi-isolated as RTL. No-op for empty strings.
  // 0x2067 = RIGHT-TO-LEFT ISOLATE, 0x2069 = POP DIRECTIONAL ISOLATE.
  static final String _rli = String.fromCharCode(0x2067);
  static final String _pdi = String.fromCharCode(0x2069);
  static String _rtl(String s) => s.isEmpty ? s : '$_rli$s$_pdi';

  String _t(String tr, String en, String ko, String ja, String id, String vi,
          String th, String ru, String es, String pt, String fr, String ar) =>
      _isTr
          ? tr
          : (_isKo
              ? ko
              : (_isJa
                  ? ja
                  : (_isId
                      ? id
                      : (_isVi
                          ? vi
                          : (_isTh
                              ? th
                              : (_isRu
                                  ? ru
                                  : (_isEs
                                      ? es
                                      : (_isPt
                                          ? pt
                                          : (_isFr ? fr : (_isAr ? _rtl(ar) : en))))))))));

  // ── Language screen ─────────────────────────────────────────────────────────
  String get chooseLanguage   => _t('Dil Seçin', 'Choose Language', '언어 선택', '言語を選択', 'Pilih Bahasa', 'Chọn ngôn ngữ', 'เลือกภาษา', 'Выберите язык', 'Elegir idioma', 'Escolher idioma', 'Choisir la langue', 'اختر اللغة');
  String get continueBtn      => _t('Devam Et', 'Continue', '계속하기', '次へ', 'Lanjut', 'Tiếp tục', 'ต่อไป', 'Продолжить', 'Continuar', 'Continuar', 'Continuer', 'متابعة');
  String get languageSubtitle => _t('İstediğin zaman ayarlardan değiştirebilirsin',
      'You can change this anytime in settings', '설정에서 언제든지 변경할 수 있어요', '設定でいつでも変更できます', 'Kamu bisa mengubahnya kapan saja di pengaturan', 'Bạn có thể đổi bất cứ lúc nào trong cài đặt', 'คุณเปลี่ยนได้ทุกเมื่อในการตั้งค่า', 'Вы можете изменить это в любое время в настройках', 'Puedes cambiar esto en cualquier momento en los ajustes', 'Você pode alterar isso a qualquer momento nas configurações', 'Vous pouvez modifier cela à tout moment dans les paramètres', 'يمكنك تغيير هذا في أي وقت من الإعدادات');

  // ── Home ────────────────────────────────────────────────────────────────────
  String get learn            => _t('Öğren', 'Learn', '학습', '学ぶ', 'Belajar', 'Học', 'เรียน', 'Учить', 'Aprender', 'Aprender', 'Apprendre', 'تعلّم');
  String get games            => _t('Oyunlar', 'Games', '게임', 'ゲーム', 'Permainan', 'Trò chơi', 'เกม', 'Игры', 'Juegos', 'Jogos', 'Jeux', 'الألعاب');
  String get community        => _t('Topluluk', 'Community', '커뮤니티', 'コミュニティ', 'Komunitas', 'Cộng đồng', 'ชุมชน', 'Сообщество', 'Comunidad', 'Comunidade', 'Communauté', 'المجتمع');
  String get filters          => _t('Filtreler', 'Filters', '필터', 'フィルター', 'Filter', 'Bộ lọc', 'ตัวกรอง', 'Фильтры', 'Filtros', 'Filtros', 'Filtres', 'عوامل التصفية');
  String get resetAll         => _t('Temizle', 'Reset All', '초기화', 'リセット', 'Atur Ulang', 'Đặt lại', 'รีเซ็ต', 'Сбросить всё', 'Restablecer todo', 'Redefinir tudo', 'Tout réinitialiser', 'إعادة تعيين الكل');
  String get grammarPatterns  => _t('文法  GRAMER', '文法  GRAMMAR', '文法  문법', '文法  ぶんぽう', '文法  TATA BAHASA', '文法  NGỮ PHÁP', '文法  ไวยากรณ์', '文法  ГРАММАТИКА', '文法  GRAMÁTICA', '文法  GRAMÁTICA', '文法  GRAMMAIRE', '文法  القواعد');
  String get sentenceLength   => _t('字数  CÜMLE UZUNLUĞU', '字数  SENTENCE LENGTH', '字数  문장 길이', '字数  文の長さ', '字数  PANJANG KALIMAT', '字数  ĐỘ DÀI CÂU', '字数  ความยาวประโยค', '字数  ДЛИНА ПРЕДЛОЖЕНИЯ', '字数  LONGITUD DE LA FRASE', '字数  COMPRIMENTO DA FRASE', '字数  LONGUEUR DE PHRASE', '字数  طول الجملة');
  String get allCategories    => _t('全部  Tümü', '全部  All', '全部  전체', '全部  すべて', '全部  Semua', '全部  Tất cả', '全部  ทั้งหมด', '全部  Все', '全部  Todo', '全部  Tudo', '全部  Tout', '全部  الكل');
  String get noVideos         => _t('Bu seviyede video yok.', 'No videos at your level.', '내 레벨에 맞는 영상이 없어요.', 'このレベルの動画はありません。', 'Tidak ada video di level ini.', 'Không có video ở cấp độ này.', 'ไม่มีวิดีโอในระดับนี้', 'Нет видео для вашего уровня.', 'No hay videos para tu nivel.', 'Nenhum vídeo no seu nível.', 'Aucune vidéo à votre niveau.', 'لا توجد فيديوهات في مستواك.');
  String get noVideosFiltered => _t('Filtreyle eşleşen video yok.', 'No videos match filters.', '필터에 맞는 영상이 없어요.', 'フィルターに一致する動画がありません。', 'Tidak ada video yang cocok dengan filter.', 'Không có video khớp với bộ lọc.', 'ไม่มีวิดีโอที่ตรงกับตัวกรอง', 'Нет видео, соответствующих фильтрам.', 'No hay videos que coincidan con los filtros.', 'Nenhum vídeo corresponde aos filtros.', 'Aucune vidéo ne correspond aux filtres.', 'لا توجد فيديوهات تطابق الفلاتر.');
  String get retry            => _t('Tekrar Dene', 'Retry', '다시 시도', '再試行', 'Coba Lagi', 'Thử lại', 'ลองอีกครั้ง', 'Повторить попытку', 'Reintentar', 'Tentar novamente', 'Réessayer', 'إعادة المحاولة');
  String get failedToLoad     => _t('Videolar yüklenemedi', 'Failed to load videos', '영상을 불러오지 못했어요', '動画を読み込めませんでした', 'Gagal memuat video', 'Không tải được video', 'โหลดวิดีโอไม่สำเร็จ', 'Не удалось загрузить видео', 'Error al cargar los videos', 'Falha ao carregar vídeos', 'Échec du chargement des vidéos', 'تعذر تحميل مقاطع الفيديو');
  String get activeFilters    => _t('Aktif filtreler', 'Active filters', '적용된 필터', '適用中のフィルター', 'Filter aktif', 'Bộ lọc đang dùng', 'ตัวกรองที่ใช้อยู่', 'Активные фильтры', 'Filtros activos', 'Filtros ativos', 'Filtres actifs', 'الفلاتر النشطة');
  String get clearAllLbl      => _t('Tümünü temizle', 'Clear all', '모두 지우기', 'すべて消去', 'Hapus semua', 'Xóa tất cả', 'ล้างทั้งหมด', 'Очистить всё', 'Borrar todo', 'Limpar tudo', 'Tout effacer', 'مسح الكل');
  String get subtitlesOn      => _t('Altyazılı', 'Subtitles On', '자막 보기', '字幕あり', 'Subtitel Nyala', 'Bật phụ đề', 'เปิดคำบรรยาย', 'Субтитры вкл.', 'Subtítulos activados', 'Legendas ativadas', 'Sous-titres activés', 'تشغيل الترجمة');
  String get subtitlesOff     => _t('Altyazısız', 'Subtitles Off', '자막 없이', '字幕なし', 'Subtitel Mati', 'Tắt phụ đề', 'ปิดคำบรรยาย', 'Субтитры выкл.', 'Subtítulos desactivados', 'Legendas desativadas', 'Sous-titres désactivés', 'إيقاف الترجمة');
  String get subtitleTitle    => _t('Altyazı', 'Subtitle', '자막', '字幕', 'Subtitel', 'Phụ đề', 'คำบรรยาย', 'Субтитры', 'Subtítulo', 'Legenda', 'Sous-titre', 'ترجمة');

  // ── Practice: playlists + reports ───────────────────────────────────────────
  String get addToPlaylist      => _t('Listeye Ekle', 'Add to Playlist', '재생목록에 추가', 'リストに追加', 'Tambah ke Daftar', 'Thêm vào danh sách', 'เพิ่มลงเพลย์ลิสต์', 'Добавить в плейлист', 'Añadir a la lista de reproducción', 'Adicionar à playlist', 'Ajouter à la playlist', 'إضافة إلى قائمة التشغيل');
  String get myPlaylists        => _t('LİSTELERİM', 'MY LISTS', '내 재생목록', 'マイリスト', 'DAFTAR SAYA', 'DANH SÁCH CỦA TÔI', 'รายการของฉัน', 'МОИ СПИСКИ', 'MIS LISTAS', 'MINHAS LISTAS', 'MES LISTES', 'قوائمي');
  String get newPlaylistHint    => _t('Yeni liste adı…', 'New playlist name…', '새 재생목록 이름…', '新しいリスト名…', 'Nama daftar baru…', 'Tên danh sách mới…', 'ชื่อเพลย์ลิสต์ใหม่…', 'Название нового плейлиста…', 'Nombre de la lista de reproducción nueva…', 'Nome da nova playlist…', 'Nom de la nouvelle playlist…', 'اسم قائمة التشغيل الجديد...');
  String get createAndAdd       => _t('Oluştur ve Ekle', 'Create & Add', '만들고 추가', '作成して追加', 'Buat & Tambah', 'Tạo & Thêm', 'สร้างและเพิ่ม', 'Создать и добавить', 'Crear y añadir', 'Criar e adicionar', 'Créer et ajouter', 'إنشاء وإضافة');
  String get noPlaylistsYet     => _t('Henüz listen yok — aşağıdan oluştur.',
      'No playlists yet — create one below.', '아직 재생목록이 없어요 — 아래에서 만들어 보세요.', 'まだリストがありません — 下から作成しましょう。', 'Belum ada daftar — buat di bawah.', 'Chưa có danh sách — hãy tạo bên dưới.', 'ยังไม่มีเพลย์ลิสต์ — สร้างได้ด้านล่าง', 'Плейлистов пока нет — создайте один ниже.', 'Aún no hay listas de reproducción. Crea una a continuación.', 'Nenhuma playlist ainda — crie uma abaixo.', 'Aucune playlist pour l\'instant — créez-en une ci-dessous.', 'لا توجد قوائم تشغيل بعد — أنشئ واحدة أدناه.');
  String get signInForPlaylists => _t('Liste oluşturmak için giriş yap.',
      'Sign in to use playlists.', '재생목록을 만들려면 로그인하세요.', 'リストを使うにはログインしてください。', 'Masuk untuk memakai daftar putar.', 'Đăng nhập để dùng danh sách phát.', 'เข้าสู่ระบบเพื่อใช้เพลย์ลิสต์', 'Войдите, чтобы использовать плейлисты.', 'Inicia sesión para usar listas de reproducción.', 'Entre para usar listas de reprodução.', 'Connectez-vous pour utiliser les listes de lecture.', 'سجّل الدخول لاستخدام قوائم التشغيل.');
  String get closeLabel         => _t('Kapat', 'Close', '닫기', '閉じる', 'Tutup', 'Đóng', 'ปิด', 'Закрыть', 'Cerrar', 'Fechar', 'Fermer', 'إغلاق');
  String get reportProblem      => _t('Sorun Bildir', 'Report a Problem', '문제 신고', '問題を報告', 'Laporkan Masalah', 'Báo lỗi', 'แจ้งปัญหา', 'Сообщить о проблеме', 'Informar de un problema', 'Reportar um problema', 'Signaler un problème', 'الإبلاغ عن مشكلة');
  String get reportHint         => _t('Bu videodaki sorunu kısaca anlat… (en fazla 300 karakter)',
      'Briefly describe the problem… (max 300 characters)', '이 영상의 문제를 간단히 알려 주세요… (최대 300자)', 'この動画の問題を簡単に教えてください…(最大300文字)', 'Jelaskan masalahnya secara singkat… (maks. 300 karakter)', 'Mô tả ngắn gọn vấn đề… (tối đa 300 ký tự)', 'อธิบายปัญหาสั้น ๆ… (ไม่เกิน 300 ตัวอักษร)', 'Кратко опишите проблему… (макс. 300 символов)', 'Describe brevemente el problema… (máx. 300 caracteres)', 'Descreva brevemente o problema… (máx. 300 caracteres)', 'Décrivez brièvement le problème… (300 caractères max)', 'صف المشكلة باختصار... (بحد أقصى 300 حرف)');
  String get reportSend         => _t('Gönder', 'Send', '보내기', '送信', 'Kirim', 'Gửi', 'ส่ง', 'Отправить', 'Enviar', 'Enviar', 'Envoyer', 'إرسال');
  String get reportThanks       => _t('✓ Bildirimin alındı, teşekkürler!',
      '✓ Report received, thanks!', '✓ 신고가 접수되었어요. 감사합니다!', '✓ 報告を受け付けました。ありがとうございます！', '✓ Laporan diterima, terima kasih!', '✓ Đã nhận báo cáo, cảm ơn bạn!', '✓ ได้รับรายงานแล้ว ขอบคุณ!', '✓ Жалоба получена, спасибо!', '✓ Informe recibido, ¡gracias!', '✓ Relatório recebido, obrigado!', '✓ Signalement reçu, merci !', '✓ تم استلام البلاغ، شكراً لك!');

  // ── Practice extras ─────────────────────────────────────────────────────────
  String get startHskTest   => _t('HSK TESTİNE BAŞLA', 'START HSK TEST', 'HSK 테스트 시작', 'HSKテストを始める', 'MULAI TES HSK', 'BẮT ĐẦU KIỂM TRA HSK', 'เริ่มทดสอบ HSK', 'НАЧАТЬ ТЕСТ HSK', 'EMPEZAR PRUEBA HSK', 'INICIAR TESTE HSK', 'DÉMARRER LE TEST HSK', 'ابدأ اختبار HSK');
  String get topicGroup     => _t('KONU', 'TOPIC', '주제', 'トピック', 'TOPIK', 'CHỦ ĐỀ', 'หัวข้อ', 'ТЕМА', 'TEMA', 'TÓPICO', 'SUJET', 'الموضوع');
  String get noListsRail    => _t('Henüz listen yok — player altındaki "Listeye Ekle" ile oluştur.',
      'No lists yet — use "Add to Playlist" under the player.',
      '아직 재생목록이 없어요 — 플레이어 아래 "재생목록에 추가"로 만들어 보세요.',
      'まだリストがありません — プレーヤー下の「リストに追加」で作成しましょう。',
      'Belum ada daftar — buat lewat "Tambah ke Daftar" di bawah pemutar.',
      'Chưa có danh sách — tạo bằng "Thêm vào danh sách" dưới trình phát.',
      'ยังไม่มีรายการ — สร้างผ่าน "เพิ่มลงเพลย์ลิสต์" ใต้เครื่องเล่น', 'Списков пока нет — используйте «Добавить в плейлист» под плеером.', 'Aún no hay listas. Usa "Añadir a lista de reproducción" debajo del reproductor.', 'Nenhuma lista ainda — use "Adicionar à Playlist" abaixo do player.', 'Aucune liste pour l\'instant — utilisez « Ajouter à la playlist » sous le lecteur.', 'لا توجد قوائم بعد — استخدم "إضافة إلى قائمة التشغيل" أسفل المشغل.');
  String get prevTooltip    => _t('Önceki', 'Previous', '이전', '前へ', 'Sebelumnya', 'Trước', 'ก่อนหน้า', 'Назад', 'Anterior', 'Anterior', 'Précédent', 'السابق');
  String get replayTooltip  => _t('Tekrar oynat', 'Replay', '다시 재생', 'もう一度再生', 'Putar ulang', 'Phát lại', 'เล่นซ้ำ', 'Повторить', 'Reproducir de nuevo', 'Repetir', 'Rejouer', 'إعادة التشغيل');
  String get watchOnYouTube => _t('YouTube\'da izle', 'Watch on YouTube', 'YouTube에서 보기', 'YouTubeで見る', 'Tonton di YouTube', 'Xem trên YouTube', 'ดูบน YouTube', 'Смотреть на YouTube', 'Ver en YouTube', 'Assistir no YouTube', 'Regarder sur YouTube', 'مشاهدة على YouTube');
  String get nextClip       => _t('Sonraki', 'Next', '다음', '次へ', 'Berikutnya', 'Tiếp theo', 'ถัดไป', 'Далее', 'Siguiente', 'Próximo', 'Suivant', 'التالي');
  String get soundOnTip     => _t('Sesi aç', 'Sound on', '소리 켜기', '音を出す', 'Nyalakan suara', 'Bật âm', 'เปิดเสียง', 'Звук вкл.', 'Sonido activado', 'Som ativado', 'Son activé', 'تشغيل الصوت');
  String get qualityDownTip => _t('Kaliteyi düşür', 'Lower quality', '화질 낮추기', '画質を下げる', 'Turunkan kualitas', 'Giảm chất lượng', 'ลดคุณภาพ', 'Низкое качество', 'Calidad inferior', 'Qualidade inferior', 'Qualité inférieure', 'جودة أقل');
  String get qualityUpTip   => _t('Kaliteyi yükselt', 'Raise quality', '화질 높이기', '画質を上げる', 'Naikkan kualitas', 'Tăng chất lượng', 'เพิ่มคุณภาพ', 'Повысить качество', 'Aumentar calidad', 'Aumentar qualidade', 'Améliorer la qualité', 'رفع الجودة');
  String get soundOffTip    => _t('Sesi kapat', 'Sound off', '소리 끄기', '音を消す', 'Matikan suara', 'Tắt âm', 'ปิดเสียง', 'Звук выкл.', 'Sonido desactivado', 'Som desativado', 'Son désactivé', 'إيقاف الصوت');
  String get notInDict      => _t('Sözlükte bulunamadı.', 'Not found in the dictionary.', '사전에 없는 단어예요.', '辞書に見つかりませんでした。', 'Tidak ditemukan di kamus.', 'Không có trong từ điển.', 'ไม่พบในพจนานุกรม', 'Не найдено в словаре.', 'No encontrado en el diccionario.', 'Não encontrado no dicionário.', 'Introuvable dans le dictionnaire.', 'لم يتم العثور عليها في القاموس.');
  String get videosWord     => _t('video', 'videos', '개 영상', '本の動画', 'video', 'video', 'วิดีโอ', 'видео', 'vídeos', 'vídeos', 'vidéos', 'مقاطع فيديو');
  String videosCount(int n) => _t('$n video', '$n videos', '영상 $n개', '動画$n本', '$n video', '$n video', '$n วิดีโอ', '$n видео', '$n videos', '$n vídeos', '$n vidéos', '$n فيديو');

  // ── Dictionary discover panel ───────────────────────────────────────────────
  String get wordOfDay         => _t('GÜNÜN KELİMESİ', 'WORD OF THE DAY', '오늘의 단어', '今日の単語', 'KATA HARI INI', 'TỪ CỦA NGÀY', 'คำศัพท์ประจำวัน', 'СЛОВО ДНЯ', 'PALABRA DEL DÍA', 'PALAVRA DO DIA', 'MOT DU JOUR', 'كلمة اليوم');
  String get idiomOfWeek       => _t('HAFTANIN DEYİMİ', 'IDIOM OF THE WEEK', '이번 주 성어', '今週の成語', 'IDIOM PEKAN INI', 'THÀNH NGỮ TUẦN NÀY', 'สำนวนประจำสัปดาห์', 'ИДИОМА НЕДЕЛИ', 'MODISMO DE LA SEMANA', 'IDIOMA DA SEMANA', 'IDIOME DE LA SEMAINE', 'مثل الأسبوع');
  String get trendingNow       => _t('POPÜLER ARAMALAR', 'TRENDING NOW', '인기 검색어', '人気の検索', 'SEDANG POPULER', 'ĐANG THỊNH HÀNH', 'กำลังนิยม', 'ПОПУЛЯРНОЕ', 'TENDENCIA AHORA', 'EM ALTA AGORA', 'TENDANCES ACTUELLES', 'الأكثر رواجاً الآن');
  String get newlyAdded        => _t('YENİ EKLENENLER', 'NEWLY ADDED', '새로 추가된 단어', '新着の単語', 'BARU DITAMBAHKAN', 'MỚI THÊM', 'เพิ่งเพิ่มใหม่', 'НОВИНКИ', 'AÑADIDO RECIENTEMENTE', 'ADICIONADOS RECENTEMENTE', 'AJOUTS RÉCENTS', 'أضيفت حديثاً');
  String get testYourChinese   => _t('Çinceni Test Et', 'Test Your Chinese', '중국어 실력 테스트', '中国語の実力テスト', 'Uji Bahasa Mandarinmu', 'Kiểm tra tiếng Trung của bạn', 'ทดสอบภาษาจีนของคุณ', 'Проверьте свой китайский', 'Pon a prueba tu chino', 'Teste seu chinês', 'Testez votre chinois', 'اختبر لغتك الصينية');
  String get testYourChineseSub => _t('20 soruluk HSK seviye testiyle kendini dene.',
      'Try the 20-question HSK placement test.', 'HSK 레벨 테스트(20문항)에 도전해 보세요.', '20問のHSKレベルテストに挑戦してみましょう。', 'Coba tes penempatan HSK 20 soal.', 'Thử bài kiểm tra xếp cấp HSK 20 câu.', 'ลองทำแบบทดสอบจัดระดับ HSK 20 ข้อ', 'Пройдите тест на определение уровня HSK из 20 вопросов.', 'Prueba el examen de nivel HSK de 20 preguntas.', 'Experimente o teste de nivelamento HSK de 20 perguntas.', 'Essayez le test de placement HSK de 20 questions.', 'جرب اختبار تحديد المستوى لـ HSK المكون من 20 سؤالاً.');
  String get dictSearchHint    => _t('Çince karakter veya kelime ara…',
      'Search Chinese characters…', '한자나 단어를 검색하세요…', '漢字や単語を検索…', 'Cari karakter atau kata Mandarin…', 'Tìm chữ Hán hoặc từ…', 'ค้นหาตัวอักษรหรือคำภาษาจีน…', 'Поиск иероглифов…', 'Buscar caracteres chinos…', 'Buscar caracteres chineses…', 'Rechercher des caractères chinois…', 'البحث عن أحرف صينية…');
  String get noResultsFound    => _t('Sonuç bulunamadı', 'No results found', '검색 결과가 없어요', '結果が見つかりません', 'Tidak ada hasil', 'Không có kết quả', 'ไม่พบผลลัพธ์', 'Ничего не найдено', 'No se encontraron resultados', 'Nenhum resultado encontrado', 'Aucun résultat trouvé', 'لم يتم العثور على نتائج');
  String get suggestThisWord   => _t('Bu kelimeyi öner', 'Suggest this word', '이 단어 제안하기', 'この単語を提案', 'Usulkan kata ini', 'Đề xuất từ này', 'เสนอคำนี้', 'Предложить слово', 'Sugerir esta palabra', 'Sugerir esta palavra', 'Suggérer ce mot', 'اقتراح هذه الكلمة');
  String get suggestedLbl      => _t('Önerildi', 'Suggested', '제안 완료', '提案しました', 'Diusulkan', 'Đã đề xuất', 'เสนอแล้ว', 'Предложенные', 'Sugerido', 'Sugerido', 'Suggéré', 'مقترح');
  String get genericError      => _t('Bir hata oluştu', 'Something went wrong', '문제가 발생했어요', 'エラーが発生しました', 'Terjadi kesalahan', 'Đã xảy ra lỗi', 'เกิดข้อผิดพลาด', 'Что-то пошло не так', 'Algo salió mal', 'Algo deu errado', 'Une erreur est survenue', 'حدث خطأ ما');
  String get offlineBanner     => _t('İnternet bağlantısı yok — önbellek gösteriliyor',
      'No internet connection — showing cached data', '인터넷 연결이 없어요 — 캐시된 데이터를 표시 중', 'インターネット接続がありません — キャッシュを表示中', 'Tidak ada koneksi internet — menampilkan data cache', 'Không có mạng — đang hiển thị dữ liệu lưu tạm', 'ไม่มีอินเทอร์เน็ต — แสดงข้อมูลที่แคชไว้', 'Нет подключения к интернету — отображаются кэшированные данные', 'Sin conexión a internet. Mostrando datos en caché', 'Sem conexão com a internet — exibindo dados em cache', 'Pas de connexion internet — affichage des données en cache', 'لا يوجد اتصال بالإنترنت — يتم عرض البيانات المخزنة مؤقتاً');
  String get errEmailTaken     => _t('Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.',
      'This email is already registered. Try signing in.', '이미 가입된 이메일이에요. 로그인해 보세요.', 'このメールは登録済みです。ログインしてみてください。', 'Email ini sudah terdaftar. Coba masuk.', 'Email này đã được đăng ký. Hãy thử đăng nhập.', 'อีเมลนี้ลงทะเบียนแล้ว ลองเข้าสู่ระบบ', 'Этот email уже зарегистрирован. Попробуйте войти.', 'Este correo electrónico ya está registrado. Intenta iniciar sesión.', 'Este e-mail já está registrado. Tente entrar.', 'Cet e-mail est déjà enregistré. Essayez de vous connecter.', 'هذا البريد الإلكتروني مسجل مسبقاً. حاول تسجيل الدخول.');
  String get errBadCredentials => _t('E-posta veya şifre hatalı.',
      'Incorrect email or password.', '이메일 또는 비밀번호가 올바르지 않아요.', 'メールアドレスまたはパスワードが正しくありません。', 'Email atau kata sandi salah.', 'Email hoặc mật khẩu không đúng.', 'อีเมลหรือรหัสผ่านไม่ถูกต้อง', 'Неверный email или пароль.', 'Correo electrónico o contraseña incorrectos.', 'E-mail ou senha incorretos.', 'E-mail ou mot de passe incorrect.', 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
  String get errTooMany        => _t('Çok fazla deneme. Lütfen bekleyin.',
      'Too many attempts. Please wait.', '시도 횟수가 너무 많아요. 잠시 후 다시 시도해 주세요.', '試行回数が多すぎます。しばらくお待ちください。', 'Terlalu banyak percobaan. Mohon tunggu.', 'Quá nhiều lần thử. Vui lòng đợi.', 'พยายามมากเกินไป กรุณารอสักครู่', 'Слишком много попыток. Пожалуйста, подождите.', 'Demasiados intentos. Por favor, espera.', 'Muitas tentativas. Por favor, aguarde.', 'Trop de tentatives. Veuillez patienter.', 'محاولات كثيرة جداً. يرجى الانتظار.');
  String get errPasswordShort  => _t('Şifre en az 6 karakter olmalıdır.',
      'Password must be at least 6 characters.', '비밀번호는 6자 이상이어야 해요.', 'パスワードは6文字以上にしてください。', 'Kata sandi minimal 6 karakter.', 'Mật khẩu phải có ít nhất 6 ký tự.', 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร', 'Пароль должен содержать не менее 6 символов.', 'La contraseña debe tener al menos 6 caracteres.', 'A senha deve ter pelo menos 6 caracteres.', 'Le mot de passe doit contenir au moins 6 caractères.', 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.');
  String get errInvalidEmail   => _t('Geçersiz e-posta adresi.',
      'Invalid email address.', '올바르지 않은 이메일 주소예요.', 'メールアドレスが正しくありません。', 'Alamat email tidak valid.', 'Địa chỉ email không hợp lệ.', 'อีเมลไม่ถูกต้อง', 'Неверный адрес электронной почты.', 'Dirección de correo electrónico no válida.', 'Endereço de e-mail inválido.', 'Adresse e-mail invalide.', 'عنوان البريد الإلكتروني غير صالح.');
  String get errVerifyPending  => _t('E-posta henüz doğrulanmadı. Gelen kutunuzu kontrol edin.',
      'Email not verified yet. Check your inbox.', '아직 이메일 인증이 안 됐어요. 받은편지함을 확인해 주세요.', 'メール認証がまだです。受信トレイをご確認ください。', 'Email belum diverifikasi. Periksa kotak masukmu.', 'Email chưa được xác minh. Hãy kiểm tra hộp thư.', 'ยังไม่ได้ยืนยันอีเมล กรุณาตรวจสอบกล่องจดหมาย', 'Эл. почта еще не подтверждена. Проверьте входящие.', 'Correo electrónico aún no verificado. Revisa tu bandeja de entrada.', 'E-mail ainda não verificado. Verifique sua caixa de entrada.', 'E-mail non encore vérifié. Consultez votre boîte de réception.', 'لم يتم التحقق من البريد الإلكتروني بعد. تحقق من صندوق الوارد.');
  String get suggestNeedLogin  => _t('Öneri yapmak için giriş yapınız',
      'Sign in to suggest words', '단어를 제안하려면 로그인하세요', '単語を提案するにはログインしてください', 'Masuk untuk mengusulkan kata', 'Đăng nhập để đề xuất từ', 'เข้าสู่ระบบเพื่อเสนอคำ', 'Войдите, чтобы предлагать слова', 'Inicia sesión para sugerir palabras', 'Entre para sugerir palavras', 'Connectez-vous pour suggérer des mots', 'سجّل الدخول لاقتراح كلمات');

  // ── HSK levels ──────────────────────────────────────────────────────────────
  String hskLabel(int level) => level >= 7 ? _t('Diğer', 'Other', '기타', 'その他', 'Lainnya', 'Khác', 'อื่น ๆ', 'Другое', 'Otro', 'Outro', 'Autre', 'أخرى') : 'HSK $level';
  String hskSublabel(int level) => switch (level) {
    1 => _t('Başlangıç', 'Beginner', '입문', '入門', 'Pemula', 'Nhập môn', 'เริ่มต้น', 'Новичок', 'Principiante', 'Iniciante', 'Débutant', 'مبتدئ'),
    2 => _t('Temel', 'Elementary', '초급', '初級', 'Dasar', 'Sơ cấp', 'พื้นฐาน', 'Начальный', 'Elemental', 'Elementar', 'Élémentaire', 'مبتدئ'),
    3 => _t('Orta', 'Intermediate', '중급', '中級', 'Menengah', 'Trung cấp', 'ปานกลาง', 'Средний', 'Intermedio', 'Intermediário', 'Intermédiaire', 'متوسط'),
    4 => _t('Orta-İleri', 'Upper-Intermediate', '중상급', '中上級', 'Menengah Atas', 'Trung cao cấp', 'ปานกลางตอนปลาย', 'Выше среднего', 'Intermedio-alto', 'Intermediário avançado', 'Intermédiaire avancé', 'فوق المتوسط'),
    5 => _t('İleri', 'Advanced', '고급', '上級', 'Lanjutan', 'Cao cấp', 'ขั้นสูง', 'Продвинутый', 'Avanzado', 'Avançado', 'Avancé', 'متقدم'),
    6 => _t('Uzman', 'Expert', '최상급', '最上級', 'Mahir', 'Thành thạo', 'เชี่ยวชาญ', 'Эксперт', 'Experto', 'Especialista', 'Expert', 'خبير'),
    _ => '',
  };

  // ── Sidebar / hub ───────────────────────────────────────────────────────────
  String get videoTab      => _t('Öğren', 'Learn', '학습', '学ぶ', 'Belajar', 'Học', 'เรียน', 'Учить', 'Aprender', 'Aprender', 'Apprendre', 'تعلّم');
  String get dictionaryTab => _t('Sözlük', 'Dictionary', '사전', '辞書', 'Kamus', 'Từ điển', 'พจนานุกรม', 'Словарь', 'Diccionario', 'Dicionário', 'Dictionnaire', 'القاموس');
  String get socialTab     => _t('Sosyal', 'Social', '소셜', 'ソーシャル', 'Sosial', 'Xã hội', 'โซเชียล', 'Социальные сети', 'Social', 'Social', 'Social', 'اجتماعي');
  String get gamesTab      => _t('Oyun', 'Games', '게임', 'ゲーム', 'Permainan', 'Trò chơi', 'เกม', 'Игры', 'Juegos', 'Jogos', 'Jeux', 'الألعاب');
  String get hubDictionary => _t('Sözlük', 'Dictionary', '사전', '辞書', 'Kamus', 'Từ điển', 'พจนานุกรม', 'Словарь', 'Diccionario', 'Dicionário', 'Dictionnaire', 'القاموس');
  String get hubSocial     => _t('Sosyal', 'Social', '소셜', 'ソーシャル', 'Sosial', 'Xã hội', 'โซเชียล', 'Социальные сети', 'Social', 'Social', 'Social', 'اجتماعي');
  String get hubGames      => _t('Oyun', 'Games', '게임', 'ゲーム', 'Permainan', 'Trò chơi', 'เกม', 'Игры', 'Juegos', 'Jogos', 'Jeux', 'الألعاب');

  // ── Left navigation (path shell) ────────────────────────────────────────────
  String get navProfile    => _t('Profil', 'Profile', '프로필', 'プロフィール', 'Profil', 'Hồ sơ', 'โปรไฟล์', 'Профиль', 'Perfil', 'Perfil', 'Profil', 'الملف الشخصي');
  String get navLearn      => _t('Öğren', 'Learn', '학습', '学ぶ', 'Belajar', 'Học', 'เรียน', 'Учить', 'Aprender', 'Aprender', 'Apprendre', 'تعلّم');
  String get navDictionary => _t('Sözlük', 'Dictionary', '사전', '辞書', 'Kamus', 'Từ điển', 'พจนานุกรม', 'Словарь', 'Diccionario', 'Dicionário', 'Dictionnaire', 'القاموس');
  String get navPractice   => _t('Alıştırma', 'Practice', '연습', '練習', 'Latihan', 'Luyện tập', 'ฝึกฝน', 'Практика', 'Práctica', 'Praticar', 'Entraînement', 'تدريب');
  String get navRanks      => _t('Rütbeler', 'Ranks', '랭킹', 'ランク', 'Peringkat', 'Cấp bậc', 'อันดับ', 'Ранги', 'Rangos', 'Rankings', 'Classements', 'المراتب');
  String get navTeaHouse   => _t('Çayevi', 'Tea House', '찻집', '茶館', 'Kedai Teh', 'Quán trà', 'ร้านน้ำชา', 'Чайная', 'Casa de té', 'Casa de Chá', 'Salon de thé', 'بيت الشاي');
  String get navBazaar     => _t('Çarşı', 'Bazaar', '상점', 'ショップ', 'Toko', 'Cửa hàng', 'ร้านค้า', 'Базар', 'Bazar', 'Bazar', 'Bazar', 'البازار');
  String get navSettings   => _t('Ayarlar', 'Settings', '설정', '設定', 'Pengaturan', 'Cài đặt', 'การตั้งค่า', 'Настройки', 'Ajustes', 'Configurações', 'Paramètres', 'الإعدادات');
  String unitTitle(int n)  => _t('$n. Ünite', 'Unit $n', '유닛 $n', 'ユニット$n', 'Unit $n', 'Bài $n', 'บทที่ $n', 'Раздел $n', 'Unidad $n', 'Unidade $n', 'Unité $n', 'الوحدة $n');
  String get startStamp    => _t('BAŞLA', 'START', '시작', 'スタート', 'MULAI', 'BẮT ĐẦU', 'เริ่ม', 'НАЧАТЬ', 'EMPEZAR', 'INICIAR', 'DÉMARRER', 'ابدأ');

  // ── Right sidebar ───────────────────────────────────────────────────────────
  String get yourProgress     => _t('İlerlemen', 'Your progress', '내 진행 상황', '進捗状況', 'Kemajuanmu', 'Tiến độ của bạn', 'ความคืบหน้าของคุณ', 'Ваш прогресс', 'Tu progreso', 'Seu progresso', 'Votre progression', 'تقدمك');
  String phasesDone(int d, int t) =>
      _t('$d / $t faz tamamlandı', '$d / $t phases done', '$d / $t 단계 완료', '$d / $t フェーズ完了', '$d / $t fase selesai', 'Hoàn thành $d / $t giai đoạn', 'เสร็จ $d / $t ระยะ', '$d / $t этапов пройдено', '$d / $t fases completadas', '$d / $t fases concluídas', '$d / $t phases terminées', 'تم إنجاز $d / $t مرحلة');
  String get dailyQuest       => _t('Günlük Görev', 'Daily quest', '오늘의 주문', 'デイリークエスト', 'Misi Harian', 'Nhiệm vụ hằng ngày', 'ภารกิจประจำวัน', 'Ежедневное задание', 'Misión diaria', 'Missão diária', 'Quête quotidienne', 'المهمة اليومية');
  String get completeOnePhase => _t('Bir faz tamamla', 'Complete one phase', '한 단계 완료하기', 'フェーズを1つ完了', 'Selesaikan satu fase', 'Hoàn thành một giai đoạn', 'ทำให้เสร็จหนึ่งระยะ', 'Завершите один этап', 'Completa una fase', 'Conclua uma fase', 'Terminer une phase', 'أكمل مرحلة واحدة');

  // ── Leaderboard / leagues ───────────────────────────────────────────────────
  String get myLeague       => _t('Ligim', 'My League', '내 랭크', 'マイリーグ', 'Ligaku', 'Giải của tôi', 'ลีกของฉัน', 'Моя лига', 'Mi liga', 'Minha liga', 'Ma ligue', 'دوريّ');
  String get friendsTab     => _t('Arkadaşlarım', 'Friends', '친구', 'フレンド', 'Teman', 'Bạn bè', 'เพื่อน', 'Друзья', 'Amigos', 'Amigos', 'Amis', 'الأصدقاء');
  String leagueOf(String n) => _t('$n Ligi', '$n League', '$n 리그', '$n リーグ', 'Liga $n', 'Giải $n', 'ลีก $n', 'Лига $n', 'Liga $n', 'Liga $n', 'Ligue $n', 'دوري $n');
  // 12 zodiac (生肖) league tiers, bottom-up; the Dragon is the diamond top.
  String leagueName(int tier) => switch (tier) {
        1 => _t('Fare', 'Rat', '쥐', 'ねずみ', 'Tikus', 'Chuột', 'หนู', 'Крыса', 'Rata', 'Rato', 'Rat', 'جرذ'),
        2 => _t('Öküz', 'Ox', '소', 'うし', 'Kerbau', 'Trâu', 'วัว', 'Бык', 'Buey', 'Boi', 'Bœuf', 'الثور'),
        3 => _t('Kaplan', 'Tiger', '호랑이', 'とら', 'Macan', 'Hổ', 'เสือ', 'Тигр', 'Tigre', 'Tigre', 'Tigre', 'نمر'),
        4 => _t('Tavşan', 'Rabbit', '토끼', 'うさぎ', 'Kelinci', 'Mèo', 'กระต่าย', 'Кролик', 'Conejo', 'Coelho', 'Lapin', 'أرنب'),
        5 => _t('Yılan', 'Snake', '뱀', 'へび', 'Ular', 'Rắn', 'งู', 'Змея', 'Serpiente', 'Cobra', 'Serpent', 'ثعبان'),
        6 => _t('At', 'Horse', '말', 'うま', 'Kuda', 'Ngựa', 'ม้า', 'Лошадь', 'Caballo', 'Cavalo', 'Cheval', 'حصان'),
        7 => _t('Keçi', 'Goat', '양', 'ひつじ', 'Kambing', 'Dê', 'แพะ', 'Коза', 'Cabra', 'Cabra', 'Chèvre', 'ماعز'),
        8 => _t('Maymun', 'Monkey', '원숭이', 'さる', 'Monyet', 'Khỉ', 'ลิง', 'Обезьяна', 'Mono', 'Macaco', 'Singe', 'قرد'),
        9 => _t('Horoz', 'Rooster', '닭', 'とり', 'Ayam Jago', 'Gà', 'ไก่', 'Петух', 'Gallo', 'Galo', 'Coq', 'ديك'),
        10 => _t('Köpek', 'Dog', '개', 'いぬ', 'Anjing', 'Chó', 'สุนัข', 'Собака', 'Perro', 'Cachorro', 'Chien', 'كلب'),
        11 => _t('Domuz', 'Pig', '돼지', 'いのしし', 'Babi', 'Lợn', 'หมู', 'Свинья', 'Cerdo', 'Porco', 'Cochon', 'الخنزير'),
        _ => _t('Ejderha', 'Dragon', '용', 'たつ', 'Naga', 'Rồng', 'มังกร', 'Дракон', 'Dragón', 'Dragão', 'Dragon', 'تنين'),
      };
  String get dragonTab      => _t('Ejderha', 'Dragon', '용', 'たつ', 'Naga', 'Rồng', 'มังกร', 'Дракон', 'Dragón', 'Dragão', 'Dragon', 'تنين');
  String get leagueRules    => _t('Bu haftanın sıralaması — ilk 6 yükselir, son 6 düşer',
      "This week's ranking — top 6 promote, bottom 6 demote",
      '이번 주 순위 — 상위 6명 승급, 하위 6명 강등',
      '今週のランキング — 上位6名が昇格、下位6名が降格',
      'Peringkat pekan ini — 6 teratas naik, 6 terbawah turun',
      'Xếp hạng tuần này — 6 đầu lên hạng, 6 cuối xuống hạng',
      'อันดับสัปดาห์นี้ — 6 อันดับแรกเลื่อนขึ้น 6 อันดับสุดท้ายตกลง', 'Рейтинг этой недели — топ-6 переходят выше, последние 6 — ниже', 'Clasificación de esta semana: los 6 mejores ascienden, los 6 últimos descienden', 'Ranking desta semana — os 6 melhores sobem, os 6 piores descem', 'Classement de la semaine — les 6 premiers montent, les 6 derniers descendent', 'ترتيب هذا الأسبوع — يصعد أول 6، ويهبط آخر 6');
  String get findFriends    => _t('ARKADAŞ ARA', 'FIND FRIENDS', '친구 찾기', 'フレンドを探す', 'CARI TEMAN', 'TÌM BẠN', 'หาเพื่อน', 'НАЙТИ ДРУЗЕЙ', 'BUSCAR AMIGOS', 'ENCONTRAR AMIGOS', 'TROUVER DES AMIS', 'البحث عن أصدقاء');
  String get noFriendsYet   => _t('Henüz arkadaşın yok — kullanıcı adıyla arayıp ekleyebilirsin.',
      'No friends yet — search by username and add them.',
      '아직 친구가 없어요 — 사용자 이름으로 검색해서 추가해 보세요.',
      'まだフレンドがいません — ユーザー名で検索して追加しましょう。',
      'Belum ada teman — cari lewat nama pengguna lalu tambahkan.',
      'Chưa có bạn — tìm theo tên người dùng rồi thêm vào.',
      'ยังไม่มีเพื่อน — ค้นหาด้วยชื่อผู้ใช้แล้วเพิ่มเพื่อน', 'Друзей пока нет — найдите их по имени пользователя и добавьте.', 'Aún no tienes amigos. Busca por nombre de usuario y añádelos.', 'Nenhum amigo ainda — pesquise pelo nome de usuário e adicione-os.', 'Aucun ami pour l\'instant — recherchez par nom d\'utilisateur pour les ajouter.', 'لا يوجد أصدقاء بعد — ابحث عن طريق اسم المستخدم وأضفهم.');
  String get typeUsername   => _t('Kullanıcı adı yaz…', 'Type a username…', '사용자 이름 입력…', 'ユーザー名を入力…', 'Ketik nama pengguna…', 'Nhập tên người dùng…', 'พิมพ์ชื่อผู้ใช้…', 'Введите имя пользователя…', 'Escribe un nombre de usuario…', 'Digite um nome de usuário…', 'Saisissez un nom d\'utilisateur…', 'اكتب اسم المستخدم...');
  String get addLbl         => _t('Ekle', 'Add', '추가', '追加', 'Tambah', 'Thêm', 'เพิ่ม', 'Добавить', 'Añadir', 'Adicionar', 'Ajouter', 'إضافة');
  String get friendRequests => _t('Arkadaşlık İstekleri', 'Friend Requests', '친구 요청', 'フレンド申請', 'Permintaan Teman', 'Lời mời kết bạn', 'คำขอเป็นเพื่อน', 'Запросы в друзья', 'Solicitudes de amistad', 'Solicitações de amizade', 'Demandes d\'amis', 'طلبات الصداقة');
  String get streakTitle    => _t('Seri', 'Streak', '스트릭', '連続記録', 'Beruntun', 'Chuỗi ngày', 'สถิติต่อเนื่อง', 'Серия', 'Racha', 'Ofensiva', 'Série', 'سلسلة الأيام');
  String streakDays(int n)  => _t('$n gün', '$n days', '$n일', '$n日', '$n hari', '$n ngày', '$n วัน', '$n дней', '$n días', '$n dias', '$n jours', '$n يوم');
  String get streakWeek     => _t('1 hafta', '1 week', '1주', '1週間', '1 minggu', '1 tuần', '1 สัปดาห์', '1 неделя', '1 semana', '1 semana', '1 semaine', 'أسبوع واحد');
  String get streakMonth    => _t('1 ay', '1 month', '1개월', '1か月', '1 bulan', '1 tháng', '1 เดือน', '1 месяц', '1 mes', '1 mês', '1 mois', 'شهر واحد');
  String get streak100      => _t('100 gün', '100 days', '100일', '100日', '100 hari', '100 ngày', '100 วัน', '100 дней', '100 días', '100 dias', '100 jours', '100 يوم');
  String get streak6Months  => _t('6 ay', '6 months', '6개월', '6か月', '6 bulan', '6 tháng', '6 เดือน', '6 месяцев', '6 meses', '6 meses', '6 mois', '6 أشهر');
  String get streakHint     => _t('Her gün bir soru cevapla, seri büyüsün.',
      'Answer one question a day to grow the streak.', '매일 한 문제만 풀어도 스트릭이 자라요.', '毎日1問解いて連続記録を伸ばしましょう。', 'Jawab satu soal tiap hari agar rentetan bertambah.', 'Trả lời một câu mỗi ngày để nối dài chuỗi.', 'ตอบวันละหนึ่งข้อเพื่อต่อสถิติ', 'Отвечайте на один вопрос в день, чтобы поддерживать серию.', 'Responde una pregunta al día para aumentar tu racha.', 'Responda a uma pergunta por dia para manter sua sequência.', 'Répondez à une question par jour pour maintenir votre série.', 'أجب عن سؤال واحد يومياً للحفاظ على سلسلة التقدم.');
  String get requestSent    => _t('İstek gönderildi', 'Request sent', '요청 보냄', '申請を送信', 'Permintaan terkirim', 'Đã gửi lời mời', 'ส่งคำขอแล้ว', 'Запрос отправлен', 'Solicitud enviada', 'Solicitação enviada', 'Demande envoyée', 'تم إرسال الطلب');
  String get acceptLbl      => _t('Onayla', 'Accept', '수락', '承認', 'Terima', 'Chấp nhận', 'ยอมรับ', 'Принять', 'Aceptar', 'Aceitar', 'Accepter', 'قبول');
  String get declineRequest => _t('Reddet', 'Decline', '거절', '拒否', 'Tolak', 'Từ chối', 'ปฏิเสธ', 'Отклонить', 'Rechazar', 'Recusar', 'Refuser', 'رفض');
  String get noRequests     => _t('Bekleyen istek yok.', 'No pending requests.', '대기 중인 요청이 없어요.', '保留中の申請はありません。', 'Tidak ada permintaan tertunda.', 'Không có lời mời nào đang chờ.', 'ไม่มีคำขอค้างอยู่', 'Нет ожидающих запросов.', 'No hay solicitudes pendientes.', 'Nenhuma solicitação pendente.', 'Aucune demande en attente.', 'لا توجد طلبات معلقة.');
  String get removeLbl      => _t('Çıkar', 'Remove', '삭제', '削除', 'Hapus', 'Xóa', 'ลบ', 'Удалить', 'Eliminar', 'Remover', 'Supprimer', 'إزالة');
  String get noResultsLbl   => _t('Sonuç yok', 'No results', '결과 없음', '結果なし', 'Tidak ada hasil', 'Không có kết quả', 'ไม่มีผลลัพธ์', 'Нет результатов', 'Sin resultados', 'Sem resultados', 'Aucun résultat', 'لا توجد نتائج');
  String get zhuangyuanTitle => _t('Ejderha Sıralaması', 'Dragon Ranking', '용 리그 랭킹', 'たつリーグランキング', 'Peringkat Naga', 'Bảng xếp hạng Rồng', 'อันดับมังกร', 'Рейтинг драконов', 'Clasificación Dragón', 'Ranking de Dragões', 'Classement Dragon', 'تصنيف التنين');
  String get zhuangyuanDesc => _t('Ejderha Ligi\'nde geçirilen her hafta +1 elmas; dışında kalınan her hafta −1.',
      'Each week in the Dragon League earns +1 diamond; each week outside costs −1.',
      '용 리그에서 보낸 주마다 다이아 +1, 벗어난 주마다 −1이에요.',
      'たつリーグで過ごした週ごとにダイヤ+1、外れた週ごとに−1です。',
      'Tiap pekan di Liga Naga +1 berlian; tiap pekan di luar −1.',
      'Mỗi tuần ở Giải Rồng +1 kim cương; mỗi tuần ngoài giải −1.',
      'ทุกสัปดาห์ในลีกมังกรได้เพชร +1; ทุกสัปดาห์นอกลีก −1', 'Каждая неделя в Лиге Драконов приносит +1 алмаз; каждая неделя вне лиги отнимает −1.', 'Cada semana en la Liga Dragón ganas +1 diamante; cada semana fuera pierdes −1.', 'Cada semana na Liga do Dragão rende +1 diamante; cada semana fora custa −1.', 'Chaque semaine dans la Ligue Dragon rapporte +1 diamant ; chaque semaine en dehors en coûte −1.', 'كل أسبوع في دوري التنين يمنحك +1 ماسة؛ وكل أسبوع خارجه يكلف -1.');
  String get noDiamondsYet  => _t('Henüz elmas kazanan yok — Ejderha Ligi\'ne ilk ulaşan sen ol!',
      'No diamonds earned yet — be the first to reach the Dragon League!',
      '아직 다이아를 얻은 사람이 없어요 — 첫 용 리그에 도전해 보세요!',
      'まだダイヤを獲得した人はいません — 最初のたつリーグを目指しましょう！',
      'Belum ada yang dapat berlian — jadilah yang pertama mencapai Liga Naga!',
      'Chưa ai có kim cương — hãy là người đầu tiên đạt Giải Rồng!',
      'ยังไม่มีใครได้เพชร — เป็นคนแรกที่ไปถึงลีกมังกรสิ!', 'Вы еще не заработали алмазы — станьте первым, кто попадет в Лигу Дракона!', 'Aún no has ganado diamantes. ¡Sé el primero en llegar a la Liga Dragón!', 'Nenhum diamante ganho ainda — seja o primeiro a alcançar a Liga do Dragão!', 'Aucun diamant gagné pour l\'instant — soyez le premier à atteindre la Ligue Dragon !', 'لم تكسب أي ماسات بعد — كن أول من يصل إلى دوري التنين!');
  String get leagueHowTitle => _t('Lig Nasıl Çalışır?', 'How ranks work', '랭크 안내', 'ランクの仕組み', 'Cara Kerja Peringkat', 'Cách xếp hạng hoạt động', 'อันดับทำงานอย่างไร', 'Как работает рейтинг', 'Cómo funcionan las clasificaciones', 'Como funcionam os rankings', 'Comment fonctionne le classement', 'كيف تعمل التصنيفات');
  String get leagueHowBody  => _t('Ders tamamladıkça puan kazanır, haftalık sıralamada yükselirsin.',
      'Earn points by completing lessons and climb the weekly ranking.',
      '학습을 완료하면 점수를 얻고 주간 순위가 올라가요.',
      'レッスンを完了すると点数を獲得し、週間ランキングが上がります。',
      'Selesaikan pelajaran untuk dapat poin dan naik di peringkat mingguan.',
      'Hoàn thành bài học để nhận điểm và leo bảng xếp hạng tuần.',
      'ทำบทเรียนให้เสร็จเพื่อรับคะแนนและไต่อันดับประจำสัปดาห์', 'Зарабатывайте очки, проходя уроки, и поднимайтесь в еженедельном рейтинге.', 'Gana puntos completando lecciones y sube en la clasificación semanal.', 'Ganhe pontos completando lições e suba no ranking semanal.', 'Gagnez des points en terminant des leçons et grimpez dans le classement hebdomadaire.', 'اكسب النقاط من خلال إكمال الدروس وارتقِ في التصنيف الأسبوعي.');

  // ── Tea house (quests) ──────────────────────────────────────────────────────
  String get teaHouseTitle  => _t('Çayevi Siparişleri ☕', 'Tea House Orders ☕', '찻집 주문 ☕', '茶館の注文 ☕', 'Pesanan Kedai Teh ☕', 'Đơn hàng Quán trà ☕', 'ออร์เดอร์ร้านน้ำชา ☕', 'Заказы в чайной ☕', 'Pedidos de la casa de té ☕', 'Pedidos da Casa de Chá ☕', 'Commandes du salon de thé ☕', 'طلبات بيت الشاي ☕');
  String teaHouseSub(int n) => _t('Siparişleri tamamla, hongbao 🧧 kazan! Bugün 3 siparişin $n tanesi hazır.',
      'Fill the orders, earn hongbao 🧧! $n of 3 ready today.',
      '주문을 완료하고 홍바오 🧧 를 받아 보세요! 오늘 3개 중 $n개 완료.',
      '注文を完了して紅包 🧧 をもらおう！本日は3件中$n件完了。',
      'Selesaikan pesanan, dapat hongbao 🧧! Hari ini $n dari 3 siap.',
      'Hoàn thành đơn, nhận hồng bao 🧧! Hôm nay xong $n trong 3 đơn.',
      'ทำออร์เดอร์ให้เสร็จ รับอั่งเปา 🧧! วันนี้เสร็จ $n จาก 3 ออร์เดอร์', 'Выполняйте заказы и получайте хунбао 🧧! Сегодня готово $n из 3.', '¡Completa los pedidos y gana hongbao 🧧! $n de 3 listos hoy.', 'Complete os pedidos, ganhe hongbao 🧧! $n de 3 prontos hoje.', 'Remplissez les commandes, gagnez des hongbao 🧧 ! $n sur 3 prêts aujourd\'hui.', 'أكمل الطلبات واكسب هونغ باو 🧧! $n من 3 جاهزة اليوم.');
  String get todaysOrders   => _t('Günün Siparişleri', "Today's Orders", '오늘의 주문', '本日の注文', 'Pesanan Hari Ini', 'Đơn hàng hôm nay', 'ออร์เดอร์วันนี้', 'Сегодняшние заказы', 'Pedidos de hoy', 'Pedidos de hoje', 'Commandes du jour', 'طلبات اليوم');
  String hoursLeftLbl(int h) => _t('$h SAAT', '$h HOURS', '$h시간 남음', '残り$h時間', '$h JAM', 'CÒN $h GIỜ', 'อีก $h ชม.', '$h ЧАСОВ', '$h HORAS', '$h HORAS', '$h HEURES', '$h ساعة');
  String get hongbaoToast   => _t('🧧 Hongbao açıldı: +20 altın!', '🧧 Hongbao: +20 gold!', '🧧 홍바오 획득: 금화 +20!', '🧧 紅包を開封：ゴールド+20！', '🧧 Hongbao dibuka: +20 emas!', '🧧 Mở hồng bao: +20 vàng!', '🧧 เปิดอั่งเปา: +20 ทอง!', '🧧 Хунбао: +20 золота!', '🧧 Hongbao: ¡+20 de oro!', '🧧 Hongbao: +20 de ouro!', '🧧 Hongbao : +20 pièces d\'or !', '🧧 هونغ باو: +20 ذهبية!');
  String questEarnPoints(int n)  => _t('$n puan kazan', 'Earn $n points', '$n점 모으기', '$n点を獲得', 'Kumpulkan $n poin', 'Kiếm $n điểm', 'รับ $n คะแนน', 'Заработайте $n очков', 'Gana $n puntos', 'Ganhe $n pontos', 'Gagnez $n points', 'اكسب $n نقطة');
  String questAnswerN(int n)     => _t('$n soru cevapla', 'Answer $n questions', '문제 $n개 풀기', '$n問に回答', 'Jawab $n soal', 'Trả lời $n câu', 'ตอบ $n ข้อ', 'Ответьте на $n вопросов', 'Responde $n preguntas', 'Responda $n perguntas', 'Répondre à $n questions', 'أجب عن $n من الأسئلة');
  String questCorrectN(int n)    => _t('$n doğru cevap ver', 'Get $n correct answers', '정답 $n개 맞히기', '$n問正解する', 'Dapatkan $n jawaban benar', 'Trả lời đúng $n câu', 'ตอบถูก $n ข้อ', 'Дайте $n правильных ответов', 'Obtén $n respuestas correctas', 'Obtenha $n respostas corretas', 'Obtenez $n bonnes réponses', 'احصل على $n إجابة صحيحة');
  String get questKeepStreak     => _t('Seriyi sürdür (bugün 1 soru)', 'Keep the streak (1 today)', '연속 기록 잇기 (오늘 1문제)', '連続記録を維持（本日1問）', 'Jaga rentetan (1 soal hari ini)', 'Giữ chuỗi (1 câu hôm nay)', 'รักษาสถิติ (วันนี้ 1 ข้อ)', 'Поддержите серию (1 сегодня)', 'Mantén la racha (1 hoy)', 'Mantenha a sequência (1 hoje)', 'Maintenir la série (1 aujourd\'hui)', 'حافظ على سلسلة التعلم (1 اليوم)');
  String get monthlyBadges  => _t('Aylık Rozetler', 'Monthly badges', '이달의 배지', '今月のバッジ', 'Lencana Bulanan', 'Huy hiệu tháng', 'เหรียญตราประจำเดือน', 'Ежемесячные значки', 'Insignias mensuales', 'Emblemas mensais', 'Badges mensuels', 'شارات شهرية');

  // ── Badges (rozetler): Three Kingdoms + mythology achievement ladder ───────
  String get badgesTitle    => _t('Rozetler', 'Badges', '배지', 'バッジ', 'Lencana', 'Huy hiệu', 'เหรียญตรา', 'Значки', 'Insignias', 'Conquistas', 'Badges', 'الأوسمة');
  String get badgesSub      => _t('Üç Krallık kahramanları ve Çin mitolojisinin efsaneleri — başarılarınla mühürlerini kazan.',
      'Heroes of the Three Kingdoms and legends of Chinese mythology — earn their seals with your progress.',
      '삼국지 영웅과 중국 신화의 전설 — 학습 성과로 인장을 모아 보세요.',
      '三国志の英雄と中国神話の伝説 — 学習の成果で印章を集めましょう。',
      'Pahlawan Tiga Kerajaan dan legenda mitologi Tiongkok — kumpulkan segelnya lewat kemajuanmu.',
      'Anh hùng Tam Quốc và huyền thoại thần thoại Trung Hoa — sưu tầm ấn triện qua tiến độ của bạn.',
      'วีรบุรุษสามก๊กและตำนานเทพปกรณัมจีน — สะสมตราประทับด้วยความก้าวหน้าของคุณ', 'Герои Троецарствия и легенды китайской мифологии — зарабатывайте их печати по мере прогресса.', 'Héroes de los Tres Reinos y leyendas de la mitología china: gana sus sellos con tu progreso.', 'Heróis dos Três Reinos e lendas da mitologia chinesa — ganhe seus selos com seu progresso.', 'Héros des Trois Royaumes et légendes de la mythologie chinoise : gagnez leurs sceaux au fil de votre progression.', 'أبطال الممالك الثلاث وأساطير الميثولوجيا الصينية — احصل على أختامهم مع تقدمك في التعلم.');
  String get badgeCatSages    => _t('Bilgeler — izleme', 'Sages — watch time', '책사 — 시청 시간', '軍師 — 視聴時間', 'Cendekiawan — waktu tonton', 'Quân sư — thời gian xem', 'ที่ปรึกษา — เวลาดู', 'Мудрецы — время просмотра', 'Sabios — tiempo de visualización', 'Sábios — tempo de exibição', 'Sages — temps de visionnage', 'الحكماء — وقت المشاهدة');
  String get badgeCatWarriors => _t('Savaşçılar — doğru cevap', 'Warriors — correct answers', '무장 — 정답 수', '武将 — 正解数', 'Ksatria — jawaban benar', 'Võ tướng — số câu đúng', 'นักรบ — จำนวนตอบถูก', 'Воины — правильные ответы', 'Guerreros: respuestas correctas', 'Guerreiros — respostas corretas', 'Guerriers — réponses correctes', 'المحاربون — الإجابات الصحيحة');
  String get badgeCatRulers   => _t('Hükümdarlar — üniteler', 'Rulers — units', '군주 — 유닛', '君主 — ユニット', 'Penguasa — unit', 'Quân vương — bài học', 'ผู้ปกครอง — บทเรียน', 'Правители — единицы', 'Reglas — unidades', 'Réguas — unidades', 'Règles — unités', 'الحكام — وحدات');
  String get badgeCatLegends  => _t('Efsaneler — seviyeler', 'Legends — levels', '전설 — 레벨', '伝説 — レベル', 'Legenda — level', 'Huyền thoại — cấp độ', 'ตำนาน — ระดับ', 'Легенды — уровни', 'Leyendas — niveles', 'Lendas — níveis', 'Légendes — niveaux', 'الأساطير — المستويات');
  String badgeWatchCond(int m)  => _t('$m dk video izle', 'Watch $m min', '영상 $m분 시청', '動画を$m分視聴', 'Tonton $m mnt', 'Xem $m phút', 'ดู $m นาที', 'Смотреть $m мин', 'Ver $m min', 'Assista por $m min', 'Regarder $m min', 'شاهد $m دقيقة');
  String badgeCorrectCond(int n) => _t('$n doğru cevap ver', '$n correct answers', '정답 $n개 달성', '正解$n問達成', '$n jawaban benar', '$n câu đúng', 'ตอบถูก $n ข้อ', '$n правильных ответов', '$n respuestas correctas', '$n respostas corretas', '$n réponses correctes', '$n إجابة صحيحة');
  String badgeUnitsCond(int n)  => _t('$n ünite bitir', 'Finish $n units', '유닛 $n개 완료', 'ユニット$n個を完了', 'Selesaikan $n unit', 'Hoàn thành $n bài', 'จบ $n บท', 'Завершите $n разделов', 'Termina $n unidades', 'Conclua $n unidades', 'Terminez $n unités', 'أكمل $n وحدة');
  String badgeLevelsCond(int n) => _t('$n seviye bitir', 'Finish $n levels', '레벨 $n개 완료', 'レベル$n個を完了', 'Selesaikan $n level', 'Hoàn thành $n cấp độ', 'จบ $n ระดับ', 'Завершите $n уровней', 'Termina $n niveles', 'Conclua $n níveis', 'Terminez $n niveaux', 'أكمل $n مستوى');
  // Figure display names: pinyin for Latin-script langs, established readings for KO/JA.
  String badgeFigure(String id) => switch (id) {
        'xushu' => _t('Xu Shu', 'Xu Shu', '서서', '徐庶', 'Xu Shu', 'Từ Thứ', 'ชีซู', 'Сюй Шу', 'Xu Shu', 'Xu Shu', 'Xu Shu', 'شو شو'),
        'pangtong' => _t('Pang Tong', 'Pang Tong', '방통', '龐統', 'Pang Tong', 'Bàng Thống', 'บังทอง', 'Пан Тун', 'Pang Tong', 'Pang Tong', 'Pang Tong', 'بانغ تونغ'),
        'zhugeliang' => _t('Zhuge Liang', 'Zhuge Liang', '제갈량', '諸葛亮', 'Zhuge Liang', 'Gia Cát Lượng', 'ขงเบ้ง', 'Чжугэ Лян', 'Zhuge Liang', 'Zhuge Liang', 'Zhuge Liang', 'تشوغه ليانغ'),
        'jiangziya' => _t('Jiang Ziya', 'Jiang Ziya', '강태공', '太公望', 'Jiang Ziya', 'Khương Tử Nha', 'เจียงจื่อหยา', 'Цзян Цзыя', 'Jiang Ziya', 'Jiang Ziya', 'Jiang Ziya', 'جيانغ زيا'),
        'zhaoyun' => _t('Zhao Yun', 'Zhao Yun', '조운', '趙雲', 'Zhao Yun', 'Triệu Vân', 'จูล่ง', 'Чжао Юнь', 'Zhao Yun', 'Zhao Yun', 'Zhao Yun', 'تشاو يون'),
        'guanyu' => _t('Guan Yu', 'Guan Yu', '관우', '関羽', 'Guan Yu', 'Quan Vũ', 'กวนอู', 'Гуань Юй', 'Guan Yu', 'Guan Yu', 'Guan Yu', 'غوان يو'),
        'lvbu' => _t('Lü Bu', 'Lü Bu', '여포', '呂布', 'Lü Bu', 'Lữ Bố', 'ลิโป้', 'Люй Бу', 'Lü Bu', 'Lü Bu', 'Lü Bu', 'لو بو'),
        'nezha' => _t('Nezha', 'Nezha', '나타', 'ナタ', 'Nezha', 'Na Tra', 'นาจา', 'Нэчжа', 'Nezha', 'Nezha', 'Nezha', 'نزهة'),
        'liubei' => _t('Liu Bei', 'Liu Bei', '유비', '劉備', 'Liu Bei', 'Lưu Bị', 'เล่าปี่', 'Лю Бэй', 'Liu Bei', 'Liu Bei', 'Liu Bei', 'ليو باي'),
        'sunquan' => _t('Sun Quan', 'Sun Quan', '손권', '孫権', 'Sun Quan', 'Tôn Quyền', 'ซุนกวน', 'Сунь Цюань', 'Sun Quan', 'Sun Quan', 'Sun Quan', 'سون تشوان'),
        'caocao' => _t('Cao Cao', 'Cao Cao', '조조', '曹操', 'Cao Cao', 'Tào Tháo', 'โจโฉ', 'Цао Цао', 'Cao Cao', 'Cao Cao', 'Cao Cao', 'تساو تساو'),
        'pangu' => _t('Pangu', 'Pangu', '반고', '盤古', 'Pangu', 'Bàn Cổ', 'ผานกู่', 'Пань-гу', 'Pangu', 'Pangu', 'Pangu', 'بانغو'),
        'zhangfei' => _t('Zhang Fei', 'Zhang Fei', '장비', '張飛', 'Zhang Fei', 'Trương Phi', 'เตียวหุย', 'Чжан Фэй', 'Zhang Fei', 'Zhang Fei', 'Zhang Fei', 'تشانغ في'),
        'zhouyu' => _t('Zhou Yu', 'Zhou Yu', '주유', '周瑜', 'Zhou Yu', 'Chu Du', 'จิวยี่', 'Чжоу Юй', 'Zhou Yu', 'Zhou Yu', 'Zhou Yu', 'تشو يو'),
        'simayi' => _t('Sima Yi', 'Sima Yi', '사마의', '司馬懿', 'Sima Yi', 'Tư Mã Ý', 'สุมาอี้', 'Сыма И', 'Sima Yi', 'Sima Yi', 'Sima Yi', 'سيما يي'),
        'nuwa' => _t('Nüwa', 'Nüwa', '여와', '女媧', 'Nüwa', 'Nữ Oa', 'หนี่วา', 'Нюйва', 'Nüwa', 'Nüwa', 'Nüwa', 'نوا'),
        _ => id,
      };
  String get monthlyBadgesBody => _t('Görevleri tamamla, bu ayın rozetini kazan.',
      "Complete quests to earn this month's badge.", '주문을 완료하고 이달의 배지를 받아 보세요.', 'クエストを完了して今月のバッジを獲得しましょう。', 'Selesaikan misi untuk meraih lencana bulan ini.', 'Hoàn thành nhiệm vụ để nhận huy hiệu tháng này.', 'ทำภารกิจให้เสร็จเพื่อรับเหรียญตราประจำเดือนนี้', 'Выполняйте задания, чтобы получить значок этого месяца.', 'Completa misiones para ganar la insignia de este mes.', 'Complete missões para ganhar a conquista deste mês.', 'Terminez des quêtes pour gagner le badge de ce mois-ci.', 'أكمل المهام لتربح وسام هذا الشهر.');

  // ── Bazaar (shop) ───────────────────────────────────────────────────────────
  String get heartsTitle    => _t('Canlar', 'Hearts', '하트', 'ハート', 'Nyawa', 'Tim', 'หัวใจ', 'Жизни', 'Vidas', 'Vidas', 'Cœurs', 'القلوب');
  String get refillHearts   => _t('Canları Yenile', 'Refill hearts', '하트 충전', 'ハートを補充', 'Isi Nyawa', 'Nạp tim', 'เติมหัวใจ', 'Восполнить жизни', 'Recargar corazones', 'Recarregar corações', 'Recharger les cœurs', 'تعبئة القلوب');
  String refillSub(int h, int m) => _t('Canlarını tekrar doldur ($h/$m)',
      'Refill your hearts ($h/$m)', '하트를 다시 채워요 ($h/$m)', 'ハートを満タンに ($h/$m)', 'Isi penuh nyawamu ($h/$m)', 'Nạp đầy tim ($h/$m)', 'เติมหัวใจให้เต็ม ($h/$m)', 'Восполнить жизни ($h/$m)', 'Recarga tus corazones ($h/$m)', 'Recarregue seus corações ($h/$m)', 'Recharger vos cœurs ($h/$m)', 'تعبئة قلوبك ($h/$m)');
  String get fullLbl        => _t('TAM', 'FULL', '가득 참', '満タン', 'PENUH', 'ĐẦY', 'เต็ม', 'ЗАПОЛНЕНО', 'LLENO', 'CHEIO', 'COMPLET', 'ممتلئ');
  String get refillLbl      => _t('YENİLE', 'REFILL', '충전', '補充', 'ISI', 'NẠP', 'เติม', 'ВОСПОЛНИТЬ', 'RECARGAR', 'RECARREGAR', 'RECHARGER', 'إعادة شحن');
  String get unlimitedHearts => _t('Sınırsız Can', 'Unlimited hearts', '무제한 하트', '無制限ハート', 'Nyawa Tak Terbatas', 'Tim vô hạn', 'หัวใจไม่จำกัด', 'Бесконечные жизни', 'Vidas ilimitadas', 'Vidas ilimitadas', 'Vies illimitées', 'قلوب غير محدودة');
  String get premiumSub     => _t('Premium ile canın hiç tükenmesin', 'Never run out with Premium', '프리미엄으로 하트 걱정 없이!', 'プレミアムでハート切れの心配なし', 'Dengan Premium, nyawa tak pernah habis', 'Với Premium, tim không bao giờ hết', 'มีพรีเมียม หัวใจไม่มีวันหมด', 'Никогда не заканчиваются с Premium', 'Nunca te quedes sin vidas con Premium', 'Nunca fique sem com o Premium', 'Ne soyez jamais à court avec Premium', 'لا تنفد أبداً مع النسخة المميزة');
  String get powerUps       => _t('Güçlendiriciler', 'Power-ups', '아이템', 'アイテム', 'Penguat', 'Vật phẩm', 'ไอเทมเสริม', 'Усилители', 'Potenciadores', 'Power-ups', 'Bonus', 'المعززات');
  String get streakFreeze   => _t('Seri Dondurma', 'Streak freeze', '연속 기록 보호', '連続記録の保護', 'Beku Rentetan', 'Đóng băng chuỗi', 'แช่แข็งสถิติ', 'Заморозка серии', 'Pausa de racha', 'Congelamento de ofensiva', 'Gel de série', 'تجميد الحماس');
  String get streakFreezeSub => _t('Bir gün ara verince serin bozulmasın (yakında)',
      'Protect your streak for a day (soon)', '하루 쉬어도 연속 기록을 지켜줘요 (출시 예정)', '1日休んでも連続記録を守ります（近日公開）', 'Lindungi rentetanmu sehari (segera hadir)', 'Giữ chuỗi khi nghỉ một ngày (sắp có)', 'รักษาสถิติได้หนึ่งวัน (เร็ว ๆ นี้)', 'Защита серии на день (скоро)', 'Protege tu racha por un día (próximamente)', 'Proteja sua sequência por um dia (em breve)', 'Protégez votre série pendant un jour (bientôt)', 'احمِ سلسلة تقدمك ليوم واحد (قريباً)');
  String get soonLbl        => _t('YAKINDA', 'SOON', '준비 중', '近日公開', 'SEGERA', 'SẮP CÓ', 'เร็ว ๆ นี้', 'СКОРО', 'PRÓXIMAMENTE', 'EM BREVE', 'BIENTÔT', 'قريباً');

  // ── Settings ────────────────────────────────────────────────────────────────
  String get preferences    => _t('Tercihler', 'Preferences', '환경설정', '環境設定', 'Preferensi', 'Tùy chọn', 'การตั้งค่า', 'Настройки', 'Preferencias', 'Preferências', 'Préférences', 'التفضيلات');
  String get appearance     => _t('Görünüm', 'Appearance', '화면', '表示', 'Tampilan', 'Giao diện', 'การแสดงผล', 'Внешний вид', 'Apariencia', 'Aparência', 'Apparence', 'المظهر');
  String get darkMode       => _t('Karanlık mod', 'Dark mode', '다크 모드', 'ダークモード', 'Mode gelap', 'Chế độ tối', 'โหมดมืด', 'Темная тема', 'Modo oscuro', 'Modo escuro', 'Mode sombre', 'الوضع الداكن');
  String get appLanguage    => _t('Uygulama dili', 'App language', '앱 언어', 'アプリの言語', 'Bahasa aplikasi', 'Ngôn ngữ ứng dụng', 'ภาษาของแอป', 'Язык приложения', 'Idioma de la aplicación', 'Idioma do aplicativo', 'Langue de l\'application', 'لغة التطبيق');
  String get accountLbl     => _t('Hesap', 'Account', '계정', 'アカウント', 'Akun', 'Tài khoản', 'บัญชี', 'Аккаунт', 'Cuenta', 'Conta', 'Compte', 'الحساب');
  String get subscriptionLbl => _t('Abonelik', 'Subscription', '구독', 'サブスク', 'Langganan', 'Gói đăng ký', 'การสมัครสมาชิก', 'Подписка', 'Suscripción', 'Assinatura', 'Abonnement', 'اشتراك');
  String get logoutLbl      => _t('Çıkış Yap', 'Log out', '로그아웃', 'ログアウト', 'Keluar', 'Đăng xuất', 'ออกจากระบบ', 'Выйти', 'Cerrar sesión', 'Sair', 'Déconnexion', 'تسجيل الخروج');
  String get deleteForever  => _t('Hesabı Kalıcı Sil', 'Delete account', '계정 영구 삭제', 'アカウントを削除', 'Hapus akun', 'Xóa tài khoản', 'ลบบัญชี', 'Удалить аккаунт', 'Eliminar cuenta', 'Excluir conta', 'Supprimer le compte', 'حذف الحساب');
  String get deleteForeverMsg => _t('Hesabın ve tüm verilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'Your account and all data will be permanently deleted. This cannot be undone.',
      '계정과 모든 데이터가 영구적으로 삭제됩니다. 되돌릴 수 없어요.',
      'アカウントとすべてのデータが完全に削除されます。元には戻せません。',
      'Akun dan semua datamu akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
      'Tài khoản và toàn bộ dữ liệu của bạn sẽ bị xóa vĩnh viễn. Không thể hoàn tác.',
      'บัญชีและข้อมูลทั้งหมดของคุณจะถูกลบถาวร ไม่สามารถกู้คืนได้', 'Ваш аккаунт и все данные будут безвозвратно удалены. Это действие нельзя отменить.', 'Tu cuenta y todos tus datos se eliminarán permanentemente. Esto no se puede deshacer.', 'Sua conta e todos os seus dados serão excluídos permanentemente. Isso não pode ser desfeito.', 'Votre compte et toutes vos données seront définitivement supprimés. Cette action est irréversible.', 'سيتم حذف حسابك وجميع بياناتك نهائياً. لا يمكن التراجع عن هذا الإجراء.');
  String get giveUp         => _t('Vazgeç', 'Cancel', '취소', 'キャンセル', 'Batal', 'Hủy', 'ยกเลิก', 'Отмена', 'Cancelar', 'Cancelar', 'Annuler', 'إلغاء');
  String get deleteLbl      => _t('Sil', 'Delete', '삭제', '削除', 'Hapus', 'Xóa', 'ลบ', 'Удалить', 'Eliminar', 'Excluir', 'Supprimer', 'حذف');
  String get privacySettings => _t('Gizlilik ayarları', 'Privacy settings', '개인정보 설정', 'プライバシー設定', 'Pengaturan privasi', 'Cài đặt quyền riêng tư', 'การตั้งค่าความเป็นส่วนตัว', 'Настройки конфиденциальности', 'Configuración de privacidad', 'Configurações de privacidade', 'Paramètres de confidentialité', 'إعدادات الخصوصية');
  String get choosePlan     => _t('Bir plan seç', 'Choose a plan', '플랜 선택', 'プランを選択', 'Pilih paket', 'Chọn gói', 'เลือกแพ็กเกจ', 'Выберите тариф', 'Elige un plan', 'Escolha um plano', 'Choisir un forfait', 'اختر خطة اشتراك');
  String get supportLbl     => _t('Destek', 'Support', '지원', 'サポート', 'Bantuan', 'Hỗ trợ', 'การสนับสนุน', 'Поддержка', 'Soporte', 'Suporte', 'Support', 'الدعم');
  String get helpCenter     => _t('Yardım Merkezi', 'Help Center', '고객센터', 'ヘルプセンター', 'Pusat Bantuan', 'Trung tâm trợ giúp', 'ศูนย์ช่วยเหลือ', 'Справочный центр', 'Centro de ayuda', 'Central de Ajuda', 'Centre d\'aide', 'مركز المساعدة');
  String get logoutCaps     => _t('OTURUMU KAPAT', 'LOG OUT', '로그아웃', 'ログアウト', 'KELUAR', 'ĐĂNG XUẤT', 'ออกจากระบบ', 'ВЫЙТИ', 'CERRAR SESIÓN', 'SAIR', 'DÉCONNEXION', 'تسجيل الخروج');

  // ── Profile view ────────────────────────────────────────────────────────────
  String get pleaseSignIn   => _t('Giriş yapın', 'Please sign in', '로그인해 주세요', 'ログインしてください', 'Silakan masuk', 'Vui lòng đăng nhập', 'กรุณาเข้าสู่ระบบ', 'Пожалуйста, войдите', 'Por favor, inicia sesión', 'Por favor, faça login', 'Veuillez vous connecter', 'يرجى تسجيل الدخول');
  String joinedOn(int m, int y) {
    const trM = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    const idM = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    const thM = ['', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    const ruM = ['', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    const esM = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    const ptM = ['', 'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    const frM = ['', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    const arM = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    if (_isTr) return '${trM[m]} $y tarihinde katıldı';
    if (_isKo) return '$y년 $m월에 가입';
    if (_isJa) return '$y年$m月に登録';
    if (_isId) return 'Bergabung ${idM[m]} $y';
    if (_isVi) return 'Tham gia tháng $m/$y';
    if (_isTh) return 'เข้าร่วมเมื่อ ${thM[m]} $y';
    if (_isRu) return 'Присоединился в ${ruM[m]} $y';
    if (_isEs) return 'Se unió en ${esM[m]} de $y';
    if (_isPt) return 'Entrou em ${ptM[m]} de $y';
    if (_isFr) return 'Inscrit en ${frM[m]} $y';
    if (_isAr) return 'انضم في ${arM[m]} $y';
    return 'Joined $m/$y';
  }
  String get statistics     => _t('İstatistikler', 'Statistics', '통계', '統計', 'Statistik', 'Thống kê', 'สถิติ', 'Статистика', 'Estadísticas', 'Estatísticas', 'Statistiques', 'الإحصائيات');
  String get dayStreakLbl   => _t('Günlük seri', 'Day streak', '연속 학습', '連続日数', 'Rentetan harian', 'Chuỗi ngày', 'สถิติรายวัน', 'Дневная серия', 'Racha de días', 'Ofensiva diária', 'Série de jours', 'سلسلة الأيام');
  String get totalXpLbl     => _t('Toplam Puan', 'Total XP', '총 점수', '総ポイント', 'Total Poin', 'Tổng điểm', 'คะแนนรวม', 'Всего XP', 'XP total', 'XP total', 'XP total', 'إجمالي نقاط الخبرة');
  String get heartsLbl      => _t('Can', 'Hearts', '하트', 'ハート', 'Nyawa', 'Tim', 'หัวใจ', 'Жизни', 'Vidas', 'Vidas', 'Cœurs', 'القلوب');
  String get answeredLbl    => _t('Cevaplanan', 'Answered', '푼 문제', '回答数', 'Terjawab', 'Đã trả lời', 'ที่ตอบแล้ว', 'Отвечено', 'Respondido', 'Respondidas', 'Répondu', 'تمت الإجابة');
  String get passportTitle  => _t('Pasaport 🛂', 'Passport 🛂', '여권 🛂', 'パスポート 🛂', 'Paspor 🛂', 'Hộ chiếu 🛂', 'พาสปอร์ต 🛂', 'Паспорт 🛂', 'Pasaporte 🛂', 'Passaporte 🛂', 'Passeport 🛂', 'جواز السفر 🛂');
  String get passportEmpty  => _t('Pasaportun henüz boş — bir üniteyi tamamla, şehrin mührünü kazan!',
      'Your passport is empty — finish a unit to earn its city seal!',
      '아직 여권이 비어 있어요 — 유닛을 완료하고 도시 도장을 모아 보세요!',
      'パスポートはまだ空です — ユニットを完了して都市のスタンプを集めましょう！',
      'Paspormu masih kosong — selesaikan satu unit untuk meraih segel kotanya!',
      'Hộ chiếu còn trống — hoàn thành một bài để nhận dấu thành phố!',
      'พาสปอร์ตยังว่าง — ทำบทให้จบเพื่อรับตราเมือง!', 'Ваш паспорт пуст — завершите урок, чтобы получить печать города!', 'Tu pasaporte está vacío: ¡termina una unidad para ganar su sello de ciudad!', 'Seu passaporte está vazio — conclua uma unidade para ganhar o selo da cidade!', 'Votre passeport est vide — terminez une unité pour gagner son sceau de ville !', 'جواز سفرك فارغ — أكمل وحدة دراسية لتربح ختم المدينة الخاص بها!');
  String get scoresRanking  => _t('Puan ve Sıralama', 'Scores & Ranking', '점수와 순위', 'スコアと順位', 'Skor & Peringkat', 'Điểm & Xếp hạng', 'คะแนนและอันดับ', 'Счёт и рейтинг', 'Puntuaciones y clasificación', 'Pontuações e Ranking', 'Scores et classement', 'النتائج والترتيب');
  String get globalRank     => _t('Genel Sıralama', 'Global Rank', '전체 순위', '総合順位', 'Peringkat Global', 'Xếp hạng toàn cầu', 'อันดับโลก', 'Мировой рейтинг', 'Clasificación global', 'Ranking Global', 'Classement mondial', 'التصنيف العالمي');
  String get myListsTitle   => _t('Listelerim', 'My Lists', '내 재생목록', 'マイリスト', 'Daftar Saya', 'Danh sách của tôi', 'รายการของฉัน', 'Мои списки', 'Mis listas', 'Minhas listas', 'Mes listes', 'قوائمي');
  String get noListsProfile => _t('Henüz listen yok — Alıştırma sekmesinde "Listeye Ekle" ile oluşturabilirsin.',
      'No lists yet — create one with "Add to Playlist" in Practice.',
      '아직 재생목록이 없어요 — 연습 탭의 "재생목록에 추가"로 만들 수 있어요.',
      'まだリストがありません — 練習タブの「リストに追加」で作成できます。',
      'Belum ada daftar — buat lewat "Tambah ke Daftar" di tab Latihan.',
      'Chưa có danh sách — tạo bằng "Thêm vào danh sách" ở tab Luyện tập.',
      'ยังไม่มีรายการ — สร้างได้ผ่าน "เพิ่มลงเพลย์ลิสต์" ในแท็บฝึกฝน', 'Списков пока нет — создайте один с помощью кнопки «Добавить в плейлист» в режиме практики.', 'Aún no hay listas. Crea una con "Añadir a lista de reproducción" en Práctica.', 'Nenhuma lista ainda — crie uma com "Adicionar à Playlist" em Prática.', 'Aucune liste pour l\'instant — créez-en une avec « Ajouter à la playlist » dans Entraînement.', 'لا توجد قوائم بعد — أنشئ واحدة باستخدام "إضافة إلى قائمة التشغيل" في التدريب.');
  String get newListHint    => _t('Yeni liste adı…', 'New list name…', '새 재생목록 이름…', '新しいリスト名…', 'Nama daftar baru…', 'Tên danh sách mới…', 'ชื่อรายการใหม่…', 'Название нового списка…', 'Nombre de la lista nueva…', 'Nome da nova lista…', 'Nom de la nouvelle liste…', 'اسم القائمة الجديد...');
  String get dailyStatsTitle => _t('Günlük İstatistikler', 'Daily Stats', '일일 통계', '日別統計', 'Statistik Harian', 'Thống kê hằng ngày', 'สถิติรายวัน', 'Ежедневная статистика', 'Estadísticas diarias', 'Estatísticas diárias', 'Statistiques quotidiennes', 'الإحصائيات اليومية');
  String get noStatsYet     => _t('Henüz istatistik yok — soru cevapladıkça burada birikecek.',
      'No stats yet — they build up as you answer questions.',
      '아직 통계가 없어요 — 문제를 풀면 여기에 쌓여요.',
      'まだ統計がありません — 問題を解くとここに蓄積されます。',
      'Belum ada statistik — akan terkumpul saat kamu menjawab soal.',
      'Chưa có thống kê — sẽ tích lũy khi bạn trả lời câu hỏi.',
      'ยังไม่มีสถิติ — จะสะสมเมื่อคุณตอบคำถาม', 'Статистики пока нет — она появится по мере ответов на вопросы.', 'Aún no hay estadísticas. Se generarán a medida que respondas preguntas.', 'Nenhuma estatística ainda — elas são geradas conforme você responde às perguntas.', 'Aucune statistique pour l\'instant — elles se cumulent au fur et à mesure que vous répondez aux questions.', 'لا توجد إحصائيات بعد — ستظهر مع إجابتك على الأسئلة.');
  String get colDate        => _t('Tarih', 'Date', '날짜', '日付', 'Tanggal', 'Ngày', 'วันที่', 'Дата', 'Fecha', 'Data', 'Date', 'التاريخ');
  String get colTotal       => _t('Toplam', 'Total', '전체', '合計', 'Total', 'Tổng', 'รวม', 'Всего', 'Total', 'Total', 'Total', 'الإجمالي');
  String get colSuccess     => _t('Doğru', 'Success', '정답', '正解', 'Benar', 'Đúng', 'ถูก', 'Успешно', 'Éxito', 'Sucesso', 'Succès', 'نجاح');
  String get colFail        => _t('Yanlış', 'Fail', '오답', '不正解', 'Salah', 'Sai', 'ผิด', 'Неудача', 'Error', 'Falha', 'Échec', 'فشل');
  String get myFriendsTitle => _t('Arkadaşlarım', 'My Friends', '내 친구', 'マイフレンド', 'Temanku', 'Bạn bè của tôi', 'เพื่อนของฉัน', 'Мои друзья', 'Mis amigos', 'Meus amigos', 'Mes amis', 'أصدقائي');
  String get noFriendsHint  => _t('Henüz arkadaşın yok — Puan Tabloları > Arkadaş Ara.',
      'No friends yet — Leaderboards > Find Friends.', '아직 친구가 없어요 — 랭킹 > 친구 찾기.', 'まだフレンドがいません — ランキング > フレンドを探す。', 'Belum ada teman — Papan Peringkat > Cari Teman.', 'Chưa có bạn — Bảng xếp hạng > Tìm bạn.', 'ยังไม่มีเพื่อน — กระดานอันดับ > หาเพื่อน', 'Друзей пока нет — Таблицы лидеров > Найти друзей.', 'Aún no tienes amigos. Marcadores > Buscar amigos.', 'Nenhum amigo ainda — Placares > Encontrar Amigos.', 'Aucun ami pour l\'instant — Classements > Trouver des amis.', 'لا يوجد أصدقاء بعد — لوحات الصدارة > العثور على أصدقاء.');
  String get deleteListTip  => _t('Listeyi sil', 'Delete list', '재생목록 삭제', 'リストを削除', 'Hapus daftar', 'Xóa danh sách', 'ลบรายการ', 'Удалить список', 'Eliminar lista', 'Excluir lista', 'Supprimer la liste', 'حذف القائمة');
  String get pointsLbl      => _t('puan', 'points', '점', '点', 'poin', 'điểm', 'คะแนน', 'баллов', 'puntos', 'pontos', 'points', 'نقاط');
  String get studentFallback => _t('Öğrenci', 'Student', '학습자', '学習者', 'Pelajar', 'Học viên', 'ผู้เรียน', 'Студент', 'Estudiante', 'Estudante', 'Étudiant', 'طالب');
  String get editTip        => _t('Düzenle', 'Edit', '편집', '編集', 'Ubah', 'Sửa', 'แก้ไข', 'Изменить', 'Editar', 'Editar', 'Modifier', 'تعديل');
  String get startCaps      => _t('BAŞLA', 'START', '시작하기', 'スタート', 'MULAI', 'BẮT ĐẦU', 'เริ่ม', 'НАЧАТЬ', 'EMPEZAR', 'INICIAR', 'DÉMARRER', 'ابدأ');
  String welcomeName(String? n) => n == null
      ? _t('Hoş geldin!', 'Welcome!', '환영해요!', 'ようこそ！', 'Selamat datang!', 'Chào mừng!', 'ยินดีต้อนรับ!', 'Добро пожаловать!', '¡Bienvenido!', 'Bem-vindo(a)!', 'Bienvenue !', 'أهلاً بك!')
      : _t('Hoş geldin, $n!', 'Welcome, $n!', '$n님, 환영해요!', '$nさん、ようこそ！', 'Selamat datang, $n!', 'Chào mừng, $n!', 'ยินดีต้อนรับ $n!', 'Добро пожаловать, $n!', '¡Bienvenido, $n!', 'Bem-vindo(a), $n!', 'Bienvenue, $n !', 'أهلاً بك، $n!');
  String get continueLearning => _t('Öğrenmeye kaldığın yerden devam et.',
      'Continue learning where you left off.', '마지막으로 학습한 곳부터 이어서 시작해요.', '前回の続きから学習を始めましょう。', 'Lanjutkan belajar dari tempat terakhirmu.', 'Tiếp tục học từ chỗ bạn dừng lại.', 'เรียนต่อจากจุดที่ค้างไว้', 'Продолжить обучение с того места, где вы остановились.', 'Continúa aprendiendo donde lo dejaste.', 'Continue aprendendo de onde parou.', 'Reprenez votre apprentissage là où vous vous êtes arrêté.', 'تابع التعلم من حيث توقفت.');

  // ── Phase runner ────────────────────────────────────────────────────────────
  String get phasePassed    => _t('Tebrikler! Faz tamamlandı', 'Well done! Phase complete', '축하해요! 단계 완료', 'お見事！フェーズ完了', 'Hebat! Fase selesai', 'Tuyệt vời! Hoàn thành giai đoạn', 'เยี่ยม! จบระยะแล้ว', 'Отлично! Этап завершен', '¡Bien hecho! Fase completada', 'Muito bem! Fase concluída', 'Bravo ! Phase terminée', 'أحسنت! اكتملت المرحلة');
  String get phaseFailed    => _t('Bu sefer olmadı', 'Not this time', '아쉽지만 다음 기회에!', '今回は残念！', 'Belum berhasil kali ini', 'Lần này chưa được', 'ครั้งนี้ยังไม่ผ่าน', 'Не в этот раз', 'Esta vez no', 'Desta vez não', 'Pas cette fois', 'ليس هذه المرة');
  String correctOf(int c, int t) => _t('$c / $t doğru', '$c / $t correct', '$t문제 중 $c개 정답', '$t問中$c問正解', '$c / $t benar', 'Đúng $c / $t', 'ถูก $c / $t', '$c / $t верно', '$c / $t correctas', '$c / $t corretas', '$c / $t correct', '$c / $t إجابة صحيحة');
  String passReq(int p)     => _t('Geçmek için en az %$p', 'Need at least $p%', '통과하려면 $p% 이상 필요해요', '合格には$p%以上必要です', 'Butuh minimal $p%', 'Cần ít nhất $p%', 'ต้องได้อย่างน้อย $p%', 'Нужно минимум $p%', 'Necesitas al menos $p%', 'Precisa de pelo menos $p%', 'Besoin d\'au moins $p%', 'تحتاج إلى $p% على الأقل');
  String get continueCaps   => _t('DEVAM ET', 'CONTINUE', '계속하기', '続ける', 'LANJUT', 'TIẾP TỤC', 'ต่อไป', 'ПРОДОЛЖИТЬ', 'CONTINUAR', 'CONTINUAR', 'CONTINUER', 'متابعة');
  String get goBackCaps     => _t('GERİ DÖN', 'GO BACK', '돌아가기', '戻る', 'KEMBALI', 'QUAY LẠI', 'ย้อนกลับ', 'НАЗАД', 'VOLVER', 'VOLTAR', 'RETOUR', 'عودة');
  String get phaseLbl       => _t('Faz', 'Phase', '단계', 'フェーズ', 'Fase', 'Giai đoạn', 'ระยะ', 'Этап', 'Fase', 'Fase', 'Phase', 'المرحلة');
  String get noVideosInSet  => _t('Bu bölümde henüz video yok.', 'No videos in this set yet.', '이 단계에는 아직 영상이 없어요.', 'このセットにはまだ動画がありません。', 'Belum ada video di set ini.', 'Chưa có video trong phần này.', 'ยังไม่มีวิดีโอในชุดนี้', 'В этом наборе пока нет видео.', 'Aún no hay videos en este conjunto.', 'Nenhum vídeo neste conjunto ainda.', 'Aucune vidéo dans cet ensemble pour l\'instant.', 'لا توجد فيديوهات في هذه المجموعة بعد.');
  String outOfHearts(int? mins) => mins == null
      ? _t('Canın kalmadı. Yenilenmesini bekle.', 'Out of hearts. Wait to refill.', '하트가 다 떨어졌어요. 충전될 때까지 기다려 주세요.', 'ハートがなくなりました。回復をお待ちください。', 'Nyawamu habis. Tunggu pengisian.', 'Hết tim. Hãy đợi nạp lại.', 'หัวใจหมดแล้ว รอการเติม', 'Сердечки закончились. Подождите восстановления.', 'Sin vidas. Espera a que se recarguen.', 'Sem corações. Aguarde para recarregar.', 'Plus de cœurs. Attendez qu\'ils se rechargent.', 'نفدت القلوب. انتظر حتى تُشحن.')
      : _t('Canın kalmadı. ~$mins dk sonra bir can dolacak.',
          'Out of hearts. A heart refills in ~$mins min.', '하트가 다 떨어졌어요. 약 $mins분 후에 하나 충전돼요.', 'ハートがなくなりました。約$mins分後に1つ回復します。', 'Nyawamu habis. Satu nyawa terisi dalam ~$mins mnt.', 'Hết tim. Một tim sẽ hồi sau ~$mins phút.', 'หัวใจหมดแล้ว อีก ~$mins นาทีจะเติมหนึ่งดวง', 'Сердечки закончились. Одно сердечко восстановится через ~$mins мин.', 'Te has quedado sin vidas. Una vida se recarga en ~$mins min.', 'Sem corações. Um coração é recarregado em ~$mins min.', 'Plus de cœurs. Un cœur se recharge en ~$mins min.', 'نفدت قلوبك. سيتم تعبئة قلب واحد خلال ~$mins دقيقة.');
  String get wordsInSet     => _t('Bu bölümün kelimeleri', 'Words in this set', '이 단계의 단어', 'このセットの単語', 'Kata dalam set ini', 'Từ trong phần này', 'คำในชุดนี้', 'Слова в этом наборе', 'Palabras en este conjunto', 'Palavras neste conjunto', 'Mots dans cet ensemble', 'الكلمات في هذه المجموعة');
  String get grammarLbl     => _t('Gramer', 'Grammar', '문법', '文法', 'Tata Bahasa', 'Ngữ pháp', 'ไวยากรณ์', 'Грамматика', 'Gramática', 'Gramática', 'Grammaire', 'القواعد');
  String get noWordsLbl     => _t('Kelime yok', 'No words', '단어 없음', '単語なし', 'Tidak ada kata', 'Không có từ', 'ไม่มีคำ', 'Нет слов', 'Sin palabras', 'Nenhuma palavra', 'Aucun mot', 'لا توجد كلمات');
  String get failedLbl      => _t('Yüklenemedi', 'Failed', '불러오지 못했어요', '読み込み失敗', 'Gagal dimuat', 'Tải thất bại', 'โหลดไม่สำเร็จ', 'Не удалось', 'Fallido', 'Falhou', 'Échoué', 'فشل');

  // ── Sign-in / onboarding ────────────────────────────────────────────────────
  String get signInTitle    => _t('Oturum Aç', 'Sign In', '로그인', 'ログイン', 'Masuk', 'Đăng nhập', 'เข้าสู่ระบบ', 'Войти', 'Iniciar sesión', 'Entrar', 'Se connecter', 'تسجيل الدخول');
  String get createAccount  => _t('Hesap Oluştur', 'Create Account', '계정 만들기', 'アカウント作成', 'Buat Akun', 'Tạo tài khoản', 'สร้างบัญชี', 'Создать аккаунт', 'Crear cuenta', 'Criar conta', 'Créer un compte', 'إنشاء حساب');
  String get kaydolCaps     => _t('KAYDOL', 'SIGN UP', '회원가입', '新規登録', 'DAFTAR', 'ĐĂNG KÝ', 'สมัครสมาชิก', 'ЗАРЕГИСТРИРОВАТЬСЯ', 'REGISTRARSE', 'CADASTRAR-SE', 'INSCRIPTION', 'إنشاء حساب');
  String get oturumAcCaps   => _t('OTURUM AÇ', 'SIGN IN', '로그인', 'ログイン', 'MASUK', 'ĐĂNG NHẬP', 'เข้าสู่ระบบ', 'ВОЙТИ', 'INICIAR SESIÓN', 'ENTRAR', 'CONNEXION', 'تسجيل الدخول');
  String get hesapOlusturCaps => _t('HESAP OLUŞTUR', 'CREATE ACCOUNT', '계정 만들기', 'アカウント作成', 'BUAT AKUN', 'TẠO TÀI KHOẢN', 'สร้างบัญชี', 'СОЗДАТЬ АККАУНТ', 'CREAR CUENTA', 'CRIAR CONTA', 'CRÉER UN COMPTE', 'إنشاء حساب');
  String get emailHint      => _t('E-posta', 'Email', '이메일', 'メールアドレス', 'Email', 'Email', 'อีเมล', 'Эл. почта', 'Correo electrónico', 'E-mail', 'E-mail', 'البريد الإلكتروني');
  String get passwordHint   => _t('Parola', 'Password', '비밀번호', 'パスワード', 'Kata sandi', 'Mật khẩu', 'รหัสผ่าน', 'Пароль', 'Contraseña', 'Senha', 'Mot de passe', 'كلمة المرور');
  String get passwordHintMin => _t('Parola (en az 6 karakter)', 'Password (min 6 characters)', '비밀번호 (6자 이상)', 'パスワード（6文字以上）', 'Kata sandi (min. 6 karakter)', 'Mật khẩu (ít nhất 6 ký tự)', 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)', 'Пароль (мин. 6 символов)', 'Contraseña (mín. 6 caracteres)', 'Senha (mín. 6 caracteres)', 'Mot de passe (6 caractères min.)', 'كلمة المرور (6 أحرف كحد أدنى)');
  String get orDivider      => _t('VEYA', 'OR', '또는', 'または', 'ATAU', 'HOẶC', 'หรือ', 'ИЛИ', 'O', 'OU', 'OU', 'أو');
  String get continueAsGuest => _t('Misafir olarak devam et', 'Continue as guest', '게스트로 둘러보기', 'ゲストとして続ける', 'Lanjut sebagai tamu', 'Tiếp tục với tư cách khách', 'ดำเนินการต่อแบบผู้เยี่ยมชม', 'Войти как гость', 'Continuar como invitado', 'Continuar como visitante', 'Continuer en tant qu\'invité', 'المتابعة كزائر');
  String get whatToCallYou  => _t('Sana nasıl\nhitap edelim?', 'What should we\ncall you?', '어떻게\n불러 드릴까요?', 'お名前を\n教えてください', 'Kami panggil kamu\nsiapa?', 'Chúng tôi nên gọi\nbạn là gì?', 'ให้เราเรียกคุณ\nว่าอะไรดี?', 'Как мы можем\nвас называть?', '¿Cómo deberíamos\nllamarte?', 'Como devemos\nchamar você?', 'Comment devons-nous\nvous appeler ?', 'ما الاسم الذي\nتود أن نناديك به؟');
  String get displayNameHint => _t('Görünen ad', 'Display name', '닉네임', '表示名', 'Nama tampilan', 'Tên hiển thị', 'ชื่อที่แสดง', 'Отображаемое имя', 'Nombre de usuario', 'Nome de exibição', 'Nom d\'affichage', 'اسم العرض');
  String get verifyTitle    => _t('E-postanı Doğrula', 'Verify your email', '이메일 인증', 'メール認証', 'Verifikasi Email', 'Xác minh email', 'ยืนยันอีเมล', 'Подтвердите ваш email', 'Verifica tu correo electrónico', 'Verifique seu e-mail', 'Vérifiez votre e-mail', 'تحقق من بريدك الإلكتروني');
  String verifyBody(String email) => _t(
      '$email adresine bir doğrulama bağlantısı gönderdik.\nE-postanı doğruladıktan sonra aşağıdaki butona bas.',
      'We sent a verification link to $email.\nTap the button below once verified.',
      '$email 주소로 인증 링크를 보냈어요.\n인증을 마친 뒤 아래 버튼을 눌러 주세요.',
      '$email に認証リンクを送信しました。\n認証が完了したら下のボタンを押してください。',
      'Kami mengirim tautan verifikasi ke $email.\nSetelah terverifikasi, tekan tombol di bawah.',
      'Chúng tôi đã gửi liên kết xác minh đến $email.\nSau khi xác minh, hãy nhấn nút bên dưới.',
      'เราได้ส่งลิงก์ยืนยันไปที่ $email\nเมื่อยืนยันแล้ว กดปุ่มด้านล่าง', 'Мы отправили ссылку для подтверждения на $email.\nНажмите кнопку ниже после подтверждения.', 'Hemos enviado un enlace de verificación a $email.\nPulsa el botón de abajo una vez verificado.', 'Enviamos um link de verificação para $email.\nToque no botão abaixo após verificar.', 'Nous avons envoyé un lien de vérification à $email.\nAppuyez sur le bouton ci-dessous une fois vérifié.', 'أرسلنا رابط تحقق إلى $email.\nاضغط على الزر أدناه بمجرد التحقق.');
  String get verifiedContinue => _t('Doğruladım, Devam Et', 'Verified, Continue', '인증 완료, 계속하기', '認証完了、次へ', 'Sudah Verifikasi, Lanjut', 'Đã xác minh, Tiếp tục', 'ยืนยันแล้ว ต่อไป', 'Подтверждено, продолжить', 'Verificado, continuar', 'Verificado, continuar', 'Vérifié, continuer', 'تم التحقق، متابعة');
  String get resendLbl      => _t('Tekrar gönder', 'Resend', '다시 보내기', '再送信', 'Kirim ulang', 'Gửi lại', 'ส่งอีกครั้ง', 'Отправить снова', 'Reenviar', 'Reenviar', 'Renvoyer', 'إعادة الإرسال');
  String get byContinuing   => _t('Devam ederek ', 'By continuing you accept the ', '계속하면 ', '続けることで', 'Dengan melanjutkan kamu menyetujui ', 'Khi tiếp tục, bạn đồng ý với ', 'เมื่อดำเนินการต่อ คุณยอมรับ', 'Продолжая, вы принимаете ', 'Al continuar, aceptas los ', 'Ao continuar, você aceita os ', 'En continuant, vous acceptez les ', 'بالمتابعة، أنت توافق على ');
  String get termsWord      => _t('Şartlar', 'Terms', '이용약관', '利用規約', 'Ketentuan', 'Điều khoản', 'ข้อกำหนด', 'Условия', 'Términos', 'Termos', 'Conditions', 'الشروط');
  String get andThe         => _t("'ı ve ", ' and ', '과 ', 'と', ' dan ', ' và ', ' และ ', ' и ', ' y ', ' e ', ' et ', ' و ');
  String get privacyWord    => _t('Gizlilik', 'Privacy', '개인정보처리방침', 'プライバシーポリシー', 'Privasi', 'Quyền riêng tư', 'นโยบายความเป็นส่วนตัว', 'Конфиденциальность', 'Privacidad', 'Privacidade', 'Confidentialité', 'الخصوصية');
  String get policyAccept   => _t(' politikasını kabul edersin.', ' policy.', '에 동의하게 됩니다.', 'に同意したことになります。', '.', '.', '', ' политика.', ' política.', ' política.', ' politique.', ' سياسة.');

  // ── HSK retest ──────────────────────────────────────────────────────────────
  String get hskTestTitle   => _t('HSK Testi', 'HSK Test', 'HSK 테스트', 'HSKテスト', 'Tes HSK', 'Kiểm tra HSK', 'ทดสอบ HSK', 'Экзамен HSK', 'Examen HSK', 'Teste HSK', 'Test HSK', 'اختبار HSK');
  String get resultTitle    => _t('Sonuç', 'Result', '결과', '結果', 'Hasil', 'Kết quả', 'ผลลัพธ์', 'Результат', 'Resultado', 'Resultado', 'Résultat', 'النتيجة');
  String get saveAndReturn  => _t('Kaydet ve Geri Dön', 'Save & Return', '저장하고 돌아가기', '保存して戻る', 'Simpan & Kembali', 'Lưu & Quay lại', 'บันทึกและกลับ', 'Сохранить и вернуться', 'Guardar y volver', 'Salvar e retornar', 'Enregistrer et quitter', 'حفظ والعودة');
  String get whatMeans      => _t('Bu ne anlama geliyor?', 'What does this mean?', '무슨 뜻일까요?', 'これはどういう意味？', 'Apa artinya ini?', 'Điều này nghĩa là gì?', 'นี่หมายความว่าอย่างไร?', 'Что это значит?', '¿Qué significa esto?', 'O que isso significa?', 'Que signifie ceci ?', 'ماذا يعني هذا؟');
  String questionOf(int i, int t) => _t('Soru $i / $t', 'Question $i / $t', '문제 $i / $t', '問題 $i / $t', 'Soal $i / $t', 'Câu $i / $t', 'ข้อ $i / $t', 'Вопрос $i / $t', 'Pregunta $i / $t', 'Pergunta $i / $t', 'Question $i / $t', 'السؤال $i / $t');
  String yourLevelInfo(int l) => _t('Mevcut seviyen: HSK $l', 'Your level: HSK $l', '내 레벨: HSK $l', '現在のレベル：HSK $l', 'Levelmu: HSK $l', 'Cấp độ của bạn: HSK $l', 'ระดับของคุณ: HSK $l', 'Ваш уровень: HSK $l', 'Tu nivel: HSK $l', 'Seu nível: HSK $l', 'Votre niveau : HSK $l', 'مستواك: HSK $l');

  // ── Onboarding (welcome + placement result) ─────────────────────────────────
  String get onbTagline     => _t(
      'Gerçek video klipler, yapay zekâ açıklamaları ve\neğlenceli oyunlarla Mandarin öğren.',
      'Learn Mandarin through real video clips,\nAI explanations, and fun games.',
      '실제 영상 클립과 AI 설명, 재미있는 게임으로\n중국어를 배워 보세요.',
      '本物の動画クリップとAI解説、\n楽しいゲームで中国語を学びましょう。',
      'Belajar Mandarin lewat klip video nyata,\npenjelasan AI, dan permainan seru.',
      'Học tiếng Trung qua video thật,\ngiải thích bằng AI và trò chơi vui nhộn.',
      'เรียนภาษาจีนผ่านคลิปวิดีโอจริง\nคำอธิบายด้วย AI และเกมสนุก ๆ', 'Учите китайский с помощью реальных видеороликов, ИИ-объяснений и увлекательных игр.', 'Aprende mandarín con videoclips reales,\nexplicaciones con IA y juegos divertidos.', 'Aprenda mandarim com clipes de vídeo reais,\nexplicações de IA e jogos divertidos.', 'Apprenez le mandarin grâce à de vrais extraits vidéo,\ndes explications par IA et des jeux amusants.', 'تعلّم الماندرين من خلال مقاطع فيديو حقيقية، وشروحات الذكاء الاصطناعي، وألعاب ممتعة.');
  String get getStarted     => _t('Başlayalım', 'Get Started', '시작하기', 'はじめる', 'Mulai', 'Bắt đầu', 'เริ่มต้น', 'Начать', 'Empezar', 'Começar', 'Commencer', 'ابدأ الآن');
  String get yourLevelLbl   => _t('Seviyen', 'Your Level', '내 레벨', 'あなたのレベル', 'Levelmu', 'Cấp độ của bạn', 'ระดับของคุณ', 'Ваш уровень', 'Tu nivel', 'Seu nível', 'Votre niveau', 'مستواك');
  String get startLearning  => _t('Öğrenmeye Başla', 'Start Learning', '학습 시작하기', '学習を始める', 'Mulai Belajar', 'Bắt đầu học', 'เริ่มเรียน', 'Начать обучение', 'Empezar a aprender', 'Começar a aprender', 'Commencer à apprendre', 'ابدأ التعلم');
  String hskLevelDesc(int l) => switch (l) {
        1 => _t(
            'Daha yeni başlıyorsun. Temel kelime ve kalıplarla sağlam bir temel kuracağız.',
            'You\'re just starting out. We\'ll build your foundation with essential words and phrases.',
            '이제 막 시작하는 단계예요. 필수 단어와 표현으로 기초를 탄탄히 다져 드릴게요.',
            '始めたばかりですね。基本の単語と表現でしっかりとした土台を築きましょう。',
            'Kamu baru memulai. Kita akan bangun fondasi dengan kata dan frasa penting.',
            'Bạn vừa mới bắt đầu. Chúng ta sẽ xây nền tảng vững với từ và mẫu câu cơ bản.',
            'คุณเพิ่งเริ่มต้น เราจะสร้างพื้นฐานให้แน่นด้วยคำและวลีที่จำเป็น', 'Вы только начинаете. Мы заложим фундамент с помощью базовых слов и фраз.', 'Estás empezando. Construiremos tu base con palabras y frases esenciales.', 'Você está apenas começando. Vamos construir sua base com palavras e frases essenciais.', 'Vous débutez tout juste. Nous allons construire vos bases avec des mots et des expressions essentiels.', 'أنت في البداية فقط. سنبني أساسك بكلمات وعبارات أساسية.'),
        2 => _t(
            'Temelleri biliyorsun. Şimdi kelime dağarcığını ve cümle kalıplarını genişletme zamanı.',
            'You know the basics. Time to expand your vocabulary and sentence patterns.',
            '기초는 알고 있어요. 이제 어휘와 문형을 넓혀 볼 차례예요.',
            '基礎はできています。語彙と文型を広げていきましょう。',
            'Kamu paham dasarnya. Saatnya memperluas kosakata dan pola kalimat.',
            'Bạn đã nắm cơ bản. Đã đến lúc mở rộng từ vựng và mẫu câu.',
            'คุณรู้พื้นฐานแล้ว ถึงเวลาขยายคำศัพท์และรูปประโยค', 'Вы знаете основы. Пора расширить словарный запас и освоить новые конструкции предложений.', 'Conoces lo básico. Es hora de ampliar tu vocabulario y tus estructuras gramaticales.', 'Você conhece o básico. É hora de expandir seu vocabulário e estruturas de frases.', 'Vous connaissez les bases. Il est temps d\'élargir votre vocabulaire et vos structures de phrases.', 'أنت تعرف الأساسيات. حان الوقت لتوسيع مفرداتك وأنماط الجمل لديك.'),
        3 => _t(
            'Orta seviye — günlük konuşmaları rahatça yürütebiliyorsun. Biraz daha ileri gidelim.',
            'Intermediate level — you can handle everyday conversations. Let\'s push further.',
            '중급 수준 — 일상 대화는 무리 없이 할 수 있어요. 한 단계 더 나아가 봐요.',
            '中級レベル — 日常会話はこなせます。もう一歩先へ進みましょう。',
            'Tingkat menengah — kamu bisa percakapan sehari-hari. Ayo melangkah lebih jauh.',
            'Trình độ trung cấp — bạn giao tiếp hằng ngày tốt. Hãy tiến xa hơn.',
            'ระดับกลาง — คุณสนทนาในชีวิตประจำวันได้ มาก้าวต่อไปกัน', 'Средний уровень — вы можете поддерживать повседневные беседы. Двигаемся дальше.', 'Nivel intermedio: puedes manejar conversaciones cotidianas. Sigamos avanzando.', 'Nível intermediário — você consegue lidar com conversas do dia a dia. Vamos avançar mais.', 'Niveau intermédiaire : vous pouvez gérer les conversations quotidiennes. Allons plus loin.', 'مستوى متوسط — يمكنك التعامل مع المحادثات اليومية. لنواصل التقدم.'),
        4 => _t(
            'Orta-üstü — karmaşık konularda rahatsın. Akıcılığını inceltelim.',
            'Upper-intermediate — you\'re comfortable with complex topics. Let\'s refine your fluency.',
            '중상급 — 복잡한 주제도 편하게 다뤄요. 유창함을 더 다듬어 봐요.',
            '中上級 — 複雑な話題も問題ありません。流暢さを磨きましょう。',
            'Menengah atas — kamu nyaman dengan topik rumit. Ayo asah kefasihanmu.',
            'Trung cao cấp — bạn thoải mái với chủ đề phức tạp. Hãy mài giũa sự trôi chảy.',
            'ระดับกลางตอนปลาย — คุณคล่องกับหัวข้อซับซ้อน มาขัดเกลาความคล่องกัน', 'Выше среднего — вы уверенно обсуждаете сложные темы. Давайте отточим вашу беглость речи.', 'Intermedio-alto: te sientes cómodo con temas complejos. Vamos a perfeccionar tu fluidez.', 'Intermediário avançado — você se sente confortável com tópicos complexos. Vamos refinar sua fluência.', 'Intermédiaire avancé — vous êtes à l\'aise avec des sujets complexes. Perfectionnons votre aisance.', 'فوق المتوسط — أنت متمكن من المواضيع المعقدة. لنصقل طلاقتك.'),
        5 => _t(
            'İleri — soyut fikirleri tartışabiliyorsun. Nüans ve kesinliğini zorlayacağız.',
            'Advanced — you can discuss abstract ideas. We\'ll challenge your nuance and precision.',
            '고급 — 추상적인 주제도 토론할 수 있어요. 뉘앙스와 정확성을 갈고닦아 봐요.',
            '上級 — 抽象的な話題も議論できます。ニュアンスと正確さを鍛えましょう。',
            'Lanjutan — kamu bisa berdiskusi soal ide abstrak. Kita asah nuansa dan ketepatanmu.',
            'Cao cấp — bạn có thể bàn về ý tưởng trừu tượng. Ta sẽ rèn sắc thái và độ chính xác.',
            'ขั้นสูง — คุณถกเรื่องนามธรรมได้ เราจะท้าทายความละเอียดและความแม่นยำ', 'Продвинутый — вы можете обсуждать абстрактные темы. Мы проверим ваше владение нюансами и точность.', 'Avanzado: puedes discutir ideas abstractas. Pondremos a prueba tus matices y precisión.', 'Avançado — você pode discutir ideias abstratas. Desafiaremos sua nuance e precisão.', 'Avancé — vous pouvez discuter d\'idées abstraites. Nous mettrons au défi votre nuance et votre précision.', 'متقدم — يمكنك مناقشة الأفكار المجردة. سنتحدى دقة تعبيرك وفهمك للفروق الدقيقة.'),
        6 => _t(
            'Ustalık — ana dile yakın bir yeterliliktesin. Seni yalnızca en seçkin meydan okumalar bekliyor.',
            'Mastery level — you\'re at near-native proficiency. Only the finest challenges await.',
            '마스터 수준 — 원어민에 가까운 실력이에요. 이제 최고 난이도의 도전만 남았어요.',
            'マスターレベル — ネイティブに近い実力です。最高難度の挑戦が待っています。',
            'Tingkat mahir — kemampuanmu mendekati penutur asli. Hanya tantangan terbaik yang menanti.',
            'Trình độ thành thạo — bạn gần như người bản xứ. Chỉ còn những thử thách đỉnh cao.',
            'ระดับเชี่ยวชาญ — คุณเก่งเกือบเท่าเจ้าของภาษา เหลือเพียงความท้าทายระดับสูงสุด', 'Уровень мастерства — вы владеете языком почти как носитель. Вас ждут только самые сложные испытания.', 'Nivel de maestría: tienes una competencia casi nativa. Solo te esperan los mejores desafíos.', 'Nível de domínio — você atingiu uma proficiência próxima à de um nativo. Apenas os melhores desafios o aguardam.', 'Niveau de maîtrise — vous avez une compétence quasi native. Seuls les meilleurs défis vous attendent.', 'مستوى الإتقان — أنت تتمتع بكفاءة تقارب كفاءة المتحدث الأصلي. بانتظارك أرقى التحديات فقط.'),
        _ => '',
      };

  // ── Misc / legacy keys (kept for existing call sites) ───────────────────────
  String get filterAll      => _t('Tümü', 'All', '전체', 'すべて', 'Semua', 'Tất cả', 'ทั้งหมด', 'Все', 'Todo', 'Tudo', 'Tout', 'الكل');
  String get filterActive   => _t('Filtre aktif', 'Filter active', '필터 적용됨', 'フィルター適用中', 'Filter aktif', 'Bộ lọc đang bật', 'ตัวกรองเปิดอยู่', 'Фильтр активен', 'Filtro activo', 'Filtro ativo', 'Filtre actif', 'التصفية مفعلة');
  String get filterLabel    => _t('Filtrele', 'Filter', '필터', 'フィルター', 'Filter', 'Lọc', 'กรอง', 'Фильтр', 'Filtrar', 'Filtrar', 'Filtrer', 'تصفية');
  String get lifeSection    => _t('Hayat', 'Life', '생활', '生活', 'Kehidupan', 'Đời sống', 'ชีวิต', 'Жизнь', 'Vida', 'Vida', 'Vie', 'الحياة');
  String get dailyLife      => _t('Günlük Hayat', 'Daily Life', '일상생활', '日常生活', 'Kehidupan Sehari-hari', 'Đời sống hằng ngày', 'ชีวิตประจำวัน', 'Повседневная жизнь', 'Vida cotidiana', 'Vida cotidiana', 'Vie quotidienne', 'الحياة اليومية');
  String get businessLife   => _t('İş', 'Business', '비즈니스', 'ビジネス', 'Bisnis', 'Kinh doanh', 'ธุรกิจ', 'Бизнес', 'Negocios', 'Negócios', 'Affaires', 'أعمال');
  String get childrenLife   => _t('Çocuk', 'Children', '어린이', '子ども', 'Anak-anak', 'Trẻ em', 'เด็ก', 'Дети', 'Niños', 'Crianças', 'Enfants', 'أطفال');
  String get levelSection   => _t('Adım', 'Level', '단계', 'レベル', 'Level', 'Cấp độ', 'ระดับ', 'Уровень', 'Nivel', 'Nível', 'Niveau', 'المستوى');
  String get grammarSection => _t('Gramer Kuralları', 'Grammar Patterns', '문법 패턴', '文法パターン', 'Pola Tata Bahasa', 'Mẫu ngữ pháp', 'รูปแบบไวยากรณ์', 'Грамматические конструкции', 'Patrones gramaticales', 'Padrões Gramaticais', 'Structures grammaticales', 'أنماط القواعد');
  String get retryBtn       => _t('Tekrar Dene', 'Retry', '다시 시도', '再試行', 'Coba Lagi', 'Thử lại', 'ลองอีกครั้ง', 'Повторить попытку', 'Reintentar', 'Tentar novamente', 'Réessayer', 'إعادة المحاولة');
  String get noVideosLevel  => _t('Seviyenizde video bulunamadı.', 'No videos at your level.', '내 레벨에 맞는 영상이 없어요.', 'あなたのレベルの動画がありません。', 'Tidak ada video di levelmu.', 'Không có video ở cấp độ của bạn.', 'ไม่มีวิดีโอในระดับของคุณ', 'Нет видео для вашего уровня.', 'No hay videos para tu nivel.', 'Nenhum vídeo no seu nível.', 'Aucune vidéo à votre niveau.', 'لا توجد فيديوهات في مستواك.');
  String get noVideosFilter => _t('Seçili filtrelere uygun video yok.', 'No videos match filters.', '선택한 필터에 맞는 영상이 없어요.', '選択したフィルターに合う動画がありません。', 'Tidak ada video yang cocok dengan filter terpilih.', 'Không có video khớp bộ lọc đã chọn.', 'ไม่มีวิดีโอที่ตรงกับตัวกรองที่เลือก', 'Нет видео, соответствующих фильтрам.', 'No hay videos que coincidan con los filtros.', 'Nenhum vídeo corresponde aos filtros.', 'Aucune vidéo ne correspond aux filtres.', 'لا توجد فيديوهات تطابق الفلاتر.');
  String get statsWatched   => _t('izlendi', 'watched', '시청', '視聴', 'ditonton', 'đã xem', 'ดูแล้ว', 'просмотрено', 'visto', 'assistidos', 'vues', 'تمت مشاهدتها');
  String get statsPoints    => _t('puan', 'points', '점', '点', 'poin', 'điểm', 'คะแนน', 'баллов', 'puntos', 'pontos', 'points', 'نقاط');
  String get statsDays      => _t('gün', 'days', '일', '日', 'hari', 'ngày', 'วัน', 'дней', 'días', 'dias', 'jours', 'أيام');
  String get searchHint     => _t('Ara…', 'Search…', '검색…', '検索…', 'Cari…', 'Tìm…', 'ค้นหา…', 'Поиск…', 'Buscar…', 'Buscar…', 'Rechercher…', 'بحث…');
  String get gamesTitle     => _t('Oyunlar', 'Games', '게임', 'ゲーム', 'Permainan', 'Trò chơi', 'เกม', 'Игры', 'Juegos', 'Jogos', 'Jeux', 'الألعاب');
  String get gamesSubtitle  => _t('Kendini sına ve arkadaşlarınla yarış',
      'Test yourself and compete with friends', '실력을 시험하고 친구와 겨뤄 보세요', '実力を試して友だちと競いましょう', 'Uji dirimu dan bersaing dengan teman', 'Thử sức và thi đua với bạn bè', 'ทดสอบตัวเองและแข่งกับเพื่อน', 'Проверьте себя и соревнуйтесь с друзьями', 'Ponte a prueba y compite con amigos', 'Teste-se e compita com amigos', 'Testez-vous et affrontez vos amis', 'اختبر نفسك ونافس أصدقاءك');
  String get duelSubtitle   => _t('Gerçek zamanlı 1v1 soru yarışması — 6 kategori',
      'Real-time 1v1 quiz — 6 categories', '실시간 1:1 퀴즈 대결 — 6개 카테고리', 'リアルタイム1対1クイズ — 6カテゴリ', 'Kuis 1 lawan 1 waktu nyata — 6 kategori', 'Đố vui 1 đối 1 thời gian thực — 6 chủ đề', 'ควิซ 1 ต่อ 1 แบบเรียลไทม์ — 6 หมวด', 'Викторина 1 на 1 в реальном времени — 6 категорий', 'Quiz 1v1 en tiempo real — 6 categorías', 'Quiz 1v1 em tempo real — 6 categorias', 'Quiz 1v1 en temps réel — 6 catégories', 'اختبار فوري 1 ضد 1 — 6 فئات');
  String get duelDetail     => _t('10 tur • 10s süre • 3 can', '10 rounds • 10s each • 3 lives', '10라운드 • 10초 제한 • 목숨 3개', '10ラウンド • 各10秒 • ライフ3', '10 ronde • 10 dtk/ronde • 3 nyawa', '10 vòng • 10 giây mỗi vòng • 3 mạng', '10 รอบ • รอบละ 10 วิ • 3 ชีวิต', '10 раундов • по 10с • 3 жизни', '10 rondas • 10s cada una • 3 vidas', '10 rodadas • 10s cada • 3 vidas', '10 manches • 10s chacune • 3 vies', '10 جولات • 10 ثوانٍ لكل منها • 3 أرواح');
  String get hanziBuildSubtitle => _t('Kökenlerden karakter yeniden oluştur',
      'Reconstruct characters from radicals', '부수로 한자를 조립해 보세요', '部首から漢字を組み立てよう', 'Susun karakter dari radikalnya', 'Ghép chữ Hán từ bộ thủ', 'ประกอบตัวอักษรจากส่วนประกอบ', 'Соберите иероглифы из ключей', 'Reconstruye caracteres a partir de radicales', 'Reconstrua caracteres a partir de radicais', 'Reconstituer les caractères à partir des radicaux', 'إعادة بناء الحروف من الجذور');
  String get hanziBuildDetail => _t('10 kelime • 20s süre • ipuçları mevcut',
      '10 words • 20s each • hints available', '10단어 • 20초 제한 • 힌트 제공', '10単語 • 各20秒 • ヒントあり', '10 kata • 20 dtk/kata • ada petunjuk', '10 từ • 20 giây mỗi từ • có gợi ý', '10 คำ • คำละ 20 วิ • มีคำใบ้', '10 слов • по 20с • есть подсказки', '10 palabras • 20s cada una • pistas disponibles', '10 palavras • 20s cada • dicas disponíveis', '10 mots • 20s chacun • indices disponibles', '10 كلمات • 20 ثانية لكل منها • تلميحات متاحة');
  String get userFallback   => _t('Kullanıcı', 'User', '사용자', 'ユーザー', 'Pengguna', 'Người dùng', 'ผู้ใช้', 'Пользователь', 'Usuario', 'Usuário', 'Utilisateur', 'مستخدم');
  String get scoreLabel     => _t('Skor', 'Score', '점수', 'スコア', 'Skor', 'Điểm', 'คะแนน', 'Счёт', 'Puntuación', 'Pontuação', 'Score', 'النتيجة');
  String get hskLevelTest   => _t('HSK Seviye Testi', 'HSK Level Test', 'HSK 레벨 테스트', 'HSKレベルテスト', 'Tes Level HSK', 'Bài kiểm tra cấp độ HSK', 'แบบทดสอบระดับ HSK', 'Тест на уровень HSK', 'Prueba de nivel HSK', 'Teste de Nível HSK', 'Test de niveau HSK', 'اختبار مستوى HSK');
  String get settingsLabel  => _t('Ayarlar', 'Settings', '설정', '設定', 'Pengaturan', 'Cài đặt', 'การตั้งค่า', 'Настройки', 'Ajustes', 'Configurações', 'Paramètres', 'الإعدادات');
  String get adminPanel     => _t('Admin Paneli', 'Admin Panel', '관리자 패널', '管理パネル', 'Panel Admin', 'Bảng quản trị', 'แผงผู้ดูแล', 'Панель администратора', 'Panel de administración', 'Painel administrativo', 'Panneau d\'administration', 'لوحة التحكم');
  String get darkTheme      => _t('Koyu Tema', 'Dark Theme', '다크 테마', 'ダークテーマ', 'Tema Gelap', 'Giao diện tối', 'ธีมมืด', 'Темная тема', 'Tema oscuro', 'Tema escuro', 'Thème sombre', 'السمة الداكنة');
  String get signOut        => _t('Çıkış Yap', 'Sign Out', '로그아웃', 'ログアウト', 'Keluar', 'Đăng xuất', 'ออกจากระบบ', 'Выйти', 'Cerrar sesión', 'Sair', 'Se déconnecter', 'تسجيل الخروج');
  String get loginBtn       => _t('Giriş Yap', 'Log In', '로그인', 'ログイン', 'Masuk', 'Đăng nhập', 'เข้าสู่ระบบ', 'Войти', 'Iniciar sesión', 'Entrar', 'Connexion', 'تسجيل الدخول');
  String get signUpBtn      => _t('Kayıt Ol', 'Sign Up', '회원가입', '新規登録', 'Daftar', 'Đăng ký', 'สมัครสมาชิก', 'Регистрация', 'Registrarse', 'Cadastrar-se', 'S\'inscrire', 'إنشاء حساب');
  String get emailLabel     => _t('E-posta', 'Email', '이메일', 'メールアドレス', 'Email', 'Email', 'อีเมล', 'Эл. почта', 'Correo electrónico', 'E-mail', 'E-mail', 'البريد الإلكتروني');
  String get passwordLabel  => _t('Şifre', 'Password', '비밀번호', 'パスワード', 'Kata sandi', 'Mật khẩu', 'รหัสผ่าน', 'Пароль', 'Contraseña', 'Senha', 'Mot de passe', 'كلمة المرور');
  String get googleSignIn   => _t('Google ile Giriş', 'Sign in with Google', 'Google로 로그인', 'Googleでログイン', 'Masuk dengan Google', 'Đăng nhập bằng Google', 'เข้าสู่ระบบด้วย Google', 'Войти через Google', 'Iniciar sesión con Google', 'Entrar com Google', 'Se connecter avec Google', 'تسجيل الدخول باستخدام Google');
  String get authSubmitLogin => _t('Giriş Yap', 'Log In', '로그인', 'ログイン', 'Masuk', 'Đăng nhập', 'เข้าสู่ระบบ', 'Войти', 'Iniciar sesión', 'Entrar', 'Connexion', 'تسجيل الدخول');
  String get authSubmitRegister => _t('Hesap Oluştur', 'Create Account', '계정 만들기', 'アカウント作成', 'Buat Akun', 'Tạo tài khoản', 'สร้างบัญชี', 'Создать аккаунт', 'Crear cuenta', 'Criar conta', 'Créer un compte', 'إنشاء حساب');
  String get verifyEmailTitle => _t('E-postanı doğrula', 'Verify your email', '이메일을 인증해 주세요', 'メールを認証してください', 'Verifikasi emailmu', 'Xác minh email của bạn', 'ยืนยันอีเมลของคุณ', 'Подтвердите ваш email', 'Verifica tu correo electrónico', 'Verifique seu e-mail', 'Vérifiez votre e-mail', 'تحقق من بريدك الإلكتروني');
  String get verifyEmailBody => _t('Doğrulama bağlantısı gönderildi. Gelen kutunuzu kontrol edin.',
      'A verification link has been sent. Check your inbox.', '인증 링크를 보냈어요. 받은편지함을 확인해 주세요.', '認証リンクを送信しました。受信トレイをご確認ください。', 'Tautan verifikasi telah dikirim. Periksa kotak masukmu.', 'Đã gửi liên kết xác minh. Hãy kiểm tra hộp thư.', 'ส่งลิงก์ยืนยันแล้ว กรุณาตรวจสอบกล่องจดหมาย', 'Ссылка для подтверждения отправлена. Проверьте почту.', 'Se ha enviado un enlace de verificación. Revisa tu bandeja de entrada.', 'Um link de verificação foi enviado. Verifique sua caixa de entrada.', 'Un lien de vérification a été envoyé. Consultez votre boîte de réception.', 'تم إرسال رابط التحقق. يرجى التحقق من بريدك الوارد.');
  String get profilePhoto   => _t('Profil Fotoğrafı', 'Profile Photo', '프로필 사진', 'プロフィール写真', 'Foto Profil', 'Ảnh hồ sơ', 'รูปโปรไฟล์', 'Фото профиля', 'Foto de perfil', 'Foto de perfil', 'Photo de profil', 'صورة الملف الشخصي');
  String get changePhoto    => _t('Fotoğrafı Değiştir', 'Change Photo', '사진 변경', '写真を変更', 'Ganti Foto', 'Đổi ảnh', 'เปลี่ยนรูป', 'Изменить фото', 'Cambiar foto', 'Alterar foto', 'Changer de photo', 'تغيير الصورة');
  String get photoSelected  => _t('Fotoğraf seçildi ✓', 'Photo selected ✓', '사진 선택됨 ✓', '写真を選択 ✓', 'Foto dipilih ✓', 'Đã chọn ảnh ✓', 'เลือกรูปแล้ว ✓', 'Фото выбрано ✓', 'Foto seleccionada ✓', 'Foto selecionada ✓', 'Photo sélectionnée ✓', 'تم اختيار الصورة ✓');
  String get profileSection => _t('Profil', 'Profile', '프로필', 'プロフィール', 'Profil', 'Hồ sơ', 'โปรไฟล์', 'Профиль', 'Perfil', 'Perfil', 'Profil', 'الملف الشخصي');
  String get firstName      => _t('Ad', 'First Name', '이름', '名', 'Nama Depan', 'Tên', 'ชื่อ', 'Имя', 'Nombre', 'Nome', 'Prénom', 'الاسم الأول');
  String get usernameLabel  => _t('Kullanıcı adı', 'Username', '사용자 이름', 'ユーザー名', 'Nama pengguna', 'Tên người dùng', 'ชื่อผู้ใช้', 'Имя пользователя', 'Nombre de usuario', 'Nome de usuário', 'Nom d\'utilisateur', 'اسم المستخدم');
  String get lastName       => _t('Soyad', 'Last Name', '성', '姓', 'Nama Belakang', 'Họ', 'นามสกุล', 'Фамилия', 'Apellido', 'Sobrenome', 'Nom de famille', 'اسم العائلة');
  String get selectHint     => _t('Seçiniz', 'Select', '선택', '選択', 'Pilih', 'Chọn', 'เลือก', 'Выбрать', 'Seleccionar', 'Selecionar', 'Sélectionner', 'اختيار');
  String get dateOfBirth    => _t('Doğum Tarihi', 'Date of Birth', '생년월일', '生年月日', 'Tanggal Lahir', 'Ngày sinh', 'วันเกิด', 'Дата рождения', 'Fecha de nacimiento', 'Data de nascimento', 'Date de naissance', 'تاريخ الميلاد');
  String get genderLabel    => _t('Cinsiyet', 'Gender', '성별', '性別', 'Jenis Kelamin', 'Giới tính', 'เพศ', 'Пол', 'Género', 'Gênero', 'Genre', 'الجنس');
  String get male           => _t('Erkek', 'Male', '남성', '男性', 'Laki-laki', 'Nam', 'ชาย', 'Мужской', 'Masculino', 'Masculino', 'Homme', 'ذكر');
  String get female         => _t('Kadın', 'Female', '여성', '女性', 'Perempuan', 'Nữ', 'หญิง', 'Женский', 'Femenino', 'Feminino', 'Femme', 'أنثى');
  String get otherGender    => _t('Diğer', 'Other', '기타', 'その他', 'Lainnya', 'Khác', 'อื่น ๆ', 'Другое', 'Otro', 'Outro', 'Autre', 'أخرى');
  String get languageLabel  => _t('Dil', 'Language', '언어', '言語', 'Bahasa', 'Ngôn ngữ', 'ภาษา', 'Язык', 'Idioma', 'Idioma', 'Langue', 'اللغة');
  String get saveChanges    => _t('Değişiklikleri Kaydet', 'Save Changes', '변경사항 저장', '変更を保存', 'Simpan Perubahan', 'Lưu thay đổi', 'บันทึกการเปลี่ยนแปลง', 'Сохранить изменения', 'Guardar cambios', 'Salvar alterações', 'Enregistrer les modifications', 'حفظ التغييرات');
  String get profileSaved   => _t('Profil kaydedildi.', 'Profile saved.', '프로필이 저장되었어요.', 'プロフィールを保存しました。', 'Profil disimpan.', 'Đã lưu hồ sơ.', 'บันทึกโปรไฟล์แล้ว', 'Профиль сохранен.', 'Perfil guardado.', 'Perfil salvo.', 'Profil enregistré.', 'تم حفظ الملف الشخصي.');
  String get saveError      => _t('Kayıt hatası: ', 'Save error: ', '저장 오류: ', '保存エラー：', 'Galat penyimpanan: ', 'Lỗi khi lưu: ', 'บันทึกผิดพลาด: ', 'Ошибка сохранения: ', 'Error al guardar: ', 'Erro ao salvar: ', 'Erreur d\'enregistrement : ', 'خطأ في الحفظ: ');
  String get accountSection => _t('Hesap', 'Account', '계정', 'アカウント', 'Akun', 'Tài khoản', 'บัญชี', 'Аккаунт', 'Cuenta', 'Conta', 'Compte', 'الحساب');
  String get themeSection   => _t('Tema', 'Theme', '테마', 'テーマ', 'Tema', 'Giao diện', 'ธีม', 'Тема', 'Tema', 'Tema', 'Thème', 'السمة');
  String get darkThemeToggle => _t('Karanlık Tema', 'Dark Theme', '다크 테마', 'ダークテーマ', 'Tema Gelap', 'Giao diện tối', 'ธีมมืด', 'Темная тема', 'Tema oscuro', 'Tema escuro', 'Thème sombre', 'السمة الداكنة');
  String get lightThemeToggle => _t('Açık Tema', 'Light Theme', '라이트 테마', 'ライトテーマ', 'Tema Terang', 'Giao diện sáng', 'ธีมสว่าง', 'Светлая тема', 'Tema claro', 'Tema claro', 'Thème clair', 'الوضع الفاتح');
  String get deleteAccount  => _t('Hesabı Sil', 'Delete Account', '계정 삭제', 'アカウントを削除', 'Hapus Akun', 'Xóa tài khoản', 'ลบบัญชี', 'Удалить аккаунт', 'Eliminar cuenta', 'Excluir conta', 'Supprimer le compte', 'حذف الحساب');
  String get passwordSection => _t('Şifre', 'Password', '비밀번호', 'パスワード', 'Kata Sandi', 'Mật khẩu', 'รหัสผ่าน', 'Пароль', 'Contraseña', 'Senha', 'Mot de passe', 'كلمة المرور');
  String get currentPassword => _t('Mevcut Şifre', 'Current Password', '현재 비밀번호', '現在のパスワード', 'Kata Sandi Saat Ini', 'Mật khẩu hiện tại', 'รหัสผ่านปัจจุบัน', 'Текущий пароль', 'Contraseña actual', 'Senha atual', 'Mot de passe actuel', 'كلمة المرور الحالية');
  String get newPassword    => _t('Yeni Şifre', 'New Password', '새 비밀번호', '新しいパスワード', 'Kata Sandi Baru', 'Mật khẩu mới', 'รหัสผ่านใหม่', 'Новый пароль', 'Nueva contraseña', 'Nova senha', 'Nouveau mot de passe', 'كلمة مرور جديدة');
  String get confirmPassword => _t('Yeni Şifre Tekrar', 'Confirm Password', '새 비밀번호 확인', '新しいパスワード（確認）', 'Konfirmasi Kata Sandi', 'Xác nhận mật khẩu', 'ยืนยันรหัสผ่าน', 'Подтвердите пароль', 'Confirmar contraseña', 'Confirmar senha', 'Confirmer le mot de passe', 'تأكيد كلمة المرور');
  String get updatePassword => _t('Şifreyi Güncelle', 'Update Password', '비밀번호 변경', 'パスワードを変更', 'Perbarui Kata Sandi', 'Cập nhật mật khẩu', 'อัปเดตรหัสผ่าน', 'Обновить пароль', 'Actualizar contraseña', 'Atualizar senha', 'Mettre à jour le mot de passe', 'تحديث كلمة المرور');
  String get passwordUpdated => _t('Şifre güncellendi.', 'Password updated.', '비밀번호가 변경되었어요.', 'パスワードを変更しました。', 'Kata sandi diperbarui.', 'Đã cập nhật mật khẩu.', 'อัปเดตรหัสผ่านแล้ว', 'Пароль обновлен.', 'Contraseña actualizada.', 'Senha atualizada.', 'Mot de passe mis à jour.', 'تم تحديث كلمة المرور.');
  String get fillAllPassFields => _t('Tüm şifre alanlarını doldurun.', 'Fill in all password fields.', '모든 비밀번호 항목을 입력해 주세요.', 'すべてのパスワード欄を入力してください。', 'Isi semua kolom kata sandi.', 'Hãy điền tất cả ô mật khẩu.', 'กรุณากรอกช่องรหัสผ่านทั้งหมด', 'Заполните все поля пароля.', 'Completa todos los campos de contraseña.', 'Preencha todos os campos de senha.', 'Remplissez tous les champs de mot de passe.', 'يرجى ملء جميع حقول كلمة المرور.');
  String get passwordMismatch => _t('Yeni şifreler eşleşmiyor.', "New passwords don't match.", '새 비밀번호가 일치하지 않아요.', '新しいパスワードが一致しません。', 'Kata sandi baru tidak cocok.', 'Mật khẩu mới không khớp.', 'รหัสผ่านใหม่ไม่ตรงกัน', 'Новые пароли не совпадают.', 'Las contraseñas nuevas no coinciden.', 'As novas senhas não coincidem.', 'Les nouveaux mots de passe ne correspondent pas.', 'كلمتا المرور الجديدتان غير متطابقتين.');
  String get passwordTooShort => _t('Şifre en az 6 karakter olmalıdır.',
      'Password must be at least 6 characters.', '비밀번호는 6자 이상이어야 해요.', 'パスワードは6文字以上にしてください。', 'Kata sandi minimal 6 karakter.', 'Mật khẩu phải có ít nhất 6 ký tự.', 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร', 'Пароль должен содержать не менее 6 символов.', 'La contraseña debe tener al menos 6 caracteres.', 'A senha deve ter pelo menos 6 caracteres.', 'Le mot de passe doit contenir au moins 6 caractères.', 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.');
  String get guestCannotEdit => _t('Misafir kullanıcılar profil düzenleyemez.',
      'Guest users cannot edit their profile.', '게스트는 프로필을 수정할 수 없어요.', 'ゲストはプロフィールを編集できません。', 'Pengguna tamu tidak bisa mengubah profil.', 'Khách không thể chỉnh sửa hồ sơ.', 'ผู้เยี่ยมชมไม่สามารถแก้ไขโปรไฟล์ได้', 'Гости не могут редактировать профиль.', 'Los usuarios invitados no pueden editar su perfil.', 'Usuários convidados não podem editar seu perfil.', 'Les utilisateurs invités ne peuvent pas modifier leur profil.', 'لا يمكن للمستخدمين الزوار تعديل ملفهم الشخصي.');
  String get signUpOrIn     => _t('Hesap Oluştur / Giriş Yap', 'Sign Up / Sign In', '회원가입 / 로그인', '新規登録 / ログイン', 'Daftar / Masuk', 'Đăng ký / Đăng nhập', 'สมัครสมาชิก / เข้าสู่ระบบ', 'Регистрация / Вход', 'Registrarse / Iniciar sesión', 'Cadastrar-se / Entrar', 'S\'inscrire / Se connecter', 'إنشاء حساب / تسجيل الدخول');
  String get cancel         => _t('İptal', 'Cancel', '취소', 'キャンセル', 'Batal', 'Hủy', 'ยกเลิก', 'Отмена', 'Cancelar', 'Cancelar', 'Annuler', 'إلغاء');
  String get signOutConfirmMsg => _t('Hesabınızdan çıkmak istediğinizden emin misiniz?',
      'Are you sure you want to sign out?', '정말 로그아웃하시겠어요?', '本当にログアウトしますか？', 'Yakin ingin keluar?', 'Bạn có chắc muốn đăng xuất?', 'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?', 'Вы уверены, что хотите выйти?', '¿Estás seguro de que quieres cerrar sesión?', 'Tem certeza de que deseja sair?', 'Êtes-vous sûr de vouloir vous déconnecter ?', 'هل أنت متأكد من رغبتك في تسجيل الخروج؟');
  String get deleteAccountMsg => _t('Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'Your account and all your data will be permanently deleted. This action cannot be undone.',
      '계정과 모든 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없어요.',
      'アカウントとすべてのデータが完全に削除されます。この操作は元に戻せません。',
      'Akun dan semua datamu akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
      'Tài khoản và toàn bộ dữ liệu của bạn sẽ bị xóa vĩnh viễn. Không thể hoàn tác.',
      'บัญชีและข้อมูลทั้งหมดของคุณจะถูกลบถาวร ไม่สามารถย้อนกลับได้', 'Ваш аккаунт и все ваши данные будут безвозвратно удалены. Это действие нельзя отменить.', 'Tu cuenta y todos tus datos se eliminarán permanentemente. Esta acción no se puede deshacer.', 'Sua conta e todos os seus dados serão excluídos permanentemente. Esta ação não pode ser desfeita.', 'Votre compte et toutes vos données seront définitivement supprimés. Cette action ne peut pas être annulée.', 'سيتم حذف حسابك وجميع بياناتك نهائياً. لا يمكن التراجع عن هذا الإجراء.');
}
