#!/bin/sh
PLATFORM=${1:-iOS,tvOS}

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: $SWIFT_VERSION"

echo "Uploading $PLATFORM ..."
carthage update --platform $PLATFORM --cache-builds --no-use-binaries && rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION
cd PVSupport
carthage update --platform $PLATFORM --cache-builds --no-use-binaries && carthage update && rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION
cd ../PVLibrary
carthage update --platform $PLATFORM --cache-builds --no-use-binaries && carthage update && rome upload --platform $PLATFORM --cache-prefix $SWIFT_VERSION
echo "Done."
