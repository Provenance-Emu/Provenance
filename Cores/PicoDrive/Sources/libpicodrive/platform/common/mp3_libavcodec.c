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
#include "mp3.h"

#if LIBAVCODEC_VERSION_MAJOR < 55
#define AVCodecID CodecID
#define AV_CODEC_ID_MP3 CODEC_ID_MP3
#define AV_CH_LAYOUT_STEREO CH_LAYOUT_STEREO
#define AV_SAMPLE_FMT_S16 SAMPLE_FMT_S16
#define request_sample_fmt sample_fmt
#endif

static void *libavcodec;
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
	int len = -1;
	int retry = 3;

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
		*file_pos += offset;

		// to avoid being flooded with "incorrect frame size" errors,
		// we must calculate and pass exact frame size - lame
		frame_size = mpeg1_l3_bitrates[input_buf[offset + 2] >> 4];
		frame_size = frame_size * 144000 / 44100;
		frame_size += (input_buf[offset + 2] >> 1) & 1;

		if (offset > 0 && bytes_in - offset < frame_size) {
			// underflow
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
			*file_pos += 1;
		} else
			*file_pos += len;
	}
	while (len <= 0 && --retry > 0);

	return len <= 0;
}

int mp3dec_start(FILE *f, int fpos_start)
{
	void (*avcodec_register_all)(void);
	AVCodec *(*avcodec_find_decoder)(enum AVCodecID id);
#if LIBAVCODEC_VERSION_MAJOR < 54
	AVCodecContext *(*avcodec_alloc_context)(void);
	int (*avcodec_open)(AVCodecContext *avctx, AVCodec *codec);
#else
	AVCodecContext *(*avcodec_alloc_context)(AVCodec *);
	int (*avcodec_open)(AVCodecContext *avctx, AVCodec *codec, AVDictionary **);
#endif
	void (*av_free)(void *ptr);
	AVCodec *codec;
	int ret;

	if (ctx != NULL)
		return 0;

#if LIBAVCODEC_VERSION_MAJOR < 54
	// either v52 or v53 should be ok
	if (libavcodec == NULL)
		libavcodec = dlopen("libavcodec.so.52", RTLD_NOW);
	if (libavcodec == NULL)
		libavcodec = dlopen("libavcodec.so.53", RTLD_NOW);
#else
	if (libavcodec == NULL)
		libavcodec = dlopen("libavcodec.so", RTLD_NOW);
#endif
	if (libavcodec == NULL) {
		lprintf("mp3dec: load libavcodec.so: %s\n", dlerror());
		return -1;
	}

	avcodec_register_all = dlsym(libavcodec, "avcodec_register_all");
	avcodec_find_decoder = dlsym(libavcodec, "avcodec_find_decoder");
#if LIBAVCODEC_VERSION_MAJOR < 54
	avcodec_alloc_context = dlsym(libavcodec, "avcodec_alloc_context");
	avcodec_open = dlsym(libavcodec, "avcodec_open");
#else
	avcodec_alloc_context = dlsym(libavcodec, "avcodec_alloc_context3");
	avcodec_open = dlsym(libavcodec, "avcodec_open2");
#endif
	av_free = dlsym(libavcodec, "av_free");
	p_av_init_packet = dlsym(libavcodec, "av_init_packet");
	p_avcodec_decode_audio3 = dlsym(libavcodec, "avcodec_decode_audio3");

	if (avcodec_register_all == NULL || avcodec_find_decoder == NULL
	    || avcodec_alloc_context == NULL || avcodec_open == NULL
	    || av_free == NULL
	    || p_av_init_packet == NULL || p_avcodec_decode_audio3 == NULL)
	{
		lprintf("mp3dec: missing symbol(s) in libavcodec.so\n");
		return -1;
	}

	// init decoder

	//avcodec_init();
	avcodec_register_all();

	codec = avcodec_find_decoder(AV_CODEC_ID_MP3);
	if (codec == NULL) {
		lprintf("mp3dec: codec missing\n");
		return -1;
	}

#if LIBAVCODEC_VERSION_MAJOR < 54
	ctx = avcodec_alloc_context();
	if (ctx == NULL) {
		lprintf("mp3dec: avcodec_alloc_context failed\n");
		return -1;
	}
#else
	ctx = avcodec_alloc_context(codec);
	if (ctx == NULL) {
		lprintf("mp3dec: avcodec_alloc_context failed\n");
		return -1;
	}
#endif
	ctx->request_channel_layout = AV_CH_LAYOUT_STEREO;
	ctx->request_sample_fmt = AV_SAMPLE_FMT_S16;
	ctx->sample_rate = 44100;

#if LIBAVCODEC_VERSION_MAJOR < 54
	ret = avcodec_open(ctx, codec);
	if (ret < 0) {
		lprintf("mp3dec: avcodec_open failed: %d\n", ret);
		av_free(ctx);
		ctx = NULL;
		return -1;
	}
#else
	ret = avcodec_open(ctx, codec, NULL);
	if (ret < 0) {
		lprintf("mp3dec: avcodec_open failed: %d\n", ret);
		av_free(ctx);
		ctx = NULL;
		return -1;
	}
#endif
	return 0;
}
