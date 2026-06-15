# One-off: add a Portuguese (10th) argument to every _t(...) call in
# locale_provider.dart. Parses each call's 9 string-literal args, translates the
# English (2nd) arg into natural UI Portuguese via the ko-batch Gemini proxy
# (preserving $placeholders, leading CJK/emoji prefixes and punctuation), then
# inserts the Portuguese literal before the closing paren. Caches translations in
# tools/_pt_locale_cache.json so re-runs don't re-hit Gemini.
# Mirror of tools/_es_locale_fill.py (now expects 9 existing args).
import json, os, re, sys, time, urllib.request, urllib.error

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "pqyceostpukueydwuiut"
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/ko-batch"
GUARD = "sinoma-ko-backfill-2026"
TARGET = os.path.join(ROOT, "lib", "presentation", "providers",
                      "locale_provider.dart")
CACHE = os.path.join(ROOT, "tools", "_pt_locale_cache.json")
MODELS = ["gemini-flash-lite-latest", "gemini-flash-latest",
          "gemini-2.5-flash", "gemini-2.5-flash-lite"]
NARGS = 9  # existing positional args before Portuguese is appended

def parse_dart_string(src, i):
    q = src[i]
    assert q in "'\""
    j = i + 1
    buf = []
    while j < len(src):
        c = src[j]
        if c == "\\":
            buf.append(src[j:j + 2]); j += 2; continue
        if c == q:
            return "".join(buf), j + 1
        buf.append(c); j += 1
    raise ValueError("unterminated string")

def find_calls(src):
    calls = []
    for m in re.finditer(r"_t\(", src):
        i = m.end()
        args = []
        depth = 0
        k = i
        arg_start = i
        ok = True
        while k < len(src):
            c = src[k]
            if c in "'\"":
                _, k = parse_dart_string(src, k)
                continue
            if c == "(":
                depth += 1; k += 1; continue
            if c == ")":
                if depth == 0:
                    args.append(src[arg_start:k].strip())
                    end = k + 1
                    break
                depth -= 1; k += 1; continue
            if c == "," and depth == 0:
                args.append(src[arg_start:k].strip())
                k += 1; arg_start = k; continue
            k += 1
        else:
            ok = False
        if ok:
            calls.append((m.start(), end, args))
    return calls

def is_string_literal(a):
    a = a.strip()
    return len(a) >= 2 and a[0] in "'\"" and a[-1] == a[0]

def literal_value(a):
    v, _ = parse_dart_string(a.strip(), 0)
    return v

model_i = 0
def gemini(prompt):
    global model_i
    for _ in range(12):
        data = json.dumps({"prompt": prompt, "temperature": 0.2,
                           "model": MODELS[model_i % len(MODELS)]}).encode()
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-pt-locale)"}, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.loads(r.read().decode())
            return json.loads(out["text"])
        except Exception as ex:
            print(f"  fn err [{MODELS[model_i % len(MODELS)]}]: {ex}", flush=True)
            model_i += 1; time.sleep(5)
    return {}

PROMPT = (
    "You are a professional EN->PT translator localizing a Mandarin-learning "
    "app's UI. Translate each English string into natural, idiomatic Brazilian "
    "Portuguese (neutral standard, the way a Brazilian app would phrase it; "
    "concise UI register, correct gender/agreement and accents). STRICT RULES:\n"
    "- Keep every $-placeholder EXACTLY as-is ($n, $d, $t, $h, $level, etc.), "
    "in a position that is grammatical in Portuguese.\n"
    "- Preserve any leading non-Latin prefix verbatim (e.g. Chinese '文法  ', "
    "'字数  ', '全部  '), all emojis (🧧 etc.), arrows, dots and punctuation.\n"
    "- Use proper Portuguese accents (ã, õ, ç, á, ê, í, ó) and punctuation.\n"
    "- Do NOT add quotes around the result. Do NOT translate placeholders.\n"
    "- Return ONLY a JSON object mapping each given id to its Portuguese string.\n\n"
    "Strings:\n")

def translate_all(unique):
    cache = {}
    if os.path.exists(CACHE):
        cache = json.load(open(CACHE, encoding="utf-8"))
    todo = [s for s in unique if s not in cache]
    print(f"to translate: {len(todo)} (cached {len(cache)})")
    items = [(str(i), s) for i, s in enumerate(todo)]
    for b in range(0, len(items), 25):
        batch = items[b:b + 25]
        lines = "\n".join(f'  id:{i} | "{s}"' for i, s in batch)
        res = gemini(PROMPT + lines)
        for i, s in batch:
            v = res.get(i)
            if isinstance(v, str) and v.strip():
                cache[s] = v
        json.dump(cache, open(CACHE, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        got = sum(1 for _, s in batch if s in cache)
        print(f"  batch {b//25}: +{got}/{len(batch)} (total {len(cache)})", flush=True)
        time.sleep(3)
    return cache

def esc(s):
    return (s.replace("\\", "\\\\").replace("'", "\\'")
             .replace("\r", "").replace("\n", "\\n").replace("\t", "\\t"))

def main():
    apply = "--apply" in sys.argv
    src = open(TARGET, encoding="utf-8").read()
    calls = find_calls(src)
    good = [c for c in calls if len(c[2]) == NARGS and all(is_string_literal(x) for x in c[2])]
    print(f"total _t calls: {len(calls)}, with {NARGS} string args: {len(good)}")
    bad = [c for c in calls if not (len(c[2]) == NARGS and all(is_string_literal(x) for x in c[2]))]
    for b in bad:
        print("  SKIP:", repr(src[b[0]:b[0]+70]))
    english = [literal_value(c[2][1]) for c in good]
    unique = sorted(set(english))
    cache = translate_all(unique)
    missing = [s for s in unique if s not in cache]
    if missing:
        print(f"MISSING {len(missing)} translations, aborting insert:")
        for s in missing[:20]:
            print("   ", s)
        return
    if not apply:
        print("dry-run OK. re-run with --apply to insert.")
        return
    for start, end, args in sorted(good, key=lambda c: c[1], reverse=True):
        en = literal_value(args[1])
        pt = cache[en]
        src = src[:end - 1] + f", '{esc(pt)}'" + src[end - 1:]
    open(TARGET, "w", encoding="utf-8", newline="\n").write(src)
    print(f"inserted pt into {len(good)} calls")

if __name__ == "__main__":
    main()
