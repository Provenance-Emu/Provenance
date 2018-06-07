set -e

if which xcodebuild > /dev/null; then
    echo "Has XCode command line tools"
else
    echo "error: Missing XCode command line tools. Intall with 'xcode-select --install' from terminal then restart XCode."
    osascript -e 'tell app "System Events" to display dialog "Error. Missing XCode command line tools. Intall with xcode-select --install from terminal then restart XCode." buttons {"OK"} with icon caution with title "Missing XCode command line tools"'
    exit 1
fi

if which fastlane >/dev/null; then
  echo "Setting up Carthage for platform $1 using fastlane"
  bundle exec fastlane carthage_bootstrap platform:"$1"
elif which carthage >/dev/null; then
    echo "Setting up Carthage for platform $1"
    /usr/local/bin/carthage bootstrap --no-use-binaries --cache-builds --platform $1 --project-directory "$SRCROOT"
    /usr/local/bin/carthage outdated --xcode-warnings
    # if [ "${BUILD_STYLE}" == "Ad Hoc Distribution" ] || [ "${BUILD_STYLE}" == "App Store" ];
    # then
    #   /usr/local/bin/carthage build --verbose --no-use-binaries --cache-builds --platform $1 --project-directory "$SRCROOT"
    # fi
else
    echo "error: Carthage is not installed, download from https://github.com/Carthage/Carthage#installing-carthage"
    osascript -e 'tell app "System Events" to display dialog "Error. Carthage is not installed, download from \nhttps://github.com/Carthage/Carthage#installing-carthage" buttons {"OK"} with icon caution with title "Missing Carthage"'
    exit 1
fi
