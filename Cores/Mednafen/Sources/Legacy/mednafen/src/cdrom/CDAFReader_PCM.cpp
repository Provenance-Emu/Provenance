/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAFReader_PCM.cpp:
**  Copyright (C) 2020 Mednafen Team
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

#include <mednafen/mednafen.h>
#include "CDAFReader.h"
#include "CDAFReader_PCM.h"

namespace Mednafen
{

class CDAFReader_PCM final : public CDAFReader
{
 public:
 CDAFReader_PCM(Stream *fp);
 ~CDAFReader_PCM();

 uint64 Read_(int16 *buffer, uint64 frames) override;
 bool Seek_(uint64 frame_offset) override;
 uint64 FrameCount(void) override;

 enum
 {
  // Don't reorder without rebuilding convert_table
  ENCODING_SIGNED = 0,
  ENCODING_UNSIGNED = 1,
  ENCODING_FLOAT = 2,
  ENCODING_ALAW = 3,
  ENCODING_ULAW = 4,
 };

 private:

 bool Load_AU(void);
 bool Load_AIFF_AIFC(void);
 bool Load_WAV_W64(void);
 //
 Stream* const fw;

 uint64 pcm_start_pos = 0;
 uint64 pcm_bound_pos = 0;

 uint64 num_frames = 0;

 struct
 {
  uint32 bits_per_sample = 0;
  uint32 bytes_per_sample = 0;
  uint32 block_offset = 0;
  uint32 block_align = 0;
  uint32 channels = 0;
  uint32 encoding = ENCODING_SIGNED;
  bool big_endian = false;
 } format;

 void (*convert)(uint32 block_offset, uint32 block_align, uint32 bytes_in_count, const uint8* inbuf, int16* output) = nullptr;

 uint32 inbuf_size = 0;
 alignas(uint32) uint8 inbuf[1024];
};

/*
#include <stdio.h>

int main(int argc, char* argv[])
{
 for(unsigned encoding = 0; encoding < 2; encoding++)
 {
  const bool is_alaw = (encoding == 0);

  printf(" // %s\n", (is_alaw) ? "A-law" : "μ-law");
  printf(" {\n ");
  for(unsigned bv = 0; bv < 256; bv++)
  {
   const unsigned char i = bv ^ (is_alaw ? 0xD5 : 0xFF);
   const unsigned int exp = (i >> 4) & 0x7;
   const unsigned int man = i & 0xF;
   int s = 0;

   if(is_alaw)
   {
    s = 8 + (man << 4);

    if(exp)
     s = (0x100 + s) << (exp - 1);
   }
   else
    s = ((0x84 + (man << 3)) << exp) - 0x84;

   if((signed char)i < 0)
    s = -s;

   printf(" 0x%04x,", s & 0xFFFF);
   if((bv & 0xF) == 0xF)
    printf("\n ");
  }
  printf("},\n");
 }
 return 0;
}
*/
static const uint16 law_table[2][256] =
{
 // A-law
 {
  0xea80, 0xeb80, 0xe880, 0xe980, 0xee80, 0xef80, 0xec80, 0xed80, 0xe280, 0xe380, 0xe080, 0xe180, 0xe680, 0xe780, 0xe480, 0xe580,
  0xf540, 0xf5c0, 0xf440, 0xf4c0, 0xf740, 0xf7c0, 0xf640, 0xf6c0, 0xf140, 0xf1c0, 0xf040, 0xf0c0, 0xf340, 0xf3c0, 0xf240, 0xf2c0,
  0xaa00, 0xae00, 0xa200, 0xa600, 0xba00, 0xbe00, 0xb200, 0xb600, 0x8a00, 0x8e00, 0x8200, 0x8600, 0x9a00, 0x9e00, 0x9200, 0x9600,
  0xd500, 0xd700, 0xd100, 0xd300, 0xdd00, 0xdf00, 0xd900, 0xdb00, 0xc500, 0xc700, 0xc100, 0xc300, 0xcd00, 0xcf00, 0xc900, 0xcb00,
  0xfea8, 0xfeb8, 0xfe88, 0xfe98, 0xfee8, 0xfef8, 0xfec8, 0xfed8, 0xfe28, 0xfe38, 0xfe08, 0xfe18, 0xfe68, 0xfe78, 0xfe48, 0xfe58,
  0xffa8, 0xffb8, 0xff88, 0xff98, 0xffe8, 0xfff8, 0xffc8, 0xffd8, 0xff28, 0xff38, 0xff08, 0xff18, 0xff68, 0xff78, 0xff48, 0xff58,
  0xfaa0, 0xfae0, 0xfa20, 0xfa60, 0xfba0, 0xfbe0, 0xfb20, 0xfb60, 0xf8a0, 0xf8e0, 0xf820, 0xf860, 0xf9a0, 0xf9e0, 0xf920, 0xf960,
  0xfd50, 0xfd70, 0xfd10, 0xfd30, 0xfdd0, 0xfdf0, 0xfd90, 0xfdb0, 0xfc50, 0xfc70, 0xfc10, 0xfc30, 0xfcd0, 0xfcf0, 0xfc90, 0xfcb0,
  0x1580, 0x1480, 0x1780, 0x1680, 0x1180, 0x1080, 0x1380, 0x1280, 0x1d80, 0x1c80, 0x1f80, 0x1e80, 0x1980, 0x1880, 0x1b80, 0x1a80,
  0x0ac0, 0x0a40, 0x0bc0, 0x0b40, 0x08c0, 0x0840, 0x09c0, 0x0940, 0x0ec0, 0x0e40, 0x0fc0, 0x0f40, 0x0cc0, 0x0c40, 0x0dc0, 0x0d40,
  0x5600, 0x5200, 0x5e00, 0x5a00, 0x4600, 0x4200, 0x4e00, 0x4a00, 0x7600, 0x7200, 0x7e00, 0x7a00, 0x6600, 0x6200, 0x6e00, 0x6a00,
  0x2b00, 0x2900, 0x2f00, 0x2d00, 0x2300, 0x2100, 0x2700, 0x2500, 0x3b00, 0x3900, 0x3f00, 0x3d00, 0x3300, 0x3100, 0x3700, 0x3500,
  0x0158, 0x0148, 0x0178, 0x0168, 0x0118, 0x0108, 0x0138, 0x0128, 0x01d8, 0x01c8, 0x01f8, 0x01e8, 0x0198, 0x0188, 0x01b8, 0x01a8,
  0x0058, 0x0048, 0x0078, 0x0068, 0x0018, 0x0008, 0x0038, 0x0028, 0x00d8, 0x00c8, 0x00f8, 0x00e8, 0x0098, 0x0088, 0x00b8, 0x00a8,
  0x0560, 0x0520, 0x05e0, 0x05a0, 0x0460, 0x0420, 0x04e0, 0x04a0, 0x0760, 0x0720, 0x07e0, 0x07a0, 0x0660, 0x0620, 0x06e0, 0x06a0,
  0x02b0, 0x0290, 0x02f0, 0x02d0, 0x0230, 0x0210, 0x0270, 0x0250, 0x03b0, 0x0390, 0x03f0, 0x03d0, 0x0330, 0x0310, 0x0370, 0x0350,
 },
 // μ-law
 {
  0x8284, 0x8684, 0x8a84, 0x8e84, 0x9284, 0x9684, 0x9a84, 0x9e84, 0xa284, 0xa684, 0xaa84, 0xae84, 0xb284, 0xb684, 0xba84, 0xbe84,
  0xc184, 0xc384, 0xc584, 0xc784, 0xc984, 0xcb84, 0xcd84, 0xcf84, 0xd184, 0xd384, 0xd584, 0xd784, 0xd984, 0xdb84, 0xdd84, 0xdf84,
  0xe104, 0xe204, 0xe304, 0xe404, 0xe504, 0xe604, 0xe704, 0xe804, 0xe904, 0xea04, 0xeb04, 0xec04, 0xed04, 0xee04, 0xef04, 0xf004,
  0xf0c4, 0xf144, 0xf1c4, 0xf244, 0xf2c4, 0xf344, 0xf3c4, 0xf444, 0xf4c4, 0xf544, 0xf5c4, 0xf644, 0xf6c4, 0xf744, 0xf7c4, 0xf844,
  0xf8a4, 0xf8e4, 0xf924, 0xf964, 0xf9a4, 0xf9e4, 0xfa24, 0xfa64, 0xfaa4, 0xfae4, 0xfb24, 0xfb64, 0xfba4, 0xfbe4, 0xfc24, 0xfc64,
  0xfc94, 0xfcb4, 0xfcd4, 0xfcf4, 0xfd14, 0xfd34, 0xfd54, 0xfd74, 0xfd94, 0xfdb4, 0xfdd4, 0xfdf4, 0xfe14, 0xfe34, 0xfe54, 0xfe74,
  0xfe8c, 0xfe9c, 0xfeac, 0xfebc, 0xfecc, 0xfedc, 0xfeec, 0xfefc, 0xff0c, 0xff1c, 0xff2c, 0xff3c, 0xff4c, 0xff5c, 0xff6c, 0xff7c,
  0xff88, 0xff90, 0xff98, 0xffa0, 0xffa8, 0xffb0, 0xffb8, 0xffc0, 0xffc8, 0xffd0, 0xffd8, 0xffe0, 0xffe8, 0xfff0, 0xfff8, 0x0000,
  0x7d7c, 0x797c, 0x757c, 0x717c, 0x6d7c, 0x697c, 0x657c, 0x617c, 0x5d7c, 0x597c, 0x557c, 0x517c, 0x4d7c, 0x497c, 0x457c, 0x417c,
  0x3e7c, 0x3c7c, 0x3a7c, 0x387c, 0x367c, 0x347c, 0x327c, 0x307c, 0x2e7c, 0x2c7c, 0x2a7c, 0x287c, 0x267c, 0x247c, 0x227c, 0x207c,
  0x1efc, 0x1dfc, 0x1cfc, 0x1bfc, 0x1afc, 0x19fc, 0x18fc, 0x17fc, 0x16fc, 0x15fc, 0x14fc, 0x13fc, 0x12fc, 0x11fc, 0x10fc, 0x0ffc,
  0x0f3c, 0x0ebc, 0x0e3c, 0x0dbc, 0x0d3c, 0x0cbc, 0x0c3c, 0x0bbc, 0x0b3c, 0x0abc, 0x0a3c, 0x09bc, 0x093c, 0x08bc, 0x083c, 0x07bc,
  0x075c, 0x071c, 0x06dc, 0x069c, 0x065c, 0x061c, 0x05dc, 0x059c, 0x055c, 0x051c, 0x04dc, 0x049c, 0x045c, 0x041c, 0x03dc, 0x039c,
  0x036c, 0x034c, 0x032c, 0x030c, 0x02ec, 0x02cc, 0x02ac, 0x028c, 0x026c, 0x024c, 0x022c, 0x020c, 0x01ec, 0x01cc, 0x01ac, 0x018c,
  0x0174, 0x0164, 0x0154, 0x0144, 0x0134, 0x0124, 0x0114, 0x0104, 0x00f4, 0x00e4, 0x00d4, 0x00c4, 0x00b4, 0x00a4, 0x0094, 0x0084,
  0x0078, 0x0070, 0x0068, 0x0060, 0x0058, 0x0050, 0x0048, 0x0040, 0x0038, 0x0030, 0x0028, 0x0020, 0x0018, 0x0010, 0x0008, 0x0000,
 }
};

template<bool bigendian, unsigned encoding, uint32 bytes_per_sample>
static INLINE int16 convert_sample(const uint8* inbuf)
{
 int16 sample;

 if(encoding == CDAFReader_PCM::ENCODING_FLOAT)
 {
  sample = 0;

  if(bytes_per_sample == 4)
  {
   uint32 tmp = MDFN_deXsb<bigendian, uint32, false>(inbuf);
   int32 exp = ((tmp >> 23) & 0xFF) - 127;
   int32 man = tmp & ((1U << 23) - 1);

   if(MDFN_UNLIKELY(exp > 0))
   {
    sample = 0x7FFF ^ ((int32)tmp >> 31);
    if((tmp & 0x7FFFFFFF) > (0xFF << 23)) // NaN
     sample = 0;
   }
   else
   {
    int32 s = 0;
    unsigned rshift = 8 - exp;

    if(rshift > 26)
     rshift = 26;

    s = ((1 << 23) + (1 << (rshift - 1)) + man) >> rshift;

    if((int32)tmp < 0)
     s = -s;

    sample = std::max<int32>(-32768, std::min<int32>(32767, s));
   }
  }
  else
  {
   uint64 tmp = MDFN_deXsb<bigendian, uint64, false>(inbuf);
   int64 exp = ((tmp >> 52) & 0x7FF) - 1023;
   int64 man = tmp & ((1ULL << 52) - 1);

   if(MDFN_UNLIKELY(exp > 0))
   {
    sample = 0x7FFF ^ ((int64)tmp >> 63);
    if((tmp & 0x7FFFFFFFFFFFFFFFULL) > (0x7FFULL << 52)) // NaN
     sample = 0;
   }
   else
   {
    int32 s = 0;
    unsigned rshift = 37 - exp;

    if(rshift > 60)
     rshift = 60;

    s = ((1ULL << 52) + (1ULL << (rshift - 1)) + man) >> rshift;

    if((int64)tmp < 0)
     s = -s;

    sample = std::max<int32>(-32768, std::min<int32>(32767, s));
   }
  }
 }
 else if(encoding == CDAFReader_PCM::ENCODING_ALAW || encoding == CDAFReader_PCM::ENCODING_ULAW)
  sample = law_table[encoding == CDAFReader_PCM::ENCODING_ULAW][*inbuf];
 else
 {
  if(bytes_per_sample == 1)
   sample = *inbuf << 8;
  else
   sample = MDFN_deXsb<bigendian, uint16, false>(inbuf + (bigendian ? 0 : (bytes_per_sample - 2)));

  if(encoding == CDAFReader_PCM::ENCODING_UNSIGNED)
   sample ^= 0x8000;
 }

 return sample;
}

template<bool bigendian, unsigned encoding, bool mono, uint32 bytes_per_sample>
static void T_convert(uint32 block_offset, uint32 block_align, uint32 bytes_in_count, const uint8* inbuf, int16* output)
{
 for(uint32 i = block_offset; i < bytes_in_count; i += block_align)
 {
  int16 sample;

  sample = convert_sample<bigendian, encoding, bytes_per_sample>(inbuf + i);
  *(output++) = sample;

  if(!mono)
   sample = convert_sample<bigendian, encoding, bytes_per_sample>(inbuf + i + bytes_per_sample);
  *(output++) = sample;
 }
}

/*
#include <stdio.h>

int main(int argc, char* argv[])
{
 static const char* bigendian_tab[2] = { "false", "true" };
 static const char* encoding_tab[5] = { "SIGNED", "UNSIGNED", "FLOAT", "ALAW", "ULAW" };

 for(unsigned bigendian = 0; bigendian < 2; bigendian++)
 {
  printf(" { // big_endian=%s\n", bigendian_tab[bigendian]);
  for(unsigned encoding = 0; encoding < 5; encoding++)
  {
   printf("  { // encoding=ENCODING_%s\n", encoding_tab[encoding]);
   for(unsigned mono = 0; mono < 2; mono++)
   {
    printf("   { // mono=%u\n    ", mono);
    for(unsigned bytes_per_sample = 1; bytes_per_sample <= 8; bytes_per_sample++)
    {
     if((encoding == 2 && bytes_per_sample != 4 && bytes_per_sample != 8) || ((encoding == 3 || encoding == 4) && bytes_per_sample != 1))
      printf("nullptr, ");
     else
      printf("T_convert<%s, CDAFReader_PCM::ENCODING_%s, %u, %u>, ", (bytes_per_sample == 1) ? "0" : bigendian_tab[bigendian], encoding_tab[encoding], mono, bytes_per_sample);
    }
    printf("\n   },\n");
   }
   printf("  },\n");
  }
  printf(" },\n");
 }
 return 0;
}
*/
static void (*const convert_table[2][5][2][8])(uint32 block_offset, uint32 block_align, uint32 bytes_in_count, const uint8* inbuf, int16* output) =
{
 { // big_endian=false
  { // encoding=ENCODING_SIGNED
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_SIGNED, 0, 1>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 2>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 3>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 4>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 5>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 6>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 7>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 0, 8>, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_SIGNED, 1, 1>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 2>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 3>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 4>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 5>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 6>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 7>, T_convert<false, CDAFReader_PCM::ENCODING_SIGNED, 1, 8>, 
   },
  },
  { // encoding=ENCODING_UNSIGNED
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 1>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 2>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 3>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 4>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 5>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 6>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 7>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 8>, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 1>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 2>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 3>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 4>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 5>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 6>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 7>, T_convert<false, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 8>, 
   },
  },
  { // encoding=ENCODING_FLOAT
   { // mono=0
    nullptr, nullptr, nullptr, T_convert<false, CDAFReader_PCM::ENCODING_FLOAT, 0, 4>, nullptr, nullptr, nullptr, T_convert<false, CDAFReader_PCM::ENCODING_FLOAT, 0, 8>, 
   },
   { // mono=1
    nullptr, nullptr, nullptr, T_convert<false, CDAFReader_PCM::ENCODING_FLOAT, 1, 4>, nullptr, nullptr, nullptr, T_convert<false, CDAFReader_PCM::ENCODING_FLOAT, 1, 8>, 
   },
  },
  { // encoding=ENCODING_ALAW
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_ALAW, 0, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_ALAW, 1, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
  },
  { // encoding=ENCODING_ULAW
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_ULAW, 0, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_ULAW, 1, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
  },
 },
 { // big_endian=true
  { // encoding=ENCODING_SIGNED
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_SIGNED, 0, 1>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 2>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 3>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 4>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 5>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 6>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 7>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 0, 8>, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_SIGNED, 1, 1>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 2>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 3>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 4>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 5>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 6>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 7>, T_convert<true, CDAFReader_PCM::ENCODING_SIGNED, 1, 8>, 
   },
  },
  { // encoding=ENCODING_UNSIGNED
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 1>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 2>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 3>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 4>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 5>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 6>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 7>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 0, 8>, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 1>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 2>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 3>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 4>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 5>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 6>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 7>, T_convert<true, CDAFReader_PCM::ENCODING_UNSIGNED, 1, 8>, 
   },
  },
  { // encoding=ENCODING_FLOAT
   { // mono=0
    nullptr, nullptr, nullptr, T_convert<true, CDAFReader_PCM::ENCODING_FLOAT, 0, 4>, nullptr, nullptr, nullptr, T_convert<true, CDAFReader_PCM::ENCODING_FLOAT, 0, 8>, 
   },
   { // mono=1
    nullptr, nullptr, nullptr, T_convert<true, CDAFReader_PCM::ENCODING_FLOAT, 1, 4>, nullptr, nullptr, nullptr, T_convert<true, CDAFReader_PCM::ENCODING_FLOAT, 1, 8>, 
   },
  },
  { // encoding=ENCODING_ALAW
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_ALAW, 0, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_ALAW, 1, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
  },
  { // encoding=ENCODING_ULAW
   { // mono=0
    T_convert<0, CDAFReader_PCM::ENCODING_ULAW, 0, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
   { // mono=1
    T_convert<0, CDAFReader_PCM::ENCODING_ULAW, 1, 1>, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, 
   },
  },
 }
};

CDAFReader_PCM::CDAFReader_PCM(Stream *fp) : fw(fp)
{
 if(!Load_WAV_W64() && (fw->rewind(), !Load_AIFF_AIFC()) && (fw->rewind(), !Load_AU()))
  throw 0;
 //
 switch(format.encoding)
 {
  default:
	throw MDFN_Error(0, _("Unsupported format: %u-bit %s"), format.bits_per_sample, _("unknown"));
	break;

  case ENCODING_SIGNED:
  case ENCODING_UNSIGNED:
	if(format.bits_per_sample < 8 || format.bits_per_sample > 32)
	 throw MDFN_Error(0, _("Unsupported format: %u-bit %s"), format.bits_per_sample, _("linear PCM"));
	break;

  case ENCODING_FLOAT:
	if(format.bits_per_sample != 32 && format.bits_per_sample != 64)
	 throw MDFN_Error(0, _("Unsupported format: %u-bit %s"), format.bits_per_sample, _("IEEE floating-point PCM"));
	break;

  case ENCODING_ALAW:
  case ENCODING_ULAW:
	if(format.bits_per_sample != 8)
	 throw MDFN_Error(0, _("Unsupported format: %u-bit %s"), format.bits_per_sample, (format.encoding == ENCODING_ALAW) ? "A-law" : "μ-law");
	break;
 }

 if(format.bytes_per_sample != ((format.bits_per_sample + 7) >> 3))
  throw MDFN_Error(0, _("Mismatch between bytes per sample and bits per sample."));

 // Currently redundant, but doesn't hurt.
 if(format.bytes_per_sample < 1 || format.bytes_per_sample > 8)
  throw MDFN_Error(0, _("Unsupported bytes per sample: %u"), format.bytes_per_sample);

 if(format.channels < 1 || format.channels > 8)
  throw MDFN_Error(0, _("Unsupported channel count: %u"), format.channels);

 if(format.block_align < (format.bytes_per_sample * format.channels) || format.block_align > (round_up_pow2(format.bytes_per_sample) * round_up_pow2(format.channels)))
  throw MDFN_Error(0, _("Unsupported block alignment: %u"), format.block_align);

 if(format.block_offset > (format.block_align - (format.bytes_per_sample * format.channels)))
  throw MDFN_Error(0, _("Unsupported block offset: %u"), format.block_offset);

 if((pcm_bound_pos - pcm_start_pos) % format.block_align)
  throw MDFN_Error(0, _("Data chunk size is not a multiple of block alignment."));

 num_frames = (pcm_bound_pos - pcm_start_pos) / format.block_align;
 inbuf_size = sizeof(inbuf) - (sizeof(inbuf) % format.block_align);

#if 0
 printf("Big endian: %u\n", format.big_endian);
 printf("Encoding: %u\n", format.encoding);
 printf("Channels: %u\n", format.channels);
 printf("Bytes per sample: %u\n", format.bytes_per_sample);
 printf("Block offset: %u\n", format.block_offset);
 printf("Block align: %u\n", format.block_align);
#endif

 convert = convert_table[format.big_endian][format.encoding][format.channels == 1][format.bytes_per_sample - 1];
 assert(convert);
 //
 fw->seek(pcm_start_pos);
}

bool CDAFReader_PCM::Load_AU(void)
{
 uint8 header[0x1C];

 if(fw->read(header, 0x1C, false) != 0x1C)
  return false;

 if(memcmp(header, ".snd", 4))
  return false;
 //
 //
 const uint32 data_offset = MDFN_de32msb(&header[0x4]);
 const uint32 data_byte_count = MDFN_de32msb(&header[0x8]);
 const uint32 data_format = MDFN_de32msb(&header[0xC]);

 format.channels = MDFN_de32msb(&header[0x14]);
 format.big_endian = true;

 pcm_start_pos = data_offset;
 if(data_byte_count == 0xFFFFFFFF)
 {
  pcm_bound_pos = fw->size();

  if(pcm_bound_pos < pcm_start_pos)
   throw MDFN_Error(0, _("AU header sound data offset is beyond the end of the file."));
 }
 else
 {
  pcm_bound_pos = pcm_start_pos + data_byte_count;
  const uint64 fw_size = fw->size();
  if(pcm_bound_pos > fw_size)
   throw MDFN_Error(0, _("AU header specifies %llu bytes more sound data than actually available."), (unsigned long long)(pcm_bound_pos - fw_size));
 }

 switch(data_format)
 {
  case 1:
	format.encoding = ENCODING_ULAW;
	format.bits_per_sample = 8;
	break;

  case 2:
  case 3:
  case 4:
  case 5:
	format.encoding = ENCODING_SIGNED;
	format.bits_per_sample = 8 * (1 + (data_format - 2));
	break;

  case 6:
  case 7:
	format.encoding = ENCODING_FLOAT;
	format.bits_per_sample = 32 * (1 + (data_format - 6));
	break;

  case 27:
	format.encoding = ENCODING_ALAW;
	format.bits_per_sample = 8;
	break;
 }

 format.bytes_per_sample = (format.bits_per_sample + 7) >> 3;
 format.block_offset = 0;
 format.block_align = format.bytes_per_sample * format.channels;

 return true;
}

#define MKID(s) (((uint32)(s)[0] << 24) | ((uint32)(s)[1] << 16) | ((uint32)(s)[2] << 8) | ((uint32)(s)[3] << 0))
bool CDAFReader_PCM::Load_AIFF_AIFC(void)
{
 uint32 chunk_padding_mask = 2 - 1;
 uint64 total_size = 0;
 uint8 header[0xC];
 bool is_aifc;

 if(fw->read(header, 0xC, false) != 0xC)
  return false;

 if(memcmp(header, "FORM", 4))
  return false;

 if(!memcmp(&header[0x8], "AIFF", 4))
  is_aifc = false;
 else if(!memcmp(&header[0x8], "AIFC", 4))
  is_aifc = true;
 else
  return false;

 total_size = (uint64)MDFN_de32msb(&header[0x4]) + 8;
 //
 //
 uint32 chunks_found = 0;
 uint32 comm_num_frames = 0;

 while(fw->tell() < total_size)
 {
  if(fw->read(header, 8, false) != 8)
   throw MDFN_Error(0, _("Unexpected EOF while reading chunk header."));
  //
  //
  const uint64 chunk_maxsize = total_size - fw->tell();
  const uint32 chunk_id = MDFN_de32msb(&header[0x0]);
  const uint32 chunk_payload_size = MDFN_de32msb(&header[0x4]);
  uint32 chunk_bytes_read = 0;

  if(chunk_payload_size > chunk_maxsize)
   throw MDFN_Error(0, _("Chunk 0x%08x is too large by %llu bytes."), MDFN_de32msb(&header[0]), (unsigned long long)(chunk_payload_size - chunk_maxsize));

  if(chunk_id == MKID("COMM"))
  {
   const uint32 comm_chunk_minsize = (is_aifc ? 0x16 : 0x12);
   uint8 tmp[0x16];

   if(chunk_payload_size < comm_chunk_minsize)
    throw MDFN_Error(0, _("Common chunk is too small by %u bytes."), (unsigned)(comm_chunk_minsize - chunk_payload_size));

   if(chunks_found & 1)
    throw MDFN_Error(0, _("Common chunk encountered more than once."));
   //
   //
   chunks_found |= 1;

   chunk_bytes_read += fw->read(tmp, comm_chunk_minsize);
   format.channels = MDFN_de16msb(&tmp[0x0]);
   comm_num_frames = MDFN_de32msb(&tmp[0x2]);
   format.bits_per_sample = MDFN_de16msb(&tmp[0x6]);
   format.bytes_per_sample = (format.bits_per_sample + 7) >> 3;
   format.encoding = ENCODING_SIGNED;
   format.big_endian = true;
   if(is_aifc)
   {
    const uint32 comp_type = MDFN_de32msb(&tmp[0x12]);

    switch(comp_type)
    {
     default:
	throw MDFN_Error(0, _("Unsupported compression type 0x%08x"), comp_type);

     case MKID("NONE"):
     case MKID("twos"):
	break;

     case MKID("sowt"):
	format.big_endian = false;
	break;

     case MKID("raw "):
	format.big_endian = false;
	format.encoding = ENCODING_UNSIGNED;
	break;

     case MKID("fl32"):
     case MKID("FL32"):
	format.encoding = ENCODING_FLOAT;
	if(format.bits_per_sample != 32)
	 throw MDFN_Error(0, _("Mismatch between bits per sample and compression type."));
	break;

     case MKID("fl64"):
	format.encoding = ENCODING_FLOAT;
	if(format.bits_per_sample != 64)
	 throw MDFN_Error(0, _("Mismatch between bits per sample and compression type."));
	break;

     case MKID("alaw"):
     case MKID("ALAW"):
	format.encoding = ENCODING_ALAW;
	if(format.bits_per_sample != 8)
	 throw MDFN_Error(0, _("Mismatch between bits per sample and compression type."));
	break;

     case MKID("ulaw"):
     case MKID("ULAW"):
	format.encoding = ENCODING_ULAW;
	if(format.bits_per_sample != 8)
	 throw MDFN_Error(0, _("Mismatch between bits per sample and compression type."));
	break;
    }
   }
  }
  else if(chunk_id == MKID("SSND"))
  {
   if(chunk_payload_size < 0x8)
    throw MDFN_Error(0, _("Sound data chunk is too small by %u bytes."), (unsigned)(0x8 - chunk_payload_size));

   if(chunks_found & 2)
    throw MDFN_Error(0, _("Sound data chunk encountered more than once."));
   //
   //
   uint8 tmp[0x8];

   chunks_found |= 2;

   chunk_bytes_read += fw->read(tmp, 0x8);
   format.block_offset = MDFN_de32msb(&tmp[0x0]);
   format.block_align = MDFN_de32msb(&tmp[0x4]);
   //
   pcm_start_pos = fw->tell();
   pcm_bound_pos = pcm_start_pos + (chunk_payload_size - chunk_bytes_read);
  }
  //
  if(chunk_bytes_read < chunk_payload_size)
  {
   //printf("%llu\n", (unsigned long long)((chunk_payload_size - chunk_bytes_read + chunk_padding_mask) &~ chunk_padding_mask));
   fw->seek(((uint64)chunk_payload_size - chunk_bytes_read + chunk_padding_mask) &~ chunk_padding_mask, SEEK_CUR);
  }
 }

 if(!(chunks_found & 1))
  throw MDFN_Error(0, _("Common chunk is missing."));

 if(!(chunks_found & 2) && comm_num_frames)
  throw MDFN_Error(0, _("Sound data chunk is missing."));

 if(!format.block_align)
  format.block_align = format.bytes_per_sample * format.channels;

 //printf("%u %llu\n", comm_num_frames, (unsigned long long)(pcm_bound_pos - pcm_start_pos));

 if((comm_num_frames * format.block_align) != (pcm_bound_pos - pcm_start_pos))
  throw MDFN_Error(0, _("Common chunk frame count is inconsistent with sound data chunk."));

 return true;
}
#undef MKID

bool CDAFReader_PCM::Load_WAV_W64(void)
{
 static const uint8 w64_riff_magic[0x10] = { 0x72, 0x69, 0x66, 0x66, 0x2E, 0x91, 0xCF, 0x11, 0xA5, 0xD6, 0x28, 0xDB, 0x04, 0xC1, 0x00, 0x00 };
 static const uint8 w64_wave_magic[0x10] = { 0x77, 0x61, 0x76, 0x65, 0xF3, 0xAC, 0xD3, 0x11, 0x8C, 0xD1, 0x00, 0xC0, 0x4F, 0x8E, 0xDB, 0x8A };
 static const uint8 fmt_magic [0x10] = { 0x66, 0x6D, 0x74, 0x20, 0xF3, 0xAC, 0xD3, 0x11, 0x8C, 0xD1, 0x00, 0xC0, 0x4F, 0x8E, 0xDB, 0x8A };
 static const uint8 data_magic[0x10] = { 0x64, 0x61, 0x74, 0x61, 0xF3, 0xAC, 0xD3, 0x11, 0x8C, 0xD1, 0x00, 0xC0, 0x4F, 0x8E, 0xDB, 0x8A };
 uint64 total_size = 0;
 uint32 magic_size = 4;
 uint32 chunk_size_size = 4;
 uint32 chunk_padding_mask = 2 - 1;
 uint8 header[0x28];

 if(fw->read(header, 0xC, false) != 0xC)
  return false;

 if(!memcmp(&header[0], "RIFF", 4) && !memcmp(&header[8], "WAVE", 4))
  total_size = (uint64)MDFN_de32lsb(&header[4]) + 8;
 else if(fw->read(&header[0xC], 0x28 - 0xC, false) == 0x28 - 0xC && !memcmp(&header[0], w64_riff_magic, 0x10) && !memcmp(&header[0x18], w64_wave_magic, 0x10))
 {
  total_size = MDFN_de64lsb(&header[0x10]);
  magic_size = 0x10;
  chunk_padding_mask = 8 - 1;
  chunk_size_size = 8;
 }
 else
  return false;

#if 0
 {
  const uint64 actual_size = fw->size();

  if(total_size != actual_size)
   throw MDFN_Error(0, _("File size derived from RIFF header(%llu bytes) does not match actual file size(%llu bytes)."), (unsigned long long)total_size, (unsigned long long)actual_size);
 }
#endif

 // Sanity check
 if(total_size >> 56)
  throw MDFN_Error(0, _("Size is larger than supported."));

 //
 //
 uint32 chunks_found = 0;

 while(fw->tell() < total_size)
 {
  if(fw->read(header, magic_size + chunk_size_size, false) != (magic_size + chunk_size_size))
   throw MDFN_Error(0, _("Unexpected EOF while reading chunk header."));
  //
  //
  uint64 chunk_bytes_read = 0;
  uint64 chunk_payload_size;

  if(chunk_size_size == 8)
  {
   const uint64 chunk_size = MDFN_de64lsb(&header[16]);

   if(chunk_size < (magic_size + chunk_size_size))
    throw MDFN_Error(0, _("Chunk 0x%016llx%016llx header-specified size is smaller than the size of the header."), (unsigned long long)MDFN_de64msb(&header[0]), (unsigned long long)MDFN_de64msb(&header[8]));

   chunk_payload_size = chunk_size - (magic_size + chunk_size_size);
  }
  else
   chunk_payload_size = MDFN_de32lsb(&header[magic_size]);
  //
  {
   const uint64 chunk_maxsize = (total_size - fw->tell());

   if(chunk_payload_size > chunk_maxsize)
   {
    if(chunk_size_size == 8)
     throw MDFN_Error(0, _("Chunk 0x%016llx%016llx is too large by %llu bytes."), (unsigned long long)MDFN_de64msb(&header[0]), (unsigned long long)MDFN_de64msb(&header[8]), (unsigned long long)(chunk_payload_size - chunk_maxsize));
    else
     throw MDFN_Error(0, _("Chunk 0x%08x is too large by %llu bytes."), MDFN_de32msb(&header[0]), (unsigned long long)(chunk_payload_size - chunk_maxsize));
   }
  }
  //
  if(!memcmp(&header[0], fmt_magic, magic_size))
  {
   if(chunk_payload_size < 0x10)
    throw MDFN_Error(0, _("Format chunk is too small by %u bytes."), (unsigned)(0x28 - chunk_payload_size));

   if(chunks_found & 1)
    throw MDFN_Error(0, _("Format chunk encountered more than once."));
   //
   //
   uint8 tmp[0x28];

   chunk_bytes_read += fw->read(tmp, 0x10);
   chunks_found |= 1;

   const uint16 fmt_tag = MDFN_de16lsb(&tmp[0x0]);
   format.channels = MDFN_de16lsb(&tmp[0x2]);
   //const uint32 fmt_rate = MDFN_de32lsb(&tmp[0x4]);
   //const uint32 fmt_abps = MDFN_de32lsb(&tmp[0x8]);
   format.block_align = MDFN_de16lsb(&tmp[0xC]);
   format.bits_per_sample = MDFN_de16lsb(&tmp[0xE]);
   format.bytes_per_sample = (format.bits_per_sample + 7) >> 3;

   format.big_endian = false;

   if(fmt_tag == 0xFFFE)
   {
    if(chunk_payload_size < 0x28)
     throw MDFN_Error(0, _("Format chunk is too small by %u bytes."), (unsigned)(0x28 - chunk_payload_size));

    chunk_bytes_read += fw->read(tmp + 0x10, 0x28 - 0x10);

    //const uint16 fmt_ext_size = MDFN_de16lsb(&tmp[0x10]);
    const uint16 fmt_valid_bits_per_sample = MDFN_de16lsb(&tmp[0x12]);
    const uint32 fmt_channel_mask = MDFN_de32lsb(&tmp[0x14]);
    const uint8 guid_linear[0x10]= { 0x01, 0x00, 0x00, 0x00, /**/ 0x00, 0x00, /**/ 0x10, 0x00, /**/ 0x80, 0x00, /**/ 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 };
    const uint8 guid_float[0x10] = { 0x03, 0x00, 0x00, 0x00, /**/ 0x00, 0x00, /**/ 0x10, 0x00, /**/ 0x80, 0x00, /**/ 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 };
    const uint8 guid_alaw[0x10] = { 0x06, 0x00, 0x00, 0x00, /**/ 0x00, 0x00, /**/ 0x10, 0x00, /**/ 0x80, 0x00, /**/ 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 };
    const uint8 guid_ulaw[0x10] = { 0x07, 0x00, 0x00, 0x00, /**/ 0x00, 0x00, /**/ 0x10, 0x00, /**/ 0x80, 0x00, /**/ 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 };
    const uint8* fmt_guid = tmp + 0x18;

    //printf("%u %u %u %08x-%04x-%04x-%04x-%08x%02x", fmt_bits_per_sample, fmt_valid_bits_per_sample, fmt_channel_mask, MDFN_de32lsb(fmt_guid + 0), MDFN_de16lsb(fmt_guid + 4), MDFN_de16lsb(fmt_guid + 6), MDFN_de16msb(fmt_guid + 8), MDFN_de32msb(fmt_guid + 10), MDFN_de16msb(fmt_guid + 14));

    if(fmt_valid_bits_per_sample > format.bits_per_sample)
     throw MDFN_Error(0, _("Valid bits per sample(%u) is larger than bits per sample(%u)."), fmt_valid_bits_per_sample, format.bits_per_sample);

    if((format.channels >= 2 && (fmt_channel_mask & 0x3) != 0x3) || (format.channels == 1 && !(fmt_channel_mask & 0x4)))
     throw MDFN_Error(0, _("Unsupported channel mask: 0x%08x"), fmt_channel_mask);

    if(!memcmp(fmt_guid, guid_linear, 0x10))
     format.encoding = (format.bits_per_sample <= 8) ? ENCODING_UNSIGNED : ENCODING_SIGNED;
    else if(!memcmp(fmt_guid, guid_float, 0x10))
     format.encoding = ENCODING_FLOAT;
    else if(!memcmp(fmt_guid, guid_alaw, 0x10))
     format.encoding = ENCODING_ALAW;
    else if(!memcmp(fmt_guid, guid_ulaw, 0x10))
     format.encoding = ENCODING_ULAW;
    else
     throw MDFN_Error(0, _("Unsupported format: %u-bit %08x-%04x-%04x-%04x-%08x%04x"), format.bits_per_sample, MDFN_de32lsb(fmt_guid + 0), MDFN_de16lsb(fmt_guid + 4), MDFN_de16lsb(fmt_guid + 6), MDFN_de16msb(fmt_guid + 8), MDFN_de32msb(fmt_guid + 10), MDFN_de16msb(fmt_guid + 14));
   }
   else if(fmt_tag == 1)
    format.encoding = (format.bits_per_sample <= 8) ? ENCODING_UNSIGNED : ENCODING_SIGNED;
   else if(fmt_tag == 3)
    format.encoding = ENCODING_FLOAT;
   else if(fmt_tag == 6)
    format.encoding = ENCODING_ALAW;
   else if(fmt_tag == 7)
    format.encoding = ENCODING_ULAW;
   else
    throw MDFN_Error(0, _("Unsupported format: %u-bit 0x%04x"), format.bits_per_sample, fmt_tag);
  }
  else if(!memcmp(&header[0], data_magic, magic_size))
  {
   if(!(chunks_found & 1))
    throw MDFN_Error(0, _("Data chunk encountered before format chunk"));

   if(chunks_found & 2)
    throw MDFN_Error(0, _("Data chunk encountered more than once."));

   chunks_found |= 2;

   pcm_start_pos = fw->tell();
   pcm_bound_pos = (uint64)pcm_start_pos + chunk_payload_size;
  }

  if(chunk_bytes_read < chunk_payload_size)
  {
   //printf("%llu\n", (unsigned long long)((chunk_payload_size - chunk_bytes_read + chunk_padding_mask) &~ chunk_padding_mask));
   fw->seek((chunk_payload_size - chunk_bytes_read + chunk_padding_mask) &~ chunk_padding_mask, SEEK_CUR);
  }
 }

 if(chunks_found != 3)
 {
  if(!chunks_found)
   throw MDFN_Error(0, _("Both format and data chunks are missing."));
  else
   throw MDFN_Error(0, _("Data chunk is missing."));
 }

 return true;
}

CDAFReader_PCM::~CDAFReader_PCM()
{

}

uint64 CDAFReader_PCM::Read_(int16 *buffer, uint64 frames)
{
 uint64 ret = 0;

 try
 {
  while(frames)
  {
   uint32 bytes_to_read = std::min<uint64>(inbuf_size, std::min<uint64>(format.block_align * frames, pcm_bound_pos - fw->tell()));
   uint32 bytes_did_read;
   uint32 frames_did_read;
   int32 rs;

   if(!bytes_to_read)
    break;

   bytes_did_read = fw->read(inbuf, bytes_to_read);

   frames_did_read = bytes_did_read / format.block_align;
   rs = bytes_did_read % format.block_align;
   if(rs)
   {
    fw->seek(-rs, SEEK_CUR);
    printf("what: %d\n", rs);
   }

   convert(format.block_offset, format.block_align, bytes_did_read - rs, inbuf, buffer);

   buffer += frames_did_read * 2;
   ret += frames_did_read;
   frames -= frames_did_read;
  }
 }
 catch(std::exception& e)
 {
  MDFN_Notify(MDFN_NOTICE_WARNING, "%s", e.what());
 }

 return ret;
}

bool CDAFReader_PCM::Seek_(uint64 frame_offset)
{
 try
 {
  frame_offset = std::min<uint64>(frame_offset, num_frames);
  fw->seek((uint64)pcm_start_pos + frame_offset * format.block_align, SEEK_SET);
 }
 catch(std::exception& e)
 {
  MDFN_Notify(MDFN_NOTICE_WARNING, "%s", e.what());
  return false;
 }

 return true;
}

uint64 CDAFReader_PCM::FrameCount(void)
{
 return num_frames;
}

CDAFReader* CDAFR_PCM_Open(Stream* fp)
{
 return new CDAFReader_PCM(fp);
}

}
