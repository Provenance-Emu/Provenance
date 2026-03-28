# libgambatte — Provenance Patches

This directory contains the vendored [gambatte](https://github.com/pokemon-speedrunning/gambatte-core)
Game Boy / Game Boy Color emulator library.

The upstream source lives in `libgambatte/` (a copy from gambatte-core, not a git submodule).
All modifications to upstream files are documented here so they can be reproduced when
updating the upstream source.

---

## Patch Index

| File | Purpose | Applied via |
|------|---------|-------------|
| `patches/0001-retro-achievements-memory-accessors.patch` | Expose WRAM/VRAM pointers for rc_client | `git apply` |

---

## Patch 0001 — RetroAchievements memory accessors

**Upstream files modified:**
- `libgambatte/include/gambatte.h`
- `libgambatte/src/gambatte.cpp`
- `libgambatte/src/memory.h`
- `libgambatte/src/cpu.h`

**Why:**
The `rc_client` RetroAchievements API requires a `read_memory` callback that can
read any byte from the console's address space.  For GB/GBC the relevant regions are:

| Region | Bus address | Notes |
|--------|-------------|-------|
| WRAM bank 0 | `0xC000–0xCFFF` | Fixed; 4 KiB |
| WRAM bank 1 (switchable on CGB) | `0xD000–0xDFFF` | Active bank; 4 KiB |
| Echo RAM | `0xE000–0xFDFF` | Mirror of 0xC000–0xDDFF |
| VRAM (active bank on CGB) | `0x8000–0x9FFF` | 8 KiB per bank |

gambatte does not expose raw pointers to these regions in its public API, so we add
four new methods to `gambatte::GB`:

```cpp
const unsigned char * wramData(unsigned area) const;
//   area 0 → pointer to 0xC000 region (fixed bank 0, stable for ROM lifetime)
//   area 1 → pointer to 0xD000 region (active CGB bank, may change)

const unsigned char * vramData() const;
//   Physical start of VRAM allocation; index 0 = bus address 0x8000.

const unsigned char * vramBankPtr() const;
//   Pre-adjusted pointer: vrambankptr[addr] for addr in [0x8000,0x9FFF]
//   returns the correct byte for the active CGB VRAM bank.
//   Prefer this over vramData() for reads.

std::size_t wramSize() const;
//   Total WRAM: 8 KiB on DMG, 32 KiB on CGB.
```

The forwarding chain is: `GB` → `CPU` → `Memory` → `Cartridge`
(`Cartridge::wramdata`, `Cartridge::vramdata`, `Cartridge::vrambankptr` already exist).

**To apply to a fresh upstream copy:**

```bash
cd Cores/Gambatte/Sources/libgambatte
git apply patches/0001-retro-achievements-memory-accessors.patch
```

Or apply manually by copying the relevant `+` lines shown in the patch file.

**Provenance issue:** #3379

---

## How to update the upstream source

1. Replace the `libgambatte/` directory contents with the new upstream version.
2. Re-apply each patch in order:
   ```bash
   cd Cores/Gambatte/Sources/libgambatte
   for p in patches/*.patch; do git apply "$p" && echo "Applied: $p"; done
   ```
3. Resolve any conflicts manually, then update this file with any new patch versions.
