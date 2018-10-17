/*  Copyright 2004-2005 Theo Berkau
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

/*! \file cd-windows.c
    \brief Windows port's cd interface using SPTI.
*/

#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#ifdef HAVE_NTDDCDRM
#include <ntddcdrm.h>
#include <ntddscsi.h>
#else
#include "fakeddk.h"
#endif
#include "cdbase.h"
#include "yabause.h"

//////////////////////////////////////////////////////////////////////////////

static HANDLE hCDROM;
static SCSI_PASS_THROUGH_DIRECT sptd;
static int KillCDThread=0;
static HANDLE thread_handle=INVALID_HANDLE_VALUE;
static CRITICAL_SECTION cd_cs;
static int drivestatus=0;
static DWORD thread_id;
static struct 
{
	int enable_read_ahead;
	u32 FAD;
	unsigned char data[2352];
	int num_sectors_read;
	int error_flag;
} cd_buf;

static int SPTICDInit(const char *);
static void SPTICDDeInit(void);
static s32 SPTICDReadTOC(u32 *);
static int SPTICDGetStatus(void);
static int SPTICDReadSectorFAD(u32, void *);
static void SPTICDReadAheadFAD(u32);

CDInterface ArchCD = {
CDCORE_ARCH,
"Windows SPTI Driver",
SPTICDInit,
SPTICDDeInit,
SPTICDGetStatus,
SPTICDReadTOC,
SPTICDReadSectorFAD,
SPTICDReadAheadFAD,
};

//////////////////////////////////////////////////////////////////////////////
// SPTI Interface
//////////////////////////////////////////////////////////////////////////////

DWORD WINAPI __stdcall SPTICDThread(void *b);

int SPTICDInit(const char *cdrom_name) {
	char pipe_name[7];

	sprintf(pipe_name, "\\\\.\\?:");
	pipe_name[4] = cdrom_name[0];

	if ((hCDROM = CreateFileA(pipe_name, GENERIC_READ | GENERIC_WRITE,
							FILE_SHARE_READ | FILE_SHARE_WRITE,
							NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
							NULL)) == INVALID_HANDLE_VALUE)
	{
		return -1;
	}

	// Setup a separate thread for handling SPTI commands(that way the emulation
	// code doesn't have to wait for a response)
	KillCDThread=0;
	memset(&cd_buf, 0, sizeof(cd_buf));
	thread_handle = CreateThread(NULL,0,(LPTHREAD_START_ROUTINE) SPTICDThread,(void *) &KillCDThread,0,&thread_id);
	InitializeCriticalSection(&cd_cs);
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

void SPTICDDeInit() {
	if (thread_handle != INVALID_HANDLE_VALUE)                               
	{
		// Set the flag telling it to stop
		KillCDThread=1;
		if (WaitForSingleObject(thread_handle,INFINITE) == WAIT_TIMEOUT)      
		{
			// Couldn't close thread cleanly
			TerminateThread(thread_handle,0);
		}
		CloseHandle(thread_handle);
		thread_handle = INVALID_HANDLE_VALUE;
	}
	DeleteCriticalSection(&cd_cs);

	CloseHandle(hCDROM);
}

//////////////////////////////////////////////////////////////////////////////

DWORD WINAPI __stdcall SPTICDThread(void *b)
{
	u64 curticks, lastticks = YabauseGetTicks();

	while (KillCDThread != 1)
	{
		DWORD dwBytesReturned;
		unsigned char statusbuf[8];
		BOOL success;

		EnterCriticalSection (&cd_cs);
		// Check to see if we have any work to do(for now, let's just do a drive
		// status check once a second)

		if (cd_buf.enable_read_ahead)
		{
			u32 FAD;
			DWORD dwBytesReturned;
			BOOL success;

			memset(&sptd, 0, sizeof(sptd));
			sptd.Length=sizeof(sptd);
			sptd.CdbLength=12;
			sptd.SenseInfoLength=0; // No sense data
			sptd.DataIn=SCSI_IOCTL_DATA_IN;
			sptd.TimeOutValue=60; // may need to be changed
			sptd.DataBuffer=(PVOID)cd_buf.data;
			sptd.SenseInfoOffset=0;
			sptd.DataTransferLength=2352; 

			sptd.Cdb[0]=0xBE; // CDB12 code
			sptd.Cdb[1]=0; // Sector Type, RELADR
			FAD = cd_buf.FAD - 150;
			sptd.Cdb[2]=(unsigned char)((FAD & 0xFF000000) >> 24); // lba(byte 1)
			sptd.Cdb[3]=(unsigned char)((FAD & 0x00FF0000) >> 16); // lba(byte 2)
			sptd.Cdb[4]=(unsigned char)((FAD & 0x0000FF00) >> 8);  // lba(byte 3)
			sptd.Cdb[5]=(unsigned char)(FAD & 0x000000FF);         // lba(byte 4)
			sptd.Cdb[6]=0; // number of sectors(byte 1)
			sptd.Cdb[7]=0; // number of sectors(byte 2)
			sptd.Cdb[8]=1; // number of sectors(byte 3)
			sptd.Cdb[9]=0xF8; // Sync + All Headers + User data + EDC/ECC

			success=DeviceIoControl(hCDROM,
				IOCTL_SCSI_PASS_THROUGH_DIRECT,
				(PVOID)&sptd, (DWORD)sizeof(SCSI_PASS_THROUGH_DIRECT),
				NULL, 0,
				&dwBytesReturned,
				NULL);

			if (success)
				cd_buf.num_sectors_read++;
			cd_buf.error_flag = success;
			cd_buf.enable_read_ahead = 0;
		}

		curticks = YabauseGetTicks();

		if (curticks-lastticks >= yabsys.tickfreq)
		{
			memset(&sptd, 0, sizeof(sptd));
			sptd.Length=sizeof(sptd);
			sptd.CdbLength=12;
			sptd.SenseInfoLength=0; // No sense data
			sptd.DataIn=SCSI_IOCTL_DATA_IN; 
			sptd.TimeOutValue=60; // may need to be changed
			sptd.DataBuffer=(PVOID)&(statusbuf);
			sptd.SenseInfoOffset=0;
			sptd.DataTransferLength=8; // may need to change this

			sptd.Cdb[0]=0xBD; // CDB12 code
			sptd.Cdb[8]=0; // Allocation Length(byte 1)
			sptd.Cdb[9]=8; // Allocation Length(byte 2) (may have to change this)

			success=DeviceIoControl(hCDROM, IOCTL_SCSI_PASS_THROUGH_DIRECT,
				(PVOID)&sptd, (DWORD)sizeof(SCSI_PASS_THROUGH_DIRECT),
				NULL, 0, &dwBytesReturned, NULL);

			if (success)
			{
				// Figure out drive status

				// Is door open?
				if (statusbuf[1] & 0x10)
					drivestatus = 3;
				else
				{
					// Ok, so the door is closed, now is there a disc there?
					success = DeviceIoControl(hCDROM, IOCTL_STORAGE_CHECK_VERIFY,
						NULL, 0, NULL, 0, &dwBytesReturned, NULL);
					if (!success)
						drivestatus = 2;
					else
						drivestatus = 0;
				}
			}
			//else
				//drivestatus = 2;
			
			lastticks = curticks;
		}

		LeaveCriticalSection(&cd_cs);
		SwitchToThread();
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

int SPTICDGetStatus() {
	// This function is called periodically to see what the status of the
	// drive is.
	//
	// Should return one of the following values:
	// 0 - CD Present, disc spinning
	// 1 - CD Present, disc not spinning
	// 2 - CD not present
	// 3 - Tray open
	//
	// If you really don't want to bother too much with this function, just
	// return status 0. Though it is kind of nice when the bios's cd player,
	// etc. recognizes when you've ejected the tray and popped in another disc.
	int status;
	EnterCriticalSection(&cd_cs);
	status = drivestatus;
	LeaveCriticalSection(&cd_cs);
	return status;
}

//////////////////////////////////////////////////////////////////////////////

#define MSF_TO_FAD(m,s,f) ((m * 4500) + (s * 75) + f)

s32 SPTICDReadTOC(u32 *TOC) {
	CDROM_TOC ctTOC;
	DWORD dwNotUsed;
	int i;

	if (hCDROM != INVALID_HANDLE_VALUE)
	{
		memset(TOC, 0xFF, 0xCC * 2);
		memset(&ctTOC, 0xFF, sizeof(CDROM_TOC));

		if (DeviceIoControl (hCDROM, IOCTL_CDROM_READ_TOC,
							NULL, 0, &ctTOC, sizeof(ctTOC),
							&dwNotUsed, NULL) == 0)
		{
			return 0;
		}

		// convert TOC to saturn format
		for (i = 0; i < ctTOC.LastTrack; i++)
		{
			TOC[i] = (ctTOC.TrackData[i].Control << 28) |
					(ctTOC.TrackData[i].Adr << 24) |
					MSF_TO_FAD(ctTOC.TrackData[i].Address[1], ctTOC.TrackData[i].Address[2], ctTOC.TrackData[i].Address[3]);
		}

		// Do First, Last, and Lead out sections here

		TOC[99] = (ctTOC.TrackData[0].Control << 28) |
				(ctTOC.TrackData[0].Adr << 24) |
				(ctTOC.FirstTrack << 16);

		TOC[100] = (ctTOC.TrackData[ctTOC.LastTrack - 1].Control << 28) |
				(ctTOC.TrackData[ctTOC.LastTrack - 1].Adr << 24) |
				(ctTOC.LastTrack << 16);

		TOC[101] = (ctTOC.TrackData[ctTOC.LastTrack].Control << 28) |
				(ctTOC.TrackData[ctTOC.LastTrack].Adr << 24) |
				MSF_TO_FAD(ctTOC.TrackData[ctTOC.LastTrack].Address[1], ctTOC.TrackData[ctTOC.LastTrack].Address[2], ctTOC.TrackData[ctTOC.LastTrack].Address[3]);

		return (0xCC * 2);
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////////

int SPTICDReadSectorFAD(u32 FAD, void *buffer) {
	// This function is supposed to read exactly 1 -RAW- 2352-byte sector at
	// the specified FAD address to buffer. Should return true if successful,
	// false if there was an error.
	//
	// Special Note: To convert from FAD to LBA/LSN, minus 150.
	//
	// The whole process needed to be changed since I need more control over
	// sector detection, etc. Not to mention it means less work for the porter
	// since they only have to implement raw sector reading as opposed to
	// implementing mode 1, mode 2 form1/form2, -and- raw sector reading.
	
	for (;;)
	{
		EnterCriticalSection(&cd_cs);
		if ((volatile)cd_buf.enable_read_ahead == 0)
		{
			if (cd_buf.FAD == FAD)
			{
				int ret;
				memcpy(buffer, cd_buf.data, 2352);
				ret = cd_buf.error_flag;
				LeaveCriticalSection(&cd_cs);
				return ret;
			}
			else
			{
				cd_buf.FAD = FAD;
				cd_buf.num_sectors_read = 0;
				cd_buf.error_flag = 0;
				cd_buf.enable_read_ahead = 1;
			}
		}
		LeaveCriticalSection(&cd_cs);
		SwitchToThread();
	}
}

//////////////////////////////////////////////////////////////////////////////

void SPTICDReadAheadFAD(u32 FAD) {
	EnterCriticalSection(&cd_cs);
	cd_buf.FAD = FAD;
	cd_buf.num_sectors_read = 0;
	cd_buf.error_flag = 0;
	cd_buf.enable_read_ahead = 1;
	LeaveCriticalSection(&cd_cs);
}

//////////////////////////////////////////////////////////////////////////////
