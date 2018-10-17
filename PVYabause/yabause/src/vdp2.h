/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2004-2006 Theo Berkau

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

#ifndef VDP2_H
#define VDP2_H

#include "memory.h"
/* This include is not *needed*, it's here to avoid breaking ports */
#include "osdcore.h"

extern u8 * Vdp2Ram;
extern u8 * Vdp2ColorRam;

u8 FASTCALL     Vdp2RamReadByte(u32);
u16 FASTCALL    Vdp2RamReadWord(u32);
u32 FASTCALL    Vdp2RamReadLong(u32);
void FASTCALL   Vdp2RamWriteByte(u32, u8);
void FASTCALL   Vdp2RamWriteWord(u32, u16);
void FASTCALL   Vdp2RamWriteLong(u32, u32);

u8 FASTCALL     Vdp2ColorRamReadByte(u32);
u16 FASTCALL    Vdp2ColorRamReadWord(u32);
u32 FASTCALL    Vdp2ColorRamReadLong(u32);
void FASTCALL   Vdp2ColorRamWriteByte(u32, u8);
void FASTCALL   Vdp2ColorRamWriteWord(u32, u16);
void FASTCALL   Vdp2ColorRamWriteLong(u32, u32);

typedef struct {
   u16 TVMD;   // 0x25F80000
   u16 EXTEN;  // 0x25F80002
   u16 TVSTAT; // 0x25F80004
   u16 VRSIZE; // 0x25F80006
   u16 HCNT;   // 0x25F80008
   u16 VCNT;   // 0x25F8000A
   u16 RAMCTL; // 0x25F8000E
   u16 CYCA0L; // 0x25F80010
   u16 CYCA0U; // 0x25F80012
   u16 CYCA1L; // 0x25F80014
   u16 CYCA1U; // 0x25F80016
   u16 CYCB0L; // 0x25F80018
   u16 CYCB0U; // 0x25F8001A
   u16 CYCB1L; // 0x25F8001C
   u16 CYCB1U; // 0x25F8001E
   u16 BGON;   // 0x25F80020
   u16 MZCTL;  // 0x25F80022
   u16 SFSEL;  // 0x25F80024
   u16 SFCODE; // 0x25F80026
   u16 CHCTLA; // 0x25F80028
   u16 CHCTLB; // 0x25F8002A
   u16 BMPNA;  // 0x25F8002C
   u16 BMPNB;  // 0x25F8002E
   u16 PNCN0;  // 0x25F80030
   u16 PNCN1;  // 0x25F80032
   u16 PNCN2;  // 0x25F80034
   u16 PNCN3;  // 0x25F80036
   u16 PNCR;   // 0x25F80038
   u16 PLSZ;   // 0x25F8003A
   u16 MPOFN;  // 0x25F8003C
   u16 MPOFR;  // 0x25F8003E
   u16 MPABN0; // 0x25F80040
   u16 MPCDN0; // 0x25F80042
   u16 MPABN1; // 0x25F80044
   u16 MPCDN1; // 0x25F80046
   u16 MPABN2; // 0x25F80048
   u16 MPCDN2; // 0x25F8004A
   u16 MPABN3; // 0x25F8004C
   u16 MPCDN3; // 0x25F8004E
   u16 MPABRA; // 0x25F80050
   u16 MPCDRA; // 0x25F80052
   u16 MPEFRA; // 0x25F80054
   u16 MPGHRA; // 0x25F80056
   u16 MPIJRA; // 0x25F80058
   u16 MPKLRA; // 0x25F8005A
   u16 MPMNRA; // 0x25F8005C
   u16 MPOPRA; // 0x25F8005E
   u16 MPABRB; // 0x25F80060
   u16 MPCDRB; // 0x25F80062
   u16 MPEFRB; // 0x25F80064
   u16 MPGHRB; // 0x25F80066
   u16 MPIJRB; // 0x25F80068
   u16 MPKLRB; // 0x25F8006A
   u16 MPMNRB; // 0x25F8006C
   u16 MPOPRB; // 0x25F8006E
   u16 SCXIN0; // 0x25F80070
   u16 SCXDN0; // 0x25F80072
   u16 SCYIN0; // 0x25F80074
   u16 SCYDN0; // 0x25F80076

#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 I:16; // 0x25F80078
      u32 D:16; // 0x25F8007A
    } part;
    u32 all;
  } ZMXN0;

  union {
    struct {
      u32 I:16; // 0x25F8007C
      u32 D:16; // 0x25F8007E
    } part;
    u32 all;
  } ZMYN0;
#else
  union {
    struct {
      u32 D:16; // 0x25F8007A
      u32 I:16; // 0x25F80078
    } part;
    u32 all;
  } ZMXN0;

  union {
    struct {
      u32 D:16; // 0x25F8007E
      u32 I:16; // 0x25F8007C
    } part;
    u32 all;
  } ZMYN0;
#endif

   u16 SCXIN1; // 0x25F80080
   u16 SCXDN1; // 0x25F80082
   u16 SCYIN1; // 0x25F80084
   u16 SCYDN1; // 0x25F80086

#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 I:16; // 0x25F80088
      u32 D:16; // 0x25F8008A
    } part;
    u32 all;
  } ZMXN1;

  union {
    struct {
      u32 I:16; // 0x25F8008C
      u32 D:16; // 0x25F8008E
    } part;
    u32 all;
  } ZMYN1;
#else
  union {
    struct {
      u32 D:16; // 0x25F8008A
      u32 I:16; // 0x25F80088
    } part;
    u32 all;
  } ZMXN1;

  union {
    struct {
      u32 D:16; // 0x25F8008E
      u32 I:16; // 0x25F8008C
    } part;
    u32 all;
  } ZMYN1;
#endif

   u16 SCXN2;  // 0x25F80090
   u16 SCYN2;  // 0x25F80092
   u16 SCXN3;  // 0x25F80094
   u16 SCYN3;  // 0x25F80096
   u16 ZMCTL;  // 0x25F80098
   u16 SCRCTL; // 0x25F8009A
#ifdef WORDS_BIGENDIAN
   union {
      struct {
         u32 U:16; // 0x25F8009C
         u32 L:16; // 0x25F8009E
      } part;
      u32 all;
   } VCSTA;

   union {
      struct {
         u32 U:16; // 0x25F800A0
         u32 L:16; // 0x25F800A2
      } part;
      u32 all;
   } LSTA0;

   union {
      struct {
         u32 U:16; // 0x25F800A4
         u32 L:16; // 0x25F800A6
      } part;
      u32 all;
   } LSTA1;

   union {
      struct {
         u32 U:16; // 0x25F800A8
         u32 L:16; // 0x25F800AA
      } part;
      u32 all;
   } LCTA;
#else
   union {
      struct {
         u32 L:16; // 0x25F8009E
         u32 U:16; // 0x25F8009C
      } part;
      u32 all;
   } VCSTA;

   union {
      struct {
         u32 L:16; // 0x25F800A2
         u32 U:16; // 0x25F800A0
      } part;
      u32 all;
   } LSTA0;

   union {
      struct {
         u32 L:16; // 0x25F800A6
         u32 U:16; // 0x25F800A4
      } part;
      u32 all;
   } LSTA1;

   union {
      struct {
         u32 L:16; // 0x25F800AA
         u32 U:16; // 0x25F800A8
      } part;
      u32 all;
   } LCTA;
#endif

   u16 BKTAU;  // 0x25F800AC
   u16 BKTAL;  // 0x25F800AE
   u16 RPMD;   // 0x25F800B0
   u16 RPRCTL; // 0x25F800B2
   u16 KTCTL;  // 0x25F800B4
   u16 KTAOF;  // 0x25F800B6
   u16 OVPNRA; // 0x25F800B8
   u16 OVPNRB; // 0x25F800BA
#ifdef WORDS_BIGENDIAN
   union {
      struct {
         u32 U:16; // 0x25F800BC
         u32 L:16; // 0x25F800BE
      } part;
      u32 all;
   } RPTA;
#else
   union {
      struct {
         u32 L:16; // 0x25F800BE
         u32 U:16; // 0x25F800BC
      } part;
      u32 all;
   } RPTA;
#endif
   u16 WPSX0;  // 0x25F800C0
   u16 WPSY0;  // 0x25F800C2
   u16 WPEX0;  // 0x25F800C4
   u16 WPEY0;  // 0x25F800C6
   u16 WPSX1;  // 0x25F800C8
   u16 WPSY1;  // 0x25F800CA
   u16 WPEX1;  // 0x25F800CC
   u16 WPEY1;  // 0x25F800CE
   u16 WCTLA;  // 0x25F800D0
   u16 WCTLB;  // 0x25F800D2
   u16 WCTLC;  // 0x25F800D4
   u16 WCTLD;  // 0x25F800D6
#ifdef WORDS_BIGENDIAN
  union {
    struct {
      u32 U:16; // 0x25F800D8
      u32 L:16; // 0x25F800DA
    } part;
    u32 all;
  } LWTA0;

  union {
    struct {
      u32 U:16; // 0x25F800DC
      u32 L:16; // 0x25F800DE
    } part;
    u32 all;
  } LWTA1;
#else
  union {
    struct {
      u32 L:16; // 0x25F800D8
      u32 U:16; // 0x25F800DA
    } part;
    u32 all;
  } LWTA0;

  union {
    struct {
      u32 L:16; // 0x25F800DC
      u32 U:16; // 0x25F800DE
    } part;
    u32 all;
  } LWTA1;
#endif


   u16 SPCTL;  // 0x25F800E0
   u16 SDCTL;  // 0x25F800E2
   u16 CRAOFA; // 0x25F800E4
   u16 CRAOFB; // 0x25F800E6
   u16 LNCLEN; // 0x25F800E8
   u16 SFPRMD; // 0x25F800EA
   u16 CCCTL;  // 0x25F800EC
   u16 SFCCMD; // 0x25F800EE
   u16 PRISA;  // 0x25F800F0
   u16 PRISB;  // 0x25F800F2
   u16 PRISC;  // 0x25F800F4
   u16 PRISD;  // 0x25F800F6
   u16 PRINA;  // 0x25F800F8
   u16 PRINB;  // 0x25F800FA
   u16 PRIR;   // 0x25F800FC
   u16 CCRSA;  // 0x25F80100
   u16 CCRSB;  // 0x25F80102
   u16 CCRSC;  // 0x25F80104
   u16 CCRSD;  // 0x25F80106
   u16 CCRNA;  // 0x25F80108
   u16 CCRNB;  // 0x25F8010A
   u16 CCRR;   // 0x25F8010C
   u16 CCRLB;  // 0x25F8010E
   u16 CLOFEN; // 0x25F80110
   u16 CLOFSL; // 0x25F80112
   u16 COAR;   // 0x25F80114
   u16 COAG;   // 0x25F80116
   u16 COAB;   // 0x25F80118
   u16 COBR;   // 0x25F8011A
   u16 COBG;   // 0x25F8011C
   u16 COBB;   // 0x25F8011E
} Vdp2;

extern Vdp2 * Vdp2Regs;

typedef struct {
   int ColorMode;
} Vdp2Internal_struct;

extern Vdp2Internal_struct Vdp2Internal;
extern u64 lastticks;
extern int vdp2_is_odd_frame;
extern Vdp2 Vdp2Lines[270];

struct CellScrollData
{
   u32 data[88];//(352/8) * 2 screens
};

extern struct CellScrollData cell_scroll_data[270];

// struct for Vdp2 part that shouldn't be saved
typedef struct {
   int disptoggle;
} Vdp2External_struct;

extern Vdp2External_struct Vdp2External;

int Vdp2Init(void);
void Vdp2DeInit(void);
void Vdp2Reset(void);
void Vdp2VBlankIN(void);
void Vdp2HBlankIN(void);
void Vdp2HBlankOUT(void);
void Vdp2VBlankOUT(void);
void Vdp2SendExternalLatch(int hcnt, int vcnt);
void SpeedThrottleEnable(void);
void SpeedThrottleDisable(void);

u8 FASTCALL     Vdp2ReadByte(u32);
u16 FASTCALL    Vdp2ReadWord(u32);
u32 FASTCALL    Vdp2ReadLong(u32);
void FASTCALL   Vdp2WriteByte(u32, u8);
void FASTCALL   Vdp2WriteWord(u32, u16);
void FASTCALL   Vdp2WriteLong(u32, u32);

int Vdp2SaveState(FILE *fp);
int Vdp2LoadState(FILE *fp, int version, int size);

void ToggleNBG0(void);
void ToggleNBG1(void);
void ToggleNBG2(void);
void ToggleNBG3(void);
void ToggleRBG0(void);
void ToggleFullScreen(void);
void EnableAutoFrameSkip(void);
void DisableAutoFrameSkip(void);

Vdp2 * Vdp2RestoreRegs(int line, Vdp2* lines);

#endif
