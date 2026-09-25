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
#
# Usage: ci-init-submodules.sh
set -uo pipefail

# Paths git reports as not checked out ('-' prefix in submodule status).
uninitialized_submodules() {
    git submodule status --recursive 2>/dev/null | awk '/^-/ { print $2 }'
}

report_and_exit() {
    local missing="$1"
    echo "::error::Submodules are still not checked out after 3 attempts. The most" \
         "likely cause is an upstream host outage — check the log above for a" \
         "'fatal: unable to access' line naming the remote."
    while IFS= read -r sub; do
        [ -n "$sub" ] && echo "::error::  not initialized: $sub"
    done <<< "$missing"
    exit 1
}

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
else
    echo "No submodule cache — cloning shallow..."
    # restore-keys may have loaded partial cache content with dangling .git file
    # pointers (the worktrees exist but .git/modules/ doesn't). Deinit clears
    # these so update --init can re-clone cleanly.
    git submodule deinit --all -f 2>/dev/null || true
    git submodule update --init --recursive --depth 1 --jobs 4
fi

missing="$(uninitialized_submodules)"

if [ -n "$missing" ]; then
    # Serial and forced: fixes the .git/shallow race and checks out worktrees the
    # aborted pass left empty. The sleep is for transient upstream 5xx responses.
    echo "::warning::Submodule init incomplete — retrying serially in 15s"
    sleep 15
    git submodule update --init --recursive --force --jobs 1
    missing="$(uninitialized_submodules)"
fi

if [ -n "$missing" ]; then
    # Last resort: a shallow clone stays shallow on refetch, so wipe and re-clone
    # with full history.
    echo "::warning::Retry incomplete — re-cloning with full history in 45s"
    sleep 45
    git submodule deinit --all -f 2>/dev/null || true
    git submodule update --init --recursive --force --jobs 4
    missing="$(uninitialized_submodules)"
fi

[ -n "$missing" ] && report_and_exit "$missing"

echo "Submodule init complete."
