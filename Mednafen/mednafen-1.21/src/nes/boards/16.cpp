/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
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

#include "mapinc.h"

namespace MDFN_IEN_NES
{

static unsigned EEPROM_Type;	// Bitfield, set by *_Init().

static uint8 IRQa, CHRBanks[8], PRGBank16, Mirroring;
static uint16 IRQCount, IRQLatch;
static uint8 EEPROM_Control;
template<unsigned model, unsigned mem_size>
struct X24C0xP
{
 X24C0xP()
 {
  memset(mem, 0xFF, sizeof(mem));
  Reset();
 }

 ~X24C0xP()
 {

 }

 int StateAction(StateMem *sm, int load, int data_only, const char *sname)
 {
  SFORMAT StateRegs[] = 
  {
   SFPTR8(mem, mem_size),
   SFVAR(prev_sda_in),
   SFVAR(prev_scl_in),
   SFVAR(phase),
   SFVAR(buf),
   SFVAR(bitpos),
   SFVAR(sda_out),

   SFVAR(slave_addr),
   SFVAR(rw_bit),
   SFVAR(mem_addr),

   SFEND
  };
  int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

  if(load)
  {
   mem_addr &= (mem_size - 1);
  }

  return(ret);
 }


 INLINE bool SDA(void)
 {
  return(prev_sda_in & sda_out);
 }

 void Reset(void)
 {
  prev_sda_in = false;
  prev_scl_in = false;
  buf = 0;
  bitpos = 0;
  phase = PHASE_STOPPED;
  sda_out = -1;

  slave_addr = 0;
  rw_bit = 0;
  mem_addr = 0;
 }

 void SetBus(bool scl_in, bool sda_in)
 {
   if((sda_out == -1 || phase == PHASE_STOPPED || phase == PHASE_NO_READ_ACK) && (scl_in & prev_scl_in) == 1 && (prev_sda_in ^ sda_in))
   {
    if(sda_in == 0)
    {
     //if(phase != PHASE_NO_READ_ACK)	// Leaving this in breaks DBZ2 and DBZ3. :/
     {
      //puts("START");

      if(model == 1)
       phase = PHASE_MEM_ADDR;
      else
       phase = PHASE_SLAVE_ADDR;
      bitpos = 0;
      buf = 0;
      sda_out = -1;
     }
    }
    else
    {
     //puts("STOP");
     phase = PHASE_STOPPED;
     sda_out = -1;     
    }
   }
   else if(phase != PHASE_STOPPED && phase != PHASE_NO_READ_ACK)
   {
    if((scl_in ^ prev_scl_in) && scl_in == 1)	// SCL 0->1
    {
     //printf("SCL 0->1, Bit in: bitpos=%d, bit=%d\n", bitpos, sda_in);

     if(bitpos < 8)
     {
      if(phase != PHASE_MEM_READ)
       buf |= sda_in << (7 - bitpos);
     }
     else if(bitpos == 8 && phase == PHASE_MEM_READ && sda_in != 0)
     {
      //printf("PHASE_MEM_READ ACK FAILED --- %d\n", sda_out);
      phase = PHASE_NO_READ_ACK;
      sda_out = -1;
     }

     bitpos++;
    }

    if((scl_in ^ prev_scl_in) && scl_in == 0)	// SCL 1->0
    {
     //printf("SCL 1->0, bitpos=%d\n", bitpos);
     if(bitpos == 8)
     {
      if(phase == PHASE_SLAVE_ADDR)
      {
       slave_addr = buf & 0xFE;
       rw_bit = buf & 0x01;

       //printf("Slave Address: %02x\n", slave_addr);

       if(slave_addr == 0xA0)
        sda_out = 0;	// ACK
       else
       {
        phase = PHASE_STOPPED;
        sda_out = -1;
       }
      }
      else if(phase == PHASE_MEM_ADDR)
      {
       if(model == 2)
        mem_addr = buf;
       else
       {
        mem_addr = buf >> 1;
        rw_bit = buf & 1;
       }

       //printf("Mem Address: %02x\n", buf);

       sda_out = 0;	// ACK
      }
      else if(phase == PHASE_MEM_WRITE)
      {
       //printf("WriteIntoBuf: %02x %02x\n", mem_addr, buf);
       mem[mem_addr] = buf;
       mem_addr = (mem_addr &~ 3) | ((mem_addr + 1) & 0x3);
       sda_out = 0;	// ACK
       //abort();
       //write_buffer[write_buffer_addr & 0x3] = buf;
       //write_buffer_addr = (write_buffer_addr + 1) & 0x3;
      }
      else if(phase == PHASE_MEM_READ)
      {
       mem_addr = (mem_addr + 1) & (mem_size - 1);
       sda_out = -1;	// De-assert sda
      }
      else
      {

      }
     }
     else if(bitpos == 9)
     {
      bitpos = 0;
      buf = 0;
      sda_out = -1;

      if(phase == PHASE_SLAVE_ADDR)
      {
       if(rw_bit)
        phase = PHASE_MEM_READ;
       else
        phase = PHASE_MEM_ADDR;
      }
      else if(phase == PHASE_MEM_ADDR)
      {
       if(model == 2)
        phase = PHASE_MEM_WRITE;
       else
       {
        if(rw_bit)
         phase = PHASE_MEM_READ;
        else
         phase = PHASE_MEM_WRITE;
       }
      }

      if(phase == PHASE_MEM_READ)
      {
       //printf(" ReadIntoBuf addr=0x%02x, val=0x%02x\n", mem_addr, mem[mem_addr]);
       buf = mem[mem_addr];
      }
     }

     if(bitpos < 8)
     {
      if(phase == PHASE_MEM_READ)
       sda_out = (buf >> (7 - bitpos)) & 1;
     }
    }
   }

  prev_sda_in = sda_in;
  prev_scl_in = scl_in;
 }

 bool prev_sda_in, prev_scl_in;
 unsigned phase;

 enum
 {
  PHASE_STOPPED = 0,
  PHASE_SLAVE_ADDR,
  PHASE_MEM_ADDR,
  PHASE_MEM_WRITE,
  PHASE_MEM_READ,

  PHASE_NO_READ_ACK,
 };
 uint8 mem[mem_size];
 uint8 buf;
 uint8 bitpos;
 int sda_out;

 //
 //
 //
 uint8 slave_addr;
 bool rw_bit;
 uint8 mem_addr;

 //uint8 write_buffer_addr;
 //uint8 write_buffer[4];
};

typedef X24C0xP<1, 128> X24C01P;
typedef X24C0xP<2, 256> X24C02P;

static X24C01P eep128;
static X24C02P eep256;

static void UpdateEEPROMSignals(void)
{
 if(EEPROM_Type & 0x02)
  eep256.SetBus(EEPROM_Control & 0x20, ((EEPROM_Control & 0x80) ? 1 : (EEPROM_Control & 0x40)));

 if(EEPROM_Type & 0x01)
  eep128.SetBus(EEPROM_Control & 0x20, ((EEPROM_Control & 0x80) ? 1 : (EEPROM_Control & 0x40)));
}

static MDFN_FASTCALL void BandaiIRQHook(int a)
{
  if(IRQa)
  {
   uint16 last_irq = IRQCount;
   IRQCount-=a;
   if(IRQCount > last_irq)
   {
    X6502_IRQBegin(MDFN_IQEXT);
    IRQa=0;
   }
  }
}

static void DoCHR(void)
{
 if(CHRsize[0] <= 8192)
  setchr8(0);
 else
 {
  for(int x = 0; x < 8; x++)
   setchr1(x << 10, CHRBanks[x]);
 }
}

static void DoPRG(void)
{
 setprg16(0x8000, PRGBank16 & 0xF);
}

static void DoMirroring(void)
{
 static const int mir_tab[4] = { MI_V, MI_H, MI_0, MI_1 };
 setmirror(mir_tab[Mirroring & 3]);
}

static DECLFR(EEPROM_Read)
{
 uint8 ret = 0;

 if(EEPROM_Type == 2)
  ret |= eep256.SDA() << 4;
 else if(EEPROM_Type == 1)
  ret |= eep128.SDA() << 4;

 //printf(" EEP SDA READ: %02x\n", ret);

 return(ret);
}

static DECLFW(Mapper16_write)
{
        A&=0xF;

        if(A<=0x7)
	{
	 CHRBanks[A & 0x7] = V;
	 DoCHR();
	}
        else if(A==0x8)
	{
	 PRGBank16 = V & 0xF;
	 DoPRG();
	}
        else switch(A) 
	{
         case 0x9: Mirroring = V & 3;
		   DoMirroring();
                   break;
         case 0xA: X6502_IRQEnd(MDFN_IQEXT);
                   IRQa=V&1;
                   IRQCount=IRQLatch;
                   break;
         case 0xB: IRQLatch&=0xFF00;
                   IRQLatch|=V;
                   break;
         case 0xC: IRQLatch&=0xFF;
                   IRQLatch|=V<<8;
                   break;

         case 0xD: //printf("EEPROM Write: %02x\n", V);
		   // D5(0x20) = SCL?
		   // D6(0x40) = SDA?
		   // D7(0x80) = 1, de-assert SDA?
		   //printf("SCL=%d, SDA=%d, DES=%d\n", (bool)(V & 0x20), (bool)(V & 0x40), (bool)(V & 0x80));
		   EEPROM_Control = V & 0xE0;
		   UpdateEEPROMSignals();
		   //printf("\n");
		   break;

	 default:  //printf("Unknown Write: %02x %02x\n", A, V);
		   break;
 }
}

static void Reset(CartInfo *info)
{
 EEPROM_Control = 0x00;
 eep128.Reset();
 eep256.Reset();
}

static void Power(CartInfo *info)
{
 Reset(info);

 IRQCount = IRQLatch = IRQa = 0;
 PRGBank16 = 0;
 for(int x = 0; x < 8; x++)
  CHRBanks[x] = x;
 DoPRG();
 DoCHR();
 DoMirroring();

 setprg16(0xc000, 0xF);
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(CHRBanks, 8),
  SFVAR(PRGBank16),

  SFVAR(IRQa), SFVAR(IRQCount), SFVAR(IRQLatch),

  SFVAR(Mirroring),
  SFVAR(EEPROM_Control),

  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");

 if(EEPROM_Type & 0x01)
  ret &= eep128.StateAction(sm, load, data_only, "X24C01P-BANDAI");

 if(EEPROM_Type & 0x02)
  ret &= eep256.StateAction(sm, load, data_only, "X24C02P-BANDAI");

 if(load)
 {
  DoPRG();
  DoCHR();
  DoMirroring();
  UpdateEEPROMSignals();
 }
 return(ret);
}

int Mapper16_Init(CartInfo *info)
{
 info->Reset = Reset;
 info->Power = Power;
 info->StateAction = StateAction;
 MapIRQHook = BandaiIRQHook;

 EEPROM_Type = 0x02;
 info->battery = true;	// A LIE!
 info->SaveGame[0] = eep256.mem;
 info->SaveGameLen[0] = sizeof(eep256.mem);

 SetReadHandler(0x6000, 0x7FFF, EEPROM_Read);
 SetWriteHandler(0x6000, 0xFFFF, Mapper16_write);
 SetReadHandler(0x8000, 0xFFFF, CartBR);

 return(1);
}

int Mapper159_Init(CartInfo *info)
{
 info->Reset = Reset;
 info->Power = Power;
 info->StateAction = StateAction;
 MapIRQHook = BandaiIRQHook;

 EEPROM_Type = 0x01;
 info->battery = true;	// A LIE!
 info->SaveGame[0] = eep128.mem;
 info->SaveGameLen[0] = sizeof(eep128.mem);

 SetReadHandler(0x6000, 0x7FFF, EEPROM_Read);
 SetWriteHandler(0x6000, 0xFFFF, Mapper16_write);
 SetReadHandler(0x8000, 0xFFFF, CartBR);
 return(1);
}

//
//
// Famicom jump 2:
// 0-7: Lower bit of data selects which 256KB PRG block is in use.
// This seems to be a hack on the developers' part, so I'll make emulation
// of it a hack(I think the current PRG block would depend on whatever the
// lowest bit of the CHR bank switching register that corresponds to the
// last CHR address read).
//
//
static uint8 WRAM[8192];

static void DoPRG_153(void)
{
 uint32 base=(CHRBanks[0]&1)<<4;
 setprg16(0x8000,(PRGBank16&0xF)|base);
 setprg16(0xC000,base|0xF);
}

static DECLFW(Mapper153_write)
{
	A&=0xF;
        if(A<=0x7) 
	{
	 CHRBanks[A & 0x7] = V;
	 DoPRG_153();
	}
        else if(A==0x8) 
	{
	 PRGBank16 = V;
	 DoPRG_153();
	}
	else switch(A) {
	 case 0x9: Mirroring = V;
		   DoMirroring();
                   break;
         case 0xA:X6502_IRQEnd(MDFN_IQEXT);
  		  IRQa=V&1;
		  IRQCount=IRQLatch;
		  break;
         case 0xB:IRQLatch&=0xFF00;
		  IRQLatch|=V;
 		  break;
         case 0xC:IRQLatch&=0xFF;
 		  IRQLatch|=V<<8;
		  break;
        }
}

static int StateAction_153(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(CHRBanks, 8),
  SFVAR(PRGBank16),
  SFVAR(IRQa), SFVAR(IRQCount), SFVAR(IRQLatch),
  SFVAR(Mirroring),
  SFPTR8(WRAM, 8192),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");
 if(load)
 {
  DoPRG_153();
  //DoCHR();
  DoMirroring();
 }
 return(ret);
}

static void Power_153(CartInfo *info)
{
 IRQCount = IRQLatch = IRQa = 0;
 PRGBank16 = 0;
 for(int x = 0; x < 8; x++)
  CHRBanks[x] = x;
 DoPRG_153();
 DoCHR();
 DoMirroring();

 setprg16r(0x10, 0x6000, 0);

 if(!info->battery)
  memset(WRAM, 0xFF, 8192);
}

int Mapper153_Init(CartInfo *info)
{
 MapIRQHook=BandaiIRQHook;
 SetWriteHandler(0x8000,0xFFFF,Mapper153_write);
 SetWriteHandler(0x6000, 0x7FFF, CartBW);
 SetReadHandler(0x6000, 0xFFFF, CartBR);

 info->Power = Power_153;
 info->StateAction = StateAction_153;
 SetupCartPRGMapping(0x10, WRAM, 8192, 1);
 if(info->battery)
 {
  info->SaveGame[0] = WRAM;
  info->SaveGameLen[0] = 8192;
 }
 /* This mapper/board seems to have WRAM at $6000-$7FFF. */

 return(1);
}

//
//
//
//
//
//
//

static uint8 BarcodeData[256];
static uint8 BarcodeReadPos;
static uint32 BarcodeCycleCount;
static uint8 BarcodeOut;

}

int MDFNI_DatachSet(const uint8 *rcode)
{
        static const uint8 prefix_parity_type[10][6] = {
                {0,0,0,0,0,0}, {0,0,1,0,1,1}, {0,0,1,1,0,1}, {0,0,1,1,1,0},
                {0,1,0,0,1,1}, {0,1,1,0,0,1}, {0,1,1,1,0,0}, {0,1,0,1,0,1},
                {0,1,0,1,1,0}, {0,1,1,0,1,0}
        };
        static const uint8 data_left_odd[10][7] = {
                {0,0,0,1,1,0,1}, {0,0,1,1,0,0,1}, {0,0,1,0,0,1,1}, {0,1,1,1,1,0,1},
                {0,1,0,0,0,1,1}, {0,1,1,0,0,0,1}, {0,1,0,1,1,1,1}, {0,1,1,1,0,1,1},
                {0,1,1,0,1,1,1}, {0,0,0,1,0,1,1}
        };
        static const uint8 data_left_even[10][7] = {
                {0,1,0,0,1,1,1}, {0,1,1,0,0,1,1}, {0,0,1,1,0,1,1}, {0,1,0,0,0,0,1},
                {0,0,1,1,1,0,1}, {0,1,1,1,0,0,1}, {0,0,0,0,1,0,1}, {0,0,1,0,0,0,1},
                {0,0,0,1,0,0,1}, {0,0,1,0,1,1,1}
        };
        static const uint8 data_right[10][7] = {
                {1,1,1,0,0,1,0}, {1,1,0,0,1,1,0}, {1,1,0,1,1,0,0}, {1,0,0,0,0,1,0},
                {1,0,1,1,1,0,0}, {1,0,0,1,1,1,0}, {1,0,1,0,0,0,0}, {1,0,0,0,1,0,0},
                {1,0,0,1,0,0,0}, {1,1,1,0,1,0,0}
        };
	uint8 code[13+1];
	uint32 tmp_p=0;
	int i, j;
	int len;

	for(i=len=0;i<13;i++)
	{
	 if(!rcode[i]) break;

	 if((code[i]=rcode[i]-'0') > 9)
	  return(0);
	 len++;
	}
	if(len!=13 && len!=12 && len!=8 && len!=7) return(0);

	#define BS(x) BarcodeData[tmp_p]=x;tmp_p++

        for(j=0;j<32;j++) 
	{
	 BS(0x00);
	}

	/* Left guard bars */
	BS(1);	BS(0); BS(1);

	if(len==13 || len==12)
	{
	 uint32 csum;

 	 for(i=0;i<6;i++)
	  if(prefix_parity_type[code[0]][i])
	  {
	   for(j=0;j<7;j++)
	   { 
	    BS(data_left_even[code[i+1]][j]);
	   }
	  }
	  else
	   for(j=0;j<7;j++)
	   {
	    BS(data_left_odd[code[i+1]][j]);
	   }
	  
	 /* Center guard bars */
	 BS(0); BS(1); BS(0); BS(1); BS(0);

	 for(i=7;i<12;i++)
	  for(j=0;j<7;j++)
	  {
	   BS(data_right[code[i]][j]);
	  }
	 csum=0;
	 for(i=0;i<12;i++) csum+=code[i]*((i&1)?3:1);
	 csum=(10-(csum%10))%10;
	 //printf("%d\n",csum);
	 for(j=0;j<7;j++)
         {
          BS(data_right[csum][j]);
         }

	}
	else if(len==8 || len==7)
	{
	 uint32 csum=0;
	
	 for(i=0;i<7;i++) csum+=(i&1)?code[i]:(code[i]*3);

	 csum=(10-(csum%10))%10;

         for(i=0;i<4;i++)
          for(j=0;j<7;j++)
          {
           BS(data_left_odd[code[i]][j]);
          }


         /* Center guard bars */
         BS(0); BS(1); BS(0); BS(1); BS(0); 
           
         for(i=4;i<7;i++) 
          for(j=0;j<7;j++)
          {
           BS(data_right[code[i]][j]);
          }

	 for(j=0;j<7;j++)
 	 { BS(data_right[csum][j]);}

	}

	/* Right guard bars */
	BS(1); BS(0); BS(1);

	for(j=0;j<32;j++) 
	{
	 BS(0x00);
	}

	BS(0xFF);
	#undef BS
	BarcodeReadPos=0;
	BarcodeOut=0x8;
	BarcodeCycleCount=0;
	return(1);
}

namespace MDFN_IEN_NES
{

static MDFN_FASTCALL void BarcodeIRQHook(int a)
{
 BandaiIRQHook(a);

 BarcodeCycleCount+=a;

 if(BarcodeCycleCount >= 1000)
 {
  BarcodeCycleCount -= 1000;
  if(BarcodeData[BarcodeReadPos]==0xFF)
  {
   BarcodeOut=0;
  }
  else
  {
   BarcodeOut=(BarcodeData[BarcodeReadPos]^1)<<3;
   BarcodeReadPos++;
  }
 }
}

static DECLFR(Mapper157_read)
{
 uint8 ret = 0;

 ret |= BarcodeOut;
 ret |= eep256.SDA() << 4;

 return(ret);
}

static void Mapper157_Power(CartInfo *info)
{
 BarcodeData[0]=0xFF;
 BarcodeReadPos=0;
 BarcodeOut=0;
 BarcodeCycleCount=0;

 Power(info);
}

static int StateAction_157(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(BarcodeData, 256),
  SFVAR(BarcodeReadPos), SFVAR(BarcodeCycleCount), SFVAR(BarcodeOut),
  SFPTR8(CHRBanks, 8),
  SFVAR(PRGBank16),
  SFVAR(IRQa), SFVAR(IRQCount), SFVAR(IRQLatch),
  SFVAR(Mirroring),
  SFVAR(EEPROM_Control),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");

 ret &= eep256.StateAction(sm, load, data_only, "X24C02P-BANDAI");

 if(load)
 {
  DoPRG();
  DoCHR();
  DoMirroring();
  UpdateEEPROMSignals();
 }
 return(ret);
}

int Mapper157_Init(CartInfo *info)
{
 info->Power = Mapper157_Power;
 info->StateAction = StateAction_157;
 MDFNGameInfo->cspecial = "datach";
 MapIRQHook=BarcodeIRQHook;

 EEPROM_Type = 0x02;
 info->battery = true;	// A LIE!
 info->SaveGame[0] = eep256.mem;
 info->SaveGameLen[0] = sizeof(eep256.mem);

 SetWriteHandler(0x6000, 0xFFFF, Mapper16_write);
 SetReadHandler(0x6000, 0x7FFF, Mapper157_read);
 SetReadHandler(0x8000, 0xFFFF, CartBR);
 return(1);
}

}
