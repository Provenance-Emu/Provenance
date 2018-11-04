/*  Copyright 2012 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifndef TITAN_H
#define TITAN_H

#include "../core.h"
#include "../vidshared.h"

#define TITAN_BLEND_TOP     0
#define TITAN_BLEND_BOTTOM  1
#define TITAN_BLEND_ADD     2

#define TITAN_SPRITE 5
#define TITAN_RBG0 4
#define TITAN_NBG0 3
#define TITAN_NBG1 2
#define TITAN_NBG2 1
#define TITAN_NBG3 0
#define TITAN_BACK -1

#define TITAN_NORMAL_SHADOW 1
#define TITAN_MSB_SHADOW 2

int TitanInit();
int TitanDeInit();
void TitanErase();

void TitanSetResolution(int width, int height);
void TitanGetResolution(int * width, int * height);

void TitanSetBlendingMode(int blend_mode);

void TitanPutBackHLine(s32 y, u32 color);

void TitanPutLineHLine(int linescreen, s32 y, u32 color);

void TitanPutPixel(int priority, s32 x, s32 y, u32 color, int linescreen, vdp2draw_struct* info);
void TitanPutHLine(int priority, s32 x, s32 y, s32 width, u32 color);

void TitanRender(pixel_t * dispbuffer);

void TitanWriteColor(pixel_t * dispbuffer, s32 bufwidth, s32 x, s32 y, u32 color);

#endif
