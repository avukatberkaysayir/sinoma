# Generates localized promo pages from the English master:
#   web/promo/sinoma_promo.html  ->  sinoma_promo_tr.html, sinoma_promo_ko.html
# Adding a UI language later = add its column to STRINGS and list it in LANGS.
# Every source string must match the master EXACTLY ONCE or the build fails —
# that guards against silent drift when the master promo is edited.
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MASTER = ROOT / 'web' / 'promo' / 'sinoma_promo.html'

LANGS = ['tr', 'ko', 'ja', 'id', 'vi', 'th']

# (en, tr, ko) — Japanese (JA) and Indonesian (ID) live in parallel lists below
# (same order) so the existing en/tr/ko tuples stay byte-for-byte identical to
# the master.
STRINGS = [
    ('<html lang="en">', '<html lang="tr">', '<html lang="ko">'),
    ('Learning Chinese?', 'Çince mi öğreniyorsun?', '중국어 배우세요?'),
    ('3,000 characters. 4 tones.<br>And it still sounds nothing like the classroom.',
     '3.000 karakter. 4 ton.<br>Ve yine de sınıfta duyduğuna hiç benzemiyor.',
     '한자 3,000자, 성조 4개.<br>그런데 실제 회화는 교실에서 듣던 것과 전혀 달라요.'),
    ('You memorize words — then a native speaker opens their mouth and you understand <b class="bad">nothing</b>.',
     'Kelimeleri ezberliyorsun — sonra ana dili Çince olan biri konuşuyor ve <b class="bad">hiçbir şey</b> anlamıyorsun.',
     '단어를 외워도 — 원어민이 입을 여는 순간 <b class="bad">아무것도</b> 안 들려요.'),
    ('📚 Dry textbook dialogues', '📚 Kuru ders kitabı diyalogları', '📚 딱딱한 교과서 대화'),
    ('🃏 Flashcards with zero context', '🃏 Bağlamsız ezber kartları', '🃏 맥락 없는 단어 카드'),
    ('🤖 Apps that never play real speech', '🤖 Gerçek konuşma dinletmeyen uygulamalar', '🤖 진짜 회화는 들려주지 않는 앱'),
    ('Learn Mandarin from <b class="accent">real videos</b> by native creators —<br>not textbook recordings.',
     "Mandarin'i ders kitabı kayıtlarından değil,<br>yerli üreticilerin <b class=\"accent\">gerçek videolarından</b> öğren.",
     '교과서 녹음이 아니라 원어민 크리에이터의<br><b class="accent">실제 영상</b>으로 중국어를 배워요.'),
    ('Comprehensible input, bite-sized', 'Anlaşılır girdi, küçük lokmalar', '이해 가능한 입력, 한입 크기'),
    ('Real videos. 5–10 second bites.<br>Then prove you understood.',
     'Gerçek videolar. 5–10 saniyelik kesitler.<br>Sonra anladığını kanıtla.',
     '실제 영상을 5–10초로 잘라서.<br>이해했는지 바로 확인해요.'),
    ('Which Chinese drinks are good?', 'Hangi Çin içecekleri güzel?', '어떤 중국 음료가 맛있을까요?'),
    ('Which Chinese drinks are NOT good?', 'Hangi Çin içecekleri güzel DEĞİL?', '어떤 중국 음료가 맛없을까요?'),
    ('Subtitles on or off — your choice. Slow it to 0.5×, replay, then answer.<br><b class="accent">Every clip ends with a quiz.</b> Miss it, lose a heart.',
     "Altyazı açık ya da kapalı — seçim senin. 0.5×'e yavaşlat, tekrar izle, sonra cevapla.<br><b class=\"accent\">Her klip bir quizle biter.</b> Kaçırırsan bir kalp kaybedersin.",
     '자막은 켜도 꺼도 자유. 0.5×로 늦추고 다시 본 다음 답하세요.<br><b class="accent">모든 클립은 퀴즈로 끝나요.</b> 틀리면 하트를 잃어요.'),
    ('Your AI tutor, one tap away', 'Yapay zekâ öğretmenin bir dokunuş uzakta', '한 번의 탭으로 만나는 AI 튜터'),
    ('Tap any word.<br>AI explains it <span class="accent">in that exact sentence.</span>',
     'Herhangi bir kelimeye dokun.<br>Yapay zekâ onu <span class="accent">tam o cümlenin içinde</span> açıklasın.',
     '아무 단어나 탭하세요.<br>AI가 <span class="accent">바로 그 문장 안에서</span> 설명해 줘요.'),
    ('<div class="def">to drink</div>', '<div class="def">içmek</div>', '<div class="def">마시다</div>'),
    ('Here <b>喝</b> attaches to <b>好</b> to form <b>好喝</b> — “good to drink / tasty”. The speaker isn’t talking about the act of drinking; she’s judging <i>which drinks taste good</i>. Compare 好吃 (tasty food) and 好看 (good-looking).',
     'Burada <b>喝</b>, <b>好</b> ile birleşip <b>好喝</b> oluyor — “içimi güzel / lezzetli”. Konuşan içme eyleminden bahsetmiyor; <i>hangi içeceklerin lezzetli olduğunu</i> değerlendiriyor. 好吃 (lezzetli yemek) ve 好看 (güzel görünümlü) ile karşılaştır.',
     '여기서 <b>喝</b>는 <b>好</b>와 결합해 <b>好喝</b>가 돼요 — “맛있다(마시기 좋다)”라는 뜻이에요. 화자는 마시는 행위가 아니라 <i>어떤 음료가 맛있는지</i>를 말하고 있어요. 好吃(음식이 맛있다), 好看(보기 좋다)과 비교해 보세요.'),
    ('Grammar-aware explanations in your own language.<br>Answers are <b class="warm">cached forever</b> — once anyone asks, it’s instant and free for everyone.',
     'Kendi dilinde, dil bilgisine hâkim açıklamalar.<br>Yanıtlar <b class="warm">kalıcı olarak önbelleklenir</b> — biri sorduysa herkes için anında ve ücretsizdir.',
     '내 언어로 문법까지 짚어 주는 설명.<br>답변은 <b class="warm">영구 캐시</b>되어 — 누군가 한 번 물으면 모두에게 즉시, 무료예요.'),
    ('A game you actually want to play', 'Gerçekten oynamak isteyeceğin bir oyun', '정말로 하고 싶어지는 게임'),
    ('Your journey across China.<br><span class="accent">576 phases</span>, HSK 1 → 6.',
     'Çin boyunca yolculuğun.<br><span class="accent">576 etap</span>, HSK 1 → 6.',
     '중국을 가로지르는 여정.<br><span class="accent">576개 단계</span>, HSK 1 → 6.'),
    ('🏮 <b>Lanterns</b>&nbsp;&&nbsp;🪙 <b>coins</b> — earn them, spend them in the Market',
     "🏮 <b>Fenerler</b>&nbsp;ve&nbsp;🪙 <b>paralar</b> — kazan, Pazar'da harca",
     '🏮 <b>등불</b>과&nbsp;🪙 <b>코인</b> — 모아서 마켓에서 쓰세요'),
    ('⚡ <b>Daily Quest:</b>&nbsp;complete one phase',
     '⚡ <b>Günlük Görev:</b>&nbsp;bir etap tamamla',
     '⚡ <b>일일 퀘스트:</b>&nbsp;단계 1개 완료'),
    ('<span>Climb ranks of Chinese legends</span>',
     '<span>Çin efsanelerinin rütbelerinde yüksel</span>',
     '<span>중국 영웅들의 계급을 올라가세요</span>'),
    ('🍵 <b>Tea House</b> — relax, review, and chat',
     '🍵 <b>Çayevi</b> — dinlen, tekrar et, sohbet et',
     '🍵 <b>찻집</b> — 쉬면서 복습하고 수다도 떨어요'),
    ('Streaks, quests, hearts and unlockable landmarks keep you coming back — <b class="accent">daily</b>.',
     'Seriler, görevler, kalpler ve kilidi açılan yapılar seni geri getirir — hem de <b class="accent">her gün</b>.',
     '스트릭, 퀘스트, 하트, 잠금 해제되는 명소가 당신을 다시 부릅니다 — <b class="accent">매일</b>.'),
    ('Learn together, compete together', 'Birlikte öğren, birlikte yarış', '함께 배우고 함께 겨뤄요'),
    ('Challenge friends. Climb the leaderboard.',
     'Arkadaşlarına meydan oku. Lider tablosunda yüksel.',
     '친구에게 도전하고 리더보드를 올라가세요.'),
    ('10 questions, 10 seconds each, 3 lives. Spin the category wheel and battle a friend — or a bot.',
     'On soru, her biri 10 saniye, 3 can. Kategori çarkını çevir; bir arkadaşınla — ya da botla — kapış.',
     '문제 10개, 각 10초, 목숨 3개. 카테고리 휠을 돌려 친구 — 또는 봇과 대결하세요.'),
    ('Assemble characters from their radicals against the clock. Learn how hanzi are actually built.',
     "Zamana karşı karakterleri köklerinden birleştir. Hanzi'lerin gerçekte nasıl kurulduğunu öğren.",
     '시간 안에 부수로 한자를 조립하세요. 한자가 실제로 어떻게 만들어지는지 배워요.'),
    ('<h3>Leaderboard</h3>', '<h3>Lider Tablosu</h3>', '<h3>리더보드</h3>'),
    ('Why Sinoma', 'Neden Sinoma', '왜 Sinoma인가'),
    ('Built to fix what’s broken<br>in language apps.',
     'Dil uygulamalarında bozuk olanı<br>düzeltmek için kuruldu.',
     '언어 앱의 고장 난 부분을<br>고치기 위해 만들었어요.'),
    ('<span class="from">Scripted textbook audio</span>',
     '<span class="from">Senaryolu ders kitabı sesi</span>',
     '<span class="from">대본 읽는 교과서 음성</span>'),
    ('<span class="to">Real native YouTube speech</span>',
     '<span class="to">Gerçek, yerli YouTube konuşması</span>',
     '<span class="to">진짜 원어민 유튜브 회화</span>'),
    ('<span class="from">Passive video watching</span>',
     '<span class="from">Pasif video izleme</span>',
     '<span class="from">수동적인 영상 시청</span>'),
    ('<span class="to">Quiz after every single clip</span>',
     '<span class="to">Her klipten sonra quiz</span>',
     '<span class="to">모든 클립 뒤에 퀴즈</span>'),
    ('<span class="from">Dictionary definitions without context</span>',
     '<span class="from">Bağlamsız sözlük tanımları</span>',
     '<span class="from">맥락 없는 사전 뜻풀이</span>'),
    ('<span class="to">AI explains the word in <i>your</i> sentence</span>',
     '<span class="to">Yapay zekâ kelimeyi <i>senin</i> cümlende açıklar</span>',
     '<span class="to">AI가 <i>내</i> 문장 속에서 단어를 설명</span>'),
    ('<span class="from">Motivation that dies in a week</span>',
     '<span class="from">Bir haftada sönen motivasyon</span>',
     '<span class="from">일주일이면 식는 의욕</span>'),
    ('<span class="to">Quests, ranks, duels & a journey across China</span>',
     '<span class="to">Görevler, rütbeler, düellolar ve Çin boyunca bir yolculuk</span>',
     '<span class="to">퀘스트, 계급, 대결, 그리고 중국 횡단 여정</span>'),
    ('Real Chinese. Real progress.', 'Gerçek Çince. Gerçek ilerleme.', '진짜 중국어, 진짜 실력.'),
    ('Free to start · 5 AI credits daily · HSK 1–6 placement test included',
     'Başlamak ücretsiz · Günde 5 AI kredisi · HSK 1–6 seviye testi dahil',
     '무료 시작 · 매일 AI 크레딧 5개 · HSK 1–6 배치고사 포함'),
    ('Sinoma — 75s Product Promo', 'Sinoma — 75 sn Tanıtım Filmi', 'Sinoma — 75초 제품 소개'),
    ('Click to play · Space = pause · ←/→ = scenes · Record the screen to export as video',
     'Oynatmak için tıkla · Boşluk = duraklat · ←/→ = sahneler · Videoya çevirmek için ekranı kaydet',
     '클릭해서 재생 · Space = 일시정지 · ←/→ = 장면 이동 · 영상으로 내보내려면 화면을 녹화하세요'),
]


# Japanese translations, in the SAME order as STRINGS (one per row).
JA = [
    '<html lang="ja">',
    '中国語を学んでいますか？',
    '漢字3,000字、声調4つ。<br>それでも実際の会話は教室で習ったのと全然違う。',
    '単語を覚えても — ネイティブが話し始めた瞬間、<b class="bad">何も</b>聞き取れない。',
    '📚 無味乾燥な教科書の会話',
    '🃏 文脈ゼロの単語カード',
    '🤖 本物の会話を流さないアプリ',
    '教科書の録音ではなく、ネイティブ制作者の<br><b class="accent">本物の動画</b>で中国語を学ぼう。',
    '理解可能なインプットを、一口サイズで',
    '本物の動画を5〜10秒に区切って。<br>そのあと、理解できたか確かめます。',
    'どの中国の飲み物がおいしい？',
    'どの中国の飲み物がおいしくない？',
    '字幕はオンでもオフでも自由。0.5×に落として、見直してから答えましょう。<br><b class="accent">どのクリップもクイズで終わります。</b>間違えるとハートを失います。',
    'ワンタップで使えるAIチューター',
    'どの単語でもタップ。<br>AIが<span class="accent">まさにその文の中で</span>説明します。',
    '<div class="def">飲む</div>',
    'ここでは<b>喝</b>が<b>好</b>と結びついて<b>好喝</b>になります — 「おいしい（飲んでおいしい）」という意味です。話し手は飲む行為ではなく、<i>どの飲み物がおいしいか</i>を述べています。好吃（食べておいしい）や好看（見た目がよい）と比べてみましょう。',
    '自分の言語で、文法まで押さえた説明。<br>回答は<b class="warm">ずっとキャッシュ</b>されます — 誰かが一度たずねれば、みんなに即座に、無料で。',
    '本当にやりたくなるゲーム',
    '中国を横断する旅。<br><span class="accent">576フェーズ</span>、HSK 1 → 6。',
    '🏮 <b>ランタン</b>&nbsp;と&nbsp;🪙 <b>コイン</b> — 集めて、マーケットで使おう',
    '⚡ <b>デイリークエスト：</b>&nbsp;フェーズを1つ完了',
    '<span>中国の英雄たちの位を駆け上がろう</span>',
    '🍵 <b>茶館</b> — くつろいで、復習して、おしゃべりも',
    'ストリーク、クエスト、ハート、解放される名所が、あなたを呼び戻します — <b class="accent">毎日</b>。',
    '一緒に学び、一緒に競う',
    '友だちに挑戦。リーダーボードを駆け上がろう。',
    '問題10問、各10秒、ライフ3つ。カテゴリーホイールを回して、友だち — またはボットと対戦。',
    '時間内に部首から漢字を組み立てよう。漢字が実際にどう作られているかを学べます。',
    '<h3>リーダーボード</h3>',
    'なぜSinomaなのか',
    '言語アプリの壊れた部分を<br>直すために作りました。',
    '<span class="from">台本どおりの教科書音声</span>',
    '<span class="to">本物のネイティブYouTube会話</span>',
    '<span class="from">受動的な動画視聴</span>',
    '<span class="to">どのクリップの後にもクイズ</span>',
    '<span class="from">文脈のない辞書の語義</span>',
    '<span class="to">AIが<i>あなたの</i>文の中で単語を説明</span>',
    '<span class="from">一週間で消えるモチベーション</span>',
    '<span class="to">クエスト、ランク、対戦、そして中国横断の旅</span>',
    '本物の中国語。本物の上達。',
    '無料で開始 · 毎日AIクレジット5個 · HSK 1–6 レベルテスト付き',
    'Sinoma — 75秒 製品プロモ',
    'クリックで再生 · Space = 一時停止 · ←/→ = シーン移動 · 動画として書き出すには画面を録画してください',
]

assert len(JA) == len(STRINGS), f'JA {len(JA)} != STRINGS {len(STRINGS)}'

# Indonesian translations, in the SAME order as STRINGS (one per row).
ID = [
    '<html lang="id">',
    'Belajar bahasa Mandarin?',
    '3.000 karakter. 4 nada.<br>Dan tetap saja tak terdengar seperti di kelas.',
    'Kamu menghafal kata — lalu penutur asli membuka mulut dan kamu <b class="bad">tak paham apa-apa</b>.',
    '📚 Dialog buku teks yang kaku',
    '🃏 Kartu hafalan tanpa konteks',
    '🤖 Aplikasi yang tak pernah memutar percakapan nyata',
    'Belajar Mandarin dari <b class="accent">video nyata</b> oleh kreator asli —<br>bukan rekaman buku teks.',
    'Masukan yang dapat dipahami, sepotong demi sepotong',
    'Video nyata. Potongan 5–10 detik.<br>Lalu buktikan kamu paham.',
    'Minuman Tiongkok mana yang enak?',
    'Minuman Tiongkok mana yang TIDAK enak?',
    'Subtitel nyala atau mati — terserah kamu. Perlambat ke 0,5×, putar ulang, lalu jawab.<br><b class="accent">Setiap klip diakhiri kuis.</b> Salah, kehilangan satu nyawa.',
    'Tutor AI-mu, cukup satu ketukan',
    'Ketuk kata mana pun.<br>AI menjelaskannya <span class="accent">tepat di dalam kalimat itu.</span>',
    '<div class="def">minum</div>',
    'Di sini <b>喝</b> bergabung dengan <b>好</b> menjadi <b>好喝</b> — "enak diminum". Penutur tidak membicarakan kegiatan minum; ia menilai <i>minuman mana yang enak</i>. Bandingkan 好吃 (enak dimakan) dan 好看 (enak dipandang).',
    'Penjelasan yang paham tata bahasa dalam bahasamu sendiri.<br>Jawaban <b class="warm">disimpan selamanya</b> — sekali ada yang bertanya, langsung tersedia gratis untuk semua.',
    'Permainan yang benar-benar ingin kamu mainkan',
    'Perjalananmu melintasi Tiongkok.<br><span class="accent">576 fase</span>, HSK 1 → 6.',
    '🏮 <b>Lampion</b>&nbsp;&&nbsp;🪙 <b>koin</b> — kumpulkan, belanjakan di Pasar',
    '⚡ <b>Misi Harian:</b>&nbsp;selesaikan satu fase',
    '<span>Naik pangkat para legenda Tiongkok</span>',
    '🍵 <b>Kedai Teh</b> — bersantai, mengulang, dan mengobrol',
    'Rentetan, misi, nyawa, dan landmark yang bisa dibuka membuatmu kembali — <b class="accent">setiap hari</b>.',
    'Belajar bersama, bersaing bersama',
    'Tantang teman. Naik di papan peringkat.',
    '10 soal, masing-masing 10 detik, 3 nyawa. Putar roda kategori dan bertanding melawan teman — atau bot.',
    'Susun karakter dari radikalnya melawan waktu. Pelajari bagaimana hanzi sebenarnya dibentuk.',
    '<h3>Papan Peringkat</h3>',
    'Mengapa Sinoma',
    'Dibuat untuk memperbaiki yang rusak<br>pada aplikasi bahasa.',
    '<span class="from">Audio buku teks bernaskah</span>',
    '<span class="to">Percakapan YouTube asli dari penutur asli</span>',
    '<span class="from">Menonton video secara pasif</span>',
    '<span class="to">Kuis setelah setiap klip</span>',
    '<span class="from">Definisi kamus tanpa konteks</span>',
    '<span class="to">AI menjelaskan kata dalam kalimat <i>milikmu</i></span>',
    '<span class="from">Motivasi yang padam dalam seminggu</span>',
    '<span class="to">Misi, pangkat, duel & perjalanan melintasi Tiongkok</span>',
    'Mandarin sungguhan. Kemajuan sungguhan.',
    'Gratis untuk memulai · 5 kredit AI per hari · Termasuk tes penempatan HSK 1–6',
    'Sinoma — Promo Produk 75 detik',
    'Klik untuk memutar · Spasi = jeda · ←/→ = adegan · Rekam layar untuk mengekspor sebagai video',
]

assert len(ID) == len(STRINGS), f'ID {len(ID)} != STRINGS {len(STRINGS)}'

# Vietnamese translations, in the SAME order as STRINGS (one per row).
VI = [
    '<html lang="vi">',
    'Đang học tiếng Trung?',
    '3.000 chữ Hán. 4 thanh điệu.<br>Mà vẫn nghe chẳng giống như trong lớp học.',
    'Bạn học thuộc từ — rồi người bản xứ vừa mở miệng là bạn <b class="bad">chẳng hiểu gì</b>.',
    '📚 Hội thoại sách giáo khoa khô khan',
    '🃏 Thẻ ghi nhớ không có ngữ cảnh',
    '🤖 Ứng dụng chẳng bao giờ cho nghe hội thoại thật',
    'Học tiếng Trung từ <b class="accent">video thật</b> của người bản xứ —<br>không phải bản thu sách giáo khoa.',
    'Đầu vào dễ hiểu, từng phần nhỏ',
    'Video thật. Cắt thành đoạn 5–10 giây.<br>Rồi chứng minh bạn đã hiểu.',
    'Đồ uống Trung Quốc nào ngon?',
    'Đồ uống Trung Quốc nào KHÔNG ngon?',
    'Bật hay tắt phụ đề — tùy bạn. Làm chậm 0,5×, xem lại, rồi trả lời.<br><b class="accent">Mỗi clip kết thúc bằng một câu đố.</b> Sai là mất một tim.',
    'Gia sư AI của bạn, chỉ một chạm',
    'Chạm vào bất kỳ từ nào.<br>AI giải thích nó <span class="accent">ngay trong câu đó.</span>',
    '<div class="def">uống</div>',
    'Ở đây <b>喝</b> kết hợp với <b>好</b> thành <b>好喝</b> — "ngon (uống ngon)". Người nói không nói về hành động uống; mà đang đánh giá <i>đồ uống nào ngon</i>. So sánh với 好吃 (ăn ngon) và 好看 (đẹp mắt).',
    'Giải thích am hiểu ngữ pháp bằng chính ngôn ngữ của bạn.<br>Câu trả lời được <b class="warm">lưu mãi mãi</b> — chỉ cần một người hỏi, mọi người đều có ngay, miễn phí.',
    'Một trò chơi bạn thực sự muốn chơi',
    'Hành trình của bạn xuyên Trung Quốc.<br><span class="accent">576 giai đoạn</span>, HSK 1 → 6.',
    '🏮 <b>Đèn lồng</b>&nbsp;&&nbsp;🪙 <b>xu</b> — kiếm chúng, tiêu ở Chợ',
    '⚡ <b>Nhiệm vụ hằng ngày:</b>&nbsp;hoàn thành một giai đoạn',
    '<span>Thăng hạng cùng các huyền thoại Trung Hoa</span>',
    '🍵 <b>Quán trà</b> — thư giãn, ôn tập và trò chuyện',
    'Chuỗi ngày, nhiệm vụ, tim và các địa danh mở khóa giúp bạn quay lại — <b class="accent">mỗi ngày</b>.',
    'Học cùng nhau, thi đua cùng nhau',
    'Thách đấu bạn bè. Leo bảng xếp hạng.',
    '10 câu hỏi, mỗi câu 10 giây, 3 mạng. Quay vòng quay chủ đề và đấu với bạn — hoặc với bot.',
    'Ghép chữ Hán từ bộ thủ trong thời gian quy định. Học cách chữ Hán thực sự được tạo nên.',
    '<h3>Bảng xếp hạng</h3>',
    'Vì sao chọn Sinoma',
    'Được tạo ra để sửa những gì còn hỏng<br>ở các ứng dụng học ngôn ngữ.',
    '<span class="from">Âm thanh sách giáo khoa đọc theo kịch bản</span>',
    '<span class="to">Hội thoại YouTube thật của người bản xứ</span>',
    '<span class="from">Xem video thụ động</span>',
    '<span class="to">Câu đố sau mỗi clip</span>',
    '<span class="from">Định nghĩa từ điển không có ngữ cảnh</span>',
    '<span class="to">AI giải thích từ trong câu của <i>bạn</i></span>',
    '<span class="from">Động lực tắt ngấm sau một tuần</span>',
    '<span class="to">Nhiệm vụ, cấp bậc, đấu trí & hành trình xuyên Trung Quốc</span>',
    'Tiếng Trung thật. Tiến bộ thật.',
    'Bắt đầu miễn phí · 5 tín dụng AI mỗi ngày · Bao gồm bài kiểm tra xếp cấp HSK 1–6',
    'Sinoma — Video giới thiệu sản phẩm 75 giây',
    'Nhấp để phát · Space = tạm dừng · ←/→ = cảnh · Quay màn hình để xuất video',
]

assert len(VI) == len(STRINGS), f'VI {len(VI)} != STRINGS {len(STRINGS)}'

# Thai translations, in the SAME order as STRINGS (one per row), Thai script.
TH = [
    '<html lang="th">',
    'กำลังเรียนภาษาจีนอยู่ใช่ไหม?',
    '3,000 ตัวอักษร 4 วรรณยุกต์<br>แต่เสียงจริงกลับไม่เหมือนในห้องเรียนเลย',
    'คุณท่องคำศัพท์ — แต่พอเจ้าของภาษาพูด คุณกลับ<b class="bad">ฟังไม่รู้เรื่อง</b>',
    '📚 บทสนทนาในตำราที่น่าเบื่อ',
    '🃏 บัตรคำที่ไม่มีบริบท',
    '🤖 แอปที่ไม่เคยให้ฟังบทสนทนาจริง',
    'เรียนภาษาจีนจาก <b class="accent">วิดีโอจริง</b> ของครีเอเตอร์เจ้าของภาษา —<br>ไม่ใช่เสียงอัดจากตำรา',
    'อินพุตที่เข้าใจได้ ทีละส่วนเล็ก ๆ',
    'วิดีโอจริง ตัดเป็นช่วงละ 5–10 วินาที<br>แล้วพิสูจน์ว่าคุณเข้าใจ',
    'เครื่องดื่มจีนชนิดไหนอร่อย?',
    'เครื่องดื่มจีนชนิดไหนไม่อร่อย?',
    'เปิดหรือปิดคำบรรยายก็ได้ ตามใจคุณ ชะลอเป็น 0.5× ดูซ้ำ แล้วตอบ<br><b class="accent">ทุกคลิปจบด้วยคำถาม</b> ตอบผิดเสียหนึ่งหัวใจ',
    'ติวเตอร์ AI ของคุณ เพียงแตะเดียว',
    'แตะคำใดก็ได้<br>AI อธิบายคำนั้น <span class="accent">ในประโยคนั้นทันที</span>',
    '<div class="def">ดื่ม</div>',
    'ที่นี่ <b>喝</b> รวมกับ <b>好</b> เป็น <b>好喝</b> — "อร่อย (ดื่มแล้วอร่อย)" ผู้พูดไม่ได้พูดถึงการดื่ม แต่กำลังประเมินว่า<i>เครื่องดื่มชนิดไหนอร่อย</i> เทียบกับ 好吃 (กินอร่อย) และ 好看 (ดูสวย)',
    'คำอธิบายที่เข้าใจไวยากรณ์ ในภาษาของคุณเอง<br>คำตอบถูก<b class="warm">เก็บไว้ตลอดไป</b> — แค่คนเดียวถาม ทุกคนก็ได้ใช้ฟรีทันที',
    'เกมที่คุณอยากเล่นจริง ๆ',
    'การเดินทางของคุณข้ามประเทศจีน<br><span class="accent">576 ด่าน</span> ตั้งแต่ HSK 1 → 6',
    '🏮 <b>โคมไฟ</b>&nbsp;&&nbsp;🪙 <b>เหรียญ</b> — สะสมแล้วใช้จ่ายที่ตลาด',
    '⚡ <b>ภารกิจประจำวัน:</b>&nbsp;ผ่านหนึ่งด่าน',
    '<span>เลื่อนอันดับไปกับตำนานจีน</span>',
    '🍵 <b>เรือนน้ำชา</b> — ผ่อนคลาย ทบทวน และพูดคุย',
    'สถิติต่อเนื่อง ภารกิจ หัวใจ และสถานที่ที่ปลดล็อกได้ ดึงคุณให้กลับมา — <b class="accent">ทุกวัน</b>',
    'เรียนด้วยกัน แข่งขันด้วยกัน',
    'ท้าดวลเพื่อน ไต่กระดานผู้นำ',
    '10 คำถาม ข้อละ 10 วินาที 3 ชีวิต หมุนวงล้อหมวดหมู่แล้วดวลกับเพื่อน — หรือกับบอท',
    'ประกอบตัวอักษรจีนจากส่วนประกอบภายในเวลาที่กำหนด เรียนรู้ว่าตัวอักษรสร้างขึ้นมาอย่างไรจริง ๆ',
    '<h3>กระดานผู้นำ</h3>',
    'ทำไมต้อง Sinoma',
    'สร้างขึ้นเพื่อแก้สิ่งที่ยังบกพร่อง<br>ในแอปเรียนภาษา',
    '<span class="from">เสียงจากตำราที่อ่านตามบท</span>',
    '<span class="to">บทสนทนา YouTube จริงของเจ้าของภาษา</span>',
    '<span class="from">การดูวิดีโอแบบเฉื่อยชา</span>',
    '<span class="to">คำถามหลังจบทุกคลิป</span>',
    '<span class="from">นิยามพจนานุกรมที่ไม่มีบริบท</span>',
    '<span class="to">AI อธิบายคำในประโยคของ<i>คุณ</i></span>',
    '<span class="from">แรงจูงใจที่หมดไปหลังหนึ่งสัปดาห์</span>',
    '<span class="to">ภารกิจ อันดับ การดวล & การเดินทางข้ามจีน</span>',
    'ภาษาจีนจริง ความก้าวหน้าจริง',
    'เริ่มฟรี · เครดิต AI 5 ครั้งต่อวัน · รวมแบบทดสอบจัดระดับ HSK 1–6',
    'Sinoma — วิดีโอแนะนำผลิตภัณฑ์ 75 วินาที',
    'คลิกเพื่อเล่น · Space = หยุดชั่วคราว · ←/→ = ฉาก · บันทึกหน้าจอเพื่อส่งออกเป็นวิดีโอ',
]

assert len(TH) == len(STRINGS), f'TH {len(TH)} != STRINGS {len(STRINGS)}'


def row_for(k):
    # en/tr/ko from STRINGS, ja/id/vi/th appended from the parallel lists.
    return STRINGS[k] + (JA[k], ID[k], VI[k], TH[k])


def main():
    master = MASTER.read_text(encoding='utf-8')
    errors = []
    for i, lang in enumerate(LANGS, start=1):
        out = master
        for k in range(len(STRINGS)):
            row = row_for(k)
            src, dst = row[0], row[i]
            n = out.count(src)
            if n != 1:
                errors.append(f'[{lang}] "{src[:60]}..." matched {n} times')
                continue
            out = out.replace(src, dst)
        path = MASTER.with_name(f'sinoma_promo_{lang}.html')
        path.write_text(out, encoding='utf-8', newline='\n')
        print(f'wrote {path.name} ({len(out)} bytes)')
    if errors:
        print('\n'.join(errors))
        sys.exit(1)


if __name__ == '__main__':
    main()
