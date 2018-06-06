/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp2_render.h:
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

#ifndef __MDFN_SS_VDP2_RENDER_H
#define __MDFN_SS_VDP2_RENDER_H

namespace MDFN_IEN_SS
{

void VDP2REND_Init(const bool IsPAL) MDFN_COLD;
void VDP2REND_SetGetVideoParams(MDFNGI* gi, const bool caspect, const int sls, const int sle, const bool show_h_overscan, const bool dohblend) MDFN_COLD;
void VDP2REND_Kill(void) MDFN_COLD;
void VDP2REND_GetGunXTranslation(const bool clock28m, float* scale, float* offs);
void VDP2REND_StartFrame(EmulateSpecStruct* espec, const bool clock28m, const int SurfInterlaceField);
void VDP2REND_EndFrame(void);
void VDP2REND_Reset(bool powering_up) MDFN_COLD;
void VDP2REND_SetLayerEnableMask(uint64 mask) MDFN_COLD;

void VDP2REND_StateAction(StateMem* sm, const unsigned load, const bool data_only, uint16 (&rr)[0x100], uint16 (&cr)[2048], uint16 (&vr)[262144]) MDFN_COLD;

struct VDP2Rend_LIB
{
 struct
 {
  uint32 Xsp, Ysp;// .10
  uint32 Xp, Yp; // .10
  uint32 dX, dY; // .10
  int32 kx, ky;	 // .16
  uint32 KAstAccum;
  uint32 DKAx;
 } rv[2];
 bool vdp1_hires8;
 bool win_ymet[2];
 uint16 vdp1_line[352];
};

VDP2Rend_LIB* VDP2REND_GetLIB(unsigned line);
void VDP2REND_DrawLine(int vdp2_line, const uint32 crt_line, const bool field);

void VDP2REND_Write8_DB(uint32 A, uint16 DB);
void VDP2REND_Write16_DB(uint32 A, uint16 DB);

}

#endif
