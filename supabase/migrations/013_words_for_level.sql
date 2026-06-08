-- All distinct vocabulary words of one HSK level (word + meaning), for the
-- per-level word picker in the YouTube import content filter. Done as an RPC so
-- the full set comes back in one call (HSK6 has ~2400 words, past PostgREST's
-- default 1000-row cap on plain table reads).
CREATE OR REPLACE FUNCTION words_for_level(p_level int)
RETURNS TABLE(word text, tr text)
LANGUAGE sql STABLE AS $$
  SELECT DISTINCT ON (word) word, tr
  FROM path_word_slots
  WHERE level = p_level
  ORDER BY word
$$;

GRANT EXECUTE ON FUNCTION words_for_level(int) TO anon, authenticated;
