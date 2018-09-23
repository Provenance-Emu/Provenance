#!/bin/bash
set -e
set -o pipefail

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

vpath="$SRCROOT/.version"
GIT_DATE=`git log -1 --format="%cd" --date="local"`

if [[ -f "$vpath" ]] && [[ "$(< $vpath)" == "$GIT_DATE" ]]; then
    success_exit "$vpath matches $GIT_DATE"
fi

buildNumber="$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")"
buildNumber=`git rev-list --count HEAD`

GIT_TAG=`git describe --tags --always --dirty`
GIT_DATE=`git log -1 --format="%cd" --date="local"`
GIT_BRANCH=`git branch | grep \* | cut -d ' ' -f2-`

PLISTBUDDY="/usr/libexec/PlistBuddy"

plist_buddy_installed() {
  [-x "$(command -v "$PLISTBUDDY")"]
}

if ! plist_buddy_installed; then
    error_exit "System binary PlistBuddy is missing."
fi

# Use the built products dir so GIT doesn't want to constantly upload a changed Info.plist in the code directory - jm
$PLISTBUDDY -c "Set :CFBundleVersion $buildNumber" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

$PLISTBUDDY -c "Set :GitBranch $GIT_BRANCH" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
$PLISTBUDDY -c "Set :GitDate $GIT_DATE" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
$PLISTBUDDY -c "Set :GitTag $GIT_TAG" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

# Set Git SHA
revision=$(git rev-parse --short HEAD)

#$PLISTBUDDY -c "Set :Revision $revision" "${PROJECT_DIR}/${INFOPLIST_FILE}"
# Use the built products dir so GIT doesn't want to constantly upload a changed Info.plist in the code directory - jm
$PLISTBUDDY-c "Set :Revision $revision" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

echo "Updated app plist with git data."
echo "TAG: ${GIT_TAG}, DATE: ${GIT_DATE}, BRANCH: ${GIT_BRANCH}, REVISION: $revision"

# Store the date for next run
echo "$GIT_DATE" > "$vpath"
