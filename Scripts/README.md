# Scripts

Start with the maintenance tool rather than browsing this folder:

```bash
make maint          # web dashboard: what's stale, why, and Run buttons
make maint-status   # the same in the terminal
```

Every script here is registered in [`maint/jobs.toml`](maint/jobs.toml) with a
description, the exact command, and when it needs running. CI fails a pull
request that adds a script without registering it.

| Folder | What lives there |
|---|---|
| `maint/` | The maintenance tool, its registry, dashboard and tests ([README](maint/README.md)) |
| `generators/` | Scripts that write committed files: contributors, licenses, core lists, skins, UTIs, skin catalog, changelog, core versions |
| `audits/` | Read-only checks: controller mappings, localization, Xcode project sources, SPM modules |
| `release/` | Release, versioning, certificates, secrets, App Store media |
| `ci/` | Helpers only GitHub Actions calls |
| `build-phases/` | Called by Xcode build phases by path; moving them means editing `project.pbxproj` |
| `tests/` | Tests for the scripts above |
| `dev/` | One-off developer utilities (StikDebug JIT script, CI target generator, …) |

RetroArch core scripts stay in `CoresRetro/RetroArch/scripts/`, next to
`cores.yml` and the module downloader they serve; the registry covers them too.
