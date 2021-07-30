/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _DISPLAY_H_
#define _DISPLAY_H_

#include "snes9x.h"

enum s9x_getdirtype
{
	DEFAULT_DIR = 0,
	HOME_DIR,
	ROMFILENAME_DIR,
	ROM_DIR,
	SRAM_DIR,
	SNAPSHOT_DIR,
	SCREENSHOT_DIR,
	SPC_DIR,
	CHEAT_DIR,
	PATCH_DIR,
	BIOS_DIR,
	LOG_DIR,
	SAT_DIR,
	LAST_DIR
};

void S9xUsage (void);
char * S9xParseArgs (char **, int);
void S9xParseArgsForCheats (char **, int);
void S9xLoadConfigFiles (char **, int);
void S9xSetInfoString (const char *);

// Routines the port has to implement even if it doesn't use them

void S9xPutImage (int, int);
void S9xInitDisplay (int, char **);
void S9xDeinitDisplay (void);
void S9xTextMode (void);
void S9xGraphicsMode (void);
void S9xSetPalette (void);
void S9xToggleSoundChannel (int);
bool8 S9xOpenSnapshotFile (const char *, bool8, STREAM *);
void S9xCloseSnapshotFile (STREAM);
const char * S9xStringInput (const char *);
const char * S9xGetDirectory (enum s9x_getdirtype);
const char * S9xGetFilename (const char *, enum s9x_getdirtype);
const char * S9xGetFilenameInc (const char *, enum s9x_getdirtype);
const char * S9xChooseFilename (bool8);
const char * S9xBasename (const char *);

// Routines the port has to implement if it uses command-line

void S9xExtraUsage (void);
void S9xParseArg (char **, int &, int);

// Routines the port may implement as needed

void S9xExtraDisplayUsage (void);
void S9xParseDisplayArg (char **, int &, int);
void S9xSetTitle (const char *);
void S9xInitInputDevices (void);
void S9xProcessEvents (bool8);
const char * S9xSelectFilename (const char *, const char *, const char *, const char *);

#endif
