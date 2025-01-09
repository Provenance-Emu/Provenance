/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* dma.inc:
**  Copyright (C) 2015-2019 Mednafen Team
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

// FIXME: Be careful to reset DMACH[ch].Offset to 0 at appropriate times(like what if HDMA cancels DMA..)
static uint8 DMAEnable;
static uint8 HDMAEnable;
static uint8 HDMAEnableMask;

static struct
{
 uint8 Control;	// What is bit5?
 uint8 BBusAddr;

 uint16 ABusAddr;
 uint8 ABusBank;

 uint8 IndirBank;	// HDMA
 union
 {
  uint16 Count;
  uint16 IndirAddr;	// HDMA
 };

 uint16 TableAddr;	// HDMA
 uint8 LineCounter;	// HDMA

 uint8 Unknown;

 //
 //
 //
 uint8 Offset;
 bool DoTransfer;
} DMACH[8];

static const struct
{
 uint8 mask;
 uint8 offsets[4];
}
TModes[8] =
{
 { 0, { 0 } },
 { 1, { 0, 1 } },
 { 1, { 0, 0 } },
 { 3, { 0, 0, 1, 1 } },
 { 3, { 0, 1, 2, 3 } },
 { 3, { 0, 1, 0, 1 } },
 { 1, { 0, 0 } },
 { 3, { 0, 0, 1, 1 } },
};

static void DMA_UnhaltCPU(void)
{
 CPUM.halted &= ~CPU_Misc::HALTED_DMA;
 CPU_TriggerIRQNMIDelayKludge();
}

// TODO: Warning message when DMA overwrites DMA registers.
void CPU_Misc::RunDMA(void)
{
#ifdef SNES_DBG_ENABLE
 assert(!InDMABusAccess);
#endif

 InDMABusAccess = true;

 for(unsigned ch = 0; ch < 8; ch++)
 {
  if(DMAEnable & (1U << ch))
  {
   const auto& tm = TModes[DMACH[ch].Control & 0x7];
   const int aa_delta = (DMACH[ch].Control & 0x08) ? 0 : ((DMACH[ch].Control & 0x10) ? -1 : 1);

   //printf("CH %u, %02x %02x\n", ch, DMACH[ch].Control, DMACH[ch].BBusAddr);

   do
   {
    if(timestamp >= next_event_ts)
    {
     InDMABusAccess = false;
     return;
    }

    const uint32 a_addr = ((DMACH[ch].ABusBank << 16) + DMACH[ch].ABusAddr);
    const uint8 b_addr = DMACH[ch].BBusAddr + tm.offsets[DMACH[ch].Offset];

    if(DMACH[ch].Control & 0x80)	// B-bus -> A-bus
    {
     //printf("ABus: %08x\n", (DMACH[ch].ABusBank << 16) + DMACH[ch].ABusAddr);
     //printf("BBus: %02x\n", DMACH[ch].BBusAddr);
     uint32 save_timestamp = CPUM.timestamp;
     uint8 tmp = ReadB(b_addr);
     CPUM.timestamp = save_timestamp;
     WriteA(a_addr, tmp);
     CPUM.timestamp = save_timestamp + MEMCYC_SLOW;
    }
    else	// A-bus -> B-bus
    {
     uint32 save_timestamp = CPUM.timestamp;
     uint8 tmp = ReadA(a_addr);
     CPUM.timestamp = save_timestamp;
     WriteB(b_addr, tmp);
     CPUM.timestamp = save_timestamp + MEMCYC_SLOW;
    }
    DMACH[ch].ABusAddr += aa_delta;
    DMACH[ch].Offset = (DMACH[ch].Offset + 1) & tm.mask;
   } while(--DMACH[ch].Count);

   DMAEnable &= ~1U << ch;
   DMACH[ch].Offset = 0;
  }
 }

 InDMABusAccess = false;

 if(DMAEnable == 0)
 {
#ifdef SNES_DBG_ENABLE
  SNES_DBG("DMA done: %u, scanline=%u\n", CPUM.timestamp, PPU_GetRegister(PPU_GSREG_SCANLINE, nullptr, 0));
#endif
  DMA_UnhaltCPU();
 }
}

static uint32 DMA_Update(uint32 timestamp)
{
 if(DMAEnable != 0)
 {
  //puts("WOOTS");
  CPUM.halted |= CPU_Misc::HALTED_DMA;
 }

 return SNES_EVENT_MAXTS;
}

void DMA_InitHDMA(void)
{
#ifdef SNES_DBG_ENABLE
 assert(!CPUM.InDMABusAccess);
#endif

 CPUM.InDMABusAccess = true;

 DMAEnable &= ~HDMAEnable;

 if((CPUM.halted & CPU_Misc::HALTED_DMA) && DMAEnable == 0)
  DMA_UnhaltCPU();
 //
 //
 HDMAEnableMask = 0xFF;

 for(unsigned ch = 0; ch < 8; ch++)
 {
  DMACH[ch].DoTransfer = false;

  if(HDMAEnable & (1U << ch))
  {
   DMACH[ch].TableAddr = DMACH[ch].ABusAddr;
   DMACH[ch].LineCounter = CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr);
   DMACH[ch].TableAddr++;

   if(!DMACH[ch].LineCounter)
    HDMAEnableMask &= ~(1U << ch);
   else
   {
    if(DMACH[ch].Control & 0x40)
    {
     DMACH[ch].IndirAddr = CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr);
     DMACH[ch].TableAddr++;

     DMACH[ch].IndirAddr |= CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr) << 8;
     DMACH[ch].TableAddr++;
    }

    DMACH[ch].DoTransfer = true;
   }

   SNES_DBG("[DMA] HDMA %u Init: Control=0x%02x, LineCounter=0x%02x, TableAddr=0x%04x, IndirAddr=0x%04x --- ABank=0x%02x, IndirBank=0x%02x\n", ch, DMACH[ch].Control, DMACH[ch].LineCounter, DMACH[ch].TableAddr, DMACH[ch].IndirAddr, DMACH[ch].ABusBank, DMACH[ch].IndirBank);
  }
 }
 CPUM.InDMABusAccess = false;
}

void DMA_RunHDMA(void)
{
#ifdef SNES_DBG_ENABLE
 assert(!CPUM.InDMABusAccess);
#endif

 CPUM.InDMABusAccess = true;

 for(unsigned ch = 0; ch < 8; ch++)
 {
  if(HDMAEnable & HDMAEnableMask & (1U << ch))
  {
   DMAEnable &= ~(1U << ch);

   if(DMACH[ch].DoTransfer)
   {
    const auto& tm = TModes[DMACH[ch].Control & 0x7];

    for(DMACH[ch].Offset = 0; DMACH[ch].Offset <= tm.mask; DMACH[ch].Offset++)
    {
     const uint32 a_addr = (DMACH[ch].Control & 0x40) ? ((DMACH[ch].IndirBank << 16) + DMACH[ch].IndirAddr) : ((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr);
     const uint8 b_addr = DMACH[ch].BBusAddr + tm.offsets[DMACH[ch].Offset];

     if(DMACH[ch].Control & 0x80)	// B-bus -> A-bus
     {
      //printf("ABus: %08x\n", (DMACH[ch].ABusBank << 16) + DMACH[ch].ABusAddr);
      //printf("BBus: %02x\n", DMACH[ch].BBusAddr);
      uint32 save_timestamp = CPUM.timestamp;
      uint8 tmp = CPUM.ReadB(b_addr);
      CPUM.timestamp = save_timestamp;
      CPUM.WriteA(a_addr, tmp);
      CPUM.timestamp = save_timestamp + MEMCYC_SLOW;
     }
     else	// A-bus -> B-bus
     {
      uint32 save_timestamp = CPUM.timestamp;
      uint8 tmp = CPUM.ReadA(a_addr);
      CPUM.timestamp = save_timestamp;
      //printf("[HDMA] CH %u 0x%08x -> 0x%02x, value=0x%02x --- Control=0x%02x, scanline=%u\n", ch, a_addr, b_addr, tmp, DMACH[ch].Control, scanline);
      CPUM.WriteB(b_addr, tmp);
      CPUM.timestamp = save_timestamp + MEMCYC_SLOW;
     }

     if(DMACH[ch].Control & 0x40)
      DMACH[ch].IndirAddr++;
     else
      DMACH[ch].TableAddr++;
    }
    DMACH[ch].Offset = 0;
   }
  }
 }

 for(unsigned ch = 0; ch < 8; ch++)
 {
  if(HDMAEnable & HDMAEnableMask & (1U << ch))
  {
   DMACH[ch].LineCounter--;
   DMACH[ch].DoTransfer = DMACH[ch].LineCounter & 0x80;

   if(!(DMACH[ch].LineCounter & 0x7F))
   {
    {
     const uint32 save_timestamp = CPUM.timestamp;    
     DMACH[ch].LineCounter = CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr);
     DMACH[ch].TableAddr++;
     CPUM.timestamp = save_timestamp + MEMCYC_SLOW;
    }

    //fprintf(stderr, "HDMA %u NewLineCounter=0x%02x --- scanline=%u\n", ch, DMACH[ch].LineCounter, scanline);

    if(DMACH[ch].Control & 0x40)
    {
     if(!DMACH[ch].LineCounter && !(HDMAEnable & HDMAEnableMask & (0xFEU << ch)))
     {
      //printf("HDMA Special~ %u\n", ch);
      DMACH[ch].IndirAddr = 0;
     }
     else
     {
      DMACH[ch].IndirAddr = CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr);
      DMACH[ch].TableAddr++;
     }

     DMACH[ch].IndirAddr |= CPUM.ReadA((DMACH[ch].ABusBank << 16) + DMACH[ch].TableAddr) << 8;
     DMACH[ch].TableAddr++;
     //fprintf(stderr, " HDMA %u New IndirAddr=0x%04x --- scanline=%u\n", ch, DMACH[ch].IndirAddr, scanline);
    }

    if(!DMACH[ch].LineCounter)
     HDMAEnableMask &= ~(1U << ch);

    DMACH[ch].DoTransfer = true;
   } // end if(!(DMACH[ch].LineCounter & 0x7F))
   else
    CPUM.timestamp += MEMCYC_SLOW;
  }
 }

 CPUM.InDMABusAccess = false;
 //
 //
 if((CPUM.halted & CPU_Misc::HALTED_DMA) && DMAEnable == 0)
  CPUM.halted &= ~CPU_Misc::HALTED_DMA;
}


static DEFWRITE(Write_420B)
{
 CPUM.timestamp += MEMCYC_FAST;

#ifdef SNES_DBG_ENABLE
 if(V)
  fprintf(stderr, "DMA: %02x --- %u, scanline=%u\n", V, CPUM.timestamp, PPU_GetRegister(PPU_GSREG_SCANLINE, nullptr, 0));
 for(unsigned i = 0; i < 8; i++)
 {
  if(V & (1 << i))
  {
   fprintf(stderr, " %d: Control=0x%02x, BBusAddr=0x%02x, ABusAddr=0x%04x, ABusBank=0x%02x, Count=0x%02x\n", i, DMACH[i].Control, DMACH[i].BBusAddr, DMACH[i].ABusAddr, DMACH[i].ABusBank, DMACH[i].Count);
  }
 }
#endif
 DMAEnable = V;

 if(DMAEnable)
  SNES_SetEventNT(SNES_EVENT_DMA_DUMMY, CPUM.timestamp);
}

static DEFWRITE(Write_420C)
{
 CPUM.timestamp += MEMCYC_FAST;

 HDMAEnable = V;

 SNES_DBG("[DMA] HDMAEnable: %02x --- scanline=%u\n", V, PPU_GetRegister(PPU_GSREG_SCANLINE, nullptr, 0));
}

//
//
DEFWRITE(DMA_Write_43x0)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u Control Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].Control = V;
}

static DEFREAD(Read_43x0)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].Control;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].Control;
}
//
//
static DEFWRITE(Write_43x1)
{
 CPUM.timestamp += MEMCYC_FAST;

 //fprintf(stderr, "*** Write BBusAddr, =0x%02x --- scanline=%u\n", V, scanline);
 SNES_DBG("[DMA] CH %u BBusAddr Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].BBusAddr = V;
}

static DEFREAD(Read_43x1)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].BBusAddr;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].BBusAddr;
}
//
//
DEFWRITE(DMA_Write_43x2)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u ABusAddrL Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].ABusAddr &= 0xFF00;
 DMACH[(A >> 4) & 0x7].ABusAddr |= V << 0;
}

static DEFREAD(Read_43x2)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].ABusAddr >> 0;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].ABusAddr >> 0;
}
//
//
DEFWRITE(DMA_Write_43x3)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u ABusAddrH Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].ABusAddr &= 0x00FF;
 DMACH[(A >> 4) & 0x7].ABusAddr |= V << 8;
}

static DEFREAD(Read_43x3)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].ABusAddr >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].ABusAddr >> 8;
}
//
//
DEFWRITE(DMA_Write_43x4)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u ABusBank Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].ABusBank = V;
}

static DEFREAD(Read_43x4)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].ABusBank;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].ABusBank;
}
//
//
DEFWRITE(DMA_Write_43x5)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u IndirAddrL Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].IndirAddr &= 0xFF00;
 DMACH[(A >> 4) & 0x7].IndirAddr |= V << 0;
}

static DEFREAD(Read_43x5)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].IndirAddr >> 0;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].IndirAddr >> 0;
}
//
//
DEFWRITE(DMA_Write_43x6)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u IndirAddrH Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].IndirAddr &= 0x00FF;
 DMACH[(A >> 4) & 0x7].IndirAddr |= V << 8;
}

static DEFREAD(Read_43x6)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].IndirAddr >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].IndirAddr >> 8;
}
//
//
static DEFWRITE(Write_43x7)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u IndirBank Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].IndirBank = V;
}

static DEFREAD(Read_43x7)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].IndirBank;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].IndirBank;
}
//
//
static DEFWRITE(Write_43x8)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u TableAddrL Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].TableAddr &= 0xFF00;
 DMACH[(A >> 4) & 0x7].TableAddr |= V << 0;
}

static DEFREAD(Read_43x8)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].TableAddr >> 0;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].TableAddr >> 0;
}
//
//
static DEFWRITE(Write_43x9)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u TableAddrH Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].TableAddr &= 0x00FF;
 DMACH[(A >> 4) & 0x7].TableAddr |= V << 8;
}

static DEFREAD(Read_43x9)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].TableAddr >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].TableAddr >> 8;
}
//
//
static DEFWRITE(Write_43xA)
{
 CPUM.timestamp += MEMCYC_FAST;

 SNES_DBG("[DMA] CH %u LineCounter Write, 0x%02x\n", (A >> 4) & 0x7, V);

 DMACH[(A >> 4) & 0x7].LineCounter = V;
}

static DEFREAD(Read_43xA)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].LineCounter;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].LineCounter;
}
//
//
static DEFWRITE(Write_43xB_43xF)
{
 CPUM.timestamp += MEMCYC_FAST;

 DMACH[(A >> 4) & 0x7].Unknown = V;
}

static DEFREAD(Read_43xB_43xF)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DMACH[(A >> 4) & 0x7].Unknown;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DMACH[(A >> 4) & 0x7].Unknown;
}

//
//
static void DMA_Reset(bool powering_up)
{
 DMAEnable = 0;
 HDMAEnable = 0;
 HDMAEnableMask = 0;

 for(unsigned ch = 0; ch < 8; ch++)
 {
  if(powering_up)
  {
   DMACH[ch].Control = 0xFF;
   DMACH[ch].BBusAddr = 0xFF;
   DMACH[ch].ABusAddr = 0xFFFF;
   DMACH[ch].ABusBank = 0xFF;
   DMACH[ch].Count = 0xFFFF;
   DMACH[ch].IndirBank = 0xFF;
   DMACH[ch].TableAddr = 0xFFFF;
   DMACH[ch].LineCounter = 0xFF;
   DMACH[ch].Unknown = 0xFF;

   DMACH[ch].Offset = 0;
   DMACH[ch].DoTransfer = false;
  }
 }
}

static void DMA_Init(void)
{
 CPUM.InDMABusAccess = false;

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x420B, OBRead_FAST, Write_420B);
   Set_A_Handlers((bank << 16) | 0x420C, OBRead_FAST, Write_420C);

   for(unsigned ch = 0; ch < 8; ch++)
   {
    const uint32 chba = (bank << 16) + 0x4300 + (ch << 4);

    Set_A_Handlers(chba + 0x0, Read_43x0, DMA_Write_43x0);
    Set_A_Handlers(chba + 0x1, Read_43x1, Write_43x1);
    Set_A_Handlers(chba + 0x2, Read_43x2, DMA_Write_43x2);
    Set_A_Handlers(chba + 0x3, Read_43x3, DMA_Write_43x3);
    Set_A_Handlers(chba + 0x4, Read_43x4, DMA_Write_43x4);
    Set_A_Handlers(chba + 0x5, Read_43x5, DMA_Write_43x5);
    Set_A_Handlers(chba + 0x6, Read_43x6, DMA_Write_43x6);
    Set_A_Handlers(chba + 0x7, Read_43x7, Write_43x7);
    Set_A_Handlers(chba + 0x8, Read_43x8, Write_43x8);
    Set_A_Handlers(chba + 0x9, Read_43x9, Write_43x9);
    Set_A_Handlers(chba + 0xA, Read_43xA, Write_43xA);
    Set_A_Handlers(chba + 0xB, Read_43xB_43xF, Write_43xB_43xF);
    Set_A_Handlers(chba + 0xF, Read_43xB_43xF, Write_43xB_43xF);
   }
  }
 }
}

static void DMA_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(DMAEnable),
  SFVAR(HDMAEnable),
  SFVAR(HDMAEnableMask),

  #define SFDMACH(n)			\
	SFVAR(DMACH[n].Control),	\
	SFVAR(DMACH[n].BBusAddr),	\
	SFVAR(DMACH[n].ABusAddr),	\
	SFVAR(DMACH[n].ABusBank),	\
	SFVAR(DMACH[n].IndirBank),	\
	SFVAR(DMACH[n].Count),		\
	SFVAR(DMACH[n].TableAddr),	\
	SFVAR(DMACH[n].LineCounter),	\
	SFVAR(DMACH[n].Unknown),	\
	SFVAR(DMACH[n].Offset),		\
	SFVAR(DMACH[n].DoTransfer)

  SFDMACH(0),
  SFDMACH(1),
  SFDMACH(2),
  SFDMACH(3),
  SFDMACH(4),
  SFDMACH(5),
  SFDMACH(6),
  SFDMACH(7),

  #undef SFDMACH

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DMA");
}
//
//
//

uint32 DMA_GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 const unsigned ch = (id >> 8) & 0x7;
 uint32 ret = 0xDEADBEEF;

 switch(id & ~0x700)
 {
  case DMA_GSREG_DMAENABLE:
	ret = DMAEnable;
	break;

  case DMA_GSREG_HDMAENABLE:
	ret = HDMAEnable;
	break;

  case DMA_GSREG_HDMAENABLEM:
	ret = HDMAEnableMask;
	break;

  case DMA_GSREG_CHN_CONTROL:
	ret = DMACH[ch].Control;
	break;

  case DMA_GSREG_CHN_BBUSADDR:
	ret = DMACH[ch].BBusAddr;
	break;

  case DMA_GSREG_CHN_ABUSADDR:
	ret = DMACH[ch].ABusAddr;
	break;

  case DMA_GSREG_CHN_ABUSBANK:
	ret = DMACH[ch].ABusBank;
	break;

  case DMA_GSREG_CHN_INDIRBANK:
	ret = DMACH[ch].IndirBank;
	break;

  case DMA_GSREG_CHN_COUNT_INDIRADDR:
	ret = DMACH[ch].IndirAddr;
	break;

  case DMA_GSREG_CHN_TABLEADDR:
	ret = DMACH[ch].TableAddr;
	break;

  case DMA_GSREG_CHN_LINECOUNTER:
	ret = DMACH[ch].LineCounter;
	break;

  case DMA_GSREG_CHN_UNKNOWN:
	ret = DMACH[ch].Unknown;
	break;

  case DMA_GSREG_CHN_OFFSET:
	ret = DMACH[ch].Offset;
	break;

  case DMA_GSREG_CHN_DOTRANSFER:
	ret = DMACH[ch].DoTransfer;
	break;
 }

 return ret;
}

void DMA_SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  // TODO
 }
}

