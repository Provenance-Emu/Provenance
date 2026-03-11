# Save State Version Mismatch — PR Tracking

**Branch:** `agent/save-state-version-mismatch` (or per-sub-ticket branches)  
**Target:** `develop`  
**Labels:** `save-states`, `core-version`, `high-priority`, `[Agent]`  
**Copilot Review:** Enable via `@github/copilot-review` or existing AI review workflow

---

## PR Strategy

Prefer **small, focused PRs** per sub-ticket for easier review. Use this document to track PRs and ensure all launch paths are covered.

| PR | Sub-Ticket | Description | Status |
|----|------------|-------------|--------|
| 1 | #2 | Centralized `SaveStateVersionChecker` + alert flow | Pending |
| 2 | #1 | Add `createdWithCoreVersion` to view models & DTOs | Pending |
| 3 | #3 | Integrate version check into all launch paths | Pending |
| 4 | #4 | Reset game investigation (PicoDrive / general) | Pending |
| 5 | #6 | Wiki page + in-app link | Pending |
| 6 | #5 | Save state porting research (optional) | Pending |

---

## PR Template Additions

When opening PRs for this epic, include:

### What does this PR do

[Link to sub-ticket from `docs/save-state-version-mismatch-tickets.md`]

### Relevant tickets

- Master: Save State Version Mismatch Detection & UX
- Sub-ticket: [number and title]

### Tags / Labels to Apply

- `save-states`
- `core-version`
- `high-priority` (for master/launch-path PRs)
- `agent-work` (if from agent)
- `[Agent]` in PR title for AI review trigger

---

## Copilot / AI Review

- PRs from `agent/**` branches with `[Agent]` in title trigger `ai-review.yml` (see `.github/workflows/ai-review-trigger.yml`)
- Ensure `@github/copilot-review` or equivalent is enabled for the repo if using Copilot for PR review
- Reviewers: Check that version check is non-blocking (user can "Load Anyway") and that all launch paths are covered

---

## Checklist Before Merge

- [ ] All affected launch paths have version check or are documented as out of scope
- [ ] User can load save state after acknowledging version mismatch
- [ ] No regression: save states with matching version load without extra prompt
- [ ] SwiftLint passes on changed files
- [ ] Manual test on iOS and tvOS (or documented as Mac-only validation needed)
