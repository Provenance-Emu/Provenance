#!/bin/bash
# Xcode Run Script: copies the PVLookup databases pinned in Scripts/lookup/databases.lock.json into
# the root of the app bundle, where PVLookup's default `LookupDatabases` source looks for
# `<file name>.zip` in Bundle.main. fetch-lookup-databases.sh downloads them once into the gitignored
# LookupDatabases/ (cached by sha256 in ~/Library/Caches/PVLookupDatabases) and verifies each sha256.
# Needs ENABLE_USER_SCRIPT_SANDBOXING=NO on the target: it reads ~/Library/Caches and the network.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/Scripts/lookup/databases.lock.json"
FETCHED="$ROOT/LookupDatabases"
DEST="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}"

/bin/bash "$ROOT/Scripts/lookup/fetch-lookup-databases.sh" "$LOCK" "$FETCHED"

mkdir -p "$DEST"
COUNT="$(plutil -extract assets raw -o - "$LOCK")"
for ((i = 0; i < COUNT; i++)); do
    NAME="$(plutil -extract "assets.${i}.as" raw -o - "$LOCK" 2>/dev/null \
        || plutil -extract "assets.${i}.name" raw -o - "$LOCK")"
    rm -f "$DEST/$NAME"
    # APFS clone when possible (no extra disk), plain copy otherwise.
    cp -c "$FETCHED/$NAME" "$DEST/$NAME" 2>/dev/null || cp "$FETCHED/$NAME" "$DEST/$NAME"
done
