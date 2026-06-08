-- Auto-assign a video's learning-path level + unit from its grammar rule when
-- they aren't set (e.g. right after the pipeline drops a clip into "pending").
-- Admin overrides are preserved: the trigger only fills NULLs. Phase stays
-- manual. Reference data lives in grammar_levels (name → level, unit), mirroring
-- kGrammarByHsk in lib/data/models/video_segment_model.dart.

CREATE TABLE IF NOT EXISTS public.grammar_levels (
  name  text PRIMARY KEY,
  level integer NOT NULL,
  unit  integer NOT NULL,
  -- symbol: matchable token (NULL = multi-token pattern); zh/tr/en: display label.
  symbol text,
  zh     text,
  tr     text,
  en     text
);
-- NOTE: grammar_levels is the SOURCE OF TRUTH for the grammar curriculum and is
-- larger than the seed below: it also holds the expanded function-word grammars
-- (every HSK adverb/conjunction/preposition + 一般) loaded from the dictionary,
-- spread across the 24 units/level (multiple grammars per unit). zh/tr come from
-- the dictionary for those. The app reads it via loadGrammarMeta(). The seed
-- below is just the original ~115 grammar points.

-- Populated from kGrammarByHsk (HSK 1-6, in curriculum order). Regenerate with
-- the generator in the repo if the grammar lists change.
INSERT INTO public.grammar_levels(name, level, unit) VALUES
  ('shi',1,1),('deStruct',1,2),('you',1,3),('le',1,4),('ma',1,5),('ne',1,6),
  ('baParticle',1,7),('a',1,8),('bu',1,9),('mei',1,10),('zai',1,11),('hui',1,12),
  ('neng',1,13),('keyi',1,14),('yao',1,15),('xiang',1,16),('dou',1,17),
  ('zenme',1,18),('zhengfan',1,19),('tai',1,20),('dui',1,21),('gei',1,22),
  ('gen',1,23),('zaiAgain',1,24),
  ('guo',2,1),('zhe',2,2),('deComplement',2,3),('deAdverbial',2,4),('jiu',2,5),
  ('hai',2,6),('yijing',2,7),('cai',2,8),('bi',2,9),('weishenme',2,10),
  ('zenmeyang',2,11),('yinwei',2,12),('suoyi',2,13),('qilai',2,14),('jieguo',2,15),
  ('cong',2,16),('li',2,17),('wei',2,18),('changchang',2,19),('bijiao',2,20),
  ('youAgain',2,21),('geng',2,22),('zui',2,23),('haishi',2,24),
  ('ba',3,1),('bei',3,2),('shiDe',3,3),('yinggai',3,4),('dei',3,5),('dasuan',3,6),
  ('ruguo',3,7),('danshi',3,8),('suiran',3,9),('genYiyang',3,10),('quxiang',3,11),
  ('weile',3,12),('guanyu',3,13),('chule',3,14),('yizhi',3,15),('gan',3,16),
  ('xuyao',3,17),('yibian',3,18),('ranhou',3,19),('yueyue',3,20),('yuelaiyue',3,21),
  ('dehua',3,22),('zhongyu',3,23),('nandao',3,24),
  ('keneng',4,1),('chengdu',4,2),('dongliang',4,3),('shiliang',4,4),('zhengzai',4,5),
  ('xiaqu',4,6),('meiyou',4,7),('buru',4,8),('zhiyao',4,9),('zhiyou',4,10),
  ('wulun',4,11),('buguan',4,12),('jiran',4,13),('budan',4,14),('erqie',4,15),
  ('huozhe',4,16),('lian',4,17),('liandou',4,18),('genju',4,19),('anzhao',4,20),
  ('jiaru',4,21),('yaoshi',4,22),('yinci',4,23),('que',4,24),
  ('cunxian',5,1),('jianyu',5,2),('liandong',5,3),('chongdong',5,4),('bixu',5,5),
  ('fouze',5,6),('raner',5,7),('jishi',5,8),('bujin',5,9),('shenzhi',5,10),
  ('yaome',5,11),('yushi',5,12),('wanyi',5,13),('xiangPrep',5,14),
  ('napa',6,1),('jinguan',6,2),('chufei',6,3),('fanwen',6,4),('shuangchong',6,5)
ON CONFLICT (name) DO UPDATE SET level = EXCLUDED.level, unit = EXCLUDED.unit;

-- Which grammar rule / slot word a clip was pinned through. ONE clip per grammar
-- rule and ONE clip per slot word (so each teaching item hosts a distinct clip).
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS slot_word    text;
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS slot_grammar text;
CREATE INDEX IF NOT EXISTS idx_videos_slot_word
  ON public.videos(slot_word) WHERE slot_word IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_videos_slot_grammar
  ON public.videos(slot_grammar) WHERE slot_grammar IS NOT NULL;

-- Backup ("Yedek") store: a clip that couldn't become an active occupant records
-- the slot it WOULD belong to (ignoring occupancy) so it can be swapped in later.
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_level int;
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_unit  int;
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_phase int;
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_kind  text; -- 'grammar' | 'word'
-- The criterion (grammar rule name / word) the HSK+Level were decided by, for a
-- backup clip (placed clips carry it in slot_grammar / slot_word). Shown as
-- "Kriter: 在 (Gramer)" / "Kriter: 漂亮 (Kelime)" in the admin.
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_grammar text;
ALTER TABLE public.videos ADD COLUMN IF NOT EXISTS backup_word    text;

-- Matchable token per grammar (NULL = multi-token pattern, e.g. 是…的 / A不A /
-- 把字句 / 结果补语 — can't be matched as a single word). Populated from
-- kGrammarMeaning.zh: contains 补语/句/否定/… or = 'A不A' → NULL; else zh.
ALTER TABLE public.grammar_levels ADD COLUMN IF NOT EXISTS symbol text;
-- (symbol values set by the app's one-off generator; see project notes.)
-- 得 is shared by deComplement (得 complement) + dei (得 must) — keep one
-- matchable so a 得 word maps to a single grammar; dei → NULL (pipeline/manual).
UPDATE public.grammar_levels SET symbol = NULL WHERE name = 'dei';

-- Standard: grammar words are already a separate set from vocab (path_word_slots
-- excludes them). So ANY confirmed word that IS a grammar token (= grammar_levels
-- .symbol) is treated as that grammar — no ambiguity heuristics. (The older
-- auto_add allow-list was dropped.)

-- BEFORE INSERT / UPDATE OF quiz_category|quiz_categories|target_words.
-- (1) Detect grammar, in priority order:
--     A. multi-token PATTERN grammars by their characteristic shape (these have no
--        single token symbol): 正反问 X不X '(.)不\1'; 是…的 '是.+的$'; 跟…一样
--        '跟.+一样'; 连…都 '连.+都'; 越…越 '越.+越' (not 越来越). Patterns rank
--        above their component single grammars (跟/连/都…).
--     B. every confirmed word equal to a grammar token (grammar_levels.symbol).
--     C. existing structural tags kept (NULL symbol & no pattern: 补语/句/否定/反问
--        — abstract structures with no fixed characters; pipeline/manual only).
--     quiz_category := first tag (else 'general').
-- (2) Placement (only when level is null and not "Diğer"=phase 0). The LEVEL is
--     the HIGHEST level at which the clip has placeable content — a grammar rule
--     OR a vocab-slot word. Lower-level grammar/words are ignored (so an L1
--     grammar 在 inside an HSK4 clip doesn't drag it to L1). hsk_level/hsk_levels
--     are synced to that level so the HSK badge always matches L. Within the level:
--      a. a grammar rule AT that level → its unit (phase 1); place if free among
--         ACTIVE clips, else backup;
--      b. else the level's word-list → first free word-slot at that level, else
--         backup at that level's word.
-- Occupancy counts only status='active', so a pending clip is placeable unless an
-- ACTIVE clip already holds its slot (→ backup).
CREATE OR REPLACE FUNCTION public.assign_video_path() RETURNS trigger AS $func$
DECLARE
  do_detect boolean := false;
  do_place boolean := false;
  joined text;
  pat_arr text[];
  maxlvl int;
  rec_g record;
  ws record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    do_detect := (NEW.target_words IS NOT NULL);
  ELSIF (NEW.target_words   IS DISTINCT FROM OLD.target_words)
     OR (NEW.quiz_categories IS DISTINCT FROM OLD.quiz_categories)
     OR (NEW.quiz_category   IS DISTINCT FROM OLD.quiz_category) THEN
    do_detect := true;
  END IF;
  do_place := (NEW.level IS NULL AND COALESCE(NEW.phase, -1) <> 0);

  IF do_detect THEN
    joined := array_to_string(COALESCE(NEW.target_words,'{}'::text[]), '');
    pat_arr := ARRAY(
      SELECT name FROM ( VALUES
        ('zhengfan',  CASE WHEN joined ~ '(.)不\1'  THEN position('不' IN joined) ELSE 0 END),
        ('shiDe',     CASE WHEN joined ~ '是.+的$'   THEN position('是' IN joined) ELSE 0 END),
        ('genYiyang', CASE WHEN joined ~ '跟.+一样'  THEN position('跟' IN joined) ELSE 0 END),
        ('liandou',   CASE WHEN joined ~ '连.+都'    THEN position('连' IN joined) ELSE 0 END),
        ('yueyue',    CASE WHEN joined ~ '越.+越' AND joined NOT LIKE '%越来越%'
                                                    THEN position('越' IN joined) ELSE 0 END),
        -- common fixed patterns for otherwise abstract structures (raise match rate)
        ('fanwen',      CASE WHEN joined LIKE '%难道%'   THEN position('难道' IN joined) ELSE 0 END),
        ('shuangchong', CASE WHEN joined LIKE '%不得不%' THEN position('不得不' IN joined) ELSE 0 END)
      ) v(name, pos) WHERE pos > 0 ORDER BY pos );
    NEW.quiz_categories :=
      pat_arr
      ||
      ( SELECT COALESCE(array_agg(name ORDER BY pos), '{}'::text[])
        FROM ( SELECT gl.name AS name, min(t.ord) AS pos
               FROM unnest(COALESCE(NEW.target_words,'{}'::text[])) WITH ORDINALITY t(w,ord)
               JOIN public.grammar_levels gl ON gl.symbol = t.w
               GROUP BY gl.name ) m
        WHERE NOT (name = ANY(pat_arr)) )
      ||
      ( SELECT COALESCE(array_agg(t.cat ORDER BY t.ord), '{}'::text[])
        FROM unnest(COALESCE(NEW.quiz_categories,'{}'::text[])) WITH ORDINALITY t(cat,ord)
        JOIN public.grammar_levels gl ON gl.name = t.cat
        WHERE gl.symbol IS NULL
          AND gl.name NOT IN ('zhengfan','shiDe','genYiyang','liandou','yueyue','fanwen','shuangchong') );
    NEW.quiz_category := COALESCE(NEW.quiz_categories[1], 'general');
    IF NEW.quiz_category IS NULL THEN NEW.quiz_category := 'general'; END IF;
  END IF;

  IF do_place THEN
    NEW.slot_grammar := NULL; NEW.slot_word := NULL;
    NEW.backup_level := NULL; NEW.backup_unit := NULL;
    NEW.backup_phase := NULL; NEW.backup_kind := NULL;
    NEW.backup_grammar := NULL; NEW.backup_word := NULL;

    -- LEVEL = highest level with placeable content (a grammar rule OR a vocab-slot
    -- word); lower-level grammar/words ignored. HSK synced to it.
    SELECT max(L) INTO maxlvl FROM (
      SELECT gl.level AS L FROM unnest(COALESCE(NEW.quiz_categories,'{}'::text[])) c
        JOIN public.grammar_levels gl ON gl.name = c
      UNION ALL
      SELECT s.level AS L FROM unnest(COALESCE(NEW.target_words,'{}'::text[])) w
        JOIN public.path_word_slots s ON s.word = w
    ) x;

    IF maxlvl IS NOT NULL THEN
      NEW.hsk_level := maxlvl; NEW.hsk_levels := ARRAY[maxlvl];
      -- (a) a grammar rule AT this level → its unit (phase 1)
      SELECT gl.unit AS unit, gl.name AS name INTO rec_g
        FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
        JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
        ORDER BY t.ord LIMIT 1;
      IF FOUND THEN
        IF NOT EXISTS (SELECT 1 FROM public.videos v2
              WHERE v2.slot_grammar = rec_g.name AND v2.status = 'active' AND v2.id <> NEW.id) THEN
          NEW.level := maxlvl; NEW.unit := rec_g.unit; NEW.phase := 1; NEW.slot_grammar := rec_g.name;
        ELSE
          NEW.backup_level := maxlvl; NEW.backup_unit := rec_g.unit;
          NEW.backup_phase := 1; NEW.backup_kind := 'grammar';
          NEW.backup_grammar := rec_g.name;
        END IF;
      ELSE
        -- (b) else this level's word-list: first free word-slot at this level
        SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
          FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
          JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
          WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
            WHERE v2.slot_word = s.word AND v2.status = 'active' AND v2.id <> NEW.id)
          ORDER BY t.ord LIMIT 1;
        IF FOUND THEN
          NEW.level := maxlvl; NEW.unit := ws.unit; NEW.phase := ws.phase; NEW.slot_word := ws.word;
        ELSE
          SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
            FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
            JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
            ORDER BY t.ord LIMIT 1;
          IF FOUND THEN
            NEW.backup_level := maxlvl; NEW.backup_unit := ws.unit;
            NEW.backup_phase := ws.phase; NEW.backup_kind := 'word';
            NEW.backup_word := ws.word;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assign_video_path ON public.videos;
CREATE TRIGGER trg_assign_video_path
  BEFORE INSERT OR UPDATE OF quiz_category, quiz_categories, target_words ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.assign_video_path();
