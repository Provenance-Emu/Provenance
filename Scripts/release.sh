#!/usr/bin/env bash
# release.sh — Provenance beta release automation
#
# Ported from iFly EMU's release.sh, adapted for Provenance's committed .xcworkspace,
# Build.xcconfig, and per-platform AppStore schemes.
#
# Usage:
#   ./Scripts/release.sh [options]
#
# Options:
#   --version X.Y.Z        Override marketing version (default: read from Build.xcconfig)
#   --build N              Override build number (default: epoch seconds, auto-increasing)
#   --channel testflight   Upload to TestFlight only
#   --channel github       Create GitHub release only (Ad Hoc IPA, iOS)
#   --channel all          All channels (TestFlight + GitHub) (default)
#   --platform ios         Archive/upload iOS only (default)
#   --platform tvos        Archive/upload tvOS only
#   --platform all         Both iOS and tvOS (TestFlight); sideload stays iOS-only
#   --no-build             Skip xcodebuild (reuse last archive)
#   --dry-run              Print actions without executing
#   --help                 Show this message
#
# Required environment variables for each channel:
#   TestFlight:  ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH (or ASC_API_KEY_CONTENT)
#                (consumed by xcodebuild via the App Store Connect API key you have configured
#                 for automatic signing / Xcode; store the .p8 where xcodebuild can find it)
#   GitHub:      GITHUB_TOKEN (or uses gh CLI auth)
#
# Overridable config env vars:
#   RELEASES_REPO  (default: Provenance-Emu/Provenance)

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCCONFIG="$PROJECT_DIR/Build.xcconfig"
EXPORT_OPTIONS_APPSTORE="$PROJECT_DIR/ExportOptions/ExportOptions-AppStore.plist"
EXPORT_OPTIONS_ADHOC="$PROJECT_DIR/ExportOptions/ExportOptions-AdHoc.plist"
ARCHIVES_DIR="$PROJECT_DIR/build/archives"
EXPORT_DIR="$PROJECT_DIR/build/export"
WORKSPACE="$PROJECT_DIR/Provenance.xcworkspace"
RELEASES_REPO="${RELEASES_REPO:-Provenance-Emu/Provenance}"

# Single multiplatform AppStore scheme for ALL platforms — the app target is
# cross-platform (iOS + tvOS), so iOS and tvOS archive from the same scheme and
# differ only in -destination (this matches CI, which uses one scheme for both).
# The old "ProvenanceTV (AppStore)" scheme has no archive action configured.
APPSTORE_SCHEME="Provenance (AppStore)"
IOS_SCHEME="$APPSTORE_SCHEME"
TVOS_SCHEME="$APPSTORE_SCHEME"

# ── Parse arguments ─────────────────────────────────────────────────────────────
VERSION=""
BUILD_NUMBER=""
CHANNEL="all"
PLATFORM="ios"
NO_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --build) BUILD_NUMBER="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --no-build) NO_BUILD=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help)
            sed -n '/^# Usage:/,/^[^#]/p' "$0" | sed '$d' | sed 's/^# \{0,2\}//'
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────────
log()  { echo "▶ $*"; }
info() { echo "  $*"; }
warn() { echo "⚠ $*" >&2; }
err()  { echo "✗ $*" >&2; exit 1; }
run()  {
    if $DRY_RUN; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}
# True when the requested channel includes "$1" (or is "all").
should_run() { [[ "$CHANNEL" == "all" || "$CHANNEL" == "$1" ]]; }
# True when the requested platform includes "$1" (or is "all").
should_platform() { [[ "$PLATFORM" == "all" || "$PLATFORM" == "$1" ]]; }
case "$PLATFORM" in ios|tvos|all) ;; *) err "Unknown --platform: $PLATFORM (use ios, tvos, or all)" ;; esac
case "$CHANNEL" in testflight|github|all) ;; *) err "Unknown --channel: $CHANNEL (use testflight, github, or all)" ;; esac

# ── Resolve version and build number ─────────────────────────────────────────────
if [[ -z "$VERSION" ]]; then
    VERSION=$(grep -E '^MARKETING_VERSION[[:space:]]*=' "$XCCONFIG" | sed 's/.*=[[:space:]]*//' | tr -d '[:space:]')
fi
if [[ -z "$VERSION" ]]; then
    err "MARKETING_VERSION not found in $XCCONFIG"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
    # Epoch seconds: always unique + strictly increasing, so App Store Connect never
    # rejects an upload as a redundant binary. We force this explicitly because the
    # command-line `xcodebuild -exportArchive` does NOT honor the export plist's
    # manageAppVersionAndBuildNumber the way the Xcode GUI Organizer checkbox does —
    # the CLI uploads the literal xcconfig value and collides. Fits CFBundleVersion's
    # uint32 per-component limit (good until 2106). Override with BUILD_NUMBER=... .
    BUILD_NUMBER=$(date +%s)
fi

TAG="v${VERSION}+${BUILD_NUMBER}"
IPA_NAME="Provenance-${VERSION}-${BUILD_NUMBER}.ipa"

log "Provenance release: $VERSION (build $BUILD_NUMBER) — channels: $CHANNEL"
info "Tag: $TAG"
info "IPA: $IPA_NAME"

# ── Check git state ──────────────────────────────────────────────────────────────
if ! $DRY_RUN && ! $NO_BUILD; then
    DIRTY=$(git -C "$PROJECT_DIR" status --porcelain --untracked-files=no)
    if [[ -n "$DIRTY" ]]; then
        warn "Working tree has uncommitted changes:"
        echo "$DIRTY"
        read -rp "  Continue anyway? [y/N] " yn
        [[ "${yn,,}" == y ]] || exit 1
    fi
fi

# ── Build number injection ────────────────────────────────────────────────────────
XCCONFIG_BAK="$XCCONFIG.release-bak"
inject_build_number() {
    log "Setting build number $BUILD_NUMBER in $(basename "$XCCONFIG")"
    # Back up the EXACT current file (not HEAD) so restore preserves any unrelated
    # uncommitted edits — a blanket `git checkout` here would silently wipe them.
    cp "$XCCONFIG" "$XCCONFIG_BAK"
    _injected=true
    # BSD sed (macOS): -i '' for in-place, matching Scripts/bump-version.sh.
    sed -i '' "s/^CURRENT_PROJECT_VERSION[[:space:]]*=.*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/" "$XCCONFIG"
}

# Whether THIS run injected a build number (and therefore owns the backup).
# Restoring must be conditional on this, not merely on the backup existing: a
# leftover backup from a previously killed run is NOT ours, and a --dry-run that
# restored it would both mutate the working tree and consume the one chance the
# next real run had to self-heal.
_injected=false

restore_build_number() {
    # Restore the pre-inject file so the build number isn't left in the working tree.
    # `return 0` so this EXIT-trap never sets a nonzero exit code — the trap's
    # status becomes the script's.
    $_injected || return 0
    [[ -f "$XCCONFIG_BAK" ]] && mv -f "$XCCONFIG_BAK" "$XCCONFIG"
    return 0
}

# Set by resolve_asc_key only when it had to materialise ASC_API_KEY_CONTENT.
# A key we wrote ourselves must not outlive the run; a key the user pointed us
# at via ASC_API_KEY_PATH is theirs and is left alone.
_asc_key_tmpdir=""

cleanup() {
    restore_build_number
    [[ -n "$_asc_key_tmpdir" && -d "$_asc_key_tmpdir" ]] && rm -rf "$_asc_key_tmpdir"
    return 0
}
trap cleanup EXIT

# Ctrl-C / SIGTERM: kill any xcodebuild we spawned, then let the EXIT trap
# restore the xcconfig. Without this, interrupting a run left the injected
# epoch build number in Build.xcconfig plus an orphaned .release-bak, and an
# orphaned xcodebuild holding the build system.
#
# CAVEAT: bash cannot run a trap while a foreground child is still running, so
# if xcodebuild has wedged and is IGNORING SIGINT (classic after sleep/wake
# mid-build) this handler never fires — mashing Ctrl-C will do nothing. In that
# case: `pkill -9 xcodebuild; pkill -9 -f XCBBuildService`, then re-run (the
# self-heal below restores the xcconfig).
on_interrupt() {
    warn "Interrupted — terminating xcodebuild and restoring $(basename "$XCCONFIG")"
    pkill -9 -P $$ xcodebuild 2>/dev/null || true
    exit 130
}
trap on_interrupt INT TERM

# Self-heal: a previous run killed hard (SIGKILL, or a wedged xcodebuild that
# never released the terminal) leaves the backup behind and the injected build
# number in the xcconfig. Restore it before injecting a new one, otherwise the
# backup gets overwritten with an already-poisoned file and the real value is
# lost permanently.
#
# Gated on dry-run: `mv` here is a working-tree mutation, and --dry-run promises
# not to make any. It also CONSUMES the backup, so a dry-run would silently use
# up the one chance the next real run had to self-heal. Report and leave it.
if [[ -f "$XCCONFIG_BAK" ]]; then
    if $DRY_RUN; then
        warn "Found leftover $(basename "$XCCONFIG_BAK") from an interrupted run — leaving it untouched (--dry-run); the next real run will restore it"
    else
        warn "Found leftover $(basename "$XCCONFIG_BAK") from an interrupted run — restoring it first"
        mv -f "$XCCONFIG_BAK" "$XCCONFIG"
    fi
fi

# Dry-run must not mutate the working tree at all (no inject, nothing to restore).
$DRY_RUN || inject_build_number

# ── Preconditions ──────────────────────────────────────────────────────────────
if [[ ! -d "$WORKSPACE" ]]; then
    err "Workspace not found: $WORKSPACE"
fi

# ── Archive (per platform) ─────────────────────────────────────────────────────────
IOS_ARCHIVE="$ARCHIVES_DIR/Provenance-iOS.xcarchive"
TVOS_ARCHIVE="$ARCHIVES_DIR/Provenance-tvOS.xcarchive"

# ── App Store Connect API key ──────────────────────────────────────────────────────
# Defined before do_archive because BOTH the archive (for -allowProvisioningUpdates
# in CI) and the export/upload step need it.
#
# Resolve the App Store Connect API key to a file path xcodebuild can read.
# Prefer ASC_API_KEY_PATH; else materialise ASC_API_KEY_CONTENT (base64 or raw
# .p8) to a temp file. Echoes the path; errors if no key / id / issuer is set.
# Without this, `xcodebuild -exportArchive` (destination=upload) falls back to
# Xcode's signed-in accounts and dies with "Failed to Use Accounts" in CLI.
_asc_key_path=""
# Sets the GLOBAL _asc_key_path; callers read that, they do not capture stdout.
#
# This used to `echo` the path, and both call sites used
# `key="$(resolve_asc_key)"` — a command-substitution SUBSHELL. Every global the
# function assigned was therefore written in a child process and lost on return,
# which broke it two ways: the `_asc_key_path` memo never persisted, so the key
# was re-materialised from ASC_API_KEY_CONTENT on EVERY call (once per platform
# during archive, again at export), and the temp-dir bookkeeping the EXIT trap
# needs never reached the parent, so each of those copies leaked.
resolve_asc_key() {
    [[ -n "$_asc_key_path" ]] && return 0
    [[ -n "${ASC_API_KEY_ID:-}" ]]   || err "ASC_API_KEY_ID is not set (App Store Connect API key ID)"
    [[ -n "${ASC_API_ISSUER_ID:-}" ]] || err "ASC_API_ISSUER_ID is not set (App Store Connect issuer ID)"
    if [[ -n "${ASC_API_KEY_PATH:-}" ]]; then
        [[ -f "$ASC_API_KEY_PATH" ]] || err "ASC_API_KEY_PATH does not exist: $ASC_API_KEY_PATH"
        _asc_key_path="$ASC_API_KEY_PATH"
    elif [[ -f "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8" ]]; then
        # xcodebuild's standard key location — set only ASC_API_KEY_ID + ISSUER.
        _asc_key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
    elif [[ -f "$HOME/private_keys/AuthKey_${ASC_API_KEY_ID}.p8" ]]; then
        _asc_key_path="$HOME/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
    elif [[ -n "${ASC_API_KEY_CONTENT:-}" ]]; then
        # Materialise into a 0700 temp DIRECTORY, not a temp file.
        #
        # This was `_asc_key_path="$(mktemp -t "AuthKey_${ID}").p8"`, which is a
        # trap: mktemp creates its file and returns that path, then `.p8` is
        # appended to the STRING. So the key was written to a path mktemp never
        # created — meaning it was created by the shell redirect at the default
        # umask, i.e. 0644 WORLD-READABLE, in a shared temp dir, while mktemp's
        # actual 0600 file was left behind empty. That is an App Store Connect
        # signing key readable by every user on the machine.
        #
        # mktemp -d is 0700, so the key inside it is unreachable by other users
        # regardless of umask; the umask 077 keeps the file itself 0600 too.
        _asc_key_tmpdir="$(mktemp -d -t provenance-asc)"
        _asc_key_path="$_asc_key_tmpdir/AuthKey_${ASC_API_KEY_ID}.p8"
        # Accept either base64-encoded or raw PEM .p8 content.
        if printf '%s' "$ASC_API_KEY_CONTENT" | grep -q "BEGIN PRIVATE KEY"; then
            ( umask 077; printf '%s' "$ASC_API_KEY_CONTENT" > "$_asc_key_path" )
        else
            ( umask 077; printf '%s' "$ASC_API_KEY_CONTENT" | base64 --decode > "$_asc_key_path" ) 2>/dev/null \
                || err "ASC_API_KEY_CONTENT is neither a valid .p8 nor base64"
        fi
    else
        err "No App Store Connect API key: set ASC_API_KEY_PATH or ASC_API_KEY_CONTENT"
    fi
}

do_archive() {
    local label="$1" scheme="$2" destination="$3" archive="$4"
    if ! $NO_BUILD; then
        log "Archiving $label ($scheme)..."
        run mkdir -p "$ARCHIVES_DIR"
        local cmd=(xcodebuild archive
            -workspace "$WORKSPACE"
            -scheme "$scheme"
            -destination "$destination"
            -configuration Release
            -archivePath "$archive"
            -scmProvider system
            -skipPackagePluginValidation
            -skipMacroValidation
            MARKETING_VERSION="$VERSION"
            CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
            CODE_SIGN_STYLE=Automatic)
        # Headless/CI: automatic signing has no Xcode account to consult, so
        # -allowProvisioningUpdates can only create/download profiles when the
        # App Store Connect API key is passed here too (the export step gets it
        # separately). Locally these vars are usually unset and Xcode uses the
        # signed-in account, so only add the flags when a key is available.
        if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
            local archive_key; resolve_asc_key; archive_key="$_asc_key_path"
            cmd+=(-allowProvisioningUpdates
                  -authenticationKeyPath "$archive_key"
                  -authenticationKeyID "$ASC_API_KEY_ID"
                  -authenticationKeyIssuerID "$ASC_API_ISSUER_ID")
        fi
        if $DRY_RUN; then
            echo "  [dry-run] ${cmd[*]}"
        else
            # Pipe through xcbeautify when available; fall back to raw xcodebuild.
            "${cmd[@]}" | xcbeautify 2>/dev/null || "${cmd[@]}"
        fi
    fi
    $DRY_RUN || [[ -d "$archive" ]] || err "Archive not found: $archive (run without --no-build)"
}

should_platform ios  && do_archive iOS  "$IOS_SCHEME"  "generic/platform=iOS"  "$IOS_ARCHIVE"
should_platform tvos && do_archive tvOS "$TVOS_SCHEME" "generic/platform=tvOS" "$TVOS_ARCHIVE"


do_appstore_upload() {
    local label="$1" archive="$2" exportdir="$3"
    log "Exporting + uploading $label to TestFlight (App Store)..."
    info "Build number $BUILD_NUMBER (forced — CLI export won't auto-increment)."
    local keypath; resolve_asc_key; keypath="$_asc_key_path"
    run mkdir -p "$exportdir"
    run xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$exportdir" \
        -exportOptionsPlist "$EXPORT_OPTIONS_APPSTORE" \
        -authenticationKeyPath "$keypath" \
        -authenticationKeyID "$ASC_API_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_API_ISSUER_ID" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
}

if should_run testflight; then
    should_platform ios  && do_appstore_upload iOS  "$IOS_ARCHIVE"  "$EXPORT_DIR/appstore-ios"
    should_platform tvos && do_appstore_upload tvOS "$TVOS_ARCHIVE" "$EXPORT_DIR/appstore-tvos"
fi

# ── Export Ad Hoc IPA (only for GitHub sideload distribution — iOS only) ────────────
# Needs an Ad Hoc / release-testing provisioning profile. Skipped for testflight-only
# so a missing ad-hoc profile can't fail an otherwise-successful TestFlight upload.
ADHOC_EXPORT="$EXPORT_DIR/adhoc"
IPA_ADHOC="$ADHOC_EXPORT/Provenance.ipa"
FINAL_IPA=""
IPA_SIZE=""

if should_platform ios && should_run github; then
    log "Exporting Ad Hoc IPA..."
    run mkdir -p "$ADHOC_EXPORT"
    run xcodebuild -exportArchive \
        -archivePath "$IOS_ARCHIVE" \
        -exportPath "$ADHOC_EXPORT" \
        -exportOptionsPlist "$EXPORT_OPTIONS_ADHOC" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    # Rename for distribution
    FINAL_IPA="$ADHOC_EXPORT/$IPA_NAME"
    run cp "$IPA_ADHOC" "$FINAL_IPA"
    $DRY_RUN || IPA_SIZE=$(stat -f%z "$FINAL_IPA" 2>/dev/null || stat -c%s "$FINAL_IPA")
fi

# ── GitHub release ────────────────────────────────────────────────────────────────
upload_github() {
    log "Creating GitHub release $TAG on $RELEASES_REPO..."

    # Get release notes from git log since last tag
    # `git log -n N` caps commits natively; avoids the `| head` SIGPIPE that trips
    # `set -o pipefail` in repos with many commits.
    LAST_TAG=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$LAST_TAG" ]]; then
        RELEASE_NOTES=$(git -C "$PROJECT_DIR" log -n 30 "${LAST_TAG}..HEAD" --pretty=format:"- %s")
    else
        RELEASE_NOTES=$(git -C "$PROJECT_DIR" log -n 20 --pretty=format:"- %s")
    fi

    RELEASE_BODY="## Provenance $VERSION (build $BUILD_NUMBER)

Pre-release beta.

### Changes
$RELEASE_NOTES"

    run gh release create "$TAG" \
        --repo "$RELEASES_REPO" \
        --title "Provenance $VERSION (build $BUILD_NUMBER)" \
        --notes "$RELEASE_BODY" \
        --prerelease \
        "$FINAL_IPA#Provenance iOS IPA"

    # Tag the source repo too (without the build number for readability)
    SEMVER_TAG="v${VERSION}"
    if ! git -C "$PROJECT_DIR" tag -l | grep -q "^${SEMVER_TAG}$"; then
        run git -C "$PROJECT_DIR" tag -a "$SEMVER_TAG" -m "Release $VERSION"
        run git -C "$PROJECT_DIR" push origin "$SEMVER_TAG"
    fi
}

# ── Dispatch channels ─────────────────────────────────────────────────────────────
# TestFlight already uploaded during the App Store export above (destination=upload).
should_run github && upload_github

log "Release $VERSION+$BUILD_NUMBER complete!"
