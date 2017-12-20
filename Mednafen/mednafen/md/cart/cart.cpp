/* Mednafen - Multi-system Emulator
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

#include "../shared.h"
#include "cart.h"

#include "map_rom.h"
#include "map_sram.h"
#include "map_eeprom.h"
#include "map_svp.h"

#include "map_realtec.h"
#include "map_ssf2.h"

#include "map_ff.h"
#include "map_rmx3.h"
#include "map_sbb.h"
#include "map_yase.h"

#include "../header.h"
#include <mednafen/hash/md5.h>
#include <mednafen/general.h>
#include <ctype.h>

#include <zlib.h>

static MD_Cart_Type *cart_hardware = NULL;
static uint8 *cart_rom = NULL;
static uint32 Cart_ROM_Size;

void MDCart_Write8(uint32 A, uint8 V)
{
 cart_hardware->Write8(A, V);
}

void MDCart_Write16(uint32 A, uint16 V)
{
 cart_hardware->Write16(A, V);
}

uint8 MDCart_Read8(uint32 A)
{
 return(cart_hardware->Read8(A));
}

uint16 MDCart_Read16(uint32 A)
{
 return(cart_hardware->Read16(A));
}

void MDCart_Reset(void)
{
 cart_hardware->Reset();
}

// MD_Cart_Type* (*MapperMake)(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size);
// MD_Make_Cart_Type_REALTEC
// MD_Make_Cart_Type_SSF2
// Final Fantasy
// MD_Make_Cart_Type_FF
// MD_Make_Cart_Type_RMX3
// MD_Make_Cart_Type_SBB
// MD_Make_Cart_Type_YaSe

typedef struct
{
 // Set any field to 0(or -1 for signed fields) to ignore it
 const char *id;

 const uint64 md5;
 const uint64 header_md5;

 const char *mapper;

 // Overrides for bad headers
 const uint32 sram_type;
 const int32 sram_start;
 const int32 sram_end;

 const uint32 region_support;
} game_db_t;

static game_db_t GamesDB[] =
{
 // Balloon Boy
 { NULL, 0, 0xa9509f505d00db6eULL, "REALTEC", 0, 0, 0, 0 },

 // Earth Defend
 { NULL, 0, 0xcf6afbf45299a800ULL, "REALTEC", 0, 0, 0, 0 },

 // Whac a Critter
 { NULL, 0, 0x5499d14fcef32f60ULL, "REALTEC", 0, 0, 0, 0 },

 // Super Street Fighter II
 { "T-12056 -00", 0, 0, "SSF2", 0, 0, 0, 0 },
 { "T-12043 -00", 0, 0, "SSF2", 0, 0, 0, 0 },

// "Conquering the world III 0x3fff"
// "Xin Qi Gai Wing Zi", "
//	0xFFFF, 0x400000, 0x40ffff
// "Rings of Power",      0x200000  0x203fff

 // Final Fantasy
 { NULL, 0, 0x7c0e11c426d65105ULL, "FF", 0, 0, 0, 0 },
 { NULL, 0, 0xe144baf931c8b61eULL, "FF", 0, 0, 0, 0 },

 // Rockman X3
 { NULL, 0, 0x1d1add6f2a64fb99ULL, "RMX3", 0, 0, 0, 0 },

 // Super Bubble Bobble
 { NULL, 0, 0x8eff5373b653111eULL, "SBB", 0, 0, 0, 0 },

 // Ya-Se Chuan Shuo
 { NULL, 0, 0x2786df4902ef8856ULL, "YaSe", 0, 0, 0, 0 },

 // Virtua Racing
 { "MK-1229 -00", 0, 0, "SVP", 0, 0, 0, 0 },


 /***************************************
 //
 // SRAM-related header corrections
 //
 ***************************************/

 // Chaoji Dafuweng
 { NULL, 0, 0x13639e87230c85aaULL, NULL,  0x5241f820, 0x200001, 0x200fff, 0 },

 // Psy-O-Blade
 { "T-26013 -00", 0, 0, NULL, 0x5241f820, 0x200000, 0x203fff, 0 },

 // Sonic and Knuckles and Sonic 3
 { NULL, 0xde0ac4e17a844d10ULL, 0, NULL, 0x5241f820, 0x200000, 0x2003ff, 0 },

 // Starflight
 { "T-50216 -00", 0, 0, NULL, 0x5241f820, 0x200000, 0x203fff, 0 },
 { "T-50216 -01", 0, 0, NULL, 0x5241f820, 0x200000, 0x203fff, 0 },

 // Taiwan Tycoon(TODO)

 // Top Shooter
 { NULL, 0, 0x31fea3093b231863ULL, NULL,  0x5241f820, 0x200001, 0x203fff, 0 },

 // World Pro Baseball 94
 { NULL, 0, 0xe7bb31787f189ebeULL, NULL, 0x5241f820, 0x200001, 0x20ffff, 0 },


 /***************************************
 //
 // EEPROM Carts
 //
 ***************************************/
 
 //
 //	Acclaim
 //
 // NBA Jam (UE)
 {"T-081326 00", 0, 0, "Acclaim_24C02_Old", 0, 0, 0, 0  },

 // NBA Jam (J)   
 {"T-81033  00", 0, 0, "Acclaim_24C02_Old", 0, 0, 0, 0  },

 // NFL Quarterback Club
 {"T-081276 00", 0, 0, "Acclaim_24C02", 0, 0, 0, 0  },

 // NBA Jam TE
 {"T-81406 -00", 0, 0, "Acclaim_24C04", 0, 0, 0, 0  },

 // NFL Quarterback Club '96
 {"T-081586-00", 0, 0, "Acclaim_24C16", 0, 0, 0, 0  },

 // College Slam
 {"T-81576 -00", 0, 0, "Acclaim_24C65", 0, 0, 0, 0  },

 // Frank Thomas Big Hurt Baseball
 {"T-81476 -00", 0, 0, "Acclaim_24C65", 0, 0, 0, 0  },
        
 //
 //	EA
 //
 // Rings of Power
 {"T-50176 -00", 0, 0, "EA_24C01", 0, 0, 0, 0  },

 // NHLPA Hockey 93 (UE)
 {"T-50396 -00", 0, 0, "EA_24C01", 0, 0, 0, 0  },

 // John Madden Football 93
 {"T-50446 -00", 0, 0, "EA_24C01", 0, 0, 0, 0  },

 // John Madden Football 93 (Championship Edition)
 {"T-50516 -00", 0, 0, "EA_24C01", 0, 0, 0, 0  },

 // Bill Walsh College Football
 {"T-50606 -00", 0, 0, "EA_24C01", 0, 0, 0, 0  },


        
 //
 //	Sega
 //
 // Megaman - The Wily Wars
 {"T-12046 -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Rockman Mega World (J)
 {"T-12053 -00", 0, 0x969a9e19a5850e7cULL, "Sega_24C01", 0, 0, 0, 0  },	// Hash necessary due to hacked RAM-using version floating around.

 // Evander 'Real Deal' Holyfield's Boxing
 {"MK-1215 -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Greatest Heavyweights of the Ring (U)
 {"MK-1228 -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Greatest Heavyweights of the Ring (J)
 {"G-5538  -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Greatest Heavyweights of the Ring (E)
 {"PR-1993 -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },	// Confirm correct product code.

 // Wonderboy in Monster World
 {"G-4060  -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Sports Talk Baseball
 {"00001211-00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },
        
 // Honoo no Toukyuuji Dodge Danpei
 {"_00004076-00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Ninja Burai Densetsu
 {"G-4524  -00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },

 // Game Toshokan
 {"00054503-00", 0, 0, "Sega_24C01", 0, 0, 0, 0  },


 //
 //	Codemasters
 //
 // Brian Lara Cricket
 {"T-120106-00", 0, 0, "Codemasters_24C08", 0, 0, 0, 0  },
 {"T-120106-50", 0, 0, "Codemasters_24C08", 0, 0, 0, 0  },

 // Micro Machines Military
 { NULL, 0, 0x34253755ee0eed41ULL, "Codemasters_24C08", 0, 0, 0, 0  },

 // Micro Machines Military (bad)
 { NULL, 0, 0x3241b7da6ce42fecULL, "Codemasters_24C08", 0, 0, 0, 0  },

 // Micro Machines 2 - Turbo Tournament (E)
 {"T-120096-50", 0, 0, "Codemasters_24C16", 0, 0, 0, 0  },

 // Micro Machines Turbo Tournament 96
 {NULL, 0, 0xe672e84fed6ce270ULL, "Codemasters_24C16", 0, 0, 0, 0  },

 // Micro Machines Turbo Tournament 96 (bad)
 {NULL, 0, 0x290afe3cd27be26cULL, "Codemasters_24C16", 0, 0, 0, 0  },

 // Brian Lara Cricket 96, Shane Warne Cricket
 {"T-120146-50", 0, 0, "Codemasters_24C65", 0, 0, 0, 0  },
 //
 // End EEPROM carts
 //

 /*
 **  Header region corrections
 */
 // Gods (Europe)
 { "T-119036-50", 0, 0, NULL, 0, 0, 0, REGIONMASK_OVERSEAS_PAL },
/*
 REGIONMASK_JAPAN_NTSC = 1,
 REGIONMASK_JAPAN_PAL = 2,
 REGIONMASK_OVERSEAS_NTSC = 4,
 REGIONMASK_OVERSEAS_PAL = 8

 REGIONMASK_JAPAN_NTSC
*/
};

typedef struct
{
 const char *boardname;
 MD_Cart_Type *(*MapperMake)(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size, 
	const uint32 iparam, const char *sparam);
 const uint32 iparam;
 const char *sparam;
} BoardHandler_t;

static BoardHandler_t BoardHandlers[] =
{
 { "ROM", MD_Make_Cart_Type_ROM, 0, NULL },
 { "SRAM", MD_Make_Cart_Type_SRAM, 0, NULL },

 { "SVP", MD_Make_Cart_Type_SVP, 0, NULL },

 { "REALTEC", MD_Make_Cart_Type_REALTEC, 0, NULL },
 { "SSF2", MD_Make_Cart_Type_SSF2, 0, NULL },
 { "FF", MD_Make_Cart_Type_FF, 0, NULL },
 { "RMX3", MD_Make_Cart_Type_RMX3, 0, NULL },
 { "SBB", MD_Make_Cart_Type_SBB, 0, NULL },
 { "YaSe", MD_Make_Cart_Type_YaSe, 0, NULL },

 { "Acclaim_24C02_Old", MD_Make_Cart_Type_EEPROM, EEP_ACCLAIM_24C02_OLD, NULL },
 { "Acclaim_24C02", MD_Make_Cart_Type_EEPROM, EEP_ACCLAIM_24C02, NULL },
 { "Acclaim_24C04", MD_Make_Cart_Type_EEPROM, EEP_ACCLAIM_24C04, NULL },  
 { "Acclaim_24C16", MD_Make_Cart_Type_EEPROM, EEP_ACCLAIM_24C16, NULL },
 { "Acclaim_24C65", MD_Make_Cart_Type_EEPROM, EEP_ACCLAIM_24C65, NULL },

 { "EA_24C01", MD_Make_Cart_Type_EEPROM, EEP_EA_24C01, NULL },

 { "Sega_24C01", MD_Make_Cart_Type_EEPROM, EEP_SEGA_24C01, NULL },

 { "Codemasters_24C08", MD_Make_Cart_Type_EEPROM, EEP_CM_24C08, NULL },
 { "Codemasters_24C16", MD_Make_Cart_Type_EEPROM, EEP_CM_24C16, NULL },
 { "Codemasters_24C65", MD_Make_Cart_Type_EEPROM, EEP_CM_24C65, NULL },
 { NULL, NULL, 0, NULL },
};

bool MDCart_TestMagic(MDFNFILE *fp)
{
 if(!strcmp(fp->ext, "gen") || !strcmp(fp->ext, "md"))
  return true;

 uint8 data[512];

 if(fp->read(data, 512, false) != 512)
  return false;

 if(!memcmp(data + 0x100, "SEGA MEGA DRIVE", 15) || !memcmp(data + 0x100, "SEGA GENESIS", 12) || !memcmp(data + 0x100, "SEGA 32X", 8))
  return true;

 if((!memcmp(data + 0x100, "SEGA", 4) || !memcmp(data + 0x100, " SEGA", 5)) && !strcmp(fp->ext, "bin"))
  return true;

 return false;
}

static void Cleanup(void)
{
 if(cart_hardware)
 {
  delete cart_hardware;
  cart_hardware = NULL;
 }

 if(cart_rom)
 {
  MDFN_free(cart_rom);
  cart_rom = NULL;
 }
}

void MDCart_Load(md_game_info *ginfo, MDFNFILE *fp)
{
 try
 {
  const char *mapper = NULL;
  const uint64 fp_in_size = fp->size();

  if(fp_in_size < 0x200)
   throw MDFN_Error(0, _("ROM image is too small."));

  if(fp_in_size > 1024 * 1024 * 128)
   throw MDFN_Error(0, _("ROM image is too large."));

  Cart_ROM_Size = fp_in_size;
  cart_rom = (uint8 *)MDFN_calloc_T(1, Cart_ROM_Size, _("Cart ROM"));
  fp->read(cart_rom, Cart_ROM_Size);

  MD_ReadSegaHeader(cart_rom + 0x100, ginfo);
  ginfo->rom_size = Cart_ROM_Size;

  md5_context md5;
  md5.starts();
  md5.update(cart_rom, Cart_ROM_Size);
  md5.finish(ginfo->md5);

  ginfo->crc32 = crc32(0, cart_rom, Cart_ROM_Size);

  md5.starts();
  md5.update(cart_rom + 0x100, 0x100);
  md5.finish(ginfo->info_header_md5);

  ginfo->checksum_real = 0;
  for(uint32 i = 0x200; i < Cart_ROM_Size; i += 2)
  {
   ginfo->checksum_real += cart_rom[i + 0] << 8;
   ginfo->checksum_real += cart_rom[i + 1] << 0;
  }

  // Rockman MegaWorld: 5241e840
  // Sonic 3: 5241f820

  uint32 sram_type = MDFN_de32msb(&cart_rom[0x1B0]);
  uint32 sram_start = MDFN_de32msb(&cart_rom[0x1B4]);
  uint32 sram_end = MDFN_de32msb(&cart_rom[0x1B8]);

  {
   uint64 hmd5_partial = 0;
   uint64 md5_partial = 0;

   for(int i = 0; i < 8; i++)
   {
    hmd5_partial |= (uint64)ginfo->info_header_md5[15 - i] << (8 * i);
    md5_partial |= (uint64)ginfo->md5[15 - i] << (8 * i);
   }
   //printf("Real: 0x%016llxULL    Header: 0x%016llxULL\n", (unsigned long long)md5_partial, (unsigned long long)hmd5_partial);

   for(unsigned int i = 0; i < sizeof(GamesDB) / sizeof(game_db_t); i++)
   {
    bool found = true;

    if(GamesDB[i].header_md5 && GamesDB[i].header_md5 != hmd5_partial)
     found = false;

    if(GamesDB[i].md5 && GamesDB[i].md5 != md5_partial)
     found = false;

    if(GamesDB[i].id && strcmp(GamesDB[i].id, ginfo->product_code))
     found = false;

    if(found)
    {
     if(GamesDB[i].mapper)
      mapper = GamesDB[i].mapper;

     if(GamesDB[i].sram_type != ~0U)
      sram_type = GamesDB[i].sram_type;
     if(GamesDB[i].sram_start > 0)
      sram_start = GamesDB[i].sram_start;
     if(GamesDB[i].sram_end > 0)
      sram_end = GamesDB[i].sram_end;

     if(GamesDB[i].region_support > 0)
      ginfo->region_support = GamesDB[i].region_support;

     break;
    }
   }
  }
 
  if(sram_type == 0x5241f820 && sram_start == 0x20202020)
   sram_type = 0x20202020;

  ginfo->sram_type = sram_type;
  ginfo->sram_start = sram_start;
  ginfo->sram_end = sram_end;

  if(!mapper)
  {
   if(sram_type == 0x5241f820)
    mapper = "SRAM";
   else if(sram_type == 0x5241e840)
    mapper = "Sega_24C01";
   else
    mapper = "ROM";
  }

  {
   const BoardHandler_t *bh = BoardHandlers;
   bool BoardFound = FALSE;

   MDFN_printf(_("Mapper: %s\n"), mapper);
   MDFN_printf(_("SRAM Type:  0x%08x\n"), sram_type);
   MDFN_printf(_("SRAM Start: 0x%08x\n"), sram_start);
   MDFN_printf(_("SRAM End:   0x%08x\n"), sram_end);
   while(bh->boardname)
   {
    if(!strcasecmp(bh->boardname, mapper))
    {
     cart_hardware = bh->MapperMake(ginfo, cart_rom, Cart_ROM_Size, bh->iparam, bh->sparam);
     BoardFound = TRUE;
     break;
    }
    bh++;
   }
   if(!BoardFound)
   {
    throw MDFN_Error(0, _("Handler for mapper/board \"%s\" not found!\n"), mapper);
   }
  }

  //MD_Cart_Type* (*MapperMake)(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size) = NULL;
  //cart_hardware = MapperMake(ginfo, cart_rom, Cart_ROM_Size);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

void MDCart_LoadNV(void)
{
 if(cart_hardware->GetNVMemorySize())
 {
  try
  {
   uint8 buf[cart_hardware->GetNVMemorySize()];
   std::unique_ptr<Stream> sp = MDFN_AmbigGZOpenHelper(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav").c_str(), std::vector<size_t>({ sizeof(buf) }));

   sp->read(buf, sizeof(buf));
   cart_hardware->WriteNVMemory(buf);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
}

void MDCart_SaveNV(void)
{
 if(cart_hardware->GetNVMemorySize())
 {
  uint8 buf[cart_hardware->GetNVMemorySize()];

  cart_hardware->ReadNVMemory(buf);

  MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), buf, sizeof(buf), true);
 }
}

void MDCart_Kill(void)
{
 Cleanup();
}

int MDCart_StateAction(StateMem *sm, int load, int data_only)
{
 return(cart_hardware->StateAction(sm, load, data_only, "CARTBOARD"));
}

