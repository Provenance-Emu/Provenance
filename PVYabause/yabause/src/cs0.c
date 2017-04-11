/*  Copyright 2004-2005 Theo Berkau
    Copyright 2006 Ex-Cyber
    Copyright 2005 Guillaume Duhamel

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

/*! \file cs0.c
    \brief A-bus CS0 emulation functions. Most of the cartridge related code is here.
*/

#include <stdlib.h>
#include "cs0.h"
#include "error.h"
#include "japmodem.h"
#include "netlink.h"

cartridge_struct *CartridgeArea;

//////////////////////////////////////////////////////////////////////////////
// Dummy/No Cart Functions
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL DummyCs0ReadByte(UNUSED u32 addr)
{
   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL DummyCs0ReadWord(UNUSED u32 addr)
{
   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DummyCs0ReadLong(UNUSED u32 addr)
{
   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs0WriteByte(UNUSED u32 addr, UNUSED u8 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs0WriteWord(UNUSED u32 addr, UNUSED u16 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs0WriteLong(UNUSED u32 addr, UNUSED u32 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL DummyCs1ReadByte(UNUSED u32 addr)
{
   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL DummyCs1ReadWord(UNUSED u32 addr)
{
   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DummyCs1ReadLong(UNUSED u32 addr)
{
   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs1WriteByte(UNUSED u32 addr, UNUSED u8 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs1WriteWord(UNUSED u32 addr, UNUSED u16 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs1WriteLong(UNUSED u32 addr, UNUSED u32 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL DummyCs2ReadByte(UNUSED u32 addr)
{
   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL DummyCs2ReadWord(UNUSED u32 addr)
{
   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DummyCs2ReadLong(UNUSED u32 addr)
{
   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs2WriteByte(UNUSED u32 addr, UNUSED u8 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs2WriteWord(UNUSED u32 addr, UNUSED u16 val)
{
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DummyCs2WriteLong(UNUSED u32 addr, UNUSED u32 val)
{
}

//////////////////////////////////////////////////////////////////////////////
// Action Replay 4M Plus funcions
//////////////////////////////////////////////////////////////////////////////

typedef enum
  {
    FL_READ,
    FL_SDP,   
    FL_CMD,
    FL_ID,
    FL_IDSDP,
    FL_IDCMD,
    FL_WRITEBUF,
    FL_WRITEARRAY
  } flashstate;

u8 flreg0 = 0;
u8 flreg1 = 0;

// Default value is for chip AT29C010
u8 vendorid=0x1F;
u8 deviceid=0xD5;

flashstate flstate0;
flashstate flstate1;

u8 flbuf0[128];
u8 flbuf1[128];

//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL FlashCs0ReadByte(u32 addr)
{
  flashstate* state;
  u8* reg;
    
  if (addr & 1)
    {
      state = &flstate1;
      reg = &flreg1;
    }
  else
    {
      state = &flstate0;
      reg = &flreg0;
    }

  switch (*state)
    {
    case FL_ID:
    case FL_IDSDP:
    case FL_IDCMD:
       if (addr & 2) return deviceid;
       else return vendorid;
    case FL_WRITEARRAY: *reg ^= 0x02;
    case FL_WRITEBUF: return *reg;  
    case FL_SDP: 
    case FL_CMD: *state = FL_READ;
    case FL_READ:
    default: return T2ReadByte(CartridgeArea->rom, addr);
    }
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL FlashCs0ReadWord(u32 addr)
{
  return ((u16)(FlashCs0ReadByte(addr) << 8) | (u16)(FlashCs0ReadByte(addr+1)));
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FlashCs0ReadLong(u32 addr)
{
  return ((u32)FlashCs0ReadWord(addr) << 16) |(u32) FlashCs0ReadWord(addr + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL FlashCs0WriteByte(u32 addr, u8 val)
{
   flashstate* state;
   u8* reg;
   u8* buf;
  
   if (addr & 1)
   {
      state = &flstate1;
      reg = &flreg1;
      buf = flbuf1;
   }
   else
   {
      state = &flstate0;
      reg = &flreg0;
      buf = flbuf0;
   }
  
   switch (*state)
   {
      case FL_READ:
         if (((addr & 0xfffe) == 0xaaaa) && (val == 0xaa))
            *state = FL_SDP;
         return;
      case FL_WRITEBUF:
         buf[(addr >> 1) & 0x7f] = val;
         if (((addr >> 1) & 0x7f) == 0x7f)
         {
            int i;
            int j = addr & 0x1;
            addr &= 0xffffff00;
            for (i = 0; i <= 127; i++)
            {
               T2WriteByte(CartridgeArea->rom, (addr + i*2 + j), buf[i]);
            }
            *state = FL_READ;
         }
         return;
      case FL_SDP:
         if (((addr & 0xfffe) == 0x5554) && (val == 0x55))
            *state = FL_CMD;
         else *state = FL_READ;
         return;
      case FL_ID:
         if (((addr & 0xfffe) == 0xaaaa) && (val == 0xaa))
            *state = FL_IDSDP;
         else *state = FL_ID;
         return;
      case FL_IDSDP:
         if (((addr & 0xfffe) == 0x5554) && (val == 0x55))
            *state = FL_READ;
         else *state=FL_ID;
         return;
      case FL_IDCMD:
         if (((addr & 0xfffe) == 0xaaaa) && (val == 0xf0))
            *state = FL_READ;
         else *state = FL_ID;
         return;
      case FL_CMD:
         if ((addr & 0xfffe) != 0xaaaa)
         {
            *state = FL_READ;
            return;
         }

         switch (val)
         {
            case 0xa0:
               *state = FL_WRITEBUF;
               return;
            case 0x90:
               *state = FL_ID;
               return;
            default:
               *state = FL_READ;
               return;
         }
      default: break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL FlashCs0WriteWord(u32 addr, u16 val)
{
  FlashCs0WriteByte(addr, (u8)(val >> 8));
  FlashCs0WriteByte(addr + 1, (u8)(val & 0xff));
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL FlashCs0WriteLong(u32 addr, u32 val)
{
  FlashCs0WriteWord(addr, (u16)(val >> 16));
  FlashCs0WriteWord(addr + 2, (u16)(val & 0xffff));
}

//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL AR4MCs0ReadByte(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   return FlashCs0ReadByte(addr);
//            return biosarea->getByte(addr);
//         else // Outport
//            fprintf(stderr, "Commlink Outport Byte read\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag read\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Byte read\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Dram area
         return T1ReadByte(CartridgeArea->dram, addr & 0x3FFFFF);
      default:   // The rest doesn't matter
         break;
   }

   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL AR4MCs0ReadWord(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   return FlashCs0ReadWord(addr);
//         else // Outport
//            fprintf(stderr, "Commlink Outport Word read\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag read\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Word read\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         return T1ReadWord(CartridgeArea->dram, addr & 0x3FFFFF);
      case 0x12:
      case 0x1E:
         if (0x80000)
            return 0xFFFD;
         break;
      case 0x13:
      case 0x16:
      case 0x17:
      case 0x1A:
      case 0x1B:
      case 0x1F:
         return 0xFFFD;
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL AR4MCs0ReadLong(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   return FlashCs0ReadLong(addr);
//         else // Outport
//            fprintf(stderr, "Commlink Outport Long read\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag read\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Long read\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         return T1ReadLong(CartridgeArea->dram, addr & 0x3FFFFF);
      case 0x12:
      case 0x1E:
         if (0x80000)
            return 0xFFFDFFFD;
         break;
      case 0x13:
      case 0x16:
      case 0x17:
      case 0x1A:
      case 0x1B:
      case 0x1F:
         return 0xFFFDFFFD;
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL AR4MCs0WriteByte(u32 addr, u8 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   FlashCs0WriteByte(addr, val);
//         else // Outport
//            fprintf(stderr, "Commlink Outport byte write\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag write\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Byte write\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteByte(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL AR4MCs0WriteWord(u32 addr, u16 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   FlashCs0WriteWord(addr, val);
//         else // Outport
//            fprintf(stderr, "Commlink Outport Word write\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag write\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Word write\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteWord(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL AR4MCs0WriteLong(u32 addr, u32 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x00:
      {
         if ((addr & 0x80000) == 0) // EEPROM
	   FlashCs0WriteLong(addr, val);
//         else // Outport
//            fprintf(stderr, "Commlink Outport Long write\n");
         break;
      }
      case 0x01:
      {
//         if ((addr & 0x80000) == 0) // Commlink Status flag
//            fprintf(stderr, "Commlink Status Flag write\n");
//         else // Inport for Commlink
//            fprintf(stderr, "Commlink Inport Long write\n");
         break;
      }
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteLong(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////
// 8 Mbit Dram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL DRAM8MBITCs0ReadByte(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         return T1ReadByte(CartridgeArea->dram, addr & 0x7FFFF);
      case 0x06: // Dram area
         return T1ReadByte(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF));
      default:   // The rest doesn't matter
         break;
   }

   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL DRAM8MBITCs0ReadWord(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         return T1ReadWord(CartridgeArea->dram, addr & 0x7FFFF);
      case 0x06: // Dram area
         return T1ReadWord(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF));
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DRAM8MBITCs0ReadLong(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         return T1ReadLong(CartridgeArea->dram, addr & 0x7FFFF);
      case 0x06: // Dram area
         return T1ReadLong(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF));
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM8MBITCs0WriteByte(u32 addr, u8 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         T1WriteByte(CartridgeArea->dram, addr & 0x7FFFF, val);
         break;
      case 0x06: // Dram area
         T1WriteByte(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF), val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM8MBITCs0WriteWord(u32 addr, u16 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         T1WriteWord(CartridgeArea->dram, addr & 0x7FFFF, val);
         break;
      case 0x06: // Dram area
         T1WriteWord(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF), val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM8MBITCs0WriteLong(u32 addr, u32 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04: // Dram area
         T1WriteLong(CartridgeArea->dram, addr & 0x7FFFF, val);
         break;
      case 0x06: // Dram area
         T1WriteLong(CartridgeArea->dram, 0x80000 | (addr & 0x7FFFF), val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////
// 32 Mbit Dram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL DRAM32MBITCs0ReadByte(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Dram area
         return T1ReadByte(CartridgeArea->dram, addr & 0x3FFFFF);
      default:   // The rest doesn't matter
         break;
   }

   return 0xFF;
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL DRAM32MBITCs0ReadWord(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         return T1ReadWord(CartridgeArea->dram, addr & 0x3FFFFF);
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DRAM32MBITCs0ReadLong(u32 addr)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         return T1ReadLong(CartridgeArea->dram, addr & 0x3FFFFF);
      default:   // The rest doesn't matter
         break;
   }

   return 0xFFFFFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM32MBITCs0WriteByte(u32 addr, u8 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteByte(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM32MBITCs0WriteWord(u32 addr, u16 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteWord(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL DRAM32MBITCs0WriteLong(u32 addr, u32 val)
{
   addr &= 0x1FFFFFF;

   switch (addr >> 20)
   {
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07: // Ram cart area
         T1WriteLong(CartridgeArea->dram, addr & 0x3FFFFF, val);
         break;
      default:   // The rest doesn't matter
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////
// 4 Mbit Backup Ram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL BUP4MBITCs1ReadByte(u32 addr)
{
   return T1ReadByte(CartridgeArea->bupram, addr & 0xFFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL BUP4MBITCs1ReadWord(u32 addr)
{
   return T1ReadWord(CartridgeArea->bupram, addr & 0xFFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL BUP4MBITCs1ReadLong(u32 addr)
{
   return T1ReadLong(CartridgeArea->bupram, addr & 0xFFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP4MBITCs1WriteByte(u32 addr, u8 val)
{
   T1WriteByte(CartridgeArea->bupram, addr & 0xFFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP4MBITCs1WriteWord(u32 addr, u16 val)
{
   T1WriteWord(CartridgeArea->bupram, addr & 0xFFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP4MBITCs1WriteLong(u32 addr, u32 val)
{
   T1WriteLong(CartridgeArea->bupram, addr & 0xFFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////
// 8 Mbit Backup Ram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL BUP8MBITCs1ReadByte(u32 addr)
{
   return T1ReadByte(CartridgeArea->bupram, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL BUP8MBITCs1ReadWord(u32 addr)
{
   return T1ReadWord(CartridgeArea->bupram, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL BUP8MBITCs1ReadLong(u32 addr)
{
   return T1ReadLong(CartridgeArea->bupram, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP8MBITCs1WriteByte(u32 addr, u8 val)
{
   T1WriteByte(CartridgeArea->bupram, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP8MBITCs1WriteWord(u32 addr, u16 val)
{
   T1WriteWord(CartridgeArea->bupram, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP8MBITCs1WriteLong(u32 addr, u32 val)
{
   T1WriteLong(CartridgeArea->bupram, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////
// 16 Mbit Backup Ram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL BUP16MBITCs1ReadByte(u32 addr)
{
   return T1ReadByte(CartridgeArea->bupram, addr & 0x3FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL BUP16MBITCs1ReadWord(u32 addr)
{
   return T1ReadWord(CartridgeArea->bupram, addr & 0x3FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL BUP16MBITCs1ReadLong(u32 addr)
{
   return T1ReadLong(CartridgeArea->bupram, addr & 0x3FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP16MBITCs1WriteByte(u32 addr, u8 val)
{
   T1WriteByte(CartridgeArea->bupram, addr & 0x3FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP16MBITCs1WriteWord(u32 addr, u16 val)
{
   T1WriteWord(CartridgeArea->bupram, addr & 0x3FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP16MBITCs1WriteLong(u32 addr, u32 val)
{
   T1WriteLong(CartridgeArea->bupram, addr & 0x3FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////
// 32 Mbit Backup Ram
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL BUP32MBITCs1ReadByte(u32 addr)
{
   return T1ReadByte(CartridgeArea->bupram, addr & 0x7FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL BUP32MBITCs1ReadWord(u32 addr)
{
   return T1ReadWord(CartridgeArea->bupram, addr & 0x7FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL BUP32MBITCs1ReadLong(u32 addr)
{
   return T1ReadLong(CartridgeArea->bupram, addr & 0x7FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP32MBITCs1WriteByte(u32 addr, u8 val)
{
   T1WriteByte(CartridgeArea->bupram, addr & 0x7FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP32MBITCs1WriteWord(u32 addr, u16 val)
{
   T1WriteWord(CartridgeArea->bupram, addr & 0x7FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL BUP32MBITCs1WriteLong(u32 addr, u32 val)
{
   T1WriteLong(CartridgeArea->bupram, addr & 0x7FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////
// 16 Mbit Rom
//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL ROM16MBITCs0ReadByte(u32 addr)
{
   return T1ReadByte(CartridgeArea->rom, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u16 FASTCALL ROM16MBITCs0ReadWord(u32 addr)
{
   return T1ReadWord(CartridgeArea->rom, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL ROM16MBITCs0ReadLong(u32 addr)
{
   return T1ReadLong(CartridgeArea->rom, addr & 0x1FFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL ROM16MBITCs0WriteByte(u32 addr, u8 val)
{
   T1WriteByte(CartridgeArea->rom, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL ROM16MBITCs0WriteWord(u32 addr, u16 val)
{
   T1WriteWord(CartridgeArea->rom, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL ROM16MBITCs0WriteLong(u32 addr, u32 val)
{
   T1WriteLong(CartridgeArea->rom, addr & 0x1FFFFF, val);
}

//////////////////////////////////////////////////////////////////////////////
// General Cart functions
//////////////////////////////////////////////////////////////////////////////

int CartInit(const char * filename, int type)
{
   if ((CartridgeArea = (cartridge_struct *)calloc(1, sizeof(cartridge_struct))) == NULL)
      return -1;

   CartridgeArea->carttype = type;
   CartridgeArea->filename = filename;

   // Setup default mappings
   CartridgeArea->Cs0ReadByte = &DummyCs0ReadByte;
   CartridgeArea->Cs0ReadWord = &DummyCs0ReadWord;
   CartridgeArea->Cs0ReadLong = &DummyCs0ReadLong;
   CartridgeArea->Cs0WriteByte = &DummyCs0WriteByte;
   CartridgeArea->Cs0WriteWord = &DummyCs0WriteWord;
   CartridgeArea->Cs0WriteLong = &DummyCs0WriteLong;

   CartridgeArea->Cs1ReadByte = &DummyCs1ReadByte;
   CartridgeArea->Cs1ReadWord = &DummyCs1ReadWord;
   CartridgeArea->Cs1ReadLong = &DummyCs1ReadLong;
   CartridgeArea->Cs1WriteByte = &DummyCs1WriteByte;
   CartridgeArea->Cs1WriteWord = &DummyCs1WriteWord;
   CartridgeArea->Cs1WriteLong = &DummyCs1WriteLong;

   CartridgeArea->Cs2ReadByte = &DummyCs2ReadByte;
   CartridgeArea->Cs2ReadWord = &DummyCs2ReadWord;
   CartridgeArea->Cs2ReadLong = &DummyCs2ReadLong;
   CartridgeArea->Cs2WriteByte = &DummyCs2WriteByte;
   CartridgeArea->Cs2WriteWord = &DummyCs2WriteWord;
   CartridgeArea->Cs2WriteLong = &DummyCs2WriteLong;

   switch(type)
   {
      case CART_PAR: // Action Replay 4M Plus(or equivalent)
      {
         if ((CartridgeArea->rom = T2MemoryInit(0x40000)) == NULL)
            return -1;

         if ((CartridgeArea->dram = T1MemoryInit(0x400000)) == NULL)
            return -1;

         // Use 32 Mbit Dram id
         CartridgeArea->cartid = 0x5C;

         // Load AR firmware to memory
         if (T123Load(CartridgeArea->rom, 0x40000, 2, filename) != 0)
            return -1;

         vendorid = 0x1F;
         deviceid = 0xD5;
         flstate0 = FL_READ;
         flstate1 = FL_READ;
		 
         // Setup Functions
         CartridgeArea->Cs0ReadByte = &AR4MCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &AR4MCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &AR4MCs0ReadLong;
         CartridgeArea->Cs0WriteByte = &AR4MCs0WriteByte;
         CartridgeArea->Cs0WriteWord = &AR4MCs0WriteWord;
         CartridgeArea->Cs0WriteLong = &AR4MCs0WriteLong;
         break;
      }
      case CART_BACKUPRAM4MBIT: // 4 Mbit Backup Ram
      {
         if ((CartridgeArea->bupram = T1MemoryInit(0x100000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x21;

         // Load Backup Ram data from file
         if (T123Load(CartridgeArea->bupram, 0x100000, 1, filename) != 0)
            FormatBackupRam(CartridgeArea->bupram, 0x100000);

         // Setup Functions
         CartridgeArea->Cs1ReadByte = &BUP4MBITCs1ReadByte;
         CartridgeArea->Cs1ReadWord = &BUP4MBITCs1ReadWord;
         CartridgeArea->Cs1ReadLong = &BUP4MBITCs1ReadLong;
         CartridgeArea->Cs1WriteByte = &BUP4MBITCs1WriteByte;
         CartridgeArea->Cs1WriteWord = &BUP4MBITCs1WriteWord;
         CartridgeArea->Cs1WriteLong = &BUP4MBITCs1WriteLong;
         break;
      }
      case CART_BACKUPRAM8MBIT: // 8 Mbit Backup Ram
      {
         if ((CartridgeArea->bupram = T1MemoryInit(0x200000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x22;

         // Load Backup Ram data from file
         if (T123Load(CartridgeArea->bupram, 0x200000, 1, filename) != 0)
            FormatBackupRam(CartridgeArea->bupram, 0x200000);

         // Setup Functions
         CartridgeArea->Cs1ReadByte = &BUP8MBITCs1ReadByte;
         CartridgeArea->Cs1ReadWord = &BUP8MBITCs1ReadWord;
         CartridgeArea->Cs1ReadLong = &BUP8MBITCs1ReadLong;
         CartridgeArea->Cs1WriteByte = &BUP8MBITCs1WriteByte;
         CartridgeArea->Cs1WriteWord = &BUP8MBITCs1WriteWord;
         CartridgeArea->Cs1WriteLong = &BUP8MBITCs1WriteLong;
         break;
      }
      case CART_BACKUPRAM16MBIT: // 16 Mbit Backup Ram
      {
         if ((CartridgeArea->bupram = T1MemoryInit(0x400000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x23;

         // Load Backup Ram data from file
         if (T123Load(CartridgeArea->bupram, 0x400000, 1, filename) != 0)
            FormatBackupRam(CartridgeArea->bupram, 0x400000);

         // Setup Functions
         CartridgeArea->Cs1ReadByte = &BUP16MBITCs1ReadByte;
         CartridgeArea->Cs1ReadWord = &BUP16MBITCs1ReadWord;
         CartridgeArea->Cs1ReadLong = &BUP16MBITCs1ReadLong;
         CartridgeArea->Cs1WriteByte = &BUP16MBITCs1WriteByte;
         CartridgeArea->Cs1WriteWord = &BUP16MBITCs1WriteWord;
         CartridgeArea->Cs1WriteLong = &BUP16MBITCs1WriteLong;
         break;
      }
      case CART_BACKUPRAM32MBIT: // 32 Mbit Backup Ram
      {
         if ((CartridgeArea->bupram = T1MemoryInit(0x800000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x24;

         // Load Backup Ram data from file
         if (T123Load(CartridgeArea->bupram, 0x800000, 1, filename) != 0)
            FormatBackupRam(CartridgeArea->bupram, 0x800000);

         // Setup Functions
         CartridgeArea->Cs1ReadByte = &BUP32MBITCs1ReadByte;
         CartridgeArea->Cs1ReadWord = &BUP32MBITCs1ReadWord;
         CartridgeArea->Cs1ReadLong = &BUP32MBITCs1ReadLong;
         CartridgeArea->Cs1WriteByte = &BUP32MBITCs1WriteByte;
         CartridgeArea->Cs1WriteWord = &BUP32MBITCs1WriteWord;
         CartridgeArea->Cs1WriteLong = &BUP32MBITCs1WriteLong;
         break;
      }
      case CART_DRAM8MBIT: // 8 Mbit Dram Cart
      {
         if ((CartridgeArea->dram = T1MemoryInit(0x100000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x5A;

         // Setup Functions
         CartridgeArea->Cs0ReadByte = &DRAM8MBITCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &DRAM8MBITCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &DRAM8MBITCs0ReadLong;
         CartridgeArea->Cs0WriteByte = &DRAM8MBITCs0WriteByte;
         CartridgeArea->Cs0WriteWord = &DRAM8MBITCs0WriteWord;
         CartridgeArea->Cs0WriteLong = &DRAM8MBITCs0WriteLong;
         break;
      }
      case CART_DRAM32MBIT: // 32 Mbit Dram Cart
      {
         if ((CartridgeArea->dram = T1MemoryInit(0x400000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0x5C;

         // Setup Functions
         CartridgeArea->Cs0ReadByte = &DRAM32MBITCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &DRAM32MBITCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &DRAM32MBITCs0ReadLong;
         CartridgeArea->Cs0WriteByte = &DRAM32MBITCs0WriteByte;
         CartridgeArea->Cs0WriteWord = &DRAM32MBITCs0WriteWord;
         CartridgeArea->Cs0WriteLong = &DRAM32MBITCs0WriteLong;
         break;
      }
      case CART_NETLINK:
      {
         CartridgeArea->cartid = 0xFF;
         CartridgeArea->Cs2ReadByte = &NetlinkReadByte;
         CartridgeArea->Cs2WriteByte = &NetlinkWriteByte;
         break;
      }
      case CART_ROM16MBIT: // 16 Mbit Rom Cart
      {
         if ((CartridgeArea->rom = T1MemoryInit(0x200000)) == NULL)
            return -1;

         CartridgeArea->cartid = 0xFF; // I have no idea what the real id is

         // Load Rom to memory
         if (T123Load(CartridgeArea->rom, 0x200000, 1, filename) != 0)
            return -1;

         // Setup Functions
         CartridgeArea->Cs0ReadByte = &ROM16MBITCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &ROM16MBITCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &ROM16MBITCs0ReadLong;
         CartridgeArea->Cs0WriteByte = &ROM16MBITCs0WriteByte;
         CartridgeArea->Cs0WriteWord = &ROM16MBITCs0WriteWord;
         CartridgeArea->Cs0WriteLong = &ROM16MBITCs0WriteLong;
         break;
      }
      case CART_JAPMODEM: // Sega Saturn Modem(Japanese)
      {
         CartridgeArea->cartid = 0xFF;

         CartridgeArea->Cs0ReadByte = &JapModemCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &JapModemCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &JapModemCs0ReadLong;

         CartridgeArea->Cs1ReadByte = &JapModemCs1ReadByte;
         CartridgeArea->Cs1ReadWord = &JapModemCs1ReadWord;
         CartridgeArea->Cs1ReadLong = &JapModemCs1ReadLong;
         CartridgeArea->Cs1WriteByte = &JapModemCs1WriteByte;
         CartridgeArea->Cs1WriteWord = &JapModemCs1WriteWord;
         CartridgeArea->Cs1WriteLong = &JapModemCs1WriteLong;

         CartridgeArea->Cs2ReadByte = &JapModemCs2ReadByte;
         CartridgeArea->Cs2WriteByte = &JapModemCs2WriteByte;
         break;
      }
      case CART_USBDEV: // USB Dev Cartridge
      {
         if ((CartridgeArea->rom = T2MemoryInit(0x40000)) == NULL)
            return -1;

         if ((CartridgeArea->dram = T1MemoryInit(0x400000)) == NULL)
            return -1;

         // No extra dram, etc. built-in
         CartridgeArea->cartid = 0;

         // Load AR firmware to memory
         if (T123Load(CartridgeArea->rom, 0x40000, 2, filename) != 0)
            return -1;

         // ID for SST39SF010A
         vendorid = 0xBF;
         deviceid = 0xB5;

         flstate0 = FL_READ;
         flstate1 = FL_READ;

         // Setup Functions
         CartridgeArea->Cs0ReadByte = &AR4MCs0ReadByte;
         CartridgeArea->Cs0ReadWord = &AR4MCs0ReadWord;
         CartridgeArea->Cs0ReadLong = &AR4MCs0ReadLong;
         CartridgeArea->Cs0WriteByte = &AR4MCs0WriteByte;
         CartridgeArea->Cs0WriteWord = &AR4MCs0WriteWord;
         CartridgeArea->Cs0WriteLong = &AR4MCs0WriteLong;
         break;
      }

      default: // No Cart
      {
         CartridgeArea->cartid = 0xFF;
         break;
      }
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void CartDeInit(void)
{
   if (CartridgeArea)
   {
      if (CartridgeArea->carttype == CART_PAR)
      {
         if (CartridgeArea->rom)
         {
            if (T123Save(CartridgeArea->rom, 0x40000, 2, CartridgeArea->filename) != 0)
               YabSetError(YAB_ERR_FILEWRITE, (void *)CartridgeArea->filename);
            T2MemoryDeInit(CartridgeArea->rom);
         }
      }
      else
      {
         if (CartridgeArea->rom)
            T1MemoryDeInit(CartridgeArea->rom);
      }

      if (CartridgeArea->bupram)
      {
         u32 size=0;

         switch (CartridgeArea->carttype)
         {
            case CART_BACKUPRAM4MBIT: // 4 Mbit Backup Ram
            {
               size = 0x100000;
               break;
            }
            case CART_BACKUPRAM8MBIT: // 8 Mbit Backup Ram
            {
               size = 0x200000;
               break;
            }
            case CART_BACKUPRAM16MBIT: // 16 Mbit Backup Ram
            {
               size = 0x400000;
               break;
            }
            case CART_BACKUPRAM32MBIT: // 32 Mbit Backup Ram
            {
               size = 0x800000;
               break;
            }
         }

         if (size != 0)
         {
            if (T123Save(CartridgeArea->bupram, size, 1, CartridgeArea->filename) != 0)
               YabSetError(YAB_ERR_FILEWRITE, (void *)CartridgeArea->filename);

            T1MemoryDeInit(CartridgeArea->bupram);
         }
      }

      if (CartridgeArea->dram)
         T1MemoryDeInit(CartridgeArea->dram);

      free(CartridgeArea);
   }
   CartridgeArea = NULL;
}

//////////////////////////////////////////////////////////////////////////////

int CartSaveState(FILE * fp)
{
   int offset;

   offset = StateWriteHeader(fp, "CART", 1);

   // Write cart type
   fwrite((void *)&CartridgeArea->carttype, 4, 1, fp);

   // Write the areas associated with the cart type here

   return StateFinishHeader(fp, offset);
}

//////////////////////////////////////////////////////////////////////////////

int CartLoadState(FILE * fp, UNUSED int version, int size)
{
   int newtype;

   // Read cart type
   fread((void *)&newtype, 4, 1, fp);

   // Check to see if old cart type and new cart type match, if they don't,
   // reallocate memory areas

   // Read the areas associated with the cart type here

   return size;
}

//////////////////////////////////////////////////////////////////////////////

