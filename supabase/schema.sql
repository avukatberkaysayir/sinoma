-- Sinoma — Supabase PostgreSQL Schema
-- Run this in the Supabase SQL editor to set up the database.
-- RLS (Row Level Security) is enabled on all tables.

-- ── Extensions ────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.users (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name          TEXT NOT NULL DEFAULT '',
  last_name             TEXT NOT NULL DEFAULT '',
  email                 TEXT NOT NULL DEFAULT '',
  photo_url             TEXT NOT NULL DEFAULT '',
  hsk_level             INTEGER NOT NULL DEFAULT 1 CHECK (hsk_level BETWEEN 1 AND 6),
  is_premium            BOOLEAN NOT NULL DEFAULT FALSE,
  ai_credits            INTEGER NOT NULL DEFAULT 5 CHECK (ai_credits >= 0),
  followers             TEXT[] NOT NULL DEFAULT '{}',
  following             TEXT[] NOT NULL DEFAULT '{}',
  learned_words         TEXT[] NOT NULL DEFAULT '{}',
  stats                 JSONB NOT NULL DEFAULT '{"totalScore":0,"videosWatched":0,"questionsAnswered":0,"currentStreak":0}',
  is_online             BOOLEAN NOT NULL DEFAULT FALSE,
  birthday              TIMESTAMPTZ,
  gender                TEXT NOT NULL DEFAULT '',
  mother_tongue         TEXT NOT NULL DEFAULT 'tr',
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"       ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"     ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile"     ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can delete own profile"     ON public.users FOR DELETE USING (auth.uid() = id);
CREATE POLICY "Authenticated users can read all" ON public.users FOR SELECT TO authenticated USING (TRUE);

-- ── Videos ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.videos (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  source_type   TEXT NOT NULL DEFAULT 'youtube' CHECK (source_type IN ('youtube', 'self_hosted')),
  youtube_id    TEXT,
  video_url     TEXT,
  start_time    DOUBLE PRECISION NOT NULL DEFAULT 0,
  end_time      DOUBLE PRECISION NOT NULL DEFAULT 0,
  hsk_level     INTEGER NOT NULL DEFAULT 1 CHECK (hsk_level BETWEEN 1 AND 6),
  transcription TEXT NOT NULL DEFAULT '',
  pinyin        TEXT NOT NULL DEFAULT '',
  target_words  TEXT[] NOT NULL DEFAULT '{}',
  quiz          JSONB NOT NULL DEFAULT '{"question":"","correctAnswer":"","wrongAnswer":""}',
  quiz_category TEXT NOT NULL DEFAULT 'general',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read videos"
  ON public.videos FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Only admins can insert videos"
  ON public.videos FOR INSERT TO authenticated
  WITH CHECK ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');

CREATE POLICY "Only admins can update videos"
  ON public.videos FOR UPDATE TO authenticated
  USING ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');

CREATE POLICY "Only admins can delete videos"
  ON public.videos FOR DELETE TO authenticated
  USING ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');

CREATE INDEX IF NOT EXISTS idx_videos_hsk_active ON public.videos (hsk_level, is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_category   ON public.videos (quiz_category, hsk_level, is_active);

-- ── Dictionary ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.dictionary (
  id               TEXT PRIMARY KEY,
  simplified       TEXT NOT NULL DEFAULT '',
  traditional      TEXT NOT NULL DEFAULT '',
  pinyin           TEXT NOT NULL DEFAULT '',
  hsk_level        INTEGER NOT NULL DEFAULT 0,
  definitions      JSONB NOT NULL DEFAULT '{"tr":"","en":"","vi":""}',
  ai_context_cache JSONB NOT NULL DEFAULT '{}',
  radicals         TEXT[] NOT NULL DEFAULT '{}',
  stroke_count     INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.dictionary ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read dictionary"
  ON public.dictionary FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Only admins can modify dictionary"
  ON public.dictionary FOR ALL TO authenticated
  USING ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com')
  WITH CHECK ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');

CREATE INDEX IF NOT EXISTS idx_dictionary_pinyin ON public.dictionary (pinyin);

CREATE INDEX IF NOT EXISTS idx_dictionary_simplified ON public.dictionary (simplified);
CREATE INDEX IF NOT EXISTS idx_dictionary_hsk        ON public.dictionary (hsk_level);

-- ── Posts ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content        TEXT NOT NULL DEFAULT '',
  attachment_url TEXT,
  likes          TEXT[] NOT NULL DEFAULT '{}',
  post_type      TEXT NOT NULL DEFAULT 'text' CHECK (post_type IN ('achievement','score','challenge','text')),
  metadata       JSONB NOT NULL DEFAULT '{}',
  timestamp      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read posts"
  ON public.posts FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Users can create own posts"
  ON public.posts FOR INSERT TO authenticated WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update own posts"
  ON public.posts FOR UPDATE TO authenticated USING (auth.uid() = author_id);

CREATE POLICY "Users can delete own posts"
  ON public.posts FOR DELETE TO authenticated USING (auth.uid() = author_id);

CREATE INDEX IF NOT EXISTS idx_posts_author_time ON public.posts (author_id, timestamp DESC);

-- ── Game Requests ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.game_requests (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_uid   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_uid     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  hsk_level  INTEGER NOT NULL DEFAULT 1,
  status     TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.game_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own game requests"
  ON public.game_requests FOR SELECT TO authenticated
  USING (auth.uid() = from_uid OR auth.uid() = to_uid);

CREATE POLICY "Users can create game requests"
  ON public.game_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = from_uid);

CREATE POLICY "Users can update game requests sent to them"
  ON public.game_requests FOR UPDATE TO authenticated USING (auth.uid() = to_uid);

CREATE INDEX IF NOT EXISTS idx_game_requests_to ON public.game_requests (to_uid, status, created_at DESC);

-- ── GDPR Consent ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.gdpr_consent (
  uid               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_given     BOOLEAN NOT NULL DEFAULT FALSE,
  consent_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  app_version       TEXT NOT NULL DEFAULT '',
  consent_version   TEXT NOT NULL DEFAULT ''
);

ALTER TABLE public.gdpr_consent ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own GDPR consent"
  ON public.gdpr_consent FOR ALL TO authenticated USING (auth.uid() = uid);

-- ── AI Credit RPC Functions ───────────────────────────────────────────────────

-- Call: supabase.rpc('decrement_ai_credits')
-- Returns the new credit balance, or raises P0001 if quota is 0.
CREATE OR REPLACE FUNCTION public.decrement_ai_credits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_credits INTEGER;
  new_credits     INTEGER;
BEGIN
  SELECT ai_credits INTO current_credits
  FROM public.users
  WHERE id = auth.uid()
  FOR UPDATE;

  IF current_credits IS NULL THEN
    RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0001';
  END IF;

  IF current_credits <= 0 THEN
    RAISE EXCEPTION 'AI credit quota exceeded' USING ERRCODE = 'P0001';
  END IF;

  new_credits := current_credits - 1;
  UPDATE public.users SET ai_credits = new_credits WHERE id = auth.uid();
  RETURN new_credits;
END;
$$;

-- Call: supabase.rpc('grant_ai_credits', params: {'p_amount': 10})
-- Returns the new credit balance.
CREATE OR REPLACE FUNCTION public.grant_ai_credits(p_amount INTEGER DEFAULT 10)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_credits     INTEGER;
  max_credits CONSTANT INTEGER := 50;
BEGIN
  UPDATE public.users
  SET ai_credits = LEAST(ai_credits + p_amount, max_credits)
  WHERE id = auth.uid()
  RETURNING ai_credits INTO new_credits;

  IF new_credits IS NULL THEN
    RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0001';
  END IF;

  RETURN new_credits;
END;
$$;

-- ── Realtime ──────────────────────────────────────────────────────────────────
-- Enable realtime for tables that use .stream() subscriptions.

ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_requests;
