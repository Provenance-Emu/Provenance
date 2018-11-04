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

#include "sexyal.h"
#include "convert.h"

static inline uint32 ConvertRandU32(void)
{
 static uint32 x = 123456789;
 static uint32 y = 987654321;
 static uint32 z = 43219876;
 static uint32 c = 6543217;
 uint64 t;

 x = 314527869 * x + 1234567;
 y ^= y << 5; y ^= y >> 7; y ^= y << 22;
 t = 4294584393ULL * z + c; c = t >> 32; z = t;

 return(x + y + z);
}

static INLINE uint32 Dither(uint32 tmp, const uint32 dither_mask)
{
 if(dither_mask)
 {
  uint32 nv = tmp + (ConvertRandU32() & dither_mask);

  if((int32)nv < (int32)tmp)
   nv = 0x7FFFFFFF;

  tmp = nv & ~dither_mask;
 }

 return tmp;
}

static INLINE void EncodeSamp(const uint32 dest_sampformat, void* d, const unsigned dest_shift, const uint32 samp)
{
 if(SAMPFORMAT_ENC(dest_sampformat) == SEXYAL_ENC_PCM_FLOAT)
 {
  uint32 tmp;
  float t = (int32)samp * (1.0 / 2147483648.0);
  memcpy(&tmp, &t, 4);
  if(SAMPFORMAT_BIGENDIAN(dest_sampformat))
   MDFN_en32msb<true>(d, tmp);
  else
   MDFN_en32lsb<true>(d, tmp);
 }
 else
 {
  uint32 tmp = samp;

  if(SAMPFORMAT_ENC(dest_sampformat) == SEXYAL_ENC_PCM_UINT)
   tmp ^= 0x80000000U;

  tmp >>= dest_shift;

  switch(SAMPFORMAT_BYTES(dest_sampformat))
  {
   default: abort(); break;
   case 1: *(uint8*)d = tmp; break;
   case 2: if(SAMPFORMAT_BIGENDIAN(dest_sampformat)) MDFN_en16msb<true>(d, tmp); else MDFN_en16lsb<true>(d, tmp); break;
   case 3: if(SAMPFORMAT_BIGENDIAN(dest_sampformat)) MDFN_en24msb      (d, tmp); else MDFN_en24lsb      (d, tmp); break;
   case 4: if(SAMPFORMAT_BIGENDIAN(dest_sampformat)) MDFN_en32msb<true>(d, tmp); else MDFN_en32lsb<true>(d, tmp); break;
  }
 }
}

static INLINE uint32 DecodeSamp(const uint32 src_sampformat, const void* s, const unsigned src_shift)
{
 if(SAMPFORMAT_ENC(src_sampformat) == SEXYAL_ENC_PCM_FLOAT)
 {
  static_assert(sizeof(float) == 4, "sizeof(float) != 4");
  float t;
  int32 tmp;

  tmp = SAMPFORMAT_BIGENDIAN(src_sampformat) ? MDFN_de32msb<true>(s) : MDFN_de32lsb<true>(s);
  memcpy(&t, &tmp, 4);

  tmp = t * 16777216.0;

  if(tmp > 16777215)
   tmp = 16777215;
  else if(t < -16777216)
   tmp = -16777216;

  return (uint32)tmp << 8;
 }
 else
 {
  uint32 tmp;

  switch(SAMPFORMAT_BYTES(src_sampformat))
  {
   default: abort(); break;
   case 1: tmp = *(uint8*)s; break;
   case 2: tmp = SAMPFORMAT_BIGENDIAN(src_sampformat) ? MDFN_de16msb<true>(s) : MDFN_de16lsb<true>(s); break;
   case 3: tmp = SAMPFORMAT_BIGENDIAN(src_sampformat) ? MDFN_de24msb      (s) : MDFN_de24lsb      (s); break;
   case 4: tmp = SAMPFORMAT_BIGENDIAN(src_sampformat) ? MDFN_de32msb<true>(s) : MDFN_de32lsb<true>(s); break;
  }

  tmp <<= src_shift;

  if(SAMPFORMAT_ENC(src_sampformat) == SEXYAL_ENC_PCM_UINT)
   tmp ^= 0x80000000U;

  return tmp;
 }
}


static INLINE void ConvertLoop(const uint32 src_sampformat, const uint32 src_chan, const bool src_noninterleaved,
			const uint32 dest_sampformat, const uint32 dest_chan, const bool dest_noninterleaved,
			const void* vsrc, void* vdest, size_t frames)
{
 unsigned src_shift;
 unsigned dest_shift;
 unsigned dither_mask;
 const unsigned char* src = (const unsigned char*)vsrc;
 const unsigned char* src_bound = src + SAMPFORMAT_BYTES(src_sampformat) * frames * src_chan;
 unsigned char* dest = (unsigned char*)vdest;

 src_shift = 32 - SAMPFORMAT_BITS(src_sampformat) - SAMPFORMAT_LSBPAD(src_sampformat);
 dest_shift = 32 - SAMPFORMAT_BITS(dest_sampformat) - SAMPFORMAT_LSBPAD(dest_sampformat);

 if(SAMPFORMAT_BITS(dest_sampformat) < SAMPFORMAT_BITS(src_sampformat)/* || dest_chan < src_chan*/)
  dither_mask = (1U << (32 - SAMPFORMAT_BITS(dest_sampformat))) - 1;
 else
  dither_mask = 0;

 //printf("%08x\n", dither_mask);

 #define DECODE(offs)   DecodeSamp(src_sampformat, src + (offs) * SAMPFORMAT_BYTES(src_sampformat), src_shift)
 #define ENCODE(offs,v) EncodeSamp(dest_sampformat, dest + (offs) * SAMPFORMAT_BYTES(dest_sampformat), dest_shift, v)
 #define DITHER(v) Dither(v, dither_mask)

 if(src_chan == 1 && dest_chan == 1)
 {
  do
  {
   uint32 tmp = DECODE(0);

   tmp = DITHER(tmp);

   ENCODE(0, tmp);

   src += SAMPFORMAT_BYTES(src_sampformat);
   dest += SAMPFORMAT_BYTES(dest_sampformat);
  } while(MDFN_LIKELY(src != src_bound));
 }
 else if(src_chan == 2 && dest_chan == 1)
 {
  do
  {
   uint32 tmp0 = (int32)DECODE(0) >> 1;
   uint32 tmp1 = (int32)DECODE(1) >> 1;
   uint32 tmp = tmp0 + tmp1;

   tmp = DITHER(tmp);

   ENCODE(0, tmp);

   src += SAMPFORMAT_BYTES(src_sampformat) * 2;
   dest += SAMPFORMAT_BYTES(dest_sampformat);
  } while(MDFN_LIKELY(src != src_bound));
 }
 else if(src_chan == 1 && dest_chan >= 2)
 {
  if(dest_noninterleaved)
  {
   do
   {
    uint32 tmp = DECODE(0);

    tmp = DITHER(tmp);

    ENCODE(0 * frames, tmp);
    ENCODE(1 * frames, tmp);

    for(unsigned padc = 2; padc < dest_chan; padc++)
     ENCODE(padc * frames, 0);

    src += SAMPFORMAT_BYTES(src_sampformat); 
    dest += SAMPFORMAT_BYTES(dest_sampformat);
   } while(MDFN_LIKELY(src != src_bound));
  }
  else
  {
   do
   {
    uint32 tmp = DECODE(0);

    tmp = DITHER(tmp);

    ENCODE(0, tmp);
    ENCODE(1, tmp);

    for(unsigned padc = 2; padc < dest_chan; padc++)
     ENCODE(padc, 0);

    src += SAMPFORMAT_BYTES(src_sampformat);
    dest += SAMPFORMAT_BYTES(dest_sampformat) * dest_chan;
   } while(MDFN_LIKELY(src != src_bound));
  }
 }
 else //if(src_chan == 2 && dest_chan >= 2)
 {
  if(dest_noninterleaved)
  {
   do
   {
    ENCODE(0 * frames, DITHER(DECODE(0)));
    ENCODE(1 * frames, DITHER(DECODE(1)));

    for(unsigned padc = 2; padc < dest_chan; padc++)
     ENCODE(padc * frames, 0);

    src += SAMPFORMAT_BYTES(src_sampformat) * 2;
    dest += SAMPFORMAT_BYTES(dest_sampformat);
   } while(MDFN_LIKELY(src != src_bound));
  }
  else
  {
   do
   {
    ENCODE(0, DITHER(DECODE(0)));
    ENCODE(1, DITHER(DECODE(1)));

    for(unsigned padc = 2; padc < dest_chan; padc++)
     ENCODE(padc, 0);

    src += SAMPFORMAT_BYTES(src_sampformat) * 2;
    dest += SAMPFORMAT_BYTES(dest_sampformat) * dest_chan;
   } while(MDFN_LIKELY(src != src_bound));
  }
 }
}

template<uint32 src_sampformat, uint32 dest_sampformat>
static void ConvertLoopT(const uint32 src_chan, const bool src_noninterleaved,
			const uint32 dest_chan, const bool dest_noninterleaved,
			const void* vsrc, void* vdest, size_t frames)
{
 ConvertLoop(src_sampformat, src_chan, src_noninterleaved,
	     dest_sampformat, dest_chan, dest_noninterleaved,
	     vsrc, vdest, frames);
}


static const struct
{
 uint32 sampformat;
 void (*convert)(const uint32 src_chan, const bool src_noninterleaved,
			const uint32 dest_chan, const bool dest_noninterleaved,
			const void* vsrc, void* vdest, size_t frames);
} convert_tab[] =
{
 #define CTE(sf) { sf, ConvertLoopT<SEXYAL_FMT_PCMS16, sf> }
 CTE(SEXYAL_FMT_PCMU8),
 CTE(SEXYAL_FMT_PCMS8),
 CTE(SEXYAL_FMT_PCMU16_LE),
 CTE(SEXYAL_FMT_PCMS16_LE),
 CTE(SEXYAL_FMT_PCMU16_BE),
 CTE(SEXYAL_FMT_PCMS16_BE),
 CTE(SEXYAL_FMT_PCMU24_LE),
 CTE(SEXYAL_FMT_PCMS24_LE),
 CTE(SEXYAL_FMT_PCMU24_BE),
 CTE(SEXYAL_FMT_PCMS24_BE),
 CTE(SEXYAL_FMT_PCMU32_LE),
 CTE(SEXYAL_FMT_PCMS32_LE),
 CTE(SEXYAL_FMT_PCMU32_BE),
 CTE(SEXYAL_FMT_PCMS32_BE),
 CTE(SEXYAL_FMT_PCMFLOAT_LE),
 CTE(SEXYAL_FMT_PCMFLOAT_BE),
 CTE(SEXYAL_FMT_PCMU18_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMS18_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMU18_3BYTE_BE),
 CTE(SEXYAL_FMT_PCMS18_3BYTE_BE),
 CTE(SEXYAL_FMT_PCMU20_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMS20_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMU20_3BYTE_BE),
 CTE(SEXYAL_FMT_PCMS20_3BYTE_BE),
 CTE(SEXYAL_FMT_PCMU24_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMS24_3BYTE_LE),
 CTE(SEXYAL_FMT_PCMU24_3BYTE_BE),
 CTE(SEXYAL_FMT_PCMS24_3BYTE_BE),
 #undef CTE
};

/* Only supports one input sample format right now:  SEXYAL_FMT_PCMS16 */
void SexiALI_Convert(const SexyAL_format *srcformat, const SexyAL_format *destformat, const void *vsrc, void *vdest, uint32 frames)
{
 if(!frames)
  return;

 assert(srcformat->noninterleaved == false);
 assert(srcformat->sampformat == SEXYAL_FMT_PCMS16);

 void (*convert)(const uint32 src_chan, const bool src_noninterleaved,
		 const uint32 dest_chan, const bool dest_noninterleaved,
		 const void* vsrc, void* vdest, size_t frames) = nullptr;
 //
 {
  const uint32 dsf = destformat->sampformat;
  uint32 adj_dest_sampformat = dsf;

  if(destformat->channels >= srcformat->channels &&
	SAMPFORMAT_BITS(dsf) >= SAMPFORMAT_BITS(srcformat->sampformat) &&
	(SAMPFORMAT_LSBPAD(dsf) + SAMPFORMAT_BITS(dsf)) == (8 * SAMPFORMAT_BYTES(dsf)))
  {
   adj_dest_sampformat = SAMPFORMAT_MAKE(SAMPFORMAT_ENC(dsf), SAMPFORMAT_BYTES(dsf), SAMPFORMAT_BITS(dsf) + SAMPFORMAT_LSBPAD(dsf), 0, SAMPFORMAT_BIGENDIAN(dsf));
   //printf("ADJ: %08x->%08x\n", dsf, adj_dest_sampformat);
  }

  for(auto& cte : convert_tab)
  {
   if(cte.sampformat == adj_dest_sampformat)
   {
    convert = cte.convert;
    break;
   }
  }
 }
 //

 if(convert)
 {
  //puts("Convert Template");
  convert(srcformat->channels, srcformat->noninterleaved, destformat->channels, destformat->noninterleaved, vsrc, vdest, frames);
 }
 else
 {
  //puts("Convert Unspecialized");
  ConvertLoop(SEXYAL_FMT_PCMS16/*srcformat->sampformat*/, srcformat->channels, srcformat->noninterleaved, destformat->sampformat, destformat->channels, destformat->noninterleaved, vsrc, vdest, frames);
 }
}
