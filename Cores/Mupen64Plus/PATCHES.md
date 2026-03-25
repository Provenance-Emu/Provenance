# Mupen64Plus iOS/tvOS Patches

This document lists all iOS/tvOS-specific patches applied to vendored Mupen64Plus source code.
It serves as a porting guide when updating the vendored dependencies.

## Component Status

| Component | Source | Version | Upstream Gap |
|-----------|--------|---------|-------------|
| mupen64plus-core | vendored | v2.5.1 (0x020501) | 424 commits behind (2026-02) |
| GLideN64 | vendored | v2.0.0 (0x020000) | ~854 commits behind provenance_2025 |
| mupen64plus-rsp-hle | vendored | unknown | unknown |
| mupen64plus-rsp-cxd4 | vendored | unknown | unknown |
| mupen64plus-video-rice | vendored | unknown | unknown |
| Mupen64Plus-NX (RetroArch) | real submodule | spm-2024 (388bd4b) | 72 commits behind libretro:develop (2026-03) |

## Note on Vendored vs Submodule

Despite entries in `.gitmodules`, the source code in `Sources/Plugins/Core/Core`,
`Sources/Plugins/Video/gliden64`, etc. is **vendored directly** as regular files — not
managed as real git submodules. `git submodule status` will not show these. Any update
requires replacing the files manually and re-applying the patches below.

Only `Cores/Mupen64Plus-NX/mupen64plus-libretro-nx` is a real git submodule (gitlink).

---

## Patches in `Sources/PVMupenBridge/`

These files are entirely Provenance-specific (no upstream equivalent):

### `vidext.m` — Video Extension (iOS/tvOS)
The video extension hooks replace the SDL-based windowing system with iOS-native rendering.
Key implementations:
- `VidExt_Init` / `VidExt_Quit` — no-op (iOS manages the GL context lifecycle)
- `VidExt_ListFullscreenModes` — returns device screen size
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

From the Provenance-Emu/mupen64plus-core `provenance` branch (7 commits ahead of upstream master):

### 1. Quick hack for paths on tvOS and iOS
- **File**: `src/osal/files_macos.c` (or similar)
- **Change**: Adjust file path resolution for iOS sandbox / app bundle paths
- **Why**: iOS apps cannot write to `/usr/local/` or system paths; must use app Documents

### 2. Increase buffer size to prevent overflows
- **File**: Likely `src/main/` or `src/backends/`
- **Change**: Enlarged a static buffer that overflowed on large ROMs or heavy cheat usage
- **Why**: iOS memory layout causes different alignment; some buffers need to be larger

### 3. Add macro to remove new_vi
- **File**: `src/main/main.h` or `src/main/main.c`
- **Change**: Adds `PROVENANCE` guard macro to remove the default `new_vi()` implementation
- **Why**: Provenance supplies its own `new_vi()` in `new_vi_main.m`; having both causes
  duplicate-symbol linker errors

---

## Patches in `Sources/Plugins/Video/gliden64/` (GLideN64)

From the Provenance-Emu/GLideN64 `provenance` and `provenance_2025` branches:

### 1. iOS NPOT texture wrap mode — APPLIED (2025-03)
- **File**: `src/Graphics/OpenGLContext/opengl_TextureManipulationObjectFactory.cpp`
- **Change**: Wraps `glTexParameteri(GL_TEXTURE_WRAP_S/T)` in `#if !defined(OS_IOS)` guard;
  forces `GL_CLAMP_TO_EDGE` on iOS/tvOS
- **Why**: OpenGL ES on iOS only supports `GL_CLAMP_TO_EDGE` for non-power-of-two (NPOT)
  textures. Using `GL_REPEAT` or `GL_MIRRORED_REPEAT` on NPOT textures is undefined and
  causes rendering artifacts (black textures, GL errors).
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

When a future update replaces the vendored source, apply patches in this order:

1. **mupen64plus-core**: Apply the 3 patches from `Provenance-Emu/mupen64plus-core@provenance`
   (or cherry-pick onto the new version). The `PROVENANCE` macro guard for `new_vi` is critical
   — without it the build will fail with a duplicate symbol error.

2. **GLideN64**: After replacing files, apply:
   - NPOT texture wrap-mode guard (already in this file)
   - Disable `glDebugMessageCallback` if it exists in the new version
   - Keep `Log_ios.mm`, `TxDbg_ios.mm`, `osal/osal_files_ios.mm` — these are wholly new files

3. **mupen64plus-video-rice**: Verify GLES conditional compilation paths still compile.

4. **Mupen64Plus-NX submodule**: Update `Cores/Mupen64Plus-NX/mupen64plus-libretro-nx` to a
   newer commit on `Provenance-Emu/mupen64plus-libretro-nx@spm-2024`, after the upstream
   Provenance fork is rebased onto `libretro:develop` (72 commits behind as of 2026-03).

---

## References

- Upstream mupen64plus-core: https://github.com/mupen64plus/mupen64plus-core
- Provenance fork (core): https://github.com/Provenance-Emu/mupen64plus-core/tree/provenance
- Upstream GLideN64: https://github.com/gonetz/GLideN64
- Provenance fork (GLideN64): https://github.com/Provenance-Emu/GLideN64/tree/provenance_2025
- Upstream mupen64plus-libretro-nx: https://github.com/libretro/mupen64plus-libretro-nx
- Provenance fork (NX): https://github.com/Provenance-Emu/mupen64plus-libretro-nx/tree/spm-2024
