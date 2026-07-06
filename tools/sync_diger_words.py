# Regenerates lib/core/constants/diger_words.dart from the dictionary rows
# saved as "Diğer" (hsk_level = 7) — the Dart file is the canonical word list,
# mirrored from the admin approval flow. deploy.ps1 runs this before every
# build so each deploy ships the current list.
import os, sys, time, requests

sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

tok = None
with open(os.path.join(ROOT, '.deploy.env'), encoding='utf-8') as f:
    for line in f:
        if line.startswith('SUPABASE_ACCESS_TOKEN='):
            tok = line.split('=', 1)[1].strip()
if not tok:
    print('[diger-sync] SUPABASE_ACCESS_TOKEN yok - atlandi')
    sys.exit(0)

QUERY = ("select simplified, pinyin, "
         "coalesce(definitions->>'pos','') pos, "
         "coalesce(definitions->>'en','') en, "
         "coalesce(definitions->>'tr','') tr, "
         "coalesce(definitions->>'ko','') ko, "
         "coalesce(definitions->>'ja','') ja, "
         "coalesce(definitions->>'id','') id, "
         "coalesce(definitions->>'vi','') vi, "
         "coalesce(definitions->>'th','') th, "
         "coalesce(definitions->>'ru','') ru, "
         "coalesce(definitions->>'es','') es, "
         "coalesce(definitions->>'pt','') pt, "
         "coalesce(definitions->>'fr','') fr, "
         "coalesce(definitions->>'ar','') ar "
         "from dictionary where hsk_level = 7 order by simplified;")

# The Management API occasionally hiccups (empty/non-JSON body, 5xx) — retry a
# few times, then skip gracefully so a transient blip never breaks the deploy.
rows = None
for attempt in range(3):
    try:
        r = requests.post(
            'https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query',
            headers={'Authorization': f'Bearer {tok}'},
            json={'query': QUERY},
            timeout=30)
        rows = r.json()
        if isinstance(rows, list):
            break
        print(f'[diger-sync] deneme {attempt + 1}: sorgu hatasi ({r.status_code}):', rows)
    except (requests.RequestException, ValueError) as e:
        print(f'[diger-sync] deneme {attempt + 1}: {type(e).__name__}: {e}')
    rows = None
    time.sleep(2 * (attempt + 1))
if rows is None:
    print('[diger-sync] API cevap vermedi - atlandi (liste bu deployda guncellenmez)')
    sys.exit(0)


def esc(s):
    return (s or '').replace('\\', '\\\\').replace("'", "\\'").replace('\n', ' ')


lines = []
for w in rows:
    lines.append(
        f"  ['{esc(w['simplified'])}', '{esc(w['pinyin'])}', "
        f"'{esc(w['pos'])}', '{esc(w['en'])}', '{esc(w['tr'])}', "
        f"'{esc(w['ko'])}', '{esc(w['ja'])}', '{esc(w['id'])}', '{esc(w['vi'])}', "
        f"'{esc(w['th'])}', '{esc(w['ru'])}', '{esc(w['es'])}', "
        f"'{esc(w['pt'])}', '{esc(w['fr'])}', '{esc(w['ar'])}'],")
body = ('const List<List<String>> kDigerWords = [\n'
        + '\n'.join(lines) + ('\n' if lines else '') + '];')

path = os.path.join(ROOT, 'lib', 'core', 'constants', 'diger_words.dart')
src = open(path, encoding='utf-8').read()
start = src.index('// ── SYNC-START ──') + len('// ── SYNC-START ──')
end = src.index('// ── SYNC-END ──')
new = src[:start] + '\n' + body + '\n' + src[end:]
if new != src:
    open(path, 'w', encoding='utf-8').write(new)
    print(f'[diger-sync] {len(rows)} kelime yazildi')
else:
    print(f'[diger-sync] degisiklik yok ({len(rows)} kelime)')
