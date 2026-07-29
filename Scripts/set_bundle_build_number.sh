#!/bin/bash
set -o pipefail

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

# Label used in log output only (the build phases pass the target name).
LABEL=${1:-"${PRODUCT_NAME:-target}"}

PLISTBUDDY="/usr/libexec/PlistBuddy"

# Stamp the PROCESSED Info.plist inside the built product.
#
# INFOPLIST_PATH is the path *within* the product ("Foo.app/Info.plist",
# "Foo.appex/Info.plist"); INFOPLIST_FILE is the project-relative path to the
# SOURCE plist. This script used to write ${BUILT_PRODUCTS_DIR}/${INFOPLIST_FILE},
# a path that never exists under the build dir, so every write silently failed
# and shipped builds carried an empty GitBranch/GitDate/GitTag and a hardcoded
# stale Revision. Writing the built copy (not the source) keeps git clean.
#
# Use TARGET_BUILD_DIR, NOT BUILT_PRODUCTS_DIR. They are the same for a normal
# build, but in an ARCHIVE (DEPLOYMENT_LOCATION=YES) the product is assembled
# under TARGET_BUILD_DIR (.../InstallationBuildProductsLocation/Applications)
# while BUILT_PRODUCTS_DIR points at .../BuildProductsPath/<config>-<sdk>, where
# no Info.plist exists. Reading BUILT_PRODUCTS_DIR made every archive fail with
# "Info.plist not found ... must run after 'Process Info.plist'".
#
# NOTE: this path must NOT be declared in the build phase's outputPaths — the
# processed Info.plist is already produced by ProcessInfoPlistFile, and naming
# it as a second producer creates a dependency cycle. Declaring it as an INPUT
# is correct and is what orders this phase after ProcessInfoPlistFile.
plistPath="${TARGET_BUILD_DIR:-${BUILT_PRODUCTS_DIR}}/${INFOPLIST_PATH}"

if [[ ( -z "${TARGET_BUILD_DIR}" && -z "${BUILT_PRODUCTS_DIR}" ) || -z "${INFOPLIST_PATH}" ]]; then
    echo "error: TARGET_BUILD_DIR/INFOPLIST_PATH unset; run this from an Xcode build phase" 1>&2
    exit 1
fi

if [[ ! -f "$plistPath" ]]; then
    echo "error: Info.plist not found at ${plistPath} — this phase must run after 'Process Info.plist'" 1>&2
    exit 1
fi

# CFBundleVersion is deliberately NOT set here. The source plists resolve it
# from $(CURRENT_PROJECT_VERSION) (Build.xcconfig locally, overridden by CI
# with the git commit count). A second writer racing that single source of
# truth is how build numbers drift between local and CI archives.

GIT_TAG=$(git describe --tags --always --dirty)
GIT_DATE=$(git log -1 --format="%cd" --date="local")
GIT_BRANCH=$(git name-rev --name-only HEAD)
REVISION=$(git rev-parse --short HEAD)

# PlistBuddy's Set fails when the key is absent, so fall back to Add. Any other
# failure is surfaced as a real Xcode error rather than being swallowed — this
# script reported success for years while writing nothing.
plist_set() {
    local key="$1"
    local value="$2"
    if "$PLISTBUDDY" -c "Set :${key} ${value}" "$plistPath" 2>/dev/null; then
        return 0
    fi
    if "$PLISTBUDDY" -c "Add :${key} string ${value}" "$plistPath" 2>/dev/null; then
        return 0
    fi
    echo "error: failed to set ${key} in ${plistPath}" 1>&2
    exit 1
}

plist_set GitBranch "$GIT_BRANCH"
plist_set GitDate "$GIT_DATE"
plist_set GitTag "$GIT_TAG"
plist_set Revision "$REVISION"

echo "Stamped ${LABEL} git metadata into ${INFOPLIST_PATH}"
echo "TAG: ${GIT_TAG}, DATE: ${GIT_DATE}, BRANCH: ${GIT_BRANCH}, REVISION: ${REVISION}"
