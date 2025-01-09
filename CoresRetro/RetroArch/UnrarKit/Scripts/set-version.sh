#!/bin/bash

# Usage: set-version.sh <version-number>
#
# Updates the main plist file, then tags the build in Git, using the release notes from CHANGELOG.md

# Colors
COLOR_OFF='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD_YELLOW='\033[1;33m'

# Did this script change since the last commit?
THIS_FILE_REGEX='.*Scripts/set-version\.sh.*'
THIS_FILE_CHANGED=$(git status --porcelain --untracked-files=no | grep $THIS_FILE_REGEX | wc -l)

# Only continue if the repo has no changes (excluding this script)
CHANGED_FILE_COUNT=$(git status --porcelain --untracked-files=no | grep -v $THIS_FILE_REGEX | wc -l)
if [ $CHANGED_FILE_COUNT -gt 0 ]; then
    echo -e "${RED}Please commit or discard any changes before continuing$COLOR_OFF"
    exit 1
fi

# Require a single argument to be passed in
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Please pass the desired version number as an argument$COLOR_OFF"
    exit 1
fi

./Scripts/get-release-notes.py $1 --beta-notes-check

# Check whether beta notes have been updated. The check passes for first- or non-beta releases
if [ ! $? -eq 0 ]; then
    exit 1
fi

RELEASE_NOTES=$(./Scripts/get-release-notes.py $1)
if [ -z "$RELEASE_NOTES" ]; then
    echo -e "${RED}Please add release notes for v$1 into CHANGELOG.md$COLOR_OFF"
    exit 1
fi

# Require agvtool for updating the plist versions. Exit if not installed
if ! [ -x "$(command -v agvtool)" ]; then
    echo -e "${RED}agvtool not found. Are you running on a Mac?$COLOR_OFF"
    exit 2
fi

echo -e "${GREEN}Updating version numbers in plist to '$1'..$COLOR_OFF"
agvtool new-version -all "$1" # CFBundleVersion
agvtool new-marketing-version "$1" # CFBundleShortVersionString

if [ "$THIS_FILE_CHANGED" -gt 0 ]; then
    echo -e "${BOLD_YELLOW}Not committing to Git, as this script isn't final. Commit it to continue$COLOR_OFF"
    exit 2
fi

echo -e "${GREEN}Committing updated plist...$COLOR_OFF"
git commit -m "Updated plist to v$1" Resources

# Revert changes to other plist files
git checkout .

echo -e "${GREEN}Tagging build...$COLOR_OFF"
git tag $1 -m "$RELEASE_NOTES"