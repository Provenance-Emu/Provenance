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

  MSU-1 code
  (c) Copyright 2016         qwertymodo


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

#include "snes9x.h"
#include "memmap.h"
#include "display.h"
#include "msu1.h"
#include "apu/bapu/dsp/blargg_endian.h"
#include <fstream>
#include <sys/stat.h>

STREAM dataStream = NULL;
STREAM audioStream = NULL;
uint32 audioLoopPos;
size_t partial_frames;

// Sample buffer
int16 *bufPos, *bufBegin, *bufEnd;

#ifdef UNZIP_SUPPORT
static int unzFindExtension(unzFile &file, const char *ext, bool restart = TRUE, bool print = TRUE, bool allowExact = FALSE)
{
    unz_file_info	info;
    int				port, l = strlen(ext), e = allowExact ? 0 : 1;

    if (restart)
        port = unzGoToFirstFile(file);
    else
        port = unzGoToNextFile(file);

    while (port == UNZ_OK)
    {
        int		len;
        char	name[132];

        unzGetCurrentFileInfo(file, &info, name, 128, NULL, 0, NULL, 0);
        len = strlen(name);

        if (len >= l + e && strcasecmp(name + len - l, ext) == 0 && unzOpenCurrentFile(file) == UNZ_OK)
        {
            if (print)
                printf("Using msu file %s", name);

            return (port);
        }

        port = unzGoToNextFile(file);
    }

    return (port);
}
#endif

STREAM S9xMSU1OpenFile(const char *msu_ext, bool skip_unpacked)
{
    const char *filename = S9xGetFilename(msu_ext, ROMFILENAME_DIR);
	STREAM file = 0;

	if (!skip_unpacked)
	{
		file = OPEN_STREAM(filename, "rb");
		if (file)
			printf("Using msu file %s.\n", filename);
	}

#ifdef UNZIP_SUPPORT
    // look for msu1 pack file in the rom or patch dir if msu data file not found in rom dir
    if (!file)
    {
        const char *zip_filename = S9xGetFilename(".msu1", ROMFILENAME_DIR);
		unzFile	unzFile = unzOpen(zip_filename);

		if (!unzFile)
		{
			zip_filename = S9xGetFilename(".msu1", PATCH_DIR);
			unzFile = unzOpen(zip_filename);
		}

        if (unzFile)
        {
            int	port = unzFindExtension(unzFile, msu_ext, true, true, true);
            if (port == UNZ_OK)
            {
                printf(" in %s.\n", zip_filename);
                file = new unzStream(unzFile);
            }
            else
                unzClose(unzFile);
        }
    }
#endif

    return file;
}

static void AudioClose()
{
	if (audioStream)
	{
		CLOSE_STREAM(audioStream);
		audioStream = NULL;
	}
}

static bool AudioOpen()
{
	MSU1.MSU1_STATUS |= AudioError;

	AudioClose();

	char ext[_MAX_EXT];
	snprintf(ext, _MAX_EXT, "-%d.pcm", MSU1.MSU1_CURRENT_TRACK);

    audioStream = S9xMSU1OpenFile(ext);
	if (audioStream)
	{
		if (GETC_STREAM(audioStream) != 'M')
			return false;
		if (GETC_STREAM(audioStream) != 'S')
			return false;
		if (GETC_STREAM(audioStream) != 'U')
			return false;
		if (GETC_STREAM(audioStream) != '1')
			return false;

        READ_STREAM((char *)&audioLoopPos, 4, audioStream);
		audioLoopPos = GET_LE32(&audioLoopPos);
		audioLoopPos <<= 2;
		audioLoopPos += 8;

        MSU1.MSU1_AUDIO_POS = 8;

		MSU1.MSU1_STATUS &= ~AudioError;
		return true;
	}

	return false;
}

static void DataClose()
{
	if (dataStream)
	{
		CLOSE_STREAM(dataStream);
		dataStream = NULL;
	}
}

static bool DataOpen()
{
	DataClose();

    dataStream = S9xMSU1OpenFile(".msu");

	if(!dataStream)
		dataStream = S9xMSU1OpenFile("msu1.rom");

	return dataStream != NULL;
}

void S9xResetMSU(void)
{
	MSU1.MSU1_STATUS		= 0;
	MSU1.MSU1_DATA_SEEK		= 0;
	MSU1.MSU1_DATA_POS		= 0;
	MSU1.MSU1_TRACK_SEEK	= 0;
	MSU1.MSU1_CURRENT_TRACK = 0;
	MSU1.MSU1_RESUME_TRACK	= 0;
	MSU1.MSU1_VOLUME		= 0;
	MSU1.MSU1_CONTROL		= 0;
	MSU1.MSU1_AUDIO_POS		= 0;
	MSU1.MSU1_RESUME_POS	= 0;


	bufPos				= 0;
	bufBegin			= 0;
	bufEnd				= 0;

	partial_frames = 0;

	DataClose();

	AudioClose();

	Settings.MSU1 = S9xMSU1ROMExists();
}

void S9xMSU1Init(void)
{
	DataOpen();
}

void S9xMSU1DeInit(void)
{
	DataClose();
	AudioClose();
}

bool S9xMSU1ROMExists(void)
{
    STREAM s = S9xMSU1OpenFile(".msu");
	if (s)
	{
		CLOSE_STREAM(s);
		return true;
	}
#ifdef UNZIP_SUPPORT
	char drive[_MAX_DRIVE + 1], dir[_MAX_DIR + 1], def[_MAX_FNAME + 1], ext[_MAX_EXT + 1];
	_splitpath(Memory.ROMFilename, drive, dir, def, ext);
	if (!strcasecmp(ext, ".msu1"))
		return true;

	unzFile unzFile = unzOpen(S9xGetFilename(".msu1", ROMFILENAME_DIR));

	if(!unzFile)
		unzFile = unzOpen(S9xGetFilename(".msu1", PATCH_DIR));

	if (unzFile)
	{
		unzClose(unzFile);
		return true;
	}
#endif
    return false;
}

void S9xMSU1Generate(size_t sample_count)
{
	partial_frames += 4410 * (sample_count / 2);

	while ((bufPos < (bufEnd - 2)) && partial_frames >= 3204)
	{
		if (MSU1.MSU1_STATUS & AudioPlaying && audioStream)
		{
			int32 sample;
			int16* left = (int16*)&sample;
			int16* right = left + 1;

			int bytes_read = READ_STREAM((char *)&sample, 4, audioStream);
			if (bytes_read == 4)
			{
				*left = ((int32)(int16)GET_LE16(left) * MSU1.MSU1_VOLUME / 255);
				*right = ((int32)(int16)GET_LE16(right) * MSU1.MSU1_VOLUME / 255);


				*(bufPos++) = *left;
				*(bufPos++) = *right;
				MSU1.MSU1_AUDIO_POS += 4;
				partial_frames -= 3204;
			}
			else
			if (bytes_read >= 0)
			{
				if (MSU1.MSU1_STATUS & AudioRepeating)
				{
					MSU1.MSU1_AUDIO_POS = audioLoopPos;
					REVERT_STREAM(audioStream, MSU1.MSU1_AUDIO_POS, 0);
				}
				else
				{
					MSU1.MSU1_STATUS &= ~(AudioPlaying | AudioRepeating);
					REVERT_STREAM(audioStream, 8, 0);
				}
			}
			else
			{
				MSU1.MSU1_STATUS &= ~(AudioPlaying | AudioRepeating);
			}
		}
		else
		{
			MSU1.MSU1_STATUS &= ~(AudioPlaying | AudioRepeating);
			partial_frames -= 3204;
			*(bufPos++) = 0;
			*(bufPos++) = 0;
		}
	}
}


uint8 S9xMSU1ReadPort(uint8 port)
{
	switch (port)
	{
	case 0:
		return MSU1.MSU1_STATUS | MSU1_REVISION;
	case 1:
    {
        if (MSU1.MSU1_STATUS & DataBusy)
            return 0;
        if (!dataStream)
            return 0;
        int data = GETC_STREAM(dataStream);
        if (data >= 0)
        {
            MSU1.MSU1_DATA_POS++;
            return data;
        }
        return 0;
    }
	case 2:
		return 'S';
	case 3:
		return '-';
	case 4:
		return 'M';
	case 5:
		return 'S';
	case 6:
		return 'U';
	case 7:
		return '1';
	}

	return 0;
}


void S9xMSU1WritePort(uint8 port, uint8 byte)
{
	switch (port)
	{
	case 0:
		MSU1.MSU1_DATA_SEEK &= 0xFFFFFF00;
		MSU1.MSU1_DATA_SEEK |= byte << 0;
		break;
	case 1:
		MSU1.MSU1_DATA_SEEK &= 0xFFFF00FF;
		MSU1.MSU1_DATA_SEEK |= byte << 8;
		break;
	case 2:
		MSU1.MSU1_DATA_SEEK &= 0xFF00FFFF;
		MSU1.MSU1_DATA_SEEK |= byte << 16;
		break;
	case 3:
		MSU1.MSU1_DATA_SEEK &= 0x00FFFFFF;
		MSU1.MSU1_DATA_SEEK |= byte << 24;
		MSU1.MSU1_DATA_POS = MSU1.MSU1_DATA_SEEK;
        if (dataStream)
        {
            REVERT_STREAM(dataStream, MSU1.MSU1_DATA_POS, 0);
        }
		break;
	case 4:
		MSU1.MSU1_TRACK_SEEK &= 0xFF00;
		MSU1.MSU1_TRACK_SEEK |= byte;
		break;
	case 5:
		MSU1.MSU1_TRACK_SEEK &= 0x00FF;
		MSU1.MSU1_TRACK_SEEK |= (byte << 8);
		MSU1.MSU1_CURRENT_TRACK = MSU1.MSU1_TRACK_SEEK;

		MSU1.MSU1_STATUS &= ~AudioPlaying;
		MSU1.MSU1_STATUS &= ~AudioRepeating;

		if (AudioOpen())
		{
			if (MSU1.MSU1_CURRENT_TRACK == MSU1.MSU1_RESUME_TRACK)
			{
				MSU1.MSU1_AUDIO_POS = MSU1.MSU1_RESUME_POS;
				MSU1.MSU1_RESUME_POS = 0;
				MSU1.MSU1_RESUME_TRACK = ~0;
			}
			else
			{
				MSU1.MSU1_AUDIO_POS = 8;
			}

            REVERT_STREAM(audioStream, MSU1.MSU1_AUDIO_POS, 0);
		}
		break;
	case 6:
		MSU1.MSU1_VOLUME = byte;
		break;
	case 7:
		if (MSU1.MSU1_STATUS & (AudioBusy | AudioError))
			break;

		MSU1.MSU1_STATUS = (MSU1.MSU1_STATUS & ~0x30) | ((byte & 0x03) << 4);

		if ((byte & (Play | Resume)) == Resume)
		{
			MSU1.MSU1_RESUME_TRACK = MSU1.MSU1_CURRENT_TRACK;
			MSU1.MSU1_RESUME_POS = MSU1.MSU1_AUDIO_POS;
		}
		break;
	}
}

size_t S9xMSU1Samples(void)
{
	return bufPos - bufBegin;
}

void S9xMSU1SetOutput(int16 * out, size_t size)
{
	bufPos = bufBegin = out;
	bufEnd = out + size;
}

void S9xMSU1PostLoadState(void)
{
	if (DataOpen())
	{
        REVERT_STREAM(dataStream, MSU1.MSU1_DATA_POS, 0);
	}

	if (MSU1.MSU1_STATUS & AudioPlaying)
	{
		if (AudioOpen())
		{
            REVERT_STREAM(audioStream, 4, 0);
            READ_STREAM((char *)&audioLoopPos, 4, audioStream);
			audioLoopPos = GET_LE32(&audioLoopPos);
			audioLoopPos <<= 2;
			audioLoopPos += 8;

            REVERT_STREAM(audioStream, MSU1.MSU1_AUDIO_POS, 0);
		}
		else
		{
			MSU1.MSU1_STATUS &= ~(AudioPlaying | AudioRepeating);
			MSU1.MSU1_STATUS |= AudioError;
		}
	}

	bufPos = 0;
	bufBegin = 0;
	bufEnd = 0;

	partial_frames = 0;
}
