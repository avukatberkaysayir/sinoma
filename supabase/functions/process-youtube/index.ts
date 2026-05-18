import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function extractYtId(input: string): string {
  try {
    const url = new URL(input.trim());
    if (url.hostname.includes("youtu.be")) return url.pathname.slice(1);
    return url.searchParams.get("v") ?? input.trim();
  } catch {
    return input.trim();
  }
}

interface CaptionEvent {
  tStartMs: number;
  dDurationMs?: number;
  segs?: Array<{ utf8: string }>;
}

async function fetchCaptions(videoId: string): Promise<CaptionEvent[]> {
  const candidates = [
    `https://www.youtube.com/api/timedtext?lang=zh-Hans&v=${videoId}&fmt=json3`,
    `https://www.youtube.com/api/timedtext?lang=zh-Hans&v=${videoId}&fmt=json3&kind=asr`,
    `https://www.youtube.com/api/timedtext?lang=zh&v=${videoId}&fmt=json3`,
    `https://www.youtube.com/api/timedtext?lang=zh&v=${videoId}&fmt=json3&kind=asr`,
    `https://www.youtube.com/api/timedtext?lang=zh-Hant&v=${videoId}&fmt=json3`,
  ];

  const hasChinese = (text: string) => /[一-鿿]/.test(text);

  for (const url of candidates) {
    try {
      const res = await fetch(url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      });
      if (!res.ok) continue;
      const data = await res.json() as { events?: CaptionEvent[] };
      const events = (data.events ?? []).filter(
        (e) => e.segs?.some((s) => hasChinese(s.utf8))
      );
      if (events.length > 0) return events;
    } catch {
      continue;
    }
  }
  return [];
}

interface Segment {
  start: number;
  end: number;
  text: string;
}

function buildSegments(events: CaptionEvent[], targetDuration = 7): Segment[] {
  const segments: Segment[] = [];
  let segStart: number | null = null;
  let segEnd = 0;
  let segText = "";

  for (const ev of events) {
    const start = ev.tStartMs / 1000;
    const end = (ev.tStartMs + (ev.dDurationMs ?? 2000)) / 1000;
    const text = (ev.segs ?? []).map((s) => s.utf8).join("").replace(/\n/g, "");
    if (!text.trim()) continue;

    if (segStart === null) {
      segStart = start;
      segEnd = end;
      segText = text;
    } else if (end - segStart <= targetDuration + 3) {
      segEnd = end;
      segText += text;
    } else {
      if (segText.trim() && segEnd - segStart! >= 2) {
        segments.push({ start: segStart!, end: segEnd, text: segText.trim() });
      }
      segStart = start;
      segEnd = end;
      segText = text;
    }
  }

  if (segStart !== null && segText.trim() && segEnd - segStart >= 2) {
    segments.push({ start: segStart, end: segEnd, text: segText.trim() });
  }

  return segments;
}

type SupabaseClient = ReturnType<typeof createClient>;

async function analyzeText(
  db: SupabaseClient,
  text: string
): Promise<{ words: string[]; hskLevel: number }> {
  const chunks = [...text.matchAll(/[一-鿿]+/g)].map((m) => m[0]);
  if (!chunks.length) return { words: [], hskLevel: 1 };

  const candidates = new Set<string>();
  for (const chunk of chunks) {
    for (let i = 0; i < chunk.length; i++) {
      for (let len = 1; len <= Math.min(4, chunk.length - i); len++) {
        candidates.add(chunk.slice(i, i + len));
      }
    }
  }

  const { data } = await db
    .from("dictionary")
    .select("id, hsk_level")
    .in("simplified", [...candidates]);

  if (!data?.length) return { words: [], hskLevel: 1 };

  const words = data.map((r: { id: string; hsk_level: number }) => r.id);
  const hskLevel = Math.max(
    ...data.map((r: { id: string; hsk_level: number }) => r.hsk_level ?? 1)
  );

  return { words, hskLevel };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { url, active = false } = await req.json() as {
      url: string;
      active?: boolean;
    };
    if (!url) return json({ error: "url zorunlu" }, 400);

    // Verify the caller is the admin
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    const callerDb = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await callerDb.auth.getUser();
    if (!user || user.email !== "berkaysayir@gmail.com") {
      return json({ error: "Yetkisiz erişim" }, 403);
    }

    const videoId = extractYtId(url);
    if (videoId.length < 4) return json({ error: "Geçersiz YouTube URL" }, 400);

    const events = await fetchCaptions(videoId);
    if (!events.length) {
      return json(
        {
          error:
            "Bu video için Çince altyazı bulunamadı. Lütfen altyazısı olan bir video deneyin.",
        },
        422
      );
    }

    const segments = buildSegments(events);
    if (!segments.length) {
      return json({ error: "Segment oluşturulamadı." }, 422);
    }

    const db = createClient(supabaseUrl, serviceKey);

    const rows = [];
    for (const seg of segments) {
      const { words, hskLevel } = await analyzeText(db, seg.text);
      rows.push({
        source_type: "youtube",
        youtube_id: videoId,
        start_time: seg.start,
        end_time: seg.end,
        transcription: seg.text,
        pinyin: "",
        hsk_level: hskLevel,
        target_words: words,
        quiz_category: "general",
        quiz: { question: "", correctAnswer: "", wrongAnswer: "" },
        is_active: active,
      });
    }

    const { error: insertErr } = await db.from("videos").insert(rows);
    if (insertErr) throw new Error(insertErr.message);

    return json({ segmentsWritten: rows.length });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
