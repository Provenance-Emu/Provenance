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

#include "pce.h"
#include "hes.h"
#include "huc.h"
#include "pcecd.h"
#include <mednafen/player.h>

namespace PCE_Fast
{


static uint8 mpr_start[8];
static uint8 IBP_Bank[0x2000];
static uint8 *rom = NULL, *rom_backup = NULL;

static uint8 CurrentSong;
static bool bootstrap;
static bool ROMWriteWarningGiven;

uint8 ReadIBP(unsigned int A)
{
 if(!(A & 0x100))
  return(IBP_Bank[0x1C00 + (A & 0xF)]);

 if(bootstrap)
 {
  memcpy(rom + 0x1FF0, rom_backup + 0x1FF0, 16);
  bootstrap = false;
  return(CurrentSong);
 }
 return(0xFF);
}

static DECLFW(HESROMWrite)
{
 rom[A] = V;
 //printf("%08x: %02x\n", A, V);
 if(!ROMWriteWarningGiven)
 {
  MDFN_printf(_("Warning:  HES is writing to physical address %08x.  Future warnings of this nature are temporarily disabled for this HES file.\n"), A);
  ROMWriteWarningGiven = true;
 }
}

static DECLFR(HESROMRead)
{
 return(rom[A]);
}

static void Cleanup(void) MDFN_COLD;
static void Cleanup(void)
{
 PCECD_Close();

 if(rom)
 {
  delete[] rom;
  rom = NULL;
 }

 if(rom_backup)
 {
  delete[] rom_backup;
  rom_backup = NULL;
 }
}

void HES_Load(MDFNFILE* fp)
{
 try
 {
  uint32 LoadAddr, LoadSize;
  uint16 InitAddr;
  uint8 StartingSong;
  int TotalSongs;
  uint8 header[0x10];
  uint8 sub_header[0x10];

  fp->read(header, 0x10);

  if(memcmp(header, "HESM", 4))
   throw MDFN_Error(0, _("HES header magic is invalid."));

  InitAddr = MDFN_de16lsb(&header[0x6]);

  rom = new uint8[0x88 * 8192];
  rom_backup = new uint8[0x88 * 8192];

  MDFN_printf(_("HES Information:\n"));
  MDFN_AutoIndent aind(1);

  StartingSong = header[5];

  MDFN_printf(_("Init address: 0x%04x\n"), InitAddr);
  MDFN_printf(_("Starting song: %d\n"), StartingSong + 1);

  for(int x = 0; x < 8; x++)
  {
   mpr_start[x] = header[0x8 + x];
   MDFN_printf("MPR%d: 0x%02x\n", x, mpr_start[x]);
  }

  memset(rom, 0, 0x88 * 8192);
  memset(rom_backup, 0, 0x88 * 8192);

  while(fp->read(sub_header, 0x10, false) == 0x10)
  {
   LoadSize = MDFN_de32lsb(&sub_header[0x4]);
   LoadAddr = MDFN_de32lsb(&sub_header[0x8]);

   //printf("Size: %08x(%d), Addr: %08x, La: %02x\n", LoadSize, LoadSize, LoadAddr, LoadAddr / 8192);
   MDFN_printf(_("Chunk load:\n"));

   MDFN_AutoIndent aindc(1);
   MDFN_printf(_("File offset:  0x%08llx\n"), (unsigned long long)fp->tell() - 0x10);
   MDFN_printf(_("Load size:  0x%08x\n"), LoadSize);
   MDFN_printf(_("Load target address:  0x%08x\n"), LoadAddr);

   // 0x88 * 8192 = 0x110000
   if(((uint64)LoadAddr + LoadSize) > 0x110000)
   {
    MDFN_printf(_("Warning:  HES is trying to load data past boundary.\n"));

    if(LoadAddr >= 0x110000)
     break;

    LoadSize = 0x110000 - LoadAddr;
   }

   uint64 rc = fp->read(rom + LoadAddr, LoadSize, false);
   if(rc < LoadSize)
   {
    MDFN_printf(_("Warning:  HES tried to load %llu bytes more data than exists!\n"), (unsigned long long)(LoadSize - rc));
   }
  }

  memcpy(rom_backup, rom, 0x88 * 8192);

  CurrentSong = StartingSong;
  TotalSongs = 256;

  memset(IBP_Bank, 0, 0x2000);

  uint8 *IBP_WR = IBP_Bank + 0x1C00;

  for(int i = 0; i < 8; i++)
  {
   *IBP_WR++ = 0xA9;             // LDA (immediate)
   *IBP_WR++ = mpr_start[i];
   *IBP_WR++ = 0x53;             // TAM
   *IBP_WR++ = 1 << i;
  }

  *IBP_WR++ = 0xAD;              // LDA(absolute)
  *IBP_WR++ = 0x00;              //
  *IBP_WR++ = 0x1D;              //
  *IBP_WR++ = 0x20;               // JSR
  *IBP_WR++ = InitAddr;           //  JSR target LSB
  *IBP_WR++ = InitAddr >> 8;      //  JSR target MSB
  *IBP_WR++ = 0x58;               // CLI
  *IBP_WR++ = 0xFC;               // (Mednafen Special)
  *IBP_WR++ = 0x80;               // BRA
  *IBP_WR++ = 0xFD;               //  -3

  Player_Init(TotalSongs, "", "", ""); //NULL, NULL, NULL, NULL); //UTF8 **snames);

  for(int x = 0; x < 0x80; x++)
  {
   HuCPU.FastMap[x] = &rom[x * 8192];
   HuCPU.PCERead[x] = HESROMRead;
   HuCPU.PCEWrite[x] = HESROMWrite;
  }

  HuCPU.FastMap[0xFF] = IBP_Bank;

  // FIXME:  If a HES rip tries to execute a SCSI command, the CD emulation code will probably crash.  Obviously, a HES rip shouldn't do this,
  // but Mednafen shouldn't crash either. ;)
  PCE_IsCD = 1;
  PCE_InitCD();

  ROMWriteWarningGiven = false;
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}


static const uint8 BootROM[16] = { 0xA9, 0xFF, 0x53, 0x01, 0xEA, 0xEA, 0xEA, 0xEA, 
                                   0xEA, 0xEA, 0xEA, 0x4C, 0x00, 0x1C, 0xF0, 0xFF };
void HES_Reset(void)
{
 memcpy(rom, rom_backup, 0x88 * 8192);
 memcpy(rom + 0x1FF0, BootROM, 16);
 bootstrap = true;
}


void HES_Draw(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int16 *SoundBuf, int32 SoundBufSize)
{
 extern uint16 pce_jp_data[5];
 static uint8 last = 0;
 bool needreload = 0;
 uint8 newset = (pce_jp_data[0] ^ last) & pce_jp_data[0];

 if(newset & 0x20)
 {
  CurrentSong++;
  needreload = 1;
 }

 if(newset & 0x80)
 {
  CurrentSong--;
  needreload = 1;
 }

 if(newset & 0x08)
  needreload = 1;

 if(newset & 0x10)
 {
  CurrentSong += 10;
  needreload = 1;
 }

 if(newset & 0x40)
 {
  CurrentSong -= 10;
  needreload = 1;
 }

 last = pce_jp_data[0];

 if(needreload)
  PCE_Power();

 Player_Draw(surface, DisplayRect, CurrentSong, SoundBuf, SoundBufSize);
}

void HES_Close(void)
{
 Cleanup();
}



};
