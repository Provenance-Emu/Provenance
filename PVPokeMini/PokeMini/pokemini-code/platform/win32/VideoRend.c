/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#include "VideoRend.h"

TVideoRend *VideoRend = NULL;

void VideoRend_Set(int index)
{
	switch (index) {
		case 0:  // GDI
			VideoRend = (TVideoRend *)&VideoRend_GDI;
			break;
		case 1:  // DirectDraw
			VideoRend = (TVideoRend *)&VideoRend_DDraw;
			break;
		case 2:  // Direct3D
			VideoRend = (TVideoRend *)&VideoRend_D3D;
			break;
		default: // Illegal
			VideoRend = (TVideoRend *)&VideoRend_GDI;
			break;
	}
}
