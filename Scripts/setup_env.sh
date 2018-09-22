get_swift_version() {
    "$1" --version 2>/dev/null | sed -ne 's/^Apple Swift version \([^\b ]*\).*/\1/p'
}

get_xcode_version() {
    "$1" -version 2>/dev/null | sed -ne 's/^Xcode \([^\b ]*\).*/\1/p'
}

rome_installed() {
  [-x "$(command -v rome)"]
}

rome_install() {
  if ! rome_installed; then
    brew install blender/homebrew-tap/rome
  fi
}

brew_installed() {
  [ -x "$(command -v brew)" ]
}

brew_install() {
  if ! brew_installed; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

brew_update() {
  if brew_installed; then
    brew update
    brew outdated swiftlint || brew upgrade swiftlint
    brew outdated carthage || brew upgrade carthage
    # rome_install
  fi
}

bundle_installed() {
   [ -x "$(command -v bundle)" ]
   return
}

bundle_install() {
  if bundle_installed; then
    echo "bundle installed. Running 'bundle install'"
    bundle install
  fi
}

fastlane_installed() {
  [ -x "$(command -v fastlane)" ]
  return
}

fastlane_install() {
  if brew_installed && ! fastlane_installed ; then
    echo 'fastlane is not installed. Installing via homebrew' >&2
    brew cask install fastlane
  fi
}

carthage_installed() {
  [ -x "$(command -v carthage)" ]
  return
}

carthage_install() {
  if ! carthage_installed && brew_installed; then
    brew install carthage
  fi
}