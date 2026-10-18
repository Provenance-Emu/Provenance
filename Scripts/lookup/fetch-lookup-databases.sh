#!/usr/bin/env bash
#
# Fetch the PVLookup databases an app pins in its databases.lock.json.
#
#   fetch-lookup-databases.sh <databases.lock.json> <destination dir>
#
# PVLookup ships no database bytes. They are assets on the immutable
# `databases-YYYY-MM-DD` releases of github.com/Provenance-Emu/PVLookup, and
# each app pins the ones it wants, by sha256, in a lock file:
#
#   {
#     "repository": "Provenance-Emu/PVLookup",
#     "release": "databases-2026-10-17",
#     "assets": [
#       { "name": "openvgdb.sqlite.zip", "sha256": "…" },
#       { "name": "libretrodb-dreamcast.sqlite.zip", "as": "libretrodb.sqlite.zip", "sha256": "…" }
#     ]
#   }
#
# `as` renames the file in the destination. PVLookup looks for
# `<database file name>.zip` (e.g. libretrodb.sqlite.zip) in the main bundle by
# default, so an app that renames a variant there needs no
# LookupDatabases.configure call.
#
# Downloads are cached by sha256 under ~/Library/Caches/PVLookupDatabases (override
# with PVLOOKUP_DATABASE_CACHE), so repeat builds, other worktrees and CI re-runs
# with a restored cache never download again. Every file is verified against its
# pinned sha256; a mismatch fails the build. Files in the destination that the
# lock doesn't list are left alone.
#
# Canonical copy: Provenance-Emu/PVLookup Scripts/fetch-lookup-databases.sh.
# Apps copy it in; keep the copies identical.
set -euo pipefail

LOCK="${1:?usage: $0 <databases.lock.json> <destination dir>}"
DEST="${2:?usage: $0 <databases.lock.json> <destination dir>}"
CACHE="${PVLOOKUP_DATABASE_CACHE:-${HOME}/Library/Caches/PVLookupDatabases}"

field() { plutil -extract "$1" raw -o - "${LOCK}" 2>/dev/null || true; }
sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

[ -f "${LOCK}" ] || { echo "error: lock file not found: ${LOCK}" >&2; exit 1; }
REPO="$(field repository)"
RELEASE="$(field release)"
COUNT="$(field assets)"
[ -n "${REPO}" ] && [ -n "${RELEASE}" ] && [ -n "${COUNT}" ] \
    || { echo "error: ${LOCK} needs repository, release and assets" >&2; exit 1; }

mkdir -p "${DEST}" "${CACHE}"

for ((i = 0; i < COUNT; i++)); do
    NAME="$(field "assets.${i}.name")"
    WANT="$(field "assets.${i}.sha256" | tr 'A-F' 'a-f')"
    AS="$(field "assets.${i}.as")"; AS="${AS:-${NAME}}"
    [ -n "${NAME}" ] && [ -n "${WANT}" ] || { echo "error: assets[${i}] needs name and sha256" >&2; exit 1; }

    OUT="${DEST}/${AS}"
    STAMP="${DEST}/.${AS}.sha256"
    # Already in place: trust the stamp only if the file is still there.
    if [ -f "${OUT}" ] && [ "$(cat "${STAMP}" 2>/dev/null)" = "${WANT}" ]; then
        continue
    fi

    CACHED="${CACHE}/${WANT}"
    if [ ! -f "${CACHED}" ] || [ "$(sha256_of "${CACHED}")" != "${WANT}" ]; then
        URL="https://github.com/${REPO}/releases/download/${RELEASE}/${NAME}"
        echo "PVLookup: downloading ${NAME} (${RELEASE})"
        TMP="${CACHED}.partial.$$"
        curl --fail --location --silent --show-error --retry 3 -o "${TMP}" "${URL}" \
            || { rm -f "${TMP}"; echo "error: download failed: ${URL}" >&2; exit 1; }
        GOT="$(sha256_of "${TMP}")"
        if [ "${GOT}" != "${WANT}" ]; then
            rm -f "${TMP}"
            echo "error: ${NAME}: sha256 ${GOT} does not match the pinned ${WANT}" >&2
            exit 1
        fi
        mv -f "${TMP}" "${CACHED}"
    fi

    # APFS clone when possible (no extra disk), plain copy otherwise.
    rm -f "${OUT}"
    cp -c "${CACHED}" "${OUT}" 2>/dev/null || cp "${CACHED}" "${OUT}"
    echo "${WANT}" > "${STAMP}"
    echo "PVLookup: ${AS} ready"
done
