/*******************************************************************************
  CDTEST - Yabause Peripheral interface tester

  (c) Copyright 2014 Theo Berkau(cwx@cyberwarriorx.com)

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
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

*******************************************************************************/

// This program is designed to be linked with any port's per*.c file.
// example: gcc perdx.c tools\pertest.c -o pertest.exe

// Once it's compiled, run it with the peripheral core indexh as your argument
// example: pertest 0

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../core.h"
#include "../cdbase.h"
#include "../m68kcore.h"
#include "../peripheral.h"
#include "../sh2core.h"
#include "../scsp.h"
#include "../vdp1.h"
#ifdef __linux__
#include "../perlinuxjoy.h"
#endif
#include "../persdljoy.h"
#ifdef __APPLE__
#include "../permacjoy.h"
#endif
#ifdef HAVE_DIRECTINPUT
#include "../perdx.h"
#endif

#define PROG_NAME "PERTEST"
#define VER_NAME "1.0"
#define COPYRIGHT_YEAR "2014"

int testspassed=0;

PerInterface_struct *PERCoreList[] = { 
	&PERDummy,
#ifdef __linux__
	&PERLinuxJoy,
#endif
#ifdef HAVE_LIBSDL
	&PERSDLJoy,
#endif
#ifdef __APPLE__
	&PERMacJoy,
#endif
#ifdef HAVE_DIRECTINPUT
	&PERDIRECTX,
#endif
	NULL
};

PerInterface_struct *CurPer;

// Unused functions and variables
SH2Interface_struct *SH2CoreList[] = {	NULL };

VideoInterface_struct *VIDCoreList[] = { NULL };

SoundInterface_struct *SNDCoreList[] = { NULL };

M68K_struct * M68KCoreList[] = { NULL };

CDInterface *CDCoreList[] = { NULL };

void YuiErrorMsg(const char *string) { }

void YuiSwapBuffers() { }

#ifdef HAVE_DIRECTINPUT
HWND DXGetWindow()
{
	return HWND_DESKTOP;
}
#endif

//////////////////////////////////////////////////////////////////////////////

void ProgramUsage()
{
   printf("%s v%s - by Cyber Warrior X (c)%s\n", PROG_NAME, VER_NAME, COPYRIGHT_YEAR);
   printf("usage: %s <core index as specified in pertest.c>\n", PROG_NAME);
   exit (1);
}

//////////////////////////////////////////////////////////////////////////////

void cleanup(void)
{	
	if (CurPer)
	{
      CurPer->DeInit();
      testspassed++;
		printf("Test Score: %d/11 \n", testspassed);
	}
}

//////////////////////////////////////////////////////////////////////////////

int TestInput(const char *msg, u32 flags, u64 timeout, u64 tickfreq)
{
	u64 time1, time2;
	u32 id;
	u32 startid;

	startid = CurPer->Scan(flags);
	printf("%s Timeout in %d seconds\n", msg, timeout);
	time1 = YabauseGetTicks();
	time2 = YabauseGetTicks();
	timeout = timeout * tickfreq;
	while ((id = CurPer->Scan(flags)) == 0 && (time2-time1) < timeout) 
		time2 = YabauseGetTicks();

	if (startid != 0)
	{
		printf("Data present before press. result code: %08X", startid);
		return 0;
	}
	if (id != 0)
	{
	   printf("result code: %08X", id);
		return 1;
	}
	else
		return 0;
}

//////////////////////////////////////////////////////////////////////////////

u64 GetTickFreq() 
{
	u64 tickfreq;
#ifdef WIN32
	QueryPerformanceFrequency((LARGE_INTEGER *)&tickfreq);
#elif defined(_arch_dreamcast)
	tickfreq = 1000;
#elif defined(GEKKO)
	tickfreq = secs_to_ticks(1);
#elif defined(PSP)
	tickfreq = 1000000;
#elif defined(HAVE_GETTIMEOFDAY)
	tickfreq = 1000000;
#elif defined(HAVE_LIBSDL)
	tickfreq = 1000;
#endif
	return tickfreq;
}

//////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
   char *cdrom_name = NULL;
   u32 f_size=0;
   int per_index=0;
	u64 tickfreq;

	tickfreq = GetTickFreq();
   atexit(cleanup);

#ifndef _arch_dreamcast
   if (argc != 2)
   {
      ProgramUsage();
   }

   printf("%s v%s - by Cyber Warrior X(c)%s\n", PROG_NAME, VER_NAME, COPYRIGHT_YEAR);

   per_index = atoi(argv[1]);
#endif

	if (per_index < 0 || per_index >= (sizeof(PERCoreList) / sizeof(PerInterface_struct *)))
	{
		printf("peripheral core index out of range\n");
		exit(1);
	}

	CurPer = PERCoreList[per_index];
	printf("Testing %s\n", CurPer->Name);

   if (CurPer->Init() != 0)
   {
      printf("PerInit error: Unable to initialize peripheral core\n");
      exit(1);
   }
   else testspassed++;

	testspassed += TestInput("Press a button on a gamepad/joystick...", PERSF_BUTTON, 10, tickfreq);
	testspassed += TestInput("Press a key on the keyboard...", PERSF_KEY, 10, tickfreq);
	testspassed += TestInput("Move d-pad/stick on a gamepad/joystick...", PERSF_AXIS|PERSF_BUTTON, 10, tickfreq);
	testspassed += TestInput("Move mouse...", PERSF_MOUSEMOVE, 10, tickfreq);
}

//////////////////////////////////////////////////////////////////////////////
