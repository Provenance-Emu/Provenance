/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"
#include "mmc3.h"
#include "../ines.h"

static bool is_BMCFK23CA;
static uint8 unromchr;
static uint32 dipswitch;
static uint8 *CHRRAM=NULL;
static uint32 CHRRAMSize;

static void BMCFK23CCW(uint32 A, uint8 V)
{
  if(EXPREGS[0]&0x40)
    setchr8(EXPREGS[2]|unromchr);
  else if(EXPREGS[0]&0x20) {
    setchr1r(0x10, A, V);
  }
  else
  {
    uint16 base=(EXPREGS[2]&0x7F)<<3;
    if(EXPREGS[3]&2)
    {
      int cbase=(MMC3_cmd&0x80)<<5;
      setchr1(A,V|base);
      setchr1(0x0000^cbase,DRegBuf[0]|base);
      setchr1(0x0400^cbase,EXPREGS[6]|base);
      setchr1(0x0800^cbase,DRegBuf[1]|base);
      setchr1(0x0c00^cbase,EXPREGS[7]|base);
    }
    else
      setchr1(A,V|base);
  }
}

//some games are wired differently, and this will need to be changed.
//all the WXN games require prg_bonus = 1, and cah4e3's multicarts require prg_bonus = 0
//we'll populate this from a game database
static int prg_bonus;
static int prg_mask;

//prg_bonus = 0
//4-in-1 (FK23C8021)[p1][!].nes
//4-in-1 (FK23C8033)[p1][!].nes
//4-in-1 (FK23C8043)[p1][!].nes
//4-in-1 (FK23Cxxxx, S-0210A PCB)[p1][!].nes

//prg_bonus = 1
//[m176]大富翁2-上海大亨.wxn.nes
//[m176]宠物翡翠.fix.nes
//[m176]格兰帝亚.wxn.nes
//[m176]梦幻之星.wxn.nes
//[m176]水浒神兽.fix.nes
//[m176]西楚霸王.fix.nes
//[m176]超级大富翁.wxn.nes
//[m176]雄霸天下.wxn.nes

//works as-is under virtuanes m176
//[m176]三侠五义.wxn.nes
//[m176]口袋金.fix.nes
//[m176]爆笑三国.fix.nes

//needs other tweaks
//[m176]三国忠烈传.wxn.nes
//[m176]破釜沉舟.fix.nes

//PRG wrapper
static void BMCFK23CPW(uint32 A, uint8 V)
{
  uint32 bank = (EXPREGS[1] & 0x1F);
  uint32 hiblock = ((EXPREGS[0] & 8) << 4)|((EXPREGS[0] & 0x80) << 1)|(UNIFchrrama?((EXPREGS[2] & 0x40)<<3):0);
  uint32 block = (EXPREGS[1] & 0x60) | hiblock;
  uint32 extra = (EXPREGS[3] & 2);

  if((EXPREGS[0]&7)==4)
    setprg32(0x8000,EXPREGS[1]>>1);
  else if ((EXPREGS[0]&7)==3)
  {
    setprg16(0x8000,EXPREGS[1]);
    setprg16(0xC000,EXPREGS[1]);
  }  
  else
  { 
    if(EXPREGS[0]&3)
		{
			uint32 blocksize = (6)-(EXPREGS[0]&3);
			uint32 mask = (1<<blocksize)-1;
			V &= mask;
			//V &= 63; //? is this a good idea?
			V |= (EXPREGS[1]<<1);
      setprg8(A,V);
		}
    else
      setprg8(A,V & prg_mask);

    if(EXPREGS[3]&2)
    {
      setprg8(0xC000,EXPREGS[4]);
      setprg8(0xE000,EXPREGS[5]);
    }
  }
	setprg8r(0x10,0x6000,A001B&3);
}

//PRG handler ($8000-$FFFF)
static DECLFW(BMCFK23CHiWrite)
{
	if(EXPREGS[0]&0x40)
	{
		if(EXPREGS[0]&0x30)
			unromchr=0;
		else
		{
			unromchr=V&3;
			FixMMC3CHR(MMC3_cmd);
		}
	}
	else
	{
		if((A==0x8001)&&(EXPREGS[3]&2&&MMC3_cmd&8))
		{
			EXPREGS[4|(MMC3_cmd&3)]=V;
			FixMMC3PRG(MMC3_cmd);
			FixMMC3CHR(MMC3_cmd);
		}
    else
      if(A<0xC000) {
        if(UNIFchrrama) { // hacky... strange behaviour, must be bit scramble due to pcb layot restrictions
                          // check if it not interfer with other dumps
          if((A==0x8000)&&(V==0x46))
            V=0x47;
          else if((A==0x8000)&&(V==0x47))
            V=0x46;
        }
        MMC3_CMDWrite(A,V);
        FixMMC3PRG(MMC3_cmd);
      }
      else
        MMC3_IRQWrite(A,V);
  }
}

//EXP handler ($5000-$5FFF)
static DECLFW(BMCFK23CWrite)
{
  if(A&(1<<(dipswitch+4)))
  {
		//printf("+ ");
    EXPREGS[A&3]=V;

		bool remap = false;

		//sometimes writing to reg0 causes remappings to occur. we think the 2 signifies this. 
		//if not, 0x24 is a value that is known to work
		//however, the low 4 bits are known to control the mapping mode, so 0x20 is more likely to be the immediate remap flag
		remap |= ((EXPREGS[0]&0xF0)==0x20); 

		//this is an actual mapping reg. i think reg0 controls what happens when reg1 is written. anyway, we have to immediately remap these
		remap |= (A&3)==1; 
		//this too.
		remap |= (A&3)==2; 

		if(remap)
		{
			FixMMC3PRG(MMC3_cmd);
			FixMMC3CHR(MMC3_cmd);
		}
  }

	if(is_BMCFK23CA)
	{
		if(EXPREGS[3]&2)
			EXPREGS[0] &= ~7;   // hacky hacky! if someone wants extra banking, then for sure doesn't want mode 4 for it! (allow to run A version boards on normal mapper)
	}

	//printf("%04X = $%02X\n",A,V);
	//printf("%02X %02X %02X %02X\n",EXPREGS[0],EXPREGS[1],EXPREGS[2],EXPREGS[3]);
}

static void BMCFK23CReset(void)
{
	//NOT NECESSARY ANYMORE
	//this little hack makes sure that we try all the dip switch settings eventually, if we reset enough
	// dipswitch++;
	// dipswitch&=7;
	//printf("BMCFK23C dipswitch set to %d\n",dipswitch);

  EXPREGS[0]=EXPREGS[1]=EXPREGS[2]=EXPREGS[3]=0;
  EXPREGS[4]=EXPREGS[5]=EXPREGS[6]=EXPREGS[7]=0xFF;
  MMC3RegReset();
  FixMMC3PRG(MMC3_cmd);
  FixMMC3CHR(MMC3_cmd);
}

static void BMCFK23CPower(void)
{
	dipswitch = 0;
  GenMMC3Power();
  EXPREGS[0]=EXPREGS[1]=EXPREGS[2]=EXPREGS[3]=0;
  EXPREGS[4]=EXPREGS[5]=EXPREGS[6]=EXPREGS[7]=0xFF;
  GenMMC3Power();
  SetWriteHandler(0x5000,0x5fff,BMCFK23CWrite);
  SetWriteHandler(0x8000,0xFFFF,BMCFK23CHiWrite);
  FixMMC3PRG(MMC3_cmd);
  FixMMC3CHR(MMC3_cmd);
}

static void BMCFK23CAPower(void)
{
  GenMMC3Power();
  dipswitch = 0;
  EXPREGS[0]=EXPREGS[1]=EXPREGS[2]=EXPREGS[3]=0;
  EXPREGS[4]=EXPREGS[5]=EXPREGS[6]=EXPREGS[7]=0xFF;
  SetWriteHandler(0x5000,0x5fff,BMCFK23CWrite);
  SetWriteHandler(0x8000,0xFFFF,BMCFK23CHiWrite);
  FixMMC3PRG(MMC3_cmd);
  FixMMC3CHR(MMC3_cmd);
}

static void BMCFK23CAClose(void)
{
  if(CHRRAM)
    FCEU_gfree(CHRRAM);
  CHRRAM=NULL;
}

void BMCFK23C_Init(CartInfo *info)
{
	is_BMCFK23CA = false;

  GenMMC3_Init(info, 512, 256, 8, 0);
  cwrap=BMCFK23CCW;
  pwrap=BMCFK23CPW;
  info->Power=BMCFK23CPower;
  info->Reset=BMCFK23CReset;
  AddExState(EXPREGS, 8, 0, "EXPR");
  AddExState(&unromchr, 1, 0, "UCHR");
  AddExState(&dipswitch, 1, 0, "DPSW");

	prg_bonus = 1;
	if(MasterRomInfoParams.find("bonus") != MasterRomInfoParams.end())
		prg_bonus = atoi(MasterRomInfoParams["bonus"].c_str());

	prg_mask = 0x7F>>(prg_bonus);
}

void BMCFK23CA_Init(CartInfo *info)
{
	is_BMCFK23CA = true;

  GenMMC3_Init(info, 512, 256, 8, 0);
  cwrap=BMCFK23CCW;
  pwrap=BMCFK23CPW;
  info->Power=BMCFK23CAPower;
  info->Reset=BMCFK23CReset;
  info->Close=BMCFK23CAClose;

	CHRRAMSize=8192;
  CHRRAM=(uint8*)FCEU_gmalloc(CHRRAMSize);
  SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
  AddExState(CHRRAM, CHRRAMSize, 0, "CRAM");

  AddExState(EXPREGS, 8, 0, "EXPR");
  AddExState(&unromchr, 1, 0, "UCHR");
  AddExState(&dipswitch, 1, 0, "DPSW");

	prg_bonus = 1;
	if(MasterRomInfoParams.find("bonus") != MasterRomInfoParams.end())
		prg_bonus = atoi(MasterRomInfoParams["bonus"].c_str());
	prg_mask = 0x7F>>(prg_bonus);
}
