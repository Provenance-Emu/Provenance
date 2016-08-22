#ifndef ARTIFACT_H_
#define ARTIFACT_H_

#include <stdio.h>

#include "config.h"

typedef enum ARTIFACT_t {
	ARTIFACT_NONE,       /* Artifacting disabled */
	ARTIFACT_NTSC_OLD,   /* Original NTSC artifacting */
	ARTIFACT_NTSC_NEW,   /* New NTSC artifacting */
#if NTSC_FILTER
	ARTIFACT_NTSC_FULL,  /* NTSC filter */
#endif /* NTSC_FILTER */
#ifndef NO_SIMPLE_PAL_BLENDING
	ARTIFACT_PAL_SIMPLE, /* ANTIC-level simple PAL blending */
#endif /* NO_SIMPLE_PAL_BLENDING */
#ifdef PAL_BLENDING
	ARTIFACT_PAL_BLEND,  /* Accurate PAL blending */
#endif /* PAL_BLENDING */
	ARTIFACT_SIZE
} ARTIFACT_t;

/* The currently used artifact emulation mode. Use ARTIFACT_Set to change this value. */
extern ARTIFACT_t ARTIFACT_mode;

/* Set artifacting mode for the current TV system. */
void ARTIFACT_Set(ARTIFACT_t mode);

/* Call after updating Atari800_tv_mode to update the artifacting mode accordingly. */
void ARTIFACT_SetTVMode(int tv_mode);

/* Read/write to configuration file. */
void ARTIFACT_WriteConfig(FILE *fp);
int ARTIFACT_ReadConfig(char *option, char *ptr);

/* Module initialisation and processing of command-line arguments. */
int ARTIFACT_Initialise(int *argc, char *argv[]);

#endif /* ARTIFACT_H_ */
