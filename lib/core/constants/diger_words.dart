/// "Diğer" — HSK 1-6 listelerinde olmayan, videolardan derlenip admin
/// panelinde onaylanan kelimeler. Diğer HSK dosyalarıyla aynı satır biçimi:
/// [simplified, pinyin, pos, en, tr, ko]
///
/// Bu dosya `tools/sync_diger_words.py` ile veritabanından üretilir
/// (deploy.ps1 her dağıtımdan önce çalıştırır) — elle düzenleme bir sonraki
/// senkronda korunmaz; kelimeler admin > Sözlük > Önerilen akışından eklenir.
/// Bu kelimeler sözlükte "Diğer" etiketiyle görünür ve HİÇBİR ZAMAN ünite /
/// bölüm yerleşim kriteri olmaz.
// ── SYNC-START ──
const List<List<String>> kDigerWords = [
];
// ── SYNC-END ──
