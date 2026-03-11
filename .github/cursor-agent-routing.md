# Cursor Agent Routing

This repository supports a hybrid Cursor setup:

- Manual GitHub app usage with `@cursor` on issues and PRs
- Workflow-driven PR follow-up with `@cursoragent` on open PR comments
- Automated workflow dispatch through `.github/workflows/cursor-agent.yml`

## Setup

1. Install the Cursor GitHub app for this repository so `@cursor` comments can open or update work directly from GitHub.
2. Add a `CURSOR_API_KEY` GitHub Actions secret so workflow-dispatched Cursor runs can execute in CI, including `@cursoragent` follow-ups on existing PRs.

## Routing

- Use `@cursor` on high-priority or nearly-complete issues/PRs when you want immediate manual intervention from Cursor's GitHub app.
- Use `@cursoragent` on an existing PR comment when you want the GitHub Actions Cursor lane to pick up focused follow-up work on that PR branch.
- Use the `cursor-work` label to route issue implementation into the automated Cursor workflow lane.
- Keep `agent-work` for Claude/Kimi-owned issues.
- Do not intentionally apply both `cursor-work` and `agent-work` to the same issue at the same time.

## PR Ownership

- Cursor-created or Cursor-updated PRs should keep `[Agent]` titles so they reuse the existing review pipeline.
- Cursor-owned PRs should carry both `agent-work` and `cursor-work`.
- `ai-review.yml` remains the shared reviewer for all `[Agent]` PRs.
- Follow-up actions such as AI review fixes and ready-for-review handoff are routed based on `cursor-work`.

## Recommended Usage Over The Next 48 Hours

- Put `cursor-work` on curated epics and bug fixes that are almost ready to land.
- Use `@cursor` on existing PRs when you want focused follow-up through the Cursor GitHub app.
- Use `@cursoragent` on existing PRs when you want the repository workflow to perform the follow-up instead.
- Keep Claude/Kimi as the primary lane for existing `agent-work` issues unless a fallback is needed.
