/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2004-2006 Theo Berkau
    Copyright 2006      Anders Montonen

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

/*! \file yabause.c
    \brief Yabause main emulation functions and interface for the ports
*/


#include <sys/types.h>
#ifdef WIN32
#include <windows.h>
#endif
#include <string.h>
#include "yabause.h"
#include "cheat.h"
#include "cs0.h"
#include "cs2.h"
#include "debug.h"
#include "error.h"
#include "memory.h"
#include "m68kcore.h"
#include "peripheral.h"
#include "scsp.h"
#include "scspdsp.h"
#include "scu.h"
#include "sh2core.h"
#include "smpc.h"
#include "vidsoft.h"
#include "vdp2.h"
#include "yui.h"
#include "bios.h"
#include "movie.h"
#include "osdcore.h"
#ifdef HAVE_LIBSDL
#if defined(__APPLE__) || defined(GEKKO)
 #ifdef HAVE_LIBSDL2
  #include <SDL2/SDL.h>
 #else
  #include <SDL/SDL.h>
 #endif
#else
 #include "SDL.h"
#endif
#endif
#if defined(_MSC_VER) || !defined(HAVE_SYS_TIME_H)
#include <time.h>
#else
#include <sys/time.h>
#endif
#ifdef _arch_dreamcast
#include <arch/timer.h>
#endif
#ifdef GEKKO
#include <ogc/lwp_watchdog.h>
#endif
#ifdef PSP
#include "psp/common.h"
#endif

#ifdef SYS_PROFILE_H
 #include SYS_PROFILE_H
#else
 #define DONT_PROFILE
 #include "profile.h"
#endif

#if defined(SH2_DYNAREC)
#include "sh2_dynarec/sh2_dynarec.h"
#endif

#if HAVE_GDBSTUB
    #include "gdb/stub.h"
#endif

#ifdef YAB_WANT_SSF
#include "aosdk/ssf.h"
#endif

//////////////////////////////////////////////////////////////////////////////

yabsys_struct yabsys;
const char *bupfilename = NULL;
u64 tickfreq;
//todo this ought to be in scspdsp.c
ScspDsp scsp_dsp = { 0 };
char ssf_track_name[256] = { 0 };
char ssf_artist[256] = { 0 };

//////////////////////////////////////////////////////////////////////////////

#ifndef NO_CLI
void print_usage(const char *program_name) {
   printf("Yabause v" VERSION "\n");
   printf("\n"
          "Purpose:\n"
          "  This program is intended to be a Sega Saturn emulator\n"
          "\n"
          "Usage: %s [OPTIONS]...\n", program_name);
   printf("   -h         --help                 Print help and exit\n");
   printf("   -b STRING  --bios=STRING          bios file\n");
   printf("   -i STRING  --iso=STRING           iso/cue file\n");
   printf("   -c STRING  --cdrom=STRING         cdrom path\n");
   printf("   -ns        --nosound              turn sound off\n");
   printf("   -a         --autostart            autostart emulation\n");
   printf("   -f         --fullscreen           start in fullscreen mode\n");
}
#endif

//////////////////////////////////////////////////////////////////////////////

void YabauseChangeTiming(int freqtype) {
   // Setup all the variables related to timing

   const double freq_base = yabsys.IsPal ? 28437500.0
      : (39375000.0 / 11.0) * 8.0;  // i.e. 8 * 3.579545... = 28.636363... MHz
   const double freq_mult = (freqtype == CLKTYPE_26MHZ) ? 15.0/16.0 : 1.0;
   const double freq_shifted = (freq_base * freq_mult) * (1 << YABSYS_TIMING_BITS);
   const double usec_shifted = 1.0e6 * (1 << YABSYS_TIMING_BITS);
   const double deciline_time = yabsys.IsPal ? 1.0 /  50        / 313 / 10
                                             : 1.0 / (60/1.001) / 263 / 10;

   yabsys.DecilineCount = 0;
   yabsys.LineCount = 0;
   yabsys.CurSH2FreqType = freqtype;
   yabsys.DecilineStop = (u32) (freq_shifted * deciline_time + 0.5);
   yabsys.SH2CycleFrac = 0;
   yabsys.DecilineUsec = (u32) (usec_shifted * deciline_time + 0.5);
   yabsys.UsecFrac = 0;
}

//////////////////////////////////////////////////////////////////////////////

int YabauseInit(yabauseinit_struct *init)
{
   // Need to set this first, so init routines see it
   yabsys.UseThreads = init->usethreads;
   yabsys.NumThreads = init->numthreads;

   // Initialize both cpu's
   if (SH2Init(init->sh2coretype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("SH2"));
      return -1;
   }

   if ((BiosRom = T2MemoryInit(0x80000)) == NULL)
      return -1;

   if ((HighWram = T2MemoryInit(0x100000)) == NULL)
      return -1;

   if ((LowWram = T2MemoryInit(0x100000)) == NULL)
      return -1;

   if ((BupRam = T1MemoryInit(0x10000)) == NULL)
      return -1;

   if (LoadBackupRam(init->buppath) != 0)
      FormatBackupRam(BupRam, 0x10000);

   BupRamWritten = 0;

   bupfilename = init->buppath;

   if (CartInit(init->cartpath, init->carttype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("Cartridge"));
      return -1;
   }

   MappedMemoryInit();

   if (VideoInit(init->vidcoretype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("Video"));
      return -1;
   }

   // Initialize input core
   if (PerInit(init->percoretype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("Peripheral"));
      return -1;
   }

   if (Cs2Init(init->carttype, init->cdcoretype, init->cdpath, init->mpegpath, init->modemip, init->modemport) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("CS2"));
      return -1;
   }

   if (ScuInit() != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("SCU"));
      return -1;
   }

   if (M68KInit(init->m68kcoretype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("M68K"));
      return -1;
   }

   if (ScspInit(init->sndcoretype) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("SCSP/M68K"));
      return -1;
   }

   if (Vdp1Init() != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("VDP1"));
      return -1;
   }

   if (Vdp2Init() != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("VDP2"));
      return -1;
   }

   if (SmpcInit(init->regionid, init->clocksync, init->basetime) != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("SMPC"));
      return -1;
   }

   if (CheatInit() != 0)
   {
      YabSetError(YAB_ERR_CANNOTINIT, _("Cheat System"));
      return -1;
   }

   YabauseSetVideoFormat(init->videoformattype);
   YabauseChangeTiming(CLKTYPE_26MHZ);
   yabsys.DecilineMode = 1;

   if (init->frameskip)
      EnableAutoFrameSkip();

#ifdef YAB_PORT_OSD
   OSDChangeCore(init->osdcoretype);
#else
   OSDChangeCore(OSDCORE_DEFAULT);
#endif

   if (init->biospath != NULL && strlen(init->biospath))
   {
      if (LoadBios(init->biospath) != 0)
      {
         YabSetError(YAB_ERR_FILENOTFOUND, (void *)init->biospath);
         return -2;
      }
      yabsys.emulatebios = 0;
   }
   else
      yabsys.emulatebios = 1;

   yabsys.usequickload = 0;

   #if defined(SH2_DYNAREC)
   if(SH2Core->id==2) {
     sh2_dynarec_init();
   }
   #endif

   YabauseResetNoLoad();

#ifdef YAB_WANT_SSF

   if (init->play_ssf && init->ssfpath != NULL && strlen(init->ssfpath))
   {
      if (!load_ssf((char*)init->ssfpath, init->m68kcoretype, init->sndcoretype))
      {
         YabSetError(YAB_ERR_FILENOTFOUND, (void *)init->ssfpath);

         yabsys.playing_ssf = 0;

         return -2;
      }

      yabsys.playing_ssf = 1;

      get_ssf_info(1, ssf_track_name);
      get_ssf_info(3, ssf_artist);

      return 0;
   }
   else
      yabsys.playing_ssf = 0;

#endif

   if (init->skip_load)
   {
	   return 0;
   }

   if (yabsys.usequickload || yabsys.emulatebios)
   {
      if (YabauseQuickLoadGame() != 0)
      {
         if (yabsys.emulatebios)
         {
            YabSetError(YAB_ERR_CANNOTINIT, _("Game"));
            return -2;
         }
         else
            YabauseResetNoLoad();
      }
   }

#ifdef HAVE_GDBSTUB
   GdbStubInit(MSH2, 43434);
#endif

   if (yabsys.UseThreads)
   {
      int num = yabsys.NumThreads < 1 ? 1 : yabsys.NumThreads;
      VIDSoftSetVdp1ThreadEnable(num == 1 ? 0 : 1);
      VIDSoftSetNumLayerThreads(num);
      VIDSoftSetNumPriorityThreads(num);
   }
   else
   {
      VIDSoftSetVdp1ThreadEnable(0);
      VIDSoftSetNumLayerThreads(0);
      VIDSoftSetNumPriorityThreads(0);
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void YabFlushBackups(void)
{
   if (BupRam)
   {
      if (T123Save(BupRam, 0x10000, 1, bupfilename) != 0)
         YabSetError(YAB_ERR_FILEWRITE, (void *)bupfilename);
   }

   CartFlush();
}

//////////////////////////////////////////////////////////////////////////////

void YabauseDeInit(void) {
   SH2DeInit();

   if (BiosRom)
      T2MemoryDeInit(BiosRom);
   BiosRom = NULL;

   if (HighWram)
      T2MemoryDeInit(HighWram);
   HighWram = NULL;

   if (LowWram)
      T2MemoryDeInit(LowWram);
   LowWram = NULL;

   if (BupRam)
   {
      if (T123Save(BupRam, 0x10000, 1, bupfilename) != 0)
         YabSetError(YAB_ERR_FILEWRITE, (void *)bupfilename);

      T1MemoryDeInit(BupRam);
   }
   BupRam = NULL;

   CartDeInit();
   Cs2DeInit();
   ScuDeInit();
   ScspDeInit();
   Vdp1DeInit();
   Vdp2DeInit();
   SmpcDeInit();
   PerDeInit();
   VideoDeInit();
   CheatDeInit();
}

//////////////////////////////////////////////////////////////////////////////

void YabauseSetDecilineMode(int on) {
   yabsys.DecilineMode = (on != 0);
}

//////////////////////////////////////////////////////////////////////////////

void YabauseResetNoLoad(void) {
   SH2Reset(MSH2);
   YabauseStopSlave();
   memset(HighWram, 0, 0x100000);
   memset(LowWram, 0, 0x100000);

   // Reset CS0 area here
   // Reset CS1 area here
   Cs2Reset();
   ScuReset();
   ScspReset();
   Vdp1Reset();
   Vdp2Reset();
   SmpcReset();

   SH2PowerOn(MSH2);
}

//////////////////////////////////////////////////////////////////////////////

void YabauseReset(void) {

   if (yabsys.playing_ssf)
      yabsys.playing_ssf = 0;

   YabauseResetNoLoad();

   if (yabsys.usequickload || yabsys.emulatebios)
   {
      if (YabauseQuickLoadGame() != 0)
      {
         if (yabsys.emulatebios)
            YabSetError(YAB_ERR_CANNOTINIT, _("Game"));
         else
            YabauseResetNoLoad();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void YabauseResetButton(void) {
   // This basically emulates the reset button behaviour of the saturn. This
   // is the better way of reseting the system since some operations (like
   // backup ram access) shouldn't be interrupted and this allows for that.

   SmpcResetButton();
}

//////////////////////////////////////////////////////////////////////////////

int YabauseExec(void) {

	//automatically advance lag frames, this should be optional later
	if (FrameAdvanceVariable > 0 && LagFrameFlag == 1){
		FrameAdvanceVariable = NeedAdvance; //advance a frame
		YabauseEmulate();
		FrameAdvanceVariable = Paused; //pause next time
		return(0);
	}

	if (FrameAdvanceVariable == Paused){
		ScspMuteAudio(SCSP_MUTE_SYSTEM);
		return(0);
	}

	if (FrameAdvanceVariable == NeedAdvance){  //advance a frame
		FrameAdvanceVariable = Paused; //pause next time
		ScspUnMuteAudio(SCSP_MUTE_SYSTEM);
		YabauseEmulate();
	}

	if (FrameAdvanceVariable == RunNormal ) { //run normally
		ScspUnMuteAudio(SCSP_MUTE_SYSTEM);
		YabauseEmulate();
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////////
#ifndef USE_SCSP2
int saved_centicycles;
#endif

int YabauseEmulate(void) {
   int oneframeexec = 0;

   const u32 cyclesinc =
      yabsys.DecilineMode ? yabsys.DecilineStop : yabsys.DecilineStop * 10;
   const u32 usecinc =
      yabsys.DecilineMode ? yabsys.DecilineUsec : yabsys.DecilineUsec * 10;
#ifndef USE_SCSP2
   unsigned int m68kcycles;       // Integral M68k cycles per call
   unsigned int m68kcenticycles;  // 1/100 M68k cycles per call

   if (yabsys.IsPal)
   {
      /* 11.2896MHz / 50Hz / 313 lines / 10 calls/line = 72.20 cycles/call */
      m68kcycles = yabsys.DecilineMode ? 72 : 722;
      m68kcenticycles = yabsys.DecilineMode ? 20 : 0;
   }
   else
   {
      /* 11.2896MHz / 60Hz / 263 lines / 10 calls/line = 71.62 cycles/call */
      m68kcycles = yabsys.DecilineMode ? 71 : 716;
      m68kcenticycles = yabsys.DecilineMode ? 62 : 20;
   }
#endif

   DoMovie();

   #if defined(SH2_DYNAREC)
   if(SH2Core->id==2) {
     if (yabsys.IsPal)
       YabauseDynarecOneFrameExec(722,0); // m68kcycles,m68kcenticycles
     else
       YabauseDynarecOneFrameExec(716,20);
     return 0;
   }
   #endif

   while (!oneframeexec)
   {
      PROFILE_START("Total Emulation");

      if (yabsys.DecilineMode) {

         // Since we run the SCU with half the number of cycles we send
         // to SH2Exec(), we always compute an even number of cycles here
         // and leave any odd remainder in SH2CycleFrac.
         u32 sh2cycles;
         yabsys.SH2CycleFrac += cyclesinc;
         sh2cycles = (yabsys.SH2CycleFrac >> (YABSYS_TIMING_BITS + 1)) << 1;
         yabsys.SH2CycleFrac &= ((YABSYS_TIMING_MASK << 1) | 1);

         if (!yabsys.playing_ssf)
         {
            PROFILE_START("MSH2");
            SH2Exec(MSH2, sh2cycles);
            PROFILE_STOP("MSH2");

            PROFILE_START("SSH2");
            if (yabsys.IsSSH2Running)
               SH2Exec(SSH2, sh2cycles);
            PROFILE_STOP("SSH2");
         }

#ifdef USE_SCSP2
         PROFILE_START("SCSP");
         ScspExec(1);
         PROFILE_STOP("SCSP");
#endif

         yabsys.DecilineCount++;
         if(yabsys.DecilineCount == 9)
         {
            // HBlankIN
            PROFILE_START("hblankin");
            Vdp2HBlankIN();
            PROFILE_STOP("hblankin");
         }

         PROFILE_START("SCU");
         ScuExec(sh2cycles / 2);
         PROFILE_STOP("SCU");

      } else {  // !DecilineMode

         const u32 decilinecycles = yabsys.DecilineStop >> YABSYS_TIMING_BITS;
         u32 sh2cycles;
         yabsys.SH2CycleFrac += cyclesinc;
         sh2cycles = (yabsys.SH2CycleFrac >> (YABSYS_TIMING_BITS + 1)) << 1;
         yabsys.SH2CycleFrac &= ((YABSYS_TIMING_MASK << 1) | 1);
         if (!yabsys.playing_ssf)
         {
            PROFILE_START("MSH2");
            SH2Exec(MSH2, sh2cycles - decilinecycles);
            PROFILE_STOP("MSH2");
            PROFILE_START("SSH2");
            if (yabsys.IsSSH2Running)
               SH2Exec(SSH2, sh2cycles - decilinecycles);
            PROFILE_STOP("SSH2");
         }

         PROFILE_START("hblankin");
         Vdp2HBlankIN();
         PROFILE_STOP("hblankin");

         if (!yabsys.playing_ssf)
         {
            PROFILE_START("MSH2");
            SH2Exec(MSH2, decilinecycles);
            PROFILE_STOP("MSH2");
            PROFILE_START("SSH2");
            if (yabsys.IsSSH2Running)
               SH2Exec(SSH2, decilinecycles);
            PROFILE_STOP("SSH2");
         }

#ifdef USE_SCSP2
         PROFILE_START("SCSP");
         ScspExec(10);
         PROFILE_STOP("SCSP");
#endif

         PROFILE_START("SCU");
         ScuExec(sh2cycles / 2);
         PROFILE_STOP("SCU");

      }  // if (yabsys.DecilineMode)

#ifndef USE_SCSP2
      PROFILE_START("68K");
      M68KSync();  // Wait for the previous iteration to finish
      PROFILE_STOP("68K");
#endif

      if (!yabsys.DecilineMode || yabsys.DecilineCount == 10)
      {
         // HBlankOUT
         PROFILE_START("hblankout");
         Vdp2HBlankOUT();
         PROFILE_STOP("hblankout");
#ifndef USE_SCSP2
         PROFILE_START("SCSP");
         ScspExec();
         PROFILE_STOP("SCSP");
#endif
         yabsys.DecilineCount = 0;
         yabsys.LineCount++;
         if (yabsys.LineCount == yabsys.VBlankLineCount)
         {
            PROFILE_START("vblankin");
            // VBlankIN
            SmpcINTBACKEnd();
            Vdp2VBlankIN();
            PROFILE_STOP("vblankin");
            CheatDoPatches();
         }
         else if (yabsys.LineCount == yabsys.MaxLineCount)
         {
            // VBlankOUT
            PROFILE_START("VDP1/VDP2");
            Vdp2VBlankOUT();
            yabsys.LineCount = 0;
            oneframeexec = 1;
            PROFILE_STOP("VDP1/VDP2");
         }
      }

      yabsys.UsecFrac += usecinc;
      PROFILE_START("SMPC");
      SmpcExec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      PROFILE_STOP("SMPC");
      PROFILE_START("CDB");
      Cs2Exec(yabsys.UsecFrac >> YABSYS_TIMING_BITS);
      PROFILE_STOP("CDB");
      yabsys.UsecFrac &= YABSYS_TIMING_MASK;

#ifndef USE_SCSP2
      {
         int cycles;

         PROFILE_START("68K");
         cycles = m68kcycles;
	 saved_centicycles += m68kcenticycles;
         if (saved_centicycles >= 100) {
            cycles++;
            saved_centicycles -= 100;
         }
         M68KExec(cycles);
         PROFILE_STOP("68K");
      }
#endif

      PROFILE_STOP("Total Emulation");
   }

#ifndef USE_SCSP2
   M68KSync();
#endif

#ifdef YAB_WANT_SSF

   if (yabsys.playing_ssf)
   {
      OSDPushMessage(OSDMSG_FPS, 1, "NAME %s", ssf_track_name);
      OSDPushMessage(OSDMSG_STATUS, 1, "ARTIST %s", ssf_artist);
   }

#endif

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void YabauseStartSlave(void) {
   if (yabsys.emulatebios)
   {
      CurrentSH2 = SSH2;
      MappedMemoryWriteLong(0xFFFFFFE0, 0xA55A03F1); // BCR1
      MappedMemoryWriteLong(0xFFFFFFE4, 0xA55A00FC); // BCR2
      MappedMemoryWriteLong(0xFFFFFFE8, 0xA55A5555); // WCR
      MappedMemoryWriteLong(0xFFFFFFEC, 0xA55A0070); // MCR

      MappedMemoryWriteWord(0xFFFFFEE0, 0x0000); // ICR
      MappedMemoryWriteWord(0xFFFFFEE2, 0x0000); // IPRA
      MappedMemoryWriteWord(0xFFFFFE60, 0x0F00); // VCRWDT
      MappedMemoryWriteWord(0xFFFFFE62, 0x6061); // VCRA
      MappedMemoryWriteWord(0xFFFFFE64, 0x6263); // VCRB
      MappedMemoryWriteWord(0xFFFFFE66, 0x6465); // VCRC
      MappedMemoryWriteWord(0xFFFFFE68, 0x6600); // VCRD
      MappedMemoryWriteWord(0xFFFFFEE4, 0x6869); // VCRWDT
      MappedMemoryWriteLong(0xFFFFFFA8, 0x0000006C); // VCRDMA1
      MappedMemoryWriteLong(0xFFFFFFA0, 0x0000006D); // VCRDMA0
      MappedMemoryWriteLong(0xFFFFFF0C, 0x0000006E); // VCRDIV
      MappedMemoryWriteLong(0xFFFFFE10, 0x00000081); // TIER
      CurrentSH2 = MSH2;

      SH2GetRegisters(SSH2, &SSH2->regs);
      SSH2->regs.R[15] = Cs2GetSlaveStackAdress();
      SSH2->regs.VBR = 0x06000400;
      SSH2->regs.PC = MappedMemoryReadLong(0x06000250);
      if (MappedMemoryReadLong(0x060002AC) != 0)
         SSH2->regs.R[15] = MappedMemoryReadLong(0x060002AC);
      SH2SetRegisters(SSH2, &SSH2->regs);
   }
   else
      SH2PowerOn(SSH2);

   yabsys.IsSSH2Running = 1;
}

//////////////////////////////////////////////////////////////////////////////

void YabauseStopSlave(void) {
   SH2Reset(SSH2);
   yabsys.IsSSH2Running = 0;
}

//////////////////////////////////////////////////////////////////////////////

u64 YabauseGetTicks(void) {
#ifdef WIN32
   u64 ticks;
   QueryPerformanceCounter((LARGE_INTEGER *)&ticks);
   return ticks;
#elif defined(_arch_dreamcast)
   return (u64) timer_ms_gettime64();
#elif defined(GEKKO)
   return gettime();
#elif defined(PSP)
   return sceKernelGetSystemTimeWide();
#elif defined(HAVE_GETTIMEOFDAY)
   struct timeval tv;
   gettimeofday(&tv, NULL);
   return (u64)tv.tv_sec * 1000000 + tv.tv_usec;
#elif defined(HAVE_LIBSDL)
   return (u64)SDL_GetTicks();
#endif
}

//////////////////////////////////////////////////////////////////////////////

void YabauseSetVideoFormat(int type) {
   yabsys.IsPal = type;
   yabsys.MaxLineCount = type ? 313 : 263;
#ifdef WIN32
   QueryPerformanceFrequency((LARGE_INTEGER *)&yabsys.tickfreq);
#elif defined(_arch_dreamcast)
   yabsys.tickfreq = 1000;
#elif defined(GEKKO)
   yabsys.tickfreq = secs_to_ticks(1);
#elif defined(PSP)
   yabsys.tickfreq = 1000000;
#elif defined(HAVE_GETTIMEOFDAY)
   yabsys.tickfreq = 1000000;
#elif defined(HAVE_LIBSDL)
   yabsys.tickfreq = 1000;
#endif
   yabsys.OneFrameTime =
      type ? (yabsys.tickfreq / 50) : (yabsys.tickfreq * 1001 / 60000);
   Vdp2Regs->TVSTAT = Vdp2Regs->TVSTAT | (type & 0x1);
   ScspChangeVideoFormat(type);
   YabauseChangeTiming(yabsys.CurSH2FreqType);
   lastticks = YabauseGetTicks();
}

//////////////////////////////////////////////////////////////////////////////

void YabauseSpeedySetup(void)
{
   u32 data;
   int i;

   if (yabsys.emulatebios)
      BiosInit();
   else
   {
      // Setup the vector table area, etc.(all bioses have it at 0x00000600-0x00000810)
      for (i = 0; i < 0x210; i+=4)
      {
         data = MappedMemoryReadLong(0x00000600+i);
         MappedMemoryWriteLong(0x06000000+i, data);
      }

      // Setup the bios function pointers, etc.(all bioses have it at 0x00000820-0x00001100)
      for (i = 0; i < 0x8E0; i+=4)
      {
         data = MappedMemoryReadLong(0x00000820+i);
         MappedMemoryWriteLong(0x06000220+i, data);
      }

      // I'm not sure this is really needed
      for (i = 0; i < 0x700; i+=4)
      {
         data = MappedMemoryReadLong(0x00001100+i);
         MappedMemoryWriteLong(0x06001100+i, data);
      }

      // Fix some spots in 0x06000210-0x0600032C area
      MappedMemoryWriteLong(0x06000234, 0x000002AC);
      MappedMemoryWriteLong(0x06000238, 0x000002BC);
      MappedMemoryWriteLong(0x0600023C, 0x00000350);
      MappedMemoryWriteLong(0x06000240, 0x32524459);
      MappedMemoryWriteLong(0x0600024C, 0x00000000);
      MappedMemoryWriteLong(0x06000268, MappedMemoryReadLong(0x00001344));
      MappedMemoryWriteLong(0x0600026C, MappedMemoryReadLong(0x00001348));
      MappedMemoryWriteLong(0x0600029C, MappedMemoryReadLong(0x00001354));
      MappedMemoryWriteLong(0x060002C4, MappedMemoryReadLong(0x00001104));
      MappedMemoryWriteLong(0x060002C8, MappedMemoryReadLong(0x00001108));
      MappedMemoryWriteLong(0x060002CC, MappedMemoryReadLong(0x0000110C));
      MappedMemoryWriteLong(0x060002D0, MappedMemoryReadLong(0x00001110));
      MappedMemoryWriteLong(0x060002D4, MappedMemoryReadLong(0x00001114));
      MappedMemoryWriteLong(0x060002D8, MappedMemoryReadLong(0x00001118));
      MappedMemoryWriteLong(0x060002DC, MappedMemoryReadLong(0x0000111C));
      MappedMemoryWriteLong(0x06000328, 0x000004C8);
      MappedMemoryWriteLong(0x0600032C, 0x00001800);

      // Fix SCU interrupts
      for (i = 0; i < 0x80; i+=4)
         MappedMemoryWriteLong(0x06000A00+i, 0x0600083C);
   }

   // Set the cpu's, etc. to sane states

   // Set CD block to a sane state
   Cs2Area->reg.HIRQ = 0xFC1;
   Cs2Area->isdiskchanged = 0;
   Cs2Area->reg.CR1 = (Cs2Area->status << 8) | ((Cs2Area->options & 0xF) << 4) | (Cs2Area->repcnt & 0xF);
   Cs2Area->reg.CR2 = (Cs2Area->ctrladdr << 8) | Cs2Area->track;
   Cs2Area->reg.CR3 = (Cs2Area->index << 8) | ((Cs2Area->FAD >> 16) & 0xFF);
   Cs2Area->reg.CR4 = (u16) Cs2Area->FAD;
   Cs2Area->satauth = 4;

   // Set Master SH2 registers accordingly
   SH2GetRegisters(MSH2, &MSH2->regs);
   for (i = 0; i < 15; i++)
      MSH2->regs.R[i] = 0x00000000;
   MSH2->regs.R[15] = 0x06002000;
   MSH2->regs.SR.all = 0x00000000;
   MSH2->regs.GBR = 0x00000000;
   MSH2->regs.VBR = 0x06000000;
   MSH2->regs.MACH = 0x00000000;
   MSH2->regs.MACL = 0x00000000;
   MSH2->regs.PR = 0x00000000;
   SH2SetRegisters(MSH2, &MSH2->regs);

   // Set SCU registers to sane states
   ScuRegs->D1AD = ScuRegs->D2AD = 0;
   ScuRegs->D0EN = 0x101;
   ScuRegs->IST = 0x2006;
   ScuRegs->AIACK = 0x1;
   ScuRegs->ASR0 = ScuRegs->ASR1 = 0x1FF01FF0;
   ScuRegs->AREF = 0x1F;
   ScuRegs->RSEL = 0x1;

   // Set SMPC registers to sane states
   SmpcRegs->COMREG = 0x10;
   SmpcInternalVars->resd = 0;

   // Set VDP1 registers to sane states
   Vdp1Regs->EDSR = 3;
   Vdp1Regs->localX = 160;
   Vdp1Regs->localY = 112;
   Vdp1Regs->systemclipX2 = 319;
   Vdp1Regs->systemclipY2 = 223;

   // Set VDP2 registers to sane states
   memset(Vdp2Regs, 0, sizeof(Vdp2));
   Vdp2Regs->TVMD = 0x8000;
   Vdp2Regs->TVSTAT = 0x020A;
   Vdp2Regs->CYCA0L = 0x0F44;
   Vdp2Regs->CYCA0U = 0xFFFF;
   Vdp2Regs->CYCA1L = 0xFFFF;
   Vdp2Regs->CYCA1U = 0xFFFF;
   Vdp2Regs->CYCB0L = 0xFFFF;
   Vdp2Regs->CYCB0U = 0xFFFF;
   Vdp2Regs->CYCB1L = 0xFFFF;
   Vdp2Regs->CYCB1U = 0xFFFF;
   Vdp2Regs->BGON = 0x0001;
   Vdp2Regs->PNCN0 = 0x8000;
   Vdp2Regs->MPABN0 = 0x0303;
   Vdp2Regs->MPCDN0 = 0x0303;
   Vdp2Regs->ZMXN0.all = 0x00010000;
   Vdp2Regs->ZMYN0.all = 0x00010000;
   Vdp2Regs->ZMXN1.all = 0x00010000;
   Vdp2Regs->ZMYN1.all = 0x00010000;
   Vdp2Regs->BKTAL = 0x4000;
   Vdp2Regs->SPCTL = 0x0020;
   Vdp2Regs->PRINA = 0x0007;
   Vdp2Regs->CLOFEN = 0x0001;
   Vdp2Regs->COAR = 0x0200;
   Vdp2Regs->COAG = 0x0200;
   Vdp2Regs->COAB = 0x0200;
}

//////////////////////////////////////////////////////////////////////////////

int YabauseQuickLoadGame(void)
{
   partition_struct * lgpartition;
   u8 *buffer;
   u32 addr;
   u32 size;
   u32 blocks;
   unsigned int i, i2;
   dirrec_struct dirrec;

   Cs2Area->outconcddev = Cs2Area->filter + 0;
   Cs2Area->outconcddevnum = 0;

   // read in lba 0/FAD 150
   if ((lgpartition = Cs2ReadUnFilteredSector(150)) == NULL)
      return -1;

   // Make sure we're dealing with a saturn game
   buffer = lgpartition->block[lgpartition->numblocks - 1]->data;

   YabauseSpeedySetup();

   if (memcmp(buffer, "SEGA SEGASATURN", 15) == 0)
   {
      // figure out how many more sectors we need to read
      size = (buffer[0xE0] << 24) |
             (buffer[0xE1] << 16) |
             (buffer[0xE2] << 8) |
              buffer[0xE3];
      blocks = size >> 11;
      if ((size % 2048) != 0)
         blocks++;


      // Figure out where to load the first program
      addr = (buffer[0xF0] << 24) |
             (buffer[0xF1] << 16) |
             (buffer[0xF2] << 8) |
              buffer[0xF3];

      // Free Block
      lgpartition->size = 0;
      Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
      lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
      lgpartition->numblocks = 0;

      // Copy over ip to 0x06002000
      for (i = 0; i < blocks; i++)
      {
         if ((lgpartition = Cs2ReadUnFilteredSector(150+i)) == NULL)
            return -1;

         buffer = lgpartition->block[lgpartition->numblocks - 1]->data;

         if (size >= 2048)
         {
            for (i2 = 0; i2 < 2048; i2++)
               MappedMemoryWriteByte(0x06002000 + (i * 0x800) + i2, buffer[i2]);
         }
         else
         {
            for (i2 = 0; i2 < size; i2++)
               MappedMemoryWriteByte(0x06002000 + (i * 0x800) + i2, buffer[i2]);
         }

         size -= 2048;

         // Free Block
         lgpartition->size = 0;
         Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
         lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
         lgpartition->numblocks = 0;
      }

      SH2WriteNotify(0x6002000, blocks<<11);

      // Ok, now that we've loaded the ip, now it's time to load the
      // First Program

      // Figure out where the first program is located
      if ((lgpartition = Cs2ReadUnFilteredSector(166)) == NULL)
         return -1;

      // Figure out root directory's location

      // Retrieve directory record's lba
      Cs2CopyDirRecord(lgpartition->block[lgpartition->numblocks - 1]->data + 0x9C, &dirrec);

      // Free Block
      lgpartition->size = 0;
      Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
      lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
      lgpartition->numblocks = 0;

      // Now then, fetch the root directory's records
      if ((lgpartition = Cs2ReadUnFilteredSector(dirrec.lba+150)) == NULL)
         return -1;

      buffer = lgpartition->block[lgpartition->numblocks - 1]->data;

      // Skip the first two records, read in the last one
      for (i = 0; i < 3; i++)
      {
         Cs2CopyDirRecord(buffer, &dirrec);
         buffer += dirrec.recordsize;
      }

      size = dirrec.size;
      blocks = size >> 11;
      if ((dirrec.size % 2048) != 0)
         blocks++;

      // Free Block
      lgpartition->size = 0;
      Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
      lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
      lgpartition->numblocks = 0;

      // Copy over First Program to addr
      for (i = 0; i < blocks; i++)
      {
         if ((lgpartition = Cs2ReadUnFilteredSector(150+dirrec.lba+i)) == NULL)
            return -1;

         buffer = lgpartition->block[lgpartition->numblocks - 1]->data;

         if (size >= 2048)
         {
            for (i2 = 0; i2 < 2048; i2++)
               MappedMemoryWriteByte(addr + (i * 0x800) + i2, buffer[i2]);
         }
         else
         {
            for (i2 = 0; i2 < size; i2++)
               MappedMemoryWriteByte(addr + (i * 0x800) + i2, buffer[i2]);
         }

         size -= 2048;

         // Free Block
         lgpartition->size = 0;
         Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
         lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
         lgpartition->numblocks = 0;
      }

      SH2WriteNotify(addr, blocks<<11);

      // Now setup SH2 registers to start executing at ip code
      SH2GetRegisters(MSH2, &MSH2->regs);
      MSH2->regs.PC = 0x06002E00;
      MSH2->regs.R[15] = Cs2GetMasterStackAdress();
      SH2SetRegisters(MSH2, &MSH2->regs);
   }
   else
   {
      // Ok, we're not. Time to bail!

      // Free Block
      lgpartition->size = 0;
      Cs2FreeBlock(lgpartition->block[lgpartition->numblocks - 1]);
      lgpartition->blocknum[lgpartition->numblocks - 1] = 0xFF;
      lgpartition->numblocks = 0;

      return -1;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////
