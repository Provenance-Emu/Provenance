#include <windows.h>
#include <vfw.h>
#include <stdio.h>

#include "common.h"
#include "fceu.h"

extern PALETTEENTRY *color_palette;
//extern WAVEFORMATEX wf;
//extern int soundo;

extern int soundrate;

#define VIDEO_STREAM	0
#define AUDIO_STREAM	1

#define VIDEO_WIDTH		256

//adelikat: TODO - perhaps put this in AVIFile
bool enableHUDrecording = false;
bool disableMovieMessages = false;
int AVICapture; //This initiates AVI capture mode with a frame number, on that frame number the AVI will stop, FCEUX will close, and a special return value will be set.  The intent is for this to be used in commandline 

static struct AVIFile
{
	int					valid;
	int					fps;
	int					fps_scale;

	int					video_added;
	BITMAPINFOHEADER	bitmap_format;

	int					sound_added;
	WAVEFORMATEX		wave_format;

	AVISTREAMINFO		avi_video_header;
	AVISTREAMINFO		avi_sound_header;
	PAVIFILE			avi_file;
	PAVISTREAM			streams[2];
	PAVISTREAM			compressed_streams[2];

	AVICOMPRESSOPTIONS	compress_options[2];
	AVICOMPRESSOPTIONS*	compress_options_ptr[2];

	int					video_frames;
	int					sound_samples;

	uint8*				convert_buffer;
	int					start_scanline;
	int					end_scanline;
	
	long				tBytes, ByteBuffer;

	u8					audio_buffer[44100*2*2]; // ~ 1 second buffer
	int					audio_buffer_pos;
} *avi_file = NULL;

struct VideoSystemInfo
{
	int					start_scanline;
	int					end_scanline;
	int					fps;
};


static char saved_cur_avi_fnameandext[MAX_PATH];
static char saved_avi_fname[MAX_PATH];
static char saved_avi_ext[MAX_PATH];
static int avi_segnum=0;
//static FILE* avi_check_file=0;
static struct AVIFile saved_avi_info;
static int use_prev_options=0;
static bool use_sound=false;



static int truncate_existing(const char* filename)
{
	// this is only here because AVIFileOpen doesn't seem to do it for us
	FILE* fd = FCEUD_UTF8fopen(filename, "wb");
	if(fd)
	{
		fclose(fd);
		return 1;
	}

	return 0;
}

static void avi_create(struct AVIFile** avi_out)
{
	*avi_out = (struct AVIFile*)malloc(sizeof(struct AVIFile));
	memset(*avi_out, 0, sizeof(struct AVIFile));
	AVIFileInit();
}

static int avi_audiosegment_size(struct AVIFile* avi_out)
{
	if(!avi_out || !avi_out->valid || !avi_out->sound_added)
		return 0;

	assert(avi_out->wave_format.nAvgBytesPerSec <= sizeof(avi_out->audio_buffer));
	return avi_out->wave_format.nAvgBytesPerSec;
}

static void avi_destroy(struct AVIFile** avi_out)
{
	if(!(*avi_out))
		return;

	if((*avi_out)->sound_added)
	{
		if((*avi_out)->compressed_streams[AUDIO_STREAM])
		{
			if ((*avi_out)->audio_buffer_pos > 0) {
				if(FAILED(AVIStreamWrite(avi_file->compressed_streams[AUDIO_STREAM],
				                         avi_file->sound_samples, (*avi_out)->audio_buffer_pos / (*avi_out)->wave_format.nBlockAlign,
				                         (*avi_out)->audio_buffer, (*avi_out)->audio_buffer_pos, 0, NULL, &avi_file->ByteBuffer)))
				{
					avi_file->valid = 0;
				}
				(*avi_out)->sound_samples += (*avi_out)->audio_buffer_pos / (*avi_out)->wave_format.nBlockAlign;
				(*avi_out)->tBytes += avi_file->ByteBuffer;
				(*avi_out)->audio_buffer_pos = 0;
			}

			LONG test = AVIStreamClose((*avi_out)->compressed_streams[AUDIO_STREAM]);
			(*avi_out)->compressed_streams[AUDIO_STREAM] = NULL;
			(*avi_out)->streams[AUDIO_STREAM] = NULL;				// compressed_streams[AUDIO_STREAM] is just a copy of streams[AUDIO_STREAM]
		}
	}

	if((*avi_out)->video_added)
	{
		if((*avi_out)->compressed_streams[VIDEO_STREAM])
		{
			AVIStreamClose((*avi_out)->compressed_streams[VIDEO_STREAM]);
			(*avi_out)->compressed_streams[VIDEO_STREAM] = NULL;
		}

		if((*avi_out)->streams[VIDEO_STREAM])
		{
			AVIStreamClose((*avi_out)->streams[VIDEO_STREAM]);
			(*avi_out)->streams[VIDEO_STREAM] = NULL;
		}
	}

	if((*avi_out)->avi_file)
	{
		AVIFileClose((*avi_out)->avi_file);
		(*avi_out)->avi_file = NULL;
	}

	free((*avi_out)->convert_buffer);
	free(*avi_out);
	*avi_out = NULL;
}

static void set_video_format(const BITMAPINFOHEADER* bitmap_format, struct AVIFile* avi_out)
{
	memcpy(&((*avi_out).bitmap_format), bitmap_format, sizeof(BITMAPINFOHEADER));
	(*avi_out).video_added = 1;
}

static void set_sound_format(const WAVEFORMATEX* wave_format, struct AVIFile* avi_out)
{
	memcpy(&((*avi_out).wave_format), wave_format, sizeof(WAVEFORMATEX));
	(*avi_out).sound_added = 1;
}

static int avi_open(const char* filename, const BITMAPINFOHEADER* pbmih, const WAVEFORMATEX* pwfex, const struct VideoSystemInfo* vsi)
{
	int error = 1;
	int result = 0;

	do
	{
		// close existing first
		FCEUI_AviEnd();

		if(!truncate_existing(filename))
			break;

		if(!pbmih)
			break;

		// create the object
		avi_create(&avi_file);

		// set video size and framerate
		avi_file->start_scanline = vsi->start_scanline;
		avi_file->end_scanline = vsi->end_scanline;
		//zero 20-oct-2012 - AVIFileClose has bugs in it which cause overflows in the calculation of dwTotalFrames, so some programs are unhappy with the resulting files.
		//so I reduced the precision here by the minimum number of shifts necessary to make it not overflow
		avi_file->fps = vsi->fps >> 3;
		avi_file->fps_scale = (16 * 1024 * 1024) >> 3;
		avi_file->convert_buffer = (uint8*)malloc(VIDEO_WIDTH*(vsi->end_scanline-vsi->start_scanline)*3);

		// open the file
		if(FAILED(AVIFileOpen(&avi_file->avi_file, filename, OF_CREATE | OF_WRITE, NULL)))
			break;

		// create the video stream
		set_video_format(pbmih, avi_file);

		memset(&avi_file->avi_video_header, 0, sizeof(AVISTREAMINFO));
		avi_file->avi_video_header.fccType = streamtypeVIDEO;
		avi_file->avi_video_header.dwScale = avi_file->fps_scale;
		avi_file->avi_video_header.dwRate = avi_file->fps;
		avi_file->avi_video_header.dwSuggestedBufferSize = avi_file->bitmap_format.biSizeImage;
		if(FAILED(AVIFileCreateStream(avi_file->avi_file, &avi_file->streams[VIDEO_STREAM], &avi_file->avi_video_header)))
			break;

		if(use_prev_options)
		{
			avi_file->compress_options[VIDEO_STREAM] = saved_avi_info.compress_options[VIDEO_STREAM];
			avi_file->compress_options_ptr[VIDEO_STREAM] = &avi_file->compress_options[0];
		}
		else
		{
			// get compression options
			memset(&avi_file->compress_options[VIDEO_STREAM], 0, sizeof(AVICOMPRESSOPTIONS));
			avi_file->compress_options_ptr[VIDEO_STREAM] = &avi_file->compress_options[0];
//retryAviSaveOptions: //mbg merge 7/17/06 removed
			error = 0;
			if(!AVISaveOptions(hAppWnd, 0, 1, &avi_file->streams[VIDEO_STREAM], &avi_file->compress_options_ptr[VIDEO_STREAM]))
				break;
			error = 1;
		}

		// create compressed stream
		if(FAILED(AVIMakeCompressedStream(&avi_file->compressed_streams[VIDEO_STREAM], avi_file->streams[VIDEO_STREAM], &avi_file->compress_options[VIDEO_STREAM], NULL)))
			break;

		// set the stream format
		if(FAILED(AVIStreamSetFormat(avi_file->compressed_streams[VIDEO_STREAM], 0, (void*)&avi_file->bitmap_format, avi_file->bitmap_format.biSize)))
			break;

		// add sound (if requested)
		if(pwfex)
		{
			// add audio format
			set_sound_format(pwfex, avi_file);

			// create the audio stream
			memset(&avi_file->avi_sound_header, 0, sizeof(AVISTREAMINFO));
			avi_file->avi_sound_header.fccType = streamtypeAUDIO;
			avi_file->avi_sound_header.dwQuality = (DWORD)-1;
			avi_file->avi_sound_header.dwScale = avi_file->wave_format.nBlockAlign;
			avi_file->avi_sound_header.dwRate = avi_file->wave_format.nAvgBytesPerSec;
			avi_file->avi_sound_header.dwSampleSize = avi_file->wave_format.nBlockAlign;
			avi_file->avi_sound_header.dwInitialFrames = 1;
			if(FAILED(AVIFileCreateStream(avi_file->avi_file, &avi_file->streams[AUDIO_STREAM], &avi_file->avi_sound_header)))
				break;

			// AVISaveOptions doesn't seem to work for audio streams
			// so here we just copy the pointer for the compressed stream
			avi_file->compressed_streams[AUDIO_STREAM] = avi_file->streams[AUDIO_STREAM];

			// set the stream format
			if(FAILED(AVIStreamSetFormat(avi_file->compressed_streams[AUDIO_STREAM], 0, (void*)&avi_file->wave_format, sizeof(WAVEFORMATEX))))
				break;
		}

		// initialize counters
		avi_file->video_frames = 0;
		avi_file->sound_samples = 0;
		avi_file->tBytes = 0;
		avi_file->ByteBuffer = 0;
		avi_file->audio_buffer_pos = 0;

		// success
		error = 0;
		result = 1;
		avi_file->valid = 1;

	} while(0);

	if(!result)
	{
		avi_destroy(&avi_file);
		if(error)
			FCEUD_PrintError("Error writing AVI file");
	}

	return result;
}

//converts to 24bpp
static void do_video_conversion(const unsigned char* buffer)
{
//	memset(avi_file->convert_buffer, 0, VIDEO_WIDTH*(avi_file->end_scanline-avi_file->start_scanline)*3);

	buffer += avi_file->start_scanline * VIDEO_WIDTH;

	for(int y=avi_file->start_scanline; y<avi_file->end_scanline; ++y)
	{
		uint8* pix = avi_file->convert_buffer + (avi_file->end_scanline-1-y)*VIDEO_WIDTH*3;
		const uint8* prevbuf = buffer;

		for(int x=0; x<VIDEO_WIDTH; ++x)
		{
			uint8 *cp = (uint8*)(color_palette + *buffer++)+2;
			*pix++ = *cp--;
			*pix++ = *cp--;
			*pix++ = *cp;
		}

		buffer = prevbuf + VIDEO_WIDTH;
	}
}

//------------------------------------
//
// Interface implementation
//
//------------------------------------



static int FCEUI_AviNextSegment()
{
	char avi_fname[MAX_PATH];
	strcpy(avi_fname,saved_avi_fname);
	char avi_fname_temp[MAX_PATH];
	sprintf(avi_fname_temp, "%s_part%d%s", avi_fname, avi_segnum+2, saved_avi_ext);
	saved_avi_info=*avi_file;
	use_prev_options=1;
	avi_segnum++;
	int ret = FCEUI_AviBegin(avi_fname_temp);
	use_prev_options=0;
	strcpy(saved_avi_fname,avi_fname);
	return ret;
}


int FCEUI_AviBegin(const char* fname)
{
	FCEUI_AviEnd();

	struct VideoSystemInfo vsi;
	BITMAPINFOHEADER bi;
	int is_pal;

	is_pal=FCEUI_GetCurrentVidSystem(&vsi.start_scanline, &vsi.end_scanline);
	vsi.fps = FCEUI_GetDesiredFPS();//is_pal ? 50 : 60;
	vsi.end_scanline++;

	memset(&bi, 0, sizeof(bi));
	bi.biSize = sizeof(BITMAPINFOHEADER);    
	bi.biPlanes = 1;
	bi.biBitCount = 24;
	bi.biWidth = VIDEO_WIDTH;
	bi.biHeight = vsi.end_scanline-vsi.start_scanline;
	bi.biSizeImage = 3 * bi.biWidth * bi.biHeight;

	//mbg 6/27/08 -- this was originally labeled as hacky..
	WAVEFORMATEX wf;
	wf.cbSize = sizeof(WAVEFORMATEX);
	wf.nAvgBytesPerSec = soundrate * 2;
	wf.nBlockAlign = 2;
	wf.nChannels = 1;
	wf.nSamplesPerSec = soundrate;
	wf.wBitsPerSample = 16;
	wf.wFormatTag = WAVE_FORMAT_PCM;
	

	saved_avi_ext[0]='\0';

	//mbg 8/10/08 - decide whether there will be sound in this movie
	//if this is a new movie..
	if(!avi_file) {
		if(FSettings.SndRate)
			use_sound = true;
		else use_sound = false;
	}

	//mbg 8/10/08 - if there is no sound in this movie, then dont open the audio stream
	WAVEFORMATEX* pwf = &wf;
	if(!use_sound)
		pwf = 0;


	if(!avi_open(fname, &bi, pwf, &vsi))
	{
		saved_avi_fname[0]='\0';
		return 0;
	}

	// Don't display at file splits
	if(!avi_segnum)
		FCEU_DispMessage("AVI recording started.",0);

	strncpy(saved_cur_avi_fnameandext,fname,MAX_PATH);
	strncpy(saved_avi_fname,fname,MAX_PATH);
	char* dot = strrchr(saved_avi_fname, '.');
	if(dot && dot > strrchr(saved_avi_fname, '/') && dot > strrchr(saved_avi_fname, '\\'))
	{
		strcpy(saved_avi_ext,dot);
		dot[0]='\0';
	}
	return 1;
}

void FCEUI_AviVideoUpdate(const unsigned char* buffer)
{
	if(!avi_file || !avi_file->valid)
		return;

	do_video_conversion(buffer);

    if(FAILED(AVIStreamWrite(avi_file->compressed_streams[VIDEO_STREAM],
                                 avi_file->video_frames, 1, avi_file->convert_buffer,
                                 avi_file->bitmap_format.biSizeImage, AVIIF_KEYFRAME,
                                 NULL, &avi_file->ByteBuffer)))
	{
		avi_file->valid = 0;
		return;
	}

	avi_file->video_frames++;
	avi_file->tBytes += avi_file->ByteBuffer;

	// segment / split AVI when it's almost 2 GB (2000MB, to be precise)
	if(!(avi_file->video_frames % 60) && avi_file->tBytes > 2097152000)
		FCEUI_AviNextSegment();
}

void FCEUI_AviSoundUpdate(void* soundData, int soundLen)
{
	if(!avi_file || !avi_file->valid || !avi_file->sound_added)
		return;

	const int audioSegmentSize = avi_audiosegment_size(avi_file);
	const int samplesPerSegment = audioSegmentSize / avi_file->wave_format.nBlockAlign;
	const int soundSize = soundLen * avi_file->wave_format.nBlockAlign;
	int nBytes = soundSize;
	while (avi_file->audio_buffer_pos + nBytes > audioSegmentSize) {
		const int bytesToTransfer = audioSegmentSize - avi_file->audio_buffer_pos;
		memcpy(&avi_file->audio_buffer[avi_file->audio_buffer_pos], &((u8*)soundData)[soundSize - nBytes], bytesToTransfer);
		nBytes -= bytesToTransfer;

		if(FAILED(AVIStreamWrite(avi_file->compressed_streams[AUDIO_STREAM],
		                         avi_file->sound_samples, samplesPerSegment,
		                         avi_file->audio_buffer, audioSegmentSize, 0, NULL, &avi_file->ByteBuffer)))
		{
			avi_file->valid = 0;
			return;
		}
		avi_file->sound_samples += samplesPerSegment;
		avi_file->tBytes += avi_file->ByteBuffer;
		avi_file->audio_buffer_pos = 0;
	}
	memcpy(&avi_file->audio_buffer[avi_file->audio_buffer_pos], &((u8*)soundData)[soundSize - nBytes], nBytes);
	avi_file->audio_buffer_pos += nBytes;
}

void FCEUI_AviEnd()
{
	if(!avi_file)
		return;

	// Don't display if we're just starting another segment
	if(avi_file->tBytes <= 2097152000)
		FCEU_DispMessage("AVI recording ended.",0);

	avi_destroy(&avi_file);
}

bool FCEUI_AviIsRecording()
{
	if(avi_file)
		return true;
	return false;
}

bool FCEUI_AviEnableHUDrecording()
{
	return enableHUDrecording;
}
void FCEUI_SetAviEnableHUDrecording(bool enable)
{
	enableHUDrecording = enable;
}
bool FCEUI_AviDisableMovieMessages()
{
	return disableMovieMessages;
}
void FCEUI_SetAviDisableMovieMessages(bool disable)
{
	disableMovieMessages = disable;
}

