/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/mednafen.h>
#include <math.h>
#include <trio/trio.h>
#include "pcecd_drive.h"
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/cdrom/SimpleFIFO.h>

namespace PCE_Fast
{
//#define SCSIDBG(format, ...) { printf("SCSI: " format "\n",  ## __VA_ARGS__); }
//#define SCSIDBG(format, ...) { }

using namespace CDUtility;

static uint32 CD_DATA_TRANSFER_RATE;
static uint32 System_Clock;
static void (*CDIRQCallback)(int);
static void (*CDStuffSubchannels)(uint8, int);
static Blip_Buffer* sbuf;

static CDIF *Cur_CDIF;
static bool TrayOpen;

// Internal operation to the SCSI CD unit.  Only pass 1 or 0 to these macros!
#define SetIOP(mask, set)	{ cd_bus.signals &= ~mask; if(set) cd_bus.signals |= mask; }

#define SetBSY(set)		SetIOP(PCECD_Drive_BSY_mask, set)
#define SetIO(set)              SetIOP(PCECD_Drive_IO_mask, set)
#define SetCD(set)              SetIOP(PCECD_Drive_CD_mask, set)
#define SetMSG(set)             SetIOP(PCECD_Drive_MSG_mask, set)

static INLINE void SetREQ(bool set)
{
 if(set && !REQ_signal)
  CDIRQCallback(PCECD_Drive_IRQ_MAGICAL_REQ);

 SetIOP(PCECD_Drive_REQ_mask, set);
}

#define SetkingACK(set)		SetIOP(PCECD_Drive_kingACK_mask, set)
#define SetkingRST(set)         SetIOP(PCECD_Drive_kingRST_mask, set)
#define SetkingSEL(set)         SetIOP(PCECD_Drive_kingSEL_mask, set)


enum
{
 QMode_Zero = 0,
 QMode_Time = 1,
 QMode_MCN = 2, // Media Catalog Number
 QMode_ISRC = 3 // International Standard Recording Code
};

typedef struct
{
 bool last_RST_signal;

 // The pending message to send(in the message phase)
 uint8 message_pending;

 bool status_sent, message_sent;

 // Pending error codes
 uint8 key_pending, asc_pending, ascq_pending, fru_pending;

 uint8 command_buffer[256];
 uint8 command_buffer_pos;
 uint8 command_size_left;

 // FALSE if not all pending data is in the FIFO, TRUE if it is.
 // Used for multiple sector CD reads.
 bool data_transfer_done;

 bool DiscChanged;

 uint8 SubQBuf[4][0xC];		// One for each of the 4 most recent q-Modes.
 uint8 SubQBuf_Last[0xC];	// The most recent q subchannel data, regardless of q-mode.

 uint8 SubPWBuf[96];

} pcecd_drive_t;

typedef Blip_Synth < blip_good_quality, 1> CDSynth;

enum
{
 CDDASTATUS_PAUSED = -1,
 CDDASTATUS_STOPPED = 0,
 CDDASTATUS_PLAYING = 1,
};

enum
{
 PLAYMODE_SILENT = 0x00,
 PLAYMODE_NORMAL,
 PLAYMODE_INTERRUPT,
 PLAYMODE_LOOP,
};

typedef struct
{
 int32 CDDADivAcc;
 uint32 scan_sec_end;

 uint8 PlayMode;
 CDSynth CDDASynth;
 int32 CDDAVolume;
 int16 last_sample[2];
 int16 CDDASectorBuffer[1176];
 uint32 CDDAReadPos;

 int8 CDDAStatus;
 uint8 ScanMode;
 int32 CDDADiv;
 int CDDATimeDiv;
} cdda_t;

static INLINE void MakeSense(uint8 target[18], uint8 key, uint8 asc, uint8 ascq, uint8 fru)
{
 memset(target, 0, 18);

 target[0] = 0x70;		// Current errors and sense data is not SCSI compliant
 target[2] = key;
 target[7] = 0x0A;
 target[12] = asc;		// Additional Sense Code
 target[13] = ascq;		// Additional Sense Code Qualifier
 target[14] = fru;		// Field Replaceable Unit code
}

static pcecd_drive_timestamp_t lastts;
static int64 monotonic_timestamp;
static int64 pce_lastsapsp_timestamp;

static pcecd_drive_t cd;
pcecd_drive_bus_t cd_bus;
static cdda_t cdda;

static SimpleFIFO<uint8> din(2048);

static CDUtility::TOC toc;

static uint32 read_sec_start;
static uint32 read_sec;
static uint32 read_sec_end;

static int32 CDReadTimer;
static uint32 SectorAddr;
static uint32 SectorCount;


enum
{
 PHASE_BUS_FREE = 0,
 PHASE_COMMAND,
 PHASE_DATA_IN,
 PHASE_STATUS,
 PHASE_MESSAGE_IN,
};

static unsigned int CurrentPhase;
static void ChangePhase(const unsigned int new_phase);

static void VirtualReset(void)
{
 din.Flush();

 cdda.CDDADivAcc = (int64)System_Clock * 65536 / 44100;
 CDReadTimer = 0;

 pce_lastsapsp_timestamp = monotonic_timestamp;

 SectorAddr = SectorCount = 0;
 read_sec_start = read_sec = 0;
 read_sec_end = ~0;

 cdda.PlayMode = PLAYMODE_SILENT;
 cdda.CDDAReadPos = 0;
 cdda.CDDAStatus = CDDASTATUS_STOPPED;
 cdda.CDDADiv = 0;

 cdda.ScanMode = 0;
 cdda.scan_sec_end = 0;

 ChangePhase(PHASE_BUS_FREE);
}

void PCECD_Drive_Power(pcecd_drive_timestamp_t system_timestamp)
{
 memset(&cd, 0, sizeof(pcecd_drive_t));
 memset(&cd_bus, 0, sizeof(pcecd_drive_bus_t));

 monotonic_timestamp = system_timestamp;

 cd.DiscChanged = false;

 if(Cur_CDIF && !TrayOpen)
  Cur_CDIF->ReadTOC(&toc);

 CurrentPhase = PHASE_BUS_FREE;

 VirtualReset();
}


void PCECD_Drive_SetDB(uint8 data)
{
 cd_bus.DB = data;
 //printf("Set DB: %02x\n", data);
}

void PCECD_Drive_SetACK(bool set)
{
 SetkingACK(set);
 //printf("Set ACK: %d\n", set);
}

void PCECD_Drive_SetSEL(bool set)
{
 SetkingSEL(set);
 //printf("Set SEL: %d\n", set);
}

void PCECD_Drive_SetRST(bool set)
{
 SetkingRST(set);
 //printf("Set RST: %d\n", set);
}

static void GenSubQFromSubPW(void)
{
 uint8 SubQBuf[0xC];

 subq_deinterleave(cd.SubPWBuf, SubQBuf);

 //printf("Real %d/ SubQ %d - ", read_sec, BCD_to_U8(SubQBuf[7]) * 75 * 60 + BCD_to_U8(SubQBuf[8]) * 75 + BCD_to_U8(SubQBuf[9]) - 150);
 // Debug code, remove me.
 //for(int i = 0; i < 0xC; i++)
 // printf("%02x ", SubQBuf[i]);
 //printf("\n");

 if(!subq_check_checksum(SubQBuf))
 {
  //SCSIDBG("SubQ checksum error!");
 }
 else
 {
  memcpy(cd.SubQBuf_Last, SubQBuf, 0xC);

  uint8 adr = SubQBuf[0] & 0xF;

  if(adr <= 0x3)
   memcpy(cd.SubQBuf[adr], SubQBuf, 0xC);

  //if(adr == 0x02)
  //for(int i = 0; i < 12; i++)
  // printf("%02x\n", cd.SubQBuf[0x2][i]);
 }
}


#define STATUS_GOOD		0
#define STATUS_CHECK_CONDITION	1

#define SENSEKEY_NO_SENSE		0x0
#define SENSEKEY_NOT_READY		0x2
#define SENSEKEY_MEDIUM_ERROR		0x3
#define SENSEKEY_HARDWARE_ERROR		0x4
#define SENSEKEY_ILLEGAL_REQUEST	0x5
#define SENSEKEY_UNIT_ATTENTION		0x6
#define SENSEKEY_ABORTED_COMMAND	0xB

#define ASC_MEDIUM_NOT_PRESENT		0x3A


// NEC sub-errors(ASC), no ASCQ.
#define NSE_NO_DISC			0x0B		// Used with SENSEKEY_NOT_READY	- This condition occurs when tray is closed with no disc present.
#define NSE_TRAY_OPEN			0x0D		// Used with SENSEKEY_NOT_READY 
#define NSE_SEEK_ERROR			0x15
#define NSE_HEADER_READ_ERROR		0x16		// Used with SENSEKEY_MEDIUM_ERROR
#define NSE_NOT_AUDIO_TRACK		0x1C		// Used with SENSEKEY_MEDIUM_ERROR
#define NSE_NOT_DATA_TRACK		0x1D		// Used with SENSEKEY_MEDIUM_ERROR
#define NSE_INVALID_COMMAND		0x20
#define NSE_INVALID_ADDRESS		0x21
#define NSE_INVALID_PARAMETER		0x22
#define NSE_END_OF_VOLUME		0x25
#define NSE_INVALID_REQUEST_IN_CDB	0x27
#define NSE_DISC_CHANGED		0x28		// Used with SENSEKEY_UNIT_ATTENTION
#define NSE_AUDIO_NOT_PLAYING		0x2C

// ASC, ASCQ pair
#define AP_UNRECOVERED_READ_ERROR	0x11, 0x00
#define AP_LEC_UNCORRECTABLE_ERROR	0x11, 0x05
#define AP_CIRC_UNRECOVERED_ERROR	0x11, 0x06

#define AP_UNKNOWN_MEDIUM_FORMAT	0x30, 0x01
#define AP_INCOMPAT_MEDIUM_FORMAT	0x30, 0x02

static void ChangePhase(const unsigned int new_phase)
{
 //printf("New phase: %d %lld\n", new_phase, monotonic_timestamp);
 switch(new_phase)
 {
  case PHASE_BUS_FREE:
		SetBSY(false);
		SetMSG(false);
		SetCD(false);
		SetIO(false);
		SetREQ(false);

	        CDIRQCallback(0x8000 | PCECD_Drive_IRQ_DATA_TRANSFER_DONE);
		break;

  case PHASE_DATA_IN:		// Us to them
		SetBSY(true);
	        SetMSG(false);
	        SetCD(false);
	        SetIO(true);
	        //SetREQ(true);
		SetREQ(false);
		break;

  case PHASE_STATUS:		// Us to them
		SetBSY(true);
		SetMSG(false);
		SetCD(true);
		SetIO(true);
		SetREQ(true);
		break;

  case PHASE_MESSAGE_IN:	// Us to them
		SetBSY(true);
		SetMSG(true);
		SetCD(true);
		SetIO(true);
		SetREQ(true);
		break;

  case PHASE_COMMAND:		// Them to us
		SetBSY(true);
	        SetMSG(false);
	        SetCD(true);
	        SetIO(false);
	        SetREQ(true);
		break;
 }
 CurrentPhase = new_phase;
}

static void SendStatusAndMessage(uint8 status, uint8 message)
{
 // This should never ever happen, but that doesn't mean it won't. ;)
 if(din.CanRead())
 {
  printf("BUG: %d bytes still in SCSI CD FIFO\n", din.CanRead());
  din.Flush();
 }

 cd.message_pending = message;

 cd.status_sent = FALSE;
 cd.message_sent = FALSE;


 if(status == STATUS_GOOD)
  cd_bus.DB = 0x00;
 else
  cd_bus.DB = 0x01;


 ChangePhase(PHASE_STATUS);
}

static void DoSimpleDataIn(const uint8 *data_in, uint32 len)
{
 din.Write(data_in, len);

 cd.data_transfer_done = true;

 ChangePhase(PHASE_DATA_IN);
}

void PCECD_Drive_SetDisc(bool new_tray_open, CDIF *cdif, bool no_emu_side_effects)
{
 Cur_CDIF = cdif;

 // Closing the tray.
 if(TrayOpen && !new_tray_open)
 {
  TrayOpen = false;

  if(cdif)
  {
   cdif->ReadTOC(&toc);

   if(!no_emu_side_effects)
   {
    memset(cd.SubQBuf, 0, sizeof(cd.SubQBuf));
    memset(cd.SubQBuf_Last, 0, sizeof(cd.SubQBuf_Last));
    cd.DiscChanged = true;
   }
  }
 }
 else if(!TrayOpen && new_tray_open)	// Opening the tray
 {
  TrayOpen = true;
 }
}

static void CommandCCError(int key, int asc = 0, int ascq = 0)
{
 //printf("CC Error: %02x %02x %02x\n", key, asc, ascq);

 cd.key_pending = key;
 cd.asc_pending = asc;
 cd.ascq_pending = ascq;
 cd.fru_pending = 0x00;

 SendStatusAndMessage(STATUS_CHECK_CONDITION, 0x00);
}

static bool ValidateRawDataSector(uint8 *data, const uint32 lba)
{
 if(!edc_lec_check_and_correct(data, false))
 {
  MDFN_DispMessage(_("Uncorrectable data at sector %u"), lba);
  MDFN_PrintError(_("Uncorrectable data at sector %u"), lba);

  din.Flush();
  cd.data_transfer_done = false;

  CommandCCError(SENSEKEY_MEDIUM_ERROR, AP_LEC_UNCORRECTABLE_ERROR);
  return(false);
 }

 return(true);
}

static void DoREADBase(uint32 sa, uint32 sc)
{
 if(sa > toc.tracks[100].lba) // Another one of those off-by-one PC-FX CD bugs.
 {
  CommandCCError(SENSEKEY_ILLEGAL_REQUEST, NSE_END_OF_VOLUME);
  return;
 }

 // Case for READ(10) and READ(12) where sc == 0, and sa == toc.tracks[100].lba
 if(!sc && sa == toc.tracks[100].lba)
 {
  CommandCCError(SENSEKEY_MEDIUM_ERROR, NSE_HEADER_READ_ERROR);
  return;
 }

 SectorAddr = sa;
 SectorCount = sc;
 if(SectorCount)
 {
  Cur_CDIF->HintReadSector(sa);	//, sa + sc);

  CDReadTimer = (uint64)3 * 2048 * System_Clock / CD_DATA_TRANSFER_RATE;
 }
 else
 {
  CDReadTimer = 0;
  SendStatusAndMessage(STATUS_GOOD, 0x00);
 }
 cdda.CDDAStatus = CDDASTATUS_STOPPED;
}

//
//
//
static void DoTESTUNITREADY(const uint8 *cdb)
{
 SendStatusAndMessage(STATUS_GOOD, 0x00);
}

static void DoREQUESTSENSE(const uint8 *cdb)
{
 uint8 data_in[18];

 MakeSense(data_in, cd.key_pending, cd.asc_pending, cd.ascq_pending, cd.fru_pending);

 DoSimpleDataIn(data_in, 18);

 cd.key_pending = 0;
 cd.asc_pending = 0;
 cd.ascq_pending = 0;
 cd.fru_pending = 0;
}

/********************************************************
*							*
*	SCSI      Command 0x08 - READ(6)		*
*							*
********************************************************/
static void DoREAD6(const uint8 *cdb)
{
 uint32 sa = ((cdb[1] & 0x1F) << 16) | (cdb[2] << 8) | (cdb[3] << 0);
 uint32 sc = cdb[4];

 // TODO: confirm real PCE does this(PC-FX does at least).
 if(!sc)
 {
  //SCSIDBG("READ(6) with count == 0.\n");
  sc = 256;
 }

 DoREADBase(sa, sc);
}

/********************************************************
*							*
*	PC Engine CD Command 0xD8 - SAPSP		*
*							*
********************************************************/
static void DoNEC_PCE_SAPSP(const uint8 *cdb)
{
 uint32 new_read_sec_start;

 //printf("Set audio start: %02x %02x %02x %02x %02x %02x %02x\n", cdb[9], cdb[1], cdb[2], cdb[3], cdb[4], cdb[5], cdb[6]);
 switch (cdb[9] & 0xc0)
 {
  default:  //SCSIDBG("Unknown SAPSP 9: %02x\n", cdb[9]);
  case 0x00:
   new_read_sec_start = (cdb[3] << 16) | (cdb[4] << 8) | cdb[5];
   break;

  case 0x40:
   new_read_sec_start = AMSF_to_LBA(BCD_to_U8(cdb[2]), BCD_to_U8(cdb[3]), BCD_to_U8(cdb[4]));
   break;

  case 0x80:
   {
    int track = BCD_to_U8(cdb[2]);

    if(!track)
     track = 1;
    else if(track >= toc.last_track + 1)
     track = 100;
    new_read_sec_start = toc.tracks[track].lba;
   }
   break;
 }

 //printf("%lld\n", (long long)(monotonic_timestamp - pce_lastsapsp_timestamp) * 1000 / System_Clock);
 if(cdda.CDDAStatus == CDDASTATUS_PLAYING && new_read_sec_start == read_sec_start && ((int64)(monotonic_timestamp - pce_lastsapsp_timestamp) * 1000 / System_Clock) < 190)
 {
  pce_lastsapsp_timestamp = monotonic_timestamp;

  SendStatusAndMessage(STATUS_GOOD, 0x00);
  CDIRQCallback(PCECD_Drive_IRQ_DATA_TRANSFER_DONE);
  return;
 }

 pce_lastsapsp_timestamp = monotonic_timestamp;

 read_sec = read_sec_start = new_read_sec_start;
 read_sec_end = toc.tracks[100].lba;


 cdda.CDDAReadPos = 588;

 cdda.CDDAStatus = CDDASTATUS_PAUSED;
 cdda.PlayMode = PLAYMODE_SILENT;

 if(cdb[1])
 {
  cdda.PlayMode = PLAYMODE_NORMAL;
  cdda.CDDAStatus = CDDASTATUS_PLAYING;
 }

 if(read_sec < toc.tracks[100].lba)
  Cur_CDIF->HintReadSector(read_sec);

 SendStatusAndMessage(STATUS_GOOD, 0x00);
 CDIRQCallback(PCECD_Drive_IRQ_DATA_TRANSFER_DONE);
}



/********************************************************
*							*
*	PC Engine CD Command 0xD9 - SAPEP		*
*							*
********************************************************/
static void DoNEC_PCE_SAPEP(const uint8 *cdb)
{
 uint32 new_read_sec_end;

 //printf("Set audio end: %02x %02x %02x %02x %02x %02x %02x\n", cdb[9], cdb[1], cdb[2], cdb[3], cdb[4], cdb[5], cdb[6]);

 switch (cdb[9] & 0xc0)
 {
  default: //SCSIDBG("Unknown SAPEP 9: %02x\n", cdb[9]);

  case 0x00:
   new_read_sec_end = (cdb[3] << 16) | (cdb[4] << 8) | cdb[5];
   break;

  case 0x40:
   new_read_sec_end = BCD_to_U8(cdb[4]) + 75 * (BCD_to_U8(cdb[3]) + 60 * BCD_to_U8(cdb[2]));
   new_read_sec_end -= 150;
   break;

  case 0x80:
   {
    int track = BCD_to_U8(cdb[2]);

    if(!track)
     track = 1;
    else if(track >= toc.last_track + 1)
     track = 100;
    new_read_sec_end = toc.tracks[track].lba;
   }
   break;
 }

 read_sec_end = new_read_sec_end;

 switch(cdb[1])	// PCE CD(TODO: Confirm these, and check the mode mask):
 {
	default:
	case 0x03: cdda.PlayMode = PLAYMODE_NORMAL;
		   cdda.CDDAStatus = CDDASTATUS_PLAYING;
		   break;

	case 0x02: cdda.PlayMode = PLAYMODE_INTERRUPT;
		   cdda.CDDAStatus = CDDASTATUS_PLAYING;
		   break;

	case 0x01: cdda.PlayMode = PLAYMODE_LOOP;
		   cdda.CDDAStatus = CDDASTATUS_PLAYING;
		   break;

	case 0x00: cdda.PlayMode = PLAYMODE_SILENT;
		   cdda.CDDAStatus = CDDASTATUS_STOPPED;
		   break;
 }

 SendStatusAndMessage(STATUS_GOOD, 0x00);
}



/********************************************************
*							*
*	PC Engine CD Command 0xDA - Pause		*
*							*
********************************************************/
static void DoNEC_PCE_PAUSE(const uint8 *cdb)
{
 if(cdda.CDDAStatus != CDDASTATUS_STOPPED) // Hmm, should we give an error if it tries to pause and it's already paused?
 {
  cdda.CDDAStatus = CDDASTATUS_PAUSED;
  SendStatusAndMessage(STATUS_GOOD, 0x00);
 }
 else // Definitely give an error if it tries to pause when no track is playing!
 {
  CommandCCError(SENSEKEY_ILLEGAL_REQUEST, NSE_AUDIO_NOT_PLAYING);
 }
}



/********************************************************
*							*
*	PC Engine CD Command 0xDD - Read Subchannel Q	*
*							*
********************************************************/
static void DoNEC_PCE_READSUBQ(const uint8 *cdb)
{
 uint8 *SubQBuf = cd.SubQBuf[QMode_Time];
 uint8 data_in[8192];

 memset(data_in, 0x00, 10);

 data_in[2] = SubQBuf[1];     // Track
 data_in[3] = SubQBuf[2];     // Index
 data_in[4] = SubQBuf[3];     // M(rel)
 data_in[5] = SubQBuf[4];     // S(rel)
 data_in[6] = SubQBuf[5];     // F(rel)
 data_in[7] = SubQBuf[7];     // M(abs)
 data_in[8] = SubQBuf[8];     // S(abs)
 data_in[9] = SubQBuf[9];     // F(abs)

 if(cdda.CDDAStatus == CDDASTATUS_PAUSED)
  data_in[0] = 2;		// Pause
 else if(cdda.CDDAStatus == CDDASTATUS_PLAYING)
  data_in[0] = 0;		// Playing
 else
  data_in[0] = 3;		// Stopped

 DoSimpleDataIn(data_in, 10);
}



/********************************************************
*							*
*	PC Engine CD Command 0xDE - Get Directory Info	*
*							*
********************************************************/
static void DoNEC_PCE_GETDIRINFO(const uint8 *cdb)
{
 // Problems:
 //	Returned data lengths on real PCE are not confirmed.
 //	Mode 0x03 behavior not tested on real PCE

 uint8 data_in[2048];
 uint32 data_in_size = 0;

 memset(data_in, 0, sizeof(data_in));

 switch(cdb[1])
 {
  default: //MDFN_DispMessage("Unknown GETDIRINFO Mode: %02x", cdb[1]);
	   //printf("Unknown GETDIRINFO Mode: %02x", cdb[1]);
  case 0x0:
   data_in[0] = U8_to_BCD(toc.first_track);
   data_in[1] = U8_to_BCD(toc.last_track);

   data_in_size = 2;
   break;

  case 0x1:
   {
    uint8 m, s, f;

    LBA_to_AMSF(toc.tracks[100].lba, &m, &s, &f);

    data_in[0] = U8_to_BCD(m);
    data_in[1] = U8_to_BCD(s);
    data_in[2] = U8_to_BCD(f);

    data_in_size = 3;
   }
   break;

  case 0x2:
   {
    uint8 m, s, f;
    int track = BCD_to_U8(cdb[2]);

    if(!track)
     track = 1;
    else if(cdb[2] == 0xAA)
    {
     track = 100;
    }
    else if(track > 99)
    {
     CommandCCError(SENSEKEY_ILLEGAL_REQUEST, NSE_INVALID_PARAMETER);
     return;
    }

    LBA_to_AMSF(toc.tracks[track].lba, &m, &s, &f);

    data_in[0] = U8_to_BCD(m);
    data_in[1] = U8_to_BCD(s);
    data_in[2] = U8_to_BCD(f);
    data_in[3] = toc.tracks[track].control;
    data_in_size = 4;
   }
   break;
 }

 DoSimpleDataIn(data_in, data_in_size);
}

#define SCF_REQUIRES_MEDIUM	0x01

typedef struct
{
 uint8 cmd;
 uint8 flags;
 void (*func)(const uint8 *cdb);
 const char *pretty_name;
 const char *format_string;
} SCSICH;

static const uint8 RequiredCDBLen[16] =
{
 6, // 0x0n
 6, // 0x1n
 10, // 0x2n
 10, // 0x3n
 10, // 0x4n
 10, // 0x5n
 10, // 0x6n
 10, // 0x7n
 10, // 0x8n
 10, // 0x9n
 12, // 0xAn
 12, // 0xBn
 10, // 0xCn
 10, // 0xDn
 10, // 0xEn
 10, // 0xFn
};

static SCSICH PCECommandDefs[] = 
{
 { 0x00, SCF_REQUIRES_MEDIUM, DoTESTUNITREADY, "Test Unit Ready" },
 { 0x03, 0, DoREQUESTSENSE, "Request Sense" },
 { 0x08, SCF_REQUIRES_MEDIUM, DoREAD6, "Read(6)" },

 { 0xD8, SCF_REQUIRES_MEDIUM, DoNEC_PCE_SAPSP, "Set Audio Playback Start Position" },
 { 0xD9, SCF_REQUIRES_MEDIUM, DoNEC_PCE_SAPEP, "Set Audio Playback End Position" },
 { 0xDA, SCF_REQUIRES_MEDIUM, DoNEC_PCE_PAUSE, "Pause" },
 { 0xDD, SCF_REQUIRES_MEDIUM, DoNEC_PCE_READSUBQ, "Read Subchannel Q" },
 { 0xDE, SCF_REQUIRES_MEDIUM, DoNEC_PCE_GETDIRINFO, "Get Dir Info" },

 { 0xFF, 0, 0, NULL, NULL },
};

void PCECD_Drive_ResetTS(void)
{
 lastts = 0;
}

void PCECD_Drive_GetCDDAValues(int16 &left, int16 &right)
{
 if(cdda.CDDAStatus)
 {
  left = cdda.CDDASectorBuffer[cdda.CDDAReadPos * 2];
  right = cdda.CDDASectorBuffer[cdda.CDDAReadPos * 2 + 1];
 }
 else
  left = right = 0;
}

static INLINE void RunCDDA(uint32 system_timestamp, int32 run_time)
{
 if(cdda.CDDAStatus == CDDASTATUS_PLAYING)
 {
  int32 sample[2];

  cdda.CDDADiv -= run_time << 16;

  while(cdda.CDDADiv <= 0)
  {
   const uint32 synthtime = ((system_timestamp + (cdda.CDDADiv >> 16))) / cdda.CDDATimeDiv;

   cdda.CDDADiv += cdda.CDDADivAcc;

   //MDFN_DispMessage("%d %d %d\n", read_sec_start, read_sec, read_sec_end);

   if(cdda.CDDAReadPos == 588)
   {
    if(read_sec >= read_sec_end)
    {
     switch(cdda.PlayMode)
     {
      case PLAYMODE_SILENT:
      case PLAYMODE_NORMAL:
       cdda.CDDAStatus = CDDASTATUS_STOPPED;
       break;

      case PLAYMODE_INTERRUPT:
       cdda.CDDAStatus = CDDASTATUS_STOPPED;
       CDIRQCallback(PCECD_Drive_IRQ_DATA_TRANSFER_DONE);
       break;

      case PLAYMODE_LOOP:
       read_sec = read_sec_start;
       break;
     }

     // If CDDA playback is stopped, break out of our while(CDDADiv ...) loop and don't play any more sound!
     if(cdda.CDDAStatus == CDDASTATUS_STOPPED)
      break;
    }

    // Don't play past the user area of the disc.
    if(read_sec >= toc.tracks[100].lba)
    {
     cdda.CDDAStatus = CDDASTATUS_STOPPED;
     break;
    }

    if(TrayOpen || !Cur_CDIF)
    {
     cdda.CDDAStatus = CDDASTATUS_STOPPED;

     #if 0
     cd.data_transfer_done = FALSE;
     cd.key_pending = SENSEKEY_NOT_READY;
     cd.asc_pending = ASC_MEDIUM_NOT_PRESENT;
     cd.ascq_pending = 0x00;
     cd.fru_pending = 0x00;
     SendStatusAndMessage(STATUS_CHECK_CONDITION, 0x00);
     #endif

     break;
    }


    cdda.CDDAReadPos = 0;

    {
     uint8 tmpbuf[2352 + 96];

     Cur_CDIF->ReadRawSector(tmpbuf, read_sec);	//, read_sec_end, read_sec_start);

     for(int i = 0; i < 588 * 2; i++)
      cdda.CDDASectorBuffer[i] = MDFN_de16lsb(&tmpbuf[i * 2]);

     memcpy(cd.SubPWBuf, tmpbuf + 2352, 96);
    }
    GenSubQFromSubPW();
    read_sec++;
   } // End    if(CDDAReadPos == 588)

   // If the last valid sub-Q data decoded indicate that the corresponding sector is a data sector, don't output the
   // current sector as audio.
   sample[0] = sample[1] = 0;

   if(!(cd.SubQBuf_Last[0] & 0x40) && cdda.PlayMode != PLAYMODE_SILENT)
   {
    sample[0] = (cdda.CDDASectorBuffer[cdda.CDDAReadPos * 2 + 0] * cdda.CDDAVolume) >> 16;
    sample[1] = (cdda.CDDASectorBuffer[cdda.CDDAReadPos * 2 + 1] * cdda.CDDAVolume) >> 16;
   }

   if(!(cdda.CDDAReadPos % 6))
   {
    int subindex = cdda.CDDAReadPos / 6 - 2;

    if(subindex >= 0)
     CDStuffSubchannels(cd.SubPWBuf[subindex], subindex);
    else // The system-specific emulation code should handle what value the sync bytes are.
     CDStuffSubchannels(0x00, subindex);
   }

   if(sbuf)
   {
    cdda.CDDASynth.offset_inline(synthtime, sample[0] - cdda.last_sample[0], &sbuf[0]);
    cdda.CDDASynth.offset_inline(synthtime, sample[1] - cdda.last_sample[1], &sbuf[1]);
   }

   cdda.last_sample[0] = sample[0];
   cdda.last_sample[1] = sample[1];

   cdda.CDDAReadPos++;
  }
 }
}

static INLINE void RunCDRead(uint32 system_timestamp, int32 run_time)
{
 if(CDReadTimer > 0)
 {
  CDReadTimer -= run_time;

  if(CDReadTimer <= 0)
  {
   if(din.CanWrite() < 2048)
   {
    //printf("Carp: %d %d %d\n", din.CanWrite(), SectorCount, CDReadTimer);
    //CDReadTimer = (cd.data_in_size - cd.data_in_pos) * 10;
    
    CDReadTimer += (uint64) 1 * 2048 * System_Clock / CD_DATA_TRANSFER_RATE;

    //CDReadTimer += (uint64) 1 * 128 * System_Clock / CD_DATA_TRANSFER_RATE;
   }
   else
   {
    uint8 tmp_read_buf[2352 + 96];

    if(TrayOpen)
    {
     din.Flush();
     cd.data_transfer_done = FALSE;

     CommandCCError(SENSEKEY_NOT_READY, NSE_TRAY_OPEN);
    }
    else if(!Cur_CDIF)
    {
     CommandCCError(SENSEKEY_NOT_READY, NSE_NO_DISC);
    }
    else if(SectorAddr >= toc.tracks[100].lba)
    {
     CommandCCError(SENSEKEY_ILLEGAL_REQUEST, NSE_END_OF_VOLUME);
    }
    else if(!Cur_CDIF->ReadRawSector(tmp_read_buf, SectorAddr))	//, SectorAddr + SectorCount))
    {
     cd.data_transfer_done = FALSE;

     CommandCCError(SENSEKEY_ILLEGAL_REQUEST);
    }
    else if(ValidateRawDataSector(tmp_read_buf, SectorAddr))
    {
     memcpy(cd.SubPWBuf, tmp_read_buf + 2352, 96);

     if(tmp_read_buf[12 + 3] == 0x2)
      din.Write(tmp_read_buf + 24, 2048);
     else
      din.Write(tmp_read_buf + 16, 2048);

     GenSubQFromSubPW();

     CDIRQCallback(PCECD_Drive_IRQ_DATA_TRANSFER_READY);

     SectorAddr++;
     SectorCount--;

     if(CurrentPhase != PHASE_DATA_IN)
      ChangePhase(PHASE_DATA_IN);

     if(SectorCount)
     {
      cd.data_transfer_done = FALSE;
      CDReadTimer += (uint64) 1 * 2048 * System_Clock / CD_DATA_TRANSFER_RATE;
     }
     else
     {
      cd.data_transfer_done = TRUE;
     }
    }
   }				// end else to if(!Cur_CDIF->ReadSector

  }
 }
}


uint32 PCECD_Drive_Run(pcecd_drive_timestamp_t system_timestamp)
{
 int32 run_time = system_timestamp - lastts;

 if(system_timestamp < lastts)
 {
  fprintf(stderr, "Meow: %d %d\n", system_timestamp, lastts);
  assert(system_timestamp >= lastts);
 }

 monotonic_timestamp += run_time;

 lastts = system_timestamp;

 RunCDRead(system_timestamp, run_time);
 RunCDDA(system_timestamp, run_time);

 bool ResetNeeded = false;

 if(RST_signal && !cd.last_RST_signal)
  ResetNeeded = true;

 cd.last_RST_signal = RST_signal;

 if(ResetNeeded)
 {
  //puts("RST");
  VirtualReset();
 }
 else switch(CurrentPhase)
 {
  case PHASE_BUS_FREE:
    if(SEL_signal)
    {
     ChangePhase(PHASE_COMMAND);
    }
    break;

  case PHASE_COMMAND:
    if(REQ_signal && ACK_signal)	// Data bus is valid nowww
    {
     //printf("Command Phase Byte I->T: %02x, %d\n", cd_bus.DB, cd.command_buffer_pos);
     cd.command_buffer[cd.command_buffer_pos++] = cd_bus.DB;
     SetREQ(FALSE);
    }

    if(!REQ_signal && !ACK_signal && cd.command_buffer_pos)	// Received at least one byte, what should we do?
    {
     if(cd.command_buffer_pos == RequiredCDBLen[cd.command_buffer[0] >> 4])
     {
      const SCSICH* cmd_info_ptr = PCECommandDefs;

      while(cmd_info_ptr->pretty_name && cmd_info_ptr->cmd != cd.command_buffer[0])
       cmd_info_ptr++;
  
      if(cmd_info_ptr->pretty_name == NULL)	// Command not found!
      {
       CommandCCError(SENSEKEY_ILLEGAL_REQUEST, NSE_INVALID_COMMAND);

       //SCSIDBG("Bad Command: %02x\n", cd.command_buffer[0]);

       cd.command_buffer_pos = 0;
      }
      else
      {
       if(TrayOpen && (cmd_info_ptr->flags & SCF_REQUIRES_MEDIUM))
       {
	CommandCCError(SENSEKEY_NOT_READY, NSE_TRAY_OPEN);
       }
       else if(!Cur_CDIF && (cmd_info_ptr->flags & SCF_REQUIRES_MEDIUM))
       {
	CommandCCError(SENSEKEY_NOT_READY, NSE_NO_DISC);
       }
       else if(cd.DiscChanged && (cmd_info_ptr->flags & SCF_REQUIRES_MEDIUM))
       {
	CommandCCError(SENSEKEY_UNIT_ATTENTION, NSE_DISC_CHANGED);
	cd.DiscChanged = false;
       }
       else
       {
        cmd_info_ptr->func(cd.command_buffer);
       }

       cd.command_buffer_pos = 0;
      }
     } // end if(cd.command_buffer_pos == RequiredCDBLen[cd.command_buffer[0] >> 4])
     else			// Otherwise, get more data for the command!
      SetREQ(TRUE);
    }
    break;

  case PHASE_STATUS:
    if(REQ_signal && ACK_signal)
    {
     SetREQ(FALSE);
     cd.status_sent = TRUE;
    }

    if(!REQ_signal && !ACK_signal && cd.status_sent)
    {
     // Status sent, so get ready to send the message!
     cd.status_sent = FALSE;
     cd_bus.DB = cd.message_pending;

     ChangePhase(PHASE_MESSAGE_IN);
    }
    break;

  case PHASE_DATA_IN:
    if(!REQ_signal && !ACK_signal)
    {
     //puts("REQ and ACK false");
     if(din.CanRead() == 0)	// aaand we're done!
     {
      CDIRQCallback(0x8000 | PCECD_Drive_IRQ_DATA_TRANSFER_READY);

      if(cd.data_transfer_done)
      {
       SendStatusAndMessage(STATUS_GOOD, 0x00);
       cd.data_transfer_done = FALSE;
       CDIRQCallback(PCECD_Drive_IRQ_DATA_TRANSFER_DONE);
      }
     }
     else
     {
      cd_bus.DB = din.ReadByte();
      SetREQ(TRUE);
     }
    }
    if(REQ_signal && ACK_signal)
    {
     //puts("REQ and ACK true");
     SetREQ(FALSE);
    }
    break;

  case PHASE_MESSAGE_IN:
   if(REQ_signal && ACK_signal)
   {
    SetREQ(FALSE);
    cd.message_sent = TRUE;
   }

   if(!REQ_signal && !ACK_signal && cd.message_sent)
   {
    cd.message_sent = FALSE;
    ChangePhase(PHASE_BUS_FREE);
   }
   break;
 }

 int32 next_time = 0x7fffffff;

 if(CDReadTimer > 0 && CDReadTimer < next_time)
  next_time = CDReadTimer;

 if(cdda.CDDAStatus == CDDASTATUS_PLAYING)
 {
  int32 cdda_div_sexytime = (cdda.CDDADiv + 0xFFFF) >> 16;
  if(cdda_div_sexytime > 0 && cdda_div_sexytime < next_time)
   next_time = cdda_div_sexytime;
 }

 assert(next_time >= 0);

 return(next_time);
}

void PCECD_Drive_SetTransferRate(uint32 TransferRate)
{
 CD_DATA_TRANSFER_RATE = TransferRate;
}

void PCECD_Drive_Close(void)
{

}

void PCECD_Drive_Init(int cdda_time_div, Blip_Buffer* lrbufs, uint32 TransferRate, uint32 SystemClock, void (*IRQFunc)(int), void (*SSCFunc)(uint8, int))
{
 Cur_CDIF = NULL;
 TrayOpen = true;

 monotonic_timestamp = 0;
 lastts = 0;

 //din = new SimpleFIFO<uint8>(2048);

 cdda.CDDATimeDiv = cdda_time_div;

 cdda.CDDAVolume = 65536;
 cdda.CDDASynth.volume(1.0f / 65536);
 cdda.CDDASynth.treble_eq(0);
 sbuf = lrbufs;

 CD_DATA_TRANSFER_RATE = TransferRate;
 System_Clock = SystemClock;
 CDIRQCallback = IRQFunc;
 CDStuffSubchannels = SSCFunc;
}

void PCECD_Drive_SetCDDAVolume(unsigned vol)
{
 cdda.CDDAVolume = vol;
}

int PCECD_Drive_StateAction(StateMem * sm, int load, int data_only, const char *sname)
{
 SFORMAT StateRegs[] = 
 {
  SFVARN(cd_bus.DB, "DB"),
  SFVARN(cd_bus.signals, "Signals"),
  SFVAR(CurrentPhase),

  SFVARN(cd.last_RST_signal, "last_RST"),
  SFVARN(cd.message_pending, "message_pending"),
  SFVARN(cd.status_sent, "status_sent"),
  SFVARN(cd.message_sent, "message_sent"),
  SFVARN(cd.key_pending, "key_pending"),
  SFVARN(cd.asc_pending, "asc_pending"),
  SFVARN(cd.ascq_pending, "ascq_pending"),
  SFVARN(cd.fru_pending, "fru_pending"),

  SFARRAYN(cd.command_buffer, 256, "command_buffer"),
  SFVARN(cd.command_buffer_pos, "command_buffer_pos"),
  SFVARN(cd.command_size_left, "command_size_left"),

  // Don't save the FIFO's write position, it will be reconstructed from read_pos and in_count
  SFARRAYN(&din.data[0], din.data.size(), "din_fifo"),
  SFVARN(din.read_pos, "din_read_pos"),
  SFVARN(din.in_count, "din_in_count"),
  SFVARN(cd.data_transfer_done, "data_transfer_done"),

  SFVARN(cd.DiscChanged, "DiscChanged"),

  SFVAR(cdda.PlayMode),
  SFARRAY16(cdda.CDDASectorBuffer, 1176),
  SFVAR(cdda.CDDAReadPos),
  SFVAR(cdda.CDDAStatus),
  SFVAR(cdda.CDDADiv),
  SFVAR(read_sec_start),
  SFVAR(read_sec),
  SFVAR(read_sec_end),

  SFVAR(CDReadTimer),
  SFVAR(SectorAddr),
  SFVAR(SectorCount),

  SFVAR(cdda.ScanMode),
  SFVAR(cdda.scan_sec_end),

  SFARRAYN(&cd.SubQBuf[0][0], sizeof(cd.SubQBuf), "SubQBufs"),
  SFARRAYN(cd.SubQBuf_Last, sizeof(cd.SubQBuf_Last), "SubQBufLast"),
  SFARRAYN(cd.SubPWBuf, sizeof(cd.SubPWBuf), "SubPWBuf"),

  SFVAR(monotonic_timestamp),
  SFVAR(pce_lastsapsp_timestamp),

  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(load)
 {
  din.in_count &= din.size - 1;
  din.read_pos &= din.size - 1;
  din.write_pos = (din.read_pos + din.in_count) & (din.size - 1);

  if(cdda.CDDADiv <= 0)
   cdda.CDDADiv = 1;
  //printf("%d %d %d\n", din.in_count, din.read_pos, din.write_pos);
 }

 return (ret);
}

}
