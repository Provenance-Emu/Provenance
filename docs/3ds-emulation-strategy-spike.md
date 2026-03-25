# 3DS Emulation Strategy — Core Consolidation, Landscape & Roadmap

> **Spike Date:** 2026-03-25
> **Related Issue:** [#2840](https://github.com/Provenance-Emu/Provenance/issues/2840)
> **Status:** Investigation Complete — Awaiting Decision

---

## 1. Current State Audit

### 1.1 Core Architecture

Provenance ships two separate 3DS core wrappers:

| Wrapper | Path | Submodule URL | Submodule Alias |
|---------|------|---------------|-----------------|
| **PVEmuThree** | `Cores/emuThree/` | `rf2222222/emuThreeDS` | `Cores/emuThree/emuthree` |
| **PVAzahar** | `Cores/Citra/` *(dir name mismatch)* | `Provenance-Emu/emuThreeDS` | `Cores/Citra/azahar` |

Both cores share an identical "override files" build pattern: local files placed in
`PVEmuThreeCore/emuThree/` or `PVAzaharCore/azahar/` shadow identically-named files from the
upstream submodule at compile time via Xcode's header search path and source file ordering.

**Key architectural note:** `Cores/Citra/azahar` does NOT point to `AzaharEmulator/azahar`
(the actual Azahar upstream). It points to `Provenance-Emu/emuThreeDS` — a Provenance-owned
fork of the same emuThreeDS codebase as PVEmuThree, with additional Azahar-derived patches applied manually.

---

### 1.2 Override File Manifest

Both cores override the following files relative to their respective submodule root:

#### Core Bridge / iOS Integration Files (Objective-C/C++)

| File | What It Does | Notes |
|------|-------------|-------|
| `CitraWrapper.mm` / `CitraWrapper.h` | ObjC wrapper for the core — `startVM`, `stopVM`, save/load, input dispatch | Primary integration layer; both cores have `// Local Changes: Add Save/Load/Cheat` comment |
| `InputBridge.mm` / `InputBridge.h` | Connects iOS `GCController` to Citra's input system | |
| `InputFactory.mm` / `InputFactory.h` | Factory for creating Citra input devices | |
| `emu_window.cpp` / `emu_window.h` | Base Apple/Metal window class (`EmuWindow_Apple`) | Defines `PresentingState` enum, `CA::MetalLayer` lifetime |
| `emu_window_vk.mm` / `emu_window_vk.h` | Vulkan/Metal swap-chain surface management | **Key difference between cores** — see §1.3 |
| `MultiplayerManager.mm` / `MultiplayerManager.h` | Stub multiplayer (no LAN on iOS) | |
| `Camera/CameraFactory.mm` / `.h` | AVFoundation camera backend | |
| `Camera/CameraInterface.mm` / `.h` | Camera interface protocol impl | |

#### Audio Overrides

| File | What It Does |
|------|-------------|
| `audio_core/coreaudio_sink.cpp` / `.h` | iOS CoreAudio output sink (replaces SDL2/OpenAL) |
| `audio_core/coreaudio_input.cpp` / `.h` | Microphone input via CoreAudio |
| `audio_core/interpolate.cpp` / `.h` | Audio interpolation tweaks |
| `audio_core/null_sink.h` | Null audio backend |
| `audio_core/openal_sink.cpp` / `.h` | OpenAL fallback sink |
| `audio_core/openal_input.cpp` / `.h` | OpenAL microphone input |
| `audio_core/sdl2_sink.cpp` / `.h` | SDL2 sink stub (disabled on iOS) |

#### Common / Settings Overrides

| File | What It Does |
|------|-------------|
| `common/settings.h` | iOS-specific `GraphicsAPI` enum variants, `MobilePortrait`/`MobileLandscape` layout options, iOS button input device ownership (std::unique_ptr members in Values struct) |
| `common/settings.cpp` | Settings initialization for iOS context |
| `core/savestate.cpp` / `.h` | Save state hooks |

#### GPU / Renderer Patches

| File | What It Does | Override Comment |
|------|-------------|-----------------|
| `renderer_vulkan.cpp` | Delays `vmaDestroyImage` — avoids UAF crash | `// Local Changes: delay vmaDestroyImage` |
| `vk_pipeline_cache.cpp` | Pipeline cache tuning for Metal/MoltenVK | |
| `vk_platform.cpp` | Vulkan platform abstraction for Metal | |
| `vk_rasterizer.cpp` | Rasterizer tweaks | |
| `vk_render_manager.cpp` | Render manager adjustments | |
| `shader_interpreter.cpp` | Shader interpreter patches | |

#### Misc C++ Patches

| File | Notes |
|------|-------|
| `applet_manager.cpp` | Applet (software keyboard, Mii selector) — iOS UI |
| `mii_selector.cpp` | Mii selector applet |
| `hid.cpp`, `extra_hid.cpp` | HID / NFC input patches |
| `bench*.cpp`, `regtest*.cpp`, `validat*.cpp`, `datatest.cpp` | Test/benchmark stubs; not upstream files |
| `rsa.cpp`, `ccm.cpp` | Crypto patches |

---

### 1.3 Key Differences Between PVEmuThree and PVAzahar

#### `emu_window_vk.mm` — The GPU Regression Root Cause

The two `emu_window_vk.mm` files are structurally similar but PVAzahar has a much more complex
implementation that is the most likely source of the GPU black screen regression:

**PVEmuThree (`Cores/emuThree/PVEmuThreeCore/emuThree/emu_window_vk.mm`)**:
- Simple `CreateWindowSurface` — just sets `window_info.render_surface = host_window`
- `TryPresenting` calls `VideoCore::g_renderer->TryPresent(0)` (old-style global pointer)
- `OrientationChanged` always calls `OnSurfaceChanged` + `OnFramebufferSizeChanged`
- No null checks on surface

**PVAzahar (`Cores/Citra/PVAzaharCore/azahar/emu_window_vk.mm`)**:
- `CreateWindowSurface` is more defensive: null-checks `host_window`, logs warning on failure,
  sets `window_info.render_surface_scale` from `[UIScreen mainScreen] nativeScale`, computes
  `window_width/height` from drawable size divided by scale
- `TryPresenting` uses `Core::System::GetInstance().GPU().Renderer().TryPresent(0)` — the newer
  Azahar API style (separate GPU object), wrapped in try/catch with frame counter logging
- `OrientationChanged` only calls `OnSurfaceChanged` if `host_window != surface` (deduplication)
- Includes `#include "video_core/gpu.h"` and `#include "core/core.h"` (Azahar-era headers)

**Likely regression cause:** PVAzahar's `TryPresenting` uses `system.GPU().Renderer()` which
requires the GPU object to be fully initialized. If the GPU hasn't been initialized yet when
`TryPresenting` is first called (the `Initial → Running` transition), `.GPU()` may return a
reference to an uninitialized object, leading to the flickering first frame then black screen.
The frame counter logging added in PVAzahar also suggests someone was investigating this.

Additionally, the `window_width/height` calculation in PVAzahar (`drawableSize / scale`) is
opposite to native scale convention — this could produce incorrect framebuffer layout dimensions.

#### Frame Rate Default
- **PVEmuThree**: `_frameInterval = 60` (correct for 3DS)
- **PVAzahar**: `_frameInterval = 120` (double — may affect timing)

#### Options
- **PVAzahar** adds `rightEyeDisableOption` (performance option to skip rendering the right eye)
- **PVEmuThree** CPU clock default is `0` (auto), PVAzahar is `100` (fixed 100%)
- **PVAzahar** `enableAsyncShader` defaults to `false`; PVEmuThree defaults to `true`

#### OSD Integration
- PVAzahar's `CitraWrapper.mm` includes an `PVPostOSD` helper for posting OSD notifications via
  `NSNotificationCenter` — not present in PVEmuThree (added in PR #3151)

---

### 1.4 Submodule Identity Confusion

```
Cores/emuThree/emuthree  → https://github.com/rf2222222/emuThreeDS.git    (original iOS fork)
Cores/Citra/azahar       → https://github.com/Provenance-Emu/emuThreeDS.git  (Provenance fork)
```

The "Azahar" core does NOT track the actual [AzaharEmulator/azahar](https://github.com/AzaharEmulator/azahar) upstream.
It tracks `Provenance-Emu/emuThreeDS`, which appears to be a fork of `rf2222222/emuThreeDS` with
additional patches applied, some inspired by Azahar. This naming is deeply confusing.

---

## 2. iOS 3DS Emulation Landscape (2024–2026)

### 2.1 Active Upstreams

| Project | Relationship | iOS Status | Notes |
|---------|-------------|-----------|-------|
| **[Citra](https://github.com/citra-emu/citra)** | Original | ⛔ Archived (2024 Nintendo C&D) | All forks derived from this |
| **[Lime3DS](https://github.com/Lime3DS-Emulator/Lime3DS)** | Citra fork | ✅ Active iOS support | Continued development post-C&D; powers Folium/Cytrus |
| **[Azahar](https://github.com/AzaharEmulator/azahar)** | Lime3DS fork | ❓ Unknown iOS status | More features; unclear iOS packaging |
| **[emuThreeDS](https://github.com/rf2222222/emuThreeDS)** | Citra fork (iOS-optimized) | ✅ iOS-specific | Our current submodule; sporadic updates; iOS perf hacks |

### 2.2 iOS App Ecosystem

| App | Backend | Build System | Notes |
|-----|---------|-------------|-------|
| **[Folium](https://github.com/folium-app/Folium)** | Cytrus (Lime3DS) | CMake + XCFramework | Active; multi-system; App Store; best iOS integration reference |
| **[Cytrus](https://github.com/folium-app/Cytrus)** | Lime3DS | CMake + SPM-compatible | Standalone iOS framework; the model to study |
| **Delta** | N/A | — | No 3DS support |

### 2.3 Key Observations

1. **Lime3DS + Cytrus/Folium** is the most mature iOS path. Cytrus ships as an XCFramework built with CMake, already in the App Store via Folium. This is the closest analog to what Provenance needs.

2. **Azahar** is actively developed but has no known clean iOS packaging. Adopting it directly would require significant investigation.

3. **emuThreeDS (`rf2222222`)** has valuable ARM64 SIMD, JIT/JITless, and Metal patches but tracks an older Citra base. The iOS-specific hacks are the key value — the upstream C++ is aging.

4. **JIT vs JITless** remains critical. Cytrus/Folium handle both paths. Any migration must preserve this.

---

## 3. Recommendation

### 3.1 Immediate: Fix PVAzahar GPU Regression (Option A)

**Priority: HIGH** — This should be done regardless of long-term strategy.

**Root cause hypothesis:** `TryPresenting` in `emu_window_vk.mm` calls `system.GPU().Renderer()`
before the GPU is fully initialized. The frame counter logs confirm someone was debugging this.

**Proposed fix:**
1. Add a null/validity check before calling `system.GPU().Renderer().TryPresent(0)`
2. Consider reverting `TryPresenting` to the simpler `VideoCore::g_renderer->TryPresent(0)` pattern
   from PVEmuThree to eliminate the `GPU()` initialization race
3. Fix `_frameInterval` from 120 to 60 in `PVAzaharCoreBridge.mm`
4. The `window_width/height` calculation (`drawableSize / scale`) may produce incorrect values —
   compare with PVEmuThree's approach and validate

### 3.2 Near-term: Consolidate to PVEmuThree (Option B)

**Priority: MEDIUM** — After GPU fix.

Given that PVAzahar is built on the same `Provenance-Emu/emuThreeDS` fork as PVEmuThree (not actual
Azahar upstream), there is limited benefit to maintaining both wrappers. PVEmuThree is the proven,
user-preferred core.

**Recommendation: Treat PVAzahar as an experimental variant, PVEmuThree as canonical.**

Tasks:
1. Port the `rightEyeDisableOption` from PVAzahar into PVEmuThree
2. Port the OSD notification integration (`PVPostOSD`) into PVEmuThree
3. Port the more defensive null-checking in `emu_window_vk.mm` into PVEmuThree
4. Deprecate PVAzahar with a comment/note — don't delete until GPU fix is confirmed stable

### 3.3 Long-term: Migrate to Lime3DS/Cytrus (Option C)

**Priority: LOW** — Research spike; 4–8 weeks of work.

The highest-leverage long-term move is migrating PVEmuThree's submodule from `rf2222222/emuThreeDS`
to a fork of **Lime3DS** (or adopting **Cytrus** as a prebuilt XCFramework).

**Rationale:**
- Lime3DS has active maintenance and better iOS support
- Cytrus/Folium prove it works in the App Store
- emuThreeDS is on an aging Citra base; Lime3DS has fixes and improvements

**Migration path:**
1. Study Cytrus/Folium's CMake + XCFramework integration
2. Create a `Provenance-Emu/Lime3DS` fork for Provenance-specific patches
3. Audit all override files (this document) for what must be ported vs. what's already upstream
4. The audio (CoreAudio sink), camera, and Metal window integration overrides are the most
   iOS-specific and require careful porting
5. The `settings.h` mobile layout additions (`MobilePortrait`/`MobileLandscape`) must be preserved

---

## 4. Override Files to Preserve in Any Migration

These files contain iOS-specific code that has no upstream equivalent and must be ported to any
new upstream base:

| File | Why Critical |
|------|-------------|
| `audio_core/coreaudio_sink.cpp` | Apple CoreAudio output — iOS/macOS only |
| `audio_core/coreaudio_input.cpp` | Microphone via CoreAudio |
| `Camera/CameraFactory.mm` | AVFoundation camera |
| `emu_window.cpp` / `emu_window.h` | Metal/iOS window base class |
| `emu_window_vk.mm` | Metal surface + Vulkan/MoltenVK integration |
| `common/settings.h` | `MobilePortrait`/`MobileLandscape` layout options; iOS input ownership |
| `renderer_vulkan.cpp` | `vmaDestroyImage` delay fix (crash prevention) |
| `CitraWrapper.mm` | Entire iOS integration layer |
| `InputBridge.mm` / `InputFactory.mm` | GCController integration |

---

## 5. Acceptance Criteria — Completed

- [x] Written recommendation on which option to pursue
- [x] List of all iOS perf hacks / override files in current cores (audit manifest above)
- [x] GPU regression root cause identified (§3.1)
- [x] Assessment of Lime3DS/Azahar build feasibility (§2)
- [x] Links to relevant forks/repos (§2.2)

## 6. Next Steps (Proposed)

- [ ] **Spike PR merged** — document approved
- [ ] **Fix PVAzahar GPU regression** — implement fix in `emu_window_vk.mm` per §3.1
- [ ] **Evaluate Cytrus as drop-in** — test-build on device; assess effort to adapt PVEmuThree override layer
- [ ] **Decision gate** — team decides Option B vs Option C based on Cytrus build test
- [ ] **Feature-flag iOS hacks** — wrap JIT/JITless, Metal, SIMD toggles behind compile flags
- [ ] **NAND/sdmc folder UI** (#2668)

---

## References

- [Issue #2840](https://github.com/Provenance-Emu/Provenance/issues/2840) — Spike issue
- [rf2222222/emuThreeDS](https://github.com/rf2222222/emuThreeDS) — PVEmuThree upstream
- [Provenance-Emu/emuThreeDS](https://github.com/Provenance-Emu/emuThreeDS) — PVAzahar upstream (Provenance fork)
- [Lime3DS-Emulator/Lime3DS](https://github.com/Lime3DS-Emulator/Lime3DS) — Recommended migration target
- [folium-app/Cytrus](https://github.com/folium-app/Cytrus) — iOS framework reference (Lime3DS-based)
- [folium-app/Folium](https://github.com/folium-app/Folium) — App Store app using Cytrus
- [AzaharEmulator/azahar](https://github.com/AzaharEmulator/azahar) — Azahar upstream (not currently used)
- Issue #2393 — 3DS regression from 2 versions ago
- Issue #2307 — Feature request: replace EmuThreeDS with Limon core
- Issue #2668 — 3DS NAND/sdmc folder management
