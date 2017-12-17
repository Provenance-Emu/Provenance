/*
  PokeMini Image Converter
  Copyright (C) 2011-2015  JustBurn

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

#ifndef IMG_CONV_H
#define IMG_CONV_H

enum {
	GFX_TILES,
	GFX_SPRITES,
	GFX_MAP,
	GFX_EXMAP
};

void init_confs();
int load_confs_args(int argc, char **argv);
int load_confs_file(const char *filename);

int checkduplicate_tiles(unsigned char *tilebase1, unsigned char *tilebase2, int tilesize, int numtiles, unsigned char *tile2check1, unsigned char *tile2check2);
void convert_tile_alpha(unsigned char *apixels, int pitch, unsigned char *dout);
void convert_tile(int field, unsigned char *pixels, int pitch, unsigned char *dout);
int convert_image(int format);

#endif
