# Changelog Fragments

This directory stores **per-PR changelog fragments**. Each open PR that has user-visible changes drops a small Markdown file here instead of editing `CHANGELOG.md` directly. This eliminates merge conflicts between concurrent PRs.

## How it works

When a PR merges to `develop`, the `consolidate-changelog.yml` workflow:
1. Reads all `*.md` files in this directory
2. Extracts the PR number from the filename
3. Appends `(#NNNN)` to every entry that lacks one
4. Inserts entries into the right section of `CHANGELOG.md`
5. Sorts by PR number (newest first within each section), deduplicates
6. Deletes the processed fragment files
7. Commits the result directly to `develop`

## File naming

Name the file after the PR number: **`NNNN.md`** (e.g. `3064.md`).

If you are writing the fragment before the PR exists (unusual), use any unique name —
the consolidation script will look up the PR number from the GitHub API using the branch name.

## Fragment format

Use standard Markdown section headers matching CHANGELOG subsections:

```markdown
### Added
- **My Feature Name** — One-sentence description of what was added.

### Fixed
- **Bug I Fixed** — One sentence saying what was broken and what the fix is.

### Changed
- **Thing I Refactored** — Why the behavior or API changed.
```

Rules:
- **One or more sections per file** — only include sections that apply.
- **`(#NNNN)` is optional** — the consolidation script adds it automatically from the filename.
- **Plain English, no trailing period** — match existing changelog style.
- **Do NOT edit `CHANGELOG.md` directly** — use a fragment file instead.

## Sections

| Section header | Use for |
|---|---|
| `### Added` | New features, new UI, new APIs |
| `### Fixed` | Bug fixes, crash fixes |
| `### Changed` | Refactors, behavior changes, API changes |
| `### CI / Infrastructure` | Build system, CI/CD, internal tooling (rarely user-visible) |

## Example

File `.changelog/3099.md`:
```markdown
### Added
- **Custom Shader Presets** — Users can now save and restore shader configurations per-game.

### Fixed
- **GameCube Boot Crash** — Fixed a crash when launching GameCube games with no BIOS set.
```

After consolidation this becomes two entries in `CHANGELOG.md [Unreleased]`:
```markdown
### Added
- **Custom Shader Presets** — Users can now save and restore shader configurations per-game. (#3099)

### Fixed
- **GameCube Boot Crash** — Fixed a crash when launching GameCube games with no BIOS set. (#3099)
```
