#!/usr/bin/env bash
# media-assets.sh — publish/fetch long-lived marketing media.
#
# App Store screenshots, press-pack assets and other marketing media are large
# (hundreds of MB per release), rarely change, and are DERIVED artifacts — the
# same reasons the custom core dylibs are not in git. They live as release
# assets on a repo instead, exactly like CoresRetro/RetroArch/scripts/local-dylibs.sh
# does for cores.
#
# Screenshots are gitignored (see .gitignore). Without this script a fresh clone
# has no screenshots and `fastlane deliver` would upload an incomplete listing.
#
# Usage:
#   ./media-assets.sh upload [set...]   # after generating locally — push to the store
#   ./media-assets.sh fetch  [set...]   # before deliver / on a fresh clone
#   ./media-assets.sh list              # what sets exist locally and in the store
#
# Sets are directories under fastlane/screenshots/ (e.g. "appleTV", "en-US") plus
# the special set "press-pack" (Media/press-pack/). With no names, acts on all.
#
# Auth: uses `gh`, so locally it just works. In CI set MEDIA_TOKEN as GH_TOKEN if
# the store repo is private.
#
# Config (env overrides):
#   MEDIA_REPO  default Provenance-Emu/provenance-media
#   MEDIA_TAG   default latest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHOTS_DIR="$REPO_ROOT/fastlane/screenshots"
PRESS_DIR="$REPO_ROOT/Media/press-pack"

MEDIA_REPO="${MEDIA_REPO:-Provenance-Emu/provenance-media}"
MEDIA_TAG="${MEDIA_TAG:-latest}"

die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

command -v gh >/dev/null 2>&1 || die "gh CLI is required"

# A "set" maps to a directory; the release asset is that directory zipped.
set_dir() {
    case "$1" in
        press-pack) echo "$PRESS_DIR" ;;
        *)          echo "$SHOTS_DIR/$1" ;;
    esac
}

# Both helpers must always succeed: under `set -e` a trailing failed test would
# abort the caller (a missing press-pack dir is normal, not an error).
local_sets() {
    [ -d "$SHOTS_DIR" ] && find "$SHOTS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
    [ -d "$PRESS_DIR" ] && echo "press-pack"
    return 0
}

store_sets() {
    gh release view "$MEDIA_TAG" --repo "$MEDIA_REPO" --json assets \
        --jq '.assets[].name | sub("\\.zip$"; "")' 2>/dev/null || true
}

ensure_release() {
    gh release view "$MEDIA_TAG" --repo "$MEDIA_REPO" >/dev/null 2>&1 && return 0
    info "creating release '$MEDIA_TAG' on $MEDIA_REPO"
    gh release create "$MEDIA_TAG" --repo "$MEDIA_REPO" \
        --title "Marketing media" \
        --notes "App Store screenshots and press-pack assets. Managed by Scripts/media-assets.sh." \
        >/dev/null
}

cmd_upload() {
    local sets=("$@")
    [ ${#sets[@]} -eq 0 ] && mapfile -t sets < <(local_sets)
    [ ${#sets[@]} -eq 0 ] && die "nothing to upload — no sets found"
    ensure_release
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    for s in "${sets[@]}"; do
        local dir; dir="$(set_dir "$s")"
        [ -d "$dir" ] || { info "skip $s (no local dir)"; continue; }
        local n; n="$(find "$dir" -type f ! -name '.*' | wc -l | tr -d ' ')"
        [ "$n" -gt 0 ] || { info "skip $s (empty)"; continue; }
        info "packing $s ($n files)"
        (cd "$(dirname "$dir")" && zip -qr "$tmp/$s.zip" "$(basename "$dir")")
        gh release upload "$MEDIA_TAG" "$tmp/$s.zip" --repo "$MEDIA_REPO" --clobber
        info "uploaded $s.zip"
    done
}

cmd_fetch() {
    local sets=("$@")
    [ ${#sets[@]} -eq 0 ] && mapfile -t sets < <(store_sets)
    [ ${#sets[@]} -eq 0 ] && die "no assets in $MEDIA_REPO@$MEDIA_TAG"
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    for s in "${sets[@]}"; do
        local dir; dir="$(set_dir "$s")"
        gh release download "$MEDIA_TAG" --repo "$MEDIA_REPO" \
            --pattern "$s.zip" --dir "$tmp" --clobber 2>/dev/null \
            || { info "skip $s (not in store)"; continue; }
        mkdir -p "$(dirname "$dir")"
        rm -rf "$dir"
        unzip -qo "$tmp/$s.zip" -d "$(dirname "$dir")"
        info "fetched $s -> ${dir#$REPO_ROOT/}"
    done
}

cmd_list() {
    echo "local:"
    local_sets | while read -r s; do
        local dir; dir="$(set_dir "$s")"
        printf '  %-16s %s files\n' "$s" "$(find "$dir" -type f ! -name '.*' | wc -l | tr -d ' ')"
    done
    echo "store ($MEDIA_REPO@$MEDIA_TAG):"
    local found; found="$(store_sets)"
    if [ -n "$found" ]; then echo "$found" | sed 's/^/  /'; else echo "  (none)"; fi
    return 0
}

case "${1:-}" in
    upload) shift; cmd_upload "$@" ;;
    fetch)  shift; cmd_fetch  "$@" ;;
    list)   shift; cmd_list ;;
    *) sed -n '2,28p' "$0"; exit 1 ;;
esac
