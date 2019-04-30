#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"
source "$DIR/rome-env.sh"

if [ -x "$(command -v rome)" ]; then
  echo "Checking ${PLATFORM} ..."
  rome list --missing --platform ${PLATFORM} --cache-prefix "${CACHE_PREFIX}"
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi
