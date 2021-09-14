#!/bin/bash

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

function fastlane_uninstall() {
    if fastlane_installed; then
        echo "Found fastlane install. Removing..."
        brew cask uninstall --force fastlane
        echo "Fastlane uninstalled"
    fi
}

function brew_uninstall() {
    if brew_installed; then
        echo "Found homebrew install. Removing..."
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
        echo "homebrew uninstalled"
    fi
}

echo "This will completely remove fastlane and homebrew."
echo "This is really only for dev testing of installation scripts on a clean system."
echo -n "Are you sure? [y/N]: "
read -n 1 -t 20 RES

if [[ $RES == "y" || $RES == "Y" ]]; then
    echo "Uninstalling..."
    fastlane_uninstall
    brew_uninstall
    echo "Done"
else
    echo "Bye!"
fi

exit 0
