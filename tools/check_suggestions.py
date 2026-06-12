import json, os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAT = [l.split("=",1)[1].strip() for l in open(os.path.join(ROOT,".deploy.env"),encoding="utf-8") if l.startswith("SUPABASE_ACCESS_TOKEN=")][0]

def sql(q):
    req = urllib.request.Request(
        "https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query",
        data=json.dumps({"query": q}).encode(),
        headers={"Authorization": f"Bearer {PAT}", "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0"}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())

print("1) suggestion queue:")
for r in sql("select content, metadata->>'suggested_by_email' src from posts "
             "where metadata->>'is_word_suggestion' = 'true'"):
    print("  ", r["content"], "|", r["src"])

print("2) proper nouns in dictionary?")
for r in sql("select simplified, hsk_level, definitions->>'tr' tr from dictionary "
             "where simplified in ('西班牙','巴塞罗那','拉宝','东东','猫小','考拉宝','动物小镇','豆小镇')"):
    print("  ", r)

print("3) missing >=2char CJK target words not in dictionary:")
for r in sql("with words as (select distinct w from videos, unnest(target_words) w "
             "where status in ('active','pending','backup') and w <> E'\\n' "
             "and length(w) >= 2 and w ~ '[一-鿿]') "
             "select w from words where not exists "
             "(select 1 from dictionary d where d.simplified = w) limit 30"):
    print("  ", r["w"])
