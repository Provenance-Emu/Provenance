#!/bin/bash
PLATFORM=${1:-iOS,tvOS}

AWS_ACCESS_KEY_ID="M2B65BPG5JRKHIC8RAKX"
AWS_SECRET_ACCESS_KEY="R1pwhbv7foHK88VDgq1cZ3jlVi2YS6PFv9ueZi4p"
AWS_REGION="us-east-1"
AWS_ENDPOINT="http://provenance.joemattiello.com:9000"

# [default]
# region = us-east-1
# endpoint = http://provenance.joemattiello.com:9000

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

lockfile_waithold "rome-download"

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: $SWIFT_VERSION"

if [ -x "$(command -v rome)" ]; then
  echo "Downloading $PLATFORM ..."
  carthage update --no-build --platform $PLATFORM && rome download --platform $PLATFORM --cache-prefix "$SWIFT_VERSION"
  echo "Done."
else
  echo "Rome not installed. Skipping cached frameworks."
  echo "Install rome via homebrew \"brew install blender/homebrew-tap/rome\""
fi

lockfile_release "rome-download"
