#!/usr/bin/env bash

PLATFORM=${1:-iOS}

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: $SWIFT_VERSION"

romeDownload() {
  if which fastlane > /dev/null; then
    echo "Downloading $PLATFORM for path $1 ..."
    pushd $1
    rome download --concurrently --platform $PLATFORM --cache-prefix $SWIFT_VERSION
    rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs carthage update --platform $PLATFORM --cache-builds --no-use-binaries # list what is missing and update/build if needed
    rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs rome upload --concurrently --platform $PLATFORM --cache-prefix $SWIFT_VERSION # upload what is missing
    popd
    echo "Done with platform: $PLATFORM path: $1"
  else
    echo "Rome not installed. Skipping cached frameworks."
    echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
  fi
}

romeDownload "PMSInterface"
romeDownload "PMS-UI"
