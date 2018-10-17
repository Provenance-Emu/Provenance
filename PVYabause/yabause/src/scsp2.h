/*  src/scsp2.h: Header for new SCSP implementation
    Copyright 2010 Andrew Church

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

#ifndef SCSP_H  // Not SCSP2_H (we substitute for the original scsp.h)
#define SCSP_H

#include "core.h"  // For sized integer types

///////////////////////////////////////////////////////////////////////////

// Module interface declaration

#define SNDCORE_DEFAULT -1
#define SNDCORE_DUMMY   0
#define SNDCORE_WAV     10  // Should be 1, but left as is for backward compat

#define SCSP_MUTE_SYSTEM    1
#define SCSP_MUTE_USER      2

typedef struct
{
   int id;
   const char *Name;
   int (*Init)(void);
   void (*DeInit)(void);
   int (*Reset)(void);
   int (*ChangeVideoFormat)(int vertfreq);
   // FIXME/SCSP1: u32* should be s32* (they're signed samples)
   void (*UpdateAudio)(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples);
   u32 (*GetAudioSpace)(void);
   void (*MuteAudio)(void);
   void (*UnMuteAudio)(void);
   void (*SetVolume)(int volume);
} SoundInterface_struct;

extern SoundInterface_struct SNDDummy;
extern SoundInterface_struct SNDWave;

///////////////////////////////////////////////////////////////////////////

// Parameter block for M68K{Get,Set}Registers()
typedef struct {
   u32 D[8];
   u32 A[8];
   u32 SR;
   u32 PC;
} M68KRegs;

// Breakpoint data structure (currently just an address)
typedef struct {
   u32 addr;
} M68KBreakpointInfo;

// Maximum number of M68K breakpoints that can be set simultaneously
#define M68K_MAX_BREAKPOINTS 10

///////////////////////////////////////////////////////////////////////////

// Data/function declarations

extern u8 *SoundRam;

extern int ScspInit(int coreid, void (*interrupt_handler)(void));
extern void ScspReset(void);
extern int ScspChangeSoundCore(int coreid);
extern int ScspChangeVideoFormat(int type);
extern void ScspSetFrameAccurate(int on);
extern void ScspMuteAudio(int flags);
extern void ScspUnMuteAudio(int flags);
extern void ScspSetVolume(int volume);
extern void ScspDeInit(void);

extern void ScspExec(int decilines);

extern u8 FASTCALL SoundRamReadByte(u32 address);
extern u16 FASTCALL SoundRamReadWord(u32 address);
extern u32 FASTCALL SoundRamReadLong(u32 address);
extern void FASTCALL SoundRamWriteByte(u32 address, u8 data);
extern void FASTCALL SoundRamWriteWord(u32 address, u16 data);
extern void FASTCALL SoundRamWriteLong(u32 address, u32 data);
extern u8 FASTCALL ScspReadByte(u32 address);
extern u16 FASTCALL ScspReadWord(u32 address);
extern u32 FASTCALL ScspReadLong(u32 address);
extern void FASTCALL ScspWriteByte(u32 address, u8 data);
extern void FASTCALL ScspWriteWord(u32 address, u16 data);
extern void FASTCALL ScspWriteLong(u32 address, u32 data);
extern void ScspReceiveCDDA(const u8 *sector);

extern int SoundSaveState(FILE *fp);
extern int SoundLoadState(FILE *fp, int version, int size);
extern void ScspSlotDebugStats(u8 slotnum, char *outstring);
extern void ScspCommonControlRegisterDebugStats(char *outstring);
extern int ScspSlotDebugSaveRegisters(u8 slotnum, const char *filename);
extern int ScspSlotDebugAudioSaveWav(u8 slotnum, const char *filename);
extern void ScspConvert32uto16s(s32 *srcL, s32 *srcR, s16 *dest, u32 len);

extern void M68KStart(void);
extern void M68KStop(void);
extern void M68KStep(void);
extern void M68KWriteNotify(u32 address, u32 size);
extern void M68KGetRegisters(M68KRegs *regs);
extern void M68KSetRegisters(const M68KRegs *regs);
extern void M68KSetBreakpointCallBack(void (*func)(u32 address));
extern int M68KAddCodeBreakpoint(u32 address);
extern int M68KDelCodeBreakpoint(u32 address);
extern const M68KBreakpointInfo *M68KGetBreakpointList(void);
extern void M68KClearCodeBreakpoints(void);
extern u32 FASTCALL M68KReadByte(u32 address);
extern u32 FASTCALL M68KReadWord(u32 address);
extern void FASTCALL M68KWriteByte(u32 address, u32 data);
extern void FASTCALL M68KWriteWord(u32 address, u32 data);

///////////////////////////////////////////////////////////////////////////

// Compatibility macros to match scsp.h interface

#define m68kregs_struct M68KRegs
#define m68kcodebreakpoint_struct M68KBreakpointInfo

#include "scu.h"
#define ScspInit(coreid)  ScspInit((coreid), ScuSendSoundRequest)

#define scsp_r_b  ScspReadByte
#define scsp_r_w  ScspReadWord
#define scsp_r_d  ScspReadLong
#define scsp_w_b  ScspWriteByte
#define scsp_w_w  ScspWriteWord
#define scsp_w_d  ScspWriteLong

#define c68k_word_read  M68KReadWord

///////////////////////////////////////////////////////////////////////////

#endif  // SCSP_H

/*
 * Local variables:
 *   c-file-style: "stroustrup"
 *   c-basic-offset: 3
 *   c-file-offsets: ((case-label . *) (statement-case-intro . *))
 *   indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=3:
 */
