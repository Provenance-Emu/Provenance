/*******************************************************************************
  CDTEST - Yabause CD interface tester

  (c) Copyright 2004-2005 Theo Berkau(cwx@cyberwarriorx.com)

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

// This program is designed to be linked with any port's cd.c file.
// example: gcc windows\cd.c tools\cdtest.c -o cdtest.exe

// Once it's compiled, run it with the cdrom path as your argument
// example: cdtest g:

// SPECIAL NOTE: You need to use a regular saturn disc as your test cd to have
// accurate test results.

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

#define PROG_NAME "CDTEST"
#define VER_NAME "1.01"
#define COPYRIGHT_YEAR "2004-2005, 2014"

int testspassed=0;

u8 cdbuffer[2352];
u32 cdTOC[102];

// Unused functions and variables
SH2Interface_struct *SH2CoreList[] = {
	NULL
};

VideoInterface_struct *VIDCoreList[] = {
	NULL
};

SoundInterface_struct *SNDCoreList[] = {
	NULL
};

M68K_struct * M68KCoreList[] = {
	NULL
};

CDInterface *CDCoreList[] = {
	NULL
};

PerInterface_struct *PERCoreList[] = {
	NULL
};

void YuiErrorMsg(const char *string) { }

void YuiSwapBuffers() { }

//////////////////////////////////////////////////////////////////////////////

void ProgramUsage()
{
   printf("%s v%s - by Cyber Warrior X (c)%s\n", PROG_NAME, VER_NAME, COPYRIGHT_YEAR);
   printf("usage: %s <drive pathname as specified in cd.c>\n", PROG_NAME);
   exit (1);
}

//////////////////////////////////////////////////////////////////////////////

void cleanup(void)
{
   ArchCD.DeInit();
   testspassed++;

   printf("Test Score: %d/11 \n", testspassed);
}

//////////////////////////////////////////////////////////////////////////////

int IsTOCValid(u32 *TOC)
{
   u8 lasttrack=1;
   int i;

   // Make sure first track's FAD is 150
   if ((TOC[0] & 0xFFFFFF) != 150)
      return 0;

   // Go through each track and make sure they start at FAD that's higher
   // than the previous track
   for (i = 1; i < 99; i++)
   {
      if (TOC[i] == 0xFFFFFFFF)
         break;

      lasttrack++;

      if ((TOC[i-1] & 0xFFFFFF) >= (TOC[i] & 0xFFFFFF))
         return 0;
   }

   // Check Point A0 information
   if (TOC[99] & 0xFF) // PFRAME - Should always be 0
      return 0;

   if (TOC[99] & 0xFF00) // PSEC - Saturn discs will be 0
      return 0;

   if (((TOC[99] & 0xFF0000) >> 16) != 0x01) // PMIN - First track's number
      return 0;

   if ((TOC[99] & 0xFF000000) != (TOC[0] & 0xFF000000)) // First track's addr/ctrl
      return 0;

   // Check Point A1 information
   if (TOC[100] & 0xFF) // PFRAME - Should always be 0
      return 0;

   if (TOC[100] & 0xFF00) // PSEC - Saturn discs will be 0
      return 0;

   if (((TOC[100] & 0xFF0000) >> 16) != lasttrack) // PMIN - Last track's number
      return 0;

   if ((TOC[100] & 0xFF000000) != (TOC[lasttrack-1] & 0xFF000000)) // Last track's addr/ctrl
      return 0;

   // Check Point A2 information
   if ((TOC[101] & 0xFFFFFF) <= (TOC[lasttrack-1] & 0xFFFFFF)) // Lead out FAD should be larger than last track's FAD
      return 0;

   if ((TOC[101] & 0xFF000000) != (TOC[lasttrack-1] & 0xFF000000)) // Lead out's addr/ctrl should be the same as last track's
      return 0;

   return 1;
}

//////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
   char *cdrom_name = NULL;
   u32 f_size=0;
   int status;
   char syncheader[12] = { 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                           0xFF, 0xFF, 0xFF, 0x00};

   atexit(cleanup);

#ifndef _arch_dreamcast
   if (argc != 2)
   {
      ProgramUsage();
   }

   printf("%s v%s - by Cyber Warrior X(c)%s\n", PROG_NAME, VER_NAME, COPYRIGHT_YEAR);

   cdrom_name = argv[1];
#endif

   if (ArchCD.Init(cdrom_name) != 0)
   {
      printf("CDInit error: Unable to initialize cdrom\n");
      exit(1);
   }
   else testspassed++;

   // Let's make sure we're returning the proper status
   status = ArchCD.GetStatus();

   if (status == 0 || status == 1)
   {
      testspassed++;

      if (ArchCD.ReadTOC(cdTOC) != (0xCC * 2))
      {
         printf("CDReadToc error: return value was not the correct size\n");
      }
      else testspassed++;

      // Make sure TOC is valid          
      if (!IsTOCValid(cdTOC))
      {
         printf("CDReadToc error: TOC data has some issues\n");
      }
      else testspassed++;

      // Read sector 0
      if (ArchCD.ReadSectorFAD(150, cdbuffer) != 1)
      {
         printf("CDReadSectorFAD error: Reading of LBA 0(FAD 150) returned false\n");
      }
      else testspassed++;

      // Check cdbuffer to make sure contents are correct
      if (memcmp(syncheader, cdbuffer, 12) != 0)
      {
         printf("CDReadSectorFAD error: LBA 0(FAD 150) read is missing sync header\n");
      }
      else testspassed++;

      // look for "SEGA SEGASATURN"
      if (memcmp("SEGA SEGASATURN", cdbuffer+0x10, 15) != 0)
      {
         printf("CDReadSectorFAD error: LBA 0(FAD 150)'s sector contents were not as expected\n");
      }
      else testspassed++;

      // Read sector 16(I figured it makes a good random test sector)
      if (ArchCD.ReadSectorFAD(166, cdbuffer) != 1)
      {
         printf("CDReadSectorFAD error: Reading of LBA 16(FAD 166) returned false\n");
      }
      else testspassed++;

      // Check cdbuffer to make sure contents are correct
      if (memcmp(syncheader, cdbuffer, 12) != 0)
      {
         printf("CDReadSectorFAD error: LBA 16(FAD 166) read is missing sync header\n");
      }
      else testspassed++;

      // look for "CD001"
      if (memcmp("CD001", cdbuffer+0x11, 5) != 0)
      {
         printf("CDReadSectorFAD error: LBA 16(FAD 166)'s sector contents were not as expected\n");
      }
      else testspassed++;
   }
   else
   {
      printf("CDGetStatus error: Can't continue the rest of the test - There's either no CD present or the tray is open\n");
      exit(1);
   }
}

//////////////////////////////////////////////////////////////////////////////
