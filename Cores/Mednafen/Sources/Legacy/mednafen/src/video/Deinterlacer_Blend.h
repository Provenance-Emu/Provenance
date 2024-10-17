/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer_Blend.h:
**  Copyright (C) 2018 Mednafen Team
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

#ifndef __MDFN_VIDEO_DEINTERLACER_BLEND_H
#define __MDFN_VIDEO_DEINTERLACER_BLEND_H

namespace Mednafen
{

class Deinterlacer_Blend : public Deinterlacer
{
 public:

 Deinterlacer_Blend(bool gc);
 virtual ~Deinterlacer_Blend() override;

 virtual void Process(MDFN_Surface* surface, MDFN_Rect& DisplayRect, int32* LineWidths, const bool field) override;
 virtual void ClearState(void) override;

 //
 //
 private:

 template<typename T, bool gc, unsigned cc0s, unsigned cc1s, unsigned cc2s>
 T Blend(T a, T b);

 template<typename T, bool gc, unsigned cc0s, unsigned cc1s, unsigned cc2s>
 void InternalProcess(MDFN_Surface* surface, MDFN_Rect& dr, int32* LineWidths, const bool field);

 std::unique_ptr<MDFN_Surface> prev_field;

 int32 prev_height;
 std::unique_ptr<int32[]> prev_field_w;
 std::unique_ptr<uint32[]> lb;
 std::unique_ptr<uint32[]> prev_field_delay;
 int32 prev_w_delay;
 bool prev_valid;
 //
 uint16 GCRLUT[256];
 uint8 GCALUT[4096];
 //
 const bool WantRG;
};

}
#endif
