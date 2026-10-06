#!/usr/bin/env bash
#
# Initialize every submodule for a CI build.
#
# Shared by build.yml and testflight.yml. These two had their own copies of this
# logic and drifted: build.yml learned to retry the shallow-clone race while
# testflight.yml did not, so TestFlight failed every day for a week on a race the
# other workflow already recovered from. Keep the recovery in one place.
#
# The failure modes this exists to survive, all observed on this repo:
#
#   * `--depth 1 --jobs 4` races on .git/shallow ("shallow file has changed since
#     we read it"), aborting the fetch and then reporting the gitlink as
#     unreachable — Dolphin's Externals/SDL/SDL pin (a release tag commit, only
#     reachable by direct SHA fetch) failed every build this way.
#   * An aborted pass leaves submodules registered with an EMPTY worktree. A plain
#     `git submodule update` sees the recorded SHA and skips the checkout, so
#     --force is required to recover.
#   * A third-party host has an outage mid-clone (gitlab.com returned HTTP 500 for
#     Dolphin's bzip2 dependency). Nothing here can fix that, but the build must
#     fail HERE, naming the submodule, instead of proceeding and dying six minutes
#     later inside SwiftPM ("Cores/VirtualJaguar/Package.swift doesn't exist").
#
# Correctness therefore comes from VERIFYING the tree after each attempt rather
# than from the exit code of `git submodule update`: a partial failure can still
# exit 0, and the last-resort attempt's failure used to be swallowed entirely.
# A non-zero exit is still treated as a failure — it is never benign here.
#
# Why the verification is more than "no '-' in `git submodule status`": with
# --jobs, git clones EVERY submodule first and checks them out one by one
# afterwards, and a nested failure (`Failed to recurse into submodule path
# 'Cores/Dolphin/dolphin-ios'`) aborts that checkout loop. Every path sorted after
# the failure is left cloned — HEAD at the gitlink, so `status` prints it as
# clean — with a worktree holding nothing but `.git`. That is how the
# 2026-10-06 build (github.com unreachable for hidapi) reported "Submodule init
# complete." with an empty Cores/VirtualJaguar.
#
# Usage: ci-init-submodules.sh
#        CI_SUBMODULE_RETRY_DELAY overrides the first retry delay in seconds
#        (default 15; the last-resort attempt waits three times as long).
set -uo pipefail

# Files the build reads from a submodule before any core build script runs, so a
# missing one fails xcodebuild's package resolution rather than a later step.
REQUIRED_FILES=(
    "Cores/VirtualJaguar/Package.swift"
)

# Prints "<path> (<reason>)" for every submodule that is not fully checked out,
# and for every required file that is missing. Prints nothing when the tree is
# complete.
incomplete_submodules() {
    local status rc line prefix path

    # stderr is left alone so git's own complaint lands in the CI log.
    status="$(git submodule status --recursive)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "(git submodule status --recursive failed with exit $rc)"
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        prefix="${line:0:1}"
        # "<prefix><sha> <path> (<describe>)". Paths can contain spaces
        # (Dependencies/SWCompression/Tests/Test Files), so cut rather than split.
        # git prints the describe part only for a checked-out submodule.
        path="${line#?}"
        path="${path#* }"
        [ "$prefix" = "-" ] || path="${path% (*)}"
        case "$prefix" in
            -) echo "$path (not cloned)" ;;
            +) echo "$path (checked out at the wrong commit)" ;;
            U) echo "$path (merge conflict)" ;;
            *)
                if [ ! -e "$path/.git" ]; then
                    echo "$path (no .git)"
                elif [ -z "$(find "$path" -mindepth 1 -maxdepth 1 ! -name .git -print -quit)" ]; then
                    echo "$path (empty worktree)"
                fi
                ;;
        esac
    done <<< "$status"

    for path in "${REQUIRED_FILES[@]}"; do
        [ -e "$path" ] || echo "$path (missing)"
    done
}

report_and_exit() {
    local missing="$1" rc="$2"
    echo "::error::Submodules are still not checked out after 3 attempts. The most" \
         "likely cause is an upstream host outage — check the log above for a" \
         "'fatal: unable to access' line naming the remote."
    [ "$rc" -ne 0 ] && echo "::error::  git submodule update exited $rc"
    while IFS= read -r sub; do
        [ -n "$sub" ] && echo "::error::  not initialized: $sub"
    done <<< "$missing"
    exit 1
}

main() {
    local rc missing delay="${CI_SUBMODULE_RETRY_DELAY:-15}"

    # Whether the cache actually restored anything, decided from the filesystem
    # rather than from actions/cache's `cache-hit`. That output is only true for an
    # EXACT key match, and the key includes github.sha — so on every develop push it
    # said "miss" even though restore-keys had just restored ~5 GB of submodules. The
    # old miss path then deinited all of it and re-cloned from scratch, costing
    # several minutes a build and widening the window for an upstream outage to take
    # the build down.
    if [ -d .git/modules ] && [ -n "$(ls -A .git/modules 2>/dev/null)" ]; then
        echo "Submodule cache restored — syncing URLs and updating in place..."
        # sync matters whenever a submodule URL changes (e.g. bzip2 moving to the
        # GitHub mirror): the cached .git/config still holds the old remote.
        git submodule sync --recursive
        git submodule update --init --recursive --force --jobs 4
        rc=$?
    else
        echo "No submodule cache — cloning shallow..."
        # restore-keys may have loaded partial cache content with dangling .git file
        # pointers (the worktrees exist but .git/modules/ doesn't). Deinit clears
        # these so update --init can re-clone cleanly.
        git submodule deinit --all -f 2>/dev/null || true
        git submodule update --init --recursive --depth 1 --jobs 4
        rc=$?
    fi

    missing="$(incomplete_submodules)"

    if [ "$rc" -ne 0 ] || [ -n "$missing" ]; then
        # Serial and forced: fixes the .git/shallow race and checks out worktrees the
        # aborted pass left empty. The sleep is for transient upstream 5xx responses.
        echo "::warning::Submodule init incomplete (git exit $rc) — retrying serially in ${delay}s"
        sleep "$delay"
        git submodule update --init --recursive --force --jobs 1
        rc=$?
        missing="$(incomplete_submodules)"
    fi

    if [ "$rc" -ne 0 ] || [ -n "$missing" ]; then
        # Last resort: a shallow clone stays shallow on refetch, so wipe and re-clone
        # with full history.
        echo "::warning::Retry incomplete (git exit $rc) — re-cloning with full history in $((delay * 3))s"
        sleep "$((delay * 3))"
        git submodule deinit --all -f 2>/dev/null || true
        git submodule update --init --recursive --force --jobs 4
        rc=$?
        missing="$(incomplete_submodules)"
    fi

    if [ "$rc" -ne 0 ] || [ -n "$missing" ]; then
        report_and_exit "$missing" "$rc"
    fi

    echo "Submodule init complete."
}

# Sourcing (Scripts/tests/test-ci-init-submodules.sh) loads the functions only.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
