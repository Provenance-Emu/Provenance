#!/bin/bash
# Xcode Run Script: copies the unpacked slang shader library (see fetch_slang_shaders.py) into the
# app bundle as SlangShaders/. The fetch is cached per lock file, so only the first build downloads.
# Needs ENABLE_USER_SCRIPT_SANDBOXING=NO on the target: it reads ~/Library/Caches and the network.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/SlangShaders"
python3 "$ROOT/Scripts/shaders/fetch_slang_shaders.py" --out "$DEST" > /dev/null
