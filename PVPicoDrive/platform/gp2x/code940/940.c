// The top-level functions for the ARM940
// (c) Copyright 2006-2007, Grazvydas "notaz" Ignotas

#include "940shared.h"
#include "../../common/mp3.h"

static _940_data_t *shared_data = (_940_data_t *)   0x00100000;
static _940_ctl_t  *shared_ctl  = (_940_ctl_t *)    0x00200000;
static unsigned char *mp3_data  = (unsigned char *) 0x00400000;
YM2612 *ym2612_940;

// from init.s
int  wait_get_job(int oldjob);
void spend_cycles(int c);
void dcache_clean(void);
void dcache_clean_flush(void);
void drain_wb(void);
// this should help to resolve race confition where shared var
// is changed by other core just before we update it
void set_if_not_changed(int *val, int oldval, int newval);

void _memcpy(void *dst, const void *src, int count);

//	asm volatile ("mov r0, #0" ::: "r0");
//	asm volatile ("mcr p15, 0, r0, c7, c6,  0" ::: "r0"); /* flush dcache */
//	asm volatile ("mcr p15, 0, r0, c7, c10, 4" ::: "r0"); /* drain write buffer */


static void mp3_decode(void)
{
	int mp3_offs = shared_ctl->mp3_offs;
	unsigned char *readPtr = mp3_data + mp3_offs;
	int bytesLeft = shared_ctl->mp3_len - mp3_offs;
	int offset; // frame offset from readPtr
	int retries = 0, err;

	if (bytesLeft <= 0) return; // EOF, nothing to do

	for (retries = 0; retries < 2; retries++)
	{
		offset = mp3_find_sync_word(readPtr, bytesLeft);
		if (offset < 0)
			goto set_eof;

		readPtr += offset;
		bytesLeft -= offset;

		err = MP3Decode(shared_data->mp3dec, &readPtr, &bytesLeft,
				shared_data->mp3_buffer[shared_ctl->mp3_buffsel], 0);
		if (err) {
			if (err == ERR_MP3_MAINDATA_UNDERFLOW)
				// just need another frame
				continue;

			if (err == ERR_MP3_INDATA_UNDERFLOW)
				goto set_eof;

			if (err <= -6 && err >= -12) {
				// ERR_MP3_INVALID_FRAMEHEADER, ERR_MP3_INVALID_*
				// just try to skip the offending frame..
				readPtr++;
				bytesLeft--;
				continue;
			}
			shared_ctl->mp3_errors++;
			shared_ctl->mp3_lasterr = err;
		}
		break;
	}

	set_if_not_changed(&shared_ctl->mp3_offs, mp3_offs, readPtr - mp3_data);
	return;

set_eof:
	set_if_not_changed(&shared_ctl->mp3_offs, mp3_offs, shared_ctl->mp3_len);
}

static void ym_flush_writes(void)
{
	UINT16 *wbuff;
	int i;

	if (shared_ctl->writebuffsel == 1) {
		wbuff = shared_ctl->writebuff1;
	} else {
		wbuff = shared_ctl->writebuff0;
	}

	/* playback all writes */
	for (i = 2048; i > 0; i--) {
		UINT16 d = *wbuff++;
		if (d == 0xffff) break;
		if (d == 0xfffe) continue;
		YM2612Write_(d >> 8, d);
	}
}

static void ym_update(int *ym_buffer)
{
	int i, dw;
	int two_upds = 0;
	UINT16 *wbuff;

	if (shared_ctl->writebuffsel == 1) {
		wbuff = shared_ctl->writebuff1;
	} else {
		wbuff = shared_ctl->writebuff0;
	}

	/* playback all writes */
	for (i = 2048/2; i > 0; i--) {
		UINT16 d;
		dw = *(int *)wbuff;
		d = dw;
		wbuff++;
		if (d == 0xffff) break;
		if (d == 0xfffe) { two_upds=1; break; }
		YM2612Write_(d >> 8, d);
		d = (dw>>16);
		wbuff++;
		if (d == 0xffff) break;
		if (d == 0xfffe) { two_upds=1; break; }
		YM2612Write_(d >> 8, d);
	}

	if (two_upds)
	{
		int len1 = shared_ctl->length / 2;
		shared_ctl->ym_active_chs =
			YM2612UpdateOne_(ym_buffer, len1, shared_ctl->stereo, 1);

		for (i *= 2; i > 0; i--) {
			UINT16 d = *wbuff++;
			if (d == 0xffff) break;
			YM2612Write_(d >> 8, d);
		}

		ym_buffer += shared_ctl->stereo ? len1*2 : len1;
		len1 = shared_ctl->length - len1;

		shared_ctl->ym_active_chs =
			YM2612UpdateOne_(ym_buffer, len1, shared_ctl->stereo, 1);
	} else {
		shared_ctl->ym_active_chs =
			YM2612UpdateOne_(ym_buffer, shared_ctl->length, shared_ctl->stereo, 1);
	}
}


void Main940(void)
{
	int *ym_buffer = shared_data->ym_buffer;
	int job = 0;
	ym2612_940 = &shared_data->ym2612;


	for (;;)
	{
		job = wait_get_job(job);

		shared_ctl->lastjob = job;

		switch (job)
		{
			case JOB940_INITALL:
				/* ym2612 */
				shared_ctl->writebuff0[0] = shared_ctl->writebuff1[0] = 0xffff;
				YM2612Init_(shared_ctl->baseclock, shared_ctl->rate);
				/* Helix mp3 decoder */
				shared_data->mp3dec = MP3InitDecoder();
				break;

			case JOB940_INVALIDATE_DCACHE:
				drain_wb();
				dcache_clean_flush();
				break;

			case JOB940_YM2612RESETCHIP:
				YM2612ResetChip_();
				break;

			case JOB940_PICOSTATELOAD:
				YM2612PicoStateLoad_();
				break;

			case JOB940_PICOSTATESAVE2:
				YM2612PicoStateSave2(0, 0);
				_memcpy(shared_ctl->writebuff0, ym2612_940->REGS, 0x200);
				break;

			case JOB940_PICOSTATELOAD2_PREP:
				ym_flush_writes();
				break;

			case JOB940_PICOSTATELOAD2:
				_memcpy(ym2612_940->REGS, shared_ctl->writebuff0, 0x200);
				YM2612PicoStateLoad2(0, 0);
				break;

			case JOB940_YM2612UPDATEONE:
				ym_update(ym_buffer);
				break;

			case JOB940_MP3DECODE:
				mp3_decode();
				break;

			case JOB940_MP3RESET:
				if (shared_data->mp3dec) MP3FreeDecoder(shared_data->mp3dec);
				shared_data->mp3dec = MP3InitDecoder();
				break;
		}

		shared_ctl->loopc++;
		dcache_clean();
	}
}

