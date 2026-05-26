-- Sprint 8: Supabase-backed Remote Config
-- Allows hot-changing feature flags and tuning values without redeployment.

CREATE TABLE IF NOT EXISTS public.app_config (
  key   TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT 'null'
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read config"
  ON public.app_config FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Only admins can modify config"
  ON public.app_config FOR ALL TO authenticated
  USING  ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com')
  WITH CHECK ((SELECT email FROM auth.users WHERE id = auth.uid()) = 'berkaysayir@gmail.com');

-- Seed defaults (ON CONFLICT keeps existing values if table already populated)
INSERT INTO public.app_config (key, value) VALUES
  ('interstitial_frequency_first',  '20'),
  ('interstitial_frequency_repeat', '10'),
  ('ai_credits_daily_free',         '5'),
  ('max_ai_credits',                '50'),
  ('min_hsk_videos_required',       '20'),
  ('min_learned_words_required',    '50'),
  ('placement_test_enabled',        'true'),
  ('rewarded_ad_credits_amount',    '10'),
  ('hanzi_build_enabled',           'true'),
  ('social_feed_enabled',           'true')
ON CONFLICT (key) DO NOTHING;
