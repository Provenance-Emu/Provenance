/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* apu.cpp:
**  Copyright (C) 2015-2019 Mednafen Team
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

#define MDFN_SNES_FAUST_SPC700_IPL_HLE 1
//#define MDFN_SNES_FAUST_SPC700_IPL_EFFECTS_ANALYZE 1

#include "snes.h"
#include "apu.h"

#include <mednafen/sound/OwlResampler.h>

#ifdef MDFN_SNES_FAUST_SPC700_IPL_EFFECTS_ANALYZE
 #include <mednafen/FileStream.h>
#endif

namespace MDFN_IEN_SNES_FAUST
{

//#include "spc700.inc"

static uint8 IPL[64];

static uint8 APURAM[65536];
static uint8 IOFromSPC700[4];
static uint8 IOToSPC700[4];
//#include "spc700.inc"

static uint8 Control;

static uint8 WizardRAM[2];
static uint8 DSPAddr;

static unsigned T01PreDiv;
static uint8 TTARGET[3];
static uint8 TCOUNT[3];
static uint8 TOUT[3];

static MDFN_HOT MDFN_FASTCALL void TickTimer(unsigned which)
{
 if(Control & (1U << which))
 {
  TCOUNT[which]++;

  if(TCOUNT[which] == TTARGET[which])
  {
   TCOUNT[which] = 0;
   TOUT[which] = (TOUT[which] + 1) & 0xF;
  }
 }
}

static INLINE void TickT01PreDiv(void)
{
 T01PreDiv--;

 if(!T01PreDiv)
 {
  T01PreDiv = 4;

  TickTimer(0);
  TickTimer(1);
 }
}

#include "spc700.inc"
static SPC700 SPC_CPU;
static void (MDFN_FASTCALL *SPC_Page00_WriteTable[256])(uint16, uint8);
static uint8 (MDFN_FASTCALL *SPC_Page00_ReadTable[256])(uint16);
static void (MDFN_FASTCALL *SPC_PageXX_WriteTable[256])(uint16, uint8);
static uint8 (MDFN_FASTCALL *SPC_PageXX_ReadTable[256])(uint16);
static uint8 (MDFN_FASTCALL *SPC_PageFF_ReadTable[256])(uint16);

#include "dsp.inc"

template<unsigned special_base>
static uint8 MDFN_HOT MDFN_FASTCALL SPC_Read(uint16 A)
{
 SPC700_IOHandler();
 //
 //
 //
 uint8 ret = APURAM[A];

 if(special_base >= 0xFFC0 && special_base <= 0xFFFF)	// IPL Area
 {
  if(MDFN_LIKELY(Control & 0x80))
  {
   #ifdef MDFN_SNES_FAUST_SPC700_IPL_HLE
   //printf("wuh oh: %04x\n", A);
   #endif

   ret = IPL[(size_t)A - 0xFFC0];
  }
 }
 else if(special_base >= 0x00F0 && special_base <= 0x00FF)
 {
  ret = 0;

  switch(special_base)
  {
   default: break;

   case 0xF2: ret = DSPAddr;
	      break;

   case 0xF3: ret = DSP_Read(DSPAddr);
	      break;

   case 0xF4:
   case 0xF5:
   case 0xF6:
   case 0xF7: ret = IOToSPC700[special_base & 0x3];
	      break;

   case 0xF8:
   case 0xF9: ret = WizardRAM[special_base & 0x1];
	      break;

   case 0xFD: 
   case 0xFE:
   case 0xFF: ret = TOUT[special_base - 0xFD];
	      TOUT[special_base - 0xFD] = 0;
	      break;
  }
  //if(special_base >= 0xF4 && special_base <= 0xF7)
  // fprintf(stderr, "[SPC700] Read: %04x %02x (%08x)\n", A, ret, special_base);
 }

 return ret;
}

template<unsigned special_base>
static MDFN_HOT void MDFN_FASTCALL SPC_Write(uint16 A, uint8 V)
{
 SPC700_IOHandler();
 //
 //
 //
 APURAM[A] = V;

 if(special_base >= 0x00F0 && special_base <= 0x00FF)
 {
  //if(special_base <= 0xF1 || special_base >= 0xFA)
  //if(special_base >= 0xF4 && special_base <= 0xF7)
  // fprintf(stderr, "[SPC700] Write: %04x %02x (%08x)\n", A, V, special_base);

  switch(special_base)
  {
   default: break;

   case 0xF1: for(unsigned t = 0; t < 3; t++)
	      {
	       if((Control ^ V) & V & (1U << t))
	       {
	        TCOUNT[t] = 0;
	        TOUT[t] = 0;
	       }
	      }

	      if(V & 0x10)
	      {
	       IOToSPC700[0] = IOToSPC700[1] = 0x00;
	      }

	      if(V & 0x20)
	      {
	       IOToSPC700[2] = IOToSPC700[3] = 0x00;
	      }
	      Control = V & 0x87;
	      break;

   case 0xF2: DSPAddr = V;
	      break;

   case 0xF3: DSP_Write(DSPAddr, V);
	      break;

   case 0xF4:
   case 0xF5:
   case 0xF6:
   case 0xF7: IOFromSPC700[special_base & 0x3] = V;
	      break;

   case 0xF8:
   case 0xF9: WizardRAM[special_base & 0x1] = V;
	      break;

   case 0xFA: 
   case 0xFB:
   case 0xFC: TTARGET[special_base - 0xFA] = V;
	      break;
  }
 }
}

static uint32 apu_last_master_timestamp;
static unsigned run_count_mod;
static unsigned clock_multiplier;

static void MDFN_HOT MDFN_FASTCALL NO_INLINE APU_Update(uint32 master_timestamp)
{
 // (21477272.727 * 3129) / 65536 / 32 = 32044.594937
 // (21477272.727 / 60) * 3129 = 1120039772.71305
 assert(master_timestamp >= apu_last_master_timestamp);
 int32 tmp;
 int32 run_count;

 tmp = ((master_timestamp - apu_last_master_timestamp) * clock_multiplier) + run_count_mod;
 apu_last_master_timestamp = master_timestamp;
 run_count_mod 	= (uint16)tmp;
 run_count 	= tmp >> 16;

 //
 //
 //
 if(MDFN_LIKELY(run_count > 0))
  SPC_CPU.Run(run_count);
}

static DEFREAD(MainCPU_APUIORead)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return IOFromSPC700[A & 0x3];
 }

 CPUM.timestamp += MEMCYC_FAST / 2;

 APU_Update(CPUM.timestamp);

 CPUM.timestamp += MEMCYC_FAST / 2;

 //printf("[MAIN] APU Read: %08x %02x\n", A, IOFromSPC700[A & 0x3]);

 return IOFromSPC700[A & 0x3];
}

static DEFWRITE(MainCPU_APUIOWrite)
{
 CPUM.timestamp += MEMCYC_FAST;

 APU_Update(CPUM.timestamp);

 //printf("[MAIN] APU Write: %08x %02x\n", A, V);

 IOToSPC700[A & 0x3] = V;
}

#ifdef MDFN_SNES_FAUST_SPC700_IPL_HLE
static int32 HLEPhase;
static uint16 HLELoadAddr;
static uint8 HLECounter;
static uint8 HLEHS;
static uint32 HLESuckCounter;
static uint8 HLETemp;

enum : int { HLEPhaseBias = __COUNTER__ + 1 };

#define HLE_YIELD()	{ HLEPhase = __COUNTER__ - HLEPhaseBias + 1; goto Breakout; case __COUNTER__: ; }

#define HLE_WRITE(a,v)	{ WriteMem((a), (v));HLE_YIELD(); }
#define HLE_DUMMY_READ(a) { ReadMem((a)); HLE_YIELD(); }
#define HLE_READ(a,v)	{ v = ReadMem((a)); HLE_YIELD(); }

#define HLE_SUCK(n)	{ for(HLESuckCounter = (n); HLESuckCounter; HLESuckCounter--) { IO(); HLE_YIELD(); } }

//
// TODO: Fix timing, and any inaccuracies(had to guess at some protocol stuff).
//
INLINE void SPC700::IPL_HLE(void)
{
 switch(HLEPhase + HLEPhaseBias)
 {
  for(;;)
  {
   default:
   case __COUNTER__:
   //
   //
   //if(PC != 0xFFC1)
   // printf("Begin %04x\n", PC);

/*
   if(PC == 0xFFC3)	// Not sure what effect this has.
   {
    // Bishoujo Senshi Sailor Moon S - Jougai Rantou! Shuyaku Soudatsusen
    // Gaia Saver - Hero Saidai no Sakusen
    // Kawa no Nushi Tsuri 2
    // Umi no Nushi Tsuri
    // Zero 4 Champ RR
    printf("%02x %02x %02x\n", PSW, SP, A);
    abort();
   }
*/

   if(PC == 0xFFCA)
    goto SkipMemInit;

   assert(PC == 0xFFC1 || PC == 0xFFC3);

   PSW = 0x00;
   SP = 0xEF;

   for(A = 0xEF; A >= 0x01; A--)
   {
    HLE_SUCK((A == 0xEF) ? 7 : 8);
    HLE_DUMMY_READ(A);
    HLE_WRITE(A, 0x00);
   }
   SkipMemInit:;

   HLE_SUCK(7);
   HLE_DUMMY_READ(0xF4);
   HLE_WRITE(0xF4, 0xAA);

   HLE_SUCK(3);
   HLE_DUMMY_READ(0xF5);
   HLE_WRITE(0xF5, 0xBB);

   HLE_SUCK(1);

   do
   {
    HLE_SUCK(2);
    HLE_READ(0xF4, A);
    HLE_SUCK(6);
   } while(A != 0xCC);

   BigLoop:;
   {
    HLE_READ(0xF6, A);
    HLELoadAddr = A;
    HLE_SUCK(1);
    HLE_READ(0xF7, A);
    HLELoadAddr |= A << 8;

    //printf("Load Address: %04x\n", HLELoadAddr);
    HLE_SUCK(2);
    HLE_DUMMY_READ(0x00);
    HLE_WRITE(0x00, HLELoadAddr);
    HLE_WRITE(0x01, HLELoadAddr >> 8);

    // ?
    HLE_READ(0xF4, A);

    HLE_READ(0xF5, HLEHS);

    HLE_READ(0xF4, A);
    HLE_WRITE(0xF4, A);

    if(!HLEHS)
    {
     HLE_SUCK(9);
     HLE_READ(0x0000, HLETemp);
     HLE_READ(0x0001, HLETemp);

     A = 0x00;
     X = 0x00;
     Y = 0x00;
     PSW = (PSW & H_FLAG) | 0x06;
     PC = HLELoadAddr;
     Halted = false;
     //printf("Done: PC=0x%04x A=%02x X=%02x Y=%02x SP=%02x PSW=%02x --- %02x %02x %02x %02x\n", PC, A, X, Y, SP, PSW, IOFromSPC700[0], IOFromSPC700[1], IOFromSPC700[2], IOFromSPC700[3]);
     HLE_YIELD();
    }
    else
    {
     do
     {
      HLE_READ(0xF4, HLECounter);
     } while(HLECounter != 0x00);

     SmallLoop:;
     do
     {
      HLE_SUCK(4);
      HLE_READ(0xF4, A);
      //printf("%02x %02x\n", HLECounter, A);
     } while(!((HLECounter - A - 1) & 0x80));  //(HLECounter > A);

     if(HLECounter == A)
     {
      HLE_SUCK(4);
      HLE_READ(0xF5, A);
      HLE_SUCK(2);
      HLE_READ(0xF4, HLETemp);
      HLE_WRITE(0xF4, HLETemp);

      HLE_SUCK(2);
      HLE_READ(0x00, HLETemp);
      HLELoadAddr = HLETemp;

      HLE_READ(0x01, HLETemp);
      HLELoadAddr |= HLETemp << 8;

      HLE_SUCK(1);
      //printf("WB: %04x %02x\n", HLELoadAddr + HLECounter, A);
      HLE_DUMMY_READ(HLELoadAddr + HLECounter);
      HLE_WRITE(HLELoadAddr + HLECounter, A);

      HLECounter++;

      if(!HLECounter)
      {
       HLE_SUCK(6);
       HLE_READ(0x01, HLETemp);
       HLETemp++;
       HLE_WRITE(0x01, HLETemp);
      }
      HLE_SUCK(4);
      goto SmallLoop;
     }
     else
     {
      goto BigLoop;
     }
    }
   }
  }
 }
 //
 //
 //
 Breakout:;
}
#endif

void APU_Reset(bool powering_up)
{
 memset(IOFromSPC700, 0x00, sizeof(IOFromSPC700));	// See: Mighty Max, Ninja Warriors Again
 memset(IOToSPC700, 0x00, sizeof(IOToSPC700));

 if(powering_up)
  memset(APURAM, 0xFF, sizeof(APURAM));

 Control = 0x80;

 memset(WizardRAM, 0xFF, sizeof(WizardRAM));
 DSPAddr = 0x00;

 T01PreDiv = 4;
 memset(TCOUNT, 0, sizeof(TCOUNT));
 memset(TTARGET, 0, sizeof(TTARGET));
 memset(TOUT, 0, sizeof(TOUT));

 DSP_Reset(powering_up);
 SPC_CPU.Reset(powering_up);

#ifdef MDFN_SNES_FAUST_SPC700_IPL_HLE
 HLEPhase = 0;
 HLELoadAddr = 0;
 HLECounter = 0;
 HLEHS = 0;
 HLESuckCounter = 0;
 HLETemp = 0;
#endif
}

double APU_Init(const bool IsPAL, double master_clock)
{
#ifdef MDFN_SNES_FAUST_SPC700_IPL_HLE
 memset(IPL, 0xFF, sizeof(IPL));
 MDFN_en16lsb(&IPL[0x3E], 0xFFC0);
#else
 static const uint8 IPL_Init[64] =
 {
  #include "apu_ipl.inc"
 };

 memcpy(IPL, IPL_Init, sizeof(IPL));
#endif
 //
 apu_last_master_timestamp = 0;
 run_count_mod = 0;
 clock_multiplier = IsPAL ? 3158 : 3129;

 Set_B_Handlers(0x40, 0x7F, MainCPU_APUIORead, MainCPU_APUIOWrite);	// 4 registers mirrored throughout the range.

 DSP_Init();

 for(unsigned i = 0; i < 256; i++)
 {
  SPC_Page00_WriteTable[i] = &SPC_Write<~0U>;
  SPC_PageXX_WriteTable[i] = &SPC_Write<~0U>;

  SPC_Page00_ReadTable[i] = &SPC_Read<~0U>;
  SPC_PageXX_ReadTable[i] = &SPC_Read<~0U>;

  if(i >= 0xC0)
   SPC_PageFF_ReadTable[i] = &SPC_Read<0xFFC0>;
  else
   SPC_PageFF_ReadTable[i] = &SPC_Read<~0U>;
 }

 #define P00H(n) SPC_Page00_ReadTable[n] = &SPC_Read<n>; SPC_Page00_WriteTable[n] = &SPC_Write<n>
 P00H(0xF0); P00H(0xF1); P00H(0xF2); P00H(0xF3); P00H(0xF4); P00H(0xF5); P00H(0xF6); P00H(0xF7);
 P00H(0xF8); P00H(0xF9); P00H(0xFA); P00H(0xFB); P00H(0xFC); P00H(0xFD); P00H(0xFE); P00H(0xFF);
 #undef P00H

 for(unsigned i = 0; i < 256; i++)
 {
  SPC700_ReadMap[i] = SPC_PageXX_ReadTable;
  SPC700_WriteMap[i] = SPC_PageXX_WriteTable;
 }

 SPC700_ReadMap[0] = SPC_Page00_ReadTable;
 SPC700_WriteMap[0] = SPC_Page00_WriteTable;
 SPC700_ReadMap[0xFF] = SPC_PageFF_ReadTable;

 return (master_clock * clock_multiplier) / (65536.0 * 32.0);
}

void APU_SetSPC(SPCReader* s)
{
 const uint8* tr = s->DSPRegs();

 memcpy(APURAM, s->APURAM(), 65536);

 DSP_Write(GRA_FLG, 0xE0);

 for(unsigned i = 0; i < 256; i++)
  SPC700_IOHandler();

 for(unsigned i = 0; i < 0x80; i++)
 {
  if(i != GRA_FLG)
   DSP_Write(i, tr[i]);
 }

 DSP_Write(GRA_KON, 0xFF);
 DSP_Write(GRA_KOFF, 0xFF);

 for(unsigned i = 0; i < 256; i++)
  SPC700_IOHandler();

 DSP_Write(GRA_KON, tr[GRA_KON]);
 DSP_Write(GRA_KOFF, tr[GRA_KOFF]);
 DSP_Write(GRA_FLG, tr[GRA_FLG]);

 Control = APURAM[0xF1] & 0x87;
 DSPAddr = APURAM[0xF2];

 for(unsigned i = 0; i < 4; i++)
 {
  IOFromSPC700[i] = APURAM[0xF4 + i];
  IOToSPC700[i] = APURAM[0xF4 + i];
 }

 for(unsigned i = 0; i < 2; i++)
  WizardRAM[i] = APURAM[0xF8 + i];

 for(unsigned i = 0; i < 3; i++)
  TTARGET[i] = APURAM[0xFA + i];

 for(unsigned i = 0; i < 3; i++)
  TOUT[i] = APURAM[0xFD + i] & 0x0F;

 SPC_CPU.SetRegister(SPC700::GSREG_PC, s->PC());
 SPC_CPU.SetRegister(SPC700::GSREG_A, s->A());
 SPC_CPU.SetRegister(SPC700::GSREG_X, s->X());
 SPC_CPU.SetRegister(SPC700::GSREG_Y, s->Y());
 SPC_CPU.SetRegister(SPC700::GSREG_PSW, s->PSW());
 SPC_CPU.SetRegister(SPC700::GSREG_SP, s->SP());
}

bool APU_StartFrame(double master_clock, double rate, int32* apu_clock_multiplier, int32* resamp_num, int32* resamp_denom)
{
 *apu_clock_multiplier = clock_multiplier;

 return DSP_StartFrame((master_clock * clock_multiplier) / (65536.0 * 32.0), rate, resamp_num, resamp_denom);
}

uint32 APU_UpdateGetResampBufPos(uint32 master_timestamp)
{
 APU_Update(master_timestamp);

 return DSP.OutputBufPos;
}

int32 APU_EndFrame(int16* SoundBuf)
{
#if 0	// Testing
 for(uint32 i = apu_last_master_timestamp; i <= CPUM.timestamp; i++)
  APU_Update(i);
#else
 APU_Update(CPUM.timestamp);
#endif

#if 0
 printf("%02x %02x %02x %02x %s\n", APURAM[0x8000], APURAM[0x8001], APURAM[0x8002], APURAM[0x8003], &APURAM[0x8004]);
#endif
 apu_last_master_timestamp = 0;

 return DSP_EndFrame(SoundBuf);
}


void APU_Kill(void)
{
 DSP_Kill();
}

void APU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(APURAM),
  SFVAR(IOFromSPC700),
  SFVAR(IOToSPC700),

  SFVAR(Control),

  SFVAR(WizardRAM),
  SFVAR(DSPAddr),

  SFVAR(T01PreDiv),
  SFVAR(TTARGET),
  SFVAR(TCOUNT),
  SFVAR(TOUT),

  SFVAR(run_count_mod),

  SFEND
 };


 MDFNSS_StateAction(sm, load, data_only, StateRegs, "APU");

 if(load)
 {
  run_count_mod = (uint16)run_count_mod;
 }

 SPC_CPU.StateAction(sm, load, data_only);

 DSP_StateAction(sm, load, data_only);

#ifdef MDFN_SNES_FAUST_SPC700_IPL_HLE
 SFORMAT HLE_StateRegs[] =
 {
  SFVAR(HLEPhase),
  SFVAR(HLELoadAddr),
  SFVAR(HLECounter),
  SFVAR(HLEHS),
  SFVAR(HLESuckCounter),
  SFVAR(HLETemp),

  SFEND
 };

 const bool hle_section_optional = SPC_CPU.GetRegister(SPC700::GSREG_PC) < 0xFFC0;

 if(!MDFNSS_StateAction(sm, load, data_only, HLE_StateRegs, "APU_IPL_HLE", hle_section_optional))
 {
  HLEPhase = 0;
  HLELoadAddr = 0;
  HLECounter = 0;
  HLEHS = 0;
  HLESuckCounter = 0;
  HLETemp = 0;
 }
#endif
}

void APU_PokeRAM(uint32 addr, const uint8 val)
{
 APURAM[addr & 0xFFFF] = val;
}

uint8 APU_PeekRAM(uint32 addr)
{
 return APURAM[addr & 0xFFFF];
}

}
