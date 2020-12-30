/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp2.h:
**  Copyright (C) 2015-2019 Mednafen Team
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

#ifndef __MDFN_SS_VDP2_H
#define __MDFN_SS_VDP2_H

namespace MDFN_IEN_SS
{
namespace VDP2
{

uint32 Write8_DB(uint32 A, uint16 DB) MDFN_HOT;
uint32 Write16_DB(uint32 A, uint16 DB) MDFN_HOT;
uint16 Read16_DB(uint32 A) MDFN_HOT;

void Init(const bool IsPAL, const uint64 affinity) MDFN_COLD;
void SetGetVideoParams(MDFNGI* gi, const bool caspect, const int sls, const int sle, const bool show_h_overscan, const bool dohblend) MDFN_COLD;
void Kill(void) MDFN_COLD;
void StateAction(StateMem* sm, const unsigned load, const bool data_only) MDFN_COLD;

void Reset(bool powering_up) MDFN_COLD;
void SetLayerEnableMask(uint64 mask) MDFN_COLD;

sscpu_timestamp_t Update(sscpu_timestamp_t timestamp);
void AdjustTS(const int32 delta);

void GetGunXTranslation(const bool clock28m, float* scale, float* offs);
void StartFrame(EmulateSpecStruct* espec, const bool clock28m);

INLINE bool GetVBOut(void) { MDFN_HIDE extern bool VBOut; return VBOut; }
INLINE bool GetHBOut(void) { MDFN_HIDE extern bool HBOut; return HBOut; }

INLINE void SetExtLatch(sscpu_timestamp_t event_timestamp, bool status)
{
 MDFN_HIDE extern bool ExLatchIn;
 MDFN_HIDE extern bool ExLatchEnable;
 MDFN_HIDE extern bool ExLatchPending;

 if(MDFN_UNLIKELY(ExLatchIn != status))
 {
  ExLatchIn = status;
  //
  //
  if(ExLatchEnable & ExLatchIn)
  {
   //
   // Should be safer(avoid unintended reentrant and recursive calls to *Update() functions, now and in the future) to just schedule a call to VDP2::Update()
   // than calling it directly from here, though it's possible a scheduled DMA could rewrite
   // ExLatchEnable and VDP2 timing registers and cause weird results(latching correct values or not latching at all, versus also latching wrong values), but that shouldn't
   // be a problem in practice...
   //
   ExLatchPending = true;
   SS_SetEventNT(&events[SS_EVENT_VDP2], event_timestamp);
#if 0
   SS_SetEventNT(&events[SS_EVENT_VDP2], Update(event_timestamp));
   //
   LatchHV();
   //
   HVIsExLatched = true;
   printf("ExLatch: %04x %04x\n", Latched_VCNT, Latched_HCNT);
#endif
  }
 }
}

//
//
enum
{
 GSREG_LINE = 0,
 GSREG_DON,
 GSREG_BM,
 GSREG_IM,
 GSREG_VRES,
 GSREG_HRES,

 GSREG_RAMCTL,

 GSREG_BGON,
 GSREG_MZCTL,
 GSREG_SFSEL,
 GSREG_SFCODE,
 GSREG_CHCTLA,
 GSREG_CHCTLB,

 GSREG_SCXIN0,
 GSREG_SCXDN0,
 GSREG_SCYIN0,
 GSREG_SCYDN0,
 GSREG_ZMXIN0,
 GSREG_ZMXDN0,
 GSREG_ZMYIN0,
 GSREG_ZMYDN0,

 GSREG_SCXIN1,
 GSREG_SCXDN1,
 GSREG_SCYIN1,
 GSREG_SCYDN1,
 GSREG_ZMXIN1,
 GSREG_ZMXDN1,
 GSREG_ZMYIN1,
 GSREG_ZMYDN1,

 GSREG_SCXN2,
 GSREG_SCYN2,
 GSREG_SCXN3,
 GSREG_SCYN3,

 GSREG_ZMCTL,
 GSREG_SCRCTL,

 GSREG_CYCA0,
 GSREG_CYCA1 = GSREG_CYCA0 + 1,
 GSREG_CYCB0 = GSREG_CYCA0 + 2,
 GSREG_CYCB1 = GSREG_CYCA0 + 3

};

uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;
void SetRegister(const unsigned id, const uint32 value) MDFN_COLD;
uint8 PeekVRAM(uint32 addr) MDFN_COLD;
void PokeVRAM(uint32 addr, const uint8 val) MDFN_COLD;
void MakeDump(const std::string& path) MDFN_COLD;

INLINE uint32 PeekLine(void) { MDFN_HIDE extern int32 VCounter; return VCounter; }
INLINE uint32 PeekHPos(void) { MDFN_HIDE extern int32 HCounter; return HCounter; }
}
}
#endif
