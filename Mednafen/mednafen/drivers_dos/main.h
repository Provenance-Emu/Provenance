#ifndef __MDFN_DRIVERS_DOS_MAIN_H
#define __MDFN_DRIVERS_DOS_MAIN_H

#include "../driver.h"
#include "../mednafen.h"
#include "../settings.h"
#include "config.h"
#include "args.h"

#include <dos.h>
#include <dpmi.h>
#include <go32.h>
#include <sys/farptr.h>
#include <sys/movedata.h>

#include "../gettext.h"

#ifndef _
#define _(String) gettext(String)
#endif

extern MDFNGI *CurGame;
int CloseGame(void);

void RefreshThrottleFPS(double);
void MainRequestExit(void);

extern bool pending_save_state, pending_snapshot, pending_save_movie;

#endif
