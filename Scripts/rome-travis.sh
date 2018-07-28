#!/bin/sh
PLATFORM=${1:-iOS,tvOS}

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: $SWIFT_VERSION"

if which rome > /dev/null; then
  echo "Downloading $PLATFORM ..."
  rome download --platform $PLATFORM --cache-prefix $SWIFT_VERSION
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs carthage update --platform $PLATFORM --cache-builds --no-use-binaries # list what is missing and update/build if needed
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION # upload what is missing
  cd PVSupport
  rome download --platform $PLATFORM --cache-prefix $SWIFT_VERSION
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs carthage update --platform $PLATFORM --cache-builds --no-use-binaries # list what is missing and update/build if needed
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION # upload what is missing
  cd ../PVLibrary
  rome download --platform $PLATFORM --cache-prefix $SWIFT_VERSION
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs carthage update --platform $PLATFORM --cache-builds --no-use-binaries # list what is missing and update/build if needed
  rome list --missing --platform $PLATFORM --cache-prefix $SWIFT_VERSION | awk '{print $1}' | xargs rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION # upload what is missing
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi
