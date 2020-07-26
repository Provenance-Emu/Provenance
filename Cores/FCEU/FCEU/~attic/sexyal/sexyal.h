#include <inttypes.h>

typedef struct
{
	uint32_t sampformat;
	uint32_t channels;	/* 1 = mono, 2 = stereo */
	uint32_t rate;		/* Number of frames per second, 22050, 44100, etc. */
	uint32_t byteorder;	/* 0 = Native(to CPU), 1 = Reversed.  PDP can go to hell. */
} SexyAL_format;

typedef struct
{
	uint32_t fragcount;
	uint32_t fragsize;
	uint32_t totalsize;	/* Shouldn't be filled in by application code. */
	uint32_t ms;		/* Milliseconds of buffering, approximate. */
} SexyAL_buffering;

#define SEXYAL_ID_DEFAULT       0
#define SEXYAL_ID_UNUSED        1

#define SEXYAL_FMT_PCMU8        0x10
#define SEXYAL_FMT_PCMS8        0x11

#define SEXYAL_FMT_PCMU16       0x20
#define SEXYAL_FMT_PCMS16        0x21

#define SEXYAL_FMT_PCMU32U24        0x40
#define SEXYAL_FMT_PCMS32S24        0x41

#define SEXYAL_FMT_PCMU32U16        0x42
#define SEXYAL_FMT_PCMS32S16        0x43

typedef struct __SexyAL_device {
	int (*SetConvert)(struct __SexyAL_device *, SexyAL_format *);
	uint32_t (*Write)(struct __SexyAL_device *, void *data, uint32_t frames);
	uint32_t (*CanWrite)(struct __SexyAL_device *);
        int (*Close)(struct __SexyAL_device *);
	SexyAL_format format;
	SexyAL_format srcformat;
	SexyAL_buffering buffering;
	void *private;
} SexyAL_device;

typedef struct __SexyAL {
        SexyAL_device * (*Open)(struct __SexyAL *, uint64_t id, SexyAL_format *, SexyAL_buffering *buffering);
	void (*Enumerate)(struct __SexyAL *, int (*func)(uint8_t *name, uint64_t id, void *udata));
	void (*Destroy)(struct __SexyAL *);
} SexyAL;

/* Initializes the library, requesting the interface of the version specified. */
void *SexyAL_Init(int version);
