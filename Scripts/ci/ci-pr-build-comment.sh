#!/usr/bin/env bash
# Writes the "test builds ready" PR comment for a Build and Upload Provenance run
# to stdout: one direct download link per IPA, plain install steps, and a warning
# when the build shipped without some locally-built cores.
#
# Usage: ci-pr-build-comment.sh <owner/repo> <run-id> <head-sha>
# Needs GH_TOKEN with actions:read.
set -euo pipefail

REPO="$1"
RUN_ID="$2"
SHA="$3"
RUN_URL="https://github.com/${REPO}/actions/runs/${RUN_ID}"
MISSING_REPORT_PREFIX="missing-local-dylibs-"

ARTIFACTS=$(gh api --paginate "repos/${REPO}/actions/runs/${RUN_ID}/artifacts" \
  --jq '.artifacts[] | select(.expired | not) | [.id, .name, .size_in_bytes, .expires_at] | @tsv')

human_size() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1073741824) printf "%.1f GB", b / 1073741824
    else printf "%.0f MB", b / 1048576
  }'
}

ROWS=""
EXPIRES=""
while IFS=$'\t' read -r id name size expires; do
  [[ "$name" == *.ipa ]] || continue
  case "$name" in
    *tvOS*) device="Apple TV" ;;
    *) device="iPhone & iPad" ;;
  esac
  ROWS+="| ${device} | [${name}](${RUN_URL}/artifacts/${id}) | $(human_size "$size") |"$'\n'
  EXPIRES="${expires%%T*}"
done <<< "$ARTIFACTS"

# Each build leg uploads a report listing the locally-built cores it was missing.
MISSING=""
REPORT_DIR=$(mktemp -d)
while IFS=$'\t' read -r _ name _ _; do
  [[ "$name" == "${MISSING_REPORT_PREFIX}"* ]] || continue
  gh run download "$RUN_ID" --repo "$REPO" -n "$name" -D "${REPORT_DIR}/${name}" >/dev/null 2>&1 || continue
  cores=$(tr -s '[:space:]' ' ' < "${REPORT_DIR}/${name}/missing-local-dylibs.txt" | sed 's/^ //; s/ $//')
  [ -n "$cores" ] && MISSING+="- ${name#"$MISSING_REPORT_PREFIX"}: ${cores}"$'\n'
done <<< "$ARTIFACTS"
rm -rf "$REPORT_DIR"

echo "## 📦 Test builds ready for \`${SHA:0:7}\`"
echo
if [ -z "$ROWS" ]; then
  echo "This build finished but produced no app files. Details are on the [build page](${RUN_URL})."
  exit 0
fi
echo "| Device | Download | Size |"
echo "|---|---|---|"
printf '%s' "$ROWS"
echo
echo "### How to install"
echo "1. Click the download for your device. GitHub only lets signed-in accounts download builds, so sign in (a free account works) if it asks."
echo "2. Unzip the file you get. The \`.ipa\` is inside."
echo "3. Install it: on iPhone or iPad use AltStore, SideStore or TrollStore; on Apple TV use Xcode or another Apple TV sideloading tool."
echo
if [ -n "$MISSING" ]; then
  echo "> [!WARNING]"
  echo "> This build is missing some emulator cores, so games for them won't start:"
  printf '%s' "$MISSING" | sed 's/^/> /'
  echo
fi
[ -n "$EXPIRES" ] && echo "<sub>Downloads available until ${EXPIRES}. [Build log](${RUN_URL})</sub>"
exit 0
