# Iteratively removes the nearest preceding `const ` for every
# invalid_constant error flutter analyze reports (fallout of AppColors
# becoming theme-aware getters). Lint infos are fine; errors are not.
import re
import subprocess
import sys
from collections import defaultdict

ROOT = r"d:\Masaustu\github\Kandao"

def analyze():
    out = subprocess.run(
        ["flutter", "analyze", "--no-pub", "lib"],
        cwd=ROOT, capture_output=True, text=True, shell=True)
    errs = []
    for line in (out.stdout + out.stderr).splitlines():
        m = re.search(r"error - .*? - (lib\\[^:]+):(\d+):(\d+) - "
                      r"(invalid_constant|const_initialized_with_non_constant_value|"
                      r"const_with_non_const|non_constant_list_element|"
                      r"non_constant_map_element|const_constructor_param_type_mismatch)",
                      line)
        if m:
            errs.append((m.group(1), int(m.group(2)), m.group(4)))
    return errs

def fix_round(errs):
    by_file = defaultdict(list)
    for f, ln, kind in errs:
        by_file[f].append((ln, kind))
    for f, items in by_file.items():
        path = ROOT + "\\" + f
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
        # process bottom-up so earlier removals don't shift later line numbers
        for ln, kind in sorted(items, reverse=True):
            if kind == "const_initialized_with_non_constant_value":
                i = ln - 1
                lines[i] = re.sub(r"\bconst\b", "final", lines[i], count=1)
                continue
            # walk up from the error line to the nearest 'const '
            for i in range(ln - 1, max(-1, ln - 40), -1):
                if re.search(r"\bconst\s", lines[i]):
                    lines[i] = re.sub(r"\bconst\s", "", lines[i], count=1)
                    break
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.writelines(lines)

for rnd in range(8):
    errs = analyze()
    print(f"round {rnd}: {len(errs)} const errors", flush=True)
    if not errs:
        break
    fix_round(errs)
print("done")
