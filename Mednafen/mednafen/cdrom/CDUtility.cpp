/* Mednafen - Multi-system Emulator
 *
 *  Subchannel Q CRC Code:  Copyright (C) 1998  Andreas Mueller <mueller@daneb.ping.de>
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

#include "../mednafen.h"
#include "CDUtility.h"
#include "dvdisaster.h"
#include "lec.h"

#include <assert.h>
//  Kill_LEC_Correct();


namespace CDUtility
{

// lookup table for crc calculation
static uint16 subq_crctab[256] = 
{
  0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7, 0x8108,
  0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF, 0x1231, 0x0210,
  0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6, 0x9339, 0x8318, 0xB37B,
  0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE, 0x2462, 0x3443, 0x0420, 0x1401,
  0x64E6, 0x74C7, 0x44A4, 0x5485, 0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE,
  0xF5CF, 0xC5AC, 0xD58D, 0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6,
  0x5695, 0x46B4, 0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D,
  0xC7BC, 0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
  0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B, 0x5AF5,
  0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12, 0xDBFD, 0xCBDC,
  0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A, 0x6CA6, 0x7C87, 0x4CE4,
  0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41, 0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD,
  0xAD2A, 0xBD0B, 0x8D68, 0x9D49, 0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13,
  0x2E32, 0x1E51, 0x0E70, 0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A,
  0x9F59, 0x8F78, 0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E,
  0xE16F, 0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,
  0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E, 0x02B1,
  0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256, 0xB5EA, 0xA5CB,
  0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D, 0x34E2, 0x24C3, 0x14A0,
  0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xA7DB, 0xB7FA, 0x8799, 0x97B8,
  0xE75F, 0xF77E, 0xC71D, 0xD73C, 0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657,
  0x7676, 0x4615, 0x5634, 0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9,
  0xB98A, 0xA9AB, 0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882,
  0x28A3, 0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,
  0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92, 0xFD2E,
  0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9, 0x7C26, 0x6C07,
  0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1, 0xEF1F, 0xFF3E, 0xCF5D,
  0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8, 0x6E17, 0x7E36, 0x4E55, 0x5E74,
  0x2E93, 0x3EB2, 0x0ED1, 0x1EF0
};


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


bool subq_check_checksum(const uint8 *SubQBuf)
{
 uint16 crc = 0;
 uint16 stored_crc = 0;

 stored_crc = SubQBuf[0xA] << 8;
 stored_crc |= SubQBuf[0xB];

 for(int i = 0; i < 0xA; i++)
  crc = subq_crctab[(crc >> 8) ^ SubQBuf[i]] ^ (crc << 8);

 crc = ~crc;

 return(crc == stored_crc);
}

void subq_generate_checksum(uint8 *buf)
{
 uint16 crc = 0;

 for(int i = 0; i < 0xA; i++)
  crc = subq_crctab[(crc >> 8) ^ buf[i]] ^ (crc << 8);

 // Checksum
 buf[0xa] = ~(crc >> 8);
 buf[0xb] = ~(crc);
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
