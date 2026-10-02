# Mupen64Plus iOS/tvOS Patches

This document lists the iOS/tvOS-specific changes to the Mupen64Plus sources and where they live.
It serves as a porting guide when updating the dependencies.

## Component Status

| Component | Source | Base | Provenance patches |
|-----------|--------|------|--------------------|
| mupen64plus-core | submodule, Provenance-Emu fork `Provenance-master` | upstream b20b27ebf9 (2.6.0+, 0x020600) | 1 (new_vi guard) |
| mupen64plus-rsp-hle | submodule, Provenance-Emu fork `Provenance-master` | upstream 8a7a472a71 | none |
| mupen64plus-rsp-cxd4 | submodule, Provenance-Emu fork `Provenance-master` | upstream 00906a9264 | none |
| mupen64plus-video-rice | submodule, Provenance-Emu fork `Provenance-master` | upstream f0a7b9f391 | 2 |
| GLideN64 | **vendored** (not a gitlink) | Provenance-Emu/GLideN64@provenance, 2018 base cbf5821f8e | see below |
| Mupen64Plus-NX (RetroArch) | real submodule | spm-2024 (388bd4b) | 72 commits behind libretro:develop (2026-03) |

## Submodules and patches

Core, rsp-hle, rsp-cxd4 and rice are real submodules tracking each fork's `Provenance-master`
branch: upstream master plus the Provenance commits, in order. The patch files those commits were
made from are listed below; keep them as separate commits on `Provenance-master` so a future
upstream bump is a rebase.

GLideN64 is still vendored as plain files at `Sources/Plugins/Video/gliden64`, even though
`.gitmodules` has an entry for it. The upstream jump is about 916 commits (threaded GL wrapper,
new default-framebuffer handling, roughly 60 new source files across two explicit-file-list
targets) and needs on-device GL testing, so it was left at the 2018 fork base. The GFX and RSP
plugin API versions (2.2 / 2.0) and the `GFX_INFO`/`RSP_INFO` layouts are unchanged in core 2.6,
so the old GLideN64 keeps working with the updated core. `Provenance-Emu/GLideN64@provenance_2025`
is an earlier, never-adopted port of the NPOT and `InitiateGFX` patches onto a 2025 upstream base.

## Patches in `Sources/PVMupenBridge/`

These files are entirely Provenance-specific (no upstream equivalent):

### `vidext.m` — Video Extension (iOS/tvOS)
The video extension hooks replace the SDL-based windowing system with iOS-native rendering.
Key implementations:
- `VidExt_Init` — no-op (iOS manages the GL context lifecycle; returns `M64ERR_SUCCESS`)
- `VidExt_Quit` — sets `sActive = 0`; not a true no-op (state tracked for `VidExt_VideoRunning`)
- `VidExt_VideoRunning` — returns `sActive` (1 after `VidExt_SetVideoMode`, 0 after `VidExt_Quit`)
- `VidExt_ListFullscreenModes` — returns two entries: 640×480 default and current device screen size; note: currently assigns `SizeArray` to a local stack variable rather than filling the caller-provided buffer — a known bug with no visible impact since GLideN64 ignores the mode list
- `VidExt_SetVideoMode` — stores width/height/depth on the bridge object, sets `sActive = 1`
- `VidExt_GL_GetProcAddress` — uses `dlsym(RTLD_NEXT, ...)` to locate GL symbols
- `VidExt_GL_SwapBuffers` — calls `[current swapBuffers]` on the bridge
- `VidExt_GL_SetAttribute` / `VidExt_GL_GetAttribute` — returns `M64ERR_UNSUPPORTED` (no SDL)
- `VidExt_InFullscreenMode` — always returns 1

**Port requirement**: No upstream equivalent. Re-create wholesale when updating. The API is
stable (m64p_vidext.h v3.0.0) and unlikely to change.

### `eventloop.m` — Event Loop Stub
Stubs out SDL event loop functions that are not needed on iOS:
- `event_set_core_defaults`, `event_initialize` — no-op
- `event_sdl_keydown` / `event_sdl_keyup` — no-op (input handled via bridge)
- `event_gameshark_active` / `event_set_gameshark` — stub (GameShark via cheats API)

**Port requirement**: Check if new event functions were added to `main/event.h` in upstream.

### `new_vi_main.m` — VI (Vertical Interrupt) Hook
Replaces `main/main.c`'s `new_vi()` function to call `[current videoInterrupt]` on the bridge.
Also applies cheats at boot and every VI as per the cheat API.

**Port requirement**: Check `new_vi()` signature in upstream `main/main.h` for changes.
If `g_dev` / `g_cheat_ctx` / `g_gs_vi_counter` are renamed, update references here.

### `screenshot.m` — Screenshot Stub
Implements `osd/screenshot.h` for iOS (likely no-op or writes to app documents).

### `PVMupenBridge+Mupen.m` — Audio and Configuration
- `MupenAudioLenChanged` — custom audio resampling to 44100 Hz
  - Uses fixed-point linear interpolation from the N64's native DAC rate
    (`AI_DACRATE == 0` is treated as 44.1 kHz, matching the core's default)
  - Writes to `ringBufferAtIndex:0` for the audio engine
- `MupenAudioSampleRateChanged` — forces 44100 Hz sample rate
- `ConfigureCore` — maps Provenance settings to mupen64plus config
- `ConfigureVideoGeneral` — screen size from UIWindow bounds
- `ConfigureGLideN64` — maps Provenance settings to GLideN64 config
  - txPath points to `<romFolder>/hires_texture/`
  - NPOT-safe texture options

**Port requirement**: Verify `AUDIO_INFO` struct field names, `AI_LEN_REG`, `AI_DRAM_ADDR_REG`,
`AI_DACRATE_REG` in `plugin/plugin.h` are unchanged. Check `ConfigSetParameter` signature.

---

## Patches in `Sources/Plugins/Core/Core/` (mupen64plus-core)

### 0001 — compile out `new_vi()` under `IN_OPENEMU` (still required)
- **File**: `src/main/main.c`
- **Why**: Provenance supplies its own `new_vi()` in `PVMupenBridge/new_vi_main.m`; the core's copy
  would be a duplicate symbol. `IN_OPENEMU=1` is set for every target in `PVMupen64Plus.xcodeproj`.

### Dropped when moving to 2.6.0+
- `files_macos.c` iOS/tvOS config path: the bridge always passes `ConfigPath`/`DataPath` to
  `CoreStartup`, so `osal_get_user_configpath()` is never used.
- `DebugMessage` buffer 256 → 512, ROM size 64 MB → 256 MB, ROM byte-swap endian fix, xxHash
  update, disabled 64-bit dynarec: all upstream now (or superseded).
- ROM database `is_initialized` / `romdatabase_init()` / `romdatabase_reset()`: upstream fixed
  `romdatabase_close()` (ad347c3c74); the bridge no longer calls `romdatabase_init()`.
- AI 44.1 kHz `ai_init()` hack: replaced by bridge glue — `MupenAudioLenChanged` treats
  `AI_DACRATE == 0` as 44.1 kHz, the same default the core's `ai_controller` uses.

### Build notes for 2.6.0+
- The bridge target compiles the upstream Makefile `SOURCE` set minus `api/vidext.c`,
  `main/eventloop.c`, `main/screenshot.c` (replaced by `PVMupenBridge/*.m`), `osd/*` and
  `main/netplay.c` (`M64P_NETPLAY` off), plus `subprojects/md5` and `subprojects/minizip`
  (`NOCRYPT`/`NOUNCRYPT`, as the Makefile does for the bundled copy).
- `vidext.m` implements the 2.6 additions (`VidExt_InitWithRenderMode`, `_SetVideoModeWithRate`,
  `_ListFullscreenRates`, `_GL_GetDefaultFramebuffer`, `_VK_*` → unsupported).
- `Compatibility/SDL` gained `SDL_timer.h` and `SDL_WasInit`.
- `m64p_media_loader` must be zero-initialised: the core calls every non-NULL callback.
- Battery saves: new saves are named `<goodname>-<md5 prefix>.<ext>` (`SaveFilenameFormat=1`),
  but the core first looks for the old `<goodname>.<ext>` file and keeps using it if present.
- Save states: 2.6 writes format 1.9 and still loads the 1.3 states the old core wrote.

## Patches in `Sources/Plugins/Video/gliden64/` (GLideN64)

From the Provenance-Emu/GLideN64 `provenance` and `provenance_2025` branches:

### 1. iOS/Emscripten NPOT texture wrap mode — APPLIED (2025-03)
- **File**: `src/Graphics/OpenGLContext/opengl_TextureManipulationObjectFactory.cpp`
- **Change**: Wraps `glTexParameteri(GL_TEXTURE_WRAP_S/T)` in `#if !defined(OS_IOS) && !defined(EMSCRIPTEN)` guard;
  forces `GL_CLAMP_TO_EDGE` on iOS/tvOS and Emscripten/WebGL builds, while leaving the
  original wrap mode (`GL_REPEAT`/`GL_MIRRORED_REPEAT`) on other platforms.
- **Why**: OpenGL ES on iOS and WebGL via Emscripten only support `GL_CLAMP_TO_EDGE` for
  non-power-of-two (NPOT) textures. Using `GL_REPEAT` or `GL_MIRRORED_REPEAT` on NPOT
  textures is undefined and causes rendering artifacts (black textures, GL errors), so the
  implementation forces `GL_CLAMP_TO_EDGE` on those platforms.
- **Source**: `Provenance-Emu/GLideN64@provenance_2025` commit `d0c7c06476`

### 2. `int` return type for `InitiateGFX` — ALREADY APPLIED
- **File**: `src/CommonPluginAPI.cpp`
- **Change**: `EXPORT BOOL CALL InitiateGFX` → `EXPORT int CALL InitiateGFX`
- **Why**: `BOOL` maps to `signed char` on some platforms; `int` matches the plugin ABI
- **Source**: Applied directly, not needing a patch guard

### 3. iOS file I/O — `src/osal/osal_files_ios.mm`
- **File**: `src/osal/osal_files_ios.mm`
- **Why**: iOS does not have a writable `/usr/local/` — GLideN64's config/shader cache paths
  must point to the app sandbox.

### 4. iOS logging — `src/Log_ios.mm`, `src/TxDbg_ios.mm`
- **File**: `src/Log_ios.mm`, `src/TxDbg_ios.mm`
- **Why**: GLideN64's default logging writes to stdout/stderr. On iOS we redirect to NSLog /
  PVLogging. These files replace the default `Log.cpp` / `TxDbg.cpp`.

---

## Update Roadmap

1. **Submodules** (core, rsp-hle, rsp-cxd4, rice): rebase `Provenance-master` onto the new upstream
   master, then bump the gitlink. Rebuild `PVMupen64Plus` for iOS and tvOS and diff the compiled file
   list against the upstream Makefile `SOURCE` set.
2. **GLideN64**: convert to a submodule on `Provenance-Emu/GLideN64@Provenance-master` with:
   - NPOT texture wrap-mode guard (`OS_IOS`)
   - `InitiateGFX` returning `int`
   - Keep `Log_ios.mm`, `TxDbg_ios.mm`, `osal/osal_files_ios.mm` (outside the submodule if possible)
   - Check that upstream's default-framebuffer path (`VidExt_GL_GetDefaultFramebuffer`) replaces the
     old iOS framebuffer binder, and that the threaded GL wrapper stays off with EAGL
   - `SetOSDCallback` must still exist; the bridge looks it up with `dlsym`.
3. **Mupen64Plus-NX submodule**: update `Cores/Mupen64Plus-NX/mupen64plus-libretro-nx` to a
   newer commit on `Provenance-Emu/mupen64plus-libretro-nx@spm-2024`, after the upstream
   Provenance fork is rebased onto `libretro:develop` (72 commits behind as of 2026-03).

## References

- Upstream mupen64plus-core: https://github.com/mupen64plus/mupen64plus-core
- Provenance fork (core): https://github.com/Provenance-Emu/mupen64plus-core/tree/Provenance-master
- Upstream GLideN64: https://github.com/gonetz/GLideN64
- Provenance fork (GLideN64): https://github.com/Provenance-Emu/GLideN64/tree/provenance_2025
- Upstream mupen64plus-libretro-nx: https://github.com/libretro/mupen64plus-libretro-nx
- Provenance fork (NX): https://github.com/Provenance-Emu/mupen64plus-libretro-nx/tree/spm-2024
