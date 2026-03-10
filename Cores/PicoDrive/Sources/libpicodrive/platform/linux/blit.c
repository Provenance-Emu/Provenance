/*
 * PicoDrive
 * (C) notaz, 2006,2009
 * (C) irixxxx, 2022
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>

// Convert 0000bbb0 ggg0rrr0 0000bbb0 ggg0rrr0
// to      00000000 rrr00000 ggg00000 bbb00000 ...
// TODO: rm when gp2x/emu.c is no longer used

void bgr444_to_rgb32(void *to, void *from, unsigned entries)
{
	unsigned short *ps = from;
	unsigned int   *pd = to;
	int pixels;

	for (pixels = entries; pixels; pixels--, ps++, pd++)
	{
		*pd = ((*ps<<20)&0xe00000) | ((*ps<<8)&0xe000) | ((*ps>>4)&0xe0);
		*pd |= *pd >> 3;
	}
}

void bgr444_to_rgb32_sh(void *to, void *from)
{
	unsigned short *ps = from;
	unsigned int   *pd = to;
	int pixels;

	pd += 0x40;
	for (pixels = 0x40; pixels; pixels--, ps++, pd++)
	{
		*pd = ((*ps<<20)&0xe00000) | ((*ps<<8)&0xe000) | ((*ps>>4)&0xe0);
		*pd >>= 1;
		*pd |= *pd >> 3;
		pd[0x40*2] = *pd;
	}

	ps -= 0x40;
	for (pixels = 0x40; pixels; pixels--, ps++, pd++)
	{
		*pd = ((*ps<<20)&0xe00000) | ((*ps<<8)&0xe000) | ((*ps>>4)&0xe0);
		continue;
		*pd += 0x00404040;
		if (*pd & 0x01000000) *pd |= 0x00e00000;
		if (*pd & 0x00010000) *pd |= 0x0000e000;
		if (*pd & 0x00000100) *pd |= 0x000000e0;
		*pd &= 0x00e0e0e0;
		*pd |= *pd >> 3;
	}
}

#define X (x_y >> 16)
#define Y (x_y & 0xffff)
#define W (w_h >> 16)
#define H (w_h & 0xffff)

// gp2x:   0-> X    wiz: Y <-0
//         |                 |
//         v                 v
//
//         Y                 X

void vidcpy_8bit(void *dest, void *src, int x_y, int w_h)
{
	unsigned char *pd = dest, *ps = src;
	int i;

	pd += X + Y*320;
	ps += X + Y*328 + 8;
	for (i = 0; i < H; i++) {
		memcpy(pd, ps, W);
		ps += 328; pd += 320;
	}
}

void vidcpy_8bit_rot(void *dest, void *src, int x_y, int w_h)
{
	unsigned char *pd = dest, *ps = src;
	int i, u;

	pd += Y + (319-X)*240;
	ps += X + Y*328 + 8;
	for (i = 0; i < H; i += 4) {
		unsigned char *p = (void *)ps;
		unsigned int  *q = (void *)pd;
		for (u = 0; u < W; u++) {
			*q = (p[3*328]<<24) + (p[2*328]<<16) + (p[1*328]<<8) + p[0*328];
			p += 1;
			q -= 240/4;
		}
		ps += 4*328; pd += 4;
	}
}

void rotated_blit8 (void *dst, void *linesx4, int y, int is_32col)
{
	unsigned char *pd = dst, *ps = linesx4;
	int x, w, u;

	x = (is_32col ? 32 : 0);
	w = (is_32col ? 256 : 320);
	y -= 4;

	pd += y + (319-x)*240;
	ps += x;

	unsigned char *p = (void *)ps;
	unsigned int  *q = (void *)pd;
	for (u = 0; u < w; u++) {
		*q = (p[3*328]<<24) + (p[2*328]<<16) + (p[1*328]<<8) + p[0*328];
		p += 1;
		q -= 240/4;
	}
}

void rotated_blit16(void *dst, void *linesx4, int y, int is_32col)
{
	unsigned short *pd = dst, *ps = linesx4;
	int x, w, u;

	x = (is_32col ? 32 : 0);
	w = (is_32col ? 256 : 320);
	y -= 4;

	pd += y + (319-x)*240;
	ps += x;

	unsigned short *p = (void *)ps;
	unsigned int   *q = (void *)pd;
	for (u = 0; u < w; u++) {
		q[0] = (p[1*328]<<16) + p[0*328];
		q[1] = (p[3*328]<<16) + p[2*328];
		p += 1;
		q -= 2*240/4;
	}
}
