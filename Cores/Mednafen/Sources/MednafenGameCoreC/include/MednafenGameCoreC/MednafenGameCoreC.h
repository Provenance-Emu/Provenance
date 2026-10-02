//
//  MednafenGameCoreC.h
//  PVCoreMednafen
//
//  Created by Joseph Mattiello on 9/24/24.
//

#ifndef MednafenGameCoreC_h
#define MednafenGameCoreC_h

#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdint.h>

#import <MednafenGameCoreC/MednafenControllerMappings.h>
#import <MednafenGameCoreC/SwiftCXXStringConversion.h>

// Import any other public headers here

// MARK: - RetroAchievements RAM Accessors
//
// These C functions expose the per-system RAM pointers that rcheevos reads
// when evaluating achievement conditions.  They return valid pointers only
// while the corresponding system is loaded; callers must not retain pointers
// across game-unload/power-cycle boundaries.
//
// Systems covered:
//   PSX    — 2 MB main RAM (MDFN_IEN_PSX::MainRAM)
//   NES    — 2 KB CPU RAM  (MDFN_IEN_NES::RAM)
//   Saturn — uint16 backing; byte-order corrected via MednafenRcheevosByteSwapModeWord16
//   PCE    — 8 KB base RAM (32 KB for SuperGrafx) (MDFN_IEN_PCE / MDFN_IEN_PCE_FAST)
//   SNES   — 128 KB Work RAM (MDFN_IEN_SNES_FAUST::WRAM, or bSNES_v059::memory::wram)
//   FDS    — 32 KB disk-system RAM (MDFN_IEN_NES::FDSRAM)
//   Lynx   — 64 KB RAM (CSystem::GetRamPointer)
//   NGP    — 16 KB work RAM (MDFN_IEN_NGP::CPUExRAM)
//   PC-FX  — 2 MB RAM + 32 KB internal / 128 KB external backup RAM
//   VB     — 64 KB WRAM + 64 KB cartridge RAM (GPRAM)
//   WSwan  — 64 KB RAM + cartridge SRAM
//   GB/GBC — WRAM, VRAM, HRAM, cartridge RAM (all banks)
//   GBA    — 32 KB IWRAM, 256 KB EWRAM, 128 KB SRAM/flash backing
//
// Every system here stores RAM as plain little-endian bytes except Saturn.

#ifdef __cplusplus
extern "C" {
#endif

/// PSX — 2 MB main RAM
uint8_t* mdfn_psx_mainram_ptr(void);
size_t   mdfn_psx_mainram_size(void);

/// NES — 2 KB CPU RAM (mirrored; rcheevos addresses 0x0000–0x07FF)
uint8_t* mdfn_nes_ram_ptr(void);
size_t   mdfn_nes_ram_size(void);

/// Saturn — 1 MB Work RAM Low (0x00200000–0x002FFFFF)
uint8_t* mdfn_ss_workraml_ptr(void);
size_t   mdfn_ss_workraml_size(void);

/// Saturn — 1 MB Work RAM High (0x06000000–0x060FFFFF)
uint8_t* mdfn_ss_workramh_ptr(void);
size_t   mdfn_ss_workramh_size(void);

/// PCE (full accuracy) — 8 KB base RAM (32 KB when IsSGX, i.e. SuperGrafx)
uint8_t* mdfn_pce_baseram_ptr(void);
size_t   mdfn_pce_baseram_size(void);

/// PCE Fast — 8 KB base RAM (32 KB when IsSGX, i.e. SuperGrafx)
uint8_t* mdfn_pce_fast_baseram_ptr(void);
size_t   mdfn_pce_fast_baseram_size(void);

/// SNES Faust — 128 KB Work RAM (0x7E0000–0x7FFFFF)
uint8_t* mdfn_snes_faust_wram_ptr(void);
size_t   mdfn_snes_faust_wram_size(void);

/// SNES (bsnes, accurate module) — 128 KB Work RAM
uint8_t* mdfn_snes_wram_ptr(void);
size_t   mdfn_snes_wram_size(void);

/// FDS — 32 KB disk-system RAM ($6000–$DFFF); NULL unless an FDS image is loaded
uint8_t* mdfn_nes_fdsram_ptr(void);
size_t   mdfn_nes_fdsram_size(void);

/// Lynx — 64 KB RAM (whole CPU address space)
uint8_t* mdfn_lynx_ram_ptr(void);
size_t   mdfn_lynx_ram_size(void);

/// Neo Geo Pocket / Color — 16 KB work RAM (bus $4000–$7FFF)
uint8_t* mdfn_ngp_ram_ptr(void);
size_t   mdfn_ngp_ram_size(void);

/// PC-FX — 2 MB RAM
uint8_t* mdfn_pcfx_ram_ptr(void);
size_t   mdfn_pcfx_ram_size(void);

/// PC-FX — 32 KB internal backup RAM
uint8_t* mdfn_pcfx_backupram_ptr(void);
size_t   mdfn_pcfx_backupram_size(void);

/// PC-FX — 128 KB external backup RAM (rcheevos maps only the first 32 KB)
uint8_t* mdfn_pcfx_exbackupram_ptr(void);
size_t   mdfn_pcfx_exbackupram_size(void);

/// Virtual Boy — 64 KB work RAM (bus 0x05000000)
uint8_t* mdfn_vb_wram_ptr(void);
size_t   mdfn_vb_wram_size(void);

/// Virtual Boy — 64 KB cartridge RAM (bus 0x06000000)
uint8_t* mdfn_vb_gpram_ptr(void);
size_t   mdfn_vb_gpram_size(void);

/// WonderSwan / Color — 64 KB RAM
uint8_t* mdfn_wswan_ram_ptr(void);
size_t   mdfn_wswan_ram_size(void);

/// WonderSwan / Color — cartridge SRAM (0 when the cart has none)
uint8_t* mdfn_wswan_sram_ptr(void);
size_t   mdfn_wswan_sram_size(void);

/// Game Boy / Color — work RAM (8 KB DMG, 32 KB CGB)
uint8_t* mdfn_gb_wram_ptr(void);
size_t   mdfn_gb_wram_size(void);

/// Game Boy / Color — video RAM (8 KB DMG, 16 KB CGB)
uint8_t* mdfn_gb_vram_ptr(void);
size_t   mdfn_gb_vram_size(void);

/// Game Boy / Color — cartridge RAM, all banks (0 when the cart has none)
uint8_t* mdfn_gb_cartram_ptr(void);
size_t   mdfn_gb_cartram_size(void);

/// Game Boy / Color — 128-byte high RAM ($FF80–$FFFF)
uint8_t* mdfn_gb_hram_ptr(void);
size_t   mdfn_gb_hram_size(void);

/// GBA — 32 KB internal work RAM (bus 0x03000000)
uint8_t* mdfn_gba_iwram_ptr(void);
size_t   mdfn_gba_iwram_size(void);

/// GBA — 256 KB external work RAM (bus 0x02000000)
uint8_t* mdfn_gba_ewram_ptr(void);
size_t   mdfn_gba_ewram_size(void);

/// GBA — 128 KB SRAM/flash save backing (bus 0x0E000000)
uint8_t* mdfn_gba_saveram_ptr(void);
size_t   mdfn_gba_saveram_size(void);

#ifdef __cplusplus
}
#endif

#endif /* MednafenGameCoreC_h */
