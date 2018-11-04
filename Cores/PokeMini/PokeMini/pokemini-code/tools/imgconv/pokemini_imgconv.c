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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <FreeImage.h>

#include "PMCommon.h"
#include "ExportCode.h"
#include "pokemini_imgconv.h"

#define VERSION_STR	"v1.4"
#define EXPORT_STR	"Image exported with PokeMini Image Converter " VERSION_STR

#define STR_GRAY	"%s_gray"
#define STR_MAP		"%s_map"
#define STR_TILES	"%s_tiles"
#define STR_MTILES	"%s_mtiles"
#define STR_SPRITES	"%s_sprites"
#define STR_MAPW	"%s_mapw"
#define STR_MAPH	"%s_maph"
#define STR_MAPSIZE	"%s_mapsize"

// ---------- Header ----------

int ImgW, ImgH;				// Width and height in pixels
int ImgMapWidth, ImgMapHeight;		// Width and height in map dim.
unsigned char *ImgSrc = NULL;		// Source, 0 = Dark(1), 1 = Gray(1/0), 2 = Light(0)
unsigned char *ImgAlp = NULL;		// Alpha, 0 = Transparent, 1 = Solid
unsigned char *ImgOut1 = NULL;		// Output 1 (output)
unsigned char *ImgOut2 = NULL;		// Output 2 (extra for gray output)
unsigned char *ImgTilesetOut1 = NULL;	// Output tileset (output)
unsigned char *ImgTilesetOut2 = NULL;	// Output tileset (extra gray)
unsigned char *ImgMap = NULL;		// Output map
int ImgMetaSize;			// Meta-tiles size
int ImgMaxMapID;			// Maximum number of map indexes
int ImgMaxTiles;			// Maximum number of tiles
int ImgMaxMetaT;			// Maximum number of meta-tiles
int ImgNumTiles;			// Number of tiles to export
int ImgNumMetaT;			// Number of meta-tiles to export
unsigned char *ImgTileset = NULL;	// External tileset, 0 = Dark(1), 1 = Gray(1/0), 2 = Light(0)
int ImgTilesetW, ImgTilesetH;		// Width and height in pixels of tileset
int ImgNumTilesetTiles;			// Number of tileset tiles
int ImgNumTilesetMetaT;			// Number of tileset meta-tiles
int ImgMaxTilesetTiles;			// Maximum number of tiles in tileset
struct {
	int quiet;		// Quiet
	int verbose;		// Verbose
	int gfx;		// 0 = Tiles, 1 = Sprites, 2 = Map
	int dither;		// Dither for 3rd color
	int colorkey;		// Transparent color key
	int meta_w;		// Metatile width (Tiles & Map)
	int meta_h;		// Metatile height (Tiles & Map)
	int meta_shift;		// Shift map index on meta-tiles
	char img_f[128];	// Image file
	char tileset_f[128];	// Tileset filename for external mapping
	char conf_f[128];	// Conf file (Optional)
	int format;		// Output format: Raw, Asm or C
	int hformat;		// Header format: Asm or C
	int joined;		// Join all data into a single file
	int out1_e;		// Output file (enable)
	char out1_f[128];	// Output file (filename)
	char out1_v[128];	// Output file (var name)
	int out2_e;		// Output file for gray (enable)
	char out2_f[128];	// Output file for gray (filename)
	char out2_v[128];	// Output file for gray (var name)
	int outts1_e;		// Output tileset file (enable)
	char outts1_f[128];	// Output tileset file (filename)
	char outts1_v[128];	// Output tileset file (var name)
	int outts2_e;		// Output tileset file for gray (enable)
	char outts2_f[128];	// Output tileset file for gray (filename)
	char outts2_v[128];	// Output tileset file for gray (var name)
	int outm_e;		// Output map file (enable)
	int outm_de;		// Output map file (def. enable)
	char outm_f[128];	// Output map file (filename)
	char outm_v[128];	// Output map file (var name)
	int outh_e;		// Output header file (enable)
	char outh_f[128];	// Output header file (filename)
	int mapidofs;		// Map Index Offset
	int mapidsiz;		// Map Index Size (0 = Unlimited)
	int maxtiles;		// Maximum number of tiles
	int threhold1;		// Dark threhold
	int threhold2;		// Light threhold
} confs;

// ---------- Conf ----------

// Initialize confs
void init_confs()
{
	memset((void *)&confs, 0, sizeof(confs));
	confs.format = FILE_ECODE_RAW;
	confs.hformat = FILE_ECODE_RAW;	// <- RAW = automatic
	confs.dither = 1;
	confs.meta_w = 1;
	confs.meta_h = 1;
	confs.colorkey = 0xFF00FF;
	confs.out1_e = 1;
	confs.out2_e = 1;
	confs.outts1_e = 1;
	confs.outts2_e = 1;
	confs.outm_e = 1;
	confs.outh_e = 1;
	confs.mapidofs = 0;
	confs.mapidsiz = 0;
	confs.maxtiles = 65536;
	confs.threhold1 = 64;
	confs.threhold2 = 192;
}

// Load confs from arguments
int load_confs_args(int argc, char **argv)
{
	argv++;
	while (*argv) {
		if (*argv[0] == '-') {
			if (!strcasecmp(*argv, "-tiles")) confs.gfx = GFX_TILES;
			else if (!strcasecmp(*argv, "-oam")) confs.gfx = GFX_SPRITES;
			else if (!strcasecmp(*argv, "-spr")) confs.gfx = GFX_SPRITES;
			else if (!strcasecmp(*argv, "-sprites")) confs.gfx = GFX_SPRITES;
			else if (!strcasecmp(*argv, "-map")) confs.gfx = GFX_MAP;
			else if (!strcasecmp(*argv, "-exmap")) confs.gfx = GFX_EXMAP;
			else if (!strcasecmp(*argv, "-external")) confs.gfx = GFX_EXMAP;
			else if (!strcasecmp(*argv, "-externalmap")) confs.gfx = GFX_EXMAP;
			else if (!strcasecmp(*argv, "-nodither")) confs.dither = 0;
			else if (!strcasecmp(*argv, "-dither")) confs.dither = 1;
			else if (!strcasecmp(*argv, "-nocolorkey")) confs.colorkey = -1;
			else if (!strcasecmp(*argv, "-colorkey")) { if (*++argv) confs.colorkey = BetweenNum(atoi_Ex(*argv, 0xFF00FF), 0x000000, 0xFFFFFF); }
			else if (!strcasecmp(*argv, "-metaw")) { if (*++argv) confs.meta_w = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-metah")) { if (*++argv) confs.meta_h = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-meta_w")) { if (*++argv) confs.meta_w = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-meta_h")) { if (*++argv) confs.meta_h = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-metax")) { if (*++argv) confs.meta_w = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-metay")) { if (*++argv) confs.meta_h = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-meta_x")) { if (*++argv) confs.meta_w = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-meta_y")) { if (*++argv) confs.meta_h = BetweenNum(atoi_Ex(*argv, 1), 1, 256); }
			else if (!strcasecmp(*argv, "-nometashl")) confs.meta_shift = 0;
			else if (!strcasecmp(*argv, "-metashl")) confs.meta_shift = 1;
			else if (!strcasecmp(*argv, "-nometa_shl")) confs.meta_shift = 0;
			else if (!strcasecmp(*argv, "-meta_shl")) confs.meta_shift = 1;
			else if (!strcasecmp(*argv, "-rawf")) confs.format = FILE_ECODE_RAW;
			else if (!strcasecmp(*argv, "-asmf")) confs.format = FILE_ECODE_ASM;
			else if (!strcasecmp(*argv, "-cf")) confs.format = FILE_ECODE_C;
			else if (!strcasecmp(*argv, "-autohf")) confs.hformat = FILE_ECODE_RAW;
			else if (!strcasecmp(*argv, "-asmhf")) confs.hformat = FILE_ECODE_ASM;
			else if (!strcasecmp(*argv, "-chf")) confs.hformat = FILE_ECODE_C;
			else if (!strcasecmp(*argv, "-separated")) confs.joined = 0;
			else if (!strcasecmp(*argv, "-joined")) confs.joined = 1;
			else if (!strcasecmp(*argv, "-i")) { if (*++argv) strncpy(confs.img_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-in")) { if (*++argv) strncpy(confs.img_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-img")) { if (*++argv) strncpy(confs.img_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-tset")) { if (*++argv) strncpy(confs.tileset_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-tileset")) { if (*++argv) strncpy(confs.tileset_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-c")) { if (*++argv) strncpy(confs.conf_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-cfg")) { if (*++argv) strncpy(confs.conf_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-conf")) { if (*++argv) strncpy(confs.conf_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-o")) { if (*++argv) strncpy(confs.out1_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-og")) { if (*++argv) strncpy(confs.out2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-ots")) { if (*++argv) strncpy(confs.outts1_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-otsg")) { if (*++argv) strncpy(confs.outts2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-om")) { if (*++argv) strncpy(confs.outm_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-oh")) { if (*++argv) strncpy(confs.outh_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-out")) { if (*++argv) strncpy(confs.out1_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outgray")) { if (*++argv) strncpy(confs.out2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outgrey")) { if (*++argv) strncpy(confs.out2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outtileset")) { if (*++argv) strncpy(confs.out1_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outtilesetgray")) { if (*++argv) strncpy(confs.out2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outtilesetgrey")) { if (*++argv) strncpy(confs.out2_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outmap")) { if (*++argv) strncpy(confs.outm_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outheader")) { if (*++argv) strncpy(confs.outh_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-vo")) { if (*++argv) strncpy(confs.out1_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vog")) { if (*++argv) strncpy(confs.out2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vots")) { if (*++argv) strncpy(confs.outts1_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-votsg")) { if (*++argv) strncpy(confs.outts2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vom")) { if (*++argv) strncpy(confs.outm_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vout")) { if (*++argv) strncpy(confs.out1_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-voutgray")) { if (*++argv) strncpy(confs.out2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-voutgrey")) { if (*++argv) strncpy(confs.out2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vouttileset")) { if (*++argv) strncpy(confs.outts1_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vouttilesetgray")) { if (*++argv) strncpy(confs.outts2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vouttilesetgrey")) { if (*++argv) strncpy(confs.outts2_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-voutmap")) { if (*++argv) strncpy(confs.outm_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-idofs")) { if (*++argv); confs.mapidofs = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-idoffset")) { if (*++argv) confs.mapidofs = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-idsize")) { if (*++argv) confs.mapidsiz = BetweenNum(atoi_Ex(*argv, 0), 0, 65536); }
			else if (!strcasecmp(*argv, "-id_ofs")) { if (*++argv) confs.mapidofs = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-id_offset")) { if (*++argv) confs.mapidofs = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-id_size")) { if (*++argv) confs.mapidsiz = BetweenNum(atoi_Ex(*argv, 0), 0, 65536); }
			else if (!strcasecmp(*argv, "-maxtiles")) { if (*++argv) confs.maxtiles = BetweenNum(atoi_Ex(*argv, 0), 0, 65536); }
			else if (!strcasecmp(*argv, "-darkthrehold")) { if (*++argv) confs.threhold1 = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-lightthrehold")) { if (*++argv) confs.threhold2 = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-dt")) { if (*++argv) confs.threhold1 = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-lt")) { if (*++argv) confs.threhold2 = BetweenNum(atoi_Ex(*argv, 0), 0, 255); }
			else if (!strcasecmp(*argv, "-q")) confs.quiet = 1;
			else if (!strcasecmp(*argv, "-v")) confs.verbose = 1;
			else return 0;
		} else return 0;
		if (*argv) argv++;
	}

	// Image filename or config filename cannot be empty
	if (!strlen(confs.img_f) && !strlen(confs.conf_f)) return 0;

	return 1;
}

// Load confs from file
int load_confs_file(const char *filename)
{
	FILE *fi;
	char tmp[1024], *txt, *key, *value;

	fi = fopen(filename, "r");
	if (!fi) return 0;

	if (fi) {
		while ((txt = fgets(tmp, 1024, fi)) != NULL) {
			// Remove comments
			RemoveComments(txt);

			// Break up key and value
			if (!SeparateAtChar(txt, '=', &key, &value)) continue;

			// Trim them
			key = TrimStr(key);
			value = TrimStr(value);

			// Decode key and set CommandLine
			if (!strcasecmp(key, "gfx")) {
				if (!strcasecmp(value, "tiles")) confs.gfx = GFX_TILES;
				else if (!strcasecmp(value, "oam")) confs.gfx = GFX_SPRITES;
				else if (!strcasecmp(value, "spr")) confs.gfx = GFX_SPRITES;
				else if (!strcasecmp(value, "sprites")) confs.gfx = GFX_SPRITES;
				else if (!strcasecmp(value, "map")) confs.gfx = GFX_MAP;
				else if (!strcasecmp(value, "exmap")) confs.gfx = GFX_EXMAP;
				else if (!strcasecmp(value, "external")) confs.gfx = GFX_EXMAP;
				else if (!strcasecmp(value, "externalmap")) confs.gfx = GFX_EXMAP;
				else printf("Conf warning: Unknown '%s' value in 'gfx' key\n", value);
			}
			else if (!strcasecmp(key, "dither")) confs.dither = Str2Bool(value);
			else if (!strcasecmp(key, "colorkey")) confs.colorkey = BetweenNum(atoi_Ex(value, 0xFF00FF), -1, 0xFFFFFF);
			else if (!strcasecmp(key, "metaw")) confs.meta_w = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "metah")) confs.meta_h = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "meta_w")) confs.meta_w = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "meta_h")) confs.meta_h = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "metax")) confs.meta_w = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "metay")) confs.meta_h = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "meta_x")) confs.meta_w = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "meta_y")) confs.meta_h = BetweenNum(atoi_Ex(value, 1), 1, 256);
			else if (!strcasecmp(key, "metashl")) confs.meta_shift = Str2Bool(value);
			else if (!strcasecmp(key, "meta_shl")) confs.meta_shift = Str2Bool(value);
			else if (!strcasecmp(key, "format")) {
				if (!strcasecmp(value, "raw")) confs.format = FILE_ECODE_RAW;
				else if (!strcasecmp(value, "bin")) confs.format = FILE_ECODE_RAW;
				else if (!strcasecmp(value, "asm")) confs.format = FILE_ECODE_ASM;
				else if (!strcasecmp(value, "c")) confs.format = FILE_ECODE_C;
				else printf("Conf warning: Unknown '%s' value in 'format' key\n", value);
			}
			else if (!strcasecmp(key, "headerformat")) {
				if (!strcasecmp(value, "auto")) confs.hformat = FILE_ECODE_RAW;
				else if (!strcasecmp(value, "asm")) confs.hformat = FILE_ECODE_ASM;
				else if (!strcasecmp(value, "c")) confs.hformat = FILE_ECODE_C;
				else printf("Conf warning: Unknown '%s' value in 'headerformat' key\n", value);
			}
			else if (!strcasecmp(key, "joined")) confs.joined = Str2Bool(value);
			else if (!strcasecmp(key, "img")) strncpy(confs.img_f, value, 127);
			else if (!strcasecmp(key, "tileset")) strncpy(confs.tileset_f, value, 127);
			else if (!strcasecmp(key, "out")) strncpy(confs.out1_f, value, 127);
			else if (!strcasecmp(key, "outgray")) strncpy(confs.out2_f, value, 127);
			else if (!strcasecmp(key, "outgrey")) strncpy(confs.out2_f, value, 127);
			else if (!strcasecmp(key, "outtileset")) strncpy(confs.outts1_f, value, 127);
			else if (!strcasecmp(key, "outtilesetgray")) strncpy(confs.outts2_f, value, 127);
			else if (!strcasecmp(key, "outtilesetgrey")) strncpy(confs.outts2_f, value, 127);
			else if (!strcasecmp(key, "outmap")) strncpy(confs.outm_f, value, 127);
			else if (!strcasecmp(key, "outheader")) strncpy(confs.outh_f, value, 127);
			else if (!strcasecmp(key, "voutgray")) strncpy(confs.out2_v, value, 127);
			else if (!strcasecmp(key, "voutgrey")) strncpy(confs.out2_v, value, 127);
			else if (!strcasecmp(key, "vouttileset")) strncpy(confs.out1_v, value, 127);
			else if (!strcasecmp(key, "vouttilesetgray")) strncpy(confs.out2_v, value, 127);
			else if (!strcasecmp(key, "vouttilesetgrey")) strncpy(confs.out2_v, value, 127);
			else if (!strcasecmp(key, "voutmap")) strncpy(confs.outm_v, value, 127);
			else if (!strcasecmp(key, "wout")) confs.out1_e = Str2Bool(value);
			else if (!strcasecmp(key, "woutgray")) confs.out2_e = Str2Bool(value);
			else if (!strcasecmp(key, "woutgrey")) confs.out2_e = Str2Bool(value);
			else if (!strcasecmp(key, "wouttileset")) confs.outts1_e = Str2Bool(value);
			else if (!strcasecmp(key, "wouttilesetgray")) confs.outts2_e = Str2Bool(value);
			else if (!strcasecmp(key, "wouttilesetgrey")) confs.outts2_e = Str2Bool(value);
			else if (!strcasecmp(key, "woutmap")) confs.outm_e = Str2Bool(value);
			else if (!strcasecmp(key, "woutheader")) confs.outh_e = Str2Bool(value);
			else if (!strcasecmp(key, "idofs")) confs.mapidofs = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "idoffset")) confs.mapidofs = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "idsize")) confs.mapidsiz = BetweenNum(atoi_Ex(value, 0), 0, 65536);
			else if (!strcasecmp(key, "id_ofs")) confs.mapidofs = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "id_offset")) confs.mapidofs = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "id_size")) confs.mapidsiz = BetweenNum(atoi_Ex(value, 0), 0, 65536);
			else if (!strcasecmp(key, "maxtiles")) confs.maxtiles = BetweenNum(atoi_Ex(value, 0), 0, 65536);
			else if (!strcasecmp(key, "darkthrehold")) confs.threhold1 = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "lightthrehold")) confs.threhold2 = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "dt")) confs.threhold1 = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else if (!strcasecmp(key, "lt")) confs.threhold2 = BetweenNum(atoi_Ex(value, 0), 0, 255);
			else printf("Conf warning: Unknown '%s' key\n", key);
		}
		fclose(fi);
	}

	return 1;
}

// ---------- Converter ----------

int checkduplicate_tiles(unsigned char *tilebase1, unsigned char *tilebase2, int tilesize, int numtiles, unsigned char *tile2check1, unsigned char *tile2check2)
{
	int x, y;
	for (y=0; y<numtiles; y++) {
		for (x=0; x<tilesize; x++) {
			if (tilebase1[y*tilesize+x] != tile2check1[x]) break;
			if (tilebase2[y*tilesize+x] != tile2check2[x]) break;
		}
		if (x == tilesize) return y;
	}
	return -1;
}

void convert_tile_alpha(unsigned char *apixels, int pitch, unsigned char *dout)
{
	unsigned char data;
	int px, py, b;
	for (py=0; py<(confs.meta_h*8); py+=8) {
		for (px=0; px<(confs.meta_w*8); px++) {
			data = 0;
			for (b=0; b<8; b++) {
				if (!apixels[(py+b) * pitch + px]) {
					data |= (1 << b);
				}
			}
			*dout++ = data;
		}
	}
}

void convert_tile(int field, unsigned char *pixels, int pitch, unsigned char *dout)
{
	unsigned char data;
	int px, py, b;
	for (py=0; py<(confs.meta_h*8); py+=8) {
		for (px=0; px<(confs.meta_w*8); px++) {
			data = 0;
			for (b=0; b<8; b++) {
				switch (pixels[(py+b) * pitch + px]) {
					case 0: data |= (1 << b);
						break;
					case 1: if (confs.dither) {
							if ((field ^ px ^ b) & 1) data |= (1 << b);
						} else {
							if (field) data |= (1 << b);
						}
						break;
				}
			}
			*dout++ = data;
		}
	}
}

int convert_image(int gfx)
{
	unsigned char *dout1 = NULL;
	unsigned char *dout2 = NULL;
	unsigned char *doutA = NULL;
	int px, py, mapoff = 0, mapid = confs.mapidofs, schid;
	int noerror = 1;

	// Allocate memory for conversion
	ImgNumTiles = 0;
	ImgNumMetaT = 0;
	ImgNumTilesetTiles = 0;
	ImgNumTilesetMetaT = 0;
	dout1 = (unsigned char *)malloc(ImgMetaSize*8);
	dout2 = (unsigned char *)malloc(ImgMetaSize*8);
	doutA = (unsigned char *)malloc(ImgMetaSize*8);

	// Convert external map first
	if (confs.gfx == GFX_EXMAP) {
		for (py=0; py<ImgTilesetH; py += (confs.meta_h*8)) {
			for (px=0; px<ImgTilesetW; px += (confs.meta_w*8)) {
				convert_tile(0, &ImgTileset[py*ImgTilesetW+px], ImgTilesetW, dout1);
				convert_tile(1, &ImgTileset[py*ImgTilesetW+px], ImgTilesetW, dout2);
				memcpy(&ImgTilesetOut1[ImgNumTilesetTiles*8], dout1, ImgMetaSize*8);
				memcpy(&ImgTilesetOut2[ImgNumTilesetTiles*8], dout2, ImgMetaSize*8);
				ImgNumTilesetTiles += ImgMetaSize;
				ImgNumTilesetMetaT++;
			}
		}
	}

	// Convert the map/sprites
	for (py=0; py<ImgH; py += (confs.meta_h*8)) {
		for (px=0; px<ImgW; px += (confs.meta_w*8)) {
			// Convert tiles
			convert_tile(0, &ImgSrc[py*ImgW+px], ImgW, dout1);
			convert_tile(1, &ImgSrc[py*ImgW+px], ImgW, dout2);
			convert_tile_alpha(&ImgAlp[py*ImgW+px], ImgW, doutA);

			if (gfx == GFX_MAP) {
				// Check for duplicates in map gfx, discard it there's one
				schid = checkduplicate_tiles(ImgOut1, ImgOut2, ImgMetaSize*8, ImgNumMetaT, dout1, dout2);
				if (schid >= 0) {
					// Duplicated
					if (confs.meta_shift) ImgMap[mapoff++] = schid * ImgMetaSize;
					else ImgMap[mapoff++] = schid;
					continue;
				} else {
					// Not duplicated
					ImgMap[mapoff++] = mapid;
					if (confs.meta_shift) mapid += ImgMetaSize;
					else mapid++;
				}
				if (mapid == 0x100) {
					// Map ID going over 8-bits range
					fprintf(stderr, "Error: Map ID out of range\n");
					noerror = 0;
				}
				if (confs.mapidsiz) {
					// Check for map ID size limit
					if (mapid >= (confs.mapidofs + confs.mapidsiz)) {
						px = ImgW; py = ImgH;
					}
				}
			} else if (confs.gfx == GFX_EXMAP) {
				// Check for the tile in the tileset
				schid = checkduplicate_tiles(ImgTilesetOut1, ImgTilesetOut2, ImgMetaSize*8, ImgNumTilesetMetaT, dout1, dout2);
				if (confs.meta_shift) ImgMap[mapoff++] = schid * ImgMetaSize;
				else ImgMap[mapoff++] = schid;
				if (schid < 0) {
					fprintf(stderr, "Error: No matching tile in (%i, %i)\n", px, py);
					noerror = 0;
				}
			} else {
				// Just copy data
				ImgMap[mapoff++] = mapid++;
			}

			// Add tile to output
			if (gfx == GFX_SPRITES) {
				memcpy(&ImgOut1[ImgNumTiles*8], &doutA[0], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+8], &doutA[16], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+16], &dout1[0], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+24], &dout1[16], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+32], &doutA[8], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+40], &doutA[24], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+48], &dout1[8], 8);
				memcpy(&ImgOut1[ImgNumTiles*8+56], &dout1[24], 8);
				memcpy(&ImgOut2[ImgNumTiles*8], &doutA[0], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+8], &doutA[16], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+16], &dout2[0], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+24], &dout2[16], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+32], &doutA[8], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+40], &doutA[24], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+48], &dout2[8], 8);
				memcpy(&ImgOut2[ImgNumTiles*8+56], &dout2[24], 8);
				ImgNumTiles += ImgMetaSize*2;
			} else {
				memcpy(&ImgOut1[ImgNumTiles*8], dout1, ImgMetaSize*8);
				memcpy(&ImgOut2[ImgNumTiles*8], dout2, ImgMetaSize*8);
				ImgNumTiles += ImgMetaSize;
			}
			ImgNumMetaT++;

			// Check for tiles limit
			if (mapid >= (confs.mapidofs + confs.maxtiles)) {
				px = ImgW; py = ImgH;
			}
		}
	}

	// Free memory
	if (dout1) free(dout1);
	if (dout2) free(dout2);
	if (doutA) free(doutA);
	if (confs.mapidsiz) {
		if (confs.mapidsiz < ImgMaxMapID) ImgMaxMapID = confs.mapidsiz;
	}

	return noerror;
}

int convert_imgdata(const char *imgfile, int *ImgW, int *ImgH, unsigned char **ImgDst, unsigned char **ImgAlp)
{
	FIBITMAP *dib, *dib2;
	FREE_IMAGE_FORMAT ftyp;
	unsigned char *dst, *alp;
	int x, y, color, dist, w, h;
	char *ext;

	// Try to guess image type
	ext = GetExtension(imgfile);
	if (!strcasecmp(ext, ".bmp")) ftyp = FIF_BMP;
	else if (!strcasecmp(ext, ".ico")) ftyp = FIF_ICO;
	else if (!strcasecmp(ext, ".jpg")) ftyp = FIF_JPEG;
	else if (!strcasecmp(ext, ".jpeg")) ftyp = FIF_JPEG;
	else if (!strcasecmp(ext, ".pcx")) ftyp = FIF_PCX;
	else if (!strcasecmp(ext, ".png")) ftyp = FIF_PNG;
	else if (!strcasecmp(ext, ".tga")) ftyp = FIF_TARGA;
	else if (!strcasecmp(ext, ".tif")) ftyp = FIF_TIFF;
	else if (!strcasecmp(ext, ".tiff")) ftyp = FIF_TIFF;
	else if (!strcasecmp(ext, ".gif")) ftyp = FIF_GIF;
	else if (!strcasecmp(ext, ".psd")) ftyp = FIF_PSD;
	else if (!strcasecmp(ext, ".dds")) {
		ftyp = FIF_DDS;
		if (!confs.quiet) printf("Warning: DDS image isn't fully supported\n");
	} else {
		fprintf(stderr, "Error: Unsupported image extension '%s'\n", ext);
		return 0;
	}	

	// Open image
	dib = FreeImage_Load(ftyp, imgfile, 0);
	if (dib == NULL) {
		fprintf(stderr, "Error: Failed to open image '%s'\n", imgfile);
		return 0;
	}
	FreeImage_FlipVertical(dib);
	w = FreeImage_GetWidth(dib);
	h = FreeImage_GetHeight(dib);
	if ((w & 7) || (h & 7)) {
		fprintf(stderr, "Error: Width and height must be multiple of 8 in '%s'\n", imgfile);
		FreeImage_Unload(dib);
		return 0;
	}
	dib2 = FreeImage_ConvertTo32Bits(dib);
	if (dib2 == NULL) {
		fprintf(stderr, "Error: Failed to convert image\n");
		FreeImage_Unload(dib);
		return 0;
	}

	// Normalize pixels values
	dst = (unsigned char *)malloc(w * h);
	alp = (unsigned char *)malloc(w * h);
	for (y=0; y<h; y++) {
		unsigned long *ptr = (unsigned long *)FreeImage_GetScanLine(dib2, y);
		unsigned char *ptrS = (unsigned char *)&dst[y * w];
		unsigned char *ptrA = (unsigned char *)&alp[y * w];
		for (x=0; x<w; x++) {
			color = ptr[x] & 0xFFFFFF;
			dist = ((color & 0x0000FF) * 19595 + ((color & 0x00FF00) >> 8) * 38470 + ((color & 0xFF0000) >> 16) * 7471) >> 16;
			if (dist >= confs.threhold2) {
				ptrS[x] = 2;
			} else if (dist <= confs.threhold1) {
				ptrS[x] = 0;
			} else {
				ptrS[x] = 1;
			}
			if (color == confs.colorkey) ptrA[x] = 0;
			else ptrA[x] = (ptr[x] & 0x80000000) ? 1 : 0;
		}
	}

	// Close image
	FreeImage_Unload(dib2);
	FreeImage_Unload(dib);

	// Set outputs
	if (ImgW) *ImgW = w;
	if (ImgH) *ImgH = h;
	if (ImgDst) {
		*ImgDst = dst;
	} else {
		free(dst);
	}
	if (ImgAlp) {
		*ImgAlp = alp;
	} else {
		free(alp);
	}
	return 1;
}

// ---------- Main ----------

int main(int argc, char **argv)
{
	FILE_ECODE *foptr;
	FILE *fo;
	int x, y;
	int exported = 0;

	// Read from command line
	init_confs();
	if (!load_confs_args(argc, argv)) {
		printf("PokeMini Image Converter " VERSION_STR "\n\n");
		printf("Usage: pokemini_imgconv [options]\n\n");
		printf("  -tiles              Convert to tiles (def)\n");
		printf("  -sprites            Convert to sprites\n");
		printf("  -map                Convert to map\n");
		printf("  -exmap              Convert to map from external tileset\n");
		printf("  -nodither           Disable dither\n");
		printf("  -dither             Enable dither (def)\n");
		printf("  -nocolorkey         No color key\n");
		printf("  -colorkey #FF00FF   Color key (def)\n");
		printf("  -metaw 1            Meta-tile width in tiles\n");
		printf("  -metah 1            Meta-tile height in tiles\n");
		printf("  -nometashl          Don't shift map index for meta (def)\n");
		printf("  -metashl            Shift map index left for meta-tiles\n");
		printf("  -rawf               Output in raw format (def)\n");
		printf("  -asmf               Output in asm format\n");
		printf("  -cf                 Output in C format\n");
		printf("  -autohf             Autodetect correct header format (def)\n");
		printf("  -asmhf              Output header in asm format\n");
		printf("  -chf                Output header in C format\n");
		printf("  -separated          Separate data to each file (def)\n");
		printf("  -joined             Join all data into a single file\n");
		printf("  -i img.png          Image input\n");
		printf("  -tileset img.dat    External tileset\n");
		printf("  -c img.txt          Conf. file input\n");
		printf("  -o img.raw          Output file\n");
		printf("  -og imgg.raw        Output file (gray)\n");
		printf("  -ots imgts.raw      Output tileset file\n");
		printf("  -otsg imgtsg.raw    Output tileset file (gray)\n");
		printf("  -om map.raw         Output map indexes file\n");
		printf("  -oh img.inc         Output header file\n");
		printf("  -vo img             Variable name for output\n");
		printf("  -vog imgg           Variable name for gray output\n");
		printf("  -vtso imgts         Variable name for tileset output\n");
		printf("  -vtsog imgtsg       Variable name for tileset gray output\n");
		printf("  -vom map            Variable name for map indexes\n");
		printf("  -idofs 0            Map index offset\n");
		printf("  -idsize 0           Map index size (0=Unlimited)\n");
		printf("  -maxtiles 65536     Maximum number of tiles\n");
		printf("  -dt 64              Dark threhold, lower lum. will be full dark\n");
		printf("  -lt 192             Light threhold, higher lum. will be full light\n");
		printf("  -q                  Quiet\n");
		printf("  -v                  Verbose\n");
		printf("\nSupported images are:\n.bmp, .ico, .jpg, .jpeg, .pcx, .png, .tga, .tif, .tiff, .gif, .psd and .dds\n");
		return 0;
	}
	if (!confs.quiet) printf("PokeMini Image Converter " VERSION_STR "\n\n");
	if (strlen(confs.conf_f)) {
		// Load configurations
		if (!load_confs_file(confs.conf_f)) {
			fprintf(stderr, "Error: Failed to load '%s' conf file\n", confs.conf_f);
			return 1;
		}
		// Make sure command-line takes priority
		load_confs_args(argc, argv);
	}

	// Image filename cannot be empty
	if (!strlen(confs.img_f)) {
		fprintf(stderr, "Error: Missing input image\n");
		return 1;
	}

	// Convert image to a normalized format
	if (!convert_imgdata(confs.img_f, &ImgW, &ImgH, &ImgSrc, &ImgAlp)) return 1;
	ImgMaxTiles = (ImgW * ImgH) >> 6;
	ImgMaxMapID = ImgMaxTiles;
	ImgOut1 = (unsigned char *)malloc(ImgMaxTiles * 8 * 2);
	ImgOut2 = (unsigned char *)malloc(ImgMaxTiles * 8 * 2);
	ImgMap = (unsigned char *)malloc(ImgMaxMapID);
	if (confs.gfx == GFX_EXMAP) {
		if (!convert_imgdata(confs.tileset_f, &ImgTilesetW, &ImgTilesetH, &ImgTileset, NULL)) return 1;
		ImgMaxTilesetTiles = (ImgTilesetW * ImgTilesetH) >> 6;
		ImgTilesetOut1 = (unsigned char *)malloc(ImgMaxTilesetTiles * 8 * 2);
		ImgTilesetOut2 = (unsigned char *)malloc(ImgMaxTilesetTiles * 8 * 2);
	}

	// Clear output data
	for (y=0; y<ImgMaxTiles; y++) {
		for (x=0; x<8*2; x++) {
			ImgOut1[y*8*2+x] = 0x00;
			ImgOut2[y*8*2+x] = 0x00;
		}
	}
	for (y=0; y<ImgMaxMapID; y++) {
		ImgMap[y] = 0;
	}

	// Force meta-tiles to 2x2 on sprites
	if (confs.gfx == GFX_SPRITES) {
		confs.meta_w = 2;
		confs.meta_h = 2;
	}
	ImgMapWidth = ImgW / (confs.meta_w*8);
	ImgMapHeight = ImgH / (confs.meta_h*8);
	ImgMaxMapID = ImgMapWidth * ImgMapHeight;
	ImgMetaSize = confs.meta_w * confs.meta_h;
	ImgMaxMetaT = ImgMaxTiles / ImgMetaSize;
	if (confs.gfx == GFX_MAP) confs.outm_de = 1;

	// Sanity check for meta tiles
	if (ImgW % (confs.meta_w*8)) {
		fprintf(stderr, "Error: Width must be multiple of %i\n", (confs.meta_w*8));
		return 1;
	}
	if (ImgH % (confs.meta_h*8)) {
		fprintf(stderr, "Error: Height must be multiple of %i\n", (confs.meta_h*8));
		return 1;
	}

	// Convert image
	if (!confs.quiet && confs.verbose) {
		printf("%3i * %3i image\n", ImgW, ImgH);
		printf("%3i * %3i map in pixels\n", ImgMapWidth * (confs.meta_w*8), ImgMapHeight * (confs.meta_h*8));
		printf("%3i * %3i map in meta-tiles, %i total\n", ImgMapWidth, ImgMapHeight, ImgMaxMapID);
	}
	if (!convert_image(confs.gfx)) return 1;
	if (!confs.quiet && confs.verbose) {
		printf("%3i tiles total\n%3i meta-tiles (%ix%i)\n", ImgNumTiles, ImgNumMetaT, confs.meta_w, confs.meta_h);
	}

	// Generate var names if they are empty
	if (!strlen(confs.out1_v)) {
		strcpy(confs.out1_v, GetFilename(confs.out1_f));
		RemoveExtension(confs.out1_v);
		FixSymbolID(confs.out1_v);
	}
	if (!strlen(confs.out2_v)) {
		strcpy(confs.out2_v, GetFilename(confs.out2_f));
		if (!strlen(confs.out2_v)) sprintf(confs.out2_v, STR_GRAY, confs.out1_v);
		RemoveExtension(confs.out2_v);
		FixSymbolID(confs.out2_v);
	}
	if (!strlen(confs.outts1_v)) {
		strcpy(confs.outts1_v, GetFilename(confs.outts1_f));
		RemoveExtension(confs.outts1_v);
		FixSymbolID(confs.outts1_v);
	}
	if (!strlen(confs.outts2_v)) {
		strcpy(confs.outts2_v, GetFilename(confs.outts2_f));
		if (!strlen(confs.outts2_v)) sprintf(confs.outts2_v, STR_GRAY, confs.outts1_v);
		RemoveExtension(confs.outts2_v);
		FixSymbolID(confs.outts2_v);
	}
	if (!strlen(confs.outm_v)) {
		strcpy(confs.outm_v, GetFilename(confs.outm_f));
		if (!strlen(confs.outm_v)) sprintf(confs.outm_v, STR_MAP, confs.out1_v);
		RemoveExtension(confs.outm_v);
		FixSymbolID(confs.outm_v);
	} else confs.outm_de = 1;
	if (!confs.quiet && confs.verbose) printf("Out data var: '%s'\n", confs.out1_v);
	if (!confs.quiet && confs.verbose) printf("Out gray var: '%s'\n", confs.out2_v);
	if (!confs.quiet && confs.verbose) printf("Out map var: '%s'\n", confs.outm_v);
	if (!confs.quiet && confs.verbose) printf("Out tileset data var: '%s'\n", confs.outts1_v);
	if (!confs.quiet && confs.verbose) printf("Out tileset gray var: '%s'\n", confs.outts2_v);

	// Output data
	if (confs.out1_e && strlen(confs.out1_f)) {
		foptr = Open_ExportCode(confs.format, confs.out1_f);
		Comment_ExportCode(foptr, "%s", EXPORT_STR);
		Comment_ExportCode(foptr, "Data file");
		Comment_ExportCode(foptr, "");
		if (foptr) {
			if (confs.joined) {
				WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.out1_v, ImgOut1, ImgNumTiles*8);
				if (!confs.quiet) {
					printf("Wrote %d tiles to output\n", ImgNumTiles);
					if (ImgMetaSize != 1) printf("      %d meta-tiles to output\n", ImgNumMetaT);
				}
				exported |= 1;
				if (confs.out2_e) {
					WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.out2_v, ImgOut2, ImgNumTiles*8);
					if (!confs.quiet) {
						printf("Wrote %d tiles to output gray\n", ImgNumTiles);
						if (ImgMetaSize != 1) printf("      %d meta-tiles to output gray\n", ImgNumMetaT);
					}
					exported |= 2;
				}
				if (confs.outts1_e) {
					WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outts1_v, ImgTilesetOut1, ImgNumTilesetTiles*8);
					if (!confs.quiet) {
						printf("Wrote %d tiles to tileset output\n", ImgNumTilesetTiles);
						if (ImgMetaSize != 1) printf("      %d meta-tiles to tileset output\n", ImgNumTilesetMetaT);
					}
					exported |= 4;
				}
				if (confs.outts2_e) {
					WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outts2_v, ImgTilesetOut2, ImgNumTilesetTiles*8);
					if (!confs.quiet) {
						printf("Wrote %d tiles to tileset output gray\n", ImgNumTilesetTiles);
						if (ImgMetaSize != 1) printf("      %d meta-tiles to tileset output gray\n", ImgNumTilesetMetaT);
					}
					exported |= 8;
				}
				if (confs.outm_e && confs.outm_de) {
					WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outm_v, ImgMap, ImgMaxMapID);
					if (!confs.quiet) printf("Wrote %d entries to map indexes\n", ImgMaxMapID);
					exported |= 16;
				}
			} else {
				WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.out1_v, ImgOut1, ImgNumTiles*8);
				if (!confs.quiet) {
					printf("Wrote %d tiles to output\n", ImgNumTiles);
					if (ImgMetaSize != 1) printf("      %d meta-tiles to output\n", ImgNumMetaT);
				}
				exported |= 1;
			}
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.out1_f);
		Close_ExportCode(foptr);
	}
	if (confs.out2_e && strlen(confs.out2_f) && !confs.joined) {
		foptr = Open_ExportCode(confs.format, confs.out2_f);
		Comment_ExportCode(foptr, "%s", EXPORT_STR);
		Comment_ExportCode(foptr, "Gray data file");
		Comment_ExportCode(foptr, "");
		if (foptr) {
			WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.out2_v, ImgOut2, ImgNumTiles*8);
			if (!confs.quiet) {
				printf("Wrote %d tiles to output gray\n", ImgNumTiles);
				if (ImgMetaSize != 1) printf("      %d meta-tiles to output gray\n", ImgNumMetaT);
			}
			exported |= 2;
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.out2_f);
		Close_ExportCode(foptr);
	}
	if (confs.outts1_e && strlen(confs.outts1_f) && !confs.joined) {
		foptr = Open_ExportCode(confs.format, confs.outts1_f);
		Comment_ExportCode(foptr, "%s", EXPORT_STR);
		Comment_ExportCode(foptr, "Tileset data file");
		Comment_ExportCode(foptr, "");
		if (foptr) {
			WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outts1_v, ImgTilesetOut1, ImgNumTilesetTiles*8);
			if (!confs.quiet) {
				printf("Wrote %d tiles to tileset output\n", ImgNumTilesetTiles);
				if (ImgMetaSize != 1) printf("      %d meta-tiles to tileset output\n", ImgNumTilesetMetaT);
			}
			exported |= 4;
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.outts1_f);
		Close_ExportCode(foptr);
	}
	if (confs.outts2_e && strlen(confs.outts2_f) && !confs.joined) {
		foptr = Open_ExportCode(confs.format, confs.outts2_f);
		Comment_ExportCode(foptr, "%s", EXPORT_STR);
		Comment_ExportCode(foptr, "Tileset gray data file");
		Comment_ExportCode(foptr, "");
		if (foptr) {
			WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outts2_v, ImgTilesetOut2, ImgNumTilesetTiles*8);
			if (!confs.quiet) {
				printf("Wrote %d tiles to tileset output gray\n", ImgNumTilesetTiles);
				if (ImgMetaSize != 1) printf("      %d meta-tiles to tileset output gray\n", ImgNumTilesetMetaT);
			}
			exported |= 8;
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.outts2_f);
		Close_ExportCode(foptr);
	}
	if (confs.outm_e && strlen(confs.outm_f) && !confs.joined) {
		foptr = Open_ExportCode(confs.format, confs.outm_f);
		Comment_ExportCode(foptr, "%s", EXPORT_STR);
		Comment_ExportCode(foptr, "Map file");
		Comment_ExportCode(foptr, "");
		if (foptr) {
			WriteArray_ExportCode(foptr, FILE_ECODE_8BITS, confs.outm_v, ImgMap, ImgMaxMapID);
			if (!confs.quiet) printf("Wrote %d entries to map indexes\n", ImgMaxMapID);
			exported |= 16;
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.outm_f);
		Close_ExportCode(foptr);
	}
	if (confs.outh_e && strlen(confs.outh_f)) {
		if (!confs.quiet) printf("Wrote header file\n");
		if (confs.hformat == FILE_ECODE_RAW) {
			confs.hformat = FILE_ECODE_ASM;
			if (confs.format == FILE_ECODE_C) confs.hformat = FILE_ECODE_C;
		}
		fo = fopen(confs.outh_f, "w");
		if (fo) {
			if (confs.hformat == FILE_ECODE_ASM) {
				fprintf(fo, "; %s\n; Header file\n\n", EXPORT_STR);
				if (confs.gfx == GFX_SPRITES) {
					if (exported & 1) fprintf(fo, ".equ " STR_SPRITES " %i\n", confs.out1_v, ImgNumMetaT);
					if (exported & 2) fprintf(fo, ".equ " STR_SPRITES " %i\n", confs.out2_v, ImgNumMetaT);
				} else {
					if (exported & 1) fprintf(fo, ".equ " STR_TILES " %i\n", confs.out1_v, ImgNumTiles);
					if (exported & 1) fprintf(fo, ".equ " STR_MTILES " %i\n", confs.out1_v, ImgNumMetaT);
					if (exported & 2) fprintf(fo, ".equ " STR_TILES " %i\n", confs.out2_v, ImgNumTiles);
					if (exported & 2) fprintf(fo, ".equ " STR_MTILES " %i\n", confs.out2_v, ImgNumMetaT);
					if (exported & 4) fprintf(fo, ".equ " STR_TILES " %i\n", confs.outts1_v, ImgNumTilesetTiles);
					if (exported & 4) fprintf(fo, ".equ " STR_MTILES " %i\n", confs.outts1_v, ImgNumTilesetMetaT);
					if (exported & 8) fprintf(fo, ".equ " STR_TILES " %i\n", confs.outts2_v, ImgNumTilesetTiles);
					if (exported & 8) fprintf(fo, ".equ " STR_MTILES " %i\n", confs.outts2_v, ImgNumTilesetMetaT);
				}
				if (exported & 16) fprintf(fo, ".equ " STR_MAPW " %i\n", confs.outm_v, ImgMapWidth);
				if (exported & 16) fprintf(fo, ".equ " STR_MAPH " %i\n", confs.outm_v, ImgMapHeight);
				if (exported & 16) fprintf(fo, ".equ " STR_MAPSIZE " %i\n", confs.outm_v, ImgMaxMapID);
				fprintf(fo, "\n");
			} else if (confs.hformat == FILE_ECODE_C) {
				fprintf(fo, "// %s\n// Header file\n\n", EXPORT_STR);
				if (confs.gfx == GFX_SPRITES) {
					if (exported & 1) fprintf(fo, "#define " STR_SPRITES " (%i)\n", confs.out1_v, ImgNumMetaT);
				} else {
					if (exported & 1) fprintf(fo, "#define " STR_TILES " (%i)\n", confs.out1_v, ImgNumTiles);
					if (exported & 1) fprintf(fo, "#define " STR_MTILES " (%i)\n", confs.out1_v, ImgNumMetaT);
					if (exported & 2) fprintf(fo, "#define " STR_TILES " (%i)\n", confs.out2_v, ImgNumTiles);
					if (exported & 2) fprintf(fo, "#define " STR_MTILES " (%i)\n", confs.out2_v, ImgNumMetaT);
					if (exported & 4) fprintf(fo, "#define " STR_TILES " (%i)\n", confs.outts1_v, ImgNumTilesetTiles);
					if (exported & 4) fprintf(fo, "#define " STR_MTILES " (%i)\n", confs.outts1_v, ImgNumTilesetMetaT);
					if (exported & 8) fprintf(fo, "#define " STR_TILES " (%i)\n", confs.outts2_v, ImgNumTilesetTiles);
					if (exported & 8) fprintf(fo, "#define " STR_MTILES " (%i)\n", confs.outts2_v, ImgNumTilesetMetaT);
				}
				if (exported & 16) fprintf(fo, "#define " STR_MAPW " (%i)\n", confs.outm_v, ImgMapWidth);
				if (exported & 16) fprintf(fo, "#define " STR_MAPH " (%i)\n", confs.outm_v, ImgMapHeight);
				if (exported & 16) fprintf(fo, "#define " STR_MAPSIZE " (%i)\n", confs.outm_v, ImgMaxMapID);
				fprintf(fo, "\n");
				if (exported & 1) fprintf(fo, "extern unsigned char %s[];\n", confs.out1_v);
				if (exported & 2) fprintf(fo, "extern unsigned char %s[];\n", confs.out2_v);
				if (exported & 4) fprintf(fo, "extern unsigned char %s[];\n", confs.outts1_v);
				if (exported & 8) fprintf(fo, "extern unsigned char %s[];\n", confs.outts2_v);
				if (exported & 16) fprintf(fo, "extern unsigned char %s[];\n", confs.outm_v);
				fprintf(fo, "\n");
			}
		} else fprintf(stderr, "Error: Couldn't write output to '%s'\n", confs.outh_f);
		fclose(fo);
	}

	// Free up resources
	if (ImgOut1) free(ImgOut1);
	if (ImgOut2) free(ImgOut2);
	if (ImgTilesetOut1) free(ImgTilesetOut1);
	if (ImgTilesetOut2) free(ImgTilesetOut2);
	if (ImgMap) free(ImgMap);
	if (ImgAlp) free(ImgAlp);
	if (ImgSrc) free(ImgSrc);

	return 0;
}
