/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* superfx.cpp:
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

#pragma GCC optimize("O2")

/*
cat superfx.cpp | sed -E "s/OPCASE_3(.)_Xn\(0x(.)0\)/OPCASE_3\1\(0x\20): OPCASE_3\1\(0x\21): OPCASE_3\1\(0x\22): OPCASE_3\1\(0x\23): OPCASE_3\1\(0x\24): OPCASE_3\1\(0x\25): OPCASE_3\1\(0x\26): OPCASE_3\1\(0x\27): OPCASE_3\1\(0x\28): OPCASE_3\1\(0x\29): OPCASE_3\1\(0x\2A): OPCASE_3\1\(0x\2B): OPCASE_3\1\(0x\2C): OPCASE_3\1\(0x\2D): OPCASE_3\1\(0x\2E): OPCASE_3\1\(0x\2F)/" | sed -E "s/OPCASE_Xn\(0x(.)0\)/OPCASE(0x\10): OPCASE(0x\11): OPCASE(0x\12): OPCASE(0x\13): OPCASE(0x\14): OPCASE(0x\15): OPCASE(0x\16): OPCASE(0x\17): OPCASE(0x\18): OPCASE(0x\19): OPCASE(0x\1A): OPCASE(0x\1B): OPCASE(0x\1C): OPCASE(0x\1D): OPCASE(0x\1E): OPCASE(0x\1F)/" | sed -E "s/OPCASE_NP_Xn\(0x(.)0\)/OPCASE_NP(0x\10): OPCASE_NP(0x\11): OPCASE_NP(0x\12): OPCASE_NP(0x\13): OPCASE_NP(0x\14): OPCASE_NP(0x\15): OPCASE_NP(0x\16): OPCASE_NP(0x\17): OPCASE_NP(0x\18): OPCASE_NP(0x\19): OPCASE_NP(0x\1A): OPCASE_NP(0x\1B): OPCASE_NP(0x\1C): OPCASE_NP(0x\1D): OPCASE_NP(0x\1E): OPCASE_NP(0x\1F)/" > superfx-adj.cpp
*/


/*
 TODO:
	Correctly handle differences between MC1, GSU1, GSU2(especially in regards to memory maps).

	Correct timings(also clock source vs NTSC/PAL vs MC1/GSUn).

	Test multiplication performance when running from uncached ROM/RAM.

	Correct handling of Rd == 4 in FMULT and LMULT(run tests).

	Test SBK behavior when immediately after each of the various RAM access instructions.


*/

#include "common.h"
#include "superfx.h"

namespace MDFN_IEN_SNES_FAUST
{

static const unsigned tnoshtab_init[4] = { 4, 5, 6, 6 };
static const uint8 wtt_init[4] = { 2 * 3, 4 * 3, 8 * 3, 8 * 3};
static const unsigned masktab_init[4] = { 0x3, 0xF, 0xFF, 0xFF };

#if defined(ARCH_X86_32)
 #define SUPERFX_STATIC static
 #define SUPERFX_SVAR(v) std::remove_reference<decltype(SuperFX::v)>::type SuperFX::v;
#else
 #define SUPERFX_STATIC
 #define SUPERFX_SVAR(v)
#endif

static struct SuperFX
{
 SUPERFX_STATIC uint16 R[16 + 1];
 SUPERFX_STATIC size_t PrefixSL8;	// 0, 1, 2, 3; << 8
 SUPERFX_STATIC uint8 Prefetch;
 SUPERFX_STATIC bool PrefixB;

 SUPERFX_STATIC uint8 Rs;
 SUPERFX_STATIC uint8 Rd;

 SUPERFX_STATIC const uint8* PBR_Ptr;
 SUPERFX_STATIC size_t PBR_Ptr_Mask;
 SUPERFX_STATIC uint8* RAM;
 SUPERFX_STATIC size_t RAM_Mask;
 SUPERFX_STATIC uint16 CBR;
 SUPERFX_STATIC uint8 PBR;
 SUPERFX_STATIC uint8 ROMBR;
 SUPERFX_STATIC uint8 RAMBR;
 SUPERFX_STATIC uint8 VCR;
 SUPERFX_STATIC bool ClockSelect;
 SUPERFX_STATIC bool MultSpeed;

 SUPERFX_STATIC uint8 SCBR;
 SUPERFX_STATIC uint8 SCMR;
 SUPERFX_STATIC uint8 POR;
 SUPERFX_STATIC uint8 ColorData;

 SUPERFX_STATIC struct
 {
  uint8 TagX;
  uint8 TagY;
  uint8 data[8];
  uint8 opaque;
 } PixelCache;
 //
 //
 //
 SUPERFX_STATIC uint16 LastRAMOffset;
 SUPERFX_STATIC uint8 ROMBuffer;

 SUPERFX_STATIC bool FlagV, FlagS, FlagC, FlagZ;
 SUPERFX_STATIC bool Running;
 SUPERFX_STATIC bool IRQPending;
 SUPERFX_STATIC bool IRQMask;

 SUPERFX_STATIC uint8 GPRWriteLatch;

 SUPERFX_STATIC uint32 superfx_timestamp;
 SUPERFX_STATIC uint32 rom_read_finish_ts;
 SUPERFX_STATIC uint32 ram_write_finish_ts;
 SUPERFX_STATIC uint32 pixcache_write_finish_ts;

 SUPERFX_STATIC uint32 cycles_per_op;
 SUPERFX_STATIC uint32 cycles_per_rom_read;
 SUPERFX_STATIC uint32 cycles_per_ram;
 SUPERFX_STATIC uint32 cycles_per_8x8mult;
 SUPERFX_STATIC uint32 cycles_per_16x16mult;

 SUPERFX_STATIC const uint8* ProgMemMap[0x80];
 SUPERFX_STATIC size_t ProgMemMapMask[0x80];

 //
 //
 //
 SUPERFX_STATIC unsigned tnoshtab[4]; 
 SUPERFX_STATIC uint8 wtt[4];
 SUPERFX_STATIC unsigned masktab[4];
 //
 //
 //
 SUPERFX_STATIC bool CacheValid[0x20];
 SUPERFX_STATIC uint8 CacheData[0x200];
 //
 //
 //
 SUPERFX_STATIC uint32 last_master_timestamp;
 SUPERFX_STATIC uint32 run_count_mod;
 SUPERFX_STATIC uint32 clock_multiplier;
 SUPERFX_STATIC uint32 superfx_timestamp_run_until;
 SUPERFX_STATIC bool EnableICache;	// For save states
 //
 //
 //
 SUPERFX_STATIC void RecalcMultTiming(void);
 SUPERFX_STATIC void SetCFGR(uint8 val);
 SUPERFX_STATIC void SetCLSR(uint8 val);
 SUPERFX_STATIC void SetPBR(uint8 val);
 SUPERFX_STATIC void DoROMRead(void);
 SUPERFX_STATIC uint8 GetROMBuffer(void);
 SUPERFX_STATIC void WriteR(size_t w, uint16 val);
 SUPERFX_STATIC uint16 ReadR(size_t w);
 SUPERFX_STATIC void CMODE(void);
 SUPERFX_STATIC void WriteColorData(uint8 tmp);
 SUPERFX_STATIC void COLOR(void);
 SUPERFX_STATIC void GETC(void);
 SUPERFX_STATIC void CalcSZ(uint16 v);
 SUPERFX_STATIC unsigned CalcTNO(unsigned x, unsigned y);
 SUPERFX_STATIC void FlushPixelCache(void);

 SUPERFX_STATIC void PLOT(void);
 SUPERFX_STATIC void RPIX(void);
 SUPERFX_STATIC void STOP(void);
 template<bool EnableCache> SUPERFX_STATIC void SetCBR(uint16 val);
 template<bool EnableCache> SUPERFX_STATIC void CACHE(void);
 SUPERFX_STATIC void ADD(uint16 arg);
 SUPERFX_STATIC void ADC(uint16 arg);
 SUPERFX_STATIC void SUB(uint16 arg);
 SUPERFX_STATIC void SBC(uint16 arg);
 SUPERFX_STATIC void CMP(uint16 arg);
 SUPERFX_STATIC void AND(uint16 arg);
 SUPERFX_STATIC void BIC(uint16 arg);
 SUPERFX_STATIC void OR(uint16 arg);
 SUPERFX_STATIC void XOR(uint16 arg);
 SUPERFX_STATIC void NOT(void);
 SUPERFX_STATIC void LSR(void);
 SUPERFX_STATIC void ASR(void);
 SUPERFX_STATIC void ROL(void);
 SUPERFX_STATIC void ROR(void);
 SUPERFX_STATIC void DIV2(void);
 SUPERFX_STATIC void INC(uint8 w);
 SUPERFX_STATIC void DEC(uint8 w);
 SUPERFX_STATIC void SWAP(void);
 SUPERFX_STATIC void SEX(void);
 SUPERFX_STATIC void LOB(void);
 SUPERFX_STATIC void HIB(void);
 SUPERFX_STATIC void MERGE(void);
 SUPERFX_STATIC void FMULT(void);
 SUPERFX_STATIC void LMULT(void);
 SUPERFX_STATIC void MULT(uint16 arg);
 SUPERFX_STATIC void UMULT(uint16 arg);
 SUPERFX_STATIC void JMP(uint8 Rn);
 template<bool EnableCache> SUPERFX_STATIC void LJMP(uint8 Rn);
 SUPERFX_STATIC void LOOP(void);
 SUPERFX_STATIC void LINK(uint8 arg);
 SUPERFX_STATIC MDFN_FASTCALL void ReadOp_Part2(void);
 SUPERFX_STATIC MDFN_FASTCALL void ReadOp_Part3(const size_t cvi, const uint16 addr);
 template<bool EnableCache> SUPERFX_STATIC uint8 ReadOp(void);
 template<bool EnableCache> SUPERFX_STATIC uint16 ReadOp16(void);
 template<bool EnableCache> SUPERFX_STATIC void RelBranch(bool cond);
 SUPERFX_STATIC uint8 ReadRAM8(uint16 offs);
 SUPERFX_STATIC uint16 ReadRAM16(uint16 offs);
 SUPERFX_STATIC void WriteRAM8(uint16 offs, uint8 val);
 SUPERFX_STATIC void WriteRAM16(uint16 offs, uint16 val);

 template<bool EnableCache> SUPERFX_STATIC MDFN_FASTCALL void Update(uint32 timestamp);
} SFX;

 SUPERFX_SVAR(R)
 SUPERFX_SVAR(PrefixSL8)	// 0, 1, 2, 3; << 8
 SUPERFX_SVAR(Prefetch)
 SUPERFX_SVAR(PrefixB)

 SUPERFX_SVAR(Rs)
 SUPERFX_SVAR(Rd)

 SUPERFX_SVAR(PBR_Ptr)
 SUPERFX_SVAR(PBR_Ptr_Mask)
 SUPERFX_SVAR(RAM)
 SUPERFX_SVAR(RAM_Mask)
 SUPERFX_SVAR(CBR)
 SUPERFX_SVAR(PBR)
 SUPERFX_SVAR(ROMBR)
 SUPERFX_SVAR(RAMBR)
 SUPERFX_SVAR(VCR)
 SUPERFX_SVAR(ClockSelect)
 SUPERFX_SVAR(MultSpeed)

 SUPERFX_SVAR(SCBR)
 SUPERFX_SVAR(SCMR)
 SUPERFX_SVAR(POR)
 SUPERFX_SVAR(ColorData)

 SUPERFX_SVAR(PixelCache)
 //
 //
 //
 SUPERFX_SVAR(LastRAMOffset)
 SUPERFX_SVAR(ROMBuffer)

 SUPERFX_SVAR(FlagV)
 SUPERFX_SVAR(FlagS)
 SUPERFX_SVAR(FlagC)
 SUPERFX_SVAR(FlagZ)
 SUPERFX_SVAR(Running)
 SUPERFX_SVAR(IRQPending)
 SUPERFX_SVAR(IRQMask)

 SUPERFX_SVAR(GPRWriteLatch)

 SUPERFX_SVAR(superfx_timestamp)
 SUPERFX_SVAR(rom_read_finish_ts)
 SUPERFX_SVAR(ram_write_finish_ts)
 SUPERFX_SVAR(pixcache_write_finish_ts)

 SUPERFX_SVAR(cycles_per_op)
 SUPERFX_SVAR(cycles_per_rom_read)
 SUPERFX_SVAR(cycles_per_ram)
 SUPERFX_SVAR(cycles_per_8x8mult)
 SUPERFX_SVAR(cycles_per_16x16mult)

 SUPERFX_SVAR(ProgMemMap)
 SUPERFX_SVAR(ProgMemMapMask)

 SUPERFX_SVAR(tnoshtab)
 SUPERFX_SVAR(wtt)
 SUPERFX_SVAR(masktab)
 //
 //
 //
 SUPERFX_SVAR(CacheValid)
 SUPERFX_SVAR(CacheData)
 //
 //
 //
 SUPERFX_SVAR(last_master_timestamp)
 SUPERFX_SVAR(run_count_mod)
 SUPERFX_SVAR(clock_multiplier)
 SUPERFX_SVAR(superfx_timestamp_run_until)
 SUPERFX_SVAR(EnableICache)
#undef SUPERFX_STATIC
#undef SUPERFX_SVAR
//
//
//
void SuperFX::RecalcMultTiming(void)
{
 SNES_DBG("[SuperFX] Clock speed: %d, mult speed: %d\n", ClockSelect, MultSpeed);

 // FIXME: timings
 if(ClockSelect | MultSpeed)
 {
  cycles_per_16x16mult = 6;
  cycles_per_8x8mult = 0;
 }
 else
 {
  cycles_per_16x16mult = 14;
  cycles_per_8x8mult = 2;
 }
}

INLINE void SuperFX::SetCFGR(uint8 val)
{
 MultSpeed = (val >> 5) & 1;
 IRQMask = val >> 7;
 CPU_SetIRQ(IRQPending & !IRQMask, CPU_IRQSOURCE_CART);
 //
 RecalcMultTiming();
}

INLINE void SuperFX::SetCLSR(uint8 val)
{
 ClockSelect = val & 0x1;
 //
 if(ClockSelect)
 {
  cycles_per_op = 1;
  cycles_per_rom_read = 5;
  cycles_per_ram = 3;
 }
 else
 {
  cycles_per_op = 2;
  cycles_per_rom_read = 6;
  cycles_per_ram = 3;
 }
 //
 RecalcMultTiming();
}

INLINE void SuperFX::SetPBR(uint8 val)
{
 PBR = val;
 PBR_Ptr = ProgMemMap[val & 0x7F];
 PBR_Ptr_Mask = ProgMemMapMask[val & 0x7F];
}

void SuperFX::DoROMRead(void)
{
 if(superfx_timestamp < rom_read_finish_ts)
 {
  //printf("DoROMRead() delay: %d\n", rom_read_finish_ts - superfx_timestamp);
 }
 superfx_timestamp = std::max<uint32>(superfx_timestamp, rom_read_finish_ts);
 ROMBuffer = ProgMemMap[ROMBR & 0x7F][R[14] & ProgMemMapMask[ROMBR & 0x7F]];
 rom_read_finish_ts = superfx_timestamp + cycles_per_rom_read;
}

INLINE uint8 SuperFX::GetROMBuffer(void)
{
 if(superfx_timestamp < rom_read_finish_ts)
 {
  //printf("GetROMBuffer() delay: %d\n", rom_read_finish_ts - superfx_timestamp);
 }
 superfx_timestamp = std::max<uint32>(superfx_timestamp, rom_read_finish_ts);

 return ROMBuffer;
}

INLINE void SuperFX::WriteR(size_t w, uint16 val)
{
 R[w] = val;

 if(w == 14)
  DoROMRead();
}

// Only needed to be used when reg might == 15
INLINE uint16 SuperFX::ReadR(size_t w)
{
 return R[w + (w == 15)];
}

INLINE void SuperFX::CMODE(void)
{
 POR = ReadR(Rs) & 0x1F;
}

INLINE void SuperFX::WriteColorData(uint8 tmp)
{
 tmp = (tmp & 0xF0) + ((tmp >> (POR & 0x4)) & 0x0F);

 if(POR & 0x8)
  tmp = (ColorData & 0xF0) + (tmp & 0x0F);

 ColorData = tmp;
}

INLINE void SuperFX::COLOR(void)
{
 WriteColorData(ReadR(Rs));
}

INLINE void SuperFX::GETC(void)
{
 uint8 tmp = GetROMBuffer();

 WriteColorData(tmp);
}

INLINE void SuperFX::CalcSZ(uint16 v)
{
 FlagS = v >> 15;
 FlagZ = !v;
}

INLINE unsigned SuperFX::CalcTNO(unsigned x, unsigned y)
{
 unsigned tno;
 const unsigned shs = ((SCMR >> 2) & 0x1) | ((SCMR >> 4) & 0x2);

 if(shs == 0x3 || (POR & 0x10))
 {
  tno = ((y >> 7) << 9) + ((x >> 7) << 8) + (((y >> 3) & 0xF) << 4) + ((x >> 3) & 0xF);
 }
 else switch(shs)
 {
  case 0: tno = (x >> 3) * 0x10 + (y >> 3); break;
  case 1: tno = (x >> 3) * 0x14 + (y >> 3); break;
  case 2: tno = (x >> 3) * 0x18 + (y >> 3); break;
 }

 tno &= 0x3FF;

 return tno;
}

void SuperFX::FlushPixelCache(void)
{
 if(!PixelCache.opaque) // FIXME: correct?
  return;

 superfx_timestamp = std::max<int64>(superfx_timestamp, pixcache_write_finish_ts);
 pixcache_write_finish_ts = std::max<int64>(superfx_timestamp, ram_write_finish_ts);
 //
 //
 //
 const unsigned bpp = SCMR & 0x3;
 const unsigned x = PixelCache.TagX;
 const unsigned y = PixelCache.TagY;
 const unsigned finey = y & 7;
 unsigned tno = CalcTNO(x, y);
 unsigned tra = (tno << tnoshtab[bpp]) + (SCBR << 10) + (finey << 1);
 uint8* p = &RAM[tra & RAM_Mask];

 if(PixelCache.opaque != 0xFF)
 {
  // FIXME: time
  pixcache_write_finish_ts += wtt[bpp];
 }
 //
 //
 //
 {
  const unsigned mask = ~PixelCache.opaque;

  p[0x00] &= mask;
  p[0x01] &= mask;
  if(bpp >= 1)
  {
   p[0x10] &= mask;
   p[0x11] &= mask;

   if(bpp >= 2)
   {
    p[0x20] &= mask;
    p[0x21] &= mask;
    p[0x30] &= mask;
    p[0x31] &= mask;
   }
  }
 }
 //
 //
 //
 for(int i = 0; i < 8; i++)
 {
  if(PixelCache.opaque & 0x01)
  {
   const unsigned color = PixelCache.data[i];

   p[0x00] |= ((color >> 0) & 1) << i;
   p[0x01] |= ((color >> 1) & 1) << i;
   if(bpp >= 1)
   {
    p[0x10] |= ((color >> 2) & 1) << i;
    p[0x11] |= ((color >> 3) & 1) << i;

    if(bpp >= 2)
    {
     p[0x20] |= ((color >> 4) & 1) << i;
     p[0x21] |= ((color >> 5) & 1) << i;
     p[0x30] |= ((color >> 6) & 1) << i;
     p[0x31] |= ((color >> 7) & 1) << i;
    }
   }
  }
  //
  PixelCache.opaque >>= 1;
 }
 // FIXME: time
 pixcache_write_finish_ts += wtt[bpp];
 //
 //
 //
 ram_write_finish_ts = pixcache_write_finish_ts;
}

INLINE void SuperFX::PLOT(void)
{
 const unsigned x = (uint8)R[1];
 const unsigned y = (uint8)R[2];

 if(PixelCache.TagX != (x & 0xF8) || PixelCache.TagY != y)
 {
  FlushPixelCache();
  PixelCache.TagX = x & 0xF8;
  PixelCache.TagY = y;
 }

 const unsigned finex = x & 7;
 const unsigned bpp = SCMR & 0x3;

 uint8 color = ColorData;
 bool visible = true;
 //
 color >>= ((((x ^ y) & 1) << 1) & POR & ~bpp) << 1;
 if(!(POR & 0x1))
 {
  if(!(color & masktab[bpp] & ((POR & 8) ? 0xF : 0xFF)))
   visible = false;
 }

 PixelCache.data[7 - finex] = color;
 PixelCache.opaque |= visible << (7 - finex);

 if(PixelCache.opaque == 0xFF)	// Set to 1, or set?
  FlushPixelCache();
 //
 WriteR(1, R[1] + 1);
}

INLINE void SuperFX::RPIX(void)
{
 FlushPixelCache();
 //
 //
 //
 const unsigned x = (uint8)R[1];
 const unsigned y = (uint8)R[2];
 const unsigned finex = x & 7;
 const unsigned finey = y & 7;
 unsigned tno = CalcTNO(x, y);
 unsigned tra;

 const unsigned bpp = SCMR & 0x3;

 tra = (tno << tnoshtab[bpp]) + (SCBR << 10) + (finey << 1);
 uint8* p = &RAM[tra & RAM_Mask];
 uint8 color = 0;
 const unsigned shift = 7 - finex;

 color |= ((p[0x00] >> shift) & 1) << 0;
 color |= ((p[0x01] >> shift) & 1) << 1;
 if(bpp >= 1)
 {
  color |= ((p[0x10] >> shift) & 1) << 2;
  color |= ((p[0x11] >> shift) & 1) << 3;

  if(bpp >= 2)
  {
   color |= ((p[0x20] >> shift) & 1) << 4;
   color |= ((p[0x21] >> shift) & 1) << 5;
   color |= ((p[0x30] >> shift) & 1) << 6;
   color |= ((p[0x31] >> shift) & 1) << 7;
  }
 }

 CalcSZ(color); // FIXME?
 WriteR(Rd, color);
}

INLINE void SuperFX::STOP(void)
{
 Running = false;
 IRQPending = true;
 //CPU_SetIRQ(IRQPending & !IRQMask, CPU_IRQSOURCE_CART);
}

template<bool EnableCache>
INLINE void SuperFX::SetCBR(uint16 val)
{
 CBR = val;
 if(EnableCache)
  memset(CacheValid, 0, sizeof(CacheValid));
}

template<bool EnableCache>
INLINE void SuperFX::CACHE(void)
{
 SetCBR<EnableCache>(ReadR(15) & 0xFFF0);
}

INLINE void SuperFX::ADD(uint16 arg)
{
 const uint32 tmp = ReadR(Rs) + arg;

 FlagV = (int16)((ReadR(Rs) ^ ~arg) & (ReadR(Rs) ^ tmp)) < 0;
 FlagC = tmp >> 16;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::ADC(uint16 arg)
{
 const uint32 tmp = ReadR(Rs) + arg + FlagC;

 FlagV = (int16)((ReadR(Rs) ^ ~arg) & (ReadR(Rs) ^ tmp)) < 0;
 FlagC = tmp >> 16;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::SUB(uint16 arg)
{
 const uint32 tmp = ReadR(Rs) - arg;

 FlagV = (int16)((ReadR(Rs) ^ arg) & (ReadR(Rs) ^ tmp)) < 0;
 FlagC = ((tmp >> 16) ^ 1) & 1;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::SBC(uint16 arg)
{
 const uint32 tmp = ReadR(Rs) - arg - !FlagC;

 FlagV = (int16)((ReadR(Rs) ^ arg) & (ReadR(Rs) ^ tmp)) < 0;
 FlagC = ((tmp >> 16) ^ 1) & 1;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::CMP(uint16 arg)
{
 const uint32 tmp = ReadR(Rs) - arg;

 FlagV = (int16)((ReadR(Rs) ^ arg) & (ReadR(Rs) ^ tmp)) < 0;
 FlagC = ((tmp >> 16) ^ 1) & 1;
 CalcSZ(tmp);
}

INLINE void SuperFX::AND(uint16 arg)
{
 const uint16 tmp = ReadR(Rs) & arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::BIC(uint16 arg)
{
 const uint16 tmp = ReadR(Rs) & ~arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::OR(uint16 arg)
{
 const uint16 tmp = ReadR(Rs) | arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::XOR(uint16 arg)
{
 const uint16 tmp = ReadR(Rs) ^ arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::NOT(void)
{
 const uint16 tmp = ~ReadR(Rs);

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::LSR(void)
{
 const uint16 tmp = ReadR(Rs) >> 1;

 FlagC = ReadR(Rs) & 1;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::ASR(void)
{
 const uint16 tmp = (int16)ReadR(Rs) >> 1;

 FlagC = ReadR(Rs) & 1;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::ROL(void)
{
 const bool NewFlagC = ReadR(Rs) >> 15;
 const uint16 tmp = (ReadR(Rs) << 1) | FlagC;

 FlagC = NewFlagC;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::ROR(void)
{
 const bool NewFlagC = ReadR(Rs) & 1;
 const uint16 tmp = (ReadR(Rs) >> 1) | (FlagC << 15);

 FlagC = NewFlagC;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::DIV2(void)
{
 //const uint16 tmp = ((int16)ReadR(Rs) + (ReadR(Rs) >> 15)) >> 1;
 uint16 tmp = ((int16)ReadR(Rs) >> 1); // + (ReadR(Rs) == 0xFFFF);

 if(tmp == 0xFFFF)
  tmp = 0;

 FlagC = ReadR(Rs) & 1;
 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::INC(uint8 w)
{
 const uint16 tmp = R[w] + 1;

 CalcSZ(tmp);

 WriteR(w, tmp);
}

INLINE void SuperFX::DEC(uint8 w)
{
 const uint16 tmp = R[w] - 1;

 CalcSZ(tmp);

 WriteR(w, tmp);
}

INLINE void SuperFX::SWAP(void)
{
 const uint16 tmp = (ReadR(Rs) >> 8) | (ReadR(Rs) << 8);

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::SEX(void)
{
 const uint16 tmp = (int8)ReadR(Rs);

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::LOB(void)
{
 const uint16 tmp = (uint8)ReadR(Rs);

 FlagS = tmp >> 7;
 FlagZ = !tmp;

 WriteR(Rd, tmp);
}

INLINE void SuperFX::HIB(void)
{
 const uint16 tmp = ReadR(Rs) >> 8;

 FlagS = ReadR(Rs) >> 15;
 FlagZ = !tmp;

 WriteR(Rd, tmp);
}

INLINE void SuperFX::MERGE(void)
{
 const uint16 tmp = (R[7] & 0xFF00) + (R[8] >> 8);

 FlagS = (bool)(tmp & 0x8080);
 FlagV = (bool)(tmp & 0xC0C0);
 FlagC = (bool)(tmp & 0xE0E0);
 FlagZ = (bool)(tmp & 0xF0F0);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::FMULT(void)
{
 superfx_timestamp += cycles_per_16x16mult;
 //
 if(Rd == 4)
  SNES_DBG("[SuperFX] FMULT with Rd=4\n");

 const uint32 tmp = (int16)ReadR(Rs) * (int16)R[6];

 // FIXME?
 FlagS = tmp >> 31;
 FlagZ = !tmp;
 FlagC = (tmp >> 15) & 1;

 WriteR(Rd, tmp >> 16);
}

INLINE void SuperFX::LMULT(void)
{
 superfx_timestamp += cycles_per_16x16mult;
 //
 if(Rd == 4)
  SNES_DBG("[SuperFX] LMULT with Rd=4\n");

 const uint32 tmp = (int16)ReadR(Rs) * (int16)R[6];

 // FIXME?
 FlagS = tmp >> 31;
 FlagZ = !tmp;
 FlagC = (tmp >> 15) & 1;

 WriteR(Rd, tmp >> 16);
 WriteR(4, tmp);
}

INLINE void SuperFX::MULT(uint16 arg)
{
 superfx_timestamp += cycles_per_8x8mult;
 //
 const uint16 tmp = (int8)ReadR(Rs) * (int8)arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}

INLINE void SuperFX::UMULT(uint16 arg)
{
 superfx_timestamp += cycles_per_8x8mult;
 //
 const uint16 tmp = (uint8)ReadR(Rs) * (uint8)arg;

 CalcSZ(tmp);

 WriteR(Rd, tmp);
}
//
//
//
INLINE void SuperFX::JMP(uint8 Rn)
{
 WriteR(15, R[Rn]);
}

template<bool EnableCache>
INLINE void SuperFX::LJMP(uint8 Rn)
{
 const uint16 target = ReadR(Rs);

 WriteR(15, target);
 SetPBR(R[Rn]);
 SetCBR<EnableCache>(target & 0xFFF0);
}

INLINE void SuperFX::LOOP(void)
{
 const uint16 result = R[12] - 1;

 CalcSZ(result);
 WriteR(12, result);

 if(!FlagZ)
  WriteR(15, R[13]);
}

INLINE void SuperFX::LINK(uint8 arg)
{
 WriteR(11, ReadR(15) + arg);
}
//
//
//
NO_INLINE void SuperFX::ReadOp_Part2(void)
{
 if(MDFN_LIKELY((PBR & 0x7F) < 0x60))
 {
  superfx_timestamp = std::max<uint32>(superfx_timestamp, rom_read_finish_ts);
  superfx_timestamp += cycles_per_rom_read;
 }
 else
 {
  superfx_timestamp = std::max<uint32>(superfx_timestamp, ram_write_finish_ts);
  superfx_timestamp += 3;
 }
}

NO_INLINE void SuperFX::ReadOp_Part3(const size_t cvi, const uint16 addr)
{
 uint8* d = &CacheData[cvi << 4];

 CacheValid[cvi] = true;

 if(MDFN_LIKELY((PBR & 0x7F) < 0x60))
 {
  superfx_timestamp = std::max<uint32>(superfx_timestamp, rom_read_finish_ts);
  rom_read_finish_ts = superfx_timestamp;
 }

 for(unsigned i = 0; i < 0x10; i++)
 {
  const uint32 ra = (addr & 0xFFF0) + i;
  if(MDFN_LIKELY((PBR & 0x7F) < 0x60))
  {
   rom_read_finish_ts += cycles_per_rom_read;

   if(ra == addr)
    superfx_timestamp = rom_read_finish_ts;
  }

  d[i] = PBR_Ptr[ra & PBR_Ptr_Mask];
 }
}

template<bool EnableCache>
INLINE uint8 SuperFX::ReadOp(void)
{
 const uint16 addr = R[15];
 uint8 ret = Prefetch;

 Prefetch = PBR_Ptr[addr & PBR_Ptr_Mask];
 size_t cindex = addr - CBR;
 if(MDFN_UNLIKELY(cindex >= 0x200))
  ReadOp_Part2();
 else if(EnableCache)
 {
  const size_t cvi = cindex >> 4;

  if(MDFN_UNLIKELY(!CacheValid[cvi]))
   ReadOp_Part3(cvi, addr);

  Prefetch = CacheData[cindex];
 }

 R[16] = R[15];
 R[15]++;
 superfx_timestamp += cycles_per_op;

 return ret;
}

template<bool EnableCache>
uint16 SuperFX::ReadOp16(void)
{
 uint16 ret;

 ret  = ReadOp<EnableCache>();
 ret |= ReadOp<EnableCache>() << 8;

 return ret;
}

template<bool EnableCache>
INLINE void SuperFX::RelBranch(bool cond)
{
 int8 disp = ReadOp<EnableCache>();

 if(cond)
  WriteR(15, ReadR(15) + disp);
}

INLINE uint8 SuperFX::ReadRAM8(uint16 offs)
{
 superfx_timestamp = std::max<uint32>(superfx_timestamp, ram_write_finish_ts);
 superfx_timestamp += 4; // FIXME
 //
 //
 uint8 ret;

 //LastRAMOffset = offs;

 ret = RAM[((RAMBR << 16) + offs) & RAM_Mask];

 return ret;
}

INLINE uint16 SuperFX::ReadRAM16(uint16 offs)
{
 superfx_timestamp = std::max<uint32>(superfx_timestamp, ram_write_finish_ts);
 superfx_timestamp += 6; // FIXME
 //
 //
 uint16 ret;

// assert(!(offs & 1));

 //LastRAMOffset = offs;

 ret  = RAM[((RAMBR << 16) + (offs ^ 0)) & RAM_Mask] << 0;
 ret |= RAM[((RAMBR << 16) + (offs ^ 1)) & RAM_Mask] << 8;

 return ret;
}

INLINE void SuperFX::WriteRAM8(uint16 offs, uint8 val)
{
 superfx_timestamp = std::max<uint32>(superfx_timestamp, ram_write_finish_ts);
 ram_write_finish_ts = superfx_timestamp + 3; // FIXME
 //
 //
 //LastRAMOffset = offs;

 RAM[((RAMBR << 16) + (offs ^ 0)) & RAM_Mask] = val;
}

INLINE void SuperFX::WriteRAM16(uint16 offs, uint16 val)
{
 superfx_timestamp = std::max<uint32>(superfx_timestamp, ram_write_finish_ts);
 //superfx_timestamp += whatever; // FIXME?
 ram_write_finish_ts = superfx_timestamp + 5; // FIXME
 //
 //
// assert(!(offs & 1));

 //LastRAMOffset = offs;

 RAM[((RAMBR << 16) + (offs ^ 0)) & RAM_Mask] = val >> 0;
 RAM[((RAMBR << 16) + (offs ^ 1)) & RAM_Mask] = val >> 8;
}

template<bool EnableCache>
NO_INLINE void SuperFX::Update(uint32 timestamp)
{
 if(MDFN_UNLIKELY(!Running))
  superfx_timestamp = timestamp;

 if((SCMR & 0x18) != 0x18)
  superfx_timestamp = timestamp;

 while(MDFN_LIKELY(superfx_timestamp < timestamp))
 {
  uint8 opcode;

  opcode = ReadOp<EnableCache>();

#if defined(__GNUC__) && defined(__arm__) && defined(__thumb2__)
  #define OPCASE_PFX(pfx, o) Op_##pfx##_##o
  const size_t cop = PrefixSL8 + opcode;

asm volatile goto("tbh [pc, %0, lsl #1]\n\t0:\n\t" : :"r"(cop) :"cc", "memory" : pseudo0);
pseudo0:asm volatile goto(".2byte (%l[Op_0_0x00]-0b)/2\n\t.2byte (%l[Op_0_0x01]-0b)/2\n\t.2byte (%l[Op_0_0x02]-0b)/2\n\t.2byte (%l[Op_0_0x03]-0b)/2\n\t.2byte (%l[Op_0_0x04]-0b)/2\n\t.2byte (%l[Op_0_0x05]-0b)/2\n\t.2byte (%l[Op_0_0x06]-0b)/2\n\t.2byte (%l[Op_0_0x07]-0b)/2\n\t.2byte (%l[Op_0_0x08]-0b)/2\n\t.2byte (%l[Op_0_0x09]-0b)/2\n\t.2byte (%l[Op_0_0x0A]-0b)/2\n\t.2byte (%l[Op_0_0x0B]-0b)/2\n\t.2byte (%l[Op_0_0x0C]-0b)/2\n\t.2byte (%l[Op_0_0x0D]-0b)/2\n\t.2byte (%l[Op_0_0x0E]-0b)/2\n\t.2byte (%l[Op_0_0x0F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x00,Op_0_0x01,Op_0_0x02,Op_0_0x03,Op_0_0x04,Op_0_0x05,Op_0_0x06,Op_0_0x07,Op_0_0x08,Op_0_0x09,Op_0_0x0A,Op_0_0x0B,Op_0_0x0C,Op_0_0x0D,Op_0_0x0E,Op_0_0x0F,pseudo1);
pseudo1:asm volatile goto(".2byte (%l[Op_0_0x10]-0b)/2\n\t.2byte (%l[Op_0_0x11]-0b)/2\n\t.2byte (%l[Op_0_0x12]-0b)/2\n\t.2byte (%l[Op_0_0x13]-0b)/2\n\t.2byte (%l[Op_0_0x14]-0b)/2\n\t.2byte (%l[Op_0_0x15]-0b)/2\n\t.2byte (%l[Op_0_0x16]-0b)/2\n\t.2byte (%l[Op_0_0x17]-0b)/2\n\t.2byte (%l[Op_0_0x18]-0b)/2\n\t.2byte (%l[Op_0_0x19]-0b)/2\n\t.2byte (%l[Op_0_0x1A]-0b)/2\n\t.2byte (%l[Op_0_0x1B]-0b)/2\n\t.2byte (%l[Op_0_0x1C]-0b)/2\n\t.2byte (%l[Op_0_0x1D]-0b)/2\n\t.2byte (%l[Op_0_0x1E]-0b)/2\n\t.2byte (%l[Op_0_0x1F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x10,Op_0_0x11,Op_0_0x12,Op_0_0x13,Op_0_0x14,Op_0_0x15,Op_0_0x16,Op_0_0x17,Op_0_0x18,Op_0_0x19,Op_0_0x1A,Op_0_0x1B,Op_0_0x1C,Op_0_0x1D,Op_0_0x1E,Op_0_0x1F,pseudo2);
pseudo2:asm volatile goto(".2byte (%l[Op_0_0x20]-0b)/2\n\t.2byte (%l[Op_0_0x21]-0b)/2\n\t.2byte (%l[Op_0_0x22]-0b)/2\n\t.2byte (%l[Op_0_0x23]-0b)/2\n\t.2byte (%l[Op_0_0x24]-0b)/2\n\t.2byte (%l[Op_0_0x25]-0b)/2\n\t.2byte (%l[Op_0_0x26]-0b)/2\n\t.2byte (%l[Op_0_0x27]-0b)/2\n\t.2byte (%l[Op_0_0x28]-0b)/2\n\t.2byte (%l[Op_0_0x29]-0b)/2\n\t.2byte (%l[Op_0_0x2A]-0b)/2\n\t.2byte (%l[Op_0_0x2B]-0b)/2\n\t.2byte (%l[Op_0_0x2C]-0b)/2\n\t.2byte (%l[Op_0_0x2D]-0b)/2\n\t.2byte (%l[Op_0_0x2E]-0b)/2\n\t.2byte (%l[Op_0_0x2F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x20,Op_0_0x21,Op_0_0x22,Op_0_0x23,Op_0_0x24,Op_0_0x25,Op_0_0x26,Op_0_0x27,Op_0_0x28,Op_0_0x29,Op_0_0x2A,Op_0_0x2B,Op_0_0x2C,Op_0_0x2D,Op_0_0x2E,Op_0_0x2F,pseudo3);
pseudo3:asm volatile goto(".2byte (%l[Op_0_0x30]-0b)/2\n\t.2byte (%l[Op_0_0x31]-0b)/2\n\t.2byte (%l[Op_0_0x32]-0b)/2\n\t.2byte (%l[Op_0_0x33]-0b)/2\n\t.2byte (%l[Op_0_0x34]-0b)/2\n\t.2byte (%l[Op_0_0x35]-0b)/2\n\t.2byte (%l[Op_0_0x36]-0b)/2\n\t.2byte (%l[Op_0_0x37]-0b)/2\n\t.2byte (%l[Op_0_0x38]-0b)/2\n\t.2byte (%l[Op_0_0x39]-0b)/2\n\t.2byte (%l[Op_0_0x3A]-0b)/2\n\t.2byte (%l[Op_0_0x3B]-0b)/2\n\t.2byte (%l[Op_0_0x3C]-0b)/2\n\t.2byte (%l[Op_0_0x3D]-0b)/2\n\t.2byte (%l[Op_0_0x3E]-0b)/2\n\t.2byte (%l[Op_0_0x3F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x30,Op_0_0x31,Op_0_0x32,Op_0_0x33,Op_0_0x34,Op_0_0x35,Op_0_0x36,Op_0_0x37,Op_0_0x38,Op_0_0x39,Op_0_0x3A,Op_0_0x3B,Op_0_0x3C,Op_0_0x3D,Op_0_0x3E,Op_0_0x3F,pseudo4);
pseudo4:asm volatile goto(".2byte (%l[Op_0_0x40]-0b)/2\n\t.2byte (%l[Op_0_0x41]-0b)/2\n\t.2byte (%l[Op_0_0x42]-0b)/2\n\t.2byte (%l[Op_0_0x43]-0b)/2\n\t.2byte (%l[Op_0_0x44]-0b)/2\n\t.2byte (%l[Op_0_0x45]-0b)/2\n\t.2byte (%l[Op_0_0x46]-0b)/2\n\t.2byte (%l[Op_0_0x47]-0b)/2\n\t.2byte (%l[Op_0_0x48]-0b)/2\n\t.2byte (%l[Op_0_0x49]-0b)/2\n\t.2byte (%l[Op_0_0x4A]-0b)/2\n\t.2byte (%l[Op_0_0x4B]-0b)/2\n\t.2byte (%l[Op_0_0x4C]-0b)/2\n\t.2byte (%l[Op_0_0x4D]-0b)/2\n\t.2byte (%l[Op_0_0x4E]-0b)/2\n\t.2byte (%l[Op_0_0x4F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x40,Op_0_0x41,Op_0_0x42,Op_0_0x43,Op_0_0x44,Op_0_0x45,Op_0_0x46,Op_0_0x47,Op_0_0x48,Op_0_0x49,Op_0_0x4A,Op_0_0x4B,Op_0_0x4C,Op_0_0x4D,Op_0_0x4E,Op_0_0x4F,pseudo5);
pseudo5:asm volatile goto(".2byte (%l[Op_0_0x50]-0b)/2\n\t.2byte (%l[Op_0_0x51]-0b)/2\n\t.2byte (%l[Op_0_0x52]-0b)/2\n\t.2byte (%l[Op_0_0x53]-0b)/2\n\t.2byte (%l[Op_0_0x54]-0b)/2\n\t.2byte (%l[Op_0_0x55]-0b)/2\n\t.2byte (%l[Op_0_0x56]-0b)/2\n\t.2byte (%l[Op_0_0x57]-0b)/2\n\t.2byte (%l[Op_0_0x58]-0b)/2\n\t.2byte (%l[Op_0_0x59]-0b)/2\n\t.2byte (%l[Op_0_0x5A]-0b)/2\n\t.2byte (%l[Op_0_0x5B]-0b)/2\n\t.2byte (%l[Op_0_0x5C]-0b)/2\n\t.2byte (%l[Op_0_0x5D]-0b)/2\n\t.2byte (%l[Op_0_0x5E]-0b)/2\n\t.2byte (%l[Op_0_0x5F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x50,Op_0_0x51,Op_0_0x52,Op_0_0x53,Op_0_0x54,Op_0_0x55,Op_0_0x56,Op_0_0x57,Op_0_0x58,Op_0_0x59,Op_0_0x5A,Op_0_0x5B,Op_0_0x5C,Op_0_0x5D,Op_0_0x5E,Op_0_0x5F,pseudo6);
pseudo6:asm volatile goto(".2byte (%l[Op_0_0x60]-0b)/2\n\t.2byte (%l[Op_0_0x61]-0b)/2\n\t.2byte (%l[Op_0_0x62]-0b)/2\n\t.2byte (%l[Op_0_0x63]-0b)/2\n\t.2byte (%l[Op_0_0x64]-0b)/2\n\t.2byte (%l[Op_0_0x65]-0b)/2\n\t.2byte (%l[Op_0_0x66]-0b)/2\n\t.2byte (%l[Op_0_0x67]-0b)/2\n\t.2byte (%l[Op_0_0x68]-0b)/2\n\t.2byte (%l[Op_0_0x69]-0b)/2\n\t.2byte (%l[Op_0_0x6A]-0b)/2\n\t.2byte (%l[Op_0_0x6B]-0b)/2\n\t.2byte (%l[Op_0_0x6C]-0b)/2\n\t.2byte (%l[Op_0_0x6D]-0b)/2\n\t.2byte (%l[Op_0_0x6E]-0b)/2\n\t.2byte (%l[Op_0_0x6F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x60,Op_0_0x61,Op_0_0x62,Op_0_0x63,Op_0_0x64,Op_0_0x65,Op_0_0x66,Op_0_0x67,Op_0_0x68,Op_0_0x69,Op_0_0x6A,Op_0_0x6B,Op_0_0x6C,Op_0_0x6D,Op_0_0x6E,Op_0_0x6F,pseudo7);
pseudo7:asm volatile goto(".2byte (%l[Op_0_0x70]-0b)/2\n\t.2byte (%l[Op_0_0x71]-0b)/2\n\t.2byte (%l[Op_0_0x72]-0b)/2\n\t.2byte (%l[Op_0_0x73]-0b)/2\n\t.2byte (%l[Op_0_0x74]-0b)/2\n\t.2byte (%l[Op_0_0x75]-0b)/2\n\t.2byte (%l[Op_0_0x76]-0b)/2\n\t.2byte (%l[Op_0_0x77]-0b)/2\n\t.2byte (%l[Op_0_0x78]-0b)/2\n\t.2byte (%l[Op_0_0x79]-0b)/2\n\t.2byte (%l[Op_0_0x7A]-0b)/2\n\t.2byte (%l[Op_0_0x7B]-0b)/2\n\t.2byte (%l[Op_0_0x7C]-0b)/2\n\t.2byte (%l[Op_0_0x7D]-0b)/2\n\t.2byte (%l[Op_0_0x7E]-0b)/2\n\t.2byte (%l[Op_0_0x7F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x70,Op_0_0x71,Op_0_0x72,Op_0_0x73,Op_0_0x74,Op_0_0x75,Op_0_0x76,Op_0_0x77,Op_0_0x78,Op_0_0x79,Op_0_0x7A,Op_0_0x7B,Op_0_0x7C,Op_0_0x7D,Op_0_0x7E,Op_0_0x7F,pseudo8);
pseudo8:asm volatile goto(".2byte (%l[Op_0_0x80]-0b)/2\n\t.2byte (%l[Op_0_0x81]-0b)/2\n\t.2byte (%l[Op_0_0x82]-0b)/2\n\t.2byte (%l[Op_0_0x83]-0b)/2\n\t.2byte (%l[Op_0_0x84]-0b)/2\n\t.2byte (%l[Op_0_0x85]-0b)/2\n\t.2byte (%l[Op_0_0x86]-0b)/2\n\t.2byte (%l[Op_0_0x87]-0b)/2\n\t.2byte (%l[Op_0_0x88]-0b)/2\n\t.2byte (%l[Op_0_0x89]-0b)/2\n\t.2byte (%l[Op_0_0x8A]-0b)/2\n\t.2byte (%l[Op_0_0x8B]-0b)/2\n\t.2byte (%l[Op_0_0x8C]-0b)/2\n\t.2byte (%l[Op_0_0x8D]-0b)/2\n\t.2byte (%l[Op_0_0x8E]-0b)/2\n\t.2byte (%l[Op_0_0x8F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x80,Op_0_0x81,Op_0_0x82,Op_0_0x83,Op_0_0x84,Op_0_0x85,Op_0_0x86,Op_0_0x87,Op_0_0x88,Op_0_0x89,Op_0_0x8A,Op_0_0x8B,Op_0_0x8C,Op_0_0x8D,Op_0_0x8E,Op_0_0x8F,pseudo9);
pseudo9:asm volatile goto(".2byte (%l[Op_0_0x90]-0b)/2\n\t.2byte (%l[Op_0_0x91]-0b)/2\n\t.2byte (%l[Op_0_0x92]-0b)/2\n\t.2byte (%l[Op_0_0x93]-0b)/2\n\t.2byte (%l[Op_0_0x94]-0b)/2\n\t.2byte (%l[Op_0_0x95]-0b)/2\n\t.2byte (%l[Op_0_0x96]-0b)/2\n\t.2byte (%l[Op_0_0x97]-0b)/2\n\t.2byte (%l[Op_0_0x98]-0b)/2\n\t.2byte (%l[Op_0_0x99]-0b)/2\n\t.2byte (%l[Op_0_0x9A]-0b)/2\n\t.2byte (%l[Op_0_0x9B]-0b)/2\n\t.2byte (%l[Op_0_0x9C]-0b)/2\n\t.2byte (%l[Op_0_0x9D]-0b)/2\n\t.2byte (%l[Op_0_0x9E]-0b)/2\n\t.2byte (%l[Op_0_0x9F]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0x90,Op_0_0x91,Op_0_0x92,Op_0_0x93,Op_0_0x94,Op_0_0x95,Op_0_0x96,Op_0_0x97,Op_0_0x98,Op_0_0x99,Op_0_0x9A,Op_0_0x9B,Op_0_0x9C,Op_0_0x9D,Op_0_0x9E,Op_0_0x9F,pseudo10);
pseudo10:asm volatile goto(".2byte (%l[Op_0_0xA0]-0b)/2\n\t.2byte (%l[Op_0_0xA1]-0b)/2\n\t.2byte (%l[Op_0_0xA2]-0b)/2\n\t.2byte (%l[Op_0_0xA3]-0b)/2\n\t.2byte (%l[Op_0_0xA4]-0b)/2\n\t.2byte (%l[Op_0_0xA5]-0b)/2\n\t.2byte (%l[Op_0_0xA6]-0b)/2\n\t.2byte (%l[Op_0_0xA7]-0b)/2\n\t.2byte (%l[Op_0_0xA8]-0b)/2\n\t.2byte (%l[Op_0_0xA9]-0b)/2\n\t.2byte (%l[Op_0_0xAA]-0b)/2\n\t.2byte (%l[Op_0_0xAB]-0b)/2\n\t.2byte (%l[Op_0_0xAC]-0b)/2\n\t.2byte (%l[Op_0_0xAD]-0b)/2\n\t.2byte (%l[Op_0_0xAE]-0b)/2\n\t.2byte (%l[Op_0_0xAF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xA0,Op_0_0xA1,Op_0_0xA2,Op_0_0xA3,Op_0_0xA4,Op_0_0xA5,Op_0_0xA6,Op_0_0xA7,Op_0_0xA8,Op_0_0xA9,Op_0_0xAA,Op_0_0xAB,Op_0_0xAC,Op_0_0xAD,Op_0_0xAE,Op_0_0xAF,pseudo11);
pseudo11:asm volatile goto(".2byte (%l[Op_0_0xB0]-0b)/2\n\t.2byte (%l[Op_0_0xB1]-0b)/2\n\t.2byte (%l[Op_0_0xB2]-0b)/2\n\t.2byte (%l[Op_0_0xB3]-0b)/2\n\t.2byte (%l[Op_0_0xB4]-0b)/2\n\t.2byte (%l[Op_0_0xB5]-0b)/2\n\t.2byte (%l[Op_0_0xB6]-0b)/2\n\t.2byte (%l[Op_0_0xB7]-0b)/2\n\t.2byte (%l[Op_0_0xB8]-0b)/2\n\t.2byte (%l[Op_0_0xB9]-0b)/2\n\t.2byte (%l[Op_0_0xBA]-0b)/2\n\t.2byte (%l[Op_0_0xBB]-0b)/2\n\t.2byte (%l[Op_0_0xBC]-0b)/2\n\t.2byte (%l[Op_0_0xBD]-0b)/2\n\t.2byte (%l[Op_0_0xBE]-0b)/2\n\t.2byte (%l[Op_0_0xBF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xB0,Op_0_0xB1,Op_0_0xB2,Op_0_0xB3,Op_0_0xB4,Op_0_0xB5,Op_0_0xB6,Op_0_0xB7,Op_0_0xB8,Op_0_0xB9,Op_0_0xBA,Op_0_0xBB,Op_0_0xBC,Op_0_0xBD,Op_0_0xBE,Op_0_0xBF,pseudo12);
pseudo12:asm volatile goto(".2byte (%l[Op_0_0xC0]-0b)/2\n\t.2byte (%l[Op_0_0xC1]-0b)/2\n\t.2byte (%l[Op_0_0xC2]-0b)/2\n\t.2byte (%l[Op_0_0xC3]-0b)/2\n\t.2byte (%l[Op_0_0xC4]-0b)/2\n\t.2byte (%l[Op_0_0xC5]-0b)/2\n\t.2byte (%l[Op_0_0xC6]-0b)/2\n\t.2byte (%l[Op_0_0xC7]-0b)/2\n\t.2byte (%l[Op_0_0xC8]-0b)/2\n\t.2byte (%l[Op_0_0xC9]-0b)/2\n\t.2byte (%l[Op_0_0xCA]-0b)/2\n\t.2byte (%l[Op_0_0xCB]-0b)/2\n\t.2byte (%l[Op_0_0xCC]-0b)/2\n\t.2byte (%l[Op_0_0xCD]-0b)/2\n\t.2byte (%l[Op_0_0xCE]-0b)/2\n\t.2byte (%l[Op_0_0xCF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xC0,Op_0_0xC1,Op_0_0xC2,Op_0_0xC3,Op_0_0xC4,Op_0_0xC5,Op_0_0xC6,Op_0_0xC7,Op_0_0xC8,Op_0_0xC9,Op_0_0xCA,Op_0_0xCB,Op_0_0xCC,Op_0_0xCD,Op_0_0xCE,Op_0_0xCF,pseudo13);
pseudo13:asm volatile goto(".2byte (%l[Op_0_0xD0]-0b)/2\n\t.2byte (%l[Op_0_0xD1]-0b)/2\n\t.2byte (%l[Op_0_0xD2]-0b)/2\n\t.2byte (%l[Op_0_0xD3]-0b)/2\n\t.2byte (%l[Op_0_0xD4]-0b)/2\n\t.2byte (%l[Op_0_0xD5]-0b)/2\n\t.2byte (%l[Op_0_0xD6]-0b)/2\n\t.2byte (%l[Op_0_0xD7]-0b)/2\n\t.2byte (%l[Op_0_0xD8]-0b)/2\n\t.2byte (%l[Op_0_0xD9]-0b)/2\n\t.2byte (%l[Op_0_0xDA]-0b)/2\n\t.2byte (%l[Op_0_0xDB]-0b)/2\n\t.2byte (%l[Op_0_0xDC]-0b)/2\n\t.2byte (%l[Op_0_0xDD]-0b)/2\n\t.2byte (%l[Op_0_0xDE]-0b)/2\n\t.2byte (%l[Op_0_0xDF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xD0,Op_0_0xD1,Op_0_0xD2,Op_0_0xD3,Op_0_0xD4,Op_0_0xD5,Op_0_0xD6,Op_0_0xD7,Op_0_0xD8,Op_0_0xD9,Op_0_0xDA,Op_0_0xDB,Op_0_0xDC,Op_0_0xDD,Op_0_0xDE,Op_0_0xDF,pseudo14);
pseudo14:asm volatile goto(".2byte (%l[Op_0_0xE0]-0b)/2\n\t.2byte (%l[Op_0_0xE1]-0b)/2\n\t.2byte (%l[Op_0_0xE2]-0b)/2\n\t.2byte (%l[Op_0_0xE3]-0b)/2\n\t.2byte (%l[Op_0_0xE4]-0b)/2\n\t.2byte (%l[Op_0_0xE5]-0b)/2\n\t.2byte (%l[Op_0_0xE6]-0b)/2\n\t.2byte (%l[Op_0_0xE7]-0b)/2\n\t.2byte (%l[Op_0_0xE8]-0b)/2\n\t.2byte (%l[Op_0_0xE9]-0b)/2\n\t.2byte (%l[Op_0_0xEA]-0b)/2\n\t.2byte (%l[Op_0_0xEB]-0b)/2\n\t.2byte (%l[Op_0_0xEC]-0b)/2\n\t.2byte (%l[Op_0_0xED]-0b)/2\n\t.2byte (%l[Op_0_0xEE]-0b)/2\n\t.2byte (%l[Op_0_0xEF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xE0,Op_0_0xE1,Op_0_0xE2,Op_0_0xE3,Op_0_0xE4,Op_0_0xE5,Op_0_0xE6,Op_0_0xE7,Op_0_0xE8,Op_0_0xE9,Op_0_0xEA,Op_0_0xEB,Op_0_0xEC,Op_0_0xED,Op_0_0xEE,Op_0_0xEF,pseudo15);
pseudo15:asm volatile goto(".2byte (%l[Op_0_0xF0]-0b)/2\n\t.2byte (%l[Op_0_0xF1]-0b)/2\n\t.2byte (%l[Op_0_0xF2]-0b)/2\n\t.2byte (%l[Op_0_0xF3]-0b)/2\n\t.2byte (%l[Op_0_0xF4]-0b)/2\n\t.2byte (%l[Op_0_0xF5]-0b)/2\n\t.2byte (%l[Op_0_0xF6]-0b)/2\n\t.2byte (%l[Op_0_0xF7]-0b)/2\n\t.2byte (%l[Op_0_0xF8]-0b)/2\n\t.2byte (%l[Op_0_0xF9]-0b)/2\n\t.2byte (%l[Op_0_0xFA]-0b)/2\n\t.2byte (%l[Op_0_0xFB]-0b)/2\n\t.2byte (%l[Op_0_0xFC]-0b)/2\n\t.2byte (%l[Op_0_0xFD]-0b)/2\n\t.2byte (%l[Op_0_0xFE]-0b)/2\n\t.2byte (%l[Op_0_0xFF]-0b)/2\n\t"::"r"(cop):"cc":Op_0_0xF0,Op_0_0xF1,Op_0_0xF2,Op_0_0xF3,Op_0_0xF4,Op_0_0xF5,Op_0_0xF6,Op_0_0xF7,Op_0_0xF8,Op_0_0xF9,Op_0_0xFA,Op_0_0xFB,Op_0_0xFC,Op_0_0xFD,Op_0_0xFE,Op_0_0xFF,pseudo16);
pseudo16:asm volatile goto(".2byte (%l[Op_1_0x00]-0b)/2\n\t.2byte (%l[Op_1_0x01]-0b)/2\n\t.2byte (%l[Op_1_0x02]-0b)/2\n\t.2byte (%l[Op_1_0x03]-0b)/2\n\t.2byte (%l[Op_1_0x04]-0b)/2\n\t.2byte (%l[Op_1_0x05]-0b)/2\n\t.2byte (%l[Op_1_0x06]-0b)/2\n\t.2byte (%l[Op_1_0x07]-0b)/2\n\t.2byte (%l[Op_1_0x08]-0b)/2\n\t.2byte (%l[Op_1_0x09]-0b)/2\n\t.2byte (%l[Op_1_0x0A]-0b)/2\n\t.2byte (%l[Op_1_0x0B]-0b)/2\n\t.2byte (%l[Op_1_0x0C]-0b)/2\n\t.2byte (%l[Op_1_0x0D]-0b)/2\n\t.2byte (%l[Op_1_0x0E]-0b)/2\n\t.2byte (%l[Op_1_0x0F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x00,Op_1_0x01,Op_1_0x02,Op_1_0x03,Op_1_0x04,Op_1_0x05,Op_1_0x06,Op_1_0x07,Op_1_0x08,Op_1_0x09,Op_1_0x0A,Op_1_0x0B,Op_1_0x0C,Op_1_0x0D,Op_1_0x0E,Op_1_0x0F,pseudo17);
pseudo17:asm volatile goto(".2byte (%l[Op_1_0x10]-0b)/2\n\t.2byte (%l[Op_1_0x11]-0b)/2\n\t.2byte (%l[Op_1_0x12]-0b)/2\n\t.2byte (%l[Op_1_0x13]-0b)/2\n\t.2byte (%l[Op_1_0x14]-0b)/2\n\t.2byte (%l[Op_1_0x15]-0b)/2\n\t.2byte (%l[Op_1_0x16]-0b)/2\n\t.2byte (%l[Op_1_0x17]-0b)/2\n\t.2byte (%l[Op_1_0x18]-0b)/2\n\t.2byte (%l[Op_1_0x19]-0b)/2\n\t.2byte (%l[Op_1_0x1A]-0b)/2\n\t.2byte (%l[Op_1_0x1B]-0b)/2\n\t.2byte (%l[Op_1_0x1C]-0b)/2\n\t.2byte (%l[Op_1_0x1D]-0b)/2\n\t.2byte (%l[Op_1_0x1E]-0b)/2\n\t.2byte (%l[Op_1_0x1F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x10,Op_1_0x11,Op_1_0x12,Op_1_0x13,Op_1_0x14,Op_1_0x15,Op_1_0x16,Op_1_0x17,Op_1_0x18,Op_1_0x19,Op_1_0x1A,Op_1_0x1B,Op_1_0x1C,Op_1_0x1D,Op_1_0x1E,Op_1_0x1F,pseudo18);
pseudo18:asm volatile goto(".2byte (%l[Op_1_0x20]-0b)/2\n\t.2byte (%l[Op_1_0x21]-0b)/2\n\t.2byte (%l[Op_1_0x22]-0b)/2\n\t.2byte (%l[Op_1_0x23]-0b)/2\n\t.2byte (%l[Op_1_0x24]-0b)/2\n\t.2byte (%l[Op_1_0x25]-0b)/2\n\t.2byte (%l[Op_1_0x26]-0b)/2\n\t.2byte (%l[Op_1_0x27]-0b)/2\n\t.2byte (%l[Op_1_0x28]-0b)/2\n\t.2byte (%l[Op_1_0x29]-0b)/2\n\t.2byte (%l[Op_1_0x2A]-0b)/2\n\t.2byte (%l[Op_1_0x2B]-0b)/2\n\t.2byte (%l[Op_1_0x2C]-0b)/2\n\t.2byte (%l[Op_1_0x2D]-0b)/2\n\t.2byte (%l[Op_1_0x2E]-0b)/2\n\t.2byte (%l[Op_1_0x2F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x20,Op_1_0x21,Op_1_0x22,Op_1_0x23,Op_1_0x24,Op_1_0x25,Op_1_0x26,Op_1_0x27,Op_1_0x28,Op_1_0x29,Op_1_0x2A,Op_1_0x2B,Op_1_0x2C,Op_1_0x2D,Op_1_0x2E,Op_1_0x2F,pseudo19);
pseudo19:asm volatile goto(".2byte (%l[Op_1_0x30]-0b)/2\n\t.2byte (%l[Op_1_0x31]-0b)/2\n\t.2byte (%l[Op_1_0x32]-0b)/2\n\t.2byte (%l[Op_1_0x33]-0b)/2\n\t.2byte (%l[Op_1_0x34]-0b)/2\n\t.2byte (%l[Op_1_0x35]-0b)/2\n\t.2byte (%l[Op_1_0x36]-0b)/2\n\t.2byte (%l[Op_1_0x37]-0b)/2\n\t.2byte (%l[Op_1_0x38]-0b)/2\n\t.2byte (%l[Op_1_0x39]-0b)/2\n\t.2byte (%l[Op_1_0x3A]-0b)/2\n\t.2byte (%l[Op_1_0x3B]-0b)/2\n\t.2byte (%l[Op_1_0x3C]-0b)/2\n\t.2byte (%l[Op_1_0x3D]-0b)/2\n\t.2byte (%l[Op_1_0x3E]-0b)/2\n\t.2byte (%l[Op_1_0x3F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x30,Op_1_0x31,Op_1_0x32,Op_1_0x33,Op_1_0x34,Op_1_0x35,Op_1_0x36,Op_1_0x37,Op_1_0x38,Op_1_0x39,Op_1_0x3A,Op_1_0x3B,Op_1_0x3C,Op_1_0x3D,Op_1_0x3E,Op_1_0x3F,pseudo20);
pseudo20:asm volatile goto(".2byte (%l[Op_1_0x40]-0b)/2\n\t.2byte (%l[Op_1_0x41]-0b)/2\n\t.2byte (%l[Op_1_0x42]-0b)/2\n\t.2byte (%l[Op_1_0x43]-0b)/2\n\t.2byte (%l[Op_1_0x44]-0b)/2\n\t.2byte (%l[Op_1_0x45]-0b)/2\n\t.2byte (%l[Op_1_0x46]-0b)/2\n\t.2byte (%l[Op_1_0x47]-0b)/2\n\t.2byte (%l[Op_1_0x48]-0b)/2\n\t.2byte (%l[Op_1_0x49]-0b)/2\n\t.2byte (%l[Op_1_0x4A]-0b)/2\n\t.2byte (%l[Op_1_0x4B]-0b)/2\n\t.2byte (%l[Op_1_0x4C]-0b)/2\n\t.2byte (%l[Op_1_0x4D]-0b)/2\n\t.2byte (%l[Op_1_0x4E]-0b)/2\n\t.2byte (%l[Op_1_0x4F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x40,Op_1_0x41,Op_1_0x42,Op_1_0x43,Op_1_0x44,Op_1_0x45,Op_1_0x46,Op_1_0x47,Op_1_0x48,Op_1_0x49,Op_1_0x4A,Op_1_0x4B,Op_1_0x4C,Op_1_0x4D,Op_1_0x4E,Op_1_0x4F,pseudo21);
pseudo21:asm volatile goto(".2byte (%l[Op_1_0x50]-0b)/2\n\t.2byte (%l[Op_1_0x51]-0b)/2\n\t.2byte (%l[Op_1_0x52]-0b)/2\n\t.2byte (%l[Op_1_0x53]-0b)/2\n\t.2byte (%l[Op_1_0x54]-0b)/2\n\t.2byte (%l[Op_1_0x55]-0b)/2\n\t.2byte (%l[Op_1_0x56]-0b)/2\n\t.2byte (%l[Op_1_0x57]-0b)/2\n\t.2byte (%l[Op_1_0x58]-0b)/2\n\t.2byte (%l[Op_1_0x59]-0b)/2\n\t.2byte (%l[Op_1_0x5A]-0b)/2\n\t.2byte (%l[Op_1_0x5B]-0b)/2\n\t.2byte (%l[Op_1_0x5C]-0b)/2\n\t.2byte (%l[Op_1_0x5D]-0b)/2\n\t.2byte (%l[Op_1_0x5E]-0b)/2\n\t.2byte (%l[Op_1_0x5F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x50,Op_1_0x51,Op_1_0x52,Op_1_0x53,Op_1_0x54,Op_1_0x55,Op_1_0x56,Op_1_0x57,Op_1_0x58,Op_1_0x59,Op_1_0x5A,Op_1_0x5B,Op_1_0x5C,Op_1_0x5D,Op_1_0x5E,Op_1_0x5F,pseudo22);
pseudo22:asm volatile goto(".2byte (%l[Op_1_0x60]-0b)/2\n\t.2byte (%l[Op_1_0x61]-0b)/2\n\t.2byte (%l[Op_1_0x62]-0b)/2\n\t.2byte (%l[Op_1_0x63]-0b)/2\n\t.2byte (%l[Op_1_0x64]-0b)/2\n\t.2byte (%l[Op_1_0x65]-0b)/2\n\t.2byte (%l[Op_1_0x66]-0b)/2\n\t.2byte (%l[Op_1_0x67]-0b)/2\n\t.2byte (%l[Op_1_0x68]-0b)/2\n\t.2byte (%l[Op_1_0x69]-0b)/2\n\t.2byte (%l[Op_1_0x6A]-0b)/2\n\t.2byte (%l[Op_1_0x6B]-0b)/2\n\t.2byte (%l[Op_1_0x6C]-0b)/2\n\t.2byte (%l[Op_1_0x6D]-0b)/2\n\t.2byte (%l[Op_1_0x6E]-0b)/2\n\t.2byte (%l[Op_1_0x6F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x60,Op_1_0x61,Op_1_0x62,Op_1_0x63,Op_1_0x64,Op_1_0x65,Op_1_0x66,Op_1_0x67,Op_1_0x68,Op_1_0x69,Op_1_0x6A,Op_1_0x6B,Op_1_0x6C,Op_1_0x6D,Op_1_0x6E,Op_1_0x6F,pseudo23);
pseudo23:asm volatile goto(".2byte (%l[Op_1_0x70]-0b)/2\n\t.2byte (%l[Op_1_0x71]-0b)/2\n\t.2byte (%l[Op_1_0x72]-0b)/2\n\t.2byte (%l[Op_1_0x73]-0b)/2\n\t.2byte (%l[Op_1_0x74]-0b)/2\n\t.2byte (%l[Op_1_0x75]-0b)/2\n\t.2byte (%l[Op_1_0x76]-0b)/2\n\t.2byte (%l[Op_1_0x77]-0b)/2\n\t.2byte (%l[Op_1_0x78]-0b)/2\n\t.2byte (%l[Op_1_0x79]-0b)/2\n\t.2byte (%l[Op_1_0x7A]-0b)/2\n\t.2byte (%l[Op_1_0x7B]-0b)/2\n\t.2byte (%l[Op_1_0x7C]-0b)/2\n\t.2byte (%l[Op_1_0x7D]-0b)/2\n\t.2byte (%l[Op_1_0x7E]-0b)/2\n\t.2byte (%l[Op_1_0x7F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x70,Op_1_0x71,Op_1_0x72,Op_1_0x73,Op_1_0x74,Op_1_0x75,Op_1_0x76,Op_1_0x77,Op_1_0x78,Op_1_0x79,Op_1_0x7A,Op_1_0x7B,Op_1_0x7C,Op_1_0x7D,Op_1_0x7E,Op_1_0x7F,pseudo24);
pseudo24:asm volatile goto(".2byte (%l[Op_1_0x80]-0b)/2\n\t.2byte (%l[Op_1_0x81]-0b)/2\n\t.2byte (%l[Op_1_0x82]-0b)/2\n\t.2byte (%l[Op_1_0x83]-0b)/2\n\t.2byte (%l[Op_1_0x84]-0b)/2\n\t.2byte (%l[Op_1_0x85]-0b)/2\n\t.2byte (%l[Op_1_0x86]-0b)/2\n\t.2byte (%l[Op_1_0x87]-0b)/2\n\t.2byte (%l[Op_1_0x88]-0b)/2\n\t.2byte (%l[Op_1_0x89]-0b)/2\n\t.2byte (%l[Op_1_0x8A]-0b)/2\n\t.2byte (%l[Op_1_0x8B]-0b)/2\n\t.2byte (%l[Op_1_0x8C]-0b)/2\n\t.2byte (%l[Op_1_0x8D]-0b)/2\n\t.2byte (%l[Op_1_0x8E]-0b)/2\n\t.2byte (%l[Op_1_0x8F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x80,Op_1_0x81,Op_1_0x82,Op_1_0x83,Op_1_0x84,Op_1_0x85,Op_1_0x86,Op_1_0x87,Op_1_0x88,Op_1_0x89,Op_1_0x8A,Op_1_0x8B,Op_1_0x8C,Op_1_0x8D,Op_1_0x8E,Op_1_0x8F,pseudo25);
pseudo25:asm volatile goto(".2byte (%l[Op_1_0x90]-0b)/2\n\t.2byte (%l[Op_1_0x91]-0b)/2\n\t.2byte (%l[Op_1_0x92]-0b)/2\n\t.2byte (%l[Op_1_0x93]-0b)/2\n\t.2byte (%l[Op_1_0x94]-0b)/2\n\t.2byte (%l[Op_1_0x95]-0b)/2\n\t.2byte (%l[Op_1_0x96]-0b)/2\n\t.2byte (%l[Op_1_0x97]-0b)/2\n\t.2byte (%l[Op_1_0x98]-0b)/2\n\t.2byte (%l[Op_1_0x99]-0b)/2\n\t.2byte (%l[Op_1_0x9A]-0b)/2\n\t.2byte (%l[Op_1_0x9B]-0b)/2\n\t.2byte (%l[Op_1_0x9C]-0b)/2\n\t.2byte (%l[Op_1_0x9D]-0b)/2\n\t.2byte (%l[Op_1_0x9E]-0b)/2\n\t.2byte (%l[Op_1_0x9F]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0x90,Op_1_0x91,Op_1_0x92,Op_1_0x93,Op_1_0x94,Op_1_0x95,Op_1_0x96,Op_1_0x97,Op_1_0x98,Op_1_0x99,Op_1_0x9A,Op_1_0x9B,Op_1_0x9C,Op_1_0x9D,Op_1_0x9E,Op_1_0x9F,pseudo26);
pseudo26:asm volatile goto(".2byte (%l[Op_1_0xA0]-0b)/2\n\t.2byte (%l[Op_1_0xA1]-0b)/2\n\t.2byte (%l[Op_1_0xA2]-0b)/2\n\t.2byte (%l[Op_1_0xA3]-0b)/2\n\t.2byte (%l[Op_1_0xA4]-0b)/2\n\t.2byte (%l[Op_1_0xA5]-0b)/2\n\t.2byte (%l[Op_1_0xA6]-0b)/2\n\t.2byte (%l[Op_1_0xA7]-0b)/2\n\t.2byte (%l[Op_1_0xA8]-0b)/2\n\t.2byte (%l[Op_1_0xA9]-0b)/2\n\t.2byte (%l[Op_1_0xAA]-0b)/2\n\t.2byte (%l[Op_1_0xAB]-0b)/2\n\t.2byte (%l[Op_1_0xAC]-0b)/2\n\t.2byte (%l[Op_1_0xAD]-0b)/2\n\t.2byte (%l[Op_1_0xAE]-0b)/2\n\t.2byte (%l[Op_1_0xAF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xA0,Op_1_0xA1,Op_1_0xA2,Op_1_0xA3,Op_1_0xA4,Op_1_0xA5,Op_1_0xA6,Op_1_0xA7,Op_1_0xA8,Op_1_0xA9,Op_1_0xAA,Op_1_0xAB,Op_1_0xAC,Op_1_0xAD,Op_1_0xAE,Op_1_0xAF,pseudo27);
pseudo27:asm volatile goto(".2byte (%l[Op_1_0xB0]-0b)/2\n\t.2byte (%l[Op_1_0xB1]-0b)/2\n\t.2byte (%l[Op_1_0xB2]-0b)/2\n\t.2byte (%l[Op_1_0xB3]-0b)/2\n\t.2byte (%l[Op_1_0xB4]-0b)/2\n\t.2byte (%l[Op_1_0xB5]-0b)/2\n\t.2byte (%l[Op_1_0xB6]-0b)/2\n\t.2byte (%l[Op_1_0xB7]-0b)/2\n\t.2byte (%l[Op_1_0xB8]-0b)/2\n\t.2byte (%l[Op_1_0xB9]-0b)/2\n\t.2byte (%l[Op_1_0xBA]-0b)/2\n\t.2byte (%l[Op_1_0xBB]-0b)/2\n\t.2byte (%l[Op_1_0xBC]-0b)/2\n\t.2byte (%l[Op_1_0xBD]-0b)/2\n\t.2byte (%l[Op_1_0xBE]-0b)/2\n\t.2byte (%l[Op_1_0xBF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xB0,Op_1_0xB1,Op_1_0xB2,Op_1_0xB3,Op_1_0xB4,Op_1_0xB5,Op_1_0xB6,Op_1_0xB7,Op_1_0xB8,Op_1_0xB9,Op_1_0xBA,Op_1_0xBB,Op_1_0xBC,Op_1_0xBD,Op_1_0xBE,Op_1_0xBF,pseudo28);
pseudo28:asm volatile goto(".2byte (%l[Op_1_0xC0]-0b)/2\n\t.2byte (%l[Op_1_0xC1]-0b)/2\n\t.2byte (%l[Op_1_0xC2]-0b)/2\n\t.2byte (%l[Op_1_0xC3]-0b)/2\n\t.2byte (%l[Op_1_0xC4]-0b)/2\n\t.2byte (%l[Op_1_0xC5]-0b)/2\n\t.2byte (%l[Op_1_0xC6]-0b)/2\n\t.2byte (%l[Op_1_0xC7]-0b)/2\n\t.2byte (%l[Op_1_0xC8]-0b)/2\n\t.2byte (%l[Op_1_0xC9]-0b)/2\n\t.2byte (%l[Op_1_0xCA]-0b)/2\n\t.2byte (%l[Op_1_0xCB]-0b)/2\n\t.2byte (%l[Op_1_0xCC]-0b)/2\n\t.2byte (%l[Op_1_0xCD]-0b)/2\n\t.2byte (%l[Op_1_0xCE]-0b)/2\n\t.2byte (%l[Op_1_0xCF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xC0,Op_1_0xC1,Op_1_0xC2,Op_1_0xC3,Op_1_0xC4,Op_1_0xC5,Op_1_0xC6,Op_1_0xC7,Op_1_0xC8,Op_1_0xC9,Op_1_0xCA,Op_1_0xCB,Op_1_0xCC,Op_1_0xCD,Op_1_0xCE,Op_1_0xCF,pseudo29);
pseudo29:asm volatile goto(".2byte (%l[Op_1_0xD0]-0b)/2\n\t.2byte (%l[Op_1_0xD1]-0b)/2\n\t.2byte (%l[Op_1_0xD2]-0b)/2\n\t.2byte (%l[Op_1_0xD3]-0b)/2\n\t.2byte (%l[Op_1_0xD4]-0b)/2\n\t.2byte (%l[Op_1_0xD5]-0b)/2\n\t.2byte (%l[Op_1_0xD6]-0b)/2\n\t.2byte (%l[Op_1_0xD7]-0b)/2\n\t.2byte (%l[Op_1_0xD8]-0b)/2\n\t.2byte (%l[Op_1_0xD9]-0b)/2\n\t.2byte (%l[Op_1_0xDA]-0b)/2\n\t.2byte (%l[Op_1_0xDB]-0b)/2\n\t.2byte (%l[Op_1_0xDC]-0b)/2\n\t.2byte (%l[Op_1_0xDD]-0b)/2\n\t.2byte (%l[Op_1_0xDE]-0b)/2\n\t.2byte (%l[Op_1_0xDF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xD0,Op_1_0xD1,Op_1_0xD2,Op_1_0xD3,Op_1_0xD4,Op_1_0xD5,Op_1_0xD6,Op_1_0xD7,Op_1_0xD8,Op_1_0xD9,Op_1_0xDA,Op_1_0xDB,Op_1_0xDC,Op_1_0xDD,Op_1_0xDE,Op_1_0xDF,pseudo30);
pseudo30:asm volatile goto(".2byte (%l[Op_1_0xE0]-0b)/2\n\t.2byte (%l[Op_1_0xE1]-0b)/2\n\t.2byte (%l[Op_1_0xE2]-0b)/2\n\t.2byte (%l[Op_1_0xE3]-0b)/2\n\t.2byte (%l[Op_1_0xE4]-0b)/2\n\t.2byte (%l[Op_1_0xE5]-0b)/2\n\t.2byte (%l[Op_1_0xE6]-0b)/2\n\t.2byte (%l[Op_1_0xE7]-0b)/2\n\t.2byte (%l[Op_1_0xE8]-0b)/2\n\t.2byte (%l[Op_1_0xE9]-0b)/2\n\t.2byte (%l[Op_1_0xEA]-0b)/2\n\t.2byte (%l[Op_1_0xEB]-0b)/2\n\t.2byte (%l[Op_1_0xEC]-0b)/2\n\t.2byte (%l[Op_1_0xED]-0b)/2\n\t.2byte (%l[Op_1_0xEE]-0b)/2\n\t.2byte (%l[Op_1_0xEF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xE0,Op_1_0xE1,Op_1_0xE2,Op_1_0xE3,Op_1_0xE4,Op_1_0xE5,Op_1_0xE6,Op_1_0xE7,Op_1_0xE8,Op_1_0xE9,Op_1_0xEA,Op_1_0xEB,Op_1_0xEC,Op_1_0xED,Op_1_0xEE,Op_1_0xEF,pseudo31);
pseudo31:asm volatile goto(".2byte (%l[Op_1_0xF0]-0b)/2\n\t.2byte (%l[Op_1_0xF1]-0b)/2\n\t.2byte (%l[Op_1_0xF2]-0b)/2\n\t.2byte (%l[Op_1_0xF3]-0b)/2\n\t.2byte (%l[Op_1_0xF4]-0b)/2\n\t.2byte (%l[Op_1_0xF5]-0b)/2\n\t.2byte (%l[Op_1_0xF6]-0b)/2\n\t.2byte (%l[Op_1_0xF7]-0b)/2\n\t.2byte (%l[Op_1_0xF8]-0b)/2\n\t.2byte (%l[Op_1_0xF9]-0b)/2\n\t.2byte (%l[Op_1_0xFA]-0b)/2\n\t.2byte (%l[Op_1_0xFB]-0b)/2\n\t.2byte (%l[Op_1_0xFC]-0b)/2\n\t.2byte (%l[Op_1_0xFD]-0b)/2\n\t.2byte (%l[Op_1_0xFE]-0b)/2\n\t.2byte (%l[Op_1_0xFF]-0b)/2\n\t"::"r"(cop):"cc":Op_1_0xF0,Op_1_0xF1,Op_1_0xF2,Op_1_0xF3,Op_1_0xF4,Op_1_0xF5,Op_1_0xF6,Op_1_0xF7,Op_1_0xF8,Op_1_0xF9,Op_1_0xFA,Op_1_0xFB,Op_1_0xFC,Op_1_0xFD,Op_1_0xFE,Op_1_0xFF,pseudo32);
pseudo32:asm volatile goto(".2byte (%l[Op_2_0x00]-0b)/2\n\t.2byte (%l[Op_2_0x01]-0b)/2\n\t.2byte (%l[Op_2_0x02]-0b)/2\n\t.2byte (%l[Op_2_0x03]-0b)/2\n\t.2byte (%l[Op_2_0x04]-0b)/2\n\t.2byte (%l[Op_2_0x05]-0b)/2\n\t.2byte (%l[Op_2_0x06]-0b)/2\n\t.2byte (%l[Op_2_0x07]-0b)/2\n\t.2byte (%l[Op_2_0x08]-0b)/2\n\t.2byte (%l[Op_2_0x09]-0b)/2\n\t.2byte (%l[Op_2_0x0A]-0b)/2\n\t.2byte (%l[Op_2_0x0B]-0b)/2\n\t.2byte (%l[Op_2_0x0C]-0b)/2\n\t.2byte (%l[Op_2_0x0D]-0b)/2\n\t.2byte (%l[Op_2_0x0E]-0b)/2\n\t.2byte (%l[Op_2_0x0F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x00,Op_2_0x01,Op_2_0x02,Op_2_0x03,Op_2_0x04,Op_2_0x05,Op_2_0x06,Op_2_0x07,Op_2_0x08,Op_2_0x09,Op_2_0x0A,Op_2_0x0B,Op_2_0x0C,Op_2_0x0D,Op_2_0x0E,Op_2_0x0F,pseudo33);
pseudo33:asm volatile goto(".2byte (%l[Op_2_0x10]-0b)/2\n\t.2byte (%l[Op_2_0x11]-0b)/2\n\t.2byte (%l[Op_2_0x12]-0b)/2\n\t.2byte (%l[Op_2_0x13]-0b)/2\n\t.2byte (%l[Op_2_0x14]-0b)/2\n\t.2byte (%l[Op_2_0x15]-0b)/2\n\t.2byte (%l[Op_2_0x16]-0b)/2\n\t.2byte (%l[Op_2_0x17]-0b)/2\n\t.2byte (%l[Op_2_0x18]-0b)/2\n\t.2byte (%l[Op_2_0x19]-0b)/2\n\t.2byte (%l[Op_2_0x1A]-0b)/2\n\t.2byte (%l[Op_2_0x1B]-0b)/2\n\t.2byte (%l[Op_2_0x1C]-0b)/2\n\t.2byte (%l[Op_2_0x1D]-0b)/2\n\t.2byte (%l[Op_2_0x1E]-0b)/2\n\t.2byte (%l[Op_2_0x1F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x10,Op_2_0x11,Op_2_0x12,Op_2_0x13,Op_2_0x14,Op_2_0x15,Op_2_0x16,Op_2_0x17,Op_2_0x18,Op_2_0x19,Op_2_0x1A,Op_2_0x1B,Op_2_0x1C,Op_2_0x1D,Op_2_0x1E,Op_2_0x1F,pseudo34);
pseudo34:asm volatile goto(".2byte (%l[Op_2_0x20]-0b)/2\n\t.2byte (%l[Op_2_0x21]-0b)/2\n\t.2byte (%l[Op_2_0x22]-0b)/2\n\t.2byte (%l[Op_2_0x23]-0b)/2\n\t.2byte (%l[Op_2_0x24]-0b)/2\n\t.2byte (%l[Op_2_0x25]-0b)/2\n\t.2byte (%l[Op_2_0x26]-0b)/2\n\t.2byte (%l[Op_2_0x27]-0b)/2\n\t.2byte (%l[Op_2_0x28]-0b)/2\n\t.2byte (%l[Op_2_0x29]-0b)/2\n\t.2byte (%l[Op_2_0x2A]-0b)/2\n\t.2byte (%l[Op_2_0x2B]-0b)/2\n\t.2byte (%l[Op_2_0x2C]-0b)/2\n\t.2byte (%l[Op_2_0x2D]-0b)/2\n\t.2byte (%l[Op_2_0x2E]-0b)/2\n\t.2byte (%l[Op_2_0x2F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x20,Op_2_0x21,Op_2_0x22,Op_2_0x23,Op_2_0x24,Op_2_0x25,Op_2_0x26,Op_2_0x27,Op_2_0x28,Op_2_0x29,Op_2_0x2A,Op_2_0x2B,Op_2_0x2C,Op_2_0x2D,Op_2_0x2E,Op_2_0x2F,pseudo35);
pseudo35:asm volatile goto(".2byte (%l[Op_2_0x30]-0b)/2\n\t.2byte (%l[Op_2_0x31]-0b)/2\n\t.2byte (%l[Op_2_0x32]-0b)/2\n\t.2byte (%l[Op_2_0x33]-0b)/2\n\t.2byte (%l[Op_2_0x34]-0b)/2\n\t.2byte (%l[Op_2_0x35]-0b)/2\n\t.2byte (%l[Op_2_0x36]-0b)/2\n\t.2byte (%l[Op_2_0x37]-0b)/2\n\t.2byte (%l[Op_2_0x38]-0b)/2\n\t.2byte (%l[Op_2_0x39]-0b)/2\n\t.2byte (%l[Op_2_0x3A]-0b)/2\n\t.2byte (%l[Op_2_0x3B]-0b)/2\n\t.2byte (%l[Op_2_0x3C]-0b)/2\n\t.2byte (%l[Op_2_0x3D]-0b)/2\n\t.2byte (%l[Op_2_0x3E]-0b)/2\n\t.2byte (%l[Op_2_0x3F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x30,Op_2_0x31,Op_2_0x32,Op_2_0x33,Op_2_0x34,Op_2_0x35,Op_2_0x36,Op_2_0x37,Op_2_0x38,Op_2_0x39,Op_2_0x3A,Op_2_0x3B,Op_2_0x3C,Op_2_0x3D,Op_2_0x3E,Op_2_0x3F,pseudo36);
pseudo36:asm volatile goto(".2byte (%l[Op_2_0x40]-0b)/2\n\t.2byte (%l[Op_2_0x41]-0b)/2\n\t.2byte (%l[Op_2_0x42]-0b)/2\n\t.2byte (%l[Op_2_0x43]-0b)/2\n\t.2byte (%l[Op_2_0x44]-0b)/2\n\t.2byte (%l[Op_2_0x45]-0b)/2\n\t.2byte (%l[Op_2_0x46]-0b)/2\n\t.2byte (%l[Op_2_0x47]-0b)/2\n\t.2byte (%l[Op_2_0x48]-0b)/2\n\t.2byte (%l[Op_2_0x49]-0b)/2\n\t.2byte (%l[Op_2_0x4A]-0b)/2\n\t.2byte (%l[Op_2_0x4B]-0b)/2\n\t.2byte (%l[Op_2_0x4C]-0b)/2\n\t.2byte (%l[Op_2_0x4D]-0b)/2\n\t.2byte (%l[Op_2_0x4E]-0b)/2\n\t.2byte (%l[Op_2_0x4F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x40,Op_2_0x41,Op_2_0x42,Op_2_0x43,Op_2_0x44,Op_2_0x45,Op_2_0x46,Op_2_0x47,Op_2_0x48,Op_2_0x49,Op_2_0x4A,Op_2_0x4B,Op_2_0x4C,Op_2_0x4D,Op_2_0x4E,Op_2_0x4F,pseudo37);
pseudo37:asm volatile goto(".2byte (%l[Op_2_0x50]-0b)/2\n\t.2byte (%l[Op_2_0x51]-0b)/2\n\t.2byte (%l[Op_2_0x52]-0b)/2\n\t.2byte (%l[Op_2_0x53]-0b)/2\n\t.2byte (%l[Op_2_0x54]-0b)/2\n\t.2byte (%l[Op_2_0x55]-0b)/2\n\t.2byte (%l[Op_2_0x56]-0b)/2\n\t.2byte (%l[Op_2_0x57]-0b)/2\n\t.2byte (%l[Op_2_0x58]-0b)/2\n\t.2byte (%l[Op_2_0x59]-0b)/2\n\t.2byte (%l[Op_2_0x5A]-0b)/2\n\t.2byte (%l[Op_2_0x5B]-0b)/2\n\t.2byte (%l[Op_2_0x5C]-0b)/2\n\t.2byte (%l[Op_2_0x5D]-0b)/2\n\t.2byte (%l[Op_2_0x5E]-0b)/2\n\t.2byte (%l[Op_2_0x5F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x50,Op_2_0x51,Op_2_0x52,Op_2_0x53,Op_2_0x54,Op_2_0x55,Op_2_0x56,Op_2_0x57,Op_2_0x58,Op_2_0x59,Op_2_0x5A,Op_2_0x5B,Op_2_0x5C,Op_2_0x5D,Op_2_0x5E,Op_2_0x5F,pseudo38);
pseudo38:asm volatile goto(".2byte (%l[Op_2_0x60]-0b)/2\n\t.2byte (%l[Op_2_0x61]-0b)/2\n\t.2byte (%l[Op_2_0x62]-0b)/2\n\t.2byte (%l[Op_2_0x63]-0b)/2\n\t.2byte (%l[Op_2_0x64]-0b)/2\n\t.2byte (%l[Op_2_0x65]-0b)/2\n\t.2byte (%l[Op_2_0x66]-0b)/2\n\t.2byte (%l[Op_2_0x67]-0b)/2\n\t.2byte (%l[Op_2_0x68]-0b)/2\n\t.2byte (%l[Op_2_0x69]-0b)/2\n\t.2byte (%l[Op_2_0x6A]-0b)/2\n\t.2byte (%l[Op_2_0x6B]-0b)/2\n\t.2byte (%l[Op_2_0x6C]-0b)/2\n\t.2byte (%l[Op_2_0x6D]-0b)/2\n\t.2byte (%l[Op_2_0x6E]-0b)/2\n\t.2byte (%l[Op_2_0x6F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x60,Op_2_0x61,Op_2_0x62,Op_2_0x63,Op_2_0x64,Op_2_0x65,Op_2_0x66,Op_2_0x67,Op_2_0x68,Op_2_0x69,Op_2_0x6A,Op_2_0x6B,Op_2_0x6C,Op_2_0x6D,Op_2_0x6E,Op_2_0x6F,pseudo39);
pseudo39:asm volatile goto(".2byte (%l[Op_2_0x70]-0b)/2\n\t.2byte (%l[Op_2_0x71]-0b)/2\n\t.2byte (%l[Op_2_0x72]-0b)/2\n\t.2byte (%l[Op_2_0x73]-0b)/2\n\t.2byte (%l[Op_2_0x74]-0b)/2\n\t.2byte (%l[Op_2_0x75]-0b)/2\n\t.2byte (%l[Op_2_0x76]-0b)/2\n\t.2byte (%l[Op_2_0x77]-0b)/2\n\t.2byte (%l[Op_2_0x78]-0b)/2\n\t.2byte (%l[Op_2_0x79]-0b)/2\n\t.2byte (%l[Op_2_0x7A]-0b)/2\n\t.2byte (%l[Op_2_0x7B]-0b)/2\n\t.2byte (%l[Op_2_0x7C]-0b)/2\n\t.2byte (%l[Op_2_0x7D]-0b)/2\n\t.2byte (%l[Op_2_0x7E]-0b)/2\n\t.2byte (%l[Op_2_0x7F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x70,Op_2_0x71,Op_2_0x72,Op_2_0x73,Op_2_0x74,Op_2_0x75,Op_2_0x76,Op_2_0x77,Op_2_0x78,Op_2_0x79,Op_2_0x7A,Op_2_0x7B,Op_2_0x7C,Op_2_0x7D,Op_2_0x7E,Op_2_0x7F,pseudo40);
pseudo40:asm volatile goto(".2byte (%l[Op_2_0x80]-0b)/2\n\t.2byte (%l[Op_2_0x81]-0b)/2\n\t.2byte (%l[Op_2_0x82]-0b)/2\n\t.2byte (%l[Op_2_0x83]-0b)/2\n\t.2byte (%l[Op_2_0x84]-0b)/2\n\t.2byte (%l[Op_2_0x85]-0b)/2\n\t.2byte (%l[Op_2_0x86]-0b)/2\n\t.2byte (%l[Op_2_0x87]-0b)/2\n\t.2byte (%l[Op_2_0x88]-0b)/2\n\t.2byte (%l[Op_2_0x89]-0b)/2\n\t.2byte (%l[Op_2_0x8A]-0b)/2\n\t.2byte (%l[Op_2_0x8B]-0b)/2\n\t.2byte (%l[Op_2_0x8C]-0b)/2\n\t.2byte (%l[Op_2_0x8D]-0b)/2\n\t.2byte (%l[Op_2_0x8E]-0b)/2\n\t.2byte (%l[Op_2_0x8F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x80,Op_2_0x81,Op_2_0x82,Op_2_0x83,Op_2_0x84,Op_2_0x85,Op_2_0x86,Op_2_0x87,Op_2_0x88,Op_2_0x89,Op_2_0x8A,Op_2_0x8B,Op_2_0x8C,Op_2_0x8D,Op_2_0x8E,Op_2_0x8F,pseudo41);
pseudo41:asm volatile goto(".2byte (%l[Op_2_0x90]-0b)/2\n\t.2byte (%l[Op_2_0x91]-0b)/2\n\t.2byte (%l[Op_2_0x92]-0b)/2\n\t.2byte (%l[Op_2_0x93]-0b)/2\n\t.2byte (%l[Op_2_0x94]-0b)/2\n\t.2byte (%l[Op_2_0x95]-0b)/2\n\t.2byte (%l[Op_2_0x96]-0b)/2\n\t.2byte (%l[Op_2_0x97]-0b)/2\n\t.2byte (%l[Op_2_0x98]-0b)/2\n\t.2byte (%l[Op_2_0x99]-0b)/2\n\t.2byte (%l[Op_2_0x9A]-0b)/2\n\t.2byte (%l[Op_2_0x9B]-0b)/2\n\t.2byte (%l[Op_2_0x9C]-0b)/2\n\t.2byte (%l[Op_2_0x9D]-0b)/2\n\t.2byte (%l[Op_2_0x9E]-0b)/2\n\t.2byte (%l[Op_2_0x9F]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0x90,Op_2_0x91,Op_2_0x92,Op_2_0x93,Op_2_0x94,Op_2_0x95,Op_2_0x96,Op_2_0x97,Op_2_0x98,Op_2_0x99,Op_2_0x9A,Op_2_0x9B,Op_2_0x9C,Op_2_0x9D,Op_2_0x9E,Op_2_0x9F,pseudo42);
pseudo42:asm volatile goto(".2byte (%l[Op_2_0xA0]-0b)/2\n\t.2byte (%l[Op_2_0xA1]-0b)/2\n\t.2byte (%l[Op_2_0xA2]-0b)/2\n\t.2byte (%l[Op_2_0xA3]-0b)/2\n\t.2byte (%l[Op_2_0xA4]-0b)/2\n\t.2byte (%l[Op_2_0xA5]-0b)/2\n\t.2byte (%l[Op_2_0xA6]-0b)/2\n\t.2byte (%l[Op_2_0xA7]-0b)/2\n\t.2byte (%l[Op_2_0xA8]-0b)/2\n\t.2byte (%l[Op_2_0xA9]-0b)/2\n\t.2byte (%l[Op_2_0xAA]-0b)/2\n\t.2byte (%l[Op_2_0xAB]-0b)/2\n\t.2byte (%l[Op_2_0xAC]-0b)/2\n\t.2byte (%l[Op_2_0xAD]-0b)/2\n\t.2byte (%l[Op_2_0xAE]-0b)/2\n\t.2byte (%l[Op_2_0xAF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xA0,Op_2_0xA1,Op_2_0xA2,Op_2_0xA3,Op_2_0xA4,Op_2_0xA5,Op_2_0xA6,Op_2_0xA7,Op_2_0xA8,Op_2_0xA9,Op_2_0xAA,Op_2_0xAB,Op_2_0xAC,Op_2_0xAD,Op_2_0xAE,Op_2_0xAF,pseudo43);
pseudo43:asm volatile goto(".2byte (%l[Op_2_0xB0]-0b)/2\n\t.2byte (%l[Op_2_0xB1]-0b)/2\n\t.2byte (%l[Op_2_0xB2]-0b)/2\n\t.2byte (%l[Op_2_0xB3]-0b)/2\n\t.2byte (%l[Op_2_0xB4]-0b)/2\n\t.2byte (%l[Op_2_0xB5]-0b)/2\n\t.2byte (%l[Op_2_0xB6]-0b)/2\n\t.2byte (%l[Op_2_0xB7]-0b)/2\n\t.2byte (%l[Op_2_0xB8]-0b)/2\n\t.2byte (%l[Op_2_0xB9]-0b)/2\n\t.2byte (%l[Op_2_0xBA]-0b)/2\n\t.2byte (%l[Op_2_0xBB]-0b)/2\n\t.2byte (%l[Op_2_0xBC]-0b)/2\n\t.2byte (%l[Op_2_0xBD]-0b)/2\n\t.2byte (%l[Op_2_0xBE]-0b)/2\n\t.2byte (%l[Op_2_0xBF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xB0,Op_2_0xB1,Op_2_0xB2,Op_2_0xB3,Op_2_0xB4,Op_2_0xB5,Op_2_0xB6,Op_2_0xB7,Op_2_0xB8,Op_2_0xB9,Op_2_0xBA,Op_2_0xBB,Op_2_0xBC,Op_2_0xBD,Op_2_0xBE,Op_2_0xBF,pseudo44);
pseudo44:asm volatile goto(".2byte (%l[Op_2_0xC0]-0b)/2\n\t.2byte (%l[Op_2_0xC1]-0b)/2\n\t.2byte (%l[Op_2_0xC2]-0b)/2\n\t.2byte (%l[Op_2_0xC3]-0b)/2\n\t.2byte (%l[Op_2_0xC4]-0b)/2\n\t.2byte (%l[Op_2_0xC5]-0b)/2\n\t.2byte (%l[Op_2_0xC6]-0b)/2\n\t.2byte (%l[Op_2_0xC7]-0b)/2\n\t.2byte (%l[Op_2_0xC8]-0b)/2\n\t.2byte (%l[Op_2_0xC9]-0b)/2\n\t.2byte (%l[Op_2_0xCA]-0b)/2\n\t.2byte (%l[Op_2_0xCB]-0b)/2\n\t.2byte (%l[Op_2_0xCC]-0b)/2\n\t.2byte (%l[Op_2_0xCD]-0b)/2\n\t.2byte (%l[Op_2_0xCE]-0b)/2\n\t.2byte (%l[Op_2_0xCF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xC0,Op_2_0xC1,Op_2_0xC2,Op_2_0xC3,Op_2_0xC4,Op_2_0xC5,Op_2_0xC6,Op_2_0xC7,Op_2_0xC8,Op_2_0xC9,Op_2_0xCA,Op_2_0xCB,Op_2_0xCC,Op_2_0xCD,Op_2_0xCE,Op_2_0xCF,pseudo45);
pseudo45:asm volatile goto(".2byte (%l[Op_2_0xD0]-0b)/2\n\t.2byte (%l[Op_2_0xD1]-0b)/2\n\t.2byte (%l[Op_2_0xD2]-0b)/2\n\t.2byte (%l[Op_2_0xD3]-0b)/2\n\t.2byte (%l[Op_2_0xD4]-0b)/2\n\t.2byte (%l[Op_2_0xD5]-0b)/2\n\t.2byte (%l[Op_2_0xD6]-0b)/2\n\t.2byte (%l[Op_2_0xD7]-0b)/2\n\t.2byte (%l[Op_2_0xD8]-0b)/2\n\t.2byte (%l[Op_2_0xD9]-0b)/2\n\t.2byte (%l[Op_2_0xDA]-0b)/2\n\t.2byte (%l[Op_2_0xDB]-0b)/2\n\t.2byte (%l[Op_2_0xDC]-0b)/2\n\t.2byte (%l[Op_2_0xDD]-0b)/2\n\t.2byte (%l[Op_2_0xDE]-0b)/2\n\t.2byte (%l[Op_2_0xDF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xD0,Op_2_0xD1,Op_2_0xD2,Op_2_0xD3,Op_2_0xD4,Op_2_0xD5,Op_2_0xD6,Op_2_0xD7,Op_2_0xD8,Op_2_0xD9,Op_2_0xDA,Op_2_0xDB,Op_2_0xDC,Op_2_0xDD,Op_2_0xDE,Op_2_0xDF,pseudo46);
pseudo46:asm volatile goto(".2byte (%l[Op_2_0xE0]-0b)/2\n\t.2byte (%l[Op_2_0xE1]-0b)/2\n\t.2byte (%l[Op_2_0xE2]-0b)/2\n\t.2byte (%l[Op_2_0xE3]-0b)/2\n\t.2byte (%l[Op_2_0xE4]-0b)/2\n\t.2byte (%l[Op_2_0xE5]-0b)/2\n\t.2byte (%l[Op_2_0xE6]-0b)/2\n\t.2byte (%l[Op_2_0xE7]-0b)/2\n\t.2byte (%l[Op_2_0xE8]-0b)/2\n\t.2byte (%l[Op_2_0xE9]-0b)/2\n\t.2byte (%l[Op_2_0xEA]-0b)/2\n\t.2byte (%l[Op_2_0xEB]-0b)/2\n\t.2byte (%l[Op_2_0xEC]-0b)/2\n\t.2byte (%l[Op_2_0xED]-0b)/2\n\t.2byte (%l[Op_2_0xEE]-0b)/2\n\t.2byte (%l[Op_2_0xEF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xE0,Op_2_0xE1,Op_2_0xE2,Op_2_0xE3,Op_2_0xE4,Op_2_0xE5,Op_2_0xE6,Op_2_0xE7,Op_2_0xE8,Op_2_0xE9,Op_2_0xEA,Op_2_0xEB,Op_2_0xEC,Op_2_0xED,Op_2_0xEE,Op_2_0xEF,pseudo47);
pseudo47:asm volatile goto(".2byte (%l[Op_2_0xF0]-0b)/2\n\t.2byte (%l[Op_2_0xF1]-0b)/2\n\t.2byte (%l[Op_2_0xF2]-0b)/2\n\t.2byte (%l[Op_2_0xF3]-0b)/2\n\t.2byte (%l[Op_2_0xF4]-0b)/2\n\t.2byte (%l[Op_2_0xF5]-0b)/2\n\t.2byte (%l[Op_2_0xF6]-0b)/2\n\t.2byte (%l[Op_2_0xF7]-0b)/2\n\t.2byte (%l[Op_2_0xF8]-0b)/2\n\t.2byte (%l[Op_2_0xF9]-0b)/2\n\t.2byte (%l[Op_2_0xFA]-0b)/2\n\t.2byte (%l[Op_2_0xFB]-0b)/2\n\t.2byte (%l[Op_2_0xFC]-0b)/2\n\t.2byte (%l[Op_2_0xFD]-0b)/2\n\t.2byte (%l[Op_2_0xFE]-0b)/2\n\t.2byte (%l[Op_2_0xFF]-0b)/2\n\t"::"r"(cop):"cc":Op_2_0xF0,Op_2_0xF1,Op_2_0xF2,Op_2_0xF3,Op_2_0xF4,Op_2_0xF5,Op_2_0xF6,Op_2_0xF7,Op_2_0xF8,Op_2_0xF9,Op_2_0xFA,Op_2_0xFB,Op_2_0xFC,Op_2_0xFD,Op_2_0xFE,Op_2_0xFF,pseudo48);
pseudo48:asm volatile goto(".2byte (%l[Op_3_0x00]-0b)/2\n\t.2byte (%l[Op_3_0x01]-0b)/2\n\t.2byte (%l[Op_3_0x02]-0b)/2\n\t.2byte (%l[Op_3_0x03]-0b)/2\n\t.2byte (%l[Op_3_0x04]-0b)/2\n\t.2byte (%l[Op_3_0x05]-0b)/2\n\t.2byte (%l[Op_3_0x06]-0b)/2\n\t.2byte (%l[Op_3_0x07]-0b)/2\n\t.2byte (%l[Op_3_0x08]-0b)/2\n\t.2byte (%l[Op_3_0x09]-0b)/2\n\t.2byte (%l[Op_3_0x0A]-0b)/2\n\t.2byte (%l[Op_3_0x0B]-0b)/2\n\t.2byte (%l[Op_3_0x0C]-0b)/2\n\t.2byte (%l[Op_3_0x0D]-0b)/2\n\t.2byte (%l[Op_3_0x0E]-0b)/2\n\t.2byte (%l[Op_3_0x0F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x00,Op_3_0x01,Op_3_0x02,Op_3_0x03,Op_3_0x04,Op_3_0x05,Op_3_0x06,Op_3_0x07,Op_3_0x08,Op_3_0x09,Op_3_0x0A,Op_3_0x0B,Op_3_0x0C,Op_3_0x0D,Op_3_0x0E,Op_3_0x0F,pseudo49);
pseudo49:asm volatile goto(".2byte (%l[Op_3_0x10]-0b)/2\n\t.2byte (%l[Op_3_0x11]-0b)/2\n\t.2byte (%l[Op_3_0x12]-0b)/2\n\t.2byte (%l[Op_3_0x13]-0b)/2\n\t.2byte (%l[Op_3_0x14]-0b)/2\n\t.2byte (%l[Op_3_0x15]-0b)/2\n\t.2byte (%l[Op_3_0x16]-0b)/2\n\t.2byte (%l[Op_3_0x17]-0b)/2\n\t.2byte (%l[Op_3_0x18]-0b)/2\n\t.2byte (%l[Op_3_0x19]-0b)/2\n\t.2byte (%l[Op_3_0x1A]-0b)/2\n\t.2byte (%l[Op_3_0x1B]-0b)/2\n\t.2byte (%l[Op_3_0x1C]-0b)/2\n\t.2byte (%l[Op_3_0x1D]-0b)/2\n\t.2byte (%l[Op_3_0x1E]-0b)/2\n\t.2byte (%l[Op_3_0x1F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x10,Op_3_0x11,Op_3_0x12,Op_3_0x13,Op_3_0x14,Op_3_0x15,Op_3_0x16,Op_3_0x17,Op_3_0x18,Op_3_0x19,Op_3_0x1A,Op_3_0x1B,Op_3_0x1C,Op_3_0x1D,Op_3_0x1E,Op_3_0x1F,pseudo50);
pseudo50:asm volatile goto(".2byte (%l[Op_3_0x20]-0b)/2\n\t.2byte (%l[Op_3_0x21]-0b)/2\n\t.2byte (%l[Op_3_0x22]-0b)/2\n\t.2byte (%l[Op_3_0x23]-0b)/2\n\t.2byte (%l[Op_3_0x24]-0b)/2\n\t.2byte (%l[Op_3_0x25]-0b)/2\n\t.2byte (%l[Op_3_0x26]-0b)/2\n\t.2byte (%l[Op_3_0x27]-0b)/2\n\t.2byte (%l[Op_3_0x28]-0b)/2\n\t.2byte (%l[Op_3_0x29]-0b)/2\n\t.2byte (%l[Op_3_0x2A]-0b)/2\n\t.2byte (%l[Op_3_0x2B]-0b)/2\n\t.2byte (%l[Op_3_0x2C]-0b)/2\n\t.2byte (%l[Op_3_0x2D]-0b)/2\n\t.2byte (%l[Op_3_0x2E]-0b)/2\n\t.2byte (%l[Op_3_0x2F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x20,Op_3_0x21,Op_3_0x22,Op_3_0x23,Op_3_0x24,Op_3_0x25,Op_3_0x26,Op_3_0x27,Op_3_0x28,Op_3_0x29,Op_3_0x2A,Op_3_0x2B,Op_3_0x2C,Op_3_0x2D,Op_3_0x2E,Op_3_0x2F,pseudo51);
pseudo51:asm volatile goto(".2byte (%l[Op_3_0x30]-0b)/2\n\t.2byte (%l[Op_3_0x31]-0b)/2\n\t.2byte (%l[Op_3_0x32]-0b)/2\n\t.2byte (%l[Op_3_0x33]-0b)/2\n\t.2byte (%l[Op_3_0x34]-0b)/2\n\t.2byte (%l[Op_3_0x35]-0b)/2\n\t.2byte (%l[Op_3_0x36]-0b)/2\n\t.2byte (%l[Op_3_0x37]-0b)/2\n\t.2byte (%l[Op_3_0x38]-0b)/2\n\t.2byte (%l[Op_3_0x39]-0b)/2\n\t.2byte (%l[Op_3_0x3A]-0b)/2\n\t.2byte (%l[Op_3_0x3B]-0b)/2\n\t.2byte (%l[Op_3_0x3C]-0b)/2\n\t.2byte (%l[Op_3_0x3D]-0b)/2\n\t.2byte (%l[Op_3_0x3E]-0b)/2\n\t.2byte (%l[Op_3_0x3F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x30,Op_3_0x31,Op_3_0x32,Op_3_0x33,Op_3_0x34,Op_3_0x35,Op_3_0x36,Op_3_0x37,Op_3_0x38,Op_3_0x39,Op_3_0x3A,Op_3_0x3B,Op_3_0x3C,Op_3_0x3D,Op_3_0x3E,Op_3_0x3F,pseudo52);
pseudo52:asm volatile goto(".2byte (%l[Op_3_0x40]-0b)/2\n\t.2byte (%l[Op_3_0x41]-0b)/2\n\t.2byte (%l[Op_3_0x42]-0b)/2\n\t.2byte (%l[Op_3_0x43]-0b)/2\n\t.2byte (%l[Op_3_0x44]-0b)/2\n\t.2byte (%l[Op_3_0x45]-0b)/2\n\t.2byte (%l[Op_3_0x46]-0b)/2\n\t.2byte (%l[Op_3_0x47]-0b)/2\n\t.2byte (%l[Op_3_0x48]-0b)/2\n\t.2byte (%l[Op_3_0x49]-0b)/2\n\t.2byte (%l[Op_3_0x4A]-0b)/2\n\t.2byte (%l[Op_3_0x4B]-0b)/2\n\t.2byte (%l[Op_3_0x4C]-0b)/2\n\t.2byte (%l[Op_3_0x4D]-0b)/2\n\t.2byte (%l[Op_3_0x4E]-0b)/2\n\t.2byte (%l[Op_3_0x4F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x40,Op_3_0x41,Op_3_0x42,Op_3_0x43,Op_3_0x44,Op_3_0x45,Op_3_0x46,Op_3_0x47,Op_3_0x48,Op_3_0x49,Op_3_0x4A,Op_3_0x4B,Op_3_0x4C,Op_3_0x4D,Op_3_0x4E,Op_3_0x4F,pseudo53);
pseudo53:asm volatile goto(".2byte (%l[Op_3_0x50]-0b)/2\n\t.2byte (%l[Op_3_0x51]-0b)/2\n\t.2byte (%l[Op_3_0x52]-0b)/2\n\t.2byte (%l[Op_3_0x53]-0b)/2\n\t.2byte (%l[Op_3_0x54]-0b)/2\n\t.2byte (%l[Op_3_0x55]-0b)/2\n\t.2byte (%l[Op_3_0x56]-0b)/2\n\t.2byte (%l[Op_3_0x57]-0b)/2\n\t.2byte (%l[Op_3_0x58]-0b)/2\n\t.2byte (%l[Op_3_0x59]-0b)/2\n\t.2byte (%l[Op_3_0x5A]-0b)/2\n\t.2byte (%l[Op_3_0x5B]-0b)/2\n\t.2byte (%l[Op_3_0x5C]-0b)/2\n\t.2byte (%l[Op_3_0x5D]-0b)/2\n\t.2byte (%l[Op_3_0x5E]-0b)/2\n\t.2byte (%l[Op_3_0x5F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x50,Op_3_0x51,Op_3_0x52,Op_3_0x53,Op_3_0x54,Op_3_0x55,Op_3_0x56,Op_3_0x57,Op_3_0x58,Op_3_0x59,Op_3_0x5A,Op_3_0x5B,Op_3_0x5C,Op_3_0x5D,Op_3_0x5E,Op_3_0x5F,pseudo54);
pseudo54:asm volatile goto(".2byte (%l[Op_3_0x60]-0b)/2\n\t.2byte (%l[Op_3_0x61]-0b)/2\n\t.2byte (%l[Op_3_0x62]-0b)/2\n\t.2byte (%l[Op_3_0x63]-0b)/2\n\t.2byte (%l[Op_3_0x64]-0b)/2\n\t.2byte (%l[Op_3_0x65]-0b)/2\n\t.2byte (%l[Op_3_0x66]-0b)/2\n\t.2byte (%l[Op_3_0x67]-0b)/2\n\t.2byte (%l[Op_3_0x68]-0b)/2\n\t.2byte (%l[Op_3_0x69]-0b)/2\n\t.2byte (%l[Op_3_0x6A]-0b)/2\n\t.2byte (%l[Op_3_0x6B]-0b)/2\n\t.2byte (%l[Op_3_0x6C]-0b)/2\n\t.2byte (%l[Op_3_0x6D]-0b)/2\n\t.2byte (%l[Op_3_0x6E]-0b)/2\n\t.2byte (%l[Op_3_0x6F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x60,Op_3_0x61,Op_3_0x62,Op_3_0x63,Op_3_0x64,Op_3_0x65,Op_3_0x66,Op_3_0x67,Op_3_0x68,Op_3_0x69,Op_3_0x6A,Op_3_0x6B,Op_3_0x6C,Op_3_0x6D,Op_3_0x6E,Op_3_0x6F,pseudo55);
pseudo55:asm volatile goto(".2byte (%l[Op_3_0x70]-0b)/2\n\t.2byte (%l[Op_3_0x71]-0b)/2\n\t.2byte (%l[Op_3_0x72]-0b)/2\n\t.2byte (%l[Op_3_0x73]-0b)/2\n\t.2byte (%l[Op_3_0x74]-0b)/2\n\t.2byte (%l[Op_3_0x75]-0b)/2\n\t.2byte (%l[Op_3_0x76]-0b)/2\n\t.2byte (%l[Op_3_0x77]-0b)/2\n\t.2byte (%l[Op_3_0x78]-0b)/2\n\t.2byte (%l[Op_3_0x79]-0b)/2\n\t.2byte (%l[Op_3_0x7A]-0b)/2\n\t.2byte (%l[Op_3_0x7B]-0b)/2\n\t.2byte (%l[Op_3_0x7C]-0b)/2\n\t.2byte (%l[Op_3_0x7D]-0b)/2\n\t.2byte (%l[Op_3_0x7E]-0b)/2\n\t.2byte (%l[Op_3_0x7F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x70,Op_3_0x71,Op_3_0x72,Op_3_0x73,Op_3_0x74,Op_3_0x75,Op_3_0x76,Op_3_0x77,Op_3_0x78,Op_3_0x79,Op_3_0x7A,Op_3_0x7B,Op_3_0x7C,Op_3_0x7D,Op_3_0x7E,Op_3_0x7F,pseudo56);
pseudo56:asm volatile goto(".2byte (%l[Op_3_0x80]-0b)/2\n\t.2byte (%l[Op_3_0x81]-0b)/2\n\t.2byte (%l[Op_3_0x82]-0b)/2\n\t.2byte (%l[Op_3_0x83]-0b)/2\n\t.2byte (%l[Op_3_0x84]-0b)/2\n\t.2byte (%l[Op_3_0x85]-0b)/2\n\t.2byte (%l[Op_3_0x86]-0b)/2\n\t.2byte (%l[Op_3_0x87]-0b)/2\n\t.2byte (%l[Op_3_0x88]-0b)/2\n\t.2byte (%l[Op_3_0x89]-0b)/2\n\t.2byte (%l[Op_3_0x8A]-0b)/2\n\t.2byte (%l[Op_3_0x8B]-0b)/2\n\t.2byte (%l[Op_3_0x8C]-0b)/2\n\t.2byte (%l[Op_3_0x8D]-0b)/2\n\t.2byte (%l[Op_3_0x8E]-0b)/2\n\t.2byte (%l[Op_3_0x8F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x80,Op_3_0x81,Op_3_0x82,Op_3_0x83,Op_3_0x84,Op_3_0x85,Op_3_0x86,Op_3_0x87,Op_3_0x88,Op_3_0x89,Op_3_0x8A,Op_3_0x8B,Op_3_0x8C,Op_3_0x8D,Op_3_0x8E,Op_3_0x8F,pseudo57);
pseudo57:asm volatile goto(".2byte (%l[Op_3_0x90]-0b)/2\n\t.2byte (%l[Op_3_0x91]-0b)/2\n\t.2byte (%l[Op_3_0x92]-0b)/2\n\t.2byte (%l[Op_3_0x93]-0b)/2\n\t.2byte (%l[Op_3_0x94]-0b)/2\n\t.2byte (%l[Op_3_0x95]-0b)/2\n\t.2byte (%l[Op_3_0x96]-0b)/2\n\t.2byte (%l[Op_3_0x97]-0b)/2\n\t.2byte (%l[Op_3_0x98]-0b)/2\n\t.2byte (%l[Op_3_0x99]-0b)/2\n\t.2byte (%l[Op_3_0x9A]-0b)/2\n\t.2byte (%l[Op_3_0x9B]-0b)/2\n\t.2byte (%l[Op_3_0x9C]-0b)/2\n\t.2byte (%l[Op_3_0x9D]-0b)/2\n\t.2byte (%l[Op_3_0x9E]-0b)/2\n\t.2byte (%l[Op_3_0x9F]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0x90,Op_3_0x91,Op_3_0x92,Op_3_0x93,Op_3_0x94,Op_3_0x95,Op_3_0x96,Op_3_0x97,Op_3_0x98,Op_3_0x99,Op_3_0x9A,Op_3_0x9B,Op_3_0x9C,Op_3_0x9D,Op_3_0x9E,Op_3_0x9F,pseudo58);
pseudo58:asm volatile goto(".2byte (%l[Op_3_0xA0]-0b)/2\n\t.2byte (%l[Op_3_0xA1]-0b)/2\n\t.2byte (%l[Op_3_0xA2]-0b)/2\n\t.2byte (%l[Op_3_0xA3]-0b)/2\n\t.2byte (%l[Op_3_0xA4]-0b)/2\n\t.2byte (%l[Op_3_0xA5]-0b)/2\n\t.2byte (%l[Op_3_0xA6]-0b)/2\n\t.2byte (%l[Op_3_0xA7]-0b)/2\n\t.2byte (%l[Op_3_0xA8]-0b)/2\n\t.2byte (%l[Op_3_0xA9]-0b)/2\n\t.2byte (%l[Op_3_0xAA]-0b)/2\n\t.2byte (%l[Op_3_0xAB]-0b)/2\n\t.2byte (%l[Op_3_0xAC]-0b)/2\n\t.2byte (%l[Op_3_0xAD]-0b)/2\n\t.2byte (%l[Op_3_0xAE]-0b)/2\n\t.2byte (%l[Op_3_0xAF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xA0,Op_3_0xA1,Op_3_0xA2,Op_3_0xA3,Op_3_0xA4,Op_3_0xA5,Op_3_0xA6,Op_3_0xA7,Op_3_0xA8,Op_3_0xA9,Op_3_0xAA,Op_3_0xAB,Op_3_0xAC,Op_3_0xAD,Op_3_0xAE,Op_3_0xAF,pseudo59);
pseudo59:asm volatile goto(".2byte (%l[Op_3_0xB0]-0b)/2\n\t.2byte (%l[Op_3_0xB1]-0b)/2\n\t.2byte (%l[Op_3_0xB2]-0b)/2\n\t.2byte (%l[Op_3_0xB3]-0b)/2\n\t.2byte (%l[Op_3_0xB4]-0b)/2\n\t.2byte (%l[Op_3_0xB5]-0b)/2\n\t.2byte (%l[Op_3_0xB6]-0b)/2\n\t.2byte (%l[Op_3_0xB7]-0b)/2\n\t.2byte (%l[Op_3_0xB8]-0b)/2\n\t.2byte (%l[Op_3_0xB9]-0b)/2\n\t.2byte (%l[Op_3_0xBA]-0b)/2\n\t.2byte (%l[Op_3_0xBB]-0b)/2\n\t.2byte (%l[Op_3_0xBC]-0b)/2\n\t.2byte (%l[Op_3_0xBD]-0b)/2\n\t.2byte (%l[Op_3_0xBE]-0b)/2\n\t.2byte (%l[Op_3_0xBF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xB0,Op_3_0xB1,Op_3_0xB2,Op_3_0xB3,Op_3_0xB4,Op_3_0xB5,Op_3_0xB6,Op_3_0xB7,Op_3_0xB8,Op_3_0xB9,Op_3_0xBA,Op_3_0xBB,Op_3_0xBC,Op_3_0xBD,Op_3_0xBE,Op_3_0xBF,pseudo60);
pseudo60:asm volatile goto(".2byte (%l[Op_3_0xC0]-0b)/2\n\t.2byte (%l[Op_3_0xC1]-0b)/2\n\t.2byte (%l[Op_3_0xC2]-0b)/2\n\t.2byte (%l[Op_3_0xC3]-0b)/2\n\t.2byte (%l[Op_3_0xC4]-0b)/2\n\t.2byte (%l[Op_3_0xC5]-0b)/2\n\t.2byte (%l[Op_3_0xC6]-0b)/2\n\t.2byte (%l[Op_3_0xC7]-0b)/2\n\t.2byte (%l[Op_3_0xC8]-0b)/2\n\t.2byte (%l[Op_3_0xC9]-0b)/2\n\t.2byte (%l[Op_3_0xCA]-0b)/2\n\t.2byte (%l[Op_3_0xCB]-0b)/2\n\t.2byte (%l[Op_3_0xCC]-0b)/2\n\t.2byte (%l[Op_3_0xCD]-0b)/2\n\t.2byte (%l[Op_3_0xCE]-0b)/2\n\t.2byte (%l[Op_3_0xCF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xC0,Op_3_0xC1,Op_3_0xC2,Op_3_0xC3,Op_3_0xC4,Op_3_0xC5,Op_3_0xC6,Op_3_0xC7,Op_3_0xC8,Op_3_0xC9,Op_3_0xCA,Op_3_0xCB,Op_3_0xCC,Op_3_0xCD,Op_3_0xCE,Op_3_0xCF,pseudo61);
pseudo61:asm volatile goto(".2byte (%l[Op_3_0xD0]-0b)/2\n\t.2byte (%l[Op_3_0xD1]-0b)/2\n\t.2byte (%l[Op_3_0xD2]-0b)/2\n\t.2byte (%l[Op_3_0xD3]-0b)/2\n\t.2byte (%l[Op_3_0xD4]-0b)/2\n\t.2byte (%l[Op_3_0xD5]-0b)/2\n\t.2byte (%l[Op_3_0xD6]-0b)/2\n\t.2byte (%l[Op_3_0xD7]-0b)/2\n\t.2byte (%l[Op_3_0xD8]-0b)/2\n\t.2byte (%l[Op_3_0xD9]-0b)/2\n\t.2byte (%l[Op_3_0xDA]-0b)/2\n\t.2byte (%l[Op_3_0xDB]-0b)/2\n\t.2byte (%l[Op_3_0xDC]-0b)/2\n\t.2byte (%l[Op_3_0xDD]-0b)/2\n\t.2byte (%l[Op_3_0xDE]-0b)/2\n\t.2byte (%l[Op_3_0xDF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xD0,Op_3_0xD1,Op_3_0xD2,Op_3_0xD3,Op_3_0xD4,Op_3_0xD5,Op_3_0xD6,Op_3_0xD7,Op_3_0xD8,Op_3_0xD9,Op_3_0xDA,Op_3_0xDB,Op_3_0xDC,Op_3_0xDD,Op_3_0xDE,Op_3_0xDF,pseudo62);
pseudo62:asm volatile goto(".2byte (%l[Op_3_0xE0]-0b)/2\n\t.2byte (%l[Op_3_0xE1]-0b)/2\n\t.2byte (%l[Op_3_0xE2]-0b)/2\n\t.2byte (%l[Op_3_0xE3]-0b)/2\n\t.2byte (%l[Op_3_0xE4]-0b)/2\n\t.2byte (%l[Op_3_0xE5]-0b)/2\n\t.2byte (%l[Op_3_0xE6]-0b)/2\n\t.2byte (%l[Op_3_0xE7]-0b)/2\n\t.2byte (%l[Op_3_0xE8]-0b)/2\n\t.2byte (%l[Op_3_0xE9]-0b)/2\n\t.2byte (%l[Op_3_0xEA]-0b)/2\n\t.2byte (%l[Op_3_0xEB]-0b)/2\n\t.2byte (%l[Op_3_0xEC]-0b)/2\n\t.2byte (%l[Op_3_0xED]-0b)/2\n\t.2byte (%l[Op_3_0xEE]-0b)/2\n\t.2byte (%l[Op_3_0xEF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xE0,Op_3_0xE1,Op_3_0xE2,Op_3_0xE3,Op_3_0xE4,Op_3_0xE5,Op_3_0xE6,Op_3_0xE7,Op_3_0xE8,Op_3_0xE9,Op_3_0xEA,Op_3_0xEB,Op_3_0xEC,Op_3_0xED,Op_3_0xEE,Op_3_0xEF,pseudo63);
pseudo63:asm volatile goto(".2byte (%l[Op_3_0xF0]-0b)/2\n\t.2byte (%l[Op_3_0xF1]-0b)/2\n\t.2byte (%l[Op_3_0xF2]-0b)/2\n\t.2byte (%l[Op_3_0xF3]-0b)/2\n\t.2byte (%l[Op_3_0xF4]-0b)/2\n\t.2byte (%l[Op_3_0xF5]-0b)/2\n\t.2byte (%l[Op_3_0xF6]-0b)/2\n\t.2byte (%l[Op_3_0xF7]-0b)/2\n\t.2byte (%l[Op_3_0xF8]-0b)/2\n\t.2byte (%l[Op_3_0xF9]-0b)/2\n\t.2byte (%l[Op_3_0xFA]-0b)/2\n\t.2byte (%l[Op_3_0xFB]-0b)/2\n\t.2byte (%l[Op_3_0xFC]-0b)/2\n\t.2byte (%l[Op_3_0xFD]-0b)/2\n\t.2byte (%l[Op_3_0xFE]-0b)/2\n\t.2byte (%l[Op_3_0xFF]-0b)/2\n\t"::"r"(cop):"cc":Op_3_0xF0,Op_3_0xF1,Op_3_0xF2,Op_3_0xF3,Op_3_0xF4,Op_3_0xF5,Op_3_0xF6,Op_3_0xF7,Op_3_0xF8,Op_3_0xF9,Op_3_0xFA,Op_3_0xFB,Op_3_0xFC,Op_3_0xFD,Op_3_0xFE,Op_3_0xFF,pseudo64);
pseudo64:asm volatile goto("1: .2byte ((1b-0b)*32)-1\n\t"::::Op_3_0xFF);
{

#else
  #define OPCASE_PFX(pfx, o) case ((pfx) << 8) + (o)

  // 1?, 2?, 5?, 6?, 7?, 8?, 9?, C?, 
#if 0
  printf("Op: %03x --- ", (unsigned)(PrefixSL8 + opcode));
  for(unsigned i = 0; i < 16; i++)
   printf("%04x ", R[i]);

  printf(" ROMBR=%02x", ROMBR);
  printf("\n");
#endif
  switch(PrefixSL8 + opcode)
  {
   default:
	SNES_DBG("[SuperFX] Unknown op 0x%03x\n", (unsigned)(PrefixSL8 + opcode));
	goto OpEnd;
#endif

  #define OPCASE(o) OPCASE_PFX(0, o): OPCASE_PFX(1, o): OPCASE_PFX(2, o): OPCASE_PFX(3, o)
  #define OPCASE_NP(o) OPCASE_PFX(0, o)
  #define OPCASE_3D(o) OPCASE_PFX(1, o)
  #define OPCASE_3E(o) OPCASE_PFX(2, o)
  #define OPCASE_3F(o) OPCASE_PFX(3, o)

   OPCASE_PFX(1, 0xDF):
   OPCASE_PFX(2, 0x30):
   OPCASE_PFX(2, 0x31):
   OPCASE_PFX(2, 0x32):
   OPCASE_PFX(2, 0x33):
   OPCASE_PFX(2, 0x34):
   OPCASE_PFX(2, 0x35):
   OPCASE_PFX(2, 0x36):
   OPCASE_PFX(2, 0x37):
   OPCASE_PFX(2, 0x38):
   OPCASE_PFX(2, 0x39):
   OPCASE_PFX(2, 0x3A):
   OPCASE_PFX(2, 0x3B):
   OPCASE_PFX(2, 0x40):
   OPCASE_PFX(2, 0x41):
   OPCASE_PFX(2, 0x42):
   OPCASE_PFX(2, 0x43):
   OPCASE_PFX(2, 0x44):
   OPCASE_PFX(2, 0x45):
   OPCASE_PFX(2, 0x46):
   OPCASE_PFX(2, 0x47):
   OPCASE_PFX(2, 0x48):
   OPCASE_PFX(2, 0x49):
   OPCASE_PFX(2, 0x4A):
   OPCASE_PFX(2, 0x4B):
   OPCASE_PFX(2, 0x4C):
   OPCASE_PFX(2, 0x4E):
   OPCASE_PFX(2, 0x96):
   OPCASE_PFX(2, 0x98):
   OPCASE_PFX(2, 0x99):
   OPCASE_PFX(2, 0x9A):
   OPCASE_PFX(2, 0x9B):
   OPCASE_PFX(2, 0x9C):
   OPCASE_PFX(2, 0x9D):
   OPCASE_PFX(2, 0x9F):
   OPCASE_PFX(3, 0x30):
   OPCASE_PFX(3, 0x31):
   OPCASE_PFX(3, 0x32):
   OPCASE_PFX(3, 0x33):
   OPCASE_PFX(3, 0x34):
   OPCASE_PFX(3, 0x35):
   OPCASE_PFX(3, 0x36):
   OPCASE_PFX(3, 0x37):
   OPCASE_PFX(3, 0x38):
   OPCASE_PFX(3, 0x39):
   OPCASE_PFX(3, 0x3A):
   OPCASE_PFX(3, 0x3B):
   OPCASE_PFX(3, 0x40):
   OPCASE_PFX(3, 0x41):
   OPCASE_PFX(3, 0x42):
   OPCASE_PFX(3, 0x43):
   OPCASE_PFX(3, 0x44):
   OPCASE_PFX(3, 0x45):
   OPCASE_PFX(3, 0x46):
   OPCASE_PFX(3, 0x47):
   OPCASE_PFX(3, 0x48):
   OPCASE_PFX(3, 0x49):
   OPCASE_PFX(3, 0x4A):
   OPCASE_PFX(3, 0x4B):
   OPCASE_PFX(3, 0x4C):
   OPCASE_PFX(3, 0x4E):
   OPCASE_PFX(3, 0x96):
   OPCASE_PFX(3, 0x98):
   OPCASE_PFX(3, 0x99):
   OPCASE_PFX(3, 0x9A):
   OPCASE_PFX(3, 0x9B):
   OPCASE_PFX(3, 0x9C):
   OPCASE_PFX(3, 0x9D):
   OPCASE_PFX(3, 0x9F):
   OPCASE_PFX(3, 0xA0):
   OPCASE_PFX(3, 0xA1):
   OPCASE_PFX(3, 0xA2):
   OPCASE_PFX(3, 0xA3):
   OPCASE_PFX(3, 0xA4):
   OPCASE_PFX(3, 0xA5):
   OPCASE_PFX(3, 0xA6):
   OPCASE_PFX(3, 0xA7):
   OPCASE_PFX(3, 0xA8):
   OPCASE_PFX(3, 0xA9):
   OPCASE_PFX(3, 0xAA):
   OPCASE_PFX(3, 0xAB):
   OPCASE_PFX(3, 0xAC):
   OPCASE_PFX(3, 0xAD):
   OPCASE_PFX(3, 0xAE):
   OPCASE_PFX(3, 0xAF):
   OPCASE_PFX(3, 0xF0):
   OPCASE_PFX(3, 0xF1):
   OPCASE_PFX(3, 0xF2):
   OPCASE_PFX(3, 0xF3):
   OPCASE_PFX(3, 0xF4):
   OPCASE_PFX(3, 0xF5):
   OPCASE_PFX(3, 0xF6):
   OPCASE_PFX(3, 0xF7):
   OPCASE_PFX(3, 0xF8):
   OPCASE_PFX(3, 0xF9):
   OPCASE_PFX(3, 0xFA):
   OPCASE_PFX(3, 0xFB):
   OPCASE_PFX(3, 0xFC):
   OPCASE_PFX(3, 0xFD):
   OPCASE_PFX(3, 0xFE):
   OPCASE_PFX(3, 0xFF):
   {

   }
   goto OpEnd;

   //
   // GETB
   //
   OPCASE_NP(0xEF):
   {
    uint8 tmp = GetROMBuffer();

    WriteR(Rd, tmp);
   }
   goto OpEnd;

   //
   // GETBH
   //
   OPCASE_3D(0xEF):
   {
    uint8 tmp = GetROMBuffer();

    WriteR(Rd, (ReadR(Rs) & 0x00FF) + (tmp << 8));
   }
   goto OpEnd;

   //
   // GETBL
   //
   OPCASE_3E(0xEF):
   {
    uint8 tmp = GetROMBuffer();

    WriteR(Rd, (ReadR(Rs) & 0xFF00) + (tmp << 0));
   }
   goto OpEnd;

   //
   // GETBS
   //
   OPCASE_3F(0xEF):
   {
    uint8 tmp = GetROMBuffer();

    WriteR(Rd, (int8)tmp);
   }
   goto OpEnd;

   //
   // LDB
   //
   OPCASE_3D(0x40): OPCASE_3D(0x41): OPCASE_3D(0x42): OPCASE_3D(0x43): OPCASE_3D(0x44): OPCASE_3D(0x45): OPCASE_3D(0x46): OPCASE_3D(0x47):
   OPCASE_3D(0x48): OPCASE_3D(0x49): OPCASE_3D(0x4A): OPCASE_3D(0x4B):
   {
    uint16 offs = R[opcode & 0xF];
    uint8 tmp;

    tmp = ReadRAM8(offs);
    LastRAMOffset = offs;

    WriteR(Rd, tmp);
   }
   goto OpEnd;

   //
   // LDW
   //
   OPCASE_NP(0x40): OPCASE_NP(0x41): OPCASE_NP(0x42): OPCASE_NP(0x43): OPCASE_NP(0x44): OPCASE_NP(0x45): OPCASE_NP(0x46): OPCASE_NP(0x47):
   OPCASE_NP(0x48): OPCASE_NP(0x49): OPCASE_NP(0x4A): OPCASE_NP(0x4B):
   {
    uint16 offs = R[opcode & 0xF];
    uint16 tmp;

    tmp = ReadRAM16(offs);
    LastRAMOffset = offs;

    WriteR(Rd, tmp);
   }
   goto OpEnd;

   //
   //  LM
   //
   OPCASE_3D(0xF0): OPCASE_3D(0xF1): OPCASE_3D(0xF2): OPCASE_3D(0xF3): OPCASE_3D(0xF4): OPCASE_3D(0xF5): OPCASE_3D(0xF6): OPCASE_3D(0xF7): OPCASE_3D(0xF8): OPCASE_3D(0xF9): OPCASE_3D(0xFA): OPCASE_3D(0xFB): OPCASE_3D(0xFC): OPCASE_3D(0xFD): OPCASE_3D(0xFE): OPCASE_3D(0xFF):
   {
    const uint16 offs = ReadOp16<EnableCache>();
    const uint16 tmp = ReadRAM16(offs);

    LastRAMOffset = offs;

    WriteR(opcode & 0xF, tmp);
   }
   goto OpEnd;

   //
   // LMS
   //
   OPCASE_3D(0xA0): OPCASE_3D(0xA1): OPCASE_3D(0xA2): OPCASE_3D(0xA3): OPCASE_3D(0xA4): OPCASE_3D(0xA5): OPCASE_3D(0xA6): OPCASE_3D(0xA7): OPCASE_3D(0xA8): OPCASE_3D(0xA9): OPCASE_3D(0xAA): OPCASE_3D(0xAB): OPCASE_3D(0xAC): OPCASE_3D(0xAD): OPCASE_3D(0xAE): OPCASE_3D(0xAF):
   {
    const uint16 offs = ReadOp<EnableCache>() << 1;
    const uint16 tmp = ReadRAM16(offs);

    //printf("%04x\n", offs);

    LastRAMOffset = offs;

    WriteR(opcode & 0xF, tmp);
   }
   goto OpEnd;

   //
   // STB
   //
   OPCASE_3D(0x30): OPCASE_3D(0x31): OPCASE_3D(0x32): OPCASE_3D(0x33): OPCASE_3D(0x34): OPCASE_3D(0x35): OPCASE_3D(0x36): OPCASE_3D(0x37):
   OPCASE_3D(0x38): OPCASE_3D(0x39): OPCASE_3D(0x3A): OPCASE_3D(0x3B):
   {
    WriteRAM8(R[opcode & 0xF], ReadR(Rs));
   }
   goto OpEnd;

   //
   // STW
   //
   OPCASE_NP(0x30): OPCASE_NP(0x31): OPCASE_NP(0x32): OPCASE_NP(0x33): OPCASE_NP(0x34): OPCASE_NP(0x35): OPCASE_NP(0x36): OPCASE_NP(0x37):
   OPCASE_NP(0x38): OPCASE_NP(0x39): OPCASE_NP(0x3A): OPCASE_NP(0x3B):
   {
    WriteRAM16(R[opcode & 0xF], ReadR(Rs));
   }
   goto OpEnd;

   //
   // SM
   //
   OPCASE_3E(0xF0): OPCASE_3E(0xF1): OPCASE_3E(0xF2): OPCASE_3E(0xF3): OPCASE_3E(0xF4): OPCASE_3E(0xF5): OPCASE_3E(0xF6): OPCASE_3E(0xF7): OPCASE_3E(0xF8): OPCASE_3E(0xF9): OPCASE_3E(0xFA): OPCASE_3E(0xFB): OPCASE_3E(0xFC): OPCASE_3E(0xFD): OPCASE_3E(0xFE): OPCASE_3E(0xFF):
   {
    const uint16 offs = ReadOp16<EnableCache>();

    WriteRAM16(offs, ReadR(opcode & 0xF));
   }
   goto OpEnd;

   //
   // SMS
   //
   OPCASE_3E(0xA0): OPCASE_3E(0xA1): OPCASE_3E(0xA2): OPCASE_3E(0xA3): OPCASE_3E(0xA4): OPCASE_3E(0xA5): OPCASE_3E(0xA6): OPCASE_3E(0xA7): OPCASE_3E(0xA8): OPCASE_3E(0xA9): OPCASE_3E(0xAA): OPCASE_3E(0xAB): OPCASE_3E(0xAC): OPCASE_3E(0xAD): OPCASE_3E(0xAE): OPCASE_3E(0xAF):
   {
    const uint16 offs = ReadOp<EnableCache>() << 1;

    WriteRAM16(offs, ReadR(opcode & 0xF));
   }
   goto OpEnd;

   //
   // SBK
   //
   OPCASE(0x90):
   {
    WriteRAM16(LastRAMOffset, ReadR(Rs));
   }
   goto OpEnd;

   //
   // IBT
   //
   OPCASE_NP(0xA0): OPCASE_NP(0xA1): OPCASE_NP(0xA2): OPCASE_NP(0xA3): OPCASE_NP(0xA4): OPCASE_NP(0xA5): OPCASE_NP(0xA6): OPCASE_NP(0xA7): OPCASE_NP(0xA8): OPCASE_NP(0xA9): OPCASE_NP(0xAA): OPCASE_NP(0xAB): OPCASE_NP(0xAC): OPCASE_NP(0xAD): OPCASE_NP(0xAE): OPCASE_NP(0xAF):
   {
    const uint8 imm = ReadOp<EnableCache>();

    WriteR(opcode & 0xF, (int8)imm);
   }
   goto OpEnd;

   //
   // IWT
   //
   OPCASE_NP(0xF0): OPCASE_NP(0xF1): OPCASE_NP(0xF2): OPCASE_NP(0xF3): OPCASE_NP(0xF4): OPCASE_NP(0xF5): OPCASE_NP(0xF6): OPCASE_NP(0xF7): OPCASE_NP(0xF8): OPCASE_NP(0xF9): OPCASE_NP(0xFA): OPCASE_NP(0xFB): OPCASE_NP(0xFC): OPCASE_NP(0xFD): OPCASE_NP(0xFE): OPCASE_NP(0xFF):
   {
    const uint16 imm = ReadOp16<EnableCache>();

    WriteR(opcode & 0xF, imm);
   }
   goto OpEnd;

   //
   // RAMB
   //
   OPCASE_3E(0xDF):
   {
    RAMBR = ReadR(Rs) & 0x1;
   }
   goto OpEnd;

   //
   // ROMB
   //
   OPCASE_3F(0xDF):
   {
    ROMBR = ReadR(Rs) & 0xFF;
//	assert(!(ROMBR & 0x80));
   }
   goto OpEnd;

   OPCASE_3D(0x4E): CMODE(); goto OpEnd;
   OPCASE_NP(0x4E): COLOR(); goto OpEnd;
   OPCASE_NP(0xDF): GETC(); goto OpEnd;
   OPCASE_NP(0x4C): PLOT(); goto OpEnd;
   OPCASE_3D(0x4C): RPIX(); goto OpEnd;

   //
   //
   //
   //
   //

   OPCASE(0x00): STOP(); superfx_timestamp = timestamp; goto OpEnd; // STOP
   OPCASE(0x01): goto OpEnd; // NOP
   OPCASE(0x02): CACHE<EnableCache>(); goto OpEnd; // CACHE

   OPCASE_NP(0x50): OPCASE_NP(0x51): OPCASE_NP(0x52): OPCASE_NP(0x53): OPCASE_NP(0x54): OPCASE_NP(0x55): OPCASE_NP(0x56): OPCASE_NP(0x57): OPCASE_NP(0x58): OPCASE_NP(0x59): OPCASE_NP(0x5A): OPCASE_NP(0x5B): OPCASE_NP(0x5C): OPCASE_NP(0x5D): OPCASE_NP(0x5E): OPCASE_NP(0x5F): ADD(ReadR(opcode & 0xF)); goto OpEnd;
   OPCASE_3E(0x50): OPCASE_3E(0x51): OPCASE_3E(0x52): OPCASE_3E(0x53): OPCASE_3E(0x54): OPCASE_3E(0x55): OPCASE_3E(0x56): OPCASE_3E(0x57): OPCASE_3E(0x58): OPCASE_3E(0x59): OPCASE_3E(0x5A): OPCASE_3E(0x5B): OPCASE_3E(0x5C): OPCASE_3E(0x5D): OPCASE_3E(0x5E): OPCASE_3E(0x5F): ADD(opcode & 0xF); goto OpEnd;

   OPCASE_3D(0x50): OPCASE_3D(0x51): OPCASE_3D(0x52): OPCASE_3D(0x53): OPCASE_3D(0x54): OPCASE_3D(0x55): OPCASE_3D(0x56): OPCASE_3D(0x57): OPCASE_3D(0x58): OPCASE_3D(0x59): OPCASE_3D(0x5A): OPCASE_3D(0x5B): OPCASE_3D(0x5C): OPCASE_3D(0x5D): OPCASE_3D(0x5E): OPCASE_3D(0x5F): ADC(ReadR(opcode & 0xF)); goto OpEnd;
   OPCASE_3F(0x50): OPCASE_3F(0x51): OPCASE_3F(0x52): OPCASE_3F(0x53): OPCASE_3F(0x54): OPCASE_3F(0x55): OPCASE_3F(0x56): OPCASE_3F(0x57): OPCASE_3F(0x58): OPCASE_3F(0x59): OPCASE_3F(0x5A): OPCASE_3F(0x5B): OPCASE_3F(0x5C): OPCASE_3F(0x5D): OPCASE_3F(0x5E): OPCASE_3F(0x5F): ADC(opcode & 0xF); goto OpEnd;

   OPCASE_NP(0x60): OPCASE_NP(0x61): OPCASE_NP(0x62): OPCASE_NP(0x63): OPCASE_NP(0x64): OPCASE_NP(0x65): OPCASE_NP(0x66): OPCASE_NP(0x67): OPCASE_NP(0x68): OPCASE_NP(0x69): OPCASE_NP(0x6A): OPCASE_NP(0x6B): OPCASE_NP(0x6C): OPCASE_NP(0x6D): OPCASE_NP(0x6E): OPCASE_NP(0x6F): SUB(ReadR(opcode & 0xF)); goto OpEnd;
   OPCASE_3E(0x60): OPCASE_3E(0x61): OPCASE_3E(0x62): OPCASE_3E(0x63): OPCASE_3E(0x64): OPCASE_3E(0x65): OPCASE_3E(0x66): OPCASE_3E(0x67): OPCASE_3E(0x68): OPCASE_3E(0x69): OPCASE_3E(0x6A): OPCASE_3E(0x6B): OPCASE_3E(0x6C): OPCASE_3E(0x6D): OPCASE_3E(0x6E): OPCASE_3E(0x6F): SUB(opcode & 0xF); goto OpEnd;

   OPCASE_3D(0x60): OPCASE_3D(0x61): OPCASE_3D(0x62): OPCASE_3D(0x63): OPCASE_3D(0x64): OPCASE_3D(0x65): OPCASE_3D(0x66): OPCASE_3D(0x67): OPCASE_3D(0x68): OPCASE_3D(0x69): OPCASE_3D(0x6A): OPCASE_3D(0x6B): OPCASE_3D(0x6C): OPCASE_3D(0x6D): OPCASE_3D(0x6E): OPCASE_3D(0x6F): SBC(ReadR(opcode & 0xF)); goto OpEnd;
   OPCASE_3F(0x60): OPCASE_3F(0x61): OPCASE_3F(0x62): OPCASE_3F(0x63): OPCASE_3F(0x64): OPCASE_3F(0x65): OPCASE_3F(0x66): OPCASE_3F(0x67): OPCASE_3F(0x68): OPCASE_3F(0x69): OPCASE_3F(0x6A): OPCASE_3F(0x6B): OPCASE_3F(0x6C): OPCASE_3F(0x6D): OPCASE_3F(0x6E): OPCASE_3F(0x6F): CMP(ReadR(opcode & 0xF)); goto OpEnd;

   /* AND Rn  */ OPCASE_NP(0x71): OPCASE_NP(0x72): OPCASE_NP(0x73): OPCASE_NP(0x74): OPCASE_NP(0x75): OPCASE_NP(0x76): OPCASE_NP(0x77):
   OPCASE_NP(0x78): OPCASE_NP(0x79): OPCASE_NP(0x7A): OPCASE_NP(0x7B): OPCASE_NP(0x7C): OPCASE_NP(0x7D): OPCASE_NP(0x7E): OPCASE_NP(0x7F):
	AND(ReadR(opcode & 0xF));
	goto OpEnd;

   /* AND #n     */ OPCASE_3E(0x71): OPCASE_3E(0x72): OPCASE_3E(0x73): OPCASE_3E(0x74): OPCASE_3E(0x75): OPCASE_3E(0x76): OPCASE_3E(0x77):
   OPCASE_3E(0x78): OPCASE_3E(0x79): OPCASE_3E(0x7A): OPCASE_3E(0x7B): OPCASE_3E(0x7C): OPCASE_3E(0x7D): OPCASE_3E(0x7E): OPCASE_3E(0x7F):
	AND(opcode & 0xF);
	goto OpEnd;

   /* BIC Rn     */ OPCASE_3D(0x71): OPCASE_3D(0x72): OPCASE_3D(0x73): OPCASE_3D(0x74): OPCASE_3D(0x75): OPCASE_3D(0x76): OPCASE_3D(0x77):
   OPCASE_3D(0x78): OPCASE_3D(0x79): OPCASE_3D(0x7A): OPCASE_3D(0x7B): OPCASE_3D(0x7C): OPCASE_3D(0x7D): OPCASE_3D(0x7E): OPCASE_3D(0x7F):
	BIC(ReadR(opcode & 0xF));
	goto OpEnd;

   /* BIC #n     */ OPCASE_3F(0x71): OPCASE_3F(0x72): OPCASE_3F(0x73): OPCASE_3F(0x74): OPCASE_3F(0x75): OPCASE_3F(0x76): OPCASE_3F(0x77):
   OPCASE_3F(0x78): OPCASE_3F(0x79): OPCASE_3F(0x7A): OPCASE_3F(0x7B): OPCASE_3F(0x7C): OPCASE_3F(0x7D): OPCASE_3F(0x7E): OPCASE_3F(0x7F):
	BIC(opcode & 0xF);
	goto OpEnd;

   /*  OR Rn  */ OPCASE_NP(0xC1): OPCASE_NP(0xC2): OPCASE_NP(0xC3): OPCASE_NP(0xC4): OPCASE_NP(0xC5): OPCASE_NP(0xC6): OPCASE_NP(0xC7):
   OPCASE_NP(0xC8): OPCASE_NP(0xC9): OPCASE_NP(0xCA): OPCASE_NP(0xCB): OPCASE_NP(0xCC): OPCASE_NP(0xCD): OPCASE_NP(0xCE): OPCASE_NP(0xCF):
	OR(ReadR(opcode & 0xF));
	goto OpEnd;

   /*  OR #n     */ OPCASE_3E(0xC1): OPCASE_3E(0xC2): OPCASE_3E(0xC3): OPCASE_3E(0xC4): OPCASE_3E(0xC5): OPCASE_3E(0xC6): OPCASE_3E(0xC7):
   OPCASE_3E(0xC8): OPCASE_3E(0xC9): OPCASE_3E(0xCA): OPCASE_3E(0xCB): OPCASE_3E(0xCC): OPCASE_3E(0xCD): OPCASE_3E(0xCE): OPCASE_3E(0xCF):
	OR(opcode & 0xF);
	goto OpEnd;

   /* XOR Rn     */ OPCASE_3D(0xC1): OPCASE_3D(0xC2): OPCASE_3D(0xC3): OPCASE_3D(0xC4): OPCASE_3D(0xC5): OPCASE_3D(0xC6): OPCASE_3D(0xC7):
   OPCASE_3D(0xC8): OPCASE_3D(0xC9): OPCASE_3D(0xCA): OPCASE_3D(0xCB): OPCASE_3D(0xCC): OPCASE_3D(0xCD): OPCASE_3D(0xCE): OPCASE_3D(0xCF):
	XOR(ReadR(opcode & 0xF));
	goto OpEnd;

   /* XOR #n     */ OPCASE_3F(0xC1): OPCASE_3F(0xC2): OPCASE_3F(0xC3): OPCASE_3F(0xC4): OPCASE_3F(0xC5): OPCASE_3F(0xC6): OPCASE_3F(0xC7):
   OPCASE_3F(0xC8): OPCASE_3F(0xC9): OPCASE_3F(0xCA): OPCASE_3F(0xCB): OPCASE_3F(0xCC): OPCASE_3F(0xCD): OPCASE_3F(0xCE): OPCASE_3F(0xCF):
	XOR(opcode & 0xF);
	goto OpEnd;

   OPCASE(0x4F): NOT(); goto OpEnd;

   OPCASE(0x03): LSR(); goto OpEnd; // LSR
   OPCASE_NP(0x96): ASR(); goto OpEnd; // ASR
   OPCASE(0x04): ROL(); goto OpEnd; // ROL
   OPCASE(0x97): ROR(); goto OpEnd; // ROR
   OPCASE_3D(0x96): DIV2(); goto OpEnd; // DIV2 (TODO: semantics!)

   //
   // INC
   //
   OPCASE(0xD0): OPCASE(0xD1): OPCASE(0xD2): OPCASE(0xD3): OPCASE(0xD4): OPCASE(0xD5): OPCASE(0xD6): OPCASE(0xD7):
   OPCASE(0xD8): OPCASE(0xD9): OPCASE(0xDA): OPCASE(0xDB): OPCASE(0xDC): OPCASE(0xDD): OPCASE(0xDE): //
   {
    INC(opcode & 0xF);
   }
   goto OpEnd;

   //
   // DEC
   //
   OPCASE(0xE0): OPCASE(0xE1): OPCASE(0xE2): OPCASE(0xE3): OPCASE(0xE4): OPCASE(0xE5): OPCASE(0xE6): OPCASE(0xE7):
   OPCASE(0xE8): OPCASE(0xE9): OPCASE(0xEA): OPCASE(0xEB): OPCASE(0xEC): OPCASE(0xED): OPCASE(0xEE): //
   {
    DEC(opcode & 0xF);
   }
   goto OpEnd;

   OPCASE(0x4D): SWAP(); goto OpEnd; // SWAP
   OPCASE(0x95): SEX(); goto OpEnd; // SEX
   OPCASE(0x9E): LOB(); goto OpEnd; // LOB
   OPCASE(0xC0): HIB(); goto OpEnd; // HIB
   OPCASE(0x70): MERGE(); goto OpEnd; // MERGE

   OPCASE_NP(0x9F): FMULT(); goto OpEnd; // FMULT
   OPCASE_3D(0x9F): LMULT(); goto OpEnd; // LMULT

   OPCASE_NP(0x80): OPCASE_NP(0x81): OPCASE_NP(0x82): OPCASE_NP(0x83): OPCASE_NP(0x84): OPCASE_NP(0x85): OPCASE_NP(0x86): OPCASE_NP(0x87): OPCASE_NP(0x88): OPCASE_NP(0x89): OPCASE_NP(0x8A): OPCASE_NP(0x8B): OPCASE_NP(0x8C): OPCASE_NP(0x8D): OPCASE_NP(0x8E): OPCASE_NP(0x8F): MULT(ReadR(opcode & 0xF)); goto OpEnd; // MULT Rn
   OPCASE_3E(0x80): OPCASE_3E(0x81): OPCASE_3E(0x82): OPCASE_3E(0x83): OPCASE_3E(0x84): OPCASE_3E(0x85): OPCASE_3E(0x86): OPCASE_3E(0x87): OPCASE_3E(0x88): OPCASE_3E(0x89): OPCASE_3E(0x8A): OPCASE_3E(0x8B): OPCASE_3E(0x8C): OPCASE_3E(0x8D): OPCASE_3E(0x8E): OPCASE_3E(0x8F): MULT(opcode & 0xF); goto OpEnd; // MULT #n

   OPCASE_3D(0x80): OPCASE_3D(0x81): OPCASE_3D(0x82): OPCASE_3D(0x83): OPCASE_3D(0x84): OPCASE_3D(0x85): OPCASE_3D(0x86): OPCASE_3D(0x87): OPCASE_3D(0x88): OPCASE_3D(0x89): OPCASE_3D(0x8A): OPCASE_3D(0x8B): OPCASE_3D(0x8C): OPCASE_3D(0x8D): OPCASE_3D(0x8E): OPCASE_3D(0x8F): UMULT(ReadR(opcode & 0xF)); goto OpEnd; // UMULT Rn
   OPCASE_3F(0x80): OPCASE_3F(0x81): OPCASE_3F(0x82): OPCASE_3F(0x83): OPCASE_3F(0x84): OPCASE_3F(0x85): OPCASE_3F(0x86): OPCASE_3F(0x87): OPCASE_3F(0x88): OPCASE_3F(0x89): OPCASE_3F(0x8A): OPCASE_3F(0x8B): OPCASE_3F(0x8C): OPCASE_3F(0x8D): OPCASE_3F(0x8E): OPCASE_3F(0x8F): UMULT(opcode & 0xF); goto OpEnd; // UMULT #n

   //
   // Relative branching
   //
   OPCASE(0x05): RelBranch<EnableCache>(true);	    goto SkipPrefixReset; // BRA
   OPCASE(0x06): RelBranch<EnableCache>(FlagS == FlagV); goto SkipPrefixReset; // BGE
   OPCASE(0x07): RelBranch<EnableCache>(FlagS != FlagV); goto SkipPrefixReset; // BLT
   OPCASE(0x08): RelBranch<EnableCache>(!FlagZ);	    goto SkipPrefixReset; // BNE
   OPCASE(0x09): RelBranch<EnableCache>( FlagZ);	    goto SkipPrefixReset; // BEQ
   OPCASE(0x0A): RelBranch<EnableCache>(!FlagS);	    goto SkipPrefixReset; // BPL
   OPCASE(0x0B): RelBranch<EnableCache>( FlagS);	    goto SkipPrefixReset; // BMI
   OPCASE(0x0C): RelBranch<EnableCache>(!FlagC);	    goto SkipPrefixReset; // BCC
   OPCASE(0x0D): RelBranch<EnableCache>( FlagC);	    goto SkipPrefixReset; // BCS
   OPCASE(0x0E): RelBranch<EnableCache>(!FlagV);	    goto SkipPrefixReset; // BVC
   OPCASE(0x0F): RelBranch<EnableCache>( FlagV);	    goto SkipPrefixReset; // BVS

   OPCASE_NP(0x98): OPCASE_NP(0x99): OPCASE_NP(0x9A): OPCASE_NP(0x9B): OPCASE_NP(0x9C): OPCASE_NP(0x9D): JMP(opcode & 0xF); goto OpEnd; // JMP
   OPCASE_3D(0x98): OPCASE_3D(0x99): OPCASE_3D(0x9A): OPCASE_3D(0x9B): OPCASE_3D(0x9C): OPCASE_3D(0x9D): LJMP<EnableCache>(opcode & 0xF); goto OpEnd; // LJMP

   OPCASE(0x3C): LOOP(); goto OpEnd; // LOOP
   OPCASE(0x91): OPCASE(0x92): OPCASE(0x93): OPCASE(0x94): LINK(opcode & 0xF); goto OpEnd; // LINK

   OPCASE(0x3D): PrefixSL8 |= 0x1 << 8; goto SkipPrefixReset; // ALT1
   OPCASE(0x3E): PrefixSL8 |= 0x2 << 8; goto SkipPrefixReset; // ALT2
   OPCASE(0x3F): PrefixSL8 |= 0x3 << 8; goto SkipPrefixReset; // ALT3

   //
   // TO/MOVE
   //
   OPCASE(0x10): OPCASE(0x11): OPCASE(0x12): OPCASE(0x13): OPCASE(0x14): OPCASE(0x15): OPCASE(0x16): OPCASE(0x17): OPCASE(0x18): OPCASE(0x19): OPCASE(0x1A): OPCASE(0x1B): OPCASE(0x1C): OPCASE(0x1D): OPCASE(0x1E): OPCASE(0x1F):
   {
    if(PrefixB)
    {
     //
     // MOVE
     //
     const uint16 tmp = ReadR(Rs);
     WriteR(opcode & 0xF, tmp);
    }
    else
    {
     //
     // TO
     //
     Rd = opcode & 0xF;
     goto SkipPrefixReset;	// TO
    }
   }
   goto OpEnd;

   //
   // WITH
   //
   OPCASE(0x20): OPCASE(0x21): OPCASE(0x22): OPCASE(0x23): OPCASE(0x24): OPCASE(0x25): OPCASE(0x26): OPCASE(0x27): OPCASE(0x28): OPCASE(0x29): OPCASE(0x2A): OPCASE(0x2B): OPCASE(0x2C): OPCASE(0x2D): OPCASE(0x2E): OPCASE(0x2F):
   {
    Rs = Rd = opcode & 0xF;
    PrefixB = true;
   }
   goto SkipPrefixReset;

   //
   // FROM/MOVES
   //
   OPCASE(0xB0): OPCASE(0xB1): OPCASE(0xB2): OPCASE(0xB3): OPCASE(0xB4): OPCASE(0xB5): OPCASE(0xB6): OPCASE(0xB7): OPCASE(0xB8): OPCASE(0xB9): OPCASE(0xBA): OPCASE(0xBB): OPCASE(0xBC): OPCASE(0xBD): OPCASE(0xBE): OPCASE(0xBF):
   {
    if(PrefixB)
    {
     //
     // MOVES
     //
     const uint16 tmp = ReadR(opcode & 0xF);

     FlagV = (bool)(tmp & 0x80);
     CalcSZ(tmp);

     WriteR(Rd, tmp);
    }
    else
    {
     //
     // FROM
     //
     Rs = opcode & 0xF;
     goto SkipPrefixReset;
    }
   }
   goto OpEnd;
  }
  //
  OpEnd:;
  Rs = 0;
  Rd = 0;
  PrefixSL8 = 0;
  PrefixB = false;
  //
  SkipPrefixReset:;
 }
}

template<bool EnableCache>
static uint32 EventHandler(uint32 master_timestamp)
{
 {
  int32 tmp;

  tmp = ((master_timestamp - SFX.last_master_timestamp) * SFX.clock_multiplier) + SFX.run_count_mod;
  SFX.last_master_timestamp = master_timestamp;
  SFX.run_count_mod  = (uint16)tmp;
  SFX.superfx_timestamp_run_until += tmp >> 16;
 }
 //
 SFX.Update<EnableCache>(SFX.superfx_timestamp_run_until);
 //
 return master_timestamp + (EnableCache ? 128 : 192);
}

static void AdjustTS(int32 delta)
{
/*
 SFX.superfx_timestamp += delta;

 SFX.pixcache_write_finish_ts = std::max<int64>(0, (int64)SFX.pixcache_write_finish_ts + delta);
 SFX.rom_read_finish_ts = std::max<int64>(0, (int64)SFX.rom_read_finish_ts + delta);
 SFX.ram_write_finish_ts = std::max<int64>(0, (int64)SFX.ram_write_finish_ts + delta);
*/
 SFX.last_master_timestamp += delta;

 SFX.pixcache_write_finish_ts = std::max<int64>(0, (int64)SFX.pixcache_write_finish_ts - SFX.superfx_timestamp_run_until);
 SFX.rom_read_finish_ts = std::max<int64>(0, (int64)SFX.rom_read_finish_ts - SFX.superfx_timestamp_run_until);
 SFX.ram_write_finish_ts = std::max<int64>(0, (int64)SFX.ram_write_finish_ts - SFX.superfx_timestamp_run_until);
 assert(SFX.superfx_timestamp >= SFX.superfx_timestamp_run_until);
 SFX.superfx_timestamp -= SFX.superfx_timestamp_run_until;
 SFX.superfx_timestamp_run_until = 0;
}

static MDFN_COLD void Reset(bool powering_up)
{
 SFX.Running = false;

 memset(SFX.R, 0, sizeof(SFX.R));
 SFX.Prefetch = 0;
 SFX.PrefixSL8 = 0;
 SFX.PrefixB = false;
 SFX.Rs = 0;
 SFX.Rd = 0;

 SFX.SetPBR(0x00); //PBR = 0;
 SFX.SetCBR<true>(0x0000); //CBR = 0;
 SFX.ROMBR = 0;
 SFX.RAMBR = 0;

 SFX.SetCLSR(0x00); //ClockSelect = false;
 SFX.SetCFGR(0x00); //MultSpeed = false;
                  //IRQMask = false;
 

 SFX.SCBR = 0;
 SFX.SCMR = 0;
 SFX.POR = 0;
 SFX.ColorData = 0;

 memset(&SFX.PixelCache, 0, sizeof(SFX.PixelCache));

 memset(SFX.CacheData, 0, sizeof(SFX.CacheData));
 memset(SFX.CacheValid, 0, sizeof(SFX.CacheValid));

 SFX.ROMBuffer = 0;
 SFX.LastRAMOffset = 0;

 SFX.FlagV = false;
 SFX.FlagS = false;
 SFX.FlagC = false;
 SFX.FlagZ = false;

 SFX.Running = false;
 SFX.IRQPending = false;

 SFX.GPRWriteLatch = 0;
 //
 //
 SFX.last_master_timestamp = CPUM.timestamp;
 SFX.run_count_mod = 0;
 SFX.superfx_timestamp_run_until = 0;
 //
 SFX.superfx_timestamp = 0;
 SFX.rom_read_finish_ts = SFX.superfx_timestamp;
 SFX.ram_write_finish_ts = SFX.superfx_timestamp;
 SFX.pixcache_write_finish_ts = SFX.superfx_timestamp;
}

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(MainCPU_ReadLoROM)
{
 //if(MDFN_UNLIKELY(DBG_InHLRead))
 //{
 // return (Cart.ROM + rom_offset)[(A & 0x7FFF) | ((A >> 1) & 0x3F8000)];
 //}
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  if(cyc >= 0)
   CPUM.timestamp += cyc;
  else
   CPUM.timestamp += CPUM.MemSelectCycles;
 }

 return (Cart.ROM + rom_offset)[(A & 0x7FFF) | ((A >> 1) & 0x3F8000)];
}

template<signed cyc, unsigned rom_offset = 0>
static DEFREAD(MainCPU_ReadHiROM)
{
 //if(MDFN_UNLIKELY(DBG_InHLRead))
 //{
  //return (Cart.ROM + rom_offset)[A & 0x3FFFFF];
 //}

 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  if(cyc >= 0)
   CPUM.timestamp += cyc;
  else
   CPUM.timestamp += CPUM.MemSelectCycles;
 }

 return (Cart.ROM + rom_offset)[A & 0x3FFFFF];
}

static DEFREAD(MainCPU_ReadRAM8K)
{
 if(SFX.Running && (SFX.SCMR & 0x18) == 0x18)
  SNES_DBG("[SuperFX] RAM read while SuperFX is running: %06x\n", A);

 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const size_t raw_sram_index = (A & 0x1FFF);

 return Cart.RAM[raw_sram_index & Cart.RAM_Mask];
}

static DEFWRITE(MainCPU_WriteRAM8K)
{
 if(SFX.Running && (SFX.SCMR & 0x18) == 0x18)
  SNES_DBG("[SuperFX] RAM write while SuperFX is running: %06x %02x\n", A, V);

 CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const size_t raw_sram_index = (A & 0x1FFF);

 Cart.RAM[raw_sram_index & Cart.RAM_Mask] = V;
}

static DEFREAD(MainCPU_ReadRAM)
{
 if(SFX.Running && (SFX.SCMR & 0x18) == 0x18)
  SNES_DBG("[SuperFX] RAM read while SuperFX is running: %06x\n", A);

 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const size_t raw_sram_index = A & 0x1FFFF;

 return Cart.RAM[raw_sram_index & Cart.RAM_Mask];
}

static DEFWRITE(MainCPU_WriteRAM)
{
 if(SFX.Running && (SFX.SCMR & 0x18) == 0x18)
  SNES_DBG("[SuperFX] RAM write while SuperFX is running: %06x %02x\n", A, V);

 CPUM.timestamp += MEMCYC_SLOW;
 //
 //
 const size_t raw_sram_index = A & 0x1FFFF;

 Cart.RAM[raw_sram_index & Cart.RAM_Mask] = V;
}


static DEFREAD(MainCPU_ReadGPR)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_FAST;
 //
 //
 return ne16_rbo_le<uint8>(SFX.R, A & 0x1F);
}

static DEFWRITE(MainCPU_WriteGPR)
{
 if(SFX.Running && (SFX.SCMR & 0x18) == 0x18)
  SNES_DBG("[SuperFX] GPR write while SuperFX is running: %06x %02x\n", A, V);

 CPUM.timestamp += MEMCYC_FAST;
 //
 //
 //SNES_DBG("[SuperFX] Write GPR 0x%06x 0x%02x\n", A, V);
 if(A & 0x1)
 {
  const size_t index = (A >> 1) & 0xF;
  const uint16 tmp = (V << 8) + SFX.GPRWriteLatch;

  SFX.R[index] = tmp;

  if(index == 0xF)
  {
   SFX.Prefetch = 0x01;
   SFX.Running = true;
   SFX.PrefixSL8 = 0;
   SFX.PrefixB = 0;
   SFX.Rs = 0;
   SFX.Rd = 0;
   //assert((bool)tmp == (bool)(SCMR & 0x10));
  }
 }
 else
  SFX.GPRWriteLatch = V;
}

template<unsigned T_A>
static DEFREAD(MainCPU_ReadIO)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_FAST;
 //
 //
 uint8 ret = 0;

 switch(T_A & 0xF)
 {
  default:
	SNES_DBG("[SuperFX] Unknown read 0x%06x\n", A);
	break;

  case 0x0:
	ret = (SFX.FlagZ << 1) | (SFX.FlagC << 2) | (SFX.FlagS << 3) | (SFX.FlagV << 4) | (SFX.Running << 5);
	break;

  case 0x1:
	ret = ((SFX.PrefixSL8 >> 8) & 0x3) | (SFX.PrefixB << 4) | (SFX.IRQPending << 7);
	if(MDFN_LIKELY(!DBG_InHLRead))
	{
	 SFX.IRQPending = false;
	 CPU_SetIRQ(false, CPU_IRQSOURCE_CART);
	}
	break;

  case 0x4:
	ret = SFX.PBR;
	break;

  case 0x6:
	ret = SFX.ROMBR;
	break;

  case 0xB:
	ret = SFX.VCR;
	break;

  case 0xC:
	ret = SFX.RAMBR;
	break;

  case 0xE:
	ret = SFX.CBR;
	break;

  case 0xF:
	ret = SFX.CBR >> 8;
	break;
 }

 return ret;
}

template<unsigned T_A>
static DEFWRITE(MainCPU_WriteIO)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 //
 //SNES_DBG("[SuperFX] IO write 0x%06x 0x%02x\n", A, V);

 switch(T_A & 0xF)
 {
  default:
	SNES_DBG("[SuperFX] Unknown write 0x%06x 0x%02x\n", A, V);
	break;

  case 0x0:
	SFX.FlagZ = (bool)(V & 0x02);
	SFX.FlagC = (bool)(V & 0x04);
	SFX.FlagS = (bool)(V & 0x08);
	SFX.FlagV = (bool)(V & 0x10);
	SFX.Running = (bool)(V & 0x20);
	if(!SFX.Running)
	 SFX.SetCBR<true>(0x0000);
	break;
/*
  case 0x1:
	PrefixSL8 = (V & 0x03) << 8;
	PrefixB = (V >> 4) & 1;
	break;
*/
  case 0x4:
	SFX.SetPBR(V);
	break;

  case 0x7:
	SFX.SetCFGR(V);
	break;

  case 0x8:
	SFX.SCBR = V & 0x3F;
	break;

  case 0x9:
	SFX.SetCLSR(V);
	break;

  case 0xA:
	SFX.SCMR = V;
	break;
 }
}

static DEFREAD(MainCPU_ReadCache)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_FAST;
 //
 //
 SNES_DBG("[SuperFX] Cache read %06x\n", A);
 return SFX.CacheData[A & 0x1FF];
}

static DEFWRITE(MainCPU_WriteCache)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 //
 SNES_DBG("[SuperFX] Cache write %06x %02x\n", A, V);
 const size_t index = A & 0x1FF;

 SFX.CacheData[index] = V;
 SFX.CacheValid[index >> 4] |= ((A & 0xF) == 0xF);
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 bool EnableICache = SFX.EnableICache;
 uint16 PrefixSL8 = SFX.PrefixSL8;

 SFORMAT StateRegs[] =
 {
  SFVARN(SFX.R, "R"),
  SFVARN(SFX.Prefetch, "Prefetch"),
  SFVAR(PrefixSL8),
  SFVARN(SFX.PrefixB, "PrefixB"),

  SFVARN(SFX.Rs, "Rs"),
  SFVARN(SFX.Rd, "Rd"),

  SFVARN(SFX.PBR, "PBR"),
  SFVARN(SFX.CBR, "CBR"),
  SFVARN(SFX.ROMBR, "ROMBR"),
  SFVARN(SFX.RAMBR, "RAMBR"),
  SFVARN(SFX.ClockSelect, "ClockSelect"),
  SFVARN(SFX.MultSpeed, "MultSpeed"),

  SFVARN(SFX.SCBR, "SCBR"),
  SFVARN(SFX.SCMR, "SCMR"),
  SFVARN(SFX.POR, "POR"),
  SFVARN(SFX.ColorData, "ColorData"),

  SFVARN(SFX.PixelCache.TagX, "PixelCache.TagX"),
  SFVARN(SFX.PixelCache.TagY, "PixelCache.TagY"),
  SFVARN(SFX.PixelCache.data, "PixelCache.data"),
  SFVARN(SFX.PixelCache.opaque, "PixelCache.opaque"),

  SFVARN(SFX.CacheData, "CacheData"),
  SFVARN(SFX.CacheValid, "CacheValid"),

  SFVARN(SFX.ROMBuffer, "ROMBuffer"),

  SFVARN(SFX.LastRAMOffset, "LastRAMOffset"),

  SFVARN(SFX.FlagV, "FlagV"),
  SFVARN(SFX.FlagS, "FlagS"),
  SFVARN(SFX.FlagC, "FlagC"),
  SFVARN(SFX.FlagZ, "FlagZ"),
  SFVARN(SFX.Running, "Running"),
  SFVARN(SFX.IRQPending, "IRQPending"),
  SFVARN(SFX.IRQMask, "IRQMask"),

  SFVARN(SFX.GPRWriteLatch, "GPRWriteLatch"),
  //
  // FIXME: save states in debugger:?
  SFVARN(SFX.run_count_mod, "run_count_mod"),
  SFVARN(SFX.superfx_timestamp, "superfx_timestamp"),
  SFVARN(SFX.rom_read_finish_ts, "rom_read_finish_ts"),
  SFVARN(SFX.ram_write_finish_ts, "ram_write_finish_ts"),
  SFVARN(SFX.pixcache_write_finish_ts, "pixcache_write_finish_ts"),

  SFVAR(EnableICache),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SuperFX");

 if(load)
 {
  SFX.PrefixSL8 = PrefixSL8 & (0x03 << 8);

  SFX.SetCLSR(SFX.ClockSelect);
  SFX.SetPBR(SFX.PBR);

  if(EnableICache != SFX.EnableICache)
  {
   memset(SFX.CacheValid, 0, sizeof(SFX.CacheValid));
  }
 }
}

void CART_SuperFX_Init(const int32 master_clock, const int32 ocmultiplier, const bool enable_icache)
{
 assert(Cart.RAM_Size);

 SFX.EnableICache = enable_icache;
 memcpy(SFX.tnoshtab, tnoshtab_init, sizeof(SFX.tnoshtab));
 memcpy(SFX.wtt, wtt_init, sizeof(SFX.wtt));
 memcpy(SFX.masktab, masktab_init, sizeof(SFX.masktab));
 SFX.RAM = &Cart.RAM[0];
 SFX.RAM_Mask = Cart.RAM_Mask;

 SFX.clock_multiplier = ocmultiplier;
 SFX.last_master_timestamp = 0;
 SFX.superfx_timestamp_run_until = 0;
 SFX.run_count_mod = 0;
 SFX.superfx_timestamp = 0;
 SFX.rom_read_finish_ts = 0;
 SFX.ram_write_finish_ts = 0;
 SFX.pixcache_write_finish_ts = 0;

 SFX.VCR = 0x04;

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(!(bank & 0x40))
  {
   Set_A_Handlers((bank << 16) | 0x3000, (bank << 16) | 0x301F, MainCPU_ReadGPR, MainCPU_WriteGPR);

   #define SHP(a, ta) Set_A_Handlers((bank << 16) | a, MainCPU_ReadIO<ta>, MainCPU_WriteIO<ta>);
   SHP(0x3030, 0x0)
   SHP(0x3031, 0x1)
   SHP(0x3032, 0x2)
   SHP(0x3033, 0x3)
   SHP(0x3034, 0x4)
   SHP(0x3035, 0x5)
   SHP(0x3036, 0x6)
   SHP(0x3037, 0x7)
   SHP(0x3038, 0x8)
   SHP(0x3039, 0x9)
   SHP(0x303A, 0xA)
   SHP(0x303B, 0xB)
   SHP(0x303C, 0xC)
   SHP(0x303D, 0xD)
   SHP(0x303E, 0xE)
   SHP(0x303F, 0xF)
   #undef SHP

   Set_A_Handlers((bank << 16) | 0x3100, (bank << 16) | 0x32FF, MainCPU_ReadCache, MainCPU_WriteCache);
   Set_A_Handlers((bank << 16) | 0x3300, (bank << 16) | 0x34FF, MainCPU_ReadCache, MainCPU_WriteCache);

   Set_A_Handlers((bank << 16) | 0x6000, (bank << 16) | 0x7FFF, MainCPU_ReadRAM8K, MainCPU_WriteRAM8K);
  }

  if(bank < 0x40)
  {
   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, MainCPU_ReadLoROM<MEMCYC_SLOW>, OBWrite_SLOW);
  }
  else if(bank < 0x60)
  {
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, MainCPU_ReadHiROM<MEMCYC_SLOW>, OBWrite_SLOW);
  }
  else if(bank < 0x70)
  {
   //Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, MainCPU_ReadHiROM<MEMCYC_SLOW>, OBWrite_SLOW);
  }
  else if(bank == 0x70 || bank == 0x71)
  {
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, MainCPU_ReadRAM, MainCPU_WriteRAM);
  }
  else if(bank >= 0x80 && bank < 0xC0)
  {
   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, MainCPU_ReadLoROM<-1, 0x200000>, OBWrite_VAR);
  }
  else if(bank >= 0xC0)
  {
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, MainCPU_ReadHiROM<-1, 0x200000>, OBWrite_VAR);
  }
 }
 //
 //
 //
 for(unsigned bank = 0x00; bank < 0x80; bank++)
 {
  static const uint8 dummy = 0xFF;
  const uint8* p = &dummy;
  size_t m = 0;

  if(bank < 0x40)
  {
   p = &Cart.ROM[bank << 15];
   m = 0x7FFF;
  }
  else if(bank < 0x60)
  {
   p = &Cart.ROM[((bank - 0x40) & 0x1F) << 16];
   m = 0xFFFF;
  }
  else if(bank < 0x80)
  {
   if(Cart.RAM)
   {
    p = &Cart.RAM[(bank << 16) & Cart.RAM_Mask];
    m = 0xFFFF & Cart.RAM_Mask;
   }
  }
  SFX.ProgMemMap[bank] = p;
  SFX.ProgMemMapMask[bank] = m;
 }
 //
 //
 //
 Cart.AdjustTS = AdjustTS;
 Cart.EventHandler = enable_icache ? EventHandler<true> : EventHandler<false>;
 Cart.Reset = Reset;
 Cart.StateAction = StateAction;
}

}
