/*
 * (C) Gražvydas "notaz" Ignotas, 2008-2011
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <png.h>
#include "readpng.h"
#include "lprintf.h"

int readpng(void *dest, const char *fname, readpng_what what, int req_w, int req_h)
{
	FILE *fp;
	png_structp png_ptr = NULL;
	png_infop info_ptr = NULL;
	png_bytepp row_ptr = NULL;
	int ret = -1;

	if (dest == NULL || fname == NULL)
	{
		return -1;
	}

	fp = fopen(fname, "rb");
	if (fp == NULL)
	{
		lprintf(__FILE__ ": failed to open: %s\n", fname);
		return -1;
	}

	png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!png_ptr)
	{
		lprintf(__FILE__ ": png_create_read_struct() failed\n");
		fclose(fp);
		return -1;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr)
	{
		lprintf(__FILE__ ": png_create_info_struct() failed\n");
		goto done;
	}

	// Start reading
	png_init_io(png_ptr, fp);
	png_read_png(png_ptr, info_ptr, PNG_TRANSFORM_STRIP_16 | PNG_TRANSFORM_STRIP_ALPHA | PNG_TRANSFORM_PACKING, NULL);
	row_ptr = png_get_rows(png_ptr, info_ptr);
	if (row_ptr == NULL)
	{
		lprintf(__FILE__ ": png_get_rows() failed\n");
		goto done;
	}

	// lprintf("%s: %ix%i @ %ibpp\n", fname, (int)png_get_image_width(png_ptr, info_ptr),
	// 	(int)png_get_image_height(png_ptr, info_ptr), png_get_bit_depth(png_ptr, info_ptr));

	switch (what)
	{
		case READPNG_BG:
		{
			int height, width, h, x_ofs = 0, y_ofs = 0;
			unsigned short *dst = dest;

			if (png_get_bit_depth(png_ptr, info_ptr) != 8)
			{
				lprintf(__FILE__ ": bg image uses %ibpc, needed 8bpc\n", png_get_bit_depth(png_ptr, info_ptr));
				break;
			}
			width = png_get_image_width(png_ptr, info_ptr);
			if (width > req_w) {
				x_ofs = (width - req_w) / 2;
				width = req_w;
			}
			height = png_get_image_height(png_ptr, info_ptr);
			if (height > req_h) {
				y_ofs = (height - req_h) / 2;
				height = req_h;
			}

			for (h = 0; h < height; h++)
			{
				unsigned char *src = row_ptr[h + y_ofs] + x_ofs * 3;
				int len = width;
				while (len--)
				{
#ifdef PSP
					*dst++ = ((src[2]&0xf8)<<8) | ((src[1]&0xf8)<<3) | (src[0] >> 3); // BGR
#else
					*dst++ = ((src[0]&0xf8)<<8) | ((src[1]&0xf8)<<3) | (src[2] >> 3); // RGB
#endif
					src += 3;
				}
				dst += req_w - width;
			}
			break;
		}

		case READPNG_FONT:
		{
			int x, y, x1, y1;
			unsigned char *dst = dest;
			if (png_get_image_width(png_ptr, info_ptr) != req_w || png_get_image_height(png_ptr, info_ptr) != req_h)
			{
				lprintf(__FILE__ ": unexpected font image size %dx%d, needed %dx%d\n",
					(int)png_get_image_width(png_ptr, info_ptr), (int)png_get_image_height(png_ptr, info_ptr), req_w, req_h);
				break;
			}
			if (png_get_bit_depth(png_ptr, info_ptr) != 8)
			{
				lprintf(__FILE__ ": font image uses %ibpp, needed 8bpp\n", png_get_bit_depth(png_ptr, info_ptr));
				break;
			}
			for (y = 0; y < 16; y++)
			{
				for (x = 0; x < 16; x++)
				{
					/* 16x16 grid of syms */
					int sym_w = req_w / 16;
					int sym_h = req_h / 16;
					for (y1 = 0; y1 < sym_h; y1++)
					{
						unsigned char *src = row_ptr[y*sym_h + y1] + x*sym_w;
						for (x1 = sym_w/2; x1 > 0; x1--, src+=2)
							*dst++ = ((src[0]^0xff) & 0xf0) | ((src[1]^0xff) >> 4);
					}
				}
			}
			break;
		}

		case READPNG_SELECTOR:
		{
			int x1, y1;
			unsigned char *dst = dest;
			if (png_get_image_width(png_ptr, info_ptr) != req_w || png_get_image_height(png_ptr, info_ptr) != req_h)
			{
				lprintf(__FILE__ ": unexpected selector image size %ix%i, needed %dx%d\n",
					(int)png_get_image_width(png_ptr, info_ptr), (int)png_get_image_height(png_ptr, info_ptr), req_w, req_h);
				break;
			}
			if (png_get_bit_depth(png_ptr, info_ptr) != 8)
			{
				lprintf(__FILE__ ": selector image uses %ibpp, needed 8bpp\n", png_get_bit_depth(png_ptr, info_ptr));
				break;
			}
			for (y1 = 0; y1 < req_h; y1++)
			{
				unsigned char *src = row_ptr[y1];
				for (x1 = req_w/2; x1 > 0; x1--, src+=2)
					*dst++ = ((src[0]^0xff) & 0xf0) | ((src[1]^0xff) >> 4);
			}
			break;
		}

		case READPNG_24:
		{
			int height, width, h;
			unsigned char *dst = dest;
			if (png_get_bit_depth(png_ptr, info_ptr) != 8)
			{
				lprintf(__FILE__ ": image uses %ibpc, needed 8bpc\n", png_get_bit_depth(png_ptr, info_ptr));
				break;
			}
			width = png_get_image_width(png_ptr, info_ptr);
			if (width > req_w)
				width = req_w;
			height = png_get_image_height(png_ptr, info_ptr);
			if (height > req_h)
				height = req_h;

			for (h = 0; h < height; h++)
			{
				int len = width;
				unsigned char *src = row_ptr[h];
				dst += (req_w - width) * 3;
				for (len = width; len > 0; len--, dst+=3, src+=3)
					dst[0] = src[2], dst[1] = src[1], dst[2] = src[0];
			}
			break;
		}
	}


	ret = 0;
done:
	png_destroy_read_struct(&png_ptr, info_ptr ? &info_ptr : NULL, (png_infopp)NULL);
	fclose(fp);
	return ret;
}

int writepng(const char *fname, unsigned short *src, int w, int h)
{
	png_structp png_ptr = NULL;
	png_infop info_ptr = NULL;
	png_bytepp row_pointers;
	int i, j, ret = -1;
	FILE *f;

	f = fopen(fname, "wb");
	if (f == NULL) {
		lprintf(__FILE__ ": failed to open \"%s\"\n", fname);
		return -1;
	}

	row_pointers = calloc(h, sizeof(row_pointers[0]));
	if (row_pointers == NULL)
		goto end1;

	for (i = 0; i < h; i++) {
		unsigned char *dst = malloc(w * 3);
		if (dst == NULL)
			goto end2;
		row_pointers[i] = dst;
		for (j = 0; j < w; j++, src++, dst += 3) {
			dst[0] = (*src & 0xf800) >> 8;
			dst[1] = (*src & 0x07e0) >> 3;
			dst[2] = (*src & 0x001f) << 3;
		}
	}

	/* initialize stuff */
	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png_ptr == NULL) {
		fprintf(stderr, "png_create_write_struct() failed");
		goto end2;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL) {
		fprintf(stderr, "png_create_info_struct() failed");
		goto end3;
	}

	if (setjmp(png_jmpbuf(png_ptr)) != 0) {
		fprintf(stderr, "error in png code\n");
		goto end4;
	}

	png_init_io(png_ptr, f);

	png_set_IHDR(png_ptr, info_ptr, w, h,
		8, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
		PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	png_write_info(png_ptr, info_ptr);
	png_write_image(png_ptr, row_pointers);
	png_write_end(png_ptr, NULL);

	ret = 0;

end4:
//	png_destroy_info_struct(png_ptr, &info_ptr); // freed below
end3:
	png_destroy_write_struct(&png_ptr, &info_ptr);
end2:
	for (i = 0; i < h; i++)
		free(row_pointers[i]);
	free(row_pointers);
end1:
	fclose(f);
	return ret;
}

