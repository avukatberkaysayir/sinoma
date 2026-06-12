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
  ['东东', 'dōngdōng', '', 'thing, stuff, objects; Dongdong (nickname)', 'şey, nesne', '것, 물건'],
  ['儿', 'ér', '', 'child, son; diminutive suffix (-r)', 'çocuk, evlat, sonek (küçültme veya isimleştirme)', '아이, 자식, 접미사 (명사화 또는 애칭)'],
  ['冬', 'dōng', '', 'winter', 'kış', '겨울'],
  ['动物小镇', 'dòngwù xiǎozhèn', '', 'animal town, animal village', 'hayvan kasabası, hayvan şehri', '동물 마을, 동물 타운'],
  ['呗', 'bei, bei·', '', 'modal particle ("then", "of course", "why not")', 'elbette, tabii, -dir/-dır (pekiştirme edatı)', '당연함을 나타내는 종결 어미, -지 뭐 (가벼운 체념이나 권유)'],
  ['呼', 'hū', '', 'call, shout, exhale, breathe out', 'çağırmak, seslenmek, nefes almak', '부르다, 외치다, 숨쉬다'],
  ['咱', 'zán', '', 'we, us', 'biz (konuşmacı ve dinleyiciyi kapsayan samimi biçim)', '우리 (말하는 이와 듣는 이를 아울러 이르는 말)'],
  ['塞', 'sāi, sè, sài', '', 'stuff, plug; blockage; frontier pass', 'tıkamak, doldurmak, geçit', '막다, 채우다, 변방'],
  ['屋', 'wū', '', 'house, room, building', 'Ev, oda, yapı', '집, 방, 건물'],
  ['巴', 'bā', '', 'cling to, hope for; bar (unit); Ba (surname)', 'yapışmak, arzu etmek, bir şeyin sonu', '달라붙다, 바라다, 끝'],
  ['扭', 'niǔ', '', 'twist, turn, wrench', 'bükmek, kıvırmak, burkmak', '비틀다, 뒤틀다, 꼬다'],
  ['招', 'zhāo', '', 'recruit, attract, beckon, move, trick', 'çağırmak, davet etmek; işaret, belirti', '부르다, 초청하다; 나타내다, 드러내다; 수단, 방법'],
  ['没', 'méi, mò', '', 'not, have not; sink, submerge', 'yok, sahip olmamak, bitmiş', '없다, 아니다, 다하다'],
  ['猫小', 'māoxiǎo', '', 'little cat, cat-small', 'küçük kedi, kedi yavrusu', '새끼 고양이, 작은 고양이'],
  ['眠', 'mián', '', 'sleep, dormant', 'uyku, uyumak', '잠, 자다'],
  ['罗', 'luó', '', 'net, collect, gather; Luo (surname)', 'ağ, file, tül; toplamak, yakalamak', '그물, 망; 얽어매다, 포획하다'],
  ['考拉宝', 'kǎolābǎo', '', 'koala treasure, koala baby', 'koala', '코알라'],
  ['镇', 'zhèn', '', 'own, township, suppress, calm', 'kasaba, nahiye, sakinleştirmek', '진정시키다, 안정시키다, 마을'],
];
// ── SYNC-END ──
