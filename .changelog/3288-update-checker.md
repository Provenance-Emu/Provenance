### Added
- **RetroArch dylib update checker** — `check-dylib-updates.sh` queries the buildbot for the latest nightly date, reports when a newer snapshot is available, and can auto-bump `cores.yml` with `--update`.
- **Staleness warning** — `get-modules.sh` now emits a build-time warning when `pinned_date` is more than 30 days old, prompting developers to run the update checker.
