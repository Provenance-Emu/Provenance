#!/bin/sh
LAST_TIMESTAMP=0
INTERVAL=3600*168
CORES_DIR="${SRCROOT}/CoresRetro/RetroArch/modules"
cd "${SRCROOT}/CoresRetro/RetroArch/scripts"
if [ "$1" = "tvos" ]; then
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/tvOS"
	MODULE_LIST="${SRCROOT}/CoresRetro/RetroArch/scripts/urls-tv.txt"
	rm "${CORES_DIR}/"*ios*.dylib
else
	CORES_ARCHIVE_DIR="${SRCROOT}/CoresRetro/RetroArch/modules_compressed/iOS"
	MODULE_LIST="${SRCROOT}/CoresRetro/RetroArch/scripts/urls.txt"
	rm "${CORES_DIR}/"*tvos*.dylib
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
	echo "GetModule: ${TIMESTAMP} > ${LAST_TIMESTAMP} Starting Download..."
	rm "${CORES_ARCHIVE_DIR}/"*.zip
	cd "${CORES_ARCHIVE_DIR}"
	echo $(xargs -n 1 curl -O < "${MODULE_LIST}")
	echo ${TIMESTAMP} > "${CORES_ARCHIVE_DIR}/timestamp.txt"
fi
echo $(find "${CORES_ARCHIVE_DIR}" -name "*.zip" -exec unzip -n {} -d "${CORES_DIR}/" ';')
echo "GetModule: Successfully Completed"
exit 0
