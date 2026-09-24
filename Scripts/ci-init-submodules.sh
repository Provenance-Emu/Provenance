#!/usr/bin/env bash
#
# Initialize every submodule for a CI build.
#
# Shared by build.yml and testflight.yml. These two had their own copies of this
# logic and drifted: build.yml learned to retry the shallow-clone race while
# testflight.yml did not, so TestFlight failed every day for a week on a race the
# other workflow already recovered from. Keep the recovery in one place.
#
# Usage: ci-init-submodules.sh <cache-hit>   # "true" when the cache restored
set -uo pipefail

cache_hit="${1:-false}"

if [ "$cache_hit" = "true" ]; then
    echo "Submodule cache hit — syncing URLs and fetching updated refs..."
    git submodule sync --recursive
    git submodule update --init --recursive --force --jobs 4
else
    echo "Submodule cache miss — cleaning stale submodule refs and doing full clone..."
    # restore-keys may have loaded partial cache content with dangling .git file
    # pointers (the worktrees exist but .git/modules/ doesn't). Deinit clears
    # these so update --init can re-clone cleanly.
    git submodule deinit --all -f 2>/dev/null || true

    # `--depth 1 --jobs 4` races on .git/shallow ("shallow file has changed since
    # we read it"), which aborts the fetch mid-flight and then reports the gitlink
    # as unreachable — that is how Dolphin's Externals/SDL/SDL pin (a release tag
    # commit, only reachable by direct SHA fetch) started failing every build.
    if ! git submodule update --init --recursive --depth 1 --jobs 4; then
        # --force matters: the aborted first pass leaves some submodules registered
        # with an EMPTY worktree, and a plain update sees the recorded SHA and skips
        # the checkout (symptom: "Cores/VirtualJaguar/Package.swift doesn't exist").
        echo "::warning::Shallow submodule init failed — retrying serially"
        if ! git submodule update --init --recursive --force --jobs 1; then
            # Last resort: a shallow clone stays shallow on refetch, so wipe them
            # and clone with full history.
            echo "::warning::Retry failed — re-cloning submodules with full history"
            git submodule deinit --all -f 2>/dev/null || true
            git submodule update --init --recursive --force --jobs 4
        fi
    fi
fi

# An empty worktree here surfaces much later as a confusing SwiftPM error ("the
# package manifest at .../Package.swift cannot be accessed"), so name the actual
# culprit while the submodule step is still on screen.
git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | while read -r sub; do
    if [ -d "$sub" ] && [ -z "$(ls -A "$sub" 2>/dev/null)" ]; then
        echo "::warning::Submodule worktree is empty after init: $sub"
    fi
done

echo "Submodule init complete."
