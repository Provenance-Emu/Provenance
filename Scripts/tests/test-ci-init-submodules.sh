#!/bin/bash
# test-ci-init-submodules.sh
# Checks that Scripts/ci/ci-init-submodules.sh notices a submodule tree that git
# left half-built, using local file:// repositories (no network).
#
# The fixture reproduces the 2026-10-06 CI failure: superproject with submodules
# a, b, c, where b pins a nested submodule (b/ext) at a commit its remote does not
# have. `git submodule update --init --recursive --jobs 4` clones a, b and c,
# checks out a and b, fails to recurse into b, and stops — leaving c cloned with
# HEAD at its gitlink (so `git submodule status` shows it clean) but no files.
# A fourth submodule lives at "d e/f": real paths contain spaces
# (Dependencies/SWCompression/Tests/Test Files) and must not be split.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/Scripts/ci/ci-init-submodules.sh"

# Keep the developer's git config out of it, and allow file:// submodules.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always
export GIT_CONFIG_KEY_1=user.name GIT_CONFIG_VALUE_1=test
export GIT_CONFIG_KEY_2=user.email GIT_CONFIG_VALUE_2=test@example.invalid
export CI_SUBMODULE_RETRY_DELAY=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

make_repo() {
    git init -q -b main "$1"
    echo "$1" > "$1/README"
    echo "// $1" > "$1/Package.swift"
    git -C "$1" add .
    git -C "$1" commit -qm init
}

# make_super <dir> <broken: yes|no>
make_super() {
    local root="$1" broken="$2" r
    mkdir -p "$root"
    (
        cd "$root" || exit 1
        for r in leaf a b c d; do make_repo "$r"; done
        git -C b submodule add -q "file://$root/leaf" ext
        if [ "$broken" = yes ]; then
            # A commit the leaf remote does not have, like hidapi's pin while
            # github.com was unreachable.
            git -C b update-index --cacheinfo 160000,d6b2a974608dec3b76fb1e36c189f22b9cf3650c,ext
        fi
        git -C b commit -qm nested
        make_repo super
        for r in a b c; do git -C super submodule add -q "file://$root/$r" "$r"; done
        git -C super submodule add -q "file://$root/d" "d e/f"
        git -C super commit -qm submodules
        git clone -q "file://$root/super" work
    )
}

# Runs incomplete_submodules in the current directory with the fixture's own
# sentinel file in place of the real repo's.
verify() {
    (
        # shellcheck source=Scripts/ci/ci-init-submodules.sh
        source "$INIT_SCRIPT"
        # shellcheck disable=SC2034  # read by incomplete_submodules
        REQUIRED_FILES=("c/Package.swift")
        incomplete_submodules
    ) 2>/dev/null
}

# expect_contains <name> <haystack> <needle>
expect_contains() {
    if grep -qF -- "$3" <<< "$2"; then pass "$1"; else fail "$1 — expected '$3' in: $2"; fi
}

# ── good tree ────────────────────────────────────────────────────────────────
make_super "$TMP/good" no
cd "$TMP/good/work" || exit 1

out="$(bash "$INIT_SCRIPT" 2>&1)"
rc=$?
# The real repo's sentinel does not exist here, so a fresh clone reports only it.
if [ "$rc" -eq 1 ] && grep -qF "not initialized: Cores/4DO/Package.swift (missing)" <<< "$out" \
    && [ "$(grep -c 'not initialized:' <<< "$out")" -eq 1 ]; then
    pass "complete tree: only the absent sentinel file is reported"
else
    fail "complete tree: rc=$rc output: $out"
fi

out="$(verify)"
if [ -z "$out" ]; then pass "complete tree verifies clean"; else
    fail "complete tree verifies clean — got: $out"; fi

mkdir -p Cores/4DO && echo "// stub" > Cores/4DO/Package.swift
out="$(bash "$INIT_SCRIPT" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && grep -qF "Submodule cache restored" <<< "$out" && grep -qF "Submodule init complete." <<< "$out"; then
    pass "cached tree: script succeeds"
else
    fail "cached tree: rc=$rc output: $out"
fi

git submodule deinit -q -f a "d e/f"
out="$(verify)"
expect_contains "deinited submodule is reported" "$out" "a (not cloned)"
expect_contains "deinited path with a space is reported whole" "$out" "d e/f (not cloned)"
git submodule update -q --init a "d e/f"
out="$(verify)"
if [ -z "$out" ]; then pass "re-inited tree verifies clean"; else
    fail "re-inited tree verifies clean — got: $out"; fi

rm -rf .git/modules/a
expect_contains "broken git dir fails status" "$(verify)" "git submodule status --recursive failed"

# ── broken tree (the 2026-10-06 failure) ─────────────────────────────────────
make_super "$TMP/broken" yes
cd "$TMP/broken/work" || exit 1

git submodule update -q --init --recursive --depth 1 --jobs 4 >/dev/null 2>&1
git_rc=$?
if [ "$git_rc" -ne 0 ]; then pass "git reports the nested failure (exit $git_rc)"; else
    fail "git reports the nested failure — exited 0"; fi

status="$(git submodule status --recursive 2>/dev/null)"
if ! grep -q '^-' <<< "$status"; then
    pass "repro: old '-' check sees nothing wrong"
else
    fail "repro: old '-' check should miss this — status: $status"
fi

out="$(verify)"
expect_contains "cloned-but-empty submodule is reported" "$out" "c (empty worktree)"
expect_contains "nested submodule at the wrong commit is reported" "$out" "b/ext (checked out at the wrong commit)"
expect_contains "missing sentinel file is reported" "$out" "c/Package.swift (missing)"
expect_contains "path with a space is reported whole" "$out" "d e/f (empty worktree)"
if grep -q '^a ' <<< "$out"; then fail "checked-out submodule a is not reported — got: $out"; else
    pass "checked-out submodule a is not reported"; fi

out="$(bash "$INIT_SCRIPT" 2>&1)"
rc=$?
if [ "$rc" -eq 1 ]; then pass "script fails on a broken tree"; else fail "script fails on a broken tree — rc=$rc"; fi
expect_contains "script retries" "$out" "retrying serially"
expect_contains "script names the empty submodule" "$out" "::error::  not initialized: c (empty worktree)"
expect_contains "script names the failing nested submodule" "$out" "::error::  not initialized: b/ext"
if grep -qF "Submodule init complete." <<< "$out"; then fail "script must not claim success"; else
    pass "script does not claim success"; fi

# ── report ordering ──────────────────────────────────────────────────────────
out="$(
    # shellcheck source=Scripts/ci/ci-init-submodules.sh
    source "$INIT_SCRIPT"
    report_and_exit "$(printf '%s\n' "a (empty worktree)" "b/ext (not cloned)" "c (checked out at the wrong commit)" "d/x (not cloned)")" 128
)"
rc=$?
order="$(grep 'not initialized:' <<< "$out" | sed 's/.*not initialized: //' | tr '\n' '|')"
if [ "$rc" -eq 1 ] && [ "$order" = "b/ext (not cloned)|d/x (not cloned)|a (empty worktree)|c (checked out at the wrong commit)|" ]; then
    pass "report lists not-cloned paths first, others in original order"
else
    fail "report ordering — rc=$rc order: $order"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "All ci-init-submodules tests passed."
else
    echo "$FAILS ci-init-submodules test(s) failed."
    exit 1
fi
