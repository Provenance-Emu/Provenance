set -e

if nc -zw1 github.com 443 > /dev/null; then
  echo "Online"
else
  echo "Not Online"
  exit 0;
fi

if which xcodebuild > /dev/null; then
    echo "Has XCode command line tools"
else
    echo "error: Missing XCode command line tools. Intall with 'xcode-select --install' from terminal then restart XCode."
    osascript -e 'tell app "System Events" to display dialog "Error. Missing XCode command line tools. Intall with xcode-select --install from terminal then restart XCode." buttons {"OK"} with icon caution with title "Missing XCode command line tools"'
    exit 1
fi

function runCarthageAndCopyResolved {
    echo "Running Carthage.."
    if which fastlane > /dev/null; then
      echo "Setting up Carthage for platform $1 using fastlane"
      bundle exec fastlane carthage_bootstrap platform:"$1"
    elif which carthage > /dev/null; then
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
    # Copies the Cartfile.resolved file to /Carthage directory
    cp "$SRCROOT"/Cartfile.resolved "$SRCROOT"/Carthage/.Cartfile.resolved
    echo "Copied Cartfile.resolved to /Carthage directory."
    echo "This will be used to check Carthage dependency updates in the future."
}

command -v carthage >/dev/null 2>&1 || {
    echo "Carthage is required. Please install Carthage and try again. Aborting.";
    exit 1;
}

# Checks if Carthage/Build directory doesn't exist and if not it'll run Carthage
# After, it checks if the Cartfile.resolved file differs from the one in Carthage. If so, Carthage runs
if [ ! -d "$SRCROOT/Carthage/Build" ]; then
    echo "No Carthage/Build directory found."
    runCarthageAndCopyResolved $1
elif [ -f $SRCROOT/Carthage/.Cartfile.resolved ] && \
        diff $SRCROOT/Carthage/.Cartfile.resolved \
        $SRCROOT/Cartfile.resolved >/dev/null ; then
    echo "Cartfile.resolved has not changed. Building project."
else
    echo "Cartfile.resolved not up to date or not found."
    runCarthageAndCopyResolved $1
fi
