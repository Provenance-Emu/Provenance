/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "movie.h"
#include "logger.h"

static int	resetno = 0;
static int	framecounter = 0;
static FILE	*video = NULL;
static FILE	*audio = NULL;


void S9xResetLogger (void)
{
	if (!Settings.DumpStreams)
		return;

	char	buffer[128];

	S9xCloseLogger();
	framecounter = 0;

	sprintf(buffer, "videostream%d.dat", resetno);
	video = fopen(buffer, "wb");
	if (!video)
	{
		printf("Opening %s failed. Logging cancelled.\n", buffer);
		return;
	}

	sprintf(buffer, "audiostream%d.dat", resetno);
	audio = fopen(buffer, "wb");
	if (!audio)
	{
		printf("Opening %s failed. Logging cancelled.\n", buffer);
		fclose(video);
		return;
	}

	resetno++;
}

void S9xCloseLogger (void)
{
	if (video)
	{
		fclose(video);
		video = NULL;
	}

	if (audio)
	{
		fclose(audio);
		audio = NULL;
	}
}	

void S9xVideoLogger (void *pixels, int width, int height, int depth, int bytes_per_line)
{
	int	fc = S9xMovieGetFrameCounter();
	if (fc > 0)
		framecounter = fc;
	else
		framecounter++;

	if (video)
	{
		char	*data = (char *) pixels;

		for (int i = 0; i < height; i++)
		{
			if (!fwrite(data + i * bytes_per_line, depth, width, video))
				printf ("Error writing video data.\n");
		}
		fflush(video);
		fflush(audio);

		if (Settings.DumpStreamsMaxFrames > 0 && framecounter >= Settings.DumpStreamsMaxFrames)
		{
			printf("Logging ended.\n");
			S9xCloseLogger();
		}

	}
}

void S9xAudioLogger (void *samples, int length)
{
	if (audio)
	{
		if (!fwrite(samples, 1, length, audio))
			printf ("Error writing audio data.\n");
	}
}
