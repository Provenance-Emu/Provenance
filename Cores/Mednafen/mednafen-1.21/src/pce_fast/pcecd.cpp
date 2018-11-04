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
   PCE_FAST(less accurate, faster, etc.) fork from PCE module "pcecd.cpp".
*/

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/cdrom/SimpleFIFO.h>
#include <mednafen/sound/okiadpcm.h>

#include "pcecd_drive.h"
#include "pcecd.h"

namespace PCE_Fast
{

//#define PCECD_DEBUG

static unsigned int OC_Multiplier;

static void (*IRQCB)(bool asserted);

static float CDDAVolumeSetting; // User setting!

static bool	bBRAMEnabled;
static uint8	_Port[15];
static uint8 	ACKStatus;

static SimpleFIFO<uint8> SubChannelFIFO(16);

static Blip_Buffer* sbuf;
static int16 RawPCMVolumeCache[2];

static int32 ClearACKDelay;

static int32 lastts;
static int32 pcecd_drive_ne;

// ADPCM variables and whatnot
#define ADPCM_DEBUG(x, ...) {  /*printf("[Half=%d, End=%d, Playing=%d] "x, ADPCM.HalfReached, ADPCM.EndReached, ADPCM.Playing, ## __VA_ARGS__);*/  }

typedef Blip_Synth<blip_good_quality, 16384> ADSynth;
static ADSynth ADPCMSynth;
static OKIADPCM_Decoder<OKIADPCM_MSM5205> MSM5205;

static bool ADPCMLP;
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
 uint32 LPF_SampleFreq;

 uint8 PlayBuffer;
 uint8 ReadBuffer;
 int32 ReadPending;
 int32 WritePending;
 uint8 WritePendingValue;

 uint32 PlayNibble;


 int64 bigdivacc;
 int64 bigdiv;
 int32 last_pcm;
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

 ADPCMFadeVolume >>= 6;
 PCECD_Drive_SetCDDAVolume(0.50f * CDDAFadeVolume * CDDAVolumeSetting);
}


static void RedoLPF(int f)
{
	if(sbuf)
	{
         if(ADPCMLP)
         {
          if(f >= 14)
          {
           int rolloff = (int)((((double)32087.5 / (16 - f)) / 2) * 0.70);
           ADPCMSynth.treble_eq( blip_eq_t(-1000, rolloff, sbuf[0].sample_rate()));
          }
          else
          {
           int rolloff = (int)((((double)32087.5 / (16 - f)) / 2) * 0.80);
           ADPCMSynth.treble_eq( blip_eq_t(-1000, rolloff, sbuf[0].sample_rate()));
          }
         }
	 else
	  ADPCMSynth.treble_eq(-8.0);
	}
}

static INLINE int32 ADPCM_ClocksToNextEvent(void)
{
 int32 ret = (ADPCM.bigdiv + 65535) >> 16;

 if(ADPCM.WritePending > 0 && ret > ADPCM.WritePending)
  ret = ADPCM.WritePending;

 if(ADPCM.ReadPending > 0 && ret > ADPCM.ReadPending)
  ret = ADPCM.ReadPending;

#if 0
 if(ret < 0)
 {
  printf("%d, %lld %d %d\n", ret, (long long)ADPCM.bigdiv, ADPCM.WritePending, ADPCM.ReadPending);
  assert(ret >= 0);
 }
#endif

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

 if(next_event > pcecd_drive_ne)
  next_event = pcecd_drive_ne;

 if(Fader.Clocked && next_event > Fader.CycleCounter)
  next_event = Fader.CycleCounter;

#if 0
 if(next_event < 0)
 {
  printf("%d, %d %d %d %d\n", next_event, ADPCM_ctne, ClearACKDelay, pcecd_drive_ne, Fader.CycleCounter);
  assert(next_event >= 0);
 }
#endif

 return(next_event);
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
  if(type == PCECD_Drive_IRQ_DATA_TRANSFER_DONE)
   _Port[0x3] &= ~0x20;
  else if(type == PCECD_Drive_IRQ_DATA_TRANSFER_READY)
   _Port[0x3] &= ~0x40;
 }
 else if(type == PCECD_Drive_IRQ_DATA_TRANSFER_DONE)
 {
  _Port[0x3] |= 0x20;
 }
 else if(type == PCECD_Drive_IRQ_DATA_TRANSFER_READY)
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

static INLINE uint8 read_1808(int32 timestamp)
{
 uint8 ret = PCECD_Drive_GetDB();

 if(PCECD_Drive_GetREQ() && !PCECD_Drive_GetACK() && !PCECD_Drive_GetCD())
 {
  if(PCECD_Drive_GetIO())
  {
   PCECD_Drive_SetACK(true);
   ACKStatus = true;
   pcecd_drive_ne = PCECD_Drive_Run(timestamp);
   ClearACKDelay = 15 * 3;
  }
 }

 return(ret);
}

bool PCECD_SetSettings(const PCECD_Settings *settings)
{
	if(settings)
	{
	 assert(settings->CDDA_Volume <= 2.0);
	 assert(settings->ADPCM_Volume <= 2.0);
	}

        CDDAVolumeSetting = settings ? settings->CDDA_Volume : 1.0;
	Fader_SyncWhich();

        ADPCMSynth.volume(0.42735f * (settings ? settings->ADPCM_Volume : 1.0));
        ADPCMLP = settings ? settings->ADPCM_LPF : 0;

	PCECD_Drive_SetTransferRate(126000 * (settings ? settings->CD_Speed : 1));

	return true;
}

void PCECD_Init(const PCECD_Settings *settings, void (*irqcb)(bool), double master_clock, unsigned int ocm, Blip_Buffer* soundbufs)
{
	lastts = 0;

	OC_Multiplier = ocm;

	IRQCB = irqcb;

	sbuf = soundbufs;

	// Warning: magic number 126000 in PCECD_SetSettings() too
	PCECD_Drive_Init(3 * OC_Multiplier, sbuf, 126000 * (settings ? settings->CD_Speed : 1), master_clock * OC_Multiplier, CDIRQ, StuffSubchannel);

        ADPCM.RAM = new uint8[0x10000];

	PCECD_SetSettings(settings);

        ADPCM.bigdivacc = (int64)((double)master_clock * OC_Multiplier * 65536 / 32087.5);
}


void PCECD_Close(void)
{
        if(ADPCM.RAM)
        {
	 delete[] ADPCM.RAM;
         ADPCM.RAM = NULL;
        }
	PCECD_Drive_Close();
}


void PCECD_Power(uint32 timestamp)
{
	if((int32)timestamp != lastts)
 	 (void)PCECD_Run(timestamp);

	IRQCB(0);

	PCECD_Drive_Power(timestamp);
        pcecd_drive_ne = 0x7fffffff;

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
	ADPCM.LPF_SampleFreq = 0;
        ADPCM.bigdiv = ADPCM.bigdivacc * (16 - ADPCM.SampleFreq);
	RedoLPF(ADPCM.LPF_SampleFreq);

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
}

bool PCECD_IsBRAMEnabled(void)
{
	return bBRAMEnabled;
}

MDFN_FASTCALL uint8 PCECD_Read(uint32 timestamp, uint32 A)
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
  PCECD_Run(timestamp);

  switch(A & 0xf)
  {
   case 0x0:
    ret = 0;
    ret |= PCECD_Drive_GetBSY() ? 0x80 : 0x00;
    ret |= PCECD_Drive_GetREQ() ? 0x40 : 0x00;
    ret |= PCECD_Drive_GetMSG() ? 0x20 : 0x00;
    ret |= PCECD_Drive_GetCD() ? 0x10 : 0x00;
    ret |= PCECD_Drive_GetIO() ? 0x08 : 0x00;
    break;

   case 0x1: ret = PCECD_Drive_GetDB();
	     break;

   case 0x2: ret = _Port[2];
	     break;

   case 0x3: bBRAMEnabled = false;

	     /* switch left/right of digitized cd playback */
	     ret = _Port[0x3];
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
     ret = SubChannelFIFO.ReadByte();
    else
     ret = 0x00;	// Not sure if it's 0, 0xFF, the last byte read, or something else.

    if(SubChannelFIFO.CanRead() == 0)
    {
     _Port[0x3] &= ~0x10;
     update_irq_state();
    }
    break;

   case 0x8:
    ret = read_1808(timestamp);
    break;

   case 0xa: 
    ADPCM_DEBUG("ReadBuffer\n");
    ADPCM.ReadPending = 19 * 3; //24 * 3;
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


MDFN_FASTCALL void PCECD_Write(uint32 timestamp, uint32 physAddr, uint8 data)
{
	const uint8 V = data;

	#ifdef PCECD_DEBUG
	printf("Write: (PC=%04x, t=%6d) %04x %02x; MSG: %d, REQ: %d, ACK: %d, CD: %d, IO: %d, BSY: %d, SEL: %d\n", HuCPU.PC, timestamp, physAddr, data, PCECD_Drive_GetMSG(), PCECD_Drive_GetREQ(), PCECD_Drive_GetACK(), PCECD_Drive_GetCD(), PCECD_Drive_GetIO(), PCECD_Drive_GetBSY(), PCECD_Drive_GetSEL());
	#endif

	PCECD_Run(timestamp);

	switch (physAddr & 0xf)
	{
		case 0x0:
			PCECD_Drive_SetSEL(1);
			PCECD_Drive_Run(timestamp);
			PCECD_Drive_SetSEL(0);
			pcecd_drive_ne = PCECD_Drive_Run(timestamp);

			/* reset irq status */
			_Port[0x3] &= ~(0x20 | 0x40);	// TODO: Confirm writing this register really reset these bits.
			update_irq_state();
			break;

		case 0x1:		// $1801
			_Port[1] = data;
			PCECD_Drive_SetDB(data);
			pcecd_drive_ne = PCECD_Drive_Run(timestamp);
			break;

		case 0x2:		// $1802
			#ifdef PCECD_DEBUG
			if(!(_Port[0x3] & _Port[2] & 0x40) && (_Port[0x3] & data & 0x40))
			 puts("IRQ on waah 0x40");
			if(!(_Port[0x3] & _Port[2] & 0x20) && (_Port[0x3] & data & 0x20))
			 puts("IRQ on waah 0x20");
			#endif

			PCECD_Drive_SetACK(data & 0x80);
			pcecd_drive_ne = PCECD_Drive_Run(timestamp);
			_Port[2] = data;
			ACKStatus = (bool)(data & 0x80);
			update_irq_state();
			break;

		case 0x3:		// read only
			break;

		case 0x4:
			PCECD_Drive_SetRST(data & 0x2);
			pcecd_drive_ne = PCECD_Drive_Run(timestamp);
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
 			  PCECD_Drive_GetCDDAValues(left, right);
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
			 Fader.CountValue = OC_Multiplier * 3 * ((V & 0x4) ? 273 : 655);	// 2.500s : 6.000s;

			 if(!Fader.Clocked)
			  Fader.CycleCounter = Fader.CountValue;

			 Fader.Clocked = true;
			}
			Fader_SyncWhich();
			break;
	}
}

static INLINE void ADPCM_PB_Run(int32 basetime, int32 run_time)
{
 ADPCM.bigdiv -= ((int64)run_time << 16);

 while(ADPCM.bigdiv <= 0)
 {
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

  if(ADPCM.Playing)
  {
   int32 pcm;
   uint8 nibble;

   nibble = (ADPCM.PlayBuffer >> (ADPCM.PlayNibble ^ 4)) & 0x0F;
   pcm = MSM5205.Decode(nibble) - 2048;

   ADPCM.PlayNibble ^= 4;

   pcm = (pcm * ADPCMFadeVolume) >> 8;
   uint32 synthtime = ((basetime + (ADPCM.bigdiv >> 16))) / (3 * OC_Multiplier);

   if(sbuf)
   {
    ADPCMSynth.offset(synthtime, pcm - ADPCM.last_pcm, &sbuf[0]);
    ADPCMSynth.offset(synthtime, pcm - ADPCM.last_pcm, &sbuf[1]);
   }
   ADPCM.last_pcm = pcm;
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
   // Run PCECD_Drive before we examine the signals.
   pcecd_drive_ne = PCECD_Drive_Run(timestamp);

   if(!PCECD_Drive_GetCD() && PCECD_Drive_GetIO() && PCECD_Drive_GetREQ() && !PCECD_Drive_GetACK())
   {
    ADPCM.WritePendingValue = read_1808(timestamp);
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

MDFN_FASTCALL void PCECD_Run(uint32 in_timestamp)
{
 int32 clocks = in_timestamp - lastts;
 int32 running_ts = lastts;

 //printf("Run Begin: Clocks=%d(%d - %d), cl=%d\n", clocks, in_timestamp, lastts, CalcNextEvent);
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
    PCECD_Drive_SetACK(false);
    PCECD_Drive_Run(running_ts);
    if(PCECD_Drive_GetCD())
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
  pcecd_drive_ne = PCECD_Drive_Run(running_ts);

  clocks -= chunk_clocks;
 }

 lastts = in_timestamp;
}

void PCECD_ResetTS(void)
{
 if(ADPCM.SampleFreq != ADPCM.LPF_SampleFreq)
 {
  ADPCM.LPF_SampleFreq = ADPCM.SampleFreq;
  RedoLPF(ADPCM.LPF_SampleFreq);
 }
 PCECD_Drive_ResetTS();
 lastts = 0;
}

static int ADPCM_StateAction(StateMem *sm, int load, int data_only)
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

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "APCM");
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
  RedoLPF(ADPCM.SampleFreq);
 }
 return(ret);
}

void PCECD_StateAction(StateMem *sm, int load, int data_only)
{
	SFORMAT StateRegs[] =
	{
	 SFVAR(bBRAMEnabled),
	 SFVAR(ACKStatus),
	 SFVAR(ClearACKDelay),
	 SFPTR16(RawPCMVolumeCache, 2),
	 SFPTR8(_Port, sizeof(_Port)),

	 SFVAR(Fader.Command),
	 SFVAR(Fader.Volume),
	 SFVAR(Fader.CycleCounter),
	 SFVAR(Fader.CountValue),
	 SFVAR(Fader.Clocked),

	 SFPTR8(&SubChannelFIFO.data[0], SubChannelFIFO.data.size()),
	 SFVAR(SubChannelFIFO.read_pos),
	 SFVAR(SubChannelFIFO.write_pos),
	 SFVAR(SubChannelFIFO.in_count),

	 SFVAR(pcecd_drive_ne),

	 SFEND
	};

        MDFNSS_StateAction(sm, load, data_only, StateRegs, "PECD");
	if(load)
	{
	 if(Fader.Clocked && Fader.CycleCounter < 1)
	  Fader.CycleCounter = 1;

	 if(pcecd_drive_ne < 1)
	  pcecd_drive_ne = 1;

	 SubChannelFIFO.SaveStatePostLoad();
	}

	PCECD_Drive_StateAction(sm, load, data_only, "CDRM");
	ADPCM_StateAction(sm, load, data_only);

	if(load)
	{
	 //
	 //
	 Fader_SyncWhich();
	 //PCECD_Drive_SetDB(_Port[1]);
	 PCECD_Drive_SetACK(ACKStatus);
         PCECD_Drive_SetRST(_Port[4] & 0x2);
	}
}

}
