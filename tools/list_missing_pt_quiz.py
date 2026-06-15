# Lists active videos whose quiz JSON lacks Portuguese options (pt.correctAnswer
# / pt.wrongAnswer). Output feeds the manual Portuguese fill-in pass.
# Mirror of tools/list_missing_es_quiz.py.
import json, urllib.request, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
tok = next(l.split('=', 1)[1].strip()
           for l in (ROOT / '.deploy.env').read_text().splitlines()
           if l.startswith('SUPABASE_ACCESS_TOKEN='))

SQL = """
select id,
       quiz->>'correctAnswer'        as tr_c,
       quiz->>'wrongAnswer'          as tr_w,
       quiz->'en'->>'correctAnswer'  as en_c,
       quiz->'en'->>'wrongAnswer'    as en_w,
       quiz->'pt'->>'correctAnswer'  as pt_c,
       quiz->'pt'->>'wrongAnswer'    as pt_w
from videos
where status='active'
order by hsk_level, created_at
"""

req = urllib.request.Request(
    'https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query',
    data=json.dumps({'query': SQL}).encode(),
    headers={'Authorization': f'Bearer {tok}',
             'Content-Type': 'application/json',
             'User-Agent': 'sinoma-tools'})
rows = json.load(urllib.request.urlopen(req))

missing = [r for r in rows
           if not (r.get('pt_c') or '').strip()
           or not (r.get('pt_w') or '').strip()]
print(f'active={len(rows)} missing_pt={len(missing)}')
for r in missing:
    print(json.dumps(r, ensure_ascii=False))
