/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2004 Ki
 *  Copyright (C) 2007-2011 Mednafen Team
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
/*
 Stuff to test:
	ADPCM playback rate relative to main PC Engine master clock rate.  (Might vary significantly from system-to-system
	due to imperfections in the separate clocks)

	Figure out how the ADPCM DMA control bits work.

	Determine real fade timings.

	Determine what D0 of the fade control register does(maybe mutes the channel not being fad-controlled if it's set?).

	Determine what D7 of the fade control register does("TEST"), assuming it even exists on the production model PCE CD.

	Handle D2 of register at 0x1804 better.  Determine what the other bits of 0x1804 are for.

	Determine what registers and bits setting D7 of $180D causes to reset.

	Test behavior of D0-D3 of $180D on a real system(already tested D4).  (Does setting the read address
	cause a new byte to be loaded into the read buffer?)

	Test ADPCM write performance at all frequencies when playback is occurring.

	OTHER STUFF.
*/

/*
 Notes:
	Reading from $180A decrements length.  Appears to saturate at 0x0000.
		Side effects include at least: half/end IRQ bit setting.  Oddly enough, when the end flags are set via read from $180A, the intermediate
		flag appears to be cleared.  This wouldn't appear to occur in normal ADPCM playback, ie both end and intermediate flags are 1 by the end
		of playback(though if D6 of $180D is cleared, the intermediate flag is apparently cleared on the next sample clock, either intentionally or due to
		some kind of length underflow I don't know; but the mode of operation of having D6 cleared is buggy, and I doubt games rely on any of its
		weirder nuances).

	Writing to $180A increments length.  Appears to saturate at 0xFFFF.
		Side effects include at least: half IRQ bit setting/clearing.

	For $180A port read/write accesses at least, half_point = (bool)(length < 32768), evaluated before length is decremented or incremented.

	ADPCM RAM reads due to playback apparently aren't reflected in $180A as ADPCM read busy state.  Unknown if it shares the same
	buffer as $180A port reads though.

	Having D4 of $180D set clears the end flags(and they will not be set as long as D4 is set).  It doesn't clear the intermediate/half flag though.
	Short of resetting the ADPCM hardware by setting D7 of $180D, this was the only way I could find to clear the end flags via software.

	Having D4 of $180D set does NOT prevent the half flag from being set(at least not during reads/writes to $180A).

	ADPCM playback doesn't seem to start if the end flags are set and 0x60 is written to $180D, but starts(at least as can be determined from a program
	monitoring the status bits) if 0x20 is written(IE D6 is clear).  More investigation is needed(unlikely to affect games though).

	ADPCM playback starting is likely delayed(or at certain intervals) compared to writes to $180D.  Investigation is needed, but emulating a non-constant
	granularity-related delay may be undesirable due to the potential of triggering race conditions in game code.

	I say "end flags", but I'm assuming there's effectively one end flag, that's present in both $1803 and $180C reads(though in different positions).
*/

/*
	Design notes:
		For a given timestamp, any calls to SCSICD_Run() called from above PCECD_Run() must be preceded by a call to PCECD_Run() or else
		timekeeping variables will get out of sync and everything will go boom.
*/

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/cdrom/scsicd.h>
#include <mednafen/sound/okiadpcm.h>
#include <mednafen/cdrom/SimpleFIFO.h>

#include "pcecd.h"

namespace MDFN_IEN_PCE
{

//#define PCECD_DEBUG

static void (*IRQCB)(bool asserted);

// Settings:
static double CDDABaseVolume;
static double ADPCMBaseVolume;
static bool ADPCMExtraPrecision;
//static bool ADPCMFancyLP;	// Commented out, not really a worthwhile feature IMO(sound effects don't sound right without the extra spectrum duplicates).


static bool	bBRAMEnabled;
static uint8	_Port[15];
static uint8 	ACKStatus;

static SimpleFIFO<uint8> SubChannelFIFO(16);

static int32* ADPCMBuf;
static int16 RawPCMVolumeCache[2];

static int32 ClearACKDelay;

static int32 lastts;
static int32 scsicd_ne;

// ADPCM variables and whatnot
#define ADPCM_DEBUG(x, ...) {  /*printf("[Half=%d, End=%d, Playing=%d] "x, ADPCM.HalfReached, ADPCM.EndReached, ADPCM.Playing, ## __VA_ARGS__);*/  }

static OKIADPCM_Decoder<OKIADPCM_MSM5205> MSM5205;

typedef struct
{
 uint8    *RAM;	// = NULL; //0x10000;
 uint16   Addr;
 uint16   ReadAddr;
 uint16   WriteAddr;
 uint16   LengthCount;

 bool HalfReached;
 bool EndReached;
 bool Playing;

 uint8 LastCmd;
 uint32 SampleFreq;

 uint8 PlayBuffer;
 uint8 ReadBuffer;
 int32 ReadPending;
 int32 WritePending;
 uint8 WritePendingValue;

 uint32 PlayNibble;


 int64 bigdivacc;
 int64 bigdiv;
 //
 //
 //
 int32 last_pcm;
 int32 integrate_accum;
 int64 lp1p_fstate;
 int64 lp2p_fstate[3];
} ADPCM_t;

static ADPCM_t ADPCM;

typedef struct
{
 uint8 Command;
 int32 Volume;

 int32 CycleCounter;
 uint32 CountValue;     // What to reload CycleCounter with when it expires.
 bool Clocked;
} FADE_t;

static FADE_t Fader;
static int32 ADPCMFadeVolume, CDDAFadeVolume;
static int32 ADPCMTotalVolume;

static INLINE void Fader_SyncWhich(void)
{
 if(Fader.Command & 0x2) // ADPCM fade
 {
  ADPCMFadeVolume = Fader.Volume;
  CDDAFadeVolume = 65536;
 }
 else   // CD-DA Fade
 {
  CDDAFadeVolume = Fader.Volume;
  ADPCMFadeVolume = 65536;
 }

 ADPCMTotalVolume = ADPCMBaseVolume * ADPCMFadeVolume;
 SCSICD_SetCDDAVolume(CDDAFadeVolume * CDDABaseVolume / 65536, CDDAFadeVolume * CDDABaseVolume / 65536);
}

static INLINE int32 ADPCM_ClocksToNextEvent(void)
{
 int32 ret = (ADPCM.bigdiv + 65535) >> 16;

 if(ADPCM.WritePending > 0 && ret > ADPCM.WritePending)
  ret = ADPCM.WritePending;

 if(ADPCM.ReadPending > 0 && ret > ADPCM.ReadPending)
  ret = ADPCM.ReadPending;

 return(ret);
}

static int32 CalcNextEvent(int32 base)
{
 int32 next_event = base;
 int32 ADPCM_ctne = ADPCM_ClocksToNextEvent();

 if(next_event > ADPCM_ctne)
  next_event = ADPCM_ctne;

 if(ClearACKDelay > 0 && next_event > ClearACKDelay)
  next_event = ClearACKDelay;

 if(next_event > scsicd_ne)
  next_event = scsicd_ne;

 if(Fader.Clocked && next_event > Fader.CycleCounter)
  next_event = Fader.CycleCounter;

 return(next_event);
}

uint32 PCECD_GetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 uint32 value = 0xDEADBEEF;

 switch(id)
 {
  case CD_GSREG_BSY:
	value = SCSICD_GetBSY();
	break;

  case CD_GSREG_REQ:
	value = SCSICD_GetREQ();
	break;

  case CD_GSREG_MSG:
	value = SCSICD_GetMSG();
	break;

  case CD_GSREG_CD:
	value = SCSICD_GetCD();
	break;

  case CD_GSREG_IO:
	value = SCSICD_GetIO();
	break;

  case CD_GSREG_SEL:
	value = SCSICD_GetSEL();
	break;

  case CD_GSREG_ADPCM_CONTROL:
	value = ADPCM.LastCmd;
	break;

  case CD_GSREG_ADPCM_FREQ:
	value = ADPCM.SampleFreq;
	break;

  case CD_GSREG_ADPCM_CUR:
	value = MSM5205.GetSample();
	break;

  case CD_GSREG_ADPCM_WRADDR:
	value = ADPCM.WriteAddr;
	break;

  case CD_GSREG_ADPCM_RDADDR:
	value = ADPCM.ReadAddr;
	break;

  case CD_GSREG_ADPCM_LENGTH:
	value = ADPCM.LengthCount;
	break;

  case CD_GSREG_ADPCM_PLAYNIBBLE:
	value = (bool)(ADPCM.PlayNibble);
	break;

  case CD_GSREG_ADPCM_PLAYING:
	value = ADPCM.Playing;
	break;

  case CD_GSREG_ADPCM_HALFREACHED:
	value = ADPCM.HalfReached;
	break;

  case CD_GSREG_ADPCM_ENDREACHED:
	value = ADPCM.EndReached;
	break;
 }

 return(value);
}

// TODO:
void PCECD_SetRegister(const unsigned int id, const uint32 value)
{

}

void ADPCM_PeekRAM(uint32 Address, uint32 Length, uint8 *Buffer)
{
 while(Length--)
 {
  Address &= 0xFFFF;
  *Buffer = ADPCM.RAM[Address];
  Address++;
  Buffer++;
 }
}

void ADPCM_PokeRAM(uint32 Address, uint32 Length, const uint8 *Buffer)
{
 while(Length--)
 {
  Address &= 0xFFFF;
  ADPCM.RAM[Address] = *Buffer;
  Address++;
  Buffer++;
 }
}

static void update_irq_state()
{
        uint8           irq = _Port[2] & _Port[0x3] & (0x4|0x8|0x10|0x20|0x40);

	IRQCB((bool)irq);
}

static void StuffSubchannel(uint8 meow, int subindex)
{
 uint8 tmp_data = meow & 0x7F;

 if(subindex == -2)
  tmp_data = 0x00;
 else if(subindex == -1)
  tmp_data = 0x80;

 if(SubChannelFIFO.CanWrite())
  SubChannelFIFO.Write(&tmp_data, 1);

 _Port[0x3] |= 0x10;
 update_irq_state();
}

static void CDIRQ(int type)
{
 #ifdef PCECD_DEBUG
 if(type != 0x8000 || _Port[0x3] & 0x60)
  printf("CDIRQ: %d\n", type);
 #endif
 if(type & 0x8000)
 {
  type &= 0x7FFF;
  if(type == SCSICD_IRQ_DATA_TRANSFER_DONE)
   _Port[0x3] &= ~0x20;
  else if(type == SCSICD_IRQ_DATA_TRANSFER_READY)
   _Port[0x3] &= ~0x40;
 }
 else if(type == SCSICD_IRQ_DATA_TRANSFER_DONE)
 {
  _Port[0x3] |= 0x20;
 }
 else if(type == SCSICD_IRQ_DATA_TRANSFER_READY)
 {
  _Port[0x3] |= 0x40;
 }
 update_irq_state();
}

static void UpdateADPCMIRQState(void)
{
 _Port[0x3] &= ~0xC;

 _Port[0x3] |= ADPCM.HalfReached ? 0x4 : 0x0;	
 _Port[0x3] |= ADPCM.EndReached ? 0x8 : 0x0;

 update_irq_state();
}

static INLINE uint8 read_1808(int32 timestamp, const bool PeekMode)
{
 uint8 ret = SCSICD_GetDB();

 if(!PeekMode)
 {
  if(SCSICD_GetREQ() && !SCSICD_GetACK() && !SCSICD_GetCD())
  {
   if(SCSICD_GetIO())
   {
    SCSICD_SetACK(true);
    ACKStatus = true;
    scsicd_ne = SCSICD_Run(timestamp);
    ClearACKDelay = 15 * 3;
   }
  }
 }

 return(ret);
}

bool PCECD_SetSettings(const PCECD_Settings *settings)
{
        //CDDABaseVolume = 0.5850f * (settings ? settings->CDDA_Volume : 1.0);
	//ADPCMBaseVolume = 0.50f * (settings ? settings->ADPCM_Volume : 1.0);

        CDDABaseVolume = 0.50f * (settings ? settings->CDDA_Volume : 1.0);
	ADPCMBaseVolume = 0.42735f * (settings ? settings->ADPCM_Volume : 1.0);
	ADPCMExtraPrecision = settings ? settings->ADPCM_ExtraPrecision : false;
	//ADPCMFancyLP = false;

	Fader_SyncWhich();
	return true;
}

static void Cleanup(void)
{
        if(ADPCM.RAM)
        {
         delete[] ADPCM.RAM;
         ADPCM.RAM = NULL;
	}
 	SCSICD_Close();
}

void PCECD_Init(const PCECD_Settings *settings, void (*irqcb)(bool), double master_clock, int32* adbuf, int32* hrbuf_l, int32* hrbuf_r)
{
 try
 {
	ADPCM.last_pcm = 0;
	ADPCM.integrate_accum = 0;
	ADPCM.lp1p_fstate = 0;
	memset(ADPCM.lp2p_fstate, 0, sizeof(ADPCM.lp2p_fstate));

	lastts = 0;

	IRQCB = irqcb;

	ADPCMBuf = adbuf;

	SCSICD_Init(SCSICD_PCE, 3, hrbuf_l, hrbuf_r, 126000, master_clock, CDIRQ, StuffSubchannel);

        ADPCM.RAM = new uint8[0x10000];

	PCECD_SetSettings(settings);

        ADPCM.bigdivacc = (int64)((double)master_clock * 65536 / 32087.5);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}


void PCECD_Close(void)
{
	Cleanup();
}


int32 PCECD_Power(uint32 timestamp)
{
	if((int32)timestamp != lastts)
 	 (void)PCECD_Run(timestamp);

	IRQCB(0);

	SCSICD_Power(timestamp);
        scsicd_ne = 0x7fffffff;

        bBRAMEnabled = false;
        memset(_Port, 0, sizeof(_Port));
	ACKStatus = 0;
	ClearACKDelay = 0;

	memset(ADPCM.RAM, 0x00, 65536);

	ADPCM.ReadPending = ADPCM.WritePending = 0;
	ADPCM.ReadBuffer = 0;
	ADPCM.PlayBuffer = 0;

        ADPCM.LastCmd = 0;
	MSM5205.SetSample(0x800);
	MSM5205.SetSSI(0);

	ADPCM.SampleFreq = 0;
        ADPCM.bigdiv = ADPCM.bigdivacc * (16 - ADPCM.SampleFreq);

        ADPCM.Addr = 0;
        ADPCM.ReadAddr = 0;
        ADPCM.WriteAddr = 0;
        ADPCM.LengthCount = 0;
        ADPCM.LastCmd = 0;

	ADPCM.HalfReached = false;
	ADPCM.EndReached = false;
	ADPCM.Playing = false;
	ADPCM.PlayNibble = 0;

	UpdateADPCMIRQState();

	Fader.Command = 0x00;
	Fader.Volume = 0;
	Fader.CycleCounter = 0;
	Fader.CountValue = 0;
	Fader.Clocked = false;

	return(CalcNextEvent(0x7FFFFFFF));
}

bool PCECD_IsBRAMEnabled()
{
	return bBRAMEnabled;
}

MDFN_FASTCALL uint8 PCECD_Read(uint32 timestamp, uint32 A, int32 &next_event, const bool PeekMode)
{
 uint8 ret = 0;

 if((A & 0x18c0) == 0x18c0)
 {
  switch (A & 0x18cf)
  {
   case 0x18c1: ret = 0xaa; break;
   case 0x18c2:	ret = 0x55; break;
   case 0x18c3: ret = 0x00; break;
   case 0x18c5:	ret = 0xaa; break;
   case 0x18c6: ret = 0x55; break;
   case 0x18c7:	ret = 0x03; break;
  }
 }
 else
 {
  if(!PeekMode)
   PCECD_Run(timestamp);

  switch(A & 0xf)
  {
   case 0x0:
    ret = 0;
    ret |= SCSICD_GetBSY() ? 0x80 : 0x00;
    ret |= SCSICD_GetREQ() ? 0x40 : 0x00;
    ret |= SCSICD_GetMSG() ? 0x20 : 0x00;
    ret |= SCSICD_GetCD() ? 0x10 : 0x00;
    ret |= SCSICD_GetIO() ? 0x08 : 0x00;
    break;

   case 0x1: ret = SCSICD_GetDB();
	     break;

   case 0x2: ret = _Port[2];
	     break;

   case 0x3: bBRAMEnabled = false;

	     /* switch left/right of digitized cd playback */
	     ret = _Port[0x3];
	     if(!PeekMode)
	      _Port[0x3] ^= 2;
	     break;

   case 0x4: ret = _Port[4];
	     break;

   case 0x5: if(_Port[0x3] & 0x2)
	      ret = RawPCMVolumeCache[1] & 0xff;	// Right
	     else
	      ret = RawPCMVolumeCache[0] & 0xff;	// Left
	     break;

   case 0x6: if(_Port[0x3] & 0x2)
	      ret = ((uint16)RawPCMVolumeCache[1]) >> 8;	// Right
	     else
	      ret = ((uint16)RawPCMVolumeCache[0]) >> 8;	// Left
	     break;

   case 0x7:
    if(SubChannelFIFO.CanRead() > 0)
     ret = SubChannelFIFO.ReadByte(PeekMode);
    else
     ret = 0x00;	// Not sure if it's 0, 0xFF, the last byte read, or something else.

    if(!PeekMode)
    {
     if(SubChannelFIFO.CanRead() == 0)
     {
      _Port[0x3] &= ~0x10;
      update_irq_state();
     }
    }
    break;

   case 0x8:
    ret = read_1808(timestamp, PeekMode);
    break;

   case 0xa: 
    if(!PeekMode)
    {
     ADPCM_DEBUG("ReadBuffer\n");
     ADPCM.ReadPending = 19 * 3; //24 * 3;
    }

    ret = ADPCM.ReadBuffer;

    break;

   case 0xb: 
    ret = _Port[0xb];
    break;

   case 0xc:
    //printf("ADPCM Status Read: %d\n", timestamp);
    ret = 0x00;

    ret |= (ADPCM.EndReached) ? 0x01 : 0x00;
    ret |= (ADPCM.Playing) ? 0x08 : 0x00;
    ret |= (ADPCM.WritePending > 0) ? 0x04 : 0x00;
    ret |= (ADPCM.ReadPending > 0) ? 0x80 : 0x00;
    break;   

   case 0xd: 
    ret = ADPCM.LastCmd;
    break;
  }
 }

 #ifdef PCECD_DEBUG
 printf("Read: %04x %02x, %d\n", A, ret, timestamp);
 #endif

 next_event = CalcNextEvent(0x7FFFFFFF);

 return(ret);
}

static INLINE void Fader_Run(const int32 clocks)
{
 if(Fader.Clocked)
 {
  Fader.CycleCounter -= clocks;
  while(Fader.CycleCounter <= 0)
  {
   if(Fader.Volume)
    Fader.Volume--;

   Fader_SyncWhich();

   Fader.CycleCounter += Fader.CountValue;
  }
 }
}


MDFN_FASTCALL int32 PCECD_Write(uint32 timestamp, uint32 physAddr, uint8 data)
{
	const uint8 V = data;

	#ifdef PCECD_DEBUG
	printf("Write: (PC=%04x, t=%6d) %04x %02x; MSG: %d, REQ: %d, ACK: %d, CD: %d, IO: %d, BSY: %d, SEL: %d\n", HuCPU.PC, timestamp, physAddr, data, SCSICD_GetMSG(), SCSICD_GetREQ(), SCSICD_GetACK(), SCSICD_GetCD(), SCSICD_GetIO(), SCSICD_GetBSY(), SCSICD_GetSEL());
	#endif

	PCECD_Run(timestamp);

	switch (physAddr & 0xf)
	{
		case 0x0:
			SCSICD_SetSEL(1);
			SCSICD_Run(timestamp);
			SCSICD_SetSEL(0);
			scsicd_ne = SCSICD_Run(timestamp);

			/* reset irq status */
			_Port[0x3] &= ~(0x20 | 0x40);	// TODO: Confirm writing this register really reset these bits.
			update_irq_state();
			break;

		case 0x1:		// $1801
			_Port[1] = data;
			SCSICD_SetDB(data);
			scsicd_ne = SCSICD_Run(timestamp);
			break;

		case 0x2:		// $1802
			#ifdef PCECD_DEBUG
			if(!(_Port[0x3] & _Port[2] & 0x40) && (_Port[0x3] & data & 0x40))
			 puts("IRQ on waah 0x40");
			if(!(_Port[0x3] & _Port[2] & 0x20) && (_Port[0x3] & data & 0x20))
			 puts("IRQ on waah 0x20");
			#endif

			SCSICD_SetACK(data & 0x80);
			scsicd_ne = SCSICD_Run(timestamp);
			_Port[2] = data;
			ACKStatus = (bool)(data & 0x80);
			update_irq_state();
			break;

		case 0x3:		// read only
			break;

		case 0x4:
			SCSICD_SetRST(data & 0x2);
			scsicd_ne = SCSICD_Run(timestamp);
			if(data & 0x2)
			{
				_Port[0x3] &= ~0x70;
				update_irq_state();
			}
			_Port[4] = data;
			break;

		case 0x5:
		case 0x6:
			 {
			  int16 left, right;
 			  SCSICD_GetCDDAValues(left, right);
			  RawPCMVolumeCache[0] = ((int64)abs(left) * CDDAFadeVolume) >> 16;
			  RawPCMVolumeCache[1] = ((int64)abs(right) * CDDAFadeVolume) >> 16;
			 }
			 break;

		case 0x7:	// $1807: D7=1 enables backup ram 
			if (data & 0x80)
			{
				bBRAMEnabled = true;
			}
			break;
	
		case 0x8:	// Set ADPCM address low
			if(ADPCM.LastCmd & 0x80)
			 break;

			ADPCM.Addr &= 0xFF00;
			ADPCM.Addr |= V;

			ADPCM_DEBUG("SAL: %02x, %d\n", V, timestamp);

                        // Length appears to be constantly latched when D4 is set(tested on a real system)
                        if(ADPCM.LastCmd & 0x10)
                        {
                         ADPCM_DEBUG("Set length(crazy way L): %04x\n", ADPCM.Addr);
                         ADPCM.LengthCount = ADPCM.Addr;
                        }
			break;

		case 0x9:	// Set ADPCM address high
			if(ADPCM.LastCmd & 0x80)
			 break;

			ADPCM.Addr &= 0x00FF;
			ADPCM.Addr |= V << 8;

			ADPCM_DEBUG("SAH: %02x, %d\n", V, timestamp);

                        // Length appears to be constantly latched when D4 is set(tested on a real system)
                        if(ADPCM.LastCmd & 0x10)
                        {
                         ADPCM_DEBUG("Set length(crazy way H): %04x\n", ADPCM.Addr);
                         ADPCM.LengthCount = ADPCM.Addr;
                        }
			break;

		case 0xa:
                        //ADPCM_DEBUG("Write: %02x, %d\n", V, timestamp);
		        ADPCM.WritePending = 3 * 11;
		        ADPCM.WritePendingValue = data;
			break;

		case 0xb:	// adpcm dma
			ADPCM_DEBUG("DMA: %02x\n", V);
                        _Port[0xb] = data;
			break;

		case 0xc:		// read-only
			break;

		case 0xd:
		        ADPCM_DEBUG("Write180D: %02x\n", V);
		        if(data & 0x80)
		        {
		         ADPCM.Addr = 0;
		         ADPCM.ReadAddr = 0;
		         ADPCM.WriteAddr = 0;
		         ADPCM.LengthCount = 0;
		         ADPCM.LastCmd = 0;

			 ADPCM.Playing = false;
			 ADPCM.HalfReached = false;
			 ADPCM.EndReached = false;

			 ADPCM.PlayNibble = 0;

			 UpdateADPCMIRQState();

		         MSM5205.SetSample(0x800);
		         MSM5205.SetSSI(0);
		         break;
		        }

			if(ADPCM.Playing && !(data & 0x20))
			 ADPCM.Playing = false;

			if(!ADPCM.Playing && (data & 0x20))
			{
			 ADPCM.bigdiv = ADPCM.bigdivacc * (16 - ADPCM.SampleFreq);
			 ADPCM.Playing = true;
			 ADPCM.HalfReached = false;	// Not sure about this.
			 ADPCM.PlayNibble = 0;
                         MSM5205.SetSample(0x800);
                         MSM5205.SetSSI(0);
			}

			// Length appears to be constantly latched when D4 is set(tested on a real system)
		        if(data & 0x10)
		        {
		         ADPCM_DEBUG("Set length: %04x\n", ADPCM.Addr);
		         ADPCM.LengthCount = ADPCM.Addr;
			 ADPCM.EndReached = false;
		        }

		        // D2 and D3 control read address
		        if(!(ADPCM.LastCmd & 0x8) && (data & 0x08))
		        {
		         if(data & 0x4)
		          ADPCM.ReadAddr = ADPCM.Addr;
		         else
		          ADPCM.ReadAddr = (ADPCM.Addr - 1) & 0xFFFF;

		         ADPCM_DEBUG("Set ReadAddr: %04x, %06x\n", ADPCM.Addr, ADPCM.ReadAddr);
		        }

		        // D0 and D1 control write address
		        if(!(ADPCM.LastCmd & 0x2) && (data & 0x2))
		        {
		         ADPCM.WriteAddr = ADPCM.Addr;
		         if(!(data & 0x1))
		          ADPCM.WriteAddr = (ADPCM.WriteAddr - 1) & 0xFFFF;
		         ADPCM_DEBUG("Set WriteAddr: %04x, %06x\n", ADPCM.Addr, ADPCM.WriteAddr);
		        }
		        ADPCM.LastCmd = data;
			UpdateADPCMIRQState();
			break;

		case 0xe:		// Set ADPCM playback rate
			{
			 uint8 freq = V & 0x0F;

		         ADPCM.SampleFreq = freq;

			 ADPCM_DEBUG("Freq: %02x\n", freq);
			}
			break;

		case 0xf:
			Fader.Command = V;

			#ifdef PCECD_DEBUG
			printf("Fade: %02x\n", data);
			#endif

			// Cancel fade
			if(!(V & 0x8))
			{
			 Fader.Volume = 65536;
			 Fader.CycleCounter = 0;
			 Fader.CountValue = 0;
			 Fader.Clocked = false;
			}
			else
			{
			 Fader.CountValue = 3 * ((V & 0x4) ? 273 : 655);	// 2.500s : 6.000s;

			 if(!Fader.Clocked)
			  Fader.CycleCounter = Fader.CountValue;

			 Fader.Clocked = true;
			}
			Fader_SyncWhich();
			break;
	}


	return(CalcNextEvent(0x7FFFFFFF));
}

static const unsigned ADPCM_Filter_NumPhases = 64;
static const unsigned ADPCM_Filter_NumConvolutions = 7;

static const uint8 ADPCM_Filter[64][ADPCM_Filter_NumConvolutions] =
{
 /*   0 */ {     5,    37,    86,    86,    37,     5,     0 }, //   256 256.314778(diff = 0.314778)
 /*   1 */ {     5,    36,    85,    86,    38,     6,     0 }, //   256 255.972526(diff = 0.027474)
 /*   2 */ {     5,    35,    84,    87,    39,     6,     0 }, //   256 255.977727(diff = 0.022273)
 /*   3 */ {     5,    34,    84,    87,    40,     6,     0 }, //   256 255.982355(diff = 0.017645)
 /*   4 */ {     4,    34,    83,    88,    41,     6,     0 }, //   256 255.986452(diff = 0.013548)
 /*   5 */ {     4,    33,    83,    88,    41,     7,     0 }, //   256 256.007876(diff = 0.007876)
 /*   6 */ {     4,    32,    82,    89,    42,     7,     0 }, //   256 255.993212(diff = 0.006788)
 /*   7 */ {     4,    32,    81,    89,    43,     7,     0 }, //   256 255.995950(diff = 0.004050)
 /*   8 */ {     4,    31,    80,    90,    44,     7,     0 }, //   256 255.642895(diff = 0.357105)
 /*   9 */ {     3,    30,    80,    90,    45,     8,     0 }, //   256 256.000315(diff = 0.000315)
 /*  10 */ {     3,    30,    79,    91,    45,     8,     0 }, //   256 256.512678(diff = 0.512678)
 /*  11 */ {     3,    29,    79,    91,    46,     8,     0 }, //   256 256.003417(diff = 0.003417)
 /*  12 */ {     3,    28,    78,    91,    47,     9,     0 }, //   256 256.004569(diff = 0.004569)
 /*  13 */ {     3,    27,    77,    92,    48,     9,     0 }, //   256 256.005492(diff = 0.005492)
 /*  14 */ {     3,    27,    76,    92,    49,     9,     0 }, //   256 255.832851(diff = 0.167149)
 /*  15 */ {     3,    26,    76,    92,    49,    10,     0 }, //   256 256.006751(diff = 0.006751)
 /*  16 */ {     2,    26,    75,    93,    50,    10,     0 }, //   256 256.322217(diff = 0.322217)
 /*  17 */ {     2,    25,    75,    93,    51,    10,     0 }, //   256 256.380094(diff = 0.380094)
 /*  18 */ {     2,    24,    74,    93,    52,    11,     0 }, //   256 256.007518(diff = 0.007518)
 /*  19 */ {     2,    24,    73,    93,    53,    11,     0 }, //   256 256.007555(diff = 0.007555)
 /*  20 */ {     2,    23,    72,    93,    54,    12,     0 }, //   256 256.007514(diff = 0.007514)
 /*  21 */ {     2,    22,    72,    94,    54,    12,     0 }, //   256 256.376453(diff = 0.376453)
 /*  22 */ {     2,    22,    71,    94,    55,    12,     0 }, //   256 256.007255(diff = 0.007255)
 /*  23 */ {     2,    21,    69,    94,    56,    13,     1 }, //   256 254.698920(diff = 1.301080)
 /*  24 */ {     2,    21,    69,    94,    56,    13,     1 }, //   256 254.310181(diff = 1.689819)
 /*  25 */ {     1,    20,    68,    94,    58,    14,     1 }, //   256 256.006624(diff = 0.006624)
 /*  26 */ {     1,    20,    67,    94,    59,    14,     1 }, //   256 256.002270(diff = 0.002270)
 /*  27 */ {     1,    19,    67,    94,    59,    15,     1 }, //   256 256.006163(diff = 0.006163)
 /*  28 */ {     1,    18,    66,    95,    60,    15,     1 }, //   256 256.005944(diff = 0.005944)
 /*  29 */ {     1,    18,    65,    95,    61,    15,     1 }, //   256 256.005740(diff = 0.005740)
 /*  30 */ {     1,    17,    64,    95,    62,    16,     1 }, //   256 256.005555(diff = 0.005555)
 /*  31 */ {     1,    17,    63,    95,    63,    16,     1 }, //   256 256.005391(diff = 0.005391)
 /*  32 */ {     1,    16,    63,    95,    63,    17,     1 }, //   256 256.005391(diff = 0.005391)
 /*  33 */ {     1,    16,    62,    95,    64,    17,     1 }, //   256 256.005555(diff = 0.005555)
 /*  34 */ {     1,    15,    61,    95,    65,    18,     1 }, //   256 256.005740(diff = 0.005740)
 /*  35 */ {     1,    15,    60,    95,    66,    18,     1 }, //   256 256.005944(diff = 0.005944)
 /*  36 */ {     1,    15,    59,    94,    67,    19,     1 }, //   256 256.006163(diff = 0.006163)
 /*  37 */ {     1,    14,    59,    94,    67,    20,     1 }, //   256 256.002270(diff = 0.002270)
 /*  38 */ {     1,    14,    58,    94,    68,    20,     1 }, //   256 256.006624(diff = 0.006624)
 /*  39 */ {     1,    13,    56,    94,    69,    21,     2 }, //   256 254.310181(diff = 1.689819)
 /*  40 */ {     1,    13,    56,    94,    69,    21,     2 }, //   256 254.698920(diff = 1.301080)
 /*  41 */ {     0,    12,    55,    94,    71,    22,     2 }, //   256 256.007255(diff = 0.007255)
 /*  42 */ {     0,    12,    54,    94,    72,    22,     2 }, //   256 256.376453(diff = 0.376453)
 /*  43 */ {     0,    12,    54,    93,    72,    23,     2 }, //   256 256.007514(diff = 0.007514)
 /*  44 */ {     0,    11,    53,    93,    73,    24,     2 }, //   256 256.007555(diff = 0.007555)
 /*  45 */ {     0,    11,    52,    93,    74,    24,     2 }, //   256 256.007518(diff = 0.007518)
 /*  46 */ {     0,    10,    51,    93,    75,    25,     2 }, //   256 256.380094(diff = 0.380094)
 /*  47 */ {     0,    10,    50,    93,    75,    26,     2 }, //   256 256.322217(diff = 0.322217)
 /*  48 */ {     0,    10,    49,    92,    76,    26,     3 }, //   256 256.006751(diff = 0.006751)
 /*  49 */ {     0,     9,    49,    92,    76,    27,     3 }, //   256 255.832851(diff = 0.167149)
 /*  50 */ {     0,     9,    48,    92,    77,    27,     3 }, //   256 256.005492(diff = 0.005492)
 /*  51 */ {     0,     9,    47,    91,    78,    28,     3 }, //   256 256.004569(diff = 0.004569)
 /*  52 */ {     0,     8,    46,    91,    79,    29,     3 }, //   256 256.003417(diff = 0.003417)
 /*  53 */ {     0,     8,    45,    91,    79,    30,     3 }, //   256 256.512678(diff = 0.512678)
 /*  54 */ {     0,     8,    45,    90,    80,    30,     3 }, //   256 256.000315(diff = 0.000315)
 /*  55 */ {     0,     7,    44,    90,    80,    31,     4 }, //   256 255.642895(diff = 0.357105)
 /*  56 */ {     0,     7,    43,    89,    81,    32,     4 }, //   256 255.995950(diff = 0.004050)
 /*  57 */ {     0,     7,    42,    89,    82,    32,     4 }, //   256 255.993212(diff = 0.006788)
 /*  58 */ {     0,     7,    41,    88,    83,    33,     4 }, //   256 256.007876(diff = 0.007876)
 /*  59 */ {     0,     6,    41,    88,    83,    34,     4 }, //   256 255.986452(diff = 0.013548)
 /*  60 */ {     0,     6,    40,    87,    84,    34,     5 }, //   256 255.982355(diff = 0.017645)
 /*  61 */ {     0,     6,    39,    87,    84,    35,     5 }, //   256 255.977727(diff = 0.022273)
 /*  62 */ {     0,     6,    38,    86,    85,    36,     5 }, //   256 255.972526(diff = 0.027474)
 /*  63 */ {     0,     5,    37,    86,    86,    37,     5 }, //   256 256.314778(diff = 0.314778)
};

// TODO: ADPCM_UpdateOutput() function here(for power and ADPCM state reset stuuuuffff).  timestamp_ex(timestamp << 16) as a parameter?

static INLINE void ADPCM_PB_Run(int32 basetime, int32 run_time)
{
 ADPCM.bigdiv -= ((int64)run_time << 16);

 while(ADPCM.bigdiv <= 0)
 {
  //const uint32 synthtime = ((basetime + (ADPCM.bigdiv >> 16))) / (3 * OC_Multiplier);
  const uint64 synthtime_ex = ((((uint64)basetime << 16) + ADPCM.bigdiv) / 3) >> 2;
  const int synthtime = synthtime_ex >> 16;
  const int synthtime_phase_int = (synthtime_ex & 0xFFFF) >> 10;
  //const int synthtime_phase = (int)(synthtime_ex & 0xFFFF) - 0x80;
  //const int synthtime_phase_int = synthtime_phase >> 10; //(16 - 6);
  //const int synthtime_phase_fract = synthtime_phase & 1023; //((1U << (16 - 6)) - 1);

  ADPCM.bigdiv += ADPCM.bigdivacc * (16 - ADPCM.SampleFreq);

  if(ADPCM.Playing && !ADPCM.PlayNibble)	// Do playback sample buffer fetch.
  {
   ADPCM.HalfReached = (ADPCM.LengthCount < 32768);
   if(!ADPCM.LengthCount && !(ADPCM.LastCmd & 0x10))
   {
    if(ADPCM.EndReached)
     ADPCM.HalfReached = false;

    ADPCM.EndReached = true;

    if(ADPCM.LastCmd & 0x40)
     ADPCM.Playing = false;
   }

   ADPCM.PlayBuffer = ADPCM.RAM[ADPCM.ReadAddr];
   ADPCM.ReadAddr = (ADPCM.ReadAddr + 1) & 0xFFFF;

   if(ADPCM.LengthCount && !(ADPCM.LastCmd & 0x10))
    ADPCM.LengthCount--;
  }

#if 0
  {
   static unsigned counter = 0;
   static int16 wv = 0x6000;

   if(!counter)
   {
    wv = -wv;
    counter = 1;
   }
   else
    counter--;

   int32 delta = wv - ADPCM.last_pcm;
   for(unsigned c = 0; c < ADPCM_Filter_NumConvolutions; c++)
   {
    int32 coeff;

    coeff = ADPCM_Filter[synthtime_phase_int][c];
    HRBufs[0][synthtime + c] += (delta * coeff);
    HRBufs[1][synthtime + c] += (delta * coeff);
   }
   ADPCM.last_pcm = wv;
  }
#else
  if(ADPCM.Playing)
  {
   int32 pcm;
   uint8 nibble;

   nibble = (ADPCM.PlayBuffer >> (ADPCM.PlayNibble ^ 4)) & 0x0F;

   if(ADPCMExtraPrecision)
    pcm = MSM5205.Decode(nibble) - 2048;
   else
    pcm = (MSM5205.Decode(nibble) &~3) - 2048;	// Chop lower 2 bits off 12-bit result, MSM5205 internal DAC is only 10 bits.

   ADPCM.PlayNibble ^= 4;

   pcm = (pcm * ADPCMTotalVolume) >> 12;

   //
   //
   //
   if(ADPCMBuf)
   {
    int32 delta = pcm - ADPCM.last_pcm;
    const uint8* sf = ADPCM_Filter[synthtime_phase_int];
    int32* tb = &ADPCMBuf[synthtime & 0xFFFF];

    for(unsigned c = 0; c < ADPCM_Filter_NumConvolutions; c++)
    {
     tb[c] += (delta * sf[c]);
    }
    ADPCM.last_pcm = pcm;
   }
  }
#endif
 }
}

#if 0
static const struct
{
 double gain;
 double yv0_coeff;
 double yv1_coeff;
 double yv2_coeff;
} ADPCMLP_FilterParams[16] =
{
 /* CF: 1002.734 */ { 2.300517993e+07, 0.9929843194, -2.9859439639, 2.9929596010 },
 /* CF: 1069.583 */ { 1.896012966e+07, 0.9925183607, -2.9850086552, 2.9924902417 },
 /* CF: 1145.982 */ { 1.541941409e+07, 0.9919861033, -2.9839399984, 2.9919538303 },
 /* CF: 1234.134 */ { 1.234948104e+07, 0.9913723196, -2.9827072999, 2.9913348993 },
 /* CF: 1336.979 */ { 9.716697944e+06, 0.9906567117, -2.9812696212, 2.9906128066 },
 /* CF: 1458.522 */ { 7.487534140e+06, 0.9898116667, -2.9795712330, 2.9897594328 },
 /* CF: 1604.375 */ { 5.628367975e+06, 0.9887985545, -2.9775341077, 2.9887353756 },
 /* CF: 1782.638 */ { 4.105654952e+06, 0.9875617266, -2.9750457348, 2.9874837647 },
 /* CF: 2005.468 */ { 2.885788193e+06, 0.9860178585, -2.9719374507, 2.9859192457 },
 /* CF: 2291.964 */ { 1.935196585e+06, 0.9840364292, -2.9679446716, 2.9839077257 },
 /* CF: 2673.958 */ { 1.220301436e+06, 0.9814007204, -2.9626272564, 2.9812257166 },
 /* CF: 3208.750 */ { 7.075197786e+05, 0.9777225813, -2.9551949245, 2.9774709298 },
 /* CF: 4010.937 */ { 3.632718552e+05, 0.9722312105, -2.9440727965, 2.9718388333 },
 /* CF: 5347.916 */ { 1.539763246e+05, 0.9631473739, -2.9256061287, 2.9624522603 },
 /* CF: 8021.875 */ { 4.605288317e+04, 0.9452335200, -2.8889356853, 2.9436804511 },
 /* CF: 16043.75 */ { 5.921030260e+03, 0.8934664072, -2.7810185247, 2.8873832279 },
};
#endif

void PCECD_ProcessADPCMBuffer(const uint32 rsc)
{
#if 0
 if(ADPCMFancyLP)
 {
  static double yv[4] = { 0 };
  double gain_recip = 1024.0 / ADPCMLP_FilterParams[ADPCM.SampleFreq].gain;
  double yv_coeff[3] = { ADPCMLP_FilterParams[ADPCM.SampleFreq].yv0_coeff,
			ADPCMLP_FilterParams[ADPCM.SampleFreq].yv1_coeff,
			ADPCMLP_FilterParams[ADPCM.SampleFreq].yv2_coeff };
  //printf("%.10f %.10f %.10f\n", yv_coeff[0], yv_coeff[1], yv_coeff[2]);

  for(uint32 i = 0; i < rsc; i++)
  {
   ADPCM.integrate_accum += ADPCMBuf[i];

   yv[0] = yv[1];
   yv[1] = yv[2];
   yv[2] = yv[3];
   yv[3] = (double)ADPCM.integrate_accum + (yv_coeff[0] * yv[0]) + (yv_coeff[1] * yv[1]) + (yv_coeff[2] * yv[2]);

   ADPCM.lp1p_fstate += ((int64)(yv[3] * gain_recip) - ADPCM.lp1p_fstate) >> 2;

   ADPCMBuf[i] = ADPCM.lp1p_fstate >> 10;
   //if(i < 10)
   // printf("%d, %f\n", i, yv[3] * gain_recip);
  }  
 }
 else
#endif
 {
  for(uint32 i = 0; i < rsc; i++)
  {
   ADPCM.integrate_accum += ADPCMBuf[i];

   ADPCM.lp2p_fstate[0] = ADPCM.lp2p_fstate[1];
   ADPCM.lp2p_fstate[1] = ADPCM.lp2p_fstate[2]; 
   ADPCM.lp2p_fstate[2] = (ADPCM.integrate_accum + (((int64)-62671 * ADPCM.lp2p_fstate[0]) >> 16) + (((int64)128143 * ADPCM.lp2p_fstate[1]) >> 16));

   ADPCM.lp1p_fstate += (ADPCM.lp2p_fstate[2] - ADPCM.lp1p_fstate) >> 2;

   ADPCMBuf[i] = ADPCM.lp1p_fstate >> 10;
   //printf("%lld\n", yv[2] >> 10);
  }
 }
}

static INLINE void ADPCM_Run(const int32 clocks, const int32 timestamp)
{
 //printf("ADPCM Run: %d\n", clocks);
 ADPCM_PB_Run(timestamp, clocks);

 if(ADPCM.WritePending > 0)
 {
  ADPCM.WritePending -= clocks;
  if(ADPCM.WritePending <= 0)
  {
   ADPCM.HalfReached = (ADPCM.LengthCount < 32768);
   if(!(ADPCM.LastCmd & 0x10) && ADPCM.LengthCount < 0xFFFF)
    ADPCM.LengthCount++;

   ADPCM.RAM[ADPCM.WriteAddr++] = ADPCM.WritePendingValue;
   ADPCM.WritePending = 0;
  }
 }

 if(ADPCM.WritePending <= 0)
 {
  if(_Port[0xb] & 0x3)
  {
   // Run SCSICD before we examine the signals.
   scsicd_ne = SCSICD_Run(timestamp);

   if(!SCSICD_GetCD() && SCSICD_GetIO() && SCSICD_GetREQ() && !SCSICD_GetACK())
   {
    ADPCM.WritePendingValue = read_1808(timestamp, false); //read_1801();
    ADPCM.WritePending = 10 * 3;
   }
  }
 }

 if(ADPCM.ReadPending > 0)
 {
  ADPCM.ReadPending -= clocks;
  if(ADPCM.ReadPending <= 0)
  {
   ADPCM.ReadBuffer = ADPCM.RAM[ADPCM.ReadAddr];
   ADPCM.ReadAddr = (ADPCM.ReadAddr + 1) & 0xFFFF;
   ADPCM.ReadPending = 0;

   ADPCM.HalfReached = (ADPCM.LengthCount < 32768);
   if(!(ADPCM.LastCmd & 0x10))
   {
    if(ADPCM.LengthCount)
     ADPCM.LengthCount--;
    else
    {
     ADPCM.EndReached = true;
     ADPCM.HalfReached = false;

     if(ADPCM.LastCmd & 0x40)
      ADPCM.Playing = false;
    }
   }
  }
 }

 UpdateADPCMIRQState();
}


// The return value of this function is ignored in PCECD_Read() and PCECD_Write() for speed reasons, and the
// fact that reading and writing can change the next potential event,
MDFN_FASTCALL int32 PCECD_Run(uint32 in_timestamp)
{
 int32 clocks = in_timestamp - lastts;
 int32 running_ts = lastts;

 //printf("Run Begin: Clocks=%d(%d - %d), cl=%d ---- (%016llx %d %d) %d %d %d\n", clocks, in_timestamp, lastts, CalcNextEvent(clocks), (long long)ADPCM.bigdiv, ADPCM.ReadPending, ADPCM.WritePending, ClearACKDelay, scsicd_ne, Fader.CycleCounter);
 //fflush(stdout);

 while(clocks > 0)
 {
  int32 chunk_clocks = CalcNextEvent(clocks);

  running_ts += chunk_clocks;

  if(ClearACKDelay > 0)
  {
   ClearACKDelay -= chunk_clocks;
   if(ClearACKDelay <= 0)
   {
    ACKStatus = false;
    SCSICD_SetACK(false);
    SCSICD_Run(running_ts);
    if(SCSICD_GetCD())
    {
     _Port[0xb] &= ~1;
     #ifdef PCECD_DEBUG
     puts("DMA End");
     #endif
    }
   }
  }

  Fader_Run(chunk_clocks);

  ADPCM_Run(chunk_clocks, running_ts);
  scsicd_ne = SCSICD_Run(running_ts);

  clocks -= chunk_clocks;
 }

 lastts = in_timestamp;

 //puts("Run End");
 //fflush(stdout);

 return(CalcNextEvent(0x7FFFFFFF));
}

void PCECD_ResetTS(uint32 ts_base)
{
 SCSICD_ResetTS(ts_base);
 lastts = ts_base;
}

static void ADPCM_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 uint32 ad_sample = MSM5205.GetSample();
 uint32 ad_ref_index = MSM5205.GetSSI();

 SFORMAT StateRegs[] =
 {
        SFPTR8(ADPCM.RAM, 0x10000),

        SFVAR(ADPCM.bigdiv),
        SFVAR(ADPCM.Addr),
        SFVAR(ADPCM.ReadAddr),
        SFVAR(ADPCM.WriteAddr),
        SFVAR(ADPCM.LengthCount),
        SFVAR(ADPCM.LastCmd),
        SFVAR(ADPCM.SampleFreq),

        SFVAR(ADPCM.ReadPending),
        SFVAR(ADPCM.ReadBuffer),
	SFVAR(ADPCM.PlayBuffer),

        SFVAR(ADPCM.WritePending),
        SFVAR(ADPCM.WritePendingValue),

	SFVAR(ADPCM.HalfReached),
	SFVAR(ADPCM.EndReached),
	SFVAR(ADPCM.Playing),

	SFVAR(ADPCM.PlayNibble),

        SFVAR(ad_sample),
        SFVAR(ad_ref_index),
        SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "APCM");

 if(load)
 {
  ad_ref_index %= 49;
  ad_sample &= 0xFFF;
  ADPCM.SampleFreq &= 0xF;

  if(ADPCM.bigdiv < 1)
   ADPCM.bigdiv = 1;
  else if(ADPCM.bigdiv > ((int64)0x7FFFFFFF << 16))
   ADPCM.bigdiv = ((int64)0x7FFFFFFF << 16);

  //
  //

  MSM5205.SetSample(ad_sample);
  MSM5205.SetSSI(ad_ref_index);
 }
}

void PCECD_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
	SFORMAT StateRegs[] =
	{
	 SFVAR(bBRAMEnabled),
	 SFVAR(ACKStatus),
	 SFVAR(ClearACKDelay),
	 SFVAR(RawPCMVolumeCache),
	 SFVAR(_Port),

	 SFVAR(Fader.Command),
	 SFVAR(Fader.Volume),
	 SFVAR(Fader.CycleCounter),
	 SFVAR(Fader.CountValue),
	 SFVAR(Fader.Clocked),

	 SFPTR8(&SubChannelFIFO.data[0], SubChannelFIFO.data.size()),
	 SFVAR(SubChannelFIFO.read_pos),
	 SFVAR(SubChannelFIFO.write_pos),
	 SFVAR(SubChannelFIFO.in_count),

	 SFVAR(scsicd_ne),

	 SFEND
	};

        MDFNSS_StateAction(sm, load, data_only, StateRegs, "PECD");
	if(load)
	{
	 if(Fader.Clocked && Fader.CycleCounter < 1)
	  Fader.CycleCounter = 1;

	 if(scsicd_ne < 1)
	  scsicd_ne = 1;

	 SubChannelFIFO.SaveStatePostLoad();
	}
	SCSICD_StateAction(sm, load, data_only, "CDRM");
	ADPCM_StateAction(sm, load, data_only);

	if(load)
	{
	 Fader_SyncWhich();
	 //SCSICD_SetDB(_Port[1]);
	 SCSICD_SetACK(ACKStatus);
         SCSICD_SetRST(_Port[4] & 0x2);
	}
}

}
