#!/usr/bin/env bash
# release.sh — Provenance beta release automation
#
# Ported from iFly EMU's release.sh, adapted for Provenance's committed .xcworkspace,
# Build.xcconfig, and per-platform AppStore schemes.
#
# Usage:
#   ./Scripts/release/release.sh [options]
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
#   --no-distribute        Upload to TestFlight but leave the build internal-only
#   --notes-file PATH      TestFlight "What to Test" text (default: "Build N from <branch> @ <sha>.")
#                          (skip adding it to the public groups / Beta App Review)
#   --dry-run              Print actions without executing
#   --help                 Show this message
#
# Required environment variables for each channel:
#   TestFlight:  ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH (or ASC_API_KEY_CONTENT)
#                (consumed by xcodebuild via the App Store Connect API key you have configured
#                 for automatic signing / Xcode; store the .p8 where xcodebuild can find it)
#   GitHub:      GITHUB_TOKEN (or uses gh CLI auth)
#   Symbols:     SENTRY_AUTH_TOKEN (or a ~/.sentryclirc login) + sentry-cli on PATH, to upload
#                the archive's dSYMs to Sentry. Optional: without them the dSYMs are only
#                kept locally and the script warns. An upload failure never fails the release.
#
# Overridable config env vars:
#   RELEASES_REPO  (default: Provenance-Emu/Provenance)
#   TESTFLIGHT_GROUPS           comma-separated beta groups to distribute to
#                               (default: every external group with a public link)
#   TESTFLIGHT_TIMEOUT_MINUTES  how long to wait for App Store Connect processing
#                               before distributing (default: 120)
#   SENTRY_ORG / SENTRY_PROJECT  Sentry destination for dSYMs
#                               (default: provenance-emu / provenance)
#
# Every archive's dSYMs (app + embedded frameworks) are copied to
#   build/export/<version>-<build>/dSYMs/<ios|tvos>/
# and uploaded to Sentry, so crash logs can be symbolicated later even without
# Sentry (see "Symbolicating a crash log" under CI in CLAUDE.md).

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
XCCONFIG="$PROJECT_DIR/Build.xcconfig"
EXPORT_OPTIONS_APPSTORE="$PROJECT_DIR/ExportOptions/ExportOptions-AppStore.plist"
EXPORT_OPTIONS_ADHOC="$PROJECT_DIR/ExportOptions/ExportOptions-AdHoc.plist"
ARCHIVES_DIR="$PROJECT_DIR/build/archives"
EXPORT_DIR="$PROJECT_DIR/build/export"
WORKSPACE="$PROJECT_DIR/Provenance.xcworkspace"
RELEASES_REPO="${RELEASES_REPO:-Provenance-Emu/Provenance}"
SENTRY_ORG="${SENTRY_ORG:-provenance-emu}"
SENTRY_PROJECT="${SENTRY_PROJECT:-provenance}"

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
DISTRIBUTE=true
NOTES_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --build) BUILD_NUMBER="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --no-build) NO_BUILD=true; shift ;;
        --no-distribute) DISTRIBUTE=false; shift ;;
        --notes-file) NOTES_FILE="$2"; shift 2 ;;
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
# Before the 30+ minute archive, not after it.
[[ -z "$NOTES_FILE" || -s "$NOTES_FILE" ]] || err "--notes-file $NOTES_FILE is missing or empty"
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
        # Non-interactive (CI) has no stdin to answer with: `read` fails
        # immediately, leaving $yn empty, and the script exited 1 before doing
        # any work. That made this unrunnable from Actions. A CI checkout is
        # reproducible from its ref by construction, and the usual "dirt" there
        # is submodule bookkeeping rather than edited sources, so warn loudly
        # and continue instead of aborting.
        if [[ ! -t 0 ]]; then
            warn "Non-interactive shell — continuing despite the dirty tree."
        else
            read -rp "  Continue anyway? [y/N] " yn
            [[ "${yn,,}" == y ]] || exit 1
        fi
    fi
fi

# ── Build number ──────────────────────────────────────────────────────────────────
# Build.xcconfig is deliberately NOT modified.
#
# Every xcodebuild invocation below already passes CURRENT_PROJECT_VERSION as a
# command-line build-setting override, which outranks the xcconfig, and the
# Info.plist resolves CFBundleVersion from that build setting (see
# Scripts/build-phases/set_bundle_build_number.sh). Editing the file was redundant.
#
# It was also unsafe: the edit had to be undone by an EXIT trap, and a trap
# cannot run when the script is SIGKILLed or when a wedged xcodebuild swallows
# the interrupt. That left a tracked file dirty — carrying an epoch build number
# like 1785899074 instead of the commit count — plus an orphaned .release-bak,
# until someone happened to run this script again. A file that is never written
# cannot be left dirty, so the failure mode is gone rather than mitigated.
XCCONFIG_BAK="$XCCONFIG.release-bak"

# Set by resolve_asc_key only when it had to materialise ASC_API_KEY_CONTENT.
# A key we wrote ourselves must not outlive the run; a key the user pointed us
# at via ASC_API_KEY_PATH is theirs and is left alone.
_asc_key_tmpdir=""

cleanup() {
    # Nothing to restore: this script no longer edits Build.xcconfig.
    # `return 0` so this EXIT-trap never sets a nonzero exit code — the trap's
    # status becomes the script's.
    [[ -n "$_asc_key_tmpdir" && -d "$_asc_key_tmpdir" ]] && rm -rf "$_asc_key_tmpdir"
    return 0
}
trap cleanup EXIT

# Ctrl-C / SIGTERM: kill any xcodebuild we spawned so it doesn't outlive us
# holding the build system.
#
# CAVEAT: bash cannot run a trap while a foreground child is still running, so
# if xcodebuild has wedged and is IGNORING SIGINT (classic after sleep/wake
# mid-build) this handler never fires — mashing Ctrl-C will do nothing. In that
# case: `pkill -9 xcodebuild; pkill -9 -f XCBBuildService`, then re-run.
# The working tree is unaffected either way now that Build.xcconfig is untouched.
on_interrupt() {
    warn "Interrupted — terminating xcodebuild"
    pkill -9 -P $$ xcodebuild 2>/dev/null || true
    exit 130
}
trap on_interrupt INT TERM

# Self-heal for backups left by older versions of this script, which did edit
# Build.xcconfig and could die before restoring it. Kept so an existing stray
# .release-bak (and the epoch build number it was meant to undo) still gets
# cleaned up rather than lingering forever now that nothing else writes it.
#
# Gated on dry-run: `mv` here is a working-tree mutation, and --dry-run promises
# not to make any. Report and leave it.
if [[ -f "$XCCONFIG_BAK" ]]; then
    if $DRY_RUN; then
        warn "Found leftover $(basename "$XCCONFIG_BAK") from an older run — leaving it untouched (--dry-run); the next real run will restore it"
    else
        warn "Found leftover $(basename "$XCCONFIG_BAK") from an older run — restoring $(basename "$XCCONFIG") from it"
        mv -f "$XCCONFIG_BAK" "$XCCONFIG"
    fi
fi

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
            # Decide the formatter BEFORE building, never after.
            #
            # This was:
            #     "${cmd[@]}" | xcbeautify 2>/dev/null || "${cmd[@]}"
            # whose `||` was meant to mean "xcbeautify isn't installed, run raw".
            # Under `set -o pipefail` it fires on ANY pipeline failure, so a
            # genuine compile error re-ran the ENTIRE archive from scratch — you
            # waited through a second full build (30-90 min) before seeing the
            # diagnostic, and the retry's own failure is what finally surfaced.
            # Probing for the binary up front expresses the actual intent and
            # can never double-build.
            local formatter=cat
            if command -v xcbeautify >/dev/null 2>&1; then
                formatter=xcbeautify
            else
                warn "xcbeautify not found — using unformatted output"
            fi
            # Tee the raw log: xcbeautify FILTERS OUT Run Script phase output, so
            # a "Generate Frameworks" failure emits no `error:` line and is
            # invisible in the formatted stream. Same rationale as build.yml.
            local logfile="$ARCHIVES_DIR/xcodebuild-${label}.log"
            info "Raw build log: $logfile"
            # release.sh uploads every dSYM itself once the archive succeeds (see
            # save_and_upload_dsyms), so tell the app's "Upload Debug Symbols to
            # Sentry" Run Script phase not to repeat the same upload mid-build.
            PV_SKIP_XCODE_SENTRY_UPLOAD=1 "${cmd[@]}" 2>&1 | tee "$logfile" | "$formatter"
        fi
    fi
    $DRY_RUN || [[ -d "$archive" ]] || err "Archive not found: $archive (run without --no-build)"
}

should_platform ios  && do_archive iOS  "$IOS_SCHEME"  "generic/platform=iOS"  "$IOS_ARCHIVE"
should_platform tvos && do_archive tvOS "$TVOS_SCHEME" "generic/platform=tvOS" "$TVOS_ARCHIVE"

# ── Debug symbols (dSYMs) ───────────────────────────────────────────────────────────
# Crashes from App Store / TestFlight builds are unsymbolicated unless the dSYMs of
# THAT archive reach Sentry (or are kept locally for atos). The archive's dSYMs/
# folder holds the app AND every embedded framework built from source, so it is
# the one place to take them from. Runs right after the archive and before
# export/upload, so symbols exist before the build can reach a tester.
#
# Never fatal: a missing token / sentry-cli / network error only WARNS, because
# losing symbols must not block shipping a build.
#
# Not covered (no dSYM exists to collect — prebuilt binaries copied into the
# bundle): the libretro buildbot *.libretro.framework cores, ffmpeg/libav*,
# MoltenVK, Sentry.framework, and PVlibDolphin-ios.
DSYM_KEPT_PATHS=()

# $1 label, $2 short dir name (ios|tvos), $3 .xcarchive path
save_and_upload_dsyms() {
    local label="$1" short="$2" archive="$3"
    # Name the folder after the ARCHIVE's own version/build (read from its
    # Info.plist) so --no-build reuse of an older archive can't be mislabelled.
    local av="$VERSION" ab="$BUILD_NUMBER" plist="$archive/Info.plist" v b
    if [[ -f "$plist" ]]; then
        v="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
        b="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$plist" 2>/dev/null || true)"
        av="${v:-$av}"
        ab="${b:-$ab}"
    fi
    local src="$archive/dSYMs" dest="$EXPORT_DIR/${av}-${ab}/dSYMs/$short"
    log "Saving + uploading $label dSYMs (Sentry $SENTRY_ORG/$SENTRY_PROJECT)..."
    if $DRY_RUN; then
        echo "  [dry-run] cp -cR $src/. $dest/"
        echo "  [dry-run] sentry-cli debug-files upload --org $SENTRY_ORG --project $SENTRY_PROJECT $src"
        return 0
    fi
    if ! compgen -G "$src/*.dSYM" >/dev/null; then
        warn "$label archive has no dSYMs at $src — crashes from this build will NOT symbolicate"
        return 0
    fi

    # Local copy for atos/symbolicatecrash. `cp -c` is an APFS clone (instant, no
    # extra disk for the ~1.3 GB set); fall back to a plain copy elsewhere.
    mkdir -p "$dest" || { warn "could not create $dest"; return 0; }
    if cp -cR "$src/." "$dest/" 2>/dev/null || cp -R "$src/." "$dest/"; then
        DSYM_KEPT_PATHS+=("$dest")
        info "$label dSYMs kept at: $dest ($(find "$dest" -maxdepth 1 -name '*.dSYM' | wc -l | tr -d ' ') bundles)"
    else
        warn "could not copy $label dSYMs to $dest"
    fi

    if ! command -v sentry-cli >/dev/null 2>&1; then
        warn "sentry-cli not installed — $label dSYMs NOT uploaded to Sentry (brew install getsentry/tools/sentry-cli)"
        return 0
    fi
    if [[ -z "${SENTRY_AUTH_TOKEN:-}" && ! -f "$HOME/.sentryclirc" ]]; then
        warn "SENTRY_AUTH_TOKEN not set and no ~/.sentryclirc — $label dSYMs NOT uploaded to Sentry"
        return 0
    fi
    local upload_log="$ARCHIVES_DIR/sentry-dsyms-${short}.log"
    # --org/--project are explicit: CI has no ~/.sentryclirc to supply them.
    if sentry-cli debug-files upload \
            --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
            "$src" >"$upload_log" 2>&1; then
        info "$label dSYMs uploaded to Sentry (log: $upload_log)"
    else
        warn "Sentry dSYM upload failed for $label — see $upload_log; symbols are still in $dest"
        tail -n 5 "$upload_log" >&2 || true
    fi
    return 0
}

should_platform ios  && save_and_upload_dsyms iOS  ios  "$IOS_ARCHIVE"
should_platform tvos && save_and_upload_dsyms tvOS tvos "$TVOS_ARCHIVE"


do_appstore_upload() {
    local label="$1" archive="$2" exportdir="$3"
    log "Exporting + uploading $label to TestFlight (App Store)..."
    info "Build number $BUILD_NUMBER (forced — CLI export won't auto-increment)."
    local keypath; resolve_asc_key; keypath="$_asc_key_path"
    run mkdir -p "$exportdir"
    # -allowProvisioningUpdates is required here as well as on the archive, not
    # just the API key. ExportOptions-AppStore.plist sets signingStyle=automatic,
    # so export must resolve a profile per bundle id; without the flag xcodebuild
    # only consults profiles already installed on the machine, and a fresh runner
    # has none. That failed the upload after both archives had succeeded:
    #   error: exportArchive No profiles for 'org.provenance-emu.provenance' were found
    run xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$exportdir" \
        -exportOptionsPlist "$EXPORT_OPTIONS_APPSTORE" \
        -allowProvisioningUpdates \
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

# ── Distribute to the public TestFlight groups ────────────────────────────────────
# The upload above only reaches the internal groups. External groups (the public
# TestFlight links) never pick a build up on their own, so a local release used
# to leave every public tester on the previous build until someone assigned it by
# hand. This runs the same script CI's testflight-distribute action runs: wait for
# processing, add the build to the external groups, submit for Beta App Review.
# CI passes --no-distribute and keeps its own step, which reports per platform.
DISTRIBUTE_FAILED=()

# PyJWT is the only dependency. Homebrew Python is PEP 668 "externally managed",
# so it goes in a venv kept under build/ and reused across runs.
distribute_python() {
    if python3 -c 'import jwt, cryptography' 2>/dev/null; then
        echo python3
        return
    fi
    local venv="$PROJECT_DIR/build/.testflight-distribute-venv"
    if [[ ! -x "$venv/bin/python" ]] || ! "$venv/bin/python" -c 'import jwt, cryptography' 2>/dev/null; then
        python3 -m venv "$venv" >&2
        "$venv/bin/python" -m pip install --quiet --disable-pip-version-check "PyJWT[crypto]>=2.8" >&2
    fi
    echo "$venv/bin/python"
}

do_distribute() {
    local label="$1" asc_platform="$2"
    log "Distributing $label build $BUILD_NUMBER to external TestFlight groups..."
    if $DRY_RUN; then
        echo "  [dry-run] distribute.py PLATFORM=$asc_platform BUILD_NUMBER=$BUILD_NUMBER"
        return 0
    fi
    local python; python="$(distribute_python)"
    resolve_asc_key
    local sha; sha="$(git -C "$PROJECT_DIR" rev-parse --short HEAD)"
    local branch; branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)"
    local whats_new="Build $BUILD_NUMBER from $branch @ $sha."
    if [[ -n "$NOTES_FILE" ]]; then
        whats_new="$(cat "$NOTES_FILE")"$'\n\n'"$whats_new"
    fi
    # distribute.py reads the key's contents, not a path.
    if ! ASC_API_KEY_CONTENT="$(cat "$_asc_key_path")" \
        BUNDLE_ID="org.provenance-emu.provenance" \
        BUILD_NUMBER="$BUILD_NUMBER" \
        PLATFORM="$asc_platform" \
        GROUPS="${TESTFLIGHT_GROUPS:-}" \
        WHATS_NEW="$whats_new" \
        TIMEOUT_MINUTES="${TESTFLIGHT_TIMEOUT_MINUTES:-120}" \
        SUBMIT_FOR_REVIEW=true \
        "$python" "$PROJECT_DIR/.github/actions/testflight-distribute/distribute.py"; then
        warn "$label build $BUILD_NUMBER was uploaded but NOT distributed — it is internal-only."
        warn "Retry: op run --env-file=.env -- env BUNDLE_ID=org.provenance-emu.provenance BUILD_NUMBER=$BUILD_NUMBER PLATFORM=$asc_platform python3 .github/actions/testflight-distribute/distribute.py"
        DISTRIBUTE_FAILED+=("$label")
    fi
}

# After both uploads, so tvOS uploads while App Store Connect processes iOS.
if should_run testflight && $DISTRIBUTE; then
    should_platform ios  && do_distribute iOS  IOS
    should_platform tvos && do_distribute tvOS TV_OS
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

# Reported last, after the GitHub channel had its chance to run: a build stuck in
# processing should not cost the sideload release too.
if [[ ${#DISTRIBUTE_FAILED[@]} -gt 0 ]]; then
    err "Release $VERSION+$BUILD_NUMBER uploaded, but distribution failed for: ${DISTRIBUTE_FAILED[*]}"
fi

log "Release $VERSION+$BUILD_NUMBER complete!"
for kept in ${DSYM_KEPT_PATHS[@]+"${DSYM_KEPT_PATHS[@]}"}; do
    info "dSYMs (for atos / symbolicatecrash): $kept"
done
