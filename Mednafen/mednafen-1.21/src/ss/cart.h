/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* cart.h - Expansion cart emulation
**  Copyright (C) 2016-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_SS_CART_H
#define __MDFN_SS_CART_H

#include <mednafen/state.h>

namespace MDFN_IEN_SS
{

struct CartInfo
{
 void (*Reset)(bool powering_up);
 void (*Kill)(void);

 void (*GetNVInfo)(const char** ext, void** nv_ptr, bool* nv16, uint64* nv_size);
 bool (*GetClearNVDirty)(void);

 void (*StateAction)(StateMem* sm, const unsigned load, const bool data_only);

 void (*AdjustTS)(const int32 delta);

 // For calculating clock ratios.
 void (*SetCPUClock)(const int32 master_clock, const int32 cpu_divider);

 ss_event_handler EventHandler;

 // A >> 20
 struct
 {
  void (*Read16)(uint32 A, uint16* DB);
  void (*Write8)(uint32 A, uint16* DB);
  void (*Write16)(uint32 A, uint16* DB);  
 } CS01_RW[0x30];

 struct
 {
  void (*Read16)(uint32 A, uint16* DB);
  void (*Write8)(uint32 A, uint16* DB);
  void (*Write16)(uint32 A, uint16* DB);  
 } CS2M_RW[0x20];

 void CS01_SetRW8W16(uint32 Astart, uint32 Aend, void (*r16)(uint32 A, uint16* DB), void (*w8)(uint32 A, uint16* DB) = nullptr, void (*w16)(uint32 A, uint16* DB) = nullptr);
 void CS2M_SetRW8W16(uint8 Ostart, uint8 Oend, void (*r16)(uint32 A, uint16* DB), void (*w8)(uint32 A, uint16* DB) = nullptr, void (*w16)(uint32 A, uint16* DB) = nullptr);
};

static INLINE void CART_CS01_Read16_DB(uint32 A, uint16* DB)  { extern CartInfo Cart; Cart.CS01_RW[(size_t)(A >> 20) - (0x02000000 >> 20)].Read16 (A, DB); }
static INLINE void CART_CS01_Write8_DB(uint32 A, uint16* DB)  { extern CartInfo Cart; Cart.CS01_RW[(size_t)(A >> 20) - (0x02000000 >> 20)].Write8 (A, DB); }
static INLINE void CART_CS01_Write16_DB(uint32 A, uint16* DB) { extern CartInfo Cart; Cart.CS01_RW[(size_t)(A >> 20) - (0x02000000 >> 20)].Write16(A, DB); }

static INLINE void CART_CS2_Read16_DB(uint32 A, uint16* DB)  { extern CartInfo Cart; Cart.CS2M_RW[(A >> 1) & 0x1F].Read16 (A, DB); }
static INLINE void CART_CS2_Write8_DB(uint32 A, uint16* DB)  { extern CartInfo Cart; Cart.CS2M_RW[(A >> 1) & 0x1F].Write8 (A, DB); }
static INLINE void CART_CS2_Write16_DB(uint32 A, uint16* DB) { extern CartInfo Cart; Cart.CS2M_RW[(A >> 1) & 0x1F].Write16(A, DB); }

enum
{
 CART__RESERVED = -1,
 CART_NONE = 0,
 CART_BACKUP_MEM,
 CART_EXTRAM_1M,
 CART_EXTRAM_4M,

 CART_KOF95,
 CART_ULTRAMAN,

 CART_AR4MP,

 CART_CS1RAM_16M,

 CART_NLMODEM,

 CART_MDFN_DEBUG
};

void CART_Init(const int cart_type) MDFN_COLD;
static INLINE ss_event_handler CART_GetEventHandler(void) { extern CartInfo Cart; return Cart.EventHandler; }
static INLINE void CART_AdjustTS(const int32 delta) { extern CartInfo Cart; Cart.AdjustTS(delta); }
static INLINE void CART_SetCPUClock(const int32 master_clock, const int32 cpu_divider) { extern CartInfo Cart; Cart.SetCPUClock(master_clock, cpu_divider); }
static INLINE void CART_Kill(void) { extern CartInfo Cart; if(Cart.Kill) { Cart.Kill(); Cart.Kill = nullptr; } }
static INLINE void CART_StateAction(StateMem* sm, const unsigned load, const bool data_only) { extern CartInfo Cart; Cart.StateAction(sm, load, data_only); }
static INLINE void CART_GetNVInfo(const char** ext, void** nv_ptr, bool* nv16, uint64* nv_size) { extern CartInfo Cart; Cart.GetNVInfo(ext, nv_ptr, nv16, nv_size); }
static INLINE bool CART_GetClearNVDirty(void) { extern CartInfo Cart; return Cart.GetClearNVDirty(); }
static INLINE void CART_Reset(bool powering_up) { extern CartInfo Cart; Cart.Reset(powering_up); }
}
#endif
