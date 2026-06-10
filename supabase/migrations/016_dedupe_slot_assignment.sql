-- Slot-collision fix. The original assign_video_path counted occupancy only over
-- status='active', so several PENDING clips matching the same word/grammar all
-- claimed the SAME slot (e.g. 6 clips on word 咖啡 at L2/Ünite15). And for grammar
-- it only tried the FIRST matching rule — if taken it went straight to backup
-- without trying the clip's other grammars or its words.
--
-- New rule (matches the curriculum policy): within the clip's highest level,
--   1. take the FIRST grammar rule the clip matches whose slot is FREE,
--   2. else the FIRST word-slot the clip matches that is FREE,
--   3. else (everything it matches at that level is taken) → backup.
-- "FREE" now means no OTHER active-OR-pending clip already holds that slot, so two
-- pending clips never pile onto one teaching item.
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

    SELECT max(L) INTO maxlvl FROM (
      SELECT gl.level AS L FROM unnest(COALESCE(NEW.quiz_categories,'{}'::text[])) c
        JOIN public.grammar_levels gl ON gl.name = c
      UNION ALL
      SELECT s.level AS L FROM unnest(COALESCE(NEW.target_words,'{}'::text[])) w
        JOIN public.path_word_slots s ON s.word = w
    ) x;

    IF maxlvl IS NOT NULL THEN
      NEW.hsk_level := maxlvl; NEW.hsk_levels := ARRAY[maxlvl];

      -- (a) first grammar rule AT this level whose slot is FREE (active OR pending)
      SELECT gl.unit AS unit, gl.name AS name INTO rec_g
        FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
        JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
        WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
              WHERE v2.slot_grammar = gl.name
                AND v2.status IN ('active','pending') AND v2.id <> NEW.id)
        ORDER BY t.ord LIMIT 1;
      IF FOUND THEN
        NEW.level := maxlvl; NEW.unit := rec_g.unit; NEW.phase := 1; NEW.slot_grammar := rec_g.name;
      ELSE
        -- (b) first word-slot AT this level that is FREE
        SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
          FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
          JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
          WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                WHERE v2.slot_word = s.word
                  AND v2.status IN ('active','pending') AND v2.id <> NEW.id)
          ORDER BY t.ord LIMIT 1;
        IF FOUND THEN
          NEW.level := maxlvl; NEW.unit := ws.unit; NEW.phase := ws.phase; NEW.slot_word := ws.word;
        ELSE
          -- (c) everything it matches at this level is taken → backup at the
          -- would-be slot (first matching grammar, else first matching word).
          SELECT gl.unit AS unit, gl.name AS name INTO rec_g
            FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
            JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
            ORDER BY t.ord LIMIT 1;
          IF FOUND THEN
            NEW.backup_level := maxlvl; NEW.backup_unit := rec_g.unit;
            NEW.backup_phase := 1; NEW.backup_kind := 'grammar'; NEW.backup_grammar := rec_g.name;
          ELSE
            SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
              FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
              JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
              ORDER BY t.ord LIMIT 1;
            IF FOUND THEN
              NEW.backup_level := maxlvl; NEW.backup_unit := ws.unit;
              NEW.backup_phase := ws.phase; NEW.backup_kind := 'word'; NEW.backup_word := ws.word;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$func$ LANGUAGE plpgsql;
