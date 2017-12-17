/*
  PokeMini Color Mapper
  Copyright (C) 2011-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef COLOR_DISPLAY_H
#define COLOR_DISPLAY_H

void colordisplay_drawhline(unsigned int *imgptr, int width, int height, int pitch,
	int y, int start, int end, int coloridx);

void colordisplay_drawvline(unsigned int *imgptr, int width, int height, int pitch,
	int x, int start, int end, int coloridx);

void colordisplay_decodespriteidx(int spriteidx, int x, int y, int *dataidx, int *maskidx);

void colordisplay_8x8Attr(unsigned int *imgptr, int width, int height, int pitch,
	int spritemode, int zoom, unsigned int offset, int select_a, int select_b,
	int negative, unsigned int transparency, int grid, int monorender, int contrast);

void colordisplay_4x4Attr(unsigned int *imgptr, int width, int height, int pitch,
	int spritemode, int zoom, unsigned int offset, int select_a, int select_b,
	int negative, unsigned int transparency, int grid, int monorender, int contrast);

#endif
