-- 024_slot_full_only_when_active.sql
-- Rule (Berkay 2026-07-27): a slot counts as FULL only when an ACTIVE clip holds
-- it. Before, "slot free = active OR pending" let a raw HSK 5-6 clip reserve a
-- slot at split time (the INSERT trigger sets level) without ever activating, so
-- later clips fell to backup — backups outnumbered actives (L6: 316 backups vs
-- 225 actives, 227 of them on pending-held slots). Now cases (a)/(b) test only
-- is_active, so a pending clip never blocks a slot; the batch resolves two raw
-- clips racing for one slot in order (first activates, second backs up/deletes).
-- Backup-slot guards in (0)/(c) are unchanged (still one backup per slot).

CREATE OR REPLACE FUNCTION public.assign_video_path()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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

      IF EXISTS (SELECT 1 FROM public.videos v2
            WHERE v2.status = 'active' AND v2.youtube_id = NEW.youtube_id
              AND v2.start_time = NEW.start_time AND v2.end_time = NEW.end_time
              AND v2.id <> NEW.id) THEN
        -- (0) this exact clip is already ACTIVE → duplicate/spare → backup at its
        -- would-be primary slot, but only if that backup slot is still EMPTY.
        SELECT gl.unit AS unit, gl.name AS name INTO rec_g
          FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
          JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
          WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                WHERE v2.backup_grammar = gl.name AND v2.backup_level = maxlvl
                  AND v2.id <> NEW.id)
          ORDER BY t.ord LIMIT 1;
        IF FOUND THEN
          NEW.backup_level := maxlvl; NEW.backup_unit := rec_g.unit;
          NEW.backup_phase := 1; NEW.backup_kind := 'grammar'; NEW.backup_grammar := rec_g.name;
        ELSE
          SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
            FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
            JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
            WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                  WHERE v2.backup_word = s.word AND v2.backup_level = maxlvl
                    AND v2.id <> NEW.id)
            ORDER BY t.ord LIMIT 1;
          IF FOUND THEN
            NEW.backup_level := maxlvl; NEW.backup_unit := ws.unit;
            NEW.backup_phase := ws.phase; NEW.backup_kind := 'word'; NEW.backup_word := ws.word;
          END IF;
        END IF;

      ELSE
        -- (a) first grammar rule AT this level whose slot is FREE (active OR pending)
        SELECT gl.unit AS unit, gl.name AS name INTO rec_g
          FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
          JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
          WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                WHERE v2.slot_grammar = gl.name
                  AND v2.is_active AND v2.id <> NEW.id)
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
                    AND v2.is_active AND v2.id <> NEW.id)
            ORDER BY t.ord LIMIT 1;
          IF FOUND THEN
            NEW.level := maxlvl; NEW.unit := ws.unit; NEW.phase := ws.phase; NEW.slot_word := ws.word;
          ELSE
            -- (c) no FREE slot → BACKUP, but at most ONE backup per slot: take the
            -- first candidate slot (grammar then word) that has NO backup yet. If
            -- every candidate slot already has a backup, leave it un-backed → the
            -- batch keeps it plain pending.
            SELECT gl.unit AS unit, gl.name AS name INTO rec_g
              FROM unnest(COALESCE(NEW.quiz_categories, '{}'::text[])) WITH ORDINALITY t(cat, ord)
              JOIN public.grammar_levels gl ON gl.name = t.cat AND gl.level = maxlvl
              WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                    WHERE v2.backup_grammar = gl.name AND v2.backup_level = maxlvl
                      AND v2.id <> NEW.id)
              ORDER BY t.ord LIMIT 1;
            IF FOUND THEN
              NEW.backup_level := maxlvl; NEW.backup_unit := rec_g.unit;
              NEW.backup_phase := 1; NEW.backup_kind := 'grammar'; NEW.backup_grammar := rec_g.name;
            ELSE
              SELECT s.unit AS unit, s.phase AS phase, s.word AS word INTO ws
                FROM unnest(COALESCE(NEW.target_words, '{}'::text[])) WITH ORDINALITY t(w, ord)
                JOIN public.path_word_slots s ON s.word = t.w AND s.level = maxlvl
                WHERE NOT EXISTS (SELECT 1 FROM public.videos v2
                      WHERE v2.backup_word = s.word AND v2.backup_level = maxlvl
                        AND v2.id <> NEW.id)
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
  END IF;
  RETURN NEW;
END;
$function$;
