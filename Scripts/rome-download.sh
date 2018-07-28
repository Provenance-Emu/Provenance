#!/bin/bash
PLATFORM=${1:-iOS,tvOS}

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: $SWIFT_VERSION"

if which rome > /dev/null; then
  echo "Downloading $PLATFORM ..."
  carthage update --no-build --platform $PLATFORM && rome download --platform $PLATFORM --cache-prefix $SWIFT_VERSION
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi
