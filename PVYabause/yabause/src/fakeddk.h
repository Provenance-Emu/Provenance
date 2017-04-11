/*
 * This file is not copyrighted, it comes from:
 * ntddcdrm.h and ntddstor.h from w32api package
 * ntddscsi.h from w64 mingw-runtime package
 *
 * Those three files are in the public domain.
 */

#define IOCTL_CDROM_BASE                  FILE_DEVICE_CD_ROM

#define MAXIMUM_NUMBER_TRACKS             100

#define SCSI_IOCTL_DATA_IN 1

#define IOCTL_SCSI_BASE         FILE_DEVICE_CONTROLLER
#define IOCTL_SCSI_PASS_THROUGH_DIRECT CTL_CODE(IOCTL_SCSI_BASE,0x0405,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_CDROM_READ_TOC \
  CTL_CODE(IOCTL_CDROM_BASE, 0x0000, METHOD_BUFFERED, FILE_READ_ACCESS)

typedef struct _TRACK_DATA {
  UCHAR  Reserved;
  UCHAR  Control : 4;
  UCHAR  Adr : 4;
  UCHAR  TrackNumber;
  UCHAR  Reserved1;
  UCHAR  Address[4];
} TRACK_DATA, *PTRACK_DATA;


typedef struct _CDROM_TOC {
  UCHAR  Length[2];
  UCHAR  FirstTrack;
  UCHAR  LastTrack;
  TRACK_DATA  TrackData[MAXIMUM_NUMBER_TRACKS];
} CDROM_TOC, *PCDROM_TOC;


typedef struct _SCSI_PASS_THROUGH_DIRECT {
  USHORT Length;
  UCHAR ScsiStatus;
  UCHAR PathId;
  UCHAR TargetId;
  UCHAR Lun;
  UCHAR CdbLength;
  UCHAR SenseInfoLength;
  UCHAR DataIn;
  ULONG DataTransferLength;
  ULONG TimeOutValue;
  PVOID DataBuffer;
  ULONG SenseInfoOffset;
  UCHAR Cdb[16];
}SCSI_PASS_THROUGH_DIRECT,*PSCSI_PASS_THROUGH_DIRECT;
