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
      "Produce natural standard Thai in Thai script with correct classifiers, head-initial word order and appropriate function words — never a word-for-word calque from Chinese or English, and never romanized.",
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
      const enCorrect = String(bp.en?.correctAnswer ?? "");
      const enWrong = String(bp.en?.wrongAnswer ?? "");
      if (enCorrect) await cacheSet(cacheKey, enCorrect, enWrong); // cacheKey is the EN key
      const extra: Record<string, { correctAnswer: string; wrongAnswer: string }> = {};
      for (const t of targets) {
        const c = String(bp[t.code]?.correctAnswer ?? "");
        const w = String(bp[t.code]?.wrongAnswer ?? "");
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

    const correctAnswer = String(parsed.correctAnswer ?? "");
    const wrongAnswer = String(parsed.wrongAnswer ?? "");
    if (correctAnswer) await cacheSet(cacheKey, correctAnswer, wrongAnswer);
    return json({ correctAnswer, wrongAnswer });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
