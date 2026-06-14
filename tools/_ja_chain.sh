#!/usr/bin/env bash
# Waits for the detached ja_backfill (dictionary) to finish, then runs the
# remaining Japanese data backfills sequentially to avoid Gemini quota
# contention. One-off helper for the Japanese rollout.
set -u
cd "$(dirname "$0")/.."

echo "[chain] waiting for ja_backfill (pid ${1:-?}) to finish..."
if [ -n "${1:-}" ]; then
  while kill -0 "$1" 2>/dev/null; do sleep 30; done
fi
echo "[chain] dictionary backfill finished."

echo "[chain] === add_ja_to_wordlists ==="
python tools/add_ja_to_wordlists.py

echo "[chain] === gen_ja_landmarks ==="
python tools/gen_ja_landmarks.py

echo "[chain] === quiz_ja_backfill ==="
python tools/quiz_ja_backfill.py

echo "[chain] ALL_DONE"
