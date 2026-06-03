-- Multi-tag classification for videos: a clip can carry several HSK levels,
-- grammar categories and life categories so it shows under every matching home
-- filter. The single hsk_level / quiz_category / life_category columns stay as
-- the "primary" (first tag) for backward compatibility and the card badge.
-- Length (SinoRhythm) stays derived from the sentence — not stored.

alter table public.videos
  add column if not exists hsk_levels      int[]  not null default '{}',
  add column if not exists quiz_categories text[] not null default '{}',
  add column if not exists life_categories text[] not null default '{}';

-- Backfill existing rows from the single values.
update public.videos set
  hsk_levels = case when hsk_level is not null then array[hsk_level] else '{}'::int[] end,
  quiz_categories = case when coalesce(quiz_category,'') <> '' then array[quiz_category] else '{}'::text[] end,
  life_categories = case when coalesce(life_category,'') <> '' then array[life_category] else '{}'::text[] end
where cardinality(hsk_levels) = 0;
