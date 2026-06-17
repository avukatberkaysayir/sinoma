import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// flash-lite default; GEMINI_MODEL overrides. On free-tier quota walls we
// also rotate through sibling models — each model has its own quota bucket.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
const MODEL_FALLBACKS = [
  MODEL,
  "gemini-flash-lite-latest",
  "gemini-flash-latest",
  "gemini-2.5-flash",
];

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

const LANG_NAMES: Record<string, string> = {
  tr: "Turkish",
  en: "English",
  ko: "Korean",
  ja: "Japanese",
  id: "Indonesian",
  vi: "Vietnamese",
  th: "Thai",
  ru: "Russian",
  es: "Spanish",
  pt: "Portuguese",
  fr: "French",
};

// Faithful translation of a Chinese sentence — or, for a single word, a
// dictionary-style gloss. Single-language calls return {translation};
// multi-language calls (body.langs) return {translations: {tr: ..., ko: ...}}.
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const text = (body.text ?? "").toString().trim();
    const langs: string[] = Array.isArray(body.langs) && body.langs.length
      ? body.langs.map((l: unknown) => String(l))
      : [(body.lang ?? "tr").toString()];
    if (!text) return json({ translation: "", translations: {} });

    const keys = geminiKeys();
    if (!keys.length) return json({ error: "GEMINI_API_KEY not set" }, 500);

    // Proper-noun mode: word segmentation helper — multi-character names
    // (people, places, brands, transliterations like 巴塞罗那) must stay ONE
    // word instead of falling apart into single characters.
    if (body.mode === "proper-nouns") {
      const pnPrompt =
        `List every proper noun that appears VERBATIM in this Chinese text: ` +
        `person names, place/city/country names, brand/organisation names, ` +
        `and foreign-name transliterations (e.g. 巴塞罗那, 麦当劳). Each item ` +
        `must be the exact substring as written, at least 2 characters. ` +
        `Do NOT include common nouns. Return ONLY JSON {"nouns": ["..."]} ` +
        `(empty array if none).\n\nText: "${text}"`;
      const pnBody = JSON.stringify({
        contents: [{ parts: [{ text: pnPrompt }] }],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: "application/json",
        },
      });
      let lastE = "";
      for (const model of MODEL_FALLBACKS) {
        for (const key of keys) {
          const r = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
            { method: "POST", headers: { "Content-Type": "application/json" }, body: pnBody },
          );
          if (r.ok) {
            const data = await r.json();
            const raw: string =
              (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
            let nouns: string[] = [];
            try {
              const p = JSON.parse(raw);
              if (Array.isArray(p?.nouns)) {
                nouns = p.nouns.map((n: unknown) => String(n))
                  .filter((n: string) => n.length >= 2 && text.includes(n));
              }
            } catch { /* ignore */ }
            return json({ nouns });
          }
          lastE = `Gemini ${r.status} [${model}]`;
          if (![429, 500, 502, 503].includes(r.status)) {
            return json({ error: lastE }, 502);
          }
        }
      }
      return json({ error: lastE || "exhausted" }, 502);
    }

    const names = langs.map((l) => LANG_NAMES[l] ?? "Turkish");
    const isWord = !/\s/.test(text) && text.length <= 6;
    const langKeys = langs
      .map((l, i) => `"${l}": "<${names[i]}>"`)
      .join(", ");
    const prompt = isWord
      ? `You are a professional lexicographer. Give the dictionary gloss of ` +
        `the Chinese word "${text}" in each requested language — concise, ` +
        `1-3 senses comma-separated, natural wording a published dictionary ` +
        `would use (Korean in natural dictionary register, verbs as -하다/-다 ` +
        `base forms; Japanese in plain dictionary form 辞書形, verbs as -する/-る ` +
        `base forms, nouns as plain nouns; Indonesian in base/root form with ` +
        `standard meN-/ber- affixation as a published KBBI dictionary would print; ` +
        `Vietnamese with full diacritics/tone marks as a standard Vietnamese ` +
        `dictionary would print; Thai in standard Thai script (อักษรไทย), natural ` +
        `wording a published Thai dictionary (ราชบัณฑิตยสภา) would use, no ` +
        `transliteration; Russian in Cyrillic citation form — nouns in nominative ` +
        `singular, verbs as the infinitive, adjectives in masculine nominative ` +
        `singular, as a published Russian dictionary would print; Spanish in ` +
        `citation form — nouns with their definite article to show gender ` +
        `(el/la), verbs as the infinitive, adjectives in masculine singular, ` +
        `as a published Spanish dictionary (RAE) would print; Portuguese ` +
        `(Brazilian) in citation form — nouns with their definite article to ` +
        `show gender (o/a), verbs as the infinitive, adjectives in masculine ` +
        `singular, as a published Brazilian Portuguese dictionary would print; ` +
        `French in citation form — nouns with their definite/indefinite article ` +
        `to show gender (le/la/un/une), verbs as the infinitive, adjectives in ` +
        `masculine singular, with correct accents, as a published French ` +
        `dictionary (Larousse/Le Robert) would print). ` +
        `Return ONLY JSON: {${langKeys}}`
      : `You are a professional translator. Translate this Chinese sentence ` +
        `faithfully and naturally into each requested language (no pinyin, ` +
        `no notes). Korean must be idiomatic 해요체; Japanese must be idiomatic ` +
        `polite 丁寧語 (です・ます体); Indonesian must be standard, natural bahasa ` +
        `baku with correct affixation; Vietnamese must be natural standard ` +
        `Vietnamese with correct diacritics/tone marks, grammatically perfect; ` +
        `Thai must be natural standard Thai in Thai script (อักษรไทย), no ` +
        `transliteration; Russian must be natural standard Russian in Cyrillic ` +
        `with correct case, gender, number and aspect, grammatically perfect; ` +
        `Spanish must be natural standard Spanish with correct gender/number ` +
        `agreement, accents and ¿¡ punctuation, grammatically perfect; ` +
        `Portuguese must be natural Brazilian Portuguese with correct ` +
        `gender/number agreement and accents (ã, õ, ç), grammatically perfect; ` +
        `French must be natural standard French with correct gender/number ` +
        `agreement, accents (é, è, ê, à, ç) and elision (l', d', j'), ` +
        `grammatically perfect.\n` +
        `Chinese: "${text}"\nReturn ONLY JSON: {${langKeys}}`;

    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.2,
        response_mime_type: "application/json",
      },
    });

    let lastErr = "";
    for (const model of MODEL_FALLBACKS) {
      for (const key of keys) {
        const r = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: reqBody,
          },
        );
        if (r.ok) {
          const data = await r.json();
          const raw: string =
            (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
          let parsed: Record<string, unknown> = {};
          try {
            parsed = JSON.parse(raw);
          } catch {
            const m = raw.match(/\{[\s\S]*\}/);
            if (m) { try { parsed = JSON.parse(m[0]); } catch { /* ignore */ } }
          }
          const translations: Record<string, string> = {};
          for (const l of langs) translations[l] = String(parsed[l] ?? "");
          return json({
            translation: translations[langs[0]] ?? "",
            translations,
          });
        }
        lastErr = `Gemini ${r.status} [${model}]: ${(await r.text()).slice(0, 200)}`;
        if (![429, 500, 502, 503].includes(r.status)) {
          return json({ error: lastErr }, 502);
        }
      }
    }
    return json({ error: lastErr || "all models exhausted" }, 502);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
