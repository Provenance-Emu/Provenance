/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* kbio.h:
**  Copyright (C) 2018-2023 Mednafen Team
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

#ifndef __MDFN_APPLE2_KBIO_H
#define __MDFN_APPLE2_KBIO_H

namespace MDFN_IEN_APPLE2
{
namespace KBIO
{
//
//

void Init(const bool emulate_iie);
void SetKeyGhosting(bool enabled);
void SetAutoKeyRepeat(bool enabled);
void SetDecodeROM(uint8* p, bool iie);
void SetInput(const char* type, uint8* p);
void TransformInput(void);
void Power(void);
void Kill(void);

bool UpdateInput(uint8* kb_pb);
void EndTimePeriod(void);

void StateAction(StateMem* sm, const unsigned load, const bool data_only);

void ClockARDelay(void);
void ClockAR(void);

MDFN_HOT void Read_C011_C01F_IIE(void);

MDFN_HIDE extern const std::vector<InputDeviceInfoStruct> InputDeviceInfoA2KBPort;
//
//
}
}
#endif
