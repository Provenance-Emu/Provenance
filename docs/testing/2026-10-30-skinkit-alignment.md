# SkinKit three-app release baseline

This pass follows the completed October 30 TestFlights. It does not replace those builds or publish a version tag.

## Ownership

- Shared SkinKit #33 (trait changes) and #42 (thumbnail point sizes), their reviews, and iFly adoption: the iFly release/design chat.
- Provenance and iCube dependency adoption and this compatibility matrix: the Top Shelf/netplay chat.
- Existing SkinKit sibling worktrees and Dolphin native build artifacts remain with their current owners.

## Shipped baseline

| Consumer | Source | SkinKit revision | iOS build | tvOS build |
| --- | --- | --- | --- | --- |
| Provenance 3.4.0 | `1b7ff7990fc91ae47926859af311dacab4b5a57e` | `f394638b2291f08df14ad315df3b7418704b9b20` | `1793353488` | `1793351045` |
| iFly 1.0.0 | app source `53108369`; release workflow repairs subsequently merged as `595d3c420` | `9f2e787424bf12ff0dbd0fbd2af2db7a37eafabf` | `1793396580` | `1793397267` |
| iCube 1.0.0 | `de88c801afba5f61ee0e996f1caef2b0ffe61f29` | `ede51db93663e0ccf3c5e7e4f5eace9cb1b5725b` | `1793395202` | `1793395259` |

All six builds finished processing and were available to external testers when checked. These are distinct from the forthcoming aligned dependency candidates.

## Alignment acceptance

Use the same immutable SkinKit commit in every consumer declaration and tracked resolver file. A future tag must identify that tested commit; do not point consumers at a moving branch or invent a version before the tag exists.

The final shared baseline is `599030369e2ed8d052618128e169e6d08405c527` (PR #46 merge), tree `17479746f2e71d1c1ce8d47fde00c66370dcbfc9`. It is byte-identical to the tested source head `5e01829e02fca1e0fea37e93e9b09d7a210199b9`; the equivalence is retained in `build/skinkit-alignment/source-equivalence.json`.

Run `python3 Scripts/dev/check_skinkit_alignment.py --expected-revision <full-SkinKit-SHA>` from Provenance. It scans every tracked package/project manifest (including Provenance's `PVTouchOverlay` dependency), iFly's resolver and every tracked Provenance resolver, including the skin demo/test apps. Use `--ifly` or `--icube` to inspect isolated consumer checkouts.

| Area | Required evidence | Result |
| --- | --- | --- |
| SkinKit #33 | One hosted view changes traits; artwork, controls and thumbsticks update; superseded loads cannot overwrite newer resources; held inputs are released safely | [PR #45](https://github.com/Provenance-Emu/SkinKit/pull/45) and its multi-touch follow-up [PR #46](https://github.com/Provenance-Emu/SkinKit/pull/46) merged; full local iOS 470 tests and all three final CI checks pass. The late review finding is addressed and resolved. |
| SkinKit #42 | Fresh thumbnails and disk-cache hits preserve the requested point dimensions and 2x raster density, including tvOS at display scale 1 | [PR #44](https://github.com/Provenance-Emu/SkinKit/pull/44) merged as `07aada49019db2022c166737646150ed2c042456`; local iOS 465 and 1x TV 448 tests pass, all three CI checks green, and the fix is included in the final baseline. |
| Shared suites | Full iOS and tvOS suites pass on the final shared revision | Final iOS, tvOS and macOS host CI all green. Optimized SkinKitUI Release builds also pass for arm64 iOS and tvOS device SDKs. |
| Provenance configuration | Existing bundled skins, manager selection, catalog cache migration, settings and theme integration pass against the new revision | Full PVUI iOS suite 647 passed, zero failures/skips on the final source tree, including six arcade mapping/fallback cases and the bundled-thumbnail test. An earlier `07aada4` API baseline also passed 647. |
| Provenance consumer | iOS/tvOS app compilation and native skin-view checks on the aligned revision | Both Coreless simulator app builds pass on `5990303`. Native iOS settings, system browser and portrait/landscape skin selectors render correctly; the fixture has no installed custom skins. Bundled artwork rendering is covered by the passing manager thumbnail test. Gameplay is not claimed. |
| iFly consumer | iOS/tvOS builds and skin behavior against the aligned revision | Both SDK builds and focused 71-test suites pass, zero failures/skips. Native phone artwork/resume/pause/quit and TV library checks pass. [PR #881](https://github.com/JoeMatt/iFly/pull/881) merged as `7e2ba56a03a319ea98cb5faf7b1f671269e27c84`, tree identical to its tested head; all CI/review checks clear. |
| iCube consumer | Existing skin model/layout/import/store/input/asset tests and iOS/tvOS compilation | iOS app/test compilation and all 146 tests from ten skin suites pass on `5990303`, zero failures/skips. TV app compilation passes. Simulator core reuse confirmed; all three protected native artifact hashes match. [PR #71](https://github.com/Provenance-Emu/iCube/pull/71) merged as `784d1735777a017155d6dbdf4485bea28e66c074`, tree identical to signed/tested head `66876f7`. Build, lint, review and the [hosted full test recovery](https://github.com/Provenance-Emu/iCube/actions/runs/41151900753) pass. The initial self-hosted test job could not start tests because its CoreSimulator service mismatched Xcode; its red result remains visible. |
| Pins | All three consumer declarations and tracked resolver files identify the same commit | Nine entries pass at `5990303`, including both Provenance direct dependencies and demo/test resolver files. iFly and iCube adoption are merged; Provenance publication pending. |
| Review | Scoped PRs, relevant checks, and no unresolved correctness findings | Shared fixes, iFly and iCube are reviewed and merged. Independent read-only review of the Provenance adoption found no actionable findings; its PR checks remain pending. |

## Consumer boundaries

Provenance and iFly use `SkinKitUI`; both receive the trait reload and thumbnail fixes. iFly-specific input and feedback behavior remains opt-in. Provenance retains its existing defaults and selection/storage hooks.

The newer core adds explicit NAOMI, NAOMI 2 and Atomiswave skin game types. Provenance's exhaustive reverse mapping must handle those cases; its existing arcade-to-Dreamcast default-skin fallback remains unchanged. Regression coverage checks both directions of this deliberately asymmetric mapping.

iCube uses `SkinKitCore`, `SkinCatalogKit`, and `SkinKitManager` on iOS/Catalyst. Its existing overlay, asset renderer, layout selection and storage remain app-owned. Aligning its dependency does not migrate it to `SkinKitUI` or introduce touch skins on tvOS.

## Evidence and remaining checks

Provenance/iCube alignment evidence will be stored under `build/skinkit-alignment/`; today's release evidence remains under `build/consolidated-validation/`. Preserve these ignored artifacts before retiring worktrees or clearing build caches.

This baseline does not certify physical-controller interaction or gameplay. Keep the outstanding device, cold-launch and multiplayer checks in [the combined integration checklist](2026-10-29-develop-integration.md) as app follow-ups; they are not additional gates for the initial SkinKit package tag. Later catalog, converter and skin-format work is outside this release baseline.
