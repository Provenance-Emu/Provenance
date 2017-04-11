/*  Copyright 2003 Guillaume Duhamel
    Copyright 2004-2006 Theo Berkau

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

#ifndef CS2_H
#define CS2_H

#include "memory.h"
#include "cdbase.h"
#include "cs0.h"

#define MAX_BLOCKS      200
#define MAX_SELECTORS   24
#define MAX_FILES       256

typedef struct
{
   s32 size;
   u32 FAD;
   u8 cn;
   u8 fn;
   u8 sm;
   u8 ci;
   u8 data[2352];
} block_struct;

typedef struct
{
   u32 FAD;
   u32 range;
   u8 mode;
   u8 chan;
   u8 smmask;
   u8 cimask;
   u8 fid;
   u8 smval;
   u8 cival;
   u8 condtrue;
   u8 condfalse;
} filter_struct;

typedef struct
{
   s32 size;
   block_struct *block[MAX_BLOCKS];
   u8 blocknum[MAX_BLOCKS];
   u8 numblocks;
} partition_struct;

typedef struct
{
  u16 groupid;
  u16 userid;
  u16 attributes;
  u16 signature;
  u8 filenumber;
  u8 reserved[5];
} xarec_struct;

typedef struct
{
  u8 recordsize;
  u8 xarecordsize;
  u32 lba;
  u32 size;
  u8 dateyear;
  u8 datemonth;
  u8 dateday;
  u8 datehour;
  u8 dateminute;
  u8 datesecond;
  u8 gmtoffset;
  u8 flags;
  u8 fileunitsize;
  u8 interleavegapsize;
  u16 volumesequencenumber;
  u8 namelength;
  char name[32];
  xarec_struct xarecord;
} dirrec_struct;

typedef struct
{
   u8 vidplaymode;
   u8 dectimingmode;
   u8 outmode;
   u8 slmode;
} mpegmode_struct;

typedef struct
{
   u8 audcon;
   u8 audlay;
   u8 audbufnum;
   u8 vidcon;
   u8 vidlay;
   u8 vidbufnum;
} mpegcon_struct;

typedef struct
{
   u8 audstm;
   u8 audstmid;
   u8 audchannum;
   u8 vidstm;
   u8 vidstmid;
   u8 vidchannum;
} mpegstm_struct;

typedef struct
{
   u32 DTR;
   u16 UNKNOWN;
   u16 HIRQ;
   u16 HIRQMASK; // Masks bits from HIRQ -only- when generating A-bus interrupts
   u16 CR1;
   u16 CR2;
   u16 CR3;
   u16 CR4;
   u16 MPEGRGB;
} blockregs_struct;

typedef struct {
  blockregs_struct reg;
  u32 FAD;
  u8 status;

  // cd specific stats
  u8 options;
  u8 repcnt;
  u8 ctrladdr;
  u8 track;
  u8 index;

  // mpeg specific stats
  u8 actionstatus;
  u8 pictureinfo;
  u8 mpegaudiostatus;
  u16 mpegvideostatus;
  u16 vcounter;

  // authentication variables
  u16 satauth;
  u16 mpgauth;

  // internal varaibles
  u32 transfercount;
  u32 cdwnum;
  u32 TOC[102];
  u32 playFAD;
  u32 playendFAD;
  unsigned int maxrepeat;
  u32 getsectsize;
  u32 putsectsize;
  u32 calcsize;
  s32 infotranstype;
  s32 datatranstype;
  int isonesectorstored;
  int isdiskchanged;
  int isbufferfull;
  int speed1x;
  int isaudio;
  u8 transfileinfo[12];
  u8 lastbuffer;
  u8 transscodeq[5 * 2];
  u8 transscoderw[12 * 2];

  filter_struct filter[MAX_SELECTORS];
  filter_struct *outconcddev;
  filter_struct *outconmpegfb;
  filter_struct *outconmpegbuf;
  filter_struct *outconmpegrom;
  filter_struct *outconhost;
  u8 outconcddevnum;
  u8 outconmpegfbnum;
  u8 outconmpegbufnum;
  u8 outconmpegromnum;
  u8 outconhostnum;

  partition_struct partition[MAX_SELECTORS];

  partition_struct *datatranspartition;
  u8 datatranspartitionnum;
  s32 datatransoffset;
  u32 datanumsecttrans;
  u16 datatranssectpos;
  u16 datasectstotrans;

  u32 blockfreespace;
  block_struct block[MAX_BLOCKS];
  struct 
  {
     s32 size;
     u32 FAD;
     u8 cn;
     u8 fn;
     u8 sm;
     u8 ci;
     u8 data[2448];
  } workblock;

  u32 curdirsect;
  u32 curdirsize;
  u32 curdirfidoffset;
  dirrec_struct fileinfo[MAX_FILES];
  u32 numfiles;

  const char *mpegpath;

  u32 mpegintmask;

  mpegmode_struct mpegmode;
  mpegcon_struct mpegcon[2];
  mpegstm_struct mpegstm[2];

  int _command;
  u32 _statuscycles;
  u32 _statustiming;
  u32 _periodiccycles;  // microseconds * 3
  u32 _periodictiming;  // microseconds * 3
  u32 _commandtiming;
  CDInterface * cdi;

  int carttype;
  int playtype;  
} Cs2;

typedef struct {
   char system[17];
   char company[17];
   char itemnum[11];
   char version[7];
   char date[11];
   char cdinfo[9];
   char region[11];
   char peripheral[17];
   char gamename[113];
   u32 ipsize;
   u32 msh2stack;
   u32 ssh2stack;
   u32 firstprogaddr;
   u32 firstprogsize;
} ip_struct;

extern Cs2 * Cs2Area;
extern ip_struct * cdip;

int Cs2Init(int, int, const char *, const char *, const char *);
int Cs2ChangeCDCore(int coreid, const char *cdpath);
void Cs2DeInit(void);

u8 FASTCALL 	Cs2ReadByte(u32);
u16 FASTCALL 	Cs2ReadWord(u32);
u32 FASTCALL 	Cs2ReadLong(u32);
void FASTCALL 	Cs2WriteByte(u32, u8);
void FASTCALL 	Cs2WriteWord(u32, u16);
void FASTCALL 	Cs2WriteLong(u32, u32);

void FASTCALL   Cs2RapidCopyT1(void *dest, u32 count);
void FASTCALL   Cs2RapidCopyT2(void *dest, u32 count);

void Cs2Exec(u32);
int Cs2GetTimeToNextSector(void);
void Cs2Execute(void);
void Cs2Reset(void);
void Cs2SetTiming(int);
void Cs2Command(void);
void Cs2SetCommandTiming(u8 cmd);

//   command name                             command code
void Cs2GetStatus(void);                   // 0x00
void Cs2GetHardwareInfo(void);             // 0x01
void Cs2GetToc(void);                      // 0x02
void Cs2GetSessionInfo(void);              // 0x03
void Cs2InitializeCDSystem(void);          // 0x04
// Open Tray                               // 0x05
void Cs2EndDataTransfer(void);             // 0x06
void Cs2PlayDisc(void);                    // 0x10
void Cs2SeekDisc(void);                    // 0x11
// Scan Disc                               // 0x12
void Cs2GetSubcodeQRW(void);               // 0x20
void Cs2SetCDDeviceConnection(void);       // 0x30
// get CD Device Connection                // 0x31
void Cs2GetLastBufferDestination(void);    // 0x32
void Cs2SetFilterRange(void);              // 0x40
// get Filter Range                        // 0x41
void Cs2SetFilterSubheaderConditions(void);// 0x42
void Cs2GetFilterSubheaderConditions(void);// 0x43
void Cs2SetFilterMode(void);               // 0x44
void Cs2GetFilterMode(void);               // 0x45
void Cs2SetFilterConnection(void);         // 0x46
// Get Filter Connection                   // 0x47
void Cs2ResetSelector(void);               // 0x48
void Cs2GetBufferSize(void);               // 0x50
void Cs2GetSectorNumber(void);             // 0x51
void Cs2CalculateActualSize(void);         // 0x52
void Cs2GetActualSize(void);               // 0x53
void Cs2GetSectorInfo(void);               // 0x54
void Cs2SetSectorLength(void);             // 0x60
void Cs2GetSectorData(void);               // 0x61
void Cs2DeleteSectorData(void);            // 0x62
void Cs2GetThenDeleteSectorData(void);     // 0x63
void Cs2PutSectorData(void);               // 0x64
// Copy Sector Data                        // 0x65
// Move Sector Data                        // 0x66
void Cs2GetCopyError(void);                // 0x67
void Cs2ChangeDirectory(void);             // 0x70
void Cs2ReadDirectory(void);               // 0x71
void Cs2GetFileSystemScope(void);          // 0x72
void Cs2GetFileInfo(void);                 // 0x73
void Cs2ReadFile(void);                    // 0x74
void Cs2AbortFile(void);                   // 0x75
void Cs2MpegGetStatus(void);               // 0x90
void Cs2MpegGetInterrupt(void);            // 0x91
void Cs2MpegSetInterruptMask(void);        // 0x92
void Cs2MpegInit(void);                    // 0x93
void Cs2MpegSetMode(void);                 // 0x94
void Cs2MpegPlay(void);                    // 0x95
void Cs2MpegSetDecodingMethod(void);       // 0x96
// MPEG Out Decoding Sync                  // 0x97
// MPEG Get Timecode                       // 0x98
// MPEG Get Pts                            // 0x99
void Cs2MpegSetConnection(void);           // 0x9A
void Cs2MpegGetConnection(void);           // 0x9B
// MPEG Change Connection                  // 0x9C
void Cs2MpegSetStream(void);               // 0x9D
void Cs2MpegGetStream(void);               // 0x9E
// MPEG Get Picture Size                   // 0x9F
void Cs2MpegDisplay(void);                 // 0xA0
void Cs2MpegSetWindow(void);               // 0xA1
void Cs2MpegSetBorderColor(void);          // 0xA2
void Cs2MpegSetFade(void);                 // 0xA3
void Cs2MpegSetVideoEffects(void);         // 0xA4
// MPEG Get Image                          // 0xA5
// MPEG Set Image                          // 0xA6
// MPEG Read Image                         // 0xA7
// MPEG Write Image                        // 0xA8
// MPEG Read Sector                        // 0xA9
// MPEG Write Sector                       // 0xAA
// MPEG Get LSI                            // 0xAE
void Cs2MpegSetLSI(void);                  // 0xAF
void Cs2AuthenticateDevice(void);          // 0xE0
void Cs2IsDeviceAuthenticated(void);       // 0xE1
void Cs2GetMPEGRom(void);                  // 0xE2

u8 Cs2FADToTrack(u32 val);
u32 Cs2TrackToFAD(u16 trackandindex);
void Cs2FADToMSF(u32 val, u8 *m, u8 *s, u8 *f);
void Cs2SetupDefaultPlayStats(u8 track_number, int writeFAD);
block_struct * Cs2AllocateBlock(u8 * blocknum);
void Cs2FreeBlock(block_struct * blk);
void Cs2SortBlocks(partition_struct * part);
partition_struct * Cs2GetPartition(filter_struct * curfilter);
partition_struct * Cs2FilterData(filter_struct * curfilter, int isaudio);
int Cs2CopyDirRecord(u8 * buffer, dirrec_struct * dirrec);
int Cs2ReadFileSystem(filter_struct * curfilter, u32 fid, int isoffset);
void Cs2SetupFileInfoTransfer(u32 fid);
partition_struct * Cs2ReadUnFilteredSector(u32 rufsFAD);
//partition_struct * Cs2ReadFilteredSector(u32 rfsFAD);
int Cs2ReadFilteredSector(u32 rfsFAD, partition_struct **partition);
u8 Cs2GetIP(int autoregion);
u8 Cs2GetRegionID(void);
int Cs2SaveState(FILE *);
int Cs2LoadState(FILE *, int, int);

#endif
