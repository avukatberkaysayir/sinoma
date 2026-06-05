-- Manual learning-path placement of a video: which unit (1-30) and which phase
-- circle (1-4) within its level. The level (L) itself is derived from the
-- video's grammar rule, so it isn't stored.
ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS unit  INTEGER,
  ADD COLUMN IF NOT EXISTS phase INTEGER;
