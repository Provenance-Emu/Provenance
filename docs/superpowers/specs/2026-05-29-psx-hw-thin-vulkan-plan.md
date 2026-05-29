Status: draft for review — 2026-05-29

# PSX Hardware Rendering on the Thin Libretro Vulkan Path

## TL;DR (the thesis)

This is **not** a "build Vulkan support from scratch" task. With the four PPSSPP
fixes that landed on develop today, the thin wrapper already has a complete,
generic Vulkan negotiation + present path that Beetle PSX HW exercises through
the **exact same code path** as PPSSPP (verified against upstream — see §B).

PSX HW rendering was *deliberately disabled* on Vulkan earlier (forced to GL),
citing "command buffer submission races with Metal presentation." Those reasons
are very likely now obsolete: the copy-based Vulkan handoff that fixed the race
explicitly names "Beetle PSX HW / PPSSPP" as the crash mode it was built to fix
(`PVThinLibretroFrontend.mm:7426`). **The plan is to flip two renderer-selection
knobs, re-enable Vulkan for PSX, and verify the race is gone** — not to write new
Vulkan infrastructure.

The only two real changes are renderer-selection knobs:
1. `PVThinLibretroCore.swift:491-493` currently pins Beetle PSX HW to the GL
   ("hardware" = Auto) renderer. Change it to request Vulkan.
2. `PVThinLibretroFrontend.mm:5819` (`GET_PREFERRED_HW_RENDER`) returns Vulkan
   for PSP only; the Auto path needs PSX to also resolve to Vulkan (belt-and-suspenders).

> **Maintainer expectation check:** CoreCapabilities.json lists
> `com.provenance.core.duckstation` at `qualityRank: 100`, *above* Beetle PSX HW
> (90). If "PSX HW" is mentally equated with DuckStation, note that the thin path
> **cannot** serve DuckStation — there is no `swanstation`/`duckstation` libretro
> dylib in `CoresRetro/RetroArch/modules/` (DuckStation is a placeholder PV* shell
> per CLAUDE.md's "Core taxonomy"). The thin-wrapper PSX HW core is **Beetle PSX
> HW** (`mednafen_psx_hw_libretro_*.dylib`). See §A.

---

## (a) Which core / dylib, and how to confirm at runtime

### The core

| Field | Value |
|---|---|
| Core identifier | `mednafen.psx.hw.libretro.framework` |
| CoreCapabilities.json | `PVCoreLoader/Sources/PVCoreLoader/Resources/CoreCapabilities.json:125-130` ("Beetle PSX with hardware renderer. Widescreen, enhanced resolution, and RetroAchievements.") |
| Dylib (iOS) | `CoresRetro/RetroArch/modules/mednafen_psx_hw_libretro_ios.dylib` (11.5 MB) |
| Dylib (tvOS) | `CoresRetro/RetroArch/modules/mednafen_psx_hw_libretro_tvos.dylib` |
| Upstream | `libretro/beetle-psx-libretro` (parallel-psx / "parallel-rsx" Vulkan backend) |
| Option key prefix | `beetle_psx_hw_*` (built with `HAVE_HW`; see CLAUDE.md note + `PVThinLibretroCore+Scaling.swift:179-184`) |

The software sibling is `mednafen.psx.libretro.framework` →
`mednafen_psx_libretro_ios.dylib` (software renderer only; out of scope).

### What is NOT available on the thin path

`CoresRetro/RetroArch/modules/` PSX-capable dylibs: only
`mednafen_psx_hw_libretro_ios.dylib`, `mednafen_psx_libretro_ios.dylib`, and
`pcsx_rearmed_libretro_ios.dylib`. There is **no** `swanstation` or `duckstation`
dylib. `com.provenance.core.duckstation` is the native PV* placeholder shell
(`Cores/DuckStation/PVDuckStation/Core.plist:6`), not a thin-wrapper-served core.
PCSX-ReARMed has no Vulkan negotiation backend (GL/software), so it is irrelevant
to this effort.

### Routing — does PSX reach the thin wrapper?

Yes. As of develop today, the thin wrapper is the default on all platforms and
**nothing force-routes PSX to thick**. `PVCoreFactory.swift:28-54`
(`PVCore.createInstance(forSystem:)`) swaps any `RetroArch`/`LibRetro`
principleClass to `PVThinLibretroCore` unless the user opts into the legacy thick
wrapper via `Defaults[.useLegacyRetroArchWrapper]`. The previous PPSSPP
force-to-thick special-case was removed (see the comment at
`PVCoreFactory.swift:39-42`: *"PPSSPP is no longer force-routed to the thick
wrapper… PSP now follows the normal thin-by-default routing"*). PSX HW therefore
goes through `PVThinLibretroCore` → `PVThinLibretroFrontend` by default.

### How to confirm at runtime

Watch the Console.app log (filter `Process = Provenance`) when launching a PSX
game on the Beetle PSX HW core:
- `ThinLibretro: swapping … → PVThinLibretroCore for com.provenance.psx`
  — confirms thin wrapper, not thick.
- After the change, the renderer-selection lines (see §E) confirm Vulkan vs GL.

---

## (b) HW render API + negotiation behavior (with upstream quotes)

Beetle PSX HW supports **three** renderers — software, OpenGL, and Vulkan —
selectable via the `beetle_psx_hw_renderer` core option. The Vulkan backend uses
the **same libretro Vulkan negotiation contract as PPSSPP**, so the thin
wrapper's existing machinery applies directly.

> **Verified against the shipped binary, not just upstream master.**
> `strings CoresRetro/RetroArch/modules/mednafen_psx_hw_libretro_ios.dylib`
> confirms the actual dylib we ship exposes `beetle_psx_hw_renderer`,
> `hardware_gl`, `hardware_vk`, `beetle_psx_hw_renderer_software_fb`, and
> `beetle_psx_hw_internal_resolution`, plus live Vulkan-backend strings
> (`[Vulkan]: Internal resolution scale …`, `Failed to create Vulkan device.`).
> So the Step 1 `hardware_vk` lever is valid for the artifact on disk, not only
> for `@master`. (Re-run this `strings` check if the dylib is ever refreshed.)

### Renderer option values (the load-bearing fact)

`beetle_psx_hw_renderer` valid values (`libretro_core_options.h`, default
`"hardware"`):

```
"hardware",     "Hardware (Auto)"          // defers to GET_PREFERRED_HW_RENDER
"hardware_gl",  "Hardware (OpenGL)"        // HAVE_OPENGL / HAVE_OPENGLES
"hardware_vk",  "Hardware (Vulkan)"        // HAVE_VULKAN — FORCES Vulkan
"software",     "Software"
```

### Renderer selection logic — `rsx/rsx_intf.c::rsx_intf_open`

This is the deciding code (fetched from `libretro/beetle-psx-libretro@master`):

- **`hardware_vk` → `FORCE_VULKAN`** (`rsx_intf.c:166-167`) → calls
  `rsx_vulkan_open(is_pal)` directly, **bypassing `GET_PREFERRED_HW_RENDER`
  entirely** (`rsx_intf.c:180-189`). This is the most deterministic way to get
  Vulkan and does not depend on the frontend's preferred-HW answer.
- **`hardware` (Auto)** → calls
  `RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER` (`rsx_intf.c:223`). If the frontend
  returns `RETRO_HW_CONTEXT_VULKAN` *or* `RETRO_HW_CONTEXT_DUMMY` (not supported),
  it tries Vulkan first (`rsx_intf.c:230-239`). If the frontend returns
  `OPENGL`/`OPENGL_CORE`, it takes the GL branch (`rsx_intf.c:243-252`).

> Current behaviour explained: the thin wrapper sets `beetle_psx_hw_renderer =
> "hardware"` (Auto) at `PVThinLibretroCore.swift:492`, and
> `GET_PREFERRED_HW_RENDER` returns `RETRO_HW_CONTEXT_OPENGLES3` for everything
> except PSP (`PVThinLibretroFrontend.mm:5824` + `5834`). So today PSX HW lands on
> the **GL** branch. That is exactly the lever to flip.

### Vulkan negotiation path — `rsx/rsx_lib_vulkan.cpp` (identical shape to PPSSPP)

- `rsx_vulkan_open` sets `hw_render.context_type = RETRO_HW_CONTEXT_VULKAN`
  (`rsx_lib_vulkan.cpp:292`), `context_reset = vk_context_reset` (`:295`), calls
  `SET_HW_RENDER` (`:298`), then registers the negotiation interface via
  `SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE` with `get_application_info` +
  `libretro_create_device` (`:301-310`).
- `libretro_create_device(... VkSurfaceKHR surface ...)` (`:240-285`) passes the
  surface straight into `new Vulkan::Context(instance, gpu, surface, …)`
  (`:264`). **It needs a non-null, queryable surface** — exactly what PPSSPP
  fix #2 (commit `7718853649`) already provides.
- `get_application_info` requests `apiVersion = VK_MAKE_VERSION(1, 0, 32)`
  (`rsx_lib_vulkan.cpp:101`). The thin wrapper already raises a too-low instance
  apiVersion to MoltenVK's best (`PVThinLibretroFrontend.mm:6521-6533`), so the
  1.1-promoted-function null-call hazard is already handled.

### Same context_reset re-entrancy class as PPSSPP — confirmed

`vk_context_reset` does `assert(context)` (`rsx_lib_vulkan.cpp:186`), where
`context` is the **static global** assigned only inside `libretro_create_device`
(`:264`). If `context_reset` fires re-entrantly *before* `create_device`
finished assigning that global, it asserts / null-derefs — the **same failure
class** PPSSPP fix #3 (`7388f57eca`) was written for. Better still, the upstream
core *expects* deferral: it has a defer queue for state-sets that arrive between
`SET_HW_RENDER` and `context_reset` and drains it at the end of `vk_context_reset`
(`rsx_lib_vulkan.cpp:54-56`, `204-209`). The thin wrapper's deferred-context-reset
mechanism (firing after `retro_load_game` returns) is precisely what this design
wants.

---

## (c) What the 4 PPSSPP fixes already cover vs. gaps

| Need for Beetle PSX HW Vulkan | Covered by | Status |
|---|---|---|
| Instance extensions (`VK_KHR_surface`, `VK_EXT_metal_surface`, `get_physical_device_properties2`) | Fix #1 (`592faadf59`) → `PVThinLibretroFrontend.mm:6515-6519` | **Covered** |
| Non-null queryable `VkSurfaceKHR` for `create_device` | Fix #2 (`7718853649`) → private CAMetalLayer surface at `PVThinLibretroFrontend.mm:6908-6944`, passed at `:6954` | **Covered** (PSX needs it too — `rsx_lib_vulkan.cpp:264`) |
| `context_reset` deferred until after `retro_load_game` | Fix #3 (`7388f57eca`) → `finalizeVulkanContextDeferred` re-entrancy guard (`:6268-6287`) + `fireDeferredVulkanContextResetIfNeeded` (`:6294-6303`) | **Covered** (PSX has the same `assert(context)` re-entrancy — `rsx_lib_vulkan.cpp:186`) |
| Negotiation interface support advertised | `GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT` → Vulkan v1 (`:5791-5808`) | **Covered** |
| Device extensions (incl. portability subset, push_descriptor, etc.) | `kDesiredExtensions[]` already names "Beetle PSX HW" (`:6635`, `:6641-6659`) | **Covered** |
| apiVersion bump for 1.0.32-requesting cores | `:6521-6533` | **Covered** |
| Vulkan frame present without GPU use-after-free | The copy handoff `didRenderVulkanFrameWithMTLTexture:` explicitly built for "Beetle PSX HW / PPSSPP" (`:7419-7445`); the legacy zero-copy path is a fallback | **Covered** (core-agnostic) |
| **GET_PREFERRED_HW_RENDER returns Vulkan for PSX** | — currently PSP-only (`:5834`) | **GAP #1** |
| **Core option picks Vulkan, not GL/Auto-that-resolves-to-GL** | — currently `"hardware"` (Auto) + the GL force block at `:491-494` | **GAP #2** |

Net: the entire Vulkan negotiation/present pipeline is generic and already
proven; **only the two renderer-selection knobs need changing.**

---

## (d) Step-by-step change plan

All changes are in the thin wrapper. No upstream dylib changes needed.

### Step 1 — Make the core request Vulkan (PRIMARY lever)

File: `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore.swift:488-494`

Today:
```swift
// Beetle PSX HW: use OpenGL hardware renderer instead of Vulkan.
// Vulkan via MoltenVK has command buffer submission races with Metal
// presentation in the thin wrapper. OpenGL works (same path as Mupen64).
if coreId.contains("psx_hw") || coreId.contains("beetle_psx") {
    setDefaultOption("beetle_psx_hw_renderer", value: "hardware")
    setDefaultOption("beetle_psx_hw_renderer_software_fb", value: "enabled")
}
```

Change `beetle_psx_hw_renderer` to **`"hardware_vk"`**. Per `rsx_intf.c:166-167,
180-189`, this takes the `FORCE_VULKAN` branch and calls `rsx_vulkan_open`
directly, bypassing `GET_PREFERRED_HW_RENDER` — the most deterministic route and
the one least coupled to other systems' behaviour.

Decision — `setDefaultOption` vs `setCoreOption`:
- `setDefaultOption` (`PVThinLibretroCore.swift:746-750`) only writes if the user
  hasn't already set the key — it respects a user who manually chose GL/software.
- For the initial bring-up I recommend `setDefaultOption("beetle_psx_hw_renderer",
  "hardware_vk")` so power users can still pick GL/software in the core-options
  UI. If we want to *guarantee* Vulkan during validation, temporarily use
  `_bridge.setCoreOption(...)` (unconditional) like the Saturn-region line at
  `:504`, then relax to `setDefaultOption` once proven.
- Keep `beetle_psx_hw_renderer_software_fb = "enabled"` (software framebuffer
  readback for accurate effects); it is renderer-agnostic.

Update the misleading comment block (`:488-490`) to reflect that Vulkan is now
the chosen renderer and why (race fixed by the copy handoff).

### Step 2 — Make Auto resolve to Vulkan for PSX (belt-and-suspenders)

File: `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.mm:5819-5840`
(`RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER`)

Add a PSX branch alongside the existing PSP branch so that *even if* the option
is left at `"hardware"` (Auto) or a user resets it, the Auto path
(`rsx_intf.c:223,230-239`) still selects Vulkan:

```objc
static NSString * const PVPSPSystemIdentifier = @"com.provenance.psp";
static NSString * const PVPSXSystemIdentifier = @"com.provenance.psx";
if ([self.systemIdentifier isEqualToString:PVPSPSystemIdentifier]
    || [self.systemIdentifier isEqualToString:PVPSXSystemIdentifier]) {
    pref = RETRO_HW_CONTEXT_VULKAN;
}
```

Mirror the constant convention (CLAUDE.md: no inline `com.provenance.*` more than
once; reuse a single `NSString * const`). This matches the PSP precedent commit
referenced as `e66b2a28a4`.

### Step 3 — Ensure the GL-rejection block does not break PSX

File: `PVThinLibretroFrontend.mm:5948-5972` (`setupHardwareRenderCallback:`)

The "reject GL HW context" block is **scoped to PSP only** (`:5968` checks
`PVPSPSystemIdentifier`). With `hardware_vk` (Step 1), Beetle PSX HW calls
`SET_HW_RENDER` with `RETRO_HW_CONTEXT_VULKAN` directly (`rsx_lib_vulkan.cpp:292,
298`), so it enters the Vulkan branch at `:5927` and never reaches the GL block.
**No change required**, but verify PSX does not need to be added to the rejection
list (it shouldn't, because `FORCE_VULKAN` never offers a GL context). If Step 1
is left at Auto instead of `hardware_vk`, the core probes renderers in order and
this block stays PSP-only — fine, because Step 2 already steers Auto to Vulkan.

### Step 4 — (Optional) internal resolution / upscaling default

File: `PVThinLibretroCore.swift` (same PSX block) and/or
`PVThinLibretroCore+Scaling.swift:179-184`

`beetle_psx_hw_internal_resolution` valid values `"1x(native)" | "2x" | "4x" |
"8x" | "16x"`, default `"1x(native)"`. Leave at native for first bring-up
(perf-safe); consider exposing 2x via the scaling integration once stable.
The widescreen hack key is already handled
(`PVThinLibretroCore+Scaling.swift:184`: `beetle_psx_hw_widescreen_hack`).

### Step 5 — Build & lint

- `swiftlint lint --path PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore.swift`
- Full workspace build (Tier 5 module + ObjC++) — verify the `.mm` compiles for
  iOS and tvOS (`#if HAVE_VULKAN` already guards the new branch).

---

## (e) Risks + how to validate

### Validation — log lines to watch (Console.app, `Process = Provenance`)

Success sequence on a PSX game with Beetle PSX HW after the change:
1. `ThinLibretro: swapping … → PVThinLibretroCore for com.provenance.psx`
2. `ThinFrontend: core requesting Vulkan HW context (context_reset=…)`
   (`:5928`) — confirms the core asked for Vulkan, not GL.
3. `ThinFrontend: created private Metal VkSurfaceKHR=… for core …` (`:6934`)
4. `ThinFrontend: invoking core create_device(instance=… surface=…)` (`:6946`)
   then `ThinFrontend: core created VkDevice=…` (`:6974`).
5. `[VK] context_reset deferred until after retro_load_game returns …` (`:6278`)
   then `[VK] firing deferred context_reset (post retro_load_game) …` (`:6298`)
   then `[VK] deferred context_reset completed` (`:6301`).
6. **The success signal:** `[VK] handoff (copy) frame #0 tex=… WxH … thread=emu`
   (`:7437`) ticking up — mirrors the PPSSPP `[VK] handoff (copy)` signal that
   indicates frames are reaching the Metal presenter.

Failure signatures and where they point:
- `ThinFrontend: vkCreateMetalSurfaceEXT failed …` / `…unavailable` (`:6937`,
  `:6941`) → surface creation broke; PSX `libretro_create_device` will fail.
- `ThinFrontend: core create_device returned false …` (`:6962`) → queue/extension
  mismatch inside parallel-psx `Vulkan::Context::is_valid()`
  (`rsx_lib_vulkan.cpp:267`). Check device-extension enable list.
- Crash at `context_reset` with null/asserted `context` → re-entrancy guard not
  taken; confirm `_inRetroLoadGame` was true during negotiation (the deferral at
  `:6269-6279` should cover it).
- `[VK] handoff (legacy zero-copy) …` warning (`:7452`) → presenter lacks
  `didRenderVulkanFrameWithMTLTexture:`; the VkImage-recycle race could reappear.
  **Confirmed implemented** in `PVUI/Sources/PVUIBase/PVGLViewController/PVMetalViewController.swift`
  — and PPSSPP already renders through this exact copy path on Vulkan, so the
  selector must be present (otherwise PPSSPP would hit the legacy warning). Treat
  this as a watch-point, not an open task.
- **Silent black screen (no crash):** `vk_context_reset` early-returns if
  `GET_HW_RENDER_INTERFACE` reports a mismatched `interface_version`
  (`rsx_lib_vulkan.cpp:177-184`). PPSSPP working through the same wrapper implies
  the reported version is compatible, but if PSX shows a black screen with no
  crash and no `[VK] handoff` lines, this version match is the first suspect.

### Risks

1. **BIOS requirement (highest practical risk).** PSX requires SCPH BIOS
   (`scph5500/5501/5502.bin` or `scph7001`, etc.). The thin wrapper syncs
   user-imported BIOS from `BIOSPath` → the core's system directory **before**
   `retro_load_game` via `_syncBIOSResources` (`PVThinLibretroFrontend.mm:2459-2514`;
   never overwrites existing files). This is renderer-independent — a missing BIOS
   fails the *same* way on GL and Vulkan, so it is not a new Vulkan risk, but it
   *will* mask a "Vulkan works" verdict if the tester's BIOS isn't present. Confirm
   BIOS present before concluding anything about the renderer. The BIOS-hint capture
   at `:1022-1025` surfaces missing-file errors in logs.

2. **Re-opening the original race.** PSX HW was forced to GL precisely to dodge the
   Vulkan/Metal present race. The copy handoff (`:7419-7445`) is the fix that made
   PPSSPP safe and is explicitly written for Beetle PSX HW. Risk is low but this is
   the thing to watch first — if frames tear/crash, the copy path or its GPU-
   completion wait is the suspect, not the negotiation.

3. **Upscaling perf.** Keep `internal_resolution` at native for bring-up; higher IR
   multiplies VRAM/GPU cost and can hide a correctness regression behind a perf
   stall.

4. **`hardware_vk` availability.** The value only exists if the dylib was built
   with `HAVE_VULKAN`. The buildbot iOS/tvOS Beetle PSX HW dylibs are Vulkan-capable
   (parallel-psx is the whole point of `_hw`), but if a stale dylib lacks it, the
   core falls back to software with the osd_message at `rsx_intf.c:194-196`. Watch
   for that log line; if seen, the dylib needs refreshing (it is a prebuilt
   buildbot artifact, not built from the in-repo submodule — see CLAUDE.md
   "retroarch-buildbot-dylibs").

5. **Two systems, one knob.** Beetle PSX HW also serves nothing else, so the
   `coreId.contains("psx_hw")` guard (`PVThinLibretroCore.swift:491`) is safe and
   does not affect the software `mednafen_psx` core (which has no `_hw_` keys).

### Rollback

If Vulkan regresses, revert Step 1 to `"hardware"` (Auto) and remove the PSX
branch in Step 2 — that restores today's GL behaviour with a one-line change each.
Users can also fall back via Settings > Advanced > "Use Legacy RetroArch Wrapper"
(thick wrapper), or set `beetle_psx_hw_renderer` to `hardware_gl`/`software` in the
core-options UI.

---

## Source index

Local (develop):
- `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.mm`
  — `:5791-5808` negotiation support; `:5819-5840` GET_PREFERRED_HW_RENDER;
  `:5925-5972` setupHardwareRenderCallback (Vulkan branch + PSP GL rejection);
  `:6463` createVulkanInstance; `:6515-6519` instance exts; `:6521-6533` apiVersion
  bump; `:6635-6659` device exts; `:6908-6959` surface + create_device;
  `:6252-6303` deferred context_reset; `:7419-7455` Vulkan present/copy handoff;
  `:2459-2514` `_syncBIOSResources`.
- `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore.swift:488-494` PSX HW
  renderer option; `:746-750` setDefaultOption semantics.
- `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Scaling.swift:179-184`
  PSX widescreen/scaling keys.
- `PVUI/Sources/PVUIBase/Emulator/PVCoreFactory.swift:28-54` thin/thick routing.
- `PVCoreLoader/Sources/PVCoreLoader/Resources/CoreCapabilities.json:111-137` PSX
  core metadata.
- `CoresRetro/RetroArch/modules/mednafen_psx_hw_libretro_{ios,tvos}.dylib`.

Upstream (`libretro/beetle-psx-libretro@master`):
- `rsx/rsx_intf.c:149-272` `rsx_intf_open` (renderer selection, FORCE_VULKAN,
  GET_PREFERRED_HW_RENDER).
- `rsx/rsx_lib_vulkan.cpp:92-104` get_application_info (apiVersion 1.0.32);
  `:175-212` vk_context_reset (`assert(context)`, defer drain); `:240-285`
  libretro_create_device (uses surface); `:287-313` rsx_vulkan_open (SET_HW_RENDER
  + negotiation interface).
- `libretro_core_options.h` — `beetle_psx_hw_renderer`
  {`hardware`,`hardware_gl`,`hardware_vk`,`software`} default `hardware`;
  `beetle_psx_hw_internal_resolution` {`1x(native)`…`16x`} default `1x(native)`.
