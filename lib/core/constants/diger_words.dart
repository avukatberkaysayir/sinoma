/// "Diğer" — HSK 1-6 listelerinde olmayan, videolardan derlenip admin
/// panelinde onaylanan kelimeler. Diğer HSK dosyalarıyla aynı satır biçimi:
/// [simplified, pinyin, pos, en, tr, ko, ja, id]
///
/// Bu dosya `tools/sync_diger_words.py` ile veritabanından üretilir
/// (deploy.ps1 her dağıtımdan önce çalıştırır) — elle düzenleme bir sonraki
/// senkronda korunmaz; kelimeler admin > Sözlük > Önerilen akışından eklenir.
/// Bu kelimeler sözlükte "Diğer" etiketiyle görünür ve HİÇBİR ZAMAN ünite /
/// bölüm yerleşim kriteri olmaz.
// ── SYNC-START ──
const List<List<String>> kDigerWords = [
  ['东东', 'dōngdōng', '', 'thing, stuff, objects; Dongdong (nickname)', 'şey, nesne', '것, 물건', '物、品物、東東（愛称）', 'barang, sesuatu; Dongdong (nama panggilan)'],
  ['东小镇', 'Dōng Xiǎozhèn', '', 'East Town, eastern small town', 'Doğu kasabası, Doğu küçük kasabası', '동쪽 작은 마을, 동쪽 마을', '東の小さな町', 'kota kecil timur'],
  ['乐宝', 'Lèbǎo', '', 'happy treasure, joyful baby', 'hazine, değerli şey, sevgili', '보물, 귀염둥이, 사랑스러운 것, 애완동물', '楽宝（愛称）', 'harta sukacita, bayi ceria'],
  ['信天风', 'Xìntiānfēng', '', 'heavenly wind, sky wind', 'albatros, rüzgarla gelen haber', '알바트로스, 신의 뜻을 전하는 바람', '信天風（固有名詞）', 'angin surgawi'],
  ['儿', 'ér', '', 'child, son; diminutive suffix (-r)', 'çocuk, evlat, sonek (küçültme veya isimleştirme)', '아이, 자식, 접미사 (명사화 또는 애칭)', '子供、息子、名詞の語尾に付く接尾辞', 'anak; sufiks diminutif'],
  ['冬', 'dōng', '', 'winter', 'kış', '겨울', '冬', 'musim dingin'],
  ['动物小镇', 'dòngwù xiǎozhèn', '', 'animal town, animal village', 'hayvan kasabası, hayvan şehri', '동물 마을, 동물 타운', '動物の町', 'kota hewan'],
  ['卡拉', 'Kǎlā', '', 'Kara, Carla, kara', 'Karla', '가라오케', 'カラ（人名・音訳）', 'Kara (nama)'],
  ['可拉宝', 'Kělābǎo', '', 'nickname, brand name', 'Takma ad', '콜라(탄산음료)', '可拉宝（愛称・ブランド名）', 'Kelabao (nama panggilan/merek)'],
  ['呗', 'bei, bei·', '', 'modal particle ("then", "of course", "why not")', 'elbette, tabii, -dir/-dır (pekiştirme edatı)', '당연함을 나타내는 종결 어미, -지 뭐 (가벼운 체념이나 권유)', '〜すればいい、〜さ（文末の語気助詞）', 'partikel modal (menunjukkan kepastian atau saran)'],
  ['呼', 'hū', '', 'call, shout, exhale, breathe out', 'çağırmak, seslenmek, nefes almak', '부르다, 외치다, 숨쉬다', '呼ぶ、叫ぶ、吐く、呼吸する', 'memanggil, berteriak, mengembuskan napas'],
  ['咱', 'zán', '', 'we, us', 'biz (konuşmacı ve dinleyiciyi kapsayan samimi biçim)', '우리 (말하는 이와 듣는 이를 아울러 이르는 말)', '私たち（話し手を含む）', 'kami, kita'],
  ['塞', 'sāi, sè, sài', '', 'stuff, plug; blockage; frontier pass', 'tıkamak, doldurmak, geçit', '막다, 채우다, 변방', '詰める、塞ぐ、関所', 'menyumbat, sumbatan, celah perbatasan'],
  ['大苹果', 'Dà Píngguǒ', '', 'big apple', 'büyük elma', '큰 사과', '大きなリンゴ、ビッグアップル', 'apel besar'],
  ['大风车', 'Dà Fēngchē', '', 'windmill', 'büyük yel değirmeni, büyük rüzgar değirmeni', '큰 풍차, 대형 풍차', '大きな風車', 'kincir angin'],
  ['屋', 'wū', '', 'house, room, building', 'Ev, oda, yapı', '집, 방, 건물', '家、部屋', 'rumah, kamar, bangunan'],
  ['巴', 'bā', '', 'cling to, hope for; bar (unit); Ba (surname)', 'yapışmak, arzu etmek, bir şeyin sonu', '달라붙다, 바라다, 끝', 'しがみつく、期待する、バー（単位）、巴（姓）', 'melekat, berharap, bar (satuan), marga Ba'],
  ['巴塞罗那', 'Bāsàiluónà', '', 'Barcelona', 'Barselona', '바르셀로나', 'バルセロナ', 'Barcelona'],
  ['巴巴屋', 'Bābāwū', '', 'Baba\'s house, house, hut', 'kulübe, baraka', '오두막, 판잣집', '巴巴屋（固有名詞）', 'rumah, gubuk'],
  ['扭', 'niǔ', '', 'twist, turn, wrench', 'bükmek, kıvırmak, burkmak', '비틀다, 뒤틀다, 꼬다', 'ねじる、ひねる、よじる', 'memutar, memilin, memelintir'],
  ['拉宝', 'lābǎo', '', 'nickname, pet name', 'takma ad', '아기 침대, 요람, 유모차', '拉宝（愛称）', 'nama panggilan kesayangan'],
  ['招', 'zhāo', '', 'recruit, attract, beckon, move, trick', 'çağırmak, davet etmek; işaret, belirti', '부르다, 초청하다; 나타내다, 드러내다; 수단, 방법', '招く、募集する、手招きする、策略', 'merekrut, menarik, melambai, tipu muslihat'],
  ['摩卡', 'mókǎ', '', 'mocha coffee', 'kahve türü, çikolata türü', '커피의 한 종류, 초콜릿의 한 종류', 'モカ（コーヒー）', 'kopi moka'],
  ['来宝', 'Láibǎo', '', 'coming treasure, treasured arrival', 'sevimli çocuk, evin neşesi', '귀염둥이, 보배 같은 아이', '来宝（愛称）', 'kedatangan berharga'],
  ['没', 'méi, mò', '', 'not, have not; sink, submerge', 'yok, sahip olmamak, bitmiş', '없다, 아니다, 다하다', 'ない、沈む', 'tidak, belum, tenggelam'],
  ['猫小', 'māoxiǎo', '', 'little cat, cat-small', 'küçük kedi, kedi yavrusu', '새끼 고양이, 작은 고양이', '子猫', 'kucing kecil'],
  ['眠', 'mián', '', 'sleep, dormant', 'uyku, uyumak', '잠, 자다', '眠る、休眠する', 'tidur, dorman'],
  ['罗', 'luó', '', 'net, collect, gather; Luo (surname)', 'ağ, file, tül; toplamak, yakalamak', '그물, 망; 얽어매다, 포획하다', '網、集める、羅（姓）', 'jaring, mengumpulkan, marga Luo'],
  ['美式', 'měishì', '', 'Americano coffee, American-style', 'Amerikano, Amerikan usulü kahve', '미국식, 미국식의, 미국의', 'アメリカンコーヒー、アメリカ風の', 'kopi americano, gaya Amerika'],
  ['考拉', 'Kǎolā', '', 'koala', 'koala', '코알라, 유대목 포유류', 'コアラ', 'koala'],
  ['考拉宝', 'kǎolābǎo', '', 'koala treasure, koala baby', 'koala', '코알라', 'コアラの赤ちゃん', 'bayi koala'],
  ['考拉灯都', 'Kǎolā Dēngdū', '', 'Koala Light City, Koala Light Capital', 'Koala Lambo (bir internet fenomeni veya argo terim)', '코알라 람보 (인터넷 밈 또는 은어)', 'コアラ・ライト・シティ（地名・施設名）', 'Kota Lampu Koala'],
  ['茉莉', 'Mòlì', '', 'jasmine', 'yasemin', '재스민', 'ジャスミン', 'melati'],
  ['莫卡', 'mòkǎ', '', 'Moka, mocha (transliteration; brand/name)', 'Moka (çevriyazım; marka/isim), moka kahvesi', '모카 (음역; 브랜드/이름)', 'モカ（コーヒーの種類、または人名・ブランド名）', 'Moka'],
  ['西班牙', 'Xībānyá', '', 'Spain', 'İspanya', '스페인, 에스파냐', 'スペイン', 'Spanyol'],
  ['豆小镇', 'Dòu Xiǎozhèn', '', 'Bean Town, Bean Village', 'Fasulye Kasabası, küçük fasulye, fasulye köyü', '콩 마을, 작은 콩, 콩 소두', '豆の町（地名）', 'Kota Kacang'],
  ['镇', 'zhèn', '', 'own, township, suppress, calm', 'kasaba, nahiye, sakinleştirmek', '진정시키다, 안정시키다, 마을', '町、鎮圧する、落ち着かせる', 'kota kecil, menekan, menenangkan'],
  ['魏君', 'Wèi Jūn', '', 'personal name', 'Wei Bey (Wei soyadlı beyefendi), Wei ailesinin beyi', '위군 (위씨 성을 가진 사람에 대한 존칭, 위나라의 군주)', '魏君（人名）', 'Wei Jun'],
];
// ── SYNC-END ──
