#!/bin/bash
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

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
if github_connection_test; then
  echo "Online"
else
  success_exit "Not Online. Skipping Carthage script."
fi

PLATFORM=${1:-iOS,tvOS}
SOURCEPATH=${2:-$SRCROOT}

# Depencey checking, lock to prevent multiple parralle installs
{
  lockfile_waithold

  # Check for xcodebuild. Alert user if missing
  if [ -x "$(command -v xcodebuild)" ]; then
      echo "Has XCode command line tools"
  else
    echo "No XCode command line tools found. Prompting to install"
    ui_prompt "Apple's Xcode command line tools are not installed. This is necessary to build Provenance. Would you like to have them installed now?" "Missing Xcode CLI Tools" "Install"
    
    if [ "$?" = "0" ]; then
      install_xcode_cli_tools
      echo "XCode CLI tools Installed. Waiting for cleanup..."
      sleep 5
      echo "Continuing..."
    else
      error_exit "Missing XCode command line tools. Intall with 'xcode-select --install' from terminal then restart XCode."
    fi
  fi

  # Carthage is required, check if installed and alert user how to install
  if ! carthage_installed; then
    carthage_install
    if [ "$?" = "0" ]; then
        error_exit "Please download and manually install from https://github.com/Carthage/Carthage#installing-carthage" "Carthage install failed."
    fi
  fi

  # Release lock
  lockfile_release
}

function runCarthageAndCopyResolved {
    echo "Running Carthage bootstrap process..."
    
    if fastlane_installed; then

      local FASTLANE_CMD="fastlane"
      if fastlane_installed && bundle_installed; then
        FASTLANE_CMD="bundle exec fastlane"
      fi

      echo "Setting up Carthage for platform $1 using fastlane"

      local FASTLANE_BOOTSTRAP_CMD=$($FASTLANE_CMD carthage_bootstrap platform:$1 directory:"$SOURCEPATH")
      eval_cmd $FASTLANE_BOOTSTRAP_CMD
    elif carthage_installed; then
        echo "Setting up Carthage for platform $1"
        carthage bootstrap --no-use-binaries --cache-builds --platform $1 --project-directory "$SOURCEPATH"
        carthage outdated --xcode-warnings
        # Example how to enable different command for different build styles.
        # ie; carthage build, will force a rebuild. Might be preferred for safety for ad-hoc and app store builds
        # if [ "${BUILD_STYLE}" == "Ad Hoc Distribution" ] || [ "${BUILD_STYLE}" == "App Store" ];
        # then
        #   /usr/local/bin/carthage build --verbose --no-use-binaries --cache-builds --platform $1 --project-directory "$SOURCEPATH"
        # fi
    else
      error_exit "Carthage is not installed, download from https://github.com/Carthage/Carthage#installing-carthage"
    fi

    # Prints warnings about outdated packages
    carthage outdated --xcode-warnings

    # Copies the Cartfile.resolved file to /Carthage directory
    local sourceCartfile="$SOURCEPATH/Cartfile.resolved"
    local destCartfile="$SOURCEPATH/Carthage/.Cartfile.$1.resolved"
    echo "Copying $sourceCartfile to $destCartfile"
    cp "$sourceCartfile" "$destCartfile"

    # Store swift version used to build
    local SWIFT_VERSION_PATH="$SOURCEPATH/Carthage/.swift-version"
    local swiftVersion=$(get_swift_version "$(xcrun -f swift)")
    echo "Storing current swift version $swiftVersion to $SWIFT_VERSION_PATH"
    echo "$swiftVersion" > "$SWIFT_VERSION_PATH"

    echo "This will be used to check Carthage dependency updates in the future."
}

# Function to iterate comma seperated list of targets and
# check that a Carthage/Build/${Platform} exists.
function carthageBuildPathNotExist {
  echo "carthageBuildPathNotExist $1"
  for i in $(echo $1 | tr "," "\n")
  do
    local path="$SOURCEPATH/Carthage/Build/$i"
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
    local CARTFILE_CACHED_PATH="$SOURCEPATH/Carthage/.Cartfile.$1.resolved"
    local RESOLVED_MATCHED
    [ -f $CARTFILE_CACHED_PATH ] && diff $CARTFILE_CACHED_PATH $SOURCEPATH/Cartfile.resolved >/dev/null && RESOLVED_MATCHED=true || RESOLVED_MATCHED=false

    if [[ $RESOLVED_MATCHED == true ]]; then
      echo "Carthage cache versions matched"
    else
      echo "Carthage cache versions mis-matched"
    fi

    local SWIFT_VERSION_PATH="$SOURCEPATH/Carthage/.swift-version"
    local SWIFT_VERSION_BUILT=`cat $SWIFT_VERSION_PATH 2>/dev/null`
    local SWIFT_VERSION_CURRENT=$(get_swift_version "$(xcrun -f swift)")
    local SWIFT_MATCH
    [ -f $SWIFT_VERSION_PATH ] && [ $SWIFT_VERSION_CURRENT == $SWIFT_VERSION_BUILT ] && SWIFT_MATCH=true || SWIFT_MATCH=false
    if [[ $SWIFT_MATCH == true ]]; then
      echo "Swift version matched: $SWIFT_VERSION_CURRENT"
    else
      echo "Swift version mis-matched: $SWIFT_VERSION_CURRENT != $SWIFT_VERSION_BUILT"
    fi

    echo "Cartfile.resolved match: $RESOLVED_MATCHED Swift version match: $SWIFT_MATCH. Current: $SWIFT_VERSION_CURRENT Cached: $SWIFT_VERSION_BUILT"
    if [[ $RESOLVED_MATCHED == true && $SWIFT_MATCH == true ]]; then
        echo "$file matches $SOURCEPATH/Cartfile.resolved & $SWIFT_VERSION_PATH matches $SWIFT_VERSION_CURRENT"
    else
      echo "Fail: manifest mismatch found for $CARTFILE_CACHED_PATH AND $SOURCEPATH/Cartfile.resolved"
      return 1
    fi
  done
  echo "Success: Manifests match for all targets $1"
  return 0
}

# The main execution starts here
if carthageBuildPathNotExist $PLATFORM; then
    echo "Carthage build required for $PLATFORM"
    echo "Making sure gem and brew are up to date"
   
    bundle_install_cmd
    brew_update
    
    runCarthageAndCopyResolved "$PLATFORM"
elif carthageManifestUpToDate $PLATFORM; then
    echo "Cartfile.resolved has not changed. Will move on to building project."
else
    echo "Cartfile.resolved not up to date or not found."
    
    bundle_install_cmd
    brew_update
    
    runCarthageAndCopyResolved "$PLATFORM"
fi
