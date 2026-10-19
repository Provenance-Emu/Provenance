#!/usr/bin/env bash
# PostToolUse hook: lint a changed Swift file with SwiftLint and surface any
# violations back to Claude (exit code 2) so they get fixed at edit time
# instead of at PR time. Reads the tool-call payload JSON from stdin.
#
# DIFF-AWARE: only violations on lines the current edit actually touched
# (working-tree + staged diff vs HEAD) are reported, so pre-existing whole-file
# debt (e.g. type_body_length, legacy force_unwrapping) doesn't block unrelated
# edits. New/untracked files are linted in full; outside a git repo it falls
# back to full-file linting.
#
# Wired up in .claude/settings.json under hooks.PostToolUse (matcher Edit|Write|MultiEdit).
# Safe no-op when: file isn't Swift, lives in an excluded dir, or swiftlint is absent.
set -uo pipefail

file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file" ] && exit 0

# Swift sources only.
case "$file" in
  *.swift) ;;
  *) exit 0 ;;
esac

# Skip third-party / generated / non-linted areas (mirrors .swiftlint.yml excludes).
case "$file" in
  */Cores/*|*/CoresRetro/*|*/Carthage/*|*/.build/*|*/Scripts/*|*/fastlane/*|*/Dependencies/*)
    exit 0 ;;
esac

[ -f "$file" ] || exit 0

# Locate swiftlint (PATH, then common Homebrew locations).
SWIFTLINT="$(command -v swiftlint 2>/dev/null || true)"
[ -z "$SWIFTLINT" ] && [ -x /opt/homebrew/bin/swiftlint ] && SWIFTLINT=/opt/homebrew/bin/swiftlint
[ -z "$SWIFTLINT" ] && [ -x /usr/local/bin/swiftlint ] && SWIFTLINT=/usr/local/bin/swiftlint
[ -z "$SWIFTLINT" ] && exit 0   # not installed — don't break the workflow

# Positional arg (NOT --path): --path makes swiftlint honor the config's
# `included:` (only 6 dirs) and skip everything else; the positional form
# lints the given file directly using the project's rule config.
out="$("$SWIFTLINT" lint --quiet "$file" 2>/dev/null)"
[ -z "$out" ] && exit 0

# Determine which line numbers this edit changed (NEW side of the diff vs HEAD).
# changed_lines="ALL" means lint the whole file (new file or not a git repo).
dir="$(dirname "$file")"
changed_lines="ALL"
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$dir" ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
    # Tracked file: union of +ranges from unstaged and staged diffs (-U0 → no context).
    # Emit as a single space-separated line (awk -v can't take embedded newlines).
    changed_lines="$(
      { git -C "$dir" diff -U0 --no-color -- "$file" 2>/dev/null
        git -C "$dir" diff -U0 --no-color --cached -- "$file" 2>/dev/null; } \
      | awk '
        /^@@/ {
          plus=$3                 # third field is the +c,d side
          sub(/^\+/,"",plus)
          n=split(plus,arr,",")
          start=arr[1]+0
          len=(n>1?arr[2]+0:1)
          for (i=0;i<len;i++) print start+i
        }' | sort -un | tr '\n' ' '
    )"
    [ -z "${changed_lines// /}" ] && changed_lines="ALL"
  fi
  # else: untracked/new file -> keep "ALL"
fi

# Filter swiftlint output to violations on changed lines (unless linting in full).
if [ "$changed_lines" != "ALL" ]; then
  out="$(printf '%s\n' "$out" | awk -v lines="$changed_lines" '
    BEGIN { n=split(lines,a,/[ \t]+/); for (i=1;i<=n;i++) if (a[i]!="") ok[a[i]+0]=1 }
    {
      # swiftlint line format: <path>:LINE:COL: severity: message
      if (match($0, /:[0-9]+:[0-9]+:/)) {
        rest=substr($0, RSTART+1)
        split(rest, p, ":")
        if ((p[1]+0) in ok) print $0
      }
    }')"
fi

[ -z "$out" ] && exit 0

# Violations on changed lines — exit 2 feeds stderr back to Claude as actionable feedback.
{
  echo "SwiftLint violations on lines you changed in $file — fix these before continuing:"
  echo "$out"
} >&2
exit 2
