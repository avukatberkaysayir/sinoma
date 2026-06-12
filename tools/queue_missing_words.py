# Queues every >=2-char CJK target word that is missing from the dictionary
# into admin > Sozluk > Onerilen (posts, is_word_suggestion). Idempotent.
import json, os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAT = [l.split("=",1)[1].strip() for l in open(os.path.join(ROOT,".deploy.env"),encoding="utf-8") if l.startswith("SUPABASE_ACCESS_TOKEN=")][0]
ADMIN_UID = "54bb82ba-fe25-4606-b0ea-5b07a7c6ae17"

def sql(q):
    req = urllib.request.Request(
        "https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query",
        data=json.dumps({"query": q}).encode(),
        headers={"Authorization": f"Bearer {PAT}", "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0"}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())

rows = sql(
    "with words as (select distinct w from videos, unnest(target_words) w "
    "where status in ('active','pending','backup') and w <> E'\\n' "
    "and length(w) >= 2 and w ~ '[一-鿿]') "
    "insert into posts (author_id, content, post_type, likes, metadata) "
    f"select '{ADMIN_UID}', w, 'text', array[]::text[], "
    "jsonb_build_object('is_word_suggestion', true, 'word', w, "
    "'suggested_by_email', 'missing-word-sweep') "
    "from words where not exists (select 1 from dictionary d where d.simplified = w) "
    "and not exists (select 1 from posts p where p.metadata->>'is_word_suggestion' = 'true' "
    "and p.content = w) returning content")
print(f"queued {len(rows)}:")
for r in rows:
    print("  ", r["content"])
