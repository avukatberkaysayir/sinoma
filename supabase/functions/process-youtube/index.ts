import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

function extractYtId(input: string): string {
  try {
    const url = new URL(input.trim());
    if (url.hostname.includes("youtu.be")) return url.pathname.slice(1);
    return url.searchParams.get("v") ?? input.trim();
  } catch {
    return input.trim();
  }
}

// ── Caption track discovery ───────────────────────────────────────────────────

interface TrackInfo {
  langCode: string;
  kind: string; // '' | 'asr'
  name: string;
}

const CHINESE_LANG_CODES = [
  "zh-Hans", "zh-hans",
  "zh-Hant", "zh-hant",
  "zh", "zh-CN", "zh-TW", "zh-HK",
  "yue", "zh-yue",
  "cmn",
];

function isChinese(lang: string): boolean {
  return CHINESE_LANG_CODES.some(
    (c) => lang.toLowerCase() === c.toLowerCase() || lang.toLowerCase().startsWith("zh")
  );
}

async function listCaptiontracks(videoId: string): Promise<TrackInfo[]> {
  try {
    const res = await fetch(
      `https://www.youtube.com/api/timedtext?v=${videoId}&type=list`,
      { headers: { "User-Agent": UA } }
    );
    if (!res.ok) return [];
    const xml = await res.text();

    // Parse <track id="..." lang_code="zh-Hans" name="..." kind="asr" ... />
    const tracks: TrackInfo[] = [];
    const regex = /<track\s[^>]*>/g;
    for (const tag of xml.matchAll(regex)) {
      const langCode = tag[0].match(/lang_code="([^"]+)"/)?.[1] ?? "";
      const kind = tag[0].match(/kind="([^"]+)"/)?.[1] ?? "";
      const name = tag[0].match(/name="([^"]+)"/)?.[1] ?? "";
      if (langCode) tracks.push({ langCode, kind, name });
    }
    return tracks;
  } catch {
    return [];
  }
}

// ── Caption event fetching ────────────────────────────────────────────────────

interface CaptionEvent {
  tStartMs: number;
  dDurationMs?: number;
  segs?: Array<{ utf8: string }>;
}

const hasChinese = (text: string) => /[一-鿿]/.test(text);

async function fetchTrack(
  videoId: string,
  langCode: string,
  kind: string
): Promise<CaptionEvent[]> {
  const kindParam = kind === "asr" ? "&kind=asr" : "";
  const url = `https://www.youtube.com/api/timedtext?v=${videoId}&lang=${langCode}&fmt=json3${kindParam}`;
  try {
    const res = await fetch(url, { headers: { "User-Agent": UA } });
    if (!res.ok) return [];
    const data = await res.json() as { events?: CaptionEvent[] };
    return (data.events ?? []).filter(
      (e) => e.segs?.some((s) => hasChinese(s.utf8))
    );
  } catch {
    return [];
  }
}

async function fetchCaptions(videoId: string): Promise<{
  events: CaptionEvent[];
  tracksFound: string[];
  tracksSearched: string[];
}> {
  // 1. Discover all available tracks for this video
  const allTracks = await listCaptiontracks(videoId);
  const tracksFound = allTracks.map((t) => `${t.langCode}${t.kind ? `(${t.kind})` : ""}`);

  // 2. Try discovered Chinese tracks first
  const chineseTracks = allTracks.filter((t) => isChinese(t.langCode));
  // Prefer manual captions over ASR; prefer zh-Hans over others
  chineseTracks.sort((a, b) => {
    const aScore = (a.kind === "asr" ? 1 : 0) + (a.langCode.toLowerCase().startsWith("zh-hans") ? 0 : 2);
    const bScore = (b.kind === "asr" ? 1 : 0) + (b.langCode.toLowerCase().startsWith("zh-hans") ? 0 : 2);
    return aScore - bScore;
  });

  const tracksSearched: string[] = [];
  for (const track of chineseTracks) {
    const label = `${track.langCode}${track.kind ? `(${track.kind})` : ""}`;
    tracksSearched.push(label);
    const events = await fetchTrack(videoId, track.langCode, track.kind);
    if (events.length > 0) return { events, tracksFound, tracksSearched };
  }

  // 3. Fallback: try hardcoded list (catches videos where type=list returned empty)
  const fallbacks: TrackInfo[] = [
    { langCode: "zh-Hans", kind: "", name: "" },
    { langCode: "zh-Hans", kind: "asr", name: "" },
    { langCode: "zh", kind: "", name: "" },
    { langCode: "zh", kind: "asr", name: "" },
    { langCode: "zh-Hant", kind: "", name: "" },
    { langCode: "zh-Hant", kind: "asr", name: "" },
    { langCode: "yue", kind: "", name: "" },
    { langCode: "yue", kind: "asr", name: "" },
  ];
  for (const track of fallbacks) {
    const label = `${track.langCode}${track.kind ? `(${track.kind})` : ""}`;
    if (tracksSearched.includes(label)) continue; // already tried
    tracksSearched.push(label);
    const events = await fetchTrack(videoId, track.langCode, track.kind);
    if (events.length > 0) return { events, tracksFound, tracksSearched };
  }

  return { events: [], tracksFound, tracksSearched };
}

// ── Segment building ──────────────────────────────────────────────────────────

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

// ── HSK / word analysis ───────────────────────────────────────────────────────

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
  const raw = Math.max(...data.map((r: { id: string; hsk_level: number }) => r.hsk_level ?? 1));
  const hskLevel = Math.min(6, Math.max(1, raw));
  return { words, hskLevel };
}

// ── Handler ───────────────────────────────────────────────────────────────────

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

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    // Verify admin
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

    const { events, tracksFound, tracksSearched } = await fetchCaptions(videoId);

    if (!events.length) {
      const detail = tracksFound.length
        ? `Videoda ${tracksFound.join(", ")} track'leri var ama Çince metin içermiyor.`
        : "Bu videoda hiç altyazı track'i bulunamadı.";
      return json(
        { error: `Çince altyazı bulunamadı — ${detail} Manuel segment oluşturucuyu kullanın.` },
        422
      );
    }

    const segments = buildSegments(events);
    if (!segments.length) return json({ error: "Segment oluşturulamadı." }, 422);

    const db = createClient(supabaseUrl, serviceKey);

    const analyses = await Promise.all(segments.map((seg) => analyzeText(db, seg.text)));
    const rows = segments.map((seg, i) => ({
      source_type: "youtube",
      youtube_id: videoId,
      start_time: seg.start,
      end_time: seg.end,
      transcription: seg.text,
      pinyin: "",
      hsk_level: analyses[i].hskLevel,
      target_words: analyses[i].words,
      quiz_category: "general",
      quiz: { question: "", correctAnswer: "", wrongAnswer: "" },
      status: "pending",
      is_active: false,
    }));

    const { error: insertErr } = await db.from("videos").insert(rows);
    if (insertErr) throw new Error(insertErr.message);

    return json({
      segmentsWritten: rows.length,
      tracksFound,
      tracksSearched,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
