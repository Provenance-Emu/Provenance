/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Deinterlacer_Simple.cpp:
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

#include "video-common.h"
#include "Deinterlacer.h"
#include "Deinterlacer_Simple.h"

namespace Mednafen
{

Deinterlacer_Simple::Deinterlacer_Simple(unsigned type) : StateValid(false), DeintType(type)
{
 PrevDRect.x = 0;
 PrevDRect.y = 0;

 PrevDRect.w = 0;
 PrevDRect.h = 0;
}

Deinterlacer_Simple::~Deinterlacer_Simple()
{

}

template<typename T>
void Deinterlacer_Simple::InternalProcess(MDFN_Surface *surface, MDFN_Rect &DisplayRect, int32 *LineWidths, const bool field)
{
 //
 // We need to output with LineWidths as always being valid to handle the case of horizontal resolution change between fields
 // while in interlace mode, so clear the first LineWidths entry if it's == ~0, and
 // [...]
 const bool LineWidths_In_Valid = (LineWidths[0] != ~0);
 const bool WeaveGood = (StateValid && PrevDRect.h == DisplayRect.h && DeintType == DEINT_WEAVE);
 //
 // XReposition stuff is to prevent exceeding the dimensions of the video surface under certain conditions(weave deinterlacer, previous field has higher
 // horizontal resolution than current field, and current field's rectangle has an x offset that's too large when taking into consideration the previous field's
 // width; for simplicity, we don't check widths, but just assume that the previous field's maximum width is >= than the current field's maximum width).
 //
 const int32 XReposition = ((WeaveGood && DisplayRect.x > PrevDRect.x) ? DisplayRect.x : 0);

 //printf("%2d %2d, %d\n", DisplayRect.x, PrevDRect.x, XReposition);

 if(XReposition)
  DisplayRect.x = 0;

 if(surface->h && !LineWidths_In_Valid)
 {
  LineWidths[0] = 0;
 }

 for(int y = 0; y < DisplayRect.h / 2; y++)
 {
  // [...]
  // set all relevant source line widths to the contents of DisplayRect(also simplifies the src_lw and related pointer calculation code
  // farther below.
  if(!LineWidths_In_Valid)
   LineWidths[(y * 2) + field + DisplayRect.y] = DisplayRect.w;

  if(XReposition)
  {
    memmove(surface->pix<T>() + ((y * 2) + field + DisplayRect.y) * surface->pitchinpix,
	    surface->pix<T>() + ((y * 2) + field + DisplayRect.y) * surface->pitchinpix + XReposition,
	    LineWidths[(y * 2) + field + DisplayRect.y] * sizeof(T));
  }

  if(WeaveGood)
  {
   const T* src = FieldBuffer->pix<T>() + y * FieldBuffer->pitchinpix;
   T* dest = surface->pix<T>() + ((y * 2) + (field ^ 1) + DisplayRect.y) * surface->pitchinpix + DisplayRect.x;
   int32 *dest_lw = &LineWidths[(y * 2) + (field ^ 1) + DisplayRect.y];

   *dest_lw = LWBuffer[y];

   memcpy(dest, src, LWBuffer[y] * sizeof(T));
  }
  else if(DeintType == DEINT_BOB)
  {
   const T* src = surface->pix<T>() + ((y * 2) + field + DisplayRect.y) * surface->pitchinpix + DisplayRect.x;
   T* dest = surface->pix<T>() + ((y * 2) + (field ^ 1) + DisplayRect.y) * surface->pitchinpix + DisplayRect.x;
   const int32 *src_lw = &LineWidths[(y * 2) + field + DisplayRect.y];
   int32 *dest_lw = &LineWidths[(y * 2) + (field ^ 1) + DisplayRect.y];

   *dest_lw = *src_lw;

   memcpy(dest, src, *src_lw * sizeof(T));
  }
  else
  {
   const int32 *src_lw = &LineWidths[(y * 2) + field + DisplayRect.y];
   const T* src = surface->pix<T>() + ((y * 2) + field + DisplayRect.y) * surface->pitchinpix + DisplayRect.x;
   const int32 dly = ((y * 2) + (field + 1) + DisplayRect.y);
   T* dest = surface->pix<T>() + dly * surface->pitchinpix + DisplayRect.x;

   if(y == 0 && field)
   {
    T black = surface->MakeColor(0, 0, 0);
    T* dm2 = surface->pix<T>() + (dly - 2) * surface->pitchinpix;

    LineWidths[dly - 2] = *src_lw;

    for(int x = 0; x < *src_lw; x++)
     dm2[x] = black;
   }

   if(dly < (DisplayRect.y + DisplayRect.h))
   {
    LineWidths[dly] = *src_lw;
    memcpy(dest, src, *src_lw * sizeof(T));
   }
  }

  //
  //
  //
  //
  //
  //
  if(DeintType == DEINT_WEAVE)
  {
   const int32 *src_lw = &LineWidths[(y * 2) + field + DisplayRect.y];
   const T* src = surface->pix<T>() + ((y * 2) + field + DisplayRect.y) * surface->pitchinpix + DisplayRect.x;
   T* dest = FieldBuffer->pix<T>() + y * FieldBuffer->pitchinpix;

   memcpy(dest, src, *src_lw * sizeof(T));
   LWBuffer[y] = *src_lw;

   StateValid = true;
  }
 }
}

void Deinterlacer_Simple::Process(MDFN_Surface *surface, MDFN_Rect &DisplayRect, int32 *LineWidths, const bool field)
{
 const MDFN_Rect DisplayRect_Original = DisplayRect;

 if(DeintType == DEINT_WEAVE)
 {
  if(!FieldBuffer || FieldBuffer->w < surface->w || FieldBuffer->h < (surface->h / 2))
  {
   FieldBuffer.reset(nullptr);
   FieldBuffer.reset(new MDFN_Surface(NULL, surface->w, surface->h / 2, surface->w, surface->format));
   LWBuffer.resize(FieldBuffer->h);
  }
  else if(surface->format != FieldBuffer->format)
  {
   FieldBuffer->SetFormat(surface->format, StateValid && PrevDRect.h == DisplayRect.h);
  }
 }

 switch(surface->format.opp)
 {
  case 1:
	InternalProcess<uint8>(surface, DisplayRect, LineWidths, field);
	break;

  case 2:
	InternalProcess<uint16>(surface, DisplayRect, LineWidths, field);
	break;

  case 4:
	InternalProcess<uint32>(surface, DisplayRect, LineWidths, field);
	break;
 }

 PrevDRect = DisplayRect_Original;
}

void Deinterlacer_Simple::ClearState(void)
{
 StateValid = false;

 PrevDRect.x = 0;
 PrevDRect.y = 0;

 PrevDRect.w = 0;
 PrevDRect.h = 0;
}

}
