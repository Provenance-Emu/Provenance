/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cart.cpp:
**  Copyright (C) 2015-2021 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "snes.h"
#include "cart.h"
#include "cart-private.h"
#include "cart/dsp1.h"
#include "cart/dsp2.h"
#include "cart/sdd1.h"
#include "cart/cx4.h"
#include "cart/sa1.h"
#include "cart/superfx.h"

#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/hash/sha1.h>

namespace MDFN_IEN_SNES_FAUST
{

CartInfo Cart;

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(CartRead_LoROM)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (Cart.ROM + rom_offset)[(A & 0x7FFF) | ((A >> 1) & 0x3F8000)];
 }

 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 return (Cart.ROM + rom_offset)[(A & 0x7FFF) | ((A >> 1) & 0x3F8000)];
}

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(CartRead_HiROM)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (Cart.ROM + rom_offset)[A & 0x3FFFFF];
 }

 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 return (Cart.ROM + rom_offset)[A & 0x3FFFFF];
}

template<signed cyc>
static DEFREAD(CartRead_SRAM_LoROM)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return Cart.RAM[((A & 0x7FFF) | ((A >> 1) &~ 0x7FFF)) & Cart.RAM_Mask];
 }

 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 return Cart.RAM[((A & 0x7FFF) | ((A >> 1) &~ 0x7FFF)) & Cart.RAM_Mask];
}

template<signed cyc>
static DEFWRITE(CartWrite_SRAM_LoROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 Cart.RAM[((A & 0x7FFF) | ((A >> 1) &~ 0x7FFF)) & Cart.RAM_Mask] = V;
}


static DEFREAD(CartRead_SRAM_HiROM)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return Cart.RAM[((A & 0x1FFF) | ((A >> 3) & 0x3E000)) & Cart.RAM_Mask];
 }

 CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const unsigned raw_sram_index = (A & 0x1FFF) | ((A >> 3) & 0x3E000);

 return Cart.RAM[raw_sram_index & Cart.RAM_Mask];
}

static DEFWRITE(CartWrite_SRAM_HiROM)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const unsigned raw_sram_index = (A & 0x1FFF) | ((A >> 3) & 0x3E000);

 Cart.RAM[raw_sram_index & Cart.RAM_Mask] = V;
}

static MDFN_COLD uint32 DummyEventHandler(uint32 timestamp)
{
 return SNES_EVENT_MAXTS;
}

bool CART_Init(Stream* fp, uint8 id[16], const int32 cx4_ocmultiplier, const int32 superfx_ocmultiplier, const bool superfx_enable_icache)
{
 bool IsPAL = false;
 static const uint64 max_rom_size = 8192 * 1024;
 const uint64 raw_size = fp->size();
 const unsigned copier_header_adjust = ((raw_size & 0x7FFF) == 512) ? 512 : 0;
 const uint64 size = raw_size - copier_header_adjust;

 //printf("%llu\n", (unsigned long long)size);

 if(size > max_rom_size)
  throw MDFN_Error(0, _("SNES ROM image is too large."));

 fp->seek(copier_header_adjust, SEEK_SET);
 fp->read(Cart.ROM, size);

 {
  sha1_digest sd = sha1(Cart.ROM, size);
  memcpy(id, &sd[0], 16);
 }

 for(uint32 s = size, i = 0; s < 8192 * 1024; i++)
 {
  if(s & (1U << i))
  {
   SNES_DBG("[CART] Copy 0x%08x bytes from 0x%08x to 0x%08x\n", 1U << i, s - (1U << i), s);
   memcpy(Cart.ROM + s, Cart.ROM + s - (1U << i), 1U << i);
   s += (1U << i);
  }
 }
 //
 //
 //
 enum
 {
  SPECIAL_CHIP_NONE = 0,
  SPECIAL_CHIP_SUPERFX,
  SPECIAL_CHIP_OBC1,
  SPECIAL_CHIP_SA1,
  SPECIAL_CHIP_SDD1,
  SPECIAL_CHIP_SPC7110,
  SPECIAL_CHIP_ST018,
  SPECIAL_CHIP_CX4,
  SPECIAL_CHIP_DSP1,
  SPECIAL_CHIP_DSP2,
  SPECIAL_CHIP_DSP3,
  SPECIAL_CHIP_DSP4,
  SPECIAL_CHIP_ST010,
  SPECIAL_CHIP_ST011
 };
 const bool maybe_exrom = (size >= 4 * 1024 * 1024 + 32768);
 const unsigned rv[4] = { MDFN_de16lsb(&Cart.ROM[0x7FFC]), MDFN_de16lsb(&Cart.ROM[0xFFFC]), MDFN_de16lsb(&Cart.ROM[0x407FFC]), MDFN_de16lsb(&Cart.ROM[0x40FFFC]) };
 unsigned ram_size = 0;
 int header_found = false;
 unsigned special_chip = SPECIAL_CHIP_NONE;
 unsigned rom_layout;

 if(maybe_exrom && rv[3] >= 0x8000)
  rom_layout = ROM_LAYOUT_EXHIROM;
 else if(rv[0] < 0x8000 && rv[1] >= 0x8000)
  rom_layout = ROM_LAYOUT_HIROM;
 else
  rom_layout = ROM_LAYOUT_LOROM;

 for(unsigned s = 0; s < 4 && header_found <= 0; s++)
 {
  uint8* tmp = &Cart.ROM[(s & 1) * 0x8000 + ((s & 2) ? 0x400000 : 0x000000)];

  if(rv[s] >= 0x8000)
  {
   const uint8 header_ram_size = tmp[0x7FD8];
   const uint8 header_rom_size = tmp[0x7FD7];
   const uint8 country_code = tmp[0x7FD9];
   const uint8 header_rom_speedmap = tmp[0x7FD5];
   const uint8 header_chipset = tmp[0x7FD6];
   const uint8 header_developer = tmp[0x7FDA];
   const uint8 header_subchip = tmp[0x7FBF];

   if(header_rom_size < 0x01 || header_rom_size > 0x0D || header_ram_size > 0x09)
    continue;

   if(tmp[0x7FDC] != (tmp[0x7FDE] ^ 0xFF) || tmp[0x7FDD] != (tmp[0x7FDF] ^ 0xFF))
   {
#if 0
    if((header_rom_speedmap & 0xE0) != 0x20)
     continue;

    if(!(0x2F & (1U << (header_rom_speedmap & 0xF))))
     continue;
#else
    if((header_rom_speedmap & 0xEE) != 0x20)
     continue;

    if(header_chipset != 0x02 && header_chipset != 0x00)
     continue;
#endif

    if(country_code > 0x14)
     continue;

    if(header_found)
     continue;

    //fprintf(stderr, "%02x %02x %02x %02x\n", tmp[0x7FD5], tmp[0x7FD6], tmp[0x7FD7], tmp[0x7FD8]);

    header_found = -1;
   }
   else
    header_found = true;
   //
   //
   //
   switch(country_code)
   {
    case 0x02:
    case 0x03:
    case 0x04:
    case 0x05:
    case 0x06:
    case 0x07:
    case 0x08:
    case 0x09:
    case 0x0A:
    case 0x0B:
    case 0x0C:
    case 0x11:
	IsPAL = true;
	break;
   }

   switch(header_rom_speedmap)
   {
    default:
	if(maybe_exrom && (s & 2))
	 rom_layout = (s & 1) ? ROM_LAYOUT_EXHIROM : ROM_LAYOUT_EXLOROM;
	else
	 rom_layout = (s & 1) ? ROM_LAYOUT_HIROM : ROM_LAYOUT_LOROM;
	break;

    case 0x30:
    case 0x20:
	rom_layout = ROM_LAYOUT_LOROM;

	// For "Derby Stallion 96", "RPG Tsukuru 2", and "Sound Novel Tsukuru"
	if(header_developer == 0x33 && tmp[0x7FB0] == 0x42 && tmp[0x7FB1] == 0x31 && tmp[0x7FB2] == 0x5A && tmp[0x7FB3] > 0x20 && tmp[0x7FB4] > 0x20 && tmp[0x7FB5] > 0x20)
	 rom_layout = ROM_LAYOUT_LOROM_SPECIAL;
	break;

    case 0x31:
    case 0x21:
	rom_layout = ROM_LAYOUT_HIROM;
	break;

    case 0x32:
	rom_layout = ROM_LAYOUT_EXLOROM;
	break;

    case 0x35:
	rom_layout = ROM_LAYOUT_EXHIROM;
	break;
   }

   if(rom_layout == ROM_LAYOUT_HIROM && (rv[1] < 0x8000) && (rv[0] >= 0x8000))
    rom_layout = ROM_LAYOUT_LOROM;
   else if(rom_layout == ROM_LAYOUT_LOROM && (rv[0] < 0x8000) && (rv[1] >= 0x8000))
    rom_layout = ROM_LAYOUT_HIROM;

   {
    const unsigned ln = header_chipset & 0xF;
    const unsigned hn = header_chipset >> 4;

    SNES_DBG("[CART] %02x %02x\n", header_chipset, header_subchip);

    ram_size = (header_ram_size ? (0x800 << (header_ram_size - 1)) : 0);

    SNES_DBG("[CART] %02x %02x %02x %02x --- %c%c%c%c\n", rom_layout, header_ram_size, header_rom_size, header_developer, tmp[0x7FB2], tmp[0x7FB3], tmp[0x7FB4], tmp[0x7FB5]);

    if(ln >= 0x3 && ln <= 0xA && ln != 0x7 && ln != 0x8)
    {
     switch(hn)
     {
      case 0x0: // DSPn
		if(rom_layout == ROM_LAYOUT_LOROM && header_ram_size == 0x05 && header_rom_size == 0x0A)
		{
		 SNES_DBG("[CART] DSP2\n");
		 special_chip = SPECIAL_CHIP_DSP2;
		}
		else if(rom_layout == ROM_LAYOUT_LOROM && header_ram_size == 0x03 && header_rom_size == 0x0A && header_developer == 0xB2)
		{
		 SNES_DBG("[CART] DSP3\n");
		 special_chip = SPECIAL_CHIP_DSP3;
		}
		else if(rom_layout == ROM_LAYOUT_LOROM && header_ram_size == 0x00 && header_rom_size == 0x0A && header_developer == 0x33)
		{
		 SNES_DBG("[CART] DSP4\n");
		 special_chip = SPECIAL_CHIP_DSP4;
		}
/*
		else if(rom_layout == ROM_LAYOUT_LOROM && header_ram_size == 0x03 && header_rom_size == 0x0A && header_developer == 0x29)
		{
		 SNES_DBG("ST010\n");
		 special_chip = SPECIAL_CHIP_ST010;
		}
*/
		else
		{
		 SNES_DBG("[CART] DSP1\n");
		 special_chip = SPECIAL_CHIP_DSP1;
		}
		break;

      case 0x1:
		special_chip = SPECIAL_CHIP_SUPERFX;
		if(!ram_size)
		{
		 const uint8 ex_header_ram_size = tmp[0x7FBD];

		 if(ex_header_ram_size == 0x5 || ex_header_ram_size == 0x6)
		  ram_size = 0x400 << ex_header_ram_size;
		 else
		  ram_size = 32768;
		}
		break;
      case 0x2: special_chip = SPECIAL_CHIP_OBC1; break; // OBC1
      case 0x3: special_chip = SPECIAL_CHIP_SA1; break; // SA1
      case 0x4: special_chip = SPECIAL_CHIP_SDD1; break; // SDD1
      case 0xF:
		switch(header_subchip)
		{
		 case 0x00: special_chip = SPECIAL_CHIP_SPC7110; break;
		 case 0x01: /*special_chip = SPECIAL_CHIP_ST010_ST011;*/ break;
		 case 0x02: special_chip = SPECIAL_CHIP_ST018; break;
		 case 0x10: special_chip = SPECIAL_CHIP_CX4; break;
	 	}
	 	break;
     }
    }
   }
   //
   //
   //
   if(rom_layout == ROM_LAYOUT_LOROM && special_chip == SPECIAL_CHIP_NONE && size <= (0x70 * 32768) && ram_size)
   {
    // For "Light Fantasy" and "Ys III"
    if(header_developer == 0xC6 || header_developer == 0x53)
    {
     for(uint64 i = 0; i < (1024 * 1024 - 7); i++)
     {
      uint8* const p = &Cart.ROM[i];
      bool isd = false;

      isd |= ((p[0] == 0xA9 && p[1] == 0x00) || p[1] == 0xA9) && p[2] == 0x00 && (p[3] == 0x9F || p[3] == 0x8F) && p[4] == 0x00 && p[5] == 0x80 && p[6] == 0x70;

      if(isd)
      {
       rom_layout = ROM_LAYOUT_LOROM_SRAM8000MIRROR;
       break;
      }
     }
    }
    // For "PGA Tour Golf"
    else if(header_rom_speedmap == 0x20 && header_rom_size == 0x09 && header_ram_size == 0x03 && (header_developer == 0x69 || (header_developer == 0x9C && country_code == 0x00)))
     rom_layout = ROM_LAYOUT_LOROM_SRAM8000MIRROR;
   }
  }
 }

 assert(rom_layout != ROM_LAYOUT_INVALID);
 //
 //
 //
 SNES_DBG("[CART] rom_layout=%d\n", rom_layout);
 Cart.ROMLayout = rom_layout;
 Cart.ROM_Size = size;
 //if((rom_type &~ 0x10) == 0x20)
 //{
 // assert(raw_ram_size <= 0x09);
 //}
 //else
 //{
 // assert(raw_ram_size <= 0x05);
 //}

 if(ram_size)
 {
  Cart.RAM = new uint8[ram_size];
  memset(Cart.RAM, 0x00, ram_size);
 }

 Cart.RAM_Size = ram_size;
 Cart.RAM_Mask = (size_t)ram_size - 1;
 SNES_DBG("[CART] Cart RAM Size: %zu\n", Cart.RAM_Size);
 //printf("%zu\n", Cart.RAM_Size);
// abort();

 //
 //
 //
 if(special_chip != SPECIAL_CHIP_SUPERFX && special_chip != SPECIAL_CHIP_SDD1)
 {
  for(unsigned bank = 0x00; bank < 0x100; bank++)
  {
   if(bank == 0x7E || bank == 0x7F)
    continue;

   readfunc cart_r;
   const writefunc cart_w = (bank & 0x80) ? OBWrite_VAR : OBWrite_SLOW;

   if(rom_layout == ROM_LAYOUT_LOROM || rom_layout == ROM_LAYOUT_EXLOROM || rom_layout == ROM_LAYOUT_LOROM_SRAM8000MIRROR)
   {
    if(rom_layout == ROM_LAYOUT_EXLOROM && bank < 0xC0)
     cart_r = ((bank >= 0x80) ? CartRead_LoROM<-1, 0x400000> : CartRead_LoROM<MEMCYC_SLOW, 0x400000>);
    else
     cart_r = ((bank >= 0x80) ? CartRead_LoROM<-1> : CartRead_LoROM<MEMCYC_SLOW>);

    Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, cart_r, cart_w);

    if(Cart.RAM_Mask != SIZE_MAX)
    {
     const uint16 ha = (rom_layout == ROM_LAYOUT_LOROM_SRAM8000MIRROR) ? 0xFFFF : 0x7FFF;

     if(bank >= 0x70 && bank <= 0x7D)
      Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | ha, CartRead_SRAM_LoROM<MEMCYC_SLOW>, CartWrite_SRAM_LoROM<MEMCYC_SLOW>);
     else if(bank >= 0xF0)
      Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | ha, CartRead_SRAM_LoROM<-1>, CartWrite_SRAM_LoROM<-1>);
    }
   }
   else if(rom_layout == ROM_LAYOUT_LOROM_SPECIAL)
   {
    uint32 la = 0x8000;
    uint32 ha = 0xFFFF;

    cart_r = (bank & 0x80) ? OBRead_VAR : OBRead_SLOW;

    if(bank < 0x40 || (bank >= 0xA0 && bank <= 0xBF))
     cart_r = (bank >= 0x80) ? CartRead_LoROM<-1> : CartRead_LoROM<MEMCYC_SLOW>;
    else if(bank >= 0x80 && bank <= 0x9F)
     cart_r = CartRead_LoROM<-1, 0x200000>;
    else if(bank >= 0xC0 && bank <= 0xDF)
    {
     la = 0x0000;
     cart_r = CartRead_LoROM<-1, 0x100000>;
    }

    Set_A_Handlers((bank << 16) | la, (bank << 16) | ha, cart_r, cart_w);

    if(Cart.RAM_Mask != SIZE_MAX)
    {
     if(bank >= 0x70 && bank <= 0x7D)
      Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0x7FFF, CartRead_SRAM_LoROM<MEMCYC_SLOW>, CartWrite_SRAM_LoROM<MEMCYC_SLOW>);
     else if(bank >= 0xF0)
      Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0x7FFF, CartRead_SRAM_LoROM<-1>, CartWrite_SRAM_LoROM<-1>);
    }
   }
   else
   {
    if(rom_layout == ROM_LAYOUT_EXHIROM && bank < 0xC0)
     cart_r = ((bank >= 0x80) ? CartRead_HiROM<-1, 0x400000> : CartRead_HiROM<MEMCYC_SLOW, 0x400000>);
    else
     cart_r = ((bank >= 0x80) ? CartRead_HiROM<-1> : CartRead_HiROM<MEMCYC_SLOW>);

    uint16 romlb = 0x8000;
    if(((bank & 0x7F) >= 0x40 && (bank & 0x7F) <= 0x7D) || bank >= 0xFE)
     romlb = 0x0000;

    Set_A_Handlers((bank << 16) | romlb, (bank << 16) | 0xFFFF, cart_r, cart_w);

    if(Cart.RAM_Mask != SIZE_MAX)
    {
     if((bank & 0x7F) >= 0x20 && (bank & 0x7F) <= 0x3F)
     {
      Set_A_Handlers((bank << 16) | 0x6000,
		    (bank << 16) | 0x7FFF,
		    CartRead_SRAM_HiROM, CartWrite_SRAM_HiROM);
     }
    }
   }  
  }
 }
 //
 //
 //
 const int32 master_clock = IsPAL ? 21281370 : 21477273;
 Cart.EventHandler = DummyEventHandler;
 Cart.Reset = nullptr;
 Cart.Kill = nullptr;
 Cart.StateAction = nullptr;
 Cart.AdjustTS = nullptr;

 switch(special_chip)
 {
  default:
	//assert(0);
	break;

  case SPECIAL_CHIP_NONE:
	break;

  case SPECIAL_CHIP_SA1:
	CART_SA1_Init(master_clock);
	break;

  case SPECIAL_CHIP_DSP1:
	CART_DSP1_Init(master_clock);
	break;

  case SPECIAL_CHIP_DSP2:
	CART_DSP2_Init(master_clock);
	break;

  case SPECIAL_CHIP_SDD1:
	CART_SDD1_Init(master_clock);
	break;

  case SPECIAL_CHIP_CX4:
	CART_CX4_Init(master_clock, cx4_ocmultiplier);
	break;

  case SPECIAL_CHIP_SUPERFX:
	CART_SuperFX_Init(master_clock, superfx_ocmultiplier, superfx_enable_icache);
	break;
 }
 //
 //
 //
 return IsPAL;
}

bool CART_LoadNV(void)
{
#ifndef MDFN_SNES_FAUST_SUPAFAUST
 if(Cart.RAM_Size)
 {
  try
  {
   const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "srm");
   FileStream fp(path, FileStream::MODE_READ);
   const uint64 fp_size_tmp = fp.size();

   if(Cart.RAM_Size != fp_size_tmp) // Check before reading any data.
    throw MDFN_Error(0, _("Save game memory file \"%s\" is an incorrect size(%llu bytes).  The correct size is %llu bytes."), path.c_str(), 
			(unsigned long long)fp_size_tmp, (unsigned long long)Cart.RAM_Size);

   fp.read(Cart.RAM, Cart.RAM_Size);

   return true;
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
#endif
 return false;
}

void CART_SaveNV(void)
{
#ifndef MDFN_SNES_FAUST_SUPAFAUST
 if(Cart.RAM_Size)
 {
  const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "srm");
  FileStream fp(path, FileStream::MODE_WRITE_INPLACE);

  fp.write(Cart.RAM, Cart.RAM_Size);
  fp.close();
 }
#endif
}

void CART_Kill(void)
{
 if(Cart.Kill)
 {
  Cart.Kill();
  Cart.Kill = nullptr;
 }

 if(Cart.RAM)
 {
  delete[] Cart.RAM;
  Cart.RAM = nullptr;
 }
}

void CART_Reset(bool powering_up)
{
 if(Cart.Reset)
  Cart.Reset(powering_up);
}

void CART_AdjustTS(const int32 delta)
{
 if(Cart.AdjustTS)
  Cart.AdjustTS(delta);
}

snes_event_handler CART_GetEventHandler(void)
{
 return Cart.EventHandler;
}

void CART_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8N(Cart.RAM, Cart.RAM_Size, SFORMAT::FORM::NVMEM, "&CartRAM[0]"),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART");

 if(Cart.StateAction)
  Cart.StateAction(sm, load, data_only);
}
//
//
//
uint8 CART_PeekRAM(uint32 addr)
{
 if(Cart.RAM_Mask != SIZE_MAX)
  return Cart.RAM[addr & Cart.RAM_Mask];

 return 0;
}

void CART_PokeRAM(uint32 addr, uint8 val)
{
 if(Cart.RAM_Mask != SIZE_MAX)
 {
  Cart.RAM[addr & Cart.RAM_Mask] = val;
 }
}

uint32 CART_GetRAMSize(void)
{
 return (size_t)(Cart.RAM_Mask + 1);
}

uint8* CART_GetRAMPointer(void)
{
 return Cart.RAM;
}

}
