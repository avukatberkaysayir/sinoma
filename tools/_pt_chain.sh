#!/usr/bin/env bash
# Robust one-off chain for the Portuguese rollout: run pt_backfill until the
# dictionary is fully filled (restarting on transient network/DNS crashes,
# since the backfill is resumable), then run the remaining data backfills
# sequentially to avoid Gemini quota contention. Mirror of tools/_es_chain.sh.
set -u
cd "$(dirname "$0")/.."

count_missing() {
  python -c "
import json,urllib.request
pat=[l.split('=',1)[1].strip() for l in open('.deploy.env',encoding='utf-8') if l.startswith('SUPABASE_ACCESS_TOKEN=')][0]
r=urllib.request.Request('https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query',data=json.dumps({'query':\"select count(*) n from dictionary where coalesce(definitions->>'pt','')=''\"}).encode(),headers={'Authorization':'Bearer '+pat,'Content-Type':'application/json','User-Agent':'Mozilla/5.0'},method='POST')
print(json.loads(urllib.request.urlopen(r,timeout=60).read())[0]['n'])
" 2>/dev/null
}

echo "[chain] starting pt_backfill loop..."
for i in $(seq 1 30); do
  python tools/pt_backfill.py >> /tmp/pt_backfill.log 2>&1
  m=$(count_missing)
  echo "[chain] pass $i done, dictionary missing pt = ${m:-?}"
  if [ "${m:-x}" = "0" ]; then break; fi
  sleep 10
done

echo "[chain] === add_pt_to_wordlists ==="
python tools/add_pt_to_wordlists.py

echo "[chain] === gen_pt_landmarks ==="
python tools/gen_pt_landmarks.py

echo "[chain] === quiz_pt_backfill ==="
python tools/quiz_pt_backfill.py

echo "[chain] ALL_DONE"
