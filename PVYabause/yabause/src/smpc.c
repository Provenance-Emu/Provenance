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

/*! \file smpc.c
    \brief SMPC emulation functions.
*/

#include <stdlib.h>
#include <time.h>
#include "smpc.h"
#include "cs2.h"
#include "debug.h"
#include "peripheral.h"
#include "scsp.h"
#include "scu.h"
#include "sh2core.h"
#include "vdp1.h"
#include "vdp2.h"
#include "yabause.h"
#include "movie.h"

#ifdef _arch_dreamcast
# include "dreamcast/localtime.h"
#endif
#if defined(PSP) && !defined(__LIBRETRO__)
# include "psp/localtime.h"
#endif

Smpc * SmpcRegs;
u8 * SmpcRegsT;
SmpcInternal * SmpcInternalVars;
int intback_wait_for_line = 0;

//////////////////////////////////////////////////////////////////////////////

int SmpcInit(u8 regionid, int clocksync, u32 basetime) {
   if ((SmpcRegsT = (u8 *) calloc(1, sizeof(Smpc))) == NULL)
      return -1;

   SmpcRegs = (Smpc *) SmpcRegsT;

   if ((SmpcInternalVars = (SmpcInternal *) calloc(1, sizeof(SmpcInternal))) == NULL)
      return -1;

   SmpcInternalVars->regionsetting = regionid;
   SmpcInternalVars->regionid = regionid;
   SmpcInternalVars->clocksync = clocksync;
   SmpcInternalVars->basetime = basetime ? basetime : time(NULL);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void SmpcDeInit(void) {
   if (SmpcRegsT)
      free(SmpcRegsT);
   SmpcRegsT = NULL;

   if (SmpcInternalVars)
      free(SmpcInternalVars);
   SmpcInternalVars = NULL;
}

//////////////////////////////////////////////////////////////////////////////

void SmpcRecheckRegion(void) {
   if (SmpcInternalVars == NULL)
      return;

   if (SmpcInternalVars->regionsetting == REGION_AUTODETECT)
   {
      // Time to autodetect the region using the cd block
      SmpcInternalVars->regionid = Cs2GetRegionID();

      // Since we couldn't detect the region from the CD, let's assume
      // it's japanese
      if (SmpcInternalVars->regionid == 0)
         SmpcInternalVars->regionid = 1;
   }
   else
      Cs2GetIP(0);
}

//////////////////////////////////////////////////////////////////////////////

void SmpcReset(void) {
   memset((void *)SmpcRegs, 0, sizeof(Smpc));
   memset((void *)SmpcInternalVars->SMEM, 0, 4);

   SmpcRecheckRegion();

   SmpcInternalVars->dotsel = 0;
   SmpcInternalVars->mshnmi = 0;
   SmpcInternalVars->sysres = 0;
   SmpcInternalVars->sndres = 0;
   SmpcInternalVars->cdres = 0;
   SmpcInternalVars->resd = 1;
   SmpcInternalVars->ste = 0;
   SmpcInternalVars->resb = 0;

   SmpcInternalVars->intback=0;
   SmpcInternalVars->intbackIreg0=0;
   SmpcInternalVars->firstPeri=0;

   SmpcInternalVars->timing=0;

   memset((void *)&SmpcInternalVars->port1, 0, sizeof(PortData_struct));
   memset((void *)&SmpcInternalVars->port2, 0, sizeof(PortData_struct));
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSSHON(void) {
   YabauseStartSlave();
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSSHOFF(void) {
   YabauseStopSlave();
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSNDON(void) {
   M68KStart();
   SmpcRegs->OREG[31] = 0x6;
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSNDOFF(void) {
   M68KStop();
   SmpcRegs->OREG[31] = 0x7;
}

//////////////////////////////////////////////////////////////////////////////

void SmpcCKCHG352(void) {
   // Reset VDP1, VDP2, SCU, and SCSP
   Vdp1Reset();
   Vdp2Reset();
   ScuReset();
   ScspReset();

   // Clear VDP1/VDP2 ram

   YabauseStopSlave();

   // change clock
   YabauseChangeTiming(CLKTYPE_28MHZ);

   // Set DOTSEL
   SmpcInternalVars->dotsel = 1;

   // Send NMI
   SH2NMI(MSH2);
}

//////////////////////////////////////////////////////////////////////////////

void SmpcCKCHG320(void) {
   // Reset VDP1, VDP2, SCU, and SCSP
   Vdp1Reset();
   Vdp2Reset();
   ScuReset();
   ScspReset();

   // Clear VDP1/VDP2 ram

   YabauseStopSlave();

   // change clock
   YabauseChangeTiming(CLKTYPE_26MHZ);

   // Set DOTSEL
   SmpcInternalVars->dotsel = 0;

   // Send NMI
   SH2NMI(MSH2);
}

struct movietime {

	int tm_year;
	int tm_wday;
	int tm_mon;
	int tm_mday;
	int tm_hour;
	int tm_min;
	int tm_sec;
};

static struct movietime movietime;
int totalseconds;
int noon= 43200;

//////////////////////////////////////////////////////////////////////////////

static void SmpcINTBACKStatus(void) {
   // return time, cartidge, zone, etc. data
   int i;
   struct tm times;
   u8 year[4];
   time_t tmp;

   SmpcRegs->OREG[0] = 0x80 | (SmpcInternalVars->resd << 6);   // goto normal startup
   //SmpcRegs->OREG[0] = 0x0 | (SmpcInternalVars->resd << 6);  // goto setclock/setlanguage screen

   // write time data in OREG1-7
   if (SmpcInternalVars->clocksync) {
      tmp = SmpcInternalVars->basetime + ((u64)framecounter * 1001 / 60000);
   } else {
      tmp = time(NULL);
   }
#ifdef WIN32
   memcpy(&times, localtime(&tmp), sizeof(times));
#elif defined(__CELLOS_LV2__)
   memcpy(&times, localtime(&tmp), sizeof(times));
#elif defined(_arch_dreamcast) || defined(PSP) && !defined(__LIBRETRO__)
   internal_localtime_r(&tmp, &times);
#else
   localtime_r(&tmp, &times);
#endif
   year[0] = (1900 + times.tm_year) / 1000;
   year[1] = ((1900 + times.tm_year) % 1000) / 100;
   year[2] = (((1900 + times.tm_year) % 1000) % 100) / 10;
   year[3] = (((1900 + times.tm_year) % 1000) % 100) % 10;
   SmpcRegs->OREG[1] = (year[0] << 4) | year[1];
   SmpcRegs->OREG[2] = (year[2] << 4) | year[3];
   SmpcRegs->OREG[3] = (times.tm_wday << 4) | (times.tm_mon + 1);
   SmpcRegs->OREG[4] = ((times.tm_mday / 10) << 4) | (times.tm_mday % 10);
   SmpcRegs->OREG[5] = ((times.tm_hour / 10) << 4) | (times.tm_hour % 10);
   SmpcRegs->OREG[6] = ((times.tm_min / 10) << 4) | (times.tm_min % 10);
   SmpcRegs->OREG[7] = ((times.tm_sec / 10) << 4) | (times.tm_sec % 10);

   if(Movie.Status == Recording || Movie.Status == Playback) {
	   movietime.tm_year=0x62;
	   movietime.tm_wday=0x04;
	   movietime.tm_mday=0x01;
	   movietime.tm_mon=0;
	   totalseconds = ((framecounter / 60) + noon);

	   movietime.tm_sec=totalseconds % 60;
	   movietime.tm_min=totalseconds/60;
	   movietime.tm_hour=movietime.tm_min/60;

	   //convert to sane numbers
	   movietime.tm_min=movietime.tm_min % 60;
	   movietime.tm_hour=movietime.tm_hour % 24;

	   year[0] = (1900 + movietime.tm_year) / 1000;
	   year[1] = ((1900 + movietime.tm_year) % 1000) / 100;
	   year[2] = (((1900 + movietime.tm_year) % 1000) % 100) / 10;
	   year[3] = (((1900 + movietime.tm_year) % 1000) % 100) % 10;
	   SmpcRegs->OREG[1] = (year[0] << 4) | year[1];
	   SmpcRegs->OREG[2] = (year[2] << 4) | year[3];
	   SmpcRegs->OREG[3] = (movietime.tm_wday << 4) | (movietime.tm_mon + 1);
	   SmpcRegs->OREG[4] = ((movietime.tm_mday / 10) << 4) | (movietime.tm_mday % 10);
	   SmpcRegs->OREG[5] = ((movietime.tm_hour / 10) << 4) | (movietime.tm_hour % 10);
	   SmpcRegs->OREG[6] = ((movietime.tm_min / 10) << 4) | (movietime.tm_min % 10);
	   SmpcRegs->OREG[7] = ((movietime.tm_sec / 10) << 4) | (movietime.tm_sec % 10);
   }

   // write cartidge data in OREG8
   SmpcRegs->OREG[8] = 0; // FIXME : random value

   // write zone data in OREG9 bits 0-7
   // 1 -> japan
   // 2 -> asia/ntsc
   // 4 -> north america
   // 5 -> central/south america/ntsc
   // 6 -> corea
   // A -> asia/pal
   // C -> europe + others/pal
   // D -> central/south america/pal
   SmpcRegs->OREG[9] = SmpcInternalVars->regionid;

   // system state, first part in OREG10, bits 0-7
   // bit | value  | comment
   // ---------------------------
   // 7   | 0      |
   // 6   | DOTSEL |
   // 5   | 1      |
   // 4   | 1      |
   // 3   | MSHNMI |
   // 2   | 1      |
   // 1   | SYSRES |
   // 0   | SNDRES |
   SmpcRegs->OREG[10] = 0x34|(SmpcInternalVars->dotsel<<6)|(SmpcInternalVars->mshnmi<<3)|(SmpcInternalVars->sysres<<1)|SmpcInternalVars->sndres;

   // system state, second part in OREG11, bit 6
   // bit 6 -> CDRES
   SmpcRegs->OREG[11] = SmpcInternalVars->cdres << 6; // FIXME

   // SMEM
   for(i = 0;i < 4;i++)
      SmpcRegs->OREG[12+i] = SmpcInternalVars->SMEM[i];

   SmpcRegs->OREG[31] = 0x10; // set to intback command
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcINTBACKPeripheral(void) {
  int oregoffset;
  PortData_struct *port1, *port2;

  if (SmpcInternalVars->firstPeri)
    SmpcRegs->SR = 0xC0 | (SmpcRegs->IREG[1] >> 4);
  else
    SmpcRegs->SR = 0x80 | (SmpcRegs->IREG[1] >> 4);

  SmpcInternalVars->firstPeri = 0;

  /* Port Status:
  0x04 - Sega-tap is connected
  0x16 - Multi-tap is connected
  0x21-0x2F - Clock serial peripheral is connected
  0xF0 - Not Connected or Unknown Device
  0xF1 - Peripheral is directly connected */

  /* PeripheralID:
  0x02 - Digital Device Standard Format
  0x13 - Racing Device Standard Format
  0x15 - Analog Device Standard Format
  0x23 - Pointing Device Standard Format
  0x23 - Shooting Device Standard Format
  0x34 - Keyboard Device Standard Format
  0xE1 - Mega Drive 3-Button Pad
  0xE2 - Mega Drive 6-Button Pad
  0xE3 - Saturn Mouse
  0xFF - Not Connected */

  /* Special Notes(for potential future uses):

  If a peripheral is disconnected from a port, you only return 1 byte for
  that port(which is the port status 0xF0), at the next OREG you then return
  the port status of the next port.

  e.g. If Port 1 has nothing connected, and Port 2 has a controller
       connected:

  OREG0 = 0xF0
  OREG1 = 0xF1
  OREG2 = 0x02
  etc.
  */

  oregoffset=0;

  if (SmpcInternalVars->port1.size == 0 && SmpcInternalVars->port2.size == 0)
  {
     // Request data from the Peripheral Interface
     port1 = &PORTDATA1;
     port2 = &PORTDATA2;
     memcpy(&SmpcInternalVars->port1, port1, sizeof(PortData_struct));
     memcpy(&SmpcInternalVars->port2, port2, sizeof(PortData_struct));
     PerFlush(&PORTDATA1);
     PerFlush(&PORTDATA2);
     SmpcInternalVars->port1.offset = 0;
     SmpcInternalVars->port2.offset = 0;
     LagFrameFlag=0;
  }

  // Port 1
  if (SmpcInternalVars->port1.size > 0)
  {
     if ((SmpcInternalVars->port1.size-SmpcInternalVars->port1.offset) < 32)
     {
        memcpy(SmpcRegs->OREG, SmpcInternalVars->port1.data+SmpcInternalVars->port1.offset, SmpcInternalVars->port1.size-SmpcInternalVars->port1.offset);
        oregoffset += SmpcInternalVars->port1.size-SmpcInternalVars->port1.offset;
        SmpcInternalVars->port1.size = 0;
     }
     else
     {
        memcpy(SmpcRegs->OREG, SmpcInternalVars->port1.data, 32);
        oregoffset += 32;
        SmpcInternalVars->port1.offset += 32;
     }
  }
  // Port 2
  if (SmpcInternalVars->port2.size > 0 && oregoffset < 32)
  {
     if ((SmpcInternalVars->port2.size-SmpcInternalVars->port2.offset) < (32 - oregoffset))
     {
        memcpy(SmpcRegs->OREG + oregoffset, SmpcInternalVars->port2.data+SmpcInternalVars->port2.offset, SmpcInternalVars->port2.size-SmpcInternalVars->port2.offset);
        SmpcInternalVars->port2.size = 0;
     }
     else
     {
        memcpy(SmpcRegs->OREG + oregoffset, SmpcInternalVars->port2.data, 32 - oregoffset);
        SmpcInternalVars->port2.offset += 32 - oregoffset;
     }
  }

/*
  Use this as a reference for implementing other peripherals
  // Port 1
  SmpcRegs->OREG[0] = 0xF1; //Port Status(Directly Connected)
  SmpcRegs->OREG[1] = 0xE3; //PeripheralID(Shuttle Mouse)
  SmpcRegs->OREG[2] = 0x00; //First Data
  SmpcRegs->OREG[3] = 0x00; //Second Data
  SmpcRegs->OREG[4] = 0x00; //Third Data

  // Port 2
  SmpcRegs->OREG[5] = 0xF0; //Port Status(Not Connected)
*/
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcINTBACK(void) {
   SmpcRegs->SF = 1;

   if (SmpcInternalVars->intback) {
      SmpcINTBACKPeripheral();
      ScuSendSystemManager();
      return;
   }

   //we think rayman sets 0x40 so that it breaks the intback command immediately when it blocks,
   //rather than having to set 0x40 in response to an interrupt
   if ((SmpcInternalVars->intbackIreg0 = (SmpcRegs->IREG[0] & 1))) {
      // Return non-peripheral data
      SmpcInternalVars->firstPeri = 1;
      SmpcInternalVars->intback = (SmpcRegs->IREG[1] & 0x8) >> 3; // does the program want peripheral data too?
      SmpcINTBACKStatus();
      SmpcRegs->SR = 0x4F | (SmpcInternalVars->intback << 5); // the low nibble is undefined(or 0xF)
      ScuSendSystemManager();
      return;
   }
   if (SmpcRegs->IREG[1] & 0x8) {
      SmpcInternalVars->firstPeri = 1;
      SmpcInternalVars->intback = 1;
      SmpcRegs->SR = 0x40;
      SmpcINTBACKPeripheral();
      SmpcRegs->OREG[31] = 0x10; // may need to be changed
      ScuSendSystemManager();
      return;
   }
}

//////////////////////////////////////////////////////////////////////////////

void SmpcINTBACKEnd(void) {
   SmpcInternalVars->intback = 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSETSMEM(void) {
   int i;

   for(i = 0;i < 4;i++)
      SmpcInternalVars->SMEM[i] = SmpcRegs->IREG[i];

   SmpcRegs->OREG[31] = 0x17;
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcNMIREQ(void) {
   SH2SendInterrupt(MSH2, 0xB, 16);
   SmpcRegs->OREG[31] = 0x18;
}

//////////////////////////////////////////////////////////////////////////////

void SmpcResetButton(void) {
   // If RESD isn't set, send an NMI request to the MSH2.
   if (SmpcInternalVars->resd)
      return;

   SH2SendInterrupt(MSH2, 0xB, 16);
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcRESENAB(void) {
  SmpcInternalVars->resd = 0;
  SmpcRegs->OREG[31] = 0x19;
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcRESDISA(void) {
  SmpcInternalVars->resd = 1;
  SmpcRegs->OREG[31] = 0x1A;
}

//////////////////////////////////////////////////////////////////////////////
void SmpcExec(s32 t) {
   if (SmpcInternalVars->timing > 0) {

      if (intback_wait_for_line)
      {
         if (yabsys.LineCount == 207)
         {
            SmpcInternalVars->timing = -1;
            intback_wait_for_line = 0;
         }
      }
      SmpcInternalVars->timing -= t;
      if (SmpcInternalVars->timing <= 0) {
         switch(SmpcRegs->COMREG) {
            case 0x0:
               SMPCLOG("smpc\t: MSHON not implemented\n");
               break;
            case 0x2:
               SMPCLOG("smpc\t: SSHON\n");
               SmpcSSHON();
               break;
            case 0x3:
               SMPCLOG("smpc\t: SSHOFF\n");
               SmpcSSHOFF();
               break;
            case 0x6:
               SMPCLOG("smpc\t: SNDON\n");
               SmpcSNDON();
               break;
            case 0x7:
               SMPCLOG("smpc\t: SNDOFF\n");
               SmpcSNDOFF();
               break;
            case 0x8:
               SMPCLOG("smpc\t: CDON not implemented\n");
               break;
            case 0x9:
               SMPCLOG("smpc\t: CDOFF not implemented\n");
               break;
            case 0xD:
               SMPCLOG("smpc\t: SYSRES not implemented\n");
               break;
            case 0xE:
               SMPCLOG("smpc\t: CKCHG352\n");
               SmpcCKCHG352();
               break;
            case 0xF:
               SMPCLOG("smpc\t: CKCHG320\n");
               SmpcCKCHG320();
               break;
            case 0x10:
               SMPCLOG("smpc\t: INTBACK\n");
               SmpcINTBACK();
               break;
            case 0x17:
               SMPCLOG("smpc\t: SETSMEM\n");
               SmpcSETSMEM();
               break;
            case 0x18:
               SMPCLOG("smpc\t: NMIREQ\n");
               SmpcNMIREQ();
               break;
            case 0x19:
               SMPCLOG("smpc\t: RESENAB\n");
               SmpcRESENAB();
               break;
            case 0x1A:
               SMPCLOG("smpc\t: RESDISA\n");
               SmpcRESDISA();
               break;
            default:
               SMPCLOG("smpc\t: Command %02X not implemented\n", SmpcRegs->COMREG);
               break;
         }

         SmpcRegs->SF = 0;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

u8 FASTCALL SmpcReadByte(u32 addr) {
   addr &= 0x7F;
   return SmpcRegsT[addr >> 1];
}

//////////////////////////////////////////////////////////////////////////////

u16 FASTCALL SmpcReadWord(USED_IF_SMPC_DEBUG u32 addr) {
   // byte access only
   SMPCLOG("smpc\t: SMPC register read word - %08X\n", addr);
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 FASTCALL SmpcReadLong(USED_IF_SMPC_DEBUG u32 addr) {
   // byte access only
   SMPCLOG("smpc\t: SMPC register read long - %08X\n", addr);
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SmpcSetTiming(void) {
   switch(SmpcRegs->COMREG) {
      case 0x0:
         SMPCLOG("smpc\t: MSHON not implemented\n");
         SmpcInternalVars->timing = 1;
         return;
      case 0x8:
         SMPCLOG("smpc\t: CDON not implemented\n");
         SmpcInternalVars->timing = 1;
         return;
      case 0x9:
         SMPCLOG("smpc\t: CDOFF not implemented\n");
         SmpcInternalVars->timing = 1;
         return;
      case 0xD:
      case 0xE:
      case 0xF:
         SmpcInternalVars->timing = 1; // this has to be tested on a real saturn
         return;
      case 0x10:
         if (SmpcInternalVars->intback)//continue was issued
         {
            SmpcInternalVars->timing = 16000;
            intback_wait_for_line = 1;
         }
         else {
            // Calculate timing based on what data is being retrieved

            if ((SmpcRegs->IREG[0] == 0x01) && (SmpcRegs->IREG[1] & 0x8))
            {
               //status followed by peripheral data
               SmpcInternalVars->timing = 250;
            }
            else if ((SmpcRegs->IREG[0] == 0x01) && ((SmpcRegs->IREG[1] & 0x8) == 0))
            {
               //status only
               SmpcInternalVars->timing = 250;
            }
            else if ((SmpcRegs->IREG[0] == 0) && (SmpcRegs->IREG[1] & 0x8))
            {
               //peripheral only
             SmpcInternalVars->timing = 16000;
               intback_wait_for_line = 1;
            }
         }
         return;
      case 0x17:
         SmpcInternalVars->timing = 1;
         return;
      case 0x2:
         SmpcInternalVars->timing = 1;
         return;
      case 0x3:
         SmpcInternalVars->timing = 1;
         return;
      case 0x6:
      case 0x7:
      case 0x18:
      case 0x19:
      case 0x1A:
         SmpcInternalVars->timing = 1;
         return;
      default:
         SMPCLOG("smpc\t: unimplemented command: %02X\n", SmpcRegs->COMREG);
         SmpcRegs->SF = 0;
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL SmpcWriteByte(u32 addr, u8 val) {
   addr &= 0x7F;
   SmpcRegsT[addr >> 1] = val;

   switch(addr) {
      case 0x01: // Maybe an INTBACK continue/break request
         if (SmpcInternalVars->intback)
         {
            if (SmpcRegs->IREG[0] & 0x40) {
               // Break
               SmpcInternalVars->intback = 0;
               SmpcRegs->SR &= 0x0F;
               break;
            }
            else if (SmpcRegs->IREG[0] & 0x80) {
               // Continue
               SmpcRegs->COMREG = 0x10;
               SmpcSetTiming();
               SmpcRegs->SF = 1;
            }
         }
         return;
      case 0x1F:
         SmpcSetTiming();
         return;
      case 0x63:
         SmpcRegs->SF &= 0x1;
         return;
      case 0x75: // PDR1
         // FIX ME (should support other peripherals)
         switch (SmpcRegs->DDR[0] & 0x7F) { // Which Control Method do we use?
            case 0x00:
               if (PORTDATA1.data[1] == PERGUN && (val & 0x7F) == 0x7F)
                  SmpcRegs->PDR[0] = PORTDATA1.data[2];
               break;
            case 0x60:
               switch (val & 0x60) {
                  case 0x60: // 1st Data
                     val = (val & 0x80) | 0x14 | (PORTDATA1.data[3] & 0x8);
                     break;
                  case 0x20: // 2nd Data
                     val = (val & 0x80) | 0x10 | ((PORTDATA1.data[2] >> 4) & 0xF);
                     break;
                  case 0x40: // 3rd Data
                     val = (val & 0x80) | 0x10 | (PORTDATA1.data[2] & 0xF);
                     break;
                  case 0x00: // 4th Data
                     val = (val & 0x80) | 0x10 | ((PORTDATA1.data[3] >> 4) & 0xF);
                     break;
                  default: break;
               }

               SmpcRegs->PDR[0] = val;
               break;
            default:
               SMPCLOG("smpc\t: Peripheral Unknown Control Method not implemented\n");
               break;
         }
			break;
	  case 0x77: // PDR1
		  // FIX ME (should support other peripherals)
		  switch (SmpcRegs->DDR[1] & 0x7F) { // Which Control Method do we use?
		  case 0x00:
			  if (PORTDATA2.data[1] == PERGUN && (val & 0x7F) == 0x7F)
				  SmpcRegs->PDR[1] = PORTDATA2.data[2];
			  break;
		  case 0x60:
			  switch (val & 0x60) {
			  case 0x60: // 1st Data
				  val = (val & 0x80) | 0x14 | (PORTDATA2.data[3] & 0x8);
				  break;
			  case 0x20: // 2nd Data
				  val = (val & 0x80) | 0x10 | ((PORTDATA2.data[2] >> 4) & 0xF);
				  break;
			  case 0x40: // 3rd Data
				  val = (val & 0x80) | 0x10 | (PORTDATA2.data[2] & 0xF);
				  break;
			  case 0x00: // 4th Data
				  val = (val & 0x80) | 0x10 | ((PORTDATA2.data[3] >> 4) & 0xF);
				  break;
			  default: break;
			  }

			  SmpcRegs->PDR[1] = val;
			  break;
		  default:
			  SMPCLOG("smpc\t: Peripheral Unknown Control Method not implemented\n");
			  break;
		  }
		  break;
	  case 0x79: // DDR1
         switch (SmpcRegs->DDR[0] & 0x7F) { // Which Control Method do we use?
            case 0x00: // Low Nibble of Peripheral ID
            case 0x40: // High Nibble of Peripheral ID
               switch (PORTDATA1.data[0])
               {
                  case 0xA0:
                  {
                     if (PORTDATA1.data[1] == PERGUN)
                        SmpcRegs->PDR[0] = 0x7C;
                           break;
                  }
                  case 0xF0:
                     SmpcRegs->PDR[0] = 0x7F;
                     break;
                  case 0xF1:
                  {
                     switch(PORTDATA1.data[1])
                     {
                        case PERPAD:
                           SmpcRegs->PDR[0] = 0x7C;
                           break;
                        case PER3DPAD:
                        case PERKEYBOARD:
                           SmpcRegs->PDR[0] = 0x71;
                           break;
                        case PERMOUSE:
                           SmpcRegs->PDR[0] = 0x70;
                           break;
                        case PERWHEEL:
                        case PERMISSIONSTICK:
                        case PERTWINSTICKS:
                        default:
                           SMPCLOG("smpc\t: Peripheral TH Control Method not supported for peripherl id %02X\n", PORTDATA1.data[1]);
                           break;
                     }
                     break;
                  }
                  default:
                     SmpcRegs->PDR[0] = 0x71;
                     break;
               }

               break;
            default: break;
         }
         break;
	  case 0x7D: // IOSEL
		  SmpcRegs->IOSEL = val;
		  break;
	  case 0x7F: // EXLE
		  SmpcRegs->EXLE = val;
		  break;
      default:
         return;
   }
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL SmpcWriteWord(USED_IF_SMPC_DEBUG u32 addr, UNUSED u16 val) {
   // byte access only
   SMPCLOG("smpc\t: SMPC register write word - %08X\n", addr);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL SmpcWriteLong(USED_IF_SMPC_DEBUG u32 addr, UNUSED u32 val) {
   // byte access only
   SMPCLOG("smpc\t: SMPC register write long - %08X\n", addr);
}

//////////////////////////////////////////////////////////////////////////////

int SmpcSaveState(FILE *fp)
{
   int offset;
   IOCheck_struct check = { 0, 0 };

   offset = StateWriteHeader(fp, "SMPC", 3);

   // Write registers
   ywrite(&check, (void *)SmpcRegs->IREG, sizeof(u8), 7, fp);
   ywrite(&check, (void *)&SmpcRegs->COMREG, sizeof(u8), 1, fp);
   ywrite(&check, (void *)SmpcRegs->OREG, sizeof(u8), 32, fp);
   ywrite(&check, (void *)&SmpcRegs->SR, sizeof(u8), 1, fp);
   ywrite(&check, (void *)&SmpcRegs->SF, sizeof(u8), 1, fp);
   ywrite(&check, (void *)SmpcRegs->PDR, sizeof(u8), 2, fp);
   ywrite(&check, (void *)SmpcRegs->DDR, sizeof(u8), 2, fp);
   ywrite(&check, (void *)&SmpcRegs->IOSEL, sizeof(u8), 1, fp);
   ywrite(&check, (void *)&SmpcRegs->EXLE, sizeof(u8), 1, fp);

   // Write internal variables
   ywrite(&check, (void *)SmpcInternalVars, sizeof(SmpcInternal), 1, fp);

   // Write ID's of currently emulated peripherals(fix me)

   return StateFinishHeader(fp, offset);
}

//////////////////////////////////////////////////////////////////////////////

int SmpcLoadState(FILE *fp, int version, int size)
{
   IOCheck_struct check = { 0, 0 };
   int internalsizev2 = sizeof(SmpcInternal) - 8;

   // Read registers
   yread(&check, (void *)SmpcRegs->IREG, sizeof(u8), 7, fp);
   yread(&check, (void *)&SmpcRegs->COMREG, sizeof(u8), 1, fp);
   yread(&check, (void *)SmpcRegs->OREG, sizeof(u8), 32, fp);
   yread(&check, (void *)&SmpcRegs->SR, sizeof(u8), 1, fp);
   yread(&check, (void *)&SmpcRegs->SF, sizeof(u8), 1, fp);
   yread(&check, (void *)SmpcRegs->PDR, sizeof(u8), 2, fp);
   yread(&check, (void *)SmpcRegs->DDR, sizeof(u8), 2, fp);
   yread(&check, (void *)&SmpcRegs->IOSEL, sizeof(u8), 1, fp);
   yread(&check, (void *)&SmpcRegs->EXLE, sizeof(u8), 1, fp);

   // Read internal variables
   if (version == 1)
   {
      // This handles the problem caused by the version not being incremented
      // when SmpcInternal was changed
      if ((size - 48) == internalsizev2)
         yread(&check, (void *)SmpcInternalVars, internalsizev2, 1, fp);
      else if ((size - 48) == 24)
         yread(&check, (void *)SmpcInternalVars, 24, 1, fp);
      else
         fseek(fp, size - 48, SEEK_CUR);
   }
   else if (version == 2)
      yread(&check, (void *)SmpcInternalVars, internalsizev2, 1, fp);
   else
      yread(&check, (void *)SmpcInternalVars, sizeof(SmpcInternal), 1, fp);

   // Read ID's of currently emulated peripherals(fix me)

   return size;
}

//////////////////////////////////////////////////////////////////////////////

