/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* smpc.cpp - SMPC Emulation
**  Copyright (C) 2015-2017 Mednafen Team
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
  TODO:
	CD On/Off
*/

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/Stream.h>
#include <mednafen/Time.h>
#include <mednafen/cdrom/CDUtility.h>
using namespace CDUtility;

#include "smpc.h"
#include "smpc_iodevice.h"
#include "sound.h"
#include "vdp1.h"
#include "vdp2.h"
#include "cdb.h"
#include "scu.h"

#include "input/gamepad.h"
#include "input/3dpad.h"
#include "input/mouse.h"
#include "input/wheel.h"
#include "input/mission.h"
#include "input/gun.h"
#include "input/keyboard.h"
#include "input/jpkeyboard.h"

#include "input/multitap.h"

namespace MDFN_IEN_SS
{
#include "sh7095.h"

enum
{
 CLOCK_DIVISOR_26M = 65,
 CLOCK_DIVISOR_28M = 61
};

enum
{
 CMD_MSHON = 0x00,
 CMD_SSHON = 0x02,
 CMD_SSHOFF = 0x03,

 CMD_SNDON = 0x06,
 CMD_SNDOFF = 0x07,

 CMD_CDON = 0x08,
 CMD_CDOFF = 0x09,

 // A, B, C do something...

 CMD_SYSRES = 0x0D,

 CMD_CKCHG352 = 0x0E,
 CMD_CKCHG320 = 0x0F,

 CMD_INTBACK = 0x10,
 CMD_SETTIME = 0x16,
 CMD_SETSMEM = 0x17,

 CMD_NMIREQ = 0x18,
 CMD_RESENAB = 0x19,
 CMD_RESDISA = 0x1A
};

static uint8 AreaCode;
static int32 MasterClock;

static struct
{
 uint64 ClockAccum;

 bool Valid;

 union
 {
  uint8 raw[7];
  struct
  {
   uint8 year[2];		// BCD; [0] = xx00, [1] = 00xx
   uint8 wday_mon;	// 0x0-0x6(upper; 6=Saturday), 0x1-0xC(lower)
   uint8 mday;		// BCD; 0x01-0x31
   uint8 hour;		// BCD; 0x00-0x23
   uint8 minute;		// BCD; 0x00-0x59
   uint8 second;		// BCD; 0x00-0x59
  };
 };
} RTC;

static uint8 SaveMem[4];

static uint8 IREG[7];
static uint8 OREG[0x20];
static uint8 SR;
static bool SF;

enum
{
 PMODE_15BYTE = 0,
 PMODE_255BYTE = 1,
 PMODE_ILL = 2,
 PMODE_0BYTE = 3
};

enum
{
 SR_RESB = 0x10,
 SR_NPE = 0x20,
 SR_PDL = 0x40,
};

static bool ResetNMIEnable;

static bool ResetButtonPhysStatus;
static int32 ResetButtonCount;
static bool ResetPending;
static int32 PendingCommand;
static int32 ExecutingCommand;
static int32 PendingClockDivisor;
static int32 CurrentClockDivisor;

static bool PendingVB;

static int32 SubPhase;
static int64 ClockCounter;
static uint32 SMPC_ClockRatio;

static bool SoundCPUOn;
static bool SlaveSH2On;
static bool CDOn;

static uint8 BusBuffer;
//
//
static struct
{
 int64 TimeCounter;
 int32 StartTime;
 int32 OptWaitUntilTime;
 int32 OptEatTime;

 int32 OptReadTime;

 uint8 Mode[2];
 bool TimeOptEn;
 bool NextContBit;

 uint8 CurPort;
 uint8 ID1;
 uint8 ID2;
 uint8 IDTap;

 uint8 CommMode;

 uint8 OWP;

 uint8 work[8];
 //
 //
 uint8 TapCounter;
 uint8 TapCount;
 uint8 ReadCounter;
 uint8 ReadCount;
 uint8 ReadBuffer[256];	// Maybe should only be 255, but +1 for save state sanitization simplification.
 uint8 WriteCounter;
 uint8 PDCounter;
} JRS;
//
//
static bool vb;
static bool vsync;
static sscpu_timestamp_t lastts;
//
//
static uint8 DataOut[2][2];
static uint8 DataDir[2][2];
static bool DirectModeEn[2];
static bool ExLatchEn[2];

static uint8 IOBusState[2];
static IODevice* IOPorts[2];

static struct
{
 IODevice none;
 IODevice_Gamepad gamepad;
 IODevice_3DPad threedpad;
 IODevice_Mouse mouse;
 IODevice_Wheel wheel;
 IODevice_Mission mission{false};
 IODevice_Mission dualmission{true};
 IODevice_Gun gun;
 IODevice_Keyboard keyboard;
 IODevice_JPKeyboard jpkeyboard;
} PossibleDevices[12];

static IODevice_Multitap PossibleMultitaps[2];

static IODevice_Multitap* SPorts[2];
static IODevice* VirtualPorts[12];
static uint8* VirtualPortsDPtr[12];
static uint8* MiscInputPtr;

IODevice::IODevice() { }
IODevice::~IODevice() { }
void IODevice::Power(void) { }
void IODevice::TransformInput(uint8* const data, float gun_x_scale, float gun_x_offs) const { }
void IODevice::UpdateInput(const uint8* data, const int32 time_elapsed) { }
void IODevice::UpdateOutput(uint8* data) { }
void IODevice::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) { }
void IODevice::Draw(MDFN_Surface* surface, const MDFN_Rect& drect, const int32* lw, int ifield, float gun_x_scale, float gun_x_offs) const { }
uint8 IODevice::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted) { return smpc_out; }

void IODevice::ResetTS(void) { if(NextEventTS < SS_EVENT_DISABLED_TS) { NextEventTS -= LastTS; assert(NextEventTS >= 0); } LastTS = 0; }
void IODevice::LineHook(const sscpu_timestamp_t timestamp, int32 out_line, int32 div, int32 coord_adj) { }
//
//

static void UpdateIOBus(unsigned port, const sscpu_timestamp_t timestamp)
{
 IOBusState[port] = IOPorts[port]->UpdateBus(timestamp, (DataOut[port][DirectModeEn[port]] | ~DataDir[port][DirectModeEn[port]]) & 0x7F, DataDir[port][DirectModeEn[port]]);
 assert(!(IOBusState[port] & 0x80));

 {
  bool tmp = (!(IOBusState[0] & 0x40) & ExLatchEn[0]) | (!(IOBusState[1] & 0x40) & ExLatchEn[1]);

  SCU_SetInt(SCU_INT_PAD, tmp);
  VDP2::SetExtLatch(timestamp, tmp);
 }
}

static void MapPorts(void)
{
 for(unsigned sp = 0, vp = 0; sp < 2; sp++)
 {
  IODevice* nd;

  if(SPorts[sp])
  {
   for(unsigned i = 0; i < 6; i++)
   {
    IODevice* const tsd = VirtualPorts[vp++];

    if(SPorts[sp]->GetSubDevice(i) != tsd)
     tsd->Power();

    SPorts[sp]->SetSubDevice(i, tsd);
   }

   nd = SPorts[sp];
  }
  else
   nd = VirtualPorts[vp++];

  if(IOPorts[sp] != nd)
   nd->Power();

  IOPorts[sp] = nd;
 }
}

void SMPC_SetMultitap(unsigned sport, bool enabled)
{
 assert(sport < 2);

 SPorts[sport] = (enabled ? &PossibleMultitaps[sport] : nullptr);
 MapPorts();
}

void SMPC_SetCrosshairsColor(unsigned port, uint32 color)
{
 assert(port < 12);

 PossibleDevices[port].gun.SetCrosshairsColor(color);
}

void SMPC_SetInput(unsigned port, const char* type, uint8* ptr)
{
 assert(port < 13);

 if(port == 12) 
 {
  MiscInputPtr = ptr;
  return;
 }
 //
 //
 //
 IODevice* nd = nullptr;

 if(!strcmp(type, "none"))
  nd = &PossibleDevices[port].none;
 else if(!strcmp(type, "gamepad"))
  nd = &PossibleDevices[port].gamepad;
 else if(!strcmp(type, "3dpad"))
  nd = &PossibleDevices[port].threedpad;
 else if(!strcmp(type, "mouse"))
  nd = &PossibleDevices[port].mouse;
 else if(!strcmp(type, "wheel"))
  nd = &PossibleDevices[port].wheel;
 else if(!strcmp(type, "mission") || !strcmp(type, "missionwoa"))
  nd = &PossibleDevices[port].mission;
 else if(!strcmp(type, "dmission") || !strcmp(type, "dmissionwoa"))
  nd = &PossibleDevices[port].dualmission;
 else if(!strcmp(type, "gun"))
  nd = &PossibleDevices[port].gun;
 else if(!strcmp(type, "keyboard"))
  nd = &PossibleDevices[port].keyboard;
 else if(!strcmp(type, "jpkeyboard"))
  nd = &PossibleDevices[port].jpkeyboard;
 else
  abort();

 VirtualPorts[port] = nd;
 VirtualPortsDPtr[port] = ptr;

 MapPorts();
}

#if 0
static void RTC_Reset(void)
{


}
#endif

void SMPC_LoadNV(Stream* s)
{
 RTC.Valid = s->get_u8();
 s->read(RTC.raw, sizeof(RTC.raw));
 s->read(SaveMem, sizeof(SaveMem));
}

void SMPC_SaveNV(Stream* s)
{
 s->put_u8(RTC.Valid);
 s->write(RTC.raw, sizeof(RTC.raw));
 s->write(SaveMem, sizeof(SaveMem));
}

void SMPC_SetRTC(const struct tm* ht, const uint8 lang)
{
 if(!ht)
 {
  RTC.Valid = false;
  RTC.year[0] = 0x19;
  RTC.year[1] = 0x93;
  RTC.wday_mon = 0x5C;
  RTC.mday = 0x31;
  RTC.hour = 0x23;
  RTC.minute = 0x59;
  RTC.second = 0x59;

  for(unsigned i = 0; i < 4; i++)
   SaveMem[i] = 0x00;
 }
 else
 {
  int year_adj = ht->tm_year;
  //if(year_adj >= 100)
  // year_adj = 100 + ((year_adj - 100) % 28);

  RTC.Valid = true; //false;
  RTC.year[0] = U8_to_BCD(19 + year_adj / 100);
  RTC.year[1] = U8_to_BCD(year_adj % 100);
  RTC.wday_mon = (std::min<unsigned>(6, ht->tm_wday) << 4) | ((std::min<unsigned>(11, ht->tm_mon) + 1) << 0);
  RTC.mday = U8_to_BCD(std::min<unsigned>(31, ht->tm_mday));
  RTC.hour = U8_to_BCD(std::min<unsigned>(23, ht->tm_hour));
  RTC.minute = U8_to_BCD(std::min<unsigned>(59, ht->tm_min));
  RTC.second = U8_to_BCD(std::min<unsigned>(59, ht->tm_sec));

  //if((SaveMem[3] & 0x0F) <= 0x05 || (SaveMem[3] & 0x0F) == 0xF)
  SaveMem[3] = (SaveMem[3] & 0xF0) | lang;
 }
}

void SMPC_Init(const uint8 area_code_arg, const int32 master_clock_arg)
{
 AreaCode = area_code_arg;
 MasterClock = master_clock_arg;

 ResetPending = false;
 vb = false;
 vsync = false;
 lastts = 0;

 for(unsigned sp = 0; sp < 2; sp++)
  SPorts[sp] = nullptr;

 for(unsigned i = 0; i < 12; i++)
 {
  VirtualPorts[i] = nullptr;
  SMPC_SetInput(i, "none", NULL);
 }

 SMPC_SetRTC(NULL, 0);
}

bool SMPC_IsSlaveOn(void)
{
 return SlaveSH2On;
}

static void SlaveOn(void)
{
 SlaveSH2On = true;
 CPU[1].AdjustTS(SH7095_mem_timestamp, true);
 CPU[1].Reset(true);
 SS_SetEventNT(&events[SS_EVENT_SH2_S_DMA], SH7095_mem_timestamp + 1);
}

static void SlaveOff(void)
{
 SlaveSH2On = false;
 CPU[1].Reset(true);
 CPU[1].AdjustTS(0x7FFFFFFF, true);
 SS_SetEventNT(&events[SS_EVENT_SH2_S_DMA], SS_EVENT_DISABLED_TS);
}

static void TurnSoundCPUOn(void)
{
 SOUND_Reset68K();
 SoundCPUOn = true;
 SOUND_Set68KActive(true);
}

static void TurnSoundCPUOff(void)
{
 SOUND_Reset68K();
 SoundCPUOn = false;
 SOUND_Set68KActive(false);
}

void SMPC_Reset(bool powering_up)
{
 SlaveOff();
 TurnSoundCPUOff();
 CDOn = true; // ? false;

 ResetButtonCount = 0;
 ResetNMIEnable = false;	// or only on powering_up?

 CPU[0].SetNMI(true);

 memset(IREG, 0, sizeof(IREG));
 memset(OREG, 0, sizeof(OREG));
 PendingCommand = -1;
 ExecutingCommand = -1;
 SF = 0;

 BusBuffer = 0x00;

 for(unsigned port = 0; port < 2; port++)
 {
  for(unsigned sel = 0; sel < 2; sel++)
  {
   DataOut[port][sel] = 0;
   DataDir[port][sel] = 0;
  }
  DirectModeEn[port] = false;
  ExLatchEn[port] = false;
  UpdateIOBus(port, SH7095_mem_timestamp);
 }

 ResetPending = false;

 PendingClockDivisor = 0;
 CurrentClockDivisor = CLOCK_DIVISOR_26M;

 SubPhase = 0;
 PendingVB = false;
 ClockCounter = 0;
 //
 memset(&JRS, 0, sizeof(JRS));
}

void SMPC_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(RTC.ClockAccum),
  SFVAR(RTC.Valid),
  SFVAR(RTC.raw),

  SFVAR(SaveMem),

  SFVAR(IREG),
  SFVAR(OREG),
  SFVAR(SR),
  SFVAR(SF),

  SFVAR(ResetNMIEnable),
  SFVAR(ResetButtonPhysStatus),
  SFVAR(ResetButtonCount),
  SFVAR(ResetPending),
  SFVAR(PendingCommand),
  SFVAR(ExecutingCommand),
  SFVAR(PendingClockDivisor),
  SFVAR(CurrentClockDivisor),

  SFVAR(PendingVB),

  SFVAR(SubPhase),
  SFVAR(ClockCounter),
  SFVAR(SMPC_ClockRatio),

  SFVAR(SoundCPUOn),
  SFVAR(SlaveSH2On),
  SFVAR(CDOn),

  SFVAR(BusBuffer),

  SFVAR(JRS.TimeCounter),
  SFVAR(JRS.StartTime),
  SFVAR(JRS.OptWaitUntilTime),
  SFVAR(JRS.OptEatTime),
  SFVAR(JRS.OptReadTime),

  SFVAR(JRS.Mode),
  SFVAR(JRS.TimeOptEn),
  SFVAR(JRS.NextContBit),

  SFVAR(JRS.CurPort),
  SFVAR(JRS.ID1),
  SFVAR(JRS.ID2),
  SFVAR(JRS.IDTap),

  SFVAR(JRS.CommMode),

  SFVAR(JRS.OWP),

  SFVAR(JRS.work),

  SFVAR(JRS.TapCounter),
  SFVAR(JRS.TapCount),
  SFVAR(JRS.ReadCounter),
  SFVAR(JRS.ReadCount),
  SFVAR(JRS.ReadBuffer),
  SFVAR(JRS.WriteCounter),
  SFVAR(JRS.PDCounter),

  SFVARN(DataOut, "&DataOut[0][0]"),
  SFVARN(DataDir, "&DataDir[0][0]"),
  SFVAR(DirectModeEn),
  SFVAR(ExLatchEn),

  SFVAR(IOBusState),

  SFVAR(vb),
  SFVAR(vsync),

  SFVAR(lastts),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SMPC");

 for(unsigned port = 0; port < 2; port++)
 {
  const char snp[] = { 'S', 'M', 'P', 'C', '_', 'P', (char)('0' + port), 0 };

  IOPorts[port]->StateAction(sm, load, data_only, snp);
 }

 if(load)
 {
  JRS.CurPort &= 0x1;
  JRS.OWP &= 0x3F;
 }
}

void SMPC_TransformInput(void)
{
 float gun_x_scale, gun_x_offs;

 VDP2::GetGunXTranslation(((PendingClockDivisor > 0) ? PendingClockDivisor : CurrentClockDivisor) == CLOCK_DIVISOR_28M, &gun_x_scale, &gun_x_offs);

 for(unsigned vp = 0; vp < 12; vp++)
  VirtualPorts[vp]->TransformInput(VirtualPortsDPtr[vp], gun_x_scale, gun_x_offs);
}

int32 SMPC_StartFrame(EmulateSpecStruct* espec)
{
 if(ResetPending)
  SS_Reset(false);

 if(PendingClockDivisor > 0)
 {
  CurrentClockDivisor = PendingClockDivisor;
  PendingClockDivisor = 0;
 }

 if(!SlaveSH2On)
  CPU[1].AdjustTS(0x7FFFFFFF, true);

 SMPC_ClockRatio = (1ULL << 32) * 4000000 * CurrentClockDivisor / MasterClock;
 SOUND_SetClockRatio((1ULL << 32) * 11289600 * CurrentClockDivisor / MasterClock);
 CDB_SetClockRatio((1ULL << 32) * 11289600 * CurrentClockDivisor / MasterClock);

 return CurrentClockDivisor;
}

void SMPC_EndFrame(EmulateSpecStruct* espec, const sscpu_timestamp_t timestamp)
{
 for(unsigned i = 0; i < 2; i++)
 {
  if(SPorts[i])
   SPorts[i]->ForceSubUpdate(timestamp);
 }

 if(!espec->skip)
 {
  float gun_x_scale, gun_x_offs;

  VDP2::GetGunXTranslation(CurrentClockDivisor == CLOCK_DIVISOR_28M, &gun_x_scale, &gun_x_offs);

  for(unsigned i = 0; i < 2; i++)
  {
   IOPorts[i]->Draw(espec->surface, espec->DisplayRect, espec->LineWidths, espec->InterlaceOn ? espec->InterlaceField : -1, gun_x_scale, gun_x_offs);
  }
 }
}

void SMPC_UpdateOutput(void)
{
 for(unsigned vp = 0; vp < 12; vp++)
 {
  VirtualPorts[vp]->UpdateOutput(VirtualPortsDPtr[vp]);
 }
}

void SMPC_UpdateInput(const int32 time_elapsed)
{
 //printf("%8d\n", time_elapsed);

 ResetButtonPhysStatus = (bool)(*MiscInputPtr & 0x1);
 for(unsigned vp = 0; vp < 12; vp++)
 {
  VirtualPorts[vp]->UpdateInput(VirtualPortsDPtr[vp], time_elapsed);
 }
}


void SMPC_Write(const sscpu_timestamp_t timestamp, uint8 A, uint8 V)
{
 BusBuffer = V;
 A &= 0x3F;

 SS_DBGTI(SS_DBG_SMPC_REGW, "[SMPC] Write to 0x%02x:0x%02x", A, V);

 //
 // Call VDP2::Update() to prevent out-of-temporal-order calls to SMPC_Update() from here and the event system.
 //
 SS_SetEventNT(&events[SS_EVENT_VDP2], VDP2::Update(timestamp));	// TODO: conditionalize so we don't consume so much CPU time if a game writes continuously to SMPC ports
 sscpu_timestamp_t nt = SMPC_Update(timestamp);
 switch(A)
 {
  case 0x00:
  case 0x01:
  case 0x02:
  case 0x03:
  case 0x04:
  case 0x05:
  case 0x06:
	if(MDFN_UNLIKELY(ExecutingCommand >= 0))
	{
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Input register %u port written with 0x%02x while command 0x%02x is executing.", A, V, ExecutingCommand);
	}

	IREG[A] = V;
	break;

  case 0x0F:
	if(MDFN_UNLIKELY(ExecutingCommand >= 0))
	{
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Command port written with 0x%02x while command 0x%02x is still executing.", V, ExecutingCommand);
	}

	if(MDFN_UNLIKELY(PendingCommand >= 0))
	{
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Command port written with 0x%02x while command 0x%02x is still pending.", V, PendingCommand);
	}

	PendingCommand = V;
	break;

  case 0x31:
	if(MDFN_UNLIKELY(SF))
	{
	 SS_DBGTI(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] SF port written while SF is 1.");
	}

	SF = true;
	break;

  //
  //
  //
  case 0x3A:
	DataOut[0][1] = V & 0x7F;
	UpdateIOBus(0, SH7095_mem_timestamp);
	break;

  case 0x3B:
	DataOut[1][1] = V & 0x7F;
	UpdateIOBus(1, SH7095_mem_timestamp);
	break;

  case 0x3C:
	DataDir[0][1] = V & 0x7F;
	UpdateIOBus(0, SH7095_mem_timestamp);
	break;

  case 0x3D:
	DataDir[1][1] = V & 0x7F;
	UpdateIOBus(1, SH7095_mem_timestamp);
	break;

  case 0x3E:
	DirectModeEn[0] = (bool)(V & 0x1);
	UpdateIOBus(0, SH7095_mem_timestamp);

	DirectModeEn[1] = (bool)(V & 0x2);
	UpdateIOBus(1, SH7095_mem_timestamp);
	break;

  case 0x3F:
	ExLatchEn[0] = (bool)(V & 0x1);
	UpdateIOBus(0, SH7095_mem_timestamp);

	ExLatchEn[1] = (bool)(V & 0x2);
	UpdateIOBus(1, SH7095_mem_timestamp);
	break;

  default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Unknown write of 0x%02x to 0x%02x\n", V, A);
	break;

 }

 if(PendingCommand >= 0)
  nt = timestamp + 1;

 nt = std::min<sscpu_timestamp_t>(nt, std::min<sscpu_timestamp_t>(IOPorts[0]->NextEventTS, IOPorts[1]->NextEventTS));

 SS_SetEventNT(&events[SS_EVENT_SMPC], nt);
}

uint8 SMPC_Read(const sscpu_timestamp_t timestamp, uint8 A)
{
 uint8 ret = BusBuffer;

 A &= 0x3F;

 switch(A)
 {
  default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Unknown read from 0x%02x\n", A);
	break;

  case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17:
  case 0x18: case 0x19: case 0x1A: case 0x1B: case 0x1C: case 0x1D: case 0x1E: case 0x1F:
  case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27:
  case 0x28: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D: case 0x2E: case 0x2F:
	if(MDFN_UNLIKELY(ExecutingCommand >= 0))
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] Output register %u port read while command 0x%02x is executing.\n", A - 0x10, ExecutingCommand);
	}

	ret = OREG[(size_t)A - 0x10];
	break;

  case 0x30:
	if(MDFN_UNLIKELY(ExecutingCommand >= 0))
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] SR port read while command 0x%02x is executing.\n", ExecutingCommand);
	}

	ret = SR;
	break;
 
  case 0x31:
	ret &= ~0x01;
	ret |= SF;
	break;

  case 0x3A:
	ret = (ret & 0x80) | IOBusState[0];
	break;

  case 0x3B:
	ret = (ret & 0x80) | IOBusState[1];
	break;

 }

 return ret;
}

void SMPC_ResetTS(void)
{
 for(unsigned p = 0; p < 2; p++)
  IOPorts[p]->ResetTS();

 lastts = 0;
}

#define SMPC_WAIT_UNTIL_COND(cond)  {					\
			    case __COUNTER__:				\
			    ClockCounter = 0; /* before if(), not after, otherwise the variable will overflow eventually. */	\
			    if(!(cond))					\
			    {						\
			     SubPhase = __COUNTER__ - SubPhaseBias - 1;	\
			     next_event_ts = timestamp + 1000;		\
			     goto Breakout;				\
			    }						\
			   }

#define SMPC_WAIT_UNTIL_COND_TIMEOUT(cond, n)							\
		{										\
		 ClockCounter -= (int64)(n) << 32;						\
		 case __COUNTER__:								\
		 if(!(cond) && ClockCounter < 0)						\
		 {										\
		  SubPhase = __COUNTER__ - SubPhaseBias - 1;					\
		  next_event_ts = timestamp + (-ClockCounter + SMPC_ClockRatio - 1) / SMPC_ClockRatio;		\
		  goto Breakout;								\
		 }										\
		 ClockCounter = 0;								\
		}

#define SMPC_EAT_CLOCKS(n)									\
		{										\
		 ClockCounter -= (int64)(n) << 32;						\
		 case __COUNTER__:								\
		 if(ClockCounter < 0)								\
		 {										\
		  SubPhase = __COUNTER__ - SubPhaseBias - 1;					\
		  next_event_ts = timestamp + (-ClockCounter + SMPC_ClockRatio - 1) / SMPC_ClockRatio;		\
		  goto Breakout;								\
		 }										\
		 /*printf("%f\n", (double)ClockCounter / (1LL << 32));*/			\
		}										\


static unsigned RTC_BCDInc(uint8 v)
{
 unsigned tmp = v & 0xF;

 tmp++;

 if(tmp >= 0xA)
  tmp += 0x06;

 tmp += v & 0xF0;

 if(tmp >= 0xA0)
  tmp += 0x60;

 return tmp;
}

static void RTC_IncTime(void)
{
 // Seconds
 if(RTC.second == 0x59)
 {
  RTC.second = 0x00;

  // Minutes
  if(RTC.minute == 0x59)
  {
   RTC.minute = 0x00;

   // Hours
   if(RTC.hour == 0x23)
   {
    RTC.hour = 0x00;

    // Day of week
    if(RTC.wday_mon >= 0x60)
     RTC.wday_mon &= 0x0F;
    else
     RTC.wday_mon += 0x10;

    //					
    static const uint8 mdtab[0x10] = { 
    //         Jan,  Feb,  Mar,  Apr,   May, June, July,  Aug, Sept, Oct,  Nov,  Dec
	0x10, 0x31, 0x28, 0x31, 0x30, 0x31, 0x30, 0x31, 0x31, 0x30, 0x31, 0x30, 0x31, 0xC1, 0xF5, 0xFF
    };
    const uint8 day_compare = mdtab[RTC.wday_mon & 0x0F] + ((RTC.wday_mon & 0x0F) == 0x02 && ((RTC.year[1] & 0x1F) < 0x1A) && !((RTC.year[1] + ((RTC.year[1] & 0x10) >> 3)) & 0x3));

    // Day of month
    if(RTC.mday >= day_compare)
    {
     RTC.mday = 0x01;

     // Month of year
     if((RTC.wday_mon & 0x0F) == 0x0C)
     {
      RTC.wday_mon &= 0xF0;
      RTC.wday_mon |= 0x01;

      // Year
      unsigned tmp = RTC_BCDInc(RTC.year[1]);
      RTC.year[1] = tmp;

      if(tmp >= 0x100)
       RTC.year[0] = RTC_BCDInc(RTC.year[0]);
     }
     else
      RTC.wday_mon++;
    }
    else
     RTC.mday = RTC_BCDInc(RTC.mday);
   }
   else
    RTC.hour = RTC_BCDInc(RTC.hour);
  }
  else
   RTC.minute = RTC_BCDInc(RTC.minute);
 }
 else
  RTC.second = RTC_BCDInc(RTC.second);
}

enum : int { SubPhaseBias = __COUNTER__ + 1 };
sscpu_timestamp_t SMPC_Update(sscpu_timestamp_t timestamp)
{
 int64 clocks;

 if(MDFN_UNLIKELY(timestamp < lastts))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SMPC, "[SMPC] [BUG] timestamp(%d) < lastts(%d)\n", timestamp, lastts);
  clocks = 0;
 }
 else
 {
  clocks = (int64)(timestamp - lastts) * SMPC_ClockRatio;
  lastts = timestamp;
 }

 ClockCounter += clocks;
 RTC.ClockAccum += clocks;
 JRS.TimeCounter += clocks;

 UpdateIOBus(0, timestamp);
 UpdateIOBus(1, timestamp);

 //
 sscpu_timestamp_t next_event_ts;

 switch(SubPhase + SubPhaseBias)
 {
  for(;;)
  {
   default:
   case __COUNTER__:

   SMPC_WAIT_UNTIL_COND(PendingCommand >= 0 || PendingVB);

   if(PendingVB && PendingCommand < 0)
   {
    PendingVB = false;

    if(JRS.OptReadTime)
     JRS.OptWaitUntilTime = std::max<int32>(0, (JRS.TimeCounter >> 32) - JRS.OptReadTime - 5000);
    else
     JRS.OptWaitUntilTime = 0;
    JRS.TimeCounter = 0;
    SMPC_EAT_CLOCKS(234);

    SR &= ~SR_RESB;
    if(ResetButtonPhysStatus)	// FIXME: Semantics may not be right in regards to CMD_RESENAB timing.
    {
     SR |= SR_RESB;
     if(ResetButtonCount >= 0)
     {
      ResetButtonCount++;
 
      if(ResetButtonCount >= 3)
      {
       ResetButtonCount = 3;

       if(ResetNMIEnable)
       {
        CPU[0].SetNMI(false);
        CPU[0].SetNMI(true);

        ResetButtonCount = -1;
       }
      }
     }
    }
    else
     ResetButtonCount = 0;

    //
    // Do RTC increment here
    // 
    while(MDFN_UNLIKELY(RTC.ClockAccum >= (4000000ULL << 32)))
    {
     RTC_IncTime();
     RTC.ClockAccum -= (4000000ULL << 32);
    }

    continue;
   }

   ExecutingCommand = PendingCommand;
   PendingCommand = -1;

   SMPC_EAT_CLOCKS(92);
   if(ExecutingCommand < 0x20)
   {
    OREG[0x1F] = ExecutingCommand;

    SS_DBGTI(SS_DBG_SMPC, "[SMPC] Command 0x%02x --- 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", ExecutingCommand, IREG[0], IREG[1], IREG[2], IREG[3], IREG[4], IREG[5], IREG[6]);

    if(ExecutingCommand == CMD_MSHON)
    {

    }
    else if(ExecutingCommand == CMD_SSHON)
    {
     if(!SlaveSH2On)
      SlaveOn();
    }
    else if(ExecutingCommand == CMD_SSHOFF)
    {
     if(SlaveSH2On)
      SlaveOff();
    }
    else if(ExecutingCommand == CMD_SNDON)
    {
     if(!SoundCPUOn)
      TurnSoundCPUOn();
    }
    else if(ExecutingCommand == CMD_SNDOFF)
    {
     if(SoundCPUOn)
      TurnSoundCPUOff();
    }
    else if(ExecutingCommand == CMD_CDON)
    {
     CDOn = true;
    }
    else if(ExecutingCommand == CMD_CDOFF)
    {
     CDOn = false;
    }
    else if(ExecutingCommand == CMD_SYSRES)
    {
     ResetPending = true;
     SMPC_WAIT_UNTIL_COND(!ResetPending);

     // TODO/FIXME(unreachable currently?):
    }
    else if(ExecutingCommand == CMD_CKCHG352 || ExecutingCommand == CMD_CKCHG320)
    {
     // Devour some time

     if(SlaveSH2On)
      SlaveOff();
 
     if(SoundCPUOn)
      TurnSoundCPUOff();

     SOUND_Reset(false);
     VDP1::Reset(false);
     VDP2::Reset(false);
     SCU_Reset(false);

     // Change clock
     PendingClockDivisor = (ExecutingCommand == CMD_CKCHG352) ? CLOCK_DIVISOR_28M : CLOCK_DIVISOR_26M;

     // Wait for a few vblanks
     SMPC_WAIT_UNTIL_COND(!vb);
     SMPC_WAIT_UNTIL_COND(vb);
     SMPC_WAIT_UNTIL_COND(!vb);
     SMPC_WAIT_UNTIL_COND(vb);
     SMPC_WAIT_UNTIL_COND(!PendingClockDivisor);
     SMPC_WAIT_UNTIL_COND(!vb);
     SMPC_WAIT_UNTIL_COND(vb);
     SMPC_WAIT_UNTIL_COND(vsync);

     // Send NMI to master SH-2
     CPU[0].SetNMI(false);
     CPU[0].SetNMI(true);
    }
    else if(ExecutingCommand == CMD_INTBACK)
    {
     //SS_DBGTI(SS_DBG_SMPC, "[SMPC] INTBACK IREG0=0x%02x, IREG1=0x%02x, IREG2=0x%02x, %d", IREG[0], IREG[1], IREG[2], vb);

     SR &= ~SR_NPE;
     if(IREG[0] & 0xF)
     {
      SMPC_EAT_CLOCKS(952);

      OREG[0] = (RTC.Valid << 7) | (!ResetNMIEnable << 6);

      for(unsigned i = 0; i < 7; i++)
       OREG[1 + i] = RTC.raw[i];

      OREG[0x8] = 0; // TODO FIXME: Cartridge code?
      OREG[0x9] = AreaCode;
      OREG[0xA] = 0x24 | 
		 ((CurrentClockDivisor == CLOCK_DIVISOR_28M) << 6) |
		 (SlaveSH2On << 4) | 
		 (true << 3) | 	// TODO?: Master NMI
		 (true << 1) |	// TODO?: sysres
		 (SoundCPUOn << 0);	// sndres

      OREG[0xB] = (CDOn << 6) | (1 << 1);	// cdres, TODO?: bit1

      for(unsigned i = 0; i < 4; i++)
       OREG[0xC + i] = SaveMem[i];

      if(IREG[1] & 0x8)
       SR |= SR_NPE;

      SR &= ~0x80;
      SR |= 0x0F;

      SCU_SetInt(SCU_INT_SMPC, true);
      SCU_SetInt(SCU_INT_SMPC, false);
     }

     // Wait for !vb, wait until (IREG[0] & 0x80), time-optimization wait.

     if(IREG[1] & 0x8)
     {
      #define JR_WAIT(cond)	{ SMPC_WAIT_UNTIL_COND((cond) || PendingVB); if(PendingVB) { SS_DBGTI(SS_DBG_SMPC, "[SMPC] abortjr wait"); goto AbortJR; } }
      #define JR_EAT(n)		{ SMPC_EAT_CLOCKS(n); if(PendingVB) { SS_DBGTI(SS_DBG_SMPC, "[SMPC] abortjr eat"); goto AbortJR; } }
      #define JR_WRNYB(val)															\
	{																	\
	 if(!JRS.OWP)																\
	 {																	\
	  if(JRS.PDCounter > 0)															\
	  {																	\
	   SR = (SR & ~SR_PDL) | ((JRS.PDCounter < 0x2) ? SR_PDL : 0);										\
      	   SR = (SR & ~0xF) | (JRS.Mode[0] << 0) | (JRS.Mode[1] << 2);										\
	   SR |= SR_NPE;															\
	   SR |= 0x80;																\
	   SCU_SetInt(SCU_INT_SMPC, true);													\
	   SCU_SetInt(SCU_INT_SMPC, false);													\
	   JR_WAIT((bool)(IREG[0] & 0x80) == JRS.NextContBit || (IREG[0] & 0x40));								\
           if(IREG[0] & 0x40)															\
           {																	\
            SS_DBGTI(SS_DBG_SMPC, "[SMPC] Big Read Break");											\
            goto AbortJR;															\
	   }																	\
	   JRS.NextContBit = !JRS.NextContBit;													\
	  }																	\
          if(JRS.PDCounter < 0xFF)														\
           JRS.PDCounter++;															\
	 }																	\
																		\
	 OREG[(JRS.OWP >> 1)] &= 0x0F << ((JRS.OWP & 1) << 2);								\
	 OREG[(JRS.OWP >> 1)] |= ((val) & 0xF) << (((JRS.OWP & 1) ^ 1) << 2);						\
	 JRS.OWP = (JRS.OWP + 1) & 0x3F;										\
	}

      #define JR_BS	IOBusState[JRS.CurPort]

      #define JR_TH_TR(th, tr)											\
	{													\
	 DataDir[JRS.CurPort][0] = ((th >= 0) << 6) | ((tr >= 0) << 5);						\
	 DataOut[JRS.CurPort][0] = (DataOut[JRS.CurPort][0] & 0x1F) | (((th) > 0) << 6) | (((tr) > 0) << 5);	\
	 UpdateIOBus(JRS.CurPort, timestamp);									\
	}

      JR_WAIT(!vb);
      JRS.NextContBit = true;
      if(SR & SR_NPE)
      {
       JR_WAIT((bool)(IREG[0] & 0x80) == JRS.NextContBit || (IREG[0] & 0x40));
       if(IREG[0] & 0x40)
       {
        SS_DBGTI(SS_DBG_SMPC, "[SMPC] Break");
        goto AbortJR;
       }
       JRS.NextContBit = !JRS.NextContBit;
      }

      JRS.PDCounter = 0;
      JRS.TimeOptEn = !(IREG[1] & 0x2);
      JRS.Mode[0] = (IREG[1] >> 4) & 0x3;
      JRS.Mode[1] = (IREG[1] >> 6) & 0x3;

      JRS.OptReadTime = 0;
      JRS.OptEatTime = std::max<int32>(0, (JRS.OptWaitUntilTime - (JRS.TimeCounter >> 32)));
      JRS.OptWaitUntilTime = 0;

      if(JRS.TimeOptEn)
      {
       SMPC_WAIT_UNTIL_COND_TIMEOUT(PendingVB, JRS.OptEatTime);
       if(PendingVB)
       {
	SS_DBGTI(SS_DBG_SMPC, "[SMPC] abortjr timeopt");
	goto AbortJR;
       }
       SS_SetEventNT(&events[SS_EVENT_MIDSYNC], timestamp + 1);
      }

      JRS.StartTime = JRS.TimeCounter >> 32;
      JR_EAT(120);
      JRS.OWP = 0;
      for(JRS.CurPort = 0; JRS.CurPort < 2; JRS.CurPort++)
      {
       JR_EAT(380);

       if(JRS.Mode[JRS.CurPort] & 0x2)
	continue;

       // TODO: 255-byte read size mode.

       JRS.ID1 = 0;
       JR_TH_TR(1, 1);
       JR_EAT(50);
       JRS.work[0] = JR_BS;
       JRS.ID1 |= ((((JRS.work[0] >> 3) | (JRS.work[0] >> 2)) & 1) << 3) | ((((JRS.work[0] >> 1) | (JRS.work[0] >> 0)) & 1) << 2);

       JR_TH_TR(0, 1);
       JR_EAT(50);
       JRS.work[1] = JR_BS;
       JRS.ID1 |= ((((JRS.work[1] >> 3) | (JRS.work[1] >> 2)) & 1) << 1) | ((((JRS.work[1] >> 1) | (JRS.work[1] >> 0)) & 1) << 0);

       //printf("%d ID1: %02x (%02x, %02x)\n", JRS.CurPort, JRS.ID1, JRS.work[0], JRS.work[1]);

       if(JRS.ID1 == 0xB)
       {
	// Saturn digital pad.
	JR_TH_TR(1, 0)
	JR_EAT(50);
	JRS.work[2] = JR_BS;

	JR_TH_TR(0, 0)
	JR_EAT(50);
	JRS.work[3] = JR_BS;

	JR_EAT(30);

	JR_WRNYB(0xF);	// Multitap ID
	JR_EAT(21);

	JR_WRNYB(0x1);	// Number of connected devices behind multitap
	JR_EAT(21);

	JR_WRNYB(0x0);	// Peripheral ID-2.
	JR_EAT(21);

	JR_WRNYB(0x2);	// Data size.
	JR_EAT(21);

	JR_WRNYB(JRS.work[1] & 0xF);
	JR_EAT(21);

	JR_WRNYB(JRS.work[2] & 0xF);
	JR_EAT(21);

	JR_WRNYB(JRS.work[3] & 0xF);
	JR_EAT(21);

	JR_WRNYB((JRS.work[0] & 0xF) | 0x7);
	JR_EAT(21);

	//JR_EAT();

	//
	//
	//
       }
       else if(JRS.ID1 == 0x3 || JRS.ID1 == 0x5)
       {
	JR_TH_TR(0, 0)
	JR_EAT(50);
	JR_WAIT(!(JR_BS & 0x10));
	JRS.ID2 = ((JR_BS & 0xF) << 4);

	JR_TH_TR(0, 1)
	JR_EAT(50);
	JR_WAIT(JR_BS & 0x10);
	JRS.ID2 |= ((JR_BS & 0xF) << 0);

	//printf("%d, %02x %02x\n", JRS.CurPort, JRS.ID1, JRS.ID2);

	if(JRS.ID1 == 0x3)
	 JRS.ID2 = 0xE3;

        if((JRS.ID2 & 0xF0) == 0x40) // Multitap
        {
	 JR_TH_TR(0, 0)
	 JR_EAT(50);
	 JR_WAIT(!(JR_BS & 0x10));
	 JRS.IDTap = ((JRS.ID2 & 0xF) << 4) | (JR_BS & 0xF);

	 JR_TH_TR(0, 1)
	 JR_EAT(50);
	 JR_WAIT(JR_BS & 0x10);
        }
	else
	 JRS.IDTap = 0xF1;

        JRS.TapCounter = 0;
        JRS.TapCount = (JRS.IDTap & 0xF);
        while(JRS.TapCounter < JRS.TapCount)
        {
         if(JRS.TapCount > 1)
         {
	  JR_TH_TR(0, 0)
	  JR_EAT(50);
	  JR_WAIT(!(JR_BS & 0x10));
	  JRS.ID2 = ((JR_BS & 0xF) << 4);

	  JR_TH_TR(0, 1)
	  JR_EAT(50);
	  JR_WAIT(JR_BS & 0x10);
	  JRS.ID2 |= ((JR_BS & 0xF) << 0);
         }
	 JRS.ReadCounter = 0;
         JRS.ReadCount = ((JRS.ID2 & 0xF0) == 0xF0) ? 0 : (JRS.ID2 & 0xF);
	 while(JRS.ReadCounter < JRS.ReadCount)
	 {
	  JR_TH_TR(0, 0)
	  JR_EAT(50);
	  JR_WAIT(!(JR_BS & 0x10));
	  JRS.ReadBuffer[JRS.ReadCounter] = ((JR_BS & 0xF) << 4);

	  JR_TH_TR(0, 1)
	  JR_EAT(50);
	  JR_WAIT(JR_BS & 0x10);
	  JRS.ReadBuffer[JRS.ReadCounter] |= ((JR_BS & 0xF) << 0);
	  JRS.ReadCounter++;
	 }

         if(!JRS.TapCounter)
         {
	  JR_WRNYB(JRS.IDTap >> 4);
	  JR_EAT(21);

	  JR_WRNYB(JRS.IDTap >> 0);
	  JR_EAT(21);
         }

         //printf("What: %d, %02x\n", JRS.TapCounter, JRS.ID2);

	 JR_WRNYB(JRS.ID2 >> 4);
	 JR_EAT(21);

	 JR_WRNYB(JRS.ID2 >> 0);
	 JR_EAT(21);

	 JRS.WriteCounter = 0;
	 while(JRS.WriteCounter < JRS.ReadCounter)
	 {
	  JR_WRNYB(JRS.ReadBuffer[JRS.WriteCounter] >> 4);
 	  JR_EAT(21);

	  JR_WRNYB(JRS.ReadBuffer[JRS.WriteCounter] >> 0);
 	  JR_EAT(21);

          JRS.WriteCounter++;
	 }
	 JRS.TapCounter++;
	}
	// Saturn analog joystick, keyboard, multitap
        // OREG[0x0] = 0xF1;	// Upper nybble, multitap ID.  Lower nybble, number of connected devices behind multitap.
        // OREG[0x1] = 0x02;	// Upper nybble, peripheral ID 2.  Lower nybble, data size.
       }
       else
       {
	JR_WRNYB(JRS.ID1);
	JR_WRNYB(0x0);
       }
       JR_EAT(26);
       JR_TH_TR(-1, -1);
      }
      JRS.CurPort = 0; // For save state sanitization consistency.

      SR = (SR & ~SR_NPE);
      SR = (SR & ~0xF) | (JRS.Mode[0] << 0) | (JRS.Mode[1] << 2);
      SR = (SR & ~SR_PDL) | ((JRS.PDCounter < 0x2) ? SR_PDL : 0);
      SR |= 0x80;
      SCU_SetInt(SCU_INT_SMPC, true);
      SCU_SetInt(SCU_INT_SMPC, false);

      if(JRS.TimeOptEn)
       JRS.OptReadTime = std::max<int32>(0, (JRS.TimeCounter >> 32) - JRS.StartTime);
     }
     AbortJR:;
     // TODO: Set TH TR to inputs on abort.
    }
    else if(ExecutingCommand == CMD_SETTIME)	// Warning: Execute RTC setting atomically(all values or none) in regards to emulator exit/power toggle.
    {
     SMPC_EAT_CLOCKS(380);

     RTC.ClockAccum = 0;	// settime resets sub-second count.
     RTC.Valid = true;

     for(unsigned i = 0; i < 7; i++)
      RTC.raw[i] = IREG[i];
    }
    else if(ExecutingCommand == CMD_SETSMEM)	// Warning: Execute save mem setting(all values or none) atomically in regards to emulator exit/power toggle.
    {
     SMPC_EAT_CLOCKS(234);

     for(unsigned i = 0; i < 4; i++)
      SaveMem[i] = IREG[i];
    }
    else if(ExecutingCommand == CMD_NMIREQ)
    {
     CPU[0].SetNMI(false);
     CPU[0].SetNMI(true);
    }
    else if(ExecutingCommand == CMD_RESENAB)
    {
     ResetNMIEnable = true;
    }
    else if(ExecutingCommand == CMD_RESDISA)
    {
     ResetNMIEnable = false;
    }
   }

   ExecutingCommand = -1;
   SF = false;
   continue;
  }
 }
 Breakout:;

 return std::min<sscpu_timestamp_t>(next_event_ts, std::min<sscpu_timestamp_t>(IOPorts[0]->NextEventTS, IOPorts[1]->NextEventTS));
}

void SMPC_SetVBVS(sscpu_timestamp_t event_timestamp, bool vb_status, bool vsync_status)
{
 if(vb ^ vb_status)
 {
  if(vb_status)	// Going into vblank
   PendingVB = true;

  SS_SetEventNT(&events[SS_EVENT_SMPC], event_timestamp + 1);
 }

 vb = vb_status;
 vsync = vsync_status;
}

void SMPC_LineHook(sscpu_timestamp_t event_timestamp, int32 out_line, int32 div, int32 coord_adj)
{
 IOPorts[0]->LineHook(event_timestamp, out_line, div, coord_adj);
 IOPorts[1]->LineHook(event_timestamp, out_line, div, coord_adj);
 //
 //
 sscpu_timestamp_t nets = std::min<sscpu_timestamp_t>(events[SS_EVENT_SMPC].event_time, std::min<sscpu_timestamp_t>(IOPorts[0]->NextEventTS, IOPorts[1]->NextEventTS));

 SS_SetEventNT(&events[SS_EVENT_SMPC], nets);
}

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoSSVPort =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Digital Gamepad
 {
  "gamepad",
  "Digital Gamepad",
  "Standard Saturn digital gamepad.",
  IODevice_Gamepad_IDII
 },

 // 3D Gamepad
 {
  "3dpad",
  "3D Control Pad",
  "3D Control Pad",
  IODevice_3DPad_IDII
 },

 // Mouse
 {
  "mouse",
  "Mouse",
  "Mouse",
  IODevice_Mouse_IDII
 },

 // Steering Wheel
 {
  "wheel",
  "Steering Wheel",
  "Arcade Racer/Racing Controller",
  IODevice_Wheel_IDII
 },

 // Mission Stick
 {
  "mission",
  "Mission Stick",
  "Mission Stick",
  IODevice_Mission_IDII
 },

 // Dual Mission Stick
 {
  "dmission",
  "Dual Mission",
  "Dual Mission Sticks, useful for \"Panzer Dragoon Zwei\".  With 30 inputs to map, don't get distracted by..LOOK A LOBSTER!",
  IODevice_DualMission_IDII
 },

 // Gun(Virtua Gun/Stunner)
 {
  "gun",
  "Light Gun",
  "Virtua Gun/Stunner.  Won't function properly if connected behind an emulated multitap.\nEmulation of the Saturn lightgun in Mednafen is not particularly accurate(in terms of low-level details), unless you happen to be in the habit of using your Saturn with a TV the size of a house and bright enough to start fires.",
  IODevice_Gun_IDII
 },

 // Keyboard (101-key US)
 {
  "keyboard",
  "Keyboard (US)",
  "101-key US keyboard.",
  IODevice_Keyboard_US101_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD
 },

 // Keyboard (Japanese)
 {
  "jpkeyboard",
  "Keyboard (JP)",
  "89-key Japanese keyboard(e.g. HSS-0129).",
  IODevice_JPKeyboard_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD
 },
};

static IDIISG IDII_Builtin =
{
 IDIIS_ResetButton(),
 IDIIS_Button("smpc_reset", "SMPC Reset", -1),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoBuiltin =
{
 {
  "builtin",
  "builtin",
  NULL,
  IDII_Builtin
 }
};

const std::vector<InputPortInfoStruct> SMPC_PortInfo =
{
 { "port1", "Virtual Port 1", InputDeviceInfoSSVPort, "gamepad" },
 { "port2", "Virtual Port 2", InputDeviceInfoSSVPort, "gamepad" },
 { "port3", "Virtual Port 3", InputDeviceInfoSSVPort, "gamepad" },
 { "port4", "Virtual Port 4", InputDeviceInfoSSVPort, "gamepad" },
 { "port5", "Virtual Port 5", InputDeviceInfoSSVPort, "gamepad" },
 { "port6", "Virtual Port 6", InputDeviceInfoSSVPort, "gamepad" },
 { "port7", "Virtual Port 7", InputDeviceInfoSSVPort, "gamepad" },
 { "port8", "Virtual Port 8", InputDeviceInfoSSVPort, "gamepad" },
 { "port9", "Virtual Port 9", InputDeviceInfoSSVPort, "gamepad" },
 { "port10", "Virtual Port 10", InputDeviceInfoSSVPort, "gamepad" },
 { "port11", "Virtual Port 11", InputDeviceInfoSSVPort, "gamepad" },
 { "port12", "Virtual Port 12", InputDeviceInfoSSVPort, "gamepad" },

 { "builtin", "Builtin", InputDeviceInfoBuiltin, "builtin" },
};


}
