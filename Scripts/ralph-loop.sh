#!/usr/bin/env bash
set -euo pipefail

# Ralph Loop: Autonomous agent development script
# Usage: ./Scripts/ralph-loop.sh <issue-number>
#
# Fetches a GitHub issue, creates a branch, runs Claude Code,
# validates changes, and creates a PR.

ISSUE_NUM="${1:-}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BASE_BRANCH="develop"

usage() {
    echo "Usage: $0 <issue-number>"
    echo ""
    echo "Fetches a GitHub issue, runs Claude Code to implement it,"
    echo "validates changes, and creates a PR."
    exit 1
}

log() {
    echo "[ralph] $(date '+%H:%M:%S') $*"
}

error() {
    echo "[ralph] ERROR: $*" >&2
    exit 1
}

# Validate arguments
if [[ -z "$ISSUE_NUM" ]]; then
    usage
fi

# Check prerequisites
command -v gh >/dev/null 2>&1 || error "gh CLI is required"
command -v claude >/dev/null 2>&1 || error "claude CLI is required"

# Fetch issue details
log "Fetching issue #${ISSUE_NUM}..."
ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" --json title -q .title)
ISSUE_BODY=$(gh issue view "$ISSUE_NUM" --json body -q .body)
ISSUE_LABELS=$(gh issue view "$ISSUE_NUM" --json labels -q '[.labels[].name] | join(",")')

if [[ -z "$ISSUE_TITLE" ]]; then
    error "Could not fetch issue #${ISSUE_NUM}"
fi

log "Issue: ${ISSUE_TITLE}"

# Label issue as in-progress
gh issue edit "$ISSUE_NUM" --add-label "agent-in-progress" 2>/dev/null || true

# Create branch from develop
BRANCH_NAME="agent/issue-${ISSUE_NUM}"
log "Creating branch: ${BRANCH_NAME}"
git fetch origin "$BASE_BRANCH"
git checkout -b "$BRANCH_NAME" "origin/${BASE_BRANCH}"

# Run Claude Code
log "Running Claude Code..."
PROMPT="You are implementing a GitHub issue for the Provenance emulator app.

## Issue #${ISSUE_NUM}: ${ISSUE_TITLE}

${ISSUE_BODY}

## Instructions
1. Read CLAUDE.md for project conventions
2. Implement the changes described in the issue
3. Follow the acceptance criteria exactly
4. Run validation (swift build/test) on affected modules
5. Keep changes focused and well-documented
6. Use conventional commit messages (fix:, feat:, etc.)"

claude --print "$PROMPT" || {
    log "Claude Code exited with non-zero status"
    gh issue edit "$ISSUE_NUM" --add-label "agent-blocked" --remove-label "agent-in-progress" 2>/dev/null || true
    error "Claude Code failed"
}

# Validate changes
log "Validating changes..."
CHANGED_MODULES=$(git diff --name-only "origin/${BASE_BRANCH}" | grep -oP '^(PV\w+)/' | sort -u || true)

VALIDATION_FAILED=false
for MODULE in $CHANGED_MODULES; do
    MODULE="${MODULE%/}"
    if [[ -f "${MODULE}/Package.swift" ]]; then
        log "Building ${MODULE}..."
        if ! (cd "$MODULE" && swift build 2>&1 | tail -5); then
            log "WARNING: ${MODULE} build failed"
            VALIDATION_FAILED=true
        fi

        log "Testing ${MODULE}..."
        if ! (cd "$MODULE" && swift test 2>&1 | tail -10); then
            log "WARNING: ${MODULE} tests failed"
            VALIDATION_FAILED=true
        fi
    fi
done

if [[ "$VALIDATION_FAILED" == "true" ]]; then
    log "WARNING: Some validations failed, but continuing with PR creation"
fi

# Check if there are changes to commit
if git diff --quiet && git diff --cached --quiet; then
    log "No changes were made"
    gh issue edit "$ISSUE_NUM" --add-label "agent-blocked" --remove-label "agent-in-progress" 2>/dev/null || true
    error "No changes to commit"
fi

# Push and create PR
log "Pushing branch..."
git push -u origin "$BRANCH_NAME"

log "Creating PR..."
PR_URL=$(gh pr create \
    --title "[Agent] ${ISSUE_TITLE}" \
    --base "$BASE_BRANCH" \
    --label "agent-review" \
    --body "$(cat <<EOF
## Summary
Automated implementation of #${ISSUE_NUM}.

## Changes
$(git log --oneline "origin/${BASE_BRANCH}..HEAD" | sed 's/^/- /')

## Validation
$(if [[ "$VALIDATION_FAILED" == "true" ]]; then echo "⚠️ Some validations failed — manual review needed"; else echo "✅ All module builds and tests passed"; fi)

## Test Plan
- [ ] Review generated code for correctness
- [ ] Verify acceptance criteria from #${ISSUE_NUM}
- [ ] Run full test suite if needed

Closes #${ISSUE_NUM}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)")

# Update issue labels
gh issue edit "$ISSUE_NUM" --add-label "agent-review" --remove-label "agent-in-progress" 2>/dev/null || true

log "PR created: ${PR_URL}"
log "Done!"
