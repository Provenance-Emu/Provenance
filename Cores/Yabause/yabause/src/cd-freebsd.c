/*  Copyright 2004-2005 Theo Berkau
    Copyright 2004-2006 Guillaume Duhamel
    Copyright 2005 Joost Peters

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

#include <sys/types.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <sys/cdio.h>
#include <sys/cdrio.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include "cdbase.h"
#include "debug.h"

static int FreeBSDCDInit(const char *);
static void FreeBSDCDDeInit(void);
static s32 FreeBSDCDReadTOC(u32 *);
static int FreeBSDCDGetStatus(void);
static int FreeBSDCDReadSectorFAD(u32, void *);
static void FreeBSDCDReadAheadFAD(u32);

CDInterface ArchCD = {
	CDCORE_ARCH,
	"FreeBSD CD Drive",
	FreeBSDCDInit,
	FreeBSDCDDeInit,
	FreeBSDCDGetStatus,
	FreeBSDCDReadTOC,
	FreeBSDCDReadSectorFAD,
	FreeBSDCDReadAheadFAD,
};

static int hCDROM;

static int FreeBSDCDInit(const char * cdrom_name) {
	int bsize = 2352;

	if ((hCDROM = open(cdrom_name, O_RDONLY | O_NONBLOCK)) == -1) {
		LOG("CDInit (%s) failed\n", cdrom_name);
		return -1;
	}

	if (ioctl (hCDROM, CDRIOCSETBLOCKSIZE, &bsize) == -1) {
		return -1;
	}

	LOG("CDInit (%s) OK\n", cdrom_name);
	return 0;
}

static void FreeBSDCDDeInit(void) {
	if (hCDROM != -1) {
		close(hCDROM);
	}

	LOG("CDDeInit OK\n");
}


static s32 FreeBSDCDReadTOC(u32 * TOC)
{
   int success;
   struct ioc_toc_header ctTOC;
   struct ioc_read_toc_single_entry ctTOCent;
   int i, j;
   int add150 = 0;

   ctTOCent.address_format = CD_LBA_FORMAT;

   if (hCDROM != -1)
   {
      memset(TOC, 0xFF, 0xCC * 2);
      memset(&ctTOC, 0xFF, sizeof(struct ioc_toc_header));

      if (ioctl(hCDROM, CDIOREADTOCHEADER, &ctTOC) == -1) {
	return 0;
      }

      ctTOCent.track = ctTOC.starting_track;
      ioctl(hCDROM, CDIOREADTOCENTRY, &ctTOCent);
      if (ctTOCent.entry.addr.lba == 0) add150 = 150;
      TOC[0] = ((ctTOCent.entry.control << 28) |
	          (ctTOCent.entry.addr_type << 24) |
	           ctTOCent.entry.addr.lba + add150);

      // convert TOC to saturn format
      for (i = ctTOC.starting_track + 1; i <= ctTOC.ending_track; i++)
      {      
	      ctTOCent.track = i;
	      ioctl(hCDROM, CDIOREADTOCENTRY, &ctTOCent);
	      TOC[i - 1] = (ctTOCent.entry.control << 28) |
                  (ctTOCent.entry.addr_type << 24) |
		  (ctTOCent.entry.addr.lba + add150);
      }

      // Do First, Last, and Lead out sections here

      ctTOCent.track = ctTOC.starting_track;
      ioctl(hCDROM, CDIOREADTOCENTRY, &ctTOCent);
      TOC[99] = (ctTOCent.entry.control << 28) |
                (ctTOCent.entry.addr_type << 24) |
                (ctTOC.starting_track << 16);

      ctTOCent.track = ctTOC.ending_track;
      ioctl(hCDROM, CDIOREADTOCENTRY, &ctTOCent);
      TOC[100] = (ctTOCent.entry.control << 28) |
                 (ctTOCent.entry.addr_type << 24) |
                 (ctTOC.starting_track << 16);

      ctTOCent.track = 0xAA;
      ioctl(hCDROM, CDIOREADTOCENTRY, &ctTOCent);
      TOC[101] = (ctTOCent.entry.control << 28) |
                 (ctTOCent.entry.addr_type << 24) |
		 (ctTOCent.entry.addr.lba + add150);

      return (0xCC * 2);
   }

   return 0;
}

static int FreeBSDCDGetStatus(void) {
	// 0 - CD Present, disc spinning
	// 1 - CD Present, disc not spinning
	// 2 - CD not present
	// 3 - Tray open
	// see ../windows/cd.cc for more info

	return 0;
}

static int FreeBSDCDReadSectorFAD(u32 FAD, void *buffer) {
	if (hCDROM != -1)
	{
		lseek(hCDROM, (FAD - 150) * 2352, SEEK_SET);
		read(hCDROM, buffer, 2352);
	
		return 1;
	}

	return 0;
}

static void FreeBSDCDReadAheadFAD(UNUSED u32 FAD)
{
	// No-op
}
