/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2004-2006, 2013 Theo Berkau

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

#ifndef SH2CORE_H
#define SH2CORE_H

#include "core.h"
#include "memory.h"

#define SH2CORE_DEFAULT     -1
#define MAX_INTERRUPTS 50

#ifdef MACH
#undef MACH
#endif

// UBC Flags
#define BBR_CPA_NONE			(0 << 6)
#define BBR_CPA_CPU				(1 << 6)
#define BBR_CPA_PER				(2 << 6)

#define BBR_IDA_NONE			(0 << 4)
#define BBR_IDA_INST	 		(1 << 4)
#define BBR_IDA_DATA			(2 << 4)

#define BBR_RWA_NONE			(0 << 2)
#define BBR_RWA_READ	 		(1 << 2)
#define BBR_RWA_WRITE			(2 << 2)

#define BBR_SZA_NONE			(0 << 0)
#define BBR_SZA_BYTE	 		(1 << 0)
#define BBR_SZA_WORD			(2 << 0)
#define BBR_SZA_LONGWORD	 	(3 << 0)

#define BRCR_CMFCA				(1 << 15)
#define BRCR_CMFPA				(1 << 14)
#define BRCR_EBBA				(1 << 13)
#define BRCR_UMD				(1 << 12)
#define BRCR_PCBA				(1 << 10)

#define BRCR_CMFCB				(1 << 7)
#define BRCR_CMFPB				(1 << 6)
#define BRCR_SEQ				(1 << 4)
#define BRCR_DBEB				(1 << 3)
#define BRCR_PCBB				(1 << 2)

typedef struct
{
   u32 R[16];

#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 reserved1:22;
      u32 M:1;
      u32 Q:1;
      u32 I:4;
      u32 reserved0:2;
      u32 S:1;
      u32 T:1;
    } part;
    u32 all;
  } SR;
#else
  union {
    struct {
      u32 T:1;
      u32 S:1;
      u32 reserved0:2;
      u32 I:4;
      u32 Q:1;
      u32 M:1;
      u32 reserved1:22;
    } part;
    u32 all;
  } SR;
#endif

   u32 GBR;
   u32 VBR;
   u32 MACH;
   u32 MACL;
   u32 PR;
   u32 PC;
} sh2regs_struct;

typedef struct
{
   u8 SMR;     // 0xFFFFFE00
   u8 BRR;     // 0xFFFFFE01
   u8 SCR;     // 0xFFFFFE02
   u8 TDR;     // 0xFFFFFE03
   u8 SSR;     // 0xFFFFFE04
   u8 RDR;     // 0xFFFFFE05
   u8 TIER;    // 0xFFFFFE10
   u8 FTCSR;   // 0xFFFFFE11

#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u16 H:8; // 0xFFFFFE12
      u16 L:8; // 0xFFFFFE13
    } part;
    u16 all;
  } FRC;
#else
  union {
    struct {
      u16 L:8; // 0xFFFFFE13
      u16 H:8; // 0xFFFFFE12
    } part;
    u16 all;
  } FRC;
#endif
   u16 OCRA;   // 0xFFFFFE14/0xFFFFFE15
   u16 OCRB;   // 0xFFFFFE14/0xFFFFFE15
   u8 TCR;     // 0xFFFFFE16
   u8 TOCR;    // 0xFFFFFE17
   u16 FICR;   // 0xFFFFFE18
               // 0xFFFFFE19
   u16 IPRB;   // 0xFFFFFE60
   u16 VCRA;   // 0xFFFFFE62
   u16 VCRB;   // 0xFFFFFE64
   u16 VCRC;   // 0xFFFFFE66
   u16 VCRD;   // 0xFFFFFE68
   u8 DRCR0;   // 0xFFFFFE71
   u8 DRCR1;   // 0xFFFFFE72
   u8 WTCSR;   // 0xFFFFFE80
   u8 WTCNT;   // 0xFFFFFE81
   u8 RSTCSR;  // 0xFFFFFE83
   u8 SBYCR;   // 0xFFFFFE91
   u8 CCR;     // 0xFFFFFE92
   u16 ICR;    // 0xFFFFFEE0
   u16 IPRA;   // 0xFFFFFEE2
   u16 VCRWDT; // 0xFFFFFEE4
   u32 DVSR;   // 0xFFFFFF00
   u32 DVDNT;  // 0xFFFFFF04
   u32 DVCR;   // 0xFFFFFF08
   u32 VCRDIV; // 0xFFFFFF0C
   u32 DVDNTH; // 0xFFFFFF10
   u32 DVDNTL; // 0xFFFFFF14
   u32 DVDNTUH; // 0xFFFFFF18
   u32 DVDNTUL; // 0xFFFFFF1C
#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 H:16; // 0xFFFFFF40
      u32 L:16; // 0xFFFFFF42
    } part;
    u16 all;
  } BARA;

  union {
    struct {
      u32 H:16; // 0xFFFFFF44
      u32 L:16; // 0xFFFFFF46
    } part;
    u16 all;
  } BAMRA;
#else
  union {
    struct {
      u32 L:16; // 0xFFFFFF42
      u32 H:16; // 0xFFFFFF40
    } part;
    u16 all;
  } BARA;

  union {
    struct {
      u32 L:16; // 0xFFFFFF46
      u32 H:16; // 0xFFFFFF44
    } part;
    u16 all;
  } BAMRA;
#endif
   u32 BBRA;   // 0xFFFFFF48
#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 H:16; // 0xFFFFFF60
      u32 L:16; // 0xFFFFFF62
    } part;
    u16 all;
  } BARB;

  union {
    struct {
      u32 H:16; // 0xFFFFFF64
      u32 L:16; // 0xFFFFFF66
    } part;
    u16 all;
  } BAMRB;
#else
  union {
    struct {
      u32 L:16; // 0xFFFFFF62
      u32 H:16; // 0xFFFFFF60
    } part;
    u16 all;
  } BARB;

  union {
    struct {
      u32 L:16; // 0xFFFFFF66
      u32 H:16; // 0xFFFFFF64
    } part;
    u16 all;
  } BAMRB;
#endif
   u32 BBRB;   // 0xFFFFFF68
#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 H:16; // 0xFFFFFF70
      u32 L:16; // 0xFFFFFF72
    } part;
    u16 all;
  } BDRB;

  union {
    struct {
      u32 H:16; // 0xFFFFFF74
      u32 L:16; // 0xFFFFFF76
    } part;
    u16 all;
  } BDMRB;
#else
  union {
    struct {
      u32 L:16; // 0xFFFFFF72
      u32 H:16; // 0xFFFFFF70
    } part;
    u16 all;
  } BDRB;

  union {
    struct {
      u32 L:16; // 0xFFFFFF76
      u32 H:16; // 0xFFFFFF74
    } part;
    u16 all;
  } BDMRB;
#endif
   u32 BRCR;   // 0xFFFFFF78
   u32 SAR0;   // 0xFFFFFF80
   u32 DAR0;   // 0xFFFFFF84
   u32 TCR0;   // 0xFFFFFF88
   u32 CHCR0;  // 0xFFFFFF8C
   u32 SAR1;   // 0xFFFFFF90
   u32 DAR1;   // 0xFFFFFF94
   u32 TCR1;   // 0xFFFFFF98
   u32 CHCR1;  // 0xFFFFFF9C
   u32 VCRDMA0;// 0xFFFFFFA0
   u32 VCRDMA1;// 0xFFFFFFA8
   u32 DMAOR;  // 0xFFFFFFB0
   u16 BCR1;   // 0xFFFFFFE0
   u16 BCR2;   // 0xFFFFFFE4
   u16 WCR;    // 0xFFFFFFE8
   u16 MCR;    // 0xFFFFFFEC
   u16 RTCSR;  // 0xFFFFFFF0
   u16 RTCNT;  // 0xFFFFFFF4
   u16 RTCOR;  // 0xFFFFFFF8
} Onchip_struct;

typedef struct
{
   u8 vector;
   u8 level;
} interrupt_struct;

typedef struct
{
  u32 addr;
} codebreakpoint_struct;

typedef struct
{
  u32 addr;
  u32 flags;
  readbytefunc oldreadbyte;
  readwordfunc oldreadword;
  readlongfunc oldreadlong;
  writebytefunc oldwritebyte;
  writewordfunc oldwriteword;
  writelongfunc oldwritelong;
} memorybreakpoint_struct;

#define MAX_BREAKPOINTS 10

typedef struct
{
   codebreakpoint_struct codebreakpoint[MAX_BREAKPOINTS];
   int numcodebreakpoints;
   memorybreakpoint_struct memorybreakpoint[MAX_BREAKPOINTS];
   int nummemorybreakpoints;
   void (*BreakpointCallBack)(void *, u32, void *);
   void *BreakpointUserData;
   int inbreakpoint;
   int breaknow;
} breakpoint_struct;

typedef struct
{
   u32 addr[256];
   int numbacktrace;
} backtrace_struct;


#define BREAK_BYTEREAD  0x1
#define BREAK_WORDREAD  0x2
#define BREAK_LONGREAD  0x4
#define BREAK_BYTEWRITE 0x8
#define BREAK_WORDWRITE 0x10
#define BREAK_LONGWRITE 0x20

enum SH2STEPTYPE
{
   SH2ST_STEPOVER,
   SH2ST_STEPOUT
};

typedef struct
{
   u32 addr;
   u64 count;
} tilInfo_struct;

typedef struct
{
   sh2regs_struct regs;
   Onchip_struct onchip;

   struct
   {
      u32 leftover;
      u32 shift;
   } frc;

   struct
   {
        int isenable;
        int isinterval;
        u32 leftover;
        u32 shift;
   } wdt;

   interrupt_struct interrupts[MAX_INTERRUPTS];
   u32 NumberOfInterrupts;
   u32 AddressArray[0x100];
   u8 DataArray[0x1000];
   u32 delay;
   u32 cycles;
   u8 isslave;
   u8 isIdle;
   u8 isSleeping;
   u16 instruction;
   u8 breakpointEnabled;
   breakpoint_struct bp;
   u8 backtraceEnabled;
   backtrace_struct bt;
   struct
   {
      u8 enabled;
      void (*callBack)(void *, u32, void *);
      enum SH2STEPTYPE type;
      union
      {
         s32 levels;
         u32 address;
      };
   } stepOverOut;
   struct 
   {
      u8 enabled;
      tilInfo_struct *match;
      int num;
      int maxNum;
   } trackInfLoop;

} SH2_struct;

typedef struct
{
   int id;
   const char *Name;

   int (*Init)(void);
   void (*DeInit)(void);
   void (*Reset)(SH2_struct *context);
   void FASTCALL (*Exec)(SH2_struct *context, u32 cycles);

   void (*GetRegisters)(SH2_struct *context, sh2regs_struct *regs);
   u32 (*GetGPR)(SH2_struct *context, int num);
   u32 (*GetSR)(SH2_struct *context);
   u32 (*GetGBR)(SH2_struct *context);
   u32 (*GetVBR)(SH2_struct *context);
   u32 (*GetMACH)(SH2_struct *context);
   u32 (*GetMACL)(SH2_struct *context);
   u32 (*GetPR)(SH2_struct *context);
   u32 (*GetPC)(SH2_struct *context);

   void (*SetRegisters)(SH2_struct *context, const sh2regs_struct *regs);
   void (*SetGPR)(SH2_struct *context, int num, u32 value);
   void (*SetSR)(SH2_struct *context, u32 value);
   void (*SetGBR)(SH2_struct *context, u32 value);
   void (*SetVBR)(SH2_struct *context, u32 value);
   void (*SetMACH)(SH2_struct *context, u32 value);
   void (*SetMACL)(SH2_struct *context, u32 value);
   void (*SetPR)(SH2_struct *context, u32 value);
   void (*SetPC)(SH2_struct *context, u32 value);

   void (*SendInterrupt)(SH2_struct *context, u8 vector, u8 level);
   int (*GetInterrupts)(SH2_struct *context,
                        interrupt_struct interrupts[MAX_INTERRUPTS]);
   void (*SetInterrupts)(SH2_struct *context, int num_interrupts,
                         const interrupt_struct interrupts[MAX_INTERRUPTS]);

   void (*WriteNotify)(u32 start, u32 length);
} SH2Interface_struct;

extern SH2_struct *MSH2;
extern SH2_struct *SSH2;
extern SH2_struct *CurrentSH2;
extern SH2Interface_struct *SH2Core;

int SH2Init(int coreid);
void SH2DeInit(void);
void SH2Reset(SH2_struct *context);
void SH2PowerOn(SH2_struct *context);
void FASTCALL SH2Exec(SH2_struct *context, u32 cycles);
void SH2SendInterrupt(SH2_struct *context, u8 vector, u8 level);
void SH2NMI(SH2_struct *context);
void SH2Step(SH2_struct *context);
int SH2StepOver(SH2_struct *context, void (*func)(void *, u32, void *));
void SH2StepOut(SH2_struct *context, void (*func)(void *, u32, void *));

int SH2TrackInfLoopInit(SH2_struct *context);
void SH2TrackInfLoopDeInit(SH2_struct *context);
void SH2TrackInfLoopStart(SH2_struct *context);
void SH2TrackInfLoopStop(SH2_struct *context);
void SH2TrackInfLoopClear(SH2_struct *context);

void SH2GetRegisters(SH2_struct *context, sh2regs_struct * r);
void SH2SetRegisters(SH2_struct *context, sh2regs_struct * r);
void SH2WriteNotify(u32 start, u32 length);

void SH2SetBreakpointCallBack(SH2_struct *context, void (*func)(void *, u32, void *), void *userdata);
int SH2AddCodeBreakpoint(SH2_struct *context, u32 addr);
int SH2DelCodeBreakpoint(SH2_struct *context, u32 addr);
codebreakpoint_struct *SH2GetBreakpointList(SH2_struct *context);
void SH2ClearCodeBreakpoints(SH2_struct *context);

static INLINE void SH2HandleBreakpoints(SH2_struct *context)
{
   int i;

   for (i=0; i < context->bp.numcodebreakpoints; i++) {

      if ((context->regs.PC == context->bp.codebreakpoint[i].addr) && context->bp.inbreakpoint == 0) {
         context->bp.inbreakpoint = 1;
         if (context->bp.BreakpointCallBack)
             context->bp.BreakpointCallBack(context, context->bp.codebreakpoint[i].addr, context->bp.BreakpointUserData);
         context->bp.inbreakpoint = 0;
      }
   }

   if (context->bp.breaknow) {
      context->bp.breaknow = 0;
      context->bp.BreakpointCallBack(context, context->regs.PC, context->bp.BreakpointUserData);
   }
}

static void SH2BreakNow(SH2_struct *context)
{
   context->bp.breaknow = 1;
}

int SH2AddMemoryBreakpoint(SH2_struct *context, u32 addr, u32 flags);
int SH2DelMemoryBreakpoint(SH2_struct *context, u32 addr);
memorybreakpoint_struct *SH2GetMemoryBreakpointList(SH2_struct *context);
void SH2ClearMemoryBreakpoints(SH2_struct *context);
void SH2HandleBackTrace(SH2_struct *context);
u32 *SH2GetBacktraceList(SH2_struct *context, int *size);
void SH2HandleStepOverOut(SH2_struct *context);
void SH2HandleTrackInfLoop(SH2_struct *context);

void DMAExec(void);
void DMATransfer(u32 *CHCR, u32 *SAR, u32 *DAR, u32 *TCR, u32 *VCRDMA);

u8 FASTCALL OnchipReadByte(u32 addr);
u16 FASTCALL OnchipReadWord(u32 addr);
u32 FASTCALL OnchipReadLong(u32 addr);
void FASTCALL OnchipWriteByte(u32 addr, u8 val);
void FASTCALL OnchipWriteWord(u32 addr, u16 val);
void FASTCALL OnchipWriteLong(u32 addr, u32 val);

u32 FASTCALL AddressArrayReadLong(u32 addr);
void FASTCALL AddressArrayWriteLong(u32 addr, u32 val);

u8 FASTCALL DataArrayReadByte(u32 addr);
u16 FASTCALL DataArrayReadWord(u32 addr);
u32 FASTCALL DataArrayReadLong(u32 addr);
void FASTCALL DataArrayWriteByte(u32 addr, u8 val);
void FASTCALL DataArrayWriteWord(u32 addr, u16 val);
void FASTCALL DataArrayWriteLong(u32 addr, u32 val);

void FASTCALL MSH2InputCaptureWriteWord(u32 addr, u16 data);
void FASTCALL SSH2InputCaptureWriteWord(u32 addr, u16 data);

int SH2SaveState(SH2_struct *context, FILE *fp);
int SH2LoadState(SH2_struct *context, FILE *fp, int version, int size);

#if defined(SH2_DYNAREC)
extern SH2Interface_struct SH2Dynarec;
#endif

#endif
