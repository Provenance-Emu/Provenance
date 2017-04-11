/*  Copyright 2005-2008 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file vdp2debug.c
    \brief VDP2 debug functions
*/

#include "vdp2.h"
#include "ygl.h"
#include "vdp2debug.h"
#include "vidshared.h"
#include "vidsoft.h"
#include "titan/titan.h"

//////////////////////////////////////////////////////////////////////////////

static INLINE void Vdp2GetPlaneSize(int planedata, int *planew, int *planeh)
{
   switch(planedata)
   {
      case 0:
         *planew = *planeh = 1;
         break;
      case 1:
         *planew = 2;
         *planeh = 1;
         break;
      case 2:
         *planew = *planeh = 2;
         break;
      default:
         *planew = *planeh = 1;         
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddBppString(char *outstring, int bpp)
{
   switch (bpp)
   {
      case 0:
         AddString(outstring, "4-bit(16 colors)\r\n");
         break;
      case 1:
         AddString(outstring, "8-bit(256 colors)\r\n");
         break;
      case 2:
         AddString(outstring, "16-bit(2048 colors)\r\n");
         break;
      case 3:
         AddString(outstring, "16-bit(32,768 colors)\r\n");
         break;
      case 4:
         AddString(outstring, "32-bit(16.7 mil colors)\r\n");
         break;
      default:
         AddString(outstring, "Unsupported BPP\r\n");
         break;
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddMosaicString(char *outstring, int mask)
{
   if (Vdp2Regs->MZCTL & mask)
   {
      AddString(outstring, "Mosaic Size = width %d height %d\r\n", ((Vdp2Regs->MZCTL >> 8) & 0xf) + 1, (Vdp2Regs->MZCTL >> 12) + 1);
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddBitmapInfoString(char *outstring, int wh, int palnum, int mapofn)
{
   int cellw=0, cellh=0;

   // Bitmap
   switch(wh)
   {
      case 0:
         cellw = 512;
         cellh = 256;
         break;
      case 1:
         cellw = 512;
         cellh = 512;
         break;
      case 2:
         cellw = 1024;
         cellh = 256;
         break;
      case 3:
         cellw = 1024;
         cellh = 512;
         break;                                                           
   }

   AddString(outstring, "Bitmap(%dx%d)\r\n", cellw, cellh);

   if (palnum & 0x20)
   {
      AddString(outstring, "Bitmap Special Priority enabled\r\n");
   }

   if (palnum & 0x10)
   {
      AddString(outstring, "Bitmap Special Color Calculation enabled\r\n");
   }

   AddString(outstring, "Bitmap Address = %X\r\n", (mapofn & 0x7) * 0x20000);
   AddString(outstring, "Bitmap Palette Address = %X\r\n", (palnum & 0x7) << 4);

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static void CalcWindowCoordinates(int num, int *hstart, int *vstart, int *hend, int *vend)
{
   clipping_struct clip;
   ReadWindowCoordinates(num, &clip);
   *hstart = clip.xstart;
   *vstart = clip.ystart;
   *hend = clip.xend;
   *vend = clip.yend;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddWindowInfoString(char *outstring, int wctl, int issprite)
{
   if (wctl & 0x2)
   {
      int hstart=0, vstart=0, hend=0, vend=0;

      AddString(outstring, "Window W0 Enabled:\r\n");

      // Retrieve Window Points
      if (Vdp2Regs->LWTA0.all & 0x80000000)
      {
         // Line Window
         AddString(outstring, "Line Window Table Address = %08lX\r\n", 0x05E00000UL | ((Vdp2Regs->LWTA0.all & 0x7FFFEUL) << 1));
      }
      else
      {
         // Normal Window
         CalcWindowCoordinates(0, &hstart, &vstart, &hend, &vend);
         AddString(outstring, "Horizontal start = %d\r\n", hstart);
         AddString(outstring, "Vertical start = %d\r\n", vstart);
         AddString(outstring, "Horizontal end = %d\r\n", hend);
         AddString(outstring, "Vertical end = %d\r\n", vend);
      }

      AddString(outstring, "Display %s of Window\r\n", (wctl & 0x1) ? "inside" : "outside");
   }

   if (wctl & 0x8)
   {
      int hstart=0, vstart=0, hend=0, vend=0;

      AddString(outstring, "Window W1 Enabled:\r\n");

      // Retrieve Window Points
      if (Vdp2Regs->LWTA1.all & 0x80000000)
      {
         // Line Window
         AddString(outstring, "Line Table address = %08lX\r\n", 0x05E00000UL | ((Vdp2Regs->LWTA1.all & 0x7FFFEUL) << 1));
      }
      else
      {
         // Normal Window
         CalcWindowCoordinates(1, &hstart, &vstart, &hend, &vend);
         AddString(outstring, "Horizontal start = %d\r\n", hstart);
         AddString(outstring, "Vertical start = %d\r\n", vstart);
         AddString(outstring, "Horizontal end = %d\r\n", hend);
         AddString(outstring, "Vertical end = %d\r\n", vend);
      }

      AddString(outstring, "Display %s of Window\r\n", (wctl & 0x4) ? "inside" : "outside");
   }

   if (wctl & 0x20)
   {
      AddString(outstring, "Sprite Window Enabled:\r\n");
      AddString(outstring, "Display %s of Window\r\n", (wctl & 0x10) ? "inside" : "outside");
   }

   if (wctl & 0x2A)
   {
      AddString(outstring, "Window Overlap Logic: %s\r\n", (wctl & 0x80) ? "AND" : "OR");
   }
   else
   {
      if (wctl & 0x80)
      {
         // Whole screen window enabled
         AddString(outstring, "Window enabled whole screen\r\n");
      }
      else
      {
         // Whole screen window disabled
         AddString(outstring, "Window disabled whole screen\r\n");
      }
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddMapInfo(char *outstring, int patternwh, u16 PNC, u8 PLSZ, int mapoffset, int numplanes, u8 *map)
{
   int deca;
   int multi;
   int i;
   int patterndatasize;
   int planew, planeh;
   u32 tmp=0;
   u32 addr;

   if(PNC & 0x8000)
      patterndatasize = 1;
   else
      patterndatasize = 2;

   switch(PLSZ)
   {
      case 0:
         planew = planeh = 1;
         break;
      case 1:
         planew = 2;
         planeh = 1;
         break;
      case 2:
         planew = planeh = 2;
         break;
      default: // Not sure what 0x3 does
         planew = planeh = 1;
         break;
   }

   deca = planeh + planew - 2;
   multi = planeh * planew;

   // Map Planes A-D
   for (i = 0; i < numplanes; i++)
   {
      tmp = mapoffset | map[i];

      if (patterndatasize == 1)
      {
         if (patternwh == 1)
            addr = ((tmp & 0x3F) >> deca) * (multi * 0x2000);
         else
            addr = (tmp >> deca) * (multi * 0x800);
      }
      else
      {
         if (patternwh == 1)
            addr = ((tmp & 0x1F) >> deca) * (multi * 0x4000);
         else
            addr = ((tmp & 0x7F) >> deca) * (multi * 0x1000);
      }
  
      AddString(outstring, "Plane %C Address = %08X\r\n", 0x41+i, (unsigned int)addr);
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddColorCalcInfo(char *outstring, u16 calcenab, u16 gradnum, u16 calcratio, u16 sfcnum)
{
   if (Vdp2Regs->CCCTL & calcenab)
   {
      AddString(outstring, "Color Calculation Enabled\r\n");

      if (Vdp2Regs->CCCTL & 0x8000 && (Vdp2Regs->CCCTL & 0x0700) == gradnum)
      {
         AddString(outstring, "Gradation Calculation Enabled\r\n");
      }
      else if (Vdp2Regs->CCCTL & 0x0400)
      {
         AddString(outstring, "Extended Color Calculation Enabled\r\n");
      }
      else
      {
         AddString(outstring, "Special Color Calculation Mode = %d\r\n", sfcnum);
      }

      AddString(outstring, "Color Calculation Ratio = %d:%d\r\n", 31 - calcratio, 1 + calcratio);
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddColorOffsetInfo(char *outstring, u16 offsetselectenab)
{
   s32 r, g, b;

   if (Vdp2Regs->CLOFEN & offsetselectenab)
   {
      if (Vdp2Regs->CLOFSL & offsetselectenab)
      {
         r = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            r |= 0xFFFFFF00;

         g = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            g |= 0xFFFFFF00;

         b = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            b |= 0xFFFFFF00;

         AddString(outstring, "Color Offset B Enabled\r\n");
         AddString(outstring, "R = %ld, G = %ld, B = %ld\r\n",
		   (long)r, (long)g, (long)b);
      }
      else
      {
         r = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            r |= 0xFFFFFF00;

         g = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            g |= 0xFFFFFF00;

         b = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            b |= 0xFFFFFF00;

         AddString(outstring, "Color Offset A Enabled\r\n");
         AddString(outstring, "R = %ld, G = %ld, B = %ld\r\n",
		   (long)r, (long)g, (long)b);
      }
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE char *AddSpecialPriorityInfo(char *outstring, u16 spriority)
{
   if (spriority & 0x3)
   {
      AddString(outstring, "Special Priority Mode %d used", spriority & 0x3);

      switch (spriority & 0x3)
      {
         case 1:
            AddString(outstring, "(per tile)\r\n");
            break;
         case 2:
            AddString(outstring, "(per pixel)\r\n");
            break;
         case 3:
            AddString(outstring, "(undocumented)\r\n");
            break;
         default: break;
      }
   }

   return outstring;
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsRBG0(char *outstring, int *isenabled)
{
   int patternwh=((Vdp2Regs->CHCTLB & 0x100) >> 8) + 1;
   u8 map[16];
   int hstart, vstart, hend, vend;

   if (Vdp2Regs->BGON & 0x10)
   {
      // enabled
      int rotatenum=0;
      int coeftbl=0, coefmode=0;

      *isenabled = 1;

      // Which Rotation Parameter is being used
      switch (Vdp2Regs->RPMD & 0x3)
      {
         case 0:
            // Parameter A
            rotatenum = 0;
            coeftbl = Vdp2Regs->KTCTL & 0x1;
            coefmode = (Vdp2Regs->KTCTL >> 2) & 0x3;
            AddString(outstring, "Using Parameter %C\r\n", 'A' + rotatenum);
            break;
         case 1:
            // Parameter B
            rotatenum = 1;
            coeftbl = Vdp2Regs->KTCTL & 0x100;
            coefmode = (Vdp2Regs->KTCTL >> 10) & 0x3;
            AddString(outstring, "Using Parameter B\r\n");
            break;
         case 2:
            // Parameter A+B switched via coefficients
            AddString(outstring, "Parameter A/B switched via coefficients\r\n");
            break;
         case 3:
            // Parameter A+B switched via rotation parameter window
            AddString(outstring, "Parameter A/B switched parameter window\r\n");
            if (Vdp2Regs->WCTLD & 0x2)
            {
               AddString(outstring, "Rotation Window 0 Enabled\r\n");
               CalcWindowCoordinates(0, &hstart, &vstart, &hend, &vend);
               AddString(outstring, "Horizontal start = %d\r\n", hstart);
               AddString(outstring, "Vertical start = %d\r\n", vstart);
               AddString(outstring, "Horizontal end = %d\r\n", hend);
               AddString(outstring, "Vertical end = %d\r\n", vend);
            }
            else if (Vdp2Regs->WCTLD & 0x4)
            {
               AddString(outstring, "Rotation Window 1 Enabled\r\n");
               CalcWindowCoordinates(1, &hstart, &vstart, &hend, &vend);
               AddString(outstring, "Horizontal start = %d\r\n", hstart);
               AddString(outstring, "Vertical start = %d\r\n", vstart);
               AddString(outstring, "Horizontal end = %d\r\n", hend);
               AddString(outstring, "Vertical end = %d\r\n", vend);
            }
            break;
      }

      if (coeftbl)
      {
         AddString(outstring, "Coefficient Table Enabled(Mode %d)\r\n", coefmode);
      }

      // Mosaic
      outstring = AddMosaicString(outstring, 0x10);

      // BPP
      outstring = AddBppString(outstring, (Vdp2Regs->CHCTLB >> 12) & 0x7);

      // Bitmap or Tile mode?
      if (Vdp2Regs->CHCTLB & 0x200)
      {
         // Bitmap mode
         if (rotatenum == 0)
         {
            // Parameter A
            outstring = AddBitmapInfoString(outstring, (Vdp2Regs->CHCTLB & 0x400) >> 10, Vdp2Regs->BMPNB, Vdp2Regs->MPOFR);
         }
         else
         {
            // Parameter B
            outstring = AddBitmapInfoString(outstring, (Vdp2Regs->CHCTLB & 0x400) >> 10, Vdp2Regs->BMPNB, Vdp2Regs->MPOFR >> 4);
         }
      }
      else
      {
         // Tile mode
         int patterndatasize; 
         u16 supplementdata=Vdp2Regs->PNCR & 0x3FF;
         int planew=0, planeh=0;

         if(Vdp2Regs->PNCR & 0x8000)
            patterndatasize = 1;
         else
            patterndatasize = 2;

         AddString(outstring, "Tile(%dH x %dV)\r\n", patternwh, patternwh);

         if (rotatenum == 0)
         {
            // Parameter A
            Vdp2GetPlaneSize((Vdp2Regs->PLSZ & 0x300) >> 8, &planew, &planeh);
         }
         else
         {
            // Parameter B
            Vdp2GetPlaneSize((Vdp2Regs->PLSZ & 0x3000) >> 8, &planew, &planeh);
         }

         AddString(outstring, "Plane Size = %dH x %dV\r\n", planew, planeh);

         // Pattern Name Control stuff
         if (patterndatasize == 2) 
         {
            AddString(outstring, "Pattern Name data size = 2 words\r\n");
         }
         else
         {
            AddString(outstring, "Pattern Name data size = 1 word\r\n");
            AddString(outstring, "Character Number Supplement bit = %d\r\n", (supplementdata >> 14) & 0x1);
            AddString(outstring, "Special Priority bit = %d\r\n", (supplementdata >> 9) & 0x1);
            AddString(outstring, "Special Color Calculation bit = %d\r\n", (supplementdata >> 8) & 0x1);
            AddString(outstring, "Supplementary Palette number = %d\r\n", (supplementdata >> 5) & 0x7);
            AddString(outstring, "Supplementary Color number = %d\r\n", supplementdata & 0x1f);
         }

         if (rotatenum == 0)
         {
            // Parameter A
            map[0] = Vdp2Regs->MPABRA & 0xFF;
            map[1] = Vdp2Regs->MPABRA >> 8;
            map[2] = Vdp2Regs->MPCDRA & 0xFF;
            map[3] = Vdp2Regs->MPCDRA >> 8;
            map[4] = Vdp2Regs->MPEFRA & 0xFF;
            map[5] = Vdp2Regs->MPEFRA >> 8;
            map[6] = Vdp2Regs->MPGHRA & 0xFF;
            map[7] = Vdp2Regs->MPGHRA >> 8;
            map[8] = Vdp2Regs->MPIJRA & 0xFF;
            map[9] = Vdp2Regs->MPIJRA >> 8;
            map[10] = Vdp2Regs->MPKLRA & 0xFF;
            map[11] = Vdp2Regs->MPKLRA >> 8;
            map[12] = Vdp2Regs->MPMNRA & 0xFF;
            map[13] = Vdp2Regs->MPMNRA >> 8;
            map[14] = Vdp2Regs->MPOPRA & 0xFF;
            map[15] = Vdp2Regs->MPOPRA >> 8;
            outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCR, (Vdp2Regs->PLSZ >> 8) & 0x3, (Vdp2Regs->MPOFR & 0x7) << 6, 16, map);
         }
         else
         {
            // Parameter B
            map[0] = Vdp2Regs->MPABRB & 0xFF;
            map[1] = Vdp2Regs->MPABRB >> 8;
            map[2] = Vdp2Regs->MPCDRB & 0xFF;
            map[3] = Vdp2Regs->MPCDRB >> 8;
            map[4] = Vdp2Regs->MPEFRB & 0xFF;
            map[5] = Vdp2Regs->MPEFRB >> 8;
            map[6] = Vdp2Regs->MPGHRB & 0xFF;
            map[7] = Vdp2Regs->MPGHRB >> 8;
            map[8] = Vdp2Regs->MPIJRB & 0xFF;
            map[9] = Vdp2Regs->MPIJRB >> 8;
            map[10] = Vdp2Regs->MPKLRB & 0xFF;
            map[11] = Vdp2Regs->MPKLRB >> 8;
            map[12] = Vdp2Regs->MPMNRB & 0xFF;
            map[13] = Vdp2Regs->MPMNRB >> 8;
            map[14] = Vdp2Regs->MPOPRB & 0xFF;
            map[15] = Vdp2Regs->MPOPRB >> 8;
            outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCR, (Vdp2Regs->PLSZ >> 12) & 0x3, (Vdp2Regs->MPOFR & 0x70) << 2, 16, map);
         }

/*
         // Figure out Cell start address
         switch(patterndatasize)
         {
            case 1:
            {
               tmp = readWord(vram, addr);

               switch(auxMode)
               {
                  case 0:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0x3FF) | ((supplementdata & 0x1F) << 10);
                           break;
                        case 2:
                           charAddr = ((tmp & 0x3FF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x1C) << 10);
                           break;
                     }
                     break;
                  case 1:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0xFFF) | ((supplementdata & 0x1C) << 10);
                           break;
                        case 4:
                           charAddr = ((tmp & 0xFFF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x10) << 10);
                           break;
                     }
                     break;
               }
               break;
            }
            case 2:
            {
               unsigned short tmp1 = readWord(vram, addr);
               unsigned short tmp2 = readWord(vram, addr+2);
   
               charAddr = tmp2 & 0x7FFF;
               break;
            }
         }
   
         if (!(readWord(reg, 0x6) & 0x8000))
            charAddr &= 0x3FFF;

         charAddr *= 0x20; // selon Runik
   
         AddString(outstring, "Cell Data Address = %X\r\n", charAddr);
*/
      }

      // Window Control
      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLC, 0);

      // Shadow Control here

      // Color Ram Address Offset
      AddString(outstring, "Color Ram Address Offset = %X\r\n", (Vdp2Regs->CRAOFB & 0x7) << 8);
       
      // Special Priority Mode
      outstring = AddSpecialPriorityInfo(outstring, Vdp2Regs->SFPRMD >> 8);

      // Color Calculation Control here

      // Special Color Calculation Mode here

      // Priority Number
      AddString(outstring, "Priority = %d\r\n", Vdp2Regs->PRIR & 0x7);
        
      // Color Calculation
      outstring = AddColorCalcInfo(outstring, 0x0010, 0x0001, Vdp2Regs->CCRR & 0x1F, (Vdp2Regs->SFCCMD >> 8) & 0x3);

      // Color Offset
      outstring = AddColorOffsetInfo(outstring, 0x0010);
      
      AddString(outstring, "Special Color Calculation %d\r\n",(Vdp2Regs->SFCCMD>>8)&0x03);
   }
   else
   {
      // disabled
      *isenabled = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsNBG0(char *outstring, int *isenabled)
{
   u16 lineVerticalScrollReg = Vdp2Regs->SCRCTL & 0x3F;
   int isbitmap=Vdp2Regs->CHCTLA & 0x2;
   int patternwh=(Vdp2Regs->CHCTLA & 0x1) + 1;
   u8 map[4];

   if (Vdp2Regs->BGON & 0x1 || Vdp2Regs->BGON & 0x20)
   {
      // enabled
      *isenabled = 1;

      // Generate specific Info for NBG0/RBG1
      if (Vdp2Regs->BGON & 0x20)
      {
         AddString(outstring, "RBG1 mode\r\n");

         if (Vdp2Regs->KTCTL & 0x100)
         {
            AddString(outstring, "Coefficient Table Enabled(Mode %d)\r\n", (Vdp2Regs->KTCTL >> 10) & 0x3);
         }
      }
      else
      {
         AddString(outstring, "NBG0 mode\r\n");
      }

      // Mosaic
      outstring = AddMosaicString(outstring, 0x1);

      // BPP
      outstring = AddBppString(outstring, (Vdp2Regs->CHCTLA & 0x70) >> 4);

      // Bitmap or Tile mode?(RBG1 can only do Tile mode)
      if (isbitmap && !(Vdp2Regs->BGON & 0x20))
      {
         // Bitmap
         outstring = AddBitmapInfoString(outstring, (Vdp2Regs->CHCTLA & 0xC) >> 2, Vdp2Regs->BMPNA, Vdp2Regs->MPOFN);
      }
      else
      {
         // Tile
         int patterndatasize; 
         u16 supplementdata=Vdp2Regs->PNCN0 & 0x3FF;
         int planew=0, planeh=0;

         if(Vdp2Regs->PNCN0 & 0x8000)
            patterndatasize = 1;
         else
            patterndatasize = 2;

         AddString(outstring, "Tile(%dH x %dV)\r\n", patternwh, patternwh);

         Vdp2GetPlaneSize(Vdp2Regs->PLSZ & 0x3, &planew, &planeh);
         AddString(outstring, "Plane Size = %dH x %dV\r\n", planew, planeh);

         // Pattern Name Control stuff
         if (patterndatasize == 2) 
         {
            AddString(outstring, "Pattern Name data size = 2 words\r\n");
         }
         else
         {
            AddString(outstring, "Pattern Name data size = 1 word\r\n");
            AddString(outstring, "Character Number Supplement bit = %d\r\n", (supplementdata >> 14) & 0x1);
            AddString(outstring, "Special Priority bit = %d\r\n", (supplementdata >> 9) & 0x1);
            AddString(outstring, "Special Color Calculation bit = %d\r\n", (supplementdata >> 8) & 0x1);
            AddString(outstring, "Supplementary Palette number = %d\r\n", (supplementdata >> 5) & 0x7);
            AddString(outstring, "Supplementary Color number = %d\r\n", supplementdata & 0x1f);
         }

         map[0] = Vdp2Regs->MPABN0 & 0xFF;
         map[1] = Vdp2Regs->MPABN0 >> 8;
         map[2] = Vdp2Regs->MPCDN0 & 0xFF;
         map[3] = Vdp2Regs->MPCDN0 >> 8;
         outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCN0, Vdp2Regs->PLSZ & 0x3, (Vdp2Regs->MPOFN & 0x7) << 6, 4, map);

/*
         // Figure out Cell start address
         switch(patterndatasize)
         {
            case 1:
            {
               tmp = T1ReadWord(Vdp2Ram, addr);
         
               switch(auxMode)
               {
                  case 0:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0x3FF) | ((supplementdata & 0x1F) << 10);
                           break;
                        case 2:
                           charAddr = ((tmp & 0x3FF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x1C) << 10);
                           break;
                     }
                     break;
                  case 1:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0xFFF) | ((supplementdata & 0x1C) << 10);
                           break;
                        case 4:
                           charAddr = ((tmp & 0xFFF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x10) << 10);
                           break;
                     }
                     break;
               }
               break;
            }
            case 2:
            {
               u16 tmp1 = T1ReadWord(Vdp2Ram, addr);
               u16 tmp2 = T1ReadWord(Vdp2Ram, addr+2);

               charAddr = tmp2 & 0x7FFF;
               break;
            }
         }
         if (!(readWord(reg, 0x6) & 0x8000))
            charAddr &= 0x3FFF;

         charAddr *= 0x20; // selon Runik

         AddString(outstring, "Cell Data Address = %X\r\n", charAddr);
*/
      }

      if (Vdp2Regs->BGON & 0x20)
      {
//         unsigned long mapOffsetReg=(readWord(reg, 0x3E) & 0x70) << 2;
                                        
         // RBG1

         // Map Planes A-P here

         // Rotation Parameter Read Control
         if (Vdp2Regs->RPRCTL & 0x400)
         {
            AddString(outstring, "Read KAst Parameter = TRUE\r\n");
         }
         else
         {
            AddString(outstring, "Read KAst Parameter = FALSE\r\n");
         }

         if (Vdp2Regs->RPRCTL & 0x200)
         {
            AddString(outstring, "Read Yst Parameter = TRUE\r\n");
         }
         else
         {
            AddString(outstring, "Read Yst Parameter = FALSE\r\n");
         }
 
         if (Vdp2Regs->RPRCTL & 0x100)
         {
            AddString(outstring, "Read Xst Parameter = TRUE\r\n");
         }
         else
         {
            AddString(outstring, "Read Xst Parameter = FALSE\r\n");
         }

         // Coefficient Table Control

         // Coefficient Table Address Offset

         // Screen Over Pattern Name(should this be moved?)

         // Rotation Parameter Table Address
      }
      else
      {
         // NBG0
/*
         // Screen scroll values
         AddString(outstring, "Screen Scroll x = %f, y = %f\r\n", (float)(reg->getLong(0x70) & 0x7FFFF00) / 65536, (float)(reg->getLong(0x74) & 0x7FFFF00) / 65536);
*/
      
         // Coordinate Increments
         AddString(outstring, "Coordinate Increments x = %f, y = %f\r\n", (float) 65536 / (Vdp2Regs->ZMXN0.all & 0x7FF00), (float) 65536 / (Vdp2Regs->ZMYN0.all & 0x7FF00));

         // Reduction Enable
         switch (Vdp2Regs->ZMCTL & 3)
         {
            case 1:
               AddString(outstring, "Horizontal Reduction = 1/2\r\n");
               break;
            case 2:
            case 3:
               AddString(outstring, "Horizontal Reduction = 1/4\r\n");
               break;
            default: break;
         }

         if (lineVerticalScrollReg & 0x8)
         {
            AddString(outstring, "Line Zoom enabled\r\n");
         }

         if (lineVerticalScrollReg & 0x4)
         {
            AddString(outstring, "Line Scroll Vertical enabled\r\n");
         }
   
         if (lineVerticalScrollReg & 0x2)
         {
            AddString(outstring, "Line Scroll Horizontal enabled\r\n");
         }

         if (lineVerticalScrollReg & 0x6) 
         {
            AddString(outstring, "Line Scroll Enabled\r\n");
            AddString(outstring, "Line Scroll Table Address = %08X\r\n", (int)(0x05E00000 + ((Vdp2Regs->LSTA0.all & 0x7FFFE) << 1)));

            switch (lineVerticalScrollReg >> 4)
            {
               case 0:
                  AddString(outstring, "Line Scroll Interval = Each Line\r\n");
                  break;
               case 1:
                  AddString(outstring, "Line Scroll Interval = Every 2 Lines\r\n");
                  break;
               case 2:
                  AddString(outstring, "Line Scroll Interval = Every 4 Lines\r\n");
                  break;
               case 3:
                  AddString(outstring, "Line Scroll Interval = Every 8 Lines\r\n");
                  break;
            }
         }

         if (lineVerticalScrollReg & 0x1)
         {      
            AddString(outstring, "Vertical Cell Scroll enabled\r\n");
            AddString(outstring, "Vertical Cell Scroll Table Address = %08X\r\n", (int)(0x05E00000 + ((Vdp2Regs->VCSTA.all & 0x7FFFE) << 1)));
         }
      }

      // Window Control
      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLA, 0);

      // Shadow Control here

      // Color Ram Address Offset
      AddString(outstring, "Color Ram Address Offset = %X\r\n", (Vdp2Regs->CRAOFA & 0x7) << 8);
 
      // Special Priority Mode
      outstring = AddSpecialPriorityInfo(outstring, Vdp2Regs->SFPRMD);

      // Color Calculation Control here

      // Special Color Calculation Mode here

      // Priority Number
      AddString(outstring, "Priority = %d\r\n", Vdp2Regs->PRINA & 0x7);

      // Color Calculation 
      outstring = AddColorCalcInfo(outstring, 0x0001, 0x0002, Vdp2Regs->CCRNA & 0x1F, Vdp2Regs->SFCCMD & 0x3);

      // Color Offset
      outstring = AddColorOffsetInfo(outstring, 0x0001);
      
      AddString(outstring, "Special Color Calculation %d\r\n",(Vdp2Regs->SFCCMD>>0)&0x03);
         
   }
   else
   {
      // disabled
      *isenabled = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsNBG1(char *outstring, int *isenabled)
{
   u16 lineVerticalScrollReg = (Vdp2Regs->SCRCTL >> 8) & 0x3F;
   int isbitmap=Vdp2Regs->CHCTLA & 0x200;
   int patternwh=((Vdp2Regs->CHCTLA & 0x100) >> 8) + 1;
   u8 map[4];

   if (Vdp2Regs->BGON & 0x2)
   {
      // enabled
      *isenabled = 1;

      // Mosaic
      outstring = AddMosaicString(outstring, 0x2);

      // BPP
      outstring = AddBppString(outstring, (Vdp2Regs->CHCTLA & 0x3000) >> 12);

      // Bitmap or Tile mode?     
      if (isbitmap)
      {
         // Bitmap
         outstring = AddBitmapInfoString(outstring, (Vdp2Regs->CHCTLA & 0xC00) >> 10, Vdp2Regs->BMPNA >> 8, Vdp2Regs->MPOFN >> 4);
      }
      else
      {
         int patterndatasize;
         u16 supplementdata=Vdp2Regs->PNCN1 & 0x3FF;
         int planew=0, planeh=0;

         if(Vdp2Regs->PNCN1 & 0x8000)
           patterndatasize = 1;
         else
           patterndatasize = 2;

         // Tile
         AddString(outstring, "Tile(%dH x %dV)\r\n", patternwh, patternwh);

         Vdp2GetPlaneSize((Vdp2Regs->PLSZ & 0xC) >> 2, &planew, &planeh);
         AddString(outstring, "Plane Size = %dH x %dV\r\n", planew, planeh);

         // Pattern Name Control stuff
         if (patterndatasize == 2) 
         {
            AddString(outstring, "Pattern Name data size = 2 words\r\n");
         }
         else
         {
            AddString(outstring, "Pattern Name data size = 1 word\r\n");
            AddString(outstring, "Character Number Supplement bit = %d\r\n", (supplementdata >> 14) & 0x1);
            AddString(outstring, "Special Priority bit = %d\r\n", (supplementdata >> 9) & 0x1);
            AddString(outstring, "Special Color Calculation bit = %d\r\n", (supplementdata >> 8) & 0x1);
            AddString(outstring, "Supplementary Palette number = %d\r\n", (supplementdata >> 5) & 0x7);
            AddString(outstring, "Supplementary Color number = %d\r\n", supplementdata & 0x1f);
         }

         map[0] = Vdp2Regs->MPABN1 & 0xFF;
         map[1] = Vdp2Regs->MPABN1 >> 8;
         map[2] = Vdp2Regs->MPCDN1 & 0xFF;
         map[3] = Vdp2Regs->MPCDN1 >> 8;
         outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCN1, (Vdp2Regs->PLSZ & 0xC) >> 2, (Vdp2Regs->MPOFN & 0x70) << 2, 4, map);

/*
         // Figure out Cell start address
         switch(patterndatasize)
         {
            case 1:
            {
               tmp = readWord(vram, addr);

               switch(auxMode)
               {
                  case 0:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0x3FF) | ((supplementdata & 0x1F) << 10);
                           break;
                        case 2:
                           charAddr = ((tmp & 0x3FF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x1C) << 10);
                           break;
                     }
                     break;
                  case 1:
                     switch(patternwh)
                     {
                        case 1:
                           charAddr = (tmp & 0xFFF) | ((supplementdata & 0x1C) << 10);
                           break;
                        case 4:
                           charAddr = ((tmp & 0xFFF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x10) << 10);
                           break;
                     }
                     break;
               }
               break;
            }
            case 2:
            {
               unsigned short tmp1 = readWord(vram, addr);
               unsigned short tmp2 = readWord(vram, addr+2);

               charAddr = tmp2 & 0x7FFF;
               break;
            }
         }
         if (!(readWord(reg, 0x6) & 0x8000))
            charAddr &= 0x3FFF;

         charAddr *= 0x20; // selon Runik
  
         AddString(outstring, "Cell Data Address = %X\r\n", charAddr);
*/
      }
     
/*
      // Screen scroll values
      AddString(outstring, "Screen Scroll x = %f, y = %f\r\n", (float)(reg->getLong(0x80) & 0x7FFFF00) / 65536, (float)(reg->getLong(0x84) & 0x7FFFF00) / 65536);
*/

      // Coordinate Increments
      AddString(outstring, "Coordinate Increments x = %f, y = %f\r\n", (float) 65536 / (Vdp2Regs->ZMXN1.all & 0x7FF00), (float) 65536 / (Vdp2Regs->ZMXN1.all & 0x7FF00));

      // Reduction Enable
      switch ((Vdp2Regs->ZMCTL >> 8) & 3)
      {
         case 1:
            AddString(outstring, "Horizontal Reduction = 1/2\r\n");
            break;
         case 2:
         case 3:
            AddString(outstring, "Horizontal Reduction = 1/4\r\n");
            break;
         default: break;
      }

      if (lineVerticalScrollReg & 0x8)
      {
         AddString(outstring, "Line Zoom X enabled\r\n");
      }

      if (lineVerticalScrollReg & 0x4)
      {
         AddString(outstring, "Line Scroll Vertical enabled\r\n");
      }
   
      if (lineVerticalScrollReg & 0x2)
      {
         AddString(outstring, "Line Scroll Horizontal enabled\r\n");
      }

      if (lineVerticalScrollReg & 0x6) 
      {
         AddString(outstring, "Line Scroll Enabled\r\n");
         AddString(outstring, "Line Scroll Table Address = %08X\r\n", (int)(0x05E00000 + ((Vdp2Regs->LSTA1.all & 0x7FFFE) << 1)));
         switch (lineVerticalScrollReg >> 4)
         {
            case 0:
               AddString(outstring, "Line Scroll Interval = Each Line\r\n");
               break;
            case 1:
               AddString(outstring, "Line Scroll Interval = Every 2 Lines\r\n");
               break;
            case 2:
               AddString(outstring, "Line Scroll Interval = Every 4 Lines\r\n");
               break;
            case 3:
               AddString(outstring, "Line Scroll Interval = Every 8 Lines\r\n");
               break;
         }
      }

      if (lineVerticalScrollReg & 0x1)
      {
         AddString(outstring, "Vertical Cell Scroll enabled\r\n");
         AddString(outstring, "Vertical Cell Scroll Table Address = %08X\r\n", (int)(0x05E00000 + ((Vdp2Regs->VCSTA.all & 0x7FFFE) << 1)));
      }

      // Window Control
      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLA >> 8, 0);

      // Shadow Control here

      // Color Ram Address Offset
      AddString(outstring, "Color Ram Address Offset = %X\r\n", (Vdp2Regs->CRAOFA & 0x70) << 4);

      // Special Priority Mode
      outstring = AddSpecialPriorityInfo(outstring, Vdp2Regs->SFPRMD >> 2);

      // Color Calculation Control here

      // Special Color Calculation Mode here

      // Priority Number
      AddString(outstring, "Priority = %d\r\n", (Vdp2Regs->PRINA >> 8) & 0x7);

      // Color Calculation
      outstring = AddColorCalcInfo(outstring, 0x0002, 0x0004, (Vdp2Regs->CCRNA >> 8) & 0x1F, (Vdp2Regs->SFCCMD >> 2) & 0x3);

      // Color Offset
      outstring = AddColorOffsetInfo(outstring, 0x0002);
      
      AddString(outstring, "Special Color Calculation %d\r\n",(Vdp2Regs->SFCCMD>>2)&0x03);
   }
   else
     // disabled
     *isenabled = 0;
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsNBG2(char *outstring, int *isenabled)
{
   u8 map[4];

   if (Vdp2Regs->BGON & 0x4)
   {
      int patterndatasize;
      u16 supplementdata=Vdp2Regs->PNCN2 & 0x3FF;
      int planew=0, planeh=0;
      int patternwh=(Vdp2Regs->CHCTLB & 0x1) + 1;

      // enabled
      *isenabled = 1;

      // Mosaic
      outstring = AddMosaicString(outstring, 0x4);

      // BPP
      outstring = AddBppString(outstring, (Vdp2Regs->CHCTLB & 0x2) >> 1);

      if(Vdp2Regs->PNCN2 & 0x8000)
         patterndatasize = 1;
      else
         patterndatasize = 2;

      AddString(outstring, "Tile(%dH x %dV)\r\n", patternwh, patternwh);

      Vdp2GetPlaneSize((Vdp2Regs->PLSZ & 0x30) >> 4, &planew, &planeh);
      AddString(outstring, "Plane Size = %dH x %dV\r\n", planew, planeh);

      // Pattern Name Control stuff
      if (patterndatasize == 2) 
      {
         AddString(outstring, "Pattern Name data size = 2 words\r\n");
      }
      else
      {
         AddString(outstring, "Pattern Name data size = 1 word\r\n");
         AddString(outstring, "Character Number Supplement bit = %d\r\n", (supplementdata >> 14) & 0x1);
         AddString(outstring, "Special Priority bit = %d\r\n", (supplementdata >> 9) & 0x1);
         AddString(outstring, "Special Color Calculation bit = %d\r\n", (supplementdata >> 8) & 0x1);
         AddString(outstring, "Supplementary Palette number = %d\r\n", (supplementdata >> 5) & 0x7);
         AddString(outstring, "Supplementary Color number = %d\r\n", supplementdata & 0x1f);
      }
     
      map[0] = Vdp2Regs->MPABN2 & 0xFF;
      map[1] = Vdp2Regs->MPABN2 >> 8;
      map[2] = Vdp2Regs->MPCDN2 & 0xFF;
      map[3] = Vdp2Regs->MPCDN2 >> 8;
      outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCN2, (Vdp2Regs->PLSZ >> 4) & 0x3, (Vdp2Regs->MPOFN & 0x700) >> 2, 4, map);
/*
      // Figure out Cell start address
      switch(patterndatasize)
      {
         case 1:
         {
            tmp = readWord(vram, addr);

            switch(auxMode)
            {
               case 0:
                  switch(patternwh)
                  {
                     case 1:
                        charAddr = (tmp & 0x3FF) | ((supplementdata & 0x1F) << 10);
                        break;
                     case 2:
                        charAddr = ((tmp & 0x3FF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x1C) << 10);
                        break;
                  }
                  break;
               case 1:
                  switch(patternwh)
                  {
                     case 1:
                        charAddr = (tmp & 0xFFF) | ((supplementdata & 0x1C) << 10);
                        break;
                     case 4:
                        charAddr = ((tmp & 0xFFF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x10) << 10);
                        break;
                  }
                  break;
            }
            break;
         }
         case 2:
         {
            unsigned short tmp1 = readWord(vram, addr);
            unsigned short tmp2 = readWord(vram, addr+2);

            charAddr = tmp2 & 0x7FFF;
            break;
         }
      }
      if (!(readWord(reg, 0x6) & 0x8000)) charAddr &= 0x3FFF;

      charAddr *= 0x20; // selon Runik

      AddString(outstring, "Cell Data Address = %X\r\n", charAddr);
*/
      // Screen scroll values
      AddString(outstring, "Screen Scroll x = %d, y = %d\r\n", - ((Vdp2Regs->SCXN2 & 0x7FF) % 512), - ((Vdp2Regs->SCYN2 & 0x7FF) % 512));

      // Window Control
      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLB, 0);

      // Shadow Control here

      // Color Ram Address Offset
      AddString(outstring, "Color Ram Address Offset = %X\r\n", Vdp2Regs->CRAOFA & 0x700);

      // Special Priority Mode
      outstring = AddSpecialPriorityInfo(outstring, Vdp2Regs->SFPRMD >> 4);

      // Color Calculation Control here

      // Special Color Calculation Mode here

      // Priority Number
      AddString(outstring, "Priority = %d\r\n", Vdp2Regs->PRINB & 0x7);
                       
      // Color Calculation
      outstring = AddColorCalcInfo(outstring, 0x0004, 0x0005, Vdp2Regs->CCRNB & 0x1F, (Vdp2Regs->SFCCMD >> 4) & 0x3);

      // Color Offset
      outstring = AddColorOffsetInfo(outstring, 0x0004);
      
      AddString(outstring, "Special Color Calculation %d\r\n",(Vdp2Regs->SFCCMD>>4)&0x03);
   }
   else
   {
     // disabled
     *isenabled = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsNBG3(char *outstring, int *isenabled)
{
   u8 map[4];

   if (Vdp2Regs->BGON & 0x8)
   {
      int patterndatasize;
      u16 supplementdata=Vdp2Regs->PNCN3 & 0x3FF;
      int planew=0, planeh=0;
      int patternwh=((Vdp2Regs->CHCTLB & 0x10) >> 4) + 1;

      // enabled
      *isenabled = 1;

      // Mosaic
      outstring = AddMosaicString(outstring, 0x8);

      // BPP
      outstring = AddBppString(outstring, (Vdp2Regs->CHCTLB & 0x20) >> 5);

      if(Vdp2Regs->PNCN3 & 0x8000)
         patterndatasize = 1;
      else
         patterndatasize = 2;

      AddString(outstring, "Tile(%dH x %dV)\r\n", patternwh, patternwh);

      Vdp2GetPlaneSize((Vdp2Regs->PLSZ & 0xC0) >> 6, &planew, &planeh);
      AddString(outstring, "Plane Size = %dH x %dV\r\n", planew, planeh);

      // Pattern Name Control stuff
      if (patterndatasize == 2) 
      {
         AddString(outstring, "Pattern Name data size = 2 words\r\n");
      }
      else
      {
         AddString(outstring, "Pattern Name data size = 1 word\r\n");
         AddString(outstring, "Character Number Supplement bit = %d\r\n", (supplementdata >> 14) & 0x1);
         AddString(outstring, "Special Priority bit = %d\r\n", (supplementdata >> 9) & 0x1);
         AddString(outstring, "Special Color Calculation bit = %d\r\n", (supplementdata >> 8) & 0x1);
         AddString(outstring, "Supplementary Palette number = %d\r\n", (supplementdata >> 5) & 0x7);
         AddString(outstring, "Supplementary Color number = %d\r\n", supplementdata & 0x1f);
      }

      map[0] = Vdp2Regs->MPABN3 & 0xFF;
      map[1] = Vdp2Regs->MPABN3 >> 8;
      map[2] = Vdp2Regs->MPCDN3 & 0xFF;
      map[3] = Vdp2Regs->MPCDN3 >> 8;
      outstring = AddMapInfo(outstring, patternwh, Vdp2Regs->PNCN3, (Vdp2Regs->PLSZ & 0xC0) >> 6, (Vdp2Regs->MPOFN & 0x7000) >> 6, 4, map);

/*
      // Figure out Cell start address
      switch(patterndatasize)
      {
         case 1:
         {
            tmp = readWord(vram, addr);

            switch(auxMode)
            {
               case 0:
                  switch(patternwh)
                  {
                     case 1:
                        charAddr = (tmp & 0x3FF) | ((supplementdata & 0x1F) << 10);
                        break;
                     case 2:
                        charAddr = ((tmp & 0x3FF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x1C) << 10);
                        break;
                  }
                  break;
               case 1:
                  switch(patternwh)
                  {
                     case 1:
                        charAddr = (tmp & 0xFFF) | ((supplementdata & 0x1C) << 10);
                        break;
                     case 4:
                        charAddr = ((tmp & 0xFFF) << 2) |  (supplementdata & 0x3) | ((supplementdata & 0x10) << 10);
                        break;
                  }
                  break;
            }
            break;
         }
         case 2:
         {
            unsigned short tmp1 = readWord(vram, addr);
            unsigned short tmp2 = readWord(vram, addr+2);

            charAddr = tmp2 & 0x7FFF;
            break;
         }
      }

      if (!(readWord(reg, 0x6) & 0x8000))
         charAddr &= 0x3FFF;

      charAddr *= 0x20; // selon Runik

      AddString(outstring, "Cell Data Address = %X\r\n", charAddr);
*/
      // Screen scroll values
      AddString(outstring, "Screen Scroll x = %d, y = %d\r\n", - ((Vdp2Regs->SCXN3 & 0x7FF) % 512), - ((Vdp2Regs->SCYN3 & 0x7FF) % 512));

      // Window Control
      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLB >> 8, 0);

      // Shadow Control here

      // Color Ram Address Offset
      AddString(outstring, "Color Ram Address Offset = %X\r\n", Vdp2Regs->CRAOFA & 0x7000);

      // Special Priority Mode
      outstring = AddSpecialPriorityInfo(outstring, Vdp2Regs->SFPRMD >> 6);

      // Special Color Calculation Mode here

      // Priority Number
      AddString(outstring, "Priority = %d\r\n", (Vdp2Regs->PRINB >> 8) & 0x7);

      // Color Calculation
      outstring = AddColorCalcInfo(outstring, 0x0008, 0x0006, (Vdp2Regs->CCRNB >> 8) & 0x1F, (Vdp2Regs->SFCCMD >> 6) & 0x3);

      // Color Offset
      outstring = AddColorOffsetInfo(outstring, 0x0008);
      
      AddString(outstring, "Special Color Calculation %d\r\n",(Vdp2Regs->SFCCMD>>6)&0x03);
   }
   else
   {
      // disabled
      *isenabled = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2DebugStatsGeneral(char *outstring, int *isenabled)
{
   u8 *sprprilist = (u8 *)&Vdp2Regs->PRISA;
   u8 *sprccrlist = (u8 *)&Vdp2Regs->CCRSA;
   int i;

   if (Vdp2Regs->TVMD & 0x8000)
   {
      // TVMD stuff
      AddString(outstring, "Border Color Mode = %s\r\n", Vdp2Regs->TVMD & 0x100 ? "Back screen" : "Black");

      AddString(outstring, "Display Resolution = ");
      switch (Vdp2Regs->TVMD & 0x7)
      {
         case 0:
         case 4:
            AddString(outstring, "320");
            break;
         case 1:
         case 5:
            AddString(outstring, "352");
            break;
         case 2:
         case 6:
            AddString(outstring, "640");
            break;                      
         case 3:
         case 7:
            AddString(outstring, "704");
            break;
         default: 
            AddString(outstring, "Invalid");
            break;
      }

      AddString(outstring, " x ");

      switch ((Vdp2Regs->TVMD >> 4) & 0x3)
      {
         case 0:
            AddString(outstring, "224");
            break;
         case 1:
            AddString(outstring, "240");
            break;
         case 2:
            AddString(outstring, "256");
            break;
         default: 
            AddString(outstring, "Invalid");
            break;
      }

      if (Vdp2Regs->TVSTAT & 0x1)
      {
         AddString(outstring, "(PAL)\r\n");
      }
      else
      {
         AddString(outstring, "(NTSC)\r\n");
      }

      AddString(outstring, "Interlace Mode = ");
      switch ((Vdp2Regs->TVMD >> 6) & 0x3)
      {
         case 0:
            AddString(outstring, "Non-Interlace\r\n");
            break;
         case 2:
            AddString(outstring, "Single-Density Interlace\r\n");
            break;
         case 3:
            AddString(outstring, "Double-Density Interlace\r\n");
            break;
         default: 
            AddString(outstring, "Invalid\r\n");
            break;
      }

      // Latch stuff
      AddString(outstring, "Latches HV counter when %s\r\n", Vdp2Regs->EXTEN & 0x200 ? "external signal triggers it" : "external latch flag is read");
      if (Vdp2Regs->EXTEN & 0x100)
      {
         AddString(outstring, "External Sync is being inputed\r\n");
      }

      // Screen status stuff
      if (Vdp2Regs->TVSTAT & 0x200)
      {
         AddString(outstring, "HV is latched\r\n");
      }

      if (Vdp2Regs->TVSTAT & 0x4)
      {
         AddString(outstring, "During H-Blank\r\n");
      }

      if (Vdp2Regs->TVSTAT & 0x8)
      {
         AddString(outstring, "During V-Blank\r\n");
      }

      if ((Vdp2Regs->TVMD >> 6) & 0x2)
      {
         AddString(outstring, "During %s Field\r\n", Vdp2Regs->TVSTAT & 0x2 ? "Odd" : "Even");
      }

      AddString(outstring, "H Counter = %d\r\n", Vdp2Regs->HCNT);
      AddString(outstring, "V Counter = %d\r\n", Vdp2Regs->VCNT);
      AddString(outstring, "\r\n");

      // Line color screen stuff
      AddString(outstring, "Line Color Screen Stuff\r\n");
      AddString(outstring, "-----------------------\r\n");
      AddString(outstring, "Mode = %s\r\n", Vdp2Regs->LCTA.part.U & 0x8000 ? "Color per line" : "Single color");
      AddString(outstring, "Address = %08lX\r\n", 0x05E00000UL | ((Vdp2Regs->LCTA.all & 0x7FFFFUL) * 2));
      AddString(outstring, "\r\n");

      // Back screen stuff
      AddString(outstring, "Back Screen Stuff\r\n");
      AddString(outstring, "-----------------\r\n");
      AddString(outstring, "Mode = %s\r\n", Vdp2Regs->BKTAU & 0x8000 ? "Color per line" : "Single color");
      AddString(outstring, "Address = %08X\r\n", 0x05E00000 | (((Vdp2Regs->BKTAU & 0x7) << 16)  | Vdp2Regs->BKTAL) * 2);
      outstring = AddColorOffsetInfo(outstring, 0x0020);
      AddString(outstring, "\r\n");

      // Cycle patterns here

      // Sprite stuff
      AddString(outstring, "Sprite Stuff\r\n");
      AddString(outstring, "------------\r\n");
      AddString(outstring, "Sprite Type = %X\r\n", Vdp2Regs->SPCTL & 0xF);
      AddString(outstring, "VDP1 Framebuffer Data Format = %s\r\n", Vdp2Regs->SPCTL & 0x20 ? "RGB and palette" : "Palette only");

      if (Vdp2Regs->SDCTL & 0x100)
      {
         AddString(outstring, "Transparent Shadow Enabled\r\n");
      }

      if (Vdp2Regs->SPCTL & 0x20)
      {
         AddString(outstring, "Sprite Window Enabled\r\n");
      }

      outstring = AddWindowInfoString(outstring, Vdp2Regs->WCTLC >> 8, 1);

      AddString(outstring, "Color RAM Offset = %X\r\n", (Vdp2Regs->CRAOFB >> 4) & 0x7);

      if (Vdp2Regs->CCCTL & 0x40)
      {
         AddString(outstring, "Color Calculation Enabled\r\n");

         if (Vdp2Regs->CCCTL & 0x8000 && (Vdp2Regs->CCCTL & 0x0700) == 0)
         {
            AddString(outstring, "Gradation Calculation Enabled\r\n");
         }
         else if (Vdp2Regs->CCCTL & 0x0400)
         {
            AddString(outstring, "Extended Color Calculation Enabled\r\n");
         }
         
         AddString(outstring, "Color Calculation Condition = ");

         switch ((Vdp2Regs->SPCTL >> 12) & 0x3)
         {
             case 0:
                AddString(outstring, "Priority <= CC Condition Number");
                break;
             case 1:
                AddString(outstring, "Priority == CC Condition Number");
                break;
             case 2:
                AddString(outstring, "Priority >= CC Condition Number");
                break;
             case 3:
                AddString(outstring, "Color Data MSB");
                break;
             default: break;
         }
         AddString(outstring, "\r\n");

         if (((Vdp2Regs->SPCTL >> 12) & 0x3) != 0x3)
         {
            AddString(outstring, "Color Calculation Condition Number = %d\r\n", (Vdp2Regs->SPCTL >> 8) & 0x7);
         }

         for (i = 0; i < 8; i++)
         {
#ifdef WORDS_BIGENDIAN
            int ratio = sprccrlist[i ^ 1] & 0x7;
#else
            int ratio = sprccrlist[i] & 0x7;
#endif
            AddString(outstring, "Color Calculation Ratio %d = %d:%d\r\n", i, 31 - ratio, 1 + ratio);
         }
      }

      for (i = 0; i < 8; i++)
      {
#ifdef WORDS_BIGENDIAN
         int priority = sprprilist[i ^ 1] & 0x7;
#else
         int priority = sprprilist[i] & 0x7;
#endif
         AddString(outstring, "Priority %d = %d\r\n", i, priority);
      }

      outstring = AddColorOffsetInfo(outstring, 0x0040);
      *isenabled = 1;
   }
   else
   {
      *isenabled = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DoNothing(UNUSED void *info, u32 pixel)
{
   return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static void ClearTextureToColor(u32 *texture, u32 color, int w, int h)
{
   int i;
   
   for (i = 0; i < (w * h); i++)
      texture[i] = color;
}

//////////////////////////////////////////////////////////////////////////////

pixel_t *Vdp2DebugTexture(u32 screen, int * w, int * h)
{
   pixel_t * bitmap;

   TitanInit();
   VIDSoftVdp2DrawScreen(screen);

   if ((bitmap = (pixel_t *)calloc(sizeof(pixel_t), 704 * 512)) == NULL)
      return NULL;

   TitanGetResolution(w, h);

   TitanRender(bitmap);

   return bitmap;
}

//////////////////////////////////////////////////////////////////////////////

