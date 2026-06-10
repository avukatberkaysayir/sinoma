import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Default to flash-lite: the free tier gives ~1000 requests/day vs only 20/day
// for gemini-2.5-flash, which the import pipeline exhausts. Override with the
// GEMINI_MODEL secret (e.g. "gemini-2.5-flash") once billing is enabled.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";

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
  Japanese: {
    authority: "文化庁 国語施策 (Agency for Cultural Affairs, Language Policy) — bunka.go.jp",
    rules: [
      "SOV word order: topic は / subject が → object を → verb (verb always final).",
      "Particles (助詞): は (topic), が (subject), を (direct object), に (indirect object / direction / time), で (location of action / means), の (possession / nominalization), か (question).",
      "Verb must appear at the end of the clause/sentence.",
      "Politeness level: use ます/です (丁寧語) form throughout.",
      "No plurals; no articles.",
      "Negative: verb stem + ません (polite) or ない (plain).",
    ],
  },
  Korean: {
    authority: "국립국어원 (National Institute of Korean Language) — korean.go.kr",
    rules: [
      "SOV word order: Subject → Object → Verb.",
      "Particles: 은/는 (topic), 이/가 (subject), 을/를 (object), 에 (static location/time), 에서 (action location), 의 (possession).",
      "Verb at end; conjugate in formal polite speech: -습니다/-ㅂ니다 or -어요/-아요.",
      "No articles; number + counter for quantities.",
      "Negation: 안 + verb (short form) or verb stem + 지 않다.",
    ],
  },
};

function buildPrompt(
  transcription: string,
  pinyin: string,
  langName: string,
  sourceEn?: string,
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
    return (
      `You are a certified ${langName} linguist and professional translator.\n` +
      `Your grammar authority: ${authority}.\n\n` +
      `MANDATORY GRAMMAR RULES for this task:\n${numberedRules}\n\n` +
      `TRANSLATE THIS APPROVED ENGLISH into ${langName}. The English is the vetted, ` +
      `authoritative meaning — translate IT. Use the Chinese only to disambiguate nuance.\n` +
      `  English (authoritative source): "${sourceEn.trim()}"\n` +
      `  Chinese (reference only):       "${transcription}"\n` +
      (pinyin ? `  Pinyin (reference only):        "${pinyin}"\n` : "") +
      `\nFollow these steps internally before producing output:\n` +
      `  Step 1 — Draft a natural ${langName} rendering of the ENGLISH meaning (not word-for-word).\n` +
      `  Step 2 — Grammar audit: fix every violation of the numbered rules.\n` +
      `  Step 3 — Naturalness check: exactly what a fluent native speaker would say.\n` +
      `  Step 4 — wrongAnswer: take your correctAnswer and change exactly ONE key semantic element ` +
      `(near-synonym that shifts meaning, add/remove a negation, or swap subject/object). It must be ` +
      `equally grammatically perfect — only the meaning is wrong; similar length/structure.\n\n` +
      `OUTPUT — return ONLY valid JSON, no markdown:\n` +
      `{"correctAnswer": "<final ${langName} translation>", "wrongAnswer": "<grammatical but semantically wrong distractor>"}`
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
    : code === "vi" ? "Vietnamese"
    : "Turkish";
}

// Batch prompt: produce English + every requested target language in ONE Gemini
// call (each target translated from the English meaning), so generating all the
// admin's languages costs a single request instead of one per language — far
// fewer hits against the free-tier daily quota.
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
    .map((t) => `"${t.code}": {"correctAnswer": "<${t.name}>", "wrongAnswer": "<${t.name} distractor>"}`)
    .join(", ");
  return (
    `You are a certified multilingual linguist and professional translator.\n\n` +
    `SOURCE Chinese: "${transcription}"\n` +
    (pinyin ? `Pinyin: "${pinyin}"\n` : "") +
    `\nTASK:\n` +
    `1. Translate the Chinese into natural English — what a native speaker would actually say, NOT word-for-word.\n` +
    `2. Translate THAT English meaning into each target language below (use the Chinese only to disambiguate nuance).\n` +
    `3. For EVERY language produce a wrongAnswer: the same grammatically-perfect sentence with exactly ONE key semantic element changed (flip a negation, swap subject/object, or a meaning-shifting near-synonym); similar length/structure.\n` +
    `4. Obey each language's numbered grammar rules.\n\n` +
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

// Try each API key in turn. callGeminiWithRetry already retries transient/overload
// cases per key; here we rotate keys when one is quota-exhausted (daily 429) so a
// single capped key never blocks generation. Non-quota errors (e.g. 400) stop early.
async function callGeminiRotating(reqBody: string, keys: string[]): Promise<string> {
  let lastErr = "";
  for (const key of keys) {
    try {
      return await callGeminiWithRetry(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
        reqBody,
      );
    } catch (e) {
      lastErr = String(e);
      const quotaLike = /429|quota|RESOURCE_EXHAUSTED|50[0234]|overload|unavailable/i.test(lastErr);
      if (!quotaLike) break; // a new key won't fix a bad request
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
    if (!transcription) return json({ error: "transcription required" }, 400);

    const langName =
      lang === "en" ? "English"
      : lang === "ja" ? "Japanese"
      : lang === "ko" ? "Korean"
      : lang === "vi" ? "Vietnamese"
      : "Turkish";

    // Cache first — same sentence+language+English-source never re-hits Gemini.
    const cacheKey = await sha256(`${MODEL}|${langName}|${sourceEn}|${transcription}`);
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

    const prompt = buildPrompt(transcription, pinyin, langName, sourceEn);

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
