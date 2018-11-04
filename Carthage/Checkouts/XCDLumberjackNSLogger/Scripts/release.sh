#!/bin/bash -e

PROJECT_NAME=XCDLumberjackNSLogger

if [[ $# -ne 1 ]]; then
    echo "usage: $0 VERSION"
    exit 1
fi

VERSION=$1
VERSION_PARTS=(${VERSION//./ })

grep "#### Version ${VERSION}" RELEASE_NOTES.md > /dev/null || (echo "RELEASE_NOTES.md must contain release notes for version ${VERSION}" && exit 1)

git flow release start ${VERSION}

echo "Updating CHANGELOG"
echo -e "$(cat RELEASE_NOTES.md)\n\n$(cat CHANGELOG.md)" > CHANGELOG.md
git add CHANGELOG.md
git commit -m "Update CHANGELOG for version ${VERSION}"

echo "Updating version"
CURRENT_PROJECT_VERSION=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -showBuildSettings | awk '/CURRENT_PROJECT_VERSION/{print $3}')
CURRENT_PROJECT_VERSION=$(expr ${CURRENT_PROJECT_VERSION} + 1)
set -v
sed -i "" "s/DYLIB_CURRENT_VERSION = .*;/DYLIB_CURRENT_VERSION = ${VERSION};/g" "${PROJECT_NAME}.xcodeproj/project.pbxproj"
sed -i "" "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${CURRENT_PROJECT_VERSION};/g" "${PROJECT_NAME}.xcodeproj/project.pbxproj"
sed -i "" "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${VERSION};/g" "${PROJECT_NAME} Demo/${PROJECT_NAME} Demo.xcodeproj/project.pbxproj"
sed -i "" "s/^\(.*s.version.*=.*\)\".*\"/\1\"${VERSION}\"/" "${PROJECT_NAME}.podspec"
sed -E -i "" "s/~> [0-9\.]+/~> ${VERSION_PARTS[0]}.${VERSION_PARTS[1]}/g" "README.md"
set +v
git add "${PROJECT_NAME}.xcodeproj"
git add "${PROJECT_NAME} Demo/${PROJECT_NAME} Demo.xcodeproj"
git add "${PROJECT_NAME}.podspec"
git add "README.md"
git commit -m "Update version to ${VERSION}"

# allow warnings until https://github.com/CocoaPods/CocoaPods/issues/5188 is resolved
pod lib lint --allow-warnings ${PROJECT_NAME}.podspec

GIT_MERGE_AUTOEDIT=no git flow release finish -s -f RELEASE_NOTES.md ${VERSION}

echo -e "#### Version X.Y.Z\n\n* " > RELEASE_NOTES.md

echo "Things remaining to do"
echo "  * git push with tags (master and develop)"
echo "  * pod trunk push ${PROJECT_NAME}.podspec"
echo "  * create a new release on GitHub: https://github.com/0xced/${PROJECT_NAME}/releases/new"
echo "  * close milestone on GitHub if applicable: https://github.com/0xced/${PROJECT_NAME}/milestones"
