#!/bin/bash

carthage --version

REPO="github \"$TRAVIS_REPO_SLUG\""
COMMIT=$TRAVIS_COMMIT

if [ -z ${TRAVIS+x} ]; then
    REPO="git \"`pwd`\""
    COMMIT=`git log -1 --oneline | cut -f1 -d' '`
    echo "Not running in Travis. Setting REPO ($REPO) and COMMIT ($COMMIT)"
fi

if [ -n "$TRAVIS" ] && [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    REPO="github \"$TRAVIS_PULL_REQUEST_SLUG\""
    COMMIT=$TRAVIS_PULL_REQUEST_SHA
    echo "Build is for a Pull Request. Overriding REPO ($REPO) and COMMIT ($COMMIT)"
fi

if [ ! -d "CarthageValidation" ]; then
    mkdir "CarthageValidation"
fi

echo "Validating commit '$COMMIT'"

pushd CarthageValidation > /dev/null

rm Cartfile
rm Cartfile.resolved
rm -rf Carthage

echo "$REPO \"$COMMIT\"" > Cartfile


carthage bootstrap --use-xcframeworks --configuration Debug --verbose
EXIT_CODE=$?

echo "Checking for build products..."

if [ ! -d "Carthage/Build/UnrarKit.xcframework/macos-arm64_x86_64" ]; then
    echo "No Mac library built"
    EXIT_CODE=1
fi

if [ ! -d "Carthage/Build/UnrarKit.xcframework/ios-arm64" ]; then
    echo "No iOS library built"
    EXIT_CODE=1
fi

popd > /dev/null

exit $EXIT_CODE