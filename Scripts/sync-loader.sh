#!/usr/bin/env bash
# Refreshes the HTML shell bundled in the IPA from the standalone browser
# loader. Runtime/assets come from the pinned CDN at runtime.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/../frickbears3-4ld-v215-loader/index.html"
DST="$ROOT/Game/index.html"

if [ ! -f "$SRC" ]; then
  echo "Could not find the browser loader at $SRC" >&2
  exit 1
fi

cp -f "$SRC" "$DST"
echo "Copied $SRC -> $DST"
echo "Remember to commit Game/index.html and re-run the IPA workflow."
