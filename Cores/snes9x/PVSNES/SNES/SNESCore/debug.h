/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifdef DEBUGGER

#ifndef _DEBUG_H_
#define _DEBUG_H_

#include <string>

struct SBreakPoint
{
	bool8	Enabled;
	uint8	Bank;
	uint16	Address;
};

#define ENSURE_TRACE_OPEN(fp, file, mode) \
	if (!fp) \
	{ \
		std::string fn = S9xGetDirectory(LOG_DIR); \
		fn += SLASH_STR file; \
		fp = fopen(fn.c_str(), mode); \
	}

extern struct SBreakPoint	S9xBreakpoint[6];

void S9xDoDebug (void);
void S9xTrace (void);
void S9xSA1Trace (void);
void S9xTraceMessage (const char *);
void S9xTraceFormattedMessage (const char *, ...);
void S9xPrintHVPosition (char *);
void S9xDebugProcessCommand(char *);

#endif

#endif
