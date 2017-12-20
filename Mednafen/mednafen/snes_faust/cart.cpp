/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "snes.h"
#include "cart.h"

#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/hash/sha1.h>

#include <vector>

namespace MDFN_IEN_SNES_FAUST
{
static uint8 CartROM[8192 * 1024];
static std::vector<uint8> CartRAM;

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(CartRead_LoROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

 return (CartROM + rom_offset)[(A & 0x7FFF) | ((A >> 1) & 0x3F8000)];
}

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(CartRead_HiROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

 return (CartROM + rom_offset)[A & 0x3FFFFF];
}

template<signed cyc>
static DEFREAD(CartRead_SRAM_LoROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

 return CartRAM[((A & 0x7FFF) | ((A >> 1) &~ 0x7FFF)) & (CartRAM.size() - 1)];
}

template<signed cyc>
static DEFWRITE(CartWrite_SRAM_LoROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

 CartRAM[((A & 0x7FFF) | ((A >> 1) &~ 0x7FFF)) & (CartRAM.size() - 1)] = V;
}


template<signed cyc>
static DEFREAD(CartRead_SRAM_HiROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;
 //
 //
 const unsigned raw_sram_index = (A & 0x1FFF) | ((A >> 3) & 0x3E000);

 return CartRAM[raw_sram_index & (CartRAM.size() - 1)];
}

template<signed cyc>
static DEFWRITE(CartWrite_SRAM_HiROM)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;
 //
 //
 const unsigned raw_sram_index = (A & 0x1FFF) | ((A >> 3) & 0x3E000);

 CartRAM[raw_sram_index & (CartRAM.size() - 1)] = V;
}

enum
{
 ROM_LAYOUT_LOROM = 0,
 ROM_LAYOUT_HIROM,
 ROM_LAYOUT_EXLOROM,
 ROM_LAYOUT_EXHIROM,

 ROM_LAYOUT_INVALID = 0xFFFFFFFF
};

void CART_Init(Stream* fp, uint8 id[16])
{
 static const uint64 max_rom_size = 8192 * 1024;
 const uint64 raw_size = fp->size();
 const unsigned copier_header_adjust = ((raw_size & 0x7FFF) == 512) ? 512 : 0;
 const uint64 size = raw_size - copier_header_adjust;

 //printf("%llu\n", (unsigned long long)size);

 if(size > max_rom_size)
  throw MDFN_Error(0, _("SNES ROM image is too large."));

 fp->seek(copier_header_adjust, SEEK_SET);
 fp->read(CartROM, size);

 {
  sha1_digest sd = sha1(CartROM, size);
  memcpy(id, &sd[0], 16);
 }

 for(uint32 s = size, i = 0; s < 8192 * 1024; i++)
 {
  if(s & (1U << i))
  {
   SNES_DBG("[CART] Copy 0x%08x bytes from 0x%08x to 0x%08x\n", 1U << i, s - (1U << i), s);
   memcpy(CartROM + s, CartROM + s - (1U << i), 1U << i);
   s += (1U << i);
  }
 }
 //
 //
 //

 unsigned rom_layout = ROM_LAYOUT_INVALID;
 unsigned ram_size = 0;
 uint8* header = NULL;

 for(unsigned s = 0; s < 2; s++)
 {
  unsigned char* tmp = &CartROM[s * 0x8000];
  unsigned rv = MDFN_de16lsb(&tmp[0x7FFC]);

  if(rv >= 0x8000)
  {
   const uint8 header_ram_size = tmp[0x7FD8];
   const uint8 header_rom_size = tmp[0x7FD7];
   const uint8 country_code = tmp[0x7FD9];
   const uint8 header_rom_type = tmp[0x7FD5];

   if(rom_layout == ROM_LAYOUT_INVALID)
    rom_layout = (s ? ROM_LAYOUT_HIROM : ROM_LAYOUT_LOROM);

   if(header_rom_size >= 0x01 && header_rom_size <= 0x0D && header_ram_size >= 0x00 && header_ram_size <= 0x09)
   {
    if(tmp[0x7FDC] == (tmp[0x7FDE] ^ 0xFF) && tmp[0x7FDD] == (tmp[0x7FDF] ^ 0xFF))
    {
     switch(header_rom_type)
     {
      case 0x30:
      case 0x20:
	rom_layout = ROM_LAYOUT_LOROM;
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

      default:
	if(size >= 4 * 1024 * 1024 + 32768)
	 rom_layout = s ? ROM_LAYOUT_EXHIROM : ROM_LAYOUT_EXLOROM;
	else
	 rom_layout = s ? ROM_LAYOUT_HIROM : ROM_LAYOUT_LOROM;
	break;
     }

     ram_size = (header_ram_size ? (0x800 << (header_ram_size - 1)) : 0);
     break;
    }
   }
  }
 }

 if(rom_layout == ROM_LAYOUT_INVALID)	// FIXME: Error out?
  rom_layout = ROM_LAYOUT_LOROM;

 SNES_DBG("[CART] rom_layout=%d\n", rom_layout);
 //if((rom_type &~ 0x10) == 0x20)
 //{
 // assert(raw_ram_size <= 0x09);
 //}
 //else
 //{
 // assert(raw_ram_size <= 0x05);
 //}

 CartRAM.resize(ram_size);

 SNES_DBG("[CART] Cart RAM Size: %zu\n", CartRAM.size());
 //printf("%zu\n", CartRAM.size());
// abort();

 //
 //
 //
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank == 0x7E || bank == 0x7F)
   continue;

  readfunc cart_r;
  writefunc cart_w;

  if(rom_layout == ROM_LAYOUT_LOROM || rom_layout == ROM_LAYOUT_EXLOROM)
  {
   if(rom_layout == ROM_LAYOUT_EXLOROM && bank < 0xC0)
    cart_r = ((bank >= 0x80) ? CartRead_LoROM<-1, 0x400000> : CartRead_LoROM<MEMCYC_SLOW, 0x400000>);
   else
    cart_r = ((bank >= 0x80) ? CartRead_LoROM<-1> : CartRead_LoROM<MEMCYC_SLOW>);

   cart_w = OBWrite_SLOW;

   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, cart_r, cart_w);

   if(CartRAM.size())
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

   cart_w = OBWrite_SLOW;

   uint16 romlb = 0x8000;
   if(((bank & 0x7F) >= 0x40 && (bank & 0x7F) <= 0x7D) || bank >= 0xFE)
    romlb = 0x0000;

   Set_A_Handlers((bank << 16) | romlb, (bank << 16) | 0xFFFF, cart_r, cart_w);

   if(CartRAM.size())
   {
    if((bank & 0x7F) >= 0x20 && (bank & 0x7F) <= 0x3F)
    {
     Set_A_Handlers((bank << 16) | 0x6000,
		    (bank << 16) | 0x7FFF,
		    ((bank & 0x80) ? CartRead_SRAM_HiROM<-1> : CartRead_SRAM_HiROM<MEMCYC_SLOW>),
		    ((bank & 0x80) ? CartWrite_SRAM_HiROM<-1> : CartWrite_SRAM_HiROM<MEMCYC_SLOW>));
    }
   }
  }  
 }
}

bool CART_LoadNV(void)
{
 if(CartRAM.size() > 0)
 {
  try
  {
   const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "srm");
   FileStream fp(path, FileStream::MODE_READ);
   const uint64 fp_size_tmp = fp.size();

   if(CartRAM.size() != fp_size_tmp) // Check before reading any data.
    throw MDFN_Error(0, _("Save game memory file \"%s\" is an incorrect size(%llu bytes).  The correct size is %llu bytes."), path.c_str(), 
			(unsigned long long)fp_size_tmp, (unsigned long long)CartRAM.size());

   fp.read(CartRAM.data(), CartRAM.size());

   return true;
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
 return false;
}

void CART_SaveNV(void)
{
 if(CartRAM.size() > 0)
 {
  const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "srm");
  FileStream fp(path, FileStream::MODE_WRITE_INPLACE);

  fp.write(CartRAM.data(), CartRAM.size());
  fp.close();
 }
}

void CART_Kill(void)
{
 CartRAM.resize(0);
}

void CART_Reset(bool powering_up)
{


}


void CART_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY(&CartRAM[0], CartRAM.size()),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART");
}

}
