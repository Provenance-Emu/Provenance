/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* stv.cpp - ST-V Cart Emulation
**  Copyright (C) 2022 Mednafen Team
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

/*
 TODO:
	315-5881 decryption support

	Decathlete decryption/decompression chip support
*/


#include "common.h"
#include "stv.h"
#include "../db.h"

#include <mednafen/hash/sha256.h>
#include <mednafen/Time.h>

namespace MDFN_IEN_SS
{

static unsigned ECChip;
static uint16* ROM;
#ifdef MDFN_ENABLE_DEV_BUILD
static uint8 ROM_Mapped[0x3000000 / sizeof(uint16)];
#endif

static uint8 rsg_thingy;
static uint8 rsg_counter;

static MDFN_HOT void ROM_Read(uint32 A, uint16* DB)
{
 *DB = *(uint16*)((uint8*)ROM + ((A - 0x2000000) & 0x3FFFFFE));

 //printf("ROM %08x %04x\n", A, *DB);

 //if(A >= 0x04FFFFF0)
 // printf("Unknown read %08x\n", A);

 if(A >= 0x04FFFFFC && rsg_thingy)
 {
  *DB = (((((rsg_counter & 0x7F) << 1) + 0) << 8) | ((((rsg_counter & 0x7F) << 1) + 1) << 0)) & (0xF0F0 >> ((rsg_counter & 0x80) >> 5));
  rsg_counter++;
 }

#ifdef MDFN_ENABLE_DEV_BUILD
 if(!ROM_Mapped[((A - 0x2000000) & 0x3FFFFFE) >> 1])
 {
  SS_DBG(SS_DBG_WARNING, "[CART-STV] Unmapped ROM: %08x %04x\n", A, *DB);
 }
#endif
}

uint8 CART_STV_PeekROM(uint32 A)
{
 assert(A < 0x3000000);

 return ne16_rbo_be<uint8>(ROM, A);
}

template<typename T>
static MDFN_HOT void Write(uint32 A, uint16* DB)
{
 //printf("Write%u: %08x %04x\n", (unsigned)sizeof(T), A, *DB);

 if(A >= 0x04FFFFF0 && ECChip == STV_EC_CHIP_RSG)
 {
  if(sizeof(T) == 2 || (A & 1))
  {
   if((A & ~1) == 0x04FFFFF0)
   {
    rsg_thingy = *DB & 0x1;
    rsg_counter = 0;
   }
  }
 }
}

static void Reset(bool powering_up)
{
 rsg_thingy = 0;
 rsg_counter = 0;
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(rsg_thingy),
  SFVAR(rsg_counter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "STV_CART");

 if(load)
 {

 }
}

static void Kill(void)
{
 if(ROM)
 {
  delete[] ROM;
  ROM = nullptr;
 }
}

void CART_STV_Init(CartInfo* c, GameFile* gf, const STVGameInfo* sgi)
{
 assert(gf && sgi);

 try
 {
  const std::string fname = gf->fbase + (gf->ext.size() ? "." : "") + gf->ext;
  sha256_hasher h;

  ECChip = sgi->ec_chip;

  ROM = new uint16[0x3000000 / sizeof(uint16)];
  memset(ROM, 0xFF, 0x3000000);
#ifdef MDFN_ENABLE_DEV_BUILD
  memset(ROM_Mapped, 0x00, sizeof(ROM_Mapped));
#endif

  for(size_t i = 0; i < sizeof(sgi->rom_layout) / sizeof(sgi->rom_layout[0]) && sgi->rom_layout[i].size; i++)
  {
   const STVROMLayout* rle = &sgi->rom_layout[i];
   const STVROMLayout* prev_rle = i ? &sgi->rom_layout[i - 1] : nullptr;
   const bool gf_fname_match = !MDFN_strazicmp(fname, rle->fname);
   const std::string fpath = gf->vfs->eval_fip(gf->dir, gf_fname_match ? fname : rle->fname);
   const bool prev_match = prev_rle && !strcmp(rle->fname, prev_rle->fname);
   std::unique_ptr<Stream> ns;
   Stream* s;

   if(gf_fname_match)
   {
    s = gf->stream;
    s->rewind();
   }
   else
   {
    ns.reset(gf->vfs->open(fpath, VirtualFS::MODE_READ));
    s = ns.get();
   }

#ifdef MDFN_ENABLE_DEV_BUILD
   memset(ROM_Mapped + (rle->offset >> 1), 0xFF, rle->size >> (rle->map != STV_MAP_BYTE));
#endif

   if(prev_match)
   {
    assert(rle->size == prev_rle->size);
    assert(rle->map == prev_rle->map);

    if(rle->map == STV_MAP_BYTE)
    {
     for(uint32 j = 0; j < rle->size; j++)
     {
      uint8 tmp = ne16_rbo_be<uint8>(ROM, prev_rle->offset + (j << 1));

      ne16_wbo_be<uint8>(ROM, rle->offset + (j << 1), tmp); 
     }
    }
    else
     memmove((uint8*)ROM + rle->offset, (uint8*)ROM + prev_rle->offset, rle->size);
   }
   else if(rle->map == STV_MAP_BYTE)
   {
    for(uint32 j = 0; j < rle->size; j++)
    {
     uint8 tmp;

     if(s->read(&tmp, 1, false) != 1)
      throw MDFN_Error(0, _("ROM image file %s is %u bytes smaller than the required size of %u bytes."), gf->vfs->get_human_path(fpath).c_str(), rle->size - j, rle->size);

     h.process(&tmp, 1);

     ne16_wbo_be<uint8>(ROM, rle->offset + (j << 1), tmp);
    }
   }
   else
   {
    assert(!(rle->offset & 1));
    assert(!(rle->size & 1));
    //
    uint8* dest = (uint8*)ROM + rle->offset;
    uint32 size = rle->size;
    uint32 dr;

    if((dr = s->read(dest, size, false)) != size)
     throw MDFN_Error(0, _("ROM image file %s is %u bytes smaller than the required size of %u bytes."), gf->vfs->get_human_path(fpath).c_str(), rle->size - dr, rle->size);

    h.process(dest, size);

    if(rle->map == STV_MAP_16LE)
     Endian_A16_NE_LE(dest, size >> 1);
    else
     Endian_A16_NE_BE(dest, size >> 1);
   }

   if(!prev_match)
   {
    const uint64 extra_data = s->read_discard();

    if(extra_data)
     throw MDFN_Error(0, _("ROM image file %s is %llu bytes larger than the required size of %u bytes."), gf->vfs->get_human_path(fpath).c_str(), (unsigned long long)extra_data, rle->size);
   }
  }

  if(sgi->romtwiddle == STV_ROMTWIDDLE_SANJEON)
  {
   for(uint32 i = 0; i < 0x3000000 / sizeof(uint64); i++)
   {
    uint64 tmp = MDFN_densb<uint64>((uint8*)ROM + (i << 3));

    tmp = ~tmp;
    tmp = ((tmp & 0x0404040404040404ULL) >> 2) | ((tmp & 0x0101010101010101ULL) << 6) | (tmp & 0x2020202020202020ULL) | ((tmp & 0x1010101010101010ULL) >> 3) | ((tmp & 0x4040404040404040ULL) << 1) | ((tmp & 0x0808080808080808ULL) >> 1) | ((tmp & 0x8080808080808080ULL) >> 3) | ((tmp & 0x0202020202020202ULL) << 2);

    MDFN_ennsb<uint64>((uint8*)ROM + (i << 3), tmp);
   }
  }

  {
   sha256_digest dig = h.digest();

   memcpy(MDFNGameInfo->MD5, dig.data(), 16);
  }

  SS_SetPhysMemMap (0x02000000, 0x04FFFFFF, ROM, 0x3000000, false);
  c->CS01_SetRW8W16(0x02000000, 0x04FFFFFF, ROM_Read, Write<uint8>, Write<uint16>);

  c->StateAction = StateAction;
  c->Reset = Reset;
  c->Kill = Kill;
 }
 catch(...)
 {
  Kill();
  throw;
 }
}

}
