/* Mednafen - Multi-system Emulator
 *
 *  Portions of this file Copyright (C) 2004 Ki
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

/*
 TODO: Allow HuC6280 code to execute properly in the Street Fighter 2 mapper's bankswitched region.
*/

#include "pce.h"
#include "pcecd.h"
#include <mednafen/hw_misc/arcade_card/arcade_card.h>
#include <mednafen/hash/md5.h>
#include <mednafen/file.h>
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/mempatcher.h>
#include <mednafen/compress/GZFileStream.h>

#include "huc.h"

namespace PCE_Fast
{

static const uint8 BRAM_Init_String[8] = { 'H', 'U', 'B', 'M', 0x00, 0x88, 0x10, 0x80 }; //"HUBM\x00\x88\x10\x80";

ArcadeCard *arcade_card = NULL;

static uint8 *HuCROM = NULL;

static bool IsPopulous;
bool PCE_IsCD;

static uint8 SaveRAM[2048];

static DECLFW(ACPhysWrite)
{
 arcade_card->PhysWrite(A, V);
}

static DECLFR(ACPhysRead)
{
 return(arcade_card->PhysRead(A));
}

static DECLFR(SaveRAMRead)
{
 if((!PCE_IsCD || PCECD_IsBRAMEnabled()) && (A & 8191) < 2048)
  return(SaveRAM[A & 2047]);
 else
  return(0xFF);
}

static DECLFW(SaveRAMWrite)
{
 if((!PCE_IsCD || PCECD_IsBRAMEnabled()) && (A & 8191) < 2048)
  SaveRAM[A & 2047] = V;
}

static DECLFR(HuCRead)
{
 return ROMSpace[A];
}

static DECLFW(HuCRAMWrite)
{
 ROMSpace[A] = V;
}

static DECLFW(HuCRAMWriteCDSpecial) // Hyper Dyne Special hack
{
 BaseRAM[0x2000 | (A & 0x1FFF)] = V;
 ROMSpace[A] = V;
}

static uint8 HuCSF2Latch = 0;

static DECLFR(HuCSF2Read)
{
 return(HuCROM[(A & 0x7FFFF) + 0x80000 + HuCSF2Latch * 0x80000 ]); // | (HuCSF2Latch << 19) ]);
}

static DECLFW(HuCSF2Write)
{
 if((A & 0x1FFC) == 0x1FF0)
 {
  HuCSF2Latch = (A & 0x3);
 }
}

static void Cleanup(void) MDFN_COLD;
static void Cleanup(void)
{
 if(arcade_card)
 {
  delete arcade_card;
  arcade_card = NULL;
 }

 if(PCE_IsCD)
 {
  PCECD_Close();
 }

 if(HuCROM)
 {
  delete[] HuCROM;
  HuCROM = NULL;
 }
}

static void LoadSaveMemory(const std::string& path, uint8* const data, const uint64 len)
{
 try
 {
  GZFileStream fp(path, GZFileStream::MODE::READ);
  const uint64 fp_size_tmp = fp.size();

  if(fp_size_tmp != len)
   throw MDFN_Error(0, _("Save game memory file \"%s\" is an incorrect size(%llu bytes).  The correct size is %llu bytes."), path.c_str(), (unsigned long long)fp_size_tmp, (unsigned long long)len);

  fp.read(data, len);
 }
 catch(MDFN_Error &e)
 {
  if(e.GetErrno() != ENOENT)
   throw;
 }
}

uint32 HuC_Load(MDFNFILE* fp)
{
 uint32 crc = 0;

 try
 {
  uint32 sf2_threshold = 2048 * 1024;
  uint32 sf2_required_size = 2048 * 1024 + 512 * 1024;
  uint64 len = fp->size();

  if(len & 512) // Skip copier header.
  {
   len &= ~512;
   fp->seek(512, SEEK_SET);
  }

  uint64 m_len = (len + 8191)&~8191;
  bool sf2_mapper = false;

  if(m_len >= sf2_threshold)
  {
   sf2_mapper = true;

   if(m_len != sf2_required_size)
    m_len = sf2_required_size;
  }

  IsPopulous = 0;
  PCE_IsCD = 0;


  HuCROM = new uint8[m_len];
  memset(HuCROM, 0xFF, m_len);
  fp->read(HuCROM, std::min<uint64>(m_len, len));

  md5_context md5;
  md5.starts();
  md5.update(HuCROM, std::min<uint64>(m_len, len));
  md5.finish(MDFNGameInfo->MD5);

  crc = crc32(0, HuCROM, std::min<uint64>(m_len, len));

  MDFN_printf(_("ROM:       %lluKiB\n"), (unsigned long long)(std::min<uint64>(m_len, len) / 1024));
  MDFN_printf(_("ROM CRC32: 0x%04x\n"), crc);
  MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());

  memset(ROMSpace, 0xFF, 0x88 * 8192 + 8192);

  if(m_len == 0x60000)
  {
   memcpy(ROMSpace + 0x00 * 8192, HuCROM, 0x20 * 8192);
   memcpy(ROMSpace + 0x20 * 8192, HuCROM, 0x20 * 8192);
   memcpy(ROMSpace + 0x40 * 8192, HuCROM + 0x20 * 8192, 0x10 * 8192);
   memcpy(ROMSpace + 0x50 * 8192, HuCROM + 0x20 * 8192, 0x10 * 8192);
   memcpy(ROMSpace + 0x60 * 8192, HuCROM + 0x20 * 8192, 0x10 * 8192);
   memcpy(ROMSpace + 0x70 * 8192, HuCROM + 0x20 * 8192, 0x10 * 8192);
  }
  else if(m_len == 0x80000)
  {
   memcpy(ROMSpace + 0x00 * 8192, HuCROM, 0x40 * 8192);
   memcpy(ROMSpace + 0x40 * 8192, HuCROM + 0x20 * 8192, 0x20 * 8192);
   memcpy(ROMSpace + 0x60 * 8192, HuCROM + 0x20 * 8192, 0x20 * 8192);
  }
  else
  {
   memcpy(ROMSpace + 0x00 * 8192, HuCROM, (m_len < 1024 * 1024) ? m_len : 1024 * 1024);
  }

  for(int x = 0x00; x < 0x80; x++)
  {
   HuCPU.FastMap[x] = &ROMSpace[x * 8192];
   HuCPU.PCERead[x] = HuCRead;
  }

  if(!memcmp(HuCROM + 0x1F26, "POPULOUS", strlen("POPULOUS")))
  {
   uint8 *PopRAM = ROMSpace + 0x40 * 8192;
   memset(PopRAM, 0xFF, 32768);

   LoadSaveMemory(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), PopRAM, 32768);

   IsPopulous = 1;

   MDFN_printf("Populous\n");

   for(int x = 0x40; x < 0x44; x++)
   {
    HuCPU.FastMap[x] = &PopRAM[(x & 3) * 8192];
    HuCPU.PCERead[x] = HuCRead;
    HuCPU.PCEWrite[x] = HuCRAMWrite;
   }
   MDFNMP_AddRAM(32768, 0x40 * 8192, PopRAM);
  }
  else
  {
   memset(SaveRAM, 0x00, 2048);
   memcpy(SaveRAM, BRAM_Init_String, 8);    // So users don't have to manually intialize the file cabinet
                                            // in the CD BIOS screen.
   
   LoadSaveMemory(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), SaveRAM, 2048);

   HuCPU.PCEWrite[0xF7] = SaveRAMWrite;
   HuCPU.PCERead[0xF7] = SaveRAMRead;
   MDFNMP_AddRAM(2048, 0xF7 * 8192, SaveRAM);
  }

  // 0x1A558
  //if(len >= 0x20000 && !memcmp(HuCROM + 0x1A558, "STREET FIGHTER#", strlen("STREET FIGHTER#")))
  if(sf2_mapper)
  {
   for(int x = 0x40; x < 0x80; x++)
   {
    HuCPU.PCERead[x] = HuCSF2Read;
   }
   HuCPU.PCEWrite[0] = HuCSF2Write;
   MDFN_printf("Street Fighter 2 Mapper\n");
   HuCSF2Latch = 0;
  }
 }
 catch(...)
 {
  Cleanup();
  throw;
 }

 return crc;
}
 
bool IsBRAMUsed(void)
{
 if(memcmp(SaveRAM, BRAM_Init_String, 8)) // HUBM string is modified/missing
  return(1);

 for(int x = 8; x < 2048; x++)
  if(SaveRAM[x]) return(1);

 return(0);
}

void HuC_LoadCD(const std::string& bios_path)
{
 static const FileExtensionSpecStruct KnownBIOSExtensions[] =
 {
  { ".pce", gettext_noop("PC Engine ROM Image") },
  { ".bin", gettext_noop("PC Engine ROM Image") },
  { ".bios", gettext_noop("BIOS Image") },
  { NULL, NULL }
 };

 try
 {
  MDFNFILE fp(bios_path.c_str(), KnownBIOSExtensions, _("CD BIOS"));

  memset(ROMSpace, 0xFF, 262144);

  if(fp.size() & 512)
   fp.seek(512, SEEK_SET);

  fp.read(ROMSpace, 262144);

  fp.Close();

  PCE_IsCD = 1;
  PCE_InitCD();

  MDFN_printf(_("Arcade Card Emulation:  %s\n"), PCE_ACEnabled ? _("Enabled") : _("Disabled")); 
  for(int x = 0; x < 0x40; x++)
  {
   HuCPU.FastMap[x] = &ROMSpace[x * 8192];
   HuCPU.PCERead[x] = HuCRead;
  }

  for(int x = 0x68; x < 0x88; x++)
  {
   HuCPU.FastMap[x] = &ROMSpace[x * 8192];
   HuCPU.PCERead[x] = HuCRead;
   HuCPU.PCEWrite[x] = HuCRAMWrite;
  }
  HuCPU.PCEWrite[0x80] = HuCRAMWriteCDSpecial; 	// Hyper Dyne Special hack
  MDFNMP_AddRAM(262144, 0x68 * 8192, ROMSpace + 0x68 * 8192);

  if(PCE_ACEnabled)
  {
   arcade_card = new ArcadeCard();

   for(int x = 0x40; x < 0x44; x++)
   {
    HuCPU.PCERead[x] = ACPhysRead;
    HuCPU.PCEWrite[x] = ACPhysWrite;
   }
  }

  memset(SaveRAM, 0x00, 2048);
  memcpy(SaveRAM, BRAM_Init_String, 8);	// So users don't have to manually intialize the file cabinet
						// in the CD BIOS screen.

  LoadSaveMemory(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), SaveRAM, 2048);

  HuCPU.PCEWrite[0xF7] = SaveRAMWrite;
  HuCPU.PCERead[0xF7] = SaveRAMRead;
  MDFNMP_AddRAM(2048, 0xF7 * 8192, SaveRAM);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

void HuC_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] = 
 {
  SFPTR8(ROMSpace + 0x40 * 8192, IsPopulous ? 32768 : 0),
  SFPTR8(SaveRAM, IsPopulous ? 0 : 2048),
  SFPTR8(ROMSpace + 0x68 * 8192, PCE_IsCD ? 262144 : 0),
  SFVAR(HuCSF2Latch),
  SFEND
 };
 MDFNSS_StateAction(sm, load, data_only, StateRegs, "HuC");

 if(load)
  HuCSF2Latch &= 0x3;

 if(PCE_IsCD)
 {
  PCECD_StateAction(sm, load, data_only);

  if(arcade_card)
   arcade_card->StateAction(sm, load, data_only);
 }
}

//
// HuC_Kill() may be called before HuC_Load*() is called or even after it errors out, so we have a separate HuC_SaveNV()
// to prevent save game file corruption in case of error.
void HuC_Kill(void)
{
 Cleanup();
}

void HuC_SaveNV(void)
{
 if(IsPopulous)
 {
  MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), ROMSpace + 0x40 * 8192, 32768);
 }
 else if(IsBRAMUsed())
 {
  MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), SaveRAM, 2048);
 }
}

void HuC_Power(void)
{
 if(PCE_IsCD)
  memset(ROMSpace + 0x68 * 8192, 0x00, 262144);

 if(arcade_card)
  arcade_card->Power();
}

};
