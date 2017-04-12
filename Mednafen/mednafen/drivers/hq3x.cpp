//hq3x filter demo program
//----------------------------------------------------------
//Copyright (C) 2003 MaxSt ( maxst@hiend3d.com )

//This program is free software; you can redistribute it and/or
//modify it under the terms of the GNU Lesser General Public
//License as published by the Free Software Foundation; either
//version 2.1 of the License, or (at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//Lesser General Public License for more details.
//
//You should have received a copy of the GNU Lesser General Public
//License along with this program; if not, write to the Free Software
//Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

/* Modified for usage in Mednafen */

#include "main.h"

#define HQXX_INTERNAL
#include "hqxx-common.h"

static inline void Interp1(unsigned char * pc, int c1, int c2)
{
  *((int*)pc) = (c1*3+c2) >> 2;
}

static inline void Interp2(unsigned char * pc, int c1, int c2, int c3)
{
  *((int*)pc) = (c1*2+c2+c3) >> 2;
}

static inline void Interp3(unsigned char * pc, int c1, int c2)
{
  //*((int*)pc) = (c1*7+c2)/8;

  *((int*)pc) = ((((c1 & 0x00FF00)*7 + (c2 & 0x00FF00) ) & 0x0007F800) +
                 (((c1 & 0xFF00FF)*7 + (c2 & 0xFF00FF) ) & 0x07F807F8)) >> 3;
}

static inline void Interp4(unsigned char * pc, int c1, int c2, int c3)
{
  //*((int*)pc) = (c1*2+(c2+c3)*7)/16;

  *((int*)pc) = ((((c1 & 0x00FF00)*2 + ((c2 & 0x00FF00) + (c3 & 0x00FF00))*7 ) & 0x000FF000) +
                 (((c1 & 0xFF00FF)*2 + ((c2 & 0xFF00FF) + (c3 & 0xFF00FF))*7 ) & 0x0FF00FF0)) >> 4;
}

static inline void Interp5(unsigned char * pc, int c1, int c2)
{
  *((int*)pc) = (c1+c2) >> 1;
}

#define PIXEL00_1M  Interp1(pOut, w[5], w[1]);
#define PIXEL00_1U  Interp1(pOut, w[5], w[2]);
#define PIXEL00_1L  Interp1(pOut, w[5], w[4]);
#define PIXEL00_2   Interp2(pOut, w[5], w[4], w[2]);
#define PIXEL00_4   Interp4(pOut, w[5], w[4], w[2]);
#define PIXEL00_5   Interp5(pOut, w[4], w[2]);
#define PIXEL00_C   *((int*)(pOut))   = w[5];

#define PIXEL01_1   Interp1(pOut+4, w[5], w[2]);
#define PIXEL01_3   Interp3(pOut+4, w[5], w[2]);
#define PIXEL01_6   Interp1(pOut+4, w[2], w[5]);
#define PIXEL01_C   *((int*)(pOut+4)) = w[5];

#define PIXEL02_1M  Interp1(pOut+8, w[5], w[3]);
#define PIXEL02_1U  Interp1(pOut+8, w[5], w[2]);
#define PIXEL02_1R  Interp1(pOut+8, w[5], w[6]);
#define PIXEL02_2   Interp2(pOut+8, w[5], w[2], w[6]);
#define PIXEL02_4   Interp4(pOut+8, w[5], w[2], w[6]);
#define PIXEL02_5   Interp5(pOut+8, w[2], w[6]);
#define PIXEL02_C   *((int*)(pOut+8)) = w[5];

#define PIXEL10_1   Interp1(pOut+BpL, w[5], w[4]);
#define PIXEL10_3   Interp3(pOut+BpL, w[5], w[4]);
#define PIXEL10_6   Interp1(pOut+BpL, w[4], w[5]);
#define PIXEL10_C   *((int*)(pOut+BpL)) = w[5];

#define PIXEL11     *((int*)(pOut+BpL+4)) = w[5];

#define PIXEL12_1   Interp1(pOut+BpL+8, w[5], w[6]);
#define PIXEL12_3   Interp3(pOut+BpL+8, w[5], w[6]);
#define PIXEL12_6   Interp1(pOut+BpL+8, w[6], w[5]);
#define PIXEL12_C   *((int*)(pOut+BpL+8)) = w[5];

#define PIXEL20_1M  Interp1(pOut+BpL+BpL, w[5], w[7]);
#define PIXEL20_1D  Interp1(pOut+BpL+BpL, w[5], w[8]);
#define PIXEL20_1L  Interp1(pOut+BpL+BpL, w[5], w[4]);
#define PIXEL20_2   Interp2(pOut+BpL+BpL, w[5], w[8], w[4]);
#define PIXEL20_4   Interp4(pOut+BpL+BpL, w[5], w[8], w[4]);
#define PIXEL20_5   Interp5(pOut+BpL+BpL, w[8], w[4]);
#define PIXEL20_C   *((int*)(pOut+BpL+BpL)) = w[5];

#define PIXEL21_1   Interp1(pOut+BpL+BpL+4, w[5], w[8]);
#define PIXEL21_3   Interp3(pOut+BpL+BpL+4, w[5], w[8]);
#define PIXEL21_6   Interp1(pOut+BpL+BpL+4, w[8], w[5]);
#define PIXEL21_C   *((int*)(pOut+BpL+BpL+4)) = w[5];

#define PIXEL22_1M  Interp1(pOut+BpL+BpL+8, w[5], w[9]);
#define PIXEL22_1D  Interp1(pOut+BpL+BpL+8, w[5], w[8]);
#define PIXEL22_1R  Interp1(pOut+BpL+BpL+8, w[5], w[6]);
#define PIXEL22_2   Interp2(pOut+BpL+BpL+8, w[5], w[6], w[8]);
#define PIXEL22_4   Interp4(pOut+BpL+BpL+8, w[5], w[6], w[8]);
#define PIXEL22_5   Interp5(pOut+BpL+BpL+8, w[6], w[8]);
#define PIXEL22_C   *((int*)(pOut+BpL+BpL+8)) = w[5];

static int MDFN_FASTCALL Diff(unsigned int w1, unsigned int w2)
{
  int YUV1;
  int YUV2;

  YUV1 = hqxx_RGB_to_YUV(w1);
  YUV2 = hqxx_RGB_to_YUV(w2);
  return ( ( abs((YUV1 & Ymask) - (YUV2 & Ymask)) > trY ) ||
           ( abs((YUV1 & Umask) - (YUV2 & Umask)) > trU ) ||
           ( abs((YUV1 & Vmask) - (YUV2 & Vmask)) > trV ) );
}

void hq3x_32( unsigned char * pIn, unsigned char * pOut, int Xres, int Yres, int srcBpL, int BpL )
{
  int  i, j, k;
  int  prevline, nextline;
  int  w[10];

  //   +----+----+----+
  //   |    |    |    |
  //   | w1 | w2 | w3 |
  //   +----+----+----+
  //   |    |    |    |
  //   | w4 | w5 | w6 |
  //   +----+----+----+
  //   |    |    |    |
  //   | w7 | w8 | w9 |
  //   +----+----+----+

  for (j=0; j<Yres; j++)
  {
    if (j>0)      prevline = -srcBpL; else prevline = 0;
    if (j<Yres-1) nextline =  srcBpL; else nextline = 0;

    for (i=0; i<Xres; i++)
    {
      int pattern;
      int flag;
      int YUV1Y,YUV1U,YUV1V;

      w[2] = *((unsigned int*)(pIn + prevline)) & 0xFCFCFC;
      w[5] = *((unsigned int*)pIn) & 0xFCFCFC;
      w[8] = *((unsigned int*)(pIn + nextline)) & 0xFCFCFC;

      if (i>0)
      {
        w[1] = *((unsigned int*)(pIn + prevline - sizeof(uint32))) & 0xFCFCFC;
        w[4] = *((unsigned int*)(pIn - sizeof(uint32))) & 0xFCFCFC;
        w[7] = *((unsigned int*)(pIn + nextline - sizeof(uint32))) & 0xFCFCFC;
      }
      else
      {
        w[1] = w[2];
        w[4] = w[5];
        w[7] = w[8];
      }

      if (i<Xres-1)
      {
        w[3] = *((unsigned int*)(pIn + prevline + sizeof(uint32))) & 0xFCFCFC;
        w[6] = *((unsigned int*)(pIn + sizeof(uint32))) & 0xFCFCFC;
        w[9] = *((unsigned int*)(pIn + nextline + sizeof(uint32))) & 0xFCFCFC;
      }
      else
      {
        w[3] = w[2];
        w[6] = w[5];
        w[9] = w[8];
      }


      pattern = 0;
      flag = 1;

      YUV1Y = YUV1U = YUV1V = hqxx_RGB_to_YUV(w[5]);

      YUV1Y &= Ymask;
      YUV1U &= Umask;
      YUV1V &= Vmask;

      for (k=1; k<=9; k++)
      {
        if (k==5) continue;

        if ( w[k] != w[5] )
        {
          int YUV2 = hqxx_RGB_to_YUV(w[k]);

          if ( ( abs(YUV1Y - (YUV2 & Ymask)) > trY ) ||
               ( abs(YUV1U - (YUV2 & Umask)) > trU ) ||
               ( abs(YUV1V - (YUV2 & Vmask)) > trV ) )
            pattern |= flag;
        }
        flag <<= 1;
      }

      switch (pattern)
      {
        case 0:
        case 1:
        case 4:
        case 32:
        case 128:
        case 5:
        case 132:
        case 160:
        case 33:
        case 129:
        case 36:
        case 133:
        case 164:
        case 161:
        case 37:
        case 165:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 2:
        case 34:
        case 130:
        case 162:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 16:
        case 17:
        case 48:
        case 49:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 64:
        case 65:
        case 68:
        case 69:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 8:
        case 12:
        case 136:
        case 140:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 3:
        case 35:
        case 131:
        case 163:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 6:
        case 38:
        case 134:
        case 166:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 20:
        case 21:
        case 52:
        case 53:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 144:
        case 145:
        case 176:
        case 177:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 192:
        case 193:
        case 196:
        case 197:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 96:
        case 97:
        case 100:
        case 101:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 40:
        case 44:
        case 168:
        case 172:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 9:
        case 13:
        case 137:
        case 141:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 18:
        case 50:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_1M
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 80:
        case 81:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_1M
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 72:
        case 76:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_1M
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 10:
        case 138:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 66:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 24:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 7:
        case 39:
        case 135:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 148:
        case 149:
        case 180:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 224:
        case 228:
        case 225:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 41:
        case 169:
        case 45:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 22:
        case 54:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 208:
        case 209:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 104:
        case 108:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 11:
        case 139:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 19:
        case 51:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL00_1L
            PIXEL01_C
            PIXEL02_1M
            PIXEL12_C
          }
          else
          {
            PIXEL00_2
            PIXEL01_6
            PIXEL02_5
            PIXEL12_1
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 146:
        case 178:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_1M
            PIXEL12_C
            PIXEL22_1D
          }
          else
          {
            PIXEL01_1
            PIXEL02_5
            PIXEL12_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          break;
        }
        case 84:
        case 85:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL02_1U
            PIXEL12_C
            PIXEL21_C
            PIXEL22_1M
          }
          else
          {
            PIXEL02_2
            PIXEL12_6
            PIXEL21_1
            PIXEL22_5
          }
          PIXEL00_2
          PIXEL01_1
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          break;
        }
        case 112:
        case 113:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL20_1L
            PIXEL21_C
            PIXEL22_1M
          }
          else
          {
            PIXEL12_1
            PIXEL20_2
            PIXEL21_6
            PIXEL22_5
          }
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          break;
        }
        case 200:
        case 204:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_1M
            PIXEL21_C
            PIXEL22_1R
          }
          else
          {
            PIXEL10_1
            PIXEL20_5
            PIXEL21_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          break;
        }
        case 73:
        case 77:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL00_1U
            PIXEL10_C
            PIXEL20_1M
            PIXEL21_C
          }
          else
          {
            PIXEL00_2
            PIXEL10_6
            PIXEL20_5
            PIXEL21_1
          }
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          PIXEL22_1M
          break;
        }
        case 42:
        case 170:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
            PIXEL01_C
            PIXEL10_C
            PIXEL20_1D
          }
          else
          {
            PIXEL00_5
            PIXEL01_1
            PIXEL10_6
            PIXEL20_2
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 14:
        case 142:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
            PIXEL01_C
            PIXEL02_1R
            PIXEL10_C
          }
          else
          {
            PIXEL00_5
            PIXEL01_6
            PIXEL02_2
            PIXEL10_1
          }
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 67:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 70:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 28:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 152:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 194:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 98:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 56:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 25:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 26:
        case 31:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL10_3
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL11
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 82:
        case 214:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 88:
        case 248:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL22_4
          }
          break;
        }
        case 74:
        case 107:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
          }
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 27:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 86:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 216:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 106:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 30:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_C
          PIXEL11
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 210:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 120:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 75:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 29:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 198:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 184:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 99:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 57:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 71:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 156:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 226:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 60:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 195:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 102:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 153:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 58:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 83:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 92:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 202:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 78:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 154:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 114:
        {
          PIXEL00_1M
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 89:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 90:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 55:
        case 23:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL00_1L
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL00_2
            PIXEL01_6
            PIXEL02_5
            PIXEL12_1
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 182:
        case 150:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
            PIXEL22_1D
          }
          else
          {
            PIXEL01_1
            PIXEL02_5
            PIXEL12_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_2
          PIXEL21_1
          break;
        }
        case 213:
        case 212:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL02_1U
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL02_2
            PIXEL12_6
            PIXEL21_1
            PIXEL22_5
          }
          PIXEL00_2
          PIXEL01_1
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          break;
        }
        case 241:
        case 240:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL20_1L
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_1
            PIXEL20_2
            PIXEL21_6
            PIXEL22_5
          }
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          break;
        }
        case 236:
        case 232:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
            PIXEL22_1R
          }
          else
          {
            PIXEL10_1
            PIXEL20_5
            PIXEL21_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          break;
        }
        case 109:
        case 105:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL00_1U
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL00_2
            PIXEL10_6
            PIXEL20_5
            PIXEL21_1
          }
          PIXEL01_1
          PIXEL02_2
          PIXEL11
          PIXEL12_1
          PIXEL22_1M
          break;
        }
        case 171:
        case 43:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
            PIXEL20_1D
          }
          else
          {
            PIXEL00_5
            PIXEL01_1
            PIXEL10_6
            PIXEL20_2
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 143:
        case 15:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL02_1R
            PIXEL10_C
          }
          else
          {
            PIXEL00_5
            PIXEL01_6
            PIXEL02_2
            PIXEL10_1
          }
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 124:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 203:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 62:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_C
          PIXEL11
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 211:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 118:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 217:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 110:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 155:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 188:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 185:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 61:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 157:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 103:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 227:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 230:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 199:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 220:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 158:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_C
          PIXEL11
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 234:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1M
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1R
          break;
        }
        case 242:
        {
          PIXEL00_1M
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_1L
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 59:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 121:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 87:
        {
          PIXEL00_1L
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_1M
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 79:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1R
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 122:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 94:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_C
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 218:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 91:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 229:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_2
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 167:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_2
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 173:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 181:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 186:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 115:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 93:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 206:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 205:
        case 201:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_1M
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 174:
        case 46:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_1M
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 179:
        case 147:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_1M
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 117:
        case 116:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_1M
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 189:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 231:
        {
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_1
          PIXEL11
          PIXEL12_1
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 126:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 219:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
            PIXEL10_3
          }
          PIXEL02_1M
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 125:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL00_1U
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL00_2
            PIXEL10_6
            PIXEL20_5
            PIXEL21_1
          }
          PIXEL01_1
          PIXEL02_1U
          PIXEL11
          PIXEL12_C
          PIXEL22_1M
          break;
        }
        case 221:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL02_1U
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL02_2
            PIXEL12_6
            PIXEL21_1
            PIXEL22_5
          }
          PIXEL00_1U
          PIXEL01_1
          PIXEL10_C
          PIXEL11
          PIXEL20_1M
          break;
        }
        case 207:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL02_1R
            PIXEL10_C
          }
          else
          {
            PIXEL00_5
            PIXEL01_6
            PIXEL02_2
            PIXEL10_1
          }
          PIXEL11
          PIXEL12_1
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 238:
        {
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
            PIXEL22_1R
          }
          else
          {
            PIXEL10_1
            PIXEL20_5
            PIXEL21_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1R
          PIXEL11
          PIXEL12_1
          break;
        }
        case 190:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
            PIXEL22_1D
          }
          else
          {
            PIXEL01_1
            PIXEL02_5
            PIXEL12_6
            PIXEL22_2
          }
          PIXEL00_1M
          PIXEL10_C
          PIXEL11
          PIXEL20_1D
          PIXEL21_1
          break;
        }
        case 187:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
            PIXEL20_1D
          }
          else
          {
            PIXEL00_5
            PIXEL01_1
            PIXEL10_6
            PIXEL20_2
          }
          PIXEL02_1M
          PIXEL11
          PIXEL12_C
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 243:
        {
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL20_1L
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_1
            PIXEL20_2
            PIXEL21_6
            PIXEL22_5
          }
          PIXEL00_1L
          PIXEL01_C
          PIXEL02_1M
          PIXEL10_1
          PIXEL11
          break;
        }
        case 119:
        {
          if (Diff(w[2], w[6]))
          {
            PIXEL00_1L
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL00_2
            PIXEL01_6
            PIXEL02_5
            PIXEL12_1
          }
          PIXEL10_1
          PIXEL11
          PIXEL20_1L
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 237:
        case 233:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_2
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 175:
        case 47:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_2
          break;
        }
        case 183:
        case 151:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_2
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 245:
        case 244:
        {
          PIXEL00_2
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 250:
        {
          PIXEL00_1M
          PIXEL01_C
          PIXEL02_1M
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL22_4
          }
          break;
        }
        case 123:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
          }
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 95:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL10_3
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL11
          PIXEL20_1M
          PIXEL21_C
          PIXEL22_1M
          break;
        }
        case 222:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 252:
        {
          PIXEL00_1M
          PIXEL01_1
          PIXEL02_1U
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 249:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL22_4
          }
          break;
        }
        case 235:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
          }
          PIXEL02_1M
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 111:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 63:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL10_C
          PIXEL11
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1M
          break;
        }
        case 159:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL10_3
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 215:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 246:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 254:
        {
          PIXEL00_1M
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_4
          }
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_4
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL21_3
            PIXEL22_2
          }
          break;
        }
        case 253:
        {
          PIXEL00_1U
          PIXEL01_1
          PIXEL02_1U
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 251:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
          }
          else
          {
            PIXEL00_4
            PIXEL01_3
          }
          PIXEL02_1M
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL10_C
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL10_3
            PIXEL20_2
            PIXEL21_3
          }
          if (Diff(w[6], w[8]))
          {
            PIXEL12_C
            PIXEL22_C
          }
          else
          {
            PIXEL12_3
            PIXEL22_4
          }
          break;
        }
        case 239:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          PIXEL02_1R
          PIXEL10_C
          PIXEL11
          PIXEL12_1
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          PIXEL22_1R
          break;
        }
        case 127:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL01_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_2
            PIXEL01_3
            PIXEL10_3
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL02_4
            PIXEL12_3
          }
          PIXEL11
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
            PIXEL21_C
          }
          else
          {
            PIXEL20_4
            PIXEL21_3
          }
          PIXEL22_1M
          break;
        }
        case 191:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          PIXEL20_1D
          PIXEL21_1
          PIXEL22_1D
          break;
        }
        case 223:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
            PIXEL10_C
          }
          else
          {
            PIXEL00_4
            PIXEL10_3
          }
          if (Diff(w[2], w[6]))
          {
            PIXEL01_C
            PIXEL02_C
            PIXEL12_C
          }
          else
          {
            PIXEL01_3
            PIXEL02_2
            PIXEL12_3
          }
          PIXEL11
          PIXEL20_1M
          if (Diff(w[6], w[8]))
          {
            PIXEL21_C
            PIXEL22_C
          }
          else
          {
            PIXEL21_3
            PIXEL22_4
          }
          break;
        }
        case 247:
        {
          PIXEL00_1L
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_1
          PIXEL11
          PIXEL12_C
          PIXEL20_1L
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
        case 255:
        {
          if (Diff(w[4], w[2]))
          {
            PIXEL00_C
          }
          else
          {
            PIXEL00_2
          }
          PIXEL01_C
          if (Diff(w[2], w[6]))
          {
            PIXEL02_C
          }
          else
          {
            PIXEL02_2
          }
          PIXEL10_C
          PIXEL11
          PIXEL12_C
          if (Diff(w[8], w[4]))
          {
            PIXEL20_C
          }
          else
          {
            PIXEL20_2
          }
          PIXEL21_C
          if (Diff(w[6], w[8]))
          {
            PIXEL22_C
          }
          else
          {
            PIXEL22_2
          }
          break;
        }
      }
      pIn += sizeof(uint32);
      pOut+=12;
    }
    pOut += BpL * 3 - Xres * 3 * sizeof(uint32);
    pIn += srcBpL - Xres * sizeof(uint32);
  }
}
