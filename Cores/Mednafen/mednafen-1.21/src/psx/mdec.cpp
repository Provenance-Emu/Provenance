/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* mdec.cpp:
**  Copyright (C) 2011-2016 Mednafen Team
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

#pragma GCC optimize ("unroll-loops")

/*
 MDEC_READ_FIFO(tfr) vs InCounter vs MDEC_DMACanRead() is a bit fragile right now.  Actually, the entire horrible state machine monstrosity is fragile.

 TODO: OutFIFOReady, so <16bpp works right.

 TODO CODE:

  bool InFIFOReady;

  if(InFIFO.CanWrite())
  {
   InFIFO.Write(V);

   if(InCommand)
   {
    if(InCounter != 0xFFFF)
    {
     InCounter--;

     // This condition when InFIFO.CanWrite() != 0 is a bit buggy on real hardware, decoding loop *seems* to be reading too
     // much and pulling garbage from the FIFO.
     if(InCounter == 0xFFFF)	
      InFIFOReady = true;
    }

    if(InFIFO.CanWrite() == 0)
     InFIFOReady = true;
   }
  }
*/

// Good test-case games:
//	Dragon Knight 4(bad disc?)
//	Final Fantasy 7 intro movie.
//	GameShark Version 4.0 intro movie; (clever) abuse of DMA channel 0.
//	SimCity 2000 startup.


#include "psx.h"
#include "mdec.h"
#include "FastFIFO.h"

#if defined(__SSE2__) || (defined(ARCH_X86) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 9)))
#include <xmmintrin.h>
#include <emmintrin.h>
#endif

#if 0 //defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

#if defined(ARCH_POWERPC_ALTIVEC) && defined(HAVE_ALTIVEC_H)
 #include <altivec.h>
#endif

namespace MDFN_IEN_PSX
{

static int32 ClockCounter;
static unsigned MDRPhase;
static FastFIFO<uint32, 0x20> InFIFO;
static FastFIFO<uint32, 0x20> OutFIFO;

static int8 block_y[8][8];
static int8 block_cb[8][8];	// [y >> 1][x >> 1]
static int8 block_cr[8][8];	// [y >> 1][x >> 1]

static uint32 Control;
static uint32 Command;
static bool InCommand;

static uint8 QMatrix[2][64];
static uint32 QMIndex;

alignas(16) static int16 IDCTMatrix[64];
static uint32 IDCTMIndex;

static uint8 QScale;

alignas(16) static int16 Coeff[64];
static uint32 CoeffIndex;
static uint32 DecodeWB;

static union
{
 uint32 pix32[48];
 uint16 pix16[96];
 uint8   pix8[192];
} PixelBuffer;
static uint32 PixelBufferReadOffset;
static uint32 PixelBufferCount32;

static uint16 InCounter;

static uint8 RAMOffsetY;
static uint8 RAMOffsetCounter;
static uint8 RAMOffsetWWS;

static const uint8 ZigZag[64] =
{
 0x00, 0x08, 0x01, 0x02, 0x09, 0x10, 0x18, 0x11, 
 0x0a, 0x03, 0x04, 0x0b, 0x12, 0x19, 0x20, 0x28, 
 0x21, 0x1a, 0x13, 0x0c, 0x05, 0x06, 0x0d, 0x14, 
 0x1b, 0x22, 0x29, 0x30, 0x38, 0x31, 0x2a, 0x23, 
 0x1c, 0x15, 0x0e, 0x07, 0x0f, 0x16, 0x1d, 0x24, 
 0x2b, 0x32, 0x39, 0x3a, 0x33, 0x2c, 0x25, 0x1e, 
 0x17, 0x1f, 0x26, 0x2d, 0x34, 0x3b, 0x3c, 0x35, 
 0x2e, 0x27, 0x2f, 0x36, 0x3d, 0x3e, 0x37, 0x3f, 
};

void MDEC_Power(void)
{
 ClockCounter = 0;
 MDRPhase = 0;

 InFIFO.Flush();
 OutFIFO.Flush();

 memset(block_y, 0, sizeof(block_y));
 memset(block_cb, 0, sizeof(block_cb));
 memset(block_cr, 0, sizeof(block_cr));

 Control = 0;
 Command = 0;
 InCommand = false;

 memset(QMatrix, 0, sizeof(QMatrix));
 QMIndex = 0;

 memset(IDCTMatrix, 0, sizeof(IDCTMatrix));
 IDCTMIndex = 0;

 QScale = 0;

 memset(Coeff, 0, sizeof(Coeff));
 CoeffIndex = 0;
 DecodeWB = 0;

 memset(PixelBuffer.pix32, 0, sizeof(PixelBuffer.pix32));
 PixelBufferReadOffset = 0;
 PixelBufferCount32 = 0;

 InCounter = 0;

 RAMOffsetY = 0;
 RAMOffsetCounter = 0;
 RAMOffsetWWS = 0;
}

void MDEC_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(ClockCounter),
  SFVAR(MDRPhase),

#define SFFIFO32(fifoobj)  SFPTR32(&fifoobj.data[0], sizeof(fifoobj.data) / sizeof(fifoobj.data[0])),	\
			 SFVAR(fifoobj.read_pos),				\
			 SFVAR(fifoobj.write_pos),				\
			 SFVAR(fifoobj.in_count)

  SFFIFO32(InFIFO),
  SFFIFO32(OutFIFO),
#undef SFFIFO

  SFVARN(block_y, "&block_y[0][0]"),
  SFVARN(block_cb, "&block_cb[0][0]"),
  SFVARN(block_cr, "&block_cr[0][0]"),

  SFVAR(Control),
  SFVAR(Command),
  SFVAR(InCommand),

  SFVARN(QMatrix, "&QMatrix[0][0]"),
  SFVAR(QMIndex),

  SFVARN(IDCTMatrix, "&IDCTMatrix[0]"),
  SFVAR(IDCTMIndex),

  SFVAR(QScale),

  SFVARN(Coeff, "&Coeff[0]"),
  SFVAR(CoeffIndex),
  SFVAR(DecodeWB),

  SFVARN(PixelBuffer.pix32, "&PixelBuffer.pix32[0]"),
  SFVAR(PixelBufferReadOffset),
  SFVAR(PixelBufferCount32),

  SFVAR(InCounter),

  SFVAR(RAMOffsetY),
  SFVAR(RAMOffsetCounter),
  SFVAR(RAMOffsetWWS),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MDEC");

 if(load)
 {
  InFIFO.SaveStatePostLoad();
  OutFIFO.SaveStatePostLoad();

  PixelBufferCount32 %= (sizeof(PixelBuffer.pix32) / sizeof(PixelBuffer.pix32[0])) + 1;
 }
}

static INLINE int8 Mask9ClampS8(int32 v)
{
 v = sign_x_to_s32(9, v);

 if(v < -128)
  v = -128;

 if(v > 127)
  v = 127;

 return v;
}

////////////////////////
//
//
#pragma GCC push_options

#if defined(__SSE2__) || (defined(ARCH_X86) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 9)))
//
//
//
#pragma GCC target("sse2")
template<typename T>
static INLINE void IDCT_1D_Multi(int16 *in_coeff, T *out_coeff)
{
 for(unsigned col = 0; col < 8; col++)
 {
  __m128i c =  _mm_load_si128((__m128i *)&in_coeff[(col * 8)]);

  for(unsigned x = 0; x < 8; x++)
  {
   __m128i sum;
   __m128i m;
   alignas(16) int32 tmp[4];

   m = _mm_load_si128((__m128i *)&IDCTMatrix[(x * 8)]);
   sum = _mm_madd_epi16(m, c);
   sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, (3 << 0) | (2 << 2) | (1 << 4) | (0 << 6)));
   sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, (1 << 0) | (0 << 2)));

   //_mm_store_ss((float *)&tmp[0], (__m128)sum);
   _mm_store_si128((__m128i*)tmp, sum);

   if(sizeof(T) == 1)
    out_coeff[(col * 8) + x] = Mask9ClampS8((tmp[0] + 0x4000) >> 15);
   else
    out_coeff[(x * 8) + col] = (tmp[0] + 0x4000) >> 15;
  }
 }
}
//
//
//
#elif 0 //defined(__ARM_NEON__)
//
//
//
template<typename T>
static INLINE void IDCT_1D_Multi(int16 *in_coeff, T *out_coeff)
{
 for(unsigned col = 0; col < 8; col++)
 {
  register int16x4_t c0 = vld1_s16(MDFN_ASSUME_ALIGNED(in_coeff + col * 8 + 0, sizeof(int16x4_t)));
  register int16x4_t c1 = vld1_s16(MDFN_ASSUME_ALIGNED(in_coeff + col * 8 + 4, sizeof(int16x4_t)));
  int32 buf[8];

  for(unsigned x = 0; x < 8; x++)
  {
   register int32x4_t accum;
   register int32x2_t sum2;

   accum = vdupq_n_s32(0);
   accum = vmlal_s16(accum, c0, vld1_s16(MDFN_ASSUME_ALIGNED(IDCTMatrix + x * 8 + 0, sizeof(int16x4_t))));
   accum = vmlal_s16(accum, c1, vld1_s16(MDFN_ASSUME_ALIGNED(IDCTMatrix + x * 8 + 4, sizeof(int16x4_t))));
   sum2 = vadd_s32(vget_high_s32(accum), vget_low_s32(accum));
   sum2 = vpadd_s32(sum2, sum2);
   vst1_lane_s32(buf + x, sum2, 0);
  }

  for(unsigned x = 0; x < 8; x++)
  {
   if(sizeof(T) == 1)
    out_coeff[(col * 8) + x] = Mask9ClampS8((buf[x] + 0x4000) >> 15);
   else
    out_coeff[(x * 8) + col] = (buf[x] + 0x4000) >> 15;
  }
 }
}
//
//
//
#else
//
//
//
template<typename T>
static INLINE void IDCT_1D_Multi(int16 *in_coeff, T *out_coeff)
{
 for(unsigned col = 0; col < 8; col++)
 {
  for(unsigned x = 0; x < 8; x++)
  {
   int32 sum = 0;

   for(unsigned u = 0; u < 8; u++)
   {
    sum += (in_coeff[(col * 8) + u] * IDCTMatrix[(x * 8) + u]);
   }

   if(sizeof(T) == 1)
    out_coeff[(col * 8) + x] = Mask9ClampS8((sum + 0x4000) >> 15);
   else
    out_coeff[(x * 8) + col] = (sum + 0x4000) >> 15;
  }
 }
}
//
//
//
#endif

static void IDCT(int16 *in_coeff, int8 *out_coeff) NO_INLINE;
static void IDCT(int16 *in_coeff, int8 *out_coeff)
{
 alignas(16) int16 tmpbuf[64];

 IDCT_1D_Multi<int16>(in_coeff, tmpbuf);
 IDCT_1D_Multi<int8>(tmpbuf, out_coeff);
}
#pragma GCC pop_options
//
//
///////////////////////

static INLINE void YCbCr_to_RGB(const int8 y, const int8 cb, const int8 cr, int &r, int &g, int &b)
{
 //
 // The formula for green is still a bit off(precision/rounding issues when both cb and cr are non-zero).
 //

 r = Mask9ClampS8(y + (((359 * cr) + 0x80) >> 8));
 //g = Mask9ClampS8(y + (((-88 * cb) + (-183 * cr) + 0x80) >> 8));
 g = Mask9ClampS8(y + ((((-88 * cb) &~ 0x1F) + ((-183 * cr) &~ 0x07) + 0x80) >> 8));
 b = Mask9ClampS8(y + (((454 * cb) + 0x80) >> 8));

 r ^= 0x80;
 g ^= 0x80;
 b ^= 0x80;
}

static INLINE uint16 RGB_to_RGB555(uint8 r, uint8 g, uint8 b)
{
 r = (r + 4) >> 3;
 g = (g + 4) >> 3;
 b = (b + 4) >> 3;

 if(r > 0x1F)
  r = 0x1F;

 if(g > 0x1F)
  g = 0x1F;

 if(b > 0x1F)
  b = 0x1F;

 return((r << 0) | (g << 5) | (b << 10));
}

static void EncodeImage(const unsigned ybn)
{
 //printf("ENCODE, %d\n", (Command & 0x08000000) ? 256 : 384);

 PixelBufferCount32 = 0;

 switch((Command >> 27) & 0x3)
 {
  case 0:	// 4bpp
  {
   const uint8 us_xor = (Command & (1U << 26)) ? 0x00 : 0x88;
   uint8* pix_out = PixelBuffer.pix8;

   for(int y = 0; y < 8; y++)
   {
    for(int x = 0; x < 8; x += 2)
    {
     uint8 p0 = std::min<int>(127, block_y[y][x + 0] + 8);
     uint8 p1 = std::min<int>(127, block_y[y][x + 1] + 8);

     *pix_out = ((p0 >> 4) | (p1 & 0xF0)) ^ us_xor;
     pix_out++;
    }
   }
   PixelBufferCount32 = 8;
  }
  break;


  case 1:	// 8bpp
  {
   const uint8 us_xor = (Command & (1U << 26)) ? 0x00 : 0x80;
   uint8* pix_out = PixelBuffer.pix8;

   for(int y = 0; y < 8; y++)
   {
    for(int x = 0; x < 8; x++)
    {
     *pix_out = (uint8)block_y[y][x] ^ us_xor;
     pix_out++;
    }
   }
   PixelBufferCount32 = 16;
  }
  break;

  case 2:	// 24bpp
  {
   const uint8 rgb_xor = (Command & (1U << 26)) ? 0x80 : 0x00;
   uint8* pix_out = PixelBuffer.pix8;

   for(int y = 0; y < 8; y++)
   {
    const int8* by = &block_y[y][0];
    const int8* cb = &block_cb[(y >> 1) | ((ybn & 2) << 1)][(ybn & 1) << 2];
    const int8* cr = &block_cr[(y >> 1) | ((ybn & 2) << 1)][(ybn & 1) << 2];
    
    for(int x = 0; x < 8; x++)
    {
     int r, g, b;

     YCbCr_to_RGB(by[x], cb[x >> 1], cr[x >> 1], r, g, b);

     pix_out[0] = r ^ rgb_xor;
     pix_out[1] = g ^ rgb_xor;
     pix_out[2] = b ^ rgb_xor;
     pix_out += 3;
    }
   }
   PixelBufferCount32 = 48;
  }
  break;

  case 3:	// 16bpp
  {
   uint16 pixel_xor = ((Command & 0x02000000) ? 0x8000 : 0x0000) | ((Command & (1U << 26)) ? 0x4210 : 0x0000);
   uint16* pix_out = PixelBuffer.pix16;

   for(int y = 0; y < 8; y++)
   {
    const int8* by = &block_y[y][0];
    const int8* cb = &block_cb[(y >> 1) | ((ybn & 2) << 1)][(ybn & 1) << 2];
    const int8* cr = &block_cr[(y >> 1) | ((ybn & 2) << 1)][(ybn & 1) << 2];

    for(int x = 0; x < 8; x++)
    {
     int r, g, b;

     YCbCr_to_RGB(by[x], cb[x >> 1], cr[x >> 1], r, g, b);

     MDFN_en16lsb<true>(pix_out, pixel_xor ^ RGB_to_RGB555(r, g, b));
     pix_out++;
    }
   }
   PixelBufferCount32 = 32;
  }
  break;

 }
}

static INLINE void WriteImageData(uint16 V, int32* eat_cycles)
{
 const uint32 qmw = (bool)(DecodeWB < 2);

  //printf("MDEC DMA SubWrite: %04x, %d\n", V, CoeffIndex);

  if(!CoeffIndex)
  {
   if(V == 0xFE00)
   {
    //printf("FE00 @ %u\n", DecodeWB);
    return;
   }

   QScale = V >> 10;

   {
    int q = QMatrix[qmw][0];	// No QScale here!
    int ci = sign_10_to_s16(V & 0x3FF);
    int tmp;

    if(q != 0)
     tmp = (int32)((uint32)(ci * q) << 4) + (ci ? ((ci < 0) ? 8 : -8) : 0);
    else
     tmp = (uint32)(ci * 2) << 4;

    // Not sure if it should be 0x3FFF or 0x3FF0 or maybe 0x3FF8?
    Coeff[ZigZag[0]] = std::min<int>(0x3FFF, std::max<int>(-0x4000, tmp));
    CoeffIndex++;
   }
  }
  else
  {
   if(V == 0xFE00)
   {
    while(CoeffIndex < 64)
     Coeff[ZigZag[CoeffIndex++]] = 0;
   }
   else
   {
    uint32 rlcount = V >> 10;

    for(uint32 i = 0; i < rlcount && CoeffIndex < 64; i++)
    {
     Coeff[ZigZag[CoeffIndex]] = 0;
     CoeffIndex++;
    }

    if(CoeffIndex < 64)
    {
     int q = QScale * QMatrix[qmw][CoeffIndex];
     int ci = sign_10_to_s16(V & 0x3FF);
     int tmp;

     if(q != 0)
      tmp = (int32)((uint32)((ci * q) >> 3) << 4) + (ci ? ((ci < 0) ? 8 : -8) : 0);
     else
      tmp = (uint32)(ci * 2) << 4;

     // Not sure if it should be 0x3FFF or 0x3FF0 or maybe 0x3FF8?
     Coeff[ZigZag[CoeffIndex]] = std::min<int>(0x3FFF, std::max<int>(-0x4000, tmp));
     CoeffIndex++;
    }
   }
  }

  if(CoeffIndex == 64)
  {
   CoeffIndex = 0;

   //printf("Block %d finished\n", DecodeWB);

   switch(DecodeWB)
   {
    case 0: IDCT(Coeff, MDAP(block_cr)); break;
    case 1: IDCT(Coeff, MDAP(block_cb)); break;
    case 2: IDCT(Coeff, MDAP(block_y)); break;
    case 3: IDCT(Coeff, MDAP(block_y)); break;
    case 4: IDCT(Coeff, MDAP(block_y)); break;
    case 5: IDCT(Coeff, MDAP(block_y)); break;
   }   

   // Timing in the PS1 MDEC is complex due to (apparent) pipelining, but the average when decoding a large number of blocks is
   // about 512.
   *eat_cycles += 512;

   if(DecodeWB >= 2)
   {
    EncodeImage((DecodeWB + 4) % 6);
   }

   DecodeWB++;
   if(DecodeWB == (((Command >> 27) & 2) ? 6 : 3))
   {
    DecodeWB = ((Command >> 27) & 2) ? 0 : 2;
   }
  }
}

#if 1

//
//
//
#define MDEC_WAIT_COND(n)  { case __COUNTER__: if(!(n)) { MDRPhase = __COUNTER__ - MDRPhaseBias - 1; return; } }

#define MDEC_WRITE_FIFO(n) { MDEC_WAIT_COND(OutFIFO.CanWrite()); OutFIFO.Write(n);  }
#define MDEC_READ_FIFO(n)  { MDEC_WAIT_COND(InFIFO.CanRead()); n = InFIFO.Read(); }
#define MDEC_EAT_CLOCKS(n) { ClockCounter -= (n); MDEC_WAIT_COND(ClockCounter > 0); }

MDFN_FASTCALL void MDEC_Run(int32 clocks)
{
 static const unsigned MDRPhaseBias = __COUNTER__ + 1;

 //MDFN_DispMessage("%u", OutFIFO.CanRead());

 ClockCounter += clocks;

 if(ClockCounter > 128)
 {
  //if(MDRPhase != 0)
  // printf("SNORT: %d\n", ClockCounter);
  ClockCounter = 128;
 }

 switch(MDRPhase + MDRPhaseBias)
 {
  for(;;)
  {
   InCommand = false;
   MDEC_READ_FIFO(Command);	// This must be the first MDEC_* macro used!
   InCommand = true;
   MDEC_EAT_CLOCKS(1);

   //printf("****************** Command: %08x, %02x\n", Command, Command >> 29);

   //
   //
   //
   if(((Command >> 29) & 0x7) == 1)
   {
    InCounter = Command & 0xFFFF;
    OutFIFO.Flush();
    //OutBuffer.Flush();

    PixelBufferCount32 = 0;
    CoeffIndex = 0;

    if((Command >> 27) & 2)
     DecodeWB = 0;
    else
     DecodeWB = 2;

    switch((Command >> 27) & 0x3)
    {
     case 0:
     case 1: RAMOffsetWWS = 0; break;
     case 2: RAMOffsetWWS = 6; break;
     case 3: RAMOffsetWWS = 4; break;
    }
    RAMOffsetY = 0;
    RAMOffsetCounter = RAMOffsetWWS;

    InCounter--;
    do
    {
     uint32 tfr;
     int32 need_eat; // = 0;

     MDEC_READ_FIFO(tfr);
     InCounter--;

//     printf("KA: %04x %08x\n", InCounter, tfr);

     need_eat = 0;
     PixelBufferCount32 = 0;
     WriteImageData(tfr, &need_eat);
     WriteImageData(tfr >> 16, &need_eat);

     MDEC_EAT_CLOCKS(need_eat);

     PixelBufferReadOffset = 0;
     while(PixelBufferReadOffset < PixelBufferCount32)
     {
      MDEC_WRITE_FIFO((MDFN_de32lsb<true>(&PixelBuffer.pix32[PixelBufferReadOffset++])));
     }
    } while(InCounter != 0xFFFF);
   }
   //
   //
   //
   else if(((Command >> 29) & 0x7) == 2)
   {
    QMIndex = 0;
    InCounter = 0x10 + ((Command & 0x1) ? 0x10 : 0x00);

    InCounter--;
    do
    {
	uint32 tfr;
    
	MDEC_READ_FIFO(tfr);
	InCounter--;

	//printf("KA: %04x %08x\n", InCounter, tfr);

	for(int i = 0; i < 4; i++)
	{
         QMatrix[QMIndex >> 6][QMIndex & 0x3F] = (uint8)tfr;
	 QMIndex = (QMIndex + 1) & 0x7F;
	 tfr >>= 8;
	}
    } while(InCounter != 0xFFFF);
   }
   //
   //
   //
   else if(((Command >> 29) & 0x7) == 3)
   {
    IDCTMIndex = 0;
    InCounter = 0x20;

    InCounter--;
    do
    {
     uint32 tfr;

     MDEC_READ_FIFO(tfr);
     InCounter--;

     for(unsigned i = 0; i < 2; i++)
     {
      IDCTMatrix[((IDCTMIndex & 0x7) << 3) | ((IDCTMIndex >> 3) & 0x7)] = (int16)(tfr & 0xFFFF) >> 3;
      IDCTMIndex = (IDCTMIndex + 1) & 0x3F;

      tfr >>= 16;
     }
    } while(InCounter != 0xFFFF);
   }
   else
   {
    InCounter = Command & 0xFFFF;
   }
  } // end for(;;)
 }
}
#endif

MDFN_FASTCALL void MDEC_DMAWrite(uint32 V)
{
 if(InFIFO.CanWrite())
 {
  InFIFO.Write(V);
  MDEC_Run(0);
 }
 else
 {
  PSX_DBG(PSX_DBG_WARNING, "[MDEC] DMA write when input FIFO is full!!\n");
 }
}

MDFN_FASTCALL uint32 MDEC_DMARead(uint32* offs)
{
 uint32 V = 0;

 *offs = 0;

 if(MDFN_LIKELY(OutFIFO.CanRead()))
 {
  V = OutFIFO.Read();

  *offs = (RAMOffsetY & 0x7) * RAMOffsetWWS;

  if(RAMOffsetY & 0x08)
  {
   *offs = (*offs - RAMOffsetWWS*7);
  }

  RAMOffsetCounter--;
  if(!RAMOffsetCounter)
  {
   RAMOffsetCounter = RAMOffsetWWS;
   RAMOffsetY++;
  }

  MDEC_Run(0);
 }
 else
 {
  PSX_DBG(PSX_DBG_WARNING, "[MDEC] DMA read when output FIFO is empty!\n");
 }

 return(V);
}

bool MDEC_DMACanWrite(void)
{
 return((InFIFO.CanWrite() >= 0x20) && (Control & (1U << 30)) && InCommand && InCounter != 0xFFFF);
}

bool MDEC_DMACanRead(void)
{
 return((OutFIFO.CanRead() >= 0x20) && (Control & (1U << 29)));
}

MDFN_FASTCALL void MDEC_Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 //PSX_WARNING("[MDEC] Write: 0x%08x 0x%08x, %d  --- %u %u", A, V, timestamp, InFIFO.CanRead(), OutFIFO.CanRead());
 if(A & 4)
 {
  if(V & 0x80000000) // Reset?
  {
   MDRPhase = 0;
   InCounter = 0;
   Command = 0;
   InCommand = false;

   PixelBufferCount32 = 0;
   ClockCounter = 0;
   QMIndex = 0;
   IDCTMIndex = 0;

   QScale = 0;

   memset(Coeff, 0, sizeof(Coeff));
   CoeffIndex = 0;
   DecodeWB = 0;

   InFIFO.Flush();
   OutFIFO.Flush();
  }
  Control = V & 0x7FFFFFFF;
 }
 else
 {
  if(InFIFO.CanWrite())
  {
   InFIFO.Write(V);

   if(!InCommand)
   {
    if(ClockCounter < 1)
     ClockCounter = 1;
   }
   MDEC_Run(0);
  }
  else
  {
   PSX_DBG(PSX_DBG_WARNING, "MDEC manual write FIFO overflow?!\n");
  }
 }
}

MDFN_FASTCALL uint32 MDEC_Read(const pscpu_timestamp_t timestamp, uint32 A)
{
 uint32 ret = 0;

 if(A & 4)
 {
  ret = 0;

  ret |= (OutFIFO.CanRead() == 0) << 31;
  ret |= (InFIFO.CanWrite() == 0) << 30;
  ret |= InCommand << 29;

  ret |= MDEC_DMACanWrite() << 28;
  ret |= MDEC_DMACanRead() << 27;

  ret |= ((Command >> 25) & 0xF) << 23;

  // Needs refactoring elsewhere to work right: ret |= ((DecodeWB + 4) % 6) << 16;

  ret |= InCounter & 0xFFFF;
 }
 else
 {
  if(OutFIFO.CanRead())
   ret = OutFIFO.Read();
 }

 //PSX_WARNING("[MDEC] Read: 0x%08x 0x%08x -- %d %d", A, ret, InputBuffer.CanRead(), InCounter);

 return(ret);
}

}
