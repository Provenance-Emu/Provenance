/******************************************************************************/
/* Mednafen Sega Arcade SCSP Sound Player Module                              */
/******************************************************************************/
/* sasplay.cpp:
**  Copyright (C) 2021 Mednafen Team
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
 Model 2A, 2B, 2C, 3

 Features TODO:
	DSB* MPEG support.

	Sound effect/voices playback.

 Verify/Fix TODO:
	68K reset vector handling

	ROM mirroring/pullup/open bus/whatever.

	Control register bits 4 and 5.

	Control register mirroring, 16-bit access, read access.

	ROM and control register access timings.

	MIDI timing.

	16-bit or 18-bit audio DAC(16-bit overflow in some unused music in DOA and VF3 specifically)

	SCSP output mixing semantics and analog filtering.

	Investigate cause of right channel squeaking sound in "Dead or Alive" song "Blade of Ryu".
*/

/*
 Known FM-utilizing games:

	Dynamite Baseball '97
	Fighting Vipers 2
	House of the Dead
	Motor Raid
	Super GT 24h (barely)
	Virtua Fighter 3
	Virtua Striker 2
*/

#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/player.h>
#include <mednafen/resampler/resampler.h>
#include <mednafen/hw_cpu/m68k/m68k.h>
#include <mednafen/jump.h>

#include <trio/trio.h>

using namespace Mednafen;

namespace MDFN_IEN_SASPLAY
{
 enum
 {
  SS_DBG_ERROR     = (1U <<  0),
  SS_DBG_WARNING   = (1U <<  1),

  SS_DBG_M68K      = (1U <<  2),

  SS_DBG_SCSP      = (1U << 26),
  SS_DBG_SCSP_REGW = (1U << 27),
  SS_DBG_SCSP_MOBUF= (1U << 28),
 };

#ifdef MDFN_ENABLE_DEV_BUILD

static const uint32 ss_dbg_mask = SS_DBG_WARNING;
static void SS_DBG(uint32 which, const char* format, ...)
{
 if(ss_dbg_mask & which)
 {
  va_list ap;
  va_start(ap, format);
 
  vprintf(format, ap);

  va_end(ap);
 }
}
#else
enum : uint32 { ss_dbg_mask = 0 };
static INLINE void SS_DBG(uint32 which, const char* format, ...)
{
 //
}
#endif

template<unsigned which>
static void SS_DBG_Wrap(const char* format, ...) noexcept
{
 if(ss_dbg_mask & which)
 {
  va_list ap;

  va_start(ap, format);

  trio_vprintf(format, ap);

  va_end(ap);
 }
}


#include "../ss/scsp.h"

typedef int32 sscpu_timestamp_t;

static std::unique_ptr<uint16[]> ProgramROM;
static std::unique_ptr<uint16[]> SamplesROM;
static uintptr_t ProgramROMPtr;
static uintptr_t SamplesROMBankPtr;
static size_t SamplesROMBankMask;
static uint8 Control;

static INLINE void RecalcSamplesROMBankPtr(void)
{
 assert(SamplesROMBankMask >= 0x7FFFFF);
 SamplesROMBankPtr = (uintptr_t)SamplesROM.get() - 0x800000 + (((Control & 0x10) << 19) & SamplesROMBankMask);
}

static SS_SCSP SCSP[2];
static M68K SoundCPU(true);
static int32 VolumeMul;
static int64 run_until_time;	// 32.32
static int32 next_scsp_time;
static sscpu_timestamp_t lastts;
static bool DualSCSP;

static MDFN_jmp_buf jbuf;

static int16 IBuffer[1024][2];
static uint32 IBufferCount;
static SpeexResamplerState* resampler = NULL;
static int last_rate;
static uint32 last_quality;

static INLINE void SCSP_SoundIntChanged(SS_SCSP* s, unsigned level)
{
 //if(level && s != &SCSP[0])
 // printf("level%u: %u\n", (unsigned)(s - SCSP), level);

 if(s != &SCSP[0])
  return;

 SoundCPU.SetIPL(level);
}

static INLINE void SCSP_MainIntChanged(SS_SCSP* s, bool state)
{
 //
}

#include "../ss/scsp.inc"

//
//
template<typename T>
static MDFN_FASTCALL T SoundCPU_BusRead(uint32 A);

static MDFN_FASTCALL uint16 SoundCPU_BusReadInstr(uint32 A);

template<typename T>
static MDFN_FASTCALL void SoundCPU_BusWrite(uint32 A, T V);

static MDFN_FASTCALL void SoundCPU_BusRMW(uint32 A, uint8 (MDFN_FASTCALL *cb)(M68K*, uint8));
static MDFN_FASTCALL unsigned SoundCPU_BusIntAck(uint8 level);
static MDFN_FASTCALL void SoundCPU_BusRESET(bool state);
//
//

void SOUND_Init(bool dual_scsp)
{
 memset(IBuffer, 0, sizeof(IBuffer));
 IBufferCount = 0;

 last_rate = -1;
 last_quality = ~0U;

 run_until_time = 0;
 next_scsp_time = 0;
 lastts = 0;

 DualSCSP = dual_scsp;

 SoundCPU.BusRead8 = SoundCPU_BusRead<uint8>;
 SoundCPU.BusRead16 = SoundCPU_BusRead<uint16>;

 SoundCPU.BusWrite8 = SoundCPU_BusWrite<uint8>;
 SoundCPU.BusWrite16 = SoundCPU_BusWrite<uint16>;

 SoundCPU.BusReadInstr = SoundCPU_BusReadInstr;

 SoundCPU.BusRMW = SoundCPU_BusRMW;

 SoundCPU.BusIntAck = SoundCPU_BusIntAck;
 SoundCPU.BusRESET = SoundCPU_BusRESET;

#ifdef MDFN_ENABLE_DEV_BUILD
 SoundCPU.DBG_Warning = SS_DBG_Wrap<SS_DBG_WARNING | SS_DBG_M68K>;
 SoundCPU.DBG_Verbose = SS_DBG_Wrap<SS_DBG_M68K>;
#endif
}

static INLINE void ResetTS_68K(void)
{
 next_scsp_time -= SoundCPU.timestamp;
 run_until_time -= (int64)SoundCPU.timestamp << 32;
 SoundCPU.timestamp = 0;
}

void SOUND_AdjustTS(const int32 delta)
{
 ResetTS_68K();
 //
 //
 lastts += delta;
}

void SOUND_Reset(bool powering_up)
{
 for(size_t i = 0; i < 2; i++)
  SCSP[i].Reset(powering_up);
 SoundCPU.Reset(powering_up);
}

void SOUND_Reset68K(void)
{
 SoundCPU.Reset(false);
}

void SOUND_Kill(void)
{
 ProgramROM.reset(nullptr);
 SamplesROM.reset(nullptr);

 if(resampler)
 {
  speex_resampler_destroy(resampler);  
  resampler = NULL;
 }
}

static NO_INLINE void RunSCSP(void)
{
 int16* const bp = IBuffer[IBufferCount];

 if(!DualSCSP)
 {
  int32 tmp[2];

  SCSP[0].RunSample(tmp);

  bp[0] = std::max<int32>(-32768, std::min<int32>(32767, (tmp[0] * VolumeMul + 512) >> 10));
  bp[1] = std::max<int32>(-32768, std::min<int32>(32767, (tmp[1] * VolumeMul + 512) >> 10));
 }
 else
 {
  int32 tmp[2][2];

  SCSP[0].RunSample(tmp[0]);
  SCSP[1].RunSample(tmp[1]);

  bp[0] = std::max<int32>(-32768, std::min<int32>(32767, ((tmp[0][0] + tmp[1][0]) * VolumeMul + 512) >> 10));
  bp[1] = std::max<int32>(-32768, std::min<int32>(32767, ((tmp[0][1] + tmp[1][1]) * VolumeMul + 512) >> 10));
 }

 IBufferCount = (IBufferCount + 1) & 1023;
 next_scsp_time += 256;
}

sscpu_timestamp_t SOUND_Update(sscpu_timestamp_t timestamp)
{
 run_until_time += ((uint64)(timestamp - lastts) << 31);
 lastts = timestamp;
 //
 //
 MDFN_setjmp(jbuf);

 if(MDFN_LIKELY(SoundCPU.timestamp < (run_until_time >> 32)))
 {
  do
  {
   int32 next_time = std::min<int32>(next_scsp_time, run_until_time >> 32);

   SoundCPU.Run(next_time);

   if(SoundCPU.timestamp >= next_scsp_time)
    RunSCSP();
  } while(MDFN_LIKELY(SoundCPU.timestamp < (run_until_time >> 32)));
 }
 else
 {
  while(next_scsp_time < (run_until_time >> 32))
   RunSCSP();
 }

 return timestamp + 128;	// FIXME
}

void SOUND_StartFrame(double rate, uint32 quality)
{
 if((int)rate != last_rate || quality != last_quality)
 {
  int err = 0;

  if(resampler)
  {
   speex_resampler_destroy(resampler);
   resampler = NULL;
  }

  if((int)rate && (int)rate != 44100)
  {
   resampler = speex_resampler_init(2, 44100, (int)rate, quality, &err);
  }

  last_rate = (int)rate;
  last_quality = quality;
 }
}

int32 SOUND_FlushOutput(int16* SoundBuf, const int32 SoundBufMaxSize, const bool reverse)
{
 if(SoundBuf && reverse)
 {
  for(unsigned lr = 0; lr < 2; lr++)
  {
   int16* p0 = &IBuffer[0][lr];
   int16* p1 = &IBuffer[IBufferCount - 1][lr];
   unsigned count = IBufferCount >> 1;

   while(MDFN_LIKELY(count--))
   {
    std::swap(*p0, *p1);

    p0 += 2;
    p1 -= 2;
   }
  }
 }
 
 if(last_rate == 44100)
 {
  int32 ret = IBufferCount;

  memcpy(SoundBuf, IBuffer, IBufferCount * 2 * sizeof(int16));
  IBufferCount = 0;

  return(ret);
 }
 else if(resampler)
 {
  spx_uint32_t in_len; // "Number of input samples in the input buffer. Returns the number of samples processed. This is all per-channel."
  spx_uint32_t out_len; // "Size of the output buffer. Returns the number of samples written. This is all per-channel."

  in_len = IBufferCount;
  out_len = SoundBufMaxSize;

  speex_resampler_process_interleaved_int(resampler, (const spx_int16_t *)IBuffer, &in_len, (spx_int16_t *)SoundBuf, &out_len);

  assert(in_len <= IBufferCount);

  if((IBufferCount - in_len) > 0)
   memmove(IBuffer, IBuffer + in_len, (IBufferCount - in_len) * sizeof(int16) * 2);

  IBufferCount -= in_len;

  return(out_len);
 }
 else
 {
  IBufferCount = 0;
  return 0;
 }
}

static void SOUND_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(next_scsp_time),
  SFVAR(run_until_time),

  SFVAR(Control),

  SFEND
 };

 //
 next_scsp_time -= SoundCPU.timestamp;
 run_until_time -= (int64)SoundCPU.timestamp << 32;

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SOUND");

 if(load)
 {
  RecalcSamplesROMBankPtr();
 }

 next_scsp_time += SoundCPU.timestamp;
 run_until_time += (int64)SoundCPU.timestamp << 32;
 //

 SoundCPU.StateAction(sm, load, data_only, "M68K");
 SCSP[0].StateAction(sm, load, data_only, "SCSP");
 if(DualSCSP)
  SCSP[1].StateAction(sm, load, data_only, "SCSP1");
}

//
//
//
template<typename T, bool IsWrite>
static INLINE void SoundCPU_BusRW(uint32 A, T& DBV)
{
 A &= 0xFFFFFF;

 //if(IsWrite)
 // printf("Write%zu: %08x %04x\n", sizeof(T), A, DBV);

 switch(A >> 19)
 {
  case 0x00: // 0x000000-0x07FFFF
  case 0x01: // 0x080000-0x0FFFFF
  case 0x02: // 0x100000-0x17FFFF
  case 0x03: // 0x180000-0x1FFFFF
	SoundCPU.timestamp += IsWrite ? 2 : 4;

	if(MDFN_UNLIKELY(SoundCPU.timestamp >= next_scsp_time))
	 RunSCSP();

	//if(A < 0x100)
	// printf("%06x %04x %zu\n", A, DBV, sizeof(T));

	SCSP[0].RW<T, IsWrite>(A & 0x1FFFFF, DBV);

	SoundCPU.timestamp += IsWrite ? 4 : 2;
	break;

  case 0x04: // 0x200000-0x27FFFF
  case 0x05: // 0x280000-0x2FFFFF
  case 0x06: // 0x300000-0x37FFFF
  case 0x07: // 0x380000-0x3FFFFF
	if(MDFN_UNLIKELY(!DualSCSP))
	 goto Unknown;
	//
	SoundCPU.timestamp += IsWrite ? 2 : 4;

	if(MDFN_UNLIKELY(SoundCPU.timestamp >= next_scsp_time))
	 RunSCSP();

	SCSP[1].RW<T, IsWrite>(A & 0x1FFFFF, DBV);

	SoundCPU.timestamp += IsWrite ? 4 : 2;
	break;

  case 0x08: // 0x400000-0x47FFFF
  case 0x09: // 0x480000-0x4FFFFF
  case 0x0A: // 0x500000-0x57FFFF
  case 0x0B: // 0x580000-0x5FFFFF
	//printf("Control %08x %04x %zu\n", A, DBV, sizeof(T));

	if(A == 0x00400001 && IsWrite)
	{
	 Control = DBV;
	 RecalcSamplesROMBankPtr();
	}

	SoundCPU.timestamp += 4;
	break;

  case 0x0C: // 0x600000-0x67FFFF
	if(!IsWrite)
	 DBV = ne16_rbo_be<T>(ProgramROMPtr, A);

	SoundCPU.timestamp += 4;
	break;

  // 0x800000-0xFFFFFF
  case 0x10:
  case 0x11:
  case 0x12:
  case 0x13:
  case 0x14:
  case 0x15:
  case 0x16:
  case 0x17:
  case 0x18:
  case 0x19:
  case 0x1A:
  case 0x1B:
  case 0x1C:
  case 0x1D:
  case 0x1E:
  case 0x1F:
	if(!IsWrite)
	 DBV = ne16_rbo_be<T>(SamplesROMBankPtr, A);

	SoundCPU.timestamp += 4;
	break;

  default:
  Unknown:;
	//printf("Unknown access: %08x %zu %d\n", A, sizeof(T), IsWrite);

	if(!IsWrite)
	 DBV = 0;
#if 0
	SoundCPU.SignalDTACKHalted(A);
	MDFN_longjmp(jbuf);
#endif
	break;
 }
}

template<typename T>
static MDFN_FASTCALL T SoundCPU_BusRead(uint32 A)
{
 if(MDFN_UNLIKELY(A & (sizeof(T) - 1)))
 {
  SoundCPU.timestamp += 4;

  SoundCPU.SignalAddressError(A, 0x3);

  MDFN_longjmp(jbuf);
 }
 //
 T ret = 0;

 SoundCPU_BusRW<T, false>(A, ret);

 return ret;
}

static MDFN_FASTCALL uint16 SoundCPU_BusReadInstr(uint32 A)
{
 if(MDFN_UNLIKELY(A & 0x1))
 {
  SoundCPU.timestamp += 4;

  SoundCPU.SignalAddressError(A, 0x2);

  MDFN_longjmp(jbuf);
 }
 //
 uint16 ret = 0;

 SoundCPU_BusRW<uint16, false>(A, ret);

 return ret;
}

template<typename T>
static MDFN_FASTCALL void SoundCPU_BusWrite(uint32 A, T V)
{
 if(MDFN_UNLIKELY(A & (sizeof(T) - 1)))
 {
  SoundCPU.timestamp += 4;

  SoundCPU.SignalAddressError(A, 0x1);

  MDFN_longjmp(jbuf);
 }
 //
 SoundCPU_BusRW<T, true>(A, V);
}

static MDFN_FASTCALL void SoundCPU_BusRMW(uint32 A, uint8 (MDFN_FASTCALL *cb)(M68K*, uint8))
{
 uint8 tmp = 0;

 if(MDFN_LIKELY(!(A & 0xC00000)))
 {
  const size_t w = (A >> 21) & 1;

  if(MDFN_UNLIKELY(w & !DualSCSP))
   goto Other;

  SoundCPU.timestamp += 4;

  if(MDFN_UNLIKELY(SoundCPU.timestamp >= next_scsp_time))
   RunSCSP();

  SCSP[w].RW<uint8, false>(A & 0x1FFFFF, tmp);

  tmp = cb(&SoundCPU, tmp);

  SoundCPU.timestamp += 6;

  SCSP[w].RW<uint8, true>(A & 0x1FFFFF, tmp);

  SoundCPU.timestamp += 2;
 }
 else
 {
  Other:;
  SoundCPU_BusRW<uint8, false>(A, tmp);

  tmp = cb(&SoundCPU, tmp);

  SoundCPU.timestamp += 6;	// TODO: check timing.
 }
}

static MDFN_FASTCALL unsigned SoundCPU_BusIntAck(uint8 level)
{
 SoundCPU.timestamp += 10;

 return M68K::BUS_INT_ACK_AUTO;
}

static MDFN_FASTCALL void SoundCPU_BusRESET(bool state)
{
 //SS_DBG(SS_DBG_WARNING, "[M68K] RESET: %d @ time %d\n", state, SoundCPU.timestamp);
 if(state)
 {
  SoundCPU.Reset(false);
 }
}

//
//
//
//
//
enum
{
 SYSTEM_MODEL2 = 0,
 SYSTEM_MODEL3 = 1
};

enum
{
 SPACE_PROGRAM = 0,
 SPACE_SAMPLES = 1,

 SPACE_ALIEN = 0xFF
};

struct ROMLayout
{
 uint8 space;
 uint32 offset;
 uint32 size;
 const char* fname;
};

struct SongInfo
{
 const uint16 id;
 const char* name;
 uint32 volume;
};

struct SMXGameInfo
{
 const char* name;
 const char* artist;
 const char* copyright;
 const SongInfo* songs;
 uint32 num_songs;
 uint32 volume;

 uint8 system;
 ROMLayout rom_layout[8];
};

#include "songs.h"
#include "games.h"

static void StateAction(StateMem* sm, const unsigned load, const bool data_only);
static MDFN_COLD void Reset(void);
static std::unique_ptr<MemoryStream> InitSaveState;
static uint8* controller_ptr;
static uint8 prev_cstate;
static uint32 CurrentSong;
static uint32 NumSongs;
static const SMXGameInfo* Game;
static const SongInfo* Songs;

// FF: Init (takes a while to complete)
// A0 00 01: silence bgm?
// A0 01 xx: set bgm volume
// A0 03 xx: fade out
// A0 04 xx: fade in?
// A0 07 xx: change instruments to song xx ?
// A0 0D xx: set dry volume? (persistent)
// A0 10 xx: play song xx
// A0 21 01: silence sfx? (VF3)

static void StartSong(void)
{
 const SongInfo* si = Songs ? &Songs[CurrentSong] : nullptr;

 SCSP[0].WriteMIDI(0xA0);

#if 0
 SCSP[0].WriteMIDI(CurrentSong >> 2);
 SCSP[0].WriteMIDI(CurrentSong & 0x3);
 //SCSP[0].WriteMIDI(0x01);
 //SCSP[0].WriteMIDI(CurrentSong);
#else
 if(si && (si->id >> 8))
  SCSP[0].WriteMIDI(si->id >> 8);
 else
  SCSP[0].WriteMIDI(0x10);

 SCSP[0].WriteMIDI(si ? si->id : CurrentSong);
#endif

 VolumeMul = (si && si->volume) ? si->volume : Game->volume;
}

static void Emulate(EmulateSpecStruct* espec)
{
 //
 //
 {
  const uint8 cur_cstate = *controller_ptr;
  const uint8 pressed = (prev_cstate ^ cur_cstate) & cur_cstate;
  //
  if(pressed & 0x1F)
  {
   int d = 0;

   d += (bool)(pressed & 0x02);
   d -= (bool)(pressed & 0x04);
   d += 10 * (bool)(pressed & 0x08);
   d -= 10 * (bool)(pressed & 0x10);
   //
   const uint32 ncs = CurrentSong + std::max<int32>(-CurrentSong, std::min<int32>(NumSongs - CurrentSong - 1, d));
   //
   Reset();
   //
   *controller_ptr = cur_cstate;
   CurrentSong = ncs;
   StartSong();
  }

  prev_cstate = cur_cstate;
 }

 SOUND_StartFrame(espec->SoundRate / espec->soundmultiplier, MDFN_GetSettingUI("sasplay.resamp_quality"));
 espec->soundmultiplier = 1;

 const int32 target_timestamp = 588 * 512;
 SOUND_Update(target_timestamp);
 espec->MasterCycles = target_timestamp >> 1;
 espec->SoundBufSize = SOUND_FlushOutput(espec->SoundBuf, espec->SoundBufMaxSize, espec->NeedSoundReverse);
 espec->NeedSoundReverse = false;
 SOUND_AdjustTS(-target_timestamp);

 if(!espec->skip)
 {
  espec->LineWidths[0] = ~0;
  Player_Draw(espec->surface, &espec->DisplayRect, CurrentSong, espec->SoundBuf, espec->SoundBufSize);
 }
}

static MDFN_COLD void Cleanup(void)
{
 SOUND_Kill();

 ProgramROM.reset(nullptr);
 SamplesROM.reset(nullptr);
 InitSaveState.reset(nullptr);
}


static MDFN_COLD void Reset(void)
{
 try
 {
  InitSaveState->rewind();
  MDFNSS_LoadInternal(InitSaveState.get(), StateAction);
 }
 catch(std::exception& e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, "Reset() failed: %s", e.what());
 }
}

static const SMXGameInfo* FindSGI(const std::string& fname)
{
 const SMXGameInfo* ret = nullptr;

 for(SMXGameInfo const& sgie : SMXGI)
 {
  for(ROMLayout const& rle : sgie.rom_layout)
  {
   if(!rle.fname)
    break;

   if(!MDFN_strazicmp(fname, rle.fname))
   {
    ret = &sgie;
    break;
   }
  }
 }

 return ret;
}


static MDFN_COLD bool TestMagic(GameFile* gf)
{
 const std::string fname = gf->fbase + "." + gf->ext;
 const SMXGameInfo* const sgi = FindSGI(fname);

 return sgi != nullptr;
}

static MDFN_COLD void Load(GameFile* gf)
{
 try
 {
  const std::string fname = gf->fbase + "." + gf->ext;
  const SMXGameInfo* const sgi = FindSGI(fname);

  if(!sgi)
   throw MDFN_Error(0, _("File unrecognized by \"%s\" module."), MDFNGameInfo->shortname);
  //
  //
  if(sgi->system == SYSTEM_MODEL3)
  {
   SamplesROMBankMask = 0xFFFFFF;
  }
  else
  {
   SamplesROMBankMask = 0x7FFFFF;
  }
  

  ProgramROM.reset(new uint16[0x80000]);
  SamplesROM.reset(new uint16[SamplesROMBankMask + 1]);

  for(size_t i = 0; i < 0x80000; i++)
   ProgramROM[i] = 0;

  for(size_t i = 0; i <= SamplesROMBankMask; i++)
   SamplesROM[i] = 0; //((i & 0xF) << 4); //rand();
  //
  //
  for(ROMLayout const& rle : sgi->rom_layout)
  {
   if(!rle.fname)
    break;

   if(rle.space == SPACE_ALIEN)
    continue;
   //
   std::unique_ptr<Stream> ns;
   Stream* s;

   if(fname == rle.fname)
    s = gf->stream;
   else
   {
    ns.reset(gf->vfs->open(gf->dir + gf->vfs->get_preferred_path_separator() + rle.fname, VirtualFS::MODE_READ));
    s = ns.get();
   }

   assert(rle.space == SPACE_PROGRAM || rle.space == SPACE_SAMPLES);
   //
   const size_t size = rle.size;
   size_t offset = rle.offset;
   uint8* t;

   if(rle.space == SPACE_PROGRAM)
   {
    assert(size <= 0x80000);

    t = (uint8*)ProgramROM.get();
   }
   else
   {
    offset &= SamplesROMBankMask;
    //
    assert(size <= (SamplesROMBankMask + 1));
    assert(offset <= (SamplesROMBankMask + 1 - size));
    //
    t = (uint8*)SamplesROM.get() + offset;
   }
   s->read(t, size);
   Endian_A16_NE_LE(t, size / sizeof(uint16));
  }
  //
  //
  //
  std::vector<std::string> SongNames;

  Game = sgi;
  NumSongs = sgi->num_songs;
  Songs = sgi->songs;

  if(Songs)
  {
   for(size_t i = 0; i < NumSongs; i++)
    SongNames.push_back(Songs[i].name ? Songs[i].name : "");
  }

  MDFNGameInfo->name = sgi->name;

  Player_Init(NumSongs, sgi->name, sgi->artist, sgi->copyright, SongNames, false);
  SOUND_Init(sgi->system == SYSTEM_MODEL3);

  MDFNGameInfo->fps = 75 * 65536 * 256;
  MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(44100 * 256);

  //
  // Reset
  //
  SOUND_Reset(true);
  SoundCPU.SetExtHalted(false);

  ProgramROMPtr = (uintptr_t)ProgramROM.get() - 0x600000;
  Control = 0;
  RecalcSamplesROMBankPtr();
  //
  //
  for(unsigned i = 0; i < 4; i++)
   SCSP[0].GetRAMPtr()[i] = ProgramROM[i];
  //
  //
  //
  CurrentSong = 0;
  //
  // Run for 4 seconds emulated time, then save state for later use.
  //
  for(unsigned i = 0; i < 75 * 4; i++)
  {
   const int32 target_timestamp = 588 * 512;
   SOUND_StartFrame(0, 0);
   SOUND_Update(target_timestamp);
   SOUND_FlushOutput(nullptr, 0, false);
   SOUND_AdjustTS(-target_timestamp);
  }
  //
  std::unique_ptr<MemoryStream> ss(new MemoryStream(2048 * 1024, false));
  MDFNSS_SaveInternal(ss.get(), StateAction);

  InitSaveState = std::move(ss);
  //
  StartSong();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static MDFN_COLD void CloseGame(void)
{
 Cleanup();
}

static MDFN_COLD void SetInput(unsigned port, const char *type, uint8* ptr)
{
 controller_ptr = ptr;
}

static MDFN_COLD void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER:
  case MDFN_MSC_RESET:
	Reset();
	StartSong();
	break;
 }
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(Control),

  SFVAR(CurrentSong),
  SFVAR(prev_cstate),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SONG");

 if(load)
 {
  CurrentSong %= NumSongs;
 }

 SOUND_StateAction(sm, load, data_only);
}


static const FileExtensionSpecStruct KnownExtensions[] =
{
 { "epr-18824a.30", -80, "ROM" }, // Manx TT Superbike
 { ".21", -81, "ROM" },
 { ".31", -82, "ROM" },
 { ".30", -83, "ROM" },
 { ".sd0", -84, "ROM" },

 { NULL, 0, NULL }
};


static const MDFNSetting SASPlaySettings[] =
{
 { "sasplay.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("SCSP output resampler quality."),
	gettext_noop("0 is lowest quality and CPU usage, 10 is highest quality and CPU usage.  The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using.  Changing Mednafen's output rate, via the \"\5sound.rate\" setting, to \"44100\" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors."), MDFNST_UINT, "5", "0", "10" },

 { NULL },
};


static const IDIISG IDII =
{
 IDIIS_Button("restart", "Restart Song", 5, NULL),

 IDIIS_Button("next_song", "Next Song", 2, NULL),
 IDIIS_Button("previous_song", "Previous Song", 1, NULL),

 IDIIS_Button("next_song_10", "Next Song 10", 4, NULL),
 IDIIS_Button("previous_song_10", "Previous Song 10", 3, NULL),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "controller",
  "Controller",
  NULL,
  IDII,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "builtin", "Built-In", InputDeviceInfo }
};

}

using namespace MDFN_IEN_SASPLAY;

MDFN_HIDE extern const MDFNGI EmulatedSASPlay =
{
 "sasplay",
 "Sega Arcade SCSP Sound Player",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 PortInfo,
 NULL,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 NULL,
 "\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 SASPlaySettings,
 0,
 0,

 EVFSUPPORT_RGB555 | EVFSUPPORT_RGB565,

 false, // Multires possible?

 480,	// lcm_width
 300,	// lcm_height
 NULL,  // Dummy

 480,   // Nominal width
 300,   // Nominal height

 480,   // Framebuffer width
 300,   // Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels
};

