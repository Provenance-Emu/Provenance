#!/bin/bash

# Copyright © 2019 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Created by Jason Leach on 2019-05-16.

set -Eeuo pipefail

[[ -z "$1" ]] && echo "Missing target name" && exit 1

TARGET=$1
PROJECT_FILE=$(find . -d 1 -iname '*.xcodeproj')
APP_PLIST=$(
    xcodebuild -project "$PROJECT_FILE" -target "$TARGET" -showBuildSettings \
    | grep "INFOPLIST_FILE" \
    | awk -F  "=" '{print $2}' \
    | awk '{$1=$1};1'
)

if [ -z "${APP_PLIST:-}" ]; then
  echo "** ERROR: Unable to locate info plist file"
  exit -1
fi

if [[ -z "${BUILD_BUILDID:-}" ]]; then
    echo "** ERROR: Unable to determine build number."
    exit -1
fi

echo "** INFO: Setting build number to $BUILD_BUILDID."
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_BUILDID" $APP_PLIST

exit 0
