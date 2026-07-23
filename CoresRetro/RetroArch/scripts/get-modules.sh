#!/bin/bash
# NOTE: Xcode build phases invoke scripts via /bin/sh, which ignores the shebang.
# This guard re-execs with bash so bash-specific syntax ((( )), arrays, etc.) works
# even when the build phase calls: /bin/sh ".../get-modules.sh"
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

LAST_TIMESTAMP=0
INTERVAL=3600*168
CORES_DIR="${SRCROOT}/CoresRetro/RetroArch/modules"
SCRIPTS_DIR="${SRCROOT}/CoresRetro/RetroArch/scripts"

# Dylibs matching these patterns are locally built and must never be deleted
# by platform-switch or pin-change purges.  Add new patterns as needed.
LOCAL_DYLIB_PATTERNS=( "*-jitless*" )

# Per-dylib sentinel convention: if `modules/<basename>.local` exists,
# treat <basename> as locally-managed — never delete or overwrite it.
# Returns 0 if $1 (a bare basename) is locally-overridden.
is_local_dylib() {
	local base="$1"
	local pat
	for pat in "${LOCAL_DYLIB_PATTERNS[@]}"; do
		case "$base" in ${pat}*) return 0 ;; esac
	done
	[ -f "${CORES_DIR}/${base}.local" ] && return 0
	# Check cores.yml local: true entries
	local core_name
	for core_name in "${LOCAL_CORES_FROM_YML[@]}"; do
		case "$base" in
			${core_name}_libretro*.dylib) return 0 ;;
		esac
	done
	return 1
}

# Read local core names from cores.yml (cores with "local: true").
# These are built locally and must never be downloaded, deleted, or overwritten.
LOCAL_CORES_FROM_YML=()
CORES_YML_EARLY="${SRCROOT}/CoresRetro/RetroArch/scripts/cores.yml"
if [ -f "${CORES_YML_EARLY}" ]; then
	_local_tmp=$(mktemp "${TMPDIR:-/tmp}/local_cores.XXXXXX")
	awk '
		/^[[:space:]]*- name:/ { name=$NF; gsub(/["'"'"']/, "", name) }
		/^[[:space:]]*local:[[:space:]]*true/ { print name }
	' "${CORES_YML_EARLY}" > "$_local_tmp"
	while IFS= read -r _local_core; do
		[ -n "$_local_core" ] && LOCAL_CORES_FROM_YML+=("$_local_core")
	done < "$_local_tmp"
	rm -f "$_local_tmp"
fi
unset _local_core _local_tmp
if [ "${#LOCAL_CORES_FROM_YML[@]}" -gt 0 ]; then
	echo "GetModule: local cores from cores.yml (will not download/delete): ${LOCAL_CORES_FROM_YML[*]}"
fi

# Collect basenames of locally-overridden dylibs (sentinel-flagged + cores.yml local: true).
LOCAL_OVERRIDE_NAMES=()
for sentinel in "${CORES_DIR}/"*.local; do
	[ -f "$sentinel" ] || continue
	base=$(basename "$sentinel" .local)
	LOCAL_OVERRIDE_NAMES+=( "$base" )
done
unset sentinel base
# Also exclude dylibs belonging to cores.yml local: true cores from extraction.
for _lc in "${LOCAL_CORES_FROM_YML[@]}"; do
	LOCAL_OVERRIDE_NAMES+=( "${_lc}_libretro_ios.dylib" "${_lc}_libretro_tvos.dylib" "${_lc}_libretro.dylib" )
done
unset _lc
# unzip syntax: `<archive> [files...] -x <xfile1> <xfile2> ...` — exclude
# args must follow the archive and use a single -x with N filenames.
UNZIP_EXCLUDE_ARGS=()
if [ "${#LOCAL_OVERRIDE_NAMES[@]}" -gt 0 ]; then
	UNZIP_EXCLUDE_ARGS=( -x "${LOCAL_OVERRIDE_NAMES[@]}" )
	echo "GetModule: protecting ${#LOCAL_OVERRIDE_NAMES[@]} locally-overridden dylib(s) from extraction (.local sentinel): ${LOCAL_OVERRIDE_NAMES[*]}"
fi

# Add parameter check
URL_SUFFIX=""
if [ "$1" = "-appstore" ]; then
    URL_SUFFIX="-appstore"
fi

cd "${SCRIPTS_DIR}"
# tvOS device is appletvos; tvOS Simulator is appletvsimulator — both must use
# urls*-tv.txt and tvOS zips. Only checking appletvos wrongly downloads iOS dylibs
# for simulator builds, then App Store make_frameworks (tv filter) skips them.
if [ "${PLATFORM_NAME}" = "appletvos" ] || [ "${PLATFORM_NAME}" = "appletvsimulator" ]; then
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/tvOS"
	MODULE_LIST="${SCRIPTS_DIR}/urls${URL_SUFFIX}-tv.txt"
	CURRENT_PLATFORM="tvos"
else
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/iOS"
	MODULE_LIST="${SCRIPTS_DIR}/urls${URL_SUFFIX}.txt"
	CURRENT_PLATFORM="ios"
fi

# Detect platform switch: compare current platform to the last-active platform
# recorded after a successful extraction.  A change means we need to purge the
# stale dylibs from the previous platform before re-extracting the new ones.
PLATFORM_CHANGED=0
STORED_PLATFORM=""
ACTIVE_PLATFORM_FILE="${CORES_DIR}/active_platform.txt"
if [ -f "${ACTIVE_PLATFORM_FILE}" ]; then
	STORED_PLATFORM=$(cat "${ACTIVE_PLATFORM_FILE}" 2>/dev/null || true)
fi
if [ -n "${STORED_PLATFORM}" ] && [ "${CURRENT_PLATFORM}" != "${STORED_PLATFORM}" ]; then
	echo "GetModule: platform changed (${STORED_PLATFORM} -> ${CURRENT_PLATFORM}), will purge stale dylibs"
	PLATFORM_CHANGED=1
fi

# Read pinned date from cores.yml for reproducible builds.
# If pinned_date is set, substitute it for "latest" in every URL.
# grep -v '^[[:space:]]*#' strips comment lines before matching the key,
# and [[:space:]] is used instead of \s for POSIX/macOS-BSD compatibility.
PINNED_DATE=""
CORES_YML="${SCRIPTS_DIR}/cores.yml"
if [ -f "${CORES_YML}" ]; then
	PINNED_DATE=$(grep -v '^[[:space:]]*#' "${CORES_YML}" | grep -E '^[[:space:]]*pinned_date:' | sed 's/.*pinned_date:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d '[:space:]')
fi

# Validate that PINNED_DATE is a well-formed YYYY-MM-DD date.
# Reject malformed values (inline comments, extra text) to avoid silently
# generating broken buildbot URLs.
if [ -n "${PINNED_DATE}" ]; then
	if ! echo "${PINNED_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
		echo "GetModule: ERROR — pinned_date '${PINNED_DATE}' is not a valid YYYY-MM-DD date; ignoring pin and falling back to latest" >&2
		PINNED_DATE=""
	fi
fi

if [ -n "${PINNED_DATE}" ]; then
	# Warn when the pin is more than 30 days old so developers know to bump it.
	# Uses BSD (date -j -f) or GNU (date -d) date for epoch conversion.
	PIN_EPOCH=$(date -j -f '%Y-%m-%d' "${PINNED_DATE}" '+%s' 2>/dev/null || date -d "${PINNED_DATE}" '+%s' 2>/dev/null || echo "")
	if [ -n "${PIN_EPOCH}" ] && [ "${PIN_EPOCH}" -gt 0 ] 2>/dev/null; then
		NOW_EPOCH=$(date +%s)
		PIN_AGE_DAYS=$(( (NOW_EPOCH - PIN_EPOCH) / 86400 ))
		if [ "${PIN_AGE_DAYS}" -lt 0 ]; then
			echo "GetModule: WARNING — pinned_date ${PINNED_DATE} appears to be in the future (${PIN_AGE_DAYS} days ahead of system time)." >&2
			echo "GetModule: WARNING — this may indicate clock skew or a misconfigured pin; please verify cores.yml pinned_date." >&2
		elif [ "${PIN_AGE_DAYS}" -gt 30 ]; then
			echo "GetModule: ⚠️  WARNING — pinned_date ${PINNED_DATE} is ${PIN_AGE_DAYS} days old." >&2
			echo "GetModule: ⚠️  Run 'CoresRetro/RetroArch/scripts/check-dylib-updates.sh --update' to pull the latest snapshot." >&2
		fi
	else
		echo "GetModule: WARNING — could not parse pinned_date '${PINNED_DATE}' as an epoch; skipping staleness check." >&2
	fi

	# Validate pinned date actually works on the buildbot before committing to full download.
	# Test one URL — if it 404s, the whole date is bad.
	TEST_URL=$(grep -v '^#' "${MODULE_LIST}" | head -1 | sed "s|/latest/|/${PINNED_DATE}/|g")
	if [ -n "${TEST_URL}" ]; then
		# --retry-all-errors: buildbot's nightly rotation window (~02:00 UTC) briefly
		# 404s / drops connections while latest/ symlinks churn; a transient failure
		# here would wrongly clear the pin and fall back to (churning) latest.
		HTTP_CODE=$(curl -s -L --retry 3 --retry-delay 10 --retry-all-errors -o /dev/null -w '%{http_code}' --head "${TEST_URL}" 2>/dev/null)
		if [ "${HTTP_CODE}" = "404" ] || [ "${HTTP_CODE}" = "000" ]; then
			echo "GetModule: ERROR — pinned_date ${PINNED_DATE} returned HTTP ${HTTP_CODE} from buildbot." >&2
			echo "GetModule: ERROR — Buildbot may not serve dated snapshots for this platform. Falling back to latest." >&2
			PINNED_DATE=""
		else
			echo "GetModule: pinned_date ${PINNED_DATE} validated (HTTP ${HTTP_CODE})"
		fi
	fi
fi

if [ -n "${PINNED_DATE}" ]; then
	echo "GetModule: using pinned buildbot date ${PINNED_DATE} (update via update-dylib-pins.sh)"
	EFFECTIVE_MODULE_LIST="${CORES_ARCHIVE_DIR}/urls_pinned.txt"
	mkdir -p "${CORES_ARCHIVE_DIR}"
	sed "s|/latest/|/${PINNED_DATE}/|g" "${MODULE_LIST}" > "${EFFECTIVE_MODULE_LIST}"
else
	echo "GetModule: no pinned_date found in cores.yml — using latest (non-reproducible)"
	EFFECTIVE_MODULE_LIST="${MODULE_LIST}"
fi

if [ ! -d "${CORES_ARCHIVE_DIR}" ]; then
	mkdir -p "${CORES_ARCHIVE_DIR}"
fi

# Fingerprint the URL list (+ pin) so `generate_core_lists.py` / cores.yml regen
# invalidates the weekly fast-path without deleting modules/ manually.
MANIFEST_CHANGED=0
MANIFEST_FP_FILE="${CORES_ARCHIVE_DIR}/url_manifest.sha256"
if [ -f "${MODULE_LIST}" ]; then
	CURRENT_MANIFEST_SHA=$( { printf '%s\n' "${PINNED_DATE:-latest}"; cat "${MODULE_LIST}"; } | shasum -a 256 2>/dev/null | awk '{print $1}' )
	if [ -z "${CURRENT_MANIFEST_SHA}" ]; then
		CURRENT_MANIFEST_SHA=$( { printf '%s\n' "${PINNED_DATE:-latest}"; cat "${MODULE_LIST}"; } | openssl dgst -sha256 2>/dev/null | awk '{print $NF}' )
	fi
	STORED_MANIFEST_SHA=""
	if [ -f "${MANIFEST_FP_FILE}" ]; then
		STORED_MANIFEST_SHA=$(tr -d '[:space:]' < "${MANIFEST_FP_FILE}" 2>/dev/null || true)
	fi
	if [ -n "${CURRENT_MANIFEST_SHA}" ] && [ "${CURRENT_MANIFEST_SHA}" != "${STORED_MANIFEST_SHA}" ]; then
		echo "GetModule: URL manifest changed (${MODULE_LIST} or pinned_date) — refreshing core downloads for this platform"
		MANIFEST_CHANGED=1
		rm -f "${CORES_ARCHIVE_DIR}/timestamp.txt"
	fi
else
	echo "GetModule: WARNING — MODULE_LIST missing: ${MODULE_LIST}" >&2
fi

# Detect pin changes: if the stored pin differs from the current one, force a
# re-download regardless of the time interval, and clear the existing dylibs so
# the new snapshot is fully extracted (unzip -n would otherwise keep stale files).
PIN_CHANGED=0
STORED_PIN=""
if [ -f "${CORES_ARCHIVE_DIR}/pinned_date.txt" ]; then
	STORED_PIN=$(cat "${CORES_ARCHIVE_DIR}/pinned_date.txt")
fi
if [ "${PINNED_DATE}" != "${STORED_PIN}" ] && { [ -n "${PINNED_DATE}" ] || [ -n "${STORED_PIN}" ]; }; then
	echo "GetModule: pin changed (${STORED_PIN:-none} -> ${PINNED_DATE:-latest}), forcing re-download on next run"
	PIN_CHANGED=1
	rm -f "${CORES_ARCHIVE_DIR}/timestamp.txt"
fi

if [ -f "${CORES_ARCHIVE_DIR}/timestamp.txt" ] ; then
	LAST_TIMESTAMP=$(cat "${CORES_ARCHIVE_DIR}/timestamp.txt")
fi
TIMESTAMP=$(date +%s)
LAST_TIMESTAMP=$(( LAST_TIMESTAMP + INTERVAL  ))
echo "GetModule: ${TIMESTAMP} ${LAST_TIMESTAMP}"

# Count expected cores from URL list (non-commented lines)
EXPECTED_COUNT=$(grep -v '^#' "${EFFECTIVE_MODULE_LIST}" | grep -c '.' || echo 0)

# Drop dylibs that are no longer listed in urls*.txt. Incremental extractions use
# unzip -n, so cores removed from cores.yml would otherwise stay in modules/ forever
# and keep producing orphan *.libretro.framework bundles in the app.
prune_dylibs_not_in_manifest() {
	local manifest="$1"
	local mod_dir="$2"
	[ -f "$manifest" ] || return 0
	local expected
	expected=$(mktemp)
	# Build raw expected basenames from zip URLs, then expand: buildbot zips named
	# fmsx_libretro.dylib.zip often extract to fmsx_libretro_tvos.dylib / _ios.dylib,
	# so those on-disk names must count as in-manifest or prune deletes them.
	local raw
	raw=$(mktemp)
	while IFS= read -r url || [ -n "$url" ]; do
		case "$url" in \#*|"") continue ;; esac
		zip_base=$(basename "$url")
		echo "${zip_base%.zip}"
	done < "$manifest" | sort -u > "$raw"
	: > "$expected"
	while IFS= read -r e || [ -n "$e" ]; do
		[ -z "$e" ] && continue
		echo "$e"
		case "$e" in
			*_ios.dylib|*_tvos.dylib) ;;
			*.dylib)
				stem="${e%.dylib}"
				echo "${stem}_ios.dylib"
				echo "${stem}_tvos.dylib"
				;;
		esac
	done < "$raw" | sort -u > "$expected"
	rm -f "$raw"

	local removed=0
	for dylib in "${mod_dir}/"*.dylib; do
		[ -f "$dylib" ] || continue
		local base
		base=$(basename "$dylib")
		is_local_dylib "$base" && continue
		if ! grep -qx "$base" "$expected"; then
			echo "GetModule: removing stale dylib not in manifest: ${base}"
			rm -f "$dylib"
			removed=$((removed + 1))
		fi
	done
	rm -f "$expected"
	if [ "$removed" -gt 0 ]; then
		echo "GetModule: pruned ${removed} stale dylib(s) (dropped from manifest — was still in modules/)"
	fi
}
prune_dylibs_not_in_manifest "${EFFECTIVE_MODULE_LIST}" "${CORES_DIR}"

# Even when PLATFORM_CHANGED=0, modules/ can still contain the other platform's dylibs
# (interrupted switch, manual copy, or a previous run that exited before purge). That
# breaks make_frameworks_retroarch.sh (non-deterministic find order → wrong Mach-O in
# *.libretro.framework) and causes DEBUG orphan assertions. Always drop stale suffixes.
remove_stale_other_platform_dylibs() {
	local mod_dir="$1"
	local plat="$2"
	local removed=0
	local f base
	for f in "${mod_dir}/"*.dylib; do
		[ -f "$f" ] || continue
		base=$(basename "$f")
		is_local_dylib "$base" && continue
		case "$base" in
			*_ios.dylib)
				if [ "$plat" = "tvos" ]; then
					echo "GetModule: removing stale iOS dylib after destination switch: ${base}"
					rm -f "$f"
					removed=$((removed + 1))
				fi
				;;
			*_tvos.dylib)
				if [ "$plat" = "ios" ]; then
					echo "GetModule: removing stale tvOS dylib after destination switch: ${base}"
					rm -f "$f"
					removed=$((removed + 1))
				fi
				;;
		esac
	done
	if [ "$removed" -gt 0 ]; then
		echo "GetModule: removed ${removed} other-platform dylib(s) — mixed modules/ cleaned for current platform '${plat}'"
	fi
}
remove_stale_other_platform_dylibs "${CORES_DIR}" "${CURRENT_PLATFORM}"

# Fast-path: when the platform is known (active_platform.txt exists), unchanged,
# the pin is unchanged, the timestamp is still fresh (no download due), and ≥80%
# of expected dylibs are already present, skip both the purge and extraction.
# Note: PLATFORM_CHANGED=0 on its own does NOT mean "same platform" — it also stays 0
# when STORED_PLATFORM="" (first run, no sentinel).  The explicit [ -n "${STORED_PLATFORM}" ]
# guard below prevents the fast-path from firing on that first run.  Without it, a fresh
# machine with no sentinel but a populated modules/ dir could incorrectly skip extraction.
if (( TIMESTAMP <= LAST_TIMESTAMP )) && [ -n "${STORED_PLATFORM}" ] && [ "${PLATFORM_CHANGED}" = "0" ] && [ "${PIN_CHANGED}" = "0" ] && [ "${MANIFEST_CHANGED}" = "0" ]; then
	# Count dylibs belonging to the current platform: include both platform-suffixed
	# dylibs (e.g. *ios*.dylib / *tvos*.dylib) and platform-neutral ones (e.g.
	# dolphin_libretro.dylib) so the 80% threshold is not artificially low when the
	# URL list contains neutral-name cores.  Stale other-platform suffixed dylibs are
	# explicitly excluded so they cannot satisfy the threshold and trigger a false skip.
	if [ "${CURRENT_PLATFORM}" = "tvos" ]; then
		EXISTING_DYLIB_COUNT=$(find "${CORES_DIR}" -maxdepth 1 \( -name "*tvos*.dylib" -o \( -name "*.dylib" -not -name "*ios*.dylib" -not -name "*tvos*.dylib" \) \) -type f 2>/dev/null | wc -l | tr -d ' ')
	else
		EXISTING_DYLIB_COUNT=$(find "${CORES_DIR}" -maxdepth 1 \( -name "*ios*.dylib" -o \( -name "*.dylib" -not -name "*ios*.dylib" -not -name "*tvos*.dylib" \) \) -type f 2>/dev/null | wc -l | tr -d ' ')
	fi
	if [ "${EXPECTED_COUNT}" -gt 0 ]; then
		FAST_THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
		[ "${FAST_THRESHOLD}" -lt 1 ] && FAST_THRESHOLD=1
		if [ "${EXISTING_DYLIB_COUNT}" -ge "${FAST_THRESHOLD}" ]; then
			echo "GetModule: platform '${CURRENT_PLATFORM}' unchanged, timestamp fresh, ${EXISTING_DYLIB_COUNT}/${EXPECTED_COUNT} dylibs present — skipping extraction"
			exit 0
		fi
	fi
fi

# Purge the other-platform dylibs only when the platform has changed or when no
# active platform has been recorded yet (first run).  Same-platform rebuilds skip
# this step so the dylibs are left in place for unzip -n to confirm quickly.
# On a platform switch we also remove platform-neutral dylibs (those without an
# ios/tvos suffix, e.g. dolphin_libretro.dylib) so they are re-extracted for the
# new platform rather than silently reused from the previous build.
if [ "${PLATFORM_CHANGED}" = "1" ] || [ -z "${STORED_PLATFORM}" ]; then
	# Remove other-platform dylibs (suffix-matched), preserving any with a
	# .local sentinel or matching LOCAL_DYLIB_PATTERNS.
	if [ "${CURRENT_PLATFORM}" = "tvos" ]; then
		other_glob='*ios*.dylib'
	else
		other_glob='*tvos*.dylib'
	fi
	for f in "${CORES_DIR}"/${other_glob}; do
		[ -f "$f" ] || continue
		base=$(basename "$f")
		is_local_dylib "$base" && continue
		rm -f "$f"
	done
	unset other_glob f base
	# Remove platform-neutral dylibs so they are not silently reused from the
	# previous platform build (unzip -o below will re-extract the correct versions).
	# Preserve locally-built dylibs matching LOCAL_DYLIB_PATTERNS or a .local sentinel.
	LOCAL_EXCLUDES=()
	for pat in "${LOCAL_DYLIB_PATTERNS[@]}"; do
		LOCAL_EXCLUDES+=( -not -name "${pat}.dylib" -not -name "${pat}" )
	done
	for sentinel in "${CORES_DIR}/"*.local; do
		[ -f "$sentinel" ] || continue
		s_base=$(basename "$sentinel" .local)
		LOCAL_EXCLUDES+=( -not -name "$s_base" )
	done
	unset sentinel s_base
	find "${CORES_DIR}" -maxdepth 1 -name "*.dylib" \
		-not -name "*ios*" -not -name "*tvos*" "${LOCAL_EXCLUDES[@]}" -type f -delete 2>/dev/null || true
fi

if (( TIMESTAMP > LAST_TIMESTAMP )); then
	echo "GetModule: ${TIMESTAMP} > ${LAST_TIMESTAMP} Starting Download... ${EFFECTIVE_MODULE_LIST}"
	rm -f "${CORES_ARCHIVE_DIR}/"*.zip
	cd "${CORES_ARCHIVE_DIR}"

	# Early sentinel check: before committing to the full download list, fetch the
	# first non-comment URL and confirm it returns a real zip (PK\x03\x04 magic).
	# This catches buildbot URL pattern breakage (path layout changes, broken
	# pinned_date snapshots, DNS/TLS issues) before we spend minutes downloading
	# 128 HTML error pages. We skip-only on validation failure, never on net errors,
	# so a transient single-URL hiccup doesn't block the rest of the run.
	SENTINEL_URL=$(grep -v '^[[:space:]]*#' "${EFFECTIVE_MODULE_LIST}" | grep -v '^[[:space:]]*$' | head -1)
	if [ -n "${SENTINEL_URL}" ]; then
		SENTINEL_TMP=$(mktemp "${TMPDIR:-/tmp}/sentinel.XXXXXX.zip")
		if curl --fail -L --silent --show-error --retry 3 --retry-delay 10 --retry-all-errors -o "${SENTINEL_TMP}" "${SENTINEL_URL}" 2>/dev/null; then
			SENTINEL_MAGIC=$(xxd -l 4 -p "${SENTINEL_TMP}" 2>/dev/null)
			if [ "${SENTINEL_MAGIC}" != "504b0304" ]; then
				echo "GetModule: ERROR — sentinel URL did not return a valid zip (magic=${SENTINEL_MAGIC:-empty})" >&2
				echo "GetModule: ERROR — URL: ${SENTINEL_URL}" >&2
				echo "GetModule: ERROR — Buildbot URL pattern may be broken." >&2
				echo "GetModule: ERROR — Check cores.yml pinned_date or buildbot path layout (apple/ios-arm64, apple/tvos-arm64)." >&2
				rm -f "${SENTINEL_TMP}"
				exit 1
			fi
			rm -f "${SENTINEL_TMP}"
			echo "GetModule: sentinel URL validated ($(basename "${SENTINEL_URL}") returns a real zip)"
		else
			# Transient single-URL failure — let the full loop run and rely on threshold.
			echo "GetModule: WARNING — sentinel URL fetch failed (network/transient?); continuing with full download and threshold check" >&2
			rm -f "${SENTINEL_TMP}"
		fi
	fi

	# Download with --fail so curl returns non-zero on HTTP errors (404, 500, etc.)
	# instead of saving error HTML as if it were a valid zip. -L follows redirects
	# (buildbot occasionally 30x's to a CDN edge). --retry-all-errors retries even
	# on 404s because buildbot's nightly rotation (~02:00 UTC) transiently 404s
	# individual URLs while latest/ symlinks are re-pointed (both CI jobs failed
	# this way on 2026-07-23; all URLs were healthy minutes later).
	DOWNLOAD_FAIL=0
	DOWNLOAD_OK=0
	while IFS= read -r url; do
		# Skip comments and blank lines
		case "$url" in \#*|"") continue ;; esac
		FILENAME=$(basename "$url")
		if curl --fail -L --silent --show-error --retry 3 --retry-delay 10 --retry-all-errors -o "${FILENAME}" "${url}"; then
			DOWNLOAD_OK=$((DOWNLOAD_OK + 1))
		else
			echo "GetModule: FAILED to download ${FILENAME} (HTTP error)" >&2
			rm -f "${FILENAME}" 2>/dev/null
			DOWNLOAD_FAIL=$((DOWNLOAD_FAIL + 1))
		fi
	done < "${EFFECTIVE_MODULE_LIST}"

	echo "GetModule: Downloaded ${DOWNLOAD_OK}/${EXPECTED_COUNT} cores successfully, ${DOWNLOAD_FAIL} failed."

	# Threshold check: fail the build if fewer than 80% of expected cores downloaded.
	# This catches network failures, bad pins, and stale buildbot URLs early.
	# Enforce a minimum threshold of 1 so a single-core list always requires at least
	# one successful download (integer division would otherwise give threshold=0).
	if [ "${EXPECTED_COUNT}" -gt 0 ]; then
		THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
		[ "${THRESHOLD}" -lt 1 ] && THRESHOLD=1
		if [ "${DOWNLOAD_OK}" -lt "${THRESHOLD}" ]; then
			echo "GetModule: ERROR — Only ${DOWNLOAD_OK}/${EXPECTED_COUNT} cores downloaded (threshold: ${THRESHOLD})." >&2
			echo "GetModule: ERROR — Check network connectivity and buildbot URL validity." >&2
			echo "GetModule: ERROR — Not saving timestamp; will retry on next build." >&2
			# Do NOT save timestamp so next build retries, then fail the build phase.
			exit 1
		fi
	fi

	echo ${TIMESTAMP} > "${CORES_ARCHIVE_DIR}/timestamp.txt"
	echo "${PINNED_DATE}" > "${CORES_ARCHIVE_DIR}/pinned_date.txt"
fi

# Validate downloaded zips before extracting — purge any that are HTML error pages
# or otherwise not valid zip archives.
VALID_ZIPS=0
INVALID_ZIPS=0
for zipfile in "${CORES_ARCHIVE_DIR}/"*.zip; do
	[ -f "$zipfile" ] || continue
	# Check zip magic bytes (PK\x03\x04 = 50 4b 03 04)
	MAGIC=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
	if [ "$MAGIC" != "504b0304" ]; then
		BASENAME=$(basename "$zipfile")
		echo "GetModule: INVALID zip (not a zip file): ${BASENAME} — removing" >&2
		rm -f "$zipfile"
		INVALID_ZIPS=$((INVALID_ZIPS + 1))
	else
		VALID_ZIPS=$((VALID_ZIPS + 1))
	fi
done

if [ "${INVALID_ZIPS}" -gt 0 ]; then
	echo "GetModule: WARNING — removed ${INVALID_ZIPS} invalid zip files (likely 404 HTML pages)"
fi

# Use -o (overwrite) when the pin or platform just changed so stale dylibs are
# replaced; use -n (never overwrite) otherwise for faster incremental builds.
# When the pin changed, also purge ALL existing dylibs so cores dropped from the
# new snapshot are not left behind (unzip -o only overwrites, never deletes).
# When the platform changed, platform-specific and neutral dylibs were already
# purged above; -o ensures any remaining shared names are overwritten correctly.
if [ "${PIN_CHANGED}" = "1" ]; then
	# Purge all downloaded dylibs but preserve locally-built ones (pattern or sentinel).
	for dylib in "${CORES_DIR}/"*.dylib; do
		[ -f "$dylib" ] || continue
		base=$(basename "$dylib")
		is_local_dylib "$base" && continue
		rm -f "$dylib"
	done
	unset base
	# unzip syntax: archive [files] [-x xfile(s)] [-d exdir] — exclude args go
	# after the archive and before -d.  Empty UNZIP_EXCLUDE_ARGS expands to nothing.
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -o {} "${UNZIP_EXCLUDE_ARGS[@]}" -d "${CORES_DIR}/" ';'
elif [ "${MANIFEST_CHANGED}" = "1" ]; then
	# Regenerated urls*.txt: prune already removed dropped cores; overwrite dylibs
	# from re-downloaded zips (unzip -n would skip same-named updates).
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -o {} "${UNZIP_EXCLUDE_ARGS[@]}" -d "${CORES_DIR}/" ';'
elif [ "${PLATFORM_CHANGED}" = "1" ] || [ -z "${STORED_PLATFORM}" ]; then
	# Platform changed (or first run): stale dylibs purged above; overwrite to be safe.
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -o {} "${UNZIP_EXCLUDE_ARGS[@]}" -d "${CORES_DIR}/" ';'
else
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -n {} "${UNZIP_EXCLUDE_ARGS[@]}" -d "${CORES_DIR}/" ';'
fi

# Sanity-check extracted dylibs: each must be non-trivial in size and a real
# Mach-O object (mirrors the framework validation in make_frameworks_retroarch.sh,
# see 58693478b2). Catches truncated downloads and corrupt extractions that still
# had a valid zip header. Downloaded offenders are removed (and the timestamp
# cleared so the next build re-downloads); locally-built dylibs are never deleted.
# Size floor is overridable for tests (fixtures are tiny stub files).
MIN_DYLIB_SIZE="${GETMODULES_MIN_DYLIB_SIZE:-4096}"
DYLIB_VALIDATION_FAIL=0
DYLIB_VALIDATION_OK=0
for dylib in "${CORES_DIR}/"*.dylib; do
	[ -f "$dylib" ] || continue
	base=$(basename "$dylib")
	DSIZE=$(wc -c < "$dylib" | tr -d ' ')
	FTYPE=$(file -b "$dylib" 2>/dev/null)
	if [ "${DSIZE:-0}" -ge "${MIN_DYLIB_SIZE}" ]; then
		case "$FTYPE" in
			*Mach-O*|*"universal binary"*)
				DYLIB_VALIDATION_OK=$((DYLIB_VALIDATION_OK + 1))
				continue
				;;
		esac
	fi
	if is_local_dylib "$base"; then
		echo "GetModule: WARNING — locally-built ${base} failed validation (size=${DSIZE}, type=${FTYPE:-unknown}) — keeping (never delete local builds)" >&2
	else
		echo "GetModule: INVALID dylib ${base} (size=${DSIZE}, type=${FTYPE:-unknown}) — removing" >&2
		rm -f "$dylib"
		DYLIB_VALIDATION_FAIL=$((DYLIB_VALIDATION_FAIL + 1))
	fi
done
unset base

if [ "${DYLIB_VALIDATION_FAIL}" -gt 0 ]; then
	echo "GetModule: WARNING — removed ${DYLIB_VALIDATION_FAIL} invalid dylib(s) after extraction (${DYLIB_VALIDATION_OK} passed Mach-O validation)" >&2
	# Force re-download next build so the removed cores come back.
	rm -f "${CORES_ARCHIVE_DIR}/timestamp.txt"
fi

# Final validation: count dylibs and warn if suspiciously low
DYLIB_COUNT=$(find "${CORES_DIR}" -maxdepth 1 -name "*.dylib" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "GetModule: ${DYLIB_COUNT} dylibs in modules/ (expected ~${EXPECTED_COUNT})"

if [ "${DYLIB_COUNT}" -eq 0 ] && [ "${EXPECTED_COUNT}" -gt 0 ]; then
	echo "GetModule: ERROR — 0 dylibs after extraction! Cores will not load at runtime." >&2
	echo "GetModule: ERROR — Check modules_compressed/ for valid zip files." >&2
	# Clear timestamp to force re-download on next build, then fail the build phase.
	rm -f "${CORES_ARCHIVE_DIR}/timestamp.txt"
	exit 1
elif [ "${EXPECTED_COUNT}" -gt 0 ] && [ "${DYLIB_COUNT}" -lt $(( EXPECTED_COUNT * 80 / 100 )) ]; then
	echo "GetModule: WARNING — only ${DYLIB_COUNT}/${EXPECTED_COUNT} dylibs present (below 80% threshold). Some cores may be missing." >&2
fi

echo "GetModule: Completed — ${VALID_ZIPS} valid zips, ${DYLIB_COUNT} dylibs (expected ~${EXPECTED_COUNT})"

# Record the active platform so the fast-path check above can skip extraction
# on subsequent same-platform builds without re-purging or re-extracting.
echo "${CURRENT_PLATFORM}" > "${CORES_DIR}/active_platform.txt"

# Save manifest fingerprint after a full run so regen of urls*.txt invalidates cache.
if [ -n "${CURRENT_MANIFEST_SHA}" ]; then
	echo "${CURRENT_MANIFEST_SHA}" > "${MANIFEST_FP_FILE}"
fi
exit 0
