/*
 * PicoDrive
 * (C) notaz, 2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>
#include <string.h>

#include <pico/pico_int.h>
#include <pico/sound/mix.h>
#include "mp3.h"

static FILE *mp3_current_file;
static int mp3_file_len, mp3_file_pos;
static int cdda_out_pos;
static int decoder_active;

unsigned short mpeg1_l3_bitrates[16] = {
	0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320
};

static int try_get_bitrate(unsigned char *buf, int buf_size)
{
	int offs1, offs = 0;
	int ret;

	while (1)
	{
		offs1 = mp3_find_sync_word(buf + offs, buf_size - offs);
		if (offs1 < 0)
			return -2;
		offs += offs1;
		if (buf_size - offs < 4)
			return -3;

		// printf("trying header %08x\n", *(int *)(buf + offs));

		ret = mpeg1_l3_bitrates[buf[offs + 2] >> 4];
		if (ret > 0)
			return ret;
	}

	return -2;
}

int mp3_get_bitrate(void *f_, int len)
{
	unsigned char buf[2048];
	FILE *f = f_;
	int retval = -1;
	int ret;

	memset(buf, 0, sizeof(buf));

	fseek(f, 0, SEEK_SET);
	ret = fread(buf, 1, sizeof(buf), f);
	if (ret != sizeof(buf))
		goto out;

	ret = try_get_bitrate(buf, sizeof(buf));
	if (ret <= 0) {
		// try to read somewhere around the middle
		fseek(f, len / 2, SEEK_SET);
		ret = fread(buf, 1, sizeof(buf), f);
		if (ret == sizeof(buf))
			ret = try_get_bitrate(buf, sizeof(buf));
	}
	if (ret > 0)
		retval = ret;

	//printf("bitrate: %i\n", retval);

out:
	fseek(f, 0, SEEK_SET);
	return retval;
}

void mp3_start_play(void *f_, int pos1024)
{
	unsigned char buf[2048];
	FILE *f = f_;
	int ret;

	mp3_file_len = mp3_file_pos = 0;
	mp3_current_file = NULL;
	cdda_out_pos = 0;
	decoder_active = 0;

	if (!(PicoIn.opt & POPT_EN_MCD_CDDA) || f == NULL) // cdda disabled or no file?
		return;

	fseek(f, 0, SEEK_END);
	mp3_file_len = ftell(f);

	// search for first sync word, skipping stuff like ID3 tags
	while (mp3_file_pos < 128*1024) {
		int offs, bytes;

		fseek(f, mp3_file_pos, SEEK_SET);
		bytes = fread(buf, 1, sizeof(buf), f);
		if (bytes < 4)
			break;
		offs = mp3_find_sync_word(buf, bytes);
		if (offs >= 0) {
			mp3_file_pos += offs;
			break;
		}
		mp3_file_pos += bytes - 3;
	}

	// seek..
	if (pos1024 != 0) {
		unsigned long long pos64 = mp3_file_len - mp3_file_pos;
		pos64 *= pos1024;
		mp3_file_pos += pos64 >> 10;
	}

	ret = mp3dec_start(f, mp3_file_pos);
	if (ret != 0) {
		return;
	}

	mp3_current_file = f;
	decoder_active = 1;

	mp3dec_decode(mp3_current_file, &mp3_file_pos, mp3_file_len);
}

void mp3_update(s32 *buffer, int length, int stereo)
{
	int length_mp3;
	void (*mix_samples)(s32 *dest_buf, short *mp3_buf, int count, int fac16) = mix_16h_to_32_resample_stereo;

	if (mp3_current_file == NULL || mp3_file_pos >= mp3_file_len)
		return; /* no file / EOF */

	if (!decoder_active)
		return;

	length_mp3 = length * Pico.snd.cdda_mult >> 16;
	if (!stereo)
		mix_samples = mix_16h_to_32_resample_mono;

	if (1152 - cdda_out_pos >= length_mp3) {
		mix_samples(buffer, cdda_out_buffer + cdda_out_pos * 2,
			length, Pico.snd.cdda_mult);

		cdda_out_pos += length_mp3;
	} else {
		int left = (1152 - cdda_out_pos) * Pico.snd.cdda_div >> 16;
		int ret, sm = stereo ? 2 : 1;

		if (left > 0)
			mix_samples(buffer, cdda_out_buffer + cdda_out_pos * 2,
				left, Pico.snd.cdda_mult);

		ret = mp3dec_decode(mp3_current_file, &mp3_file_pos,
			mp3_file_len);
		if (ret == 0) {
			mix_samples(buffer + left * sm, cdda_out_buffer,
				length-left, Pico.snd.cdda_mult);
			cdda_out_pos = (length-left) * Pico.snd.cdda_mult >> 16;
		} else
			cdda_out_pos = 0;
	}
}

