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

namespace MDFN_IEN_PCE
{

static uint8 mpr_start[8];
static uint8 IBP[0x100];
static uint8 *rom = NULL, *rom_backup = NULL;

static uint8 CurrentSong;
static bool bootstrap;
static bool ROMWriteWarningGiven;

uint8 ReadIBP(unsigned int A)
{
 if(!(A & 0x100))
  return(IBP[A & 0xFF]);

 if(bootstrap)
 {
  if(!PCE_InDebug)
  {
   memcpy(rom + 0x1FF0, rom_backup + 0x1FF0, 16);
   bootstrap = false;
  }
  return(CurrentSong);
 }

 return(0xFF);
}

static DECLFW(HESROMWrite)
{
 if(bootstrap)
 {
  puts("Write during bootstrap?");
  return;
 }

 rom[A] = V;
 //printf("%08x: %02x\n", A, V);
 if(!ROMWriteWarningGiven)
 {
  MDFN_printf(_("Warning:  HES is writing to physical address %08x.  Future warnings of this nature are temporarily disabled for this HES file.\n"), A);
  ROMWriteWarningGiven = TRUE;
 }
}

static const uint8 BootROM[16] = { 0xA9, 0xFF, 0x53, 0x01, 0xEA, 0xEA, 0xEA, 0xEA, 
				   0xEA, 0xEA, 0xEA, 0x4C, 0x00, 0x1C, 0xF0, 0xFF };

static DECLFR(HESROMRead)
{
 return(rom[A]);
}

static void Cleanup(void)
{
 if(rom)
 {
  MDFN_free(rom);
  rom = NULL;
 }

 if(rom_backup)
 {
  MDFN_free(rom_backup);
  rom_backup = NULL;
 }
}

static const uint8 vdc_init_rom[] =
{
	0xA0, 0x01,

	0x8C, 0x0E, 0x00,	// SGFX ST_mode

	//
	//
	//
	0xA2, 0x1F,

	0x8E, 0x00, 0x00,
	0x8E, 0x10, 0x00,

	0x13, 0x00,
	0x23, 0x00,
	0xCA,
	0x10, 0xF3,
	//
	//
	//
	0x03, 0x0A,
	0x13, 0x02,
	0x23, 0x02,

	0x03, 0x0B,
	0x13, 0x1F,
	0x23, 0x04,

	0x03, 0x0C,
	0x13, 0x02,
	0x23, 0x0D,

	0x03, 0x0D,
	0x13, 0xEF,
	0x23, 0x00,

	0x03, 0x0E,
	0x13, 0x04,

	0x88,
	0x10, 0xCF,

	// VCE init
	0xA9, 0x04,
	0x8D, 0x00, 0x04,
};

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

  rom = (uint8 *)MDFN_malloc_T(0x88 * 8192, _("HES ROM"));
  rom_backup = (uint8 *)MDFN_malloc_T(0x88 * 8192, _("HES ROM"));

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

  //
  // Try to detect SuperGrafx rips in the future?
  //
  //for(unsigned i = 0; i < 0x80; i++)
  //{
  // printf("0x%02x: 0x%08x\n", i, (uint32)crc32(0, &rom[i * 8192], 8192));
  //}
  //
  //
  //

  CurrentSong = StartingSong;
  TotalSongs = 256;
  uint8 *IBP_WR = IBP;

  for(int i = 0; i < 8; i++)
  {
   *IBP_WR++ = 0xA9;		// LDA (immediate)
   *IBP_WR++ = mpr_start[i];
   *IBP_WR++ = 0x53;		// TAM
   *IBP_WR++ = 1 << i;
  }

  // Initialize VDC registers.
  memcpy(IBP_WR, vdc_init_rom, sizeof(vdc_init_rom));
  IBP_WR += sizeof(vdc_init_rom);

  *IBP_WR++ = 0xAD;		// LDA(absolute)
  *IBP_WR++ = 0x00;		//
  *IBP_WR++ = 0x1D;		//
  *IBP_WR++ = 0x20;               // JSR
  *IBP_WR++ = InitAddr;           //  JSR target LSB
  *IBP_WR++ = InitAddr >> 8;      //  JSR target MSB
  *IBP_WR++ = 0x58;               // CLI
  *IBP_WR++ = 0xCB;               // (Mednafen Special)
  *IBP_WR++ = 0x80;               // BRA
  *IBP_WR++ = 0xFD;               //  -3

  assert((unsigned int)(IBP_WR - IBP) <= sizeof(IBP));

  Player_Init(TotalSongs, "", "", ""); //NULL, NULL, NULL, NULL); //UTF8 **snames);

  for(int x = 0; x < 0x88; x++)
  {
   if(x)
    HuCPU->SetFastRead(x, rom + x * 8192);
   HuCPU->SetReadHandler(x, HESROMRead);
   HuCPU->SetWriteHandler(x, HESROMWrite);
  }

  ROMWriteWarningGiven = FALSE;
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

void HES_Reset(void)
{
 memcpy(rom, rom_backup, 0x88 * 8192);
 memcpy(rom + 0x1FF0, BootROM, 16);
 bootstrap = true;
}

void HES_Update(EmulateSpecStruct *espec, uint16 jp_data)
{
 static uint8 last = 0;
 bool needreload = 0;

 if((jp_data & 0x20) && !(last & 0x20))
 {
  CurrentSong++;
  needreload = 1;
 }

 if((jp_data & 0x80) && !(last & 0x80))
 {
  CurrentSong--;
  needreload = 1;
 }

 if((jp_data & 0x8) && !(last & 0x8))
  needreload = 1;

 if((jp_data & 0x10) && !(last & 0x10))
 {
  CurrentSong += 10;
  needreload = 1;
 }

 if((jp_data & 0x40) && !(last & 0x40))
 {
  CurrentSong -= 10;
  needreload = 1;
 }

 last = jp_data;

 if(needreload)
  PCE_Power();

 if(!espec->skip)
  Player_Draw(espec->surface, &espec->DisplayRect, CurrentSong, espec->SoundBuf, espec->SoundBufSize);
}

void HES_Close(void)
{
 Cleanup();
}


};
