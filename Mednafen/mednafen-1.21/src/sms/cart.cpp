/*
    Copyright (C) 1998-2004  Charles MacDonald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "shared.h"
#include "romdb.h"
#include "cart.h"
#include <mednafen/general.h>
#include <mednafen/hash/md5.h>

#include <zlib.h>

namespace MDFN_IEN_SMS
{

static uint8 *rom = NULL;
static uint8 pages;
static uint32 page_mask8;
static uint32 page_mask16;
static uint32 rom_mask;
static uint32 crc;
static int mapper;
static uint8 *sram = NULL;

static uint8 fcr[4];
static uint8 BankAdd;

static uint8 CodeMasters_Bank[3];

static uint8 *CastleRAM = NULL;

static void writemem_mapper_sega(uint16 A, uint8 V)
{
 if(A >= 0xFFFC)
 {
  fcr[A & 0x3] = V;
  if(A >= 0xFFFD)
  {
   static const int BankAddoo[4] = { 0x00, 0x18, 0x10, 0x08 };
   BankAdd = BankAddoo[fcr[0] & 0x3];
  }
 }
 if(fcr[0] & 0x3)
  printf("%02x\n", fcr[0] & 0x3);
}

static void writemem_mapper_codies(uint16 A, uint8 V)
{
 if(A < 0xC000)
 {
  if((CodeMasters_Bank[1] & 0x80) && (A >= 0xA000))
   sram[A & 0x1FFF] = V;
  else
   CodeMasters_Bank[A >> 14] = V;
 }
}

void Cart_Reset(void)
{
    CodeMasters_Bank[0] = 0;
    CodeMasters_Bank[1] = 0;
    CodeMasters_Bank[2] = 0;

    fcr[0] = 0x00;
    fcr[1] = 0x00;
    fcr[2] = 0x01;
    fcr[3] = 0x02;

    BankAdd = 0x00;
}

static const char *sms_mapper_string_table[] =
{
 "None",
 "Sega",
 "CodeMasters",
 "32KiB ROM + 8KiB RAM",
};

void Cart_Init(MDFNFILE* fp)
{
 uint64 size = fp->size();

 if(size & 512)
 {
  size &= ~512;
  fp->seek(512, SEEK_SET);
 }

 if(size > 1024 * 1024)
  throw MDFN_Error(0, _("SMS/GG ROM image is too large."));

 rom = new uint8[std::max<uint64>(size, 0x2000)];
 if(size < 0x2000)
  memset(rom + size, 0xFF, 0x2000 - size);
 fp->read(rom, size);

 pages = size / 0x2000;
 page_mask8 = round_up_pow2(pages) - 1;
 page_mask16 = page_mask8 >> 1;
 rom_mask = (round_up_pow2(pages) * 8192) - 1;

 crc = crc32(0, rom, size);

 md5_context md5;
 md5.starts();
 md5.update(rom, size);
 md5.finish(MDFNGameInfo->MD5);

 if(size <= 40960)
  mapper = MAPPER_NONE;
 else
  mapper = MAPPER_SEGA;

 const rominfo_t *romi;

 if((romi = find_rom_in_db(crc)))
 {
  mapper     = romi->mapper;
  sms.display     = romi->display;
  sms.territory   = romi->territory;
 }

 if(mapper == MAPPER_CASTLE)
 {
  CastleRAM = new uint8[8192];
  memset(CastleRAM, 0x00, 8192);
 }

 sram = new uint8[0x8000];
 memset(sram, 0x00, 0x8000);

 MDFN_printf(_("ROM:       %uKiB\n"), (unsigned)((size + 1023) / 1024));
 MDFN_printf(_("ROM CRC32: 0x%08x\n"), crc);
 MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());
 MDFN_printf(_("Mapper:    %s\n"), sms_mapper_string_table[mapper]);
 MDFN_printf(_("Territory: %s\n"), (sms.territory == TERRITORY_DOMESTIC) ? _("Domestic") : _("Export"));
}

void Cart_LoadNV(void)
{
 // Load battery-backed RAM, if any.
 if(sram)
 {
  try
  {
   std::unique_ptr<Stream> savegame_fp = MDFN_AmbigGZOpenHelper(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), std::vector<size_t>({ 0x8000 }));

   savegame_fp->read(sram, 0x8000);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
}

void Cart_SaveNV(void)
{
 if(sram)
 {
  for(int i = 0; i < 0x8000; i++)
  {
   if(sram[i] != 0x00)
   {
    MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), sram, 0x8000, true);
    break;
   }
  }
 }
}

void Cart_Close(void)
{
 if(rom)
 {
  delete[] rom;
  rom = NULL;
 }

 if(CastleRAM)
 {
  delete[] CastleRAM;
  CastleRAM = NULL;
 }

 if(sram)
 {
  delete[] sram;
  sram = NULL;
 }
}

void Cart_Write(uint16 A, uint8 V)
{
 if(mapper == MAPPER_CODIES)
  writemem_mapper_codies(A, V);
 else if(mapper == MAPPER_SEGA)
 {
  if(A >= 0x8000 && A < 0xC000)
  {
   if(fcr[0] & 0x8)
    sram[((fcr[0] & 0x4) ? 0x4000 : 0x0000) + (A & 0x3FFF)] = V;
  }
  else 
   writemem_mapper_sega(A, V);
 }
 else if(mapper == MAPPER_CASTLE)
 {
  if(A >= 0x8000 && A <= 0xBFFF)
   CastleRAM[A & 0x1FFF] = V;
 }
 else if(A < 0xc000)
  printf("Bah: %04x %02x\n", A, V);
}

uint8 Cart_Read(uint16 A)
{
 if(mapper == MAPPER_CODIES)
 {
  if(A < 0x4000) // 0 - 0x3fff
  {
   return(rom[(A & 0x3FFF) + ((CodeMasters_Bank[0] & page_mask16) << 14)]);
  }
  else if(A < 0x8000) // 0x4000 - 0x7FFF
  {
   return(rom[(A & 0x3FFF) + ((CodeMasters_Bank[1] & page_mask16) << 14)]);
  }
  else if(A < 0xC000) // 0x8000 - 0xBFFF
  {
   if((CodeMasters_Bank[1] & 0x80) && (A >= 0xA000))
    return(sram[A & 0x1FFF]);

   return(rom[(A & 0x3FFF) + ((CodeMasters_Bank[2] & page_mask16) << 14)]);
  }
 }
 else if(mapper == MAPPER_SEGA)
 {
  if(A < 0x4000)
  {
   if(A < 0x0400)
    return(rom[A]);
   else
    return(rom[(A & 0x3FFF) + (((fcr[1] + BankAdd) & page_mask16) << 14) ]);
  }
  else if(A < 0x8000)
  {
   return(rom[(A & 0x3FFF) + (((fcr[2] + BankAdd) & page_mask16) << 14) ]);
  }
  else if(A < 0xC000)
  {
   if(fcr[0] & 0x8)
    return(sram[((fcr[0] & 0x4) ? 0x4000 : 0x0000) + (A & 0x3FFF)]);
   else
    return(rom[(A & 0x3FFF) + (((fcr[3] + BankAdd) & page_mask16) << 14) ]);
  }
 }
 else if(mapper == MAPPER_CASTLE)
 {
  if(A >= 0x8000 && A <= 0xBFFF)
   return(CastleRAM[A & 0x1FFF]);
  else
   return(rom[A & rom_mask]);
 }
 else
 {
  return(rom[A & rom_mask]);
 }
 return((((A >> 8) | data_bus_pullup) & ~data_bus_pulldown));
}

void Cart_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(sram, 0x8000),
  SFPTR8(fcr, 4),
  SFVAR(BankAdd),
  SFPTR8(CodeMasters_Bank, 3),
  SFPTR8(CastleRAM, CastleRAM ? 8192 : 0),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART");

 if(load)
 {

 }
}

}
