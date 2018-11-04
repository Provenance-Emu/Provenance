/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* primitives.h:
**  Copyright (C) 2013-2016 Mednafen Team
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

#ifndef __MDFN_VIDEO_PRIMITIVES_H
#define __MDFN_VIDEO_PRIMITIVES_H

// Note: For simplicity, these functions do NOT perform surface dimension clipping.

void MDFN_DrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color);
void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color);
void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 fill_color);
void MDFN_DrawLine(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color);
#endif
