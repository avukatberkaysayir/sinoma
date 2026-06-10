-- Per (level, unit, phase) slot-fill stats for the admin Aktif / Yedek cascade
-- colouring: red = no video, yellow = ≥1 video but not every slot filled, green =
-- every grammar + word slot filled. The admin aggregates these rows up to unit and
-- level. "Active" view uses (total, filled, vids); "Yedek" uses (total, bfilled, bvids).
--   total   — grammar + word slots that belong to this (level,unit,phase)
--   filled  — of those, how many have an ACTIVE video pinned to the slot
--   vids    — active videos physically placed at this (level,unit,phase)
--   bfilled — slots with a BACKUP clip (pending + backup_* set)
--   bvids   — backup clips at this (level,unit,phase)
CREATE OR REPLACE FUNCTION public.path_fill_stats()
RETURNS TABLE(level int, unit int, phase int,
              total bigint, filled bigint, vids bigint,
              bfilled bigint, bvids bigint)
LANGUAGE sql STABLE AS $$
  WITH slots AS (
    SELECT s.level, s.unit, s.phase, s.word AS key, false AS is_gram
      FROM public.path_word_slots s
    UNION ALL
    SELECT gl.level, gl.unit, 1 AS phase, gl.name AS key, true AS is_gram
      FROM public.grammar_levels gl
  ),
  slotstat AS (
    SELECT s.level, s.unit, s.phase,
      count(*) AS total,
      count(*) FILTER (WHERE EXISTS (
        SELECT 1 FROM public.videos v WHERE v.status = 'active'
          AND ((NOT s.is_gram AND v.slot_word = s.key)
            OR (s.is_gram AND v.slot_grammar = s.key)))) AS filled,
      count(*) FILTER (WHERE EXISTS (
        SELECT 1 FROM public.videos v
          WHERE v.status = 'pending' AND v.backup_level IS NOT NULL
          AND ((NOT s.is_gram AND v.backup_word = s.key)
            OR (s.is_gram AND v.backup_grammar = s.key)))) AS bfilled
    FROM slots s GROUP BY s.level, s.unit, s.phase
  ),
  av AS (SELECT level, unit, phase, count(*) c FROM public.videos
           WHERE status = 'active' AND level IS NOT NULL GROUP BY 1,2,3),
  bv AS (SELECT backup_level AS level, backup_unit AS unit, backup_phase AS phase,
                count(*) c FROM public.videos
           WHERE status = 'pending' AND backup_level IS NOT NULL GROUP BY 1,2,3)
  SELECT ss.level, ss.unit, ss.phase, ss.total, ss.filled,
         COALESCE(av.c, 0), ss.bfilled, COALESCE(bv.c, 0)
  FROM slotstat ss
  LEFT JOIN av ON av.level = ss.level AND av.unit = ss.unit AND av.phase = ss.phase
  LEFT JOIN bv ON bv.level = ss.level AND bv.unit = ss.unit AND bv.phase = ss.phase;
$$;
