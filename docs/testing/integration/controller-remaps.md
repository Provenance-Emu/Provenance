# Controller remaps: consolidated test checklist

Part of the [consolidated develop validation run](../2026-10-29-develop-integration.md).

## Controller remaps — deferred integration/hardware checks

Evidence baseline: source `9f92c1ae4f`; 80/80 synthetic-controller cases passed in a separate simulator probe. Native Mednafen SNES/NES and snes9x each completed 60 synthetic-ROM frames. Thin used the production frontend with a simulator input-echo plugin. This does not establish full-app UI, hardware, tvOS runtime, or real thin-core gameplay coverage.

Run these after the parallel work has been integrated into the consolidated develop test build. Record build SHA, platform, controller vendor/model, game/core and evidence for each result. Leave checks pending until actually exercised.

- [ ] **Physical controller, native cores:** on iOS, use a Bluetooth/USB gamepad with native Mednafen SNES, Mednafen NES and snes9x. Test identity, Swap A/B, Swap X/Y, both swaps and clearing mappings. Verify presses and releases; on NES verify the existing X/Y alternate A/B bindings rather than nonexistent NES X/Y buttons. Check another controller/vendor stays on its own saved mapping and reconnect preserves the intended mapping/player assignment.
- [ ] **Settings persistence and real handoff:** create/edit/clear the remaps through Settings → Controllers, launch each native core through the normal app flow, and repeat after app restart and controller reconnect. Confirm vendor identification and player slots reach the expected core without relying on a probe-assigned controller.
- [ ] **Mid-session notification/reassignment:** with a game running, change identity → A/B → both → cleared through the actual app UI. Verify PVEmulatorViewController's mapping-change observer reassigns controllers, including creating the first wrapper and restoring identity when cleared, with no app/game restart or stuck buttons. The probe explicitly reassigned controller1 between modes and did not exercise this observer.
- [ ] **Real thin-core gameplay, one remap only:** repeat the matrix with bsnes and/or thin snes9x, using the same game/controller as native SNES. Compare guest inputs after the frontend's normal MFi-to-Nintendo layout conversion; a user swap must invert the relevant pair once, and clearing must restore the baseline. The input-echo plugin passed but was not a real emulator core.
- [ ] **tvOS runtime:** repeat the native/real-thin remap matrix and in-session Settings flow on the consolidated tvOS app with a supported controller. Previous tvOS compile/unit checks do not establish runtime remap behavior.
- [ ] **Switch Online/Joy-Con hardware regression:** exercise the physical-profile Switch Online SNES pad on native and thin, checking printed-label baseline, manual A/B and X/Y swaps, Start/Select and pause/Home behavior through PVPhysicalProfileController. Clear stale workaround mappings when establishing baseline. Check Joy-Con default auto-swap applies once and saved manual mappings still take precedence.

Persistent evidence: `/Users/jmattiello/.codex/visualizations/2026/10/26/01a17895-8112-77e1-a6ec-5908d02edfdc/controller-remap-runtime/README.md` (same directory contains raw/enriched JSON, screenshot and reproduction sources). No production remap changes are awaiting integration; d167e46f8b, 9e799425d7 and eb1949fd29 are already on develop.

## Completed validation

- Production changes are already on develop: `d167e46f8b` (shared native remapping), `9e799425d7` (PVCoreBridgeTests repairs), `eb1949fd29` (CI job). No remap implementation is waiting for a cherry-pick.
- [Full CI run 40952893206](https://github.com/Provenance-Emu/Provenance/actions/runs/40952893206) passed on `bae478d1ed`: smoke build, PVCoreBridge, thin, PVLibrary, PVUI iOS/tvOS and all eight standalone packages. This predates the latest parallel UI changes and is not validation of the final consolidated build.
- Isolated runtime probe: 80/80 cases passed on `9f92c1ae4f`, iPhone 17 Pro / iOS 26.5. The screenshot and raw JSON are preserved with reproduction sources. Each native core's 60 completed frames were asserted via its frame-completion callback. Thin's actual `retro_run` input mask matched the once-remapped expected mask; a double swap would fail.

## Evidence and cleanup

Persistent evidence directory (local to this Mac):

`/Users/jmattiello/.codex/visualizations/2026/10/26/01a17895-8112-77e1-a6ec-5908d02edfdc/controller-remap-runtime/`

Preserve `README.md`, `remap-runtime.raw.json`, `remap-runtime.json`, `screenshot.png`, `App.swift`, `Run.swift`, `project.yml`, `probe.c`, fixture ROMs, `snes9x-observer.patch`, `input_echo.dylib`, `Package.resolved`, `build-success.log.gz`, and `SHA256SUMS.json`. The observer was test-only, retained the original engine call, and was never applied to the shared checkout. No upstream submodule source was modified.

Cleanup removes only this chat's temporary `/tmp/provenance-remap-runtime` clone, `/tmp/remap-runtime-dd` derived data, named probe logs/captures, and the dedicated `PV Remap Runtime` simulator (`0C87C07F-EFA1-4389-A9C8-57716BCCCBE9`, bundle `org.provenance.remap.runtime`). Dependency symlinks in the clone are unlinked rather than traversed. No shared build directory, other simulator/worktree, staged change, or other agent's source belongs to this cleanup. The live preview ends when that dedicated simulator is removed; its saved screenshot remains evidence.

Cleanup outcome: complete. The two temporary directories and dedicated simulator are absent; the evidence archive and original 80-case JSON/screenshot were verified intact. No additional builds were started. Other agents' files, shared caches/build outputs and staged changes were left intact.
