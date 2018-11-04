/***********************************************************************************
  Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.

  (c) Copyright 1996 - 2002  Gary Henderson (gary.henderson@ntlworld.com),
                             Jerremy Koot (jkoot@snes9x.com)

  (c) Copyright 2002 - 2004  Matthew Kendora

  (c) Copyright 2002 - 2005  Peter Bortas (peter@bortas.org)

  (c) Copyright 2004 - 2005  Joel Yliluoma (http://iki.fi/bisqwit/)

  (c) Copyright 2001 - 2006  John Weidman (jweidman@slip.net)

  (c) Copyright 2002 - 2006  funkyass (funkyass@spam.shaw.ca),
                             Kris Bleakley (codeviolation@hotmail.com)

  (c) Copyright 2002 - 2010  Brad Jorsch (anomie@users.sourceforge.net),
                             Nach (n-a-c-h@users.sourceforge.net),

  (c) Copyright 2002 - 2011  zones (kasumitokoduck@yahoo.com)

  (c) Copyright 2006 - 2007  nitsuja

  (c) Copyright 2009 - 2018  BearOso,
                             OV2

  (c) Copyright 2017         qwertymodo

  (c) Copyright 2011 - 2017  Hans-Kristian Arntzen,
                             Daniel De Matteis
                             (Under no circumstances will commercial rights be given)


  BS-X C emulator code
  (c) Copyright 2005 - 2006  Dreamer Nom,
                             zones

  C4 x86 assembler and some C emulation code
  (c) Copyright 2000 - 2003  _Demo_ (_demo_@zsnes.com),
                             Nach,
                             zsKnight (zsknight@zsnes.com)

  C4 C++ code
  (c) Copyright 2003 - 2006  Brad Jorsch,
                             Nach

  DSP-1 emulator code
  (c) Copyright 1998 - 2006  _Demo_,
                             Andreas Naive (andreasnaive@gmail.com),
                             Gary Henderson,
                             Ivar (ivar@snes9x.com),
                             John Weidman,
                             Kris Bleakley,
                             Matthew Kendora,
                             Nach,
                             neviksti (neviksti@hotmail.com)

  DSP-2 emulator code
  (c) Copyright 2003         John Weidman,
                             Kris Bleakley,
                             Lord Nightmare (lord_nightmare@users.sourceforge.net),
                             Matthew Kendora,
                             neviksti

  DSP-3 emulator code
  (c) Copyright 2003 - 2006  John Weidman,
                             Kris Bleakley,
                             Lancer,
                             z80 gaiden

  DSP-4 emulator code
  (c) Copyright 2004 - 2006  Dreamer Nom,
                             John Weidman,
                             Kris Bleakley,
                             Nach,
                             z80 gaiden

  OBC1 emulator code
  (c) Copyright 2001 - 2004  zsKnight,
                             pagefault (pagefault@zsnes.com),
                             Kris Bleakley
                             Ported from x86 assembler to C by sanmaiwashi

  SPC7110 and RTC C++ emulator code used in 1.39-1.51
  (c) Copyright 2002         Matthew Kendora with research by
                             zsKnight,
                             John Weidman,
                             Dark Force

  SPC7110 and RTC C++ emulator code used in 1.52+
  (c) Copyright 2009         byuu,
                             neviksti

  S-DD1 C emulator code
  (c) Copyright 2003         Brad Jorsch with research by
                             Andreas Naive,
                             John Weidman

  S-RTC C emulator code
  (c) Copyright 2001 - 2006  byuu,
                             John Weidman

  ST010 C++ emulator code
  (c) Copyright 2003         Feather,
                             John Weidman,
                             Kris Bleakley,
                             Matthew Kendora

  Super FX x86 assembler emulator code
  (c) Copyright 1998 - 2003  _Demo_,
                             pagefault,
                             zsKnight

  Super FX C emulator code
  (c) Copyright 1997 - 1999  Ivar,
                             Gary Henderson,
                             John Weidman

  Sound emulator code used in 1.5-1.51
  (c) Copyright 1998 - 2003  Brad Martin
  (c) Copyright 1998 - 2006  Charles Bilyue'

  Sound emulator code used in 1.52+
  (c) Copyright 2004 - 2007  Shay Green (gblargg@gmail.com)

  S-SMP emulator code used in 1.54+
  (c) Copyright 2016         byuu

  SH assembler code partly based on x86 assembler code
  (c) Copyright 2002 - 2004  Marcus Comstedt (marcus@mc.pp.se)

  2xSaI filter
  (c) Copyright 1999 - 2001  Derek Liauw Kie Fa

  HQ2x, HQ3x, HQ4x filters
  (c) Copyright 2003         Maxim Stepin (maxim@hiend3d.com)

  NTSC filter
  (c) Copyright 2006 - 2007  Shay Green

  GTK+ GUI code
  (c) Copyright 2004 - 2018  BearOso

  Win32 GUI code
  (c) Copyright 2003 - 2006  blip,
                             funkyass,
                             Matthew Kendora,
                             Nach,
                             nitsuja
  (c) Copyright 2009 - 2018  OV2

  Mac OS GUI code
  (c) Copyright 1998 - 2001  John Stiles
  (c) Copyright 2001 - 2011  zones

  Libretro port
  (c) Copyright 2011 - 2017  Hans-Kristian Arntzen,
                             Daniel De Matteis
                             (Under no circumstances will commercial rights be given)


  Specific ports contains the works of other authors. See headers in
  individual files.


  Snes9x homepage: http://www.snes9x.com/

  Permission to use, copy, modify and/or distribute Snes9x in both binary
  and source form, for non-commercial purposes, is hereby granted without
  fee, providing that this license information and copyright notice appear
  with all copies and any derived work.

  This software is provided 'as-is', without any express or implied
  warranty. In no event shall the authors be held liable for any damages
  arising from the use of this software or it's derivatives.

  Snes9x is freeware for PERSONAL USE only. Commercial users should
  seek permission of the copyright holders first. Commercial use includes,
  but is not limited to, charging money for Snes9x or software derived from
  Snes9x, including Snes9x or derivatives in commercial game bundles, and/or
  using Snes9x as a promotion for your commercial product.

  The copyright holders request that bug fixes and improvements to the code
  should be forwarded to them so everyone can benefit from the modifications
  in future versions.

  Super NES and Super Nintendo Entertainment System are trademarks of
  Nintendo Co., Limited and its subsidiary companies.
 ***********************************************************************************/

#include <math.h>
#include "snes9x.h"
#include "apu.h"
#include "msu1.h"
#include "snapshot.h"
#include "display.h"
#include "hermite_resampler.h"

#include "snes/snes.hpp"

#define APU_DEFAULT_INPUT_RATE		31950 // ~ 59.94Hz
#define APU_MINIMUM_SAMPLE_COUNT	512
#define APU_MINIMUM_SAMPLE_BLOCK	128
#define APU_NUMERATOR_NTSC			15664
#define APU_DENOMINATOR_NTSC		328125
#define APU_NUMERATOR_PAL			34176
#define APU_DENOMINATOR_PAL			709379

namespace SNES
{
#include "bapu/dsp/blargg_endian.h"

	CPU	cpu;
}

namespace spc
{
	static apu_callback	sa_callback     = NULL;
	static void			*extra_data     = NULL;

	static bool8		sound_in_sync   = TRUE;
	static bool8		sound_enabled   = FALSE;

	static int			buffer_size;
	static int			lag_master      = 0;
	static int			lag             = 0;

	static uint8		*landing_buffer = NULL;
	static uint8		*shrink_buffer  = NULL;

	static Resampler	*resampler      = NULL;

	static int32		reference_time;
	static uint32		remainder;

	static const int	timing_hack_numerator   = 256;
	static int			timing_hack_denominator = 256;
	/* Set these to NTSC for now. Will change to PAL in S9xAPUTimingSetSpeedup
	   if necessary on game load. */
	static uint32		ratio_numerator = APU_NUMERATOR_NTSC;
	static uint32		ratio_denominator = APU_DENOMINATOR_NTSC;

	static double		dynamic_rate_multiplier = 1.0;
}

namespace msu
{
	static int			buffer_size;
	static uint8		*landing_buffer = NULL;
	static Resampler	*resampler		= NULL;
	static int			resample_buffer_size	= -1;
	static uint8		*resample_buffer		= NULL;
}

static void EightBitize (uint8 *, int);
static void DeStereo (uint8 *, int);
static void ReverseStereo (uint8 *, int);
static void UpdatePlaybackRate (void);
static void SPCSnapshotCallback (void);
static inline int S9xAPUGetClock (int32);
static inline int S9xAPUGetClockRemainder (int32);


static void EightBitize (uint8 *buffer, int sample_count)
{
	uint8	*buf8  = (uint8 *) buffer;
	int16	*buf16 = (int16 *) buffer;

	for (int i = 0; i < sample_count; i++)
		buf8[i] = (uint8) ((buf16[i] / 256) + 128);
}

static void DeStereo (uint8 *buffer, int sample_count)
{
	int16	*buf = (int16 *) buffer;
	int32	s1, s2;

	for (int i = 0; i < (sample_count >> 1); i++)
	{
		s1 = (int32) buf[2 * i];
		s2 = (int32) buf[2 * i + 1];
		buf[i] = (int16) ((s1 + s2) >> 1);
	}
}

static void ReverseStereo (uint8 *src_buffer, int sample_count)
{
	int16	*buffer = (int16 *) src_buffer;

	for (int i = 0; i < sample_count; i += 2)
	{
		buffer[i + 1] ^= buffer[i];
		buffer[i] ^= buffer[i + 1];
		buffer[i + 1] ^= buffer[i];
	}
}

bool8 S9xMixSamples (uint8 *buffer, int sample_count)
{
	static int	shrink_buffer_size = -1;
	uint8		*dest;

	if (!Settings.SixteenBitSound || !Settings.Stereo)
	{
		/* We still need both stereo samples for generating the mono sample */
		if (!Settings.Stereo)
			sample_count <<= 1;

		/* We still have to generate 16-bit samples for bit-dropping, too */
		if (shrink_buffer_size < (sample_count << 1))
		{
			delete[] spc::shrink_buffer;
			spc::shrink_buffer = new uint8[sample_count << 1];
			shrink_buffer_size = sample_count << 1;
		}

		dest = spc::shrink_buffer;
	}
	else
		dest = buffer;

	if (Settings.MSU1 && msu::resample_buffer_size < (sample_count << 1))
	{
		delete[] msu::resample_buffer;
		msu::resample_buffer = new uint8[sample_count << 1];
		msu::resample_buffer_size = sample_count << 1;
	}

	if (Settings.Mute)
	{
		memset(dest, 0, sample_count << 1);
		spc::resampler->clear();

		if(Settings.MSU1)
			msu::resampler->clear();

		return (FALSE);
	}
	else
	{
		if (spc::resampler->avail() >= (sample_count + spc::lag))
		{
			spc::resampler->read((short *) dest, sample_count);
			if (spc::lag == spc::lag_master)
				spc::lag = 0;

			if (Settings.MSU1)
			{
				if (msu::resampler->avail() >= sample_count)
				{
					msu::resampler->read((short *)msu::resample_buffer, sample_count);
					for (int i = 0; i < sample_count; ++i)
						*((int16*)(dest+(i * 2))) += *((int16*)(msu::resample_buffer +(i * 2)));
				}
				else // should never occur
					assert(0);
			}
		}
		else
		{
			memset(buffer, (Settings.SixteenBitSound ? 0 : 128), (sample_count << (Settings.SixteenBitSound ? 1 : 0)) >> (Settings.Stereo ? 0 : 1));
			if (spc::lag == 0)
				spc::lag = spc::lag_master;

			return (FALSE);
		}
	}

	if (Settings.ReverseStereo && Settings.Stereo)
		ReverseStereo(dest, sample_count);

	if (!Settings.Stereo || !Settings.SixteenBitSound)
	{
		if (!Settings.Stereo)
		{
			DeStereo(dest, sample_count);
			sample_count >>= 1;
		}

		if (!Settings.SixteenBitSound)
			EightBitize(dest, sample_count);

		memcpy(buffer, dest, (sample_count << (Settings.SixteenBitSound ? 1 : 0)));
	}

	return (TRUE);
}

int S9xGetSampleCount (void)
{
	return (spc::resampler->avail() >> (Settings.Stereo ? 0 : 1));
}

/* TODO: Attach */
void S9xFinalizeSamples (void)
{
	bool drop_current_msu1_samples = true;

	if (!Settings.Mute)
	{
		drop_current_msu1_samples = false;

		if (!spc::resampler->push((short *)spc::landing_buffer, SNES::dsp.spc_dsp.sample_count()))
		{
			/* We weren't able to process the entire buffer. Potential overrun. */
			spc::sound_in_sync = FALSE;

			if (Settings.SoundSync && !Settings.TurboMode)
				return;

			// since we drop the current dsp samples we also want to drop generated msu1 samples
			drop_current_msu1_samples = true;
		}
	}

	// only generate msu1 if we really consumed the dsp samples (sample_count() resets at end of function),
	// otherwise we will generate multiple times for the same samples - so this needs to be after all early
	// function returns
	if (Settings.MSU1)
	{
		// generate the same number of msu1 samples as dsp samples were generated
		S9xMSU1SetOutput((int16 *)msu::landing_buffer, msu::buffer_size);
		S9xMSU1Generate(SNES::dsp.spc_dsp.sample_count());
		if (!drop_current_msu1_samples && !msu::resampler->push((short *)msu::landing_buffer, S9xMSU1Samples()))
		{
			// should not occur, msu buffer is larger and we drop msu samples if spc buffer overruns
			assert(0);
		}
	}


	if (!Settings.SoundSync || Settings.TurboMode || Settings.Mute)
		spc::sound_in_sync = TRUE;
	else
	if (spc::resampler->space_empty() >= spc::resampler->space_filled())
		spc::sound_in_sync = TRUE;
	else
		spc::sound_in_sync = FALSE;

	SNES::dsp.spc_dsp.set_output((SNES::SPC_DSP::sample_t *) spc::landing_buffer, spc::buffer_size);
}

void S9xLandSamples (void)
{
	if (spc::sa_callback != NULL)
		spc::sa_callback(spc::extra_data);
	else
		S9xFinalizeSamples();
}

void S9xClearSamples (void)
{
	spc::resampler->clear();
	if (Settings.MSU1)
		msu::resampler->clear();
	spc::lag = spc::lag_master;
}

bool8 S9xSyncSound (void)
{
	if (!Settings.SoundSync || spc::sound_in_sync)
		return (TRUE);

	S9xLandSamples();

	return (spc::sound_in_sync);
}

void S9xSetSamplesAvailableCallback (apu_callback callback, void *data)
{
	spc::sa_callback = callback;
	spc::extra_data  = data;
}

void S9xUpdateDynamicRate (int avail, int buffer_size)
{
	spc::dynamic_rate_multiplier = 1.0 + (Settings.DynamicRateLimit * (buffer_size - 2 * avail)) /
					(double)(1000 * buffer_size);

	UpdatePlaybackRate();
}

static void UpdatePlaybackRate (void)
{
	if (Settings.SoundInputRate == 0)
		Settings.SoundInputRate = APU_DEFAULT_INPUT_RATE;

	double time_ratio = (double) Settings.SoundInputRate * spc::timing_hack_numerator / (Settings.SoundPlaybackRate * spc::timing_hack_denominator);

	if (Settings.DynamicRateControl)
	{
		time_ratio *= spc::dynamic_rate_multiplier;
	}

	spc::resampler->time_ratio(time_ratio);

	if (Settings.MSU1)
	{
		time_ratio = (44100.0 / Settings.SoundPlaybackRate) * (Settings.SoundInputRate / 32040.0);
		msu::resampler->time_ratio(time_ratio);
	}
}

bool8 S9xInitSound (int buffer_ms, int lag_ms)
{
	// buffer_ms : buffer size given in millisecond
	// lag_ms    : allowable time-lag given in millisecond

	int	sample_count     = buffer_ms * 32040 / 1000;
	int	lag_sample_count = lag_ms    * 32040 / 1000;

	spc::lag_master = lag_sample_count;
	if (Settings.Stereo)
		spc::lag_master <<= 1;
	spc::lag = spc::lag_master;

	if (sample_count < APU_MINIMUM_SAMPLE_COUNT)
		sample_count = APU_MINIMUM_SAMPLE_COUNT;

	spc::buffer_size = sample_count << 2;
	msu::buffer_size = (int)((sample_count << 2) * 1.5); // Always 16-bit, Stereo; 1.5 to never overflow before dsp buffer

	printf("Sound buffer size: %d (%d samples)\n", spc::buffer_size, sample_count);

	if (spc::landing_buffer)
		delete[] spc::landing_buffer;
	spc::landing_buffer = new uint8[spc::buffer_size * 2];
	if (!spc::landing_buffer)
		return (FALSE);
	if (msu::landing_buffer)
		delete[] msu::landing_buffer;
	msu::landing_buffer = new uint8[msu::buffer_size * 2];
	if (!msu::landing_buffer)
		return (FALSE);

	/* The resampler and spc unit use samples (16-bit short) as
	   arguments. Use 2x in the resampler for buffer leveling with SoundSync */
	if (!spc::resampler)
	{
		spc::resampler = new HermiteResampler(spc::buffer_size >> (Settings.SoundSync ? 0 : 1));
		if (!spc::resampler)
		{
			delete[] spc::landing_buffer;
			return (FALSE);
		}
	}
	else
		spc::resampler->resize(spc::buffer_size >> (Settings.SoundSync ? 0 : 1));


	if (!msu::resampler)
	{
		msu::resampler = new HermiteResampler(msu::buffer_size);
		if (!msu::resampler)
		{
			delete[] msu::landing_buffer;
			return (FALSE);
		}
	}
	else
		msu::resampler->resize(msu::buffer_size);


	SNES::dsp.spc_dsp.set_output ((SNES::SPC_DSP::sample_t *) spc::landing_buffer, spc::buffer_size);

	UpdatePlaybackRate();

	spc::sound_enabled = S9xOpenSoundDevice();

	return (spc::sound_enabled);
}

void S9xSetSoundControl (uint8 voice_switch)
{
	SNES::dsp.spc_dsp.set_stereo_switch (voice_switch << 8 | voice_switch);
}

void S9xSetSoundMute (bool8 mute)
{
	Settings.Mute = mute;
	if (!spc::sound_enabled)
		Settings.Mute = TRUE;
}

void S9xDumpSPCSnapshot (void)
{
	SNES::dsp.spc_dsp.dump_spc_snapshot();

}

static void SPCSnapshotCallback (void)
{
	S9xSPCDump(S9xGetFilenameInc((".spc"), SPC_DIR));
	printf("Dumped key-on triggered spc snapshot.\n");
}

bool8 S9xInitAPU (void)
{
	spc::landing_buffer = NULL;
	spc::shrink_buffer  = NULL;
	spc::resampler      = NULL;
	msu::resampler		= NULL;

	return (TRUE);
}

void S9xDeinitAPU (void)
{
	if (spc::resampler)
	{
		delete spc::resampler;
		spc::resampler = NULL;
	}

	if (spc::landing_buffer)
	{
		delete[] spc::landing_buffer;
		spc::landing_buffer = NULL;
	}

	if (spc::shrink_buffer)
	{
		delete[] spc::shrink_buffer;
		spc::shrink_buffer = NULL;
	}

	if (msu::resampler)
	{
		delete msu::resampler;
		msu::resampler = NULL;
	}

	if (msu::landing_buffer)
	{
		delete[] msu::landing_buffer;
		msu::landing_buffer = NULL;
	}

	if (msu::resample_buffer)
	{
		delete[] msu::resample_buffer;
		msu::resample_buffer = NULL;
	}

	S9xMSU1DeInit();
}

static inline int S9xAPUGetClock (int32 cpucycles)
{
	return (spc::ratio_numerator * (cpucycles - spc::reference_time) + spc::remainder) /
			spc::ratio_denominator;
}

static inline int S9xAPUGetClockRemainder (int32 cpucycles)
{
	return (spc::ratio_numerator * (cpucycles - spc::reference_time) + spc::remainder) %
			spc::ratio_denominator;
}

uint8 S9xAPUReadPort (int port)
{
	S9xAPUExecute ();
	return ((uint8) SNES::smp.port_read (port & 3));
}

void S9xAPUWritePort (int port, uint8 byte)
{
	S9xAPUExecute ();
	SNES::cpu.port_write (port & 3, byte);
}

void S9xAPUSetReferenceTime (int32 cpucycles)
{
	spc::reference_time = cpucycles;
}

void S9xAPUExecute (void)
{
	SNES::smp.clock -= S9xAPUGetClock (CPU.Cycles);
	SNES::smp.enter ();

	spc::remainder = S9xAPUGetClockRemainder(CPU.Cycles);

	S9xAPUSetReferenceTime(CPU.Cycles);
}

void S9xAPUEndScanline (void)
{
	S9xAPUExecute();
	SNES::dsp.synchronize();

	if (SNES::dsp.spc_dsp.sample_count() >= APU_MINIMUM_SAMPLE_BLOCK || !spc::sound_in_sync)
		S9xLandSamples();
}

void S9xAPUTimingSetSpeedup (int ticks)
{
	if (ticks != 0)
		printf("APU speedup hack: %d\n", ticks);

	spc::timing_hack_denominator = 256 - ticks;

	spc::ratio_numerator = Settings.PAL ? APU_NUMERATOR_PAL : APU_NUMERATOR_NTSC;
	spc::ratio_denominator = Settings.PAL ? APU_DENOMINATOR_PAL : APU_DENOMINATOR_NTSC;
	spc::ratio_denominator = spc::ratio_denominator * spc::timing_hack_denominator / spc::timing_hack_numerator;

	UpdatePlaybackRate();
}

void S9xResetAPU (void)
{
	spc::reference_time = 0;
	spc::remainder = 0;

	SNES::cpu.reset ();
	SNES::cpu.frequency = Settings.PAL ? PAL_MASTER_CLOCK : NTSC_MASTER_CLOCK;
	SNES::smp.power ();
	SNES::dsp.power ();
	SNES::dsp.spc_dsp.set_output ((SNES::SPC_DSP::sample_t *) spc::landing_buffer, spc::buffer_size >> 1);
	SNES::dsp.spc_dsp.set_spc_snapshot_callback(SPCSnapshotCallback);

	spc::resampler->clear();

	if (Settings.MSU1)
		msu::resampler->clear();
}

void S9xSoftResetAPU (void)
{
	spc::reference_time = 0;
	spc::remainder = 0;
	SNES::cpu.reset ();
	SNES::smp.reset ();
	SNES::dsp.reset ();
	SNES::dsp.spc_dsp.set_output ((SNES::SPC_DSP::sample_t *) spc::landing_buffer, spc::buffer_size >> 1);

	spc::resampler->clear();

	if (Settings.MSU1)
		msu::resampler->clear();
}

void S9xAPUSaveState (uint8 *block)
{
	uint8	*ptr = block;

	SNES::smp.save_state (&ptr);
	SNES::dsp.save_state (&ptr);

	SNES::set_le32(ptr, spc::reference_time);
	ptr += sizeof(int32);
	SNES::set_le32(ptr, spc::remainder);
	ptr += sizeof(int32);
	SNES::set_le32(ptr, SNES::dsp.clock);
	ptr += sizeof(int32);
	memcpy (ptr, SNES::cpu.registers, 4);
	ptr += sizeof(int32);

	memset (ptr, 0, SPC_SAVE_STATE_BLOCK_SIZE-(ptr-block));
}

void S9xAPULoadState (uint8 *block)
{
	uint8	*ptr = block;

	SNES::smp.load_state (&ptr);
	SNES::dsp.load_state (&ptr);

	spc::reference_time = SNES::get_le32(ptr);
	ptr += sizeof(int32);
	spc::remainder = SNES::get_le32(ptr);
	ptr += sizeof(int32);
	SNES::dsp.clock = SNES::get_le32(ptr);
	ptr += sizeof(int32);
	memcpy (SNES::cpu.registers, ptr, 4);
}

static void to_var_from_buf (uint8 **buf, void *var, size_t size)
{
  memcpy(var, *buf, size);
  *buf += size;
}

#undef IF_0_THEN_256
#define IF_0_THEN_256( n ) ((uint8_t) ((n) - 1) + 1)
void S9xAPULoadBlarggState(uint8 *oldblock)
{
    uint8	*ptr = oldblock;

    SNES::SPC_State_Copier copier(&ptr,to_var_from_buf);

    copier.copy(SNES::smp.apuram,0x10000); // RAM

    uint8_t regs_in [0x10];
    uint8_t regs [0x10];
    uint16_t pc, spc_time, dsp_time;
    uint8_t a,x,y,psw,sp;

    copier.copy(regs,0x10); // REGS
    copier.copy(regs_in,0x10); // REGS_IN

    // CPU Regs
    pc = copier.copy_int( 0, sizeof(uint16_t) );
    a = copier.copy_int( 0, sizeof(uint8_t) );
    x = copier.copy_int( 0, sizeof(uint8_t) );
    y = copier.copy_int( 0, sizeof(uint8_t) );
    psw = copier.copy_int( 0, sizeof(uint8_t) );
    sp = copier.copy_int( 0, sizeof(uint8_t) );
    copier.extra();

    // times
    spc_time = copier.copy_int( 0, sizeof(uint16_t) );
    dsp_time = copier.copy_int( 0, sizeof(uint16_t) );

    int cur_time = S9xAPUGetClock(CPU.Cycles);

    // spc_time is absolute, dsp_time is relative
    // smp.clock is relative, dsp.clock relative but counting upwards
    SNES::smp.clock = spc_time - cur_time;
    SNES::dsp.clock = -1 * dsp_time;

    // DSP
    SNES::dsp.load_state(&ptr);

    // Timers
    uint16_t next_time[3];
    uint8_t divider[3], counter[3];
    for ( int i = 0; i < 3; i++ )
    {
	    next_time[i] = copier.copy_int( 0, sizeof(uint16_t) );
	    divider[i] = copier.copy_int( 0, sizeof(uint8_t) );
	    counter[i] = copier.copy_int( 0, sizeof(uint8_t) );
	    copier.extra();
    }
    // construct timers out of available parts from blargg smp
    SNES::smp.timer0.enable = regs[1] >> 0 & 1;                 // regs[1] = CONTROL
    SNES::smp.timer0.target = IF_0_THEN_256(regs[10]);          // regs[10+i] = TiTARGET
    // blargg counts time, get ticks through timer frequency
    // (assume tempo = 256)
    SNES::smp.timer0.stage1_ticks = 128 - (next_time[0] - cur_time) / 128;
    SNES::smp.timer0.stage2_ticks = divider[0];
    SNES::smp.timer0.stage3_ticks = counter[0];

    SNES::smp.timer1.enable = regs[1] >> 1 & 1;
    SNES::smp.timer1.target = IF_0_THEN_256(regs[11]);
    SNES::smp.timer1.stage1_ticks = 128 - (next_time[1] - cur_time) / 128;
    SNES::smp.timer1.stage2_ticks = divider[0];
    SNES::smp.timer1.stage3_ticks = counter[0];

    SNES::smp.timer2.enable = regs[1] >> 2 & 1;
    SNES::smp.timer2.target = IF_0_THEN_256(regs[12]);
    SNES::smp.timer2.stage1_ticks = 16 - (next_time[2] - cur_time) / 16;
    SNES::smp.timer2.stage2_ticks = divider[0];
    SNES::smp.timer2.stage3_ticks = counter[0];

    copier.extra();

    SNES::smp.opcode_number = 0;
    SNES::smp.opcode_cycle = 0;

    SNES::smp.regs.pc = pc;
    SNES::smp.regs.sp = sp;
    SNES::smp.regs.B.a = a;
    SNES::smp.regs.x = x;
    SNES::smp.regs.B.y = y;

    // blargg's psw has same layout as byuu's flags
    SNES::smp.regs.p = psw;

    // blargg doesn't explicitly store iplrom_enable
    SNES::smp.status.iplrom_enable = regs[1] & 0x80;

    SNES::smp.status.dsp_addr = regs[2];

    SNES::smp.status.ram00f8 = regs_in[8];
    SNES::smp.status.ram00f9 = regs_in[9];

    // default to 0 - we are on an opcode boundary, shouldn't matter
    SNES::smp.rd=SNES::smp.wr=SNES::smp.dp=SNES::smp.sp=SNES::smp.ya=SNES::smp.bit=0;

    spc::reference_time = SNES::get_le32(ptr);
    ptr += sizeof(int32);
    spc::remainder = SNES::get_le32(ptr);

    // blargg stores CPUIx in regs_in
    memcpy (SNES::cpu.registers, regs_in + 4, 4);
}

bool8 S9xSPCDump (const char *filename)
{
	FILE	*fs;
	uint8	buf[SPC_FILE_SIZE];
	size_t	ignore;

	fs = fopen(filename, "wb");
	if (!fs)
		return (FALSE);

	S9xSetSoundMute(TRUE);

	SNES::smp.save_spc (buf);

	ignore = fwrite (buf, SPC_FILE_SIZE, 1, fs);

	if (ignore == 0)
	{
		fprintf (stderr, "Couldn't write file %s.\n", filename);
	}

	fclose(fs);

	S9xSetSoundMute(FALSE);

	return (TRUE);
}
