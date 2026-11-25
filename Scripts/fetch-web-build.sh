#!/usr/bin/env bash
set -euo pipefail

# Downloads the publicly served GameMaker HTML5 build of Frickbear's 3 into
# Game/, which is bundled into the iOS app. GameURLSchemeHandler serves every
# file from the app bundle through fb3:// so the finished IPA works offline.
#
# IMPORTANT: This fetches third-party fan-game assets from the unofficial web
# port. Use for personal, non-commercial purposes only and keep CREDITS.md.

BASE="${FB3_WEB_BASE:-https://cdn.gachaplay.online/games/frickbears-3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${FB3_GAME_DIR:-$ROOT/Game}"

mkdir -p "$DEST"

echo "==> Downloading index.html"
curl -fsSL --retry 3 --retry-delay 1 \
  -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36" \
  "$BASE/index.html" -o "$DEST/index.html"

# The CDN page contains an obfuscated host/referrer check that replaces the
# document with a "Play ... on playfrickbears.com" link unless it is loaded
# from cdn.gachaplay.online with a playfrickbears.com referrer. Our app loads
# it from fb3://local, so that script must be stripped before bundling.
python3 - "$DEST/index.html" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    html = handle.read()

removed = []

# Keep the opening/closing tags around a comment so the HTML stays valid.
def scrub_full(match):
    body = match.group(2)
    # The obfuscator renames every identifier on each CDN request, so match
    # the script's shape: a small decoder block with a base64 string table,
    # a rotation loop, and reads of navigator/document/window/location.
    is_redirect = (
        "function _0xc1bb(" in body
        or "__pfb" in body
        or "playfrickbears.com" in body
        or (
            4000 <= len(body) <= 12000
            and "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/=" in body
            and "while(!![])" in body
            and all(token in body for token in ("navigator", "document", "window", "location"))
        )
    )
    if is_redirect:
        removed.append(len(body))
        return match.group(1) + "/* removed host-redirect script */" + match.group(3)
    return match.group(0)

cleaned = re.sub(r"(<script[^>]*>)([\s\S]*?)(</script>)", scrub_full, html)

with open(path, "w", encoding="utf-8", newline="") as handle:
    handle.write(cleaned)

if removed:
    print("==> Removed %d host-redirect script(s) (%d chars)" % (len(removed), sum(removed)))
else:
    print("==> WARNING: no host-redirect script found; verify index.html manually")
PY

echo "==> Resolving file list from manifestFiles()"
python3 - "$DEST/index.html" "$BASE" "$DEST" <<'PY'
import os
import re
import shutil
import subprocess
import sys

index_path, base, dest = sys.argv[1:4]

with open(index_path, "r", encoding="utf-8") as handle:
    html = handle.read()

match = re.search(
    r"function\s+manifestFiles\s*\(\s*\)\s*\{.*?return\s*\[(.*?)\]\s*\.join",
    html,
    re.S,
)
if not match:
    raise SystemExit("Could not find manifestFiles() in index.html")

files = re.findall(r'"([^"]+)"', match.group(1))

# Files referenced directly by index.html but not listed in the manifest.
files += [
    "index.html",
    "manifest.webmanifest",
    "icon-192.png",
    "runner.svg",
    "display_mouse_lock.js",
    "NekoPresence.js",
]

# runnerLocal.svg does not exist on the CDN; bundle a copy locally so the
# runner's hidden <img> does not generate a 404 during startup.

# Preserve order, remove duplicates.
files = list(dict.fromkeys(f.strip() for f in files if f.strip()))
if not files:
    raise SystemExit("Could not parse file list - check the CDN build layout.")

print("==> Bundling %d files" % len(files))
for i, name in enumerate(files, 1):
    out = os.path.join(dest, name)
    if os.path.exists(out) and os.path.getsize(out) > 0:
        print("[%d/%d] skip    %s" % (i, len(files), name))
        continue

    os.makedirs(os.path.dirname(out), exist_ok=True)
    partial = out + ".part"
    print("[%d/%d] fetch   %s" % (i, len(files), name))
    # The CDN rejects some non-browser User-Agents; curl with a browser UA is
    # reliable. Download to .part so a failed fetch is never mistaken for a
    # valid cached asset on the next run.
    subprocess.run([
        "curl", "-fsSL", "--retry", "3", "--retry-delay", "1",
        "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
              "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        "-o", partial, base + "/" + name,
    ], check=True)
    os.replace(partial, out)

runner_svg = os.path.join(dest, "runner.svg")
local_runner_svg = os.path.join(dest, "runnerLocal.svg")
if os.path.exists(runner_svg) and not os.path.exists(local_runner_svg):
    shutil.copyfile(runner_svg, local_runner_svg)
    print("==> Added local runnerLocal.svg copy")

total = sum(
    os.path.getsize(os.path.join(root, f))
    for root, _, names in os.walk(dest)
    for f in names
    if not f.endswith(".part")
)
print("==> Done. Game bundle size: %.1f MB" % (total / 1024 / 1024))
PY

echo "==> Downloaded Game/ bundle:"
du -sh "$DEST"
