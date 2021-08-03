/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"
#include "display.h"
#include "msu1.h"
#include "apu/resampler.h"
#include "apu/bapu/dsp/blargg_endian.h"
#include <fstream>
#include <sys/stat.h>

STREAM dataStream = NULL;
STREAM audioStream = NULL;
uint32 audioLoopPos;
size_t partial_frames;

// Sample buffer
static Resampler *msu_resampler = NULL;

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

	if (msu_resampler)
		msu_resampler->clear();

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

	while (partial_frames >= 3204)
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

				msu_resampler->push_sample(*left, *right);
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
			msu_resampler->push_sample(0, 0);
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
	return msu_resampler->space_filled();
}

void S9xMSU1SetOutput(Resampler *resampler)
{
	msu_resampler = resampler;
}

void S9xMSU1PostLoadState(void)
{
	if (DataOpen())
	{
        REVERT_STREAM(dataStream, MSU1.MSU1_DATA_POS, 0);
	}

	if (MSU1.MSU1_STATUS & AudioPlaying)
	{
		uint32 savedPosition = MSU1.MSU1_AUDIO_POS;

		if (AudioOpen())
		{
            REVERT_STREAM(audioStream, 4, 0);
            READ_STREAM((char *)&audioLoopPos, 4, audioStream);
			audioLoopPos = GET_LE32(&audioLoopPos);
			audioLoopPos <<= 2;
			audioLoopPos += 8;

			MSU1.MSU1_AUDIO_POS = savedPosition;
            REVERT_STREAM(audioStream, MSU1.MSU1_AUDIO_POS, 0);
		}
		else
		{
			MSU1.MSU1_STATUS &= ~(AudioPlaying | AudioRepeating);
			MSU1.MSU1_STATUS |= AudioError;
		}
	}

	if (msu_resampler)
		msu_resampler->clear();

	partial_frames = 0;
}
