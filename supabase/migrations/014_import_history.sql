-- Segmentation history: one row per YouTube source video we've split. Powers the
-- admin "Geçmiş" tab (list + placement view) and the re-import warning on the
-- import screen. channel/title/upload_year are filled best-effort by the local
-- worker (job_type='video_meta', yt-dlp metadata) after the import is recorded.
CREATE TABLE IF NOT EXISTS public.import_history (
  youtube_id    text PRIMARY KEY,
  url           text NOT NULL,
  title         text,
  channel       text,
  upload_year   int,
  clip_count    int DEFAULT 0,
  hsk_filter    int[],
  grammar_filter text[],
  word_filter   text[],
  segmented_at  timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

ALTER TABLE public.import_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ih_read ON public.import_history;
CREATE POLICY ih_read ON public.import_history FOR SELECT USING (true);

DROP POLICY IF EXISTS ih_admin_ins ON public.import_history;
CREATE POLICY ih_admin_ins ON public.import_history FOR INSERT
  WITH CHECK ((auth.jwt()->>'email') = 'berkaysayir@gmail.com');

DROP POLICY IF EXISTS ih_admin_upd ON public.import_history;
CREATE POLICY ih_admin_upd ON public.import_history FOR UPDATE
  USING ((auth.jwt()->>'email') = 'berkaysayir@gmail.com');

DROP POLICY IF EXISTS ih_admin_del ON public.import_history;
CREATE POLICY ih_admin_del ON public.import_history FOR DELETE
  USING ((auth.jwt()->>'email') = 'berkaysayir@gmail.com');

CREATE INDEX IF NOT EXISTS ih_segmented_at_idx
  ON public.import_history(segmented_at DESC);
