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

#include "nes.h"
#include <math.h>
#include "x6502.h"
#include "sound.h"
#include "nsf.h"
#include "nsfe.h"
#include "fds.h"
#include "fds-sound.h"
#include "cart.h"
#include "input.h"
#include <mednafen/player.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int NSFVRC6_Init(EXPSOUND *, bool MultiChip);
int NSFMMC5_Init(EXPSOUND *, bool MultiChip);
int NSFAY_Init(EXPSOUND *, bool MultiChip);
int NSFN106_Init(EXPSOUND *, bool MultiChip);
int NSFVRC7_Init(EXPSOUND *, bool MultiChip);

namespace MDFN_IEN_NES
{

int NSFFDS_Init(EXPSOUND *, bool MultiChip);

static DECLFW(NSF_write);
static DECLFR(NSF_read);
static void NSF_init(void);

static NSFINFO *NSFInfo;
typedef std::vector<writefunc> NSFWriteEntry;
static NSFWriteEntry *WriteHandlers = NULL; //[0x10000];

static uint8 NSFROM[0x30+6]=
{
/* 0x00 - NMI */
0x8D,0xF4,0x3F,                         /* Stop play routine NMIs. */
0xA2,0xFF,0x9A,                         /* Initialize the stack pointer. */
0xAD,0xF0,0x3F,                         /* See if we need to init. */
0xF0,0x09,                              /* If 0, go to play routine playing. */

0xAD,0xF1,0x3F,                         /* Confirm and load A      */
0xAE,0xF3,0x3F,                         /* Load X with PAL/NTSC byte */

0x20,0x00,0x00,                         /* JSR to init routine     */

0xA9,0x00,
0xAA,
0xA8,
0x20,0x00,0x00,                         /* JSR to play routine  */
0x8D,0xF5,0x3F,				/* Start play routine NMIs. */
0x90,0xFE,                               /* Loopie time. */

/* 0x20 */
0x8D,0xF3,0x3F,				/* Init init NMIs */
0x18,
0x90,0xFE				/* Loopie time. */
};

static DECLFR(NSFROMRead)
{
 return (NSFROM-0x3800)[A];
}

static uint8 BSon;

static uint8 SongReload;
static bool doreset = false;
static int NSFNMIFlags;
static uint8 *ExWRAM = NULL;

static void FreeNSF(void)
{
 if(NSFInfo)
 {
  delete NSFInfo;
  NSFInfo = NULL;
 }

 if(ExWRAM)
 {
  free(ExWRAM);
  ExWRAM = NULL;
 }

 if(WriteHandlers)
 {
  delete[] WriteHandlers;
  WriteHandlers = NULL;
 }
}

static void NSF_Kill(void)
{
 FreeNSF();
}

static void NSF_Reset(void)
{
 NSF_init();
}

static void NSF_Power(void)
{
 NSF_init();
}

static void NSF_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SongReload),
  SFVAR(doreset),
  SFVAR(NSFNMIFlags),
  SFARRAY(ExWRAM, ((NSFInfo->SoundChip&4) ? (32768+8192) : 8192)),

  SFVAR(NSFInfo->CurrentSong),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "NSF");

 if(load)
 {
  NSFInfo->CurrentSong %= NSFInfo->TotalSongs;
 }
}


// First 32KB is reserved for sound chip emulation in the iNES mapper code.

static INLINE void BANKSET(uint32 A, uint32 bank)
{
 bank &= NSFInfo->NSFMaxBank;
 if(NSFInfo->SoundChip&4)
  memcpy(ExWRAM+(A-0x6000),NSFInfo->NSFDATA+(bank<<12),4096);
 else 
  setprg4(A,bank);
}

static void LoadNSF(Stream *fp)
{
 NSF_HEADER NSFHeader;

 fp->read(&NSFHeader, 0x80);

 // NULL-terminate strings just in case.
 NSFHeader.GameName[31] = NSFHeader.Artist[31] = NSFHeader.Copyright[31] = 0;

 NSFInfo->GameName = std::string(MDFN_RemoveControlChars((char *)NSFHeader.GameName));
 NSFInfo->Artist = std::string(MDFN_RemoveControlChars((char *)NSFHeader.Artist));
 NSFInfo->Copyright = std::string(MDFN_RemoveControlChars((char *)NSFHeader.Copyright));

 MDFN_trim(NSFInfo->GameName);
 MDFN_trim(NSFInfo->Artist);
 MDFN_trim(NSFInfo->Copyright);

 NSFInfo->LoadAddr = NSFHeader.LoadAddressLow | (NSFHeader.LoadAddressHigh << 8);
 NSFInfo->InitAddr = NSFHeader.InitAddressLow | (NSFHeader.InitAddressHigh << 8);
 NSFInfo->PlayAddr = NSFHeader.PlayAddressLow | (NSFHeader.PlayAddressHigh << 8);

 uint64 tmp_size = fp->size() - 0x80;
 if(tmp_size > 16 * 1024 * 1024)
  throw MDFN_Error(0, _("NSF is too large."));

 NSFInfo->NSFSize = tmp_size;

 NSFInfo->NSFMaxBank = ((NSFInfo->NSFSize+(NSFInfo->LoadAddr&0xfff)+4095)/4096);
 NSFInfo->NSFMaxBank = round_up_pow2(NSFInfo->NSFMaxBank);

 NSFInfo->NSFDATA=(uint8 *)MDFN_malloc_T(NSFInfo->NSFMaxBank*4096, _("NSF data"));

 memset(NSFInfo->NSFDATA, 0x00, NSFInfo->NSFMaxBank*4096);
 fp->read(NSFInfo->NSFDATA+(NSFInfo->LoadAddr&0xfff), NSFInfo->NSFSize);
 
 NSFInfo->NSFMaxBank--;

 NSFInfo->VideoSystem = NSFHeader.VideoSystem;
 NSFInfo->SoundChip = NSFHeader.SoundChip;
 NSFInfo->TotalSongs = NSFHeader.TotalSongs;

 if(NSFHeader.StartingSong == 0)
  NSFHeader.StartingSong = 1;

 NSFInfo->StartingSong = NSFHeader.StartingSong - 1;
 memcpy(NSFInfo->BankSwitch, NSFHeader.BankSwitch, 8);
}


bool NSF_TestMagic(MDFNFILE *fp)
{
 uint8 magic[5];

 if(fp->read(magic, 5, false) != 5 || (memcmp(magic, "NESM\x1a", 5) && memcmp(magic, "NSFE", 4)))
  return false;

 return true;
} 

void NSFLoad(Stream *fp, NESGameType *gt)
{
 try
 {
  char magic[5];
  int x;

  NSFInfo = new NSFINFO();

  fp->rewind();
  fp->read(magic, 5);

  if(!memcmp(magic, "NESM\x1a", 5))
  {
   fp->rewind();
   LoadNSF(fp);
  }
  else if(!memcmp(magic, "NSFE", 4))
  {
   fp->rewind();
   LoadNSFE(NSFInfo, fp, 0);
  }

  if(NSFInfo->LoadAddr < 0x6000)
   throw MDFN_Error(0, _("Load address is invalid!"));

  if(NSFInfo->TotalSongs < 1)
   throw MDFN_Error(0, _("Total number of songs is less than 1!"));

  BSon = 0;
  for(x=0;x<8;x++)
   BSon |= NSFInfo->BankSwitch[x];

  MDFNGameInfo->GameType = GMT_PLAYER;

  if(NSFInfo->GameName.size())
   MDFNGameInfo->name = strdup(NSFInfo->GameName.c_str());

  for(x=0;;x++)
  {
   if(NSFROM[x]==0x20)
   {
    NSFROM[x+1]=NSFInfo->InitAddr&0xFF;
    NSFROM[x+2]=NSFInfo->InitAddr>>8;
    NSFROM[x+8]=NSFInfo->PlayAddr&0xFF;
    NSFROM[x+9]=NSFInfo->PlayAddr>>8;
    break;
   }
  }

  if(NSFInfo->VideoSystem == 0)
   MDFNGameInfo->VideoSystem = VIDSYS_NTSC;
  else if(NSFInfo->VideoSystem == 1)
   MDFNGameInfo->VideoSystem = VIDSYS_PAL;

  MDFN_printf(_("NSF Loaded.  File information:\n\n"));
  MDFN_indent(1);
  if(NSFInfo->GameName.size())
   MDFN_printf(_("Game/Album Name:\t%s\n"), NSFInfo->GameName.c_str());
  if(NSFInfo->Artist.size())
   MDFN_printf(_("Music Artist:\t%s\n"), NSFInfo->Artist.c_str());
  if(NSFInfo->Copyright.size())
   MDFN_printf(_("Copyright:\t\t%s\n"), NSFInfo->Copyright.c_str());
  if(NSFInfo->Ripper.size())
   MDFN_printf(_("Ripper:\t\t%s\n"), NSFInfo->Ripper.c_str());

  if(NSFInfo->SoundChip)
  {
   static const char *tab[6]={"Konami VRCVI","Konami VRCVII","Nintendo FDS","Nintendo MMC5","Namco 106","Sunsoft FME-07"};

   for(x=0;x<6;x++)
    if(NSFInfo->SoundChip&(1<<x))
    {
     MDFN_printf(_("Expansion hardware:  %s\n"), tab[x]);
     //NSFInfo->SoundChip=1<<x;	/* Prevent confusing weirdness if more than one bit is set. */
     //break;
    }
  }

  if(BSon)
   MDFN_printf(_("Bank-switched\n"));
  MDFN_printf(_("Load address:  $%04x\nInit address:  $%04x\nPlay address:  $%04x\n"),NSFInfo->LoadAddr,NSFInfo->InitAddr,NSFInfo->PlayAddr);
  MDFN_printf("%s\n",(NSFInfo->VideoSystem&1)?"PAL":"NTSC");
  MDFN_printf(_("Starting song:  %d / %d\n\n"),NSFInfo->StartingSong + 1,NSFInfo->TotalSongs);

  if(NSFInfo->SoundChip&4)
   ExWRAM=(uint8 *)MDFN_malloc_T(32768+8192, _("NSF expansion RAM"));
  else
   ExWRAM=(uint8 *)MDFN_malloc_T(8192, _("NSF expansion RAM"));

  MDFN_indent(-1);

  gt->Power = NSF_Power;
  gt->Reset = NSF_Reset;
  gt->SaveNV = NULL;
  gt->Kill = NSF_Kill;
  gt->StateAction = NSF_StateAction;

  Player_Init(NSFInfo->TotalSongs, NSFInfo->GameName, NSFInfo->Artist, NSFInfo->Copyright, NSFInfo->SongNames);
 }
 catch(...)
 {
  FreeNSF();
  throw;
 }
}

static DECLFR(NSFVectorRead)
{
 if(((NSFNMIFlags&1) && SongReload) || (NSFNMIFlags&2) || doreset)
 {
  if(A==0xFFFA) return(0x00);
  else if(A==0xFFFB) return(0x38);
  else if(A==0xFFFC) return(0x20);
  else if(A==0xFFFD) { doreset = false; return(0x38); }
  return(X.DB);
 }
 else
  return(CartBR(A));
}

void NSFECSetWriteHandler(int32 start, int32 end, writefunc func)
{
  int32 x;

  if(!func) return;

  for(x=end;x>=start;x--)
   WriteHandlers[x].push_back(func);
}

static DECLFW(NSFECWriteHandler)
{
 for(unsigned int x = 0; x < WriteHandlers[A].size(); x++)
  WriteHandlers[A][x](A, V);

}

static void NSF_init(void)
{
  doreset = true;

  WriteHandlers = new NSFWriteEntry[0x10000];

  ResetCartMapping();

  SetWriteHandler(0x2000, 0x3FFF, NSFECWriteHandler);
  SetWriteHandler(0x4020, 0xFFFF, NSFECWriteHandler);

  if(NSFInfo->SoundChip&4)
  {
   SetupCartPRGMapping(0,ExWRAM,32768+8192,1);
   setprg32(0x6000,0);
   setprg8(0xE000,4);
   memset(ExWRAM,0x00,32768+8192);
   NSFECSetWriteHandler(0x6000,0xDFFF,CartBW);
   SetReadHandler(0x6000,0xFFFF,CartBR);
  }
  else
  {
   memset(ExWRAM,0x00,8192);
   SetReadHandler(0x6000,0x7FFF,CartBR);
   NSFECSetWriteHandler(0x6000,0x7FFF,CartBW);
   SetupCartPRGMapping(0,NSFInfo->NSFDATA,((NSFInfo->NSFMaxBank+1)*4096),0);
   SetupCartPRGMapping(1,ExWRAM,8192,1);
   setprg8r(1,0x6000,0);
   SetReadHandler(0x8000,0xFFFF,CartBR);
  }

  if(BSon)
  {
   int32 x;
   for(x=0;x<8;x++)
   {
    if(NSFInfo->SoundChip&4 && x>=6)
     BANKSET(0x6000+(x-6)*4096,NSFInfo->BankSwitch[x]);
    BANKSET(0x8000+x*4096,NSFInfo->BankSwitch[x]);
   }
  }
  else
  {
   int32 x;
   for(x=(NSFInfo->LoadAddr&0xF000);x<0x10000;x+=0x1000)
    BANKSET(x,((x-(NSFInfo->LoadAddr&0xf000))>>12));
  }

  SetReadHandler(0xFFFA,0xFFFD,NSFVectorRead);

  NSFECSetWriteHandler(0x2000,0x3fff,0);
  SetReadHandler(0x2000,0x37ff,0);
  SetReadHandler(0x3836,0x3FFF,0);
  SetReadHandler(0x3800,0x3835,NSFROMRead);

  NSFECSetWriteHandler(0x5ff6,0x5fff,NSF_write);

  NSFECSetWriteHandler(0x3ff0,0x3fff,NSF_write);
  SetReadHandler(0x3ff0,0x3fff,NSF_read);

  int (*InitPointers[8])(EXPSOUND *, bool MultiChip) = { NSFVRC6_Init, NSFVRC7_Init, NSFFDS_Init, NSFMMC5_Init, NSFN106_Init, NSFAY_Init, NULL, NULL };

  for(int x = 0; x < 8; x++)
   if((NSFInfo->SoundChip & (1U << x)) && InitPointers[x])
   {
    EXPSOUND TmpExpSound;
    memset(&TmpExpSound, 0, sizeof(TmpExpSound));

    InitPointers[x](&TmpExpSound, NSFInfo->SoundChip != (1U << x));
    GameExpSound.push_back(TmpExpSound);
   }

  NSFInfo->CurrentSong=NSFInfo->StartingSong;
  SongReload=0xFF;
  NSFNMIFlags=0;
}

static DECLFW(NSF_write)
{
 switch(A)
 {
  case 0x3FF3:NSFNMIFlags|=1;break;
  case 0x3FF4:NSFNMIFlags&=~2;break;
  case 0x3FF5:NSFNMIFlags|=2;break;

  case 0x5FF6:
  case 0x5FF7:if(!(NSFInfo->SoundChip&4)) return;
  case 0x5FF8:
  case 0x5FF9:
  case 0x5FFA:
  case 0x5FFB:
  case 0x5FFC:
  case 0x5FFD:
  case 0x5FFE:
  case 0x5FFF:if(!BSon) return;
              A&=0xF;
              BANKSET((A*4096),V);
  	      break;
 } 
}

static DECLFR(NSF_read)
{
 int x;

 switch(A)
 {
 case 0x3ff0:x=SongReload;
	     if(!fceuindbg)
	      SongReload=0;
	     return x;
 case 0x3ff1:
	    if(!fceuindbg)
	    {
	     for(int i = 0; i < 0x800; i++)
	      BWrite[i](i, 0x00);

             BWrite[0x4015](0x4015,0x0);
             for(x=0;x<0x14;x++)
              BWrite[0x4000+x](0x4000+x,0);
             BWrite[0x4015](0x4015,0xF);

	     if(NSFInfo->SoundChip & 4) 
	     {
	      FDSSound_Power();
	      BWrite[0x4017](0x4017,0xC0);	/* FDS BIOS writes $C0 */
	      BWrite[0x4089](0x4089,0x80);
	      BWrite[0x408A](0x408A,0xE8);
	     }
	     else 
	     {
	      memset(ExWRAM,0x00,8192);
	      BWrite[0x4017](0x4017,0xC0);
              BWrite[0x4017](0x4017,0xC0);
              BWrite[0x4017](0x4017,0x40);
	     }

             if(BSon)
             {
              for(x=0;x<8;x++)
	       BANKSET(0x8000+x*4096,NSFInfo->BankSwitch[x]);
             }
             return (NSFInfo->CurrentSong);
 	     }
 case 0x3FF3:return PAL;
 }
 return 0;
}

uint8 MDFN_GetJoyJoy(void);

void DoNSFFrame(void)
{
 if(((NSFNMIFlags&1) && SongReload) || (NSFNMIFlags&2))
  TriggerNMI();

 {
  static uint8 last=0;
  uint8 tmp;
  tmp=MDFN_GetJoyJoy();
  if((tmp&JOY_RIGHT) && !(last&JOY_RIGHT))
  {
   if(NSFInfo->CurrentSong < (NSFInfo->TotalSongs - 1))
   {
    NSFInfo->CurrentSong++;
    SongReload = 0xFF;
   }
  }
  else if((tmp&JOY_LEFT) && !(last&JOY_LEFT))
  {
   if(NSFInfo->CurrentSong > 0)
   {
    NSFInfo->CurrentSong--;
    SongReload = 0xFF;
   }
  }
  else if((tmp&JOY_UP) && !(last&JOY_UP))
  {
   unsigned ns = NSFInfo->CurrentSong + std::min<unsigned>(NSFInfo->TotalSongs - 1 - NSFInfo->CurrentSong, 10);

   if(NSFInfo->CurrentSong != ns)
   {
    NSFInfo->CurrentSong = ns;
    SongReload = 0xFF;
   }
  }
  else if((tmp&JOY_DOWN) && !(last&JOY_DOWN))
  {
   unsigned ns = NSFInfo->CurrentSong - std::min<unsigned>(NSFInfo->CurrentSong, 10);

   if(NSFInfo->CurrentSong != ns)
   {
    NSFInfo->CurrentSong = ns;
    SongReload = 0xFF;
   }
  }
  else if((tmp&JOY_START) && !(last&JOY_START))
   SongReload = 0xFF;
  else if((tmp&JOY_A) && !(last&JOY_A))
  {

  }
  last=tmp;
 }
}

void MDFNNES_DrawNSF(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int16 *samples, int32 scount)
{
 Player_Draw(surface, DisplayRect, NSFInfo->CurrentSong, samples, scount);
}

}
