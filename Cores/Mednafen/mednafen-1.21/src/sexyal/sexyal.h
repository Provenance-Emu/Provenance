/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/types.h>
#include <mednafen/string/string.h>

struct SexyAL_DriverInfo
{
	// Pointers to statically-allocated strings, DO NOT FREE.
	const char* short_name;
	const char* name;
	int type;
	//bool lfn_lowlatency;	// Large frames(higher bit depth, more channels) needed for low latency(e.g. small period sizes)
};

enum
{
 SEXYAL_ENC_PCM_UINT = 0x0,
 SEXYAL_ENC_PCM_SINT = 0x1,
 SEXYAL_ENC_PCM_FLOAT = 0xF
};

#define SAMPFORMAT_ENC(f) 	(((f) >>  0) &  0xF)
#define SAMPFORMAT_BYTES(f) 	(((f) >>  4) &  0xF)
#define SAMPFORMAT_BITS(f) 	(((f) >>  8) & 0xFF)
#define SAMPFORMAT_LSBPAD(f)	(((f) >> 16) & 0xFF)
#define SAMPFORMAT_BIGENDIAN(f) (bool)((f) & 0x80000000U)

#define SAMPFORMAT_MAKE(encoding, bytes, bits, lsbpad, bigendian)	\
	( (((encoding) & 0xF) << 0) |					\
	  (((bytes) & 0xF) << 4) |					\
	  (((bits) & 0xFF) << 8) |					\
	  (((lsbpad) & 0xFF) << 16) | 					\
	  ((uint32)(bool)(bigendian) << 31)				\
	)

struct SexyAL_format
{
	uint32 sampformat;
	uint32 channels;	/* 1 = mono, 2 = stereo (actual device output channels will be 1<=ch<=8, however, 
				   source format MUST be 1 or 2, since the converter can't handle other numbers of source
				   channels) */
	uint32 rate;		/* Number of frames per second, 22050, 44100, etc. */
	bool noninterleaved;	/* 0 = Interleaved multichannel audio(stereo), 1 = Non-Interleaved */
};

struct SexyAL_buffering
{
	/* Inputs(requested) and Outputs(obtained; dev-note: ms and period_us outputs calculated by core SexyAL code, not sound device interface/driver code) */
	uint32 ms;		/* Desired buffer size, in milliseconds. */
	uint32 period_us;	/* Desired period size, in MICROseconds */
	bool overhead_kludge;	/* If true, and ms is non-zero, and we're using driver "dsound", add 20 to ms when calculating the buffer size.

				   Implemented this way to preserve "sound.buffer_time" setting semantics from older versions of Mednafen.
				*/

	/* Outputs Only(obtained) */
	uint32 buffer_size;	/* Buffer size(as in the maximum value returned by CanWrite()). In frames. */
	uint32 period_size;	/* Period/Fragment size.  In frames. */
	uint32 latency;	/* Estimated total latency(between first Write() and actual sound output; essentially equal to the maximum value of
				   CanWrite() plus any additional internal or external buffering). In frames. */

	uint32 bt_gran;	/* Buffer timing granularity(RawWrite() blocking, RawCanWrite() granularity), best-case.  In frames.
				   If 0, period_size is the granularity. */

        //uint32 ms;            /* Milliseconds of buffering, approximate(application code should set this value to control buffer size). */
	//uint32 period_time;	/* If non-zero, specifies the desired period/fragment size, in frames. */
	//uint32 size;		/* Shouldn't be filled in by application code. */
	//uint32 latency;	/* Estimated latency between Write() and sound output, in frames. */
};


// Bits 4 through 7 should reflect the byte count for each sample.
// If the format is integer PCM, bit 0 should be 0 if unsigned, 1 if signed.
enum
{
 SEXYAL_FMT_PCMU8  = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 1,  8, 0, false),
 SEXYAL_FMT_PCMS8  = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 1,  8, 0, false),

 SEXYAL_FMT_PCMU16_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 2, 16, 0, false),
 SEXYAL_FMT_PCMS16_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 2, 16, 0, false),
 SEXYAL_FMT_PCMU16_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 2, 16, 0, true),
 SEXYAL_FMT_PCMS16_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 2, 16, 0, true),

 SEXYAL_FMT_PCMU24_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 4, 24, 0, false),
 SEXYAL_FMT_PCMS24_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 4, 24, 0, false),
 SEXYAL_FMT_PCMU24_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 4, 24, 0, true),
 SEXYAL_FMT_PCMS24_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 4, 24, 0, true),

 SEXYAL_FMT_PCMU32_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 4, 32, 0, false),
 SEXYAL_FMT_PCMS32_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 4, 32, 0, false),
 SEXYAL_FMT_PCMU32_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 4, 32, 0, true),
 SEXYAL_FMT_PCMS32_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 4, 32, 0, true),

 SEXYAL_FMT_PCMFLOAT_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_FLOAT, 4, 32, 0, false),
 SEXYAL_FMT_PCMFLOAT_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_FLOAT, 4, 32, 0, true),

 SEXYAL_FMT_PCMU18_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 18, 0, false),
 SEXYAL_FMT_PCMS18_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 18, 0, false),
 SEXYAL_FMT_PCMU18_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 18, 0, true),
 SEXYAL_FMT_PCMS18_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 18, 0, true),

 SEXYAL_FMT_PCMU20_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 20, 0, false),
 SEXYAL_FMT_PCMS20_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 20, 0, false),
 SEXYAL_FMT_PCMU20_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 20, 0, true),
 SEXYAL_FMT_PCMS20_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 20, 0, true),

 SEXYAL_FMT_PCMU24_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 24, 0, false),
 SEXYAL_FMT_PCMS24_3BYTE_LE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 24, 0, false),
 SEXYAL_FMT_PCMU24_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_UINT, 3, 24, 0, true),
 SEXYAL_FMT_PCMS24_3BYTE_BE = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, 3, 24, 0, true),

#ifdef MSB_FIRST
 SEXYAL_FMT_PCMU16 = SEXYAL_FMT_PCMU16_BE,
 SEXYAL_FMT_PCMS16 = SEXYAL_FMT_PCMS16_BE,

 SEXYAL_FMT_PCMU24 = SEXYAL_FMT_PCMU24_BE,
 SEXYAL_FMT_PCMS24 = SEXYAL_FMT_PCMS24_BE,

 SEXYAL_FMT_PCMU32 = SEXYAL_FMT_PCMU32_BE,
 SEXYAL_FMT_PCMS32 = SEXYAL_FMT_PCMS32_BE,

 SEXYAL_FMT_PCMFLOAT = SEXYAL_FMT_PCMFLOAT_BE
#else
 SEXYAL_FMT_PCMU16 = SEXYAL_FMT_PCMU16_LE,
 SEXYAL_FMT_PCMS16 = SEXYAL_FMT_PCMS16_LE,

 SEXYAL_FMT_PCMU24 = SEXYAL_FMT_PCMU24_LE,
 SEXYAL_FMT_PCMS24 = SEXYAL_FMT_PCMS24_LE,

 SEXYAL_FMT_PCMU32 = SEXYAL_FMT_PCMU32_LE,
 SEXYAL_FMT_PCMS32 = SEXYAL_FMT_PCMS32_LE,

 SEXYAL_FMT_PCMFLOAT = SEXYAL_FMT_PCMFLOAT_LE
#endif
};

typedef struct __SexyAL_device
{
	int (*SetConvert)(struct __SexyAL_device *, SexyAL_format *);
	int (*Write)(struct __SexyAL_device *, void *data, uint32 frames);


	// Returns the number of frames that can be written via Write() without blocking.
	// This number may be partially estimated for some drivers, and it may be higher than the actual
	// amount of data that can be written without blocking.  Additionally, it will not be higher
	// than the buffer size(unless there's a bug somewhere ;) ).
	// So, try to use this function for advisory timing purposes only.
	uint32 (*CanWrite)(struct __SexyAL_device *);

        int (*Close)(struct __SexyAL_device *);

	// Returns 1 on success, 0 on failure(failure if the new pause state equals the old pause state, or another
	// problem occurs).
	int (*Pause)(struct __SexyAL_device *, int state);

	// Clears all audio data pending play on the output device.
	// Returns 1 on success, 0 on failure.
	int (*Clear)(struct __SexyAL_device *);

	// Writes "bytes" bytes of data from "data" to the device, blocking if necessary.
	// Returns 1 on success, 0 on failure(probably fatal).
        int (*RawWrite)(struct __SexyAL_device *, const void *data, uint32 bytes);

	// Sets *count to the number of bytes that can be written to the device without blocking.
	// Returns 1 on success, 0 on failure(probably fatal).
        int (*RawCanWrite)(struct __SexyAL_device *, uint32 *can_write);

	// Closes the device.
	// Returns 1 on success, 0 on failure(failure should indicate some resources may be left open/allocated due to
	// an erro, but calling RawClose() again is illegal).
        int (*RawClose)(struct __SexyAL_device *);

	SexyAL_format format;
	SexyAL_format srcformat;
	SexyAL_buffering buffering;
	void *private_data;

	void *convert_buffer;
	uint32 convert_buffer_fsize;
} SexyAL_device;

typedef struct __SexyAL_enumdevice
{
        char *name;
        char *id;
        struct __SexyAL_enumdevice *next;
} SexyAL_enumdevice;

enum
{
 SEXYAL_TYPE_OSSDSP = 0x001,
 SEXYAL_TYPE_ALSA = 0x002,
 SEXYAL_TYPE_OPENBSD = 0x003,

 SEXYAL_TYPE_DIRECTSOUND = 0x010,
 SEXYAL_TYPE_WASAPI = 0x011,
 SEXYAL_TYPE_WASAPISH = 0x012,

 SEXYAL_OSX_COREAUDIO = 0x030,	/* TODO */

 SEXYAL_TYPE_ESOUND = 0x100,
 SEXYAL_TYPE_JACK = 0x101,
 SEXYAL_TYPE_SDL = 0x102,

 SEXYAL_TYPE_DOS_SB = 0x180,
 SEXYAL_TYPE_DOS_ES1370 = 0x181,
 SEXYAL_TYPE_DOS_ES1371 = 0x182,
 SEXYAL_TYPE_DOS_CMI8738 = 0x183,

 SEXYAL_TYPE_DUMMY = 0x1FF
};

SexyAL_device* SexyAL_Open(const char *id, SexyAL_format *, SexyAL_buffering *buffering, int type);
SexyAL_enumdevice* SexyAL_EnumerateDevices(int type);

//
// Returns a list(vector :p) describing drivers that are compiled-in.
//
std::vector<SexyAL_DriverInfo> SexyAL_GetDriverList(void);

//
// To find the default driver, set name to NULL or "default"
//
bool SexyAL_FindDriver(SexyAL_DriverInfo* out_di, const char* name);

