/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* DSP2Chip.h:
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

/*
 TODO: Figure out exact algorithm for bitmap scaling(might involve a division with
       precision loss, not sure...).

 TODO: Implement unimplemented commands.

 TODO: Correct end-of-command data register value?
*/

class DSP2Chip
{
 public:
 DSP2Chip();
 ~DSP2Chip();

 void Reset(bool powering_up);
#ifndef MDFN_SNES_FAUST_DSP2CHIP_TEST
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
 uint16 Args[16];
 uint16 Results[16];
 uint32 Scratch;
 uint8 Scratch8[256];
 //
 //
 //
 uint8 tp_color;
 uint32 i;
 uint32 count;
 //
 //
 //
 uint32 CommandPhase;
 int32 CycleCounter;
};

DSP2Chip::DSP2Chip()
{

}

DSP2Chip::~DSP2Chip()
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

#define READ16_8BDR(v)		\
	{			\
	 StatusReg |= 0x84;	\
	 WAIT_RQM()		\
	 (v) = (uint8)DataReg;	\
	 StatusReg |= 0x84;	\
	 WAIT_RQM()		\
	 (v) |= (uint8)DataReg << 8;	\
	}

#define WRITE16_8BDR(v)					\
	WRITE8((v) & 0xFF)				\
	WRITE8((v) >> 8)

void DSP2Chip::Reset(bool powering_up)
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
 Scratch = 0;
 memset(Scratch8, 0, sizeof(Scratch8));

 tp_color = 0;
 i = 0;
 count = 0;
}

#ifndef MDFN_SNES_FAUST_DSP2CHIP_TEST
void DSP2Chip::StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(DataReg),
  SFVAR(StatusReg),

  SFVAR(Command),
  SFVAR(Args),
  SFVAR(Results),
  SFVAR(Scratch),
  SFVAR(Scratch8),

  SFVAR(tp_color),
  SFVAR(i),
  SFVAR(count),

  SFVAR(CommandPhase),
  SFVAR(CycleCounter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DSP2CHIP");
}
#endif

NO_INLINE void DSP2Chip::Run(int32 cycles)
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

 SNES_DBG("[DSP2] DSP2Chip::Run(); Command: %02x\n", Command);
 //
 Command &= 0x0F; // Wrong?

 if(Command == 0x01)
 {
  //
  // Converts 4bpp bitmap 8x8 tile to bitplane format?
  //
  // 32 bytes in, 32 bytes out
  for(i = 0; i < 16; i++)
  {
   READ16_8BDR(Args[i & 0xF])
  }
  //
  for(unsigned y = 0; y < 8; y++)
  {
   uint32 tmp = 0;

   for(unsigned x = 0; x < 8; x++)
   {
    const unsigned ax = x ^ 6;
    const uint8 sp = (Args[(y << 1) + (ax >> 2)] >> ((ax & 3) << 2)) & 0xF;

    tmp |= ((sp >> 0) & 0x1) << ( 0 + x);
    tmp |= ((sp >> 1) & 0x1) << ( 8 + x);
    tmp |= ((sp >> 2) & 0x1) << (16 + x);
    tmp |= ((sp >> 3) & 0x1) << (24 + x);
   }

   Results[0 + y] = tmp & 0xFFFF;
   Results[8 + y] = tmp >> 16;
  }
  //
  for(i = 0; i < 16; i++)
  {
   WRITE16_8BDR(Results[i & 0xF])
  }
 }
/*
 else if(Command == 0x02)
 {
  // 16x16 or 8bpp?
  // 64 bytes in, 64 bytes out?
  assert(0);
 }
*/
 else if(Command == 0x03)
 {
  //
  // Set transparent color?
  //
  READ8(Args[0])
  tp_color = Args[0] & 0xF;
  tp_color |= tp_color << 4;
 }
 else if(Command == 0x05)
 {
  //
  // Transparency bitmap replace?
  //
  READ8(Args[0])

  count = std::min<uint8>(Args[0], 0x50);

  // Replacement nybbles
  for(i = 0; i < count; i++)
   READ8(Scratch8[0x00 + (i & 0x7F)])

  // Bitmap
  for(i = 0; i < count; i++)
   READ8(Scratch8[0x80 + (i & 0x7F)])

  for(i = 0; i < count; i++)
  {
   {
    uint8 tmp = Scratch8[0x80 + (i & 0x7F)];

    if(!((tmp ^ tp_color) & 0x0F))
     tmp = (tmp & 0xF0) | (Scratch8[0x00 + (i & 0x7F)] & 0x0F);

    if(!((tmp ^ tp_color) & 0xF0))
     tmp = (tmp & 0x0F) | (Scratch8[0x00 + (i & 0x7F)] & 0xF0);

    Results[0] = tmp;
   }
   //
   WRITE8(Results[0])
  }
 }
 else if(Command == 0x06)
 {
  //
  // Reverse bitmap?
  //
  READ8(Args[0])

  assert(Args[0]);

  if(Args[0])
  {
   for(i = 0; i < Args[0]; i++)
   {
    READ8(Scratch8[i & 0xFF])
   }

   count = Args[0];
   while(count)
   {
    count--;
    Scratch = Scratch8[count & 0xFF];
    Scratch = (Scratch << 4) | (Scratch >> 4);
    WRITE8(Scratch)
   }
  }
  //
  DataReg = 0xFFFF; // or 0xFF?
 }
/*
 else if(Command == 0x07)
 {
  //
  // Add?
  //
  // Puts data reg in 16-bit mode for results?
  assert(0);
 }
 else if(Command == 0x08)
 {
  //
  // Subtract?
  //
  assert(0);
 }
*/
 else if(Command == 0x09 || Command == 0x0A)
 {
  //
  // Buggy multiplication
  //
  READ16_8BDR(Args[0])
  READ16_8BDR(Args[1])
  {
   uint32 simu_result;

   simu_result = ((int16)Args[0] * (int16)Args[1]) & 0x7FFFFFFF;
   simu_result = (simu_result & ~0x8000) | ((simu_result << 1) & 0x8000);

   //printf("multiply %d %d 0x%08x --- 0x%08x\n", (int16)Args[0], (int16)Args[1], simu_result, (int16)Args[0] * (int16)Args[1]);

   Results[0] = simu_result;
   Results[1] = simu_result >> 16;
  }
  WRITE16_8BDR(Results[0])
  WRITE16_8BDR(Results[1])
 }
/*
 else if(Command == 0x0B)
 {
  //
  // Something
  //
  // 8 bytes in
  assert(0);
 }
 else if(Command == 0x0C)
 {
  //
  // Something
  //
  // 8 bytes in
  assert(0);
 }
*/
 else if(Command == 0x0D)
 {
  //
  // Scale bitmap?
  //
  READ8(Args[0]) // nybbles in count
  READ8(Args[1]) // nybbles out count

  SNES_DBG("[DSP2] scale: 0x%02x 0x%02x\n", Args[0], Args[1]);

  count = (Args[0] + 1) >> 1;
  for(i = 0; i < count; i++)
  {
   READ8(Scratch8[i & 0x7F])
  }

  {
   int32 accum = 0;
   uint32 dp = 0;

   for(i = 0; i < Args[0]; i++)
   {
    unsigned ss = ((i & 1) ^ 1) << 2;
    unsigned ds = ((dp & 1) ^ 1) << 2;
    
    Scratch8[0x80 + ((dp >> 1) & 0x7F)] &= 0xF0 << ds;
    Scratch8[0x80 + ((dp >> 1) & 0x7F)] |= ((Scratch8[(i >> 1) & 0x7F] >> ss) & 0xF) << ds;
//    Scratch8[0x80 + ((dp >> 1) & 0x7F)] |= /*((Scratch8[(i >> 1) & 0x7F] >> ss) & 0xF)*/ (rand() & 0xF) << ds;

    accum += Args[1] + 1;
    if(accum >= 0)
    {
     accum -= Args[0];
     dp++;
    }
   }
  }

  count = (Args[1] + 1) >> 1;
  for(i = 0; i < count; i++)
  {
   WRITE8(Scratch8[0x80 + (i & 0x7F)])
  }
 }
/*
 else if(Command == 0x0E)
 {
  //
  // Something
  //
  // One 16-bit input, one 16-bit result?
  assert(0);
 }
*/
 else if(Command == 0x0F)
 {
  //
  // Sync/NOP ?
  //
  DataReg = 0xFFFF; // or 0xFF?
 }
 else
 {
  SNES_DBG("[DSP2] Unknown command: %02x\n", Command);
  DataReg = 0xFFFF;
 }

 // FIXME, different per command?
 //if(Command != 0x0F)
 // DataReg = 0;
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

INLINE void DSP2Chip::WriteData(uint8 V)
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

INLINE uint8 DSP2Chip::ReadData(void)
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

INLINE uint8 DSP2Chip::ReadStatus(void)
{
 Run();
 //
 //
 return StatusReg;
}
