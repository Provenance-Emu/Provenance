/*  Copyright 2003-2006 Guillaume Duhamel
    Copyright 2004-2007 Theo Berkau

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

/*! \file vidshared.c
    \brief Functions shared between opengl and software video renderers.
*/

#include "ygl.h"
#include "vidshared.h"
#include "vdp2.h"
#include "debug.h"

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2NBG0PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x7) << 6;
   u32 tmp=0;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN0 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN0 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN0 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN0 >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2NBG1PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x70) << 2;
   u32 tmp=0;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN1 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN1 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN1 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN1 >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2NBG2PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x700) >> 2;
   u32 tmp=0;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN2 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN2 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN2 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN2 >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2NBG3PlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFN & 0x7000) >> 6;
   u32 tmp=0;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABN3 & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABN3 >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDN3 & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDN3 >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2ReadRotationTable(int which, vdp2rotationparameter_struct *parameter)
{
   s32 i;
   u32 addr;

   addr = Vdp2Regs->RPTA.all << 1;

   if (which == 0)
   {
      // Rotation Parameter A
      addr &= 0x000FFF7C;
      parameter->coefenab = Vdp2Regs->KTCTL & 0x1;
      parameter->screenover = (Vdp2Regs->PLSZ >> 10) & 0x3;
   }
   else
   {
      // Rotation Parameter B
      addr = (addr & 0x000FFFFC) | 0x00000080;
      parameter->coefenab = Vdp2Regs->KTCTL & 0x100;
      parameter->screenover = (Vdp2Regs->PLSZ >> 14) & 0x3;
   }

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Xst = (float) (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Yst = (float) (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Zst = (float) (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaXst = (float) (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaYst = (float) (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaX = (float) (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaY = (float) (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->A = (float) (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->B = (float) (signed) ((i & 0x000FFFC0) | ((i & 0x00080000) ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->C = (float) (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->D = (float) (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->E = (float) (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->F = (float) (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Px = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Py = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Pz = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cx = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cy = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cz = (float) (signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Mx = (float) (signed) ((i & 0x3FFFFFC0) | (i & 0x20000000 ? 0xE0000000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->My = (float) (signed) ((i & 0x3FFFFFC0) | (i & 0x20000000 ? 0xE0000000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->kx = (float) (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000)) / 65536;
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->ky = (float) (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000)) / 65536;
   addr += 4;

   if (parameter->coefenab)
   {
      // Read in coefficient values
      i = T1ReadLong(Vdp2Ram, addr);
      parameter->KAst = (float)(unsigned)(i & 0xFFFFFFC0) / 65536;
      addr += 4;

      i = T1ReadLong(Vdp2Ram, addr);
      parameter->deltaKAst = (float) (signed) ((i & 0x03FFFFC0) | (i & 0x02000000 ? 0xFE000000 : 0x00000000)) / 65536;
      addr += 4;     

      i = T1ReadLong(Vdp2Ram, addr);
      parameter->deltaKAx = (float) (signed) ((i & 0x03FFFFC0) | (i & 0x02000000 ? 0xFE000000 : 0x00000000)) / 65536;
      addr += 4;

      if (which == 0)
      {
         parameter->coefdatasize = (Vdp2Regs->KTCTL & 0x2 ? 2 : 4);
         parameter->coeftbladdr = ((Vdp2Regs->KTAOF & 0x7) * 0x10000 + (int)(parameter->KAst)) * parameter->coefdatasize;
         parameter->coefmode = (Vdp2Regs->KTCTL >> 2) & 0x3;
      }
      else
      {
         parameter->coefdatasize = (Vdp2Regs->KTCTL & 0x200 ? 2 : 4);
         parameter->coeftbladdr = (((Vdp2Regs->KTAOF >> 8) & 0x7) * 0x10000 + (int)(parameter->KAst)) * parameter->coefdatasize;
         parameter->coefmode = (Vdp2Regs->KTCTL >> 10) & 0x3;
      }
   }
   

   VDP2LOG("Xst: %f, Yst: %f, Zst: %f, deltaXst: %f deltaYst: %f deltaX: %f\n"
       "deltaY: %f A: %f B: %f C: %f D: %f E: %f F: %f Px: %f Py: %f Pz: %f\n"
       "Cx: %f Cy: %f Cz: %f Mx: %f My: %f kx: %f ky: %f KAst: %f\n"
       "deltaKAst: %f deltaKAx: %f kadr %08X\n", 
       parameter->Xst, parameter->Yst, parameter->Zst, parameter->deltaXst,
       parameter->deltaYst, parameter->deltaX, parameter->deltaY,
       parameter->A, parameter->B, parameter->C, parameter->D, parameter->E,
       parameter->F, parameter->Px, parameter->Py, parameter->Pz,
       parameter->Cx, parameter->Cy, parameter->Cz, parameter->Mx,
       parameter->My, parameter->kx, parameter->ky, parameter->KAst,
       parameter->deltaKAst, parameter->deltaKAx,parameter->coeftbladdr);
}

//////////////////////////////////////////////////////////////////////////////

void Vdp2ReadRotationTableFP(int which, vdp2rotationparameterfp_struct *parameter)
{
   s32 i;
   u32 addr;

   addr = Vdp2Regs->RPTA.all << 1;

   if (which == 0)
   {
      // Rotation Parameter A
      addr &= 0x000FFF7C;
      parameter->coefenab = Vdp2Regs->KTCTL & 0x1;
      parameter->screenover = (Vdp2Regs->PLSZ >> 10) & 0x3;
   }
   else
   {
      // Rotation Parameter B
      addr = (addr & 0x000FFFFC) | 0x00000080;
      parameter->coefenab = Vdp2Regs->KTCTL & 0x100;
      parameter->screenover = (Vdp2Regs->PLSZ >> 14) & 0x3;
   }

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Xst = (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Yst = (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Zst = (signed) ((i & 0x1FFFFFC0) | (i & 0x10000000 ? 0xF0000000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaXst = (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaYst = (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaX = (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->deltaY = (signed) ((i & 0x0007FFC0) | (i & 0x00040000 ? 0xFFFC0000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->A = (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->B = (signed) ((i & 0x000FFFC0) | ((i & 0x00080000) ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->C = (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->D = (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->E = (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->F = (signed) ((i & 0x000FFFC0) | (i & 0x00080000 ? 0xFFF80000 : 0x00000000));
   addr += 4;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Px = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Py = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Pz = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 4;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cx = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cy = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 2;

   i = T1ReadWord(Vdp2Ram, addr);
   parameter->Cz = tofixed((signed) ((i & 0x3FFF) | (i & 0x2000 ? 0xFFF80000 : 0x00000000)));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->Mx = (signed) ((i & 0x3FFFFFC0) | (i & 0x20000000 ? 0xE0000000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->My = (signed) ((i & 0x3FFFFFC0) | (i & 0x20000000 ? 0xE0000000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->kx = (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000));
   addr += 4;

   i = T1ReadLong(Vdp2Ram, addr);
   parameter->ky = (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000));
   addr += 4;

   if (parameter->coefenab)
   {
      // Read in coefficient values
      i = T1ReadLong(Vdp2Ram, addr);
      parameter->KAst = (unsigned)(i & 0xFFFFFFC0);
      addr += 4;

      i = T1ReadLong(Vdp2Ram, addr);
      parameter->deltaKAst = (signed) ((i & 0x03FFFFC0) | (i & 0x02000000 ? 0xFE000000 : 0x00000000));
      addr += 4;     

      i = T1ReadLong(Vdp2Ram, addr);
      parameter->deltaKAx = (signed) ((i & 0x03FFFFC0) | (i & 0x02000000 ? 0xFE000000 : 0x00000000));
      addr += 4;

      if (which == 0)
      {
         parameter->coefdatasize = (Vdp2Regs->KTCTL & 0x2 ? 2 : 4);
         parameter->coeftbladdr = ((Vdp2Regs->KTAOF & 0x7) * 0x10000 + touint(parameter->KAst)) * parameter->coefdatasize;
         parameter->coefmode = (Vdp2Regs->KTCTL >> 2) & 0x3;
      }
      else
      {
         parameter->coefdatasize = (Vdp2Regs->KTCTL & 0x200 ? 2 : 4);
         parameter->coeftbladdr = (((Vdp2Regs->KTAOF >> 8) & 0x7) * 0x10000 + touint(parameter->KAst)) * parameter->coefdatasize;
         parameter->coefmode = (Vdp2Regs->KTCTL >> 10) & 0x3;
      }
   }

   VDP2LOG("Xst: %f, Yst: %f, Zst: %f, deltaXst: %f deltaYst: %f deltaX: %f\n"
       "deltaY: %f A: %f B: %f C: %f D: %f E: %f F: %f Px: %f Py: %f Pz: %f\n"
       "Cx: %f Cy: %f Cz: %f Mx: %f My: %f kx: %f ky: %f KAst: %f\n"
       "deltaKAst: %f deltaKAx: %f\n", 
       tofloat(parameter->Xst), tofloat(parameter->Yst),
       tofloat(parameter->Zst), tofloat(parameter->deltaXst),
       tofloat(parameter->deltaYst), tofloat(parameter->deltaX),
       tofloat(parameter->deltaY), tofloat(parameter->A),
       tofloat(parameter->B), tofloat(parameter->C), tofloat(parameter->D),
       tofloat(parameter->E), tofloat(parameter->F), tofloat(parameter->Px),
       tofloat(parameter->Py), tofloat(parameter->Pz), tofloat(parameter->Cx),
       tofloat(parameter->Cy), tofloat(parameter->Cz), tofloat(parameter->Mx),
       tofloat(parameter->My), tofloat(parameter->kx),
       tofloat(parameter->ky), tofloat(parameter->KAst),
       tofloat(parameter->deltaKAst), tofloat(parameter->deltaKAx));
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2ParameterAPlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFR & 0x7) << 6;
   u32 tmp=0;

   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABRA & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABRA >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDRA & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDRA >> 8);
         break;
      case 4:
         tmp = offset | (Vdp2Regs->MPEFRA & 0xFF);
         break;
      case 5:
         tmp = offset | (Vdp2Regs->MPEFRA >> 8);
         break;
      case 6:
         tmp = offset | (Vdp2Regs->MPGHRA & 0xFF);
         break;
      case 7:
         tmp = offset | (Vdp2Regs->MPGHRA >> 8);
         break;
      case 8:
         tmp = offset | (Vdp2Regs->MPIJRA & 0xFF);
         break;
      case 9:
         tmp = offset | (Vdp2Regs->MPIJRA >> 8);
         break;
      case 10:
         tmp = offset | (Vdp2Regs->MPKLRA & 0xFF);
         break;
      case 11:
         tmp = offset | (Vdp2Regs->MPKLRA >> 8);
         break;
      case 12:
         tmp = offset | (Vdp2Regs->MPMNRA & 0xFF);
         break;
      case 13:
         tmp = offset | (Vdp2Regs->MPMNRA >> 8);
         break;
      case 14:
         tmp = offset | (Vdp2Regs->MPOPRA & 0xFF);
         break;
      case 15:
         tmp = offset | (Vdp2Regs->MPOPRA >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp2ParameterBPlaneAddr(vdp2draw_struct *info, int i)
{
   u32 offset = (Vdp2Regs->MPOFR & 0x70) << 2;
   u32 tmp=0;

   // Parameter B
   switch(i)
   {
      case 0:
         tmp = offset | (Vdp2Regs->MPABRB & 0xFF);
         break;
      case 1:
         tmp = offset | (Vdp2Regs->MPABRB >> 8);
         break;
      case 2:
         tmp = offset | (Vdp2Regs->MPCDRB & 0xFF);
         break;
      case 3:
         tmp = offset | (Vdp2Regs->MPCDRB >> 8);
         break;
      case 4:
         tmp = offset | (Vdp2Regs->MPEFRB & 0xFF);
         break;
      case 5:
         tmp = offset | (Vdp2Regs->MPEFRB >> 8);
         break;
      case 6:
         tmp = offset | (Vdp2Regs->MPGHRB & 0xFF);
         break;
      case 7:
         tmp = offset | (Vdp2Regs->MPGHRB >> 8);
         break;
      case 8:
         tmp = offset | (Vdp2Regs->MPIJRB & 0xFF);
         break;
      case 9:
         tmp = offset | (Vdp2Regs->MPIJRB >> 8);
         break;
      case 10:
         tmp = offset | (Vdp2Regs->MPKLRB & 0xFF);
         break;
      case 11:
         tmp = offset | (Vdp2Regs->MPKLRB >> 8);
         break;
      case 12:
         tmp = offset | (Vdp2Regs->MPMNRB & 0xFF);
         break;
      case 13:
         tmp = offset | (Vdp2Regs->MPMNRB >> 8);
         break;
      case 14:
         tmp = offset | (Vdp2Regs->MPOPRB & 0xFF);
         break;
      case 15:
         tmp = offset | (Vdp2Regs->MPOPRB >> 8);
         break;
   }

   CalcPlaneAddr(info, tmp);
}

//////////////////////////////////////////////////////////////////////////////

float Vdp2ReadCoefficientMode0_2(vdp2rotationparameter_struct *parameter, u32 addr)
{
   s32 i;

   if (parameter->coefdatasize == 2)
   {
      addr &= 0x7FFFE;
      i = T1ReadWord(Vdp2Ram, addr);
      parameter->msb = (i >> 15) & 0x1;
      return (float) (signed) ((i & 0x7FFF) | (i & 0x4000 ? 0xFFFFC000 : 0x00000000)) / 1024;
   }
   else
   {
      addr &= 0x7FFFC;
      i = T1ReadLong(Vdp2Ram, addr);
      parameter->msb = (i >> 31) & 0x1;
      return (float) (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000)) / 65536;
   }
}

//////////////////////////////////////////////////////////////////////////////

fixed32 Vdp2ReadCoefficientMode0_2FP(vdp2rotationparameterfp_struct *parameter, u32 addr)
{
   s32 i;

   if (parameter->coefdatasize == 2)
   {
      addr &= 0x7FFFE;
      i = T1ReadWord(Vdp2Ram, addr);
      parameter->msb = (i >> 15) & 0x1;
      return (signed) ((i & 0x7FFF) | (i & 0x4000 ? 0xFFFFC000 : 0x00000000)) * 64;
   }
   else
   {
      addr &= 0x7FFFC;
      i = T1ReadLong(Vdp2Ram, addr);
      parameter->linescreen = (i >> 24) & 0x7F;
      parameter->msb = (i >> 31) & 0x1;
      return (signed) ((i & 0x00FFFFFF) | (i & 0x00800000 ? 0xFF800000 : 0x00000000));
   }
}

//////////////////////////////////////////////////////////////////////////////
