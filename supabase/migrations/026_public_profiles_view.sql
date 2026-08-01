-- 026_public_profiles_view.sql
-- Security (2026-08-01 audit): policy "Authenticated users can read all" let any
-- signed-in user SELECT * on public.users — exposing email, is_premium,
-- ai_credits, diamonds, stripe_customer_id, birthday, gender, mother_tongue and
-- path_progress of EVERY user. Drop that policy so the table itself is
-- own-row-only (policy "Users can read own profile" stays). Cross-user social
-- reads (search, leaderboard, follower lists) go through public_profiles, a view
-- that exposes only the safe, social columns.

DROP POLICY IF EXISTS "Authenticated users can read all" ON public.users;

-- security_invoker = false → the view runs with its owner's rights and bypasses
-- the now own-row-only RLS on users, returning the safe columns for ALL rows.
CREATE OR REPLACE VIEW public.public_profiles
  WITH (security_invoker = false) AS
SELECT id, username, display_name, photo_url, hsk_level,
       followers, following, learned_words, stats, is_online,
       league, weekly_score, created_at
FROM public.users;

-- Supabase's default privileges hand new views full CRUD to anon+authenticated.
-- A simple view is auto-updatable and, with security_invoker=false, its writes
-- run as owner and bypass users RLS — so an authenticated user could UPDATE any
-- profile through it. Strip everything, then grant SELECT to authenticated only.
REVOKE ALL ON public.public_profiles FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.public_profiles TO authenticated;

NOTIFY pgrst, 'reload schema';
