#!/bin/bash

set -euxo pipefail

(set +x; echo "=> Removing bcsymbolmap files for dependencies.")
rm -f Carthage/Build/Mac/*.bcsymbolmap
rm -f Carthage/Build/watchOS/*.bcsymbolmap
rm -f Carthage/Build/tvOS/*.bcsymbolmap
rm -f Carthage/Build/iOS/*.bcsymbolmap
(set +x; echo "=> Removing checkouts for dependencies.")
rm -rf Carthage/Checkouts
(set +x; echo "=> Preparing deployment files.")
carthage build --no-skip-current
carthage archive SWCompression
swift build
sourcekitten doc --spm-module SWCompression > docs.json
jazzy
