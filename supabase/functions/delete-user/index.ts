import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response("Unauthorized", { status: 401 });

    // Verify the calling user via anon client
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data: { user }, error: authErr } = await anonClient.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (authErr || !user) return new Response("Unauthorized", { status: 401 });

    const uid = user.id;

    // Use service role client for privileged deletes
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    // 1. Soft-delete all user's posts
    await admin.from("posts").delete().eq("author_id", uid);

    // 2. Remove user from followers/following arrays of others
    await admin.rpc("remove_user_from_social_arrays", { p_uid: uid });

    // 3. Delete pipeline jobs authored by user (if any)
    await admin.from("pipeline_jobs")
      .delete()
      .filter("payload->>'userId'", "eq", uid);

    // 4. Delete the users row (cascade handles learned_words, stats etc.)
    await admin.from("users").delete().eq("id", uid);

    // 5. Delete the auth user — irreversible
    const { error: deleteErr } = await admin.auth.admin.deleteUser(uid);
    if (deleteErr) throw new Error(deleteErr.message);

    return new Response(
      JSON.stringify({ deleted: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
