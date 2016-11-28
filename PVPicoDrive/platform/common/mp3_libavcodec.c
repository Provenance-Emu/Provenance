/*
 * Some mp3 related code for Sega/Mega CD.
 * Uses Libav/FFmpeg libavcodec
 * (C) notaz, 2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>
#include <libavcodec/avcodec.h>
#include <dlfcn.h>

#include <pico/pico_int.h>
#include "../libpicofe/lprintf.h"
#include "mp3.h"

static AVCodecContext *ctx;

/* avoid compile time linking to libavcodec due to huge list of it's deps..
 * we also use this old API as newer one is not available on pandora */
void (*p_av_init_packet)(AVPacket *pkt);
int (*p_avcodec_decode_audio3)(AVCodecContext *avctx, int16_t *samples,
	int *frame_size_ptr, AVPacket *avpkt);

int mp3dec_decode(FILE *f, int *file_pos, int file_len)
{
	unsigned char input_buf[2 * 1024];
	int frame_size;
	AVPacket avpkt;
	int bytes_in;
	int bytes_out;
	int offset;
	int len;

	p_av_init_packet(&avpkt);

	do
	{
		if (*file_pos >= file_len)
			return 1; // EOF, nothing to do

		fseek(f, *file_pos, SEEK_SET);
		bytes_in = fread(input_buf, 1, sizeof(input_buf), f);

		offset = mp3_find_sync_word(input_buf, bytes_in);
		if (offset < 0) {
			lprintf("find_sync_word (%i/%i) err %i\n",
				*file_pos, file_len, offset);
			*file_pos = file_len;
			return 1; // EOF
		}

		// to avoid being flooded with "incorrect frame size" errors,
		// we must calculate and pass exact frame size - lame
		frame_size = mpeg1_l3_bitrates[input_buf[offset + 2] >> 4];
		frame_size = frame_size * 144000 / 44100;
		frame_size += (input_buf[offset + 2] >> 1) & 1;

		if (offset > 0 && bytes_in - offset < frame_size) {
			// underflow
			*file_pos += offset;
			continue;
		}

		avpkt.data = input_buf + offset;
		avpkt.size = frame_size;
		bytes_out = sizeof(cdda_out_buffer);
#if LIBAVCODEC_VERSION_MAJOR < 53
		// stupidity in v52: enforces this size even when
		// it doesn't need/use that much at all
		bytes_out = AVCODEC_MAX_AUDIO_FRAME_SIZE;
#endif

		len = p_avcodec_decode_audio3(ctx, cdda_out_buffer,
			&bytes_out, &avpkt);
		if (len <= 0) {
			lprintf("mp3 decode err (%i/%i) %i\n",
				*file_pos, file_len, len);

			// attempt to skip the offending frame..
			*file_pos += offset + 1;
			continue;
		}

		*file_pos += offset + len;
	}
	while (0);

	return 0;
}

int mp3dec_start(FILE *f, int fpos_start)
{
	void (*avcodec_register_all)(void);
	AVCodec *(*avcodec_find_decoder)(enum CodecID id);
	AVCodecContext *(*avcodec_alloc_context)(void);
	int (*avcodec_open)(AVCodecContext *avctx, AVCodec *codec);
	void (*av_free)(void *ptr);
	AVCodec *codec;
	void *soh;
	int ret;

	if (ctx != NULL)
		return 0;

	// either v52 or v53 should be ok
	soh = dlopen("libavcodec.so.52", RTLD_NOW);
	if (soh == NULL)
		soh = dlopen("libavcodec.so.53", RTLD_NOW);
	if (soh == NULL) {
		lprintf("mp3dec: load libavcodec.so: %s\n", dlerror());
		return -1;
	}

	avcodec_register_all = dlsym(soh, "avcodec_register_all");
	avcodec_find_decoder = dlsym(soh, "avcodec_find_decoder");
	avcodec_alloc_context = dlsym(soh, "avcodec_alloc_context");
	avcodec_open = dlsym(soh, "avcodec_open");
	av_free = dlsym(soh, "av_free");
	p_av_init_packet = dlsym(soh, "av_init_packet");
	p_avcodec_decode_audio3 = dlsym(soh, "avcodec_decode_audio3");

	if (avcodec_register_all == NULL || avcodec_find_decoder == NULL
	    || avcodec_alloc_context == NULL || avcodec_open == NULL
	    || av_free == NULL
	    || p_av_init_packet == NULL || p_avcodec_decode_audio3 == NULL)
	{
		lprintf("mp3dec: missing symbol(s) in libavcodec.so\n");
		dlclose(soh);
		return -1;
	}

	// init decoder

	//avcodec_init();
	avcodec_register_all();

	// AV_CODEC_ID_MP3 ?
	codec = avcodec_find_decoder(CODEC_ID_MP3);
	if (codec == NULL) {
		lprintf("mp3dec: codec missing\n");
		return -1;
	}

	ctx = avcodec_alloc_context();
	if (ctx == NULL) {
		lprintf("mp3dec: avcodec_alloc_context failed\n");
		return -1;
	}

	ret = avcodec_open(ctx, codec);
	if (ret < 0) {
		lprintf("mp3dec: avcodec_open failed: %d\n", ret);
		av_free(ctx);
		ctx = NULL;
		return -1;
	}

	return 0;
}
