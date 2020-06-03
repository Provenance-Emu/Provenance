/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* dsp1chip.h:
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

static const int16 DataROM[0x400] = 
{
 #include "dsp1-datarom-synth.h"
};

/*
static const int16* DivTab = &DataROM[101];
static const int16* SqrtTab = &DataROM[229];
static const int16* SinTab = &DataROM[280];
static const int16* CosTab = &DataROM[408];
static const int16* ACosTab = &DataROM[542];
*/

class DSP1Chip
{
 public:
 DSP1Chip();
 ~DSP1Chip();

 void Reset(bool powering_up);
#ifndef MDFN_SNES_FAUST_DSP1CHIP_TEST
 void StateAction(StateMem* sm, const unsigned load, const bool data_only);
#endif
 void Run(int32 cycles = 4);

 void WriteData(uint8 V);
 uint8 ReadData(void);
 uint8 ReadStatus(void);

 private:

 uint16 DataReg;
 uint8 StatusReg;
 //
 uint8 Command;
 int16 Args[16];
 int16 Results[16];
 uint32 Scratch[16];
 //
 //
 //
 float cop_x;
 float cop_y;
 float cop_z;
 int screen_cop_distance;
 int azimuth_angle;
 int zenith_angle;
 int raster_vfudge;	// Utilize the one weakness of infinitely large mode 7 center coordinates that are rumored to eat all of your almond shortbread cookies: fudge!
 //
 float obj_rot_matrix[3][3][3];
 //
 //
 //
 uint32 CommandPhase;
 int32 CycleCounter;
 //
 //
 //
 uint16 Revision;

 public:
 enum : int { ANGLE_PI = 32768 };
 enum : int { ANGLE_HALF_PI = 16384 };
};

#if 0
static void SynthDataROM(void)
{
 FileStream fp("datarom-synth.bin", FileStream::MODE_WRITE);
 FileStream fph("datarom-synth.h", FileStream::MODE_WRITE);
 int16 tmp[0x400];

 memset(tmp, 0, sizeof(tmp));

 // 0 ... 97
 for(int i = 0; i < 98; i++)
 {
  int v = 0;

  if(i == 60) // bug?
   v = 1;
  else if(i >= 34 && i <= 64)
   v = std::min<int>(32767, 32768 >> abs(i - 49));

  tmp[i] = v;
 }

 // TODO: 98 ... 100

 // 101...228
 //
 // Inverse table
 for(int i = 0; i < 128; i++)
 {
  int v = std::min<int>(32767, floor(0.5 + 32768.0 / (1.0 + i / 128.0)));

  tmp[101 + i] = v;
 }

 // 229...277
 //
 // Square root table
 for(int i = 0; i < 49; i++)
 {
  float fv = 32767.0 / 2.0 * sqrt(1.0 + i / 16.0);
  int v = std::min<int>(32767, floor(fv));

  tmp[229 + i] = v;
 }

 // 278...279
 for(int i = 0; i < 2; i++)
 {
  int v = 32 << i;

  tmp[278 + i] = v;
 }

 // 280 ... 407
 //
 // Sine table
 for(int i = 0; i < 128; i++)
 {
  int v = std::min<int>(32767, floor(32768 * sin(i * M_PI / 128.0)));

  tmp[280 + i] = v;
 }

 // 408 ... 535
 //
 // Cosine table
 for(int i = 0; i < 128; i++)
 {
  float angle = i * M_PI / 128.0;
  float fv = 32768.0 * cos(angle);
  int v = std::min<int>(32767, (int)fv);

  tmp[408 + i] = v;
 }

 // TODO: 536 ... 541
 // pi, 2**7, (2**10)-1, ?, ?, 2**7

 // 542 ... 797
 //
 // Arc cosine table
 for(int i = 0; i < 256; i++)
 {
  float fv = 32768.0 * acos(i / 256.0) / M_PI;
  int v = std::min<int>(32767, floor(0.5 + fv));

  tmp[542 + i] = v;
 }

 // TODO: 798 ... 808

 // 809
 //
 // tasty pie
 {
  int v = floor(0.5 + M_PI * 8192);

  tmp[809] = v;
 }

 // TODO: 810 ... 816

 // 817 ... 1023
 for(int i = 817; i < 1024; i++)
 {
  tmp[i] = -1;
 }

 for(unsigned i = 0; i < 0x400; i++)
 {
  fp.put_LE<uint16>(tmp[i]);

  fph.print_format("%d, ", tmp[i]);

  if((i & 0xF) == 0xF)
   fph.print_format("\n");
 }
}
#endif
DSP1Chip::DSP1Chip()
{
 Revision = 0x0101;
 //
 //
 //
#if 0
 SynthDataROM();
#endif
}

DSP1Chip::~DSP1Chip()
{


}

enum : int { CommandPhaseBias = __COUNTER__ + 1 };

#define WAIT_RQM()				\
	{					\
	 case __COUNTER__:			\
	 if(StatusReg & 0x80)			\
	 {					\
	  CycleCounter = 0;			\
	  CommandPhase = __COUNTER__ - CommandPhaseBias - 1;	\
	  goto Breakout;			\
	 }					\
	}

#define EAT_CYCLES(n)						\
	{							\
	 CycleCounter -= (n);					\
	 case __COUNTER__:					\
	 if(CycleCounter < 0)					\
	 {							\
	  CommandPhase = __COUNTER__ - CommandPhaseBias - 1;	\
	  goto Breakout;					\
	 }							\
	}


#define READ8(v)		\
	{			\
	 StatusReg |= 0x84;	\
	 WAIT_RQM()		\
	 (v) = (uint8)DataReg;	\
	}

#define READ16(v)		\
	{			\
	 StatusReg = (StatusReg & ~0x04) | 0x80;	\
	 WAIT_RQM()		\
	 (v) = DataReg;		\
	}

#define WRITE8(v)					\
	{						\
	 DataReg = (DataReg & 0xFF00) | (uint8)(v);	\
	 StatusReg |= 0x84;				\
	 WAIT_RQM()					\
	}

#define WRITE16(v)					\
	{						\
	 DataReg = (v);					\
	 StatusReg = (StatusReg & ~0x04) | 0x80;	\
	 WAIT_RQM()					\
	}

#define WRITE32(v)		\
	WRITE16((v) & 0xFFFF)	\
	WRITE16((v) >> 16)

void DSP1Chip::Reset(bool powering_up)
{
 DataReg = 0;
 StatusReg = 0;

 CommandPhase = 0;
 CycleCounter = 0;
 //
 //
 Command = 0;
 memset(Args, 0, sizeof(Args));
 memset(Results, 0, sizeof(Results));
 memset(Scratch, 0, sizeof(Scratch));

 cop_x = 0;
 cop_y = 0;
 cop_z = 0;
 screen_cop_distance = 0;
 azimuth_angle = 0;
 zenith_angle = 0;
 raster_vfudge = 0;

 memset(obj_rot_matrix, 0, sizeof(obj_rot_matrix));
}

#ifndef MDFN_SNES_FAUST_DSP1CHIP_TEST
void DSP1Chip::StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(DataReg),
  SFVAR(StatusReg),

  SFVAR(Command),
  SFVAR(Args),
  SFVAR(Results),
  SFVAR(Scratch),

  SFVAR(cop_x),
  SFVAR(cop_y),
  SFVAR(cop_z),
  SFVAR(screen_cop_distance),
  SFVAR(azimuth_angle),
  SFVAR(zenith_angle),
  SFVAR(raster_vfudge),
  SFVAR(obj_rot_matrix),

  SFVAR(CommandPhase),
  SFVAR(CycleCounter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DSP1CHIP");
}
#endif

static INLINE int16 Saturate(float v)
{
 return (int)floorf(std::max<float>(-32767, std::min<float>(32767, v)));
}

static INLINE float Inverse(float v)
{
 if(fabsf(v) < (1.0f / 4294967296.0f))
  return copysignf(4294967296.0f, v);

 return 1.0f / v;
}

static float Cos(int16 angle)
{
#if 0
 bool neg = false;

 if(angle >= 16384)
 {
  angle = 32768 - angle;
  neg = true;
 }

 if(angle <= -16384)
 {
  angle = -32768 - angle;
  neg = true;
 }

 int ret;
 int x = (((int64)angle * 105414357) + 32768) >> 16;
 int x_2 = ((int64)x*x + (1 << 23)) >> 24;
 int x_4 = ((int64)x_2*x_2 + (1 << 23)) >> 24;
 int x_6 = ((int64)x_4*x_2 + (1 << 23)) >> 24;
 int x_8 = ((int64)x_4*x_4 + (1 << 23)) >> 24;
 int x_10 = ((int64)x_6*x_4 + (1 << 23)) >> 24;

 //printf("%d %d %d %d %d %d\n", x, x_2, x_4, x_6, x_8, x_10);

 ret = 16777216 - ((x_2 + 1) >> 1);
 ret += ((int64)x_4 * 178956971) >> 32;
 ret -= x_6 / 720;
 ret += ((int64)x_8 * 106522) >> 32;
 ret -= ((int64)x_10 * 302996) >> 40; // / 3628800;

 if(neg)
  ret = -ret;

 return ret * (1.0f / 16777216);
#else
 return cosf(angle * M_PI * 2 / 65536);
#endif
}

static INLINE float Sin(uint16 angle)
{
#if 0
 return Cos(DSP1Chip::ANGLE_HALF_PI - angle);
#else
 return sinf(angle * M_PI * 2 / 65536);
#endif
}

static INLINE float Tan(uint16 angle)
{
 return Sin(angle) * Inverse(Cos(angle));
}

static INLINE uint16 ATan2(float y, float x)
{
 return (int)((65536.0f / (float)(M_PI * 2)) * atan2f(y, x));
}

NO_INLINE void DSP1Chip::Run(int32 cycles)
{
 CycleCounter += cycles;
 //
 //
 //
 switch(CommandPhase + CommandPhaseBias)
 {
 for(;;)
 {
 default:
 case __COUNTER__:
 //
 //
 //////
 READ8(Command)

 //printf("Command: %02x %u\n", Command, PPU_GetRegister(PPU_GSREG_SCANLINE, nullptr, 0));

 if(Command == 0x00)
 {
  // 16-bit multiplication
  //
  // Two 16-bit args, one 16-bit result.
  READ16(Args[0])
  READ16(Args[1])
  {
   Results[0] = (Args[0] * Args[1]) >> 15;
  }
  WRITE16(Results[0])
 }
 else if(Command == 0x10)
 {
  // Inverse?
  // plot [x=101:229] "datarom.plot" with lines, 32767/(1.0 + (x-101)/128)
  READ16(Args[0])
  READ16(Args[1])
  {
   const bool neg = Args[0] < 0;
   const int in_exp = Args[1];
   const int in_sig = neg ? -Args[0] : Args[0];

   if(!in_sig)
   {
    Results[0] = 0x7FFF;
    Results[1] = 0x002F;
   }
   else
   {
    //
    //
    //
    //gnuplot> plot [x=0:32767] 32768 / (1 + x / 32768)
    const int16* invtable = &DataROM[101];
    const unsigned l2 = log2(in_sig);
    //const unsigned p2 = 1U << l2;

    //const int rawshift = 7 - l2;
    //const unsigned lshift = std::max<int>(0, rawshift);
    const unsigned ipc_lshift = 14 - l2;
    const size_t index = ((in_sig << 7) >> l2) & 0x7F;
    const int s0 = invtable[index];
    const int s1 = invtable[index + 1];
    int sig, exp;
    int ipc;

    //l = std::min<unsigned>(0x7FFF, 32768 * p2 / div); //((uint64)32768 * p2 * 2 + div) / (div * 2));
    ipc = (in_sig << ipc_lshift) & 0x7F;

    sig = 32768 / in_sig;

    sig = ((s0 * (0x80 - ipc)) + (s1 * ipc)) >> 7;
    //sig = (sig + 1) & ~1;
    exp = 15 - l2;

    if(neg && !index && !ipc)
    {
     sig >>= 1;
     exp++;
    }
    exp -= in_exp;

    if(neg)
     sig = -sig;

    Results[0] = sig;
    Results[1] = exp;
   }
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
 }
 else if(Command == 0x04)
 {
  // Trig calculation?
  //
  // gnuplot> plot [x=408:535] "datarom.plot" with lines, 32767*cos((x-408)*pi*2/256)
  //
  // Two 16-bit args, two 16-bit results
  READ16(Args[0]); // Angle
  READ16(Args[1]); // Scale
  {
   Results[0] = Saturate(Sin(Args[0]) * Args[1]);
   Results[1] = Saturate(Cos(Args[0]) * Args[1]);
  }
  WRITE16(Results[0])	// sine result
  WRITE16(Results[1])	// cosine result
 }
 else if(Command == 0x14)
 {
  // 3D angle rotation?
  //
  // Six 16-bit args, three 16-bit results?
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  READ16(Args[3])
  READ16(Args[4])
  READ16(Args[5])

  //printf("angle rot: %04x %04x %04x, %04x %04x %04x\n", Args[0], Args[1], Args[2], Args[3], Args[4], Args[5]);
  {
   float tmp[3];

   tmp[0] = (Args[3] * Cos(Args[2]) - Args[4] * Sin(Args[2])) * Inverse(Cos(Args[1]));
   tmp[1] = (Args[3] * Sin(Args[2]) + Args[4] * Cos(Args[2]));
   tmp[2] = -Tan(Args[1]) * (Args[3] * Cos(Args[2]) + Args[4] * Sin(Args[2])) + Args[5];

   Results[0] = Args[0] + Saturate(tmp[0]);
   Results[1] = Args[1] + (int)floorf(tmp[1]);
   Results[2] = Args[2] + Saturate(tmp[2]);
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
 }
 else if(Command == 0x0C)
 {
  // 2D coordinate rotation?
  //
  // Three 16-bit args, two 16-bit results?
  READ16(Args[0]) // Angle
  READ16(Args[1]) // x (y?)
  READ16(Args[2]) // y (x?)
  {
   Results[0] = Saturate(Args[1] * Cos(Args[0]) + Args[2] * Sin(Args[0]));
   Results[1] = Saturate(Args[2] * Cos(Args[0]) - Args[1] * Sin(Args[0]));
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
 }
 else if(Command == 0x1C)
 {
  // 3D coordinate rotation?
  //
  // Six 16-bit args, three 16-bit results
  READ16(Args[0]) // angle
  READ16(Args[1]) // angle
  READ16(Args[2]) // angle

  READ16(Args[3]) // coord
  READ16(Args[4]) // coord
  READ16(Args[5]) // coord
  {
   float simu[3];
   float ns[3];

   simu[0] = Args[3];
   simu[1] = Args[4];
   simu[2] = Args[5];
   //
   ns[0] =  simu[0] * Cos(Args[0]) + simu[1] * Sin(Args[0])          ;
   ns[1] = -simu[0] * Sin(Args[0]) + simu[1] * Cos(Args[0])          ;
   simu[0] = ns[0];
   simu[1] = ns[1];
   //
   ns[0] = simu[0] * Cos(Args[1]) - simu[2] * Sin(Args[1]);
   ns[2] = simu[0] * Sin(Args[1]) + simu[2] * Cos(Args[1]);
   simu[0] = ns[0];
   simu[2] = ns[2];
   //
   //
   ns[1] =  simu[1] * Cos(Args[2]) + simu[2] * Sin(Args[2]);
   ns[2] = -simu[1] * Sin(Args[2]) + simu[2] * Cos(Args[2]);
   simu[1] = ns[1];
   simu[2] = ns[2];

   Results[0] = simu[0];
   Results[1] = simu[1];
   Results[2] = simu[2];
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
 }
 else if(Command == 0x01 || Command == 0x11 || Command == 0x21)
 {
  // Set Attitude?
  //
  // Four 16-bit args, zero 16-bit results?
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  READ16(Args[3])
  {
   float (&matrix)[3][3] = obj_rot_matrix[(Command >> 4) % 3];

   matrix[0][0] = Args[0] * (Cos(-Args[1]) * Cos(-Args[2]));
   matrix[0][1] = Args[0] * (-Sin(-Args[1]) * Cos(-Args[3]) + Cos(-Args[1]) * Sin(-Args[2]) * Sin(-Args[3]));
   matrix[0][2] = Args[0] * (Sin(-Args[1]) * Sin(-Args[3]) + Cos(-Args[1]) * Sin(-Args[2]) * Cos(-Args[3]));

   matrix[1][0] = Args[0] * (Sin(-Args[1]) * Cos(-Args[2]));
   matrix[1][1] = Args[0] * (Cos(-Args[1]) * Cos(-Args[3]) + Sin(-Args[1]) * Sin(-Args[2]) * Sin(-Args[3]));
   matrix[1][2] = Args[0] * (-Cos(-Args[1]) * Sin(-Args[3]) + Sin(-Args[1]) * Sin(-Args[2]) * Cos(-Args[3]));

   matrix[2][0] = Args[0] * (-Sin(-Args[2]));
   matrix[2][1] = Args[0] * (Cos(-Args[2]) * Sin(-Args[3]));
   matrix[2][2] = Args[0] * (Cos(-Args[2]) * Cos(-Args[3]));
  }
 }
 else if(Command == 0x03 || Command == 0x13 || Command == 0x23)
 {
  // Object to Global Coordinate?
  //
  // Three 16-bit args, three 16-bit results?
  Scratch[0] = Command >> 4;
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  {
   float (&matrix)[3][3] = obj_rot_matrix[(Command >> 4) % 3];

   for(unsigned ri = 0; ri < 3; ri++)
   {
    Results[ri] = Saturate((matrix[ri][0] * Args[0] + matrix[ri][1] * Args[1] + matrix[ri][2] * Args[2]) / 65536);
   }
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
 }
 else if(Command == 0x0D || Command == 0x1D || Command == 0x2D)
 {
  // Global to Object Coordinate?
  //
  // Three 16-bit args, three 16-bit results?
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  {
   float (&matrix)[3][3] = obj_rot_matrix[(Command >> 4) % 3];

   for(unsigned ri = 0; ri < 3; ri++)
   {
    Results[ri] = Saturate((matrix[0][ri] * Args[0] + matrix[1][ri] * Args[1] + matrix[2][ri] * Args[2]) / 65536);
   }
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
 }
 else if(Command == 0x0B || Command == 0x1B || Command == 0x2B)
 {
  // Inner Product with forward attitude and vector?
  //
  // Three 16-bit args, one 16-bit result?
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  {
   float (&matrix)[3][3] = obj_rot_matrix[(Command >> 4) % 3];
   Results[0] = Saturate((matrix[0][0] * Args[0] + matrix[1][0] * Args[1] + matrix[2][0] * Args[2]) / 65536);
  }
  WRITE16(Results[0])
 }
 else if(Command == 0x02)
 {
  // Projection parameter settings?
  //
  // Seven 16-bit args, four 16-bit results?
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  READ16(Args[3])
  READ16(Args[4])
  READ16(Args[5])
  READ16(Args[6])
  //
  //
  //
  {
   int base_x = Args[0]; // Base X
   int base_y = Args[1]; // Base Y
   int base_z = Args[2]; // Base Z
   int base_cop_distance = Args[3];	// Distance between base point and center of projection
   screen_cop_distance = Args[4]; 	// Distance between center of projection and screen.
   azimuth_angle = Args[5]; 		// Azimuth angle.
   zenith_angle = Args[6]; 		// Zenith angle.
   //
   //
   //
   cop_z = base_z - base_cop_distance * Sin(zenith_angle - ANGLE_HALF_PI);
   cop_y = base_y + base_cop_distance * Cos(zenith_angle - ANGLE_HALF_PI) * Cos(azimuth_angle);
   cop_x = base_x - base_cop_distance * Cos(zenith_angle - ANGLE_HALF_PI) * Sin(azimuth_angle);

   //printf("PROJPARAM; base_x=%d, base_y=%d, base_z=%d(cop_x=%d, cop_y=%d, cop_z=%d), base_cop_distance=%d, screen_cop_distance=%d, azimuth_angle=%d, zenith_angle=%d\n", base_x, base_y, base_z, cop_x, cop_y, cop_z, base_cop_distance, screen_cop_distance, azimuth_angle, zenith_angle);
   {
    raster_vfudge = 0;

    if(Args[6] >= 14515)
     raster_vfudge = (int)floorf(0.5f + screen_cop_distance * 0.00009778887f * (Args[6] - 14515));

    Results[0] = Saturate(raster_vfudge);
    Results[1] = Saturate(floorf(screen_cop_distance * Tan(zenith_angle - ANGLE_HALF_PI)) - raster_vfudge);
    //
    //
    float y = cop_z * Tan(ANGLE_PI - (zenith_angle - ATan2(raster_vfudge, screen_cop_distance)));
    float new_x = -y * Sin(azimuth_angle);
    float new_y =  y * Cos(azimuth_angle);

    Results[2] = Saturate(cop_x + new_x);
    Results[3] = Saturate(cop_y + new_y);
   }
  }
  //
  //
  //
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
  WRITE16(Results[3])
 }
 else if(Command == 0x06)
 {
  // Projection
  //
  // Three args, three results
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  {
   float x, y, z;

   x = Args[0] - cop_x;
   y = Args[1] - cop_y;
   z = Args[2] - cop_z;
   //
   {
    float new_x = x * Cos(-azimuth_angle) - y * Sin(-azimuth_angle);
    float new_y = x * Sin(-azimuth_angle) + y * Cos(-azimuth_angle);

    x = new_x;
    y = new_y;
   }
   //
   {
    float new_y = y * Cos(-zenith_angle) + z * Sin(-zenith_angle);
    float new_z = y * Sin(-zenith_angle) - z * Cos(-zenith_angle);

    y = new_y;
    z = new_z;
   }
   //
   float scale = screen_cop_distance * 256.0f * Inverse(z);

   x *= scale / 256.0f;
   y *= scale / 256.0f;

   Results[0] = Saturate(x);
   Results[1] = Saturate(y);
   Results[2] = Saturate(scale);
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
  WRITE16(Results[2])
 }
 else if(Command == 0x0E)
 {
  //
  // Converts screen coordinates to (mode 7) ground plane coordinates
  //
  READ16(Args[0])
  READ16(Args[1])
  {
   float y = cop_z * Tan(ANGLE_PI - (zenith_angle - ATan2((int8)Args[1] + raster_vfudge, screen_cop_distance)));
   float x = (int8)Args[0] * (y * Sin(-zenith_angle) + cop_z * Cos(-zenith_angle)) * Inverse(screen_cop_distance);
   //
   float new_x = x * Cos(azimuth_angle) - y * Sin(azimuth_angle);
   float new_y = y * Cos(azimuth_angle) - x * Sin(azimuth_angle);

   Results[0] = Saturate(cop_x + 0.5f + new_x);
   Results[1] = Saturate(cop_y + 0.5f + new_y);
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
 }
 else if(Command == 0x1A || Command == 0x0A)
 {
  if(Command == 0x1A)
  {
   SNES_DBG("[DSP1] Untested command: %02x\n", Command);
  }
  // Mode 7 matrix calculation
  //
  // One 16-bit args, variable results
  READ16(Args[0])

  Scratch[0] = Args[0];
  do
  {
   {
    int16 screen_y = (int16)Scratch[0] + raster_vfudge;
    {
     float y = cop_z * Tan(ANGLE_PI - (zenith_angle - ATan2(screen_y, screen_cop_distance)));
     float xs = (y * Sin(-zenith_angle) + cop_z * Cos(-zenith_angle)) * Inverse(screen_cop_distance);
     //float ys = (y - centery) / screen_y; //xs / cos(ph)*1.1; //(y_diff / -sin(M_PI - ph_adj)) / new_screen_cop_distance;
     float ys = xs * Inverse(Cos(zenith_angle - ATan2(raster_vfudge, screen_cop_distance)));
     //
     //
     Results[0] = Saturate(0x100 * Cos(azimuth_angle) * xs);
     Results[1] = Saturate(-0x100 * Sin(azimuth_angle) * ys);
     Results[2] = Saturate(0x100 * Sin(azimuth_angle) * xs);
     Results[3] = Saturate(0x100 * Cos(azimuth_angle) * ys);
    }
   }
   Scratch[0]++;
   //
   //
   WRITE16(Results[0])
   WRITE16(Results[1])
   WRITE16(Results[2])
   WRITE16(Results[3])
  } while(DataReg == (uint16)Results[3]);
 }
 else if(Command == 0x08)
 {
  // Vector size calculation?
  //
  // Three 16-bit args, two 16-bit results
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  {
   uint32 tmp = ((uint32)(Args[0] * Args[0]) + (Args[1] * Args[1]) + (Args[2] * Args[2])) << 1;

   Results[0] = tmp;
   Results[1] = tmp >> 16;
  }
  WRITE16(Results[0])
  WRITE16(Results[1])
 }
 else if(Command == 0x18 || Command == 0x38)
 {
  // Vector size comparison
  //
  // Four 16-bit args, one 16-bit result
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])
  READ16(Args[3])

  Scratch[0] = (uint32)(Args[0] * Args[0]) + (Args[1] * Args[1]) + (Args[2] * Args[2]);

  if(Command == 0x38)
   Scratch[0] += 128 * 256;	// FIXME ? ? ?
  else
   Scratch[0] -= Args[3] * Args[3];

  Scratch[0] <<= 1;
  Scratch[0] >>= 16;

  WRITE16(Scratch[0])
 }
 else if(Command == 0x28)
 {
  // Vector absolute value?
  //
  // plot [x=229:277] "datarom.plot" with lines, 16384*sqrt(1.0 + (x-229)/16)
  //
  // Craps out around an input value of 64 with others 0(value to take square root of == 8192))
  // Also around:
  //  (18919 * 18919) * 3 * 2
  //  (25027*25027)*3*2
  //  (26755*26755)*3*2
  //
  // Three 16-bit args, one 16-bit result
  READ16(Args[0])
  READ16(Args[1])
  READ16(Args[2])

  {
   int64 ss = (int64)(Args[0] * Args[0]) + (Args[1] * Args[1]) + (Args[2] * Args[2]);

   Results[0] = (uint16)(int)floor(0.5 + sqrt(ss));
  }
  WRITE16(Results[0]);
 }
 else if(Command == 0x0F)
 {
  //
  // Test data RAM?
  //
  READ16(Args[0])

  // TODO: wait

  WRITE16(0x0000);
 }
 else if(Command == 0x1F)
 {
  //
  // Get data ROM
  //
  READ16(Args[0])	// ?

  for(Scratch[0] = 0; Scratch[0] < 0x400; Scratch[0]++)
  {
   WRITE16(DataROM[Scratch[0] & 0x3FF])
  }
 }
 else if(Command == 0x2F)
 {
  //
  // Get version
  //
  READ16(Args[0])	// ?

  WRITE16(Revision)
 }
 else
 {
  if(Command != 0x80)
  {
   SNES_DBG("[DSP1] Unknown command: %02x\n", Command);
  }
  Command = 0x80;
 }

 if(Command != 0x80)
  DataReg = 0x80;
 //////
 //
 //
 }
 }
 Breakout:;
 //
}

#undef WAIT_RQM
#undef EAT_CYCLES
#undef READ8
#undef READ16
#undef WRITE8
#undef WRITE16
#undef WRITE32

INLINE void DSP1Chip::WriteData(uint8 V)
{
 Run();
 //
 //
 const unsigned shift = ((StatusReg >> 1) & 0x8);
 DataReg &= ~(0xFF << shift);
 DataReg |= V << shift;
 StatusReg ^= (~StatusReg & 0x4) << 2;
 StatusReg &= ~((~StatusReg & 0x10) << 3);
 //StatusReg &= (StatusReg >> 5) & 0x4;

 //printf("WriteDR: %02x\n", V);
}

INLINE uint8 DSP1Chip::ReadData(void)
{
 Run();
 //
 //
 uint8 ret = DataReg >> ((StatusReg >> 1) & 0x8);
 StatusReg ^= (~StatusReg & 0x4) << 2;
 StatusReg &= ~((~StatusReg & 0x10) << 3);

 //printf("ReadDR: %02x\n", ret);

 return ret;
}

INLINE uint8 DSP1Chip::ReadStatus(void)
{
 Run();
 //
 //
 return StatusReg;
}
