/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
#include <errno.h>
#include "ppu/ppu.h"
#include "cart.h"
#include "x6502.h"

#include <array>

#include <mednafen/mempatcher.h>
#include <mednafen/FileStream.h>

/* 
   This file contains all code for coordinating the mapping in of the
   address space external to the NES.
   It's also (ab)used by the NSF code.
*/
namespace MDFN_IEN_NES
{
uint8 *Page[32],*VPage[8];
uint8 **VPageR=VPage;
uint8 *VPageG[8];
uint8 *MMC5SPRVPage[8];
uint8 *MMC5BGVPage[8];

static uint8 PRGIsRAM[32];	/* This page is/is not PRG RAM. */

/* 16 are (sort of) reserved for UNIF/iNES and 16 to map other stuff. */
static int CHRram[32];
static int PRGram[32];

uint8 *PRGptr[32];
uint8 *CHRptr[32];

uint32 PRGsize[32];
uint32 CHRsize[32];

uint32 PRGmask2[32];
uint32 PRGmask4[32];
uint32 PRGmask8[32];
uint32 PRGmask16[32];
uint32 PRGmask32[32];

uint32 CHRmask1[32];
uint32 CHRmask2[32];
uint32 CHRmask4[32];
uint32 CHRmask8[32];

//
//
//
//

/*
enum
{
 GENIESTAGE_UNUSED = 0,
 GENIESTAGE_ENTRY = 1,
 GENIESTAGE_GAME = 2
};
*/

uint8 geniestage = 0;
static uint8 modcon;
static std::array<uint8, 3> genieval;
static std::array<uint8, 3> geniech;
static std::array<uint16, 3> genieaddr;

static DECLFR(GenieFix1);
static DECLFR(GenieFix2);
static DECLFR(GenieFix3);
static readfunc const GenieFix[3] = { GenieFix1, GenieFix2, GenieFix3 };

//
//
//
//

static INLINE void setpageptr(int s, uint32 A, uint8 *p, int ram)
{
 uint32 AB=A>>11;
 int x;

 if(p)
  for(x=(s>>1)-1;x>=0;x--)
  {
   PRGIsRAM[AB+x]=ram;
   Page[AB+x]=p-A;
  }
 else
  for(x=(s>>1)-1;x>=0;x--)
  {
   PRGIsRAM[AB+x]=0;
   Page[AB+x]=0;
  }
}

static uint8 nothing[8192];

uint8 *GetCartPagePtr(uint16 A)
{
 int n = A >> 11;

 if(Page[n] == (nothing - (n << 11)))
 {
  return(0);
 }
 else
  return(Page[n]);
}

void ResetCartMapping(void)
{
 int x;

 for(x=0;x<32;x++)
 {
  Page[x]=nothing-x*2048;
  PRGptr[x]=CHRptr[x]=0;
  PRGsize[x]=CHRsize[x]=0;
 }
 for(x=0;x<8;x++)
 {
  MMC5SPRVPage[x]=MMC5BGVPage[x]=VPageR[x]=nothing-0x400*x;
 }

}

void SetupCartPRGMapping(int chip, uint8 *p, uint32 size, int ram)
{
 PRGptr[chip]=p;
 PRGsize[chip]=size;

 PRGmask2[chip]=(size>>11)-1;
 PRGmask4[chip]=(size>>12)-1;
 PRGmask8[chip]=(size>>13)-1;
 PRGmask16[chip]=(size>>14)-1;
 PRGmask32[chip]=(size>>15)-1; 

 PRGram[chip]=ram?1:0;
}

void SetupCartCHRMapping(int chip, uint8 *p, uint32 size, int ram)
{
 CHRptr[chip]=p;
 CHRsize[chip]=size;

 CHRmask1[chip]=(size>>10)-1;
 CHRmask2[chip]=(size>>11)-1;
 CHRmask4[chip]=(size>>12)-1;
 CHRmask8[chip]=(size>>13)-1;

 CHRram[chip]=ram;
}

DECLFR(CartBR)
{
 return Page[A>>11][A];
}

DECLFW(CartBW)
{
 //printf("Ok: %04x:%02x, %d\n",A,V,PRGIsRAM[A>>11]);
 if(PRGIsRAM[A>>11] && Page[A>>11])
  Page[A>>11][A]=V;
}

DECLFR(CartBROB)
{
 if(!Page[A>>11]) return(X.DB);
 return Page[A>>11][A];
}

void setprg2r(int r, unsigned int A, unsigned int V)
{
  V&=PRGmask2[r];

  setpageptr(2,A,PRGptr[r]?(&PRGptr[r][V<<11]):0,PRGram[r]);
}

void setprg2(uint32 A, uint32 V)
{
 setprg2r(0,A,V);
}

void setprg4r(int r, unsigned int A, unsigned int V)
{
  V&=PRGmask4[r];
  setpageptr(4,A,PRGptr[r]?(&PRGptr[r][V<<12]):0,PRGram[r]);
}

void setprg4(uint32 A, uint32 V)
{
 setprg4r(0,A,V);
}

void setprg8r(int r, unsigned int A, unsigned int V)
{
  if(PRGsize[r]>=8192)
  {
   V&=PRGmask8[r];
   setpageptr(8,A,PRGptr[r]?(&PRGptr[r][V<<13]):0,PRGram[r]);
  }
  else
  {
   uint32 VA=V<<2;
   int x;
   for(x=0;x<4;x++)
    setpageptr(2,A+(x<<11),PRGptr[r]?(&PRGptr[r][((VA+x)&PRGmask2[r])<<11]):0,PRGram[r]);
  }
}

void setprg8(uint32 A, uint32 V)
{
 setprg8r(0,A,V);
}

void setprg16r(int r, unsigned int A, unsigned int V)
{
  if(PRGsize[r]>=16384)
  {
   V&=PRGmask16[r];
   setpageptr(16,A,PRGptr[r]?(&PRGptr[r][V<<14]):0,PRGram[r]);
  }
  else
  {
   uint32 VA=V<<3;
   int x;

   for(x=0;x<8;x++)
    setpageptr(2,A+(x<<11),PRGptr[r]?(&PRGptr[r][((VA+x)&PRGmask2[r])<<11]):0,PRGram[r]);
  }
}

void setprg16(uint32 A, uint32 V)
{
 setprg16r(0,A,V);
}

void setprg32r(int r,unsigned int A, unsigned int V)
{
  if(PRGsize[r]>=32768)
  {
   V&=PRGmask32[r];
   setpageptr(32,A,PRGptr[r]?(&PRGptr[r][V<<15]):0,PRGram[r]);
  }
  else
  {
   uint32 VA=V<<4;
   int x;

   for(x=0;x<16;x++)
    setpageptr(2,A+(x<<11),PRGptr[r]?(&PRGptr[r][((VA+x)&PRGmask2[r])<<11]):0,PRGram[r]);
  }
}

void setprg32(uint32 A, uint32 V)
{
 setprg32r(0,A,V);
}

void setchr1r(int r, unsigned int A, unsigned int V)
{
  if(!CHRptr[r]) return;
  MDFNPPU_LineUpdate();
  V&=CHRmask1[r];
  if(CHRram[r])
   PPUCHRRAM|=(1<<(A>>10));
  else
   PPUCHRRAM&=~(1<<(A>>10));
  VPageR[(A)>>10]=&CHRptr[r][(V)<<10]-(A);
}

void setchr2r(int r, unsigned int A, unsigned int V)
{
  if(!CHRptr[r]) return;
  MDFNPPU_LineUpdate();
  V&=CHRmask2[r];
  VPageR[(A)>>10]=VPageR[((A)>>10)+1]=&CHRptr[r][(V)<<11]-(A);
  if(CHRram[r])
   PPUCHRRAM|=(3<<(A>>10));
  else
   PPUCHRRAM&=~(3<<(A>>10));
}

void setchr4r(int r, unsigned int A, unsigned int V)
{
  if(!CHRptr[r]) return;
  MDFNPPU_LineUpdate();
  V&=CHRmask4[r];
  VPageR[(A)>>10]=VPageR[((A)>>10)+1]=
  VPageR[((A)>>10)+2]=VPageR[((A)>>10)+3]=&CHRptr[r][(V)<<12]-(A);

  if(CHRram[r])
   PPUCHRRAM |= (15<<(A>>10));
  else
   PPUCHRRAM&=~(15<<(A>>10));
}

void setchr8r(int r, unsigned int V)
{
  int x;

  if(!CHRptr[r]) return;
  MDFNPPU_LineUpdate();
  V&=CHRmask8[r];
  for(x=7;x>=0;x--)
   VPageR[x]=&CHRptr[r][V<<13];

  if(CHRram[r])
   PPUCHRRAM = 0xFF;
  else
   PPUCHRRAM = 0;
}

void setchr1(unsigned int A, unsigned int V)
{
 setchr1r(0,A,V);
}

void setchr2(unsigned int A, unsigned int V)
{
 setchr2r(0,A,V);
}

void setchr4(unsigned int A, unsigned int V)
{
 setchr4r(0,A,V);
}

void setchr8(unsigned int V)
{
 setchr8r(0,V);
}

void setvram8(uint8 *p)
{
  int x;

  MDFNPPU_LineUpdate();

  for(x=7;x>=0;x--)
   VPageR[x]=p;
  PPUCHRRAM|=255;
}

void setvram4(uint32 A, uint8 *p)
{
  int x;

  MDFNPPU_LineUpdate();

  for(x=3;x>=0;x--)
   VPageR[(A>>10)+x]=p-A;
  PPUCHRRAM|=(15<<(A>>10));
}

void setvramb1(uint8 *p, uint32 A, uint32 b)
{
  MDFNPPU_LineUpdate();
  VPageR[A>>10]=p-A+(b<<10);
  PPUCHRRAM|=(1<<(A>>10));
}

void setvramb2(uint8 *p, uint32 A, uint32 b)
{
  MDFNPPU_LineUpdate();
  VPageR[(A>>10)]=VPageR[(A>>10)+1]=p-A+(b<<11);
  PPUCHRRAM|=(3<<(A>>10));
}

void setvramb4(uint8 *p, uint32 A, uint32 b)
{
  int x;

  MDFNPPU_LineUpdate();
  for(x=3;x>=0;x--)
   VPageR[(A>>10)+x]=p-A+(b<<12);
  PPUCHRRAM|=(15<<(A>>10));
}

void setvramb8(uint8 *p, uint32 b)
{
  int x;

  MDFNPPU_LineUpdate();
  for(x=7;x>=0;x--)
   VPageR[x]=p+(b<<13);
  PPUCHRRAM|=255;
}

/* This function can be called without calling SetupCartMirroring(). */

void setntamem(uint8 *p, int ram, uint32 b)
{
 MDFNPPU_LineUpdate();
 vnapage[b]=p;
 PPUNTARAM&=~(1<<b);
 if(ram)
  PPUNTARAM|=1<<b;
}

static bool mirrorhard = FALSE;

void setmirrorw(int a, int b, int c, int d)
{
 MDFNPPU_LineUpdate();
 vnapage[0]=NTARAM+a*0x400;
 vnapage[1]=NTARAM+b*0x400;
 vnapage[2]=NTARAM+c*0x400;
 vnapage[3]=NTARAM+d*0x400;
}

void setmirror(int t)
{
  MDFNPPU_LineUpdate();
  if(!mirrorhard)
  {
   switch(t)
   {
    case MI_H:
     vnapage[0]=vnapage[1]=NTARAM;vnapage[2]=vnapage[3]=NTARAM+0x400;
     break;
    case MI_V:
     vnapage[0]=vnapage[2]=NTARAM;vnapage[1]=vnapage[3]=NTARAM+0x400;
     break;
    case MI_0:
     vnapage[0]=vnapage[1]=vnapage[2]=vnapage[3]=NTARAM;
     break;
    case MI_1:
     vnapage[0]=vnapage[1]=vnapage[2]=vnapage[3]=NTARAM+0x400;
     break;
   }
  PPUNTARAM=0xF;
 }
}

void SetupCartMirroring(int m, int hard, uint8 *extra)
{
 if(m < 4)
 {
  mirrorhard = FALSE;
  setmirror(m);
 }
 else
 {
  vnapage[0]=NTARAM;
  vnapage[1]=NTARAM+0x400;
  vnapage[2]=extra;
  vnapage[3]=extra+0x400;
  PPUNTARAM=0xF;
 }
 mirrorhard = hard;
}

bool CartHasHardMirroring(void)
{
 return(mirrorhard);
}

static uint8 *GENIEROM = NULL;
static readfunc GenieBackup[3] = { NULL, NULL, NULL };
static void FixGenieMap(void);

static DECLFW(GenieWrite);
static DECLFR(GenieRead);
static bool GenieBIOSHooksInstalled = FALSE;
static readfunc *AReadGG = NULL;
static writefunc *BWriteGG = NULL;

bool Genie_BIOSInstalled(void)
{
 return(GenieBIOSHooksInstalled);
}

static void InstallGenieBIOSHooks(void)
{
 if(GenieBIOSHooksInstalled)
  return;

 for(int i = 0; i < 0x8000; i++)
 {
  //assert(AReadGG[i] == NULL);
  //assert(BWriteGG[i] == NULL);

  AReadGG[i] = GetReadHandler(i + 0x8000);
  BWriteGG[i] = GetWriteHandler(i + 0x8000);
 }

 SetWriteHandler(0x8000, 0xFFFF, GenieWrite);
 SetReadHandler(0x8000, 0xFFFF, GenieRead);

 for(int x = 0; x < 8; x++)
  VPage[x]=GENIEROM+4096-0x400*x;

 VPageR = VPageG;

 GenieBIOSHooksInstalled = true;
}

static void RemoveGenieBIOSHooks(void)
{
 if(!GenieBIOSHooksInstalled)
  return;

 for(int x = 0; x < 8; x++)
  VPage[x] = VPageG[x];

 VPageR = VPage;

 for(int i = 0; i < 0x8000; i++)
 {
  //assert(GetReadHandler(i + 0x8000) == GenieRead);
  //assert(GetWriteHandler(i + 0x8000) == GenieWrite);

  SetReadHandler(i + 0x8000, i + 0x8000, AReadGG[i]);
  SetWriteHandler(i + 0x8000, i + 0x8000, BWriteGG[i]);

  AReadGG[i] = NULL;
  BWriteGG[i] = NULL;
 }

 GenieBIOSHooksInstalled = false;
}

static void InstallGenieReadPatches(void)
{
 for(int x = 0; x <= 2; x++)
 {
  if((modcon >> (4 + x)) & 1)
  {
   //assert(!GenieBackup[x]);

   GenieBackup[x] = GetReadHandler(genieaddr[x]);
   SetReadHandler(genieaddr[x], genieaddr[x], GenieFix[x]);
  }
 }
}

static void RemoveGenieReadPatches(void)
{
 // Remove in reverse order to install in case addrs are the same(corrupted save states could trigger this possibly).
 for(int x = 2; x >= 0; x--)
 {
  if(GenieBackup[x])
  {
   SetReadHandler(genieaddr[x], genieaddr[x], GenieBackup[x]);
   GenieBackup[x] = NULL;
  }
 }
}

/* Called when a game(file) is opened successfully. */
void Genie_Init(void)
{
 try
 {
  if(!GENIEROM)
  {
   GENIEROM = (uint8 *)MDFN_malloc_T(4096+1024, _("Game Genie ROM image"));

   std::string fn = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS("nes.ggrom"));
   MDFNFILE fp(fn.c_str(), NULL, _("Game Genie ROM Image"));

   fp.read(GENIEROM, 16);

   if(!memcmp(GENIEROM, "NES\x1A", 4))	/* iNES ROM image */
   {
    fp.read(GENIEROM, 4096);
    fp.seek(16384 - 4096, SEEK_CUR);
    fp.read(GENIEROM + 4096, 256);
   }
   else
   {
    fp.read(GENIEROM + 16, 4352-16);
   }
   fp.Close();
 
   /* Workaround for the Mednafen CHR page size only being 1KB */
   for(int x = 0; x < 4; x++)
    memcpy(GENIEROM + 4096 + (x<<8), GENIEROM + 4096, 256);
  }

  AReadGG = (readfunc *)MDFN_calloc_T(sizeof(readfunc), 32768, _("Game Genie Read Map Backup"));
  BWriteGG = (writefunc *)MDFN_calloc_T(sizeof(writefunc), 32768, _("Game Genie Write Map Backup"));

  GenieBIOSHooksInstalled = FALSE;

  for(int x = 0; x < 3; x++)
  {
   GenieBackup[x] = NULL;

   genieval[x] = 0xFF;
   geniech[x] = 0xFF;
   genieaddr[x] = 0xFFFF;
  }

  geniestage=1;
 }
 catch(...)
 {
  if(GENIEROM)
  {
   MDFN_free(GENIEROM);
   GENIEROM = NULL;
  }

  if(AReadGG)
  {
   MDFN_free(AReadGG);
   AReadGG = NULL;
  }

  if(BWriteGG)
  {
   MDFN_free(BWriteGG);
   BWriteGG = NULL;
  }

  throw;
 }
}

void Genie_Kill(void)
{
 geniestage = 0;
 //FlushGenieRW();
 VPageR = VPage;

 if(GENIEROM)
 {
  MDFN_free(GENIEROM);
  GENIEROM = NULL;
 }

 if(AReadGG)
 {
  MDFN_free(AReadGG);
  AReadGG = NULL;
 }

 if(BWriteGG)
 {
  MDFN_free(BWriteGG);
  BWriteGG = NULL;
 }

 memset(&GenieBackup, 0, sizeof(GenieBackup));
}

static DECLFR(GenieRead)
{
 return GENIEROM[A&4095];
}

static DECLFW(GenieWrite)
{
 switch(A)
 {
  case 0x800c:
  case 0x8008:
  case 0x8004:
	      genieval[((A-4)&0xF)>>2]=V;
	      break;

  case 0x800b:
  case 0x8007:
  case 0x8003:
	      geniech[((A-3)&0xF)>>2]=V;
	      break;

  case 0x800a:
  case 0x8006:
  case 0x8002:genieaddr[((A-2)&0xF)>>2] &= 0xFF00;
	      genieaddr[((A-2)&0xF)>>2] |= V;
	      break;

  case 0x8009:
  case 0x8005:
  case 0x8001:genieaddr[((A-1)&0xF)>>2] &= 0x00FF;
	      genieaddr[((A-1)&0xF)>>2] |= (V | 0x80) << 8;
	      break;

  case 0x8000:if(!V)
               FixGenieMap();
              else
              {
               modcon = V ^ 0xFF;
               if(V == 0x71) 
		modcon=0;
              }
              break;
 }
}


static DECLFR(GenieFix1)
{
 uint8 r=GenieBackup[0](A);

 if((modcon>>1)&1)		// No check
  return genieval[0];
 else if(r==geniech[0])
  return genieval[0];

 return r;
}

static DECLFR(GenieFix2)
{
 uint8 r=GenieBackup[1](A);

 if((modcon>>2)&1)              // No check
  return genieval[1];
 else if(r==geniech[1])
  return genieval[1];

 return r;
}

static DECLFR(GenieFix3)
{
 uint8 r=GenieBackup[2](A);

 if((modcon>>3)&1)              // No check
  return genieval[2];
 else if(r==geniech[2])
  return genieval[2];

 return r;
}

static void FixGenieMap(void)
{
 geniestage = 2;

 if(!GenieBIOSHooksInstalled)
  return;

 RemoveGenieBIOSHooks();

 InstallGenieReadPatches();

 // Call this last, after GenieBIOSHooksInstalled = FALSE and our read cheat hooks are installed.  Yay spaghetti code.
 MDFNMP_InstallReadPatches();
}

void Genie_Power(void)
{
 if(!geniestage)
  return;

 RemoveGenieReadPatches();

 for(unsigned x = 0; x < 3; x++)
 {
  genieval[x] = 0xFF;
  geniech[x] = 0xFF;
  genieaddr[x] = 0xFFFF;
 }

 geniestage = 1;
 modcon = 0;

 if(!GenieBIOSHooksInstalled)
  InstallGenieBIOSHooks();
}

void Genie_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 auto tmp_modcon = modcon;
 auto tmp_geniestage = geniestage;
 auto tmp_genieval = genieval;
 auto tmp_geniech = geniech;
 auto tmp_genieaddr = genieaddr;

 SFORMAT StateRegs[] =
 {
  SFVAR(tmp_geniestage),
  SFVAR(tmp_modcon),

  SFARRAY(tmp_genieval.data(), tmp_genieval.size()),
  SFARRAY(tmp_geniech.data(), tmp_geniech.size()),
  SFARRAY16(tmp_genieaddr.data(), tmp_genieaddr.size()),

  SFEND
 };

 bool lsv = MDFNSS_StateAction(sm, load, data_only, StateRegs, "GENIE", load < 0x937);

 if(load)
 {
  if(!lsv || !GENIEROM)
  {
   if(lsv && tmp_geniestage == 1)
    throw MDFN_Error(0, _("State saved in Game Genie screen, but GG emulation is currently disabled!"));

   tmp_geniestage = (GENIEROM ? 2 : 0);
   tmp_modcon = 0;

   for(unsigned x = 0; x < 3; x++)
   {
    tmp_genieval[x] = 0xFF;
    tmp_geniech[x] = 0xFF;
    tmp_genieaddr[x] = 0xFFFF;
   }
  }

  for(unsigned x = 0; x < 3; x++)
   tmp_genieaddr[x] |= 0x8000;

  MDFNMP_RemoveReadPatches();
  RemoveGenieReadPatches();
  RemoveGenieBIOSHooks();

  modcon = tmp_modcon;
  geniestage = tmp_geniestage;
  genieval = tmp_genieval;
  geniech = tmp_geniech;
  genieaddr = tmp_genieaddr;

  switch(geniestage)
  {
   default:
	geniestage = 0;
	MDFNMP_InstallReadPatches();
	break;

   case 1:
	InstallGenieBIOSHooks();
	break;

   case 2:
	InstallGenieReadPatches();
	MDFNMP_InstallReadPatches();
	break;
  }
 }
}

void MDFN_SaveGameSave(CartInfo *LocalHWInfo)
{
 if(LocalHWInfo->battery && LocalHWInfo->SaveGame[0])
 {
  try
  {
   FileStream sp(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), FileStream::MODE_WRITE_INPLACE);

   for(unsigned x = 0; x < 4; x++)
    if(LocalHWInfo->SaveGame[x])
     sp.write(LocalHWInfo->SaveGame[x], LocalHWInfo->SaveGameLen[x]);

   sp.close();
  }
  catch(std::exception &e)
  {
   throw MDFN_Error(0, _("Error saving save game file: %s\n"), e.what());
  }
 }
}

void MDFN_LoadGameSave(CartInfo *LocalHWInfo)
{
 if(LocalHWInfo->battery && LocalHWInfo->SaveGame[0])
 {
  try
  {
   FileStream sp(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), FileStream::MODE_READ);

   for(unsigned x = 0; x < 4; x++)
    if(LocalHWInfo->SaveGame[x])
     sp.read(LocalHWInfo->SaveGame[x], LocalHWInfo->SaveGameLen[x]);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw MDFN_Error(0, _("Error loading save game file: %s\n"), e.what());
  }
  catch(std::exception &e)
  {
   throw MDFN_Error(0, _("Error loading save game file: %s\n"), e.what());
  }
 }
}

}
