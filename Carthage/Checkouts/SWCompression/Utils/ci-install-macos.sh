#!/bin/bash

set -euxo pipefail

brew install git-lfs
git lfs install
gem install -N xcpretty-travis-formatter
