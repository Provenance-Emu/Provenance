/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* tblur.h:
**  Copyright (C) 2007-2020 Mednafen Team
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

#ifndef __MDFN_VIDEO_TBLUR_H
#define __MDFN_VIDEO_TBLUR_H

#include <mednafen/video.h>

namespace Mednafen
{

void TBlur_Init(bool accum_mode, double accum_amount, uint32 max_width, uint32 max_height) MDFN_COLD;
void TBlur_Kill(void) MDFN_COLD;
void TBlur_Run(EmulateSpecStruct *espec);
bool TBlur_IsOn(void);

}
#endif
