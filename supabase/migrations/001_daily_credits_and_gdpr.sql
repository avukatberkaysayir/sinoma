-- ── Migration 001: Daily credit refresh + GDPR helpers ───────────────────────
-- Run this in Supabase SQL Editor after enabling pg_cron:
--   Dashboard → Database → Extensions → pg_cron → Enable

-- ── Daily credit refresh ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.refresh_daily_credits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET ai_credits = 5
  WHERE is_premium = FALSE AND ai_credits < 5;
END;
$$;

-- Schedule: every day at 00:00 UTC
-- Requires pg_cron extension (enable in Supabase Dashboard → Extensions)
SELECT cron.schedule(
  'sinoma-daily-credit-refresh',
  '0 0 * * *',
  'SELECT public.refresh_daily_credits()'
);

-- ── GDPR: remove user from social arrays ─────────────────────────────────────
-- Called by the delete-user edge function before deleting the auth user.

CREATE OR REPLACE FUNCTION public.remove_user_from_social_arrays(p_uid TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET
    followers = array_remove(followers, p_uid),
    following = array_remove(following, p_uid)
  WHERE p_uid = ANY(followers) OR p_uid = ANY(following);
END;
$$;

-- ── videos: add life_category column if not exists ───────────────────────────
-- Supports home screen life-category filter (daily_life / business / children)

ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS life_category TEXT NOT NULL DEFAULT 'daily_life'
  CHECK (life_category IN ('daily_life', 'business', 'children'));

CREATE INDEX IF NOT EXISTS idx_videos_life_category
  ON public.videos (life_category, hsk_level, is_active);
