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
//   SNES   — 128 KB Work RAM (MDFN_IEN_SNES_FAUST::WRAM)

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

#ifdef __cplusplus
}
#endif

#endif /* MednafenGameCoreC_h */
