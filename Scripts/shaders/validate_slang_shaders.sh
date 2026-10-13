#!/bin/bash
# Loads and renders every preset of the pinned slang library on this Mac's GPU and records the
# ones that fail in Scripts/shaders/slang-shaders-excluded.json, which fetch_slang_shaders.py
# marks as excluded in the manifest so the app never offers them.
# Run after bumping slang-shaders.lock.json or editing PVShaders/Library. Takes ~3 minutes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/Scripts/shaders/slang-shaders-excluded.json"

LIBRARY="$(python3 "$ROOT/Scripts/shaders/fetch_slang_shaders.py")"
(cd "$ROOT/PVShaders" && swift build -c release --product pvshader-validate)
"$ROOT/PVShaders/.build/release/pvshader-validate" "$LIBRARY" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "Wrote $OUT"
