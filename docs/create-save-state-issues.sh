#!/bin/bash
# Create GitHub issues for the save state version mismatch epic.
# Requires: gh CLI (brew install gh) and authentication (gh auth login)
#
# Usage: ./docs/create-save-state-issues.sh

set -e
REPO="${REPO:-Provenance-EMU/Provenance}"
LABELS="save-states,core-version,agent-work"

# Master ticket
gh issue create --repo "$REPO" \
  --title "[Agent] Save State Version Mismatch Detection & UX" \
  --label "$LABELS,high-priority" \
  --body-file - <<'BODY'
See `docs/save-state-version-mismatch-tickets.md` for full spec.

**Objective:** Introduce a unified flow to check save states against the current core version before load, present clear UI when there is a version mismatch, and allow users to load anyway with an explicit warning.

**Priority:** High (next release)
BODY

# Sub-tickets can be created similarly; adjust titles and bodies as needed.
echo "Master issue created. Create sub-issues manually or extend this script."
echo "Labels to use: $LABELS"
