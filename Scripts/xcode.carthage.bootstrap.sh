#!/bin/bash

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

# Check for and optionally install build tools
function prebuild() {
    # Stop multiple scripts from installing shit at the same time
    lockfile_waithold

    if ! brew_installed; then
        brew_install
        if ! brew_installed; then
            error_exit "Homebrew failed to install."
        fi
    fi

    if ! carthage_installed; then
        carthage_install
        if ! carthage_installed; then
            error_exit "Carthage failed to install."
        fi
    fi

    if ! fastlane_installed; then
        fastlane_install
        if ! fastlane_installed; then
            error_exit "Fastlane failed to install."
        fi
    fi

    # Release lock
    lockfile_release
}

prebuild

PLATFORM=${1:-iOS,tvOS}
SOURCEPATH=${2:-$SRCROOT}

echo "Boot strapping Carthage for the following setup: "
echo "PLATFORM: $PLATFORM"
echo "PATH: $SOURCEPATH"

if fastlane_installed && bundle_installed; then
    FASTLANE_CMD="bundle exec fastlane"
elif fastlane_installed; then
    FASTLANE_CMD="fastlane"
fi

if [ "$FASTLANE_CMD" != "" ]; then
    bundle_install_cmd
    brew_update
    echo "Setting up Carthage for platform $PLATFORM using '$FASTLANE_CMD'"
    BOOTSTRAP_CMD="$FASTLANE_CMD carthage_bootstrap platform:$PLATFORM directory:\"$SOURCEPATH\""
    eval_command $BOOTSTRAP_CMD
else
    echo "Failed to find a working fastlane command: '${FASTLANE_CMD}'"
    echo "Falling back to cartage.sh script"
    if ! carthage_installed; then
        carthage_install
    fi

    . "$DIR/carthage.sh" $PLATFORM "$SOURCEPATH"
fi
