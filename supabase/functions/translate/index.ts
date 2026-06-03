import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// flash-lite default for the higher free-tier daily quota; GEMINI_MODEL overrides.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Faithful, literal translation of a Chinese sentence — used in the admin to
// sanity-check that an ASR/Whisper transcription actually makes sense.
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const text = (body.text ?? "").toString().trim();
    const lang = (body.lang ?? "tr").toString();
    if (!text) return json({ translation: "" });

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ error: "GEMINI_API_KEY not set" }, 500);

    const langName = lang === "en" ? "English" : "Turkish";
    const prompt =
      `Translate this Chinese sentence into ${langName}. Give ONLY the faithful, ` +
      `natural translation — no pinyin, no notes, no quotes.\n\nChinese: "${text}"`;

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2 },
        }),
      },
    );
    if (!r.ok) {
      const t = await r.text();
      return json({ error: `Gemini ${r.status}: ${t.slice(0, 200)}` }, 502);
    }
    const data = await r.json();
    const out: string =
      (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
    return json({ translation: out });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
