#!/bin/bash

set -ev

# Archives the Carthage packages, and prints the name of the archive

carthage build --use-xcframeworks --no-skip-current

# This is currently broken, combined with the --use-xcframeworks option above,  as of Carthage 0.38.0 on 2/17/2021
carthage archive

export ARCHIVE_PATH="UnrarKit.xcframework.zip"