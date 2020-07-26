#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"
source "$DIR/rome-env.sh"

if [ -x "$(command -v rome)" ]; then
  echo "Downloading $PLATFORM ..."
  rome download --concurrently --platform $PLATFORM --cache-prefix "$CACHE_PREFIX" --no-skip-current
  rome list --missing --platform $PLATFORM --cache-prefix "$CACHE_PREFIX" | awk '{print $1}' | xargs carthage build --platform $PLATFORM --cache-builds --no-skip-current # list what is missing and update/build if needed
  rome list --missing --platform $PLATFORM --cache-prefix "$CACHE_PREFIX" | awk '{print $1}' | xargs rome upload --concurrently --platform $PLATFORM --cache-prefix "$CACHE_PREFIX" --no-skip-current # upload what is missing
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi
