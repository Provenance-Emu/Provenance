#include "../../../pico/sound/ym2612.h"

// max 16 jobs, lower num means higher prio
enum _940_job_t {
	JOB940_INITALL = 1,
	JOB940_INVALIDATE_DCACHE,
	JOB940_YM2612RESETCHIP,
	JOB940_YM2612UPDATEONE,
	JOB940_MP3DECODE,
	JOB940_PICOSTATELOAD,
	JOB940_PICOSTATESAVE2,
	JOB940_PICOSTATELOAD2_PREP,
	JOB940_PICOSTATELOAD2,
	JOB940_MP3RESET,
};

//#define MAX_940JOBS	2

typedef struct
{
	YM2612  ym2612;				/* current state of the emulated YM2612 */
	void	*mp3dec;			/* mp3 decoder's handle */
	int     ym_buffer[44100/50*2];		/* this is where the YM2612 samples will be mixed to */
	short   mp3_buffer[2][1152*2];		/* buffers for mp3 decoder's output */
} _940_data_t;


typedef struct
{
	int		vstarts[8];				/* debug: 00: number of starts from each of 8 vectors */
	int		last_lr;				/* debug: 20: last exception's lr */
//	int		jobs[MAX_940JOBS];			/* jobs for second core */
//	int		busy_;					/* unused */
	int		length;					/* number of samples to mix (882 max) */
	int		stereo;					/* mix samples as stereo, doubles sample count automatically */
	int		baseclock;				/* ym2612 settings */
	int		rate;
	int		writebuffsel;			/* which write buffer to use (from 940 side) */
	UINT16  writebuff0[2048];			/* list of writes to ym2612, 1024 for savestates, 1024 extra */
	UINT16  writebuff1[2048];
	int		ym_active_chs;
	int		mp3_len;			/* data len of loaded mp3 */
	int		mp3_offs;			/* current playback offset (just after last decoded frame) */
	int		mp3_buffsel;			/* which output buffer to decode to */
	int		loopc;				/* debug: main loop counter */
	int		mp3_errors;			/* debug: mp3 decoder's error counter */
	int		mp3_lasterr;			/* debug: mp3 decoder's last error */
	int		lastjob;			/* debug: last job id */
} _940_ctl_t;
