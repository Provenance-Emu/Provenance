#!/bin/bash
set -eo pipefail
export RELEASE_VERSION="$(git describe --abbrev=0 | tr -d '\n')"
RELEASE_VERSION=${RELEASE_VERSION:1}
pod lib lint --allow-warnings
pod trunk push --allow-warnings