#!/bin/bash
# Package an archived app without allocating a second full app bundle.
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 APP_PATH OUTPUT_IPA PAYLOAD_APP_NAME [--without-extensions]" >&2
    exit 2
fi
app_path="${1%/}"
if [ ! -d "$app_path" ]; then
    echo "App bundle not found: $app_path" >&2
    exit 1
fi
app_path="$(cd "$(dirname "$app_path")" && pwd)/$(basename "$app_path")"
mkdir -p "$(dirname "$2")"
output="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
app_name="$3"
case "$app_name" in
    ""|*/*) echo "PAYLOAD_APP_NAME must be a single filename" >&2; exit 2 ;;
esac
if [ "$#" -eq 4 ] && [ "$4" != "--without-extensions" ]; then
    echo "Unknown option: $4" >&2
    exit 2
fi
staging=$(mktemp -d "${TMPDIR:-/tmp}/provenance-ipa.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/Payload"
ln -s "$app_path" "$staging/Payload/$app_name"
rm -f "$output"
# ZIP dereferences this app symlink by default; do not use -y (store symlinks).
if [ "${4-}" = "--without-extensions" ]; then
    (cd "$staging" && zip -qr "$output" Payload -x \
        "Payload/$app_name/PlugIns/*" "Payload/$app_name/Watch/*" "Payload/$app_name/Extensions/*")
else
    (cd "$staging" && zip -qr "$output" Payload)
fi
