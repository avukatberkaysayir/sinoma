-- Vocabulary→slot map for the learning path. Each HSK word is pinned to a
-- (level, unit, phase) circle so that a clip WITHOUT a grammar rule but
-- containing the word surfaces in that circle. Also feeds the "gözat" panel
-- (word + dictionary meaning per slot). Meanings are denormalized from
-- dictionary at populate time so the app reads one table.
CREATE TABLE IF NOT EXISTS public.path_word_slots (
  word   text PRIMARY KEY,
  level  integer NOT NULL,
  unit   integer NOT NULL,
  phase  integer NOT NULL,
  pinyin text,
  tr     text,
  en     text
);

-- Public read (reference data) — without this the app's anon/authenticated role
-- can't load the words (RLS is on by default, and a table with 0 policies denies
-- all SELECTs). grammar_levels gets the same so the trigger can read it too.
DROP POLICY IF EXISTS read_path_word_slots ON public.path_word_slots;
CREATE POLICY read_path_word_slots ON public.path_word_slots FOR SELECT USING (true);
DROP POLICY IF EXISTS read_grammar_levels ON public.grammar_levels;
CREATE POLICY read_grammar_levels ON public.grammar_levels FOR SELECT USING (true);

-- Populate L1: all HSK1 words minus grammar-rule symbols, shuffled once and
-- spread round-robin across the 24×4 = 96 slots (2-3 words each). Re-running
-- reshuffles; run only for the initial setup. Grammar symbols come from
-- kGrammarMeaning (lib/data/models/video_segment_model.dart).
--
-- DELETE FROM public.path_word_slots WHERE level = 1;
-- INSERT INTO public.path_word_slots (word, level, unit, phase, pinyin, tr, en)
-- WITH base AS (
--   SELECT simplified AS word, pinyin,
--          definitions->>'tr' AS tr, definitions->>'en' AS en,
--          row_number() OVER (ORDER BY random()) - 1 AS rn
--   FROM public.dictionary
--   WHERE hsk_level = 1 AND simplified NOT IN ( <grammar zh symbols> )
-- )
-- SELECT word, 1, ((rn % 96) / 4)::int + 1, ((rn % 96) % 4)::int + 1, pinyin, tr, en
-- FROM base;
--
-- L2-L6 populated the same way (loop h IN 2..6, hsk_level = h), excluding grammar
-- tokens via: simplified NOT IN (SELECT symbol FROM grammar_levels WHERE symbol
-- IS NOT NULL). Words/slot grow with level (L2 ~2 … L6 ~25); the gözat panel
-- scrolls past 5. ~5856 rows total.
