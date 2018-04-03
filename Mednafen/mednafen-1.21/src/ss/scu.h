/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scu.h:
**  Copyright (C) 2015-2016 Mednafen Team
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

#ifndef __MDFN_SS_SCU_H
#define __MDFN_SS_SCU_H

namespace MDFN_IEN_SS
{

enum
{
 SCU_INT_VBIN = 0x00,
 SCU_INT_VBOUT,
 SCU_INT_HBIN,
 SCU_INT_TIMER0,
 SCU_INT_TIMER1,
 SCU_INT_DSP,
 SCU_INT_SCSP,
 SCU_INT_SMPC,
 SCU_INT_PAD,

 SCU_INT_L2DMA,
 SCU_INT_L1DMA,
 SCU_INT_L0DMA,

 SCU_INT_DMA_ILL,

 SCU_INT_VDP1,

 SCU_INT_EXT0	= 0x10,
 SCU_INT_EXTF	= 0x1F,
};

void SCU_Reset(bool powering_up) MDFN_COLD;

void SCU_SetInt(unsigned which, bool active);
int32 SCU_SetHBVB(int32 pclocks, bool hblank_in, bool vblank_in);

bool SCU_CheckVDP1HaltKludge(void);

sscpu_timestamp_t SCU_UpdateDMA(sscpu_timestamp_t timestamp);
sscpu_timestamp_t SCU_UpdateDSP(sscpu_timestamp_t timestamp);

enum
{
 SCU_GSREG_ILEVEL = 0,
 SCU_GSREG_IVEC,
 SCU_GSREG_ICLEARMASK,

 SCU_GSREG_IASSERTED,
 SCU_GSREG_IPENDING,
 SCU_GSREG_IMASK,

 SCU_GSREG_T0CNT,
 SCU_GSREG_T0CMP,
 SCU_GSREG_T0MET,

 SCU_GSREG_T1RLV,
 SCU_GSREG_T1CNT,
 SCU_GSREG_T1MOD,
 SCU_GSREG_T1MET,

 SCU_GSREG_TENBL,
 //
 //
 //
 SCU_GSREG_DSP_EXEC,
 SCU_GSREG_DSP_PAUSE,
 SCU_GSREG_DSP_PC,
 SCU_GSREG_DSP_END,
};

uint32 SCU_GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;
void SCU_SetRegister(const unsigned id, const uint32 value) MDFN_COLD;
}

#endif
