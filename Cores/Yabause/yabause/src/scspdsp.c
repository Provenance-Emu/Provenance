/*  Copyright 2015 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "scsp.h"
#include "scspdsp.h"

s32 float_to_int(u16 f_val);
u16 int_to_float(u32 i_val);

//saturate 24 bit signed integer
static INLINE s32 saturate_24(s32 value)
{
   if (value > 8388607)
      value = 8388607;

   if (value < (-8388608))
      value = (-8388608);

   return value;
}

void ScspDspExec(ScspDsp* dsp, int addr, u8 * sound_ram)
{
   u16* sound_ram_16 = (u16*)sound_ram;
   u64 mul_temp = 0;

   union ScspDspInstruction instruction;
   instruction.all = scsp_dsp.mpro[addr];

   if (instruction.part.ira >= 0 && instruction.part.ira <= 0x1f)
      dsp->inputs = dsp->mems[instruction.part.ira & 0x1f];
   else if (instruction.part.ira >= 0x20 && instruction.part.ira <= 0x2f)
      dsp->inputs = dsp->mixs[instruction.part.ira - 0x20] << 4;
   else if (instruction.part.ira == 0x30 || instruction.part.ira == 0x31)
      dsp->inputs = dsp->exts[(instruction.part.ira - 0x30) & 1];

   if (instruction.part.iwt)
      dsp->mems[instruction.part.iwa] = dsp->mrd_value;

   if (instruction.part.bsel == 0)
   {
      s32 temp_val = dsp->temp[(instruction.part.tra + dsp->mdec_ct) & 0x7f];

      if (temp_val & 0x800000)
         temp_val |= 0x3000000;//sign extend to 26 bits

      dsp->b = temp_val;
   }
   else if (instruction.part.bsel == 1)
      dsp->b = dsp->acc;

   if (instruction.part.negb)
      dsp->b = 0 - dsp->b;

   if (instruction.part.zero)
      dsp->b = 0;

   if (instruction.part.xsel == 0)
      dsp->x = dsp->temp[(instruction.part.tra + dsp->mdec_ct) & 0x7f];
   else if (instruction.part.xsel == 1)
      dsp->x = dsp->inputs;

   if (instruction.part.ysel == 0)
      dsp->y = dsp->frc_reg;
   else if (instruction.part.ysel == 1)
   {
      dsp->y = dsp->coef[instruction.part.coef] >> 3;

      if (dsp->coef[instruction.part.coef] & 0x8000)
         dsp->y |= 0xE000;
   }
   else if (instruction.part.ysel == 2)
      dsp->y = (dsp->y_reg >> 11) & 0x1FFF;
   else if (instruction.part.ysel == 3)
      dsp->y = (dsp->y_reg >> 4) & 0xFFF;

   if (instruction.part.yrl)
      dsp->y_reg = dsp->inputs;

   if (instruction.part.shift == 0)
      dsp->shifted = saturate_24(dsp->acc);
   else if (instruction.part.shift == 1)
      dsp->shifted = saturate_24(dsp->acc * 2);
   else if (instruction.part.shift == 2)
      dsp->shifted = (dsp->acc * 2) & 0xffffff;
   else if (instruction.part.shift == 2)
      dsp->shifted = dsp->acc & 0xffffff;

   mul_temp = (u64)dsp->x * (u64)dsp->y;//prevent clipping
   dsp->acc = (mul_temp >> 12) + dsp->b;

   dsp->acc &= 0xffffff;

   if (dsp->acc & 0x800000)
      dsp->acc |= 0xff000000;

   if (instruction.part.twt)
      dsp->temp[(instruction.part.twa + dsp->mdec_ct) & 0x7f] = dsp->shifted;

   if (instruction.part.frcl)
   {
      if (instruction.part.shift == 3)
         dsp->frc_reg = dsp->shifted & 0xFFF;
      else
         dsp->frc_reg = (dsp->shifted >> 11) & 0x1FFF;
   }

   if (instruction.part.mrd || instruction.part.mwt)
   {
      u32 address = dsp->madrs[instruction.part.masa];

      if (instruction.part.table == 0)
         address += dsp->mdec_ct;

      if (instruction.part.adreb)
         address += dsp->adrs_reg & 0xfff;

      if (instruction.part.nxadr)
         address += 1;

      if (instruction.part.table == 0)
      {
         if (dsp->rbl == 0)
            address &= 0x1fff;
         else if (dsp->rbl == 1)
            address &= 0x3fff;
         else if (dsp->rbl == 2)
            address &= 0x7fff;
         else if (dsp->rbl == 3)
            address &= 0xffff;
      }
      else if (instruction.part.table == 1)
         address &= 0xffff;

      address += (dsp->rbp << 11) * 2;

      if (instruction.part.mrd)
      {
         u16 temp = sound_ram_16[address & 0x7ffff];
         dsp->mrd_value = float_to_int(temp);
      }

      if (instruction.part.mwt)
      {
         s32 shifted_val = dsp->shifted;
         shifted_val = int_to_float(shifted_val);
         sound_ram_16[address & 0x7ffff] = shifted_val;
      }
   }

   if (instruction.part.adrl)
   {
      if (instruction.part.shift == 3)
         dsp->adrs_reg = dsp->inputs >> 16;
      else
         dsp->adrs_reg = (dsp->shifted >> 12) & 0xFFF;
   }

   if (instruction.part.ewt)
      dsp->efreg[instruction.part.ewa] = dsp->shifted >> 8;
}

//sign extended to 32 bits instead of 24
s32 float_to_int(u16 f_val)
{
   u32 sign = (f_val >> 15) & 1;
   u32 sign_inverse = (!sign) & 1;
   u32 exponent = (f_val >> 11) & 0xf;
   u32 mantissa = f_val & 0x7FF;

   s32 ret_val = sign << 31;

   if (exponent > 11)
   {
      exponent = 11;
      ret_val |= (sign << 30);
   }
   else
      ret_val |= (sign_inverse << 30);

   ret_val |= mantissa << 19;

   ret_val = ret_val >> (exponent + (1 << 3));

   return ret_val;
}

u16 int_to_float(u32 i_val)
{
   u32 sign = (i_val >> 23) & 1;
   u32 exponent = 0;

   if (sign != 0)
      i_val = (~i_val) & 0x7FFFFF;

   if (i_val <= 0x1FFFF)
   {
      i_val *= 64;
      exponent += 0x3000;
   }

   if (i_val <= 0xFFFFF)
   {
      i_val *= 8;
      exponent += 0x1800;
   }

   if (i_val <= 0x3FFFFF)
   {
      i_val *= 2;
      exponent += 0x800;
   }

   if (i_val <= 0x3FFFFF)
   {
      i_val *= 2;
      exponent += 0x800;
   }

   if (i_val <= 0x3FFFFF)
      exponent += 0x800;

   i_val >>= 11;
   i_val &= 0x7ff;
   i_val |= exponent;

   if (sign != 0)
      i_val ^= (0x7ff | (1 << 15));

   return i_val;
}

int ScspDspAssembleGetValue(char* instruction)
{
   char temp[512] = { 0 };
   int value = 0;
   sscanf(instruction, "%s %d", temp, &value);
   return value;
}

u64 ScspDspAssembleLine(char* line)
{
   union ScspDspInstruction instruction = { 0 };

   char* temp = NULL;

   if ((temp = strstr(line, "tra")))
   {
      instruction.part.tra = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "twt"))
   {
      instruction.part.twt = 1;
   }

   if ((temp = strstr(line, "twa")))
   {
      instruction.part.twa = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "xsel"))
   {
      instruction.part.xsel = 1;
   }

   if ((temp = strstr(line, "ysel")))
   {
      instruction.part.ysel = ScspDspAssembleGetValue(temp);
   }

   if ((temp = strstr(line, "ira")))
   {
      instruction.part.ira = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "iwt"))
   {
      instruction.part.iwt = 1;
   }

   if ((temp = strstr(line, "iwa")))
   {
      instruction.part.iwa = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "table"))
   {
      instruction.part.table = 1;
   }

   if (strstr(line, "mwt"))
   {
      instruction.part.mwt = 1;
   }

   if (strstr(line, "mrd"))
   {
      instruction.part.mrd = 1;
   }

   if (strstr(line, "ewt"))
   {
      instruction.part.ewt = 1;
   }

   if ((temp = strstr(line, "ewa")))
   {
      instruction.part.ewa = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "adrl"))
   {
      instruction.part.adrl = 1;
   }

   if (strstr(line, "frcl"))
   {
      instruction.part.frcl = 1;
   }

   if ((temp = strstr(line, "shift")))
   {
      instruction.part.shift = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "yrl"))
   {
      instruction.part.yrl = 1;
   }

   if (strstr(line, "negb"))
   {
      instruction.part.negb = 1;
   }

   if (strstr(line, "zero"))
   {
      instruction.part.zero = 1;
   }

   if (strstr(line, "bsel"))
   {
      instruction.part.bsel = 1;
   }

   if (strstr(line, "nofl"))
   {
      instruction.part.nofl = 1;
   }

   if ((temp = strstr(line, "coef")))
   {
      instruction.part.coef = ScspDspAssembleGetValue(temp);
   }

   if ((temp = strstr(line, "masa")))
   {
      instruction.part.masa = ScspDspAssembleGetValue(temp);
   }

   if (strstr(line, "adreb"))
   {
      instruction.part.adreb = 1;
   }

   if (strstr(line, "nxadr"))
   {
      instruction.part.adreb = 1;
   }

   if (strstr(line, "nop"))
   {
      instruction.all = 0;
   }

   return instruction.all;
}

void ScspDspAssembleFromFile(char * filename, u64* output)
{
   int i;
   char line[1024] = { 0 };

   FILE * fp = fopen(filename, "r");

   if (!fp)
   {
      return;
   }

   for (i = 0; i < 128; i++)
   {
      char * result = fgets(line, sizeof(line), fp);
      output[i] = ScspDspAssembleLine(line);
   }
   fclose(fp);
}

void ScspDspDisasm(u8 addr, char *outstring)
{
   union ScspDspInstruction instruction;

   instruction.all = scsp_dsp.mpro[addr];

   sprintf(outstring, "%02X: ", addr);
   outstring += strlen(outstring);

   if (instruction.all == 0)
   {
      sprintf(outstring, "nop ");
      outstring += strlen(outstring);
      return;
   }

   if (instruction.part.nofl)
   {
      sprintf(outstring, "nofl ");
      outstring += strlen(outstring);
   }

   if (instruction.part.coef)
   {
      sprintf(outstring, "coef %02X ", (unsigned int)(instruction.part.coef & 0x3F));
      outstring += strlen(outstring);
   }

   if (instruction.part.masa)
   {
      sprintf(outstring, "masa %02X ", (unsigned int)(instruction.part.masa & 0x1F));
      outstring += strlen(outstring);
   }

   if (instruction.part.adreb)
   {
      sprintf(outstring, "adreb ");
      outstring += strlen(outstring);
   }

   if (instruction.part.nxadr)
   {
      sprintf(outstring, "nxadr ");
      outstring += strlen(outstring);
   }

   if (instruction.part.table)
   {
      sprintf(outstring, "table ");
      outstring += strlen(outstring);
   }

   if (instruction.part.mwt)
   {
      sprintf(outstring, "mwt ");
      outstring += strlen(outstring);
   }

   if (instruction.part.mrd)
   {
      sprintf(outstring, "mrd ");
      outstring += strlen(outstring);
   }

   if (instruction.part.ewt)
   {
      sprintf(outstring, "ewt ");
      outstring += strlen(outstring);
   }

   if (instruction.part.ewa)
   {
      sprintf(outstring, "ewa %01X ", (unsigned int)(instruction.part.ewa & 0xf));
      outstring += strlen(outstring);
   }

   if (instruction.part.adrl)
   {
      sprintf(outstring, "adrl ");
      outstring += strlen(outstring);
   }

   if (instruction.part.frcl)
   {
      sprintf(outstring, "frcl ");
      outstring += strlen(outstring);
   }

   if (instruction.part.shift)
   {
      sprintf(outstring, "shift %d ", (int)(instruction.part.shift & 3));
      outstring += strlen(outstring);
   }

   if (instruction.part.yrl)
   {
      sprintf(outstring, "yrl ");
      outstring += strlen(outstring);
   }

   if (instruction.part.negb)
   {
      sprintf(outstring, "negb ");
      outstring += strlen(outstring);
   }

   if (instruction.part.zero)
   {
      sprintf(outstring, "zero ");
      outstring += strlen(outstring);
   }

   if (instruction.part.bsel)
   {
      sprintf(outstring, "bsel ");
      outstring += strlen(outstring);
   }

   if (instruction.part.xsel)
   {
      sprintf(outstring, "xsel ");
      outstring += strlen(outstring);
   }

   if (instruction.part.ysel)
   {
      sprintf(outstring, "ysel %d ", (int)(instruction.part.ysel & 3));
      outstring += strlen(outstring);
   }

   if (instruction.part.ira)
   {
      sprintf(outstring, "ira %02X ", (int)(instruction.part.ira & 0x3F));
      outstring += strlen(outstring);
   }

   if (instruction.part.iwt)
   {
      sprintf(outstring, "iwt ");
      outstring += strlen(outstring);
   }

   if (instruction.part.iwa)
   {
      sprintf(outstring, "iwa %02X ", (unsigned int)(instruction.part.iwa & 0x1F));
      outstring += strlen(outstring);
   }

   if (instruction.part.tra)
   {
      sprintf(outstring, "tra %02X ", (unsigned int)(instruction.part.tra & 0x7F));
      outstring += strlen(outstring);
   }

   if (instruction.part.twt)
   {
      sprintf(outstring, "twt ");
      outstring += strlen(outstring);
   }

   if (instruction.part.twa)
   {
      sprintf(outstring, "twa %02X ", (unsigned int)(instruction.part.twa & 0x7F));
      outstring += strlen(outstring);
   }

   if (instruction.part.unknown)
   {
      sprintf(outstring, "unknown ");
      outstring += strlen(outstring);
   }

   if (instruction.part.unknown2)
   {
      sprintf(outstring, "unknown2 ");
      outstring += strlen(outstring);
   }

   if (instruction.part.unknown3)
   {
      sprintf(outstring, "unknown3 %d", (int)(instruction.part.unknown3 & 3));
      outstring += strlen(outstring);
   }
}

void ScspDspDisassembleToFile(char * filename)
{
   int i;
   FILE * fp = fopen(filename,"w");

   if (!fp)
   {
      return;
   }

   for (i = 0; i < 128; i++)
   {
      char output[1024] = { 0 };
      ScspDspDisasm(i, output);
      fprintf(fp, "%s\n", output);
   }

   fclose(fp);
}
