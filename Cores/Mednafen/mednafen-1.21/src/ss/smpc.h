/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* smpc.h:
**  Copyright (C) 2015-2017 Mednafen Team
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

#include <time.h>

#ifndef __MDFN_SS_SMPC_H
#define __MDFN_SS_SMPC_H

namespace MDFN_IEN_SS
{

enum
{
 SMPC_AREA_JP		= 0x1,
 SMPC_AREA_ASIA_NTSC	= 0x2,
 SMPC_AREA_NA		= 0x4,
 SMPC_AREA_CSA_NTSC	= 0x5,
 SMPC_AREA_KR		= 0x6,

 SMPC_AREA_ASIA_PAL	= 0xA,
 SMPC_AREA_EU_PAL	= 0xC,
 SMPC_AREA_CSA_PAL	= 0xD,
 //
 //
 //
 SMPC_AREA__PAL_MASK	= 0x8
};

enum
{
 SMPC_RTC_LANG_ENGLISH = 0,
 SMPC_RTC_LANG_GERMAN = 1,
 SMPC_RTC_LANG_FRENCH = 2,
 SMPC_RTC_LANG_SPANISH = 3,
 SMPC_RTC_LANG_ITALIAN = 4,
 SMPC_RTC_LANG_JAPANESE = 5,
};

void SMPC_Init(const uint8 area_code, const int32 master_clock) MDFN_COLD;
bool SMPC_IsSlaveOn(void);
void SMPC_Reset(bool powering_up) MDFN_COLD;
void SMPC_LoadNV(Stream* s) MDFN_COLD;
void SMPC_SaveNV(Stream* s) MDFN_COLD;
void SMPC_StateAction(StateMem* sm, const unsigned load, const bool data_only) MDFN_COLD;

void SMPC_SetRTC(const struct tm* ht, const uint8 lang) MDFN_COLD;

void SMPC_Write(const sscpu_timestamp_t timestamp, uint8 A, uint8 V) MDFN_HOT;
uint8 SMPC_Read(const sscpu_timestamp_t timestamp, uint8 A) MDFN_HOT;

sscpu_timestamp_t SMPC_Update(sscpu_timestamp_t timestamp);
void SMPC_ResetTS(void);

int32 SMPC_StartFrame(EmulateSpecStruct* espec);
void SMPC_EndFrame(EmulateSpecStruct* espec, sscpu_timestamp_t timestamp);
void SMPC_TransformInput(void);
void SMPC_UpdateInput(const int32 time_elapsed);
void SMPC_UpdateOutput(void);
void SMPC_SetInput(unsigned port, const char* type, uint8* ptr) MDFN_COLD;
void SMPC_SetMultitap(unsigned sport, bool enabled) MDFN_COLD;
void SMPC_SetCrosshairsColor(unsigned port, uint32 color) MDFN_COLD;

void SMPC_SetVBVS(sscpu_timestamp_t event_timestamp, bool vb_status, bool vsync_status);

void SMPC_LineHook(sscpu_timestamp_t event_timestamp, int32 out_line, int32 div, int32 coord_adj);

extern const std::vector<InputPortInfoStruct> SMPC_PortInfo;

}
#endif
