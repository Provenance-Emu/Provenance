#ifndef __MDFN_PSX_CDC_H
#define __MDFN_PSX_CDC_H

#include <mednafen/cdrom/cdromif.h>
#include <mednafen/cdrom/SimpleFIFO.h>

namespace MDFN_IEN_PSX
{

struct CD_Audio_Buffer
{
 int16 Samples[2][0x1000];	// [0][...] = l, [1][...] = r
 int32 Size;
 uint32 Freq;
 int32 ReadPos;
};

class PS_CDC
{
 public:

 PS_CDC();
 ~PS_CDC();

 void SetDisc(bool tray_open, CDIF *cdif, const char disc_id[4]);

 void Power(void);
 void StateAction(StateMem *sm, const unsigned load, const bool data_only);
 void ResetTS(void);

 int32 CalcNextEvent(void);	// Returns in master cycles to next event.

 pscpu_timestamp_t Update(const pscpu_timestamp_t timestamp);

 void Write(const pscpu_timestamp_t timestamp, uint32 A, uint8 V);
 uint8 Read(const pscpu_timestamp_t timestamp, uint32 A);

 bool DMACanRead(void);
 uint32 DMARead(void);
 void SoftReset(void);

 void GetCDAudio(int32 samples[2]);

 private:
 CDIF *Cur_CDIF;
 bool DiscChanged;
 int32 DiscStartupDelay;

 CD_Audio_Buffer AudioBuffer;

 uint8 Pending_DecodeVolume[2][2], DecodeVolume[2][2];		// [data_source][output_port]

 int16 ADPCM_ResampBuf[2][32 * 2];
 uint8 ADPCM_ResampCurPos;
 uint8 ADPCM_ResampCurPhase;

 void ApplyVolume(int32 samples[2]);
 void ReadAudioBuffer(int32 samples[2]);

 void ClearAudioBuffers(void);


 //
 //
 //


 uint8 RegSelector;
 uint8 ArgsBuf[16];
 uint8 ArgsWP;		// 5-bit(0 ... 31)
 uint8 ArgsRP;		// 5-bit(0 ... 31)

 uint8 ArgsReceiveLatch;
 uint8 ArgsReceiveBuf[32];
 uint8 ArgsReceiveIn;

 uint8 ResultsBuffer[16];
 uint8 ResultsIn;	// 5-bit(0 ... 31)
 uint8 ResultsWP;	// Write position, 4 bit(0 ... 15).
 uint8 ResultsRP;	// Read position, 4 bit(0 ... 15).

 SimpleFIFO<uint8> DMABuffer;
 uint8 SB[2340];
 uint32 SB_In;

 enum { SectorPipe_Count = 2 };
 uint8 SectorPipe[SectorPipe_Count][2352];
 uint8 SectorPipe_Pos;
 uint8 SectorPipe_In;

 uint8 SubQBuf[0xC];
 uint8 SubQBuf_Safe[0xC];
 bool SubQChecksumOK;

 bool HeaderBufValid;
 uint8 HeaderBuf[12];

 void RecalcIRQ(void);
 enum
 {
  CDCIRQ_NONE = 0,
  CDCIRQ_DATA_READY = 1,
  CDCIRQ_COMPLETE = 2,
  CDCIRQ_ACKNOWLEDGE = 3,
  CDCIRQ_DATA_END = 4,
  CDCIRQ_DISC_ERROR = 5
 };

 // Names are just guessed for these based on what conditions cause them:
 enum
 {
  ERRCODE_BAD_ARGVAL  = 0x10,
  ERRCODE_BAD_NUMARGS = 0x20,
  ERRCODE_BAD_COMMAND = 0x40,
  ERRCODE_NOT_READY = 0x80,	// 0x80 (happens with getlocl when drive isn't reading, pause when tray is open, and MAYBE when trying to run an async
				//	 command while another async command is currently in its asynch phase being executed[pause when in readtoc, todo test more])
 };

 uint8 IRQBuffer;
 uint8 IRQOutTestMask;
 int32 CDCReadyReceiveCounter;	// IRQBuffer being non-zero prevents new results and new IRQ from coming in and erasing the current results,
				// but apparently at least one CONFOUNDED game is clearing the IRQ state BEFORE reading the results, so we need to have a delay
				// between IRQBuffer being cleared to when we allow new results to come in.  (The real thing should be like this too,
				// but the mechanism is probably more nuanced and complex and ugly and I like anchovy pizza)

 void BeginResults(void);
 void WriteIRQ(uint8);
 void WriteResult(uint8);
 uint8 ReadResult(void);

 uint8 FilterFile;
 uint8 FilterChan;


 uint8 PendingCommand;
 int PendingCommandPhase;
 int32 PendingCommandCounter;

 int32 SPUCounter;

 enum { MODE_SPEED = 0x80 };
 enum { MODE_STRSND = 0x40 };
 enum { MODE_SIZE = 0x20 };
 enum { MODE_SIZE2 = 0x10 };
 enum { MODE_SF = 0x08 };
 enum { MODE_REPORT = 0x04 };
 enum { MODE_AUTOPAUSE = 0x02 };
 enum { MODE_CDDA = 0x01 };
 uint8 Mode;

 enum
 {
  DS_STANDBY = -2,
  DS_PAUSED = -1,
  DS_STOPPED = 0,
  DS_SEEKING,
  DS_SEEKING_LOGICAL,
  DS_PLAY_SEEKING,
  DS_PLAYING,
  DS_READING,
  DS_RESETTING
 };
 int DriveStatus;
 int StatusAfterSeek;
 bool Forward;
 bool Backward;
 bool Muted;

 int32 PlayTrackMatch;

 int32 PSRCounter;

 int32 CurSector;
 uint32 SectorsRead;	// Reset to 0 on Read*/Play command start; used in the rough simulation of PS1 SetLoc->Read->Pause->Read behavior.

 unsigned AsyncIRQPending;
 uint8 AsyncResultsPending[16];
 uint8 AsyncResultsPendingCount;

 int32 CalcSeekTime(int32 initial, int32 target, bool motor_on, bool paused);

 void ClearAIP(void);
 void CheckAIP(void);
 void SetAIP(unsigned irq, unsigned result_count, uint8 *r);
 void SetAIP(unsigned irq, uint8 result0);
 void SetAIP(unsigned irq, uint8 result0, uint8 result1);

 int32 SeekTarget;
 uint32 SeekRetryCounter;

 pscpu_timestamp_t lastts;

 CDUtility::TOC toc;
 bool IsPSXDisc;
 uint8 DiscID[4];

 int32 CommandLoc;
 bool CommandLoc_Dirty;

 uint8 MakeStatus(bool cmd_error = false);
 bool DecodeSubQ(uint8 *subpw);
 bool CommandCheckDiscPresent(void);
 void DMForceStop();

 void EnbufferizeCDDASector(const uint8 *buf);
 bool XA_Test(const uint8 *sdata);
 void XA_ProcessSector(const uint8 *sdata, CD_Audio_Buffer *ab);
 int16 xa_previous[2][2];
 bool xa_cur_set;
 uint8 xa_cur_file;
 uint8 xa_cur_chan;

 uint8 ReportLastF;

 void HandlePlayRead(void);

 struct CDC_CTEntry
 {
  uint8 args_min;
  uint8 args_max;
  const char *name;
  int32 (PS_CDC::*func)(const int arg_count, const uint8 *args);
  int32 (PS_CDC::*func2)(void);
 };

 void PreSeekHack(int32 target);
 void ReadBase(void);

 static CDC_CTEntry Commands[0x20];

 int32 Command_Nop(const int arg_count, const uint8 *args);
 int32 Command_Setloc(const int arg_count, const uint8 *args);
 int32 Command_Play(const int arg_count, const uint8 *args);
 int32 Command_Forward(const int arg_count, const uint8 *args);
 int32 Command_Backward(const int arg_count, const uint8 *args);
 int32 Command_ReadN(const int arg_count, const uint8 *args);
 int32 Command_Standby(const int arg_count, const uint8 *args);
 int32 Command_Standby_Part2(void);
 int32 Command_Stop(const int arg_count, const uint8 *args);
 int32 Command_Stop_Part2(void); 
 int32 Command_Pause(const int arg_count, const uint8 *args);
 int32 Command_Pause_Part2(void);
 int32 Command_Reset(const int arg_count, const uint8 *args);
 int32 Command_Mute(const int arg_count, const uint8 *args);
 int32 Command_Demute(const int arg_count, const uint8 *args);
 int32 Command_Setfilter(const int arg_count, const uint8 *args);
 int32 Command_Setmode(const int arg_count, const uint8 *args);
 int32 Command_Getparam(const int arg_count, const uint8 *args);
 int32 Command_GetlocL(const int arg_count, const uint8 *args);
 int32 Command_GetlocP(const int arg_count, const uint8 *args);

 int32 Command_ReadT(const int arg_count, const uint8 *args);
 int32 Command_ReadT_Part2(void);

 int32 Command_GetTN(const int arg_count, const uint8 *args);
 int32 Command_GetTD(const int arg_count, const uint8 *args);
 int32 Command_SeekL(const int arg_count, const uint8 *args);
 int32 Command_SeekP(const int arg_count, const uint8 *args);
 int32 Command_Seek_PartN(void);

 int32 Command_Test(const int arg_count, const uint8 *args);

 int32 Command_ID(const int arg_count, const uint8 *args);
 int32 Command_ID_Part2(void);

 int32 Command_ReadS(const int arg_count, const uint8 *args);
 int32 Command_Init(const int arg_count, const uint8 *args);

 int32 Command_ReadTOC(const int arg_count, const uint8 *args);
 int32 Command_ReadTOC_Part2(void);

 int32 Command_0x1d(const int arg_count, const uint8 *args);
};

}

#endif
