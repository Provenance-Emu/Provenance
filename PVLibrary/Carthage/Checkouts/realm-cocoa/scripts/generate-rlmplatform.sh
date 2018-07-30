#!/bin/sh

: ${SRCROOT:?"generate-rlmplatform.sh must be invoked as part of an Xcode script phase"}

SOURCE_FILE="${SRCROOT}/Realm/RLMPlatform.h.in"
DESTINATION_FILE="${TARGET_BUILD_DIR}/${PUBLIC_HEADERS_FOLDER_PATH}/RLMPlatform.h"
TEMPORARY_FILE="${TARGET_TEMP_DIR}/RLMPlatform.h"

if [[ "${PLATFORM_NAME}" == "macosx" ]]; then
  FLAG="-D"
else
  FLAG="-U"
fi

unifdef -B "${FLAG}"REALM_BUILDING_FOR_OS_X < "${SOURCE_FILE}" | sed -e "s/''/'/" > "${TEMPORARY_FILE}"

if ! cmp -s "${TEMPORARY_FILE}" "${DESTINATION_FILE}"; then
  echo "Updating ${DESTINATION_FILE}"
  cp "${TEMPORARY_FILE}" "${DESTINATION_FILE}"
fi
