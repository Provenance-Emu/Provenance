#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"
source "$DIR/rome-env.sh"

lockfile_waithold "rome-upload"

echo "Uploading $PLATFORM ..."

MISSING=`rome list --missing --platform ${PLATFORM} --cache-prefix "${CACHE_PREFIX}" | awk '{print $1}'`
echo "Missing ${MISSING}"
#echo "${MISSING}" | awk '{print $1}' | carthage update --platform $PLATFORM --cache-builds && rome list --missing --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}" | awk '{print $1}' | xargs rome upload --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}"
#echo "${MISSING}" | awk '{print $1}' | carthage build --platform $PLATFORM --no-skip-current --cache-builds && rome list --missing --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}" --no-skip-current | awk '{print $1}' | xargs rome upload --concurrently --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}" --no-skip-current
echo "${MISSING}" | awk '{print $1}' | carthage build --platform $PLATFORM --cache-builds && rome list --missing --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}" | awk '{print $1}' | xargs rome upload --concurrently --platform $PLATFORM --cache-prefix "${CACHE_PREFIX}"

echo "Done."

lockfile_release "rome-upload"
