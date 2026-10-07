# Azahar 3DS Core Rebuild — Design

**Date:** 2026-10-07
**Status:** Approved in chat 2026-10-07; implementation plan follows
**Scope:** Replace the hand-forked 3DS core (`Cores/Citra`, "PVAzahar") with a fresh
core that tracks upstream azahar-emu, ship it alongside PVEmuThree, migrate user data,
then retire PVEmuThree.

## 1. Current state (audited 2026-10-07)

- **Both 3DS cores are the same codebase.** `Cores/emuThree/emuthree` and
  `Cores/Citra/azahar` are two checkouts of `Provenance-Emu/emuThreeDS`, a 2023 Citra
  snapshot with an iOS wrapper. `Cores/Citra/azahar` is a detached commit with 137
  Provenance commits on top (Citra video_core ported forward, azahar realtime audio
  and SPIR-V cache grafted in, NEON dyncom/audio experiments from March 2025). It
  shares no git history with azahar-emu.
- **Override folder.** 57 files in `Cores/Citra/PVAzaharCore/azahar/` shadow submodule
  files purely through header-search-path order
  (`PVAzahar.xcodeproj/project.pbxproj` ≈ lines 45107–45122). Every upstream bump has to
  be re-merged by hand into those copies. This is the "dual folder" pain.
- **Shipping status.** `PVEmuThree.framework` is embedded in every app target.
  `PVAzahar.framework` is referenced in the project but embedded in none, so deleting
  it costs nothing. It renders black today.
- **Upstream azahar-emu** (`master`, release 2126.1.2, 2026-09-20):
  - Builds for iOS through plain CMake (`.ci/ios.sh`, `CMAKE_SYSTEM_NAME=iOS`), downloads
    a static MoltenVK v1.4.1, and gates iOS-incompatible options
    (`ENABLE_CUBEB`, `ENABLE_LIBUSB`, `ENABLE_TESTS`, `ENABLE_ROOM` are `NOT IOS`). There
    is **no iOS job in `build.yml`**, so the iOS path has bit-rotted in places (see §4.2).
  - Merged **FastInterp** (PR #2376, 2026-09-16): a new ARM interpreter selected when
    `use_cpu_jit` is off and `use_fastinterp` is on (`core/core.cpp:600–623`). This is the
    jitless performance path and supersedes our 2025 NEON dyncom work.
  - Ships `AppleUtils` / `AppleAuthorization` helpers; `apple_utils.mm` imports Cocoa and is
    compiled for every Apple target (`common/CMakeLists.txt:122–130`).
- **jarrodnorwell/azahar** = upstream master + 2 commits (13 behind): CoreAudio
  sink/input, SDL3 input, `FOR_CYTRUS` data-dir name, `@rpath` MoltenVK load. The
  CoreAudio sink is the only piece we want.
- **folium-app/Cytrus** = a flat copy of azahar `src/` plus five glue files
  (`bridge.cpp`, `emu_window_vk.cpp`, `camera.mm`, `input_manager.cpp`,
  `configuration.cpp`), built inside Folium.xcodeproj against `$(HOME)/Developer/Repositories`
  and a local VulkanSDK. iOS only, GPL-3, five commits. A reference for the glue shape,
  not a dependency.
- **In-repo patterns to reuse.** Dolphin builds an on-demand xcframework from CMake
  (`Cores/Dolphin/build_dolphin_core.py`, `cmake/ios.toolchain.cmake`, Run Script phase
  with preflight guard and fresh-slice rsync in `PVDolphin.xcodeproj`). VirtualJaguar
  tracks a `Provenance-Emu` fork whose `provenance` branch is upstream + a rebased patch
  stack (`Cores/VirtualJaguar/Scripts/update-upstream.sh`). Own-view cores hand their view
  to the host through `touchViewController` with `skipLayout = true`
  (`PVEmulatorCore.swift:88,128`; `Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore.mm:1296–1354`).
- **emuThree data root.** `DirectoryManager::DocumentDirectory()`
  (`Cores/emuThree/emuthree/emuThreeDS/citra_wrapper/DirectoryManager.mm:11–15`) returns
  the app `Documents/` on iOS and `Library/Caches/` on tvOS, and `file_util.cpp` uses it as
  the user root, so `nand/`, `sdmc/`, `sysdata/`, `config/`, `cheats/`, `states/`,
  `shaders/`, `log/` sit directly under it.

## 2. Goals and non-goals

**Goals**
1. A 3DS core whose emulator source is upstream azahar-emu, bumped by moving one
   submodule gitlink, with zero shadowed files.
2. Builds for iOS, iOS Simulator, tvOS and tvOS Simulator from one script.
3. JIT via dynarmic when PVJIT acquires it, FastInterp otherwise.
4. Ships alongside PVEmuThree first; users can move their NAND/SD/sysdata across.
5. Every local change to emulator code is an upstreamable patch on a fork branch.

**Non-goals (v1)**
- Separate top/bottom Metal layers for dual-screen skins (follow-up; azahar's built-in
  layouts cover v1).
- Camera on tvOS, microphone, Artic Base, netplay/rooms, Mii/software-keyboard applets
  beyond upstream defaults.
- Forwarding the 2025 NEON interpreter patches upstream. FastInterp supersedes them.
- Touching PVEmuThree's code. It is only removed at the end.

## 3. Architecture

```
Cores/Azahar/
├── azahar/                      submodule → Provenance-Emu/azahar @ branch `provenance`
├── build_azahar_core.py         CMake+Ninja → build/xcframework/PVlibAzahar.xcframework
├── cmake/ios.toolchain.cmake    copy of Cores/Dolphin/cmake/ios.toolchain.cmake
├── PVAzahar.xcodeproj           framework target PVAzahar (iOS + tvOS)
├── PVAzahar/                    Core.plist, Info.plist, PVAzahar.h (umbrella)
└── PVAzaharCore/
    ├── Glue/                    C++/ObjC++ compiled by Xcode against azahar headers
    │   ├── AzaharEmuWindow.{h,mm}      Frontend::EmuWindow over CAMetalLayer
    │   ├── AzaharGraphicsContext.{h,mm} Frontend::GraphicsContext → MoltenVK handle
    │   ├── AzaharAppleUtils.mm         AppleUtils / AppleAuthorization for iOS/tvOS
    │   ├── AzaharCamera.{h,mm}         iOS AVFoundation camera factory (tvOS: blank)
    │   ├── AzaharInput.{h,cpp}         Input::InputDevice button/analog/motion bridges
    │   └── AzaharLogBackend.{h,cpp}    Common::Log backend → PVLogging
    ├── PVAzaharCoreBridge.{h,mm}       lifecycle, settings, run loop
    ├── PVAzaharCoreBridge+Controls.mm  PV3DSButton → AzaharInput
    ├── PVAzaharCoreBridge+Saves.mm     save states (azahar `states/`)
    ├── PVAzaharCoreBridge+Cheats.mm    Cheats::CheatEngine (Gateway codes)
    ├── PVAzaharCoreBridge+Video.mm     layer hand-off, resize, pause/resume
    ├── PVAzaharCoreBridge+Audio.mm     CoreAudio sink selection, volume, mute
    ├── PVAzaharCore.swift              PVEmulatorCore subclass
    ├── PVAzaharCoreOptions.swift       CoreOptional
    ├── PVAzaharDataMigrator.swift      emuThree → Azahar data move
    ├── PVAzaharRenderView.swift        UIView whose layer is CAMetalLayer
    └── CorePlist.swift / CorePlist-Generated.swift
```

Dependency direction: `PVAzahar.framework` → `PVlibAzahar.xcframework` (static, merged)
→ `MoltenVK.framework` (dlopen at runtime, the copy the app already embeds from
`MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework`, currently 1.2.11).

### 3.1 Boot sequence

1. `PVAzaharCore.loadFile` → bridge records ROM path, sets `FileUtil::SetUserPath(<Documents>/Azahar/)`,
   installs the log backend, applies `Settings::values` from core options, and sets
   `use_cpu_jit = PVJITManagerIsAcquired()`, `use_fastinterp = !use_cpu_jit`.
2. Host assigns `touchViewController`; `+Video` inserts `PVAzaharRenderView` behind the
   skin/overlay (Dolphin pattern, `skipLayout = true`), and creates `AzaharEmuWindow`
   with that layer, the view's `contentScaleFactor`, and the current bounds.
3. `startEmulation` → emulation thread: `Core::System::GetInstance().Load(window, path)`
   then `while (running) { if (!paused) system.RunLoop(); else wait on cv; }`.
4. First-frame watchdog (`PVEmulatorViewController+FirstFrameWatchdog`) fires `[NO-FRAME]`
   if nothing presents in 5 s; a failed `Load` or Vulkan init returns an error from
   `loadFile`/`startEmulation` instead of a black screen.

### 3.2 Threading

- Emulation thread owns `Core::System`. `pause` flips an atomic flag checked before
  `RunLoop`; the emu loop never holds a lock the main thread needs (CLAUDE.md
  `@synchronized` gotcha).
- Layer resize/rotation: main thread updates view bounds, then posts
  `window.OnFramebufferSizeChanged()` to the emulation thread via a queued callback
  drained before `RunLoop`, never calling renderer methods from the main thread.
- Background/resume: on `applicationState != .active` the presenter stops; the emu
  loop pauses via the existing PV pause path. No `nextDrawable` on the main thread.

## 4. Components

### 4.1 Fork and sync

- Reuse the existing `Provenance-Emu/azahar` fork (stale since 2025-03). Add branch
  `provenance` = `azahar-emu/master` + patch stack. Add a scheduled
  `sync-upstream.yml` that merges `master` into `provenance` (same shape as the
  virtualjaguar fork's; a carried patch that upstream merges drops out on the next sync).
- `Cores/Azahar/azahar` gitlink pins a specific `provenance` commit. Bumps are a gitlink
  change plus `build_azahar_core.py --clean`.
- Submodule path is `Cores/Azahar/azahar`; `.gitmodules` entry
  `url = https://github.com/Provenance-Emu/azahar.git`, `branch = provenance`.

### 4.2 Patch stack (expected initial contents)

Each is one commit on `provenance`, each written so it can be a PR to azahar-emu.

| # | Patch | Why |
|---|---|---|
| 1 | `common: build apple_utils.mm only on macOS; iOS/tvOS frontends provide AppleUtils` | `apple_utils.mm` imports Cocoa; iOS build fails. Cytrus does the same by defining `AppleUtils::*` in its bridge. |
| 2 | `vk_platform: honour GraphicsContext::GetDriverLibrary on all platforms` | `OpenLibrary` only consults the frontend's driver library `#ifdef ANDROID` (`vk_platform.cpp:98–104`). On iOS a bare `dlopen("libMoltenVK.dylib")` does not search `@rpath`, so the frontend must hand over its handle. |
| 3 | `audio_core: add CoreAudio sink and input (ENABLE_COREAUDIO)` | From jarrodnorwell/azahar `4b6bb8ff` (CoreAudio parts only, no SDL3). OpenAL is deprecated on iOS/tvOS. |
| 4 | `cmake: allow MOLTENVK_LIBRARY override for tvOS/simulator slices` | `download_moltenvk()` hardcodes `static/MoltenVK.xcframework/ios-arm64`. We pass `USE_SYSTEM_MOLTENVK=ON -DMOLTENVK_LIBRARY=<slice>`; only needed if `find_library` ignores a pre-set cache value. |

Anything else the first build surfaces (tvOS-only compile errors, AVFoundation on
tvOS, etc.) joins the stack with the same rule. The stack is listed in
`Cores/Azahar/PATCHES.md` with upstream PR links once opened.

### 4.3 Build pipeline

`Cores/Azahar/build_azahar_core.py`, modelled on `build_dolphin_core.py`:

- Platforms: `OS64` (iphoneos), `SIMULATORARM64` (iphonesimulator), `TVOS` (appletvos),
  `SIMULATOR_TVOS` (appletvsimulator). Deployment targets iOS 17 / tvOS 17.
  `ios.toolchain.cmake` sets `IOS=TRUE` for tvOS too (`ios.toolchain.cmake:469,669`), so
  upstream's `if (IOS)` gates apply to tvOS.
- CMake options:
  `ENABLE_QT=OFF ENABLE_SDL2=OFF ENABLE_WEB_SERVICE=OFF ENABLE_SCRIPTING=OFF
  ENABLE_GDBSTUB=OFF ENABLE_OPENAL=OFF ENABLE_COREAUDIO=ON ENABLE_FFMPEG=OFF
  ENABLE_SOFTWARE_RENDERER=OFF ENABLE_VULKAN=ON ENABLE_TESTS=OFF ENABLE_ROOM=OFF
  ENABLE_DISCORD_RPC=OFF USE_SYSTEM_MOLTENVK=ON MOLTENVK_LIBRARY=<slice .a>
  CMAKE_BUILD_TYPE=Release ENABLE_LTO=ON`
  plus `-DCMAKE_C_COMPILER_LAUNCHER=ccache` when present.
- Targets built: `citra_core citra_common video_core audio_core network input_common`
  and their externals (dynarmic, teakra, glslang/SPIRV, sirit, boost_serialization,
  boost_iostreams, zstd, fmt, cryptopp, faad2, soundtouch, lodepng, enet, httplib
  deps, libressl if `network` still needs it, xxhash, spirv-tools). `citra_qt`,
  `citra_cli`, `citra_room*` and `tests` are never built.
- Merge: every produced `.a` for a slice → `libtool -static -o PVlibAzahar.a`, wrapped
  as `PVlibAzahar-<slice>.framework` (headers = azahar `src/` include tree + externals
  headers the glue needs: `boost`, `fmt`, `vulkan-headers`, `vma`) and combined with
  `xcodebuild -create-xcframework` into `build/xcframework/PVlibAzahar.xcframework`.
- `PVAzahar.xcodeproj` "Build PVlibAzahar" Run Script phase: same preflight guard
  (submodule present, cmake, ninja), builds only the active `PLATFORM_NAME` slice, and
  rsyncs the fresh slice into `BUILT_PRODUCTS_DIR` (Dolphin's stale-slice fix).
- MoltenVK: static `libMoltenVK.a` is linked into `PVlibAzahar` only to satisfy
  `PLATFORM_LIBRARIES`; the renderer loads Vulkan entry points from the **dynamic**
  `MoltenVK.framework` the app embeds, handed in through patch #2. A compatibility check
  task confirms `TargetVulkanApiVersion` and the extensions in `vk_instance.cpp:451–478`
  against the embedded MoltenVK 1.2.11; if it falls short, upgrading the app-wide
  MoltenVK (which the thin wrapper also uses) is a separate explicit task, not a second
  MoltenVK copy.
- The build directory lives under `Cores/Azahar/build/` and is gitignored. CI caches it
  keyed on the submodule gitlink + script hash, as Dolphin's job does.

### 4.4 Glue layer

- **AzaharEmuWindow** (`Frontend::EmuWindow`): holds `CAMetalLayer*`,
  `window_info.type = WindowSystemType::MacOS`, `render_surface_scale = contentScaleFactor`
  (not Cytrus's hard-coded 3.0). `OnFramebufferSizeChanged` calls
  `UpdateCurrentFramebufferLayout(w, h, is_portrait)`. Touch: `TouchPressed/Moved/Released`
  in window pixels; azahar maps to the bottom screen through the active layout.
- **AzaharGraphicsContext**: `GetDriverLibrary()` returns a
  `Common::DynamicLibrary` wrapping `dlopen("@rpath/MoltenVK.framework/MoltenVK")`,
  opened once per process.
- **AzaharAppleUtils.mm**: `GetRefreshRate()` from `UIScreen.main.maximumFramesPerSecond`
  (iOS) / 60 (tvOS); `IsLowPowerModeEnabled()` from `NSProcessInfo`;
  `IsRunningFromTerminal()` false; `CheckAuthorizationForCamera/Microphone` via
  AVFoundation on iOS, false on tvOS.
- **AzaharInput**: `Input::InputDevice<bool>` and `InputDevice<std::tuple<float,float>>`
  factories registered with `Input::RegisterFactory` under engine name `"provenance"`.
  Settings `current_input_profile.buttons[n] = "engine:provenance,button:<n>"`. Mapping
  PV3DSButton → `Settings::NativeButton` (A, B, X, Y, Up, Down, Left, Right, L, R, Start,
  Select, ZL, ZR, Home) and PV3DSButton analogs → `NativeAnalog::CirclePad/CStick`.
  `swap`, `rotate`, `analogMode` are frontend actions (layout swap / rotate / toggle
  C-stick vs circle pad on the single touch stick), not emulator buttons.
- **AzaharLogBackend**: `Common::Log::Backend` forwarding to `PVLogging` with the
  class name as category; upstream's console backend disabled.
- **Camera**: iOS front/rear factories adapted from Cytrus's `camera.mm` (GPL-2+
  compatible; keep header attribution), registered in `loadFile`. tvOS registers
  `Camera::BlankCamera`.

### 4.5 Bridge and Swift core

- `PVAzaharCore: PVEmulatorCore` with `jitRequirement = .automaticWithFallback`,
  `supportsSkins = true` on iOS, `requiresExplicitSkinSelection = false`,
  `rendersToVulkan = true`, `skipLayout = true` once the view is attached.
- Core identifier stays `com.provenance.core.azahar`, principle class
  `PVAzahar.PVAzaharCore`, supported system `com.provenance.3ds`, `PVProjectName`
  "Azahar", `PVJITRequirement` `optional`, license fields as in the current
  `Core.plist` but version taken from the submodule (`PVProjectVersion` generated).
- Options (`PVAzaharCoreOptions.swift`) → `Settings::values`:

  | Option | Setting | Default |
  |---|---|---|
  | Resolution scale | `resolution_factor` | 1 (2 on A15+) |
  | Screen layout | `layout_option` | Default (tvOS: LargeScreen) |
  | Swap screens | `swap_screen` | off |
  | New 3DS mode | `is_new_3ds` | on |
  | CPU clock % | `cpu_clock_percentage` | 100 |
  | Hardware shader | `use_hw_shader` | on |
  | Accurate multiplication | `shaders_accurate_mul` | on |
  | Async shader compilation | `async_shader_compilation` | on |
  | Async presentation | `async_presentation` | on |
  | Disk shader cache | `use_disk_shader_cache` | on |
  | Texture filter | `texture_filter` | none |
  | Audio stretching | `enable_audio_stretching` | on |
  | Realtime audio | `enable_realtime_audio` | on |
  | Region | `region_value` | auto |
  | Stereoscopic 3D off | `render_3d = Off`, `factor_3d = 0` | fixed |
  | Frame limit | `frame_limit` | 100 |

  Language follows the device locale through the existing core-language sync hook
  (`#3515`). Per-game overrides work through `CoreOptionsContext.currentGameMD5` like
  every other core.
- Save states: `system.SendSignal(Core::System::Signal::Save, slot)` /
  `Signal::Load` with the slot path redirected to PV's `saveStatesPath`; the result is
  reported through azahar's `RegisterSaveStateCallback`? If the callback is absent,
  poll `system.GetSignal()`; the task verifies the API at implementation time.
- Cheats: `system.CheatEngine()` `AddCheat`/`RemoveCheat` with `Cheats::GatewayCheat`
  parsed from the PV cheat string; `cheatCodeTypes = ["Gateway"]`.
- Audio: `Settings::values.output_type = AudioCore::SinkType::CoreAudio`;
  `volume` from PV; mute pauses the sink.

### 4.6 Data layout and migration

- User root: `<app Documents>/Azahar/` via `FileUtil::SetUserPath`. Subdirectories are
  upstream's (`nand`, `sdmc`, `sysdata`, `config`, `cheats`, `states`, `shaders`,
  `log`, `dump`, `load`). Game saves live in `sdmc/` as on a real 3DS; PV's
  `batterySavesPath` is unused except to hold a marker file.
- `PVAzaharDataMigrator` (Swift, pure functions over `FileManager` + injected paths):
  - `legacyRoot` = emuThree root (`Documents/` on iOS, `Library/Caches/` on tvOS).
  - `candidates` = `[nand, sdmc, sysdata, config, cheats, shaders]`. `states` is skipped
    (incompatible format); `log`/`dump` are skipped (noise).
  - `plan()` returns, per candidate, `.move` when the source exists and the destination
    does not, `.skip(reason)` otherwise, plus total byte size for the UI.
  - `apply()` does `moveItem` (same-volume rename). On failure it falls back to copy
    then delete, and on copy failure leaves the source untouched and reports.
  - Writes `<root>/.migrated-from-emuthree` on success; never runs twice.
- Entry points:
  - While both cores ship: Settings → Cores → Azahar → "Import 3DS system data from
    emuThreeDS", confirmation sheet states that emuThreeDS will no longer see the data
    and shows the size.
  - Once `com.provenance.core.emuThree` is absent from `CoreOptionsContext`/the core
    registry: run automatically on first `loadFile` before `SetUserPath` is used.
- Tests: `PVAzaharCoreTests` XCTest target in `PVAzahar.xcodeproj` covering plan/apply
  with a temp directory fixture (move, skip-existing, partial failure, marker idempotence).

### 4.7 Retirement of PVEmuThree

1. Device checklist passes on the new core (see §5).
2. One release with `PVEmuThree` `Core.plist` marked `PVDisabled` and the migrator's
   automatic path enabled.
3. Remove `Cores/emuThree` from every app target's Embed Frameworks phase and the
   workspace, delete the directory and submodule, following the dead-core cleanup
   method (`dead-libretro-core-cleanup` memory). Binary size drop is recorded in the PR.

`Cores/Citra` (the old PVAzahar) is deleted in the first implementation PR since no app
target embeds it; its `.gitmodules` entry (`Cores/Citra/azahar`) and `cmake/zstd`
submodule go with it.

## 5. Testing

- **Unit:** migrator (above); option-mapping table (`PVAzaharCoreOptions` → expected
  `Settings` values) through a small ObjC++ test shim; PV3DSButton → NativeButton map.
- **Build:** `build_azahar_core.py --all-platforms` must produce four slices;
  `xcodebuild build -scheme PVAzahar` for iphoneos, iphonesimulator, appletvos,
  appletvsimulator; the full app archive for Provenance-Lite iOS and tvOS. CI: add the
  slice build to `build.yml` with the Dolphin-style cache.
- **Device checklist (gates retirement):** boot a homebrew `.3dsx` and a commercial
  `.cia`/`.3ds`; JIT on and off (verify `[JIT]` log line and FastInterp selection);
  DeltaSkin on iPhone; save/load state; background and resume with no main-thread hang;
  rotation; tvOS boot with controller; migrator on a device with real emuThree data.
- **Regression watch:** `[NO-FRAME]` watchdog, MetricKit crash reports, Sentry.

## 6. Upstreaming

Candidate PRs to azahar-emu, in order: patch #1 (apple_utils guard), patch #2
(driver library on all platforms), patch #3 (CoreAudio sink, co-credited to Jarrod
Norwell), patch #4 if needed. Any tvOS compile fixes follow. Our 2025 NEON interpreter
work is not forwarded.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| MoltenVK 1.2.11 too old for azahar's Vulkan use | Compatibility check task before glue work; upgrade app-wide MoltenVK as its own task if needed. |
| dynarmic W^X on iOS 26 | PVJIT already handles acquisition; `use_cpu_jit` is set only when `PVJITManagerIsAcquired()`; FastInterp otherwise. |
| tvOS compile failures in core (AVFoundation camera, UIKit assumptions) | Patch stack; each fix upstreamable. |
| Build time / CI cost | ccache, cached `build/` keyed on gitlink + script hash, only the active slice built in Xcode. |
| Binary size (user concern) | `-Oz`-free Release with LTO and `-fvisibility=hidden`; software renderer, Qt, SDL, FFmpeg, OpenAL excluded; size recorded per PR; PVEmuThree removal is the real win. |
| Explicit-file-list xcodeproj | `Scripts/audits/check_pbxproj_sources.py` runs in CI; glue files are added to the project when created. |
| Two cores writing the same data | They don't share a root; migration is an explicit move with a warning while both ship. |

## 8. Work breakdown (phases for the implementation plan)

1. **Fork + sync + patch stack** (fork branch, workflow, patches 1–3, PATCHES.md).
2. **Build pipeline** (script, toolchain copy, xcframework, Xcode project with Run Script,
   delete Cores/Citra, four slices green).
3. **Glue + bridge** (window, context, utils, input, log, camera, bridge files, Swift core,
   options, Core.plist) to first frame on iOS Simulator.
4. **Migrator + settings entry point + tests.**
5. **tvOS + device hardening** (checklist), then **retirement PR**.

## 9. Follow-up: Apple Silicon performance pass (not in this plan)

After the device checklist passes, a separate spec will port the jitless-interpreter and
platform work done for iCube (Dolphin) and iFly (flycast) onto the fork: FastInterp
dispatch instruction-count reduction (upstream already uses computed goto), fused
adjacent ops, NEON/FPU fast paths, fastmem, idle-loop detection, and an audit of
azahar's assumptions about disk I/O, CPU/GPU memory sharing, core count and cache
size that do not hold on Apple Silicon (unified memory, fast SSD, many cores).
Patches follow the same fork + `PATCHES.md` rule.
