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

int mp3_find_sync_word(const unsigned char *buf, int size)
{
	const unsigned char *p, *pe;

	/* find byte-aligned syncword - need 12 (MPEG 1,2) or 11 (MPEG 2.5) matching bits */
	for (p = buf, pe = buf + size - 3; p <= pe; p++)
	{
		int pn;
		if (p[0] != 0xff)
			continue;
		pn = p[1];
		if ((pn & 0xf8) != 0xf8 || // currently must be MPEG1
		    (pn & 6) == 0) {       // invalid layer
			p++; continue;
		}
		pn = p[2];
		if ((pn & 0xf0) < 0x20 || (pn & 0xf0) == 0xf0 || // bitrates
		    (pn & 0x0c) != 0) { // not 44kHz
			continue;
		}

		return p - buf;
	}

	return -1;
}

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

	if (!(PicoOpt & POPT_EN_MCD_CDDA) || f == NULL) // cdda disabled or no file?
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

void mp3_update(int *buffer, int length, int stereo)
{
	int length_mp3, shr = 0;
	void (*mix_samples)(int *dest_buf, short *mp3_buf, int count) = mix_16h_to_32;

	if (mp3_current_file == NULL || mp3_file_pos >= mp3_file_len)
		return; /* no file / EOF */

	if (!decoder_active)
		return;

	length_mp3 = length;
	if (PsndRate <= 11025 + 100) {
		mix_samples = mix_16h_to_32_s2;
		length_mp3 <<= 2; shr = 2;
	}
	else if (PsndRate <= 22050 + 100) {
		mix_samples = mix_16h_to_32_s1;
		length_mp3 <<= 1; shr = 1;
	}

	if (1152 - cdda_out_pos >= length_mp3) {
		mix_samples(buffer, cdda_out_buffer + cdda_out_pos * 2,
			length * 2);

		cdda_out_pos += length_mp3;
	} else {
		int ret, left = 1152 - cdda_out_pos;

		if (left > 0)
			mix_samples(buffer, cdda_out_buffer + cdda_out_pos * 2,
				(left >> shr) * 2);

		ret = mp3dec_decode(mp3_current_file, &mp3_file_pos,
			mp3_file_len);
		if (ret == 0) {
			cdda_out_pos = length_mp3 - left;
			mix_samples(buffer + (left >> shr) * 2,
				cdda_out_buffer,
				(cdda_out_pos >> shr) * 2);
		} else
			cdda_out_pos = 0;
	}
}

