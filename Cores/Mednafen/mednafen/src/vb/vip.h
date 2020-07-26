/******************************************************************************/
/* Mednafen Virtual Boy Emulation Module                                      */
/******************************************************************************/
/* vip.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __VB_VIP_H
#define __VB_VIP_H

namespace MDFN_IEN_VB
{

extern const CustomPalette_Spec VIP_CPInfo[];

void VIP_Init(void) MDFN_COLD;
void VIP_Kill(void) MDFN_COLD;
void VIP_Power(void) MDFN_COLD;

void VIP_SetInstantDisplayHack(bool) MDFN_COLD;
void VIP_SetAllowDrawSkip(bool) MDFN_COLD;
void VIP_Set3DMode(uint32 mode, bool reverse, uint32 prescale, uint32 sbs_separation) MDFN_COLD;
void VIP_SetParallaxDisable(bool disabled) MDFN_COLD;
void VIP_SetDefaultColor(uint32 default_color) MDFN_COLD;
void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor) MDFN_COLD;	// R << 16, G << 8, B << 0
void VIP_SetLEDOnScale(float coeff) MDFN_COLD;

v810_timestamp_t MDFN_FASTCALL VIP_Update(const v810_timestamp_t timestamp);
void VIP_ResetTS(void);

void VIP_StartFrame(EmulateSpecStruct *espec);

MDFN_FASTCALL uint8 VIP_Read8(v810_timestamp_t &timestamp, uint32 A);
MDFN_FASTCALL uint16 VIP_Read16(v810_timestamp_t &timestamp, uint32 A);


MDFN_FASTCALL void VIP_Write8(v810_timestamp_t &timestamp, uint32 A, uint8 V);
MDFN_FASTCALL void VIP_Write16(v810_timestamp_t &timestamp, uint32 A, uint16 V);

void VIP_StateAction(StateMem *sm, const unsigned load, const bool data_only);


enum
{
 VIP_GSREG_IPENDING = 0,	// Current pending interrupt(bits)
 VIP_GSREG_IENABLE,

 VIP_GSREG_DPCTRL,

 VIP_GSREG_BRTA,
 VIP_GSREG_BRTB,
 VIP_GSREG_BRTC,
 VIP_GSREG_REST,
 VIP_GSREG_FRMCYC,
 VIP_GSREG_XPCTRL,

 VIP_GSREG_SPT0,
 VIP_GSREG_SPT1,
 VIP_GSREG_SPT2,
 VIP_GSREG_SPT3,

 VIP_GSREG_GPLT0,
 VIP_GSREG_GPLT1,
 VIP_GSREG_GPLT2,
 VIP_GSREG_GPLT3,

 VIP_GSREG_JPLT0,
 VIP_GSREG_JPLT1,
 VIP_GSREG_JPLT2,
 VIP_GSREG_JPLT3,

 VIP_GSREG_BKCOL,
};

uint32 VIP_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void VIP_SetRegister(const unsigned int id, const uint32 value);


}
#endif
