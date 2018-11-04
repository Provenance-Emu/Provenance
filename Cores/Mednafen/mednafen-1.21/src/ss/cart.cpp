/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* cart.cpp - Expansion cart emulation
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

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/FileStream.h>
#include <mednafen/general.h>

#include "cart.h"
#include "cart/backup.h"
#include "cart/cs1ram.h"
#include "cart/debug.h"
#include "cart/extram.h"
//#include "cart/nlmodem.h"
#include "cart/rom.h"
#include "cart/ar4mp.h"

namespace MDFN_IEN_SS
{

CartInfo Cart;

template<typename T>
static MDFN_HOT void DummyRead(uint32 A, uint16* DB)
{
 // Don't set *DB here.
 SS_DBG(SS_DBG_WARNING, "[CART] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);
}

template<typename T>
static MDFN_HOT void DummyWrite(uint32 A, uint16* DB)
{
 SS_DBG(SS_DBG_WARNING, "[CART] Unknown %zu-byte write to 0x%08x(DB=0x%04x)\n", sizeof(T), A, *DB);
}

static sscpu_timestamp_t DummyUpdate(sscpu_timestamp_t timestamp)
{
 return SS_EVENT_DISABLED_TS;
}

static void DummyAdjustTS(const int32 delta)
{

}

static void DummySetCPUClock(const int32 master_clock, const int32 divider)
{

}

static MDFN_COLD void DummyReset(bool powering_up)
{

}

static MDFN_COLD void DummyStateAction(StateMem* sm, const unsigned load, const bool data_only)
{

}

static MDFN_COLD bool DummyGetClearNVDirty(void)
{
 return false;
}

static MDFN_COLD void DummyGetNVInfo(const char** ext, void** nv_ptr, bool* nv16, uint64* nv_size)
{
 *ext = nullptr;
 *nv_ptr = nullptr;
 *nv16 = false;
 *nv_size = 0;
}

static MDFN_COLD void DummyKill(void)
{

}

void CartInfo::CS01_SetRW8W16(uint32 Astart, uint32 Aend, void (*r16)(uint32 A, uint16* DB), void (*w8)(uint32 A, uint16* DB), void (*w16)(uint32 A, uint16* DB))
{
 assert(Astart >= 0x02000000 && Aend <= 0x04FFFFFF);

 assert(!(Astart & ((1U << 20) - 1)));
 assert(!((Aend + 1) & ((1U << 20) - 1)));

 for(unsigned i = (Astart - 0x02000000) >> 20; i <= (Aend - 0x02000000) >> 20; i++)
 {
  auto& rw = Cart.CS01_RW[i];

  if(r16) rw.Read16 = r16;
  if(w8) rw.Write8 = w8;
  if(w16) rw.Write16 = w16;
 }
}

void CartInfo::CS2M_SetRW8W16(uint8 Ostart, uint8 Oend, void (*r16)(uint32 A, uint16* DB), void (*w8)(uint32 A, uint16* DB), void (*w16)(uint32 A, uint16* DB))
{
 assert(!(Ostart & 0x1));
 assert(Oend & 0x1);
 assert(Ostart < 0x40);
 assert(Oend < 0x40);

 for(int i = Ostart >> 1; i <= Oend >> 1; i++)
 {
  auto& rw = Cart.CS2M_RW[i];

  if(r16) rw.Read16 = r16;
  if(w8) rw.Write8 = w8;
  if(w16) rw.Write16 = w16;
 }
}


void CART_Init(const int cart_type)
{
 Cart.CS01_SetRW8W16(0x02000000, 0x04FFFFFF, DummyRead<uint16>, DummyWrite<uint8>, DummyWrite<uint16>);
 Cart.CS2M_SetRW8W16(0x00, 0x3F, DummyRead<uint16>, DummyWrite<uint8>, DummyWrite<uint16>);

 Cart.Reset = DummyReset;
 Cart.Kill = DummyKill;
 Cart.GetNVInfo = DummyGetNVInfo;
 Cart.GetClearNVDirty = DummyGetClearNVDirty;
 Cart.StateAction = DummyStateAction;
 Cart.EventHandler = DummyUpdate;
 Cart.AdjustTS = DummyAdjustTS;
 Cart.SetCPUClock = DummySetCPUClock;

 switch(cart_type)
 {
  default:
  case CART_NONE:
	break;

  case CART_BACKUP_MEM:
	CART_Backup_Init(&Cart);
	break;

  case CART_EXTRAM_1M:
  case CART_EXTRAM_4M:
	CART_ExtRAM_Init(&Cart, cart_type == CART_EXTRAM_4M);
	break;

  case CART_KOF95:
  case CART_ULTRAMAN:
	{
	 const std::string path = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS((cart_type == CART_KOF95) ? "ss.cart.kof95_path" : "ss.cart.ultraman_path"));
	 FileStream fp(path, FileStream::MODE_READ);

	 CART_ROM_Init(&Cart, &fp);
	}
	break;

  case CART_AR4MP:
	{
	 const std::string path = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS("ss.cart.satar4mp_path"));
	 FileStream fp(path, FileStream::MODE_READ);

	 CART_AR4MP_Init(&Cart, &fp);
	}
	break;

  case CART_CS1RAM_16M:
	CART_CS1RAM_Init(&Cart);
	break;

  case CART_MDFN_DEBUG:
	CART_Debug_Init(&Cart);
	break;

//  case CART_NLMODEM:
//	CART_NLModem_Init(&Cart);
//	break;
 }

 for(auto& m : Cart.CS01_RW)
  assert(m.Read16 != nullptr && m.Write8 != nullptr && m.Write16 != nullptr);

 for(auto& m : Cart.CS2M_RW)
  assert(m.Read16 != nullptr && m.Write8 != nullptr && m.Write16 != nullptr);
}

}
