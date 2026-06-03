import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// gemini-2.5-flash: better reasoning quality than lite, needed for accurate grammar
const MODEL = "gemini-2.5-flash";

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
): string {
  const profile = LANG_PROFILES[langName];
  const authority = profile?.authority ?? `the most authoritative ${langName} grammar standard`;
  const rules = profile?.rules ?? [
    `Strictly follow all ${langName} grammar rules.`,
    `Produce output a fluent native ${langName} speaker would say naturally, not a literal translation.`,
  ];
  const numberedRules = rules.map((r, i) => `  ${i + 1}. ${r}`).join("\n");

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
      lastErr = `Gemini ${r.status}: ${(await r.text()).slice(0, 300)}`;
      if (!RETRYABLE.has(r.status)) throw new Error(lastErr);
    } catch (e) {
      lastErr = String(e);
    }
    if (i < attempts - 1) await sleep(500 * (i + 1) + Math.random() * 300);
  }
  throw new Error(lastErr || "Gemini request failed");
}

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
    if (!transcription) return json({ error: "transcription required" }, 400);

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ error: "GEMINI_API_KEY not set" }, 500);

    const langName =
      lang === "en" ? "English"
      : lang === "ja" ? "Japanese"
      : lang === "ko" ? "Korean"
      : lang === "vi" ? "Vietnamese"
      : "Turkish";

    const prompt = buildPrompt(transcription, pinyin, langName);

    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: 0.4, // lower = more consistent, less hallucination
      },
    });

    let text: string;
    try {
      text = await callGeminiWithRetry(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
        reqBody,
      );
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

    return json({
      correctAnswer: String(parsed.correctAnswer ?? ""),
      wrongAnswer: String(parsed.wrongAnswer ?? ""),
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
