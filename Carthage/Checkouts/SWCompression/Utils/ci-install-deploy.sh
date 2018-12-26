#!/bin/bash

set -euxo pipefail

brew outdated carthage || brew upgrade carthage
brew install sourcekitten
gem install -N jazzy
gem update -N cocoapods
