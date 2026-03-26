# Provenance Modifications to Mednafen

Mednafen is distributed as a source zip from https://mednafen.github.io/ (not a git
repository), so modifications cannot be tracked via `git diff` against upstream.  This
file documents every change Provenance has made to the vendored Mednafen source so they
can be re-applied whenever the Mednafen source is updated.

> **When updating Mednafen:** replace `Sources/mednafen/` with the new source, then
> re-apply every patch listed below.  Each entry includes the exact code to add/edit.

---

## 1. RetroAchievements RAM accessor functions (PR #3510, Phase 1)

**Purpose:** Expose raw RAM pointers so the rcheevos runtime can read emulator memory
for achievement condition evaluation.

**Pattern:** At the **end** of each system `.cpp` file, after the last existing function,
add an `extern "C"` block with a `_ptr()` accessor and a `_size()` accessor.

### `src/psx/psx.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
extern "C" {
    uint8_t* mdfn_psx_mainram_ptr(void) { return MainRAM.data8; }
    size_t   mdfn_psx_mainram_size(void) { return 2 * 1024 * 1024; }
}
```

### `src/nes/nes.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
extern "C" {
    uint8_t* mdfn_nes_ram_ptr(void) { return MDFN_IEN_NES::RAM; }
    size_t   mdfn_nes_ram_size(void) { return 0x800; }
}
```

### `src/snes_faust/snes.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
extern "C" {
    uint8_t* mdfn_snes_faust_wram_ptr(void) { return WRAM; }
    size_t   mdfn_snes_faust_wram_size(void) { return sizeof(WRAM); }
}
```

### `src/pce/pce.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
extern "C" {
    uint8_t* mdfn_pce_baseram_ptr(void) { return BaseRAM; }
    size_t   mdfn_pce_baseram_size(void) { return IsSGX ? 32768 : 8192; } // 32 KB for SuperGrafx, 8 KB for PCE
}
```

### `src/pce_fast/pce.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
extern "C" {
    uint8_t* mdfn_pce_fast_baseram_ptr(void) { return MDFN_IEN_PCE_FAST::BaseRAM; }
    size_t   mdfn_pce_fast_baseram_size(void) { return MDFN_IEN_PCE_FAST::IsSGX ? 32768 : 8192; } // 32 KB for SuperGrafx, 8 KB for PCE
}
```

### `src/ss/ss.cpp` — end of file

```cpp
// ---- Provenance RetroAchievements RAM accessors ----
//
// NOTE: WorkRAML / WorkRAMH are uint16_t arrays that Mednafen accesses through
// ne16_rbo_be / ne16_wbo_be helpers which swap byte lanes on little-endian hosts
// (byte_offset ^ 1 for 8-bit reads).  The reinterpret_cast<uint8_t*> below
// exposes raw host memory layout — byte-wise readers see scrambled byte order.
//
// The Swift bridge corrects this via MednafenRcheevosByteSwapModeWord16:
// the read-memory callback XORs each logical offset by 1 before reading, which
// reverses the ne16_rbo_be swap.  Callers that do NOT apply this correction will
// read garbled bytes.  See MednafenRcheevosObjC.h for the byteSwapMode field.
extern "C" {
    uint8_t* mdfn_ss_workraml_ptr(void) { return reinterpret_cast<uint8_t*>(WorkRAML); }
    size_t   mdfn_ss_workraml_size(void) { return sizeof(WorkRAML); }
    uint8_t* mdfn_ss_workramh_ptr(void) { return reinterpret_cast<uint8_t*>(WorkRAMH); }
    size_t   mdfn_ss_workramh_size(void) { return sizeof(WorkRAMH); }
}
```

---

## 2. Function declarations in `MednafenGameCoreC.h` (PR #3510, Phase 1)

**File:** `Cores/Mednafen/Sources/MednafenGameCoreC/include/MednafenGameCoreC/MednafenGameCoreC.h`

This header is NOT upstream Mednafen — it is a Provenance-authored bridge header.
Add the following declarations (they match the `extern "C"` blocks above):

```c
// PSX
uint8_t* mdfn_psx_mainram_ptr(void);
size_t   mdfn_psx_mainram_size(void);

// NES
uint8_t* mdfn_nes_ram_ptr(void);
size_t   mdfn_nes_ram_size(void);

// Saturn
uint8_t* mdfn_ss_workraml_ptr(void);
size_t   mdfn_ss_workraml_size(void);
uint8_t* mdfn_ss_workramh_ptr(void);
size_t   mdfn_ss_workramh_size(void);

// PCE / PCE-fast
uint8_t* mdfn_pce_baseram_ptr(void);
size_t   mdfn_pce_baseram_size(void);
uint8_t* mdfn_pce_fast_baseram_ptr(void);
size_t   mdfn_pce_fast_baseram_size(void);

// SNES fast (snes_faust)
uint8_t* mdfn_snes_faust_wram_ptr(void);
size_t   mdfn_snes_faust_wram_size(void);
```

---

## Future Work: patch-based update workflow

The user (@JoeMatt) has noted that a better long-term system would be to maintain these
changes as `.diff` patch files and apply them at build time via an SPM build plugin or
Makefile rule (e.g. `patch -p1 < patches/ra_accessors.patch`).  This is tracked in
issue #3380 (Phase 2+ notes) as a future improvement.  For now, this file serves as the
manual checklist.
