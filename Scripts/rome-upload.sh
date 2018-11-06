#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

export AWS_ACCESS_KEY_ID="M2B65BPG5JRKHIC8RAKX"
export AWS_SECRET_ACCESS_KEY="R1pwhbv7foHK88VDgq1cZ3jlVi2YS6PFv9ueZi4p"
export AWS_REGION="us-east-1"
export AWS_ENDPOINT="http://provenance.joemattiello.com:9000"

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"

lockfile_waithold "rome-upload"

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: ${SWIFT_VERSION}"

echo "Uploading $PLATFORM ..."

MISSING=`rome list --missing --platform ${PLATFORM} --cache-prefix "{$SWIFT_VERSION}" | awk '{print $1}'`
echo "Missing ${MISSING}"
echo "${MISSING}" | awk '{print $1}' | carthage update --platform $PLATFORM --cache-builds && rome list --missing --platform $PLATFORM --cache-prefix "${SWIFT_VERSION}" | awk '{print $1}' | xargs rome upload --platform $PLATFORM --cache-prefix "${SWIFT_VERSION}"

echo "Done."

lockfile_release "rome-upload"
