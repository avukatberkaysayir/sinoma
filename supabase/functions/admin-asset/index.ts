// Admin backfill helper: receives a processed path asset (e.g. the Orni unit
// mascot animation webp) as a raw binary body and stores it with the
// service-role key — the Management API PAT used by local tooling cannot touch
// storage directly. Guarded by a shared header token like ko-batch.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GUARD = "sinoma-admin-asset-2026";
const URL_BASE = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// New-format secret keys (sb_secret_…) are not JWTs: passing them as a Bearer
// token trips "Invalid Compact JWS" — they authenticate via apikey alone.
const AUTH: Record<string, string> = KEY.startsWith("sb_")
  ? { apikey: KEY }
  : { apikey: KEY, Authorization: `Bearer ${KEY}` };

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.headers.get("x-backfill-guard") !== GUARD) {
    return new Response(JSON.stringify({ error: "forbidden" }), { status: 403 });
  }
  try {
    const q = new URL(req.url).searchParams;
    const level = Number(q.get("level"));
    const unit = Number(q.get("unit"));
    const kind = q.get("kind") ?? "mascot";
    const slot = Number(q.get("slot") ?? "0");
    const ext = q.get("ext") ?? "webp";
    const ctype = req.headers.get("content-type") ?? "application/octet-stream";
    if (!level || !unit) {
      return new Response(JSON.stringify({ error: "level/unit required" }), { status: 400 });
    }
    const bytes = new Uint8Array(await req.arrayBuffer());
    const path = `L${level}/U${unit}/${kind}_${slot}.${ext}`;
    const up = await fetch(`${URL_BASE}/storage/v1/object/path-assets/${path}`, {
      method: "POST",
      headers: { ...AUTH, "Content-Type": ctype, "x-upsert": "true" },
      body: bytes,
    });
    if (!up.ok) {
      return new Response(JSON.stringify({ error: `storage ${up.status}: ${await up.text()}` }),
        { status: 500 });
    }
    const url = `${URL_BASE}/storage/v1/object/public/path-assets/${path}?v=${Date.now()}`;
    const row = await fetch(
      `${URL_BASE}/rest/v1/path_assets?on_conflict=level,unit,kind,slot`, {
        method: "POST",
        headers: {
          ...AUTH,
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates",
        },
        body: JSON.stringify({ level, unit, kind, slot, url,
          updated_at: new Date().toISOString() }),
      });
    if (!row.ok) {
      return new Response(JSON.stringify({ error: `db ${row.status}: ${await row.text()}` }),
        { status: 500 });
    }
    return new Response(JSON.stringify({ url }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
