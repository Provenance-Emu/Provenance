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

#ifndef __MDFN_APPLE2_GAMEIO_H
#define __MDFN_APPLE2_GAMEIO_H

namespace MDFN_IEN_APPLE2
{
namespace GameIO
{
//
//

void Init(uint32* resistance);
void SetInput(unsigned port, const char* type, uint8* ptr);
void SetInput(const char* type, uint8* p);
void Power(void);
void Kill(void);

void UpdateInput(uint8 kb_pb);
void EndTimePeriod(void);

void StateAction(StateMem* sm, const unsigned load, const bool data_only);

MDFN_HIDE extern const std::vector<InputDeviceInfoStruct> InputDeviceInfoGIOVPort1;
MDFN_HIDE extern const std::vector<InputDeviceInfoStruct> InputDeviceInfoGIOVPort2;

MDFN_HIDE extern const std::vector<InputDeviceInfoStruct> InputDeviceInfoA2KBPort;
//
//
}
}
#endif
