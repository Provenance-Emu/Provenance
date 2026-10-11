# Local branch and worktree triage (2026-10-11)

These were cleared out of the maintainer's local checkout: 104 local branches and 11 worktrees.
This file records what was unfinished so it doesn't get lost.

## Kept: unfinished work worth resuming

| Branch | State | What it is | Next step |
|---|---|---|---|
| `pr-3518` | PR #3518 open | Cloudflare Worker cheat proxy for GameHacking.org (`Scripts/cheat-proxy/`), with five rounds of Copilot fixes | Merge, then run `wrangler deploy` and put the Worker URL in `GameHackingOrgLookup.swift` |
| `pr-3608` / `agent/issue-3601` | PR #3608 open (same 2 commits, rebased twice) | Replaces `SideNavigationController` with a SwiftUI side-menu container; fixes a leaked NotificationCenter observer in `PVRootViewNavigationController` | Rebase onto develop (it predates the Oct UI work), then review. Delete `agent/issue-3601` once the PR is settled |
| `agent/bg-crash-visibility` | no PR, Aug 14 | MetricKit jetsam/0xdead10cc exit metrics; app-extension termination detection via App Group run markers (`ExtensionRunMarker` + tests); Spotlight/TopShelf Realm reads bounded, primary-key sort for stable index batches | Not on develop. Develop has since added read-only extension Realm configs (`145b8bb25a`, `c0b87ebd26`), so rebase and drop whatever overlaps |
| `feature/lost-files-scanner` | no PR, Jun 8 | Design spec only: `docs/superpowers/specs/2026-06-08-lost-files-scanner-design.md` (library health / orphaned-file scanner) | Land the spec on develop or fold it into the importer roadmap |

## Archived (deleted locally, tips saved under `refs/archive/<branch>`)

Restore any of them with `git branch <name> refs/archive/<name>`.
List them with `git for-each-ref refs/archive`.

- **Merged by squash or PR, nothing left to do:** feature/prune-dead-cores (#3731), feature/macos-desktop-input (#3664, which also contains the Aug agent branches catalyst-audit, bios-wiki-link, library-keyboard-nav, macos-library-layout and worktree-agent-a7ee3d8e/ae7c2001/afdf48fd), feature/macos-desktop-polish (#3660), pr-3523, pr-3618, the #3636/#3637/#3645/#3646/#3649/#3650/#3662/#3663 fix branches, pr/issue-3179..3189 (#3191–#3200), fix/libretro-scanner-feature-flag (#3118), fix/mupen-rumble-haptic-fallback (#3110), feature/new-cores/fMSX (#2372).
- **Closed or superseded:** pr-3681, pr-3667, pr/issue-3188, pr3641merge, test-rebase-2560.
- **Old experiments, now obsolete** (the core was pruned, the thick RetroArch wrapper was removed, or the work was redone on develop):
  - Dead cores: feature/CorePVBeetlePSX, feature/desmume2015, feature/ReicastPortSPM.
  - Flycast: feature/flycastRedo, feature/flycastRedo2, feature/new-cores/libretrogles.
  - feature/MupenGlidenEtcUpdate: GLideN64 later went in via feature/gliden64-upstream.
  - feature/Core_Azahar: Azahar now ships on develop.
  - feature/AirPlay: RetroArch pointer changes, thick wrapper.
  - feature/CheatsSwiftUI: the cheats UI was rebuilt since.
  - iCloud sync: feature/iCloudSyncV2, pullrequests/pabloarista/feature/iCloud-sync-v1 (CloudKit syncers replaced it).
  - bugfix/SegaCDGenesisPlus: a failed attempt.
  - Others: feature/betterScreenshotsRetroCores, develop-testflight, the emuthreeRebirth branches, worktree-agent-a64f230a (input diag).

The remaining ~40 branches were already fully on develop (every patch present) and were dropped without an archive ref.
