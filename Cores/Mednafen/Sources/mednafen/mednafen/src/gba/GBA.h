// -*- C++ -*-
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2005 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#ifndef VBA_GBA_H
#define VBA_GBA_H

#include <mednafen/mednafen.h>
#include <zlib.h>

using namespace Mednafen;

namespace MDFN_IEN_GBA
{

typedef struct {
  uint8 *address;
  uint32 mask;
} memoryMap;

typedef union {
  struct {
#ifdef MSB_FIRST
    uint8 B3;
    uint8 B2;
    uint8 B1;
    uint8 B0;
#else
    uint8 B0;
    uint8 B1;
    uint8 B2;
    uint8 B3;
#endif
  } B;
  struct {
#ifdef MSB_FIRST
    uint16 W1;
    uint16 W0;
#else
    uint16 W0;
    uint16 W1;
#endif
  } W;
#ifdef MSB_FIRST
  volatile uint32 I;
#else
	uint32 I;
#endif
} reg_pair;

#ifndef NO_GBA_MAP
MDFN_HIDE extern memoryMap map[256];
#endif

MDFN_HIDE extern bool busPrefetch;
MDFN_HIDE extern bool busPrefetchEnable;
MDFN_HIDE extern uint32 busPrefetchCount;
MDFN_HIDE extern uint32 cpuPrefetch[2];

MDFN_HIDE extern int cpuDmaCount;

MDFN_HIDE extern uint8 memoryWait[16];
MDFN_HIDE extern uint8 memoryWait32[16];
MDFN_HIDE extern uint8 memoryWaitSeq[16];
MDFN_HIDE extern uint8 memoryWaitSeq32[16];

MDFN_HIDE extern reg_pair reg[45];
MDFN_HIDE extern uint8 biosProtected[4];

MDFN_HIDE extern uint32 N_FLAG;
MDFN_HIDE extern bool Z_FLAG;
MDFN_HIDE extern bool C_FLAG;
MDFN_HIDE extern bool V_FLAG;
MDFN_HIDE extern bool armIrqEnable;
MDFN_HIDE extern bool armState;
MDFN_HIDE extern int armMode;
MDFN_HIDE extern void (*cpuSaveGameFunc)(uint32,uint8);

void doMirroring(bool);
void CPUUpdateRegister(uint32, uint16);
void applyTimer ();

MDFN_FASTCALL void CPUWriteMemory(uint32 address, uint32 value);
MDFN_FASTCALL void CPUWriteHalfWord(uint32, uint16);
MDFN_FASTCALL void CPUWriteByte(uint32, uint8);

void CPUCheckDMA(int,int);

void CPUSwitchMode(int mode, bool saveState, bool breakLoop);
void CPUSwitchMode(int mode, bool saveState);
void CPUUndefinedException();
void CPUSoftwareInterrupt();
void CPUSoftwareInterrupt(int comment);
void CPUUpdateCPSR();
void CPUUpdateFlags(bool breakLoop);
void CPUUpdateFlags();


MDFN_HIDE extern uint8 cpuBitsSet[256];
MDFN_HIDE extern uint8 cpuLowestBitSet[256];

MDFN_HIDE extern uint32 soundTS;

int32 MDFNGBA_GetTimerPeriod(int which);


#define R13_IRQ  18
#define R14_IRQ  19
#define SPSR_IRQ 20
#define R13_USR  26
#define R14_USR  27
#define R13_SVC  28
#define R14_SVC  29
#define SPSR_SVC 30
#define R13_ABT  31
#define R14_ABT  32
#define SPSR_ABT 33
#define R13_UND  34
#define R14_UND  35
#define SPSR_UND 36
#define R8_FIQ   37
#define R9_FIQ   38
#define R10_FIQ  39
#define R11_FIQ  40
#define R12_FIQ  41
#define R13_FIQ  42
#define R14_FIQ  43
#define SPSR_FIQ 44
}

#include "Globals.h"
#include "eeprom.h"
#include "flash.h"
#include "RTC.h"

namespace MDFN_IEN_GBA
{

MDFN_HIDE extern RTC *GBA_RTC;

}

#endif //VBA_GBA_H
