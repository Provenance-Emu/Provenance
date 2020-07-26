/*  Copyright 2004-2005 Lucas Newman
    Copyright 2004-2005 Theo Berkau
    Copyright 2005 Weston Yager
    Copyright 2006-2008 Guillaume Duhamel
    Copyright 2010 Lawrence Sebald

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

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <paths.h>
#include <sys/param.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOMediaBSDClient.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOCDMedia.h>
#include <CoreFoundation/CoreFoundation.h>
#include <util.h>

#include "cdbase.h"

static int MacOSXCDInit(const char *);
static void MacOSXCDDeInit(void);
static int MacOSXCDGetStatus(void);
static s32 MacOSXCDReadTOC(u32 *);
static int MacOSXCDReadSectorFAD(u32, void *);
static void MacOSXCDReadAheadFAD(u32);

CDInterface ArchCD = {
CDCORE_ARCH,
"MacOSX CD Drive",
MacOSXCDInit,
MacOSXCDDeInit,
MacOSXCDGetStatus,
MacOSXCDReadTOC,
MacOSXCDReadSectorFAD,
MacOSXCDReadAheadFAD,
};

static int hCDROM;

static int MacOSXCDInit(const char * useless_for_now)
{
	CFMutableDictionaryRef  classesToMatch;
	io_iterator_t mediaIterator;
	io_object_t media;
	char cdrom_name[ MAXPATHLEN ];

	classesToMatch = IOServiceMatching(kIOCDMediaClass); 
	CFDictionarySetValue(classesToMatch, CFSTR(kIOMediaEjectableKey),
		kCFBooleanTrue); 
	IOServiceGetMatchingServices(kIOMasterPortDefault,
		classesToMatch, &mediaIterator);    

	media = IOIteratorNext(mediaIterator);
	
	if(media)
	{
		CFTypeRef path;

		path = IORegistryEntryCreateCFProperty(media,
			CFSTR(kIOBSDNameKey),
			kCFAllocatorDefault, 0);

		if (path)
		{
			size_t length;

			strcpy(cdrom_name, _PATH_DEV);
			strcat(cdrom_name, "r");
			length = strlen(cdrom_name);

			CFStringGetCString(path, cdrom_name + length,
				MAXPATHLEN - length, kCFStringEncodingUTF8);

			CFRelease(path);
		}
		IOObjectRelease(media);
	}

	if ((hCDROM = open(cdrom_name, O_RDONLY)) == -1)
	{
		return -1;
	}

	return 0;
}

static void MacOSXCDDeInit(void) 
{
	if (hCDROM != -1) 
	{
		close(hCDROM);
	}
}

static CDTOC * GetTOCFromCDPath(void)
{
	CFMutableDictionaryRef  classesToMatch;
	io_iterator_t mediaIterator;
	io_object_t media;
	CDTOC * TOC = NULL;

	classesToMatch = IOServiceMatching(kIOCDMediaClass); 
	CFDictionarySetValue(classesToMatch, CFSTR(kIOMediaEjectableKey),
		kCFBooleanTrue); 
	IOServiceGetMatchingServices(kIOMasterPortDefault,
		classesToMatch, &mediaIterator);    

	media = IOIteratorNext(mediaIterator);
	
	if(media)
	{
		CFDataRef TOCData = IORegistryEntryCreateCFProperty(media, CFSTR(kIOCDMediaTOCKey), kCFAllocatorDefault, 0);
		TOC = malloc(CFDataGetLength(TOCData));
		CFDataGetBytes(TOCData,CFRangeMake(0,CFDataGetLength(TOCData)),(UInt8 *)TOC);
		CFRelease(TOCData);
		IOObjectRelease(media);
	}
	
	return TOC;
}

static s32 MacOSXCDReadTOC(u32 *TOC) 
{
  	int add150 = 150, tracks = 0;
	u_char track;
	int i, fad = 0;
	CDTOC *cdTOC = GetTOCFromCDPath();
	CDTOCDescriptor *pTrackDescriptors;
	pTrackDescriptors = cdTOC->descriptors;

	memset(TOC, 0xFF, 0xCC * 2);

	/* Convert TOC to Saturn format */
	for( i = 3; i < CDTOCGetDescriptorCount(cdTOC); i++ ) {
        	track = pTrackDescriptors[i].point;
		fad = CDConvertMSFToLBA(pTrackDescriptors[i].p) + add150;
		if ((track > 99) || (track < 1))
			continue;
		TOC[i-3] = (pTrackDescriptors[i].control << 28 | pTrackDescriptors[i].adr << 24 | fad);
		tracks++;
	}

	/* First */
	TOC[99] = pTrackDescriptors[0].control << 28 | pTrackDescriptors[0].adr << 24 | 1 << 16;
	/* Last */
	TOC[100] = pTrackDescriptors[1].control << 28 | pTrackDescriptors[1].adr << 24 | tracks << 16;
	/* Leadout */
	TOC[101] = pTrackDescriptors[2].control << 28 | pTrackDescriptors[2].adr << 24 | CDConvertMSFToLBA(pTrackDescriptors[2].p) + add150;

	//free(cdTOC); Looks like this is not need, will look into that.
	return (0xCC * 2);
}

static int MacOSXCDGetStatus(void) 
{
	// 0 - CD Present, disc spinning
	// 1 - CD Present, disc not spinning
	// 2 - CD not present
	// 3 - Tray open
	// see ../windows/cd.cc for more info

	//Return that disc is present and spinning.  2 and 3 can't happen in the mac port, i don't understand what "not spinning" is supposed to say
	return 0;
}

static int MacOSXCDReadSectorFAD(u32 FAD, void *buffer) 
{
	const int blockSize = 2352;
#ifdef CRAB_REWRITE
    const int cacheBlocks = 32;
    static u8 cache[blockSize * cacheBlocks];
    static u32 cacheFAD = 0xFFFFFF00;
#endif
	
	if (hCDROM != -1) 
	{
#ifdef CRAB_REWRITE
        /* See if the block we are looking for is in the cache already... */
        if(FAD < cacheFAD || FAD >= cacheFAD + cacheBlocks) {
            /* Cache miss, read some blocks from the cd, then we'll hit the
               cache below. */
            if(!pread(hCDROM, cache, blockSize * cacheBlocks,
                      (FAD - 150) * blockSize)) {
                return 0;
            }

            cacheFAD = FAD;
        }

        /* Cache hit, copy the block out. */
        memcpy(buffer, cache + (blockSize * (FAD - cacheFAD)), blockSize);
        return 1;
#else
		if (pread(hCDROM, buffer, blockSize, (FAD - 150) * blockSize))
			return true;
#endif
	}
	
	return false;
}

static void MacOSXCDReadAheadFAD(UNUSED u32 FAD)
{
	// No-op
}
