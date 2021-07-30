/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifdef HAVE_LIBPNG
#include <png.h>
#endif
#include "port.h"
#include "crosshairs.h"

static const char	*crosshairs[32] =
{
	"`              "  // Crosshair 0 (no image)
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               ",

	"`              "  // Crosshair 1 (the classic small dot)
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"       #.      "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               "
	"               ",

	"`              "  // Crosshair 2 (a standard cross)
	"               "
	"               "
	"               "
	"      .#.      "
	"      .#.      "
	"    ...#...    "
	"    #######    "
	"    ...#...    "
	"      .#.      "
	"      .#.      "
	"               "
	"               "
	"               "
	"               ",

	"`     .#.      "  // Crosshair 3 (a standard cross)
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	".......#......."
	"###############"
	".......#......."
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      ",

	"`              "  // Crosshair 4 (an X)
	"               "
	"               "
	"    .     .    "
	"   .#.   .#.   "
	"    .#. .#.    "
	"     .#.#.     "
	"      .#.      "
	"     .#.#.     "
	"    .#. .#.    "
	"   .#.   .#.   "
	"    .     .    "
	"               "
	"               "
	"               ",

	"`.           . "  // Crosshair 5 (an X)
	".#.         .#."
	" .#.       .#. "
	"  .#.     .#.  "
	"   .#.   .#.   "
	"    .#. .#.    "
	"     .#.#.     "
	"      .#.      "
	"     .#.#.     "
	"    .#. .#.    "
	"   .#.   .#.   "
	"  .#.     .#.  "
	" .#.       .#. "
	".#.         .#."
	" .           . ",

	"`              "  // Crosshair 6 (a combo)
	"               "
	"               "
	"               "
	"    #  .  #    "
	"     # . #     "
	"      #.#      "
	"    ...#...    "
	"      #.#      "
	"     # . #     "
	"    #  .  #    "
	"               "
	"               "
	"               "
	"               ",

	"`      .       "  // Crosshair 7 (a combo)
	" #     .     # "
	"  #    .    #  "
	"   #   .   #   "
	"    #  .  #    "
	"     # . #     "
	"      #.#      "
	".......#......."
	"      #.#      "
	"     # . #     "
	"    #  .  #    "
	"   #   .   #   "
	"  #    .    #  "
	" #     .     # "
	"       .       ",

	"`      #       "  // Crosshair 8 (a diamond cross)
	"      #.#      "
	"     # . #     "
	"    #  .  #    "
	"   #   .   #   "
	"  #    .    #  "
	" #     .     # "
	"#......#......#"
	" #     .     # "
	"  #    .    #  "
	"   #   .   #   "
	"    #  .  #    "
	"     # . #     "
	"      #.#      "
	"       #       ",

	"`     ###      "  // Crosshair 9 (a circle cross)
	"    ## . ##    "
	"   #   .   #   "
	"  #    .    #  "
	" #     .     # "
	" #     .     # "
	"#      .      #"
	"#......#......#"
	"#      .      #"
	" #     .     # "
	" #     .     # "
	"  #    .    #  "
	"   #   .   #   "
	"    ## . ##    "
	"      ###      ",

	"`     .#.      "  // Crosshair 10 (a square cross)
	"      .#.      "
	"      .#.      "
	"   ....#....   "
	"   .#######.   "
	"   .#     #.   "
	"....#     #...."
	"#####     #####"
	"....#     #...."
	"   .#     #.   "
	"   .#######.   "
	"   ....#....   "
	"      .#.      "
	"      .#.      "
	"      .#.      ",

	"`     .#.      "  // Crosshair 11 (an interrupted cross)
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"               "
	".....     ....."
	"#####     #####"
	".....     ....."
	"               "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      "
	"      .#.      ",

	"`.           . "  // Crosshair 12 (an interrupted X)
	".#.         .#."
	" .#.       .#. "
	"  .#.     .#.  "
	"   .#.   .#.   "
	"               "
	"               "
	"               "
	"               "
	"               "
	"   .#.   .#.   "
	"  .#.     .#.  "
	" .#.       .#. "
	".#.         .#."
	" .           . ",

	"`      .       "  // Crosshair 13 (an interrupted combo)
	" #     .     # "
	"  #    .    #  "
	"   #   .   #   "
	"    #  .  #    "
	"               "
	"               "
	".....     ....."
	"               "
	"               "
	"    #  .  #    "
	"   #   .   #   "
	"  #    .    #  "
	" #     .     # "
	"       .       ",

	"`####     #### "  // Crosshair 14
	"#....     ....#"
	"#.           .#"
	"#.           .#"
	"#.           .#"
	"       #       "
	"       #       "
	"     #####     "
	"       #       "
	"       #       "
	"#.           .#"
	"#.           .#"
	"#.           .#"
	"#....     ....#"
	" ####     #### ",

	"`  .#     #.   "  // Crosshair 15
	"   .#     #.   "
	"   .#     #.   "
	"....#     #...."
	"#####     #####"
	"               "
	"               "
	"               "
	"               "
	"               "
	"#####     #####"
	"....#     #...."
	"   .#     #.   "
	"   .#     #.   "
	"   .#     #.   ",

	"`      #       "  // Crosshair 16
	"       #       "
	"       #       "
	"   ....#....   "
	"   .   #   .   "
	"   .   #   .   "
	"   .   #   .   "
	"###############"
	"   .   #   .   "
	"   .   #   .   "
	"   .   #   .   "
	"   ....#....   "
	"       #       "
	"       #       "
	"       #       ",

	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
};


bool S9xLoadCrosshairFile (int idx, const char *filename)
{
	if (idx < 1 || idx > 31)
		return (false);

	char	*s = (char *) calloc(15 * 15 + 1, sizeof(char));
	if (s == NULL)
	{
		fprintf(stderr, "S9xLoadCrosshairFile: malloc error while reading ");
		perror(filename);
		return (false);
	}

	FILE	*fp = fopen(filename, "rb");
	if (fp == NULL)
	{
		fprintf(stderr, "S9xLoadCrosshairFile: Couldn't open ");
		perror(filename);
		free(s);
		return (false);
	}

	size_t	l = fread(s, 1, 8, fp);
	if (l != 8)
	{
		fprintf(stderr, "S9xLoadCrosshairFile: File is too short!\n");
		free(s);
		fclose(fp);
		return (false);
	}

#ifdef HAVE_LIBPNG
	png_structp	png_ptr;
	png_infop	info_ptr;

	if (!png_sig_cmp((png_byte *) s, 0, 8))
	{
		png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
		if (!png_ptr)
		{
			free(s);
			fclose(fp);
			return (false);
		}

		info_ptr = png_create_info_struct(png_ptr);
		if (!info_ptr)
		{
			png_destroy_read_struct(&png_ptr, (png_infopp) NULL, (png_infopp) NULL);
			free(s);
			fclose(fp);
			return (false);
		}

		png_init_io(png_ptr, fp);
		png_set_sig_bytes(png_ptr, 8);
		png_read_info(png_ptr, info_ptr);

		png_uint_32	width, height;
		int			bit_depth, color_type;

		png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type, NULL, NULL, NULL);
		if (color_type != PNG_COLOR_TYPE_PALETTE)
		{
			fprintf(stderr, "S9xLoadCrosshairFile: Input PNG is not a palettized image!\n");
			png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
			free(s);
			fclose(fp);
			return (false);
		}

		if (bit_depth == 16)
			png_set_strip_16(png_ptr);

		if (width != 15 || height != 15)
		{
			fprintf(stderr, "S9xLoadCrosshairFile: Expecting a 15x15 PNG\n");
			png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
			free(s);
			fclose(fp);
			return (false);
		}

		png_color	*pngpal;
		png_byte	*trans;
		int			num_palette = 0, num_trans = 0;
		int			transcol = -1, fgcol = -1, bgcol = -1;

		png_get_PLTE(png_ptr, info_ptr, &pngpal, &num_palette);
		png_get_tRNS(png_ptr, info_ptr, &trans, &num_trans, NULL);

		if (num_palette != 3 || num_trans != 1)
		{
			fprintf(stderr, "S9xLoadCrosshairFile: Expecting a 3-color PNG with 1 trasnparent color\n");
			png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
			free(s);
			fclose(fp);
			return (false);
		}

		for (int i = 0; i < 3; i++)
		{
			if (trans[0] == i)
				transcol = i;
			else
			if (pngpal[i].red ==   0 && pngpal[i].green ==   0 && pngpal[i].blue ==   0)
				bgcol = i;
			else
			if (pngpal[i].red == 255 && pngpal[i].green == 255 && pngpal[i].blue == 255)
				fgcol = i;
		}

		if (transcol < 0 || fgcol < 0 || bgcol < 0)
		{
			fprintf(stderr, "S9xLoadCrosshairFile: PNG must have 3 colors: white (fg), black (bg), and transparent.\n");
			png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
			free(s);
			fclose(fp);
			return (false);
		}

		png_set_packing(png_ptr);
		png_read_update_info(png_ptr, info_ptr);
		png_byte	*row_pointer = new png_byte[png_get_rowbytes(png_ptr, info_ptr)];

		for (int r = 0; r < 15 * 15; r += 15)
		{
			png_read_row(png_ptr, row_pointer, NULL);

			for (int i = 0; i < 15; i++)
			{
				if (row_pointer[i] == transcol)
					s[r + i] = ' ';
				else
				if (row_pointer[i] == fgcol)
					s[r + i] = '#';
				else
				if (row_pointer[i] == bgcol)
					s[r + i] = '.';
				else
				{
					fprintf(stderr, "S9xLoadCrosshairFile: WTF? This was supposed to be a 3-color PNG!\n");
					png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
					free(s);
					fclose(fp);
					return (false);
				}
			}
		}

		s[15 * 15] = 0;
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp) NULL);
	}
	else
#endif
	{
		l = fread(s + 8, 1, 15 - 8, fp);
		if (l != 15 - 8)
		{
			fprintf(stderr, "S9xLoadCrosshairFile: File is too short!\n");
			free(s);
			fclose(fp);
			return (false);
		}

		if (getc(fp) != '\n')
		{
			fprintf(stderr, "S9xLoadCrosshairFile: Invalid file format! (note: PNG support is not available)\n");
			free(s);
			fclose(fp);
			return (false);
		}

		for (int r = 1; r < 15; r++)
		{
			l = fread(s + r * 15, 1, 15, fp);
			if (l != 15)
			{
				fprintf(stderr, "S9xLoadCrosshairFile: File is too short! (note: PNG support is not available)\n");
				free(s);
				fclose(fp);
				return (false);
			}

			if (getc(fp) != '\n')
			{
				fprintf(stderr, "S9xLoadCrosshairFile: Invalid file format! (note: PNG support is not available)\n");
				free(s);
				fclose(fp);
				return (false);
			}
		}

		for (int i = 0; i < 15 * 15; i++)
		{
			if (s[i] != ' ' && s[i] != '#' && s[i] != '.')
			{
				fprintf(stderr, "S9xLoadCrosshairFile: Invalid file format! (note: PNG support is not available)\n");
				free(s);
				fclose(fp);
				return (false);
			}
		}
	}

	fclose(fp);

	if (crosshairs[idx] != NULL && crosshairs[idx][0] != '`')
		free((void *) crosshairs[idx]);
	crosshairs[idx] = s;

	return (true);
}

const char * S9xGetCrosshair (int idx)
{
	if (idx < 0 || idx > 31)
		return (NULL);

	return (crosshairs[idx]);
}
