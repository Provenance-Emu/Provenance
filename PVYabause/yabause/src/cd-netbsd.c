/*  Copyright 2004-2005 Theo Berkau
    Copyright 2004-2005 Guillaume Duhamel
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
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include "cdbase.h"
#include "debug.h"

static int NetBSDCDInit(const char *);
static void NetBSDCDDeInit(void);
static s32 NetBSDCDReadTOC(u32 *);
static int NetBSDCDGetStatus(void);
static int NetBSDCDReadSectorFAD(u32, void *);
static void NetBSDCDReadAheadFAD(u32);

CDInterface ArchCD = {
       CDCORE_ARCH,
       "NetBSD CD Drive",
       NetBSDCDInit,
       NetBSDCDDeInit,
       NetBSDCDGetStatus,
       NetBSDCDReadTOC,
       NetBSDCDReadSectorFAD,
       NetBSDCDReadAheadFAD,
};

static int hCDROM;

static int NetBSDCDInit(const char * cdrom_name) {
       if ((hCDROM = open(cdrom_name, O_RDONLY | O_NONBLOCK)) == -1) {
               LOG("CDInit (%s) failed\n", cdrom_name);
               return -1;
       }

       LOG("CDInit (%s) OK\n", cdrom_name);
       return 0;
}

static void NetBSDCDDeInit(void) {
       if (hCDROM != -1) {
               close(hCDROM);
       }

       LOG("CDDeInit OK\n");
}


static s32 NetBSDCDReadTOC(u32 * TOC)
{
   int success;
   struct ioc_toc_header ctTOC;
   struct ioc_read_toc_entry ctTOCent;
   struct cd_toc_entry data;
   int i, j;
   int add150 = 0;

   ctTOCent.address_format = CD_LBA_FORMAT;
   ctTOCent.data_len = sizeof (struct cd_toc_entry);
   ctTOCent.data = &data;

   if (hCDROM != -1)
   {
      memset(TOC, 0xFF, 0xCC * 2);
      memset(&ctTOC, 0xFF, sizeof(struct ioc_toc_header));

      if (ioctl(hCDROM, CDIOREADTOCHEADER, &ctTOC) == -1) {
       return 0;
      }

      ctTOCent.starting_track = ctTOC.starting_track;
      ioctl(hCDROM, CDIOREADTOCENTRYS, &ctTOCent);
      if (ctTOCent.data->addr.lba == 0) add150 = 150;
      TOC[0] = ((ctTOCent.data->control << 28) |
                 (ctTOCent.data->addr_type << 24) |
                  ctTOCent.data->addr.lba + add150);

      // convert TOC to saturn format
      for (i = ctTOC.starting_track + 1; i <= ctTOC.ending_track; i++)
      {
             ctTOCent.starting_track = i;
             ioctl(hCDROM, CDIOREADTOCENTRYS, &ctTOCent);
             TOC[i - 1] = (ctTOCent.data->control << 28) |
                  (ctTOCent.data->addr_type << 24) |
                 (ctTOCent.data->addr.lba + add150);
      }

      // Do First, Last, and Lead out sections here

      ctTOCent.starting_track = ctTOC.starting_track;
      ioctl(hCDROM, CDIOREADTOCENTRYS, &ctTOCent);
      TOC[99] = (ctTOCent.data->control << 28) |
                (ctTOCent.data->addr_type << 24) |
                (ctTOC.starting_track << 16);

      ctTOCent.starting_track = ctTOC.ending_track;
      ioctl(hCDROM, CDIOREADTOCENTRYS, &ctTOCent);
      TOC[100] = (ctTOCent.data->control << 28) |
                 (ctTOCent.data->addr_type << 24) |
                 (ctTOC.starting_track << 16);

      ctTOCent.starting_track = 0xAA;
      ioctl(hCDROM, CDIOREADTOCENTRYS, &ctTOCent);
      TOC[101] = (ctTOCent.data->control << 28) |
                 (ctTOCent.data->addr_type << 24) |
                (ctTOCent.data->addr.lba + add150);

      return (0xCC * 2);
   }

   return 0;
}

static int NetBSDCDGetStatus(void) {
       // 0 - CD Present, disc spinning
       // 1 - CD Present, disc not spinning
       // 2 - CD not present
       // 3 - Tray open
       // see ../windows/cd.cc for more info

       return 0;
}

static int NetBSDCDReadSectorFAD(u32 FAD, void *buffer) {
       static const s8 syncHdr[] = {
           0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
           0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00 };

       if (hCDROM != -1)
       {
               memcpy(buffer, syncHdr, sizeof (syncHdr));
               lseek(hCDROM, (FAD - 150) * 2048, SEEK_SET);
               read(hCDROM, (char *)buffer + 0x10, 2048);

               return 1;
       }

       return 0;
}

static void NetBSDCDReadAheadFAD(UNUSED u32 FAD)
{
       // No-op
}
