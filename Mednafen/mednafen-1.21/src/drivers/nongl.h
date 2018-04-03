/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* nongl.h:
**  Copyright (C) 2012-2016 Mednafen Team
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

#ifndef __MDFN_DRIVERS_NONGL_H
#define __MDFN_DRIVERS_NONGL_H

// This function DOES NOT handle format conversions; IE the src_surface and dest_surface should be in the same color formats.
// Also, clipping is...sketchy.  Just don't pass negative coordinates in the rects, and it should be ok.
void MDFN_StretchBlitSurface(const MDFN_Surface* src_surface, const MDFN_Rect& src_rect, MDFN_Surface* dest_surface, const MDFN_Rect& dest_rect, bool source_alpha = false, int scanlines = 0, const MDFN_Rect* original_src_rect = NULL, int rotated = MDFN_ROTATE0, int InterlaceField = -1);

#endif
