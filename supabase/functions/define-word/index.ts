import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Same rotation scheme as translate/generate-quiz: GEMINI_MODEL overrides the
// first choice; sibling models have their own free-tier quota buckets.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
const MODEL_FALLBACKS = [
  MODEL,
  "gemini-flash-lite-latest",
  "gemini-flash-latest",
  "gemini-2.5-flash",
];

const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SB_HEADERS = {
  apikey: SB_KEY,
  Authorization: `Bearer ${SB_KEY}`,
  "Content-Type": "application/json",
};

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

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const LANGS = ["tr", "ko", "ja", "id", "vi", "th", "ru", "es", "pt", "fr", "ar"];
const LANG_NAMES: Record<string, string> = {
  tr: "Turkish", ko: "Korean", ja: "Japanese", id: "Indonesian",
  vi: "Vietnamese", th: "Thai", ru: "Russian", es: "Spanish",
  pt: "Portuguese", fr: "French", ar: "Arabic",
};
// The value placeholder must NAME the language ("tr": "<Turkish>") — with an
// anonymous placeholder the model doesn't resolve the code and echoes English.
const langKeysFor = (langs: string[]) =>
  langs.map((l) => `"${l}": "<${LANG_NAMES[l]}>"`).join(", ");

// Same per-language dictionary-register rules as translate's single-word mode,
// so auto-filled "Diğer" entries read like the manually filled ones.
const REGISTER =
  `Korean in natural dictionary register, verbs as -하다/-다 base forms; ` +
  `Japanese in plain dictionary form 辞書形; Indonesian in base/root form ` +
  `with standard meN-/ber- affixation (KBBI style); Vietnamese with full ` +
  `diacritics/tone marks; Thai in Thai script (อักษรไทย), no transliteration; ` +
  `Russian in Cyrillic citation form (nouns nominative singular, verbs ` +
  `infinitive); Spanish in citation form with definite article showing gender ` +
  `(el/la), verbs infinitive; Brazilian Portuguese in citation form with ` +
  `article (o/a), verbs infinitive; French in citation form with article ` +
  `(le/la/un/une), correct accents; Arabic (MSA fuṣḥā) in citation form, ` +
  `Arabic script, no full vowel diacritics.`;

// tone-marked pinyin per character composed from our own dictionary (first
// reading of each char) — deterministic, no Gemini tone hallucinations.
async function pinyinFromChars(word: string): Promise<string> {
  const chars = [...new Set(word.split(""))];
  const list = chars.map((c) => `"${c}"`).join(",");
  const r = await fetch(
    `${SB_URL}/rest/v1/dictionary?simplified=in.(${encodeURIComponent(list)})` +
      `&select=simplified,pinyin`,
    { headers: SB_HEADERS },
  );
  if (!r.ok) return "";
  const rows: { simplified: string; pinyin: string | null }[] = await r.json();
  const map = new Map(rows.map((x) => [x.simplified, x.pinyin ?? ""]));
  const parts: string[] = [];
  for (const c of word) {
    const p = (map.get(c) ?? "").split(",")[0].trim();
    if (!p) return ""; // a char we don't know → fall back to Gemini's pinyin
    parts.push(p);
  }
  return parts.join(" ");
}

// One word → validity gate + POS + English gloss + 11 languages pivoted from
// that English gloss (decided once → same sense everywhere), then the entry is
// UPSERTED into the dictionary as "Diğer" (hsk_level 7) and the matching
// suggestion posts are removed. On any failure the suggestion stays put, so
// the manual Önerilen editor remains a complete fallback.
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const word = (body.word ?? "").toString().trim();
    const context = (body.context ?? "").toString().trim().slice(0, 200);
    if (!/^[一-鿿]{1,6}$/.test(word)) {
      return json({ valid: false, reason: "not-a-cjk-word" });
    }
    if (!SB_KEY) return json({ error: "service role key missing" }, 500);

    // Already in the dictionary → just clean the suggestion up.
    const existsR = await fetch(
      `${SB_URL}/rest/v1/dictionary?simplified=eq.${encodeURIComponent(word)}&select=id&limit=1`,
      { headers: SB_HEADERS },
    );
    if (existsR.ok && (await existsR.json()).length > 0) {
      await removeSuggestions(word);
      return json({ valid: true, existed: true });
    }

    const keys = geminiKeys();
    if (!keys.length) return json({ error: "GEMINI_API_KEY not set" }, 500);

    const langKeys = langKeysFor(LANGS);
    const prompt =
      `You are a professional Chinese lexicographer. Candidate headword: "${word}"` +
      (context ? ` (seen in the sentence: "${context}")` : "") + `.\n` +
      `Step 1 — VALIDITY: decide whether this is a real, standalone Chinese ` +
      `dictionary word or proper noun. ASR artifacts, truncated fragments, ` +
      `random character clumps that only make sense as parts of other words, ` +
      `and ungrammatical combinations are NOT valid. Be strict: when in ` +
      `doubt, mark invalid.\n` +
      `Step 2 — if valid: give its part of speech (one of: noun, verb, adj, ` +
      `adv, pron, num, meas, part, conj, prep, interj, name) and its concise ` +
      `ENGLISH dictionary gloss (1-3 senses, comma-separated), choosing the ` +
      `sense that fits the sentence context if given.\n` +
      `Step 3 — translate THAT English gloss (not the Chinese directly) into ` +
      `each language below so every language expresses the same sense. ${REGISTER}\n` +
      `Also give tone-marked Hanyu Pinyin for the word.\n` +
      `Return ONLY JSON: {"valid": true|false, "reason": "<if invalid>", ` +
      `"pos": "...", "pinyin": "...", "en": "...", ${langKeys}}`;

    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.2, response_mime_type: "application/json" },
    });

    let lastErr = "";
    for (const model of MODEL_FALLBACKS) {
      for (const key of keys) {
        const r = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: reqBody },
        );
        if (!r.ok) {
          lastErr = `Gemini ${r.status} [${model}]`;
          if (![429, 500, 502, 503].includes(r.status)) return json({ error: lastErr }, 502);
          continue;
        }
        const data = await r.json();
        const raw: string =
          (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
        let p: Record<string, unknown> = {};
        try {
          p = JSON.parse(raw);
        } catch {
          const m = raw.match(/\{[\s\S]*\}/);
          if (m) { try { p = JSON.parse(m[0]); } catch { /* ignore */ } }
        }
        if (p.valid !== true) {
          return json({ valid: false, reason: String(p.reason ?? "not-a-word") });
        }
        const en = String(p.en ?? "").trim();
        if (!en) return json({ valid: false, reason: "empty-gloss" });

        const pinyin = (await pinyinFromChars(word)) ||
          String(p.pinyin ?? "").trim();
        const definitions: Record<string, string> = {
          en,
          pos: String(p.pos ?? "").trim(),
        };
        for (const l of LANGS) definitions[l] = String(p[l] ?? "").trim();

        // Audit + repair: a language left empty or as a verbatim copy of the
        // English gloss (model shortcut, seen with tr) gets ONE retry that
        // translates the English gloss alone into just those languages.
        const suspect = LANGS.filter((l) =>
          !definitions[l] || definitions[l] === en);
        if (suspect.length) {
          const fixKeys = langKeysFor(suspect);
          const fixPrompt =
            `Translate this English dictionary gloss into each language below ` +
            `(these are dictionary definitions of the Chinese word "${word}"; ` +
            `do NOT answer in English). ${REGISTER}\n` +
            `English gloss: "${en}"\nReturn ONLY JSON: {${fixKeys}}`;
          const fr = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{ parts: [{ text: fixPrompt }] }],
                generationConfig: {
                  temperature: 0.2,
                  response_mime_type: "application/json",
                },
              }),
            },
          );
          if (fr.ok) {
            const fd = await fr.json();
            const fraw: string =
              (fd?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
            try {
              const fp = JSON.parse(fraw);
              for (const l of suspect) {
                const v = String(fp[l] ?? "").trim();
                if (v) definitions[l] = v;
              }
            } catch { /* keep originals */ }
          }
        }

        const up = await fetch(
          `${SB_URL}/rest/v1/dictionary?on_conflict=id`,
          {
            method: "POST",
            headers: { ...SB_HEADERS, Prefer: "resolution=merge-duplicates" },
            body: JSON.stringify([{
              id: word,
              simplified: word,
              traditional: word,
              pinyin,
              pinyin_ascii: pinyin.normalize("NFD").replace(/[̀-ͯ]/g, ""),
              hsk_level: 7,
              definitions,
              ai_context_cache: {},
              radicals: [],
              stroke_count: 0,
            }]),
          },
        );
        if (!up.ok) {
          return json({ error: `dictionary upsert ${up.status}: ${(await up.text()).slice(0, 150)}` }, 502);
        }
        await removeSuggestions(word);
        // New word may green-light clips that were waiting on it (best-effort).
        await fetch(`${SB_URL}/rest/v1/rpc/reevaluate_unplaced_videos`, {
          method: "POST", headers: SB_HEADERS, body: "{}",
        }).catch(() => {});
        return json({ valid: true, saved: true, pinyin, definitions });
      }
    }
    return json({ error: lastErr || "all models exhausted" }, 502);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

async function removeSuggestions(word: string): Promise<void> {
  await fetch(
    `${SB_URL}/rest/v1/posts?content=eq.${encodeURIComponent(word)}` +
      `&metadata->>is_word_suggestion=eq.true`,
    { method: "DELETE", headers: SB_HEADERS },
  ).catch(() => {});
}
