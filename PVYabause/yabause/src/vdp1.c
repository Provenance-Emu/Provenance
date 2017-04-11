/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2004 Lawrence Sebald
    Copyright 2004-2006 Theo Berkau

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

/*! \file vdp1.c
    \brief VDP1 emulation functions.
*/


#include <stdlib.h>
#include "vdp1.h"
#include "debug.h"
#include "scu.h"
#include "vdp2.h"

u8 * Vdp1Ram;
u8 * Vdp1FrameBuffer;

VideoInterface_struct *VIDCore=NULL;
extern VideoInterface_struct *VIDCoreList[];

//////////////////////////////////////////////////////////////////////////////

u8 FASTCALL Vdp1RamReadByte(u32 addr) {
   addr &= 0x7FFFF;
   return T1ReadByte(Vdp1Ram, addr);
}

//////////////////////////////////////////////////////////////////////////////

u16 FASTCALL Vdp1RamReadWord(u32 addr) {
   addr &= 0x7FFFF;
   return T1ReadWord(Vdp1Ram, addr);
}

//////////////////////////////////////////////////////////////////////////////

u32 FASTCALL Vdp1RamReadLong(u32 addr) {
   addr &= 0x7FFFF;
   return T1ReadLong(Vdp1Ram, addr);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1RamWriteByte(u32 addr, u8 val) {
   addr &= 0x7FFFF;
   T1WriteByte(Vdp1Ram, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1RamWriteWord(u32 addr, u16 val) {
   addr &= 0x7FFFF;
   T1WriteWord(Vdp1Ram, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1RamWriteLong(u32 addr, u32 val) {
   addr &= 0x7FFFF;
   T1WriteLong(Vdp1Ram, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

u8 FASTCALL Vdp1FrameBufferReadByte(u32 addr) {
   addr &= 0x3FFFF;
   return T1ReadByte(Vdp1FrameBuffer, addr);
}

//////////////////////////////////////////////////////////////////////////////

u16 FASTCALL Vdp1FrameBufferReadWord(u32 addr) {
   addr &= 0x3FFFF;
   return T1ReadWord(Vdp1FrameBuffer, addr);
}

//////////////////////////////////////////////////////////////////////////////

u32 FASTCALL Vdp1FrameBufferReadLong(u32 addr) {
   addr &= 0x3FFFF;
   return T1ReadLong(Vdp1FrameBuffer, addr);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1FrameBufferWriteByte(u32 addr, u8 val) {
   addr &= 0x3FFFF;
   T1WriteByte(Vdp1FrameBuffer, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1FrameBufferWriteWord(u32 addr, u16 val) {
   addr &= 0x3FFFF;
   T1WriteWord(Vdp1FrameBuffer, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1FrameBufferWriteLong(u32 addr, u32 val) {
   addr &= 0x3FFFF;
   T1WriteLong(Vdp1FrameBuffer, addr, val);
}

//////////////////////////////////////////////////////////////////////////////

Vdp1 * Vdp1Regs;
Vdp1External_struct Vdp1External;

//////////////////////////////////////////////////////////////////////////////

int Vdp1Init(void) {
   if ((Vdp1Regs = (Vdp1 *) malloc(sizeof(Vdp1))) == NULL)
      return -1;

   if ((Vdp1Ram = T1MemoryInit(0x80000)) == NULL)
      return -1;

   // Allocate enough memory for two frames
   if ((Vdp1FrameBuffer = T1MemoryInit(0x80000)) == NULL)
      return -1;

   Vdp1External.disptoggle = 1;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void Vdp1DeInit(void) {
   if (Vdp1Regs)
      free(Vdp1Regs);
   Vdp1Regs = NULL;

   if (Vdp1Ram)
      T1MemoryDeInit(Vdp1Ram);
   Vdp1Ram = NULL;

   if (Vdp1FrameBuffer)
      T1MemoryDeInit(Vdp1FrameBuffer);
   Vdp1FrameBuffer = NULL;
}

//////////////////////////////////////////////////////////////////////////////

int VideoInit(int coreid) {
   return VideoChangeCore(coreid);
}

//////////////////////////////////////////////////////////////////////////////

int VideoChangeCore(int coreid)
{
   int i;

   // Make sure the old core is freed
   VideoDeInit();

   // So which core do we want?
   if (coreid == VIDCORE_DEFAULT)
      coreid = 0; // Assume we want the first one

   // Go through core list and find the id
   for (i = 0; VIDCoreList[i] != NULL; i++)
   {
      if (VIDCoreList[i]->id == coreid)
      {
         // Set to current core
         VIDCore = VIDCoreList[i];
         break;
      }
   }

   if (VIDCore == NULL)
      return -1;

   if (VIDCore->Init() != 0)
      return -1;

   // Reset resolution/priority variables
   if (Vdp2Regs)
   {
      VIDCore->Vdp1Reset();
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VideoDeInit(void) {
   if (VIDCore)
      VIDCore->DeInit();
   VIDCore = NULL;
}

//////////////////////////////////////////////////////////////////////////////

void Vdp1Reset(void) {
   Vdp1Regs->PTMR = 0;
   Vdp1Regs->MODR = 0x1000; // VDP1 Version 1
   VIDCore->Vdp1Reset();
}

//////////////////////////////////////////////////////////////////////////////

u8 FASTCALL Vdp1ReadByte(u32 addr) {
   addr &= 0xFF;
   LOG("trying to byte-read a Vdp1 register\n");
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u16 FASTCALL Vdp1ReadWord(u32 addr) {
   addr &= 0xFF;
   switch(addr) {
      case 0x10:
         return Vdp1Regs->EDSR;
      case 0x12:
         return Vdp1Regs->LOPR;
      case 0x14:
         return Vdp1Regs->COPR;
      case 0x16:
         return 0x1000 | ((Vdp1Regs->PTMR & 2) << 7) | ((Vdp1Regs->FBCR & 0x1E) << 3) | (Vdp1Regs->TVMR & 0xF);
      default:
         LOG("trying to read a Vdp1 write-only register\n");
   }
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 FASTCALL Vdp1ReadLong(u32 addr) {
   addr &= 0xFF;
   LOG("trying to long-read a Vdp1 register - %08X\n", addr);
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1WriteByte(u32 addr, UNUSED u8 val) {
   addr &= 0xFF;
   LOG("trying to byte-write a Vdp1 register - %08X\n", addr);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1WriteWord(u32 addr, u16 val) {
   addr &= 0xFF;
   switch(addr) {
      case 0x0:
         Vdp1Regs->TVMR = val;
         break;
      case 0x2:
         Vdp1Regs->FBCR = val;
         if ((Vdp1Regs->FBCR & 3) == 3)
         {
            Vdp1External.manualchange = 1;
         }
         else if ((Vdp1Regs->FBCR & 3) == 2)
            Vdp1External.manualerase = 1;
         break;
      case 0x4:
         Vdp1Regs->COPR = 0;
         Vdp1Regs->PTMR = val;
         if (val == 1) Vdp1Draw();
         break;
      case 0x6:
         Vdp1Regs->EWDR = val;
         break;
      case 0x8:
         Vdp1Regs->EWLR = val;
         break;
      case 0xA:
         Vdp1Regs->EWRR = val;
         break;
      case 0xC:
         Vdp1Regs->ENDR = val;
         break;
      default:
         LOG("trying to write a Vdp1 read-only register - %08X\n", addr);
   }
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1WriteLong(u32 addr, UNUSED u32 val) {
   addr &= 0xFF;
   LOG("trying to long-write a Vdp1 register - %08X\n", addr);
}

//////////////////////////////////////////////////////////////////////////////

void Vdp1Draw(void) {
   u32 returnAddr;
   u32 commandCounter;
   u16 command;

   VIDCore->Vdp1DrawStart();

   if (!Vdp1External.disptoggle)
   {
      Vdp1NoDraw();
      return;
   }

   Vdp1Regs->addr = 0;
   returnAddr = 0xFFFFFFFF;
   commandCounter = 0;

   // beginning of a frame
   // BEF <- CEF
   // CEF <- 0
   Vdp1Regs->EDSR >>= 1;
   /* this should be done after a frame change or a plot trigger */
   Vdp1Regs->COPR = 0;

   command = T1ReadWord(Vdp1Ram, Vdp1Regs->addr);

   while (!(command & 0x8000) && commandCounter < 2000) { // fix me
      // First, process the command
      if (!(command & 0x4000)) { // if (!skip)
         switch (command & 0x000F) {
            case 0: // normal sprite draw
               VIDCore->Vdp1NormalSpriteDraw();
               break;
            case 1: // scaled sprite draw
               VIDCore->Vdp1ScaledSpriteDraw();
               break;
            case 2: // distorted sprite draw
            case 3: /* this one should be invalid, but some games
                    (Hardcore 4x4 for instance) use it instead of 2 */
               VIDCore->Vdp1DistortedSpriteDraw();
               break;
            case 4: // polygon draw
               VIDCore->Vdp1PolygonDraw();
               break;
            case 5: // polyline draw
            case 7: // undocumented mirror
               VIDCore->Vdp1PolylineDraw();
               break;
            case 6: // line draw
               VIDCore->Vdp1LineDraw();
               break;
            case 8: // user clipping coordinates
            case 11: // undocumented mirror
               VIDCore->Vdp1UserClipping();
               break;
            case 9: // system clipping coordinates
               VIDCore->Vdp1SystemClipping();
               break;
            case 10: // local coordinate
               VIDCore->Vdp1LocalCoordinate();
               break;
            default: // Abort
               VDP1LOG("vdp1\t: Bad command: %x\n",  command);
               Vdp1Regs->EDSR |= 2;
               VIDCore->Vdp1DrawEnd();
               Vdp1Regs->LOPR = Vdp1Regs->addr >> 3;
               Vdp1Regs->COPR = Vdp1Regs->addr >> 3;
               return;
         }
      }

      // Next, determine where to go next
      switch ((command & 0x3000) >> 12) {
         case 0: // NEXT, jump to following table
            Vdp1Regs->addr += 0x20;
            break;
         case 1: // ASSIGN, jump to CMDLINK
            Vdp1Regs->addr = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 2) * 8;
            break;
         case 2: // CALL, call a subroutine
            if (returnAddr == 0xFFFFFFFF)
               returnAddr = Vdp1Regs->addr + 0x20;
	
            Vdp1Regs->addr = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 2) * 8;
            break;
         case 3: // RETURN, return from subroutine
            if (returnAddr != 0xFFFFFFFF) {
               Vdp1Regs->addr = returnAddr;
               returnAddr = 0xFFFFFFFF;
            }
            else
               Vdp1Regs->addr += 0x20;
            break;
      }

      command = T1ReadWord(Vdp1Ram, Vdp1Regs->addr);
      commandCounter++;    
   }

   // we set two bits to 1
   Vdp1Regs->EDSR |= 2;
   Vdp1Regs->COPR = Vdp1Regs->addr >> 3;
   ScuSendDrawEnd();
   VIDCore->Vdp1DrawEnd();
}

//////////////////////////////////////////////////////////////////////////////

void Vdp1NoDraw(void) {
   u32 returnAddr;
   u32 commandCounter;
   u16 command;

   Vdp1Regs->addr = 0;
   returnAddr = 0xFFFFFFFF;
   commandCounter = 0;

   // beginning of a frame (ST-013-R3-061694 page 53)
   // BEF <- CEF
   // CEF <- 0
   Vdp1Regs->EDSR >>= 1;
   /* this should be done after a frame change or a plot trigger */
   Vdp1Regs->COPR = 0;

   command = T1ReadWord(Vdp1Ram, Vdp1Regs->addr);

   while (!(command & 0x8000) && commandCounter < 2000) { // fix me
      // First, process the command
      if (!(command & 0x4000)) { // if (!skip)
         switch (command & 0x000F) {
            case 0: // normal sprite draw
            case 1: // scaled sprite draw
            case 2: // distorted sprite draw
            case 3: /* this one should be invalid, but some games
                    (Hardcore 4x4 for instance) use it instead of 2 */
            case 4: // polygon draw
            case 5: // polyline draw
            case 6: // line draw
            case 7: // undocumented polyline draw mirror
               break;
            case 8: // user clipping coordinates
            case 11: // undocumented mirror
               VIDCore->Vdp1UserClipping();
               break;
            case 9: // system clipping coordinates
               VIDCore->Vdp1SystemClipping();
               break;
            case 10: // local coordinate
               VIDCore->Vdp1LocalCoordinate();
               break;
            default: // Abort
               VDP1LOG("vdp1\t: Bad command: %x\n",  command);
               Vdp1Regs->EDSR |= 2;
               VIDCore->Vdp1DrawEnd();
               Vdp1Regs->LOPR = Vdp1Regs->addr >> 3;
               Vdp1Regs->COPR = Vdp1Regs->addr >> 3;
               return;
         }
      }

      // Next, determine where to go next
      switch ((command & 0x3000) >> 12) {
         case 0: // NEXT, jump to following table
            Vdp1Regs->addr += 0x20;
            break;
         case 1: // ASSIGN, jump to CMDLINK
            Vdp1Regs->addr = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 2) * 8;
            break;
         case 2: // CALL, call a subroutine
            if (returnAddr == 0xFFFFFFFF)
               returnAddr = Vdp1Regs->addr + 0x20;
	
            Vdp1Regs->addr = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 2) * 8;
            break;
         case 3: // RETURN, return from subroutine
            if (returnAddr != 0xFFFFFFFF) {
               Vdp1Regs->addr = returnAddr;
               returnAddr = 0xFFFFFFFF;
            }
            else
               Vdp1Regs->addr += 0x20;
            break;
      }

      command = T1ReadWord(Vdp1Ram, Vdp1Regs->addr);
      commandCounter++;    
   }

   // we set two bits to 1
   Vdp1Regs->EDSR |= 2;
   ScuSendDrawEnd();
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL Vdp1ReadCommand(vdp1cmd_struct *cmd, u32 addr) {
   cmd->CMDCTRL = T1ReadWord(Vdp1Ram, addr);
   cmd->CMDLINK = T1ReadWord(Vdp1Ram, addr + 0x2);
   cmd->CMDPMOD = T1ReadWord(Vdp1Ram, addr + 0x4);
   cmd->CMDCOLR = T1ReadWord(Vdp1Ram, addr + 0x6);
   cmd->CMDSRCA = T1ReadWord(Vdp1Ram, addr + 0x8);
   cmd->CMDSIZE = T1ReadWord(Vdp1Ram, addr + 0xA);
   cmd->CMDXA = T1ReadWord(Vdp1Ram, addr + 0xC);
   cmd->CMDYA = T1ReadWord(Vdp1Ram, addr + 0xE);
   cmd->CMDXB = T1ReadWord(Vdp1Ram, addr + 0x10);
   cmd->CMDYB = T1ReadWord(Vdp1Ram, addr + 0x12);
   cmd->CMDXC = T1ReadWord(Vdp1Ram, addr + 0x14);
   cmd->CMDYC = T1ReadWord(Vdp1Ram, addr + 0x16);
   cmd->CMDXD = T1ReadWord(Vdp1Ram, addr + 0x18);
   cmd->CMDYD = T1ReadWord(Vdp1Ram, addr + 0x1A);
   cmd->CMDGRDA = T1ReadWord(Vdp1Ram, addr + 0x1C);
}

//////////////////////////////////////////////////////////////////////////////

int Vdp1SaveState(FILE *fp)
{
   int offset;
   IOCheck_struct check;

   offset = StateWriteHeader(fp, "VDP1", 1);

   // Write registers
   ywrite(&check, (void *)Vdp1Regs, sizeof(Vdp1), 1, fp);

   // Write VDP1 ram
   ywrite(&check, (void *)Vdp1Ram, 0x80000, 1, fp);

   return StateFinishHeader(fp, offset);
}

//////////////////////////////////////////////////////////////////////////////

int Vdp1LoadState(FILE *fp, UNUSED int version, int size)
{
   IOCheck_struct check;

   // Read registers
   yread(&check, (void *)Vdp1Regs, sizeof(Vdp1), 1, fp);

   // Read VDP1 ram
   yread(&check, (void *)Vdp1Ram, 0x80000, 1, fp);

   return size;
}

//////////////////////////////////////////////////////////////////////////////

static u32 Vdp1DebugGetCommandNumberAddr(u32 number)
{
   u32 addr = 0;
   u32 returnAddr = 0xFFFFFFFF;
   u32 commandCounter = 0;
   u16 command;

   command = T1ReadWord(Vdp1Ram, addr);

   while (!(command & 0x8000) && commandCounter != number)
   {
      // Make sure we're still dealing with a valid command
      if ((command & 0x000C) == 0x000C)
         // Invalid, abort
         return 0xFFFFFFFF;

      // Determine where to go next
      switch ((command & 0x3000) >> 12)
      {
         case 0: // NEXT, jump to following table
            addr += 0x20;
            break;
         case 1: // ASSIGN, jump to CMDLINK
            addr = T1ReadWord(Vdp1Ram, addr + 2) * 8;
            break;
         case 2: // CALL, call a subroutine
            if (returnAddr == 0xFFFFFFFF)
               returnAddr = addr + 0x20;
	
            addr = T1ReadWord(Vdp1Ram, addr + 2) * 8;
            break;
         case 3: // RETURN, return from subroutine
            if (returnAddr != 0xFFFFFFFF) {
               addr = returnAddr;
               returnAddr = 0xFFFFFFFF;
            }
            else
               addr += 0x20;
            break;
      }

      if (addr > 0x7FFE0)
         return 0xFFFFFFFF;
      command = T1ReadWord(Vdp1Ram, addr);
      commandCounter++;    
   }

   if (commandCounter == number)
      return addr;
   else
      return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

char *Vdp1DebugGetCommandNumberName(u32 number)
{
   u32 addr;
   u16 command;

   if ((addr = Vdp1DebugGetCommandNumberAddr(number)) != 0xFFFFFFFF)
   {
      command = T1ReadWord(Vdp1Ram, addr);

      if (command & 0x8000)
         return "Draw End";

      // Figure out command name
      switch (command & 0x000F)
      {
         case 0:
            return "Normal Sprite";
         case 1:
            return "Scaled Sprite";
         case 2:
            return "Distorted Sprite";
         case 3:
            return "Distorted Sprite *";
         case 4:
            return "Polygon";
         case 5:
            return "Polyline";
         case 6:
            return "Line";
         case 7:
            return "Polyline *";
         case 8:
            return "User Clipping Coordinates";
         case 9:
            return "System Clipping Coordinates";
         case 10:
            return "Local Coordinates";
         case 11:
            return "User Clipping Coordinates *";
         default:
             return "Bad command";
      }
   }
   else
      return NULL;
}

//////////////////////////////////////////////////////////////////////////////

void Vdp1DebugCommand(u32 number, char *outstring)
{
   u16 command;
   vdp1cmd_struct cmd;
   u32 addr;

   if ((addr = Vdp1DebugGetCommandNumberAddr(number)) == 0xFFFFFFFF)
      return;

   command = T1ReadWord(Vdp1Ram, addr);

   if (command & 0x8000)
   {
      // Draw End
      outstring[0] = 0x00;
      return;
   }

   if (command & 0x4000)
   {
      AddString(outstring, "Command is skipped\r\n");
      return;
   }

   Vdp1ReadCommand(&cmd, addr);

   switch (cmd.CMDCTRL & 0x000F)
   {
      case 0:
         AddString(outstring, "Normal Sprite\r\n");
         AddString(outstring, "x = %d, y = %d\r\n", cmd.CMDXA, cmd.CMDYA);
         break;
      case 1:
         AddString(outstring, "Scaled Sprite\r\n");

         AddString(outstring, "Zoom Point: ");

         switch ((cmd.CMDCTRL >> 8) & 0xF)
         {
            case 0x0:
               AddString(outstring, "Only two coordinates\r\n");
               break;
            case 0x5:
               AddString(outstring, "Upper-left\r\n");
               break;
            case 0x6:
               AddString(outstring, "Upper-center\r\n");
               break;
            case 0x7:
               AddString(outstring, "Upper-right\r\n");
               break;
            case 0x9:
               AddString(outstring, "Center-left\r\n");
               break;
            case 0xA:
               AddString(outstring, "Center-center\r\n");
               break;
            case 0xB:
               AddString(outstring, "Center-right\r\n");
               break;
            case 0xC:
               AddString(outstring, "Lower-left\r\n");
               break;
            case 0xE:
               AddString(outstring, "Lower-center\r\n");
               break;
            case 0xF:
               AddString(outstring, "Lower-right\r\n");
               break;
            default: break;
         }

         if (((cmd.CMDCTRL >> 8) & 0xF) == 0)
         {
            AddString(outstring, "xa = %d, ya = %d, xc = %d, yc = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXC, cmd.CMDYC);
         }
         else
         {
            AddString(outstring, "xa = %d, ya = %d, xb = %d, yb = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         }

         break;
      case 2:
         AddString(outstring, "Distorted Sprite\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         AddString(outstring, "x3 = %d, y3 = %d, x4 = %d, y4 = %d\r\n", cmd.CMDXC, cmd.CMDYC, cmd.CMDXD, cmd.CMDYD);
         break;
      case 3:
         AddString(outstring, "Distorted Sprite *\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         AddString(outstring, "x3 = %d, y3 = %d, x4 = %d, y4 = %d\r\n", cmd.CMDXC, cmd.CMDYC, cmd.CMDXD, cmd.CMDYD);
         break;
      case 4:
         AddString(outstring, "Polygon\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         AddString(outstring, "x3 = %d, y3 = %d, x4 = %d, y4 = %d\r\n", cmd.CMDXC, cmd.CMDYC, cmd.CMDXD, cmd.CMDYD);
         break;
      case 5:
         AddString(outstring, "Polyline\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         AddString(outstring, "x3 = %d, y3 = %d, x4 = %d, y4 = %d\r\n", cmd.CMDXC, cmd.CMDYC, cmd.CMDXD, cmd.CMDYD);
         break;
      case 6:
         AddString(outstring, "Line\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         break;
      case 7:
         AddString(outstring, "Polyline *\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXB, cmd.CMDYB);
         AddString(outstring, "x3 = %d, y3 = %d, x4 = %d, y4 = %d\r\n", cmd.CMDXC, cmd.CMDYC, cmd.CMDXD, cmd.CMDYD);
         break;
      case 8:
         AddString(outstring, "User Clipping\r\n");
         AddString(outstring, "x1 = %d, y1 = %d, x2 = %d, y2 = %d\r\n", cmd.CMDXA, cmd.CMDYA, cmd.CMDXC, cmd.CMDYC);
         break;
      case 9:
         AddString(outstring, "System Clipping\r\n");
         AddString(outstring, "x1 = 0, y1 = 0, x2 = %d, y2 = %d\r\n", cmd.CMDXC, cmd.CMDYC);
         break;
      case 10:
         AddString(outstring, "Local Coordinates\r\n");
         AddString(outstring, "x = %d, y = %d\r\n", cmd.CMDXA, cmd.CMDYA);
         break;
      default:
         AddString(outstring, "Invalid command\r\n");
         return;
   }

   // Only Sprite commands use CMDSRCA, CMDSIZE
   if (!(cmd.CMDCTRL & 0x000C))
   {
      AddString(outstring, "Texture address = %08X\r\n", ((unsigned int)cmd.CMDSRCA) << 3);
      AddString(outstring, "Texture width = %d, height = %d\r\n", (cmd.CMDSIZE & 0x3F00) >> 5, cmd.CMDSIZE & 0xFF);
      AddString(outstring, "Texture read direction: ");

      switch ((cmd.CMDCTRL >> 4) & 0x3)
      {
         case 0:
            AddString(outstring, "Normal\r\n");
            break;
         case 1:
            AddString(outstring, "Reversed horizontal\r\n");
            break;
         case 2:
            AddString(outstring, "Reversed vertical\r\n");
            break;
         case 3:
            AddString(outstring, "Reversed horizontal and vertical\r\n");
            break;
         default: break;
      }      
   }

   // Only draw commands use CMDPMOD
   if (!(cmd.CMDCTRL & 0x0008))
   {
      if (cmd.CMDPMOD & 0x8000)
      {
         AddString(outstring, "MSB set\r\n");
      }

      if (cmd.CMDPMOD & 0x1000)
      {
         AddString(outstring, "High Speed Shrink Enabled\r\n");
      }

      if (!(cmd.CMDPMOD & 0x0800))
      {
         AddString(outstring, "Pre-clipping Enabled\r\n");
      }

      if (cmd.CMDPMOD & 0x0400)
      {
         AddString(outstring, "User Clipping Enabled\r\n");
         AddString(outstring, "Clipping Mode = %d\r\n", (cmd.CMDPMOD >> 9) & 0x1);
      }

      if (cmd.CMDPMOD & 0x0100)
      {
         AddString(outstring, "Mesh Enabled\r\n");
      }

      if (!(cmd.CMDPMOD & 0x0080))
      {
         AddString(outstring, "End Code Enabled\r\n");
      }

      if (!(cmd.CMDPMOD & 0x0040))
      {
         AddString(outstring, "Transparent Pixel Enabled\r\n");
      }

      AddString(outstring, "Color mode: ");

      switch ((cmd.CMDPMOD >> 3) & 0x7)
      {
         case 0:
            AddString(outstring, "4 BPP(16 color bank)\r\n");
            AddString(outstring, "Color bank: %08X\r\n", (cmd.CMDCOLR << 3));
            break;
         case 1:
            AddString(outstring, "4 BPP(16 color LUT)\r\n");
            AddString(outstring, "Color lookup table: %08X\r\n", (cmd.CMDCOLR << 3));
            break;
         case 2:
            AddString(outstring, "8 BPP(64 color bank)\r\n");
            AddString(outstring, "Color bank: %08X\r\n", (cmd.CMDCOLR << 3));
            break;
         case 3:
            AddString(outstring, "8 BPP(128 color bank)\r\n");
            AddString(outstring, "Color bank: %08X\r\n", (cmd.CMDCOLR << 3));
            break;
         case 4:
            AddString(outstring, "8 BPP(256 color bank)\r\n");
            AddString(outstring, "Color bank: %08X\r\n", (cmd.CMDCOLR << 3));
            break;
         case 5:
            AddString(outstring, "15 BPP(RGB)\r\n");

            // Only non-textured commands
            if (cmd.CMDCTRL & 0x0004)
            {
               AddString(outstring, "Non-textured color: %04X\r\n", cmd.CMDCOLR);
            }
            break;
         default: break;
      }

      AddString(outstring, "Color Calc. mode: ");

      switch (cmd.CMDPMOD & 0x7)
      {
         case 0:
            AddString(outstring, "Replace\r\n");
            break;
         case 1:
            AddString(outstring, "Cannot overwrite/Shadow\r\n");
            break;
         case 2:
            AddString(outstring, "Half-luminance\r\n");
            break;
         case 3:
            AddString(outstring, "Replace/Half-transparent\r\n");
            break;
         case 4:
            AddString(outstring, "Gouraud Shading\r\n");
            AddString(outstring, "Gouraud Shading Table = %08X\r\n", ((unsigned int)cmd.CMDGRDA) << 3);
            break;
         case 6:
            AddString(outstring, "Gouraud Shading + Half-luminance\r\n");
            AddString(outstring, "Gouraud Shading Table = %08X\r\n", ((unsigned int)cmd.CMDGRDA) << 3);
            break;
         case 7:
            AddString(outstring, "Gouraud Shading/Gouraud Shading + Half-transparent\r\n");
            AddString(outstring, "Gouraud Shading Table = %08X\r\n", ((unsigned int)cmd.CMDGRDA) << 3);
            break;
         default: break;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

#if defined WORDS_BIGENDIAN
#define SAT2YAB1(alpha,temp)		(alpha | (temp & 0x7C00) << 1 | (temp & 0x3E0) << 14 | (temp & 0x1F) << 27)
#else
#define SAT2YAB1(alpha,temp)		(alpha << 24 | (temp & 0x1F) << 3 | (temp & 0x3E0) << 6 | (temp & 0x7C00) << 9)
#endif

#if defined WORDS_BIGENDIAN
#define SAT2YAB2(alpha,dot1,dot2)       (((dot2 & 0xFF) << 24) | ((dot2 & 0xFF00) << 8) | ((dot1 & 0xFF) << 8) | alpha)
#else
#define SAT2YAB2(alpha,dot1,dot2)       (alpha << 24 | ((dot1 & 0xFF) << 16) | (dot2 & 0xFF00) | (dot2 & 0xFF))
#endif

static u32 ColorRamGetColor(u32 colorindex)
{
   switch(Vdp2Internal.ColorMode)
   {
      case 0:
      case 1:
      {
         u32 tmp;
         colorindex <<= 1;
         tmp = T2ReadWord(Vdp2ColorRam, colorindex & 0xFFF);
         return SAT2YAB1(0xFF, tmp);
      }
      case 2:
      {
         u32 tmp1, tmp2;
         colorindex <<= 2;
         colorindex &= 0xFFF;
         tmp1 = T2ReadWord(Vdp2ColorRam, colorindex);
         tmp2 = T2ReadWord(Vdp2ColorRam, colorindex+2);
         return SAT2YAB2(0xFF, tmp1, tmp2);
      }
      default: break;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE int CheckEndcode(int dot, int endcode, int *code)
{
   if (dot == endcode)
   {
      code[0]++;
      if (code[0] == 2)
      {
         code[0] = 0;
         return 2;
      }
      return 1;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE int DoEndcode(int count, u32 *charAddr, u32 **textdata, int width, int xoff, int oddpixel, int pixelsize)
{
   if (count > 1)
   {
      charAddr[0] += (int)((float)(width - xoff + oddpixel) / (float)(8 / pixelsize));
      memset(textdata[0], 0, sizeof(u32) * (width - xoff));
      textdata[0] += (width - xoff);
      return 1;
   }
   else
      *textdata[0]++ = 0;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 *Vdp1DebugTexture(u32 number, int *w, int *h)
{
   u16 command;
   vdp1cmd_struct cmd;
   u32 addr;
   u32 *texture;
   u32 charAddr;
   u32 dot;
   u8 SPD;
   u32 alpha;
   u32 *textdata;   
   int isendcode=0;
   int code=0;
   int ret;

   if ((addr = Vdp1DebugGetCommandNumberAddr(number)) == 0xFFFFFFFF)
      return NULL;

   command = T1ReadWord(Vdp1Ram, addr);

   if (command & 0x8000)
      // Draw End
      return NULL;

   if (command & 0x4000)
      // Command Skipped
      return NULL;

   Vdp1ReadCommand(&cmd, addr);

   switch (cmd.CMDCTRL & 0x000F)
   {
      case 0: // Normal Sprite
      case 1: // Scaled Sprite
      case 2: // Distorted Sprite
      case 3: // Distorted Sprite *
         w[0] = (cmd.CMDSIZE & 0x3F00) >> 5;
         h[0] = cmd.CMDSIZE & 0xFF;

         if ((texture = (u32 *)malloc(sizeof(u32) * w[0] * h[0])) == NULL)
            return NULL;

         if (!(cmd.CMDPMOD & 0x80))
         {
            isendcode = 1;
            code = 0;
         }
         else
            isendcode = 0;
         break;
      case 4: // Polygon
      case 5: // Polyline
      case 6: // Line
      case 7: // Polyline *
         // Do 1x1 pixel
         w[0] = 1;
         h[0] = 1;
         if ((texture = (u32 *)malloc(sizeof(u32))) == NULL)
            return NULL;

         if (cmd.CMDCOLR & 0x8000)
            texture[0] = SAT2YAB1(0xFF, cmd.CMDCOLR);
         else
            texture[0] = ColorRamGetColor(cmd.CMDCOLR);

         return texture;
      case 8: // User Clipping
      case 9: // System Clipping
      case 10: // Local Coordinates
      case 11: // User Clipping *
         return NULL;
      default: // Invalid command
         return NULL;
   }

   charAddr = cmd.CMDSRCA * 8;
   SPD = ((cmd.CMDPMOD & 0x40) != 0);
   alpha = 0xFF;
   textdata = texture;

   switch((cmd.CMDPMOD >> 3) & 0x7)
   {
      case 0:
      {
         // 4 bpp Bank mode
         u32 colorBank = cmd.CMDCOLR;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i;

         for(i = 0;i < h[0];i++)
         {
            u16 j;
            j = 0;
            while(j < w[0])
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

               // Pixel 1
               if (isendcode && (ret = CheckEndcode(dot >> 4, 0xF, &code)) > 0)
               {
                  if (DoEndcode(ret, &charAddr, &textdata, w[0], j, 0, 4))
                     break;
               }
               else
               {
                  if (((dot >> 4) == 0) && !SPD) *textdata++ = 0;
                  else *textdata++ = ColorRamGetColor(((dot >> 4) | colorBank) + colorOffset);
               }

               j += 1;

               // Pixel 2
               if (isendcode && (ret = CheckEndcode(dot & 0xF, 0xF, &code)) > 0)
               {
                  if (DoEndcode(ret, &charAddr, &textdata, w[0], j, 1, 4))
                     break;
               }
               else
               {
                  if (((dot & 0xF) == 0) && !SPD) *textdata++ = 0;
                  else *textdata++ = ColorRamGetColor(((dot & 0xF) | colorBank) + colorOffset);
               }

               j += 1;
               charAddr += 1;
            }
         }
         break;
      }
      case 1:
      {
         // 4 bpp LUT mode
         u32 temp;
         u32 colorLut = cmd.CMDCOLR * 8;
         u16 i;

         for(i = 0;i < h[0];i++)
         {
            u16 j;
            j = 0;
            while(j < w[0])
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

               if (isendcode && (ret = CheckEndcode(dot >> 4, 0xF, &code)) > 0)
               {
                  if (DoEndcode(ret, &charAddr, &textdata, w[0], j, 0, 4))
                     break;
               }
               else
               {
                  if (((dot >> 4) == 0) && !SPD)
                     *textdata++ = 0;
                  else
                  {
                     temp = T1ReadWord(Vdp1Ram, ((dot >> 4) * 2 + colorLut) & 0x7FFFF);
                     if (temp & 0x8000)
                        *textdata++ = SAT2YAB1(0xFF, temp);
                     else
                        *textdata++ = ColorRamGetColor(temp);
                  }
               }

               j += 1;

               if (isendcode && (ret = CheckEndcode(dot & 0xF, 0xF, &code)) > 0)
               {
                  if (DoEndcode(ret, &charAddr, &textdata, w[0], j, 1, 4))
                     break;
               }
               else
               {
                  if (((dot & 0xF) == 0) && !SPD)
                     *textdata++ = 0;
                  else
                  {
                     temp = T1ReadWord(Vdp1Ram, ((dot & 0xF) * 2 + colorLut) & 0x7FFFF);
                     if (temp & 0x8000)
                        *textdata++ = SAT2YAB1(0xFF, temp);
                     else
                        *textdata++ = ColorRamGetColor(temp);
                  }
               }

               j += 1;

               charAddr += 1;
            }
         }
         break;
      }
      case 2:
      {
         // 8 bpp(64 color) Bank mode
         u32 colorBank = cmd.CMDCOLR;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;

         u16 i, j;

         for(i = 0;i < h[0];i++)
         {
            for(j = 0;j < w[0];j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) & 0x3F;
               charAddr++;

               if ((dot == 0) && !SPD) *textdata++ = 0;
               else *textdata++ = ColorRamGetColor((dot | colorBank) + colorOffset);
            }
         }
         break;
      }
      case 3:
      {
         // 8 bpp(128 color) Bank mode
         u32 colorBank = cmd.CMDCOLR;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i, j;

         for(i = 0;i < h[0];i++)
         {
            for(j = 0;j < w[0];j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) & 0x7F;
               charAddr++;

               if ((dot == 0) && !SPD) *textdata++ = 0;
               else *textdata++ = ColorRamGetColor((dot | colorBank) + colorOffset);
            }
         }
         break;
      }
      case 4:
      {
         // 8 bpp(256 color) Bank mode
         u32 colorBank = cmd.CMDCOLR;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i, j;

         for(i = 0;i < h[0];i++)
         {
            for(j = 0;j < w[0];j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);
               charAddr++;

               if ((dot == 0) && !SPD) *textdata++ = 0;
               else *textdata++ = ColorRamGetColor((dot | colorBank) + colorOffset);
            }
         }
         break;
      }
      case 5:
      {
         // 16 bpp Bank mode
         u16 i, j;

         for(i = 0;i < h[0];i++)
         {
            for(j = 0;j < w[0];j++)
            {
               dot = T1ReadWord(Vdp1Ram, charAddr & 0x7FFFF);

               if (isendcode && (ret = CheckEndcode(dot, 0x7FFF, &code)) > 0)
               {
                  if (DoEndcode(ret, &charAddr, &textdata, w[0], j, 0, 16))
                     break;
               }
               else
               {
                  //if (!(dot & 0x8000) && (Vdp2Regs->SPCTL & 0x20)) printf("mixed mode\n");
                  if (!(dot & 0x8000) && !SPD) *textdata++ = 0;
                  else *textdata++ = SAT2YAB1(0xFF, dot);
               }

               charAddr += 2;
            }
         }
         break;
      }
      default:
         break;
   }

   return texture;
}

//////////////////////////////////////////////////////////////////////////////

void ToggleVDP1(void)
{
   Vdp1External.disptoggle ^= 1;
}

//////////////////////////////////////////////////////////////////////////////
// Dummy Video Interface
//////////////////////////////////////////////////////////////////////////////

int VIDDummyInit(void);
void VIDDummyDeInit(void);
void VIDDummyResize(unsigned int, unsigned int, int);
int VIDDummyIsFullscreen(void);
int VIDDummyVdp1Reset(void);
void VIDDummyVdp1DrawStart(void);
void VIDDummyVdp1DrawEnd(void);
void VIDDummyVdp1NormalSpriteDraw(void);
void VIDDummyVdp1ScaledSpriteDraw(void);
void VIDDummyVdp1DistortedSpriteDraw(void);
void VIDDummyVdp1PolygonDraw(void);
void VIDDummyVdp1PolylineDraw(void);
void VIDDummyVdp1LineDraw(void);
void VIDDummyVdp1UserClipping(void);
void VIDDummyVdp1SystemClipping(void);
void VIDDummyVdp1LocalCoordinate(void);
int VIDDummyVdp2Reset(void);
void VIDDummyVdp2DrawStart(void);
void VIDDummyVdp2DrawEnd(void);
void VIDDummyVdp2DrawScreens(void);
void VIDDummyGetGlSize(int *width, int *height);


VideoInterface_struct VIDDummy = {
VIDCORE_DUMMY,
"Dummy Video Interface",
VIDDummyInit,
VIDDummyDeInit,
VIDDummyResize,
VIDDummyIsFullscreen,
VIDDummyVdp1Reset,
VIDDummyVdp1DrawStart,
VIDDummyVdp1DrawEnd,
VIDDummyVdp1NormalSpriteDraw,
VIDDummyVdp1ScaledSpriteDraw,
VIDDummyVdp1DistortedSpriteDraw,
VIDDummyVdp1PolygonDraw,
VIDDummyVdp1PolylineDraw,
VIDDummyVdp1LineDraw,
VIDDummyVdp1UserClipping,
VIDDummyVdp1SystemClipping,
VIDDummyVdp1LocalCoordinate,
VIDDummyVdp2Reset,
VIDDummyVdp2DrawStart,
VIDDummyVdp2DrawEnd,
VIDDummyVdp2DrawScreens,
VIDDummyGetGlSize
};

//////////////////////////////////////////////////////////////////////////////

int VIDDummyInit(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyDeInit(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyResize(UNUSED unsigned int i, UNUSED unsigned int j, UNUSED int on)
{
}

//////////////////////////////////////////////////////////////////////////////

int VIDDummyIsFullscreen(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int VIDDummyVdp1Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1DrawStart(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1DrawEnd(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1NormalSpriteDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1ScaledSpriteDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1DistortedSpriteDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1PolygonDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1PolylineDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1LineDraw(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1UserClipping(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1SystemClipping(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp1LocalCoordinate(void)
{
}

//////////////////////////////////////////////////////////////////////////////

int VIDDummyVdp2Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp2DrawStart(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp2DrawEnd(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyVdp2DrawScreens(void)
{
}

//////////////////////////////////////////////////////////////////////////////

void VIDDummyGetGlSize(int *width, int *height)
{
   *width = 0;
   *height = 0;
}
