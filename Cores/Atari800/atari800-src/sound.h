#ifndef SOUND_H_
#define SOUND_H_

#include <stdio.h>

#include "config.h"
#include "atari.h"

int Sound_Initialise(int *argc, char *argv[]);
void Sound_Exit(void);
void Sound_Update(void);
void Sound_Pause(void);
void Sound_Continue(void);
#ifdef SUPPORTS_SOUND_REINIT
void Sound_Reinit(void);
#endif /* SUPPORTS_SOUND_REINIT */

#ifdef SOUND_THIN_API
/* Nomenclature used:
   Sample - a single portion of one channel of audio signal. Sample size equals
   1 byte for 8-bit audio and 2 bytes for 16-bit audio.
   Frame - a single portion of samples for all channels of audio signal. Frame
   size equals sample size * number of channels.
   The word "size", unless additionally specified, means size in bytes.
 */

typedef struct Sound_setup_t {
	/* Sound sample rate - number of frames per second: 1000..65535. */
	unsigned int freq;
	/* Number of bytes per each sample, also determines sample format:
	   1 = unsigned 8-bit format.
	   2 = signed 16-bit system-endian format. */
	int sample_size;
	/* Number of audio channels: 1 = mono, 2 = stereo. */
	unsigned int channels;
	/* Size of the hardware audio buffer in frames. Should be a power of 2.
	   To get the buffer's size in bytes, compute
	   frag_frames*sample_size*channels. */
	unsigned int frag_frames;
} Sound_setup_t;

/* Holds parameters of the audio output desired by user. When calling Sound_Setup(),
   these parameters are used to open audio output. Audio output may get opened with
   different parameters than the desired ones (e.g. hardware might not support
   the desired parameters), so after opening, the actual parameters of the opened
   output are stored in Sound_out.
   Set Sound_desired.frag_frames to 0 if you want the hardware to decide value of this
   parameter automatically.
 */
extern Sound_setup_t Sound_desired;

/* Holds parameters of the currently-opened hardware audio output. Don't change
   it directly - use Sound_Setup instead. */
extern Sound_setup_t Sound_out;

/* Indicates whether sound output is enabled. Don't change it directly - use
   Sound_Setup to enable sound, and Sound_Exit to disable it. */
extern int Sound_enabled;

/* Enables hardware audio output with parameters based on those stored in
   Sound_desired. Stores the parameters of the actual opened output in
   Sound_out. The actual parameters may differ from the desired ones.

   The function can be called multiple times without calling Sound_Exit
   inbetween, e.g. to update params of an already-opened audio output.

   The function returns TRUE or FALSE to indicate if audio output
   has opened successfully, and also sets Sound_enabled to that value. */
int Sound_Setup(void);

#ifdef SOUND_CALLBACK
/* Callback function to be called from platform-specific code. Fills audio
   buffer BUFFER with SIZE bytes of audio samples. */
void Sound_Callback(UBYTE *buffer, unsigned int size);
#endif /* SOUND_CALLBACK */

/* Read/write to configuration file. */
int Sound_ReadConfig(char *option, char *ptr);
void Sound_WriteConfig(FILE *fp);

#ifdef SYNCHRONIZED_SOUND
/* Sound latency in ms. Don't change directly - use Sound_SetLatency instead. */
extern unsigned int Sound_latency;

void Sound_SetLatency(unsigned int latency);

/* Returns a factor (1.0 by default) to adjust the speed of the emulation
 * so that if the sound buffer is too full or too empty. The emulation
 * slows down or speeds up to match the actual speed of sound output. */
double Sound_AdjustSpeed(void);
#endif /* SYNCHRONIZED_SOUND */

#endif /* SOUND_THIN_API */

#endif /* SOUND_H_ */
