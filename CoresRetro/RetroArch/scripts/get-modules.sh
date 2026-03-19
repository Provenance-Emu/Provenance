#!/bin/bash
# NOTE: Xcode build phases invoke scripts via /bin/sh, which ignores the shebang.
# This guard re-execs with bash so bash-specific syntax ((( )), arrays, etc.) works
# even when the build phase calls: /bin/sh ".../get-modules.sh"
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

LAST_TIMESTAMP=0
INTERVAL=3600*168
CORES_DIR="${SRCROOT}/CoresRetro/RetroArch/modules"
SCRIPTS_DIR="${SRCROOT}/CoresRetro/RetroArch/scripts"

# Add parameter check
URL_SUFFIX=""
if [ "$1" = "-appstore" ]; then
    URL_SUFFIX="-appstore"
fi

cd "${SCRIPTS_DIR}"
if [ "${PLATFORM_NAME}" = "appletvos" ]; then
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/tvOS"
	MODULE_LIST="${SCRIPTS_DIR}/urls${URL_SUFFIX}-tv.txt"
	rm -f "${CORES_DIR}/"*ios*.dylib 2>/dev/null
else
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/iOS"
	MODULE_LIST="${SCRIPTS_DIR}/urls${URL_SUFFIX}.txt"
	rm -f "${CORES_DIR}/"*tvos*.dylib 2>/dev/null
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
		HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --head "${TEST_URL}" 2>/dev/null)
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

if (( TIMESTAMP > LAST_TIMESTAMP )); then
	echo "GetModule: ${TIMESTAMP} > ${LAST_TIMESTAMP} Starting Download... ${EFFECTIVE_MODULE_LIST}"
	rm -f "${CORES_ARCHIVE_DIR}/"*.zip
	cd "${CORES_ARCHIVE_DIR}"

	# Download with --fail so curl returns non-zero on HTTP errors (404, 500, etc.)
	# instead of saving error HTML as if it were a valid zip.
	DOWNLOAD_FAIL=0
	DOWNLOAD_OK=0
	while IFS= read -r url; do
		# Skip comments and blank lines
		case "$url" in \#*|"") continue ;; esac
		FILENAME=$(basename "$url")
		if curl --fail --silent --show-error -o "${FILENAME}" "${url}"; then
			DOWNLOAD_OK=$((DOWNLOAD_OK + 1))
		else
			echo "GetModule: FAILED to download ${FILENAME} (HTTP error)" >&2
			rm -f "${FILENAME}" 2>/dev/null
			DOWNLOAD_FAIL=$((DOWNLOAD_FAIL + 1))
		fi
	done < "${EFFECTIVE_MODULE_LIST}"

	echo "GetModule: Downloaded ${DOWNLOAD_OK}/${EXPECTED_COUNT} cores (${DOWNLOAD_FAIL} failed)"

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

# Use -o (overwrite) when the pin just changed so stale dylibs are replaced;
# use -n (never overwrite) otherwise for faster incremental builds.
# When the pin changed, also purge existing dylibs so cores dropped from the
# new snapshot are not left behind (unzip -o only overwrites, never deletes).
if [ "${PIN_CHANGED}" = "1" ]; then
	rm -f "${CORES_DIR}/"*.dylib
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -o {} -d "${CORES_DIR}/" ';'
else
	find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -n {} -d "${CORES_DIR}/" ';'
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

echo "GetModule: Completed (${VALID_ZIPS} valid zips, ${DYLIB_COUNT} dylibs)"
exit 0
