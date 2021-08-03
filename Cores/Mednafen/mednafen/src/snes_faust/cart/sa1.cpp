/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* sa1.cpp:
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

/* Much guesswork */

#include "common.h"
#include "sa1.h"
#include "sa1cpu.h"

namespace MDFN_IEN_SNES_FAUST
{

namespace SA1CPU
{
#ifdef ARCH_X86
MDFN_HIDE CPU_Misc CPUM;
#else
static CPU_Misc CPUM;
#endif

static INLINE void CPU_SetIRQ(bool active)
{
 CPUM.CombinedNIState &= ~0x04;
 CPUM.CombinedNIState |= active ? 0x04 : 0x00;
}

static INLINE void CPU_SetNMI(bool active)
{
 if((CPUM.NMILineState ^ active) & active)
  CPUM.CombinedNIState |= 0x01;

 CPUM.NMILineState = active;
}

static INLINE void CPU_SetIRQNMISuppress(bool active)
{
 CPUM.CombinedNIState &= ~0x80;
 CPUM.CombinedNIState |= active ? 0x80 : 0x00;
}


static INLINE void CPU_Exit(void)
{
 CPUM.running_mask = 0;
 CPUM.next_event_ts = 0;
}

//
//
static MDFN_COLD void CPU_ClearRWFuncs(void)
{
 memset(CPUM.ReadFuncs, 0, sizeof(CPUM.ReadFuncs));
 memset(CPUM.WriteFuncs, 0, sizeof(CPUM.WriteFuncs));
}

static MDFN_COLD void CPU_SetRWHandlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler, bool special = false)
{
 if(special)
 {
  assert(!((A1 ^ A2) >> 9));

  CPUM.RWIndex[A1 >> 9] = 0;

  for(uint32 A = A1; A <= A2; A++)
  {
   const size_t am = A & 0x1FF;

   //assert((!CPUM.ReadFuncs[am] && !CPUM.WriteFuncs[am]) || (CPUM.ReadFuncs[am] == read_handler && CPUM.WriteFuncs[am] == write_handler));

   CPUM.ReadFuncs[am] = read_handler;
   CPUM.WriteFuncs[am] = write_handler;
  }
 }
 else
 {
  assert(!(A1 & 0x1FF) && (A2 & 0x1FF) == 0x1FF);
  assert(A1 <= A2);
  assert((A2 >> 9) < 0x8000);

  size_t index = 512;

  while(index < (512 + 256) && CPUM.ReadFuncs[index] && CPUM.WriteFuncs[index] && (CPUM.ReadFuncs[index] != read_handler || CPUM.WriteFuncs[index] != write_handler))
   index++;

  assert(index < (512 + 256));

  CPUM.ReadFuncs[index] = read_handler;
  CPUM.WriteFuncs[index] = write_handler;

  for(uint32 A = A1; A <= A2; A += 512)
   CPUM.RWIndex[A >> 9] = index;

  CPUM.RWIndex[0x8000] = CPUM.RWIndex[0x7FFF];
 }
}
}

#define GLBVAR(x) static auto& x = SA1CPU::CPUM.x;
GLBVAR(SA1VectorSpace)
GLBVAR(SA1VectorMask)
GLBVAR(MainVectors)

GLBVAR(SA1CPUControl)
GLBVAR(SA1CPUIRQEnable)
GLBVAR(SA1CPUIRQPending)

GLBVAR(MainCPUControl)
GLBVAR(MainCPUIRQEnable)
GLBVAR(MainCPUIRQPending)

GLBVAR(DMAControl)
GLBVAR(DMACharConvParam)
GLBVAR(DMASourceAddr)
GLBVAR(DMADestAddr)
GLBVAR(DMALength)
GLBVAR(DMAFinishTS)

GLBVAR(DMACharConvAutoActive)
GLBVAR(DMACharConvSourceXTile)
GLBVAR(DMACharConvSourceYTile)
GLBVAR(DMACharConvCCVBWRAMCounter)
GLBVAR(CharConvBMRegs)
GLBVAR(CharConvTileY)


GLBVAR(ROMBank)
GLBVAR(ROMPtr)

GLBVAR(MainBWRAMBank)
GLBVAR(SA1BWRAMBank)
GLBVAR(BWRAMWriteEnable)
GLBVAR(BWRAMWriteProtectSize)
GLBVAR(IWRAMWriteEnable)

GLBVAR(BWRAMBitmapFormat)

//
GLBVAR(MathControl)
GLBVAR(MathParam)
GLBVAR(MathResult)

GLBVAR(VarLenControl)
GLBVAR(VarLenAddr)
GLBVAR(VarLenCurAddr)
GLBVAR(VarLenCurBitOffs)
GLBVAR(VarLenBuffer)

GLBVAR(IRAM)

GLBVAR(SA1CPUBoundTS)

#undef GLBVAR
//
//
//
static INLINE void RecalcROMPtr(unsigned w)
{
 ROMPtr[0 + w] = (uintptr_t)&Cart.ROM[(ROMBank[w] & 0x80) ? ((ROMBank[w] & 0x7) << 20) : (w << 20)];
 ROMPtr[4 + w] = (uintptr_t)&Cart.ROM[(ROMBank[w] & 0x7) << 20] - ((0xC0 + (w << 4)) << 16);
}

static void AdjustTS(int32 delta)
{
 SA1CPU::CPUM.timestamp += delta;
 if(DMAFinishTS != 0x7FFFFFFF)
  DMAFinishTS = std::max<int64>(0, (int64)DMAFinishTS + delta);
}

static NO_INLINE void Update(uint32 timestamp)
{
 SA1CPUBoundTS = timestamp;
 SA1CPU::CPUM.next_event_ts = std::min<uint32>(DMAFinishTS, SA1CPUBoundTS);
 SA1CPU::CPU_Run();
}

static uint32 EventHandler(uint32 timestamp)
{
 Update(timestamp);

 return timestamp + 256;
}
//
//
//
void SA1CPU::CPU_Misc::RunDMA(void)
{
 //puts("HAH");
 SA1CPU::CPUM.timestamp = SA1CPU::CPUM.next_event_ts;
}

void SA1CPU::CPU_Misc::EventHandler(void)
{
 if(MDFN_UNLIKELY(timestamp >= DMAFinishTS))
 {
  if(SA1CPUIRQEnable & 0x20)
  {
   SA1CPUIRQPending |= 0x20;
   SA1CPU::CPU_SetIRQ(SA1CPUIRQPending & 0xE0);
  }
  //
  DMAFinishTS = 0x7FFFFFFF;
 }

 SA1CPU::CPUM.next_event_ts = std::min<uint32>(DMAFinishTS, SA1CPUBoundTS);

 if(timestamp >= SA1CPUBoundTS)
  SA1CPU::CPU_Exit();
}


template<bool SA1Side>
static DEFWRITE(WriteIRAM)
{
 if(SA1Side)
  SA1CPU::CPUM.timestamp += 2;
 else
 {
  CPUM.timestamp += MEMCYC_FAST;
  //
  Update(CPUM.timestamp);
 }
 //
 A &= 0x7FF;
 if((IWRAMWriteEnable[SA1Side] >> (A >> 8)) & 1)
  IRAM[A] = V;
 else
  SNES_DBG("[%s] IRAM write blocked; 0x%06x 0x%02x\n", SA1Side ? "SA1CPU" : "SA1", A, V);
}

template<bool SA1Side>
static DEFREAD(ReadIRAM)
{
 if(SA1Side)
  SA1CPU::CPUM.timestamp += 2;
 else
 {
  if(MDFN_LIKELY(!DBG_InHLRead))
  {
   CPUM.timestamp += MEMCYC_FAST;
   //
   Update(CPUM.timestamp);
  }
 }
 //
 return IRAM[A & 0x7FF];
}

static INLINE uint8 ReadROM(size_t region, uint32 A)
{
 if(region < 0x4)
  return *(uint8*)(ROMPtr[region] + (A & 0x7FFF) + ((A >> 1) & 0xF8000));
 else
  return *(uint8*)(ROMPtr[region] + A);
}

static INLINE uint8 DMA_ReadROM(uint32 A)
{
 size_t region;

 if(A >= 0xC00000)
  region = (A >> 20) & 0x7;
 else
 {
  //assert(!(A & 0x400000) && (A & 0x8000));
  region = ((A >> 22) & 0x2) + ((A >> 21) & 0x1);
 }

 return ReadROM(region, A);
}

static NO_INLINE void DMA_RunNormal(const uint32 timestamp)
{
 SNES_DBG("[SA1] DMA: 0x%06x->0x%06x * 0x%04x, Control=0x%02x\n", DMASourceAddr, DMADestAddr, DMALength, DMAControl);

 uint32 DMACurSourceAddr = DMASourceAddr;
 uint32 DMACurDestAddr = DMADestAddr;
 uint32 DMACurCount = DMALength;
 const unsigned DMASourceMem = DMAControl & 0x3;
 const bool DMADestMem = (bool)(DMAControl & 0x4);

 DMAFinishTS = timestamp + (DMALength << (DMASourceMem == 1 || DMADestMem == 1));

 if(((DMASourceMem & 2) && DMADestMem == 0) || (DMASourceMem == 1 && DMADestMem == 1))
  SNES_DBG("[SA1] Attempted to start illegal DMA.");
 else if(!DMACurCount)
  SNES_DBG("[SA1] Attempted to start 0-length DMA.");
 else while(MDFN_LIKELY(DMACurCount))
 {
  uint8 tmp = 0xFF;

  if(DMASourceMem & 2)
   tmp = IRAM[DMACurSourceAddr & 0x7FF];
  else if(DMASourceMem == 1 && Cart.RAM_Mask != SIZE_MAX)
   tmp = Cart.RAM[DMACurSourceAddr & Cart.RAM_Mask];
  else if(DMASourceMem == 0)
   tmp = DMA_ReadROM(DMACurSourceAddr & 0xFFFFFF);

  if(DMADestMem == 1 && Cart.RAM_Mask != SIZE_MAX)
   Cart.RAM[DMACurDestAddr & Cart.RAM_Mask] = tmp;
  else if(DMADestMem == 0)
   IRAM[DMACurDestAddr & 0x7FF] = tmp;
  //
  DMACurCount--;
  DMACurSourceAddr++;
  DMACurDestAddr++;
 }
}

static INLINE void WriteCharConvBMReg(unsigned which, uint8 V)
{
 CharConvBMRegs[which] = V;
 //
 //
 //
 const unsigned depth = DMACharConvParam & 0x3;
 const unsigned bpp = 8 >> depth;

 if(which == 0x7 || which == 0xF)
 {
  uint8 tmp[8] = { 0 };

  for(unsigned x = 0; x < 8; x++)
  {
   const unsigned pix = CharConvBMRegs[x + (which & 8)];
   //   printf("Charconv %08x %08x %zu:%zu %08zx --- %02x\n", DMASourceAddr, DMADestAddr, source_x, source_y, bwoffs, Cart.RAM[bwoffs & Cart.RAM_Mask]);

   for(unsigned i = 0; i < bpp; i++)
    tmp[i] |= ((pix >> i) & 0x1) << (7 - x);
  }

  size_t iro = DMADestAddr + ((CharConvTileY & 0x7) << 1) + ((bool)(CharConvTileY & 8) << (6 - depth));

  for(unsigned i = 0; i < bpp; i++)
   IRAM[(iro + (i & 0x1) + ((i >> 1) << 4)) & 0x7FF] = tmp[i];

  CharConvTileY = (CharConvTileY + 1) & 0xF;
 }
}

static void DMA_RunCharConvIter(void)
{
 const unsigned depth = DMACharConvParam & 0x3;	// 8bpp, 4bpp, 2bpp
 const unsigned vw = (DMACharConvParam >> 2) & 0x7;	// 1, 2, 4, 8, 16, 32, ?, ? characters

 if(MDFN_UNLIKELY(Cart.RAM_Mask == SIZE_MAX))
 {
  for(unsigned i = 0; i < 64; i++)
   WriteCharConvBMReg(i & 0xF, 0xFF);
 }
 else
 {
  for(unsigned y = 0; y < 8; y++)
  {
   for(unsigned x = 0; x < 8; x++)
   {
    const size_t source_x = x + (DMACharConvSourceXTile << 3);
    const size_t source_y = y + (DMACharConvSourceYTile << 3);
    const size_t bwoffs = DMASourceAddr + (((source_y << (3 + vw)) + source_x) >> depth);
    const unsigned src_shift = ((x & ((1 << depth) - 1)) << (3 - depth));
    const unsigned pix = Cart.RAM[bwoffs & Cart.RAM_Mask] >> src_shift;

    //   printf("Charconv %08x %08x %zu:%zu %08zx --- %02x\n", DMASourceAddr, DMADestAddr, source_x, source_y, bwoffs, Cart.RAM[bwoffs & Cart.RAM_Mask]);

    WriteCharConvBMReg(((y & 1) << 3) + x, pix);
   }
  }
 }

 DMACharConvSourceXTile = (DMACharConvSourceXTile + 1) & ((1 << vw) - 1);
 if(!DMACharConvSourceXTile)
 {
  DMACharConvSourceYTile++;
 }
}

static INLINE uint8 DMA_ReadCCVBWRAM(void)
{
 const unsigned depth = DMACharConvParam & 0x3;	// 8bpp, 4bpp, 2bpp
 uint8 ret;

 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  if(!(DMACharConvCCVBWRAMCounter & (0x3F >> depth)))
   DMA_RunCharConvIter();
 }

 ret = IRAM[(DMADestAddr + (DMACharConvCCVBWRAMCounter & (0x7F >> depth))) & 0x7FF];

 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  DMACharConvCCVBWRAMCounter++;
 }

 return ret;
}

template<unsigned T_A>
static INLINE void WriteSharedDMAReg(const uint32 timestamp, uint32 A, uint8 V)
{
 //printf("SharedDMA: %08x %02x\n", A, V);

 if(T_A == 0x2231)
 {
  DMACharConvParam = V & 0x1F;
  //printf("CharConv: %02x\n", V);
  if(V & 0x80)
  {
   DMACharConvAutoActive = false;
  }
 }
 else if(T_A >= 0x2232 && T_A <= 0x2234)
 {
  const unsigned shift = ((T_A - 0x2232) & 0x3) << 3;

  DMASourceAddr = (DMASourceAddr & ~(0xFF << shift)) | (V << shift);
 }
 else if(T_A >= 0x2235 && T_A <= 0x2237)
 {
  const unsigned offs = (T_A - 0x2235) & 0x3;
  const unsigned shift = offs << 3;

  DMADestAddr = (DMADestAddr & ~(0xFF << shift)) | (V << shift);

  if(((DMAControl & 0xA0) == 0x80) && offs == (1 + (bool)(DMAControl & 0x4)))
  {
   DMA_RunNormal(timestamp);
  }
  else if(((DMAControl & 0xA0) == 0xA0) && offs == 1)
  {
   CharConvTileY = 0;
   if(DMAControl & 0x10)
   {
    DMACharConvAutoActive = true;
    DMACharConvSourceXTile = 0;
    DMACharConvSourceYTile = 0;
    DMACharConvCCVBWRAMCounter = 0;
    //DMA_RunCharConvIter();
    if(MainCPUIRQEnable & 0x20)
    {
     MainCPUIRQPending |= 0x20;
     CPU_SetIRQ(MainCPUIRQPending, CPU_IRQSOURCE_CART);
    }
   }
   //else
   // assert(0);
  }
 }
}

template<unsigned T_A>
static DEFWRITE(MainCPU_WriteIO)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 Update(CPUM.timestamp);
 //
 SNES_DBG("[SA1] IO Write 0x%06x 0x%02x\n", T_A, V);
 assert((A & 0xFFFF) == T_A);

 switch(T_A)
 {
  default:
	SNES_DBG("[SA1] Unknown Write: $%02x:%04x $%02x\n", A >> 16, A & 0xFFFF, V);
	break;

  case 0x2200:
/*
	// SA-1 CPU control
	Message[1] = V & 0xF;
	if(V & 0x10)
	{
	 SA1CPU::CPU_SetNMI(true);
	 SA1CPU::CPU_SetNMI(false);
	}

	if(V & 0x20)
	{
	 SA1CPU::CPU_Reset(false);
	}

	Wait = (bool)(V & 0x20);
*/
	{
	 const uint8 old_SA1CPUControl = SA1CPUControl;

	 if(V & SA1CPUIRQEnable & 0x10)
	 {
	  SA1CPUIRQPending |= 0x10;
	  SA1CPU::CPU_SetNMI(SA1CPUIRQPending & 0x10);
	 }

	 if(V & SA1CPUIRQEnable & 0x80)
	 {
	  SA1CPUIRQPending |= 0x80;
	  SA1CPU::CPU_SetIRQ(SA1CPUIRQPending & 0xE0);
	 }

	 SA1CPUControl = V;

	 if((old_SA1CPUControl ^ SA1CPUControl) & old_SA1CPUControl & 0x20)
	 {
	  SA1CPU::CPUM.halted = SA1CPU::CPU_Misc::HALTED_NOT;
	  SA1CPU::CPU_Reset(false);	// TODO: don't clear IRQ pending in 65816 core.
	  SA1CPU::CPU_SetIRQ(SA1CPUIRQPending & 0xE0);
	 }
	 else if(SA1CPUControl & 0x20)
	 {
	  SA1CPU::CPUM.halted = SA1CPU::CPU_Misc::HALTED_DMA;
	 }
	}
	break;

  case 0x2201:
	MainCPUIRQEnable = V & 0xA0;
	//MainCPUIRQPending &= ~MainCPUIRQEnable;
	break;

  case 0x2202:
	MainCPUIRQPending &= ~V;
	CPU_SetIRQ(MainCPUIRQPending, CPU_IRQSOURCE_CART);
	break;

  //
  // SA-1 CPU Vectors
  //
  case 0x2203:
  case 0x2204:
  case 0x2205:
  case 0x2206:
  case 0x2207:
  case 0x2208:
	{
	 static const size_t tl[6] = { /*Reset:*/ 0xFFEC, 0xFFED, /*NMI*/0xFFEA, 0xFFEB, /*IRQ*/0xFFEE, 0xFFEF };
         const size_t t = tl[T_A - 0x2203];

	 SA1VectorSpace[t & 0xF] = V;
	}
	break;

  case 0x2220:
  case 0x2221:
  case 0x2222:
  case 0x2223:
	ROMBank[T_A & 0x3] = V & 0x87;
	RecalcROMPtr(T_A & 0x3);
	break;

  case 0x2224:
	MainBWRAMBank = V & 0x1F;
	break;

  case 0x2226:
	BWRAMWriteEnable[0] = V >> 7;
	break;

  case 0x2228:
	BWRAMWriteProtectSize = V & 0xF;
	break;

  case 0x2229:
	IWRAMWriteEnable[0] = V;
	break;

  case 0x2231:
  case 0x2232:
  case 0x2233:
  case 0x2234:
  case 0x2235:
  case 0x2236:
  case 0x2237:
	WriteSharedDMAReg<T_A>(CPUM.timestamp, A, V);
	break;
 }
}

template<unsigned T_A>
static DEFREAD(MainCPU_ReadIO)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += MEMCYC_FAST;
  Update(CPUM.timestamp);
 }
 //
 uint8 ret = 0x00;

 SNES_DBG("[SA1] IO Read 0x%06x\n", A);
 assert((A & 0xFFFF) == T_A);
 switch(T_A)
 {
  default:
	SNES_DBG("[SA1CPU] Unknown Read: $%02x:%04x\n", A >> 16, A & 0xFFFF);
	break;

  case 0x2300:
	ret = MainCPUControl | MainCPUIRQPending;
	break;

  case 0x230E:
	ret = 0x23;
	break;
 }

 return ret;
}

template<unsigned w>
static DEFREAD(MainCPU_ReadVector)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += MEMCYC_SLOW;
 }
 //
 if(MainCPUControl & (w ? 0x40 : 0x10))
  return *(MainVectors + (w << 1) + (A & 1));

 return ReadROM(0, A);
}

static DEFREAD(SA1CPU_ReadVector)
{
 SA1CPU::CPUM.timestamp += 2;
 //
 uint8 ret = ReadROM(0, A);

 if(MDFN_UNLIKELY(A >= 0xFFE0))
 {
  if(SA1CPU::CPUM.VectorPull)
  {
   const size_t index = A & 0xF;
   ret = (ret & SA1VectorMask[index]) | SA1VectorSpace[index];
  }
 }

 return ret;
}

template<unsigned T_Region, bool SA1Side>
static DEFREAD(ReadROM)
{
 if(SA1Side)
  SA1CPU::CPUM.timestamp += 2;
 else
 {
  if(MDFN_LIKELY(!DBG_InHLRead))
  {
   CPUM.timestamp += (T_Region >= 2) ? CPUM.MemSelectCycles : MEMCYC_SLOW;
  }
 }
 //
 return ReadROM(T_Region, A);;
}

template<bool SA1Side>
static DEFREAD(ReadBWRAM_40_43)
{
 if(SA1Side)
  SA1CPU::CPUM.timestamp += 4;
 else
 {
  if(MDFN_LIKELY(!DBG_InHLRead))
  {
   CPUM.timestamp += MEMCYC_SLOW;
   //
   Update(CPUM.timestamp);
  }
 }
 //
 if(!SA1Side && DMACharConvAutoActive)
  return DMA_ReadCCVBWRAM();
 //
 return Cart.RAM[A & Cart.RAM_Mask];
}

template<bool SA1Side>
static DEFWRITE(WriteBWRAM_40_43)
{
 if(SA1Side)
  SA1CPU::CPUM.timestamp += 4;
 else
 {
  CPUM.timestamp += MEMCYC_SLOW;
  //
  Update(CPUM.timestamp);
 }
 //
 if(!BWRAMWriteEnable[SA1Side] && (A & 0x3FFFF) < (256U << BWRAMWriteProtectSize))
 {
  SNES_DBG("[SA1] %d, BWRAM write blocked; 0x%06x 0x%02x\n", SA1Side, A, V);
  //return;
 }

 //printf("SA1CPU BWRAM write %08x %02x\n", A, V);

 Cart.RAM[A & Cart.RAM_Mask] = V;
}

static DEFREAD(MainCPU_ReadBWRAM_Banked)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += MEMCYC_SLOW;
  //
  Update(CPUM.timestamp);
 }
 //
 return Cart.RAM[((A & 0x1FFF) + (MainBWRAMBank << 13)) & Cart.RAM_Mask];
}

static DEFWRITE(MainCPU_WriteBWRAM_Banked)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 Update(CPUM.timestamp);
 //
 //if(!BWRAMWriteEnable[0])
 //{
 // SNES_DBG("[SA1] BWRAM write blocked; 0x%06x 0x%02x\n", A, V);
 // return;
 //}

 Cart.RAM[((A & 0x1FFF) + (MainBWRAMBank << 13)) & Cart.RAM_Mask] = V;
}

static INLINE uint8 ReadBWBitmap(uint32 A)
{
 uint8 ret;

 if(BWRAMBitmapFormat)
 {
  ret = (Cart.RAM[(A >> 2) & Cart.RAM_Mask] >> ((A & 3) << 1)) & 0x3;
  //ret |= ret << 2;
  //ret |= ret << 4;
 }
 else
 {
  ret = (Cart.RAM[(A >> 1) & Cart.RAM_Mask] >> ((A & 1) << 2)) & 0xF;
  //ret ^= rand() & 0xF0;
 }

 return ret;
}


static INLINE void WriteBWBitmap(uint32 A, uint8 V)
{
 if(BWRAMBitmapFormat)	// 2-bit
 {
  //printf("Awesomewrite: %08x %02x --- %08x\n", A, V, (A >> 2) & Cart.RAM_Mask);
  const unsigned shift = (A & 3) << 1;
  uint8* const p = &Cart.RAM[(A >> 2) & Cart.RAM_Mask];

  *p = (*p & ~(0x3 << shift)) | ((V & 0x3) << shift);
 }
 else	// 4-bit
 {
  const unsigned shift = (A & 1) << 2;
  uint8* const p = &Cart.RAM[(A >> 1) & Cart.RAM_Mask];

  *p = (*p & (0xF0 >> shift)) | ((V & 0xF) << shift);
 }
}

static DEFREAD(SA1CPU_ReadBWRAM_Banked)
{
 SA1CPU::CPUM.timestamp += 4;
 //
 //if(SA1BWRAMBank & 0x80)
 // return rand();
 const size_t bwram_index = (A & 0x1FFF) + ((SA1BWRAMBank & 0x7F) << 13);

 if(SA1BWRAMBank & 0x80)
  return ReadBWBitmap(bwram_index);
 else
  return Cart.RAM[bwram_index & Cart.RAM_Mask];
}

static DEFWRITE(SA1CPU_WriteBWRAM_Banked)
{
 SA1CPU::CPUM.timestamp += 4;
 //
 //if(!BWRAMWriteEnable[1])
 //{
 // SNES_DBG("[SA1CPU] BWRAM write blocked; 0x%06x 0x%02x\n", A, V);
 // return;
 //}

 const size_t bwram_index = (A & 0x1FFF) + ((SA1BWRAMBank & 0x7F) << 13);

 //printf("MOO: %08x %zu %02x\n", A, bwram_index, V);

 //WriteBWBitmap(A, V);
 if(SA1BWRAMBank & 0x80)
  WriteBWBitmap(bwram_index, V);
 else
  Cart.RAM[bwram_index & Cart.RAM_Mask] = V;
}

static DEFREAD(SA1CPU_ReadBWRAM_Bitmap)
{
 SA1CPU::CPUM.timestamp += 4;
 //
 return ReadBWBitmap(A);
}

static DEFWRITE(SA1CPU_WriteBWRAM_Bitmap)
{
 SA1CPU::CPUM.timestamp += 4;
 //
 if(!BWRAMWriteEnable[1])
 {
  SNES_DBG("[SA1CPU] BWRAM write blocked; 0x%06x 0x%02x\n", A, V);
  return;
 }

 //printf("awesome BORP: %08x %02x\n", A, V);

 WriteBWBitmap(A, V);
}

static DEFWRITE(SA1CPU_OBWrite)
{
 SA1CPU::CPUM.timestamp += 2;
 //
 SNES_DBG("[SA1CPU] Unknown Write: $%02x:%04x $%02x\n", A >> 16, A & 0xFFFF, V);
}

static DEFREAD(SA1CPU_OBRead)
{
 SA1CPU::CPUM.timestamp += 2;
 //
 SNES_DBG("[SA1CPU] Unknown Read: $%02x:%04x\n", A >> 16, A & 0xFFFF);
 return CPUM.mdr;
}

static void VarLen_Start(void)
{
 VarLenCurBitOffs = 0;
 VarLenCurAddr = VarLenAddr;
 VarLenBuffer = 0;
 for(unsigned i = 0; i < 3; i++)
 {
  uint8 tmp = DMA_ReadROM(VarLenCurAddr & 0xFFFFFF);
  //printf("VARLEN Buffer: %02x\n", tmp);
  VarLenBuffer |= tmp << (i << 3);
  VarLenCurAddr++;
 }
}
static void VarLen_Advance(void)
{
 VarLenCurBitOffs += ((VarLenControl - 1) & 0xF) + 1;
 while(VarLenCurBitOffs >= 8)
 {
  VarLenCurBitOffs -= 8;
  VarLenBuffer >>= 8;
  uint8 tmp = DMA_ReadROM(VarLenCurAddr & 0xFFFFFF);
  //printf("VARLEN Buffer: %02x\n", tmp);
  VarLenBuffer |= tmp << 16;
  VarLenCurAddr++;
 }
}

template<unsigned T_A>
static DEFWRITE(SA1CPU_WriteIO)
{
 SA1CPU::CPUM.timestamp += 2;
 //
 SNES_DBG("[SA1CPU] IO Write 0x%06x 0x%02x\n", T_A, V);
 switch(T_A)
 {
  default:
	SNES_DBG("[SA1CPU] Unknown Write: $%02x:%04x $%02x\n", A >> 16, A & 0xFFFF, V);
	break;

  case 0x2209:
	{
	 //const uint8 old_MainCPUControl = MainCPUControl;

	 if(V & MainCPUIRQEnable & 0x80)
	 {
	  MainCPUIRQPending |= 0x80;
	  CPU_SetIRQ(MainCPUIRQPending, CPU_IRQSOURCE_CART);
	 }
	 MainCPUControl = V & 0x5F;
	}
	break;

  case 0x220A:
	SA1CPUIRQEnable = V & 0xF0;
	break;

  case 0x220B:
	SA1CPUIRQPending &= ~V;
	SA1CPU::CPU_SetNMI(SA1CPUIRQPending & 0x10);
	SA1CPU::CPU_SetIRQ(SA1CPUIRQPending & 0xE0);
	break;

  case 0x220C:
  case 0x220D:
  case 0x220E:
  case 0x220F:
	MainVectors[T_A & 0x3] = V;
	break;

  case 0x2225:
	SA1BWRAMBank = V;
	break;

  case 0x2227:
	BWRAMWriteEnable[1] = V >> 7;
	break;

  case 0x222A:
	IWRAMWriteEnable[1] = V;
	break;

  case 0x2230:
	DMAControl = V & 0xF7;
	//printf("CharConv DMAControl=%02x\n", DMAControl);
	break;

  case 0x2231:
  case 0x2232:
  case 0x2233:
  case 0x2234:
  case 0x2235:
  case 0x2236:
  case 0x2237:
	WriteSharedDMAReg<T_A>(SA1CPU::CPUM.timestamp, A, V);
	break;

  case 0x2238:
	DMALength = (DMALength & 0xFF00) | (V << 0);
	break;

  case 0x2239:
	DMALength = (DMALength & 0x00FF) | (V << 8);
	break;

  case 0x223F:
	BWRAMBitmapFormat = V >> 7;
	break;

  case 0x2240:
  case 0x2241:
  case 0x2242:
  case 0x2243:
  case 0x2244:
  case 0x2245:
  case 0x2246:
  case 0x2247:
  case 0x2248:
  case 0x2249:
  case 0x224A:
  case 0x224B:
  case 0x224C:
  case 0x224D:
  case 0x224E:
  case 0x224F:
	WriteCharConvBMReg(T_A & 0xF, V);
	break;

  case 0x2250:
	MathControl = V & 0x3;
	if(V & 2)
	 MathResult = 0;
	break;

  case 0x2251: MathParam[0] = (MathParam[0] & 0xFF00) | (V << 0); break;
  case 0x2252: MathParam[0] = (MathParam[0] & 0x00FF) | (V << 8); break;
  case 0x2253: MathParam[1] = (MathParam[1] & 0xFF00) | (V << 0); break;
  case 0x2254:
	MathParam[1] = (MathParam[1] & 0x00FF) | (V << 8);
	switch(MathControl)
	{
	 case 0:
		MathResult = (int16)MathParam[0] * (int16)MathParam[1];
		break;

	 case 1:
		if(!MathParam[1])
		 MathResult = 0;
		else
		{
		 uint16 a = (int16)MathParam[0] / (uint16)MathParam[1];
		 uint16 b = (int16)MathParam[0] % (uint16)MathParam[1];

		 MathResult = a | ((uint32)b << 16);
		}
		break;

	 case 2:
		MathResult = MathResult + (int16)MathParam[0] * (int16)MathParam[1];
		//if((int64)MathResult < 
		// TODO/FIXME: overflow
		break;

	 case 3:
		assert(0);
		break;

	}
	break;

  case 0x2258:
	//printf("VARLEN Write: %08x %02x\n", A, V);
	VarLenControl = V & 0x8F;
	VarLen_Advance();
	break;

  case 0x2259:
	//printf("VARLEN Write: %08x %02x\n", A, V);
	VarLenAddr = (VarLenAddr & 0xFFFF00) | (V << 0);
	break;

  case 0x225A:
	//printf("VARLEN Write: %08x %02x\n", A, V);
	VarLenAddr = (VarLenAddr & 0xFF00FF) | (V << 8);
	break;

  case 0x225B:
	//printf("VARLEN Write: %08x %02x\n", A, V);
	VarLenAddr = (VarLenAddr & 0x00FFFF) | (V << 16);
	VarLen_Start();
	break;

 }
}

template<unsigned T_A>
static DEFREAD(SA1CPU_ReadIO)
{
 SA1CPU::CPUM.timestamp += 2;
 //
 uint8 ret = 0x00;

 SNES_DBG("[SA1CPU] IO Read 0x%06x\n", A);
 switch(T_A)
 {
  default:
	SNES_DBG("[SA1CPU] Unknown Read: $%02x:%04x\n", A >> 16, A & 0xFFFF);
	break;

  case 0x2301:
	ret = (SA1CPUControl & 0x0F) | SA1CPUIRQPending;
	break;

  case 0x2306:
  case 0x2307:
  case 0x2308:
  case 0x2309:
  case 0x230A:
	ret = MathResult >> (((T_A - 0x2306) & 0x7) << 3);
	break;
  //	
  //
  case 0x230C:
	ret = VarLenBuffer >> VarLenCurBitOffs;
	//printf("VARLEN Read: %08x %02x\n", A, ret);
	break;

  case 0x230D:
	ret = VarLenBuffer >> (8 + VarLenCurBitOffs);
	if(VarLenControl & 0x80)
	 VarLen_Advance();

	//printf("VARLEN Read: %08x %02x\n", A, ret);
	break;

 }

 return ret;
}

static void Reset(bool powering_up)
{
 if(powering_up)
  SA1CPU::CPU_Reset(true);
 //
 //
 memset(SA1VectorSpace, 0, sizeof(SA1VectorSpace));
 memset(MainVectors, 0, sizeof(MainVectors));

 SA1CPUControl = 0x20;
 SA1CPU::CPUM.halted = SA1CPU::CPU_Misc::HALTED_DMA;
 SA1CPUIRQEnable = 0;
 SA1CPUIRQPending = 0;

 MainCPUControl = 0;
 MainCPUIRQEnable = 0;
 MainCPUIRQPending = 0;
 CPU_SetIRQ(MainCPUIRQPending, CPU_IRQSOURCE_CART);

 DMAControl = 0;
 DMACharConvParam = 0;
 DMASourceAddr = 0;
 DMADestAddr = 0;
 DMALength = 0;
 DMAFinishTS = 0x7FFFFFFF;

 DMACharConvAutoActive = false;
 DMACharConvSourceXTile = 0;
 DMACharConvSourceYTile = 0;
 DMACharConvCCVBWRAMCounter = 0;
 memset(CharConvBMRegs, 0, sizeof(CharConvBMRegs));
 CharConvTileY = 0;

 for(unsigned i = 0; i < 4; i++)
 {
  ROMBank[i] = i;
  RecalcROMPtr(i);
 }

 MainBWRAMBank = 0;
 SA1BWRAMBank = 0;
 for(unsigned i = 0; i < 2; i++)
 {
  BWRAMWriteEnable[i] = false;
  IWRAMWriteEnable[i] = 0x00;
 }
 BWRAMWriteProtectSize = 0;	// ?

 BWRAMBitmapFormat = 0;

 MathControl = 0;
 for(unsigned i = 0; i < 2; i++)
  MathParam[i] = 0;
 MathResult = 0;

 VarLenControl = 0;
 VarLenAddr = 0;
 VarLenCurAddr = 0;
 VarLenCurBitOffs = 0;
 VarLenBuffer = 0;

 if(powering_up)
  memset(IRAM, 0, sizeof(IRAM));
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SA1VectorSpace), // FIXME/TODO: cleaner
  SFVAR(MainVectors),

  SFVAR(SA1CPUControl),
  SFVAR(SA1CPUIRQEnable),
  SFVAR(SA1CPUIRQPending),

  SFVAR(MainCPUControl),
  SFVAR(MainCPUIRQEnable),
  SFVAR(MainCPUIRQPending),

  SFVAR(DMAControl),
  SFVAR(DMACharConvParam),
  SFVAR(DMASourceAddr),
  SFVAR(DMADestAddr),
  SFVAR(DMALength),
  SFVAR(DMAFinishTS),

  SFVAR(DMACharConvAutoActive),
  SFVAR(DMACharConvSourceXTile),
  SFVAR(DMACharConvSourceYTile),
  SFVAR(DMACharConvCCVBWRAMCounter),
  SFVAR(CharConvBMRegs),
  SFVAR(CharConvTileY),

  SFVAR(ROMBank),

  SFVAR(MainBWRAMBank),
  SFVAR(SA1BWRAMBank),
  SFVAR(BWRAMWriteEnable),
  SFVAR(BWRAMWriteProtectSize),
  SFVAR(IWRAMWriteEnable),

  SFVAR(BWRAMBitmapFormat),

//
  SFVAR(MathControl),
  SFVAR(MathParam),
  SFVAR(MathResult),

  SFVAR(VarLenControl),
  SFVAR(VarLenAddr),
  SFVAR(VarLenCurAddr),
  SFVAR(VarLenCurBitOffs),
  SFVAR(VarLenBuffer),

  SFVAR(IRAM),
//
  SFVAR(SA1CPU::CPUM.timestamp),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SA1");

 SA1CPU::CPU_StateAction(sm, load, data_only, "SA1CPU", "SA1CPUCORE");

 if(load)
 {
  for(unsigned w = 0; w < 4; w++)
   RecalcROMPtr(w);
 }
}


void CART_SA1_Init(const int32 master_clock)
{
 for(unsigned i = 0; i < 0x10; i++)
 {
  SA1VectorMask[i] = (i >= 0xA) ? 0x00 : 0xFF;
  SA1VectorSpace[i] = 0;
 }

 SA1CPU::CPU_Init(&SA1CPU::CPUM);
 SA1CPU::CPU_ClearRWFuncs();
 SA1CPU::CPU_SetRWHandlers(0x000000, 0xFFFFFF, SA1CPU_OBRead, SA1CPU_OBWrite);

 Set_A_Handlers((0x40 << 16) | 0x0000, (0x7D << 16) | 0xFFFF, OBRead_SLOW, OBWrite_SLOW);

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank >= 0x40 && bank <= 0x4F)
  {
   if(Cart.RAM_Mask != SIZE_MAX)
   {
    Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, ReadBWRAM_40_43<false>, WriteBWRAM_40_43<false>);
    SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, ReadBWRAM_40_43<true>, WriteBWRAM_40_43<true>);
   }
  }
  else if(!(bank & 0x40))
  {
   readfunc rf;
   readfunc sa1cpu_rf;

   if(bank < 0x20)
   {
    rf = ReadROM<0, false>;
    sa1cpu_rf = ReadROM<0, true>;
   }
   else if(bank < 0x40)
   {
    rf = ReadROM<1, false>;
    sa1cpu_rf = ReadROM<1, true>;
   }
   else if(bank < 0xA0)
   {
    rf = ReadROM<2, false>;
    sa1cpu_rf = ReadROM<2, true>;
   }
   else if(bank < 0xC0)
   {
    rf = ReadROM<3, false>;
    sa1cpu_rf = ReadROM<3, true>;
   }

   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, rf, (bank & 0x80) ? OBWrite_VAR : OBWrite_SLOW);
   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, sa1cpu_rf, SA1CPU_OBWrite);

   if(!bank)
   {
    for(unsigned i = 0; i < 4; i++)
    {
     const unsigned offs = (i & 1) + ((i & 2) << 3);
     Set_A_Handlers(0xFFEA + offs, MainCPU_ReadVector<0>, OBWrite_SLOW);
     Set_A_Handlers(0xFFEE + offs, MainCPU_ReadVector<1>, OBWrite_SLOW);
    }

    SA1CPU::CPU_SetRWHandlers(0xFE00, 0xFFFF, SA1CPU_ReadVector, SA1CPU_OBWrite);
   }
  }
  else if(bank >= 0xC0)
  {
   readfunc rf;
   readfunc sa1cpu_rf;

   if(bank < 0xD0)
   {
    rf = ReadROM<4, false>;
    sa1cpu_rf = ReadROM<4, true>;
   }
   else if(bank < 0xE0)
   {
    rf = ReadROM<5, false>;
    sa1cpu_rf = ReadROM<5, true>;
   }
   else if(bank < 0xF0)
   {
    rf = ReadROM<6, false>;
    sa1cpu_rf = ReadROM<6, true>;
   }
   else
   {
    rf = ReadROM<7, false>;
    sa1cpu_rf = ReadROM<7, true>;
   }

   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, rf, OBWrite_VAR);
   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, sa1cpu_rf, SA1CPU_OBWrite);
  }
  //
  //
  //
  if(bank >= 0x60 && bank <= 0x6F)
  {
   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, SA1CPU_ReadBWRAM_Bitmap, SA1CPU_WriteBWRAM_Bitmap);
  }

  //
  //
  //
  if(!(bank & 0x40))
  {
   Set_A_Handlers((bank << 16) | 0x3000, (bank << 16) | 0x37FF, ReadIRAM<false>, WriteIRAM<false>);
   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x3000, (bank << 16) | 0x37FF, ReadIRAM<true>, WriteIRAM<true>);
   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x0000, (bank << 16) | 0x07FF, ReadIRAM<true>, WriteIRAM<true>);

   if(Cart.RAM_Mask != SIZE_MAX)
   {
    Set_A_Handlers((bank << 16) | 0x6000, (bank << 16) | 0x7FFF, MainCPU_ReadBWRAM_Banked, MainCPU_WriteBWRAM_Banked);
    SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x6000, (bank << 16) | 0x7FFF, SA1CPU_ReadBWRAM_Banked, SA1CPU_WriteBWRAM_Banked);
   }

   SA1CPU::CPU_SetRWHandlers((bank << 16) | 0x2200, (bank << 16) | 0x23FF, SA1CPU_OBRead, SA1CPU_OBWrite, true);

   #define MHW(a) Set_A_Handlers((bank << 16) | a, OBRead_FAST, MainCPU_WriteIO<a>);
   MHW(0x2200)
   MHW(0x2201)
   MHW(0x2202)
   MHW(0x2203)
   MHW(0x2204)
   MHW(0x2205)
   MHW(0x2206)
   MHW(0x2207)
   MHW(0x2208)
   MHW(0x2220)
   MHW(0x2221)
   MHW(0x2222)
   MHW(0x2223)
   MHW(0x2224)
   MHW(0x2226)
   MHW(0x2228)
   MHW(0x2229)
   MHW(0x2231)
   MHW(0x2232)
   MHW(0x2233)
   MHW(0x2234)
   MHW(0x2235)
   MHW(0x2236)
   MHW(0x2237)
   #undef MHW

   #define MHR(a) Set_A_Handlers((bank << 16) | a, MainCPU_ReadIO<a>, OBWrite_FAST);
   MHR(0x2300)
   MHR(0x230E)
   #undef MHR

   #define SHW(a) SA1CPU::CPU_SetRWHandlers((bank << 16) | a, (bank << 16) | a, SA1CPU_OBRead, SA1CPU_WriteIO<a>, true);
   SHW(0x2209)
   SHW(0x220A)
   SHW(0x220B)
   SHW(0x220C)
   SHW(0x220D)
   SHW(0x220E)
   SHW(0x220F)
   SHW(0x2210)
   SHW(0x2211)
   SHW(0x2212)
   SHW(0x2213)
   SHW(0x2214)
   SHW(0x2215)
   SHW(0x2225)
   SHW(0x2227)
   SHW(0x222A)
   SHW(0x2230)
   SHW(0x2231)
   SHW(0x2232)
   SHW(0x2233)
   SHW(0x2234)
   SHW(0x2235)
   SHW(0x2236)
   SHW(0x2237)
   SHW(0x2238)
   SHW(0x2239)
   SHW(0x223F)
   SHW(0x2240)
   SHW(0x2241)
   SHW(0x2242)
   SHW(0x2243)
   SHW(0x2244)
   SHW(0x2245)
   SHW(0x2246)
   SHW(0x2247)
   SHW(0x2248)
   SHW(0x2249)
   SHW(0x224A)
   SHW(0x224B)
   SHW(0x224C)
   SHW(0x224D)
   SHW(0x224E)
   SHW(0x224F)
   SHW(0x2250)
   SHW(0x2251)
   SHW(0x2252)
   SHW(0x2253)
   SHW(0x2254)
   SHW(0x2258)
   SHW(0x2259)
   SHW(0x225A)
   SHW(0x225B)
   #undef SHW

   #define SHR(a) SA1CPU::CPU_SetRWHandlers((bank << 16) | a, (bank << 16) | a, SA1CPU_ReadIO<a>, SA1CPU_OBWrite, true);
   SHR(0x2301)
   SHR(0x2302)
   SHR(0x2303)
   SHR(0x2304)
   SHR(0x2305)
   SHR(0x2306)
   SHR(0x2307)
   SHR(0x2308)
   SHR(0x2309)
   SHR(0x230A)
   SHR(0x230B)
   SHR(0x230C)
   SHR(0x230D)
   #undef SHR
  }
 }
 //
 //
 //
 Cart.Reset = Reset;
 Cart.EventHandler = EventHandler;
 Cart.AdjustTS = AdjustTS;
 Cart.StateAction = StateAction;
}

}
