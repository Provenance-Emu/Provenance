#!/usr/bin/env bash

PLATFORM=${1:-iOS,tvOS}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source "$DIR/setup_env.sh"
source "$DIR/rome-env.sh"

romeDownload() {
  if which fastlane > /dev/null; then
    echo "Downloading $PLATFORM for path $1 ..."
    pushd $1
    rome download --concurrently --platform $PLATFORM --cache-prefix $CACHE_PREFIX
    rome list --missing --platform $PLATFORM --cache-prefix $CACHE_PREFIX | awk '{print $1}' | xargs carthage update --platform $PLATFORM --cache-builds --no-use-binaries # list what is missing and update/build if needed
    rome list --missing --platform $PLATFORM --cache-prefix $CACHE_PREFIX | awk '{print $1}' | xargs rome upload --concurrently --platform $PLATFORM --cache-prefix $CACHE_PREFIX # upload what is missing
    popd
    echo "Done with platform: $PLATFORM path: $1"
  else
    echo "Rome not installed. Skipping cached frameworks."
    echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
  fi
}

romeDownload "./"
