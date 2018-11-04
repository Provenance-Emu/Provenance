/*
 * tile renderer
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"

#define START_ROW  0 // which row of tiles to start rendering at?
#define END_ROW   28 // ..end

#define TILE_ROWS END_ROW-START_ROW

// note: this is not implemented in ARM asm
#if defined(DRAW2_OVERRIDE_LINE_WIDTH)
#define LINE_WIDTH DRAW2_OVERRIDE_LINE_WIDTH
#else
#define LINE_WIDTH 328
#endif

static unsigned char PicoDraw2FB_[(8+320) * (8+240+8)];
unsigned char *PicoDraw2FB = PicoDraw2FB_;

static int HighCache2A[41*(TILE_ROWS+1)+1+1]; // caches for high layers
static int HighCache2B[41*(TILE_ROWS+1)+1+1];

unsigned short *PicoCramHigh=Pico.cram; // pointer to CRAM buff (0x40 shorts), converted to native device color (works only with 16bit for now)
void (*PicoPrepareCram)()=0;            // prepares PicoCramHigh for renderer to use


// stuff available in asm:
#ifdef _ASM_DRAW_C
void BackFillFull(int reg7);
void DrawLayerFull(int plane, int *hcache, int planestart, int planeend);
void DrawTilesFromCacheF(int *hc);
void DrawWindowFull(int start, int end, int prio);
void DrawSpriteFull(unsigned int *sprite);
#else


static int TileXnormYnorm(unsigned char *pd,int addr,unsigned char pal)
{
	unsigned int pack=0; unsigned int t=0, blank = 1;
	int i;

	for(i=8; i; i--, addr+=2, pd += LINE_WIDTH) {
		pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
		if(!pack) continue;

		t=pack&0x0000f000; if (t) pd[0]=(unsigned char)((t>>12)|pal);
		t=pack&0x00000f00; if (t) pd[1]=(unsigned char)((t>> 8)|pal);
		t=pack&0x000000f0; if (t) pd[2]=(unsigned char)((t>> 4)|pal);
		t=pack&0x0000000f; if (t) pd[3]=(unsigned char)((t    )|pal);
		t=pack&0xf0000000; if (t) pd[4]=(unsigned char)((t>>28)|pal);
		t=pack&0x0f000000; if (t) pd[5]=(unsigned char)((t>>24)|pal);
		t=pack&0x00f00000; if (t) pd[6]=(unsigned char)((t>>20)|pal);
		t=pack&0x000f0000; if (t) pd[7]=(unsigned char)((t>>16)|pal);
		blank = 0;
	}

	return blank; // Tile blank?
}

static int TileXflipYnorm(unsigned char *pd,int addr,unsigned char pal)
{
	unsigned int pack=0; unsigned int t=0, blank = 1;
	int i;

	for(i=8; i; i--, addr+=2, pd += LINE_WIDTH) {
		pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
		if(!pack) continue;

		t=pack&0x000f0000; if (t) pd[0]=(unsigned char)((t>>16)|pal);
		t=pack&0x00f00000; if (t) pd[1]=(unsigned char)((t>>20)|pal);
		t=pack&0x0f000000; if (t) pd[2]=(unsigned char)((t>>24)|pal);
		t=pack&0xf0000000; if (t) pd[3]=(unsigned char)((t>>28)|pal);
		t=pack&0x0000000f; if (t) pd[4]=(unsigned char)((t    )|pal);
		t=pack&0x000000f0; if (t) pd[5]=(unsigned char)((t>> 4)|pal);
		t=pack&0x00000f00; if (t) pd[6]=(unsigned char)((t>> 8)|pal);
		t=pack&0x0000f000; if (t) pd[7]=(unsigned char)((t>>12)|pal);
		blank = 0;
	}
	return blank; // Tile blank?
}

static int TileXnormYflip(unsigned char *pd,int addr,unsigned char pal)
{
	unsigned int pack=0; unsigned int t=0, blank = 1;
	int i;

	addr+=14;
	for(i=8; i; i--, addr-=2, pd += LINE_WIDTH) {
		pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
		if(!pack) continue;

		t=pack&0x0000f000; if (t) pd[0]=(unsigned char)((t>>12)|pal);
		t=pack&0x00000f00; if (t) pd[1]=(unsigned char)((t>> 8)|pal);
		t=pack&0x000000f0; if (t) pd[2]=(unsigned char)((t>> 4)|pal);
		t=pack&0x0000000f; if (t) pd[3]=(unsigned char)((t    )|pal);
		t=pack&0xf0000000; if (t) pd[4]=(unsigned char)((t>>28)|pal);
		t=pack&0x0f000000; if (t) pd[5]=(unsigned char)((t>>24)|pal);
		t=pack&0x00f00000; if (t) pd[6]=(unsigned char)((t>>20)|pal);
		t=pack&0x000f0000; if (t) pd[7]=(unsigned char)((t>>16)|pal);
		blank = 0;
	}

	return blank; // Tile blank?
}

static int TileXflipYflip(unsigned char *pd,int addr,unsigned char pal)
{
	unsigned int pack=0; unsigned int t=0, blank = 1;
	int i;

	addr+=14;
	for(i=8; i; i--, addr-=2, pd += LINE_WIDTH) {
		pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
		if(!pack) continue;

		t=pack&0x000f0000; if (t) pd[0]=(unsigned char)((t>>16)|pal);
		t=pack&0x00f00000; if (t) pd[1]=(unsigned char)((t>>20)|pal);
		t=pack&0x0f000000; if (t) pd[2]=(unsigned char)((t>>24)|pal);
		t=pack&0xf0000000; if (t) pd[3]=(unsigned char)((t>>28)|pal);
		t=pack&0x0000000f; if (t) pd[4]=(unsigned char)((t    )|pal);
		t=pack&0x000000f0; if (t) pd[5]=(unsigned char)((t>> 4)|pal);
		t=pack&0x00000f00; if (t) pd[6]=(unsigned char)((t>> 8)|pal);
		t=pack&0x0000f000; if (t) pd[7]=(unsigned char)((t>>12)|pal);
		blank = 0;
	}
	return blank; // Tile blank?
}


// start: (tile_start<<16)|row_start, end: [same]
static void DrawWindowFull(int start, int end, int prio)
{
	struct PicoVideo *pvid=&Pico.video;
	int nametab, nametab_step, trow, tilex, blank=-1, code;
	unsigned char *scrpos = PicoDraw2FB;
	int tile_start, tile_end; // in cells

	// parse ranges
	tile_start = start>>16;
	tile_end = end>>16;
	start = start<<16>>16;
	end = end<<16>>16;

	// Find name table line:
	if (pvid->reg[12]&1)
	{
		nametab=(pvid->reg[3]&0x3c)<<9; // 40-cell mode
		nametab_step = 1<<6;
	}
	else
	{
		nametab=(pvid->reg[3]&0x3e)<<9; // 32-cell mode
		nametab_step = 1<<5;
	}
	nametab += nametab_step*start;

	// check priority
	code=Pico.vram[nametab+tile_start];
	if ((code>>15) != prio) return; // hack: just assume that whole window uses same priority

	scrpos+=8*LINE_WIDTH+8;
	scrpos+=8*LINE_WIDTH*(start-START_ROW);

	// do a window until we reach planestart row
	for(trow = start; trow < end; trow++, nametab+=nametab_step) { // current tile row
		for (tilex=tile_start; tilex<tile_end; tilex++)
		{
			int code,addr,zero=0;
//			unsigned short *pal=NULL;
			unsigned char pal;

			code=Pico.vram[nametab+tilex];
			if (code==blank) continue;

			// Get tile address/2:
			addr=(code&0x7ff)<<4;

//			pal=PicoCramHigh+((code>>9)&0x30);
			pal=(unsigned char)((code>>9)&0x30);

			switch((code>>11)&3) {
				case 0: zero=TileXnormYnorm(scrpos+(tilex<<3),addr,pal); break;
				case 1: zero=TileXflipYnorm(scrpos+(tilex<<3),addr,pal); break;
				case 2: zero=TileXnormYflip(scrpos+(tilex<<3),addr,pal); break;
				case 3: zero=TileXflipYflip(scrpos+(tilex<<3),addr,pal); break;
			}
			if(zero) blank=code; // We know this tile is blank now
		}

		scrpos += LINE_WIDTH*8;
	}
}


static void DrawLayerFull(int plane, int *hcache, int planestart, int planeend)
{
	struct PicoVideo *pvid=&Pico.video;
	static char shift[4]={5,6,6,7}; // 32,64 or 128 sized tilemaps
	int width, height, ymask, htab;
	int nametab, hscroll=0, vscroll, cells;
	unsigned char *scrpos;
	int blank=-1, xmask, nametab_row, trow;

	// parse ranges
	cells = (planeend>>16)-(planestart>>16);
	planestart = planestart<<16>>16;
	planeend = planeend<<16>>16;

	// Work out the Tiles to draw

	htab=pvid->reg[13]<<9; // Horizontal scroll table address
//	if ( pvid->reg[11]&2)     htab+=Scanline<<1; // Offset by line
//	if ((pvid->reg[11]&1)==0) htab&=~0xf; // Offset by tile
	htab+=plane; // A or B

	if(!(pvid->reg[11]&3)) { // full screen scroll
		// Get horizontal scroll value
		hscroll=Pico.vram[htab&0x7fff];
		htab = 0; // this marks that we don't have to update scroll value
	}

	// Work out the name table size: 32 64 or 128 tiles (0-3)
	width=pvid->reg[16];
	height=(width>>4)&3; width&=3;

	xmask=(1<<shift[width ])-1; // X Mask in tiles
	ymask=(height<<5)|0x1f;     // Y Mask in tiles
	if(width == 1)   ymask&=0x3f;
	else if(width>1) ymask =0x1f;

	// Find name table:
	if (plane==0) nametab=(pvid->reg[2]&0x38)<< 9; // A
	else          nametab=(pvid->reg[4]&0x07)<<12; // B

	scrpos = PicoDraw2FB;
	scrpos+=8*LINE_WIDTH*(planestart-START_ROW);

	// Get vertical scroll value:
	vscroll=Pico.vsram[plane]&0x1ff;
	scrpos+=(8-(vscroll&7))*LINE_WIDTH;
	if(vscroll&7) planeend++; // we have vertically clipped tiles due to vscroll, so we need 1 more row

	*hcache++ = 8-(vscroll&7); // push y-offset to tilecache


	for(trow = planestart; trow < planeend; trow++) { // current tile row
		int cellc=cells,tilex,dx;

		// Find the tile row in the name table
		//ts.line=(vscroll+Scanline)&ymask;
		//ts.nametab+=(ts.line>>3)<<shift[width];
		nametab_row = nametab + (((trow+(vscroll>>3))&ymask)<<shift[width]); // pointer to nametable entries for this row

		// update hscroll if needed
		if(htab) {
			int htaddr=htab+(trow<<4);
			if(trow) htaddr-=(vscroll&7)<<1;
			hscroll=Pico.vram[htaddr&0x7fff];
		}

		// Draw tiles across screen:
		tilex=(-hscroll)>>3;
		dx=((hscroll-1)&7)+1;
		if(dx != 8) cellc++; // have hscroll, do more cells

		for (; cellc; dx+=8,tilex++,cellc--)
		{
			int code=0,addr=0,zero=0;
//			unsigned short *pal=NULL;
			unsigned char pal;

			code=Pico.vram[nametab_row+(tilex&xmask)];
			if (code==blank) continue;

			if (code>>15) { // high priority tile
				*hcache++ = code|(dx<<16)|(trow<<27); // cache it
				continue;
			}

			// Get tile address/2:
			addr=(code&0x7ff)<<4;

//			pal=PicoCramHigh+((code>>9)&0x30);
			pal=(unsigned char)((code>>9)&0x30);

			switch((code>>11)&3) {
				case 0: zero=TileXnormYnorm(scrpos+dx,addr,pal); break;
				case 1: zero=TileXflipYnorm(scrpos+dx,addr,pal); break;
				case 2: zero=TileXnormYflip(scrpos+dx,addr,pal); break;
				case 3: zero=TileXflipYflip(scrpos+dx,addr,pal); break;
			}
			if(zero) blank=code; // We know this tile is blank now
		}

		scrpos += LINE_WIDTH*8;
	}

	*hcache = 0; // terminate cache
}


static void DrawTilesFromCacheF(int *hc)
{
	int code, addr, zero = 0;
	unsigned int prevy=0xFFFFFFFF;
//	unsigned short *pal;
	unsigned char pal;
	short blank=-1; // The tile we know is blank
	unsigned char *scrpos = PicoDraw2FB, *pd = 0;

	// *hcache++ = code|(dx<<16)|(trow<<27); // cache it
	scrpos+=(*hc++)*LINE_WIDTH - START_ROW*LINE_WIDTH*8;

	while((code=*hc++)) {
		if((short)code == blank) continue;

		// y pos
		if(((unsigned)code>>27) != prevy) {
			prevy = (unsigned)code>>27;
			pd = scrpos + prevy*LINE_WIDTH*8;
		}

		// Get tile address/2:
		addr=(code&0x7ff)<<4;
//		pal=PicoCramHigh+((code>>9)&0x30);
		pal=(unsigned char)((code>>9)&0x30);

		switch((code>>11)&3) {
			case 0: zero=TileXnormYnorm(pd+((code>>16)&0x1ff),addr,pal); break;
			case 1: zero=TileXflipYnorm(pd+((code>>16)&0x1ff),addr,pal); break;
			case 2: zero=TileXnormYflip(pd+((code>>16)&0x1ff),addr,pal); break;
			case 3: zero=TileXflipYflip(pd+((code>>16)&0x1ff),addr,pal); break;
		}

		if(zero) blank=(short)code;
	}
}


// sx and sy are coords of virtual screen with 8pix borders on top and on left
static void DrawSpriteFull(unsigned int *sprite)
{
	int width=0,height=0;
//	unsigned short *pal=NULL;
	unsigned char pal;
	int tile,code,tdeltax,tdeltay;
	unsigned char *scrpos;
	int sx, sy;

	sy=sprite[0];
	height=sy>>24;
	sy=(sy&0x1ff)-0x78; // Y
	width=(height>>2)&3; height&=3;
	width++; height++; // Width and height in tiles

	code=sprite[1];
	sx=((code>>16)&0x1ff)-0x78; // X

	tile=code&0x7ff; // Tile number
	tdeltax=height; // Delta to increase tile by going right
	tdeltay=1;      // Delta to increase tile by going down
	if (code&0x0800) { tdeltax=-tdeltax; tile+=height*(width-1); } // Flip X
	if (code&0x1000) { tdeltay=-tdeltay; tile+=height-1; } // Flip Y

	//delta<<=4; // Delta of address
//	pal=PicoCramHigh+((code>>9)&0x30); // Get palette pointer
	pal=(unsigned char)((code>>9)&0x30);

	// goto first vertically visible tile
	while(sy <= START_ROW*8) { sy+=8; tile+=tdeltay; height--; }

	scrpos = PicoDraw2FB;
	scrpos+=(sy-START_ROW*8)*LINE_WIDTH;

	for (; height > 0; height--, sy+=8, tile+=tdeltay)
	{
		int w = width, x=sx, t=tile;

		if(sy >= END_ROW*8+8) return; // offscreen

		for (; w; w--,x+=8,t+=tdeltax)
		{
			if(x<=0)   continue;
			if(x>=328) break; // Offscreen

			t&=0x7fff; // Clip tile address
			switch((code>>11)&3) {
				case 0: TileXnormYnorm(scrpos+x,t<<4,pal); break;
				case 1: TileXflipYnorm(scrpos+x,t<<4,pal); break;
				case 2: TileXnormYflip(scrpos+x,t<<4,pal); break;
				case 3: TileXflipYflip(scrpos+x,t<<4,pal); break;
			}
		}

		scrpos+=8*LINE_WIDTH;
	}
}
#endif


static void DrawAllSpritesFull(int prio, int maxwidth)
{
	struct PicoVideo *pvid=&Pico.video;
	int table=0,maskrange=0;
	int i,u,link=0;
	unsigned int *sprites[80]; // Sprites
	int y_min=START_ROW*8, y_max=END_ROW*8; // for a simple sprite masking

	table=pvid->reg[5]&0x7f;
	if (pvid->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
	table<<=8; // Get sprite table address/2

	for (i=u=0; u < 80; u++)
	{
		unsigned int *sprite=NULL;
		int code, code2, sx, sy, height;

		sprite=(unsigned int *)(Pico.vram+((table+(link<<2))&0x7ffc)); // Find sprite

		// get sprite info
		code = sprite[0];

		// check if it is not hidden vertically
		sy = (code&0x1ff)-0x80;
		height = (((code>>24)&3)+1)<<3;
		if(sy+height <= y_min || sy > y_max) goto nextsprite;

		// masking sprite?
		code2=sprite[1];
		sx = (code2>>16)&0x1ff;
		if(!sx) {
			int to = sy+height; // sy ~ from
			if(maskrange) {
				// try to merge with previous range
				if((maskrange>>16)+1 >= sy && (maskrange>>16) <= to && (maskrange&0xffff) < sy) sy = (maskrange&0xffff);
				else if((maskrange&0xffff)-1 <= to && (maskrange&0xffff) >= sy && (maskrange>>16) > to) to = (maskrange>>16);
			}
			// support only very simple masking (top and bottom of screen)
			if(sy <= y_min && to+1 > y_min) y_min = to+1;
			else if(to >= y_max && sy-1 < y_max) y_max = sy-1;
			else maskrange=sy|(to<<16);

			goto nextsprite;
		}

		// priority
		if(((code2>>15)&1) != prio) goto nextsprite; // wrong priority

		// check if sprite is not hidden horizontally
		sx -= 0x78; // Get X coordinate + 8
		if(sx <= -8*3 || sx >= maxwidth) goto nextsprite;

		// sprite is good, save it's index
		sprites[i++]=sprite;

		nextsprite:
		// Find next sprite
		link=(code>>16)&0x7f;
		if(!link) break; // End of sprites
	}

	// Go through sprites backwards:
	for (i-- ;i>=0; i--)
	{
		DrawSpriteFull(sprites[i]);
	}
}

#ifndef _ASM_DRAW_C
static void BackFillFull(int reg7)
{
	unsigned int back;

	// Start with a background color:
//	back=PicoCramHigh[reg7&0x3f];
	back=reg7&0x3f;
	back|=back<<8;
	back|=back<<16;

	memset32((int *)PicoDraw2FB, back, LINE_WIDTH*(8+(END_ROW-START_ROW)*8)/4);
}
#endif

static void DrawDisplayFull(void)
{
	struct PicoVideo *pvid=&Pico.video;
	int win, edge=0, hvwin=0; // LSb->MSb: hwin&plane, vwin&plane, full
	int planestart=START_ROW, planeend=END_ROW; // plane A start/end when window shares display with plane A (in tile rows or columns)
	int winstart=START_ROW, winend=END_ROW;     // same for window
	int maxw, maxcolc; // max width and col cells

	if(pvid->reg[12]&1) {
		maxw = 328; maxcolc = 40;
	} else {
		maxw = 264; maxcolc = 32;
	}

	// horizontal window?
	if ((win=pvid->reg[0x12]))
	{
		hvwin=1; // hwindow shares display with plane A
		edge=win&0x1f;
		if(win == 0x80) {
			// fullscreen window
			hvwin=4;
		} else if(win < 0x80) {
			// window on the top
			     if(edge <= START_ROW) hvwin=0; // window not visible in our drawing region
			else if(edge >= END_ROW)   hvwin=4;
			else planestart = winend = edge;
		} else if(win > 0x80) {
			// window at the bottom
			if(edge >= END_ROW) hvwin=0;
			else planeend = winstart = edge;
		}
	}

	// check for vertical window, but only if win is not fullscreen
	if (hvwin != 4)
	{
		win=pvid->reg[0x11];
		edge=win&0x1f;
		if (win&0x80) {
			if(!edge) hvwin=4;
			else if(edge < (maxcolc>>1)) {
				// window is on the right
				hvwin|=2;
				planeend|=edge<<17;
				winstart|=edge<<17;
				winend|=maxcolc<<16;
			}
		} else {
			if(edge >= (maxcolc>>1)) hvwin=4;
			else if(edge) {
				// window is on the left
				hvwin|=2;
				winend|=edge<<17;
				planestart|=edge<<17;
				planeend|=maxcolc<<16;
			}
		}
	}

	if (hvwin==1) { winend|=maxcolc<<16; planeend|=maxcolc<<16; }

	HighCache2A[1] = HighCache2B[1] = 0;
	if (PicoDrawMask & PDRAW_LAYERB_ON)
		DrawLayerFull(1, HighCache2B, START_ROW, (maxcolc<<16)|END_ROW);
	if (PicoDrawMask & PDRAW_LAYERA_ON) switch (hvwin)
	{
		case 4:
		// fullscreen window
		DrawWindowFull(START_ROW, (maxcolc<<16)|END_ROW, 0);
		break;

		case 3:
		// we have plane A and both v and h windows
		DrawLayerFull(0, HighCache2A, planestart, planeend);
		DrawWindowFull( winstart&~0xff0000, (winend&~0xff0000)|(maxcolc<<16), 0); // h
		DrawWindowFull((winstart&~0xff)|START_ROW, (winend&~0xff)|END_ROW, 0);    // v
		break;

		case 2:
		case 1:
		// both window and plane A visible, window is vertical XOR horizontal
		DrawLayerFull(0, HighCache2A, planestart, planeend);
		DrawWindowFull(winstart, winend, 0);
		break;

		default:
		// fullscreen plane A
		DrawLayerFull(0, HighCache2A, START_ROW, (maxcolc<<16)|END_ROW);
		break;
	}
	if (PicoDrawMask & PDRAW_SPRITES_LOW_ON)
		DrawAllSpritesFull(0, maxw);

	if (HighCache2B[1]) DrawTilesFromCacheF(HighCache2B);
	if (HighCache2A[1]) DrawTilesFromCacheF(HighCache2A);
	if (PicoDrawMask & PDRAW_LAYERA_ON) switch (hvwin)
	{
		case 4:
		// fullscreen window
		DrawWindowFull(START_ROW, (maxcolc<<16)|END_ROW, 1);
		break;

		case 3:
		// we have plane A and both v and h windows
		DrawWindowFull( winstart&~0xff0000, (winend&~0xff0000)|(maxcolc<<16), 1); // h
		DrawWindowFull((winstart&~0xff)|START_ROW, (winend&~0xff)|END_ROW, 1);    // v
		break;

		case 2:
		case 1:
		// both window and plane A visible, window is vertical XOR horizontal
		DrawWindowFull(winstart, winend, 1);
		break;
	}
	if (PicoDrawMask & PDRAW_SPRITES_HI_ON)
		DrawAllSpritesFull(1, maxw);
}


PICO_INTERNAL void PicoFrameFull()
{
	pprof_start(draw);

	// prepare cram?
	if (PicoPrepareCram) PicoPrepareCram();

	// Draw screen:
	BackFillFull(Pico.video.reg[7]);
	if (Pico.video.reg[1] & 0x40)
		DrawDisplayFull();

	pprof_end(draw);
}

