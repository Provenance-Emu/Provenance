#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"
source "$DIR/rome-env.sh"

lockfile_waithold "rome-download"

if [ -x "$(command -v rome)" ]; then
  echo "Downloading ${PLATFORM} ..."
  carthage bootstrap --no-build --use-submodules --platform ${PLATFORM} && rome download --concurrently --platform ${PLATFORM} --cache-prefix "${CACHE_PREFIX}"
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi

lockfile_release "rome-download"
