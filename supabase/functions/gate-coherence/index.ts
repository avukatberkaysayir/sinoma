import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// flash-lite default for the higher free-tier daily quota; GEMINI_MODEL overrides.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";

// Multiple keys (GEMINI_API_KEYS comma-list and/or GEMINI_API_KEY, _2.._5) so a
// daily-quota wall on one key rotates to the next instead of failing. The import
// pipeline calls this per batch, so it's the heaviest Gemini consumer.
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

// Coherence gate (anti-hallucination layer E). Given a batch of ASR/Whisper
// Chinese segment texts, asks Gemini which ones are real, coherent spoken
// Mandarin vs. hallucinated gibberish / stuck repetition / non-speech artifacts
// (the kind Whisper invents over music or silence). Returns keep[i] = 1|0.
// Conservative by design: keep anything plausibly real, drop only clear garbage.
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const texts: string[] = Array.isArray(body.texts)
      ? body.texts.map((t: unknown) => (t ?? "").toString())
      : [];
    if (texts.length === 0) return json({ keep: [] });

    const keys = geminiKeys();
    // Fail-open: if no key is set, keep everything (A–D already filtered).
    if (!keys.length) return json({ keep: texts.map(() => 1), note: "no key, fail-open" });

    const numbered = texts
      .map((t, i) => `${i}: ${t.replace(/\s+/g, " ").trim()}`)
      .join("\n");
    const prompt =
      "You are an anti-hallucination filter for Mandarin speech-to-text. " +
      "Below are numbered transcript segments produced by an ASR model. Some " +
      "are real spoken Mandarin; some are hallucinations the model invented " +
      "over music or silence. Return 0 (drop) for a segment if it is any of: " +
      "(a) gibberish or random unrelated characters; (b) stuck single-word or " +
      "phrase repetition; (c) text that is not natural spoken Chinese; or " +
      "(d) YouTube/streaming boilerplate that ASR models notoriously " +
      "hallucinate — e.g. requests to like / subscribe / share / follow / " +
      "donate / reward, channel or sponsor credits, or '字幕'/'subtitles by' " +
      "credit lines — DROP these even though they are grammatically correct, " +
      "because they are not part of the actual dialogue. Otherwise return 1 " +
      "(keep). For genuine conversational/narration content, when unsure, " +
      'return 1. Return ONLY a JSON object {"keep":[...]} with one 0/1 per ' +
      `index, in order.\n\n${numbered}`;

    const reqInit = {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0, responseMimeType: "application/json" },
      }),
    };
    // Try each key; rotate past a quota-exhausted one. Non-quota errors stop early.
    // deno-lint-ignore no-explicit-any
    let data: any = null;
    let lastErr = "";
    for (const key of keys) {
      const r = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
        reqInit,
      );
      if (r.ok) { data = await r.json(); break; }
      lastErr = `Gemini ${r.status}: ${(await r.text()).slice(0, 200)}`;
      if (!/429|quota|RESOURCE_EXHAUSTED|50[0234]|overload|unavailable/i.test(lastErr)) break;
    }
    // Fail-open on upstream error so a Gemini outage never drops content.
    if (!data) return json({ keep: texts.map(() => 1), error: lastErr });
    const raw: string =
      (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();

    let keep: number[];
    try {
      const parsed = JSON.parse(raw);
      const arr: unknown[] = Array.isArray(parsed) ? parsed : parsed?.keep;
      keep = texts.map((_, i) => (Number(arr?.[i]) === 0 ? 0 : 1));
    } catch (_e) {
      keep = texts.map(() => 1); // unparseable → fail-open
    }
    return json({ keep });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
