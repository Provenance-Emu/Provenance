#!/bin/sh
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
	rm "${CORES_DIR}/"*ios*.dylib
else
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/iOS"
	MODULE_LIST="${SCRIPTS_DIR}/urls${URL_SUFFIX}.txt"
	rm "${CORES_DIR}/"*tvos*.dylib
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
	mkdir "${CORES_ARCHIVE_DIR}"
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
	echo "GetModule: pin changed (${STORED_PIN:-none} -> ${PINNED_DATE:-latest}), clearing cached archives and dylibs"
	PIN_CHANGED=1
	rm -f "${CORES_ARCHIVE_DIR}/timestamp.txt"
fi

if [ -f "${CORES_ARCHIVE_DIR}/timestamp.txt" ] ; then
	LAST_TIMESTAMP=$(cat "${CORES_ARCHIVE_DIR}/timestamp.txt")
fi
TIMESTAMP=$(date +%s)
LAST_TIMESTAMP=$(( LAST_TIMESTAMP + INTERVAL  ))
echo "GetModule: ${TIMESTAMP} ${LAST_TIMESTAMP}"
if (( TIMESTAMP > LAST_TIMESTAMP )); then
	echo "GetModule: ${TIMESTAMP} > ${LAST_TIMESTAMP} Starting Download... ${EFFECTIVE_MODULE_LIST}"
	rm -f "${CORES_ARCHIVE_DIR}/"*.zip
	cd "${CORES_ARCHIVE_DIR}"
	echo $(xargs -n 1 curl -O < "${EFFECTIVE_MODULE_LIST}")
	echo ${TIMESTAMP} > "${CORES_ARCHIVE_DIR}/timestamp.txt"
	echo "${PINNED_DATE}" > "${CORES_ARCHIVE_DIR}/pinned_date.txt"
fi
# Use -o (overwrite) when the pin just changed so stale dylibs are replaced;
# use -n (never overwrite) otherwise for faster incremental builds.
# When the pin changed, also purge existing dylibs so cores dropped from the
# new snapshot are not left behind (unzip -o only overwrites, never deletes).
if [ "${PIN_CHANGED}" = "1" ]; then
	rm -f "${CORES_DIR}/"*.dylib
	echo $(find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -o {} -d "${CORES_DIR}/" ';')
else
	echo $(find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -n {} -d "${CORES_DIR}/" ';')
fi
echo "GetModule: Successfully Completed"
exit 0
