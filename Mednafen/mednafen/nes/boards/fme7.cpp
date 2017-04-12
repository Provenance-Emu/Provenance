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

#include "mapinc.h"
#include "../nsf.h"
#include <math.h>

static uint8 WRAM[8192];
static void AYSoundHQ(void);
static void DoAYSQHQ(int x);

static uint16 IRQCount;
static uint8 IRQa;
static uint8 CHRRegs[8];
static uint8 PRGRegs[3];
static uint8 Mirroring;

static uint8 reg_select;
static uint8 wram_control;
static int32 amp_lut[0x10];
static uint8 sr[0x10];
static uint8 sr_index;

static int32 vcount[3];
static uint32 dcount[3];
static uint32 CAYBC[3];


static DECLFW(SUN5BWRAM)
{
 if((wram_control&0xC0)==0xC0)
  (WRAM-0x6000)[A]=V;
}

static DECLFR(SUN5AWRAM)
{
 if((wram_control&0xC0)==0x40)
  return X.DB; 
 return CartBR(A);
}

static void SyncCHR(void)
{
 for(unsigned x = 0; x < 8; x++)
  setchr1(x << 10, CHRRegs[x]);
}

static void SyncPRG(void)
{
 if(wram_control&0x40)
 {
  if(wram_control&0x80) // Select WRAM
   setprg8r(0x10,0x6000,0);
 }
 else
  setprg8(0x6000,wram_control);

 setprg8(0x8000, PRGRegs[0]);
 setprg8(0xa000, PRGRegs[1]);
 setprg8(0xc000, PRGRegs[2]);
}

static void SyncMirroring(void)
{
 switch(Mirroring&3)
 {
  case 0:setmirror(MI_V);break;
  case 1:setmirror(MI_H);break;
  case 2:setmirror(MI_0);break;
  case 3:setmirror(MI_1);break;
 }
}

static DECLFW(Mapper69_SWL)
{
  sr_index= V & 0xF;
}

static DECLFW(Mapper69_SWH)
{
	     int x;

             switch(sr_index)
             {
              case 0:
              case 1:
              case 8:DoAYSQHQ(0);break;
              case 2:
              case 3:
              case 9:DoAYSQHQ(1);;break;
              case 4:
              case 5:
              case 10:DoAYSQHQ(2);break;
              case 7:
		     for(x=0;x<2;x++)
  		      DoAYSQHQ(x); 
		     break;
             }
             sr[sr_index]=V; 
}

static DECLFW(Mapper69_write)
{
 switch(A&0xE000)
 {
  case 0x8000:reg_select=V;break;
  case 0xa000:
              reg_select&=0xF;
              if(reg_select < 8)
	      {
	       CHRRegs[reg_select] = V;
	       SyncCHR();
              }
              else
               switch(reg_select&0x0f)
               {
                case 0x8: wram_control = V; SyncPRG(); break;
                case 0x9: PRGRegs[0] = V & 0x3F; SyncPRG(); break;
                case 0xa: PRGRegs[1] = V & 0x3F; SyncPRG(); break;
                case 0xb: PRGRegs[2] = V & 0x3F; SyncPRG(); break;
                case 0xc: Mirroring = V & 0x3; SyncMirroring(); break;

             case 0xd:IRQa=V; X6502_IRQEnd(MDFN_IQEXT); break;
             case 0xe:IRQCount&=0xFF00;IRQCount|=V;break;
             case 0xf:IRQCount&=0x00FF;IRQCount|=V<<8;break;
             }
             break;
 }
}

static void DoAYSQHQ(int x) 
{
 const int32 period = sr[x * 2] | ((sr[(x * 2) + 1] & 0xF) << 8);
 const int32 amp = amp_lut[(sr[0x8 + x] & 0xF)];
 uint32 V;

 if(!(sr[0x7]&(1<<x)))
 {
  for(V=CAYBC[x];V<SOUNDTS;V++)
  {
   if(dcount[x] & 0x10)
    WaveHiEx[V] += amp;

   vcount[x]++;
   if(vcount[x] >= period)
   {
    dcount[x] = (dcount[x] + 1) & 0x1F;
    vcount[x] = 0;
   }
  }
 }
 CAYBC[x]=SOUNDTS;
}

static void AYSoundHQ(void)
{
    DoAYSQHQ(0);
    DoAYSQHQ(1);
    DoAYSQHQ(2);
}

static void AYHiSync(int32 ts)
{
 int x;

 for(x=0;x<3;x++)
  CAYBC[x]=ts;
}

static void SunIRQHook(int a)
{
  if(IRQa & 1)
  {
   uint16 prev = IRQCount;

   IRQCount-=a;

   if(IRQCount > prev && (IRQa & 0x80))
   {
    X6502_IRQBegin(MDFN_IQEXT);
   }
  }
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
        SFVARN(reg_select, "FM7S"),
        SFVARN(wram_control, "FM7W"),
        SFARRAYN(sr, 0x10, "FM7SR"),
        SFVARN(sr_index, "FM7I"),
	SFARRAY(PRGRegs, 3),
	SFARRAY(CHRRegs, 8),
	SFVAR(Mirroring),
	SFARRAY32(vcount, 3),
	SFARRAY32(dcount, 3),

	SFVAR(IRQa),
	SFVAR(IRQCount),
	
	SFARRAY(WRAM, 8192),

	SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");

 if(load)
 {
  SyncCHR();
  SyncPRG();
  SyncMirroring();
 }

 return(ret);
}

void Mapper69_ESI(EXPSOUND *ep)
{
 for(int i = 0; i < 0x10; i++)
 {
  double vl = 1.0 / pow(2, 1.0 / 2 * (15 - i));

  //amp_lut[i] = i * 96;
  amp_lut[i] = 7000 * vl; //7500 * vl; //6500 * vl; //8192 * vl; //(int32)(48 * 128 * vl);

  if(!i)
   amp_lut[i] = 0;

  //printf("%d %f, %d\n", i, vl, amp_lut[i]);
 }

 ep->HiFill=AYSoundHQ;
 ep->HiSync=AYHiSync;
 memset(dcount,0,sizeof(dcount));
 memset(vcount,0,sizeof(vcount));
 memset(CAYBC,0,sizeof(CAYBC));
}

int NSFAY_Init(EXPSOUND *ep, bool MultiChip)
{
 sr_index=0;
 if(MultiChip)
 {
  NSFECSetWriteHandler(0xc000,0xc000,Mapper69_SWL);
  NSFECSetWriteHandler(0xe000,0xe000,Mapper69_SWH);
 }
 else
 {
  NSFECSetWriteHandler(0xc000,0xdfff,Mapper69_SWL);
  NSFECSetWriteHandler(0xe000,0xffff,Mapper69_SWH);
 }
 Mapper69_ESI(ep);
 return(1);
}

static void Reset(CartInfo *info)
{
 sr_index = 0;
 wram_control = 0;
 memset(sr, 0xFF, sizeof(sr));  // Setting all bits will cause sound output to be disabled on reset.

 for(unsigned x = 0; x < 8; x++)
  CHRRegs[x] = x;

 PRGRegs[0] = PRGRegs[1] = PRGRegs[2] = 0x3F;

 Mirroring = info->mirror ? 0 : 1; // Do any mapper 69 boards use hardware-fixed mirroring?

 SyncCHR();
 SyncPRG();
 SyncMirroring();

 setprg8(0xe000, 0x3F);
}

static void Power(CartInfo *info)
{
 if(!info->battery)
  memset(WRAM, 0x00, 8192);

 Reset(info);
}

int BTR_Init(CartInfo *info)
{
 SetupCartPRGMapping(0x10,WRAM,8192,1);

 SetWriteHandler(0x8000,0xbfff,Mapper69_write);
 SetWriteHandler(0xc000,0xdfff,Mapper69_SWL);
 SetWriteHandler(0xe000,0xffff,Mapper69_SWH);
 SetWriteHandler(0x6000,0x7fff,SUN5BWRAM);
 SetReadHandler(0x6000,0x7fff,SUN5AWRAM);
 SetReadHandler(0x8000, 0xFFFF, CartBR);

 info->Power = Power;
 info->Reset = Reset;
 info->StateAction = StateAction;

 if(info->battery)
 {
  info->SaveGame[0] = WRAM;
  info->SaveGameLen[0] = 8192;
 }

 Mapper69_ESI(&info->CartExpSound);

 MapIRQHook = SunIRQHook;

 return(1);
}

