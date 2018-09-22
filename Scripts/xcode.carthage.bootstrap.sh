#!/bin/bash
if [ -f ~/.bash_profile ]; then
    source ~/.bash_profile 2> /dev/null
elif [ -f ~/.bashrc ]; then
    source ~/.bashrc 2> /dev/null
fi

. Scripts/setup_env.sh
brew_install
fastlane_install

echo "EFFECTIVE_PLATFORM_NAME = $EFFECTIVE_PLATFORM_NAME"

PLATFORM="tvOS,iOS"
if [[ $EFFECTIVE_PLATFORM_NAME == "-iphoneos" || $EFFECTIVE_PLATFORM_NAME == "-iphonesimulator" ]]; then
    PLATFORM="iOS"
else
    PLATFORM="tvOS"
fi

FASTLANE_CMD="fastlane"
if fastlane_installed && bundle_installed; then
    FASTLANE_CMD="bundle exec fastlane"
fi

echo "Setting up Carthage for platform $PLATFORM using $FASTLANE_CMD"
$FASTLANE_CMD carthage_bootstrap platform:"$PLATFORM" directory:"$SRCROOT"
