#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>

#include "940shared.h"
#include "../gp2x.h"
//#include "emu.h"
//#include "menu.h"
#include "../asmutils.h"
#include "../helix/pub/mp3dec.h"

/* we will need some gp2x internals here */
extern volatile unsigned short *gp2x_memregs; /* from minimal library rlyeh */
extern volatile unsigned long  *gp2x_memregl;

static unsigned char *shared_mem = 0;
static _940_data_t *shared_data = 0;
static _940_ctl_t *shared_ctl = 0;
static unsigned char *mp3_mem = 0;

#define MP3_SIZE_MAX (0x1000000 - 4*640*480)

int crashed_940 = 0;


/***********************************************************/

#define MAXOUT		(+32767)
#define MINOUT		(-32768)

/* limitter */
#define Limit(val, max,min) { \
	if ( val > max )      val = max; \
	else if ( val < min ) val = min; \
}


void wait_busy_940(void)
{
	int i;
#if 0
	printf("940 busy, entering wait loop.. (cnt: %i, wc: %i, ve: ", shared_ctl->loopc, shared_ctl->waitc);
	for (i = 0; i < 8; i++)
		printf("%i ", shared_ctl->vstarts[i]);
	printf(")\n");

	for (i = 0; shared_ctl->busy; i++)
	{
		spend_cycles(1024); /* needs tuning */
	}
	printf("wait iterations: %i\n", i);
#else
	for (i = 0; shared_ctl->busy && i < 0x10000; i++)
		spend_cycles(8*1024);
	if (i < 0x10000) return;

	/* 940 crashed */
	printf("940 crashed (cnt: %i, ve: ", shared_ctl->loopc);
	for (i = 0; i < 8; i++)
		printf("%i ", shared_ctl->vstarts[i]);
	printf(")\n");
	crashed_940 = 1;
#endif
}


void add_job_940(int job0, int job1)
{
	shared_ctl->jobs[0] = job0;
	shared_ctl->jobs[1] = job1;
	shared_ctl->busy = 1;
	gp2x_memregs[0x3B3E>>1] = 0xffff; // cause an IRQ for 940
}


static int read_to_upper(void *dest, void *tmpbuf, int tmpsize, FILE *f)
{
	int nRead, nLen = 0;

	while(1)
	{
		nRead = fread(tmpbuf, 1, tmpsize, f);
		if(nRead <= 0)
			break;
		memcpy((unsigned char *)dest + nLen, tmpbuf, nRead);
		nLen += nRead;
	}

	return nLen;
}

static void simpleWait(int thissec, int lim_time)
{
	struct timeval tval;

	spend_cycles(1024);
	gettimeofday(&tval, 0);
	if(thissec != tval.tv_sec) tval.tv_usec+=1000000;

	while(tval.tv_usec < lim_time)
	{
		spend_cycles(1024);
		gettimeofday(&tval, 0);
		if(thissec != tval.tv_sec) tval.tv_usec+=1000000;
	}
}


char **g_argv;

/* none of the functions in this file should be called before this one */
void YM2612Init_940(int baseclock, int rate)
{
	printf("YM2612Init_940()\n");
	printf("Mem usage: shared_data: %i, shared_ctl: %i\n", sizeof(*shared_data), sizeof(*shared_ctl));

	Reset940(1, 2);
	Pause940(1);

	gp2x_memregs[0x3B46>>1] = 0xffff; // clear pending DUALCPU interrupts for 940
	gp2x_memregs[0x3B42>>1] = 0xffff; // enable DUALCPU interrupts for 940

	gp2x_memregl[0x4508>>2] = ~(1<<26); // unmask DUALCPU ints in the undocumented 940's interrupt controller

	if (shared_mem == NULL)
	{
		shared_mem = (unsigned char *) mmap(0, 0x210000, PROT_READ|PROT_WRITE, MAP_SHARED, memdev, 0x2000000);
		if(shared_mem == MAP_FAILED)
		{
			printf("mmap(shared_data) failed with %i\n", errno);
			exit(1);
		}
		shared_data = (_940_data_t *) (shared_mem+0x100000);
		/* this area must not get buffered on either side */
		shared_ctl =  (_940_ctl_t *)  (shared_mem+0x200000);
		mp3_mem = (unsigned char *) mmap(0, MP3_SIZE_MAX, PROT_READ|PROT_WRITE, MAP_SHARED, memdev, 0x3000000);
		if (mp3_mem == MAP_FAILED)
		{
			printf("mmap(mp3_mem) failed with %i\n", errno);
			exit(1);
		}
		crashed_940 = 1;
	}

	if (crashed_940)
	{
		unsigned char ucData[1024];
		int i;
		char binpath[1024];
		FILE *fp;

		strncpy(binpath, g_argv[0], 1023);
		binpath[1023] = 0;
		for (i = strlen(binpath); i > 0; i--)
			if (binpath[i] == '/') { binpath[i] = 0; break; }
		strcat(binpath, "/code940.bin");

		fp = fopen(binpath, "rb");
		if(!fp)
		{
			printf("failed to open %s\n", binpath);
			exit(1);
		}

		read_to_upper(shared_mem, ucData, sizeof(ucData), fp);
		fclose(fp);
		crashed_940 = 0;
	}

	memset(shared_data, 0, sizeof(*shared_data));
	memset(shared_ctl,  0, sizeof(*shared_ctl));

	/* now cause 940 to init it's ym2612 stuff */
	shared_ctl->baseclock = baseclock;
	shared_ctl->rate = rate;
	shared_ctl->jobs[0] = JOB940_INITALL;
	shared_ctl->jobs[1] = 0;
	shared_ctl->busy = 1;

	/* start the 940 */
	Reset940(0, 2);
	Pause940(0);
}


unsigned char *mp3_data = 0;

void local_decode(void)
{
	int mp3_offs = shared_ctl->mp3_offs;
	unsigned char *readPtr = mp3_data + mp3_offs;
	int bytesLeft = shared_ctl->mp3_len - mp3_offs;
	int offset; // frame offset from readPtr
	int err = 0;

	if (bytesLeft <= 0) return; // EOF, nothing to do

	offset = MP3FindSyncWord(readPtr, bytesLeft);
	if (offset < 0) {
		shared_ctl->mp3_offs = shared_ctl->mp3_len;
		return; // EOF
	}
	readPtr += offset;
	bytesLeft -= offset;

	err = MP3Decode(shared_data->mp3dec, &readPtr, &bytesLeft,
			shared_data->mp3_buffer[shared_ctl->mp3_buffsel], 0);
	if (err) {
		if (err == ERR_MP3_INDATA_UNDERFLOW) {
			shared_ctl->mp3_offs = shared_ctl->mp3_len; // EOF
			return;
		} else if (err <= -6 && err >= -12) {
			// ERR_MP3_INVALID_FRAMEHEADER, ERR_MP3_INVALID_*
			// just try to skip the offending frame..
			readPtr++;
		}
		shared_ctl->mp3_errors++;
		shared_ctl->mp3_lasterr = err;
	}
	shared_ctl->mp3_offs = readPtr - mp3_data;
}


void gp2x_sound_sync(void);

#define USE_LOCAL 0
#define BENCHMARK 0

int main(int argc, char *argv[])
{
	FILE *f;
	int size;
	struct timeval tval; // timing
	int thissec = 0, fps = 0;
	int target_frametime, frame_samples, samples_ready, mp3_buffer_offs, play_bufsel;
	unsigned char play_buffer[44100/50*2*2];

	if (argc != 2) {
		printf("usage: %s <mp3file>\n", argv[0]);
		return 1;
	}

	g_argv = argv;

	gp2x_init();
	YM2612Init_940(123, 44100);

	// load a mp3
	f = fopen(argv[1], "rb");
	if (!f) {
		printf("can't open %s\n", argv[1]);
		return 1;
	}

	fseek(f, 0, SEEK_END);
	size = (int) ftell(f);
	if (size > MP3_SIZE_MAX) {
		printf("size %i > %i\n", size, MP3_SIZE_MAX);
		size = MP3_SIZE_MAX;
	}

	fseek(f, 0, SEEK_SET);
	if (fread(mp3_mem, 1, size, f) != size) {
		printf("read failed, errno=%i\n", errno);
		fclose(f);
		exit(1);
	}
	fclose(f);
	shared_ctl->mp3_len = size;

#if USE_LOCAL
	shared_data->mp3dec = MP3InitDecoder();
	mp3_data = malloc(size);
	printf("init: dec: %p ptr: %p\n", shared_data->mp3dec, mp3_data);
	if (!mp3_data) {
		printf("low mem\n");
		exit(1);
	}
	memcpy(mp3_data, mp3_mem, size);
#else
	//printf("YM2612UpdateOne_940()\n");
	if (shared_ctl->busy) wait_busy_940();
#endif

	gp2x_start_sound(44100, 16, 1);

	#define DESIRED_FPS 50
	target_frametime = 1000000/DESIRED_FPS;
	frame_samples = 44100/DESIRED_FPS;
	samples_ready = mp3_buffer_offs = 0;
	play_bufsel = 1;

	for (;; fps++)
	{
		int lim_time;

		gettimeofday(&tval, 0);
		if (tval.tv_sec != thissec)
		{
			printf("fps: %i\n", fps);
			thissec = tval.tv_sec;
			fps = 0;
#if BENCHMARK
			shared_ctl->mp3_offs = 0;
#endif
		}

#if 0
		// decode
#if USE_LOCAL
		shared_ctl->mp3_buffsel ^= 1;
		local_decode();
#else
		wait_busy_940();
		shared_ctl->mp3_buffsel ^= 1;
		add_job_940(JOB940_MP3DECODE, 0);
#endif

		if (shared_ctl->mp3_lasterr) {
			printf("mp3_lasterr #%i: %i size: %i offs: %i\n", shared_ctl->mp3_errors, shared_ctl->mp3_lasterr,
				shared_ctl->mp3_len, shared_ctl->mp3_offs);
			printf("loopc: %i bytes: %08x\n",
				shared_ctl->loopc, *(int *)(mp3_mem+shared_ctl->mp3_offs));
			shared_ctl->mp3_lasterr = 0;
		}

#if !BENCHMARK
		// play
		gp2x_sound_sync();
		gp2x_sound_write(shared_data->mp3_buffer[shared_ctl->mp3_buffsel^1], 1152*2*2);
#endif
#else
		lim_time = (fps+1) * target_frametime;

		wait_busy_940();

		// decode, play
		if (samples_ready >= frame_samples) {
			if (1152 - mp3_buffer_offs >= frame_samples) {
				memcpy(play_buffer, shared_data->mp3_buffer[play_bufsel] + mp3_buffer_offs*2,
					frame_samples*2*2);
				mp3_buffer_offs += frame_samples;
			} else {
				// collect from both buffers..
				int left = 1152 - mp3_buffer_offs;
				memcpy(play_buffer, shared_data->mp3_buffer[play_bufsel] + mp3_buffer_offs*2,
					left*2*2);
				play_bufsel ^= 1;
				mp3_buffer_offs = frame_samples - left;
				memcpy(play_buffer + left*2*2, shared_data->mp3_buffer[play_bufsel],
					mp3_buffer_offs*2*2);
			}
			gp2x_sound_write(play_buffer, frame_samples*2*2);
			samples_ready -= frame_samples;
		}

		// make sure we will have enough samples next frame
		if (samples_ready < frame_samples) {
//			wait_busy_940();
			shared_ctl->mp3_buffsel ^= 1;
			add_job_940(JOB940_MP3DECODE, 0);
			samples_ready += 1152;
		}

		gettimeofday(&tval, 0);
		if(thissec != tval.tv_sec) tval.tv_usec+=1000000;
		if(tval.tv_usec < lim_time)
		{
			// we are too fast
			simpleWait(thissec, lim_time);
		}
#endif
	}

	return 0;
}

