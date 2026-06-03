import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MODEL = "gemini-2.5-flash";

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

    const key = Deno.env.get("GEMINI_API_KEY");
    // Fail-open: if the key is missing, keep everything (A–D already filtered).
    if (!key) return json({ keep: texts.map(() => 1), note: "no key, fail-open" });

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

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0,
            responseMimeType: "application/json",
          },
        }),
      },
    );
    if (!r.ok) {
      const t = await r.text();
      // Fail-open on upstream error so a Gemini outage never drops content.
      return json({ keep: texts.map(() => 1), error: `Gemini ${r.status}: ${t.slice(0, 200)}` });
    }
    const data = await r.json();
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
