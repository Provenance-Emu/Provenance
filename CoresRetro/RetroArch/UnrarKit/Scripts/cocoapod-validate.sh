#!/bin/bash

set -ev
set -o pipefail

git fetch --tags

if [ -z "$TRAVIS_TAG" ]; then
    TRAVIS_TAG_SUBSTITUTED=1
    export TRAVIS_TAG="$(git tag -l | tail -1)"
    echo "Not a tagged build. Using last tag ($TRAVIS_TAG) for pod lib lint..."
fi

# For linting purposes, fix the error in dll.hpp
sed -i .original 's/RARGetDllVersion();/RARGetDllVersion(void);/' Libraries/unrar/dll.hpp

# Lint the podspec to check for errors. Don't call `pod spec lint`, because we want it to evaluate locally

# Using sed to remove logging from output until CocoaPods issue #7577 is implemented and I can use the
# OS_ACTIVITY_MODE = disable environment variable from the test spec scheme
pod lib lint --verbose | sed -l '/xctest\[/d; /^$/d'

# Put back the original dll.hpp
mv Libraries/unrar/dll.hpp.original Libraries/unrar/dll.hpp

if [ -n "$TRAVIS_TAG_SUBSTITUTED" ]; then
    echo "Unsetting TRAVIS_TAG..."
    unset TRAVIS_TAG
fi
