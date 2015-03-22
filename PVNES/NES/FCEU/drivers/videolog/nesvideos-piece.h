#ifndef NESVPIECEhh
#define NESVPIECEhh

#define NESVIDEOS_LOGGING 1

#ifdef __cplusplus
extern "C" {
#endif

/* Is video logging enabled? 0=no, 1=yes, 2=active. Default value: 0 */ 
extern int LoggingEnabled; 

/* Get and set the video recording command (shell command) */ 
extern const char* NESVideoGetVideoCmd(void); 
extern void NESVideoSetVideoCmd(const char *cmd);

/* Save 1 frame of video. (Assumed to be 16-bit RGB) */ 
/* FPS is scaled by 24 bits (*0x1000000) */
/* Does not do anything if LoggingEnabled<2. */ 
extern void NESVideoLoggingVideo
    (const void*data, unsigned width, unsigned height,
     unsigned fps_scaled,
     unsigned bpp); 

/* Save N bytes of audio. bytes_per_second is required on the first call. */ 
/* Does not do anything if LoggingEnabled<2. */ 
/* The interval of calling this function is not important, as long as all the audio
 * data is eventually written without too big delay (5 seconds is too big)
 * This function may be called multiple times per video frame, or once per a few video
 * frames, or anything in between. Just that all audio data must be written exactly once,
 * and in order. */ 
extern void NESVideoLoggingAudio
    (const void*data,
     unsigned rate, unsigned bits, unsigned chans,
     unsigned nsamples);
/* nsamples*chans*(bits/8) = bytes in *data. */

/* Requests current AVI to be closed and new be started */
/* Use when encoding parameters have changed */
extern void NESVideoNextAVI();

extern void NESVideoSetRerecordingMode(long FrameNumber);
extern void NESVideoRerecordingSave(const char* slot);
extern void NESVideoRerecordingLoad(const char* slot);

#ifdef __cplusplus
}
#endif

#endif
