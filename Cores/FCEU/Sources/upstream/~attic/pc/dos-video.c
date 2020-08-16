/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 \Firebug\
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <string.h>
#include <dpmi.h>
#include <sys/farptr.h>
#include <go32.h>
#include <pc.h>

#include "dos.h"
#include "dos-video.h"

#define TEXT            3
#define G320x200x256    0x13

static void vga_waitretrace(void)
{ 
 while(inp(0x3da)&0x8); 
 while(!(inp(0x3da)&0x8));
}

static void vga_setmode(int mode)
{
 __dpmi_regs regs;

 memset(&regs,0,sizeof(regs));
 regs.x.ax=mode;

 __dpmi_int(0x10,&regs);
}

void vga_setpalette(int i, int r, int g, int b)
{ 
 outp(0x3c8,i);
 outp(0x3c9,r);
 outp(0x3c9,g);
 outp(0x3c9,b); 
}

int FCEUDvmode=1;

static int vidready=0;

/*      Part of the VGA low-level mass register setting code derived from
	code by \Firebug\.
*/

#include "vgatweak.c"

void SetBorder(void)
{
 inportb(0x3da);
 outportb(0x3c0,(0x11|0x20));
 outportb(0x3c0,0x80);
}

void TweakVGA(int VGAMode)
{
  int I;
  
  vga_waitretrace();

  outportb(0x3C8,0x00);
  for(I=0;I<768;I++) outportb(0x3C9,0x00);

  outportb(0x3D4,0x11);
  I=inportb(0x3D5)&0x7F;
  outportb(0x3D4,0x11);
  outportb(0x3D5,I);

  switch(VGAMode)
  {
    case 1:  for(I=0;I<25;I++) VGAPortSet(v256x240[I]);break;
    case 2:  for(I=0;I<25;I++) VGAPortSet(v256x256[I]);break;
    case 3:  for(I=0;I<25;I++) VGAPortSet(v256x256S[I]);break;
    case 6:  for(I=0;I<25;I++) VGAPortSet(v256x224S[I]);break;
    case 8:  for(I=0;I<25;I++) VGAPortSet(v256x224_103[I]);break;
    default: break;
  }

  outportb(0x3da,0);
}


static uint8 palettedbr[256],palettedbg[256],palettedbb[256];

static void FlushPalette(void)
{
 int x;
 for(x=0;x<256;x++)
 {
  int z=x;
  vga_setpalette(z,palettedbr[x]>>2,palettedbg[x]>>2,palettedbb[x]>>2);
 }
}

void FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b)
{
  palettedbr[index]=r;
  palettedbg[index]=g;
  palettedbb[index]=b;
  if(vidready)
  {
   vga_setpalette(index,r>>2,g>>2,b>>2);
  }
}


void FCEUD_GetPalette(uint8 i, uint8 *r, uint8 *g, uint8 *b)
{
 *r=palettedbr[i];
 *g=palettedbg[i];
 *b=palettedbb[i];
}

static uint32 ScreenLoc;

int InitVideo(void)
{
 vidready=0;
 switch(FCEUDvmode)
 {
  default:
  case 1:
  case 2:
  case 3:
  case 6:
  case 8:
         vga_setmode(G320x200x256);
	 vidready|=1;
         ScreenLoc=0xa0000;
         TweakVGA(FCEUDvmode);
         SetBorder();
         DOSMemSet(ScreenLoc, 128, 256*256);
         break;
 }
 vidready|=2;
 FlushPalette();
 return 1;
}

void KillVideo(void)
{
 if(vidready)
 {
  vga_setmode(TEXT);
  vidready=0;
 }
}
void LockConsole(void){}
void UnlockConsole(void){}
void BlitScreen(uint8 *XBuf)
{
 uint32 dest;
 int tlines;

 if(eoptions&4 && !NoWaiting)
  vga_waitretrace();

 tlines=erendline-srendline+1;

 dest=ScreenLoc;

 switch(FCEUDvmode)
 {
  case 1:dest+=(((240-tlines)>>1)<<8);break;
  case 2:
  case 3:dest+=(((256-tlines)>>1)<<8);break;
  case 4:
  case 5:dest+=(((240-tlines)>>1)*640+((640-512)>>1));break;
  case 8:
  case 6:if(tlines>224) tlines=224;dest+=(((224-tlines)>>1)<<8);break;
 }
 
 XBuf+=(srendline<<8)+(srendline<<4);
           
  _farsetsel(_dos_ds);
 if(eoptions&DO_CLIPSIDES)
 {
  asm volatile(     
     "agoop1:\n\t"
     "movl $30,%%eax\n\t"
     "agoop2:\n\t"
     "movl (%%esi),%%edx\n\t"
     "movl 4(%%esi),%%ecx\n\t"
     ".byte 0x64 \n\t"
     "movl %%edx,(%%edi)\n\t"
     ".byte 0x64 \n\t"
     "movl %%ecx,4(%%edi)\n\t"
     "addl $8,%%esi\n\t"
     "addl $8,%%edi\n\t"
     "decl %%eax\n\t"
     "jne agoop2\n\t"
     "addl $32,%%esi\n\t"
     "addl $16,%%edi\n\t"
     "decb %%bl\n\t"
     "jne agoop1\n\t"
     :
     : "S" (XBuf+8), "D" (dest+8), "b" (tlines)
     : "%eax","%cc","%edx","%ecx" );
 }
 else
 {
  asm volatile(     
     "goop1:\n\t"
     "movl $32,%%eax\n\t"
     "goop2:\n\t"
     "movl (%%esi),%%edx\n\t"
     "movl 4(%%esi),%%ecx\n\t"
     ".byte 0x64 \n\t"
     "movl %%edx,(%%edi)\n\t"
     ".byte 0x64 \n\t"
     "movl %%ecx,4(%%edi)\n\t"
     "addl $8,%%esi\n\t"
     "addl $8,%%edi\n\t"
     "decl %%eax\n\t"
     "jne goop2\n\t"
     "addl $16,%%esi\n\t"
     "decb %%bl\n\t"
     "jne goop1\n\t"
     :
     : "S" (XBuf), "D" (dest), "b" (tlines)
     : "%eax","%cc","%edx","%ecx" );
 }
}


