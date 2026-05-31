import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Gemini does the work only here, at authoring time. The generated options are
// stored on the video and served from the DB afterwards — no Gemini at runtime.
const MODEL = "gemini-2.0-flash";

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
    if (!key) return json({ error: "GEMINI_API_KEY ayarlı değil (Supabase secret)" }, 500);

    const langName =
      lang === "en" ? "English" : lang === "vi" ? "Vietnamese" : "Turkish";

    const prompt =
      `You are building a multiple-choice translation quiz for Mandarin Chinese ` +
      `learners. Target/answer language: ${langName}.\n\n` +
      `Chinese sentence: "${transcription}"\n` +
      (pinyin ? `Pinyin: "${pinyin}"\n` : "") +
      `\nReturn STRICT JSON with exactly these keys:\n` +
      `- "correctAnswer": an accurate, natural ${langName} translation of the sentence.\n` +
      `- "wrongAnswer": a ${langName} sentence that is VERY CLOSE to the correct ` +
      `meaning but subtly WRONG (e.g. swapped subject/object, a negation, one ` +
      `changed word) — a tempting distractor that is still clearly incorrect to ` +
      `someone who understands the sentence. Similar length to correctAnswer.\n` +
      `- "question": a short ${langName} prompt asking the user to pick the correct meaning.\n` +
      `Output ONLY the JSON object, no markdown.`;

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            response_mime_type: "application/json",
            temperature: 0.8,
          },
        }),
      },
    );

    if (!r.ok) {
      const t = await r.text();
      return json({ error: `Gemini ${r.status}: ${t.slice(0, 300)}` }, 502);
    }

    const data = await r.json();
    const text: string =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(text);
    } catch {
      const m = text.match(/\{[\s\S]*\}/);
      if (m) {
        try {
          parsed = JSON.parse(m[0]);
        } catch { /* ignore */ }
      }
    }

    return json({
      question: String(parsed.question ?? ""),
      correctAnswer: String(parsed.correctAnswer ?? ""),
      wrongAnswer: String(parsed.wrongAnswer ?? ""),
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
