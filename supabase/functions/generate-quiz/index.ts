import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Quiz options are low-volume but quality-critical → prefer the stronger
// 2.5-flash and fall through sibling models when a free-tier quota bucket
// runs dry (each model has its OWN bucket). GEMINI_MODEL overrides the first
// choice. The cache key keeps using MODEL so entries stay stable.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const MODEL_FALLBACKS = [...new Set([
  MODEL,
  "gemini-flash-latest",
  "gemini-2.5-flash-lite",
  "gemini-flash-lite-latest",
])];

// Multiple API keys so a free-tier daily-quota wall on one key (429 PerDay) does
// NOT stop generation — we rotate to the next key. Supply either a comma-separated
// GEMINI_API_KEYS secret and/or GEMINI_API_KEY, GEMINI_API_KEY_2..._5. The free
// daily quota is effectively multiplied by the number of distinct keys.
function geminiKeys(): string[] {
  const list: string[] = [];
  for (const k of (Deno.env.get("GEMINI_API_KEYS") ?? "").split(",")) {
    const t = k.trim();
    if (t) list.push(t);
  }
  for (const name of ["GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3",
                      "GEMINI_API_KEY_4", "GEMINI_API_KEY_5"]) {
    const t = (Deno.env.get(name) ?? "").trim();
    if (t) list.push(t);
  }
  return [...new Set(list)];
}

// Per-language expert profile: authoritative source + ordered grammar rules.
// Rules are numbered so the model can cite them in its self-audit step.
const LANG_PROFILES: Record<string, { authority: string; rules: string[] }> = {
  Turkish: {
    authority: "Türk Dil Kurumu (TDK) — tdk.gov.tr",
    rules: [
      "SOV word order: Subject → Object → Verb. The main verb must be at the very end.",
      "Vowel harmony (sesli uyum): every suffix vowel must harmonically agree with the last vowel of the stem (back vowels a/ı/o/u → back suffix; front vowels e/i/ö/ü → front suffix).",
      "Noun-as-adjective compound: when a noun modifies another noun descriptively, it takes -lı/-li/-lu/-lü (e.g. 'kafalı', 'yüzlü', 'sesli'). NEVER leave the modifier as a bare noun before another noun (NOT 'küçük kafa baba' → MUST be 'küçük kafalı baba').",
      "No definite article. 'Bir' is used only for explicit indefinite singular ('a/an'); omit it when the indefinite meaning is general.",
      "Agglutination: build meaning through chained suffixes, not separate words. Avoid calque constructions copied from Chinese.",
      "Question particle: mı/mi/mu/mü after the final verb, following vowel harmony. Written separately from the verb.",
      "Negation: insert -me/-ma before the tense suffix (e.g. yiyemez, görülmez, yapılamaz).",
      "PASSIVE vs ACTIVE voice: When Chinese uses 能+verb to ask about the property/edibility/usability of an OBJECT (e.g. 这个能吃吗 = is this edible?), use Turkish PASSIVE voice with -(i)l suffix (e.g. 'bu yenilebilir mi?' NOT 'bunu yiyebilir mi?'). Active voice is only correct when a named agent does the action.",
      "Capitalization: ONLY the very first word of the sentence is capitalized. Common nouns, adjectives, and verbs in the middle of a sentence are ALL lowercase (e.g. 'Küçük kafalı baba bu yenilebilir mi?' — not 'Küçük Kafalı Baba').",
      "Comma use: place a comma after a long subject phrase when it aids readability (e.g. 'Küçük kafalı baba, bu yenilebilir mi?').",
      "da/de: the CONJUNCTION da/de ('also/too') is written as a separate word and never becomes ta/te; the locative SUFFIX -da/-de attaches to the word and follows consonant assimilation (kitapta). Same for ki: the conjunction ki is separate (diyorlar ki), the suffix -ki attaches (seninki, akşamki).",
      "Buffer consonants (kaynaştırma y, ş, s, n) between vowels: iki-ş-er, baba-s-ı, kapı-y-ı, onun-n-... — never drop or double them.",
      "Produce idiomatic Turkish — what a fluent native speaker would naturally say, NOT a literal word-for-word mapping from Chinese.",
    ],
  },
  English: {
    authority: "Oxford English Grammar (Sidney Greenbaum) & Cambridge Grammar of English",
    rules: [
      "SVO word order: Subject → Verb → Object.",
      "Articles: 'a' before consonant sounds (indefinite), 'an' before vowel sounds (indefinite), 'the' for specific or previously mentioned referents, no article for generic plurals or uncountable nouns.",
      "Adjective order before noun (OSASCOMP): Opinion → Size → Age → Shape → Color → Origin → Material → Purpose → Noun.",
      "Subject-verb agreement: third-person singular present adds -s/-es.",
      "Compound adjective for body-part characteristics: use NOUN + -ed, hyphenated before the noun (e.g. 'small-headed', 'blue-eyed', 'long-legged'). NEVER omit the hyphen or the -ed suffix (NOT 'small head dad' → MUST be 'small-headed dad').",
      "Size words: use 'small' for physical size descriptions (dimensions, body parts). Reserve 'little' for informal/emotional tone or small quantity. 小 (xiǎo) in physical descriptions = 'small', not 'little'.",
      "Capitalization: only the first word of a sentence and proper nouns are capitalized. Common nouns and adjectives in the middle of a sentence are lowercase.",
      "Passive voice for edibility/usability questions: when asking if something CAN BE eaten/drunk/used, prefer passive construction ('Is this edible?' / 'Can this be eaten?') over active ('Can someone eat this?').",
      "Topic-comment sentence structure: when the Chinese sentence has a topic followed by a comment (e.g. '[小头爸爸] [这个能吃吗]'), mirror this in English with a comma: '[Small-headed dad,] [is this edible?]' — do NOT merge them into a single clause like 'Is this small-headed dad edible?'.",
      "Choose the most natural English equivalent — avoid literal calques from Chinese. Rephrase into idiomatic English.",
      "Punctuation: sentences end with a period or question mark; yes/no questions use subject-auxiliary inversion.",
    ],
  },
  // ── Japanese grammar, integrated in parts from Tae Kim's Japanese Grammar
  // Guide. Part 1: Writing System + Basic Grammar (guide ch. 2-3). ──────────────
  Japanese: {
    authority: "文化庁 国語施策 (Agency for Cultural Affairs, Language Policy) — bunka.go.jp; reference: Tae Kim's Japanese Grammar Guide",
    rules: [
      // [P1] Writing system (ch. 2)
      "Scripts: write native words and all grammatical parts (particles, okurigana, inflections) in hiragana; write foreign loanwords, foreign names and onomatopoeia in katakana; write content-word roots in kanji where standard. Never spell a native grammatical element in katakana.",
      // [P1] Sentence order (ch. 3.1, 3.5, 3.10)
      "Strict SOV / head-final order: topic は / subject が → indirect object に → direct object を → other complements → predicate. The verb or predicate (incl. state-of-being) MUST be the last element of its clause. A grammatically complete sentence needs only a predicate.",
      "Relative and descriptive clauses come BEFORE the noun they modify, with no relative pronoun (e.g. 魚が好きな人 = 'a person who likes fish'). Build modifiers left of their head noun.",
      // [P1] State-of-being (ch. 3.2)
      "State-of-being for nouns / na-adjectives: non-past plain だ (polite です), negative じゃない／ではない (polite じゃありません／ではありません), past だった (polite でした), past-negative じゃなかった (polite じゃありませんでした). In this app use the polite 丁寧語 (です・ます) register consistently.",
      // [P1] Core particles (ch. 3.3, 3.8, 3.11)
      "Particle roles: は = topic ('as for…', pronounced 'wa'); が = identifier/subject (introduces or specifies new/unknown info, answers who/what); を = direct object; に = target/indirect object/destination/point in time/existence location; へ = direction; で = location of action or means/method; と = 'and'/'with'; の = possession/nominalization; か = question. Pick は vs が by information structure — they are NOT interchangeable.",
      "も = inclusive 'also/too' and REPLACES は/が/を (write トムも, never トムはも). Keep polarity consistent with the clause.",
      "Particles attach directly to the preceding word with no space.",
      // [P1] Adjectives (ch. 3.4)
      "na-adjectives act like nouns: insert な to directly modify a noun (静かな人) and conjugate like nouns (だ／じゃない／だった). i-adjectives end in い, modify a noun directly with NO な, and NEVER take だ. i-adjective negative = drop い + くない (高い→高くない); past = drop い + かった (高かった); past-negative = くなかった.",
      "Irregular: いい and ～いい compounds (かっこいい) conjugate from よい — よくない／よかった／よくなかった. Never produce いくない.",
      // [P1] Nouns & verbs basics (ch. 3.5, 3.6, 3.7)
      "No articles, no grammatical plural, no gender. Verbs split into ru-verbs, u-verbs and the irregulars する/来る; negative plain = ない-form, polite = ません; past plain = た-form, polite = ました. Use counters with native/Sino readings for quantities.",
      // [P2] Essential grammar — polite form, te-form, compounds, conditionals (guide ch. 4.1-4.8)
      "Polite register: build から the ます-stem (買う→買い→買います／買いません／買いました／買いませんでした); use です for noun/adjective predicates. Keep です・ます consistently in this app's output.",
      "te-form chains actions/states; its tense is fixed by the FINAL predicate only. Form it from the past form: verb た→て, だ→で (食べた→食べて, 飲んだ→飲んで, 行った→行って); i-adjective and negatives い→くて (狭い→狭くて, じゃない→じゃなくて, いい→よくて); chain nouns/na-adjectives with で (学生で、先生だ).",
      "Reason/cause: [reason]から[result] — から needs だ after a noun/na-adjective (友達だから). ので is softer and more polite and needs な after a noun/na-adjective (学生なので). 〜のに = 'despite/although', clause + のに with な after noun/na-adjective (学生なのに).",
      "Contrast: が and けど ('but/although') join two clauses as [clause1]が／けど、[clause2]. し lists multiple reasons/qualities ('and on top of that'); 〜たり〜たりする lists representative, non-exhaustive actions and must close with する/した.",
      "Enduring states & te-helpers: 〜ている = ongoing action or a continuing resultant state; 〜てある = resultant state from a deliberate action; 〜ておく = do something in advance/as preparation; motion verbs attach as 〜ていく／〜てくる.",
      "Potential (ability): ru-verb 〜られる, u-verb final -u→-eru (書く→書ける), する→できる, 来る→来られる. The object of a potential verb normally takes が, not を. 見える/聞こえる express spontaneous perception (can naturally see/hear).",
      "なる/する with に: なる = 'become' (noun/na-adj + に + なる: 静かになる; i-adj drops い + く + なる: 高くなる). する = 'make/decide' (noun/na-adj + に + する). Use the correct linker (に vs く).",
      "Conditionals — choose precisely: と = automatic/inevitable natural consequence ('whenever/when'); なら = contextual 'if (that is the case / speaking of)'; ば = general hypothetical 'if'; たら = most general 'when/if', also 'after'. Do not swap one conditional for another.",
      "Questions: polite speech ends with か; casual speech usually drops か with rising intonation or の; embedded questions use 〜か(どうか).",
      // [P3] Essential grammar II — obligation, desire, quotes, giving/receiving, requests (guide ch. 4.9-4.18)
      "Obligation 'must/have to': 〜なければならない／〜なければいけない (formal), casual 〜なきゃ(いけない)／〜ないと(いけない). 'Must not' = 〜てはいけない／〜てはだめ／〜たらだめ.",
      "Permission: 'may / it's OK to' = 〜てもいい(です); 'don't have to' = 〜なくてもいい(です).",
      "Desire: the SPEAKER's want = verb-stem + たい (conjugates like an i-adjective: 食べたい／食べたくない); wanting a THING = 欲しい with the thing marked by が. Do not state a third person's desire with bare たい/欲しい — use 〜たがる／〜たがっている or 〜てほしい.",
      "Volitional ('let's / I shall'): polite 〜ましょう; plain ru-verb 〜よう (食べよう), u-verb final -u→-ou (行こう), する→しよう, 来る→来よう. 〜ようと思う = 'intend to'.",
      "Quoting & defining: direct quote 「…」と言う; reported/embedded thought or speech = plain form + と + 言う/思う; casual contraction って replaces と. AというB = 'B called A'; 〜という defines, quotes or draws a conclusion.",
      "Trying: 〜てみる = 'try doing (to see how it goes)'; volitional + とする = 'attempt/be about to do' (食べようとする).",
      "Giving/receiving — direction is mandatory: あげる = give outward (away from the speaker / in-group); くれる = give inward (toward the speaker / in-group); もらう = receive (subject gets it; the giver is marked に or から). For favours use 〜てあげる／〜てくれる, and ask with 〜てくれる？／〜てもらえる？.",
      "Requests/commands by politeness: polite 〜てください; honorific 〜てくださる; firm-but-polite 〜なさい; plain command (rough: 行け／食べろ); prohibition = dictionary form + な (行くな).",
      "Counters & casual speech: choose the correct counter (〜個／〜人／〜回／〜本／〜枚 …) and 〜目 for ordinals. Casual speech drops particles, contracts (〜ている→〜てる, 〜てしまう→〜ちゃう), and uses sentence-final particles: ね (seeking agreement), よ (informing), よね, な, さ, かい／だい (casual questions). Match register to context.",
      // [P4] Special expressions — causative/passive, keigo, certainty, amounts, similarity (guide ch. 5)
      "Causative & passive: causative ('make/let do') ru→させる, u-verb -u→-aseru (行かせる), する→させる, 来る→来させる; passive ru→られる, u-verb -u→-areru (読まれる); causative-passive ('be made to do') 〜させられる. Passive also conveys suffering or politeness. Mark the agent with に.",
      "Keigo: elevate OTHERS' actions with honorific 尊敬語 (お〜になる or special verbs いらっしゃる／召し上がる／ご覧になる); lower YOUR OWN actions with humble 謙譲語 (お〜する or 致す／いただく／参る／申す). Never apply honorific forms to yourself or humble forms to others; use only when the register calls for it.",
      "〜てしまう = completion/finality or regret ('ended up / unfortunately'); casual 〜ちゃう／〜じゃう.",
      "Generic nouns: こと nominalizes an action/fact ('the act/fact of'), 〜ことがある = experience or occasional occurrence; ところ = moment/abstract place (〜るところ 'about to', 〜たところ 'just did'); もの for tangible things or emphatic/explanatory tone.",
      "Certainty: 〜かもしれない = 'might' (uncertain); 〜でしょう (polite) / 〜だろう = 'probably / I'd say' (fairly certain). Do not overstate certainty beyond the source.",
      "Amounts & limits: だけ = 'only/just'; のみ = formal 'only'; しか + NEGATIVE verb = 'only / nothing but'; 〜ばかり = 'nothing but / just (did)'; 〜すぎる = 'too much'; 〜ほど = extent ('to the point of'); adjective-stem + さ makes a measurable noun (高い→高さ).",
      "Similarity & hearsay (keep distinct): よう(だ)／みたい(だ) = 'seems/looks like' (みたい is casual); stem + そう(だ) = looks/seems like it will happen (visual guess); plain form + そうだ = reported hearsay ('I hear that'); らしい = 'apparently / typical of'; 〜っぽい = casual '-ish'.",
      "Comparison: AはBより〜 = 'A is more … than B'; AよりBのほうが〜 = 'B is more … than A'; use 〜方(ほう) for 'the … one/way'.",
      "Ease/difficulty: verb-stem + やすい = easy to do; + にくい／づらい = hard to do; + がたい = next to impossible to do.",
      "More negatives & states: 〜ずに／〜ないで = 'without doing'; 〜まま = 'leaving (it) as it is / in an unchanged state'; 〜っぱなし = 'left … (ongoing/undone)'; 〜ながら = doing two actions simultaneously.",
      // [P5] Advanced topics — formal forms, expectation, tendencies, literary patterns (guide ch. 6)
      "Formal/written register: である is the formal copula 'is/are' (replaces だ/です in essays/writing), negative ではない; use it only for clearly formal or written sentences.",
      "Expectation/obligation: 〜はず = 'is supposed to / expected to be'; 〜べき(だ) = 'ought to / should do' (proper conduct); 〜べく = 'in order to'; 〜べからず = formal prohibition 'must not'.",
      "Minimum / even: 〜さえ／〜すら = 'even'; 〜さえ〜ば = 'as long as / if only'; 〜はおろか = 'let alone'.",
      "Outward signs & atmosphere: 〜がる = show outward signs of an emotion (use for a third person: 寒がる, 欲しがる); 〜めく = take on the air/signs of (春めく); 〜ばかり(に) = 'as if it might'.",
      "Non-feasibility (formal): 〜ざるを得ない = 'cannot help but / have no choice but to'; やむを得ない = 'unavoidable'; 〜かねる = 'cannot (politely) / be unable to'; 〜かねない = 'might well (turn out badly)'.",
      "Tendencies: 〜がち = 'tends to / prone to' (usually negative); 〜つつ(ある) = 'in the process of'; 〜きらいがある = 'has a (negative) tendency to'.",
      "Covered/full of & literary proximity: 〜だらけ = 'covered/full of (a mess)'; 〜まみれ = 'smeared with'; 〜ずくめ = 'entirely/all'; 〜とたん(に) = 'the instant'; 〜が早いか／〜や否や = 'the moment that'; 〜そばから = 'no sooner … than (repeatedly)'; 〜がてら = 'while also'; 〜あげく(に) = 'after all … (bad outcome)'; 〜と思いきや = 'contrary to expectation'.",
      "Register discipline: reserve these advanced/literary forms for genuinely formal or written contexts; for everyday subtitle/quiz sentences prefer the plain everyday equivalent, and always keep particles and conjugation flawless.",
      "Produce idiomatic Japanese a native speaker would actually say — never a word-for-word calque from Chinese or English.",
    ],
  },
  Korean: {
    authority: "국립국어원 (National Institute of Korean Language) — korean.go.kr",
    rules: [
      "SOV word order: Subject → Object → Verb. The predicate must close the sentence.",
      "Particles must be chosen and attached correctly: 은/는 (topic), 이/가 (subject), 을/를 (object), 에 (static location/time/destination), 에서 (action location/source), 의 (possession, often omitted in speech), 도/만/까지 as meaning requires. Alternate by final consonant (받침): 은/이/을 after consonant, 는/가/를 after vowel.",
      "Speech level: use the polite informal 해요체 (-아요/-어요/-해요) consistently — this is how learning apps and subtitles address users. Do NOT mix 합쇼체 (-습니다) and 해요체 in one sentence.",
      "Questions end in -아요?/-어요?/-나요?/-ㄹ까요? with rising intonation marked only by '?'. No subject-auxiliary inversion exists.",
      "No articles. Use number + native/Sino counter for quantities (한 개, 두 명, 세 번).",
      "Negation: 안 + verb (short) or stem + 지 않다; ability: -(으)ㄹ 수 있다/없다; for 'edible/usable' questions prefer '먹을 수 있어요?' style potential forms.",
      "Honorifics: use -(으)시- when the subject deserves respect (e.g. 아버지가 오세요), and plain forms otherwise. Kinship terms like 아빠/아버지 follow natural family-register usage.",
      "Sino-Korean vs native vocabulary: pick the register a Korean would actually use in conversation (e.g. 'study' = 공부하다, not 학습하다 in casual speech).",
      "Spacing (띄어쓰기) follows 한글 맞춤법: particles attach to the preceding word; dependent nouns and auxiliary verbs are spaced (먹을 수 있다, 가고 싶다).",
      "Produce idiomatic Korean — what a native speaker would naturally say, NOT a literal word-for-word mapping from Chinese or English. Avoid translationese (번역투).",
    ],
  },
  // ── Indonesian grammar, integrated in parts from Djenar, "A Student's Guide
  // to Indonesian Grammar" (Oxford). Standard register (bahasa baku). ──────────
  Indonesian: {
    authority: "Ejaan yang Disempurnakan (EYD) & KBBI (Kamus Besar Bahasa Indonesia); reference: Djenar, A Student's Guide to Indonesian Grammar (Oxford)",
    rules: [
      // [P1] Basics & noun phrases
      "Word order is SVO: Subject → Verb → Object/complement. Verbs do NOT conjugate for tense or person; time is shown by adverbs, not verb endings.",
      "Noun phrases are head-initial: the head noun comes FIRST, then its modifiers — possessor (rumah saya = my house), classifying noun (guru bahasa), adjective (rumah besar = big house), demonstrative (buku ini = this book), or a yang-clause. Never put the adjective before the noun.",
      "'To be': link two nouns with adalah/ialah (formal, often simply omitted: Dia guru = He is a teacher). NEVER use adalah before an adjective or verb (write 'Dia pintar', not 'Dia adalah pintar'). merupakan = 'constitutes/is'.",
      "ada = 'there is/are', 'to be (located) at', and (with punya/mempunyai) 'to have'.",
      "No articles, no grammatical gender. Plural is shown by context or full reduplication (buku-buku); after a number or quantifier do NOT reduplicate (tiga buku, never tiga buku-buku).",
      "Counting: number + classifier + noun. Classifiers: orang (people), ekor (animals), buah (things), batang/helai/biji (long/flat/small). E.g. dua orang guru, tiga ekor kucing, lima buah buku.",
      "Negation: tidak negates verbs/adjectives; bukan negates nouns/pronouns; belum = 'not yet'; jangan = 'don't' (negative imperative). Choose tidak vs bukan correctly by word class.",
      "Question words: apa (what), siapa (who), (di) mana (where), kapan (when), bagaimana (how), mengapa/kenapa (why), berapa (how much/many). Yes/no questions use apakah or rising intonation / clitic -kah.",
      "Pronouns: saya/aku (I), kamu/Anda/kau (you), dia/ia (he/she), kami (we, exclusive), kita (we, inclusive), mereka (they). Possessive enclitics: -ku, -mu, -nya (buku saya = bukuku).",
      "Prepositions: di (at/in — static), ke (to), dari (from), pada/kepada (to a person or time), untuk (for), dengan (with/by means of), oleh (by — passive agent), tentang (about). Do not confuse di (preposition, written separately: di rumah) with the di- passive prefix (attached: dibaca).",
      // [P2] Verb morphology core
      "Most verbs take a prefix; a bare root is mainly imperative or colloquial. Intransitive/stative verbs usually take ber- or meN-; active transitive verbs take meN-, their passive counterpart takes di-.",
      "ber-: forms intransitive/stative verbs — 'to have' (beristri = be married/have a wife), 'to wear/use' (berbaju), or 'to do' the base activity (bekerja, berlari, belajar). Allomorphs: bel- (belajar), be- before an r-initial root (bekerja).",
      "meN- nasalisation by the root's first sound (drop the voiceless initial): me- before l,m,n,r,w,y,ng,ny (melihat); mem- before b,f and p→ (pukul→memukul); men- before d,c,j and t→ (tulis→menulis); meng- before g,h,vowels and k→ (kirim→mengirim, ambil→mengambil); meny- before s→ (sapu→menyapu); menge- before a one-syllable root (cat→mengecat). Apply this nasalisation exactly.",
      "meN- makes active transitive verbs (membaca buku = reads a book) or intransitive activity verbs; the object follows the verb.",
      "di- forms the passive / object-focus (Buku itu dibaca = the book is read); the agent follows as 'oleh + agent'. di- attaches to the verb (never spaced).",
      // [P3] Affix suite
      "-kan suffix makes a verb transitive: causative ('make/cause to be': panas→memanaskan = to heat) or benefactive ('do for someone': beli→membelikan = to buy for). The benefactive's beneficiary becomes the object.",
      "-i suffix makes a transitive verb whose object is a location/goal, often locative or iterative: tanam→menanami (to plant on), pukul→memukuli (to hit repeatedly). Contrast with -kan (menanam jagung di kebun vs menanami kebun dengan jagung).",
      "ter-: non-volitional/accidental (jatuh→terjatuh = fell by accident), resultant state (tertutup = (is) closed), ability, and the superlative on adjectives (besar→terbesar = biggest).",
      "ke-…-an: circumfix for abstract nouns (bebas→kebebasan = freedom), adverse/excessive experiences (hujan→kehujanan = caught in the rain), or some adjectives.",
      "Noun-deriving affixes: peN- = agent/instrument noun with meN- nasalisation (tulis→penulis = writer, bersih→pembersih = cleaner); -an = result/object noun (makan→makanan = food, tulis→tulisan = writing); peN-…-an / per-…-an = process/abstract nouns (didik→pendidikan = education, jalan→perjalanan = journey).",
      // [P4] Voice/focus, yang, -nya, comparison, aspect, reduplication
      "Subject-focus (active meN-) vs object-focus (passive). Object-focus has two patterns: (1) 3rd-person agent → di-verb (+ oleh agent): 'Buku itu dibaca olehnya'; (2) 1st/2nd-person agent → Object + agent-pronoun + BARE root, no di-: 'Buku itu saya baca' (= I read the book). Never use di- with a pronoun agent like saya/kamu.",
      "yang = relative marker 'who/which/that' (orang yang datang = the person who came); also nominalises (yang merah = the red one) and asks 'which one?' (yang mana?).",
      "-nya: 3rd-person possessive (rumahnya = his/her house), definiteness 'the' (bukunya = the book), nominaliser (datangnya), and a politeness/topic device.",
      "Comparison: lebih … daripada (more … than), kurang … daripada (less … than), paling … or ter- (most/-est: paling besar = terbesar), sama … dengan or se- (as … as: setinggi = as tall as).",
      "Tense/aspect via adverbs only (no conjugation): sudah/telah (already), sedang (in progress, '-ing'), akan (will/future), belum (not yet), masih (still), pernah (have ever). Place them before the verb.",
      "Reduplication conveys plurality/variety (anak-anak = children), reciprocity (pukul-memukul), intensity, or a derived sense (jalan→jalan-jalan = to stroll). Do not reduplicate for plural after a numeral/quantifier.",
      // [P5] Connectives, imperatives, reported speech, particles
      "Imperatives: bare root or meN-verb minus prefix (Makan! / Baca buku ini!); soften with -lah (Duduklah), tolong/coba/silakan (please/go ahead), mari/ayo (let's). Negative command = jangan + verb. Polite request = tolong/minta + verb.",
      "Connectives — reason: karena/sebab (because), gara-gara (because of, often negative), oleh karena itu/maka (therefore). Condition: kalau/jika/bila/apabila (if), seandainya/andai (if only); 'kalau … maka …' (if … then). Time: ketika/waktu/saat (when), sambil/sementara (while), setelah/sesudah (after), sebelum (before), selama (during), sejak (since).",
      "Concession/contrast: meskipun/walaupun/biarpun (although), tetapi/tapi (but), namun (however), sedangkan (whereas), 'bukan … melainkan …' / 'tidak … tetapi …' (not … but). Coordination/focus particles: dan (and), atau (or), 'baik … maupun …' (both … and), juga (also), saja (just/only), pun (even), clitics -lah (emphasis) and -kah (question).",
      "Reported speech: introduce indirect reports with bahwa (Dia berkata bahwa …); 'say' verbs = bilang (colloquial), berkata/mengatakan (formal), menurut (according to). There is NO tense backshift.",
      "Indefinites combine a question word with -pun/saja or reduplication: apa-apa / apa pun (anything), siapa-siapa / siapa pun (anyone), di mana-mana (everywhere), ke mana-mana (anywhere); with negation = 'not anything/anyone' (tidak apa-apa = it's nothing / never mind).",
      "Colloquial causatives bikin/buat ('make/cause') are common alongside -kan (bikin marah = make angry); colloquial registers drop meN- and use -in for -kan/-i (bikinin, beliin) — but for neutral subtitle/quiz sentences keep standard baku affixation.",
      "Produce natural, idiomatic standard Indonesian (bahasa baku) with correct affixation and prefix nasalisation — never a word-for-word calque from Chinese or English.",
    ],
  },
  // ── Vietnamese grammar, integrated in parts. Reference: Emeneau, Studies in
  // Vietnamese (Annamese) Grammar (UC Press); modern standard Vietnamese. ──────
  Vietnamese: {
    authority: "Standard Vietnamese (chữ Quốc ngữ) orthography & usage; reference: Emeneau, Studies in Vietnamese (Annamese) Grammar",
    rules: [
      // [P1] Isolating typology & word order
      "Vietnamese is isolating/analytic: words NEVER inflect — no conjugation, no plural endings, no case, no gender, no articles. Grammatical relations come from word order and function words only.",
      "SVO word order: Subject → Verb → Object (Tôi ăn cơm = I eat rice).",
      "Noun phrase is HEAD-INITIAL: head noun first, then modifiers in order — (number) + classifier + NOUN + adjective + possessor + demonstrative. E.g. 'con mèo đen này' = 'this black cat' (lit. CL cat black this); possession = noun + của + owner (or noun + owner): 'nhà của tôi' / 'nhà tôi' = my house.",
      "Diacritics and tone marks are MANDATORY and meaning-distinguishing (ma/má/mà/mả/mã/mạ). Always write full Vietnamese orthography with correct tones (à á ả ã ạ, â ê ô ơ ư, đ).",
      // [P2] Classifiers, copula, plural, negation
      "Classifiers are obligatory between a number/demonstrative and a noun: number + classifier + noun ('ba con chó' = three dogs; 'cái này' = this one). Common classifiers: cái (inanimate), con (animals & some objects), người (people), quyển/cuốn (books), chiếc (vehicles/single items), tờ (sheets), bài (lessons/songs). Pick the right classifier.",
      "Copula là links two NOUNS ('to be'): 'Tôi là sinh viên'. NEVER use là before an adjective — adjectives are stative verbs: 'Tôi mệt' (I am tired), not 'Tôi là mệt'. Use là only noun↔noun (and với 'không phải (là)' to negate a noun).",
      "Plurality is optional via những / các before the noun ('những cuốn sách', 'các bạn'); never add a plural marker after a number.",
      "Negation: không (not — before verb/adjective), chưa (not yet), đừng (don't — negative imperative), chẳng (emphatic not), 'không phải (là)' (negates a noun). Choose by what is negated.",
      // [P3] Tense/aspect, pronouns, questions
      "Tense/aspect via preverbal markers only (no conjugation): đã (past/completed), đang (progressive '-ing'), sẽ (future), vừa/mới (just/recently), sắp (about to), từng (used to); sentence-final 'rồi' = already/done; chưa = not yet.",
      "Pronouns are kinship/age/status based — choose by the relationship. Neutral: tôi (I), bạn (you). Age/gender terms double as I and you: anh (older male), chị (older female), em (younger), ông/bà (elder, respectful). Third person adds ấy: anh ấy/chị ấy/cô ấy (he/she), họ (they), nó (it / informal he-she). Do not use a single fixed 'you/he'.",
      "Question words stay IN SITU (no fronting): ai (who), gì (what), đâu (where), nào (which), bao giờ/khi nào (when — before the verb = future, after = past), tại sao/sao (why), thế nào (how), bao nhiêu/mấy (how many). Yes/no questions: 'có … không?', '… phải không?', 'đã … chưa?'; confirmation particles à, hả, nhỉ.",
      // [P4] Modification, comparison, serial verbs
      "An adjective FOLLOWS its noun and is itself a stative verb in the predicate (no copula): 'áo đỏ' = a red shirt; 'Áo đỏ.' = The shirt is red. Degree words: rất (very, BEFORE the adjective: rất đẹp), lắm/quá (very, AFTER: đẹp lắm/đẹp quá), hơi (a bit), khá (fairly).",
      "Comparison: 'A [adj] hơn B' = A is more … than B ('Tôi cao hơn anh ấy'); '[adj] nhất' = the most …; 'bằng'/'như' = as … as; 'càng … càng …' = the more … the more.",
      "Relative/attributive clauses FOLLOW the noun, optionally introduced by 'mà': 'người (mà) tôi gặp' = the person (that) I met. Serial verb constructions share the subject ('đi mua' = go buy); directional/resultative complements follow the verb: ra (out), vào (in), lên (up), xuống (down), về (back), đi (away).",
      // [P5] Function words, voice, particles, register
      "Voice with bị / được: 'bị' = adverse passive ('bị phạt' = got punished); 'được' = favourable passive / 'get to' ('được khen' = be praised) and postverbal ability ('làm được' = can do). Modals: có thể (can/may), phải (must), nên (should), cần (need).",
      "Existence/possession: 'có' = have / there is ('Tôi có sách'; 'Có người ở đây'). Connectives: vì/bởi vì (because), nên/cho nên (therefore), 'nếu … thì …' (if … then), 'tuy/mặc dù … nhưng …' (although … but), để (in order to), và (and), hoặc/hay (or), nhưng (but).",
      "Sentence-final particles set politeness/mood: ạ (polite/respectful), nhé/nha (friendly suggestion), đi (urging: 'ăn đi' = eat!), thôi, mà, đấy/đó, vậy. Match register to context; for neutral subtitle/quiz sentences keep it polite-neutral.",
      // [P6] Finer points
      "Topic-comment fronting is idiomatic: a topic may be set off with thì or là ('Cái này thì đắt' = 'As for this, it's expensive'; 'Tôi thì không biết'). 'mà' links a surprising/contrastive comment or a relative clause.",
      "Result/direction complements after the verb carry aspect/outcome: được (manage to / favourable), mất (lose/cost), phải (end up with something adverse), xong (finish), ra/thấy (figure out/perceive): làm xong (finish doing), tìm được (manage to find), nhìn thấy (catch sight of).",
      "Reduplication (từ láy) softens or intensifies and is very common: đẹp→đẹp đẽ, vui→vui vẻ, nhỏ→nho nhỏ (a bit small), đỏ→đo đỏ (reddish). Use established reduplicated forms rather than inventing them.",
      "Numbers have special sandhi forms: 'một' after a ten becomes mốt (hai mươi mốt = 21), 'bốn' often → tư (mười tư = 14; thứ tư = fourth), 'năm' after a ten → lăm (hai mươi lăm = 25); 'mười' (10) → mươi after a multiplier (ba mươi = 30). Ordinals = thứ + number (thứ nhất, thứ hai, thứ ba).",
      "Produce natural standard Vietnamese with correct diacritics/tones, correct classifiers and head-initial word order — never a word-for-word calque from Chinese or English.",
    ],
  },
  // ── Thai grammar, integrated in parts. Reference: Noss, Thai Reference
  // Grammar (FSI, 1964); modern standard (Central) Thai. ──────────────────────
  Thai: {
    authority: "Standard (Central) Thai orthography & usage in Thai script (อักษรไทย); reference: Noss, Thai Reference Grammar (FSI)",
    rules: [
      // [P1] Script, isolating typology, word order
      "Always write in Thai script (อักษรไทย) only — NEVER romanization/transliteration. Thai is normally written with NO spaces between words; use spaces only between clauses/phrases as a Thai writer would, and never insert a space inside a single word.",
      "Thai is isolating/analytic: words NEVER inflect — no conjugation, no plural endings, no case, no gender, no articles, no agreement. Grammatical relations come from word order and function words only.",
      "Basic word order is SVO: Subject → Verb → Object (ฉันกินข้าว = I eat rice). Topic-comment fronting is common in natural Thai.",
      "Noun phrase is HEAD-INITIAL: head noun first, then modifiers — NOUN + adjective + demonstrative, and for counting NOUN + number + classifier. E.g. แมวดำตัวนี้ = this black cat (lit. cat black CL this).",
      // [P2] Classifiers, copula, plural, adjectives
      "Classifiers (ลักษณนาม) are obligatory when counting or specifying: NOUN + NUMBER + CLASSIFIER (หนังสือสามเล่ม = three books; คนสองคน = two people). With a demonstrative: NOUN + CLASSIFIER + นี้/นั้น (รถคันนี้ = this car). Common classifiers: คน (people), ตัว (animals/clothing/furniture), อัน (small things), เล่ม (books), คัน (vehicles), ใบ (containers/leaves/sheets), ลูก (round things/fruit), แผ่น (flat sheets), อย่าง (kinds). Pick the correct classifier.",
      "Copula เป็น / คือ links NOUNS ('to be'): เขาเป็นครู = he is a teacher; คือ is identificational/definitional. NEVER use เป็น/คือ before an adjective — Thai adjectives are stative verbs used directly: เขาเหนื่อย = he is tired (NOT เขาเป็นเหนื่อย).",
      "An adjective FOLLOWS its noun and acts as a stative verb in the predicate with no copula: เสื้อแดง = a red shirt; เสื้อแดง (as a sentence) = the shirt is red. Degree: มาก (very, AFTER the adjective: สวยมาก), ที่สุด (most: สวยที่สุด), ค่อนข้าง (rather), นิดหน่อย (a little), เกินไป (too…).",
      "Plurality is unmarked; number/quantity is shown by context, numbers+classifiers, or words like หลาย (several), บาง (some), ทุก (every), พวก (group/plural marker for people: พวกเขา = they). Never add a plural ending to a noun.",
      // [P3] Tense/aspect, negation, pronouns
      "No tense conjugation — time is shown by context or aspect/time words: แล้ว (already/completed, sentence-final), กำลัง…(อยู่) (progressive '-ing'), จะ (future/irrealis, preverbal), เพิ่ง (just recently), กำลังจะ (about to), เคย (have ever / used to), ยัง (still / not yet with negation).",
      "Negation: ไม่ (not — before verb/adjective: ไม่กิน, ไม่สวย), ยังไม่ (not yet), ไม่ได้ + verb (did not / negates past action), อย่า (don't — negative imperative), ไม่ใช่ (negates a noun: ไม่ใช่ครู = is not a teacher). Choose by what is negated.",
      "Pronouns depend on politeness, gender and relationship — choose appropriately. Neutral/polite: ฉัน or ผม (I — ผม male, ดิฉัน formal female), คุณ (you, polite), เขา (he/she), เธอ (she / informal you), พวกเขา (they), มัน (it / informal), เรา (we / casual I). Avoid one fixed 'you/he' regardless of context.",
      // [P4] Questions, comparison, modifiers
      "Question words stay IN SITU (no fronting): ใคร (who), อะไร (what), ที่ไหน (where), อันไหน/ไหน (which), เมื่อไหร่ (when), ทำไม (why), อย่างไร/ยังไง (how), เท่าไหร่ (how much), กี่ + classifier (how many). Yes/no questions use sentence-final ไหม or …หรือเปล่า; confirmation with ใช่ไหม, นะ, หรือ.",
      "Comparison: 'A + adj + กว่า + B' = A is more … than B (เขาสูงกว่าฉัน = he is taller than me); adj + ที่สุด = the most …; เท่ากับ/…เท่ากัน = as … as; ยิ่ง…ยิ่ง… = the more … the more.",
      "Relative/attributive clauses FOLLOW the noun, introduced by ที่ / ซึ่ง / อัน: คนที่ฉันพบ = the person (that) I met. Possession = NOUN + ของ + owner (บ้านของฉัน) or simply NOUN + owner (บ้านฉัน) = my house.",
      // [P5] Function words, voice, particles, register
      "Voice/causation: ถูก marks the adverse passive (ถูกลงโทษ = got punished); ได้รับ marks a neutral/favourable passive (ได้รับคำชม = was praised); ทำให้ = cause to / make; ให้ = give / let / for. Postverbal ได้ = can / be able (ทำได้ = can do).",
      "Modals/auxiliaries (preverbal unless noted): สามารถ…ได้ (can/be able), ต้อง (must), ควร (should), อยาก (want to), ชอบ (like to), คง/น่าจะ (probably). Existence/possession: มี = have / there is (ฉันมีหนังสือ; มีคนอยู่ที่นี่).",
      "Connectives: เพราะ/เพราะว่า (because), เลย/ดังนั้น/จึง (therefore — จึง goes before the verb), ถ้า…ก็… (if … then), แม้ว่า/ถึงแม้ว่า…แต่… (although … but), เพื่อ (in order to), และ (and), หรือ (or), แต่ (but), เวลา/ตอน (when/while).",
      "Polite particles are sentence-final and gender-based: ครับ (male speaker, polite/affirmative) and ค่ะ/คะ (female speaker — ค่ะ for statements, คะ for questions). Use them for polite register; other particles: นะ (softening), สิ (urging), หรอก, ล่ะ. For neutral quiz/subtitle sentences keep a polite-neutral tone consistently.",
      // [P6] Finer points
      "Serial verbs and directionals are pervasive: stack verbs in sequence (ไปซื้อ = go buy, เดินเข้าไป = walk in). Directional/result complements follow the verb: ไป (away), มา (toward speaker), ขึ้น (up), ลง (down), เข้า (in), ออก (out), ได้ (can/manage), เสร็จ (finish): ทำเสร็จ (finish doing), หาเจอ (manage to find).",
      "ก็ resumes the topic / links 'then/also/so' (ถ้าฝนตก ฉันก็จะอยู่บ้าน = if it rains, then I'll stay home). Topic-comment fronting is idiomatic; เรื่อง…/สำหรับ… sets a topic.",
      "อยู่ after a verb marks ongoing action (กำลัง…อยู่), while อยู่ alone = 'to be located'. ไว้ marks doing something in advance/for later (เก็บไว้ = keep it); เลย = 'right away / as a result'.",
      "Reduplication with the ๆ mark pluralizes/intensifies or softens (เด็ก ๆ = children, ช้า ๆ = slowly, ใหญ่ ๆ = quite big); some pairs change tone for emphasis. Use established forms.",
      "Pronouns are often dropped when clear from context, and people commonly use their own name, kinship terms (พี่ older sibling, น้อง younger, ผม/หนู) or titles instead of 'I/you' — choose by age/status/politeness rather than a fixed pronoun.",
      "Produce natural standard Thai in Thai script with correct classifiers, head-initial word order and appropriate function words — never a word-for-word calque from Chinese or English, and never romanized.",
    ],
  },
  // ── Russian grammar, integrated in parts. Reference: Wade, A Comprehensive
  // Russian Grammar (Wiley-Blackwell, 3rd ed.); modern standard Russian. ───────
  Russian: {
    authority: "Standard Russian orthography & usage in Cyrillic; reference: Terence Wade, A Comprehensive Russian Grammar (Wiley-Blackwell)",
    rules: [
      // [P1] Script, typology, gender, number
      "Write ONLY in Cyrillic (русский алфавит) — NEVER romanization/transliteration. Use ё where it is pronounced (ёлка, всё) only when needed for clarity; otherwise standard orthography. Capitalize only the first word of a sentence and proper nouns — NOT nationalities/languages/months/days (русский, январь, понедельник are lowercase).",
      "Russian is a fusional, heavily INFLECTED language: every noun, pronoun, adjective, numeral and past-tense verb changes its ending for grammatical role. Get the ENDINGS right — a wrong ending is a grammatical error even if the stem is correct.",
      "Every noun has a GENDER — masculine (consonant or -й: стол, музей), feminine (-а/-я: книга, неделя), or neuter (-о/-е: окно, море); most -ь nouns are feminine (ночь) but some are masculine (день, словарь). Gender drives ALL agreement (adjectives, past-tense verbs, pronouns).",
      "NUMBER: singular vs plural; plural nominative is typically -ы/-и (столы, книги) or -а/-я for many neuters/some masculines (окна, города). After numbers, use the special quantitative forms (see numerals).",
      // [P2] The six cases — the core of Russian
      "Russian has SIX CASES; choose the case by the word's role and any governing preposition/verb. NOMINATIVE = subject and predicate noun (Студент читает). ACCUSATIVE = direct object (Я читаю книгу); for masculine animate & all animate plurals, accusative = genitive (Я вижу студента/студентов). GENITIVE = possession/'of', after negation of existence (нет времени), after quantity words and 2-4/5+ numerals, after many prepositions (без, для, до, из, от, с 'from', у, около, после). DATIVE = indirect object 'to/for' (Я дал другу книгу), with к, по, and impersonal subjects (мне нравится, ему холодно, нужно/надо). INSTRUMENTAL = 'by/with' a means (писать ручкой), with с 'together with', after быть/стать in the past/future (был врачом), and prepositions с, над, под, перед, между, за. PREPOSITIONAL (locative) = ONLY after о/об (about), в/на (location 'in/at'), при (Я думаю о тебе; в Москве; на работе).",
      "Adjectives AGREE with their noun in gender, number AND case. Hard endings: m -ый/-ой, f -ая, n -ое, pl -ые (новый дом, новая книга, новое окно, новые дома); they decline through all six cases (нового, новому, новым, о новом…). Spelling rules: after г/к/х/ж/ч/ш/щ write -ий not -ый, и not ы (русский, хорошие); after sibilants unstressed о→е (хорошее).",
      "The past tense agrees in GENDER and NUMBER with the subject (not person): он читал, она читала, оно читало, они читали. The verb 'to be' (быть) is normally OMITTED in the present (Он студент = He is a student), but appears as был/была/было/были (past) and буду/будешь… (future).",
      // [P3] Verb conjugation, aspect
      "Present/future-tense verbs conjugate for PERSON and NUMBER in two patterns. 1st conjugation (-е-): я читаю, ты читаешь, он читает, мы читаем, вы читаете, они читают. 2nd conjugation (-и-): я говорю, ты говоришь, он говорит, мы говорим, вы говорите, они говорят. Watch consonant mutations (любить→люблю, видеть→вижу).",
      "ASPECT is obligatory and central. Every action is either IMPERFECTIVE (process, repetition, general fact: читать, писать, делать) or PERFECTIVE (a single completed whole/result: прочитать, написать, сделать). Imperfective has present (читаю), past (читал) and compound future (буду читать). Perfective has NO present — its present-form endings express the FUTURE (прочитаю = I will read [and finish]); plus past (прочитал). Pick the aspect the meaning requires; do not default to one.",
      "Negation: не before the negated word (Я не знаю; не сегодня). Genitive of negation for non-existence: нет/не было/не будет + GENITIVE (Здесь нет воды; У меня нет времени). Double negation is REQUIRED: никто не знает, ничего не вижу, никогда не был (the ни-word AND не together).",
      // [P4] Pronouns, prepositions+case, comparison
      "Personal pronouns decline: я/меня/мне/мной, ты/тебя/тебе/тобой, он/его/ему/им, она/её/ей, мы/нас/нам/нами, вы/вас/вам/вами, они/их/им/ими; after a preposition 3rd-person adds н- (у него, с ней, о них). Possessives мой/твой/наш/ваш agree like adjectives; его/её/их are invariable. Use вы for polite/plural 'you', ты for informal singular.",
      "Each preposition GOVERNS a fixed case (and в/на/за/под govern accusative for motion-into, prepositional/instrumental for static location): в/на + prepositional = location (в городе), + accusative = direction (в город); у/без/для/до/от/из/с('from')/около/после + genitive; к/по + dative; с('with')/над/под/перед/между + instrumental; о/при + prepositional. Choosing the wrong case after a preposition is an error.",
      "Comparatives: simple form usually -ее/-ей (быстрее, новее), some irregular (лучше, хуже, больше, меньше, старше, моложе); 'than' = чем + nominative OR the genitive without чем (Он старше меня = Он старше, чем я). Superlative = самый + adjective (самый большой) or -ейший/-айший.",
      // [P5] Verbs of motion, reflexives, word order, numerals
      "VERBS OF MOTION come in pairs: unidirectional (one trip/in progress: идти, ехать, бежать, лететь) vs multidirectional (habitual/round trips/general ability: ходить, ездить, бегать, летать). 'Go' on foot = идти/ходить, by vehicle = ехать/ездить. Prefixes add direction and perfectivize: при- (arrive), у- (leave), в-/во- (enter), вы- (exit), по- (set off).",
      "Reflexive verbs end in -ся/-сь (учиться, находиться, нравиться, заниматься); -ся after a consonant, -сь after a vowel (я учусь, он учится). They cover true reflexive, reciprocal, passive and many intransitives. Note the dative construction нравиться: Мне нравится книга (lit. 'to me is-pleasing the book').",
      "Word order is relatively FREE (information structure: given→new, the new/focused element tends to come last) but the неутральный default is SVO (Студент читает книгу). Because case marking shows roles, order can shift for emphasis without ambiguity; keep adjectives BEFORE their noun and keep prepositions with their governed noun.",
      "Numerals govern case: один/одна/одно agrees like an adjective (одна книга); 2/3/4 (and compounds ending in them) take GENITIVE SINGULAR (два студента, три книги, двадцать два года); 5 and above (and 0, много, несколько) take GENITIVE PLURAL (пять студентов, много книг, шесть лет). The whole numeral phrase itself declines in oblique cases.",
      "Produce natural standard Russian in Cyrillic with correct case, gender/number agreement, aspect and verb government — never a word-for-word calque from Chinese or English, and never romanized.",
    ],
  },
  // ── Spanish grammar, integrated in parts. Reference: Nissenberg, Practice
  // Makes Perfect: Complete Spanish Grammar (McGraw-Hill); neutral modern
  // standard Spanish. ─────────────────────────────────────────────────────────
  Spanish: {
    authority: "Standard (neutral) Spanish orthography & usage; reference: Nissenberg, Complete Spanish Grammar (McGraw-Hill)",
    rules: [
      // [P1] Orthography, gender, number, articles
      "Use full Spanish orthography: written accents (á é í ó ú), ñ, ü, and BOTH question/exclamation marks ¿…? ¡…! Lowercase nationalities, languages, months and days (español, lunes, enero).",
      "Every noun has GENDER: masculine (usually -o: el libro) or feminine (usually -a/-ción/-dad: la casa, la canción, la ciudad), with exceptions (el día, el problema, el mapa; la mano, la foto). Articles and adjectives MUST agree.",
      "Articles: definite el/la/los/las, indefinite un/una/unos/unas; a+el→al, de+el→del. Spanish uses the definite article more than English (with abstractions, generic plurals, languages, body parts, titles, days, telling time: los gatos, el español, los lunes, las ocho).",
      "Number/agreement: plural -s after a vowel (libros), -es after a consonant (ciudades); adjectives agree in gender AND number (la casa blanca, los coches rojos). Descriptive adjectives normally FOLLOW the noun; a few (bueno→buen, grande→gran, primero→primer) shorten before a masculine singular noun.",
      // [P2] ser vs estar, the two 'to be'
      "TWO verbs 'to be'. SER = identity, origin, profession, inherent/defining traits, possession, time/date, what something is made of (Soy profesor; Ella es alta; Es de Madrid; Son las dos). ESTAR = location, temporary states/conditions, results, and the progressive (Estoy cansado; Está en casa; Estamos comiendo). Some adjectives change meaning: ser aburrido (boring) vs estar aburrido (bored); ser listo (clever) vs estar listo (ready). Choose ser/estar correctly — it is a core distinction.",
      "hay (from haber) = 'there is/there are' for existence (Hay un libro; Hay dos gatos) — invariable, NOT estar.",
      // [P3] Present & verb conjugation, stem changes, reflexives
      "Verbs conjugate by person/number in three classes (-ar, -er, -ir). Present: hablar→hablo, hablas, habla, hablamos, habláis, hablan; comer→como, comes, come, comemos, coméis, comen; vivir→vivo, vives, vive, vivimos, vivís, viven. The ending already shows the subject, so SUBJECT PRONOUNS are usually OMITTED (use them only for contrast/emphasis).",
      "Stem-changing verbs in the present: e→ie (pensar→pienso, querer→quiero), o→ue (poder→puedo, dormir→duermo), e→i (pedir→pido) in all forms except nosotros/vosotros. Many verbs are irregular in 'yo' (tener→tengo, hacer→hago, salir→salgo, conocer→conozco).",
      "Reflexive verbs use pronouns me/te/se/nos/os/se (levantarse→me levanto, se llama). They cover true reflexives, reciprocals (se quieren), and 'become' (ponerse, volverse, hacerse). 'gustar'-type verbs invert: the thing liked is the subject and the experiencer is an indirect object — Me gusta el café; Me gustan los libros; A ella le gusta (also: encantar, faltar, doler, parecer).",
      // [P4] Past, future/conditional, compound, progressive
      "Two simple past tenses, chosen by aspect: PRETERITE = a completed, bounded action/event (Ayer comí; Llegó a las dos; Fui al cine) — irregulars: fui, hice, tuve, estuve, dije. IMPERFECT = ongoing/habitual/background, descriptions, time & age in the past (Comía todos los días; Era alto; Eran las tres; De niño jugaba). Pick preterite vs imperfect by meaning — this is a key contrast.",
      "Future and conditional add endings to the WHOLE infinitive: future -é/-ás/-á/-emos/-éis/-án (hablaré), conditional -ía/-ías/-ía/-íamos/-íais/-ían (hablaría); shared irregular stems (tendr-, har-, dir-, podr-, saldr-). Common alternative future: ir a + infinitive (Voy a comer). The future/conditional can also express probability (Serán las cinco = It must be five).",
      "Compound tenses = haber (he/has/ha/hemos/habéis/han; past había…) + past participle (-ado/-ido; irregulars hecho, dicho, visto, escrito, puesto, vuelto): present perfect (He comido), pluperfect (Había comido). The participle here is INVARIABLE. Progressive = estar + gerund (-ando/-iendo): Estoy comiendo.",
      // [P5] Subjunctive, commands, negation
      "The SUBJUNCTIVE is required in dependent clauses after expressions of wish/influence, emotion, doubt/denial, and impersonal value, with a different subject and 'que': Quiero que vengas; Espero que estés bien; Dudo que sea verdad; Es importante que estudies. Present subjunctive flips the vowel (hablar→hable, comer→coma). Also after certain conjunctions (para que, antes de que, cuando + future event, aunque) and contrary-to-fact 'si' clauses (Si tuviera dinero, viajaría — imperfect subjunctive + conditional).",
      "Commands (imperative): affirmative tú = 3rd-person present (¡Habla! ¡Come!) with irregulars (di, haz, ve, pon, sal, sé, ten, ven); usted/ustedes and ALL negative commands use the subjunctive (hable, no hables, coman, no coman). Object/reflexive pronouns ATTACH to affirmative commands (dímelo, levántate) but go BEFORE negative ones (no me lo digas).",
      "Negation: place no before the verb (No hablo). Spanish uses DOUBLE negation: no … nada/nadie/nunca/ninguno/tampoco (No veo nada; No viene nadie; No voy nunca) — unless the negative word precedes the verb (Nadie viene; Nunca voy).",
      // [P6] Pronouns, por/para, comparison, relatives
      "Object pronouns precede the conjugated verb but may attach to an infinitive/gerund/affirmative command: direct me/te/lo/la/nos/os/los/las, indirect me/te/le/nos/os/les. With two pronouns the order is INDIRECT then DIRECT, and le/les→se before lo/la/los/las (Se lo di, not 'le lo di'). The 'personal a' marks a specific human direct object (Veo a María).",
      "por vs para: para = purpose/goal, recipient, destination, deadline (Es para ti; Estudio para aprender; Salgo para Madrid; para el lunes); por = cause/reason, exchange, duration, 'through/along', means, 'by' in the passive (Gracias por todo; por la mañana; pagué diez euros por esto; por el parque). Choose correctly.",
      "Comparison: más/menos … que (más alto que), de instead of que before a number (más de diez); equality tan + adj + como, tanto/-a/-os/-as + noun + como. Irregulars: mejor, peor, mayor, menor. Superlative: el/la más … (de) (el más alto de la clase); absolute -ísimo (carísimo).",
      "Relatives & connectors: que (that/which/who, most common), quien/quienes (who, after prepositions/with commas), el que/el cual (clarity/after prepositions), lo que (that which/what), cuyo/-a (whose, agrees with the thing possessed). Common conjunctions: porque (because), aunque (although), pero/sino (but — sino after a negative), si (if), cuando (when), mientras (while).",
      "Produce natural, idiomatic standard Spanish with correct gender/number agreement, ser/estar, the right past aspect, mood (indicative vs subjunctive) and accents/¿¡ — never a word-for-word calque from Chinese or English.",
    ],
  },
  // ── Portuguese grammar, integrated in parts. Reference: Celegatti Althoff,
  // Portuguese Grammar; neutral modern Brazilian Portuguese. ──────────────────
  Portuguese: {
    authority: "Standard Brazilian Portuguese orthography & usage (Acordo Ortográfico); reference: Celegatti Althoff, Portuguese Grammar",
    rules: [
      // [P1] Orthography, gender, number, articles & contractions
      "Use full Portuguese orthography: accents (á â ã, é ê, í, ó ô õ, ú), cedilha (ç) and the nasal vowels ã/õ and -ão. Lowercase nationalities, languages, months and days (português, segunda-feira, janeiro). Write neutral Brazilian Portuguese.",
      "Every noun has GENDER: masculine (usually -o: o livro) or feminine (usually -a, -ção, -dade, -gem: a casa, a informação, a cidade, a viagem), with exceptions (o problema, o dia, o mapa). Articles and adjectives MUST agree.",
      "Articles: definite o/a/os/as, indefinite um/uma/uns/umas. Portuguese uses the definite article a lot — often even before possessives and people's names (o meu carro, a Maria). Adjectives normally FOLLOW the noun (uma casa branca, os carros vermelhos) and agree in gender and number.",
      "Prepositions CONTRACT with following articles/demonstratives (mandatory): de+o=do, de+a=da, em+o=no, em+a=na, a+o=ao, a+a=à, por+o=pelo, por+a=pela; de+este=deste, em+esse=nesse, de+isso=disso. Always use the contracted form.",
      // [P2] ser / estar / ficar / ter; haver
      "Multiple 'to be'. SER = identity, origin, profession, inherent traits, time/date (Eu sou professor; Ela é alta; É de São Paulo; São duas horas). ESTAR = location, temporary states, results, progressive (Estou cansado; Está em casa; Estou comendo). FICAR = become / be located / stay (Ela ficou feliz; A loja fica aqui). Choose correctly.",
      "Possession is TER ('to have'): Eu tenho um livro. Existence = TER in colloquial Brazilian Portuguese (Tem um livro na mesa) or haver in formal register (Há um livro). Use ter for the spoken/neutral register.",
      // [P3] Present, conjugation, pronouns, você/a gente
      "Verbs conjugate by person/number in three classes (-ar, -er, -ir). Present: falar→falo, fala, falamos, falam; comer→como, come, comemos, comem; partir→parto, parte, partimos, partem. Subject pronouns are often kept in Brazilian Portuguese but can be dropped.",
      "Subject pronouns: eu, você (you, sing. — takes 3rd-person verb), ele/ela, nós, vocês (you, pl.), eles/elas. 'a gente' = 'we' colloquially and takes a SINGULAR (3rd-person) verb: A gente vai (= we go). Avoid European 'tu' forms in neutral Brazilian text; use você.",
      "Object pronouns: direct me/te/o/a/nos/os/as, indirect me/te/lhe/nos/lhes. In Brazilian Portuguese, proclisis (pronoun BEFORE the verb) is the natural default (Eu te amo; Ele me viu); colloquially a stressed pronoun often replaces 3rd-person o/a (Eu vi ele). gostar requires the preposition DE: Eu gosto de café; Ela gosta de você.",
      // [P4] Past, future/conditional, compound, progressive, infinitive
      "Two simple past tenses by aspect: PRETÉRITO PERFEITO = a completed past action (Ontem comi; Ele chegou; Eu fui ao cinema) — irregulars fui, fiz, tive, estive, disse. PRETÉRITO IMPERFEITO = ongoing/habitual/background, descriptions, time & age in the past (Eu comia todo dia; Ele era alto; Eram três horas). Choose by meaning.",
      "Future commonly = ir (presente) + infinitive (Vou comer); simple future falarei/comerá is more formal. Conditional (futuro do pretérito) = falaria/comeria (would). Compound tenses use TER + past participle (-ado/-ido; irregulars feito, dito, visto, escrito, posto): pretérito perfeito composto 'tenho comido' (repeated/ongoing up to now, NOT a one-off), mais-que-perfeito 'tinha comido'. Progressive (Brazil) = estar + GERÚNDIO -ndo (Estou comendo); (Europe) estar a + infinitive.",
      "Portuguese has a PERSONAL (inflected) INFINITIVE — the infinitive takes endings for its own subject: -/-es/-/-mos/-em (para eu falar, para eles falarem; É melhor vocês irem). Use it when the infinitive has its own subject, especially after prepositions (antes de saírem, para fazermos).",
      // [P5] Subjunctive (incl. future subjunctive), commands, negation
      "The SUBJUNCTIVE (subjuntivo) is required in dependent 'que' clauses after wish/influence, emotion, doubt/denial and impersonal value (Quero que você venha; Espero que esteja bem; Duvido que seja verdade; É importante que estude). Present subjunctive flips the vowel (falar→fale, comer→coma). Portuguese also has a FUTURE SUBJUNCTIVE used after quando/se/assim que for future events (Quando eu chegar…; Se você quiser…; Assim que ele puder…) and an imperfect subjunctive for contrary-to-fact (Se eu tivesse dinheiro, viajaria).",
      "Commands: affirmative você uses the subjunctive form (Fale!, Coma!, Venha!); all negative commands use the subjunctive (Não fale, Não coma). For 'let's', use Vamos + infinitive (Vamos comer).",
      "Negation: não before the verb (Não falo). Portuguese uses DOUBLE negation: não … nada/ninguém/nunca/nenhum (Não vejo nada; Não vem ninguém; Nunca fui) — if the negative word precedes the verb, drop the first não (Ninguém veio; Nunca vou).",
      // [P6] Comparison, relatives, por/para, questions
      "Comparison: mais/menos … (do) que (mais alto do que / mais alto que); equality tão + adj + quanto/como, tanto/-a/-os/-as + noun + quanto. Irregulars: melhor, pior, maior, menor. Superlative: o/a mais … (de) (o mais alto da turma); absolute -íssimo (caríssimo).",
      "por vs para: para = purpose/goal, recipient, destination, deadline (É para você; Estudo para aprender; Vou para São Paulo; para segunda); por (and its contractions pelo/pela) = cause/reason, exchange, duration, 'through/along', means, agent (Obrigado por tudo; de manhã→pela manhã; paguei dez reais por isto; pelo parque). Choose correctly.",
      "Relatives & connectors: que (that/which/who, most common), quem (who, after prepositions), o qual/a qual (clarity/after prepositions), o que (that which/what), cujo/-a (whose, agrees with the thing possessed), onde (where). Conjunctions: porque (because), embora/apesar de (although), mas (but), se (if), quando (when), enquanto (while). Question words: o que/que (what), quem (who), onde (where), quando (when), por que (why), como (how), qual/quais (which), quanto/-a (how much/many).",
      "Produce natural, idiomatic Brazilian Portuguese with correct gender/number agreement, ser/estar/ter, preposition+article contractions, the right past aspect and mood (incl. the personal infinitive and future subjunctive) — never a word-for-word calque from Chinese or English.",
    ],
  },
  // ── French grammar, integrated in parts. Reference: Heminway, Complete
  // French Grammar (McGraw-Hill); standard modern French. ──────────────────────
  French: {
    authority: "Standard French orthography & usage; reference: Heminway, Complete French Grammar (McGraw-Hill)",
    rules: [
      // [P1] Orthography, gender, number, articles
      "Use full French orthography: accents (é è ê ë, à â, î ï, ô, ù û ü, ç) and elision before a vowel/mute h (le+ami→l'ami, je+ai→j'ai, de+eau→d'eau, que+il→qu'il, ne+a→n'a). Lowercase nationalities, languages, months and days (français, lundi, janvier).",
      "Every noun has GENDER: masculine or feminine — it is largely unpredictable, so treat gender as part of the word. Articles and adjectives MUST agree in gender and number.",
      "Articles: definite le/la/l'/les, indefinite un/une/des, partitive du/de la/de l'/des ('some'). Contractions are mandatory: à+le→au, à+les→aux, de+le→du, de+les→des. After a negation the partitive/indefinite becomes de/d' (Je n'ai pas de pain). French uses articles far more than English (with general nouns: J'aime le café).",
      "Number/agreement: plural usually adds -s (silent) — chats, maisons; -x for -eau/-eu (gâteaux). Adjectives agree in gender AND number (une voiture bleue, des livres verts). Most adjectives FOLLOW the noun; a few common ones precede (beau, bon, grand, petit, jeune, vieux, joli, nouveau): une grande maison.",
      // [P2] être / avoir, c'est, il y a
      "Two core verbs: ÊTRE (to be: je suis, tu es, il est, nous sommes, vous êtes, ils sont) and AVOIR (to have: j'ai, tu as, il a, nous avons, vous avez, ils ont). Many states use AVOIR where English uses 'be': avoir faim/soif/froid/chaud/peur/raison/20 ans (be hungry/thirsty/cold/hot/afraid/right/20 years old). 'There is/are' = il y a. 'It is / this is' = c'est (+ noun) vs il/elle est (+ adjective/profession).",
      // [P3] Present, pronominal verbs, negation, questions
      "Present tense conjugates by group: -er (parler→parle, parles, parle, parlons, parlez, parlent), -ir (finir→finis, finis, finit, finissons, finissez, finissent), -re (vendre→vends, vends, vend, vendons, vendez, vendent). Many irregular verbs (aller, faire, prendre, venir, pouvoir, vouloir, devoir) — use their correct forms. SUBJECT PRONOUNS are obligatory (unlike Spanish): on = informal 'we' / impersonal 'one', takes 3rd-singular.",
      "Pronominal (reflexive) verbs take se: se lever (je me lève), s'appeler (il s'appelle), se souvenir. They also express reciprocal ('each other') and some passives.",
      "Negation wraps the verb: ne … pas (Je ne sais pas), ne … jamais (never), ne … plus (no longer), ne … rien (nothing), ne … personne (nobody), ne … que (only). In casual speech 'ne' may drop, but for neutral quiz/subtitle text keep BOTH ne and the second element.",
      "Questions: rising intonation (Tu viens ?), est-ce que (Est-ce que tu viens ?), or inversion (Viens-tu ? Parlez-vous français ?). Question words: qui (who), que/quoi (what), où (where), quand (when), pourquoi (why), comment (how), combien (how much/many), quel/quelle (which). Always put a space before ? ! : ; in French typography.",
      // [P4] Past, future, conditional, compound, object pronouns
      "Two main past tenses by aspect: PASSÉ COMPOSÉ = a completed past action (J'ai mangé; Il est parti) — formed with avoir or être + past participle. IMPARFAIT = ongoing/habitual/background, descriptions, time & age in the past (Je mangeais tous les jours; Il était grand; Il faisait beau). Choose by meaning — this is a key contrast.",
      "Passé composé auxiliary: most verbs take AVOIR; a set of intransitive 'movement/state-change' verbs and ALL pronominal verbs take ÊTRE (aller, venir, arriver, partir, entrer, sortir, monter, descendre, rester, tomber, naître, mourir, devenir + se laver…). With être the participle AGREES with the subject (Elle est allée; Ils sont venus; Elles se sont levées); with avoir it agrees only with a PRECEDING direct object (les livres que j'ai lus).",
      "Future: futur proche = aller + infinitive (Je vais manger); futur simple adds endings to the infinitive (je parlerai, il finira) with irregular stems (ser-, aur-, ir-, fer-, viendr-, pourr-). Conditional = same stems + imparfait endings (je voudrais, j'aimerais — polite). Compound past tenses use avoir/être in those tenses (plus-que-parfait: j'avais mangé).",
      "Object pronouns go BEFORE the verb in this order: me/te/se/nous/vous → le/la/les → lui/leur → y → en (Je le lui donne; Il y va; J'en veux). y replaces à+thing/place; en replaces de+thing or a quantity. Stressed/disjunctive pronouns (moi, toi, lui, elle, nous, vous, eux, elles) follow prepositions (avec moi) and stand alone.",
      // [P5] Subjunctive, imperative, comparison, relatives, prepositions
      "The SUBJONCTIF is required after expressions of will, emotion, doubt and necessity + que with a different subject (Je veux que tu viennes; Il faut que tu partes; Je suis content que tu sois là; bien que, pour que, avant que). Present subjunctive: que je parle, que tu finisses, que nous fassions (irregular: sois/aies, fasse, aille, puisse).",
      "Imperative drops the subject pronoun (Parle ! Parlons ! Parlez ! Finis ! Va !). In affirmative commands object pronouns FOLLOW and link with hyphens, with me→moi (Donne-le-moi ; Lève-toi) ; in negative commands they precede (Ne me le donne pas).",
      "Comparison: plus/moins/aussi + adjective + que (plus grand que, aussi vite que); de before a number (plus de dix). Irregular: meilleur (better, adj.), mieux (better, adv.), pire/plus mauvais. Superlative: le/la/les plus … (de) (le plus grand de la classe) — the adjective keeps its normal position and repeats the article.",
      "Relative pronouns: qui (subject: l'homme qui parle), que/qu' (direct object: le livre que je lis), où (where/when: la ville où j'habite), dont (of which/whose: le livre dont je parle), and ce qui/ce que ('what'). Key prepositions: à (to/at), de (of/from), en/dans (in), chez (at someone's), pour (for), avec, sans, par. Countries: en + feminine country (en France), au + masculine (au Japon), aux + plural (aux États-Unis).",
      "Produce natural, idiomatic standard French with correct gender/number agreement, articles/contractions, elision, the right past aspect (passé composé vs imparfait), participle agreement, mood (indicatif vs subjonctif) and accents — never a word-for-word calque from Chinese or English.",
    ],
  },
  // ── Arabic grammar, integrated in parts. Reference: Ryding, A Reference
  // Grammar of Modern Standard Arabic (Cambridge); fuṣḥā. ────────────────────────
  Arabic: {
    authority: "Modern Standard Arabic (fuṣḥā) orthography & usage; reference: Ryding, A Reference Grammar of Modern Standard Arabic (Cambridge)",
    rules: [
      // [P1] Script & orthography
      "Write right-to-left Modern Standard Arabic (fuṣḥā) in connected script. Use hamza on its correct seat (أ إ ؤ ئ or ء), shadda (ّ) for doubled consonants, and ta marbuta (ة) for the feminine ending. Short vowels are normally left unwritten; do NOT add full vowel diacritics to quiz options. Keep the lam of الـ written even before sun letters (الشمس, not اششمس).",
      // [P2] Definiteness, gender, the nominal sentence
      "Definiteness: a definite noun takes the prefix الـ (الكتاب 'the book'); indefiniteness is shown by nunation/tanwin, not a separate word (كتاب 'a book'). There is no verb 'to be' in the present: a nominal sentence is subject + predicate (البيت كبير 'the house is big'; هو طالب 'he is a student'). Use كان for the past (كان البيت كبيراً) and ليس to negate it (ليس كبيراً 'is not big').",
      "Gender: every noun is masculine or feminine; the feminine is usually marked with ة (طالب m → طالبة f). Some nouns are feminine without ة (شمس, أرض, يد, مدينة + country/city names). Adjectives FOLLOW the noun and agree in gender, number, definiteness and case (الكتاب الكبير 'the big book'; مدينة كبيرة 'a big city').",
      // [P3] Number, case
      "Three numbers: singular, DUAL and plural. Dual adds ـان/ـين (كتابان/كتابين 'two books'). Sound masc. plural ـون/ـين (مدرّسون/مدرّسين), sound fem. plural ـات (مدرّسات). Many nouns take a BROKEN plural with an internal pattern change that must be learned: كتاب→كتب, ولد→أولاد, رجل→رجال, بيت→بيوت, مدينة→مدن.",
      "Case (iʿrāb): nominative (مرفوع, -u) for subject/predicate; accusative (منصوب, -a) for the object, the predicate of كان, and the noun of إنّ; genitive (مجرور, -i) after a preposition and as the second term of an iḍāfa. In unvowelled quiz text these endings are usually invisible, but choose forms that are grammatically consistent.",
      // [P4] Iḍāfa, agreement
      "Iḍāfa (possessive/of construction): the FIRST noun takes NO article and NO tanwin and the SECOND noun is genitive and definite (باب البيت 'the door of the house'; كتاب الطالب 'the student's book'; غرفة نوم 'a bedroom'). Never put الـ on the first term of an iḍāfa.",
      "Non-human plural agreement (key Arabic rule): plural nouns referring to NON-humans agree as FEMININE SINGULAR with their adjective and verb (الكتب الجديدة 'the new books'; السيارات كبيرة 'the cars are big'; هذه الكتب 'these books'). Human plurals take full plural agreement (المدرّسون الجدد 'the new teachers').",
      // [P5] Verb system
      "Two aspects: PERFECT (الماضي, past) with suffix conjugation (كتب 'he wrote', كتبتُ 'I wrote', كتبوا 'they wrote') and IMPERFECT (المضارع, present/non-past) with prefix conjugation (يكتب 'he writes/is writing', أكتب, يكتبون). The subject is built into the verb; a separate pronoun is for emphasis. Future = سـ/سوف + imperfect (سيكتب 'he will write').",
      "Verb-initial sentences keep the verb SINGULAR with a plural subject (كتب الطلاب 'the students wrote'), but a subject-initial sentence shows full agreement (الطلاب كتبوا). Negation: past → ما or لم + jussive imperfect (لم يذهب 'he did not go'); present → لا (لا يعرف 'he doesn't know'); future → لن + subjunctive (لن أذهب 'I won't go'); nominal → ليس.",
      "Roots are triliteral and meaning shifts by FORM (wazn): I فعل, II فعّل (intensive/causative درّس 'taught'), III فاعل (reciprocal), IV أفعل (causative أرسل 'sent'), V تفعّل, VI تفاعل, VII انفعل, VIII افتعل, X استفعل (استخدم 'used'). Use the active participle (كاتب 'writer'), passive participle (مكتوب 'written') and verbal noun/maṣdar (كتابة 'writing', دراسة 'studying') where natural.",
      // [P6] Pronouns, prepositions, questions, numbers
      "Attached pronouns express possession on nouns (كتابي 'my book', كتابه 'his book', بيتنا 'our house'), object on verbs (رآني 'he saw me') and complement on prepositions (له, معي, عنده). There is no verb 'to have': use عند or لـ (عندي كتاب 'I have a book'; لي أخ 'I have a brother').",
      "Prepositions take the genitive: في (in), على (on), من (from), إلى (to), بـ (with/by), لـ (for), عن (about), مع (with), عند (at/by). Question words: هل/أ (yes-no), ما/ماذا (what), من (who), أين (where), متى (when), لماذا (why), كيف (how), كم (how many — followed by a SINGULAR accusative: كم كتاباً؟).",
      "Numbers: 3–10 show REVERSE gender agreement and are followed by a genitive plural (ثلاثة كتب 'three books' — masc. counted noun → feminine-form number; ثلاث بنات 'three girls'); 11–99 are followed by a SINGULAR accusative (عشرون كتاباً 'twenty books'). The conjunction وَ ('and') is written attached to the next word (الكتاب والقلم). إنّ and its sisters put their noun in the accusative.",
      "Produce natural, idiomatic Modern Standard Arabic with correct definiteness (الـ / tanwin), gender and number agreement, NON-HUMAN-PLURAL feminine-singular agreement, article-less first term in iḍāfa, correct iʿrāb, the right negation (لم/لن/لا/ليس) and verb form — never a word-for-word calque from Chinese or English.",
    ],
  },
};

function buildPrompt(
  transcription: string,
  pinyin: string,
  langName: string,
  sourceEn?: string,
  sourceEnWrong?: string,
): string {
  const profile = LANG_PROFILES[langName];
  const authority = profile?.authority ?? `the most authoritative ${langName} grammar standard`;
  const rules = profile?.rules ?? [
    `Strictly follow all ${langName} grammar rules.`,
    `Produce output a fluent native ${langName} speaker would say naturally, not a literal translation.`,
  ];
  const numberedRules = rules.map((r, i) => `  ${i + 1}. ${r}`).join("\n");

  // Pivot mode: translate the APPROVED English (not directly from Chinese). The
  // English carries the vetted meaning; Chinese/pinyin are only grammar reference.
  // Chinese→English→target reads far more naturally than Chinese→target direct.
  if (sourceEn && sourceEn.trim() && langName !== "English") {
    const hasWrong = !!(sourceEnWrong && sourceEnWrong.trim());
    return (
      `You are a certified ${langName} linguist and professional translator.\n` +
      `Your grammar authority: ${authority}.\n\n` +
      `MANDATORY GRAMMAR RULES for this task:\n${numberedRules}\n\n` +
      `Translate the APPROVED English options into ${langName}. The English is the ` +
      `vetted, authoritative meaning — translate ITS meaning faithfully and naturally ` +
      `(NOT word-for-word). Use the Chinese only to disambiguate nuance.\n` +
      `  correctAnswer — English: "${sourceEn.trim()}"\n` +
      (hasWrong ? `  wrongAnswer — English:   "${sourceEnWrong!.trim()}"\n` : "") +
      `  Chinese (reference only): "${transcription}"\n` +
      (pinyin ? `  Pinyin (reference only):  "${pinyin}"\n` : "") +
      `\nSteps before output:\n` +
      `  1 — Translate correctAnswer into natural ${langName} (what a native would say).\n` +
      (hasWrong
        ? `  2 — Translate wrongAnswer into ${langName} the SAME way. Preserve ITS meaning ` +
          `exactly — do NOT invent a different distractor; it is already the chosen wrong option.\n`
        : `  2 — wrongAnswer: take your correctAnswer and change exactly ONE key semantic ` +
          `element (flip a negation, swap subject/object, or a meaning-shifting near-synonym).\n`) +
      `  3 — Grammar-audit both against the numbered rules; each must be grammatically perfect.\n\n` +
      `OUTPUT — return ONLY valid JSON, no markdown:\n` +
      `{"correctAnswer": "<${langName} of correctAnswer>", "wrongAnswer": "<${langName} of wrongAnswer>"}`
    );
  }

  return (
    `You are a certified ${langName} linguist and professional translator.\n` +
    `Your grammar authority: ${authority}.\n\n` +
    `MANDATORY GRAMMAR RULES for this task:\n${numberedRules}\n\n` +
    `SOURCE SENTENCE\n` +
    `  Chinese: "${transcription}"\n` +
    (pinyin ? `  Pinyin:  "${pinyin}"\n` : "") +
    `\nTRANSLATION TASK — follow these four steps internally before producing output:\n` +
    `  Step 1 — Draft a natural ${langName} translation. Aim for what a native speaker would actually say, NOT a word-for-word mapping from Chinese.\n` +
    `  Step 2 — Grammar audit: check your draft against every numbered rule above. Fix every violation before continuing.\n` +
    `  Step 3 — Naturalness check: would a fluent native ${langName} speaker say this sentence exactly? If not, rephrase.\n` +
    `  Step 4 — Create wrongAnswer: take your final correctAnswer and change exactly ONE key semantic element ` +
    `(swap a crucial word with a near-synonym that subtly changes the meaning, add/remove a negation, or swap subject/object). ` +
    `The wrongAnswer MUST be equally grammatically perfect — only the meaning is wrong. Similar length and structure to correctAnswer.\n\n` +
    `OUTPUT — return ONLY valid JSON with exactly these two keys, no markdown, no explanation:\n` +
    `{"correctAnswer": "<final ${langName} translation>", "wrongAnswer": "<grammatically correct but semantically wrong distractor>"}`
  );
}

function langCodeToName(code: string): string {
  return code === "en" ? "English"
    : code === "ja" ? "Japanese"
    : code === "ko" ? "Korean"
    : code === "id" ? "Indonesian"
    : code === "vi" ? "Vietnamese"
    : code === "th" ? "Thai"
    : code === "ru" ? "Russian"
    : code === "es" ? "Spanish"
    : code === "pt" ? "Portuguese"
    : code === "fr" ? "French"
    : code === "ar" ? "Arabic"
    : "Turkish";
}

// Batch prompt: produce English + every requested target language in ONE Gemini
// call. The English correctAnswer + wrongAnswer are decided ONCE; every target
// language is a FAITHFUL TRANSLATION of that same English pair (same meaning,
// same distractor) — never an independently invented distractor. This keeps the
// options identical in meaning/structure across all languages, differing only
// in wording and grammar. One request also keeps free-tier quota usage low.
function buildBatchPrompt(
  transcription: string,
  pinyin: string,
  targets: { code: string; name: string }[],
): string {
  const blockFor = (name: string): string => {
    const p = LANG_PROFILES[name];
    const rules = (p?.rules ?? [`Follow all ${name} grammar rules and be idiomatic.`])
      .map((r, i) => `  ${i + 1}. ${r}`).join("\n");
    return `${name.toUpperCase()} — authority ${p?.authority ?? name}:\n${rules}\n`;
  };
  let blocks = blockFor("English") + "\n";
  for (const t of targets) blocks += blockFor(t.name) + "\n";
  const targetKeys = targets
    .map((t) => `"${t.code}": {"correctAnswer": "<${t.name} translation of the English correctAnswer>", "wrongAnswer": "<${t.name} translation of the SAME English wrongAnswer>"}`)
    .join(", ");
  return (
    `You are a certified multilingual linguist and professional translator.\n\n` +
    `SOURCE Chinese: "${transcription}"\n` +
    (pinyin ? `Pinyin: "${pinyin}"\n` : "") +
    `\nTASK:\n` +
    `1. Translate the Chinese into a natural English correctAnswer — what a native speaker would actually say, NOT word-for-word.\n` +
    `2. Build ONE English wrongAnswer from that correctAnswer by changing exactly ONE key semantic element (flip a negation, swap subject/object, or a meaning-shifting near-synonym); same length/structure, grammatically perfect. This single distractor is shared by ALL languages.\n` +
    `3. For EACH target language, TRANSLATE the English correctAnswer and the English wrongAnswer faithfully and naturally (use the Chinese only to disambiguate nuance). Preserve EACH option's meaning EXACTLY: the target wrongAnswer must be a translation of the SAME English wrongAnswer — do NOT invent a different distractor, and do NOT change which element is altered. Across all languages the correctAnswer must mean the same thing, and the wrongAnswer must mean the same (wrong) thing; only wording and grammar adapt per language.\n` +
    `4. Obey each language's numbered grammar rules while keeping the meaning identical to the English pair.\n\n` +
    `GRAMMAR RULES:\n${blocks}\n` +
    `OUTPUT — return ONLY valid JSON, no markdown:\n` +
    `{"en": {"correctAnswer": "<English>", "wrongAnswer": "<English distractor>"}, ${targetKeys}}`
  );
}

const RETRYABLE = new Set([429, 500, 502, 503, 504]);
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Gemini occasionally returns a transient 502/503/429 (overload). Retry a few
// times with backoff so the admin doesn't have to manually press the button
// again. Returns the response text, or throws after the last attempt.
async function callGeminiWithRetry(
  url: string,
  reqBody: string,
  attempts = 4,
): Promise<string> {
  let lastErr = "";
  for (let i = 0; i < attempts; i++) {
    try {
      const r = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: reqBody,
      });
      if (r.ok) {
        const data = await r.json();
        return data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      }
      const bodyText = (await r.text()).slice(0, 1500);
      lastErr = `Gemini ${r.status}: ${bodyText}`;
      // A daily-quota 429 will not clear on retry — only retry per-minute/over-
      // load cases. Stop early when the message is an exhausted daily quota.
      const dailyExhausted = r.status === 429 && /per ?day|PerDay/i.test(bodyText);
      if (!RETRYABLE.has(r.status) || dailyExhausted) throw new Error(lastErr);
    } catch (e) {
      lastErr = String(e);
    }
    if (i < attempts - 1) await sleep(500 * (i + 1) + Math.random() * 300);
  }
  throw new Error(lastErr || "Gemini request failed");
}

// Try every model bucket × API key. callGeminiWithRetry already retries
// transient/overload cases per attempt; here we rotate keys when one is
// quota-exhausted and then fall through to the next MODEL (per-model quota
// buckets are independent). Non-quota errors (e.g. 400) stop early.
async function callGeminiRotating(reqBody: string, keys: string[]): Promise<string> {
  let lastErr = "";
  for (const model of MODEL_FALLBACKS) {
    for (const key of keys) {
      try {
        return await callGeminiWithRetry(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
          reqBody,
        );
      } catch (e) {
        lastErr = String(e);
        const quotaLike = /429|quota|RESOURCE_EXHAUSTED|50[0234]|overload|unavailable/i.test(lastErr);
        if (!quotaLike) return Promise.reject(new Error(lastErr)); // bad request
      }
    }
  }
  throw new Error(lastErr || "Gemini request failed");
}

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Persisted cache so the same (sentence, language, English-source) is generated
// once and reused forever — keeps Gemini usage sustainable under the free quota.
const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const sbHeaders = {
  apikey: SB_KEY,
  Authorization: `Bearer ${SB_KEY}`,
  "Content-Type": "application/json",
};

async function cacheGet(
  k: string,
): Promise<{ correct: string; wrong: string } | null> {
  if (!SB_URL || !SB_KEY) return null;
  try {
    const r = await fetch(
      `${SB_URL}/rest/v1/ai_quiz_cache?cache_key=eq.${k}&select=correct_answer,wrong_answer`,
      { headers: sbHeaders },
    );
    if (!r.ok) return null;
    const rows = await r.json();
    if (Array.isArray(rows) && rows.length) {
      return { correct: rows[0].correct_answer ?? "", wrong: rows[0].wrong_answer ?? "" };
    }
  } catch { /* ignore */ }
  return null;
}

async function cacheSet(k: string, correct: string, wrong: string): Promise<void> {
  if (!SB_URL || !SB_KEY || !correct) return;
  try {
    await fetch(`${SB_URL}/rest/v1/ai_quiz_cache`, {
      method: "POST",
      headers: { ...sbHeaders, Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify({
        cache_key: k,
        correct_answer: correct,
        wrong_answer: wrong,
        model: MODEL,
      }),
    });
  } catch { /* ignore */ }
}

// Languages whose sentences start with a capital letter. Capitalize the first
// real letter of every quiz option (correct AND wrong) for these, skipping any
// leading punctuation/quotes (e.g. Spanish ¿¡). Turkish locale keeps i→İ right.
const CAP_LANGS = new Set(["tr", "en", "id", "vi", "es", "pt", "ru", "fr"]);
function capFirst(s: string, code: string): string {
  if (!s || !CAP_LANGS.has(code)) return s;
  const m = s.match(/^([\s¿¡"'(\[«]*)([\s\S])([\s\S]*)$/);
  if (!m) return s;
  return m[1] + m[2].toLocaleUpperCase(code) + m[3];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const transcription = (body.transcription ?? "").toString().trim();
    const pinyin = (body.pinyin ?? "").toString().trim();
    const lang = (body.lang ?? "tr").toString();
    const sourceEn = (body.sourceEn ?? "").toString().trim();
    const sourceEnWrong = (body.sourceEnWrong ?? "").toString().trim();
    if (!transcription) return json({ error: "transcription required" }, 400);

    const langName =
      lang === "en" ? "English"
      : lang === "ja" ? "Japanese"
      : lang === "ko" ? "Korean"
      : lang === "id" ? "Indonesian"
      : lang === "vi" ? "Vietnamese"
      : lang === "th" ? "Thai"
      : lang === "ru" ? "Russian"
      : lang === "es" ? "Spanish"
      : lang === "pt" ? "Portuguese"
      : lang === "fr" ? "French"
      : lang === "ar" ? "Arabic"
      : "Turkish";

    // Cache first — same sentence+language+English source (correct+wrong) never
    // re-hits Gemini. The wrong-source is part of the key so editing the English
    // distractor regenerates the translation instead of returning a stale one.
    const cacheKey = await sha256(
      `${MODEL}|${langName}|${sourceEn}|${sourceEnWrong}|${transcription}`);
    const cached = await cacheGet(cacheKey);
    if (cached) {
      return json({ correctAnswer: cached.correct, wrongAnswer: cached.wrong, cached: true });
    }

    const keys = geminiKeys();
    if (!keys.length) return json({ error: "GEMINI_API_KEY not set" }, 500);

    // Batch mode: generate English + all requested target languages in ONE call.
    // Triggered when generating English (lang='en') with targetLangs — the EN tab
    // pre-fills the other tabs, so approving EN needs no extra Gemini request.
    const targetLangs: string[] = Array.isArray(body.targetLangs)
      ? [...new Set(body.targetLangs.map((x: unknown) => String(x)))]
          .filter((c) => c && c !== "en")
      : [];
    if (lang === "en" && targetLangs.length) {
      const targets = targetLangs.map((code) => ({ code, name: langCodeToName(code) }));
      const batchBody = JSON.stringify({
        contents: [{ parts: [{ text: buildBatchPrompt(transcription, pinyin, targets) }] }],
        generationConfig: { response_mime_type: "application/json", temperature: 0.4 },
      });
      let btext: string;
      try {
        btext = await callGeminiRotating(batchBody, keys);
      } catch (e) {
        return json({ error: String(e) }, 502);
      }
      let bp: Record<string, { correctAnswer?: string; wrongAnswer?: string }> = {};
      try {
        bp = JSON.parse(btext);
      } catch {
        const m = btext.match(/\{[\s\S]*\}/);
        if (m) { try { bp = JSON.parse(m[0]); } catch { /* ignore */ } }
      }
      const enCorrect = capFirst(String(bp.en?.correctAnswer ?? ""), "en");
      const enWrong = capFirst(String(bp.en?.wrongAnswer ?? ""), "en");
      if (enCorrect) await cacheSet(cacheKey, enCorrect, enWrong); // cacheKey is the EN key
      const extra: Record<string, { correctAnswer: string; wrongAnswer: string }> = {};
      for (const t of targets) {
        const c = capFirst(String(bp[t.code]?.correctAnswer ?? ""), t.code);
        const w = capFirst(String(bp[t.code]?.wrongAnswer ?? ""), t.code);
        extra[t.code] = { correctAnswer: c, wrongAnswer: w };
        if (c && enCorrect) {
          // Same key a later single-language call (sourceEn = approved EN) would use.
          await cacheSet(
            await sha256(`${MODEL}|${t.name}|${enCorrect}|${transcription}`), c, w);
        }
      }
      return json({ correctAnswer: enCorrect, wrongAnswer: enWrong, extra, batched: true });
    }

    const prompt = buildPrompt(transcription, pinyin, langName, sourceEn, sourceEnWrong);

    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: 0.4, // lower = more consistent, less hallucination
      },
    });

    let text: string;
    try {
      text = await callGeminiRotating(reqBody, keys);
    } catch (e) {
      return json({ error: String(e) }, 502);
    }

    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(text);
    } catch {
      const m = text.match(/\{[\s\S]*\}/);
      if (m) {
        try { parsed = JSON.parse(m[0]); } catch { /* ignore */ }
      }
    }

    const correctAnswer = capFirst(String(parsed.correctAnswer ?? ""), lang);
    const wrongAnswer = capFirst(String(parsed.wrongAnswer ?? ""), lang);
    if (correctAnswer) await cacheSet(cacheKey, correctAnswer, wrongAnswer);
    return json({ correctAnswer, wrongAnswer });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
