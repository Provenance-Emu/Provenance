/* 2xSaI
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* http://lists.fedoraproject.org/pipermail/legal/2009-October/000928.html */

#include <mednafen/types.h>

#ifndef __2XSAI_H
#define __2XSAI_H

bool SAI_SetFormat(unsigned bpp, bool rgb555);

void SAI_Super2xSaI   (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_Super2xSaI32 (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_SuperEagle   (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_SuperEagle32 (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_2xSaI       (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_2xSaI32     (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, int width, int height);
void SAI_Scale_2xSaI  (uint8 *srcPtr, uint32 srcPitch, uint8 *dstPtr, uint32 dstPitch, uint32 dstWidth, uint32 dstHeight, int width, int height);

#endif
