#!/usr/bin/env bash
# local-dylibs.sh — publish/fetch the custom-built libretro dylibs.
#
# Some cores are NOT on the libretro buildbot: they are custom Provenance builds
# (flycast-jitless, virtualjaguar). cores.yml marks them `local: true`, which stops
# get-modules.sh downloading or pruning them — but says nothing about where they
# live. They are gitignored (modules/.gitignore is `*`), so until now they existed
# only on the machine that built them and were one `rm -rf modules/` from gone.
#
# They are stored as release assets on a PRIVATE repo rather than committed:
#   - a 13 MB binary per rebuild is not something to put in git history
#   - private, because these are unreleased custom builds
#
# Usage:
#   ./local-dylibs.sh upload [core...]   # after building locally — push to the store
#   ./local-dylibs.sh fetch  [core...]   # on a fresh clone / CI — pull into modules/
#   ./local-dylibs.sh list               # what cores.yml marks local, and what is on disk
#
# With no core names, acts on every `local: true` core in cores.yml.
#
# Auth: uses `gh`, so locally it just works. In CI, GITHUB_TOKEN cannot read another
# private repo — set DYLIBS_TOKEN to a PAT with `repo` scope and export it as GH_TOKEN
# for this step only.
#
# Config (env overrides):
#   DYLIBS_REPO  default Provenance-Emu/provenance-dylibs
#   DYLIBS_TAG   default latest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/modules"
CORES_YML="$SCRIPT_DIR/cores.yml"

DYLIBS_REPO="${DYLIBS_REPO:-Provenance-Emu/provenance-dylibs}"
DYLIBS_TAG="${DYLIBS_TAG:-latest}"

die() { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

command -v gh >/dev/null 2>&1 || die "gh CLI is required"
[ -f "$CORES_YML" ] || die "cores.yml not found at $CORES_YML"
mkdir -p "$MODULES_DIR"

# Parse cores.yml for `local: true` entries, emitting "<name>\t<filename-or-empty>".
# Deliberately not using a YAML library: this script has to run on a bare CI runner
# and on a fresh clone, where PyYAML may not be installed.
local_cores() {
    awk '
        /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
            if (name != "" && islocal) print name "\t" fname
            name = $0
            sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
            gsub(/["\047]/, "", name)
            islocal = 0; fname = ""
            next
        }
        /^[[:space:]]*local:[[:space:]]*true/ { islocal = 1 }
        /^[[:space:]]*filename:[[:space:]]*/ {
            fname = $0
            sub(/^[[:space:]]*filename:[[:space:]]*/, "", fname)
            gsub(/["\047]/, "", fname)
        }
        END { if (name != "" && islocal) print name "\t" fname }
    ' "$CORES_YML"
}

# A core may ship one platform-neutral dylib (filename: set) or the _ios/_tvos pair.
dylibs_for() {
    local name="$1" fname="$2"
    if [ -n "$fname" ]; then
        echo "$fname"
    else
        echo "${name}_libretro_ios.dylib"
        echo "${name}_libretro_tvos.dylib"
    fi
}

selected_cores() {
    if [ "$#" -gt 0 ]; then
        for want in "$@"; do
            local row; row=$(local_cores | awk -F'\t' -v w="$want" '$1==w')
            [ -n "$row" ] || die "'$want' is not a local: true core in cores.yml"
            echo "$row"
        done
    else
        local_cores
    fi
}

ensure_release() {
    gh release view "$DYLIBS_TAG" --repo "$DYLIBS_REPO" >/dev/null 2>&1 && return 0
    info "creating release '$DYLIBS_TAG' on $DYLIBS_REPO"
    gh release create "$DYLIBS_TAG" --repo "$DYLIBS_REPO" \
        --title "Custom libretro dylibs" \
        --notes "Custom Provenance builds of libretro cores that are not on the buildbot. Rolling — assets are replaced in place by local-dylibs.sh upload." \
        >/dev/null
}

cmd_list() {
    echo "local: true cores in cores.yml  (store: $DYLIBS_REPO @ $DYLIBS_TAG)"
    while IFS=$'\t' read -r name fname; do
        [ -n "$name" ] || continue
        while read -r d; do
            [ -n "$d" ] || continue
            if [ -f "$MODULES_DIR/$d" ]; then
                printf "  %-40s present  %s\n" "$d" "$(du -h "$MODULES_DIR/$d" | cut -f1)"
            else
                printf "  %-40s MISSING\n" "$d"
            fi
        done < <(dylibs_for "$name" "$fname")
    done < <(local_cores)
}

cmd_upload() {
    ensure_release
    local n=0
    while IFS=$'\t' read -r name fname; do
        [ -n "$name" ] || continue
        while read -r d; do
            [ -n "$d" ] || continue
            local src="$MODULES_DIR/$d"
            if [ ! -f "$src" ]; then
                info "skip $d (not present locally)"
                continue
            fi
            local tmp; tmp=$(mktemp -d)
            # Zip from inside modules/ so the archive contains a bare dylib, matching
            # the buildbot layout that get-modules.sh already knows how to unzip.
            ( cd "$MODULES_DIR" && zip -q -j "$tmp/$d.zip" "$d" )
            info "uploading $d.zip ($(du -h "$tmp/$d.zip" | cut -f1))"
            gh release upload "$DYLIBS_TAG" "$tmp/$d.zip" --repo "$DYLIBS_REPO" --clobber
            rm -rf "$tmp"
            n=$((n + 1))
        done < <(dylibs_for "$name" "$fname")
    done < <(selected_cores "$@")
    echo "uploaded $n dylib(s) to $DYLIBS_REPO @ $DYLIBS_TAG"
}

cmd_fetch() {
    local n=0 missing=0
    while IFS=$'\t' read -r name fname; do
        [ -n "$name" ] || continue
        while read -r d; do
            [ -n "$d" ] || continue
            local tmp; tmp=$(mktemp -d)
            if gh release download "$DYLIBS_TAG" --repo "$DYLIBS_REPO" \
                 --pattern "$d.zip" --dir "$tmp" >/dev/null 2>&1; then
                unzip -q -o "$tmp/$d.zip" -d "$MODULES_DIR"
                info "fetched $d"
                n=$((n + 1))
            else
                echo "  WARNING: $d.zip not found on $DYLIBS_REPO @ $DYLIBS_TAG" >&2
                missing=$((missing + 1))
            fi
            rm -rf "$tmp"
        done < <(dylibs_for "$name" "$fname")
    done < <(selected_cores "$@")
    # Not ${missing:+...}: that expands whenever the var is non-EMPTY, and "0" is
    # non-empty, so a clean run reported "0 missing".
    if [ "$missing" -gt 0 ]; then
        echo "fetched $n dylib(s), $missing missing"
    else
        echo "fetched $n dylib(s)"
    fi
    # Missing assets are a real problem for a build that expects them (they are in the
    # xcfilelists), so fail rather than let the build die later with a vaguer error.
    [ "$missing" -eq 0 ] || exit 1
}

case "${1:-}" in
    upload) shift; cmd_upload "$@" ;;
    fetch)  shift; cmd_fetch "$@" ;;
    list)   cmd_list ;;
    *)      sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
