/******************************************************************************/
/* Mednafen Virtual Boy Emulation Module                                      */
/******************************************************************************/
/* input.h:
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

#ifndef __VB_INPUT_H
#define __VB_INPUT_H

namespace MDFN_IEN_VB
{

void VBINPUT_Init(void) MDFN_COLD;
void VBINPUT_SetInstantReadHack(bool);

void VBINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);

uint8 VBINPUT_Read(v810_timestamp_t &timestamp, uint32 A);

void VBINPUT_Write(v810_timestamp_t &timestamp, uint32 A, uint8 V);

void VBINPUT_Frame(void);
void VBINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only);

int32 VBINPUT_Update(const int32 timestamp);
void VBINPUT_ResetTS(void);


void VBINPUT_Power(void);


int VBINPUT_StateAction(StateMem *sm, int load, int data_only);

}
#endif
