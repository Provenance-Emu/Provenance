# Develop consolidation audit — 2026-10-30

Completed source is on `develop`: Claude's UIKit/alert cleanup `c6193f2770`, remote integration merge `094e7e0fc4`, netplay/theme checkpoints, Top Shelf artwork/cache follow-up `efdb839bfb`, SkinKit lockfile checkpoint `68d1fb56a8`, and resolved-color regression test `bb7a45198d`. The last two source checkpoints were pushed to `origin/develop`.

## Completed source branches

GitHub PR metadata confirms these merges; squash merges explain why some source commits are not ancestors of develop. Do not cherry-pick them again.

| Source | Integrated proof | Disposition |
| --- | --- | --- |
| `feature/debug-api` | PR #3773, `d064efa221` | Source preserved; device gameplay/cover evidence remains in the consolidated checklist. |
| `fix/skin-change-viewport` | PR #3776, `e9cbc662c7` | Integrated. |
| `docs/realm-to-swiftdata-plan` | PR #3772, `b68323ff71` | Docs integrated; no migration implementation implied. |
| `codex/topshelf-maint-registration` | PR #3775, `623070d35f` | Integrated; protected primary worktree retained. |
| `claude/dazzling-poitras-851dbb` | PR #3771, `6dc5956910` | Source integrated; owner checkpoint/evidence preserved. |
| `feature/skinkit-followups` | PR #3769, `680c44cc87` | Integrated; retain historical ref rather than replay old package/UI changes. |
| `fix/skinkit-swiftlint` | PR #3770, `3d6f7cc80c` | Patch-equivalent source confirmed by `git cherry`. |
| `fix/pvjit-dangling-debuggerutils-symlink` | PR #3767, `8fff8b3169` | Aggregate patch ID equals merged PR patch ID. |
| `codex/swiftui-lifecycle-integration` | PR #3755, `9301dffaf3` | Patch-equivalent source confirmed by `git cherry`. |
| Nearby receiver feature | PR #3753, `329295aad6` | Feature integrated; older `codex/icube-nearby-receiver-checkpoint` differs from final reviewed source and stays preserved. |
| Native-core integration | PR #3754, `12ccc3b07c` | Integrated. Older standalone Azahar/emuThree scratch refs stay preserved; do not replace the later package implementation with their snapshots. |

## Retired local branch names

Removed only unattached branches proven by `git merge-base --is-ancestor` to be ancestors of develop. All commits remain reachable from develop. No worktree or remote branch was removed in this step.

| Local branch | Preserved commit |
| --- | --- |
| `codex/core-spm-registry-fix` | `3b5e6cefdc` |
| `codex/ipa-packaging-disk-usage` | `aa364dbcf3` |
| `codex/libretro-package-ci-tests` | `3f94aaab48` |
| `codex/native-core-ci-build-fixes` | `076d173f58` |
| `codex/native-core-ci-followup` | `56379e749d` |
| `codex/native-core-spm-integration` | `7cf7fdac45` |

## Preserved work and evidence

- `codex/swiftui-library-lifecycle` is a mixed historical WIP snapshot. Reviewed netplay/theme/Claude changes have their own later checkpoints; do not blanket merge or delete the snapshot.
- Detached Claude scratch worktrees and the attached `maint/auto-local` checkout remain intact. Maintenance-job ownership must be checked before retiring its checkout.
- The completed Top Shelf CI chat cannot safely relocate through the available handoff tool: it moves associated Git state and offers no preserve-main-ref option. The unmanaged main checkout cannot be attached with `attach_worktree`; Codex UI automation was denied. Its clean primary worktree and archived evidence are retained; no manual bypass or source/ref switch was performed.
- Dolphin's working checkout is `de88c801af` rather than recorded gitlink `9c2ec2b673`, with three generated native-framework files dirty. Those upstream CI/dependency commits and artifacts were left untouched, outside this source checkpoint. Local builds must record that input; clean CI uses the committed gitlink.
- Separate iFly coordination: PR #875 is merged as `3b3373bf2`, #876 as `707f67e73`; its main checkout is clean and both feature worktrees/branch names were archived by their owner. Evidence: `../iFly-worktree-archives/2026-10-30/PR-INTEGRATION.md`. Active DreamPicoPort PR #877, the owner's subsequent `codex/combined-validation-fixes`, and the shared SkinKit #39 asset-fallback investigation remain untouched.

The exact build/test outcomes and outstanding hardware checks belong in [the consolidated checklist](../2026-10-29-develop-integration.md).
