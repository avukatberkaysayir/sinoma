-- Auto-assign a video's learning-path level + unit from its grammar rule when
-- they aren't set (e.g. right after the pipeline drops a clip into "pending").
-- Admin overrides are preserved: the trigger only fills NULLs. Phase stays
-- manual. Reference data lives in grammar_levels (name → level, unit), mirroring
-- kGrammarByHsk in lib/data/models/video_segment_model.dart.

CREATE TABLE IF NOT EXISTS public.grammar_levels (
  name  text PRIMARY KEY,
  level integer NOT NULL,
  unit  integer NOT NULL
);

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

-- Fills level + unit + phase from the grammar rule when null. Phase distributes
-- 8 clips per circle (kPhaseSize), capped at 4, by how many already sit in that
-- (level, unit). General/unknown grammar leaves all null (word-slot placement
-- handles those).
CREATE OR REPLACE FUNCTION public.assign_video_path() RETURNS trigger AS $func$
DECLARE g public.grammar_levels%ROWTYPE;
DECLARE n integer;
BEGIN
  IF NEW.level IS NULL OR NEW.unit IS NULL OR NEW.phase IS NULL THEN
    SELECT * INTO g FROM public.grammar_levels WHERE name = NEW.quiz_category;
    IF FOUND THEN
      IF NEW.level IS NULL THEN NEW.level := g.level; END IF;
      IF NEW.unit  IS NULL THEN NEW.unit  := g.unit;  END IF;
      IF NEW.phase IS NULL THEN
        SELECT count(*) INTO n FROM public.videos v
          WHERE v.level = g.level AND v.unit = g.unit
            AND v.status IN ('active','pending') AND v.id <> NEW.id;
        NEW.phase := LEAST(4, (n / 8) + 1);
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assign_video_path ON public.videos;
CREATE TRIGGER trg_assign_video_path
  BEFORE INSERT OR UPDATE OF quiz_category ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.assign_video_path();
