-- Manual learning-path level (L1-L6) override. Defaults to the grammar rule's
-- level when null; set explicitly in the admin to move a clip to another level.
ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS level INTEGER;
