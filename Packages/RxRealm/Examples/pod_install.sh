#!/bin/bash

set -eo pipefail
export RELEASE_VERSION="$(git describe --abbrev=0 | tr -d '\n')"
RELEASE_VERSION=${RELEASE_VERSION:1}
xcodegen
pod install --repo-update
open RxRealmDemo.xcworkspace