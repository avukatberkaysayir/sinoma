# Backfills the 10 generated landmark language packs (ko/ja/id/vi/th/ru/es/pt/
# fr/ar) with ONLY the missing keys (the L6 cities), reusing each language's
# existing gen_<lang>_landmarks.py module (prompt, edge-fn caller, parser).
# Existing translations are preserved verbatim; new entries are appended before
# the closing brace of landmarks_<lang>.dart.
import importlib
import os
import re
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK_DIR = os.path.join(ROOT, "lib", "core", "constants", "landmarks")
LANGS = ["ko", "ja", "id", "vi", "th", "ru", "es", "pt", "fr", "ar"]


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def backfill(lang):
    mod = importlib.import_module(f"gen_{lang}_landmarks")
    entries = mod.parse()
    pack_path = os.path.join(PACK_DIR, f"landmarks_{lang}.dart")
    pack = open(pack_path, encoding="utf-8").read()
    have = set(re.findall(r"^  '([^']+)':", pack, re.M))
    todo = [e for e in entries if e["key"] not in have]
    print(f"[{lang}] {len(entries)} total, {len(have)} present, "
          f"{len(todo)} to translate", flush=True)
    if not todo:
        return
    results = {}
    for _pass in range(4):
        rest = [e for e in todo if e["key"] not in results]
        if not rest:
            break
        for i in range(0, len(rest), 15):
            batch = rest[i:i + 15]
            lines = "\n".join(
                f"- key:{e['key']} name_en:\"{e['name']}\" desc_en:\"{e['desc']}\""
                for e in batch)
            out = mod.call_fn(mod.PROMPT + lines)
            for e in batch:
                v = out.get(e["key"])
                if isinstance(v, dict) and v.get("name"):
                    results[e["key"]] = (str(v["name"]).strip(),
                                         str(v.get("desc") or "").strip())
            print(f"[{lang}] translated {len(results)}/{len(todo)}", flush=True)
            time.sleep(4)
    new_lines = "".join(
        f"  '{e['key']}': ('{esc(results[e['key']][0])}', "
        f"'{esc(results[e['key']][1])}'),\n"
        for e in todo if e["key"] in results)
    closing = "};"
    assert pack.rstrip().endswith(closing), f"unexpected pack tail in {lang}"
    idx = pack.rindex(closing)
    open(pack_path, "w", encoding="utf-8").write(
        pack[:idx] + new_lines + pack[idx:])
    print(f"[{lang}] appended {len(results)} entries -> {pack_path}", flush=True)
    missing = [e["key"] for e in todo if e["key"] not in results]
    if missing:
        print(f"[{lang}] STILL MISSING: {missing}", flush=True)


def main():
    only = sys.argv[1:] or LANGS
    for lang in only:
        backfill(lang)


if __name__ == "__main__":
    main()
