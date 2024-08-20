/*
 * Texture Filtering
 * Version:  1.0
 *
 * Copyright (C) 2007  Hiroshi Morii   All Rights Reserved.
 * Email koolsmoky(at)users.sourceforge.net
 * Web   http://www.3dfxzone.it/koolsmoky
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * this is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Make; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

/* use power of 2 texture size
 * (0:disable, 1:enable, 2:3dfx) */
#define POW2_TEXTURES 0

/* check 8 bytes. use a larger value if needed. */
#define PNG_CHK_BYTES 8

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "TxImage.h"
#include "TxReSample.h"
#include "TxDbg.h"

boolean
TxImage::getPNGInfo(FILE *fp, png_structp *png_ptr, png_infop *info_ptr)
{
	unsigned char sig[PNG_CHK_BYTES];

	/* check for valid file pointer */
	if (!fp)
		return 0;

	/* check if file is PNG */
	if (fread(sig, 1, PNG_CHK_BYTES, fp) != PNG_CHK_BYTES)
		return 0;

	if (png_sig_cmp(sig, 0, PNG_CHK_BYTES) != 0)
		return 0;

	/* get PNG file info */
	*png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
	if (!*png_ptr)
		return 0;

	*info_ptr = png_create_info_struct(*png_ptr);
	if (!*info_ptr) {
		png_destroy_read_struct(png_ptr, nullptr, nullptr);
		return 0;
	}

	if (setjmp(png_jmpbuf(*png_ptr))) {
		DBG_INFO(80, wst("error reading png!\n"));
		png_destroy_read_struct(png_ptr, info_ptr, nullptr);
		return 0;
	}

	png_init_io(*png_ptr, fp);
	png_set_sig_bytes(*png_ptr, PNG_CHK_BYTES);
	png_read_info(*png_ptr, *info_ptr);

	return 1;
}

uint8*
TxImage::readPNG(FILE* fp, int* width, int* height, ColorFormat *format)
{
	/* NOTE: returned image format is GR_TEXFMT_ARGB_8888 */

	png_structp png_ptr;
	png_infop info_ptr;
	uint8 *image = nullptr;
	int bit_depth, color_type, interlace_type, compression_type, filter_type,
			row_bytes, o_width, o_height, num_pas;

	/* initialize */
	*width  = 0;
	*height = 0;
	*format = graphics::internalcolorFormat::NOCOLOR;

	/* check if we have a valid png file */
	if (!fp)
		return nullptr;

	if (!getPNGInfo(fp, &png_ptr, &info_ptr)) {
		INFO(80, wst("error reading png file! png image is corrupt.\n"));
		return nullptr;
	}

	png_get_IHDR(png_ptr, info_ptr,
				 (png_uint_32*)&o_width, (png_uint_32*)&o_height, &bit_depth, &color_type,
				 &interlace_type, &compression_type, &filter_type);

	DBG_INFO(80, wst("png format %d x %d bitdepth:%d color:%x interlace:%x compression:%x filter:%x\n"),
			 o_width, o_height, bit_depth, color_type,
			 interlace_type, compression_type, filter_type);

	/* transformations */

	/* Rice hi-res textures
   * _all.png
   * _rgb.png, _a.png
   * _ciByRGBA.png
   * _allciByRGBA.png
   */

	/* strip if color channel is larger than 8 bits */
	if (bit_depth > 8) {
		png_set_strip_16(png_ptr);
		bit_depth = 8;
	}

#if 1
	/* These are not really required per Rice format spec,
   * but is done just in case someone uses them.
   */
	/* convert palette color to rgb color */
	if (color_type == PNG_COLOR_TYPE_PALETTE) {
		png_set_palette_to_rgb(png_ptr);
		color_type = PNG_COLOR_TYPE_RGB;
	}

	/* expand 1,2,4 bit gray scale to 8 bit gray scale */
	if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
		png_set_expand_gray_1_2_4_to_8(png_ptr);

	/* convert gray scale or gray scale + alpha to rgb color */
	if (color_type == PNG_COLOR_TYPE_GRAY ||
			color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
		png_set_gray_to_rgb(png_ptr);
		color_type = PNG_COLOR_TYPE_RGB;
	}
#endif

	/* add alpha channel if any */
	if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS)) {
		png_set_tRNS_to_alpha(png_ptr);
		color_type = PNG_COLOR_TYPE_RGB_ALPHA;
	}

	/* convert rgb to rgba */
	if (color_type == PNG_COLOR_TYPE_RGB) {
		png_set_filler(png_ptr, 0xff, PNG_FILLER_AFTER);
		color_type = PNG_COLOR_TYPE_RGB_ALPHA;
	}

	/* punt invalid formats */
	if (color_type != PNG_COLOR_TYPE_RGB_ALPHA) {
		png_destroy_read_struct(&png_ptr, &info_ptr, nullptr);
		DBG_INFO(80, wst("Error: not PNG_COLOR_TYPE_RGB_ALPHA format!\n"));
		return nullptr;
	}

	/*png_color_8p sig_bit;
  if (png_get_sBIT(png_ptr, info_ptr, &sig_bit))
	png_set_shift(png_ptr, sig_bit);*/

	/* convert rgba to bgra */
	//png_set_bgr(png_ptr); // OpenGL does not need it

	/* turn on interlace handling to cope with the weirdness
   * of texture authors using interlaced format */
	num_pas = png_set_interlace_handling(png_ptr);

	/* update info structure */
	png_read_update_info(png_ptr, info_ptr);

	/* we only get here if RGBA8888 */
	row_bytes = png_get_rowbytes(png_ptr, info_ptr);

	/* allocate memory to read in image */
	image = (uint8*)malloc(row_bytes * o_height);

	/* read in image */
	if (image) {
		int pas, i;
		uint8* tmpimage;

		for (pas = 0; pas < num_pas; pas++) { /* deal with interlacing */
			tmpimage = image;

			for (i = 0; i < o_height; i++) {
				/* copy row */
				png_read_rows(png_ptr, &tmpimage, nullptr, 1);
				tmpimage += row_bytes;
			}
		}

		/* read rest of the info structure */
		png_read_end(png_ptr, info_ptr);

		*width = (row_bytes >> 2);
		*height = o_height;
		*format = graphics::internalcolorFormat::RGBA8;

#if POW2_TEXTURES
		/* next power of 2 size conversions */
		/* NOTE: I can do this in the above loop for faster operations, but some
	 * texture packs require a workaround. see HACKALERT in nextPow2().
	 */

		TxReSample txReSample = new TxReSample; // XXX: temporary. move to a better place.

#if (POW2_TEXTURES == 2)
		if (!txReSample->nextPow2(&image, width, height, 32, 1)) {
#else
		if (!txReSample->nextPow2(&image, width, height, 32, 0)) {
#endif
			if (image) {
				free(image);
				image = nullptr;
			}
			*width = 0;
			*height = 0;
			*format = graphics::internalcolorFormat::NOCOLOR;
		}

		delete txReSample;

#endif /* POW2_TEXTURES */
	}

	/* clean up */
	png_destroy_read_struct(&png_ptr, &info_ptr, nullptr);

#ifdef DEBUG
	if (!image) {
		DBG_INFO(80, wst("Error: failed to load png image!\n"));
	}
#endif

	return image;
}

boolean
TxImage::writePNG(uint8* src, FILE* fp, int width, int height, int rowStride, ColorFormat format)
{
	assert(format == graphics::internalcolorFormat::RGBA8);
	png_structp png_ptr = nullptr;
	png_infop info_ptr = nullptr;
	png_color_8 sig_bit;
	int bit_depth = 0, color_type = 0, row_bytes = 0;
	int i = 0;

	if (!src || !fp)
		return 0;

	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
	if (png_ptr == nullptr)
		return 0;

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == nullptr) {
		png_destroy_write_struct(&png_ptr, nullptr);
		return 0;
	}

	if (setjmp(png_jmpbuf(png_ptr))) {
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return 0;
	}

	png_init_io(png_ptr, fp);

	bit_depth = 8;
	sig_bit.red   = 8;
	sig_bit.green = 8;
	sig_bit.blue  = 8;
	sig_bit.alpha = 8;
	color_type = PNG_COLOR_TYPE_RGB_ALPHA;

	//row_bytes = (bit_depth * width) >> 1;
	row_bytes = rowStride;
	//png_set_bgr(png_ptr); // OpenGL does not need it
	png_set_sBIT(png_ptr, info_ptr, &sig_bit);

	png_set_IHDR(png_ptr, info_ptr, width, height,
				 bit_depth, color_type, PNG_INTERLACE_NONE,
				 PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	png_write_info(png_ptr, info_ptr);
	for (i = 0; i < height; i++) {
		png_write_row(png_ptr, (png_bytep)src);
		src += row_bytes;
	}
	png_write_end(png_ptr, info_ptr);

	png_destroy_write_struct(&png_ptr, &info_ptr);

	return 1;
}

boolean
TxImage::getBMPInfo(FILE* fp, BITMAPFILEHEADER* bmp_fhdr, BITMAPINFOHEADER* bmp_ihdr)
{
	/*
   * read in BITMAPFILEHEADER
   */

	/* is this a BMP file? */
	if (fread(&bmp_fhdr->bfType, 2, 1, fp) != 1)
		return 0;

	if (memcmp(&bmp_fhdr->bfType, "BM", 2) != 0)
		return 0;

	/* get file size */
	if (fread(&bmp_fhdr->bfSize, 4, 1, fp) != 1)
		return 0;

	/* reserved 1 */
	if (fread(&bmp_fhdr->bfReserved1, 2, 1, fp) != 1)
		return 0;

	/* reserved 2 */
	if (fread(&bmp_fhdr->bfReserved2, 2, 1, fp) != 1)
		return 0;

	/* offset to the image data */
	if (fread(&bmp_fhdr->bfOffBits, 4, 1, fp) != 1)
		return 0;

	/*
   * read in BITMAPINFOHEADER
   */

	/* size of BITMAPINFOHEADER */
	if (fread(&bmp_ihdr->biSize, 4, 1, fp) != 1)
		return 0;

	/* is this a Windows BMP? */
	if (bmp_ihdr->biSize != 40)
		return 0;

	/* width of the bitmap in pixels */
	if (fread(&bmp_ihdr->biWidth, 4, 1, fp) != 1)
		return 0;

	/* height of the bitmap in pixels */
	if (fread(&bmp_ihdr->biHeight, 4, 1, fp) != 1)
		return 0;

	/* number of planes (always 1) */
	if (fread(&bmp_ihdr->biPlanes, 2, 1, fp) != 1)
		return 0;

	/* number of bits-per-pixel. (1, 4, 8, 16, 24, 32) */
	if (fread(&bmp_ihdr->biBitCount, 2, 1, fp) != 1)
		return 0;

	/* compression for a compressed bottom-up bitmap
   *   0 : uncompressed format
   *   1 : run-length encoded 4 bpp format
   *   2 : run-length encoded 8 bpp format
   *   3 : bitfield
   */
	if (fread(&bmp_ihdr->biCompression, 4, 1, fp) != 1)
		return 0;

	/* size of the image in bytes */
	if (fread(&bmp_ihdr->biSizeImage, 4, 1, fp) != 1)
		return 0;

	/* horizontal resolution in pixels-per-meter */
	if (fread(&bmp_ihdr->biXPelsPerMeter, 4, 1, fp) != 1)
		return 0;

	/* vertical resolution in pixels-per-meter */
	if (fread(&bmp_ihdr->biYPelsPerMeter, 4, 1, fp) != 1)
		return 0;

	/* number of color indexes in the color table that are actually used */
	if (fread(&bmp_ihdr->biClrUsed, 4, 1, fp) != 1)
		return 0;

	/*  the number of color indexes that are required for displaying */
	if (fread(&bmp_ihdr->biClrImportant, 4, 1, fp) != 1)
		return 0;

	return 1;
}

uint8*
TxImage::readBMP(FILE* fp, int* width, int* height, ColorFormat *format)
{
	/* NOTE: returned image format;
   *       4, 8bit palette bmp -> COLOR_INDEX8
   *       24, 32bit bmp -> RGBA8
   */

	uint8 *image = nullptr;
	uint8 *image_row = nullptr;
	uint8 *tmpimage = nullptr;
	int row_bytes, pos, i, j;
	/* Windows Bitmap */
	BITMAPFILEHEADER bmp_fhdr;
	BITMAPINFOHEADER bmp_ihdr;

	/* initialize */
	*width  = 0;
	*height = 0;
	*format = graphics::internalcolorFormat::NOCOLOR;

	/* check if we have a valid bmp file */
	if (!fp)
		return nullptr;

	if (!getBMPInfo(fp, &bmp_fhdr, &bmp_ihdr)) {
		INFO(80, wst("error reading bitmap file! bitmap image is corrupt.\n"));
		return nullptr;
	}

	DBG_INFO(80, wst("bmp format %d x %d bitdepth:%d compression:%x offset:%d\n"),
			 bmp_ihdr.biWidth, bmp_ihdr.biHeight, bmp_ihdr.biBitCount,
			 bmp_ihdr.biCompression, bmp_fhdr.bfOffBits);

	/* rowStride in bytes */
	row_bytes = (bmp_ihdr.biWidth * bmp_ihdr.biBitCount) >> 3;
	/* align to 4bytes boundary */
	row_bytes = (row_bytes + 3) & ~3;

	/* Rice hi-res textures */
	if (!(bmp_ihdr.biBitCount == 8 || bmp_ihdr.biBitCount == 4 || bmp_ihdr.biBitCount == 32 || bmp_ihdr.biBitCount == 24) ||
			bmp_ihdr.biCompression != 0) {
		DBG_INFO(80, wst("Error: incompatible bitmap format!\n"));
		return nullptr;
	}

	switch (bmp_ihdr.biBitCount) {
	case 8:
	case 32:
		/* 8 bit, 32 bit bitmap */
		image = (uint8*)malloc(row_bytes * bmp_ihdr.biHeight);
		if (image) {
			tmpimage = image;
			pos = bmp_fhdr.bfOffBits + row_bytes * (bmp_ihdr.biHeight - 1);
			for (i = 0; i < bmp_ihdr.biHeight; i++) {
				/* read in image */
				fseek(fp, pos, SEEK_SET);
				fread(tmpimage, row_bytes, 1, fp);
				tmpimage += row_bytes;
				pos -= row_bytes;
			}
		}
	break;
	case 4:
		/* 4bit bitmap */
		image = (uint8*)malloc((row_bytes * bmp_ihdr.biHeight) << 1);
		image_row = (uint8*)malloc(row_bytes);
		if (image && image_row) {
			tmpimage = image;
			pos = bmp_fhdr.bfOffBits + row_bytes * (bmp_ihdr.biHeight - 1);
			for (i = 0; i < bmp_ihdr.biHeight; i++) {
				/* read in image */
				fseek(fp, pos, SEEK_SET);
				fread(image_row, row_bytes, 1, fp);
				/* expand 4bpp to 8bpp. stuff 4bit values into 8bit comps. */
				for (j = 0; j < row_bytes; j++) {
					tmpimage[j << 1] = image_row[j] & 0x0f;
					tmpimage[(j << 1) + 1] = (image_row[j] & 0xf0) >> 4;
				}
				tmpimage += (row_bytes << 1);
				pos -= row_bytes;
			}
			free(image_row);
		} else {
			if (image_row) free(image_row);
			if (image) free(image);
			image = nullptr;
		}
	break;
	case 24:
		/* 24 bit bitmap */
		image = (uint8*)malloc((bmp_ihdr.biWidth * bmp_ihdr.biHeight) << 2);
		image_row = (uint8*)malloc(row_bytes);
		if (image && image_row) {
			tmpimage = image;
			pos = bmp_fhdr.bfOffBits + row_bytes * (bmp_ihdr.biHeight - 1);
			for (i = 0; i < bmp_ihdr.biHeight; i++) {
				/* read in image */
				fseek(fp, pos, SEEK_SET);
				fread(image_row, row_bytes, 1, fp);
				/* convert 24bpp to 32bpp. */
				for (j = 0; j < bmp_ihdr.biWidth; j++) {
					tmpimage[(j << 2)]     = image_row[j * 3];
					tmpimage[(j << 2) + 1] = image_row[j * 3 + 1];
					tmpimage[(j << 2) + 2] = image_row[j * 3 + 2];
					tmpimage[(j << 2) + 3] = 0xFF;
				}
				tmpimage += (bmp_ihdr.biWidth << 2);
				pos -= row_bytes;
			}
			free(image_row);
		} else {
			if (image_row) free(image_row);
			if (image) free(image);
			image = nullptr;
		}
	}

	if (image) {
		*width = (row_bytes << 3) / bmp_ihdr.biBitCount;
		*height = bmp_ihdr.biHeight;

		switch (bmp_ihdr.biBitCount) {
		case 8:
		case 4:
			*format = graphics::internalcolorFormat::COLOR_INDEX8;
		break;
		case 32:
		case 24:
			*format = graphics::internalcolorFormat::RGBA8;
		}

#if POW2_TEXTURES
		/* next power of 2 size conversions */
		/* NOTE: I can do this in the above loop for faster operations, but some
	 * texture packs require a workaround. see HACKALERT in nextPow2().
	 */

		TxReSample txReSample = new TxReSample; // XXX: temporary. move to a better place.

#if (POW2_TEXTURES == 2)
		if (!txReSample->nextPow2(&image, width, height, 8, 1)) {
#else
		if (!txReSample->nextPow2(&image, width, height, 8, 0)) {
#endif
			if (image) {
				free(image);
				image = nullptr;
			}
			*width = 0;
			*height = 0;
			*format = graphics::internalcolorFormat::NOCOLOR;
		}

		delete txReSample;

#endif /* POW2_TEXTURES */
	}

#ifdef DEBUG
	if (!image) {
		DBG_INFO(80, wst("Error: failed to load bmp image!\n"));
	}
#endif

	return image;
}

boolean
TxImage::getDDSInfo(FILE *fp, DDSFILEHEADER *dds_fhdr)
{
	/*
   * read in DDSFILEHEADER
   */

	/* is this a DDS file? */
	if (fread(&dds_fhdr->dwMagic, 4, 1, fp) != 1)
		return 0;

	if (memcmp(&dds_fhdr->dwMagic, "DDS ", 4) != 0)
		return 0;

	if (fread(&dds_fhdr->dwSize, 4, 1, fp) != 1)
		return 0;

	/* get file flags */
	if (fread(&dds_fhdr->dwFlags, 4, 1, fp) != 1)
		return 0;

	/* height of dds in pixels */
	if (fread(&dds_fhdr->dwHeight, 4, 1, fp) != 1)
		return 0;

	/* width of dds in pixels */
	if (fread(&dds_fhdr->dwWidth, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwLinearSize, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwDepth, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwMipMapCount, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwReserved1, 4 * 11, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwSize, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwFlags, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwFourCC, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwRGBBitCount, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwRBitMask, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwGBitMask, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwBBitMask, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->ddpf.dwRGBAlphaBitMask, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwCaps1, 4, 1, fp) != 1)
		return 0;

	if (fread(&dds_fhdr->dwCaps2, 4, 1, fp) != 1)
		return 0;

	return 1;
}
