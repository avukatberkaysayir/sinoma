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
  ['东小镇', 'Dōng Xiǎozhèn', '', 'East Town, eastern small town', 'Doğu kasabası, Doğu küçük kasabası', '동쪽 작은 마을, 동쪽 마을'],
  ['乐宝', 'Lèbǎo', '', 'happy treasure, joyful baby', 'hazine, değerli şey, sevgili', '보물, 귀염둥이, 사랑스러운 것, 애완동물'],
  ['信天风', 'Xìntiānfēng', '', 'heavenly wind, sky wind', 'albatros, rüzgarla gelen haber', '알바트로스, 신의 뜻을 전하는 바람'],
  ['儿', 'ér', '', 'child, son; diminutive suffix (-r)', 'çocuk, evlat, sonek (küçültme veya isimleştirme)', '아이, 자식, 접미사 (명사화 또는 애칭)'],
  ['冬', 'dōng', '', 'winter', 'kış', '겨울'],
  ['动物小镇', 'dòngwù xiǎozhèn', '', 'animal town, animal village', 'hayvan kasabası, hayvan şehri', '동물 마을, 동물 타운'],
  ['卡拉', 'Kǎlā', '', 'Kara, Carla, kara', 'Karla', '가라오케'],
  ['可拉宝', 'Kělābǎo', '', 'nickname, brand name', 'Takma ad', '콜라(탄산음료)'],
  ['呗', 'bei, bei·', '', 'modal particle ("then", "of course", "why not")', 'elbette, tabii, -dir/-dır (pekiştirme edatı)', '당연함을 나타내는 종결 어미, -지 뭐 (가벼운 체념이나 권유)'],
  ['呼', 'hū', '', 'call, shout, exhale, breathe out', 'çağırmak, seslenmek, nefes almak', '부르다, 외치다, 숨쉬다'],
  ['咱', 'zán', '', 'we, us', 'biz (konuşmacı ve dinleyiciyi kapsayan samimi biçim)', '우리 (말하는 이와 듣는 이를 아울러 이르는 말)'],
  ['塞', 'sāi, sè, sài', '', 'stuff, plug; blockage; frontier pass', 'tıkamak, doldurmak, geçit', '막다, 채우다, 변방'],
  ['大苹果', 'Dà Píngguǒ', '', 'big apple', 'büyük elma', '큰 사과'],
  ['大风车', 'Dà Fēngchē', '', 'windmill', 'büyük yel değirmeni, büyük rüzgar değirmeni', '큰 풍차, 대형 풍차'],
  ['屋', 'wū', '', 'house, room, building', 'Ev, oda, yapı', '집, 방, 건물'],
  ['巴', 'bā', '', 'cling to, hope for; bar (unit); Ba (surname)', 'yapışmak, arzu etmek, bir şeyin sonu', '달라붙다, 바라다, 끝'],
  ['巴塞罗那', 'Bāsàiluónà', '', 'Barcelona', 'Barselona', '바르셀로나'],
  ['巴巴屋', 'Bābāwū', '', 'Baba\'s house, house, hut', 'kulübe, baraka', '오두막, 판잣집'],
  ['扭', 'niǔ', '', 'twist, turn, wrench', 'bükmek, kıvırmak, burkmak', '비틀다, 뒤틀다, 꼬다'],
  ['拉宝', 'lābǎo', '', 'nickname, pet name', 'takma ad', '아기 침대, 요람, 유모차'],
  ['招', 'zhāo', '', 'recruit, attract, beckon, move, trick', 'çağırmak, davet etmek; işaret, belirti', '부르다, 초청하다; 나타내다, 드러내다; 수단, 방법'],
  ['摩卡', 'mókǎ', '', 'mocha coffee', 'kahve türü, çikolata türü', '커피의 한 종류, 초콜릿의 한 종류'],
  ['来宝', 'Láibǎo', '', 'coming treasure, treasured arrival', 'sevimli çocuk, evin neşesi', '귀염둥이, 보배 같은 아이'],
  ['没', 'méi, mò', '', 'not, have not; sink, submerge', 'yok, sahip olmamak, bitmiş', '없다, 아니다, 다하다'],
  ['猫小', 'māoxiǎo', '', 'little cat, cat-small', 'küçük kedi, kedi yavrusu', '새끼 고양이, 작은 고양이'],
  ['眠', 'mián', '', 'sleep, dormant', 'uyku, uyumak', '잠, 자다'],
  ['罗', 'luó', '', 'net, collect, gather; Luo (surname)', 'ağ, file, tül; toplamak, yakalamak', '그물, 망; 얽어매다, 포획하다'],
  ['美式', 'měishì', '', 'Americano coffee, American-style', 'Amerikano, Amerikan usulü kahve', '미국식, 미국식의, 미국의'],
  ['考拉', 'Kǎolā', '', 'koala', 'koala', '코알라, 유대목 포유류'],
  ['考拉宝', 'kǎolābǎo', '', 'koala treasure, koala baby', 'koala', '코알라'],
  ['考拉灯都', 'Kǎolā Dēngdū', '', 'Koala Light City, Koala Light Capital', 'Koala Lambo (bir internet fenomeni veya argo terim)', '코알라 람보 (인터넷 밈 또는 은어)'],
  ['茉莉', 'Mòlì', '', 'jasmine', 'yasemin', '재스민'],
  ['西班牙', 'Xībānyá', '', 'Spain', 'İspanya', '스페인, 에스파냐'],
  ['豆小镇', 'Dòu Xiǎozhèn', '', 'Bean Town, Bean Village', 'Fasulye Kasabası, küçük fasulye, fasulye köyü', '콩 마을, 작은 콩, 콩 소두'],
  ['镇', 'zhèn', '', 'own, township, suppress, calm', 'kasaba, nahiye, sakinleştirmek', '진정시키다, 안정시키다, 마을'],
  ['魏君', 'Wèi Jūn', '', 'personal name', 'Wei Bey (Wei soyadlı beyefendi), Wei ailesinin beyi', '위군 (위씨 성을 가진 사람에 대한 존칭, 위나라의 군주)'],
];
// ── SYNC-END ──
