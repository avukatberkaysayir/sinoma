-- A few representative words per (level, unit) for the learning-path unit caption.
-- Units without a grammar rule (most of HSK6 — its dictionary words carry no POS,
-- so no function-word grammar is derived) used to read "Soon"; they now show their
-- vocabulary instead. One compact query (~144 rows) feeds unitWordSummaryProvider.
CREATE OR REPLACE FUNCTION unit_word_summary()
RETURNS TABLE(level int, unit int, words text[])
LANGUAGE sql STABLE AS $$
  SELECT level, unit, (array_agg(word ORDER BY phase, word))[1:4]
  FROM path_word_slots
  GROUP BY level, unit
$$;

GRANT EXECUTE ON FUNCTION unit_word_summary() TO anon, authenticated;
