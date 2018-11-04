/*
 * PicoDrive
 * (C) notaz, 2007,2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>

#include <pspkernel.h>
#include <pspsdk.h>
#include <pspaudiocodec.h>
#include <kubridge.h>

#include "../../pico/pico_int.h"
#include "../../pico/sound/mix.h"
#include "../common/lprintf.h"

int mp3_last_error = 0;

static int initialized = 0;
static SceUID thread_job_sem = -1;
static SceUID thread_busy_sem = -1;
static int thread_exit = 0;

// MPEG-1, layer 3
static int bitrates[] = { 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0 };
//static int samplerates[] = { 44100, 48000, 32000, 0 };

#define MIN_INFRAME_SIZE 96
#define IN_BUFFER_SIZE (2*1024)

static unsigned long mp3_codec_struct[65] __attribute__((aligned(64)));

static unsigned char mp3_src_buffer[2][IN_BUFFER_SIZE] __attribute__((aligned(64)));
static short mp3_mix_buffer[2][1152*2] __attribute__((aligned(64)));
static int working_buf = 0;

static const char *mp3_fname = NULL;
static SceUID mp3_handle = -1;
static int mp3_src_pos = 0, mp3_src_size = 0;

static int decode_thread(SceSize args, void *argp);


static void psp_sem_lock(SceUID sem)
{
	int ret = sceKernelWaitSema(sem, 1, 0);
	if (ret < 0) lprintf("sceKernelWaitSema(%08x) failed with %08x\n", sem, ret);
}

static void psp_sem_unlock(SceUID sem)
{
	int ret = sceKernelSignalSema(sem, 1);
	if (ret < 0) lprintf("sceKernelSignalSema(%08x) failed with %08x\n", sem, ret);
}

// only accepts MPEG-1, layer3
static int find_sync_word(unsigned char *data, int len)
{
	int i;
	for (i = 0; i < len-1; i++)
	{
		if ( data[i+0] != 0xff) continue;
		if ((data[i+1] & 0xfe) == 0xfa) return i;
		i++;
	}
	return -1;
}

static int read_next_frame(int which_buffer)
{
	int i, bytes_read, frame_offset;
	int bitrate, padding, frame_size = 0;

	for (i = 0; i < 32; i++)
	{
		bytes_read = sceIoRead(mp3_handle, mp3_src_buffer[which_buffer], sizeof(mp3_src_buffer[which_buffer]));
		mp3_src_pos += bytes_read;
		if (bytes_read < MIN_INFRAME_SIZE) {
			mp3_src_pos = mp3_src_size;
			return 0; // EOF/IO failure
		}
		frame_offset = find_sync_word(mp3_src_buffer[which_buffer], bytes_read);
		if (frame_offset < 0) {
			lprintf("missing syncword, foffs=%i\n", mp3_src_pos - bytes_read);
			mp3_src_pos--;
			sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);
			continue;
		}
		if (bytes_read - frame_offset < 4) {
			lprintf("syncword @ EOB, foffs=%i\n", mp3_src_pos - bytes_read);
			mp3_src_pos--;
			sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);
			continue;
		}

		bitrate =  mp3_src_buffer[which_buffer][frame_offset+2] >> 4;
		padding = (mp3_src_buffer[which_buffer][frame_offset+2] & 2) >> 1;

		frame_size = 144000*bitrates[bitrate]/44100 + padding;
		if (frame_size <= 0) {
			lprintf("bad frame, foffs=%i\n", mp3_src_pos - bytes_read);
			continue; // bad frame
		}

		if (bytes_read - frame_offset < frame_size)
		{
			lprintf("unfit, foffs=%i\n", mp3_src_pos - bytes_read);
			mp3_src_pos -= bytes_read - frame_offset;
			if (mp3_src_size - mp3_src_pos < frame_size) {
				mp3_src_pos = mp3_src_size;
				return 0; // EOF
			}
			sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);
			continue; // didn't fit, re-read..
		}

		if (frame_offset) {
			//lprintf("unaligned, foffs=%i, offs=%i\n", mp3_src_pos - bytes_read, frame_offset);
			memmove(mp3_src_buffer[which_buffer], mp3_src_buffer[which_buffer] + frame_offset, frame_size);
		}

		// align for next frame read
		mp3_src_pos -= bytes_read - (frame_offset + frame_size);
		sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);

		break;
	}

	return frame_size > 0 ? frame_size : -1;
}


static SceUID load_start_module(const char *prxname)
{
	SceUID mod, mod1;
	int status, ret;

	mod = pspSdkLoadStartModule(prxname, PSP_MEMORY_PARTITION_KERNEL);
	if (mod < 0) {
		lprintf("failed to load %s (%08x), trying kuKernelLoadModule\n", prxname, mod);
		mod1 = kuKernelLoadModule(prxname, 0, NULL);
		if (mod1 < 0) lprintf("kuKernelLoadModule failed with %08x\n", mod1);
		else {
			ret = sceKernelStartModule(mod1, 0, NULL, &status, 0);
			if (ret < 0) lprintf("sceKernelStartModule failed with %08x\n", ret);
			else mod = mod1;
		}
	}
	return mod;
}


int mp3_init(void)
{
	SceUID thid, mod;
	int ret;

	/* load modules */
	/* <= 1.5 (and probably some other, not sure which) fw need this to for audiocodec to work,
	 * so if it fails, assume we are just on new enough firmware and continue.. */
	load_start_module("flash0:/kd/me_for_vsh.prx");

	if (sceKernelDevkitVersion() < 0x02070010)
	     mod = load_start_module("flash0:/kd/audiocodec.prx");
	else mod = load_start_module("flash0:/kd/avcodec.prx");
	if (mod < 0) {
		ret = mod;
		mod = load_start_module("flash0:/kd/audiocodec_260.prx"); // last chance..
		if (mod < 0) goto fail;
	}

	/* audiocodec init */
	memset(mp3_codec_struct, 0, sizeof(mp3_codec_struct));
	ret = sceAudiocodecCheckNeedMem(mp3_codec_struct, 0x1002);
	if (ret < 0) {
		lprintf("sceAudiocodecCheckNeedMem failed with %08x\n", ret);
		goto fail;
	}

	ret = sceAudiocodecGetEDRAM(mp3_codec_struct, 0x1002);
	if (ret < 0) {
		lprintf("sceAudiocodecGetEDRAM failed with %08x\n", ret);
		goto fail;
	}

	ret = sceAudiocodecInit(mp3_codec_struct, 0x1002);
	if (ret < 0) {
		lprintf("sceAudiocodecInit failed with %08x\n", ret);
		goto fail1;
	}

	/* thread and stuff */
	thread_job_sem = sceKernelCreateSema("p_mp3job_sem", 0, 0, 1, NULL);
	if (thread_job_sem < 0) {
		lprintf("sceKernelCreateSema() failed: %08x\n", thread_job_sem);
		ret = thread_job_sem;
		goto fail1;
	}

	thread_busy_sem = sceKernelCreateSema("p_mp3busy_sem", 0, 1, 1, NULL);
	if (thread_busy_sem < 0) {
		lprintf("sceKernelCreateSema() failed: %08x\n", thread_busy_sem);
		ret = thread_busy_sem;
		goto fail2;
	}

	/* use slightly higher prio then main */
	thread_exit = 0;
	thid = sceKernelCreateThread("mp3decode_thread", decode_thread, 30, 0x2000, 0, NULL);
	if (thid < 0) {
		lprintf("failed to create decode thread: %08x\n", thid);
		ret = thid;
		goto fail3;
	}
	ret = sceKernelStartThread(thid, 0, 0);
	if (ret < 0) {
		lprintf("failed to start decode thread: %08x\n", ret);
		goto fail3;
	}

	mp3_last_error = 0;
	initialized = 1;
	return 0;

fail3:
	sceKernelDeleteSema(thread_busy_sem);
	thread_busy_sem = -1;
fail2:
	sceKernelDeleteSema(thread_job_sem);
	thread_job_sem = -1;
fail1:
	sceAudiocodecReleaseEDRAM(mp3_codec_struct);
fail:
	mp3_last_error = ret;
	initialized = 0;
	return 1;
}

void mp3_deinit(void)
{
	lprintf("mp3_deinit, initialized=%i\n", initialized);

	if (!initialized) return;
	thread_exit = 1;
	psp_sem_lock(thread_busy_sem);
	psp_sem_unlock(thread_busy_sem);

	sceKernelSignalSema(thread_job_sem, 1);
	sceKernelDelayThread(100*1000);

	if (mp3_handle >= 0) sceIoClose(mp3_handle);
	mp3_handle = -1;
	mp3_fname = NULL;

	sceKernelDeleteSema(thread_busy_sem);
	thread_busy_sem = -1;
	sceKernelDeleteSema(thread_job_sem);
	thread_job_sem = -1;
	sceAudiocodecReleaseEDRAM(mp3_codec_struct);
	initialized = 0;
}

// may overflow stack?
static int decode_thread(SceSize args, void *argp)
{
	int ret, frame_size;

	lprintf("decode_thread started with id %08x, priority %i\n",
                sceKernelGetThreadId(), sceKernelGetThreadCurrentPriority());

	while (!thread_exit)
	{
		psp_sem_lock(thread_job_sem);
		if (thread_exit) break;

		psp_sem_lock(thread_busy_sem);
		//lprintf("{ job\n");

		frame_size = read_next_frame(working_buf);
		if (frame_size > 0)
		{
			mp3_codec_struct[6] = (unsigned long)mp3_src_buffer[working_buf];
			mp3_codec_struct[8] = (unsigned long)mp3_mix_buffer[working_buf];
			mp3_codec_struct[7] = mp3_codec_struct[10] = frame_size;
			mp3_codec_struct[9] = 1152 * 4;

			ret = sceAudiocodecDecode(mp3_codec_struct, 0x1002);
			if (ret < 0) lprintf("sceAudiocodecDecode failed with %08x\n", ret);
		}

		//lprintf("} job\n");
		psp_sem_unlock(thread_busy_sem);
	}

	lprintf("leaving decode thread\n");
	sceKernelExitDeleteThread(0);
	return 0;
}


// might be called before initialization
int mp3_get_bitrate(void *f, int size)
{
	int ret, retval = -1, sample_rate, bitrate;
	// filenames are stored instead handles in PSP, due to stupid max open file limit
	char *fname = f;

	/* make sure thread is not busy.. */
	if (thread_busy_sem >= 0)
		psp_sem_lock(thread_busy_sem);

	if (mp3_handle >= 0) sceIoClose(mp3_handle);
	mp3_handle = sceIoOpen(fname, PSP_O_RDONLY, 0777);
	if (mp3_handle < 0) {
		lprintf("sceIoOpen(%s) failed\n", fname);
		goto end;
	}

	mp3_src_pos = 0;
	ret = read_next_frame(0);
	if (ret <= 0) {
		lprintf("read_next_frame() failed (%s)\n", fname);
		goto end;
	}
	sample_rate = (mp3_src_buffer[0][2] & 0x0c) >> 2;
	bitrate = mp3_src_buffer[0][2] >> 4;

	if (sample_rate != 0) {
		lprintf("unsupported samplerate (%s)\n", fname);
		goto end; // only 44kHz supported..
	}
	bitrate = bitrates[bitrate];
	if (bitrate == 0) {
		lprintf("unsupported bitrate (%s)\n", fname);
		goto end;
	}

	/* looking good.. */
	retval = bitrate;
end:
	if (mp3_handle >= 0) sceIoClose(mp3_handle);
	mp3_handle = -1;
	mp3_fname = NULL;
	if (thread_busy_sem >= 0)
		psp_sem_unlock(thread_busy_sem);
	if (retval < 0) mp3_last_error = -1; // remember we had a problem..
	return retval;
}


static int mp3_job_started = 0, mp3_samples_ready = 0, mp3_buffer_offs = 0, mp3_play_bufsel = 0;

void mp3_start_play(void *f, int pos)
{
	char *fname = f;

	if (!initialized) return;

	lprintf("mp3_start_play(%s) @ %i\n", fname, pos);
	psp_sem_lock(thread_busy_sem);

	if (mp3_fname != fname || mp3_handle < 0)
	{
		if (mp3_handle >= 0) sceIoClose(mp3_handle);
		mp3_handle = sceIoOpen(fname, PSP_O_RDONLY, 0777);
		if (mp3_handle < 0) {
			lprintf("sceIoOpen(%s) failed\n", fname);
			psp_sem_unlock(thread_busy_sem);
			return;
		}
		mp3_src_size = sceIoLseek32(mp3_handle, 0, PSP_SEEK_END);
		mp3_fname = fname;
	}

	// clear decoder state
	sceAudiocodecInit(mp3_codec_struct, 0x1002);

	// seek..
	mp3_src_pos = (int) (((float)pos / 1023.0f) * (float)mp3_src_size);
	sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);
	lprintf("seek %i: %i/%i\n", pos, mp3_src_pos, mp3_src_size);

	mp3_job_started = 1;
	mp3_samples_ready = mp3_buffer_offs = mp3_play_bufsel = 0;
	working_buf = 0;

	/* send a request to decode first frame */
	psp_sem_unlock(thread_busy_sem);
	psp_sem_unlock(thread_job_sem);
	sceKernelDelayThread(1); // reschedule
}


void mp3_update(int *buffer, int length, int stereo)
{
	int length_mp3;

	// playback was started, track not ended
	if (mp3_handle < 0 || mp3_src_pos >= mp3_src_size) return;

	length_mp3 = length;
	if (PsndRate == 22050) length_mp3 <<= 1;	// mp3s are locked to 44100Hz stereo
	else if (PsndRate == 11025) length_mp3 <<= 2;	// so make length 44100ish

	/* do we have to wait? */
	if (mp3_job_started && mp3_samples_ready < length_mp3)
	{
		psp_sem_lock(thread_busy_sem);
		psp_sem_unlock(thread_busy_sem);
		mp3_job_started = 0;
		mp3_samples_ready += 1152;
	}

	/* mix mp3 data, only stereo */
	if (mp3_samples_ready >= length_mp3)
	{
		int shr = 0;
		void (*mix_samples)(int *dest_buf, short *mp3_buf, int count) = mix_16h_to_32;
		if (PsndRate == 22050) { mix_samples = mix_16h_to_32_s1; shr = 1; }
		else if (PsndRate == 11025) { mix_samples = mix_16h_to_32_s2; shr = 2; }

		if (1152 - mp3_buffer_offs >= length_mp3) {
			mix_samples(buffer, mp3_mix_buffer[mp3_play_bufsel] + mp3_buffer_offs*2, length<<1);

			mp3_buffer_offs += length_mp3;
		} else {
			// collect samples from both buffers..
			int left = 1152 - mp3_buffer_offs;
			if (mp3_play_bufsel == 0)
			{
				mix_samples(buffer, mp3_mix_buffer[0] + mp3_buffer_offs*2, length<<1);
				mp3_buffer_offs = length_mp3 - left;
				mp3_play_bufsel = 1;
			} else {
				mix_samples(buffer, mp3_mix_buffer[1] + mp3_buffer_offs*2, (left>>shr)<<1);
				mp3_buffer_offs = length_mp3 - left;
				mix_samples(buffer + ((left>>shr)<<1),
					mp3_mix_buffer[0], (mp3_buffer_offs>>shr)<<1);
				mp3_play_bufsel = 0;
			}
		}
		mp3_samples_ready -= length_mp3;
	}

	// ask to decode more if we already can
	if (!mp3_job_started)
	{
		mp3_job_started = 1;
		working_buf ^= 1;

		/* next job.. */
		psp_sem_lock(thread_busy_sem);   // just in case
		psp_sem_unlock(thread_busy_sem);
		psp_sem_unlock(thread_job_sem);
		sceKernelDelayThread(1);
	}
}


int mp3_get_offset(void) // 0-1023
{
	unsigned int offs1024 = 0;
	int cdda_on;

	cdda_on = (PicoAHW & PAHW_MCD) && (PicoOpt&0x800) && !(Pico_mcd->s68k_regs[0x36] & 1) &&
			(Pico_mcd->scd.Status_CDC & 1) && mp3_handle >= 0;

	if (cdda_on) {
		offs1024  = mp3_src_pos << 7;
		offs1024 /= mp3_src_size >> 3;
	}
	lprintf("offs1024=%u (%i/%i)\n", offs1024, mp3_src_pos, mp3_src_size);

	return offs1024;
}


void mp3_reopen_file(void)
{
	if (mp3_fname == NULL) return;
	lprintf("mp3_reopen_file(%s)\n", mp3_fname);

	// try closing, just in case
	if (mp3_handle >= 0) sceIoClose(mp3_handle);

	mp3_handle = sceIoOpen(mp3_fname, PSP_O_RDONLY, 0777);
	if (mp3_handle >= 0)
		sceIoLseek32(mp3_handle, mp3_src_pos, PSP_SEEK_SET);
	lprintf("mp3_reopen_file %s\n", mp3_handle >= 0 ? "ok" : "failed");
}

