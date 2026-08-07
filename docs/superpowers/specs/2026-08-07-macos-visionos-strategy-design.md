# macOS & visionOS Support Strategy — Design

**Date:** 2026-08-07
**Status:** Draft — awaiting review
**Scope:** Strategy + phased plan. No implementation in this doc.

## 1. Current state (audited 2026-08-07)

Four parallel codebase audits (build config, UI layer, core/rendering pipeline, visionOS footprint) established:

### What "Mac support" actually is today

- **There is no native macOS app target.** No app target sets `SDKROOT = macosx`. The
  "native mode" users see is **"Designed for iPad"** (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES`
  on every app target) — the unmodified iOS binary running on Apple Silicon.
- **Catalyst is declared but structurally broken.** Every app target sets
  `SUPPORTS_MACCATALYST = YES` and `TARGETED_DEVICE_FAMILY = 1,2,3,6`, but:
  - `SUPPORTED_PLATFORMS` omits `macosx` on every target.
  - `PVMetalViewController.swift` does not compile for the Catalyst SDK: `glContext` is never
    declared under Catalyst (guards at :239/:243 both exclude it, use at :2065 is unguarded), and
    `initializeOpenGLContext()` (defined only in the non-mac branch at :802) is called unguarded
    at :447 and :2067. There is a literal `#warning("macOS incomplete")` at :2108 (IOSurface↔GL
    binding has no mac path).
  - No Scaled-vs-Optimized idiom choice was ever recorded; no Mac CI; a dead
    platform-entitlements mechanism in `Build.xcconfig:90` (`MACOS_CODE_SIGN_ENTITLEMENTS`
    undefined + `PLATFORM_NAME` mismatch).
- **Orphaned native-mac artifacts:** `ThumbnailExtensionMacOS` (real `macosx` extension, no host
  app), two DriverKit drivers whose host app is iOS-only, `PVUIBase/AppKitWrapper.swift`
  typealias shim, ~64 dead `#if os(macOS)` sites in PVUI, and a commented-out
  `xcodegen/project_macos.yml` include that was never written.

### The decisive constraint: core binary supply chain

| Mac path | libretro dylibs available? | Why |
|---|---|---|
| Designed for iPad | **Yes, today** | It IS the iOS platform; the existing `ios-arm64` buildbot dylibs load unchanged. This is why Mac support works at all right now. |
| Mac Catalyst | **No, and none exist upstream** | Catalyst is a distinct Mach-O platform variant. `cores.yml` models only `ios_path`/`tvos_path`; libretro's buildbot publishes no Catalyst builds; dyld refuses macOS-platform dylibs in a Catalyst process. We would have to build and host **60+ cores ourselves** for the Catalyst ABI, forever. MoltenVK also has no Catalyst slice (the `MoltenVK-Catalyst.xcframework` is mislabeled plain-macOS and orphaned). |
| Native macOS | **Yes, upstream** | libretro buildbot publishes `nightly/apple/osx/arm64` cores. The checked-in `MoltenVK-1.2.8.xcframework` already contains a `macos-arm64_x86_64` slice. Only `cores.yml`/generator plumbing (`osx_path`) is missing. |

Additional native-macOS advantages: **unrestricted JIT** (the hardened-runtime
`com.apple.security.cs.allow-jit` entitlement is already in `Provenance.entitlements`; Mac App
Store permits it — Dolphin/PPSSPP/DuckStation at full speed, a real differentiator vs. iOS), and
real desktop chrome (menu bar, multi-window, Files integration).

### UI layer readiness

- ~70% SwiftUI by volume. The two big UIKit survivors are exactly the desktop-critical pieces:
  `PVEmulatorViewController` (~3.5k lines) + `PVMetalViewController`/`PVGLViewController`
  (game screen), and `PVControllerViewController` (touch overlay — correctly self-disabled on
  Catalyst/mac already).
- **The tvOS-style controller UI already runs outside tvOS.** `TVMediaMainView` +
  `TVMediaFocusCoordinator` (`#if os(tvOS) || os(iOS)`) + `GamepadManager` (no platform guards)
  compile on iOS and auto-activate on iPad when landscape + a controller is connected
  (`MainView.swift:186` `shouldUseTVMediaUI`). The user's instinct — "the tvOS UI could work on
  desktop" — is already half-built.
- In-game desktop input works: `GCKeyboard.createController()` synthesizes a virtual gamepad
  from the hardware keyboard (`PVControllerManager.swift:949+`, hardcoded map), and `GCMouse`
  drivers route physical mice to mouse/light-gun cores.
- Out-of-game desktop chrome is absent: **zero** `UIMenuBuilder`/`UICommand`/menu-bar code,
  zero window-geometry code, zero `UIPointerInteraction`. Keyboard shortcuts exist only on the
  emulator scene (5 of them; ⌘L Load State is an empty stub). The SwiftUI library has no
  keyboard navigation (the legacy UIKit library's rich `UIKeyCommand` set at
  `PVGameLibraryViewController.swift:1814+` doesn't carry over).

### visionOS footprint

Aspirational only. 33 packages declare `.visionOS(.v1)` and shared code carries guards, but no
app target builds for `xros` (no device family 7, no `XROS_DEPLOYMENT_TARGET` in the live
project, no CI/fastlane path), zero RealityKit usage, and the `Provenance VR` Reality Composer
package is a 3-line unwired placeholder. Vision Pro users get iPad-compatibility mode today
(`SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = YES` is already set). Note: `CLAUDE.md` claims
visionOS 1+ support; `.github/prompts/reviewer-context.md` correctly labels it "Aspirational" —
docs should be reconciled.

## 2. Options considered

### Option A — Invest in Catalyst (fix iPad-idiom Catalyst, add touch/mouse/menu support)

The originally proposed direction. **Rejected.** Catalyst is the only Mac path with **no core
binary supply**: every libretro core would need bespoke Catalyst-ABI builds hosted in
provenance-dylibs indefinitely, MoltenVK has no Catalyst slice, the render path needs real work
(`#warning("macOS incomplete")`), and at the end you still have an iPad app in a window — while
Designed-for-iPad already delivers that for free with working cores. Catalyst combines native
macOS's porting cost with none of its payoff. The 84 dead-config sites (`SUPPORTS_MACCATALYST =
YES` without `macosx` in `SUPPORTED_PLATFORMS`) should be treated as debt to remove, not fix.

### Option B — Polish "Designed for iPad" as the near-term Mac experience

Keep the shipping iOS binary as the Mac product, but make it feel intentional:
controller/keyboard-navigable library UI, menu bar, shortcuts, pointer polish. Everything here
also improves iPad-with-keyboard/trackpad and (via compatibility mode) Vision Pro. Cheap, low
risk, no new targets, no new binary pipeline. Ceiling: it will never feel like a Mac app
(iOS idiom, iOS JIT restrictions, no true multi-window control).

### Option C — Native macOS target (hybrid SwiftUI shell + AppKit game hosting)

A real `SDKROOT = macosx` app target reusing the PVSwiftUI library/settings surface (packages
already declare `.macOS(.v14)`), with new AppKit/NSViewController hosting for the emulator
screen and a `osx_path` extension to the buildbot dylib pipeline. Highest cost (port the UIKit
game stack, revive ~370 bit-rotted `os(macOS)` sites incrementally, new CI lane), highest
payoff (upstream core supply, unrestricted JIT, real desktop app, and the same SwiftUI shell
later carries a native visionOS window app if ever wanted).

## 3. Recommendation

**B now, C next, A never.** And for visionOS: **no native app now** — keep compatibility mode,
inherit the Option B improvements for free, revisit only after the native Mac shell exists.

Rationale in one line each:
- The core supply chain, not the UI, is the binding constraint — it favors Designed-for-iPad
  today and native macOS long-term, and rules out Catalyst.
- Every Option B work item is shared-platform work (iPad + Vision Pro compatibility + future
  Mac), so nothing is throwaway.
- Native macOS is the only path to the two features that would make Mac a first-class platform:
  upstream buildbot cores and unrestricted JIT.
- visionOS native would demand RealityKit/immersive investment for a tiny market; the
  interesting reuse (SwiftUI shell in a plain window) falls out of the Mac work anyway.

## 4. Phased plan

### Phase 0 — Hygiene & decision lock-in (small)
- Remove/neutralize dead Catalyst config: decide `SUPPORTS_MACCATALYST = NO` across app targets
  (or leave YES but document non-support); delete or quarantine `AppKitWrapper.swift` and the
  dead `#if os(macOS)` UI branches that mislead contributors.
- Fix `Build.xcconfig:90` dead entitlements var (or delete the mechanism — pbxproj overrides it
  anyway).
- Reconcile docs: CLAUDE.md's "macOS 14+ (Catalyst), visionOS 1+" claim vs. reality.
- Delete or archive the orphaned `Provenance VR` package, `ThumbnailExtensionMacOS` (until a mac
  host exists), and the stale TopShelf v1-style dead targets encountered along the way.

### Phase 1 — "Great on a Mac (and iPad) today": Designed-for-iPad polish (medium)
1. **Keyboard-driven controller UI.** Feed `GamepadManager` from the existing
   `GCKeyboard.createController()` bridge and relax `shouldUseTVMediaUI`
   (`MainView.swift:186`) so hardware-keyboard-without-gamepad (i.e., every Mac) can opt into
   the TVMedia controller-navigable UI. Add a Settings toggle ("Controller-style navigation").
2. **Menu bar.** Add SwiftUI `.commands` to the main `WindowGroup` (the app is SwiftUI
   lifecycle; `.commands` surfaces as the Mac menu bar and the iPad keyboard-discoverability
   HUD with far less code than `UIMenuBuilder` — reserve `UIMenuBuilder` for later if default
   menu replacement/removal is ever needed). Wire the existing NotificationCenter /
   `SceneCoordinator` actions.
3. **Keyboard shortcuts parity.** Port the legacy `UIKeyCommand` set
   (`PVGameLibraryViewController.swift:1814+`) to the SwiftUI library via `.commands` on the
   main `WindowGroup`; finish the ⌘L Load State stub in `EmulatorScene.swift`.
4. **Pointer polish.** `UIPointerInteraction`/hover on game tiles and pause-menu tiles
   (iPadOS pointer APIs work in Designed-for-iPad).
5. **Keyboard remap UI.** The hardcoded map at `PVControllerManager.swift:964-1010` gets a
   settings surface (reuse controller-remap patterns).
6. Ship it in the regular iOS release; verify on Apple Silicon Macs + one Vision Pro
   compatibility check.

### Phase 2 — Native macOS app (large; own epic)
1. **Pipeline first:** add `osx_path: "osx-arm64/latest"` (verify exact buildbot path) to
   `cores.yml` + `generate_core_lists.py` + `CoreManifest.swift`; produce a mac dylib set and
   validate `dlopen` + thin-wrapper boot headlessly before any UI work.
2. **Render/host:** new `NSViewController`-hosted Metal path (CAMetalLayer directly; resolve the
   IOSurface/GL TODO by dropping GL on mac — Metal + MoltenVK macos slice only).
3. **App shell:** new `Provenance-Mac` target, SwiftUI `WindowGroup` reusing
   PVSwiftUI library/settings; emulator in its own window (multi-window free).
4. **Input:** reuse GameController framework (GCKeyboard/GCMouse/GCController all exist on
   macOS); menu bar natively via SwiftUI `.commands`.
5. **JIT:** short-circuit `JitAcquisitionUtils`/`DOLJitManager` to "available" on macOS;
   entitlements already present.
6. **CI + release automation are in-scope from day one, not an afterthought** *(added
   2026-08-07 per maintainer direction)*: extend `.github/workflows/build.yml`'s matrix with a
   `generic/platform=macOS` entry alongside iOS/tvOS; extend `Scripts/release.sh`, the
   `Makefile` (`make testflight-all` / `make release-all`), and `fastlane` so the native Mac
   build archives, notarizes, and publishes in the **same release train** as iOS/tvOS — one
   version number, one changelog, simultaneous ship. The sideload/alpha feed gains a macOS
   artifact entry (same `version`/`buildVersion`-must-match rule as the IPA feed).
7. Explicit non-goals for v1: Catalyst, x86_64, DriverKit revival, App Store submission
   (notarized direct distribution first — fits the existing sideload/alpha feed).

### Phase 2+ direction — Mac as ROM/library server *(added 2026-08-07)*

Once the native Mac app exists, it becomes the natural always-on library host: PVWebServer
already ships HTTP + WebDAV servers (GCDWebServer today, new Swift server + planned REST API),
so a Mac build can serve ROMs, BIOS, and save states to iOS/tvOS clients on the LAN — a
first-party alternative to CloudKit sync for large libraries, and a reason the Mac app earns
its keep beyond playing games. Not specced here; gets its own brainstorm/spec when Phase 2
lands. Design consequence for Phase 2 now: keep PVWebServer fully enabled in the Mac target
(don't strip it as "mobile-only"), and prefer server-friendly choices (background operation,
LSUIElement-style headless mode is a candidate) when they're free.

### Phase 3 (optional, post-Mac) — visionOS
- Keep compatibility mode as the supported story; mention it in docs.
- Only if the Mac SwiftUI shell proves cleanly portable: a native `xros` target as a flat
  window app (no immersive space) reusing that shell — decide then, not now.

## 5. Risks & open questions

- **Buildbot macOS core coverage** may not match iOS 1:1 (some cores missing/broken upstream);
  Phase 2 step 1 is deliberately a headless validation gate before UI investment.
- **Custom cores** (provenance-dylibs: virtualjaguar HLE, flycast-jitless, etc.) need macOS
  builds — same recurring cost Catalyst would have had, but scoped to the handful of custom
  cores rather than all 60+.
- **Realm/CloudKit/FreemiumKit on native macOS** — believed fine (packages declare macOS) but
  unverified; include in the Phase 2 spike.
- **`.uikit` MainUIMode and legacy UIKit library** are iOS-only debt that Phase 2 simply won't
  port; confirm acceptable.
- Whether Phase 1's TVMedia-UI-on-desktop should become the *default* Mac experience or an
  opt-in — recommend opt-in first, promote based on feedback.
