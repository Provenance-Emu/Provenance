/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* sdd1.cpp:
**  Copyright (C) 2019 Mednafen Team
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

/*
 TODO:
	Decompression DMA stuff is probably not correct.

	Check register readability.
*/

#include "common.h"
#include "sdd1.h"

namespace MDFN_IEN_SNES_FAUST
{

static uint8 ROMBank[4];
static uintptr_t ROMPtr[8];

static INLINE void RecalcROMPtr(size_t rbi)
{
 ROMPtr[0 + rbi] = (uintptr_t)&Cart.ROM[(ROMBank[rbi] & 0x80) ? ((ROMBank[rbi] & 0x7) << 20) : (rbi << 20)];
 ROMPtr[4 + rbi] = (uintptr_t)&Cart.ROM[(ROMBank[rbi] & 0x7) << 20] - ((0xC0 + (rbi << 4)) << 16);
}

static uint8 DMAEnable[2];
static uint8 DMARegs[0x80];

struct EvTableS
{
 EvTableS* next[2];
 unsigned golomb_n;
 bool mps_update_mask;
};

static struct
{
 uint32 dma_trigger_addr;
 uint32 dma_count;
 //
 uint32 depth;
 uint32 depth_planes;

 uint32 input_addr;
 uint32 input_bits;
 uint32 input_bits_count;

 uint32 prev_bits_mask[2];
 uint32 prev_bits[8];

 uint32 output_buf_pos;
 uint32 output_buf_pos_mask;
 uint8 output_buf[0x40];

 struct
 {
  uint8 run_counter;
  bool run_end_bit;
 } bitgen[8];

 struct
 {
  bool mps;
  EvTableS* pred;
 } contexts[0x20];
 //
 //
 //
 uint8 rev_inv_table[0x100];
 EvTableS ev_table[0x21];
} Decomp;


static INLINE uint8 ReadROM(uint32 A)
{
 return *(uint8*)(*(ROMPtr + 4 + ((A >> 20) & 0x3)) + A);
}

static INLINE void ReadyInputBits(unsigned count)
{
 if(Decomp.input_bits_count < count)
 {
  Decomp.input_bits |= ReadROM(Decomp.input_addr) << (8 - Decomp.input_bits_count);
  Decomp.input_addr++;
  Decomp.input_bits_count += 8;
 }
}

static INLINE void AdvanceInputBits(unsigned count)
{
 Decomp.input_bits <<= count;
 Decomp.input_bits_count -= count;
}

static INLINE uint8 GetInputBits(unsigned count = 1)
{
 //assert(count <= 8);
 //
 uint8 ret;

 ReadyInputBits(count);

 ret = (Decomp.input_bits >> (16 - count)) & ((1U << count) - 1);
 AdvanceInputBits(count);

 return ret;
}

static INLINE uint8 PeekInputByte(void)
{
 ReadyInputBits(8);

 return Decomp.input_bits >> 8;
}

static void InitDecomp(const uint32 addr)
{
 for(unsigned c = 0; c < 0x20; c++)
 {
  Decomp.contexts[c].mps = false;
  Decomp.contexts[c].pred = &Decomp.ev_table[0x20];
 }

 for(unsigned p = 0; p < 8; p++)
 {
  Decomp.prev_bits[p] = 0;
 } 

 for(unsigned bg = 0; bg < 8; bg++)
 {
  Decomp.bitgen[bg].run_counter = 0;
  Decomp.bitgen[bg].run_end_bit = false;
 }
 //
 //
 //
 Decomp.input_addr = addr;
 Decomp.input_bits = 0;
 Decomp.input_bits_count = 0;

 Decomp.output_buf_pos = 0;
 //
 //
 //
 uint32 prevsel;

 SNES_DBG("[SDD1] Decompression start; addr=0x%06x\n", addr);
 //assert(Decomp.input_addr >= 0xC00000);

 Decomp.depth = GetInputBits(2);
 prevsel = GetInputBits(2);
 SNES_DBG("[SDD1]  depth=%u, prevsel=%u\n", Decomp.depth, prevsel);
 //
 switch(Decomp.depth)
 {
  case 0: Decomp.output_buf_pos_mask = 0x0F; Decomp.depth_planes = 2; break;
  case 2: Decomp.output_buf_pos_mask = 0x1F; Decomp.depth_planes = 4; break;

  case 1: Decomp.output_buf_pos_mask = 0x3F; Decomp.depth_planes = 8; break;
  case 3: Decomp.output_buf_pos_mask = 0x3F; Decomp.depth_planes = 8; break;
 }
 //
 Decomp.prev_bits_mask[0] = 0x1;
 switch(prevsel)
 {
  case 0: Decomp.prev_bits_mask[1] = 0x7 << 1; break;
  case 1: Decomp.prev_bits_mask[1] = 0x6 << 1; break;
  case 2: Decomp.prev_bits_mask[1] = 0x3 << 1; break;
  case 3: Decomp.prev_bits_mask[1] = 0x6 << 1; Decomp.prev_bits_mask[0] = 0x3; break;
 }
}

static INLINE bool DecompBit(unsigned plane)
{
 uint32* prev_bits = &Decomp.prev_bits[plane];
 bool ret;
 uint32 c;

/*
 c  = pl->prev_bits & 0x1;
 c |= (plane & 0x1) << 4;

 switch(Decomp.prevsel)
 {
  case 0:
	c |= ((pl->prev_bits >> 6) & 0x7) << 1;
	break

  case 1:
	c |= ((pl->prev_bits >> 6) & 0x6) << 1;
	break;

  case 2:
	c |= ((pl->prev_bits >> 6) & 0x3) << 1;
	break;

  case 3:
	c |= (pl->prev_bits & 0x2);
	c |= ((pl->prev_bits >> 6) & 0x6) << 1;
	break;
 }
*/
// c = (((pl->prev_bits >> 0) & 1) << 0) | (((pl->prev_bits >> 6) & 1) << 1) | (((pl->prev_bits >> 7) & 1) << 2) | (((pl->prev_bits >> 8) & 1) << 3);
 //c = (((pl->prev_bits >> 0) & 1) << 0) | (((pl->prev_bits >> 6) & 1) << 1) | (((pl->prev_bits >> 7) & 1) << 2) | (((pl->prev_bits >> 8) & 1) << 3);
 //c = (((pl->prev_bits >> 0) & 1) << 0) | (((pl->prev_bits >> 1) & 1) << 1) | (((pl->prev_bits >> 7) & 1) << 2) | (((pl->prev_bits >> 8) & 1) << 3);
 c = (*prev_bits & Decomp.prev_bits_mask[0]) | ((*prev_bits >> 5) & Decomp.prev_bits_mask[1]);
 c |= (plane & 0x1) << 4;
 //
 //
 auto* ctx = &Decomp.contexts[c];
 const unsigned gn = ctx->pred->golomb_n;
 auto* bg = &Decomp.bitgen[gn];

 ret = ctx->mps;

 if(!bg->run_counter)
 {
/*
  bool b = GetInputBits(1);

  bg->run_end_bit = b;
  if(!b)
   bg->run_counter = 1U << gn;
  else
  {
   const unsigned shift = 8 - gn;

   bg->run_counter = 1 + (Decomp.rev_inv_table[GetInputBits(gn) << shift] & ((1U << gn) - 1));
  }
*/
  uint8 tmp = PeekInputByte();
  bg->run_end_bit = tmp >> 7;
  bg->run_counter = 1 + (Decomp.rev_inv_table[tmp] & ((1U << gn) - 1));
  AdvanceInputBits(1 + (gn & ((int8)tmp >> 7)));
 }
 bg->run_counter--;
 if(!bg->run_counter)
 {
  ret ^= bg->run_end_bit;
  ctx->mps ^= bg->run_end_bit & ctx->pred->mps_update_mask;
  ctx->pred = ctx->pred->next[bg->run_end_bit];
 }
 //
 *prev_bits = (*prev_bits << 1) | ret;

 return ret;
}

static void DoDecomp(void)
{
 if(Decomp.depth == 3)
 {
  for(uint32 i = 0; i < 64; i++)
  {
   uint8 tmp = 0;

   for(uint32 p = 0; p < 8; p++)
   {
    DecompBit(p);
    tmp |= (Decomp.prev_bits[p] & 1) << p;
   }

   Decomp.output_buf[i] = tmp;
  }
 }
 else
 {
  for(uint32 p = 0; p < Decomp.depth_planes; p += 2)
  {
   for(uint32 y = 0; y < 8; y++)
   {
    for(uint32 x = 0; x < 8; x++)
    {
     DecompBit(p + 0);
     DecompBit(p + 1);
    }
    Decomp.output_buf[(p << 3) + (y << 1) + 0] = Decomp.prev_bits[p + 0];
    Decomp.output_buf[(p << 3) + (y << 1) + 1] = Decomp.prev_bits[p + 1];
   }
  }
 }
}

static INLINE uint8 DecompByte(void)
{
 uint8 ret = 0;

 if(!Decomp.output_buf_pos)
  DoDecomp();

 ret = Decomp.output_buf[Decomp.output_buf_pos];
 Decomp.output_buf_pos = (Decomp.output_buf_pos + 1) & Decomp.output_buf_pos_mask;
 //
 Decomp.dma_count--;
 if(!Decomp.dma_count)
  Decomp.dma_trigger_addr = ~0U;

 return ret;
}


template<unsigned T_offs>
static DEFWRITE(SDD1_Write_43xx)
{
 static_assert(T_offs == 0 || T_offs == 2 || T_offs == 3 || T_offs == 4 || T_offs == 5 || T_offs == 6, "wrong offs");
 switch(T_offs)
 {
  case 0: DMA_Write_43x0(A, V); break;
  case 2: DMA_Write_43x2(A, V); break;
  case 3: DMA_Write_43x3(A, V); break;
  case 4: DMA_Write_43x4(A, V); break;
  case 5: DMA_Write_43x5(A, V); break;
  case 6: DMA_Write_43x6(A, V); break;
 }

 DMARegs[((A >> 1) & 0x78) + (A & 0x7)] = V;
}

/*
static INLINE uint8 ReadROM(size_t region, uint32 A)
{
 if(region < 0x4)
  return *(uint8*)(ROMPtr[region] + (A & 0x7FFF) + ((A >> 1) & 0xF8000));
 else
  return *(uint8*)(ROMPtr[region] + A);
}
*/

template<signed cyc>
static DEFREAD(MainCPU_ReadLoROM)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 }
 //
 //
 return *(uint8*)(*(ROMPtr + 0 + ((A >> 21) & 0x3)) + (A & 0x7FFF) + ((A >> 1) & 0xF8000));
}

template<signed cyc>
static DEFREAD(MainCPU_ReadHiROM)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 }
 //
 //
 if(A == Decomp.dma_trigger_addr)
  return DecompByte();

 return *(uint8*)(*(ROMPtr + 4 + ((A >> 20) & 0x3)) + A);
}

template<signed cyc, unsigned w>
static DEFWRITE(MainCPU_WriteIO)
{
 CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 //
 //
 SNES_DBG("[SDD1] IO write 0x%06x 0x%02x\n", A, V);

 switch(w)
 {
  case 0x0:
	DMAEnable[0] = V;
	break;

  case 0x1:
	DMAEnable[1] = V;
	//
	Decomp.dma_trigger_addr = ~0U;
        for(unsigned ch = 0; ch < 8; ch++)
        {
         if((DMAEnable[0] & DMAEnable[1] & (1U << ch)) && (DMARegs[(ch << 3) + 0] & 0x88) == 0x08)
	 {
	  //assert(Decomp.dma_trigger_addr == ~0U);

	  Decomp.dma_trigger_addr = MDFN_de24lsb(&DMARegs[(ch << 3) + 2]);
	  Decomp.dma_count = MDFN_de16lsb(&DMARegs[(ch << 3) + 5]);
	  //
 	  InitDecomp(Decomp.dma_trigger_addr);
	  break;
	 }
	}
	break;

  case 0x4:
  case 0x5:
  case 0x6:
  case 0x7:
	{
	 size_t rbi = w & 0x3;
	 ROMBank[rbi] = V;
	 RecalcROMPtr(rbi);
	}
	break;
 }
}

template<signed cyc, unsigned w>
static DEFREAD(MainCPU_ReadIO)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 }
 //
 //
 uint8 ret = 0;

 SNES_DBG("[SDD1] IO read 0x%06x\n", A);

 switch(w)
 {
  case 0x0:
	ret = DMAEnable[0];
	break;

  case 0x4:
  case 0x5:
  case 0x6:
  case 0x7:
	ret = ROMBank[w & 0x3];  
	break;
 }

 return ret;
}

template<size_t mask = SIZE_MAX>
static DEFREAD(MainCPU_ReadSRAM)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return Cart.RAM[A & mask & Cart.RAM_Mask];
 }
 //
 CPUM.timestamp += MEMCYC_SLOW;
 //
 return Cart.RAM[A & mask & Cart.RAM_Mask];
}

template<size_t mask = SIZE_MAX>
static DEFWRITE(MainCPU_WriteSRAM)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 Cart.RAM[A & mask & Cart.RAM_Mask] = V;
}

static MDFN_COLD void Reset(bool powering_up)
{
 for(size_t rbi = 0; rbi < 4; rbi++)
 {
  ROMBank[rbi] = rbi;
  RecalcROMPtr(rbi);
 }

 DMAEnable[0] = 0;
 DMAEnable[1] = 0;

 memset(DMARegs, 0xFF, sizeof(DMARegs));

 Decomp.dma_trigger_addr = 0;
 Decomp.dma_count = 0;

 Decomp.depth = 0;
 Decomp.depth_planes = 0;

 Decomp.input_addr = 0;
 Decomp.input_bits = 0;
 Decomp.input_bits_count = 0;

 for(unsigned i = 0; i < 2; i++)
  Decomp.prev_bits_mask[i] = 0;

 for(unsigned i = 0; i < 8; i++)
  Decomp.prev_bits[i] = 0;

 Decomp.output_buf_pos = 0;
 Decomp.output_buf_pos_mask = 0;
 memset(Decomp.output_buf, 0x00, sizeof(Decomp.output_buf));

 for(unsigned i = 0; i < 8; i++)
 {
  Decomp.bitgen[i].run_counter = 0;
  Decomp.bitgen[i].run_end_bit = 0;
 }

 for(unsigned i = 0; i < 0x20; i++)
 {
  Decomp.contexts[i].mps = false;
  Decomp.contexts[i].pred = &Decomp.ev_table[0x20];
 }
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 uint8 contexts_pred[0x20];

 for(unsigned i = 0; i < 0x20; i++)
  contexts_pred[i] = Decomp.contexts[i].pred - Decomp.ev_table;

 SFORMAT StateRegs[] =
 {
  SFVAR(ROMBank),
  SFVAR(DMAEnable),
  SFVAR(DMARegs),
  //
  SFVAR(Decomp.dma_trigger_addr),
  SFVAR(Decomp.dma_count),

  SFVAR(Decomp.depth),
  SFVAR(Decomp.depth_planes),

  SFVAR(Decomp.input_addr),
  SFVAR(Decomp.input_bits),
  SFVAR(Decomp.input_bits_count),

  SFVAR(Decomp.prev_bits_mask),
  SFVAR(Decomp.prev_bits),

  SFVAR(Decomp.output_buf_pos),
  SFVAR(Decomp.output_buf_pos_mask),
  SFVAR(Decomp.output_buf),

  SFVAR(Decomp.bitgen->run_counter, 8, sizeof(*Decomp.bitgen), Decomp.bitgen),
  SFVAR(Decomp.bitgen->run_end_bit, 8, sizeof(*Decomp.bitgen), Decomp.bitgen),

  SFVAR(Decomp.contexts->mps, 0x20, sizeof(*Decomp.contexts), Decomp.contexts),
  SFVAR(contexts_pred),
  //
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SDD1");

 if(load)
 {
  for(size_t rbi = 0; rbi < 4; rbi++)
   RecalcROMPtr(rbi);

  for(unsigned i = 0; i < 0x20; i++)
   Decomp.contexts[i].pred = Decomp.ev_table + (contexts_pred[i] % 0x21);

  Decomp.depth &= 0x3;
  Decomp.depth_planes = std::min<uint32>(Decomp.depth_planes, 8);

  Decomp.output_buf_pos_mask &= 0x3F;
  Decomp.output_buf_pos &= Decomp.output_buf_pos_mask;
 }
}

void CART_SDD1_Init(const int32 master_clock)
{
 if(Cart.RAM_Size)
  Set_A_Handlers(0x700000, 0x73FFFF, MainCPU_ReadSRAM, MainCPU_WriteSRAM);

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(!(bank & 0x40))
  {
   #define SHP(ta) Set_A_Handlers((bank << 16) | (0x4800 + ta), MainCPU_ReadIO<MEMCYC_FAST, ta>, MainCPU_WriteIO<MEMCYC_FAST, ta>);
   SHP(0x0)
   SHP(0x1)
   SHP(0x2)
   SHP(0x3)
   SHP(0x4)
   SHP(0x5)
   SHP(0x6)
   SHP(0x7)
   #undef SHP

   if(Cart.RAM_Size)
   {
    Set_A_Handlers((bank << 16) | 0x6000, (bank << 16) | 0x7FFF,
	((bank & 0x80) ? MainCPU_ReadSRAM<0x1FFF> : MainCPU_ReadSRAM<0x1FFF>),
	((bank & 0x80) ? MainCPU_WriteSRAM<0x1FFF> : MainCPU_WriteSRAM<0x1FFF>));
   }

   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, (bank & 0x80) ? MainCPU_ReadLoROM<-1> : MainCPU_ReadLoROM<MEMCYC_SLOW>, (bank & 0x80) ? OBWrite_VAR : OBWrite_SLOW);
   //
   //
   for(unsigned ch = 0; ch < 8; ch++)
   {
    const uint32 chba = (bank << 16) + 0x4300 + (ch << 4);

    Set_A_Handlers(chba + 0x0, nullptr, SDD1_Write_43xx<0>);
    Set_A_Handlers(chba + 0x2, nullptr, SDD1_Write_43xx<2>);
    Set_A_Handlers(chba + 0x3, nullptr, SDD1_Write_43xx<3>);
    Set_A_Handlers(chba + 0x4, nullptr, SDD1_Write_43xx<4>);
    Set_A_Handlers(chba + 0x5, nullptr, SDD1_Write_43xx<5>);
    Set_A_Handlers(chba + 0x6, nullptr, SDD1_Write_43xx<6>);
   }
  }
  else if(bank & 0x80)
  {
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, (bank & 0x80) ? MainCPU_ReadHiROM<-1> : MainCPU_ReadHiROM<MEMCYC_SLOW>, (bank & 0x80) ? OBWrite_VAR : OBWrite_SLOW);
  }
 }
 //
 //
 //
 for(int i = 0; i < 0x21; i++)
 {
  EvTableS* e = &Decomp.ev_table[i];

  e->mps_update_mask = !(i & 0x1F);

  if(i < 0x18)
  {
   if(i < 0x10)
    e->golomb_n = i >> 2;
   else
    e->golomb_n = 4 + ((i >> 1) & 0x3);

   e->next[0] = &Decomp.ev_table[std::min<int>(0x17, i + 1)];
   e->next[1] = &Decomp.ev_table[std::max<int>(0x00, i - 1)];
  }
  else if(i < 0x20)
  {
   static const uint8 tab[8] = { 0, 1, 3, 7, 11, 15, 17, 21 };
   e->golomb_n = i - 0x18;
   e->next[0] = &Decomp.ev_table[(i == 0x1F) ? 0x17 : i + 1];
   e->next[1] = &Decomp.ev_table[tab[i & 0x7]];
  }
  else
  {
   e->golomb_n = 0;
   e->next[0] = &Decomp.ev_table[0x18];
   e->next[1] = &Decomp.ev_table[0x18];
  }

  //if(i == 24)
  // e->mps_update_mask = true;

  //printf("%2u: golomb_n=%u, mps_next=%u, lps_next=%u. update_mask=%u\n", i, e->golomb_n, (unsigned)(e->next[0] - &Decomp.ev_table[0]), (unsigned)(e->next[1] - &Decomp.ev_table[0]), e->mps_update_mask);
 }

/*
 for(unsigned i = 0; i < 0x100; i++)
 {
  const unsigned k = ~i;

  Decomp.rev_inv_table[i] = ((k >> 7) & 0x1) | ((k >> 5) & 0x2) | ((k >> 3) & 0x4) | ((k >> 1) & 0x8) | ((k << 1) & 0x10) | ((k << 3) & 0x20) | ((k << 5) & 0x40) | ((k << 7) & 0x80);
 }
*/

 for(unsigned i = 0; i < 0x100; i++)
 {
  uint8 tmp = 0xFF;

  if(i & 0x80)
  {
   const unsigned k = ~i;
   tmp = ((k >> 6) & 0x1) | ((k >> 4) & 0x2) | ((k >> 2) & 0x4) | ((k >> 0) & 0x8) | ((k << 2) & 0x10) | ((k << 4) & 0x20) | ((k << 6) & 0x40);
  }

  Decomp.rev_inv_table[i] = tmp;
 }
 //
 //
 //
 Cart.Reset = Reset;
 Cart.StateAction = StateAction;
}

}
