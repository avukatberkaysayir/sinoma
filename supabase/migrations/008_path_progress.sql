-- Learning-path progress per user. A flat JSON map keyed by phase id
-- ("hsk1.s0.p2") → {"correct":7,"total":9,"done":true}. One column keeps RLS
-- simple (read/write the whole map atomically; single-user writes).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS path_progress JSONB NOT NULL DEFAULT '{}'::jsonb;
