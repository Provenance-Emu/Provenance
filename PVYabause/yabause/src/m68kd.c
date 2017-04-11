/*  Copyright 2005 Theo Berkau

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

/*! \file m68kd.c
    \brief 68000 disassembler function.
*/

#include "core.h"
#include "m68kd.h"
#include "scsp.h"  // for c68k_word_read()

typedef struct
{
   u16 mask;
   u16 inst;
   const char *name;
   int (*disasm)(u32, u16, char *);
} m68kdis_struct;

//////////////////////////////////////////////////////////////////////////////

static int setsizestr(u16 size, char *outstring)
{
   switch (size & 0x3)
   {
      case 0x1:
         return sprintf(outstring, ".b ");
      case 0x3:
         return sprintf(outstring, ".w ");
      case 0x2:
         return sprintf(outstring, ".l ");
      default:
         return sprintf(outstring, " ");
   }
}

//////////////////////////////////////////////////////////////////////////////

static int setsizestr2(u16 size, char *outstring)
{
   switch (size & 0x3)
   {
      case 0x0:
         return sprintf(outstring, ".b ");
      case 0x1:
         return sprintf(outstring, ".w ");
      case 0x2:
         return sprintf(outstring, ".l ");
      default:
         return sprintf(outstring, " ");
   }
}

//////////////////////////////////////////////////////////////////////////////

static int setimmstr(u32 addr, u16 size, int *addsize, char *outstring)
{
   switch (size & 0x3)
   {
      case 0x0:
         *addsize+=2;
         return sprintf(outstring, "#0x%X", (unsigned int)(c68k_word_read(addr) & 0xFF));
      case 0x1:
         *addsize+=2;
         return sprintf(outstring, "#0x%X", (unsigned int)c68k_word_read(addr));
      case 0x2:
         *addsize+=4;
         return sprintf(outstring, "#0x%X", (unsigned int)((c68k_word_read(addr) << 16) | c68k_word_read(addr+2)));
      default:
         return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static int seteafieldstr(u32 addr, u16 modereg, int *addsize, char *outstring)
{
   switch ((modereg >> 3) & 0x7)
   {
      case 0x0:
         // Dn         
         return sprintf(outstring, "d%d", modereg & 0x7);
      case 0x1:
         // An         
         return sprintf(outstring, "a%d", modereg & 0x7);
      case 0x2:
         // (An)         
         return sprintf(outstring, "(a%d)", modereg & 0x7);
      case 0x3:
         // (An)+         
         return sprintf(outstring, "(a%d)+", modereg & 0x7);
      case 0x4:
         // -(An)         
         return sprintf(outstring, "-(a%d)", modereg & 0x7);
      case 0x5:
         // (d16, An)
         *addsize += 2;         
         return sprintf(outstring, "0x%X(a%d)", (unsigned int)c68k_word_read(addr), modereg & 0x7);
      case 0x6:
         // (d8,An,Xn)
         // fix me
         *addsize += 2;         
         return sprintf(outstring, "0x%X(a%d, Xn)", (unsigned int)(c68k_word_read(addr) & 0xFF), modereg & 0x7);
      case 0x7:
         switch (modereg & 0x7)
         {
            case 0x0:
               // (xxx).W
               *addsize += 2; // fix me?
               return sprintf(outstring, "(0x%X).w", (unsigned int)c68k_word_read(addr));
            case 0x1:
               // (xxx).L
               *addsize += 4; // fix me?
               return sprintf(outstring, "(0x%X).l", (unsigned int)((c68k_word_read(addr) << 16) | c68k_word_read(addr+2)));
            case 0x4:
               // #<data>
               *addsize += 2; // fix me?
               return sprintf(outstring, "#0x%X", (unsigned int)c68k_word_read(addr));
            case 0x2:
               // (d16,PC)
               *addsize += 2;               
               return sprintf(outstring, "0x%X(PC)", (unsigned int)c68k_word_read(addr));
            case 0x3:
               // (d8,PC,Xn)
               // fix me
               return 0;
            default: break;
         }
      default: break;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int setcondstr(u16 cond, char *outstring)
{
   switch (cond & 0xF)
   {
      case 0x0:
         // True
         return sprintf(outstring, "t ");
      case 0x1:
         // False
         return sprintf(outstring, "f ");
      case 0x2:
         // High
         return sprintf(outstring, "hi");
      case 0x3:
         // Low or Same
         return sprintf(outstring, "ls");
      case 0x4:
         // Carry Clear
         return sprintf(outstring, "cc");
      case 0x5:
         // Carry Set
         return sprintf(outstring, "cs");
      case 0x6:
         // Not Equal
         return sprintf(outstring, "ne");
      case 0x7:
         // Equal
         return sprintf(outstring, "eq");
      case 0x8:
         // Overflow Clear
         return sprintf(outstring, "vc");
      case 0x9:
         // Overflow Set
         return sprintf(outstring, "vs");
      case 0xA:
         // Plus
         return sprintf(outstring, "pl");
      case 0xB:
         // Minus
         return sprintf(outstring, "mi");
      case 0xC:
         // Greater or Equal
         return sprintf(outstring, "ge");
      case 0xD:
         // Less Than
         return sprintf(outstring, "lt");
      case 0xE:
         // Greater Than
         return sprintf(outstring, "gt");
      case 0xF:
         // Less or Equal
         return sprintf(outstring, "le");
      default: break;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int setbranchdispstr(u32 addr, u16 op, int *addsize, char *outstring)
{
   if ((op & 0xFF) == 0xFF)
   {
      // 32-bit displacement
      *addsize += 4;
      return sprintf(outstring, ".l   %X", (unsigned int)(addr + ((c68k_word_read(addr) << 16) |  c68k_word_read(addr+2))));
   }
   else if ((op & 0xFF) == 0x00)
   {
      // 16-bit displacement
      *addsize += 2;
      return sprintf(outstring, ".w   %X", (unsigned int)((s32)addr + (s32)(s16)c68k_word_read(addr)));
   }

   // 8-bit displacement
   return sprintf(outstring, ".s   %X", (unsigned int)((s32)addr + (s32)(s8)(op & 0xFF)));
}

//////////////////////////////////////////////////////////////////////////////

static int disabcd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "abcd");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disadd(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "add");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += sprintf(outstring, "  ");

   if (op & 0x100)
   {
      // Dn, <ea>
      outstring += sprintf(outstring, "d%d, ", (op >> 9) & 7);
      seteafieldstr(addr+size, op, &size, outstring);
   }
   else
   {
      // <ea>, Dn
      outstring += seteafieldstr(addr+size, op, &size, outstring);
      sprintf(outstring, ", d%d", (op >> 9) & 7);
   }

   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disadda(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "adda");
   if ((op & 0x1C0) == 0xC0)
      outstring += sprintf(outstring, ".w  ");
   else
      outstring += sprintf(outstring, ".l  ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", a%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disaddi(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "addi");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += setimmstr(addr+size, op >> 6, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disaddq(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "addq");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += sprintf(outstring, " ");
   outstring += sprintf(outstring, "#%d, ", (op >> 9) & 7); // fix me
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disaddx(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "addx");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disand(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "and");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disandi(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "andi");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += sprintf(outstring, " ");
   outstring += setimmstr(addr+size, op >> 6, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disanditoccr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "andi to CCR");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disasl(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "asl");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disasr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "asr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbcc(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "b");
   outstring += setcondstr(op >> 8, outstring);
   setbranchdispstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbkpt(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bkpt");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbra(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bra");
   setbranchdispstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbchg(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bchg");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbclrd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bclr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbclrs(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bclr    ");
   outstring += setimmstr(addr+size, 0, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbsetd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bset");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbsets(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bset    ");
   outstring += setimmstr(addr+size, 0, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbtstd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "btst");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbtsts(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "btst    ");
   outstring += setimmstr(addr+size, 0, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disbsr(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "bsr");
   setbranchdispstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dischk(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "chk");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disclr(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "clr");
   outstring += setsizestr2((op >> 6), outstring);
   outstring += sprintf(outstring, "  ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disdbcc(u32 addr, u16 op, char *outstring)
{
   outstring += sprintf(outstring, "db");
   outstring += setcondstr(op >> 8, outstring);
   outstring += sprintf(outstring, "   ");
   sprintf(outstring, " d%d, %X", op & 0x7, (unsigned int)((s32)addr+2+(s32)(s16)c68k_word_read(addr+2)));
   return 4;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpb(u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "cmp.b   ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", d%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpw(u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "cmp.w   ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", d%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpl(u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "cmp.l   ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", d%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpaw(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "cmpa.w");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpal(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "cmpa.l");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpi(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "cmpi");
   outstring += setsizestr2((op >> 6), outstring);
   outstring += sprintf(outstring, " ");
   outstring += setimmstr(addr+size, op >> 6, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disdivs(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "divs.w");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disdivu(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "divu.w");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int discmpm(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "cmpm");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int diseorb(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "eor.b");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int diseorw(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "eor.w");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int diseorl(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "eor.l");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int diseori(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "eori");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int diseoritoccr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "eori to ccr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disexg(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "exg");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disext(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "ext");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disillegal(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   sprintf(outstring, "illegal");
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int disjmp(u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "jmp ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disjsr(u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "jsr     ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dislea(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "lea     ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", a%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dislink(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "link");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dislsl(UNUSED u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "lsl");
   outstring += setsizestr2(op >> 6, outstring);
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dislsr(UNUSED u32 addr, u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "lsr");
   outstring += setsizestr2(op >> 6, outstring);
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismove(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "move");
   outstring += setsizestr((op >> 12), outstring);
   outstring += sprintf(outstring, " ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, ((op >> 3) & 0x38) | ((op >> 9) & 0x7), &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovea(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "movea");
   outstring += setsizestr((op >> 12), outstring);
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   outstring += sprintf(outstring, ", a%d", (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovetoccr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "move to ccr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovefromsr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "move from sr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovetosr(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "move    ");
   outstring += seteafieldstr(addr+size, op, &size, outstring);
   sprintf(outstring, ", sr");
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovem(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   outstring += sprintf(outstring, "movem");
   // fix me
   return 4;
}

//////////////////////////////////////////////////////////////////////////////

static int dismovep(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "movep");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismoveq(UNUSED u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "moveq   #0x%X, d%d", op & 0xFF, (op >> 9) & 0x7);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismuls(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "muls");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dismulu(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "mulu");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disnbcd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "nbcd");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disneg(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "neg");
   outstring += setsizestr2((op >> 6), outstring);
   outstring += sprintf(outstring, "  ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disnegx(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "negx");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disnop(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   sprintf(outstring, "nop");
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int disnot(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "not");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disor(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "ori to CCR");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disori(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "ori");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disoritoccr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "ori to CCR");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dispea(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "pea");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disrol(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "rol");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disror(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "ror");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disroxl(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "roxl");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disroxr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "roxr");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disrtr(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   sprintf(outstring, "rtr");
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int disrts(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   sprintf(outstring, "rts");
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int dissbcd(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "sbcd");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disscc(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "scc");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dissub(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "sub");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dissuba(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "suba");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dissubi(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "subi");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += sprintf(outstring, " ");
   outstring += setimmstr(addr+size, op >> 6, &size, outstring);
   outstring += sprintf(outstring, ", ");
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dissubq(u32 addr, u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "subq");
   outstring += setsizestr2(op >> 6, outstring);
   outstring += sprintf(outstring, " #%d, ", (op >> 9) & 7); // fix me
   seteafieldstr(addr+size, op, &size, outstring);
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int dissubx(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "subx");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disswap(UNUSED u32 addr, u16 op, char *outstring)
{
   sprintf(outstring, "swap d%d", op & 0x7);
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int distas(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "tas");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int distrap(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "trap");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int distrapv(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   sprintf(outstring, "trapv");
   return 2;
}

//////////////////////////////////////////////////////////////////////////////

static int distst(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;

   outstring += sprintf(outstring, "tst");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static int disunlk(UNUSED u32 addr, UNUSED u16 op, char *outstring)
{
   int size=2;
   outstring += sprintf(outstring, "unlk");
   // fix me
   return size;
}

//////////////////////////////////////////////////////////////////////////////

static m68kdis_struct instruction[] = {
   { 0xFFFF, 0x023C, "andi #??, CCR", disanditoccr },
   { 0xFFFF, 0x0A3C, "eori #??, CCR", diseoritoccr },
   { 0xFFFF, 0x4AFC, "illegal", disillegal },
   { 0xFFFF, 0x4E71, "nop", disnop },
   { 0xFFFF, 0x003C, "ori #??, CCR", disoritoccr },
   { 0xFFFF, 0x4E77, "rtr", disrtr },
   { 0xFFFF, 0x4E75, "rts", disrts },
   { 0xFFFF, 0x4E76, "trapv", distrapv },
   { 0xFFF8, 0x4848, "bkpt", disbkpt },
   { 0xFFF8, 0x4E50, "link", dislink },
   { 0xFFF8, 0x4840, "swap", disswap },
   { 0xFFF8, 0x4E58, "unlk", disunlk },
   { 0xFFF0, 0x4E40, "trap", distrap },
   { 0xF1F8, 0xD100, "addx.b", disaddx },
   { 0xF1F8, 0xD140, "addx.w", disaddx },
   { 0xF1F8, 0xD180, "addx.l", disaddx },
   { 0xF1F8, 0xB108, "cmpm.b", discmpm },
   { 0xF1F8, 0xB148, "cmpm.w", discmpm },
   { 0xF1F8, 0xB188, "cmpm.l", discmpm },
   { 0xFFC0, 0xE1C0, "asl", disasl },
   { 0xFFC0, 0xE0C0, "asr", disasr },
   { 0xFFC0, 0x0880, "bclr", disbclrs },
   { 0xFFC0, 0x08C0, "bset", disbsets },
   { 0xFFC0, 0x0800, "btst", disbtsts },
   { 0xFFC0, 0x4EC0, "jmp", disjmp },
   { 0xFFC0, 0x4E80, "jsr", disjsr },
   { 0xFFC0, 0x44C0, "move ??, CCR", dismovetoccr },
   { 0xFFC0, 0x40C0, "move SR, ??", dismovefromsr },
   { 0xFFC0, 0x46C0, "move ??, SR", dismovetosr },
   { 0xFFC0, 0x4800, "nbcd", disnbcd },
   { 0xFFC0, 0x4840, "pea", dispea },
   { 0xFFC0, 0x4AC0, "tas", distas },
   { 0xFE38, 0x4800, "ext", disext },
   { 0xF1F0, 0xC100, "abcd", disabcd },
   { 0xF1F0, 0x8100, "sbcd", dissbcd },
   { 0xF0F8, 0x50C8, "dbcc", disdbcc },
   { 0xFB80, 0x4880, "movem", dismovem },
   { 0xFF00, 0x0600, "addi", disaddi },
   { 0xFF00, 0x0200, "andi", disandi },
   { 0xFF00, 0x6000, "bra", disbra },
   { 0xFF00, 0x6100, "bsr", disbsr },
   { 0xFF00, 0x4200, "clr", disclr },
   { 0xFF00, 0x0C00, "cmpi", discmpi },
   { 0xFF00, 0x0A00, "eori", diseori },
   { 0xFF00, 0x4400, "neg", disneg },
   { 0xFF00, 0x4000, "negx", disnegx },
   { 0xFF00, 0x4600, "not", disnot },
   { 0xFF00, 0x0000, "ori", disori },
   { 0xFF00, 0x0400, "subi", dissubi },
   { 0xFF00, 0x4A00, "tst", distst },
   { 0xF118, 0xE108, "lsl", dislsl },
   { 0xF118, 0xE008, "lsr", dislsr },
   { 0xF118, 0xE118, "rol", disrol },
   { 0xF118, 0xE018, "ror", disror },
   { 0xF118, 0xE110, "roxl", disroxl },
   { 0xF118, 0xE010, "roxr", disroxr },
   { 0xF1C0, 0xD0C0, "adda.w", disadda },
   { 0xF1C0, 0xD1C0, "adda.l", disadda },
   { 0xF1C0, 0x0140, "bchg", disbchg },
   { 0xF1C0, 0x0180, "bclr", disbclrd },
   { 0xF1C0, 0x01C0, "bset", disbsetd },
   { 0xF1C0, 0x0100, "btst", disbtstd },
   { 0xF1C0, 0xB000, "cmp.b", discmpb },
   { 0xF1C0, 0xB040, "cmp.w", discmpw },
   { 0xF1C0, 0xB080, "cmp.l", discmpl },
   { 0xF1C0, 0xB0C0, "cmpa.w", discmpaw },
   { 0xF1C0, 0xB1C0, "cmpa.l", discmpal },
   { 0xF1C0, 0x81C0, "divs.w", disdivs },
   { 0xF1C0, 0x80C0, "divu.w", disdivu },
   { 0xF1C0, 0xB100, "eor.b", diseorb },
   { 0xF1C0, 0xB140, "eor.w", diseorw },
   { 0xF1C0, 0xB180, "eor.l", diseorl },
   { 0xF1C0, 0x41C0, "lea", dislea },
   { 0xF1C0, 0xC1C0, "muls", dismuls },
   { 0xF1C0, 0xC0C0, "mulu", dismulu },
   { 0xF130, 0x9100, "subx", dissubx },
   { 0xF038, 0x0008, "movep", dismovep },
   { 0xF0C0, 0x50C0, "scc", disscc },
   { 0xC1C0, 0x0040, "movea", dismovea },
   { 0xF040, 0x4000, "chk", dischk },
   { 0xF100, 0x5000, "addq", disaddq },
   { 0xF100, 0xC100, "exg", disexg },
   { 0xF100, 0x7000, "moveq", dismoveq },
   { 0xF100, 0x5100, "subq", dissubq },
   { 0xF000, 0xD000, "add", disadd }, // fix me
   { 0xF000, 0xC000, "and", disand },
   { 0xF000, 0x6000, "bcc", disbcc },
   { 0xF000, 0x8000, "or", disor },
   { 0xF000, 0x9000, "sub", dissub }, // fix me
   { 0xF000, 0x9000, "suba", dissuba }, // fix me
   { 0xC000, 0x0000, "move", dismove },
   { 0x0000, 0x0000, NULL, NULL }
};

//////////////////////////////////////////////////////////////////////////////

u32 M68KDisasm(u32 addr, char *outstring)
{
   int i;

   outstring += sprintf(outstring, "%05X: ", (unsigned int)addr);

   for (i = 0; instruction[i].name != NULL; i++)
   {
      u16 op = (u16)c68k_word_read(addr);

      if ((op & instruction[i].mask) == instruction[i].inst)
      {
         addr += instruction[i].disasm(addr, op, outstring);
         return addr;
      }
   }

   sprintf(outstring, "unknown");
   return (addr+2);
}

//////////////////////////////////////////////////////////////////////////////
