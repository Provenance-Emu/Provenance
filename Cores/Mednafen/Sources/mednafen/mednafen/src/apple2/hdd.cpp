/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* hdd.cpp:
**  Copyright (C) 2023 Mednafen Team
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

#include <mednafen/mednafen.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/SimpleBitset.h>

#include "apple2.h"
#include "hdd.h"

namespace MDFN_IEN_APPLE2
{
namespace HDD
{
//
//
static const uint8 ROM[0x100] = 
{
 #include "firmware/hdd_driver.bin.h"
};

enum
{
 STATUS_WP    = 0x01,
 //
 STATUS_SIG   = 0x08,
 STATUS__RESERVED_MASK = 0x3E,
 //
 STATUS_BUSY  = 0x40,
 STATUS_ERROR = 0x80,
};

static uint8 Buffer[512];
static uint32 BufferOffs;

static uint8 Magic;
static uint16 LBATemp;
static uint16 WriteBlock;
static bool Error;

static uint8* Data;
static uint16 BlockCount;
static bool WriteProtect;

static uint8* StateHelper;
static SimpleBitset<65535> BlockModified;

static DEFREAD(ReadROM)
{
 //if(!InHLPeek)
 // printf("ROM Read: %04x\n", A);

 DB = ROM[A & 0xFF];
 if(!InHLPeek)
 {
  CPUTick1();
 }
}

static DEFREAD(ReadStatus)
{
 DB = STATUS_SIG | (WriteProtect ? STATUS_WP : 0) | (Error ? STATUS_ERROR : 0);
 //
 if(!InHLPeek)
 {
  CPUTick1();
 }
}

static DEFWRITE(WriteStatus)
{
 const uint8 tv = DB & 0x1C;

 if(tv != 0x04 && tv != 0x08 && tv != 0x10)
  WriteBlock = 0xFFFF;
 //
 CPUTick1();
}

static DEFRW(RWBad)
{
 WriteBlock = 0xFFFF;
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLBA)
{
 const unsigned shift = (A & 1) << 3;

 LBATemp &= ~(0xFF << shift);
 LBATemp |= DB << shift;

 WriteBlock = 0xFFFF;

 if(!shift)
  Error = false;
 else if(shift)
 {
  if(LBATemp >= BlockCount)
   Error = true;
  else
  {
   //printf("Block: 0x%04x\n", LBATemp);
   memcpy(Buffer, Data + (LBATemp << 9), 512);
   WriteBlock = LBATemp;
   BufferOffs = 0;
   Magic = 0xFF;
  }
 }
 //
 CPUTick1();
}

static DEFREAD(ReadBlockCount)
{
 const unsigned shift = (A & 1) << 3;

 DB = BlockCount >> shift;

 if(!InHLPeek)
 {
  WriteBlock = 0xFFFF;
  //
  CPUTick1();
 }
}

static DEFREAD(ReadData)
{
 //printf("ReadData: writeblock=0x%04x, offs=%u\n", WriteBlock, BufferOffs);
 DB = Buffer[((BufferOffs >> 1) | (BufferOffs << 8)) & 0x1FF];

 if(!InHLPeek)
 {
  BufferOffs = (BufferOffs + 1) & 0x1FF;
  WriteBlock = 0xFFFF;
  //
  CPUTick1();
 }
}

static DEFWRITE(WriteMagic)
{
 Magic = DB ^ 0xAA;
 //
 CPUTick1();
}

static DEFWRITE(WriteData)
{
 //printf("Write: block=0x%04x, offs=%u, db=%02x, magic=0x%02x\n", WriteBlock, BufferOffs, DB, Magic);
 //
 if((BufferOffs >> 1) != Magic)
  WriteBlock = 0xFFFF;
 //
 Buffer[((BufferOffs >> 1) | (BufferOffs << 8)) & 0x1FF] = DB;
 BufferOffs = (BufferOffs + 1) & 0x1FF;

 if(!BufferOffs && WriteBlock != 0xFFFF && !WriteProtect)
 {
  uint8* const tp = Data + (WriteBlock << 9);
  if(memcmp(tp, Buffer, 512))
  {
   BlockModified.set(WriteBlock, true);	// Never set to false here.
   memcpy(tp, Buffer, 512);
  }
  //
  WriteBlock = 0xFFFF;
 }
 //
 CPUTick1();
}

static MDFN_WARN_UNUSED_RESULT uint32 SaveSHDelta(void)
{
 uint32 SHSize = 0;

 for(unsigned i = 0; i < BlockCount; i++)
 {
  if(BlockModified[i])
  {
   memcpy(StateHelper + SHSize, Data + i * 512, 512);
   SHSize += 512;
  }
 }

 return SHSize;
}

static void LoadSHDelta(void)
{
 for(unsigned i = 0, offs = 0; i < BlockCount; i++)
 {
  if(BlockModified[i])
  {
   memcpy(Data + i * 512, StateHelper + offs, 512);
   offs += 512;
  }
 }
}

void StateAction_Disk(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT BMStateRegs[] =
 {
  SFVARN(BlockModified.data, "BlockModified"),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, BMStateRegs, "HDD_MODIFIED_BITMAP");
 //
 //
 uint32 SHSize;

 SHSize = SaveSHDelta();

 SFORMAT DataStateRegs[] =
 {
  SFPTR8(StateHelper, SHSize),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, DataStateRegs, "HDD_MODIFIED_DATA");

 if(load)
 {
  LoadSHDelta();
 }
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(Buffer),
  SFVAR(BufferOffs),

  SFVAR(Magic),
  SFVAR(LBATemp),
  SFVAR(WriteBlock),

  SFVAR(Error),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "HDD");

 if(load)
 {
  BufferOffs &= 0x1FF;

  if(WriteBlock != 0xFFFF)
   WriteBlock %= BlockCount;
 }
 //
 StateAction_Disk(sm, load, data_only);
}

void Power(void)
{
 memset(Buffer, 0xFF, sizeof(Buffer));
 BufferOffs = 0;

 Magic = 0xFF;
 LBATemp = 0xFFFF;
 WriteBlock = 0xFFFF;

 Error = false;
}

static void LoadDisk(Stream* sp, const std::string& ext)
{
 assert(!Data);
 //
 const uint64 size = sp->size();

 if(size < 512)
  throw MDFN_Error(0, _("Virtual hard disk drive image is too small."));
 else if(size > (512 * 0xFFFF))
  throw MDFN_Error(0, _("Virtual hard disk drive image is too large."));
 else if(size & 0x1FF)
  throw MDFN_Error(0, _("Virtual hard disk drive image size is not a multiple of 512."));
 //
 //
 const uint32 scan_size = std::min<uint64>(size, 0x800);
 std::unique_ptr<uint8[]> tmp(new uint8[scan_size]);
 uint16 vol_block_count = 0;

 sp->read(tmp.get(), scan_size);

 if(scan_size >= 0x600)
 {
  uint8* p = tmp.get() + 0x400;

  if(MDFN_de16lsb(p + 0) == 0x0000 && (p[0x04] & 0xF0) == 0xF0)
   vol_block_count = MDFN_de16lsb(p + 0x29);
 }
 BlockCount = std::max<uint16>(size >> 9, vol_block_count);
 //
 //
 assert(size <= BlockCount * 512);
 //
 Data = new uint8[BlockCount * 512];
 memset(Data, 0, BlockCount * 512);
 memcpy(Data, tmp.get(), scan_size);

 sp->read(Data + scan_size, size - scan_size);

 BlockModified.reset();
}

static void HashDisk(sha256_hasher* h)
{
 h->process(Data, 512 * BlockCount);
}

bool GetEverModified(void)
{
 bool ret = false;

 for(unsigned i = 0; i < BlockCount; i++)
  ret |= BlockModified[i];

 return ret;
}

void LoadDelta(Stream* sp)
{
 assert(Data);
 //
 uint8 bm[0x2000];

 sp->read(bm, sizeof(bm));

 for(unsigned i = 0; i < BlockCount; i++)
 {
  if((bm[i >> 3] >> (i & 0x7)) & 1)
  {
   BlockModified.set(i, true);
   sp->read(Data + i * 512, 512);
  }
 }
}

void SaveDelta(Stream* sp)
{
 assert(Data);
 //
 uint8 bm[0x2000];

 for(unsigned i = 0; i < 0x2000; i += 4)
  MDFN_en32lsb(bm + i, BlockModified.data[i >> 2]);

 sp->write(bm, sizeof(bm));

 for(unsigned i = 0; i < BlockCount; i++)
 {
  if((bm[i >> 3] >> (i & 0x7)) & 1)
   sp->write(Data + i * 512, 512);
 }
}

/*
void SaveDisk(Stream* sp)
{
 assert(Data);
 sp->write(Data, BlockCount * 512);
}
*/

uint32 Init(unsigned slot, Stream* sp, const std::string& ext, sha256_hasher* h, const bool write_protect)
{
 uint16 base = 0xC080 + (slot << 4);
 //
 SetRWHandlers(base + 0x0, ReadStatus, WriteStatus);
 SetRWHandlers(base + 0x1, ReadData, RWBad);
 SetRWHandlers(base + 0x2, ReadBlockCount, RWBad);
 SetRWHandlers(base + 0x3, ReadBlockCount, RWBad);

 SetWriteHandler(base + 0x4, WriteMagic);
 SetWriteHandler(base + 0x5, WriteData);
 SetWriteHandler(base + 0x6, WriteLBA);
 SetWriteHandler(base + 0x7, WriteLBA);

 for(unsigned i = 0x8; i < 0x10; i++)
  SetRWHandlers(base + i, RWBad, RWBad);
 //
 for(unsigned i = 0; i < 0x100; i++)
 {
  readfunc_t rf = ReadROM;

  SetReadHandler(0xC000 + (slot << 8) + i, rf);
 }

 //
 //
 //
 WriteProtect = write_protect;

 LoadDisk(sp, ext);
 HashDisk(h);

 StateHelper = new uint8[BlockCount * 512];

 return BlockCount;
}

void Kill(void)
{
 if(Data)
 {
  delete[] Data;
  Data = nullptr;
 }

 if(StateHelper)
 {
  delete[] StateHelper;
  StateHelper = nullptr;
 }

 BlockCount = 0;
}


//
//
}
}
