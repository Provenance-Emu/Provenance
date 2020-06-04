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

#include <mednafen/mednafen.h>
#include "CDUtility.h"
#include "dvdisaster.h"
#include "lec.h"

//  Kill_LEC_Correct();

namespace Mednafen
{

namespace CDUtility
{
static uint8 scramble_table[2352 - 12];

static bool CDUtility_Inited = false;

static void InitScrambleTable(void)
{
 unsigned cv = 1;

 for(unsigned i = 12; i < 2352; i++)
 {
  unsigned char z = 0;

  for(int b = 0; b < 8; b++)
  {
   z |= (cv & 1) << b;

   int feedback = ((cv >> 1) & 1) ^ (cv & 1);
   cv = (cv >> 1) | (feedback << 14);
  }

  scramble_table[i - 12] = z;
 }

 //for(int i = 0; i < 2352 - 12; i++)
 // printf("0x%02x, ", scramble_table[i]);
}

void CDUtility_Init(void)
{
 if(!CDUtility_Inited)
 {
  Init_LEC_Correct();

  InitScrambleTable();

  CDUtility_Inited = true;
 }
}

void encode_mode0_sector(uint32 aba, uint8 *sector_data)
{
 CDUtility_Init();

 lec_encode_mode0_sector(aba, sector_data);
}

void encode_mode1_sector(uint32 aba, uint8 *sector_data)
{
 CDUtility_Init();

 lec_encode_mode1_sector(aba, sector_data);
}

void encode_mode2_sector(uint32 aba, uint8 *sector_data)
{
 CDUtility_Init();

 lec_encode_mode2_sector(aba, sector_data);
}

void encode_mode2_form1_sector(uint32 aba, uint8 *sector_data)
{
 CDUtility_Init();

 lec_encode_mode2_form1_sector(aba, sector_data);
}

void encode_mode2_form2_sector(uint32 aba, uint8 *sector_data)
{
 CDUtility_Init();

 lec_encode_mode2_form2_sector(aba, sector_data);
}

bool edc_check(const uint8 *sector_data, bool xa)
{
 CDUtility_Init();

 return(CheckEDC(sector_data, xa));
}

bool edc_lec_check_and_correct(uint8 *sector_data, bool xa)
{
 CDUtility_Init();

 return(ValidateRawSector(sector_data, xa));
}

void subq_deinterleave(const uint8 *SubPWBuf, uint8 *qbuf)
{
 memset(qbuf, 0, 0xC);

 for(int i = 0; i < 96; i++)
 {
  qbuf[i >> 3] |= ((SubPWBuf[i] >> 6) & 0x1) << (7 - (i & 0x7));
 }
}


// Deinterleaves 96 bytes of subchannel P-W data from 96 bytes of interleaved subchannel PW data.
void subpw_deinterleave(const uint8 *in_buf, uint8 *out_buf)
{
 assert(in_buf != out_buf);

 memset(out_buf, 0, 96);

 for(unsigned ch = 0; ch < 8; ch++)
 {
  for(unsigned i = 0; i < 96; i++)
  {
   out_buf[(ch * 12) + (i >> 3)] |= ((in_buf[i] >> (7 - ch)) & 0x1) << (7 - (i & 0x7));
  }
 }

}

// Interleaves 96 bytes of subchannel P-W data from 96 bytes of uninterleaved subchannel PW data.
void subpw_interleave(const uint8 *in_buf, uint8 *out_buf)
{
 assert(in_buf != out_buf);

 for(unsigned d = 0; d < 12; d++)
 {
  for(unsigned bitpoodle = 0; bitpoodle < 8; bitpoodle++)
  {
   uint8 rawb = 0;

   for(unsigned ch = 0; ch < 8; ch++)
   {
    rawb |= ((in_buf[ch * 12 + d] >> (7 - bitpoodle)) & 1) << (7 - ch);
   }
   out_buf[(d << 3) + bitpoodle] = rawb;
  }
 }
}

// NOTES ON LEADOUT AREA SYNTHESIS
//
//  I'm not trusting that the "control" field for the TOC leadout entry will always be set properly, so | the control fields for the last track entry
//  and the leadout entry together before extracting the D2 bit.  Audio track->data leadout is fairly benign though maybe noisy(especially if we ever implement
//  data scrambling properly), but data track->audio leadout could break things in an insidious manner for the more accurate drive emulation code).
//
void subpw_synth_leadout_lba(const TOC& toc, const int32 lba, uint8* SubPWBuf)
{
 uint8 buf[0xC];
 uint32 lba_relative;
 uint32 ma, sa, fa;
 uint32 m, s, f;

 lba_relative = lba - toc.tracks[100].lba;

 f = (lba_relative % 75);
 s = ((lba_relative / 75) % 60);
 m = (lba_relative / 75 / 60);

 fa = (lba + 150) % 75;
 sa = ((lba + 150) / 75) % 60;
 ma = ((lba + 150) / 75 / 60);

 uint8 adr = 0x1; // Q channel data encodes position
 uint8 control = toc.tracks[100].control;

 if(toc.tracks[toc.last_track].valid)
  control |= toc.tracks[toc.last_track].control & 0x4;
 else if(toc.disc_type == DISC_TYPE_CD_I)
  control |= 0x4;

 memset(buf, 0, 0xC);
 buf[0] = (adr << 0) | (control << 4);
 buf[1] = 0xAA;
 buf[2] = 0x01;

 // Track relative MSF address
 buf[3] = U8_to_BCD(m);
 buf[4] = U8_to_BCD(s);
 buf[5] = U8_to_BCD(f);

 buf[6] = 0; // Zerroooo

 // Absolute MSF address
 buf[7] = U8_to_BCD(ma);
 buf[8] = U8_to_BCD(sa);
 buf[9] = U8_to_BCD(fa);

 subq_generate_checksum(buf);

 for(int i = 0; i < 96; i++)
  SubPWBuf[i] = (((buf[i >> 3] >> (7 - (i & 0x7))) & 1) ? 0x40 : 0x00) | 0x80;
}

void synth_leadout_sector_lba(uint8 mode, const TOC& toc, const int32 lba, uint8* out_buf)
{
 memset(out_buf, 0, 2352 + 96);
 subpw_synth_leadout_lba(toc, lba, out_buf + 2352);

 if(out_buf[2352 + 1] & 0x40)
 {
  if(mode == 0xFF) 
  {
   if(toc.disc_type == DISC_TYPE_CD_XA || toc.disc_type == DISC_TYPE_CD_I)
    mode = 0x02;
   else
    mode = 0x01;
  }

  switch(mode)
  {
   default:
	encode_mode0_sector(LBA_to_ABA(lba), out_buf);
	break;

   case 0x01:
	encode_mode1_sector(LBA_to_ABA(lba), out_buf);
	break;

   case 0x02:
	out_buf[12 +  6] = 0x20;
	out_buf[12 + 10] = 0x20;
	encode_mode2_form2_sector(LBA_to_ABA(lba), out_buf);
	break;
  }
 }
}

// ISO/IEC 10149:1995 (E): 20.2
//
void subpw_synth_udapp_lba(const TOC& toc, const int32 lba, const int32 lba_subq_relative_offs, uint8* SubPWBuf)
{
 uint8 buf[0xC];
 uint32 lba_relative;
 uint32 ma, sa, fa;
 uint32 m, s, f;

 if(lba < -150 || lba >= 0)
  printf("[BUG] subpw_synth_udapp_lba() lba out of range --- %d\n", lba);

 {
  int32 lba_tmp = lba + lba_subq_relative_offs;

  if(lba_tmp < 0)
   lba_relative = 0 - 1 - lba_tmp;
  else
   lba_relative = lba_tmp - 0;
 }

 f = (lba_relative % 75);
 s = ((lba_relative / 75) % 60);
 m = (lba_relative / 75 / 60);

 fa = (lba + 150) % 75;
 sa = ((lba + 150) / 75) % 60;
 ma = ((lba + 150) / 75 / 60);

 uint8 adr = 0x1; // Q channel data encodes position
 uint8 control;

 if(toc.disc_type == DISC_TYPE_CD_I && toc.first_track > 1)
  control = 0x4;
 else if(toc.tracks[toc.first_track].valid)
  control = toc.tracks[toc.first_track].control;
 else
  control = 0x0;

 memset(buf, 0, 0xC);
 buf[0] = (adr << 0) | (control << 4);
 buf[1] = U8_to_BCD(toc.first_track);
 buf[2] = U8_to_BCD(0x00);

 // Track relative MSF address
 buf[3] = U8_to_BCD(m);
 buf[4] = U8_to_BCD(s);
 buf[5] = U8_to_BCD(f);

 buf[6] = 0; // Zerroooo

 // Absolute MSF address
 buf[7] = U8_to_BCD(ma);
 buf[8] = U8_to_BCD(sa);
 buf[9] = U8_to_BCD(fa);

 subq_generate_checksum(buf);

 for(int i = 0; i < 96; i++)
  SubPWBuf[i] = (((buf[i >> 3] >> (7 - (i & 0x7))) & 1) ? 0x40 : 0x00) | 0x80;
}

void synth_udapp_sector_lba(uint8 mode, const TOC& toc, const int32 lba, int32 lba_subq_relative_offs, uint8* out_buf)
{
 memset(out_buf, 0, 2352 + 96);
 subpw_synth_udapp_lba(toc, lba, lba_subq_relative_offs, out_buf + 2352);

 if(out_buf[2352 + 1] & 0x40)
 {
  if(mode == 0xFF) 
  {
   if(toc.disc_type == DISC_TYPE_CD_XA || toc.disc_type == DISC_TYPE_CD_I)
    mode = 0x02;
   else
    mode = 0x01;
  }

  switch(mode)
  {
   default:
	encode_mode0_sector(LBA_to_ABA(lba), out_buf);
	break;

   case 0x01:
	encode_mode1_sector(LBA_to_ABA(lba), out_buf);
	break;

   case 0x02:
	out_buf[12 +  6] = 0x20;
	out_buf[12 + 10] = 0x20;
	encode_mode2_form2_sector(LBA_to_ABA(lba), out_buf);
	break;
  }
 }
}

#if 0
bool subq_extrapolate(const uint8 *subq_input, int32 position_delta, uint8 *subq_output)
{
 assert(subq_check_checksum(subq_input));


 subq_generate_checksum(subq_output);
}
#endif

void scrambleize_data_sector(uint8 *sector_data)
{
 for(unsigned i = 12; i < 2352; i++)
  sector_data[i] ^= scramble_table[i - 12];
}

}

}
