#!/bin/bash
set -o pipefail

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

ROOT=${1:-$SRCROOT}

vpath="${ROOT}/.version"
GIT_DATE=`git log -1 --format="%cd" --date="local"`

if [[ -f "$vpath" ]] && [[ "$(< $vpath)" == "$GIT_DATE" ]]; then
    success_exit "$vpath matches $GIT_DATE"
fi

plistPath="${BUILT_PRODUCTS_DIR}/${INFOPLIST_FILE}"
#buildNumber="$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${plistPath})"
buildNumber=`git rev-list --count HEAD`

GIT_TAG=`git describe --tags --always --dirty`
GIT_DATE=`git log -1 --format="%cd" --date="local"`
#GIT_BRANCH=`git branch | grep \* | cut -d ' ' -f2-`
GIT_BRANCH=`git name-rev --name-only HEAD`

PLISTBUDDY="/usr/libexec/PlistBuddy"
PLUTIL="/usr/bin/PlistBuddy"

# plist_buddy_installed() {
#   [-x "$(command -v "$PLISTBUDDY")"]
# }
# plist_buddy_installed() {
#   [-x "$(command -v "$PLISTBUDDY")"]
# }

# if ! plist_buddy_installed; then
#     error_exit "System binary PlistBuddy is missing."
# fi

# Use the built products dir so GIT doesn't want to constantly upload a changed Info.plist in the code directory - jm
$PLISTBUDDY -c "Set :CFBundleVersion $buildNumber" "${plistPath}"

$PLISTBUDDY -c "Set :GitBranch $GIT_BRANCH" "${plistPath}"
$PLISTBUDDY -c "Set :GitDate $GIT_DATE" "${plistPath}"
$PLISTBUDDY -c "Set :GitTag $GIT_TAG" "${plistPath}"

# Set Git SHA
revision=$(git rev-parse --short HEAD)

#$PLISTBUDDY -c "Set :Revision $revision" "${PROJECT_DIR}/${INFOPLIST_FILE}"
# Use the built products dir so GIT doesn't want to constantly upload a changed Info.plist in the code directory - jm
$PLISTBUDDY -c "Set :Revision $revision" "${plistPath}"

$PLUTIL -replace "ICLOUD_CONTAINER_IDENTIFIER" -string "DICK" "${plistPath}"

echo "Updated app plist with git data."
echo "TAG: ${GIT_TAG}, DATE: ${GIT_DATE}, BRANCH: ${GIT_BRANCH}, REVISION: $revision"
echo "Plist path: ${plistPath}"

# Store the date for next run
echo "Storing $GIT_DATE to ${vpath}"
echo "$GIT_DATE" > "${vpath}"

success_exit "Finished setting build number"
