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

// ── Shared helpers ────────────────────────────────────────────────────────────

interface CaptionEvent {
  tStartMs: number;
  dDurationMs?: number;
  segs?: Array<{ utf8: string }>;
}

const hasChinese = (text: string) => /[一-鿿]/.test(text);

const CHINESE_LANG_CODES = [
  "zh-Hans", "zh-hans", "zh-Hant", "zh-hant",
  "zh", "zh-CN", "zh-TW", "zh-HK", "yue", "zh-yue", "cmn",
];

function isChinese(lang: string): boolean {
  return CHINESE_LANG_CODES.some(
    (c) => lang.toLowerCase() === c.toLowerCase() || lang.toLowerCase().startsWith("zh")
  );
}

// ── Method 1: Watch-page caption track extraction (most reliable) ─────────────
// YouTube embeds the full captionTracks array (with direct URLs) in the page HTML.
// This bypasses the undocumented timedtext list API which often returns nothing.

async function fetchCaptionsFromWatchPage(videoId: string): Promise<{
  events: CaptionEvent[];
  tracksFound: string[];
}> {
  try {
    const res = await fetch(
      `https://www.youtube.com/watch?v=${videoId}`,
      {
        headers: {
          "User-Agent": UA,
          "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
          "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
        },
      }
    );
    if (!res.ok) return { events: [], tracksFound: [] };
    const html = await res.text();

    // Locate "captionTracks": and bracket-match the JSON array
    const markerIdx = html.indexOf('"captionTracks":');
    if (markerIdx === -1) return { events: [], tracksFound: [] };

    const arrayStart = html.indexOf("[", markerIdx);
    if (arrayStart === -1) return { events: [], tracksFound: [] };

    let depth = 0;
    let arrayEnd = arrayStart;
    for (; arrayEnd < html.length; arrayEnd++) {
      if (html[arrayEnd] === "[") depth++;
      else if (html[arrayEnd] === "]") {
        if (--depth === 0) break;
      }
    }

    let tracks: Array<{
      baseUrl?: string;
      languageCode?: string;
      kind?: { captionTrackKind?: string };
    }>;
    try {
      tracks = JSON.parse(html.slice(arrayStart, arrayEnd + 1));
    } catch {
      return { events: [], tracksFound: [] };
    }

    const tracksFound = tracks
      .map((t) => t.languageCode ?? "")
      .filter(Boolean);

    const chineseTracks = tracks
      .filter((t) => t.languageCode && isChinese(t.languageCode))
      .sort((a, b) => {
        const aAsr = a.kind?.captionTrackKind === "ASR" ? 1 : 0;
        const bAsr = b.kind?.captionTrackKind === "ASR" ? 1 : 0;
        const aHans = (a.languageCode ?? "").toLowerCase().startsWith("zh-hans") ? 0 : 2;
        const bHans = (b.languageCode ?? "").toLowerCase().startsWith("zh-hans") ? 0 : 2;
        return (aAsr + aHans) - (bAsr + bHans);
      });

    for (const track of chineseTracks) {
      if (!track.baseUrl) continue;
      try {
        // Unescape HTML entities in the URL (YouTube encodes & as &amp; in HTML)
        const url = track.baseUrl.replace(/&amp;/g, "&");
        const captionRes = await fetch(`${url}&fmt=json3`);
        if (!captionRes.ok) continue;
        const data = await captionRes.json() as { events?: CaptionEvent[] };
        const events = (data.events ?? []).filter(
          (e) => e.segs?.some((s) => hasChinese(s.utf8))
        );
        if (events.length > 0) return { events, tracksFound };
      } catch { continue; }
    }

    return { events: [], tracksFound };
  } catch {
    return { events: [], tracksFound: [] };
  }
}

// ── Method 2: timedtext list API (legacy fallback) ────────────────────────────

interface TrackInfo {
  langCode: string;
  kind: string;
  name: string;
}

async function listCaptiontracks(videoId: string): Promise<TrackInfo[]> {
  try {
    const res = await fetch(
      `https://www.youtube.com/api/timedtext?v=${videoId}&type=list`,
      { headers: { "User-Agent": UA } }
    );
    if (!res.ok) return [];
    const xml = await res.text();
    const tracks: TrackInfo[] = [];
    for (const tag of xml.matchAll(/<track\s[^>]*>/g)) {
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

// ── Combined caption fetch: watch-page → list API → hardcoded fallback ────────

async function fetchCaptions(videoId: string): Promise<{
  events: CaptionEvent[];
  tracksFound: string[];
  tracksSearched: string[];
}> {
  const tracksSearched: string[] = [];

  // 1. Watch-page parsing (primary — most reliable)
  const watchResult = await fetchCaptionsFromWatchPage(videoId);
  if (watchResult.events.length > 0) {
    return {
      events: watchResult.events,
      tracksFound: watchResult.tracksFound,
      tracksSearched: ["watch-page"],
    };
  }
  tracksSearched.push("watch-page:empty");
  const tracksFound = [...watchResult.tracksFound];

  // 2. timedtext list API
  const listTracks = await listCaptiontracks(videoId);
  for (const t of listTracks) {
    const label = t.langCode + (t.kind ? `(${t.kind})` : "");
    if (!tracksFound.includes(t.langCode)) tracksFound.push(t.langCode);
    if (isChinese(t.langCode) && !tracksSearched.includes(label)) {
      tracksSearched.push(label);
    }
  }

  const chineseTracks = listTracks
    .filter((t) => isChinese(t.langCode))
    .sort((a, b) => {
      const aScore = (a.kind === "asr" ? 1 : 0) + (a.langCode.toLowerCase().startsWith("zh-hans") ? 0 : 2);
      const bScore = (b.kind === "asr" ? 1 : 0) + (b.langCode.toLowerCase().startsWith("zh-hans") ? 0 : 2);
      return aScore - bScore;
    });

  for (const track of chineseTracks) {
    const events = await fetchTrack(videoId, track.langCode, track.kind);
    if (events.length > 0) return { events, tracksFound, tracksSearched };
  }

  // 3. Hardcoded last-resort codes
  const fallbacks = [
    { langCode: "zh-Hans", kind: "" }, { langCode: "zh-Hans", kind: "asr" },
    { langCode: "zh", kind: "" },      { langCode: "zh", kind: "asr" },
    { langCode: "zh-Hant", kind: "" }, { langCode: "zh-Hant", kind: "asr" },
    { langCode: "yue", kind: "" },     { langCode: "yue", kind: "asr" },
  ];
  for (const track of fallbacks) {
    const label = track.langCode + (track.kind ? `(${track.kind})` : "");
    if (tracksSearched.includes(label)) continue;
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

// Sentence-aware segmentation. A segment closes when:
//   • the line ends with sentence punctuation, OR
//   • there is a silence gap before the next line (natural boundary — crucial
//     for auto-captions that carry no punctuation), OR
//   • it reaches maxDuration seconds, OR
//   • it reaches maxChars Chinese characters.
// Short utterances (min ~0.8s) are kept so lines like "这个能吃" aren't dropped.
function buildSegments(
  events: CaptionEvent[],
  { maxDuration = 10, maxChars = 45, maxGap = 1.0, minDuration = 0.8 } = {},
): Segment[] {
  const segments: Segment[] = [];
  let segStart: number | null = null;
  let segEnd = 0;
  let segText = "";
  const endsSentence = (t: string) => /[。！？!?…；;]\s*$/.test(t.trim());
  const hanziCount = (t: string) => (t.match(/[一-鿿]/g) ?? []).length;

  const flush = () => {
    const text = segText.trim();
    if (segStart !== null && text && segEnd - segStart >= minDuration) {
      segments.push({ start: segStart, end: segEnd, text });
    }
    segStart = null;
    segText = "";
  };

  for (const ev of events) {
    const start = ev.tStartMs / 1000;
    const end = (ev.tStartMs + (ev.dDurationMs ?? 2000)) / 1000;
    const text = (ev.segs ?? []).map((s) => s.utf8).join("").replace(/\n/g, "");
    if (!text.trim()) continue;

    // Close FIRST when this line would either start after a silence gap or
    // push the segment past maxDuration — closing before adding keeps every
    // merged segment ≤ maxDuration instead of overshooting by a whole line.
    if (
      segStart !== null &&
      (start - segEnd > maxGap || end - segStart > maxDuration)
    ) {
      flush();
    }

    if (segStart === null) {
      segStart = start;
      segEnd = end;
      segText = text;
    } else {
      segEnd = end;
      segText += text;
    }

    if (endsSentence(text) || hanziCount(segText) >= maxChars) {
      flush();
    }
  }
  flush();

  return segments;
}

// ── HSK / word analysis ───────────────────────────────────────────────────────

type SupabaseClient = ReturnType<typeof createClient>;

async function analyzeText(
  db: SupabaseClient,
  text: string
): Promise<{ words: string[]; hskLevel: number }> {
  const chunks = [...text.matchAll(/[一-鿿]+/g)].map((m) => m[0]);
  if (!chunks.length) return { words: [], hskLevel: 0 };

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

  if (!data?.length) return { words: [], hskLevel: 0 };

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
    const { url, active = false, hsk_filter } = await req.json() as {
      url: string;
      active?: boolean;
      hsk_filter?: number[];
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
        ? `Videoda ${tracksFound.join(", ")} dil izleri var ama Çince metin içermiyor.`
        : "Bu videoda Çince altyazı bulunamadı.";
      return json(
        { error: `Çince altyazı bulunamadı — ${detail} Whisper ASR butonunu deneyin.` },
        422
      );
    }

    const segments = buildSegments(events);
    if (!segments.length) return json({ error: "Segment oluşturulamadı." }, 422);

    const db = createClient(supabaseUrl, serviceKey);
    const analyses = await Promise.all(segments.map((seg) => analyzeText(db, seg.text)));

    const allRows = segments.map((seg, i) => ({
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

    const activeFilter = hsk_filter?.length ? hsk_filter : null;
    const rows = allRows.filter((r) => {
      if (r.hsk_level === 0) return false;
      if (activeFilter) return activeFilter.includes(r.hsk_level);
      return true;
    });

    const skipped = allRows.length - rows.length;
    const unknownSkipped = allRows.filter((r) => r.hsk_level === 0).length;
    const filterSkipped = skipped - unknownSkipped;

    if (!rows.length) {
      const detail = activeFilter
        ? `Filtre: HSK ${activeFilter.join("/")}. ${allRows.length} segmentten ${unknownSkipped} sözlük dışı, ${filterSkipped} farklı seviye.`
        : `${allRows.length} segmentin tamamı sözlükte eşleşen kelime içermiyor.`;
      return json({ error: `Kaydedilecek segment bulunamadı. ${detail}` }, 422);
    }

    const { error: insertErr } = await db.from("videos").insert(rows);
    if (insertErr) throw new Error(insertErr.message);

    return json({
      segmentsWritten: rows.length,
      segmentsSkipped: skipped,
      unknownSkipped,
      filterSkipped,
      eventCount: events.length,
      rawSegments: segments.length,
      tracksFound,
      tracksSearched,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
