# Advanced settings and feature flags audit (2026-10-14)

Scope: every row in Settings › Advanced (`PVUI/Sources/PVSwiftUI/Settings/Views/AdvancedTogglesView.swift`,
`AdvancedSection` in `SettingsSwiftUI.swift`) and every entry in `PVFeatureFlags` (`PVFeature`,
`features.json`). For each: where it is read, what state the feature is in, and the decision.
The thin libretro wrapper is the only wrapper since 2026-10-03, which retires some of these.

## Done in this pass

| Item | Finding | Change |
|---|---|---|
| `dynamicLibretroScanner` flag | `Core.plist` lists all 110 cores enabled in `cores.yml`, so the scanner only adds dylibs not in the plist (sideloaded, migration off retired native cores). The flag defaulted on for tvOS and off for iOS, a leftover from the RetroArch-vs-thin era. | Flag removed (enum, static, JSON, manager property). `isDynamicScanEnabledForMerge` is now true unless the `dynamicLibretroScanner` UserDefaults key or debug override says false. CHANGELOG entry. |
| `enhancedArtworkSearch` JSON entry | No `PVFeature` case and no reader anywhere. | Removed from both `features.json` files. |
| `PVFeatureFlags/features.json` (repo root) | Stale copy with one entry; the bundled file under `Resources/` is what ships, the remote is `data.provenance-emu.com/features/features.json`. | Synced to the bundled content. Delete it if nothing publishes from it. |
| OpenGL Renderer toggle (`useMetal`) | `PVThinLibretroFrontend` forces `alwaysUseMetal`, so the toggle only affects native cores that do not force Metal. Still real for those. | Subtitle now says native cores only. |
| Overlay Style picker | A plain preference for the programmatic overlay; nothing experimental about it. | Moved to the Skins section. |

## Beta labels: owner decision

All of these are wired and read somewhere. The owner decided the promotions below on 2026-10-14 (Apple rejects "Beta" wording, so it is gone from every promoted string). The Recommendation column is the original; the Decision column is what shipped.

| Toggle (default) | Read by | State in code | Recommendation | Decision |
|---|---|---|---|---|
| Light Gun Crosshair (off) | `EmulatorWithSkinView` | Renders; style configured under Mouse / Light Gun. No beta label already. | Done. Consider default ON, or move the toggle next to the style picker. | Done 2026-10-14: default ON, toggle kept, subtitle without beta wording. |
| Tap to Remap (Beta, off) | `ControllerSettingsView` (mode button) | Press-mode remap UI exists; subtitle says "still rough". | Needs a device check. If press mode works for a full remap, drop "(Beta)". | Done 2026-10-14: always on; toggle and `Defaults[.tapToRemapUI]` removed (the `PVFeature.tapToRemapUI` case stays as a remote-config mirror). |
| Companion Controller (Beta, off) | pause menu (tile + retro) | Overlay works; subtitle says DSU integration incomplete. | Keep beta until `PVControllerDSU` pairing is verified on device. | Not changed: stays Beta, off. |
| Reposition Skin Buttons (Beta, off, iOS) | `EmulatorWithSkinView` | Drag editor for DeltaSkins. The programmatic overlay now has its own live editor (`PVTouchOverlay`), so two editors exist. | Decide: finish for DeltaSkins, or retire in favour of the overlay editor. | Done 2026-10-14: `skinButtonReposition` defaults ON, Advanced toggle removed; the editor entry point moves to the pause menu. |
| AirPlay Audio Menu (off) | pause menu | Audio route picker only. | Keep; "finish" = video AirPlay, a separate project. | Not changed. |
| Netplay (off) | lobby, settings, pause menu | Works for mGBA link cable and netpacket libretro cores; other native cores are stubs. Untested on devices since the Oct rebuild. | Keep off by default; label stays honest. | Done 2026-10-14: default ON, toggle kept, subtitle names the supported cores. |
| Live Broadcast (off) | pause menu | ReplayKit Go Live; subtitle says early. | Keep. | Not changed. |
| N64 Transfer Pak (off) | context menu, scene coordinator, pause menu, emulator VC | Full path exists on native and thin. | Candidate to default ON once device-verified. | Done 2026-10-14: default ON, toggle kept. |
| SRAM Import / Export (on, iOS) | `GameContextMenu` | Simple menu actions. | Done. Could stop being a toggle. | Done 2026-10-14: unconditional; toggle and `sramImportExport` key removed. |
| Case Companion Skins (off, iOS) | `CaseControllerSkinCoordinator`, skin selection | Wired (the May audit note asking "wire or remove" is resolved). | Keep as preference. | Not changed. |
| Use Modern Web Server (off) | `PVWebServerManager` | Hummingbird server; parity with GCDWebServer not documented. | Keep until parity is listed. | Not changed. |
| Auto JIT (off, non-App Store) | app delegate | Fine. | Keep. | Not changed. |
| Disable Auto Lock (off) | app delegate | Fine. | Keep. | Not changed. |
| iCloud Sync (non-App Store) | — | Fine. | Keep. | Not changed. |
| UI Mode picker | root view | `.uikit` kept the legacy `PVSettingsViewController` alive. | Done: UIKit mode and the legacy settings VC were removed; a stored "UIKit" value decodes to the platform default. | Done 2026-10-14: removed. |

## Remaining feature flags (remote-config style, keep)

`inAppFreeROMs` (non-App Store), `romPathMigrator` (always on; could be hard-coded), `contentlessCores`
(off; gates DOOM/Quake style cores), `tapToRemapUI`/`companionController`/`lightGunCrosshair`/
`skinButtonReposition`/`airPlayMenu` (mirrors of the Advanced toggles; the Defaults keys are what the UI reads).

`clipBuffering` was the one hidden flag with no Advanced toggle. Done 2026-10-14: promoted as "Gameplay Clips"
(Advanced toggle bound to `Defaults[.clipBufferingEnabled]`; the existing opt-in prompt is the only other gate) and
the flag is removed from `PVFeatureFlags` (enum case, static, both `features.json` files, manager property). The
pause menu Save Clip entries now read `Defaults[.clipBufferingEnabled]`.

## Other

- `FeatureFlagsDebugView` is reachable through `SecretSettingsRow` (Konami code on App Store builds) and
  lists `PVFeature.allCases`, so removing a case removes its row.
- `SettingsSearchIndex` does not index the Advanced toggles by title; add them if search should find them.
