set -e

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# carhage caching by Joe Mattiello
#
# Inspired from http://shashikantjagtap.net/cache-carthage-speed-ios-continuous-integration/
#
# Additional files at https://gist.github.com/JoeMatt/5e0218cdd27fcc38de0b81900d4c969e
#
# The purpose of this script is to reduce the amount of checkouts Carthage runs.
# I use this script in an XCode 'run script' build phase as the first phase before compiling
# If you have mutliple targets, projects, frameworks etc, you can include this script in each and it will selec
# the correct Carthage folder for each target.
#
# There's also an optional fastlane integration if it's installed.
# For my project we make fastlane optional, this script will choose which ever is availabe.
# An example Fastfile will be included with this gist.
#
# Usage:
#  $ ./carthage.sh platform
# * platform: Cant be a single platform, 'tvOS', or command seperated multiples, 'tvOS,iOS'

# If  not online, we just quit successfully.
# If the user hasn't bootstap'd carthage locally they will most likely get a build error next.
if nc -zw1 github.com 443 > /dev/null; then
  echo "Online"
else
  echo "Not Online"
  exit 0;
fi

# Check for xcodebuild. Alert user if missing
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
      bundle exec fastlane carthage_bootstrap platform:"$1" directory:"$SRCROOT"
      /usr/local/bin/carthage outdated --xcode-warnings
    elif which carthage > /dev/null; then
        echo "Setting up Carthage for platform $1"
        /usr/local/bin/carthage bootstrap --no-use-binaries --cache-builds --platform $1 --project-directory "$SRCROOT"
        /usr/local/bin/carthage outdated --xcode-warnings
        # Example how to enable different command for different build styles.
        # ie; carthage build, will force a rebuild. Might be preferred for safety for ad-hoc and app store builds
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
    local sourceCartfile="$SRCROOT/Cartfile.resolved"
    local destCartfile="$SRCROOT/Carthage/.Cartfile.$1.resolved"
    cp "$sourceCartfile" "$destCartfile"
    echo "Copied $sourceCartfile to $destCartfile"
    echo "This will be used to check Carthage dependency updates in the future."
}

# Carthage is required, check if installed and alert user how to install
command -v carthage >/dev/null 2>&1 || {
  echo "error: Carthage is not installed, download from https://github.com/Carthage/Carthage#installing-carthage"
  osascript -e 'tell app "System Events" to display dialog "Error. Carthage is not installed, download from \nhttps://github.com/Carthage/Carthage#installing-carthage" buttons {"OK"} with icon caution with title "Missing Carthage"'
  exit 1;
}

# Function to iterate comma seperated list of targets and
# check that a Carthage/Build/${Platform} exists.
function carthageBuildPathNotExist {
  echo "carthageBuildPathNotExist $1"
  for i in $(echo $1 | tr "," "\n")
  do
    local path="$SRCROOT/Carthage/Build/$i"
    echo "Testing for $path"
    if [ ! -d $path ]; then
      echo "Fail: No path found for $i"
      return 0
    else
      echo "Success: Path found for $i"
    fi
  done
  echo "Success: Build paths exist for all targets $1"
  return 1
}


# Function to iterate comma seperated list of targets and
# check that a Carthage/.Cartfile.${Platform}.resolved exists.
# and matches the current Carthage.resolved file
function carthageManifestUpToDate {
  echo "carthageManifestUpToDate $1"
  for i in $(echo $1 | tr "," "\n")
  do
    local path="$SRCROOT/Carthage/.Cartfile.$1.resolved"
    echo "Testing for $path"
    if [ -f $path ] && \
            diff $path \
            $SRCROOT/Cartfile.resolved >/dev/null ; then
        echo "$file matches $SRCROOT/Cartfile.resolved."
    else
      echo "Fail: manifest mismatch found for $path AND $SRCROOT/Cartfile.resolved"
      return 1
    fi
  done
  echo "Success: Manifests match for all targets $1"
  return 0
}

# The main execution starts here
if carthageBuildPathNotExist $1; then
    echo "Carthage build required for $1"
    runCarthageAndCopyResolved $1
elif carthageManifestUpToDate $1; then
    echo "Cartfile.resolved has not changed. Will move on to building project."
else
    echo "Cartfile.resolved not up to date or not found."
    runCarthageAndCopyResolved $1
fi
