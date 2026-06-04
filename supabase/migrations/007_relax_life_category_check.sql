-- The life_category CHECK (daily_life/business/children) blocks the expanded
-- topic set (family, food, travel, business, school, health, technology,
-- entertainment, sports, …). Categories are now validated in app code
-- (LifeCategory), so drop the rigid DB constraint.

ALTER TABLE public.videos
  DROP CONSTRAINT IF EXISTS videos_life_category_check;
