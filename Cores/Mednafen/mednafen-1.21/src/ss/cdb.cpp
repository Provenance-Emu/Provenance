/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* cdb.cpp - CD Block Emulation
**  Copyright (C) 2016-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

// TODO: Respect auth type with COMMAND_AUTH_DEVICE.

// TODO: Test INIT 0x00 side effects(and see if it affects CD device connection)

// TODO: edc_lec_check_and_correct

// TODO: Proper seek delays(for "Gungriffon" FMV)

// TODO: Some filesys commands(at least change dir, read file) seem to reset the saved command start and end positions(accessed via 0xFFFFFF to PLAY command) to something
// akin to 0.

// TODO: SMPC CD off/on

// TODO: Consider serializing HIRQ_PEND and HIRQ_SCDQ with command execution.

// TODO: Look into weird issue where WAIT status for Change Dir might be set to 1 slightly after CMOK IRQ is triggered...

// TODO: Test state reset on Init with SW reset.

// TODO: Scan command.

// TODO: assert()s

// TODO: Reject all commands during disc startup?

// TODO:     for(unsigned i = 0; i < 5; i++) DT_ReadIntoFIFO();

// TODO: Auth and auth type.

// TODO: Test play command while filesys op is in progress.

#include "ss.h"
#include <mednafen/mednafen.h>
#include "scu.h"
#include "sound.h"

#include <mednafen/cdrom/CDUtility.h>
#include <mednafen/cdrom/cdromif.h>
using namespace CDUtility;

namespace MDFN_IEN_SS
{

enum
{
 SECLEN__FIRST = 0,

 SECLEN_2048 = 0,
 SECLEN_2336 = 1,
 SECLEN_2340 = 2,
 SECLEN_2352 = 3,

 SECLEN__LAST = 3,
};

static uint8 GetSecLen, PutSecLen;

static uint8 AuthDiscType;
enum
{
 COMMAND_GET_CDSTATUS	= 0x00,
 COMMAND_GET_HWINFO	= 0x01,
 COMMAND_GET_TOC	= 0x02,
 COMMAND_GET_SESSINFO	= 0x03,
 COMMAND_INIT		= 0x04,
 COMMAND_OPEN		= 0x05,
 COMMAND_END_DATAXFER	= 0x06,

 COMMAND_PLAY		= 0x10,
 COMMAND_SEEK		= 0x11,
 COMMAND_SCAN		= 0x12,

 COMMAND_GET_SUBCODE	= 0x20,

 COMMAND_SET_CDDEVCONN	= 0x30,
 COMMAND_GET_CDDEVCONN	= 0x31,
 COMMAND_GET_LASTBUFDST	= 0x32,

 COMMAND_SET_FILTRANGE	= 0x40,
 COMMAND_GET_FILTRANGE	= 0x41,
 COMMAND_SET_FILTSUBHC	= 0x42,
 COMMAND_GET_FILTSUBHC	= 0x43,
 COMMAND_SET_FILTMODE	= 0x44,
 COMMAND_GET_FILTMODE	= 0x45,
 COMMAND_SET_FILTCONN	= 0x46,
 COMMAND_GET_FILTCONN	= 0x47,
 COMMAND_RESET_SEL	= 0x48,

 COMMAND_GET_BUFSIZE	= 0x50,
 COMMAND_GET_SECNUM	= 0x51,
 COMMAND_CALC_ACTSIZE	= 0x52,
 COMMAND_GET_ACTSIZE	= 0x53,
 COMMAND_GET_SECINFO	= 0x54,
 COMMAND_EXEC_FADSRCH	= 0x55,
 COMMAND_GET_FADSRCH	= 0x56,

 COMMAND_SET_SECLEN	= 0x60,
 COMMAND_GET_SECDATA	= 0x61,
 COMMAND_DEL_SECDATA	= 0x62,
 COMMAND_GETDEL_SECDATA	= 0x63,
 COMMAND_PUT_SECDATA	= 0x64,
 COMMAND_COPY_SECDATA	= 0x65,
 COMMAND_MOVE_SECDATA	= 0x66,
 COMMAND_GET_COPYERR	= 0x67,

 COMMAND_CHANGE_DIR	= 0x70,
 COMMAND_READ_DIR	= 0x71,
 COMMAND_GET_FSSCOPE	= 0x72,
 COMMAND_GET_FINFO	= 0x73,
 COMMAND_READ_FILE	= 0x74,
 COMMAND_ABORT_FILE	= 0x75,

 COMMAND_AUTH_DEVICE	= 0xE0,
 COMMAND_GET_AUTH	= 0xE1
};

static MDFN_COLD void GetCommandDetails(const uint16* CD, char* s, size_t sl)
{
 switch(CD[0] >> 8)
 {
  default:
	trio_snprintf(s, sl, "UNKNOWN: 0x%04x, 0x%04x, 0x%04x, 0x%04x", CD[0], CD[1], CD[2], CD[3]);
	break;

  case COMMAND_GET_CDSTATUS:
	trio_snprintf(s, sl, "Get CD Status");
	break;

  case COMMAND_GET_HWINFO:
	trio_snprintf(s, sl, "Get Hardware Info");
	break;

  case COMMAND_GET_TOC:
	trio_snprintf(s, sl, "Get TOC");
	break;

  case COMMAND_GET_SESSINFO:
	trio_snprintf(s, sl, "Get Session Info; Type=0x%02x", CD[0] & 0xFF);
	break;

  case COMMAND_INIT:
	trio_snprintf(s, sl, "Initialize; Flags=0x%02x, StandbyTime=0x%04x, ECC=0x%02x, Retry=0x%02x", CD[0] & 0xFF, CD[1], CD[3] >> 8, CD[3] & 0xFF);
	break;

  case COMMAND_OPEN:
	trio_snprintf(s, sl, "Open Tray");
	break;

  case COMMAND_END_DATAXFER:
	trio_snprintf(s, sl, "End Data Transfer");
	break;

  case COMMAND_PLAY:
	trio_snprintf(s, sl, "Play; Start=0x%06x, End=0x%06x, Mode=0x%02x", ((CD[0] & 0xFF) << 16) | CD[1], ((CD[2] & 0xFF) << 16) | CD[3], CD[2] >> 8);
	break;

  case COMMAND_SEEK:
	// 0xFFFFFF=pause, 0=stop
	trio_snprintf(s, sl, "Seek; Target=0x%06x", ((CD[0] & 0xFF) << 16) | CD[1]);
	break;

  case COMMAND_SCAN:
	trio_snprintf(s, sl, "Scan; Direction=0x%02x", CD[0] & 0xFF);
	break;

  case COMMAND_GET_SUBCODE:
	trio_snprintf(s, sl, "Get Subcode; Type=0x%02x", CD[0] & 0xFF);
	break;

  case COMMAND_SET_CDDEVCONN:
	trio_snprintf(s, sl, "Set CD Device Connection; Filter=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_GET_CDDEVCONN:
	trio_snprintf(s, sl, "Get CD Device Connection");
	break;

  case COMMAND_GET_LASTBUFDST:
	trio_snprintf(s, sl, "Get Last Buffer Destination");
	break;

  case COMMAND_SET_FILTRANGE:
	trio_snprintf(s, sl, "Set Filter Range; Filter=0x%02x, FAD=0x%06x, Count=0x%06x", CD[2] >> 8, ((CD[0] & 0xFF) << 16) | CD[1], ((CD[2] & 0xFF) << 16) | CD[3]);
	break;

  case COMMAND_GET_FILTRANGE:
	trio_snprintf(s, sl, "Get Filter Range; Filter=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_SET_FILTSUBHC:
	trio_snprintf(s, sl, "Set Filter Subheader Conditions; Filter=0x%02x, Channel=0x%02x, Sub Mode: 0x%02x(Mask=0x%02x), Coding Info: 0x%02x(Mask=0x%02x), File: 0x%02x", (CD[2] >> 8), CD[0] & 0xFF, CD[3] >> 8, CD[1] >> 8, CD[3] & 0xFF, CD[1] & 0xFF, CD[2] & 0xFF);
	break;

  case COMMAND_GET_FILTSUBHC:
	trio_snprintf(s, sl, "Get Filter Subheader Conditions; Filter=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_SET_FILTMODE:
	trio_snprintf(s, sl, "Set Filter Mode; Filter=0x%02x, Mode=0x%02x", (CD[2] >> 8), CD[0] & 0xFF);
	break;

  case COMMAND_GET_FILTMODE:
	trio_snprintf(s, sl, "Get Filter Mode; Filter=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_SET_FILTCONN:
	trio_snprintf(s, sl, "Set Filter Connection; Filter=0x%02x, Flags=0x%02x, True=0x%02x, False=0x%02x", (CD[2] >> 8), (CD[0] & 0xFF), (CD[1] >> 8), (CD[1] & 0xFF));
	break;

  case COMMAND_GET_FILTCONN:
	trio_snprintf(s, sl, "Get Filter Connection; Filter=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_RESET_SEL:
	trio_snprintf(s, sl, "Reset Selector; Flags=0x%02x, pn=0x%04x", CD[0] & 0xFF, CD[2] >> 8);
	break;

  case COMMAND_GET_BUFSIZE:
	trio_snprintf(s, sl, "Get Buffer Size");
	break;

  case COMMAND_GET_SECNUM:
	trio_snprintf(s, sl, "Get Sector Number; Source=0x%02x", CD[2] >> 8);
	break;

  case COMMAND_CALC_ACTSIZE:
	trio_snprintf(s, sl, "Calculate Actual Size; Source=0x%02x[0x%04x], Count=0x%02x", CD[2] >> 8, CD[1], CD[3]);
	break;

  case COMMAND_GET_ACTSIZE:
	trio_snprintf(s, sl, "Get Actual Size");
	break;

  case COMMAND_GET_SECINFO:
	trio_snprintf(s, sl, "Get Sector Info; Source=0x%02x[0x%04x]", CD[2] >> 8, CD[1]);
	break;

  case COMMAND_EXEC_FADSRCH:
	trio_snprintf(s, sl, "Execute FAD Search; Source=0x%02x[0x%04x], FAD=0x%06x", CD[2] >> 8, CD[1], ((CD[2] & 0xFF) << 16) | CD[3]);
	break;

  case COMMAND_GET_FADSRCH:
	trio_snprintf(s, sl, "Get FAD Search Results");
	break;

  case COMMAND_SET_SECLEN:
	trio_snprintf(s, sl, "Set Sector Length; Get: 0x%02x, Put: 0x%02x", (CD[0] & 0xFF), (CD[1] >> 8));
	break;

  case COMMAND_GET_SECDATA:
	trio_snprintf(s, sl, "Get Sector Data; Source=0x%02x[0x%04x], Count=0x%04x", CD[2] >> 8, CD[1], CD[3]);
	break;

  case COMMAND_DEL_SECDATA:
	trio_snprintf(s, sl, "Delete Sector Data; Source=0x%02x[0x%04x], Count=0x%04x", CD[2] >> 8, CD[1], CD[3]);
	break;

  case COMMAND_GETDEL_SECDATA:
	trio_snprintf(s, sl, "Get and Delete Sector Data; Source=0x%02x[0x%04x], Count=0x%04x", CD[2] >> 8, CD[1], CD[3]);
	break;

  case COMMAND_PUT_SECDATA:
	trio_snprintf(s, sl, "Put Sector Data; Filter=0x%02x, Count=0x%04x", CD[2] >> 8, CD[3]);
	break;

  case COMMAND_COPY_SECDATA:
	trio_snprintf(s, sl, "Copy Sector Data; Source=0x%02x[0x%04x], Dest=0x%02x, Count=0x%04x", CD[2] >> 8, CD[1], CD[0] & 0xFF, CD[3]);
	break;

  case COMMAND_MOVE_SECDATA:
	trio_snprintf(s, sl, "Move Sector Data; Source=0x%02x[0x%04x], Dest=0x%02x, Count=0x%04x", CD[2] >> 8, CD[1], CD[0] & 0xFF, CD[3]);
	break;

  case COMMAND_GET_COPYERR:
	trio_snprintf(s, sl, "Get Copy Error");
	break;

  case COMMAND_CHANGE_DIR:
	trio_snprintf(s, sl, "Change Directory; ID=0x%06x, Filter: 0x%02x", ((CD[2] & 0xFF) << 16) | CD[3], (CD[2] >> 8));
	break;

  case COMMAND_READ_DIR:
	trio_snprintf(s, sl, "Read Directory; ID=0x%06x, Filter=0x%02x", ((CD[2] & 0xFF) << 16) | CD[3], (CD[2] >> 8));
	break;

  case COMMAND_GET_FSSCOPE:
	trio_snprintf(s, sl, "Get Filesystem Scope");
	break;

  case COMMAND_GET_FINFO:
	trio_snprintf(s, sl, "Get File Info; ID=0x%06x", ((CD[2] & 0xFF) << 16) | CD[3]);
	break;

  case COMMAND_READ_FILE:
	trio_snprintf(s, sl, "Read File; Offset=0x%06x, ID=0x%06x, Filter=0x%02x\n", ((CD[0] & 0xFF) << 16) | CD[1], ((CD[2] & 0xFF) << 16) | CD[3], CD[2] >> 8);
	break;

  case COMMAND_ABORT_FILE:
	trio_snprintf(s, sl, "Abort File");
	break;

  case COMMAND_AUTH_DEVICE:
	trio_snprintf(s, sl, "Authenticate Device; Type=0x%04x, Filter=0x%02x", CD[1], CD[2] >> 8);
	break;

  case COMMAND_GET_AUTH:
	trio_snprintf(s, sl, "Get Device Authentication Status");
	break;
 }
}


enum
{
 STATUS_BUSY	 = 0x00,
 STATUS_PAUSE	 = 0x01,
 STATUS_STANDBY	 = 0x02,
 STATUS_PLAY	 = 0x03,
 STATUS_SEEK	 = 0x04,
 STATUS_SCAN	 = 0x05,
 STATUS_OPEN	 = 0x06,
 STATUS_NODISC	 = 0x07,
 STATUS_RETRY	 = 0x08,
 STATUS_ERROR	 = 0x09,
 STATUS_FATAL	 = 0x0A,

 //
 STATUS_PERIODIC = 0x20,
 STATUS_DTREQ	 = 0x40,
 STATUS_WAIT	 = 0x80,

 //
 STATUS_REJECTED = 0xFF
};

enum
{
 HIRQ_CMOK = 0x0001,	// command ok?
 HIRQ_DRDY = 0x0002,	// data transfer ready
 HIRQ_CSCT = 0x0004,	// 1 sector read complete?
 HIRQ_BFUL = 0x0008,	// buffer full
 HIRQ_PEND = 0x0010,	// play end (FIXME: Status must indicate a "Pause" state at the time this is triggered)
 HIRQ_DCHG = 0x0020,	// disc change
 HIRQ_ESEL = 0x0040,	// end of selector something?
 HIRQ_EHST = 0x0080,	// end of host I/O?
 HIRQ_ECPY = 0x0100,	// end of copy/move
 HIRQ_EFLS = 0x0200,	// end of filesystem something?
 HIRQ_SCDQ = 0x0400,	// Sub-channel Q update complete?

 HIRQ_MPED = 0x0800,
 HIRQ_MPCM = 0x1000,
 HIRQ_MPST = 0x2000
};
static uint16 HIRQ, HIRQ_Mask;
static uint16 CData[4];
static uint16 Results[4];
static bool CommandPending;
static uint16 SWResetHIRQDeferred;
static bool SWResetPending;

static uint8 CDDevConn;
static uint8 LastBufDest;

enum : int { NumBuffers = 0xC8 };
static struct BufferT
{
 uint8 Data[2352];
 uint8 Prev;
 uint8 Next;
} Buffers[NumBuffers];

static struct FilterS
{
 enum
 {
  MODE_SEL_FILE    = 0x01,
  MODE_SEL_CHANNEL = 0x02,
  MODE_SEL_SUBMODE = 0x04,
  MODE_SEL_CINFO   = 0x08,
  MODE_SEL_SHREV   = 0x10,	// Reverse sub-header conditions
  MODE_SEL_FADR	   = 0x40,
  MODE_INIT	   = 0x80
 };

 uint8 Mode;
 uint8 TrueConn;
 uint8 FalseConn;
 //
 uint32 FAD;
 uint32 Range;

 uint8 Channel;
 uint8 File;

 uint8 SubMode;
 uint8 SubModeMask;

 uint8 CInfo;
 uint8 CInfoMask;
} Filters[0x18];

static struct
{
 uint8 FirstBuf;
 uint8 LastBuf;
 uint8 Count;
} Partitions[0x18];

static uint8 FirstFreeBuf;
static uint8 FreeBufferCount;

static struct
{
 uint32 fad;
 uint16 spos;
 uint8 pnum;
} FADSearch;

static uint32 CalcedActualSize;
//
//
//
//
//
static bool TrayOpen;
static CDIF* Cur_CDIF;
static CDUtility::TOC toc;
static sscpu_timestamp_t lastts;
static int32 CommandPhase;
//static bool CommandYield;
static int64 CommandClockCounter;
static uint32 CDB_ClockRatio;

static struct
{
 uint8 Command;
 uint16 CD[4];
} CTR;

static struct
{
 bool Active;
 bool Writing;
 bool NeedBufFree;

 unsigned CurBufIndex;
 unsigned BufCount;

 unsigned InBufOffs;
 unsigned InBufCounter;

 unsigned TotalCounter;

 uint8 FNum;

 uint16 FIFO[6];
 uint8 FIFO_RP;
 uint8 FIFO_WP;
 uint8 FIFO_In;

 uint8 BufList[NumBuffers];
} DT;

static uint16 StandbyTime;
static uint8 ECCEnable;
static uint8 RetryCount;

static bool ResultsRead;

static int32 SeekIndexPhase;
static uint32 CurSector;
static int32 DrivePhase;

enum
{
 DRIVEPHASE_STOPPED = 0,
 DRIVEPHASE_PLAY,

 DRIVEPHASE_SEEK_START,
 DRIVEPHASE_SEEK,
 DRIVEPHASE_SCAN,

 DRIVEPHASE_EJECTED0,
 DRIVEPHASE_EJECTED1,
 DRIVEPHASE_EJECTED_WAITING,
 DRIVEPHASE_STARTUP,

 DRIVEPHASE_RESETTING
};
static int64 DriveCounter;
static int64 PeriodicIdleCounter;
enum : int64 { PeriodicIdleCounter_Reload = (int64)187065 << 32 };

static uint8 PlayRepeatCounter;
static uint8 CurPlayRepeat;

static uint32 CurPlayStart;
static uint32 CurPlayEnd;
static uint32 PlayEndIRQType;
//static uint32 PlayEndIRQPending;

static uint32 PlayCmdStartPos, PlayCmdEndPos;
static uint8 PlayCmdRepCnt;

enum : int { CDDABuf_PrefillCount = 4 };
enum : int { CDDABuf_MaxCount = 4 + 588 + 4 };
static uint16 CDDABuf[CDDABuf_MaxCount][2];
static uint32 CDDABuf_RP, CDDABuf_WP;
static uint32 CDDABuf_Count;

static uint8 SecPreBuf[2352 + 96];
static int SecPreBuf_In;

static uint8 TOC_Buffer[(99 + 3) * 4];

static struct
{
 uint8 status;
 uint32 fad;
 uint32 rel_fad;
 uint8 ctrl_adr;
 uint8 idx;
 uint8 tno;

 bool is_cdrom;
 uint8 repcount;
} CurPosInfo;

// Higher-level:
static uint8 SubCodeQBuf[10];
static uint8 SubCodeRWBuf[24];

// SubQBuf for ADR=1 only for now.
static uint8 SubQBuf[0xC];
static uint8 SubQBuf_Safe[0xC];
static bool SubQBuf_Safe_Valid;

static bool DecodeSubQ(uint8 *subpw)
{
 uint8 tmp_q[0xC];

 memset(tmp_q, 0, 0xC);

 for(int i = 0; i < 96; i++)
  tmp_q[i >> 3] |= ((subpw[i] & 0x40) >> 6) << (7 - (i & 7));

 if((tmp_q[0] & 0xF) == 1)
 {
  memcpy(SubQBuf, tmp_q, 0xC);

  if(subq_check_checksum(tmp_q))
  {
   memcpy(SubQBuf_Safe, tmp_q, 0xC);
   SubQBuf_Safe_Valid = true;
   return(true);
  }
 }

 return(false);
}

static void ResetBuffers(void)
{
 Buffers[0].Prev = 0xFF;
 Buffers[0].Next = 1;
 for(unsigned i = 1; i < (NumBuffers - 1); i++)
 {
  Buffers[i].Prev = i - 1;
  Buffers[i].Next = i + 1;
 }
 Buffers[NumBuffers - 1].Prev = NumBuffers - 1 - 1;
 Buffers[NumBuffers - 1].Next = 0xFF;

 FirstFreeBuf = 0;
 FreeBufferCount = NumBuffers;

 for(unsigned i = 0; i < 0x18; i++)
 {
  Partitions[i].FirstBuf = 0xFF;
  Partitions[i].LastBuf = 0xFF;
  Partitions[i].Count = 0;
 }
}

static void Filter_ResetCond(const unsigned fnum)
{
 auto& f = Filters[fnum];

 f.Mode = 0;

 f.FAD = 0;
 f.Range = 0;

 f.Channel = 0;
 f.File = 0;

 f.SubMode = 0;
 f.SubModeMask = 0;

 f.CInfo = 0;
 f.CInfoMask = 0;
}

static uint8 Buffer_Allocate(const bool zero_clear)
{
 const unsigned bfsidx = FirstFreeBuf;
 assert(bfsidx != 0xFF && FreeBufferCount > 0);

 if(zero_clear)
  memset(Buffers[bfsidx].Data, 0x00, sizeof(Buffers[bfsidx].Data));

 if(Buffers[bfsidx].Prev == 0xFF)
  FirstFreeBuf = Buffers[bfsidx].Next;
 else
  Buffers[Buffers[bfsidx].Prev].Next = Buffers[bfsidx].Next;

 if(Buffers[bfsidx].Next == 0xFF)
 {

 }
 else
  Buffers[Buffers[bfsidx].Next].Prev = Buffers[bfsidx].Prev;

 FreeBufferCount--;

 //
 Buffers[bfsidx].Prev = 0xFF;
 Buffers[bfsidx].Next = 0xFF;
 //

 return bfsidx;
}

// Must not alter "Data" member, as it may be used while "free"'d.
static void Buffer_Free(const uint8 bfsidx)
{
 assert((FirstFreeBuf == 0xFF && FreeBufferCount == 0) || (FirstFreeBuf != 0xFF && FreeBufferCount > 0));
 assert(Buffers[bfsidx].Next == 0xFF && Buffers[bfsidx].Prev == 0xFF);

 Buffers[bfsidx].Prev = 0xFF;
 Buffers[bfsidx].Next = FirstFreeBuf;

 if(FirstFreeBuf != 0xFF)
 {
  assert(Buffers[FirstFreeBuf].Prev == 0xFF);
  Buffers[FirstFreeBuf].Prev = bfsidx;
 }

 FreeBufferCount++;
 FirstFreeBuf = bfsidx;
}

static void Partition_LinkBuffer(const unsigned pnum, const unsigned bfsidx)
{
 assert(Buffers[bfsidx].Next == 0xFF && Buffers[bfsidx].Prev == 0xFF);

 Buffers[bfsidx].Next = 0xFF;

 if(Partitions[pnum].FirstBuf == 0xFF)
 {
  assert(Partitions[pnum].LastBuf == 0xFF);
  Partitions[pnum].FirstBuf = bfsidx;
  Partitions[pnum].LastBuf = bfsidx;
  Buffers[bfsidx].Prev = 0xFF;
 }
 else
 {
  assert(Partitions[pnum].LastBuf != 0xFF);
  Buffers[Partitions[pnum].LastBuf].Next = bfsidx;
  Buffers[bfsidx].Prev = Partitions[pnum].LastBuf;
 }

 Partitions[pnum].LastBuf = bfsidx;
 Partitions[pnum].Count++;
}

static int Partition_GetBuffer(unsigned pnum, unsigned rbi)
{
 for(unsigned ii = Partitions[pnum].FirstBuf; ii != 0xFF; ii = Buffers[ii].Next)
 {
  if(!rbi)
   return ii;

  rbi--;
 }

 return -1;
}

// Must not alter "Data" member, as it may be used while unlinked.
static void Partition_UnlinkBuffer(unsigned pnum, unsigned bfsidx)
{
 assert(Partitions[pnum].Count > 0);

 Partitions[pnum].Count--;

 if(Buffers[bfsidx].Prev == 0xFF)
 {
  assert(Partitions[pnum].FirstBuf == bfsidx);
  Partitions[pnum].FirstBuf = Buffers[bfsidx].Next;
 }
 else
 {
  assert(Partitions[pnum].FirstBuf != bfsidx);
  Buffers[Buffers[bfsidx].Prev].Next = Buffers[bfsidx].Next;
 }

 if(Buffers[bfsidx].Next == 0xFF)
 {
  assert(Partitions[pnum].LastBuf == bfsidx);
  Partitions[pnum].LastBuf = Buffers[bfsidx].Prev;
 }
 else
 {
  assert(Partitions[pnum].LastBuf != bfsidx);
  Buffers[Buffers[bfsidx].Next].Prev = Buffers[bfsidx].Prev;
 }

 //
 Buffers[bfsidx].Prev = 0xFF;
 Buffers[bfsidx].Next = 0xFF;
}

static void SetCDDeviceConn(const uint8 fnum)
{
 for(unsigned fs = 0; fs < 0x18; fs++)
  if(Filters[fs].FalseConn == fnum)
   Filters[fs].FalseConn = 0xFF;

 CDDevConn = fnum;
}

static void Filter_SetRange(const uint8 fnum, const uint32 fad, const uint32 range)
{
 Filters[fnum].FAD = fad;
 Filters[fnum].Range = range;
}

static void Filter_SetTrueConn(const uint8 fnum, const uint8 tconn)
{
 Filters[fnum].TrueConn = tconn;
}

static void Filter_DisconnectInput(const uint8 fnum)
{
 if(fnum == 0xFF)
  return;

 if(CDDevConn == fnum)
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Filter 0x%02x input disconnected from CD device as side effect!\n", fnum);
  CDDevConn = 0xFF;
 }

 for(unsigned fs = 0; fs < 0x18; fs++)
 {
  if(Filters[fs].FalseConn == fnum)
  {
   SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Filter 0x%02x input disconnected from filter 0x%02x output as side effect!\n", fnum, fs);
   Filters[fs].FalseConn = 0xFF;
  }
 }
}

static void Filter_SetFalseConn(const uint8 fnum, const uint8 fconn)
{
 Filter_DisconnectInput(fconn);
 Filters[fnum].FalseConn = fconn;
}

static void Partition_Clear(const unsigned pnum)
{
 while(Partitions[pnum].Count > 0)
 {
  const unsigned bfi = Partitions[pnum].FirstBuf;

  Partition_UnlinkBuffer(pnum, bfi);
  Buffer_Free(bfi);
 }
}

//
//
//
//
//
static struct FileInfoS
{
 uint8 fad_be[4];
 uint8 size_be[4];

 INLINE uint32 fad(void) const { return MDFN_de32msb(fad_be); }
 INLINE uint32 size(void) const { return MDFN_de32msb(size_be); }

 uint8 unit_size;
 uint8 gap_size;
 uint8 fnum;
 uint8 attr;
} FileInfo[256];
static_assert(sizeof(FileInfoS) == 12 && sizeof(FileInfo) == 12 * 256, "FileInfo wrong size!");
static bool FileInfoValid;

enum
{
 FATTR_DIR = 0x02,
 FATTR_XA_M2F1 = 0x08,
 FATTR_XA_M2F2 = 0x10,
 FATTR_XA_ILEAVE = 0x20,
 FATTR_XA_CDDA = 0x40,
 FATTR_XA_DIR = 0x80
};


static FileInfoS RootDirInfo;
static bool RootDirInfoValid;

static struct
{
 bool Active;
 bool DoAuth;
 bool Abort;
 uint8 pnum;

 uint32 CurDirFAD;

 uint8 FileInfoValidCount;	// 0 ... 254
 uint32 FileInfoOffs;		// 2 ... whatever
 uint32 FileInfoOnDiscCount;	// 0 ... infinities

 uint32 Phase;

 uint8 pbuf[2048];
 uint32 pbuf_offs;
 uint32 pbuf_read_i;

 uint32 total_counter;
 uint32 total_max;

 uint8 record[256];
 uint32 record_counter;

 uint32 finfo_offs;
} FLS;


enum : int { FLSPhaseBias = __COUNTER__ + 1 };

#define FLS_PROLOGUE	 switch(FLS.Phase + FLSPhaseBias) { for(;;) { default: case __COUNTER__: ;
#define FLS_EPILOGUE  }	} FLSGetOut:;

#define FLS_YIELD	   {							\
			    FLS.Phase = __COUNTER__ - FLSPhaseBias + 1;		\
			    goto FLSGetOut;					\
			    case __COUNTER__:;					\
			   }

#define FLS_WAIT_UNTIL_COND(n) {						\
			    case __COUNTER__:					\
			    if(!(n))						\
			    {							\
			     FLS.Phase = __COUNTER__ - FLSPhaseBias - 1;	\
			     goto FLSGetOut;					\
			    }							\
			   }

#define FLS_WAIT_GRAB_BUF 						\
	  FLS_WAIT_UNTIL_COND(Partitions[FLS.pnum].Count > 0);		\
	  {								\
	   const unsigned bfi = Partitions[FLS.pnum].FirstBuf;		\
	   const uint8* const dptr = Buffers[bfi].Data;			\
	   Partition_UnlinkBuffer(FLS.pnum, bfi);			\
	   memcpy(FLS.pbuf, &dptr[(dptr[15] == 0x2) ? 24 : 16], 2048);	\
	   Buffer_Free(bfi);						\
	  }								

#define FLS_READ(buffer, count)						\
	for(FLS.pbuf_read_i = 0; FLS.pbuf_read_i < (count); FLS.pbuf_read_i++)	\
	{								\
	 if(FLS.pbuf_offs == 0)						\
	 {								\
          FLS_WAIT_GRAB_BUF;						\
	 }								\
	 if((buffer) != NULL)						\
	  (buffer)[FLS.pbuf_read_i] = FLS.pbuf[FLS.pbuf_offs];		\
	 FLS.pbuf_offs = (FLS.pbuf_offs + 1) % 2048;			\
	 FLS.total_counter++;						\
	}

static void ReadRecord(FileInfoS* fi, const uint8* rr)
{
 const uint8 rec_len = rr[0];
 const uint8 fi_len = rr[32];

 MDFN_en32msb(fi->fad_be, 150 + MDFN_de32msb(&rr[6]));
 MDFN_en32msb(fi->size_be, MDFN_de32msb(&rr[14]));

 fi->attr = rr[25] & 0x2;
 fi->unit_size = rr[26];
 fi->gap_size = rr[27];
 fi->fnum = 0;

 int su_offs = 33 + (fi_len | 1);
 int su_len = (rec_len - su_offs);

 //printf("%d %d %d %d\n", rec_len, fi_len, su_offs, su_len);

 if(su_len >= 14 && (su_offs + su_len) <= 256)
 {
  if(rr[su_offs + 6] == 'X' && rr[su_offs + 7] == 'A')
  {
   fi->attr |= rr[su_offs + 4] & 0xF8;
   fi->fnum = rr[su_offs + 8];
  }
 }

 //printf("Meow: fad=%08x size=%08x attr=%02x us=%02x gs=%02x fnum=%02x %s\n", fi->fad(), fi->size(), fi->attr, fi->unit_size, fi->gap_size, fi->fnum, &FLS.record[33]);
}

static void ClearPendingSec(void);

static bool FLS_Run(void)
{
 bool ret = false;
 //printf("%d, %d\n", Partitions[FLS.pnum].Count, FreeBufferCount);

 if(FLS.Abort)
 {
  if(FLS.Active)
  {
   SS_DBG(SS_DBG_CDB, "[CDB] FLS Abort: %d %d\n", FLS.Active, FLS.DoAuth);
  }

  goto Abort;
 }

 //
 FLS_PROLOGUE;
 //
 if(FLS.Active)
 {
  if(FLS.DoAuth)
  {
   RootDirInfoValid = false;
   AuthDiscType = 0x04; // FIXME: //0x02;

   for(;;)
   {
    static const char stdid[5] = { 'C', 'D', '0', '0', '1' };
    FLS_WAIT_GRAB_BUF;

    if(memcmp(FLS.pbuf + 1, stdid, 5) || FLS.pbuf[0] == 0xFF)
     break;
    else if(FLS.pbuf[0] == 0x01)	// PVD
    {
     //printf("MEOW MEOW:");
     //for(unsigned i = 0; i < 64; i++)
     // printf("%02x ", FLS.pbuf[156 + i]);
     //printf("\n");

     ReadRecord(&RootDirInfo, &FLS.pbuf[156]);
     RootDirInfoValid = true;
     break;
    }
   }
   SetCDDeviceConn(0xFF);
  }
  else
  {
   FileInfoValid = false;
   //
   //
   FLS.total_counter = 0;
   FLS.pbuf_offs = 0;
   FLS.FileInfoValidCount = 0;
   FLS.record_counter = 0;
   FLS.finfo_offs = 0;

   //printf("Start\n");
   while(FLS.total_counter < FLS.total_max)
   {
    memset(FLS.record, 0, sizeof(FLS.record));

    FLS_READ(&FLS.record[0], 1);
    if(!FLS.record[0])
     continue;
    FLS_READ(&FLS.record[1], FLS.record[0] - 1);

    if(FLS.finfo_offs < 256)
    {
     if(FLS.record_counter < 2 || FLS.record_counter >= FLS.FileInfoOffs)
     {
      ReadRecord(&FileInfo[FLS.finfo_offs], FLS.record);

      FLS.finfo_offs++;

      if(FLS.record_counter >= 2)
       FLS.FileInfoValidCount++;
     }
     FLS.record_counter++;
    }
   }

   FLS.FileInfoOnDiscCount = FLS.record_counter;
   //
   //
   FileInfoValid = true;
  }

  Partition_Clear(FLS.pnum);	// Place before Abort:;
  //
  //
  //
  Abort:;
  FLS.Active = false;
  FLS.DoAuth = false;
  FLS.Abort = false;
  //
  // Pause
  //
  PlayEndIRQType = 0;
  CurPlayStart = 0x800000;
  CurPlayEnd = 0x800000;
  CurPlayRepeat = 0;
  //
  //
  //

  ret = true;
 }
 FLS_YIELD;
 //
 FLS_EPILOGUE;

 return ret;
}

//
// Sector size can change in the middle of the transfer, and takes effect around sector buffer boundaries
//
static void DT_SetIBOffsCount(const uint8* sd)
{
 if(DT.Writing)
 {
  static const unsigned DTW_OffsTab[4] = { 12, 8, 6, 0 };
  static const unsigned DTW_CountTab[4] = { 1024, 1168, 1170, 1176 };

  DT.InBufOffs = DTW_OffsTab[PutSecLen];
  DT.InBufCounter = DTW_CountTab[PutSecLen];
 }
 else switch(GetSecLen)
 {
  case SECLEN_2048:
	if(sd[12 + 3] == 0x1)	// Mode 1
	{
	 DT.InBufOffs = 8;
	 DT.InBufCounter = 1024;
	}
	else	// Mode 2
	{
	 if(sd[16 + 2] & 0x20) // Form 2
	 {
	  DT.InBufOffs = 12;
	  DT.InBufCounter = 1162;
	 }
	 else // Form 1
	 {
	  DT.InBufOffs = 12;
	  DT.InBufCounter = 1024;
	 }
	}
	break;

  case SECLEN_2336:
	DT.InBufOffs = 8;
	DT.InBufCounter = 1168;
	break;

  case SECLEN_2340:
	DT.InBufOffs = 6;
	DT.InBufCounter = 1170;
	break;

  case SECLEN_2352:
	DT.InBufOffs = 0;
	DT.InBufCounter = 1176;
	break;
 }

 if(!DT.Writing)
 {
  const uint32 fad = AMSF_to_ABA(BCD_to_U8(sd[12 + 0]), BCD_to_U8(sd[12 + 1]), BCD_to_U8(sd[12 + 2]));
  SS_DBG(SS_DBG_CDB, "[CDB] DT FAD: %08x --- %d %d\n", fad, DT.InBufOffs, DT.InBufCounter);
 }
}

static void DT_ReadIntoFIFO(void)
{
 uint16 tmp;

 if(MDFN_UNLIKELY(DT.BufList[DT.CurBufIndex] >= 0xF0))
 {
  const uint8 t = DT.BufList[DT.CurBufIndex];

  if(t == 0xFF)
   tmp = MDFN_de16msb(&TOC_Buffer[DT.InBufOffs << 1]);
  else if(t == 0xFE)
   tmp = MDFN_de16msb(&SubCodeQBuf[DT.InBufOffs << 1]);
  else if(t == 0xFD)
   tmp = MDFN_de16msb(&SubCodeRWBuf[DT.InBufOffs << 1]);
  else
   tmp = MDFN_de16msb((uint8*)FileInfo + (DT.InBufOffs << 1));
 }
 else
  tmp = MDFN_de16msb(&Buffers[DT.BufList[DT.CurBufIndex]].Data[DT.InBufOffs << 1]);

 //printf("%02x %02x\n", DT.BufList[DT.CurBufIndex], DT.CurBufIndex);
 DT.FIFO[DT.FIFO_WP] = tmp;
 DT.FIFO_WP = (DT.FIFO_WP + 1) % (sizeof(DT.FIFO) / sizeof(DT.FIFO[0]));
 DT.FIFO_In++;
 DT.InBufOffs++;
 DT.InBufCounter--;
 DT.TotalCounter++;

 if(!DT.InBufCounter)
 {
  DT.CurBufIndex++;
  if(DT.CurBufIndex < DT.BufCount)
  {
   DT_SetIBOffsCount(Buffers[DT.BufList[DT.CurBufIndex]].Data);
  }
 }
}



// Ratio between SH-2 clock and sound subsystem 68K clock (sound clock / 2)
// (needs to match the algorithm precision in sound.cpp, for proper CD-DA stream synch without having to get into more complicated designs)
void CDB_SetClockRatio(uint32 ratio)
{
 CDB_ClockRatio = ratio;
}

static void SWReset(void)
{
 GetSecLen = SECLEN_2048;
 PutSecLen = SECLEN_2048;

 CDDevConn = 0xFF;

 LastBufDest = 0xFF;

 memset(&DT, 0, sizeof(DT));
 DT.Active = false;

 for(unsigned i = 0; i < 0x18; i++)
 {
  auto& f = Filters[i];

  f.TrueConn = i;
  f.FalseConn = 0xFF;

  Filter_ResetCond(i);
 }

 ResetBuffers();

 FADSearch.fad = 0;
 FADSearch.spos = 0;
 FADSearch.pnum = 0;

 CalcedActualSize = 0;

 PlayEndIRQType = 0;
 CurPlayEnd = 0x800000;
 CurPlayRepeat = 0;
 ClearPendingSec();
 //
 //
 //
 memset(&FLS, 0, sizeof(FLS));
 FileInfoValid = false;
 FLS.Phase = 0;
}

void CDB_ResetCD(void)	// TODO
{
 PeriodicIdleCounter = 0x7FFFFFFFFFFFFFFFLL;
 DrivePhase = DRIVEPHASE_RESETTING;
 DriveCounter = 0x7FFFFFFFFFFFFFFFLL;

 Results[0] = 0;
 Results[1] = 0;
 Results[2] = 0;
 Results[3] = 0;
 ResultsRead = true;

 CommandPhase = -1;
 CommandClockCounter = 0;
 // TODO: Set next event, timestamp + 1.
}

void CDB_SetCDActive(bool active)	// TODO
{

}



void CDB_Init(void)
{
 lastts = 0;
 Cur_CDIF = NULL;
 TrayOpen = false;
}

void CDB_Kill(void)
{

}

void CDB_SetDisc(bool tray_open, CDIF *cdif)
{
 TrayOpen = tray_open;
 Cur_CDIF = tray_open ? NULL : cdif;

 if(!Cur_CDIF)
 {
  if(DrivePhase != DRIVEPHASE_RESETTING)
  {
   AuthDiscType = 0x00;
   DrivePhase = DRIVEPHASE_EJECTED0;
   DriveCounter = (int64)1000 << 32;
  }
 }
 else
  Cur_CDIF->ReadTOC(&toc);
}

static INLINE void RecalcIRQOut(void)
{
 SCU_SetInt(16, (bool)(HIRQ & HIRQ_Mask));
}

void CDB_Reset(bool powering_up)
{
 HIRQ = 0;
 HIRQ_Mask = 0;
 RecalcIRQOut();

 CDB_ResetCD();
}

static INLINE void TriggerIRQ(unsigned bs)
{
 HIRQ |= bs;

 RecalcIRQOut();
}

enum : int { CommandPhaseBias = __COUNTER__ + 1 };

#define CMD_YIELD	   {							\
			    CommandPhase = __COUNTER__ - CommandPhaseBias + 1;	\
			    CommandClockCounter = -(500LL << 32);		\
			    /*CommandYield = true;*/				\
			    goto CommandGetOut;					\
			    case __COUNTER__:					\
			    /*CommandYield = false;*/				\
			    CommandClockCounter = 0;				\
			   }

#define CMD_EAT_CLOCKS(n) {									\
			    CommandClockCounter -= (int64)(n) << 32;				\
			    {									\
			     case __COUNTER__:							\
			     if(CommandClockCounter < 0)					\
			     {									\
			      CommandPhase = __COUNTER__ - CommandPhaseBias - 1;			\
			      goto CommandGetOut;						\
			     }									\
			     /*printf("%f\n", (double)ClockCounter / (1LL << 32));*/		\
			    }									\
			   }


// Drive commands: Init, Open, Play, Seek, Scan
//   return busy status
// Commands that change drive status:
//	Init, Open, Play, Seek, Scan
//

static uint8 MakeBaseStatus(const bool rejected = false, const uint8 hb = 0)
{
 if(rejected)
  return STATUS_REJECTED;

 uint8 ret = 0;

 if(TrayOpen)
  ret = STATUS_OPEN;
 else if(!Cur_CDIF)
  ret = STATUS_NODISC;
 else
  ret = CurPosInfo.status;

 return ret | hb;
}

static bool TestFilterCond(const unsigned fnum, const uint8* data)
{
 auto& f = Filters[fnum];

 if(f.Mode & FilterS::MODE_SEL_FADR)
 {
  const uint32 fad = AMSF_to_ABA(BCD_to_U8(data[12 + 0]), BCD_to_U8(data[12 + 1]), BCD_to_U8(data[12 + 2]));

  if(fad < f.FAD || fad >= (f.FAD + f.Range))
   return false;
 }

 uint8 file, channel, submode, cinfo;

 if(data[15] == 0x2)
 {
  file = data[16];
  channel = data[17];
  submode = data[18];
  cinfo = data[19];
 }
 else
  file = channel = submode = cinfo = 0x00;

 const bool shinv = (bool)(f.Mode & FilterS::MODE_SEL_SHREV) && (bool)(f.Mode & 0x0F);

 if(f.Mode & FilterS::MODE_SEL_FILE)
 {
  if((bool)(file != f.File))
   return shinv;
 }

 if(f.Mode & FilterS::MODE_SEL_CHANNEL)
 {
  if((bool)(channel != f.Channel))
   return shinv;
 }

 if(f.Mode & FilterS::MODE_SEL_SUBMODE)
 {
  if((bool)((submode & f.SubModeMask) != f.SubMode))
   return shinv;
 }

 if(f.Mode & FilterS::MODE_SEL_CINFO)
 {
  if((bool)((cinfo & f.CInfoMask) != f.CInfo))
   return shinv;
 }

 return !shinv;
}

static uint8 FilterBuf(const unsigned fnum, const unsigned bfsidx)
{
 assert(bfsidx != 0xFF);

 unsigned cur = fnum;
 unsigned max_iter = 0x18;
 //uint32 done = 0;

 SS_DBG(SS_DBG_CDB, "[CDB] DT FilterBuf: fad=0x%08x -- %02x %02x --- %02x %02x\n", AMSF_to_ABA(BCD_to_U8(Buffers[bfsidx].Data[12 + 0]), BCD_to_U8(Buffers[bfsidx].Data[12 + 1]), BCD_to_U8(Buffers[bfsidx].Data[12 + 2])), fnum, bfsidx, (fnum == 0xFF) ? 0xFF : Filters[fnum].TrueConn, (fnum == 0xFF) ? 0xFF : Filters[fnum].FalseConn);

 while(cur != 0xFF && max_iter--)
 {
  if(TestFilterCond(cur, Buffers[bfsidx].Data))
  {
   if(Filters[cur].TrueConn != 0xFF)
   {
    Partition_LinkBuffer(Filters[cur].TrueConn, bfsidx);
    return cur;
   }
   cur = 0xFF;
  }
  else
   cur = Filters[cur].FalseConn;
 }

 // Discarded.  Poor buffer.
 Buffer_Free(bfsidx);

 return 0xFF;
}

static void TranslateTOC(void)
{
 uint8* td = TOC_Buffer;

 for(unsigned i = 1; i < 100; i++)
 {
  const auto& t = toc.tracks[i];

  if(t.valid)
  {
   const uint32 fad = t.lba + 150;

   td[0] = (t.control << 4) | t.adr;
   td[1] = fad >> 16;
   td[2] = fad >> 8;
   td[3] = fad >> 0;
  }
  else
   td[0] = td[1] = td[2] = td[3] = 0xFF;

  td += 4;
 }

 // TODO: Better raw TOC support in core code.

 // POINT=A0
 {
  const auto& t = toc.tracks[toc.first_track];

  td[0] = (t.control << 4) | t.adr;
  td[1] = toc.first_track;
  td[2] = toc.disc_type;
  td[3] = 0;

  td += 4;
 }

 // POINT=A1
 {
  const auto& t = toc.tracks[toc.last_track];

  td[0] = (t.control << 4) | t.adr;
  td[1] = toc.last_track;
  td[2] = 0;
  td[3] = 0;

  td += 4;
 }

 // Lead-out
 {
  const auto& t = toc.tracks[100];
  const uint32 fad = t.lba + 150;

  td[0] = (t.control << 4) | t.adr;
  td[1] = fad >> 16;
  td[2] = fad >> 8;
  td[3] = fad >> 0;
  td += 4;
 }

 assert((td - TOC_Buffer) == sizeof(TOC_Buffer));
 assert(sizeof(TOC_Buffer) == 0xCC * 2);
}

//
//
//
//
//
//
static void MakeReport(const bool rejected = false, const uint8 hb = 0)
{
 Results[0] = (MakeBaseStatus(rejected, hb) << 8) | (CurPosInfo.is_cdrom << 7) | (CurPosInfo.repcount & 0x7F);

 Results[1] = (CurPosInfo.ctrl_adr << 8) | CurPosInfo.tno;
 Results[2] = (CurPosInfo.idx << 8) | (CurPosInfo.fad >> 16);
 Results[3] = CurPosInfo.fad;
}

static void CDStatusResults(const bool rejected = false, const uint8 hb = 0)
{
 MakeReport(rejected, hb);

 SS_DBG(SS_DBG_CDB, "[CDB]   Results: %04x %04x %04x %04x\n", Results[0], Results[1], Results[2], Results[3]);
 ResultsRead = false;
 CommandPending = false;
 TriggerIRQ(HIRQ_CMOK | SWResetHIRQDeferred);
 SWResetHIRQDeferred = 0;
}

static void BasicResults(uint32 res0, uint32 res1, uint32 res2, uint32 res3)
{
 Results[0] = res0;
 Results[1] = res1;
 Results[2] = res2;
 Results[3] = res3;
 ResultsRead = false;

 SS_DBG(SS_DBG_CDB, "[CDB]   Results: %04x %04x %04x %04x\n", Results[0], Results[1], Results[2], Results[3]);

 CommandPending = false;
 TriggerIRQ(HIRQ_CMOK | SWResetHIRQDeferred);
 SWResetHIRQDeferred = 0;
}

static void StartSeek(const uint32 cmd_target, const bool no_pickup_change = false)
{
 if(!Cur_CDIF)
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] [BUG] StartSeek() called when no disc present or tray open.\n");
  return;
 }

 CurPlayStart = cmd_target;

 if(no_pickup_change)
 {
  if(DrivePhase == DRIVEPHASE_PLAY)
  {
   // Maybe stop scanning?  or before the if(no_pickup_change)...
   return;
  }
 }
 else if(cmd_target & 0x800000)
 {
  int32 fad_target = cmd_target & 0x7FFFFF;
  int32 tt = 1;

  if(fad_target < 150)
   fad_target = 150;
  else if(fad_target >= (150 + (int32)toc.tracks[100].lba))
   fad_target = 150 + toc.tracks[100].lba;

  for(int32 track = 1; track <= 100; track++)
  {
   if(!toc.tracks[track].valid)
    continue;

   if(fad_target < (150 + (int32)toc.tracks[track].lba))
    break;
    
   tt = track;
  }

  CurPosInfo.tno = (tt == 100) ? 0xAA : tt;
  CurPosInfo.idx = 1;
  CurPosInfo.fad = fad_target;
  CurPosInfo.rel_fad = fad_target - (150 + toc.tracks[tt].lba);
  CurPosInfo.ctrl_adr = (toc.tracks[tt].control << 4) | (toc.tracks[tt].adr << 0);
 }
 else
 {
  int32 track_target = (cmd_target >> 8) & 0xFF;
  int32 index_target = cmd_target & 0xFF;

  if(track_target > toc.last_track)
   track_target = toc.last_track;
  else if(track_target < toc.first_track)
   track_target = toc.first_track;

  if(index_target < 1)
   index_target = 1;
  else if(index_target > 99)
   index_target = 99;

  CurPosInfo.tno = track_target;
  CurPosInfo.idx = index_target;
  CurPosInfo.fad = 150 + toc.tracks[track_target].lba;
  CurPosInfo.rel_fad = 0;
  CurPosInfo.ctrl_adr = (toc.tracks[track_target].control << 4) | (toc.tracks[track_target].adr << 0);
 }
 //
 CurPosInfo.status = STATUS_BUSY;
 CurPosInfo.is_cdrom = false;
 CurPosInfo.repcount = PlayRepeatCounter & 0xF;
 DrivePhase = DRIVEPHASE_SEEK_START;

 Cur_CDIF->HintReadSector(CurPosInfo.fad);

// PlayEndIRQPending = false;
 PeriodicIdleCounter = PeriodicIdleCounter_Reload;
 DriveCounter = (int64)256000 << 32; //(int64)((44100 * 256) / 150) << 32;
 SeekIndexPhase = 0;
}

static void Drive_Run(int64 clocks)
{
  DriveCounter -= clocks;
  PeriodicIdleCounter -= clocks;
  while(DriveCounter <= 0)
  {
   switch(DrivePhase)
   {
    case DRIVEPHASE_EJECTED0:
	memset(TOC_Buffer, 0xFF, sizeof(TOC_Buffer));	// TODO: confirm 0xFF(or 0x00?)

	// TODO: Check DrivePhase and these vars in command processing.
	AuthDiscType = 0x00;
	FileInfoValid = false;
	RootDirInfoValid = false;

        CurPosInfo.status = STATUS_OPEN;
	CurPosInfo.fad = 0xFFFFFF;
	CurPosInfo.rel_fad = 0xFFFFFF;
	CurPosInfo.ctrl_adr = 0xFF;
	CurPosInfo.idx = 0xFF;
	CurPosInfo.tno = 0xFF;
	CurPosInfo.is_cdrom = true;
	CurPosInfo.repcount = 0x7F;
	TriggerIRQ(HIRQ_DCHG);

	DrivePhase = DRIVEPHASE_EJECTED1;
	DriveCounter = (int64)4000 << 32;
	break;

    case DRIVEPHASE_EJECTED1:
	TriggerIRQ(HIRQ_EFLS);
	DrivePhase = DRIVEPHASE_EJECTED_WAITING;
	DriveCounter = (int64)1 << 32;
	break;

    case DRIVEPHASE_EJECTED_WAITING:
	if(Cur_CDIF)
	{
         CurPosInfo.status = STATUS_BUSY;
	 DrivePhase = DRIVEPHASE_STARTUP;
	 DriveCounter = (int64)(1 * 44100 * 256) << 32;
	}
	else
	 DriveCounter = (int64)1000 << 32;
	
	break;

    case DRIVEPHASE_STARTUP:
	TranslateTOC();
	//
	//
	//
	ClearPendingSec();
	//
	PlayEndIRQType = 0;
	CurPlayEnd = 0x800000;
	CurPlayRepeat = 0;
	//
        StartSeek(0x800096);
	break;

    case DRIVEPHASE_STOPPED:
	CurPosInfo.status = STATUS_STANDBY;
	DriveCounter += (int64)2000 << 32;
	break;

    case DRIVEPHASE_SEEK_START:
	//
	// TODO: Motor spinup from stopped state time penalty?
	//
	{
	 int32 seek_time;
	 int32 fad_delta;

	 fad_delta = CurPosInfo.fad - CurSector;

	 seek_time = 6 * (44100 * 256) / 150;
	 seek_time += abs(fad_delta) * ((fad_delta < 0) ? 28 : 26);
	 seek_time += (fad_delta < 0 || fad_delta >= 150) ? (44100 * 256) / 150 : 0;
	 //seek_time += fabs(sqrt(CurSector) - sqrt(CurPosInfo.fad)) * 13000;

	 CurPosInfo.status = STATUS_SEEK;
	 DrivePhase = DRIVEPHASE_SEEK;
	 DriveCounter += (int64)seek_time << 32;
	 CurSector = CurPosInfo.fad;
	 SubQBuf_Safe_Valid = false;
	}
	break;


    case DRIVEPHASE_SEEK:
	//
	// Extremely crude approximation.
	//
	{
	 static uint8 pwbuf[96];
         const bool old_safe_valid = SubQBuf_Safe_Valid;

	 Cur_CDIF->ReadRawSectorPWOnly(pwbuf, CurSector - 150, false);
	 DecodeSubQ(pwbuf);

	 if(!SubQBuf_Safe_Valid)
         {
	  CurSector++;
	  DriveCounter += (int64)((44100 * 256) / 150) << 32;
         }
	 else
	 {
	  bool index_ok = true;

	  if(!old_safe_valid)
	   CurSector = CurPosInfo.fad;

	  if(!(CurPlayStart & 0x800000))
	  {
	   const unsigned start_track = std::min<unsigned>(toc.last_track, std::max<unsigned>(toc.first_track, (CurPlayStart >> 8) & 0xFF));
	   const unsigned start_index = std::min<unsigned>(99, std::max<unsigned>(1, CurPlayStart & 0xFF));
	   const unsigned sq_idx = BCD_to_U8(SubQBuf_Safe[0x2]);
	   const unsigned sq_tno = (SubQBuf_Safe[0x1] >= 0xA0) ? SubQBuf_Safe[0x1] : BCD_to_U8(SubQBuf_Safe[0x1]);

	   if(sq_idx < start_index && sq_tno <= start_track)
	   {
	    if(SeekIndexPhase == 2)
	    {
	     index_ok = false;
	     CurSector += 4;
	     DriveCounter += (int64)((44100 * 256) / 150) << 32;
	    }
	    else
	    {
	     index_ok = false;
	     CurSector += 128;
	     DriveCounter += (int64)((44100 * 256) / 150) << 32;
	     SeekIndexPhase = 1;
	    }
	   }
	   else
	   {
	    if(SeekIndexPhase == 1)
	    {
	     index_ok = false;
	     CurSector -= 124;
	     DriveCounter += (int64)((44100 * 256) / 150) << 32;
	     SeekIndexPhase = 2;
	    }
	   }
	  }

	  if(index_ok)
	  {
	   DrivePhase = DRIVEPHASE_PLAY;
	   DriveCounter += (int64)((44100 * 256) / ((SubQBuf_Safe[0] & 0x40) ? 150 : 75)) << 32;
	  }
	  //else
	  // printf("%d\n", CurSector);
         }
        }
	break;

    case DRIVEPHASE_PLAY:
	if(SecPreBuf_In > 0)
	{
	 if(SubQBuf_Safe[0] & 0x40)
	 {
	  CurPosInfo.is_cdrom = true;

	  //assert(edc_check(SecPreBuf, false));

	  if(FreeBufferCount > 0)
          {
	   const uint8 bfi = Buffer_Allocate(false);

	   memcpy(Buffers[bfi].Data, SecPreBuf, 2352);

	   SecPreBuf_In = false;
           LastBufDest = FilterBuf(CDDevConn, bfi);
	   TriggerIRQ(HIRQ_CSCT);
	   if(FreeBufferCount == 0)
	    TriggerIRQ(HIRQ_BFUL);
          }
	 }
	 else
	 {
	  CurPosInfo.is_cdrom = false;
	  if(!CDDABuf_Count)
	  {
	   for(int i = 0; i < CDDABuf_PrefillCount; i++)
	   {
	    CDDABuf[CDDABuf_WP][0] = 0;
	    CDDABuf[CDDABuf_WP][1] = 0;
	    CDDABuf_WP = (CDDABuf_WP + 1) % CDDABuf_MaxCount;
	    CDDABuf_Count++;
	   }
	  }

	  for(int i = 0; i < 588 && CDDABuf_Count < CDDABuf_MaxCount; i++)
	  {
	   CDDABuf[CDDABuf_WP][0] = MDFN_de16lsb(&SecPreBuf[i * 4 + 0]);
	   CDDABuf[CDDABuf_WP][1] = MDFN_de16lsb(&SecPreBuf[i * 4 + 2]);
	   CDDABuf_WP = (CDDABuf_WP + 1) % CDDABuf_MaxCount;
	   CDDABuf_Count++;
	  }

	  SecPreBuf_In = false;
	 }

	 if(!SecPreBuf_In)
	 {
	  CurPosInfo.status = STATUS_PLAY;
	 }
	} // end if(SecPreBuf_In > 0)

        PeriodicIdleCounter = 17712LL << 32;
	if(DrivePhase == DRIVEPHASE_PLAY)
	{
	 if(SecPreBuf_In)
	 {
	  // TODO: More accurate:
	  CurPosInfo.status = STATUS_PAUSE;

	  if(SecPreBuf_In > 0)
	   SS_DBG(SS_DBG_CDB, "[CDB] SB Overflow\n");
	 }
	 else
	 {
	  Cur_CDIF->ReadRawSector(SecPreBuf, CurSector - 150);
	  SecPreBuf_In = true;

	  // TODO:(maybe pointless...)
	  //if(SubQBuf_Safe[0] & 0x40)
          // CurPosInfo.fad = SECTOR HEADER
          //else
	  // CurPosInfo.fad = SUBQ STUFF
	  CurPosInfo.fad = CurSector;	
	  if(DecodeSubQ(SecPreBuf + 2352))
	  {
	   CurPosInfo.rel_fad = (BCD_to_U8(SubQBuf[0x3]) * 60 + BCD_to_U8(SubQBuf[0x4])) * 75 + BCD_to_U8(SubQBuf[0x5]);
	   CurPosInfo.tno = (SubQBuf[0x1] >= 0xA0) ? SubQBuf[0x1] : BCD_to_U8(SubQBuf[0x1]);
	   CurPosInfo.idx = BCD_to_U8(SubQBuf[0x2]);
	  }
	  CurSector++;
	 }
	}

	DriveCounter += (int64)((44100 * 256) / ((SubQBuf_Safe[0] & 0x40) ? 150 : 75)) << 32;
	break;
   }
  }

  if(PeriodicIdleCounter <= 0)
  {
   PeriodicIdleCounter = PeriodicIdleCounter_Reload;
 
   //
   //
   //
   if(SecPreBuf_In && DrivePhase == DRIVEPHASE_PLAY)
   {
    bool end_met = (CurPosInfo.tno == 0xAA);

    if(CurPlayEnd != 0)
    {
     if(CurPlayEnd & 0x800000)
      end_met |= (CurPosInfo.fad >= (CurPlayEnd & 0x7FFFFF));
     else
     {
      const unsigned end_track = std::min<unsigned>(toc.last_track, std::max<unsigned>(toc.first_track, (CurPlayEnd >> 8) & 0xFF));
      const unsigned end_index = std::min<unsigned>(99, std::max<unsigned>(1, CurPlayEnd & 0xFF));

      end_met |= (CurPosInfo.tno > end_track) || (CurPosInfo.tno == end_track && CurPosInfo.idx > end_index);
     }
    }

    //
    // Steam Heart's, it's always Steam Heart's...
    //
    if(CurPlayStart & 0x800000)
    {
     end_met |= (CurPosInfo.fad < (CurPlayStart & 0x7FFFFF));
    }
    else
    {
     const unsigned start_track = std::min<unsigned>(toc.last_track, std::max<unsigned>(toc.first_track, (CurPlayStart >> 8) & 0xFF));
     const unsigned start_index = std::min<unsigned>(99, std::max<unsigned>(1, CurPlayStart & 0xFF));

     end_met |= (CurPosInfo.tno < start_track); //|| (CurPosInfo.tno == start_track && CurPosInfo.idx < start_index);
    }

    if(end_met)
    {
     SecPreBuf_In = false;
     if(PlayRepeatCounter >= CurPlayRepeat)
     {
      CurSector = CurPosInfo.fad;

      if(PlayEndIRQType)
      {
       CurPosInfo.status = STATUS_BUSY;

       PlayEndIRQType += 1 << 30;	// Crappy delay so we're in STATUS_BUSY state long enough.

       if((PlayEndIRQType >> 30) >= 3)
       {
	// Don't generate IRQ if we've repeated and there hasn't been a non-end_met sector since.
        if(!(PlayRepeatCounter & 0x80))
         TriggerIRQ(PlayEndIRQType & 0xFFFF);	// May not be right for EFLS with Read File, maybe EFLS is only triggered after the buffer is written?
        PlayEndIRQType = 0;
       }
      }

      if(!PlayEndIRQType)
       CurPosInfo.status = STATUS_PAUSE;
     }
     else
     {
      if(PlayRepeatCounter < 0xE)
       PlayRepeatCounter++;

      PlayRepeatCounter |= 0x80;
      //
      StartSeek(PlayCmdStartPos);
     }
    }
    else
     PlayRepeatCounter &= ~0x80;
   }
   //
   //
   //
   PeriodicIdleCounter = PeriodicIdleCounter_Reload;

   if(ResultsRead)
    MakeReport(false, STATUS_PERIODIC);

   // FIXME: Other ADR types, and correct handling when in STANDBY/STOPPED state?
   SubCodeQBuf[0] = CurPosInfo.ctrl_adr;
   SubCodeQBuf[1] = CurPosInfo.tno;
   SubCodeQBuf[2] = CurPosInfo.idx;
   SubCodeQBuf[3] = CurPosInfo.rel_fad >> 16;
   SubCodeQBuf[4] = CurPosInfo.rel_fad >> 8;
   SubCodeQBuf[5] = CurPosInfo.rel_fad >> 0;
   SubCodeQBuf[6] = 0;	// ? OxFF in some cases...
   SubCodeQBuf[7] = CurPosInfo.fad >> 16;
   SubCodeQBuf[8] = CurPosInfo.fad >> 8;
   SubCodeQBuf[9] = CurPosInfo.fad >> 0;

   TriggerIRQ(HIRQ_SCDQ);
  }
}

void CDB_GetCDDA(uint16* outbuf)
{
 outbuf[0] = outbuf[1] = 0;

 if(CDDABuf_Count)
 {
  outbuf[0] = CDDABuf[CDDABuf_RP][0];
  outbuf[1] = CDDABuf[CDDABuf_RP][1];

  CDDABuf_RP = (CDDABuf_RP + 1) % CDDABuf_MaxCount;
  CDDABuf_Count--;
 }

 //static int32 counter = 0;
 //outbuf[0] = (counter & 0xFF) << 6;
 //outbuf[1] = (counter & 0xFF) << 6;
 //counter++;
}

static void ClearPendingSec(void)
{
 //PlayEndIRQPending = 0;
 PlayEndIRQType = 0;

 SecPreBuf_In = false;

 CDDABuf_WP = CDDABuf_RP = 0;
 CDDABuf_Count = 0;
}

sscpu_timestamp_t CDB_Update(sscpu_timestamp_t timestamp)
{
 if(MDFN_UNLIKELY(timestamp < lastts))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] [BUG] timestamp(%d) < lastts(%d)\n", timestamp, lastts);
 }
 else
 {
  int64 clocks = (int64)(timestamp - lastts) * CDB_ClockRatio;
  lastts = timestamp;

  Drive_Run(clocks);

  //
  //
  //
  CommandClockCounter += clocks;
  switch(CommandPhase + CommandPhaseBias)
  {
   for(;;)
   {
    default:
    case __COUNTER__:

    while(!CommandPending)
    {
     if(FLS_Run())
     {
      CMD_EAT_CLOCKS(60);
      TriggerIRQ(HIRQ_EFLS);
      CMD_EAT_CLOCKS(60);
     }
     else
     {
      CMD_YIELD;
     }
    }

    for(unsigned i = 0; i < 4; i++)
     CTR.CD[i] = CData[i];

    CTR.Command = CTR.CD[0] >> 8;
    if(MDFN_UNLIKELY(ss_dbg_mask & SS_DBG_CDB))
    {
     char cdet[128];
     GetCommandDetails(CTR.CD, cdet, sizeof(cdet));
     SS_DBG(SS_DBG_CDB, "[CDB] Command: %s --- HIRQ=0x%04x, HIRQ_Mask=0x%04x\n", cdet, HIRQ, HIRQ_Mask);
    }
    //
    //
    CMD_EAT_CLOCKS(84);

    //
    //
    //
    if(CTR.Command == COMMAND_GET_CDSTATUS) //	= 0x00,
    {
     CDStatusResults();
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_HWINFO) //	= 0x01,
    {
     BasicResults(MakeBaseStatus() << 8,
		  0x0002,
		  0x0000,
		  0x0600); // TODO: Before INIT: 0xFF00;
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_TOC) //	= 0x02,
    {
     if(DrivePhase == DRIVEPHASE_STARTUP || DT.Active)
      CDStatusResults(false, STATUS_WAIT);
     else
     {
      BasicResults(MakeBaseStatus(false, STATUS_DTREQ) << 8, 0xCC, 0, 0);

      //
      //
      DT.CurBufIndex = 0;
      DT.BufCount = 1;

      DT.InBufOffs = 0;
      DT.InBufCounter = 0xCC;

      DT.TotalCounter = 0;

      DT.FIFO_RP = 0;
      DT.FIFO_WP = 0;
      DT.FIFO_In = 0;

      DT.BufList[0] = 0xFF;
     
      DT.Writing = false;
      DT.NeedBufFree = false;
      DT.Active = true;
      //
      //
      //
      CMD_EAT_CLOCKS(128);
      TriggerIRQ(HIRQ_DRDY);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_SESSINFO) //	= 0x03,
    {
     if(DrivePhase == DRIVEPHASE_STARTUP)
      CDStatusResults(false, STATUS_WAIT);
     else
     {
      const unsigned sess = CTR.CD[0] & 0xFF;
      uint32 fad;
      uint8 rsw;

      if(!sess)
      {
       fad = 150 + toc.tracks[100].lba;
       rsw = 0x01; // Session count;
      }
      else if(sess <= 0x01)
      {
       fad = 0;
       rsw = sess;
      }
      else
      {
       fad = 0xFFFFFF;
       rsw = 0xFF;
      }

      BasicResults(MakeBaseStatus() << 8, 0, (rsw << 8) | (fad >> 16), fad);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_INIT) //		= 0x04,
    {
     ClearPendingSec();
     CurPlayEnd = 0x800000;
     CurPlayRepeat = 0;
     CurPosInfo.status = STATUS_BUSY;

     CDStatusResults(false, 0x00);

     //
     if(CTR.CD[0] & 0x01)	// Software reset of CD block
     {
      CMD_EAT_CLOCKS(180);
      SWResetPending = true;

      //
      // If a new command was issued in the time we spent in CMD_EAT_CLOCKS(), process it before we do the software reset
      // down below.
      //
      if(CommandPending)
       continue;
     }

     // TODO TODO TODO
     //  & 0x02;	// Decode subcode RW
     //  & 0x04;	// Ignore mode2 subheader?
     //  & 0x08;	// Retry form2 read
     //  & 0x30;	// CD read speed(unused?)
     //  & 0x80;	// No change?
    }
/*
    //
    //
    //
    else if(CTR.Command == COMMAND_OPEN) //		= 0x05,
    {
    }
*/
    //
    //
    //
    else if(CTR.Command == COMMAND_END_DATAXFER) //	= 0x06,
    {
     if(DT.Active)
     {
      DT.Active = false;

      BasicResults((MakeBaseStatus() << 8) | (DT.TotalCounter >> 16), DT.TotalCounter, 0, 0);

      if(DT.InBufCounter > 0 || DT.FIFO_In > 0)
      {
       SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Data transfer ended prematurely at %u bytes left!\n", (DT.InBufCounter + DT.FIFO_In) * 2);
      }

      if(DT.Writing)
      {
       Filter_DisconnectInput(DT.FNum);

       for(unsigned i = 0; i < DT.BufCount; i++)
       {
	FilterBuf(DT.FNum, DT.BufList[i]);
       }

       CMD_EAT_CLOCKS(270);
       if(FreeBufferCount == 0)
        TriggerIRQ(HIRQ_BFUL);
       TriggerIRQ(HIRQ_EHST);
      }
      else
      {
       if(DT.NeedBufFree)
       {
        for(unsigned i = 0; i < DT.BufCount; i++)
        {
 	 Buffer_Free(DT.BufList[i]);
        }
       }

       if(DT.BufList[0] != 0xFE && DT.BufList[0] != 0xFD)	// FIXME: Cleanup(use enums for special buffer ids) - Also check for TOC and FINFO
       {
        CMD_EAT_CLOCKS(130);
        TriggerIRQ(HIRQ_EHST);
       }
      }
     }
     else
      BasicResults((MakeBaseStatus() << 8) | 0xFF, 0xFFFF, 0, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_PLAY) //		= 0x10,
    {
     uint32 cmd_psp = ((CTR.CD[0] & 0xFF) << 16) | CTR.CD[1];
     uint32 cmd_pep = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];
     uint8 pm = CTR.CD[2] >> 8;

     if(cmd_psp == 0xFFFFFF)
      cmd_psp = PlayCmdStartPos;

     if(cmd_pep == 0xFFFFFF)
      cmd_pep = PlayCmdEndPos;
     else if((cmd_psp & 0x800000) && (cmd_pep & 0x800000))
      cmd_pep = 0x800000 | ((cmd_psp + cmd_pep) & 0x7FFFFF);

     if(((cmd_psp ^ cmd_pep) & 0x800000) && cmd_pep != 0)
      CDStatusResults(true);
     else
     {
      PlayCmdStartPos = cmd_psp;
      PlayCmdEndPos = cmd_pep;
      //

      CurPosInfo.status = STATUS_BUSY;	// Happens even if (PlayMode & 0x80)...
      CDStatusResults();
      //
      //
      if(!(pm & 0x80))
       ClearPendingSec();
      //
      PlayEndIRQType = HIRQ_PEND;
      CurPlayEnd = PlayCmdEndPos;

      if(!(pm & 0x70))
       PlayCmdRepCnt = pm & 0x0F;

      CurPlayRepeat = PlayCmdRepCnt;

      PlayRepeatCounter = 0;
      //
      StartSeek(PlayCmdStartPos, (bool)(pm & 0x80));
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SEEK) //		= 0x11,
    {
     CurPosInfo.status = STATUS_BUSY;
     CDStatusResults();
     //
     //
     const uint32 cmd_sp = ((CTR.CD[0] & 0xFF) << 16) | CTR.CD[1];

     if(!cmd_sp)	// Stop
     {
      ClearPendingSec();
      CurPosInfo.is_cdrom = true;
      CurPosInfo.repcount = 0x7F;
      CurPosInfo.status = STATUS_BUSY;
      CurPosInfo.fad = 0xFFFFFF;
      CurPosInfo.rel_fad = 0xFFFFFF;
      CurPosInfo.ctrl_adr = 0xFF;
      CurPosInfo.idx = 0xFF;
      CurPosInfo.tno = 0xFF;

      DrivePhase = DRIVEPHASE_STOPPED;
      DriveCounter = (int64)380000 << 32;
     }
     else if(cmd_sp == 0xFFFFFF) // Pause
     {
      if(DrivePhase == DRIVEPHASE_STOPPED)	// TODO: Test
      {
       ClearPendingSec();
       StartSeek(0x800096);
      }

      SecPreBuf_In = -abs(SecPreBuf_In);
      PlayEndIRQType = 0;
      CurPlayEnd = 0x800000;
      CurPlayRepeat = 0;
     }
     else
     {
      ClearPendingSec();
      //
      CurPlayEnd = 0x800000;
      CurPlayRepeat = 0;
      //
      StartSeek(cmd_sp);
     }
    }
/*
    //
    //
    //
    else if(CTR.Command == COMMAND_SCAN) //		= 0x12,
    {
	//CurPosInfo.is_cdrom = false;
 Forward scan data track(on Saturn CD):
	4-5 sequential position updates, then jumps like:
	  17f-> 1e1 (62)
	  96d-> 9d0 (63)
	  fd8->103b (63)
	 202c->2093 (67)
	 2fa1->300a (69)
	 3fdf->404a (6b)
	 4fa3->5011 (6e)
         5fad->601c (6f)
	 6f96->7007 (71)
	 7fcd->8040 (73)
	 8fd7->904e (77)
	 9faf->a028 (79)
	 afcd->b047 (7a)

	97.79888435299837 + 0.0005527097174003169x
    }
*/
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_SUBCODE) //	= 0x20,
    {
     if(DT.Active)
      CDStatusResults(false, STATUS_WAIT);
     else
     {
      uint8 type;

      type = CTR.CD[0] & 0xFF;

      if(type >= 0x02)
       CDStatusResults(true);
      else
      {
       if(type == 0) // Q (TODO: ADR other than 0x1)
       {
        BasicResults(MakeBaseStatus(false, STATUS_DTREQ) << 8, 0x05, 0, 0);
        DT.BufList[0] = 0xFE;
	DT.InBufCounter = 0x05;
       }
       else	// R-W	(TODO)
       {
        BasicResults(MakeBaseStatus(false, STATUS_DTREQ) << 8, 0x0C, 0, 0);

	for(unsigned i = 0; i < 24; i++)
	 SubCodeRWBuf[i] = 0xFF;

        DT.BufList[0] = 0xFD;
	DT.InBufCounter = 0x0C;
       }

       DT.CurBufIndex = 0;
       DT.BufCount = 1;

       DT.InBufOffs = 0;
       
       DT.TotalCounter = 0;
       DT.FIFO_RP = 0;
       DT.FIFO_WP = 0;
       DT.FIFO_In = 0;
     
       DT.Writing = false;
       DT.NeedBufFree = false;
       DT.Active = true;
       //
       //
       //
       CMD_EAT_CLOCKS(128);
       TriggerIRQ(HIRQ_DRDY);
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_AUTH_DEVICE)
    {
     uint8 fnum;

     fnum = (CTR.CD[2] >> 8);

     if(fnum >= 0x18)
      CDStatusResults(true);
     else if(FLS.Active)
      CDStatusResults(false, STATUS_WAIT);
     else
     {
      CDStatusResults();
      //
      //
      //
      bool is_audio_cd;
      uint32 data_track_fad;

      is_audio_cd = true;

      // TODO: Check DrivePhase == DRIVEPHASE_STARTUP
      for(int32 track = toc.first_track; track <= toc.last_track; track++)
      {
       if(toc.tracks[track].control & SUBQ_CTRLF_DATA)
       {
        data_track_fad = 150 + toc.tracks[track].lba;
        is_audio_cd = false;
        break;
       }
      }

      if(is_audio_cd)
      {
       AuthDiscType = 0x01; //0x04;
       CMD_EAT_CLOCKS(200);
       TriggerIRQ(HIRQ_EFLS);
      }
      else
      {
       SetCDDeviceConn(fnum);
       Filter_SetTrueConn(fnum, fnum);
       Filter_SetFalseConn(fnum, 0xFF);
       Filter_SetRange(fnum, 0, 0);
       Filters[fnum].Mode = 0;
      
       FLS.pnum = fnum;
       FLS.DoAuth = true;
       FLS.Active = true;

       ClearPendingSec();
       //
       CurPlayEnd = 0;
       CurPlayRepeat = 0;
       PlayRepeatCounter = 0;
       //
       StartSeek(0x800000 | (data_track_fad + 16));
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_AUTH)
    {
     if(FLS.Active && FLS.DoAuth)
      CDStatusResults(true);
     else
      BasicResults(MakeBaseStatus() << 8, AuthDiscType, 0, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_CDDEVCONN) //	= 0x30,
    {
     #define fnum (CTR.CD[2] >> 8)

     if(fnum >= 0x18 && fnum != 0xFF)
      CDStatusResults(true);
     else
     {
      SetCDDeviceConn(fnum);

      CDStatusResults();

      CMD_EAT_CLOCKS(96);
      TriggerIRQ(HIRQ_ESEL);
     }
     #undef fnum
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_CDDEVCONN) //	= 0x31,
    {
     BasicResults((MakeBaseStatus() << 8), 0, CDDevConn << 8, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_LASTBUFDST) //	= 0x32,
    {
     BasicResults(MakeBaseStatus() << 8, 0, LastBufDest << 8, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_FILTRANGE) //	= 0x40,
    {
     #define fnum (CTR.CD[2] >> 8)

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      {
       const uint32 fad = ((CTR.CD[0] & 0xFF) << 16) | CTR.CD[1];
       const uint32 range = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];

       Filter_SetRange(fnum, fad, range);

       CDStatusResults();
      }
      CMD_EAT_CLOCKS(96);
      TriggerIRQ(HIRQ_ESEL);
     }
     #undef fnum
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FILTRANGE) //	= 0x41,
    {
     const unsigned fnum = CTR.CD[2] >> 8;

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      const uint32 fad = Filters[fnum].FAD;
      const uint32 range = Filters[fnum].Range;

      BasicResults((MakeBaseStatus() << 8) | (fad >> 16),
		   fad,
		   (fnum << 8) | (range >> 16),
		   range);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_FILTSUBHC) //	= 0x42,
    {
     #define fnum (CTR.CD[2] >> 8)

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      Filters[fnum].Channel = CTR.CD[0] & 0xFF;
      Filters[fnum].SubModeMask = CTR.CD[1] >> 8;
      Filters[fnum].CInfoMask = CTR.CD[1] & 0xFF;
      Filters[fnum].File = CTR.CD[2] & 0xFF;
      Filters[fnum].SubMode = CTR.CD[3] >> 8;
      Filters[fnum].CInfo = CTR.CD[3] & 0xFF;

      CDStatusResults();

      CMD_EAT_CLOCKS(96);
      TriggerIRQ(HIRQ_ESEL);
     }
     #undef fnum
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FILTSUBHC) //	= 0x43,
    {
     const unsigned fnum = CTR.CD[2] >> 8;

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      const auto& f = Filters[fnum];

      BasicResults((MakeBaseStatus() << 8) | f.Channel,
		   (f.SubModeMask << 8) | f.CInfoMask,
		   (fnum << 8) | f.File,
		   (f.SubMode << 8) | f.CInfo);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_FILTMODE) //	= 0x44,
    {
     #define fnum (CTR.CD[2] >> 8)

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      Filters[fnum].Mode = CTR.CD[0] & 0xFF;

      if(CTR.CD[0] & 0x80)
       Filter_ResetCond(fnum);

      CDStatusResults();

      CMD_EAT_CLOCKS(96);
      TriggerIRQ(HIRQ_ESEL);
     }
     #undef fnum
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FILTMODE) //	= 0x45,
    {
     const unsigned fnum = CTR.CD[2] >> 8;

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
      BasicResults((MakeBaseStatus() << 8) | Filters[fnum].Mode,
		   0,
		   fnum << 8,
		   0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_FILTCONN) //	= 0x46,
    {
     #define fnum (CTR.CD[2] >> 8)
     #define fcflags (CTR.CD[0] & 0xFF)
     #define tconn (CTR.CD[1] >> 8)
     #define fconn (CTR.CD[1] & 0xFF)

     if(fnum >= 0x18 || ((fcflags & 0x1) && (tconn >= 0x18) && tconn != 0xFF) || ((fcflags & 0x2) && (fconn >= 0x18) && fconn != 0xFF))
      CDStatusResults(true);
     else
     {
      if(fcflags & 0x1)
       Filter_SetTrueConn(fnum, tconn);

      if(fcflags & 0x2)
       Filter_SetFalseConn(fnum, fconn);

      CDStatusResults();

      CMD_EAT_CLOCKS(96);
      TriggerIRQ(HIRQ_ESEL);
     }
     #undef fconn
     #undef tconn
     #undef fcflags
     #undef fnum
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FILTCONN) //	= 0x47,
    {
     const unsigned fnum = CTR.CD[2] >> 8;

     if(fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      const auto& f = Filters[fnum];

      BasicResults((MakeBaseStatus() << 8),
		   (f.TrueConn << 8) | f.FalseConn,
		   fnum << 8,
		   0);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_RESET_SEL) //	= 0x48,
    {
     unsigned rflags;

     rflags = CTR.CD[0] & 0xFF;

     if(!rflags)
     {
      unsigned pnum;

      pnum = CTR.CD[2] >> 8;

      if(pnum >= 0x18)
       CDStatusResults(true);
      else
      {
       Partition_Clear(pnum);

       CDStatusResults();
       //
       //
       //
       CMD_EAT_CLOCKS(150);
       TriggerIRQ(HIRQ_ESEL);      
      }
     }
     else
     {
      for(unsigned pnum = 0; pnum < 0x18; pnum++)
      {
       if(rflags & 0x04)	// Initialize all partition data
       {
	Partition_Clear(pnum);
       }

       // TODO: Initialize all partition output connectors.
       //       Has to do with MPEG decoding, copy/move sector data
       //       commands, and maybe some other commands too?
       if(rflags & 0x08)
       {

       }

       if(rflags & 0x10)	// Initialize all filter conditions
       {
	Filter_ResetCond(pnum);
       }

       if(rflags & 0x20)	// Initialize all filter input connectors
       {
	if(pnum == CDDevConn)
	 CDDevConn = 0xFF;

	if(Filters[pnum].FalseConn < 0x18)
	 Filters[pnum].FalseConn = 0xFF;
       }

       if(rflags & 0x40) // Initialize all true output connectors
       {
	Filters[pnum].TrueConn = pnum;
       }

       if(rflags & 0x80) // Initialize all false output connectors
       {
	Filters[pnum].FalseConn = 0xFF;
       }
      }
      CDStatusResults();
      //
      //
      //
      // TODO: Accurate timing(while not blocking other command execution and sector reading).
      CMD_EAT_CLOCKS(300);
      TriggerIRQ(HIRQ_ESEL);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_BUFSIZE) //	= 0x50,
    {
     BasicResults(MakeBaseStatus() << 8,
		  FreeBufferCount,
		  0x18 << 8,
		  NumBuffers);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_SECNUM) //	= 0x51,
    {
     const unsigned pnum = CTR.CD[2] >> 8;

     if(pnum >= 0x18)
     {
      CDStatusResults(true);
     }
     else
     {
      BasicResults(MakeBaseStatus() << 8,
		   0,
		   0,
		   Partitions[pnum].Count);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_CALC_ACTSIZE) //	= 0x52,
    {
     unsigned pnum;
     int offs, numsec;

     offs = CTR.CD[1];
     pnum = CTR.CD[2] >> 8;
     numsec = CTR.CD[3];

     if(pnum >= 0x18)
      CDStatusResults(true);
     else
     {
      offs = CTR.CD[1];
      numsec = CTR.CD[3];

      if(offs == 0xFFFF)
       offs = Partitions[pnum].Count - 1;

      if(numsec == 0xFFFF)
       numsec = Partitions[pnum].Count - offs;

      if((DT.Active && DT.Writing) || numsec <= 0 || offs < 0 || (offs + numsec) > (int)Partitions[pnum].Count)
       CDStatusResults(false, STATUS_WAIT);
      else
      {
       CDStatusResults();

       //
       {
        uint32 tmp_accum = 0;
        for(int i = 0, bfi = Partition_GetBuffer(pnum, offs); i < numsec; i++, bfi = Buffers[bfi].Next)
	{
	 const uint8* const sd = Buffers[bfi].Data;

	 switch(GetSecLen)
	 {
	  default:
	  case SECLEN_2048:
	  	if((sd[12 + 3] == 0x2) && (sd[16 + 2] & 0x20))	// Mode 2 Form 2
		 tmp_accum += 1162;
		else	// M2F1 and Mode 1(weird tested inconsistency with Get Sector Data command, not that it probably matters)
	 	 tmp_accum += 1024;
		break;

	  case SECLEN_2336: tmp_accum += 1168; break;
	  case SECLEN_2340: tmp_accum += 1170; break;
	  case SECLEN_2352: tmp_accum += 1176; break;
	 }
	}
        CalcedActualSize = tmp_accum;
       }
       //
       CMD_EAT_CLOCKS(240);	// TODO: proper timing(can be surprisingly large for higher numsec)
       TriggerIRQ(HIRQ_ESEL);
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_ACTSIZE) //	= 0x53,
    {
     BasicResults((MakeBaseStatus() << 8) | (CalcedActualSize >> 16), CalcedActualSize, 0, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_SECINFO) //	= 0x54,
    {
     unsigned offs;
     unsigned pnum;

     offs = CTR.CD[1];
     pnum = CTR.CD[2] >> 8;

     if(pnum >= 0x18 || (offs != 0xFFFF && offs >= Partitions[pnum].Count) || Partitions[pnum].Count == 0)
      CDStatusResults(true);
     else
     {
      const int bfi = ((offs == 0xFFFF) ? Partitions[pnum].LastBuf : Partition_GetBuffer(pnum, offs));
      const uint8* sd = Buffers[bfi].Data;
      uint32 fad;
      uint8 file = 0, chan = 0, submode = 0, cinfo = 0;

      fad = AMSF_to_ABA(BCD_to_U8(sd[12 + 0]), BCD_to_U8(sd[12 + 1]), BCD_to_U8(sd[12 + 2]));
      if(sd[12 + 3] == 0x2)
      {
       file = sd[16];
       chan = sd[17];
       submode = sd[18];
       cinfo = sd[19];
      }

      BasicResults((MakeBaseStatus() << 8) | (fad >> 16),
		  fad,
		  (file << 8) | chan,
		  (submode << 8) | cinfo);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_EXEC_FADSRCH) //	= 0x55,
    {
     unsigned offs;
     unsigned pnum;
     uint32 sfad;

     offs = CTR.CD[1];
     pnum = CTR.CD[2] >> 8;
     sfad = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];

     if(pnum >= 0x18 || (offs != 0xFFFF && offs >= Partitions[pnum].Count) || Partitions[pnum].Count == 0)
      CDStatusResults(true);
     else
     {
      int counter;
      int effoffs, bfi;
      bool match_made;

      FADSearch.spos = 0xFFFF;
      FADSearch.pnum = pnum;
      FADSearch.fad = 0;

      counter = 0;
      effoffs = (offs == 0xFFFF) ? (Partitions[pnum].Count - 1) : offs;
      bfi = Partitions[pnum].FirstBuf;
      match_made = false;

      do
      {
       if(counter >= effoffs)
       {
        const uint8* sd = Buffers[bfi].Data;
        const uint32 fad = AMSF_to_ABA(BCD_to_U8(sd[12 + 0]), BCD_to_U8(sd[12 + 1]), BCD_to_U8(sd[12 + 2]));

        if(fad <= sfad && fad >= (FADSearch.fad + match_made))
        {
         FADSearch.spos = counter;
         FADSearch.fad = fad;
         match_made = true;
        }
       }
       bfi = Buffers[bfi].Next;
       counter++;
      } while(bfi != 0xFF);

      CDStatusResults();
      //
      //
      //
      CMD_EAT_CLOCKS(300);
      TriggerIRQ(HIRQ_ESEL);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FADSRCH) //	= 0x56,
    {
     BasicResults(MakeBaseStatus() << 8, FADSearch.spos, (FADSearch.pnum << 8) | (FADSearch.fad >> 16), FADSearch.fad);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_SET_SECLEN) //	= 0x60,
    {
     const unsigned NewGetSecLen = (CTR.CD[0] & 0xFF);
     const unsigned NewPutSecLen = (CTR.CD[1] >> 8);
     const bool NewGetSecLenBad = NewGetSecLen != 0xFF && (NewGetSecLen < SECLEN__FIRST || NewGetSecLen > SECLEN__LAST);
     const bool NewPutSecLenBad = NewPutSecLen != 0xFF && (NewPutSecLen < SECLEN__FIRST || NewPutSecLen > SECLEN__LAST);

     if(NewGetSecLenBad || NewPutSecLenBad)
     {
      CDStatusResults(true);
     }
     else
     {
      if(NewGetSecLen != 0xFF)
       GetSecLen = NewGetSecLen;

      if(NewPutSecLen != 0xFF)
       PutSecLen = NewPutSecLen;

      CDStatusResults();
      TriggerIRQ(HIRQ_ESEL);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_SECDATA || CTR.Command == COMMAND_DEL_SECDATA || CTR.Command == COMMAND_GETDEL_SECDATA) //	= 0x61, 0x62, 0x63
    {
     unsigned pnum;
     int offs, numsec;

     pnum = CTR.CD[2] >> 8;
     if(pnum >= 0x18)
      CDStatusResults(true);
     else
     {
      offs = CTR.CD[1];
      numsec = CTR.CD[3];

      if(offs == 0xFFFF)
       offs = Partitions[pnum].Count - 1;

      if(numsec == 0xFFFF)
       numsec = Partitions[pnum].Count - offs;

      if((DT.Active && CTR.Command != COMMAND_DEL_SECDATA) || numsec <= 0 || offs < 0 || (offs + numsec) > (int)Partitions[pnum].Count)
       CDStatusResults(false, STATUS_WAIT);
      else
      {
       int sbfi;

       sbfi = Partition_GetBuffer(pnum, offs);

       if(CTR.Command != COMMAND_DEL_SECDATA)
       {
        for(int i = 0, bfi = sbfi; i < numsec; i++)
        {
         const int next_bfi = Buffers[bfi].Next;
	 DT.BufList[i] = bfi;
	 if(CTR.Command == COMMAND_GETDEL_SECDATA)
          Partition_UnlinkBuffer(pnum, bfi);
         bfi = next_bfi;
        }

        CDStatusResults(false, STATUS_DTREQ);

        DT.Writing = false;
        DT.NeedBufFree = (CTR.Command == COMMAND_GETDEL_SECDATA);
        DT.CurBufIndex = 0;
        DT.BufCount = numsec;

        DT_SetIBOffsCount(Buffers[DT.BufList[0]].Data);

        DT.TotalCounter = 0;

        DT.FIFO_RP = 0;
        DT.FIFO_WP = 0;
        DT.FIFO_In = 0;

        for(unsigned i = 0; i < 5; i++)
 	 DT_ReadIntoFIFO();

        DT.Active = true;
       }
       else
        CDStatusResults();

       //
       //
       //
       if(CTR.Command == COMMAND_DEL_SECDATA)
       {
        for(int i = 0, bfi = sbfi; i < numsec; i++)
        {
         const int next_bfi = Buffers[bfi].Next;
         Partition_UnlinkBuffer(pnum, bfi);
	 Buffer_Free(bfi);
         bfi = next_bfi;
        }

        CMD_EAT_CLOCKS(485);
        TriggerIRQ(HIRQ_EHST);
       }
       else
       {
        CMD_EAT_CLOCKS(460);
        TriggerIRQ(HIRQ_DRDY);
       }
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_PUT_SECDATA) //	= 0x64,
    {
     unsigned fnum, numsec;

     fnum = CTR.CD[2] >> 8;
     numsec = CTR.CD[3];

     if(fnum >= 0x18)
     {
      CDStatusResults(true);
     }
     else if(numsec == 0 || numsec > FreeBufferCount || DT.Active)
     {
      CDStatusResults(false, STATUS_WAIT);
     }
     else
     {
      Filter_DisconnectInput(fnum);

      CDStatusResults(false, STATUS_DTREQ);

      DT.Writing = true;
      DT.NeedBufFree = false;
      DT.FNum = fnum;
      DT.CurBufIndex = 0;
      for(unsigned i = 0; i < numsec; i++)
      {
       DT.BufList[i] = Buffer_Allocate(true);
      }

      DT.BufCount = numsec;

      DT_SetIBOffsCount(NULL);

      DT.TotalCounter = 0;

      DT.FIFO_RP = 0;
      DT.FIFO_WP = 0;
      DT.FIFO_In = 0;
      DT.Active = true;
      //
      //
      //
      CMD_EAT_CLOCKS(300);
      TriggerIRQ(HIRQ_DRDY);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_COPY_SECDATA || CTR.Command == COMMAND_MOVE_SECDATA) //	= 0x65,  =0x66
    {
     unsigned dst_fnum, src_pnum;

     dst_fnum = CTR.CD[0] & 0xFF;
     src_pnum = CTR.CD[2] >> 8;

     if(src_pnum >= 0x18 || dst_fnum >= 0x18)
      CDStatusResults(true);
     else
     {
      int src_offs, numsec;

      src_offs = CTR.CD[1];
      numsec = CTR.CD[3];

      if(src_offs == 0xFFFF)
       src_offs = Partitions[src_pnum].Count - 1;

      if(numsec == 0xFFFF)
       numsec = Partitions[src_pnum].Count - src_offs;

      if(DT.Active || numsec <= 0 || (numsec > (int)FreeBufferCount && CTR.Command != COMMAND_MOVE_SECDATA) || src_offs < 0 || (src_offs + numsec) > (int)Partitions[src_pnum].Count)
       CDStatusResults(false, STATUS_WAIT);
      else
      {
       Filter_DisconnectInput(dst_fnum);

       for(int i = 0, bfi = Partition_GetBuffer(src_pnum, src_offs); i < numsec; i++)
       {
        const uint8* bufdata = Buffers[bfi].Data;
        const int next_bfi = Buffers[bfi].Next;

        if(CTR.Command == COMMAND_MOVE_SECDATA)
        {
         Partition_UnlinkBuffer(src_pnum, bfi);
         FilterBuf(dst_fnum, bfi);
        }
        else
	{
	 int abfi = Buffer_Allocate(false);
	
	 memcpy(Buffers[abfi].Data, bufdata, sizeof(Buffers[abfi].Data));

         FilterBuf(dst_fnum, abfi);
	}

        bfi = next_bfi;
       }
       CDStatusResults();
       //
       //
       // TODO: Accurate timing(while not blocking other command execution and sector reading).  Note that "move sector data" is much faster than "copy sector data".
       CMD_EAT_CLOCKS(300);
       if(FreeBufferCount == 0)
        TriggerIRQ(HIRQ_BFUL);
       TriggerIRQ(HIRQ_ECPY);
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_COPYERR) //	= 0x67,
    {
     // TODO: Implement if we ever implement proper asynch copy/moving
     BasicResults((MakeBaseStatus() << 8) | 0x00, 0, 0, 0);
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_CHANGE_DIR) //	= 0x70,
    {
     bool reject;
     uint8 fnum;
     uint32 fileid;
     uint32 fiaoffs;

     fnum = (CTR.CD[2] >> 8);
     fileid = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];
     fiaoffs = (fileid < 2) ? fileid : (2 + fileid - FLS.FileInfoOffs);

     reject = false;

     if(fnum >= 0x18)
      reject = true;

     if(fileid == 0xFFFFFF)
     {
      if(!RootDirInfoValid)
       reject = true;
     }
     else
     {
      if(!FileInfoValid)
       reject = true;
      else if(fileid >= 2 && (fileid < FLS.FileInfoOffs || fileid >= (FLS.FileInfoOffs + FLS.FileInfoValidCount)))
       reject = true;
      else if(!(FileInfo[fiaoffs].attr & 0x2))	// FIXME: test XA directory flag too?
       reject = true;
     }

     if(FLS.Active)
      CDStatusResults(false, STATUS_WAIT);
     else if(reject)
      CDStatusResults(true);
     else if(fileid == 0)	// NOP, kind of apparently(test after READ_DIR with a largeish file start id)...
     {
      CDStatusResults();
      CMD_EAT_CLOCKS(400);
      TriggerIRQ(HIRQ_EFLS);
     }
     else
     {
      CDStatusResults();
      //
      // Check (attr & 2) first?  and & 0x80 for XA?
      //
      const FileInfoS* fi;

      if(fileid == 0xFFFFFF)
       fi = &RootDirInfo;
      else
       fi = &FileInfo[fiaoffs];

      Partition_Clear(fnum);

      SetCDDeviceConn(fnum);
      Filter_SetTrueConn(fnum, fnum);
      Filter_SetFalseConn(fnum, 0xFF);
      Filter_SetRange(fnum, fi->fad(), (fi->size() + 2047) >> 11);	// TODO: maybe remove + 2047, actual Saturn drive seems buggy...
      Filters[fnum].Mode = FilterS::MODE_SEL_FADR;
      Filters[fnum].File = fi->fnum;

      Filters[fnum].Channel = 0;
      Filters[fnum].SubMode = 0;
      Filters[fnum].SubModeMask = 0;
      Filters[fnum].CInfo = 0;
      Filters[fnum].CInfoMask = 0;
      
      FLS.pnum = fnum;
      FLS.total_max = fi->size();
      FLS.FileInfoOffs = 2;
      FLS.DoAuth = false;
      FLS.Active = true;

      ClearPendingSec();
      //
      CurPlayEnd = 0;
      CurPlayRepeat = 0;
      PlayRepeatCounter = 0;
      //
      StartSeek(0x800000 | fi->fad());
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_READ_DIR) //	= 0x71,
    {
     uint8 fnum;
     uint32 start_fileid;

     fnum = (CTR.CD[2] >> 8);
     start_fileid = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];

     if(FLS.Active)
      CDStatusResults(false, STATUS_WAIT);
     else if(fnum >= 0x18 || !FileInfoValid)
      CDStatusResults(true);
     else
     {
      CDStatusResults();
      //
      // Check (attr & 2) first?  and & 0x80 for XA?
      //
      const FileInfoS* fi = &FileInfo[0];

      if(start_fileid < FLS.FileInfoOffs || start_fileid >= (FLS.FileInfoOffs + FLS.FileInfoValidCount))
       start_fileid = 2;

      SetCDDeviceConn(fnum);
      Filter_SetTrueConn(fnum, fnum);
      Filter_SetFalseConn(fnum, 0xFF);
      Filter_SetRange(fnum, fi->fad(), (fi->size() + 2047) >> 11);
      Filters[fnum].Mode = FilterS::MODE_SEL_FADR;
      
      FLS.pnum = fnum;
      FLS.total_max = fi->size();
      FLS.FileInfoOffs = start_fileid;
      FLS.DoAuth = false;
      FLS.Active = true;

      ClearPendingSec();
      //
      CurPlayEnd = 0;
      CurPlayRepeat = 0;
      PlayRepeatCounter = 0;
      //
      StartSeek(0x800000 | fi->fad());
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FSSCOPE) //	= 0x72,
    {
     if(FLS.Active)	// Maybe add a specific check for directory reading?  (Will have to if we chain READ_FILE into FLS.Active someday for whatever reason)
      CDStatusResults(false, STATUS_WAIT);
     else if(!FileInfoValid)
      CDStatusResults(true);
     else
     {
      // FIXME: Not sure about the [0].fad == [1].fad root dir thing...  Might instead be 0x01 to note that the number of files in the directory 
      // can be held without using Read Directory?
      BasicResults((MakeBaseStatus() << 8),
		FLS.FileInfoValidCount, 
		((FileInfo[0].fad() == FileInfo[1].fad()) << 8) | (FLS.FileInfoOffs >> 16),
		FLS.FileInfoOffs);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_GET_FINFO) //	= 0x73,
    {
     if(FLS.Active || DT.Active)
      CDStatusResults(false, STATUS_WAIT);
     else if(!FileInfoValid)
      CDStatusResults(true);
     else
     {
      uint32 fileid;

      fileid = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];

      if(fileid != 0xFFFFFF && (fileid >= 2 && (fileid < FLS.FileInfoOffs || fileid >= (FLS.FileInfoOffs + FLS.FileInfoValidCount))))
       CDStatusResults(true);
      else
      {
       {
	const uint32 fiaoffs = (fileid < 2) ? fileid : (2 + fileid - FLS.FileInfoOffs);

        DT.CurBufIndex = 0;
        DT.BufCount = 1;

        if(fileid == 0xFFFFFF)
        {
         DT.InBufOffs = 6 * 2;
         DT.InBufCounter = 6 * FLS.FileInfoValidCount;
        }
        else
        {
         DT.InBufOffs = 6 * fiaoffs;
         DT.InBufCounter = 6;
        }

        DT.TotalCounter = 0;

        DT.FIFO_RP = 0;
        DT.FIFO_WP = 0;
        DT.FIFO_In = 0;

        DT.BufList[0] = 0xF0;
      
        DT.Writing = false;
        DT.NeedBufFree = false;
        DT.Active = true;

        BasicResults(MakeBaseStatus(false, STATUS_DTREQ) << 8, DT.InBufCounter, 0, 0);
       }
       //
       //
       //
       CMD_EAT_CLOCKS(128);
       TriggerIRQ(HIRQ_DRDY);
      }
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_READ_FILE) //	= 0x74,
    {
     uint32 offset;
     uint32 fileid;
     uint8 fnum;

     offset = ((CTR.CD[0] & 0xFF) << 16) | CTR.CD[1];
     fileid = ((CTR.CD[2] & 0xFF) << 16) | CTR.CD[3];
     fnum = CTR.CD[2] >> 8;

     if(FLS.Active)
      CDStatusResults(false, STATUS_WAIT);
     else if(fnum >= 0x18 || !FileInfoValid || (fileid >= 2 && (fileid < FLS.FileInfoOffs || fileid >= (FLS.FileInfoOffs + FLS.FileInfoValidCount))))
      CDStatusResults(true);
     else
     {
      CDStatusResults();

      Partition_Clear(fnum);

      //printf("DT Meow READ: 0x%08x 0x%08x --- offs=0x%08x\n", FileInfo[fileid].fad(), FileInfo[fileid].size(), offset);
      const uint32 fiaoffs = (fileid < 2) ? fileid : (2 + fileid - FLS.FileInfoOffs);
      uint32 start_fad = (FileInfo[fiaoffs].fad() + offset) & 0xFFFFFF;
      uint32 sec_count = ((FileInfo[fiaoffs].size() + 2047) >> 11) - offset;	// FIXME: Check offset versus ifile size.

      ClearPendingSec();
      //
      SetCDDeviceConn(fnum);
      Filter_SetTrueConn(fnum, fnum);
      Filter_SetFalseConn(fnum, 0xFF);
      Filter_SetRange(fnum, start_fad, sec_count);	// Not sure if correct for XA interleaved files...

      Filters[fnum].Mode = FilterS::MODE_SEL_FADR | FilterS::MODE_SEL_FILE;
      Filters[fnum].File = FileInfo[fiaoffs].fnum;

      Filters[fnum].Channel = 0;
      Filters[fnum].SubMode = 0;
      Filters[fnum].SubModeMask = 0;
      Filters[fnum].CInfo = 0;
      Filters[fnum].CInfoMask = 0;
      //
      PlayEndIRQType = HIRQ_EFLS;
      CurPlayEnd = 0x800000 | ((start_fad + sec_count) & 0x7FFFFF);
      CurPlayRepeat = 0;
      PlayRepeatCounter = 0;
      //
      StartSeek(start_fad | 0x800000);
     }
    }
    //
    //
    //
    else if(CTR.Command == COMMAND_ABORT_FILE) //	= 0x75,
    {
     // TODO: Does tray opening during a file operation trigger HIRQ_EFLS?
     CDStatusResults();

     FLS.Abort = true;
    }
    else
    {
     SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Unknown Command: 0x%04x 0x%04x 0x%04x 0x%04x --- HIRQ=0x%04x, HIRQ_Mask=0x%04x\n", CTR.CD[0], CTR.CD[1], CTR.CD[2], CTR.CD[3], HIRQ, HIRQ_Mask);

     ResultsRead = false;
     CommandPending = false;
    }

    if(SWResetPending)
    {
     SWResetPending = false;
     SWReset();

     CMD_EAT_CLOCKS(8192 - 180);

     SWResetHIRQDeferred = HIRQ_MPED | HIRQ_EFLS | HIRQ_ECPY | HIRQ_EHST | HIRQ_ESEL | HIRQ_CMOK;
     // If a stupid game(Tenchi Muyou Ryououki Gokuraku) tries to run a new command after the Initialize command's software reset process
     // begins but before it finishes, delay software reset HIRQ bit setting until the command generates its own HIRQ_CMOK(effectively collapsing two HIRQ_CMOKs
     // into one HIRQ_CMOK in the process).
     if(!CommandPending)
     {
      TriggerIRQ(SWResetHIRQDeferred);
      SWResetHIRQDeferred = 0;
     }
    }

    continue;
    //
    //
    //
    case -1 + CommandPhaseBias:

    CMD_EAT_CLOCKS(4880000);

    StandbyTime = 0;
    ECCEnable = 0xFF;
    RetryCount = 1;
    CommandPending = false;
    SWResetPending = false;
    SWResetHIRQDeferred = 0;
    ResultsRead = true;

    memset(&DT, 0, sizeof(DT));

    PlayCmdStartPos = 0;	// TODO: Test for correct value.
    PlayCmdEndPos = 0;	// TODO: Test for correct value.
    PlayCmdRepCnt = 0;	// TODO: ...

    CurPlayRepeat = 0;	// TODO: . . .
    PlayRepeatCounter = 0;

    DriveCounter = (int64)1000 << 32;
    DrivePhase = DRIVEPHASE_EJECTED_WAITING;

    memset(TOC_Buffer, 0xFF, sizeof(TOC_Buffer));	// TODO: confirm 0xFF(or 0x00?)

    AuthDiscType = 0x00;
    FileInfoValid = false;
    RootDirInfoValid = false;
    PeriodicIdleCounter = PeriodicIdleCounter_Reload;

    CurPosInfo.status = STATUS_OPEN;
    CurPosInfo.is_cdrom = false;
    CurPosInfo.fad = 0xFFFFFF;
    CurPosInfo.rel_fad = 0xFFFFFF;
    CurPosInfo.ctrl_adr = 0xFF;
    CurPosInfo.idx = 0xFF;
    CurPosInfo.tno = 0xFF;

    CDDABuf_WP = 0;
    CDDABuf_RP = 0;
    CDDABuf_Count = 0;

    //
    //
    RootDirInfoValid = false;
    //
    //
    SWReset();

    CurPosInfo.status = STATUS_BUSY;	// FIXME(so it's set long enough from POV of program)
    CurPosInfo.is_cdrom = false;
    CurSector = 0;

    Results[0] = 0x0043;
    Results[1] = 0x4442;
    Results[2] = 0x4c4f;
    Results[3] = 0x434b;
    ResultsRead = false;
    TriggerIRQ(HIRQ_CMOK | HIRQ_DCHG | HIRQ_ESEL | HIRQ_EHST | HIRQ_MPED | HIRQ_ECPY | HIRQ_EFLS);
    continue;
   }
  }
  CommandGetOut:;
  //
  //
  //

  //RunFLS(clocks);
 }


 assert(DriveCounter > 0);

 {
  int64 net = -CommandClockCounter;

  if(DriveCounter < net)
   net = DriveCounter;

  if(PeriodicIdleCounter < net)
   net = PeriodicIdleCounter;

  return timestamp + (net + CDB_ClockRatio - 1) / CDB_ClockRatio;
 }
}

void CDB_ResetTS(void)
{
 lastts = 0;
}


uint16 CDB_Read(uint32 offset)
{
 uint16 ret = 0; //0xFFFF;

#if 1
 if(offset >= 0x6 && offset <= 0x9 && CommandPending)
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Read from register 0x%01x while busy processing command!\n", offset);
 }
#endif

 switch(offset)
 {
  case 0x0:
	if(DT.Active && !DT.Writing)
	{
	 if(DT.InBufCounter > 0)
	  DT_ReadIntoFIFO();

	 if(MDFN_UNLIKELY(!DT.FIFO_In))
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] DT FIFO underflow.\n");
	 }

	 ret = DT.FIFO[DT.FIFO_RP];
	 DT.FIFO_RP = (DT.FIFO_RP + 1) % (sizeof(DT.FIFO) / sizeof(DT.FIFO[0]));
	 DT.FIFO_In -= (bool)DT.FIFO_In;
	}
	break;

  case 0x2:	// HIRQ
	ret = HIRQ;
	break;

  case 0x3:	// HIRQ mask
	ret = HIRQ_Mask;
	break;

  case 0x6: ret = Results[0]; /*if(!ResultsRead) printf(" [CDB] Result0 Read: 0x%04x\n", ret);*/ break;
  case 0x7: ret = Results[1]; /*if(!ResultsRead) printf(" [CDB] Result1 Read: 0x%04x\n", ret);*/ break;
  case 0x8: ret = Results[2]; /*if(!ResultsRead) printf(" [CDB] Result2 Read: 0x%04x\n", ret);*/ break;
  case 0x9: ret = Results[3]; /*if(!ResultsRead) printf(" [CDB] Result3 Read: 0x%04x\n", ret);*/ ResultsRead = true; break;
 }

 //if(offset == 0)
 // fprintf(stderr, "Read: %02x %04x\n", offset, ret);

 return ret;
}

void CDB_Write_DBM(uint32 offset, uint16 DB, uint16 mask)
{
 sscpu_timestamp_t nt = CDB_Update(SH7095_mem_timestamp);

 //SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Write %02x %04x %04x\n", offset, DB, mask);

#if 1
 if(offset >= 0x6 && offset <= 0x9 && CommandPending)
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_CDB, "[CDB] Write to register 0x%01x(DB=0x%04x, mask=0x%04x) while busy processing command!\n", offset, DB, mask);
 }
#endif

 switch(offset)
 {
  case 0x0:
	if(DT.Active && DT.Writing)
	{
	 if(DT.InBufCounter > 0)
	 {
	  DT.FIFO[DT.FIFO_WP] = (DT.FIFO[DT.FIFO_WP] &~ mask) | (DB & mask);
	  DT.FIFO_WP = (DT.FIFO_WP + 1) % (sizeof(DT.FIFO) / sizeof(DT.FIFO[0]));
	  DT.FIFO_In++;

	  MDFN_en16msb(&Buffers[DT.BufList[DT.CurBufIndex]].Data[DT.InBufOffs << 1], DT.FIFO[DT.FIFO_RP]);
          DT.InBufOffs++;
	  DT.FIFO_RP = (DT.FIFO_RP + 1) % (sizeof(DT.FIFO) / sizeof(DT.FIFO[0]));
	  DT.FIFO_In--;

	  DT.InBufCounter--;
	  DT.TotalCounter++;

	  if(!DT.InBufCounter)
	  {
	   DT.CurBufIndex++;
	   if(DT.CurBufIndex < DT.BufCount)
	   {
	    DT_SetIBOffsCount(NULL);
	   }
	  }
	 }
	}
	break;

  case 0x2:
	HIRQ = HIRQ & (DB | ~mask);
	RecalcIRQOut();
	break;

  case 0x3:
	HIRQ_Mask = (HIRQ_Mask &~ mask) | (DB & mask);
	RecalcIRQOut();
	break;

  case 0x6:
	CData[0] = (CData[0] &~ mask) | (DB & mask);
	break;

  case 0x7:
	CData[1] = (CData[1] &~ mask) | (DB & mask);
	break;

  case 0x8:
	CData[2] = (CData[2] &~ mask) | (DB & mask);
	break;

  case 0x9:
	CData[3] = (CData[3] &~ mask) | (DB & mask);
	if(mask == 0xFFFF)
	{
	 CommandPending = true;
	 nt = SH7095_mem_timestamp + 1;
	}
	break;
 }

 SS_SetEventNT(&events[SS_EVENT_CDB], nt);
}



void CDB_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(GetSecLen),
  SFVAR(PutSecLen),

  SFVAR(AuthDiscType),

  SFVAR(HIRQ),
  SFVAR(HIRQ_Mask),
  SFVAR(CData),
  SFVAR(Results),

  SFVAR(CommandPending),
  SFVAR(SWResetHIRQDeferred),
  SFVAR(SWResetPending),

  SFVAR(CDDevConn),
  SFVAR(LastBufDest),

  //
  //
  SFVAR(Buffers->Data, NumBuffers, sizeof(*Buffers), Buffers),
  SFVAR(Buffers->Prev, NumBuffers, sizeof(*Buffers), Buffers),
  SFVAR(Buffers->Next, NumBuffers, sizeof(*Buffers), Buffers),
  //
  //
  SFVAR(Filters->Mode, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->TrueConn, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->FalseConn, 0x18, sizeof(*Filters), Filters),

  SFVAR(Filters->FAD, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->Range, 0x18, sizeof(*Filters), Filters),

  SFVAR(Filters->Channel, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->File, 0x18, sizeof(*Filters), Filters),

  SFVAR(Filters->SubMode, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->SubModeMask, 0x18, sizeof(*Filters), Filters),

  SFVAR(Filters->CInfo, 0x18, sizeof(*Filters), Filters),
  SFVAR(Filters->CInfoMask, 0x18, sizeof(*Filters), Filters),
  //
  //
  SFVAR(Partitions->FirstBuf, 0x18, sizeof(*Partitions), Partitions),
  SFVAR(Partitions->LastBuf, 0x18, sizeof(*Partitions), Partitions),
  SFVAR(Partitions->Count, 0x18, sizeof(*Partitions), Partitions),

  SFVAR(FirstFreeBuf),
  SFVAR(FreeBufferCount),

  SFVAR(FADSearch.fad),
  SFVAR(FADSearch.spos),
  SFVAR(FADSearch.pnum),

  SFVAR(CalcedActualSize),

  SFVAR(lastts),
  SFVAR(CommandPhase),
  //SFVAR(CommandYield),
  SFVAR(CommandClockCounter),

  SFVAR(CTR.Command),
  SFVAR(CTR.CD),

  SFVAR(DT.Active),
  SFVAR(DT.Writing),
  SFVAR(DT.NeedBufFree),

  SFVAR(DT.CurBufIndex),
  SFVAR(DT.BufCount),

  SFVAR(DT.InBufOffs),
  SFVAR(DT.InBufCounter),

  SFVAR(DT.TotalCounter),

  SFVAR(DT.FNum),

  SFVAR(DT.FIFO),
  SFVAR(DT.FIFO_RP),
  SFVAR(DT.FIFO_WP),
  SFVAR(DT.FIFO_In),

  SFVAR(DT.BufList),

  SFVAR(StandbyTime),
  SFVAR(ECCEnable),
  SFVAR(RetryCount),

  SFVAR(ResultsRead),

  SFVAR(SeekIndexPhase),
  SFVAR(CurSector),
  SFVAR(DrivePhase),

  SFVAR(DriveCounter),
  SFVAR(PeriodicIdleCounter),

  SFVAR(PlayRepeatCounter),
  SFVAR(CurPlayRepeat),

  SFVAR(CurPlayStart),
  SFVAR(CurPlayEnd),
  SFVAR(PlayEndIRQType),
  //static uint32 PlayEndIRQPending;

  SFVAR(PlayCmdStartPos),
  SFVAR(PlayCmdEndPos),
  SFVAR(PlayCmdRepCnt),

  SFVARN(CDDABuf, "&CDDABuf[0][0]"),
  SFVAR(CDDABuf_RP),
  SFVAR(CDDABuf_WP),
  SFVAR(CDDABuf_Count),

  SFVAR(SecPreBuf),
  SFVAR(SecPreBuf_In),

  SFVAR(TOC_Buffer),

  SFVAR(CurPosInfo.status),
  SFVAR(CurPosInfo.fad),
  SFVAR(CurPosInfo.rel_fad),
  SFVAR(CurPosInfo.ctrl_adr),
  SFVAR(CurPosInfo.idx),
  SFVAR(CurPosInfo.tno),

  SFVAR(CurPosInfo.is_cdrom),
  SFVAR(CurPosInfo.repcount),

  SFVAR(SubCodeQBuf),
  SFVAR(SubCodeRWBuf),

  SFVAR(SubQBuf),
  SFVAR(SubQBuf_Safe),
  SFVAR(SubQBuf_Safe_Valid),

  #define SFFIS(vs, tc)						\
	SFVAR((vs).fad_be, tc, sizeof(vs), &vs),		\
	SFVAR((vs).size_be, tc, sizeof(vs), &vs),		\
	SFVAR((vs).unit_size, tc, sizeof(vs), &vs),		\
	SFVAR((vs).gap_size, tc, sizeof(vs), &vs),		\
	SFVAR((vs).fnum, tc, sizeof(vs), &vs),			\
	SFVAR((vs).attr, tc, sizeof(vs), &vs)

  SFFIS(*FileInfo, 256),
  SFVAR(FileInfoValid),

  SFFIS(RootDirInfo, 1),
  SFVAR(RootDirInfoValid),
  #undef SFFIS

  SFVAR(FLS.Active),
  SFVAR(FLS.DoAuth),
  SFVAR(FLS.Abort),
  SFVAR(FLS.pnum),

  SFVAR(FLS.CurDirFAD),

  SFVAR(FLS.FileInfoValidCount),
  SFVAR(FLS.FileInfoOffs),
  SFVAR(FLS.FileInfoOnDiscCount),

  SFVAR(FLS.Phase),

  SFVAR(FLS.pbuf),
  SFVAR(FLS.pbuf_offs),
  SFVAR(FLS.pbuf_read_i),

  SFVAR(FLS.total_counter),
  SFVAR(FLS.total_max),

  SFVAR(FLS.record),
  SFVAR(FLS.record_counter),

  SFVAR(FLS.finfo_offs),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CDB");

 if(load)
 {
  // FIXME: Sanitizing!
  //
  //
  //
  bool need_reset_buffers = false;

  for(unsigned i = 0; i < 0x18; i++)
  {
   auto& p = Partitions[i];

   if(p.FirstBuf >= NumBuffers && p.FirstBuf != 0xFF)
    need_reset_buffers = true;
   else if(p.LastBuf >= NumBuffers && p.LastBuf != 0xFF)
    need_reset_buffers = true;
   //Partitions[i].Count = 0;
  }

  for(unsigned i = 0; i < NumBuffers; i++)
  {
   auto& b = Buffers[i];

   if(b.Prev >= NumBuffers && b.Prev != 0xFF)
    need_reset_buffers = true;
   else if(b.Next >= NumBuffers && b.Next != 0xFF)
    need_reset_buffers = true;
  }

  if(need_reset_buffers)
  {
   printf("need_reset_buffers!\n");
   ResetBuffers();
  }
  //
  //
  //


  DT.FNum %= 0x18;

  DT.FIFO_WP %= sizeof(DT.FIFO) / sizeof(DT.FIFO[0]);
  DT.FIFO_RP %= sizeof(DT.FIFO) / sizeof(DT.FIFO[0]);

  CDDABuf_RP %= CDDABuf_MaxCount;
  CDDABuf_WP %= CDDABuf_MaxCount;

  FLS.pbuf_offs %= 2048;
  //FLS.pbuf_read_i
  FLS.finfo_offs %= 256 + 1;
 }
}


}
