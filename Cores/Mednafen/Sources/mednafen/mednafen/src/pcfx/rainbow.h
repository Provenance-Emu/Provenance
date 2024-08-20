/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* rainbow.h:
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

#ifndef __PCFX_RAINBOW_H
#define __PCFX_RAINBOW_H

namespace MDFN_IEN_PCFX
{

void RAINBOW_Write8(uint32 A, uint8 V);
void RAINBOW_Write16(uint32 A, uint16 V);

void RAINBOW_ForceTransferReset(void);
void RAINBOW_SwapBuffers(void);
void RAINBOW_DecodeBlock(bool arg_FirstDecode, bool Skip);

int RAINBOW_FetchRaster(uint32 *, uint32 layer_or, uint32 *palette_ptr);
void RAINBOW_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void RAINBOW_Init(bool arg_ChromaIP) MDFN_COLD;
void RAINBOW_Close(void) MDFN_COLD;
void RAINBOW_Reset(void) MDFN_COLD;

#ifdef WANT_DEBUGGER
enum
{
 RAINBOW_GSREG_RSCRLL,
 RAINBOW_GSREG_RCTRL,
 RAINBOW_GSREG_RNRY,
 RAINBOW_GSREG_RNRU,
 RAINBOW_GSREG_RNRV,
 RAINBOW_GSREG_RHSYNC,
};
uint32 RAINBOW_GetRegister(const unsigned int id, char* special, const uint32 special_len);
void RAINBOW_SetRegister(const unsigned int id, uint32 value);
#endif

}

#endif
