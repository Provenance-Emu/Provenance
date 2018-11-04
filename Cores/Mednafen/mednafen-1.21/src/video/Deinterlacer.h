/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer.h:
**  Copyright (C) 2011-2016 Mednafen Team
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

#ifndef __MDFN_DEINTERLACER_H
#define __MDFN_DEINTERLACER_H

class Deinterlacer
{
 public:

 Deinterlacer();
 ~Deinterlacer();

 enum
 {
  DEINT_BOB_OFFSET = 0,	// Code will fall-through to this case under certain conditions, too.
  DEINT_BOB,
  DEINT_WEAVE,
 };

 void SetType(unsigned t);
 inline unsigned GetType(void)
 {
  return(DeintType);
 }

 void Process(MDFN_Surface *surface, MDFN_Rect &DisplayRect, int32 *LineWidths, const bool field);

 void ClearState(void);

 private:

 template<typename T>
 void InternalProcess(MDFN_Surface *surface, MDFN_Rect &DisplayRect, int32 *LineWidths, const bool field);

 std::unique_ptr<MDFN_Surface> FieldBuffer;
 std::vector<int32> LWBuffer;
 bool StateValid;
 MDFN_Rect PrevDRect;
 unsigned DeintType;
};

#endif
