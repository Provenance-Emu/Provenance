/*
    Copyright (C) 1999, 2000, 2001, 2002, 2003  Charles MacDonald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "shared.h"
#include "cart/cart.h"
#include "cd/cd.h"
#include <mednafen/hash/md5.h>
#include <mednafen/general.h>
#include <mednafen/mempatcher.h>

#include <trio/trio.h>

namespace MDFN_IEN_MD
{

enum
{
 REGION_SAME = 1,
 REGION_GAME,
 REGION_OVERSEAS_NTSC,
 REGION_OVERSEAS_PAL,
 REGION_DOMESTIC_NTSC,
 REGION_DOMESTIC_PAL
};


static const MDFNSetting_EnumList MultiTap_List[] =
{
 { "none", MTAP_NONE, gettext_noop("No multitap(s).") },

 { "tp1", MTAP_TP_PRT1, gettext_noop("Team Player/Sega Tap on MD/Genesis port 1.") },
 { "tp2", MTAP_TP_PRT2, gettext_noop("Team Player/Sega Tap on MD/Genesis port 2.") },
 { "tpd", MTAP_TP_DUAL, gettext_noop("Team Player/Sega Tap on both MD/Genesis ports.") },

 { "4way", MTAP_4WAY, gettext_noop("EA 4-Way Play") },

 { NULL, 0 },
};


int MD_HackyHackyMode = 0;
bool MD_IsCD;
static int32 z80_cycle_counter;
static int32 z80_last_ts;
int32 md_timestamp;
static bool suspend68k = false;

static bool run_cpu;

void MD_Suspend68K(bool state)
{
 suspend68k = state;
 Main68K.SetExtHalted(state);
}

bool MD_Is68KSuspended(void)
{
 return(suspend68k);
}

static void system_init(bool overseas, bool PAL, bool overseas_reported, bool PAL_reported)
{
    gen_running = 1;

    z80_init();
    z80_readbyte = MD_Z80_ReadByte;
    z80_writebyte = MD_Z80_WriteByte;
    z80_readport = MD_Z80_ReadPort;
    z80_writeport = MD_Z80_WritePort;

    gen_init();
    MDIO_Init(overseas, PAL, overseas_reported, PAL_reported);
    MainVDP.SetSettings(PAL, PAL_reported, MDFN_GetSettingB("md.correct_aspect"));

#ifdef WANT_DEBUGGER
    MDDBG_Init();
#endif

}

static void system_reset(bool poweron)
{
 obsim = 0;
 z80_cycle_counter = 0;
 z80_last_ts = 0;

 if(MD_IsCD)
  MDCD_Reset(poweron);
 else
  MDCart_Reset();

 gen_reset(poweron);
 if(poweron)
  MainVDP.Reset();
 MDSound_Power();
}

void MD_ExitCPULoop(void)
{
 run_cpu = false;
}

void MD_UpdateSubStuff(void)
{
 int32 max_md_timestamp;

 max_md_timestamp = Main68K.timestamp * 7;

 if(zreset == 1 && zbusreq == 0)
 {
  z80_cycle_counter += max_md_timestamp - z80_last_ts;

  while(z80_cycle_counter > 0)
  {
   int32 z80_temp = z80_do_opcode() * 15;

   z80_cycle_counter -= z80_temp;
   md_timestamp += z80_temp;

   if(md_timestamp > max_md_timestamp)
   {
    //printf("Meow: %d\n", md_timestamp - max_md_timestamp);
    md_timestamp = max_md_timestamp;
   }
   MainVDP.Run();
  }
 }
 z80_last_ts = max_md_timestamp;

 md_timestamp = max_md_timestamp;
 MainVDP.Run();

 //if(MD_IsCD)
 // MDCD_Run(master_cycles);
}

void MD_DBG(unsigned level, const char *format, ...) throw()
{
#if 0
 //if(md_dbg_level >= level)
 {
  va_list ap;

  va_start(ap, format);

  trio_vprintf(format, ap);

  va_end(ap);
 }
#endif
}


static int system_frame(int do_skip)
{
 run_cpu = true;

 while(run_cpu > 0)
 {
  #ifdef WANT_DEBUGGER
  if(MDFN_UNLIKELY(MD_DebugMode) && MDFN_UNLIKELY(!suspend68k))
   MDDBG_CPUHook();
  #endif

  Main68K.Step();
  MD_UpdateSubStuff();
 }
 return gen_running;
}

static void Emulate(EmulateSpecStruct *espec)
{
 //printf("%016llx %016llx %016llx\n", z80_tstates, last_z80_tstates, z80.interrupts_enabled_at);

 MDFNMP_ApplyPeriodicCheats();

 MDIO_BeginTimePeriod(md_timestamp);

 MDINPUT_Frame();

 if(espec->VideoFormatChanged)
  MainVDP.SetPixelFormat(espec->surface->format); //.Rshift, espec->surface->format.Gshift, espec->surface->format.Bshift);

 if(espec->SoundFormatChanged)
  MDSound_SetSoundRate(espec->SoundRate);

 MainVDP.SetSurface(espec);	//espec->surface, &espec->DisplayRect);

 system_frame(0);

 espec->MasterCycles = md_timestamp;

 espec->SoundBufSize = MDSound_Flush(espec->SoundBuf, espec->SoundBufMaxSize);

#if 0
 {
  static double avg = 0;
  static double s_avg = 0;

  avg += (espec->MasterCycles - avg) * 0.05;
  s_avg += (espec->SoundBufSize - s_avg) * 0.05;
  printf("%f, %f\n", avg / 262 / 10, 48000 / s_avg);
 }
#endif

 MDIO_EndTimePeriod(md_timestamp);

 md_timestamp = 0;
 z80_last_ts = 0;
 Main68K.timestamp = 0;
 MainVDP.ResetTS();

 //MainVDP.SetSurface(NULL);
}

static void Cleanup(void)
{
 MDCart_Kill();
 MDIO_Kill();

 MDSound_Kill();
}

static void CloseGame(void)
{
 try
 {
  MDCart_SaveNV();
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }

 Cleanup();
}

static const struct 
{
 const char* prod_code;
 uint32 crc32;
 bool compat_6button;
 unsigned tap;
 unsigned max_players;
}
InputDB[] =
{
 { NULL, 0x2c6cbd77, 		true, MTAP_TP_PRT1, 4 }, // Aq Renkan Awa (China) (Unl)
 { "MK-1234 -00", 0x8c822884, 	true, MTAP_TP_PRT1, 4 }, // ATP Tour Championship Tennis (USA)
 { "MK-1234 -50", 0x1a3da8c5, 	true, MTAP_TP_PRT1, 4 }, // ATP Tour (Europe)
 { "T-172106-01", 0xac5bc26a,	true, MTAP_4WAY,    4 }, // Australian Rugby League (Europe)
 { "T-119066-01", 0xde27357b, 	true, MTAP_TP_PRT1, 4 }, // Barkley Shut Up and Jam 2 (USA) (Beta)
 { "T-119186-00", 0x321bb6bd, 	true, MTAP_TP_PRT1, 4 }, // Barkley Shut Up and Jam 2 (USA)
 { "T-119066-00", 0x63fbf497, 	true, MTAP_TP_PRT1, 4 }, // Barkley Shut Up and Jam! (USA, Europe)
 { "T-50826 -00", 0xa582f45a, 	true, MTAP_4WAY,    4 }, // Bill Walsh College Football 95 (USA)
 { "T-50606 -00", 0x3ed83362, 	true, MTAP_4WAY,    4 }, // Bill Walsh College Football (USA, Europe)
 { "T-172016-00", 0x67c309c6,	true, MTAP_4WAY,    4 }, // Coach K College Basketball (USA)
 { "T-172046-00", 0xb9075385,	true, MTAP_4WAY,    4 }, // College Football USA 96 (USA)
 { "T-172126-01", 0x2ebb90a3,	true, MTAP_4WAY,    4 }, // College Football USA 97 (USA)
 { "MK-1241 -00", 0x65b64413, 	true, MTAP_TP_PRT1, 4 }, // College Football's National Championship II (USA)
 { "MK-1227 -00", 0x172c5dbb, 	true, MTAP_TP_PRT1, 4 }, // College Football's National Championship (USA)
 { "T-81576 -00", 0x96a42431, 	true, MTAP_TP_PRT1, 4 }, // College Slam (USA)
 { "T-23056 -00", 0xdc678f6d, 	true, MTAP_TP_PRT2, 5 }, // Columns III - Revenge of Columns (USA)
 { "00004801-00", 0xcd07462f, 	true, MTAP_TP_PRT2, 5 }, // Columns III - Taiketsu! Columns World (Japan, Korea)
 { "T-70276-00", 0x4608f53a,	true, MTAP_TP_PRT2, 4 }, // Dino Dini's Soccer (Europe)
 /* Can support dual multitap, *BUT* Some game modes are incompatible with multitap
 { "T-95126-00", 0x8352b1d0, 	true, * }, // Double Dribble - The Playoff Edition (USA)
 */
 { "T-70286 -00", 0xfdeed51d, 	true, MTAP_TP_PRT1, 3 }, // Dragon - The Bruce Lee Story (Europe)
 { "T-81496 -00", 0xefe850e5, 	true, MTAP_TP_PRT1, 3 }, // Dragon - The Bruce Lee Story (USA)
 { "T-50976 -00", 0xe10a25c0,	true, MTAP_4WAY,    4 }, // Elitserien 95 (Sweden)
 { "T-172096-00", 0x9821d0a3,	true, MTAP_4WAY,    4 }, // Elitserien 96 (Sweden)
 { NULL, 0xa427814a, 		true, MTAP_TP_PRT1, 4 }, // ESPN National Hockey Night (USA) (Beta)
 { "T-93176 -00", 0x1d08828c, 	true, MTAP_TP_PRT1, 4 }, // ESPN National Hockey Night (USA)
 { "T-79196-50", 0xfac29677, 	true, MTAP_TP_PRT1, 5 }, // Fever Pitch Soccer (Europe) (En,Fr,De,Es,It)
 { "T-172206-00", 0x96947f57,	true, MTAP_4WAY,    4 }, // FIFA 98 - Road to World Cup (Europe) (En,Fr,Es,It,Sv)
 { "T-50706 -00", 0xbddbb763,	true, MTAP_4WAY,    4 }, // FIFA International Soccer (USA, Europe) (En,Fr,De,Es)
 { "T-50916 -01", 0x012591f9,	true, MTAP_4WAY,    4 }, // FIFA Soccer 95 (Korea) (En,Fr,De,Es)
 { "T-50916 -00", 0xb389d036,	true, MTAP_4WAY,    4 }, // FIFA Soccer 95 (USA, Europe) (En,Fr,De,Es)
 { "T-172086-00", 0xbad30ffa,	true, MTAP_4WAY,    4 }, // FIFA Soccer 96 (USA, Europe) (En,Fr,De,Es,It,Sv)
 { "T-172156-01", 0xa33d5803,	true, MTAP_4WAY,    4 }, // FIFA Soccer 97 (USA, Europe) (En,Fr,De,Es,It,Sv)
 // Maybe port2? { "T-81476 -00", 0x863e0950, true, MTAP_TP_PRT1, 4 }, // Frank Thomas Big Hurt Baseball (USA, Europe)
 // Maybe port2? { "133037   -00", 0xcdf5678f, true, MTAP_TP_PRT1, 4 }, // From TV Animation Slam Dunk - Kyougou Makkou Taiketsu! (Japan)
 { "T-48216 -00", 0x3bf46dce, 	true, MTAP_TP_PRT1, 4 }, // Gauntlet IV (USA, Europe) (En,Ja) (August 1993)
 { "T-48123 -00", 0xf9d60510, 	true, MTAP_TP_PRT1, 4 }, // Gauntlet IV (USA, Europe) (En,Ja) (September 1993)
 { "T-48123 -00", 0xf9872055, 	true, MTAP_TP_PRT1, 4 }, // Gauntlet (Japan) (En,Ja)
 { "T-106253-00", 0x05cc7369,	true, MTAP_4WAY,    4 }, // General Chaos (Japan)
 { "T-50626 -00", 0xf1ecc4df,	true, MTAP_4WAY,    4 }, // General Chaos (USA, Europe)
 { "T-79196", 0xdcffa327, 	true, MTAP_TP_PRT1, 5 }, // Head-On Soccer (USA)
 /* Can support dual multitap, *BUT* Some game modes are incompatible with multitap
 { "T-95126-00", 0xf27c576a, 	true, * }, // Hyper Dunk (Europe)
 { NULL, 0xdb124bbb, 		true, * }, // Hyper Dunk - The Playoff Edition (Japan) (Beta)
 { "T-95083-00", 0x5baf53d7, 	true, * }, // Hyper Dunk - The Playoff Edition (Japan)
 */
 { "T-50836 -00", 0xe04ffc2b,	true, MTAP_4WAY,    4 }, // IMG International Tour Tennis (USA, Europe)
 { "T-95196-50", 0x9bb3b180, 	true, MTAP_TP_PRT1, 5 }, // International Superstar Soccer Deluxe (Europe)
 //{ "G-5540  00", 0x9fe71002, 	true, MTAP_TP_PRT2, 4 }, // J. League Pro Striker 2 (Japan)
 { "G-5547", 0xe35e25fb, 	true, MTAP_TP_PRT1, 4 }, // J. League Pro Striker Final Stage (Japan)
 //{ "00005518-00", 0xec229156, 	true, MTAP_TP_PRT1, 4 }, // J. League Pro Striker (Japan) (v1.0)
 //{ "00005518-03", 0x2d5b7a11, 	true, MTAP_TP_PRT1, 4 }, // J. League Pro Striker (Japan) (v1.3)
 //{ "00005532-00", 0x0abed379, 	true, MTAP_TP_PRT1, 4 }, // J. League Pro Striker Perfect (Japan)
 { NULL, 0x17bed25f, 		true, MTAP_TP_PRT1, 3 }, // Lost Vikings, The (Europe) (Beta)
 { "T-70226-500", 0x1f14efc6, 	true, MTAP_TP_PRT1, 3 }, // Lost Vikings, The (Europe)
 { "T-125016-00", 0x7ba49edb, 	true, MTAP_TP_PRT1, 3 }, // Lost Vikings, The (USA)
 { "T-50676 -00", 0xd14b811b,	true, MTAP_4WAY,    4 }, // Madden NFL '94 (USA, Europe)
 { "T-50926 -00", 0xdb0be0c2,	true, MTAP_4WAY,    4 }, // Madden NFL 95 (USA, Europe)
 { "T-172076-00", 0xf126918b,	true, MTAP_4WAY,    4 }, // Madden NFL 96 (USA, Europe)
 { "T-172136-00", 0xc4b4e112,	true, MTAP_4WAY,    4 }, // Madden NFL 97 (USA, Europe)
 { "T-172196-00", 0xe051ea62,	true, MTAP_4WAY,    4 }, // Madden NFL 98 (USA)
 { "MK-1573-00", 0x54ab3beb, 	true, MTAP_TP_PRT1, 4 }, // Mega Bomberman (Europe)
 { "MK-1573-00", 0x4bd6667d, 	true, MTAP_TP_PRT1, 4 }, // Mega Bomberman (USA)
 { NULL, 0xd41c0d81, 		true, MTAP_TP_DUAL, 8 }, // Mega Bomberman - 8 Player Demo (Unl)
 { "T-120096-50", 0x01c22a5d, 	false, MTAP_TP_PRT1, 4 }, // Micro Machines 2 - Turbo Tournament (Europe) (J-Cart) (Alt 1)
 { "T-120096-50", 0x42bfb7eb, 	false, MTAP_TP_PRT1, 4 }, // Micro Machines 2 - Turbo Tournament (Europe) (J-Cart)
 { NULL, 0xb3abb15e, 		false, MTAP_TP_PRT1, 4 }, // Micro Machines Military (Europe) (J-Cart)
 { NULL, 0x7492b1de, 		false, MTAP_TP_PRT1, 4 }, // Micro Machines Turbo Tournament 96 (Europe) (J-Cart)
 { NULL, 0x23319d0d, 		false, MTAP_TP_PRT1, 4 }, // Micro Machines Turbo Tournament 96 (Europe) (v1.1) (J-Cart)
 { "T-50816 -00", 0x14a8064d,	true, MTAP_4WAY,    4 }, // MLBPA Baseball (USA)
 { "T-50766 -00", 0x3529180f,	true, MTAP_4WAY,    4 }, // Mutant League Hockey (USA, Europe)
 { "MK-1221 -00", 0x99c348ba, 	true, MTAP_TP_PRT1, 5 }, // NBA Action '94 (USA)
 { "MK-1236 -00", 0xaa7006d6, 	true, MTAP_TP_PRT1, 5 }, // NBA Action '95 Starring David Robinson (USA, Europe)
 { "T-97136 -50", 0xedb4d4aa, 	true, MTAP_TP_PRT1, 4 }, // NBA Hang Time (Europe)
 { "T-97136 -00", 0x176b0338, 	true, MTAP_TP_PRT1, 4 }, // NBA Hang Time (USA)
 { "T-81033  00", 0xa6c6305a, 	true, MTAP_TP_PRT1, 4 }, // NBA Jam (Japan)
 { "T-81406 -00", 0xe9ffcb37, 	true, MTAP_TP_PRT1, 4 }, // NBA Jam Tournament Edition (World)
 { "T-081326 00", 0x10fa248f, 	true, MTAP_TP_PRT1, 4 }, // NBA Jam (USA, Europe)
 { "T-081326 01", 0xeb8360e6, 	true, MTAP_TP_PRT1, 4 }, // NBA Jam (USA, Europe) (v1.1)
 { "T-50936 -00", 0x779c1244,	true, MTAP_4WAY,    4 }, // NBA Live 95 (Korea)
 { "T-50936 -00", 0x66018abc,	true, MTAP_4WAY,    4 }, // NBA Live 95 (USA, Europe)
 { "T-172056-00", 0x49de0062,	true, MTAP_4WAY,    4 }, // NBA Live 96 (USA, Europe)
 { "T-172166-00", 0x7024843a,	true, MTAP_4WAY,    4 }, // NBA Live 97 (USA, Europe)
 { "T-172186-00", 0x23473a8a, 	true, MTAP_TP_PRT1, 4 }, // NBA Live 98 (USA)
 { NULL, 0xeea19bce, 		true, MTAP_TP_PRT1, 4 }, // NBA Pro Basketball '94 (Japan)
 { "T-50756 -00", 0x160b7090,	true, MTAP_4WAY,    4 }, // NBA Showdown '94 (USA, Europe)
 { "T-158016-00", 0xed0c1303, 	true, MTAP_TP_PRT1, 5 }, // NCAA Final Four Basketball (USA)
 { "T-87106 -00", 0x081012f0, 	true, MTAP_TP_PRT1, 4 }, // NCAA Football (USA)
 { "MK-1237 -00", 0xb58e4a81, 	true, MTAP_TP_PRT1, 4 }, // NFL '95 (USA, Europe)
 { "MK-1243 -00", 0xf73ec54c, 	true, MTAP_TP_PRT1, 4 }, // NFL 98 (USA)
 { "T-081586-00", 0xd5a37cab, 	true, MTAP_TP_PRT1, 4 }, // NFL Quarterback Club 96 (USA, Europe)
 { "T-081276 00", 0x94542eaf, 	true, MTAP_TP_PRT1, 4 }, // NFL Quarterback Club (World)
 { "T-50656 -00", 0x9438f5dd,	true, MTAP_4WAY,    4 }, // NHL '94 (USA, Europe)
 { "T-50856 -00", 0xe8ee917e,	true, MTAP_4WAY,    4 }, // NHL 95 (USA, Europe)
 { "T-172036-00", 0x8135702c,	true, MTAP_4WAY,    4 }, // NHL 96 (USA, Europe)
 { "T-172146-03", 0xf067c103,	true, MTAP_4WAY,    4 }, // NHL 97 (USA, Europe)
 { "T-172176-00", 0x7b64cd98,	true, MTAP_4WAY,    4 }, // NHL 98 (USA)
 { "00004107-00", 0x9d4b447a, 	true, MTAP_TP_PRT2, 5 }, // Party Quiz Mega Q (Japan)
 { "T-119096-00", 0x05a486e9, 	true, MTAP_TP_PRT1, 4 }, // Pele II - World Tournament Soccer (USA, Europe)
 { "G-4133-00", 0xd1e2324b, 	true, MTAP_TP_PRT2, 4 }, // Pepenga Pengo (Japan)
 { "T-50796 -00", 0x8ca45acd,	true, MTAP_4WAY,    4 }, // PGA European Tour (USA, Europe)
 { "T-50946 -00", 0xaeb3f65f,	true, MTAP_4WAY,    4 }, // PGA Tour Golf III (USA, Europe)
 { "MK-1240 -00", 0x5aa53cbc, 	true, MTAP_TP_PRT1, 4 }, // Prime Time NFL Starring Deion Sanders (USA)
 { "G-4128  -00", 0x7bdec762, 	true, MTAP_TP_PRT1, 4 }, // Puzzle & Action - Ichidanto-R (Japan)
 { "G-4118  -00", 0xd2d2d437, 	true, MTAP_TP_PRT1, 4 }, // Puzzle & Action - Tanto-R (Japan)
 { "T-50956 -00", 0x61f90a8a,	true, MTAP_4WAY,    4 }, // Rugby World Cup 95 (USA, Europe) (En,Fr,It)
 { "MK-1183 -00", 0x07fedaf1, 	true, MTAP_TP_PRT2, 4 }, // Sega Sports 1 (Europe)
 { NULL, 0x72dd884f, 		true, MTAP_TP_PRT1, 4 }, // Shi Jie Zhi Bang Zheng Ba Zhan - World Pro Baseball 94 (China) (Unl)
 { "MK-1233 -00", 0x7e3ecabf, 	true, MTAP_TP_PRT1, 5 }, // Sport Games (Brazil) [b]
 { "T-177016-00", 0x1a58d5fe, 	true, MTAP_TP_PRT1, 4 }, // Street Racer (Europe)
 { "T-95146-00", 0x1227b2b2, 	true, MTAP_TP_PRT1, 4 }, // Tiny Toon Adventures - Acme All-Stars (Europe)
 { "T-95146-00", 0x2f9faa1d, 	true, MTAP_TP_PRT1, 4 }, // Tiny Toon Adventures - Acme All-Stars (USA, Korea)
 { "T-172026-04", 0xf1748e91,	true, MTAP_4WAY,    4 }, // Triple Play 96 (USA)
 { "T-172116-00", 0xbbe69017,	true, MTAP_4WAY,    4 }, // Triple Play - Gold Edition (USA)
 //maybe port2? { NULL, 0x9d451f72, 		true, MTAP_TP_PRT1, 4 }, // Ultimate Soccer (Europe) (En,Fr,De,Es,It) (Beta)
 //{ "MK1219  -00", 0x83db6e58, 	true, MTAP_TP_PRT1, 4 }, // Ultimate Soccer (Europe) (En,Fr,De,Es,It)
 { "T-119156-00", 0x9920e7b7, 	true, MTAP_TP_PRT1, 4 }, // Unnecessary Roughness '95 (USA)
 { "T-048416-00", 0xc2c13b81, 	true, MTAP_TP_PRT1, 4 }, // Wayne Gretzky and the NHLPA All-Stars (USA, Europe)
 { "MK-1224 -50", 0xb791a435, 	true, MTAP_TP_PRT2, 4 }, // Wimbledon Championship Tennis (Europe)
 { "G-4110  -00", 0x3e0c9daf, 	true, MTAP_TP_PRT2, 4 }, // Wimbledon Championship Tennis (Japan)
 { NULL, 0x9febc760, 		true, MTAP_TP_PRT2, 4 }, // Wimbledon Championship Tennis (USA) (Beta)
 { "MK-1224 -00", 0xf9142aee, 	true, MTAP_TP_PRT2, 4 }, // Wimbledon Championship Tennis (USA)
 { "MK-1233 -00", 0x6065774d, 	true, MTAP_TP_PRT1, 5 }, // World Championship Soccer II (Europe)
 { "MK-1233 -00", 0xc1dd1c8e, 	true, MTAP_TP_PRT1, 5 }, // World Championship Soccer II (USA)
 { "T-79116-00", 0x0171b47f, 	true, MTAP_TP_PRT1, 4 }, // World Cup USA 94 (USA, Europe)
 { "T-081316-00", 0x4ef5d411, 	true, MTAP_TP_PRT1, 4 }, // WWF Raw (World)
 { "G-004122-00", 0x71ceac6f, 	true, MTAP_TP_PRT1, 4 }, // Yuu Yuu Hakusho - Makyou Toitsusen (Japan)
 { "G-004122-00", 0xfe3fb8ee, 	true, MTAP_TP_PRT1, 4 }, // Yuu Yuu Hakusho - Sunset Fighters (Brazil)
};

static bool decode_region_setting(const int setting, bool &overseas, bool &pal)
{
 switch(setting)
 {
  default: assert(0);
	   return(false);

  case REGION_OVERSEAS_NTSC:
	overseas = true;
	pal = false;
	return(true);

  case REGION_OVERSEAS_PAL:
	overseas = true;
	pal = true;
	return(true);

  case REGION_DOMESTIC_NTSC:
	overseas = false;
	pal = false;
	return(true);

  case REGION_DOMESTIC_PAL:
	overseas = false;
	pal = true;
	return(true);
 }
}

static void LoadCommonPost(const md_game_info &ginfo)
{
 MDFN_printf(_("ROM:       %dKiB\n"), (ginfo.rom_size + 1023) / 1024);
 MDFN_printf(_("ROM CRC32: 0x%08x\n"), ginfo.crc32);
 MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(ginfo.md5, 0).c_str());
 MDFN_printf(_("Header MD5: 0x%s\n"), md5_context::asciistr(ginfo.info_header_md5, 0).c_str());
 MDFN_printf(_("Product Code: %s\n"), ginfo.product_code);
 MDFN_printf(_("Domestic name: %s\n"), ginfo.domestic_name); // TODO: Character set conversion(shift_jis -> utf-8)
 MDFN_printf(_("Overseas name: %s\n"), ginfo.overseas_name);
 MDFN_printf(_("Copyright: %s\n"), ginfo.copyright);
 if(ginfo.checksum == ginfo.checksum_real)
  MDFN_printf(_("Checksum:  0x%04x\n"), ginfo.checksum);
 else
  MDFN_printf(_("Checksum:  0x%04x\n Warning: calculated checksum(0x%04x) does not match\n"), ginfo.checksum, ginfo.checksum_real);

 MDFN_printf(_("Supported I/O devices:\n"));
 MDFN_indent(1);
 for(unsigned int iot = 0; iot < sizeof(IO_types) / sizeof(IO_type_t); iot++)
 {
  if(ginfo.io_support & (1 << IO_types[iot].id))
   MDFN_printf(_("%s\n"), _(IO_types[iot].name));
 }
 MDFN_indent(-1);

 MDFNMP_Init(8192, (1 << 24) / 8192);

 for(uint32 A = (0x7 << 21); A < (0x8 << 21); A += 65536)
  MDFNMP_AddRAM(65536, A, work_ram, (A == 0xFF0000));

 MDFNGameInfo->GameSetMD5Valid = false;

 MDSound_Init();

 MDFN_printf(_("Supported regions:\n"));
 MDFN_indent(1);
 if(ginfo.region_support & REGIONMASK_JAPAN_NTSC)
  MDFN_printf(_("Japan/Domestic NTSC\n"));
 if(ginfo.region_support & REGIONMASK_JAPAN_PAL)
  MDFN_printf(_("Japan/Domestic PAL\n"));
 if(ginfo.region_support & REGIONMASK_OVERSEAS_NTSC)
  MDFN_printf(_("Overseas NTSC\n"));
 if(ginfo.region_support & REGIONMASK_OVERSEAS_PAL)
  MDFN_printf(_("Overseas PAL\n"));
 MDFN_indent(-1);

 {
  const int region_setting = MDFN_GetSettingI("md.region");
  const int reported_region_setting = MDFN_GetSettingI("md.reported_region");

  // Default, in case the game doesn't support any regions!
  bool game_overseas = true;
  bool game_pal = false;
  bool overseas;
  bool pal;
  bool overseas_reported;
  bool pal_reported;

  // Preference order, TODO:  Make it configurable
  if(ginfo.region_support & REGIONMASK_OVERSEAS_NTSC)
  {
   game_overseas = true;
   game_pal = false;
  }
  else if(ginfo.region_support & REGIONMASK_JAPAN_NTSC)
  {
   game_overseas = false;
   game_pal = false;
  }
  else if(ginfo.region_support & REGIONMASK_OVERSEAS_PAL)
  {
   game_overseas = true;
   game_pal = true;
  }
  else if(ginfo.region_support & REGIONMASK_JAPAN_PAL) // WTF?
  {
   game_overseas = false;
   game_pal = true;
  }
 
  if(region_setting == REGION_GAME)
  {
   overseas = game_overseas;
   pal = game_pal;
  }
  else
  {
   decode_region_setting(region_setting, overseas, pal);
  }

  if(reported_region_setting == REGION_GAME)
  {
   overseas_reported = game_overseas;
   pal_reported = game_pal;
  }
  else if(reported_region_setting == REGION_SAME)
  {
   overseas_reported = overseas;
   pal_reported = pal;   
  }
  else
  {
   decode_region_setting(reported_region_setting, overseas_reported, pal_reported);
  }

  MDFN_printf("\n");
  MDFN_printf(_("Active Region: %s %s\n"), overseas ? _("Overseas") : _("Domestic"), pal ? _("PAL") : _("NTSC"));
  MDFN_printf(_("Active Region Reported: %s %s\n"), overseas_reported ? _("Overseas") : _("Domestic"), pal_reported ? _("PAL") : _("NTSC"));

  system_init(overseas, pal, overseas_reported, pal_reported);

  if(pal)
   MDFNGameInfo->nominal_height = 240;
  else
   MDFNGameInfo->nominal_height = 224;

  MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(pal ? CLOCK_PAL : CLOCK_NTSC);

  if(pal)
   MDFNGameInfo->fps = (int64)CLOCK_PAL * 65536 * 256 / (313 * 3420);
  else
   MDFNGameInfo->fps = (int64)CLOCK_NTSC * 65536 * 256 / (262 * 3420);

  //printf("%f\n", (double)MDFNGameInfo->fps / 65536 / 256);
 }

 if(MDFN_GetSettingB("md.correct_aspect"))
 {
  MDFNGameInfo->nominal_width = 292;
  MDFNGameInfo->lcm_width = 1280;
 }
 else
 {
  MDFNGameInfo->nominal_width = 320;
  MDFNGameInfo->lcm_width = 320;
 }

 MDFNGameInfo->lcm_height = MDFNGameInfo->nominal_height * 2;

 MDFNGameInfo->LayerNames = "BG0\0BG1\0OBJ\0";

 //
 //
 {
  unsigned mtt = MDFN_GetSettingUI("md.input.multitap");

  if(MDFN_GetSettingB("md.input.auto"))
  {
   for(auto const& e : InputDB)
   {
    if(e.crc32 == ginfo.crc32 && (!e.prod_code || !strcmp(e.prod_code, ginfo.product_code)))
    {
     MDFNGameInfo->DesiredInput.resize(8);

     for(unsigned n = e.max_players; n < 8; n++)	// Particularly for Gauntlet 4.
      MDFNGameInfo->DesiredInput[n] = "none";

     mtt = e.tap;
     break;
    }
   }
  }

  for(const auto* mte = MultiTap_List; mte->string; mte++)
  {
   if((unsigned)mte->number == mtt)
   {
    MDFN_printf(_("Active Multitap(s): %s\n"), mte->description);
    break;
   }
  }

  MDINPUT_SetMultitap(mtt);
 }

 //
 //

 system_reset(true);
}

static void Load(MDFNFILE *fp)
{
 try
 {
  md_game_info ginfo;

  memset(&ginfo, 0, sizeof(md_game_info));
  MDCart_Load(&ginfo, fp);

  memcpy(MDFNGameInfo->MD5, ginfo.md5, 16);

  MD_IsCD = false;

  MD_ExtRead8 = MDCart_Read8;
  MD_ExtRead16 = MDCart_Read16;
  MD_ExtWrite8 = MDCart_Write8;
  MD_ExtWrite16 = MDCart_Write16;

  MDCart_LoadNV();

  LoadCommonPost(ginfo);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static void LoadCD(std::vector<CDIF *> *CDInterfaces)
{
 try
 {
  md_game_info ginfo;

  memset(&ginfo, 0, sizeof(md_game_info));

  MD_IsCD = true;

  MDCD_Load(CDInterfaces, &ginfo);

  LoadCommonPost(ginfo);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static bool TestMagicCD(std::vector<CDIF *> *CDInterfaces)
{
 return(MDCD_TestMagic(CDInterfaces));
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER: system_reset(true); break;
  case MDFN_MSC_RESET: system_reset(false); break;
 }
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 uint8 c68k_state[M68K::OldStateLen];

 SFORMAT StateRegs[] =
 {
  SFPTR8(work_ram, 65536),
  SFPTR8(zram, 8192),
  SFVAR(zbusreq),
  SFVAR(zreset),
  SFVAR(zbusack),
  SFVAR(zirq),
  SFVAR(zbank),

  SFVAR(suspend68k),
  SFVAR(z80_cycle_counter),

  SFVAR(obsim),

  SFPTR8N((load && load < 0x939) ? c68k_state : NULL, sizeof(c68k_state), "c68k_state"),
  SFEND
 };


 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");
 if(load)
 {
  zbusreq &= 1;
  zreset &= 1;
  zbusack &= 1;

  if(z80_cycle_counter > 0)
   z80_cycle_counter = 0;
 }


 z80_state_action(sm, load, data_only, "Z80");
 MDINPUT_StateAction(sm, load, data_only);
 MainVDP.StateAction(sm, load, data_only);
 MDSound_StateAction(sm, load, data_only);
 MDCart_StateAction(sm, load, data_only);

 if(!load || load >= 0x939)
  Main68K.StateAction(sm, load, data_only, "M68K");

 if(load)
 {
  z80_set_interrupt(zirq);
  //
  if(load < 0x939)
  {
   Main68K.LoadOldState(c68k_state);
   Main68K.SetExtHalted(suspend68k);
  }
 }
}

static const MDFNSetting_EnumList RegionList[] =
{
 { "game", REGION_GAME, gettext_noop("Match game's header."), gettext_noop("Emulate the region that the game indicates it expects to run in via data in the header(or in an internal database for a few games that may have bad header data).") },

 { "overseas_ntsc", REGION_OVERSEAS_NTSC, gettext_noop("Overseas(non-Japan), NTSC"), gettext_noop("Region used in North America.") },
 { "overseas_pal", REGION_OVERSEAS_PAL, gettext_noop("Overseas(non-Japan), PAL"), gettext_noop("Region used in Europe.") },

 { "domestic_ntsc", REGION_DOMESTIC_NTSC, gettext_noop("Domestic(Japan), NTSC"), gettext_noop("Region used in Japan.") },
 { "domestic_pal", REGION_DOMESTIC_PAL, gettext_noop("Domestic(Japan), PAL"), gettext_noop("Probably an invalid region, but available for testing purposes anyway.") },

 { NULL, 0 }
};

static const MDFNSetting_EnumList ReportedRegionList[] =
{
 { "same", REGION_SAME, gettext_noop("Match the region emulated.") },

 { "game", REGION_GAME, gettext_noop("Match game's header."), gettext_noop("This option, in conjunction with the \"md.region\" setting, can be used to run all games at NTSC speeds, or all games at PAL speeds.")  },

 { "overseas_ntsc", REGION_OVERSEAS_NTSC, gettext_noop("Overseas(non-Japan), NTSC"), gettext_noop("Region used in North America.") },
 { "overseas_pal", REGION_OVERSEAS_PAL, gettext_noop("Overseas(non-Japan), PAL"), gettext_noop("Region used in Europe.") },

 { "domestic_ntsc", REGION_DOMESTIC_NTSC, gettext_noop("Domestic(Japan), NTSC"), gettext_noop("Region used in Japan.") },
 { "domestic_pal", REGION_DOMESTIC_PAL, gettext_noop("Domestic(Japan), PAL"), gettext_noop("Probably an invalid region, but available for testing purposes anyway.") },

 { NULL, 0 },
};

static const MDFNSetting MDSettings[] =
{
 { "md.region", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate the specified region's Genesis/MegaDrive"), NULL, MDFNST_ENUM, "game", NULL, NULL, NULL, NULL, RegionList },
 { "md.reported_region", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Region reported to the game."), NULL, MDFNST_ENUM, "same", NULL, NULL, NULL, NULL, ReportedRegionList },

 { "md.cdbios", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the CD BIOS"), gettext_noop("SegaCD/MegaCD emulation is currently nonfunctional."), MDFNST_STRING, "us_scd1_9210.bin" },

 { "md.correct_aspect", MDFNSF_CAT_VIDEO, gettext_noop("Correct the aspect ratio."), NULL, MDFNST_BOOL, "1" },

 { "md.input.auto", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Automatically select appropriate input devices."),
	gettext_noop("Automatically select appropriate input devices, based on an internal database.  Currently, only multitap device usage data is contained in the database."),
	MDFNST_BOOL, "1" },
 { "md.input.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap(s)."), NULL, MDFNST_ENUM, "none", NULL, NULL, NULL, NULL, MultiTap_List },

 { "md.input.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Emulated mouse sensitivity."), NULL, MDFNST_FLOAT, "1.00", NULL, NULL },

 { NULL }
};

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".bin", gettext_noop("Super Magic Drive binary ROM Image") },
 { ".smd", gettext_noop("Super Magic Drive interleaved format ROM Image") },
 { ".md", gettext_noop("Multi Game Doctor format ROM Image") },
 { NULL, NULL }
};

void SetLayerEnableMask(uint64 mask)
{
 MainVDP.SetLayerEnableMask(mask);
}

}


MDFNGI EmulatedMD =
{
 "md",
 "Sega Genesis/MegaDrive",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef WANT_DEBUGGER
 &DBGInfo,
 #else
 NULL,
 #endif
 MDPortInfo,
 Load,
 MDCart_TestMagic,
 LoadCD,
 TestMagicCD,
 CloseGame,

 SetLayerEnableMask,
 NULL,

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 NULL,
 MDINPUT_SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 MDSettings,
 0,	// MasterClock(set in game loading code)
 0,
 true, // Multires possible?

 0,   // lcm_width		// Calculated in game load
 0,   // lcm_height         	// Calculated in game load
 NULL,  // Dummy


 // We want maximum values for nominal width and height here so the automatic fullscreen setting generation code will have
 // selected a setting suitable if aspect ratio correction is turned off.
 320,   // Nominal width(adjusted in game loading code, with aspect ratio correction enabled, it's 292, otherwise 320)
 240,   // Nominal height(adjusted in game loading code to 224 for NTSC, and 240 for PAL)
 1024,	// Framebuffer width
 512,	// Framebuffer height

 2,     // Number of output sound channels
};

