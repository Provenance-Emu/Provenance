#!/bin/bash

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

# Stop multiple scripts from running at same time
lockfile_waithold

if ! brew_installed; then
    brew_install
    if ! brew_installed; then
        error_exit "Homebrew failed to install."
    fi
fi

if ! fastlane_installed; then
    fastlane_install
    if ! fastlane_installed; then
        error_exit "Fastlane failed to install."
    fi
fi

echo "EFFECTIVE_PLATFORM_NAME = $EFFECTIVE_PLATFORM_NAME"

PLATFORM="tvOS,iOS"
if [[ $EFFECTIVE_PLATFORM_NAME == "-iphoneos" || $EFFECTIVE_PLATFORM_NAME == "-iphonesimulator" ]]; then
    PLATFORM="iOS"
else
    PLATFORM="tvOS"
fi

if fastlane_installed && bundle_installed; then
    FASTLANE_CMD="bundle exec fastlane"
elif fastlane_installed; then
    FASTLANE_CMD="fastlane"
fi

if [ "$FASTLANE_CMD" -ne "" ] && [ -x "$(command -v "$FASTLANE_CMD")" ]; then
    echo "Setting up Carthage for platform $PLATFORM using $FASTLANE_CMD"
    $($FASTLANE_CMD carthage_bootstrap platform:"$PLATFORM" directory:"$SRCROOT")
else
    echo "Failed to find a working fastlane command: '${FASTLANE_CMD}'"
    echo "Falling back to cartage.sh script"
    if ! carthage_installed; then
        carthage_install
    fi

    . "$DIR/carthage.sh" "$PLATFORM"
fi

# Release lock
lockfile_release
