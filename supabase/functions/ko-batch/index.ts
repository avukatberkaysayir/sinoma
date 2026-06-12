// TEMPORARY backfill proxy: forwards a prepared prompt to Gemini using the
// project's API keys (which are only available server-side). Guarded by a
// shared header token. Delete this function once the Korean backfill is done.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
const GUARD = "sinoma-ko-backfill-2026";

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

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.headers.get("x-backfill-guard") !== GUARD) {
    return new Response(JSON.stringify({ error: "forbidden" }), { status: 403 });
  }
  try {
    const body = await req.json();
    const prompt = String(body.prompt ?? "");
    if (!prompt) {
      return new Response(JSON.stringify({ error: "prompt required" }), { status: 400 });
    }
    // Per-model free-tier quotas are separate buckets; the caller may pick one.
    const model = String(body.model ?? MODEL);
    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: Number(body.temperature ?? 0.2),
      },
    });
    const keys = geminiKeys();
    let lastErr = "";
    for (const key of keys) {
      for (let i = 0; i < 3; i++) {
        const r = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: reqBody },
        );
        if (r.ok) {
          const data = await r.json();
          const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          return new Response(JSON.stringify({ text }), {
            headers: { "Content-Type": "application/json" },
          });
        }
        lastErr = `Gemini ${r.status}: ${(await r.text()).slice(0, 900)}`;
        if (r.status === 429 && /per ?day|PerDay/i.test(lastErr)) break; // next key
        if (![429, 500, 502, 503, 504].includes(r.status)) {
          return new Response(JSON.stringify({ error: lastErr }), { status: 502 });
        }
        await sleep(1500 * (i + 1));
      }
    }
    return new Response(JSON.stringify({ error: lastErr || "no keys" }), { status: 502 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
