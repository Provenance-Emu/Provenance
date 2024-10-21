/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* sound.h:
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

#ifndef __MDFN_APPLE2_SOUND_H
#define __MDFN_APPLE2_SOUND_H

namespace MDFN_IEN_APPLE2
{
namespace Sound
{

void SetParams(double rate, double rate_error, unsigned quality);
void StartTimePeriod(void);
uint32 EndTimePeriod(int16* OutSoundBuf, const int32 OutSoundBufMaxSize, const bool reverse);
void Power(void);
void Init(void);
void Kill(void);
void StateAction(StateMem* sm, const unsigned load, const bool data_only);

}
}
#endif
