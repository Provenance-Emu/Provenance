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
PINNED_DATE=""
CORES_YML="${SCRIPTS_DIR}/cores.yml"
if [ -f "${CORES_YML}" ]; then
	PINNED_DATE=$(grep -E '^\s*pinned_date:' "${CORES_YML}" | sed 's/.*pinned_date:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d '[:space:]')
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
if [ -f "${CORES_ARCHIVE_DIR}/timestamp.txt" ] ; then
	LAST_TIMESTAMP=$(cat "${CORES_ARCHIVE_DIR}/timestamp.txt")
fi
TIMESTAMP=$(date +%s)
LAST_TIMESTAMP=$(( LAST_TIMESTAMP + INTERVAL  ))
echo "GetModule: ${TIMESTAMP} ${LAST_TIMESTAMP}"
if (( TIMESTAMP > LAST_TIMESTAMP )); then
	echo "GetModule: ${TIMESTAMP} > ${LAST_TIMESTAMP} Starting Download... ${EFFECTIVE_MODULE_LIST}"
	rm "${CORES_ARCHIVE_DIR}/"*.zip
	cd "${CORES_ARCHIVE_DIR}"
	echo $(xargs -n 1 curl -O < "${EFFECTIVE_MODULE_LIST}")
	echo ${TIMESTAMP} > "${CORES_ARCHIVE_DIR}/timestamp.txt"
fi
echo $(find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -n {} -d "${CORES_DIR}/" ';')
echo "GetModule: Successfully Completed"
exit 0
