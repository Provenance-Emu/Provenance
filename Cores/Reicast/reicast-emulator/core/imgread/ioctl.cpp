#include "types.h"

#if HOST_OS==OS_WINDOWS
#include "common.h"

#include <stddef.h>
#include <Windows.h>

#include <ntddscsi.h>
#include "SCSIDEFS.H"


#ifndef noheaders
#define RAW_SECTOR_SIZE         2352
#define CD_SECTOR_SIZE          2048
#define MAXIMUM_NUMBER_TRACKS   100
#define SECTORS_AT_READ         20
#define CD_BLOCKS_PER_SECOND    75
#define IOCTL_CDROM_RAW_READ    0x2403E
#define IOCTL_CDROM_READ_TOC    0x24000
#define IOCTL_CDROM_READ_TOC_EX 0x24054

// These structures are defined somewhere in the windows-api, but I did
//   not have the include-file.
typedef struct _TRACK_DATA
{
	UCHAR Reserved;
	UCHAR Control : 4;
	UCHAR Adr : 4;
	UCHAR TrackNumber;
	UCHAR Reserved1;
	UCHAR Address[4];
} TRACK_DATA;

typedef struct _CDROM_TOC
{
	UCHAR Length[2];
	UCHAR FirstTrack;
	UCHAR LastTrack;
	TRACK_DATA TrackData[MAXIMUM_NUMBER_TRACKS];
} CDROM_TOC;

typedef enum _TRACK_MODE_TYPE
{
	YellowMode2,
	XAForm2,
	CDDA
} TRACK_MODE_TYPE, *PTRACK_MODE_TYPE;

typedef struct __RAW_READ_INFO
{
	LARGE_INTEGER  DiskOffset;
	ULONG  SectorCount;
	TRACK_MODE_TYPE  TrackMode;
} RAW_READ_INFO, *PRAW_READ_INFO;
typedef struct _CDROM_TOC_FULL_TOC_DATA_BLOCK {  UCHAR  SessionNumber;  UCHAR  Control:4;  UCHAR  Adr:4;  UCHAR  Reserved1;  UCHAR  Point;  UCHAR  MsfExtra[3];  UCHAR  Zero;  UCHAR  Msf[3];} CDROM_TOC_FULL_TOC_DATA_BLOCK, *PCDROM_TOC_FULL_TOC_DATA_BLOCK;
typedef struct _CDROM_TOC_FULL_TOC_DATA
{
	UCHAR  Length[2];
	UCHAR  FirstCompleteSession;
	UCHAR  LastCompleteSession;
	CDROM_TOC_FULL_TOC_DATA_BLOCK  Descriptors[0];
} CDROM_TOC_FULL_TOC_DATA, *PCDROM_TOC_FULL_TOC_DATA;
/* CDROM_READ_TOC_EX.Format constants */
  #define CDROM_READ_TOC_EX_FORMAT_TOC      0x00
  #define CDROM_READ_TOC_EX_FORMAT_SESSION  0x01
  #define CDROM_READ_TOC_EX_FORMAT_FULL_TOC 0x02
  #define CDROM_READ_TOC_EX_FORMAT_PMA      0x03
  #define CDROM_READ_TOC_EX_FORMAT_ATIP     0x04
  #define CDROM_READ_TOC_EX_FORMAT_CDTEXT   0x05
  
typedef struct _CDROM_READ_TOC_EX 
{
    UCHAR  Format : 4;
    UCHAR  Reserved1 : 3;
    UCHAR  Msf : 1;
    UCHAR  SessionTrack;
   UCHAR  Reserved2;
    UCHAR  Reserved3;
 } CDROM_READ_TOC_EX, *PCDROM_READ_TOC_EX;
#endif
struct spti_s 
{
	SCSI_PASS_THROUGH_DIRECT sptd;
	DWORD alignmentDummy;
	BYTE  senseBuf[0x12];
} ;

ULONG msf2fad( UCHAR Addr[4] )
{
	ULONG Sectors = ( Addr[0] * (CD_BLOCKS_PER_SECOND*60) ) + ( Addr[1]*CD_BLOCKS_PER_SECOND) + Addr[2];
	return Sectors;
}


// Msf: Hours, Minutes, Seconds, Frames
ULONG AddressToSectors( UCHAR Addr[4] );


bool spti_SendCommand(HANDLE hand,spti_s& s,SCSI_ADDRESS& ioctl_addr)
{
	s.sptd.Length             = sizeof(SCSI_PASS_THROUGH_DIRECT);
	s.sptd.PathId             = ioctl_addr.PathId;
	s.sptd.TargetId           = ioctl_addr.TargetId;
	s.sptd.Lun                = ioctl_addr.Lun;
	s.sptd.TimeOutValue       = 30;
	//s.sptd.CdbLength        = 0x0A;
	s.sptd.SenseInfoLength    = 0x12;
	s.sptd.SenseInfoOffset    = offsetof(spti_s, senseBuf);
//	s.sptd.DataIn             = 0x01;//DATA_IN
//	s.sptd.DataTransferLength = 0x800;
//	s.sptd.DataBuffer         = pdata;

	DWORD bytesReturnedIO = 0;
	if(!DeviceIoControl(hand, IOCTL_SCSI_PASS_THROUGH_DIRECT, &s, sizeof(s), &s, sizeof(s), &bytesReturnedIO, NULL)) 
		return false;

	if(s.sptd.ScsiStatus)
		return false;
	return true;
}

bool spti_Read10(HANDLE hand,void * pdata,u32 sector,SCSI_ADDRESS& ioctl_addr)
{
	spti_s s;
	memset(&s,0,sizeof(spti_s));

	s.sptd.Cdb[0] = SCSI_READ10;
	s.sptd.Cdb[1] = (ioctl_addr.Lun&7) << 5;// | DPO ;	DPO = 8

	s.sptd.Cdb[2] = (BYTE)(sector >> 0x18 & 0xFF); // MSB
	s.sptd.Cdb[3] = (BYTE)(sector >> 0x10 & 0xFF);
	s.sptd.Cdb[4] = (BYTE)(sector >> 0x08 & 0xFF);
	s.sptd.Cdb[5] = (BYTE)(sector >> 0x00 & 0xFF); // LSB

	s.sptd.Cdb[7] = 0;
	s.sptd.Cdb[8] = 1;
	
	s.sptd.CdbLength          = 0x0A;
	s.sptd.DataIn             = 0x01;//DATA_IN
	s.sptd.DataTransferLength = 0x800;
	s.sptd.DataBuffer         = pdata;

	return spti_SendCommand(hand,s,ioctl_addr);
}
bool spti_ReadCD(HANDLE hand,void * pdata,u32 sector,SCSI_ADDRESS& ioctl_addr)
{
	spti_s s;
	memset(&s,0,sizeof(spti_s));
	MMC_READCD& r=*(MMC_READCD*)s.sptd.Cdb;

	r.opcode	= MMC_READCD_OPCODE;
	

	//lba
	r.LBA[0] = (BYTE)(sector >> 0x18 & 0xFF);
	r.LBA[1] = (BYTE)(sector >> 0x10 & 0xFF);
	r.LBA[2] = (BYTE)(sector >> 0x08 & 0xFF);
	r.LBA[3] = (BYTE)(sector >> 0x00 & 0xFF);

	//1 sector
	r.len[0]=0;
	r.len[1]=0;
	r.len[2]=1;
	
	//0xF8
	r.sync=1;
	r.HeaderCodes=3;
	r.UserData=1;
	r.EDC_ECC=1;
	

	r.subchannel=1;
	
	s.sptd.CdbLength          = 12;
	s.sptd.DataIn             = 0x01;//DATA_IN
	s.sptd.DataTransferLength = 2448;
	s.sptd.DataBuffer         = pdata;
	return spti_SendCommand(hand,s,ioctl_addr);
}

struct PhysicalDrive;
struct PhysicalTrack:TrackFile
{
	PhysicalDrive* disc;
	PhysicalTrack(PhysicalDrive* disc) { this->disc=disc; }

	virtual void Read(u32 FAD,u8* dst,SectorFormat* sector_type,u8* subcode,SubcodeFormat* subcode_type);
};

struct PhysicalDrive:Disc
{
	HANDLE drive;
	SCSI_ADDRESS scsi_addr;
	bool use_scsi;

	PhysicalDrive()
	{
		drive=INVALID_HANDLE_VALUE;
		memset(&scsi_addr,0,sizeof(scsi_addr));
		use_scsi=false;
	}

	bool Build(wchar* path)
	{
		drive = CreateFile( path, GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,NULL, OPEN_EXISTING, 0, NULL);

		if ( INVALID_HANDLE_VALUE == drive )
			return false; //failed to open

		printf(" Opened device %s, reading TOC ...",path);
		// Get track-table and parse it
		CDROM_READ_TOC_EX tocrq={0};
		 
	 	tocrq.Format = CDROM_READ_TOC_EX_FORMAT_FULL_TOC;
	 	tocrq.Msf=1;
	 	tocrq.SessionTrack=1;
		u8 buff[2048];
	 	CDROM_TOC_FULL_TOC_DATA *ftd=(CDROM_TOC_FULL_TOC_DATA*)buff;
	
		ULONG BytesRead;
		memset(buff,0,sizeof(buff));
		int code = DeviceIoControl(drive,IOCTL_CDROM_READ_TOC_EX,&tocrq,sizeof(tocrq),ftd, 2048, &BytesRead, NULL);
		
//		CDROM_TOC toc;
		int currs=-1;
		if (0==code)
		{
			printf(" failed\n");
			//failed to read toc
			CloseHandle(drive);
			return false;
		}
		else
		{
			printf(" done !\n");

			type=CdRom_XA;

			BytesRead-=sizeof(CDROM_TOC_FULL_TOC_DATA);
			BytesRead/=sizeof(ftd->Descriptors[0]);

			for (u32 i=0;i<BytesRead;i++)
			{
				if (ftd->Descriptors[i].Point==0xA2)
				{
					this->EndFAD=msf2fad(ftd->Descriptors[i].Msf);
					continue;
				}
				if (ftd->Descriptors[i].Point>=1 && ftd->Descriptors[i].Point<=0x63 &&
					ftd->Descriptors[i].Adr==1)
				{
					u32 trackn=ftd->Descriptors[i].Point-1;
					verify(trackn==tracks.size());
					Track t;

					t.ADDR=ftd->Descriptors[i].Adr;
					t.CTRL=ftd->Descriptors[i].Control;
					t.StartFAD=msf2fad(ftd->Descriptors[i].Msf);
					t.file = new PhysicalTrack(this);

					tracks.push_back(t);

					if (currs!=ftd->Descriptors[i].SessionNumber)
					{
						currs=ftd->Descriptors[i].SessionNumber;
						verify(sessions.size()==(currs-1));
						Session s;
						s.FirstTrack=trackn+1;
						s.StartFAD=t.StartFAD;

						sessions.push_back(s);
					}
				}
			}
			LeadOut.StartFAD=EndFAD;
			LeadOut.ADDR=0;
			LeadOut.CTRL=0;
		}

		DWORD bytesReturnedIO = 0;
		BOOL resultIO = DeviceIoControl(drive, IOCTL_SCSI_GET_ADDRESS, NULL, 0, &scsi_addr, sizeof(scsi_addr), &bytesReturnedIO, NULL);
		//done !
		if (resultIO)
			use_scsi=true;
		else
			use_scsi=false;

		return true;
	}
};

void PhysicalTrack::Read(u32 FAD,u8* dst,SectorFormat* sector_type,u8* subcode,SubcodeFormat* subcode_type)
{
	u32 fmt=0;
	static u8 temp[2500];

	u32 LBA=FAD-150;

	if (disc->use_scsi)
	{
		if (!spti_ReadCD(disc->drive, temp,LBA,disc->scsi_addr))
		{
			if (spti_Read10(disc->drive, dst,LBA,disc->scsi_addr))
			{
				//sector read success, just user data
				*sector_type=SECFMT_2048_MODE2_FORM1; //m2f1 seems more common ? is there some way to detect it properly here?
				return;
			}
		}
		else
		{
			//sector read success, with subcode
			memcpy(dst,temp,2352);
			memcpy(subcode,temp+2352,96);

			*sector_type=SECFMT_2352;
			*subcode_type=SUBFMT_96;
			return;
		}
	}

	//hmm, spti failed/cannot be used


	//try IOCTL_CDROM_RAW_READ


	static __RAW_READ_INFO Info;
	
	Info.SectorCount=1;
	Info.DiskOffset.QuadPart = LBA * CD_SECTOR_SIZE; //CD_SECTOR_SIZE, even though we read RAW sectors. Its how winapi works.
	ULONG Dummy;
	
	//try all 3 track modes, starting from the one that succeeded last time (Info is static) to save time !
	for (int tr=0;tr<3;tr++)
	{
		if ( 0 == DeviceIoControl( disc->drive, IOCTL_CDROM_RAW_READ, &Info, sizeof(Info), dst, RAW_SECTOR_SIZE, &Dummy, NULL ) )
		{
			Info.TrackMode=(TRACK_MODE_TYPE)((Info.TrackMode+1)%3);	//try next mode
		}
		else
		{
			//sector read success
			*sector_type=SECFMT_2352;
			return;
		}
	}

	//finally, try ReadFile
	if (SetFilePointer(disc->drive,LBA*2048,0,FILE_BEGIN)!=INVALID_SET_FILE_POINTER)
	{
		DWORD BytesRead;
		if (FALSE!=ReadFile(disc->drive,dst,2048,&BytesRead,0) && BytesRead==2048)
		{
			//sector read success, just user data
			*sector_type=SECFMT_2048_MODE2_FORM1; //m2f1 seems more common ? is there some way to detect it properly here?
			return;
		}
	}

	printf("IOCTL: Totally failed to read sector @LBA %d\n", LBA);
}


Disc* ioctl_parse(const wchar* file)
{
	
	if (strlen(file)==3 && GetDriveType(file)==DRIVE_CDROM)
	{
		printf("Opening device %s ...",file);
		wchar fn[]={ '\\', '\\', '.', '\\', file[0],':', '\0' };
		PhysicalDrive* rv = new PhysicalDrive();	

		if (rv->Build(fn))
		{
			return rv;
		}
		else
		{
			delete rv;
			return 0;
		}
	}
	else
	{
		return 0;
	}
}

#endif