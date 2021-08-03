/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer.h:
**  Copyright (C) 2011-2018 Mednafen Team
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

#ifndef __MDFN_VIDEO_DEINTERLACER_H
#define __MDFN_VIDEO_DEINTERLACER_H

namespace Mednafen
{

class Deinterlacer
{
 public:

 enum
 {
  DEINT_BOB_OFFSET = 0,	// Code will fall-through to this case under certain conditions, too.
  DEINT_BOB,
  DEINT_WEAVE,
  DEINT_BLEND,
  DEINT_BLEND_RG
 };

 static Deinterlacer* Create(unsigned type);

 Deinterlacer();
 virtual ~Deinterlacer();

 virtual void Process(MDFN_Surface *surface, MDFN_Rect &DisplayRect, int32 *LineWidths, const bool field) = 0;
 virtual void ClearState(void) = 0;
};

}
#endif
