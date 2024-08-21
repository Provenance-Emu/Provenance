/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* king.h:
**  Copyright (C) 2006-2016 Mednafen Team
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

#ifndef __PCFX_KING_H
#define __PCFX_KING_H

namespace MDFN_IEN_PCFX
{

//
// Be sure to keep the numbered/lettered *_GSREG_* registers(MPROG0*, AFFIN*, etc.) here in contiguous sequential order(since we do stuff like "- KING_GSREG_MPROG0"
// in king.cpp.
//

void KING_StartFrame(VDC **, EmulateSpecStruct *espec);
void KING_SetPixelFormat(const MDFN_PixelFormat &format);
uint16 FXVCE_Read16(uint32 A);
void FXVCE_Write16(uint32 A, uint16 V);

#ifdef WANT_DEBUGGER
enum
{
 FXVCE_GSREG_Line = 0,

 FXVCE_GSREG_PRIO0,
 FXVCE_GSREG_PRIO1,

 FXVCE_GSREG_PICMODE,
 FXVCE_GSREG_PALRWOF,
 FXVCE_GSREG_PALRWLA,

 FXVCE_GSREG_PALOFS0,
 FXVCE_GSREG_PALOFS1,
 FXVCE_GSREG_PALOFS2,
 FXVCE_GSREG_PALOFS3,

 FXVCE_GSREG_CCR,
 FXVCE_GSREG_BLE,
 FXVCE_GSREG_SPBL,

 FXVCE_GSREG_COEFF0,
 FXVCE_GSREG_COEFF1,
 FXVCE_GSREG_COEFF2,
 FXVCE_GSREG_COEFF3,
 FXVCE_GSREG_COEFF4,
 FXVCE_GSREG_COEFF5,

 FXVCE_GSREG_CKeyY,
 FXVCE_GSREG_CKeyU,
 FXVCE_GSREG_CKeyV
};

uint32 FXVCE_GetRegister(const unsigned int id, char* special, const uint32 special_len);
void FXVCE_SetRegister(const unsigned int id, uint32 value);
#endif

uint8 KING_Read8(const v810_timestamp_t timestamp, uint32 A);
uint16 KING_Read16(const v810_timestamp_t timestamp, uint32 A);

void KING_Write8(const v810_timestamp_t timestamp, uint32 A, uint8 V);
void KING_Write16(const v810_timestamp_t timestamp, uint32 A, uint16 V);
void KING_Init(void) MDFN_COLD;
void KING_Close(void) MDFN_COLD;
void KING_Reset(const v810_timestamp_t timestamp) MDFN_COLD;

uint16 KING_GetADPCMHalfWord(int ch);

uint8 KING_MemPeek(uint32 A);

uint8 KING_RB_Fetch();

void KING_SetLayerEnableMask(uint64 mask);

void KING_StateAction(StateMem *sm, const unsigned load, const bool data_only);

#ifdef WANT_DEBUGGER
enum
{
 KING_GSREG_AR = 0,
 KING_GSREG_MPROGADDR,
 KING_GSREG_MPROGCTRL,

 KING_GSREG_PAGESET,
 KING_GSREG_RTCTRL,
 KING_GSREG_RKRAMA,
 KING_GSREG_RSTART,
 KING_GSREG_RCOUNT,
 KING_GSREG_RIRQLINE,
 KING_GSREG_KRAMWA,
 KING_GSREG_KRAMRA,
 KING_GSREG_DMATA,
 KING_GSREG_DMATS,
 KING_GSREG_DMASTT,
 KING_GSREG_ADPCMCTRL,

 KING_GSREG_ADPCMBM0,
 KING_GSREG_ADPCMBM1,

 KING_GSREG_ADPCMPA0,
 KING_GSREG_ADPCMPA1,

 KING_GSREG_ADPCMSA0,
 KING_GSREG_ADPCMSA1,

 KING_GSREG_ADPCMIA0,
 KING_GSREG_ADPCMIA1,

 KING_GSREG_ADPCMEA0,
 KING_GSREG_ADPCMEA1,

 KING_GSREG_ADPCMStat,
 KING_GSREG_Reg01,
 KING_GSREG_Reg02,
 KING_GSREG_Reg03,
 KING_GSREG_SUBCC,
 KING_GSREG_DB,
 KING_GSREG_BSY,
 KING_GSREG_REQ,
 KING_GSREG_ACK,
 KING_GSREG_MSG,
 KING_GSREG_IO,
 KING_GSREG_CD,
 KING_GSREG_SEL,

 KING_GSREG_BGMODE,
 KING_GSREG_BGPRIO,
 KING_GSREG_BGSCRM,

 KING_GSREG_BGSIZ0,
 KING_GSREG_BGSIZ1,
 KING_GSREG_BGSIZ2,
 KING_GSREG_BGSIZ3,

 KING_GSREG_BGXSC0,
 KING_GSREG_BGXSC1,
 KING_GSREG_BGXSC2,
 KING_GSREG_BGXSC3,

 KING_GSREG_BGYSC0,
 KING_GSREG_BGYSC1,
 KING_GSREG_BGYSC2,
 KING_GSREG_BGYSC3,

 KING_GSREG_BGBATS,
 KING_GSREG_BGBAT0,
 KING_GSREG_BGBAT1,
 KING_GSREG_BGBAT2,
 KING_GSREG_BGBAT3,

 KING_GSREG_BGCGS,
 KING_GSREG_BGCG0,
 KING_GSREG_BGCG1,
 KING_GSREG_BGCG2,
 KING_GSREG_BGCG3,

 KING_GSREG_AFFINA,
 KING_GSREG_AFFINB,
 KING_GSREG_AFFINC,
 KING_GSREG_AFFIND,

 KING_GSREG_AFFINX,
 KING_GSREG_AFFINY,

 KING_GSREG_MPROG0,
 KING_GSREG_MPROG1,
 KING_GSREG_MPROG2,
 KING_GSREG_MPROG3,
 KING_GSREG_MPROG4,
 KING_GSREG_MPROG5,
 KING_GSREG_MPROG6,
 KING_GSREG_MPROG7,
 KING_GSREG_MPROG8,
 KING_GSREG_MPROG9,
 KING_GSREG_MPROGA,
 KING_GSREG_MPROGB,
 KING_GSREG_MPROGC,
 KING_GSREG_MPROGD,
 KING_GSREG_MPROGE,
 KING_GSREG_MPROGF
};

uint32 KING_GetRegister(const unsigned int id, char* special, const uint32 special_len);
void KING_SetRegister(const unsigned int id, uint32 value);
#endif

void KING_SetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn);

void KING_NotifyOfBPE(bool read, bool write);

void KING_SetLogFunc(void (*logfunc)(const char *, const char *, ...));

void KING_EndFrame(v810_timestamp_t timestamp);
void KING_ResetTS(v810_timestamp_t ts_base);

v810_timestamp_t MDFN_FASTCALL KING_Update(const v810_timestamp_t timestamp);

}

#endif
