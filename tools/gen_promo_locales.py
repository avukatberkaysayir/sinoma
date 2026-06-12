# Generates localized promo pages from the English master:
#   web/promo/sinoma_promo.html  ->  sinoma_promo_tr.html, sinoma_promo_ko.html
# Adding a UI language later = add its column to STRINGS and list it in LANGS.
# Every source string must match the master EXACTLY ONCE or the build fails —
# that guards against silent drift when the master promo is edited.
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MASTER = ROOT / 'web' / 'promo' / 'sinoma_promo.html'

LANGS = ['tr', 'ko']

# (en, tr, ko)
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


def main():
    master = MASTER.read_text(encoding='utf-8')
    errors = []
    for i, lang in enumerate(LANGS, start=1):
        out = master
        for row in STRINGS:
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
