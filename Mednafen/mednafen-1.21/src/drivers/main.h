#ifndef _DRIVERS_MAIN_H
#define _DRIVERS_MAIN_H

#include <mednafen/driver.h>
#include <mednafen/mednafen.h>
#include <mednafen/settings.h>
#include <mednafen/Time.h>
#include "config.h"
#include "args.h"

#include <SDL.h>
#include <SDL_thread.h>

#include <mednafen/gettext.h>

enum
{
 CEVT_TOGGLEGUI = 1,
 CEVT_TOGGLEFS,
 CEVT_VIDEOSYNC,
 CEVT_CHEATTOGGLEVIEW,

 CEVT_OUTPUT_NOTICE,

 CEVT_SET_WMINPUTBEHAVIOR,

 CEVT_SET_STATE_STATUS,
 CEVT_SET_MOVIE_STATUS,

 CEVT_WANT_EXIT,	// Emulator exit or GUI exit or bust!

 CEVT_NP_DISPLAY_TEXT,
 CEVT_NP_TOGGLE_TT,
 CEVT_NP_LINE,
 CEVT_NP_LINE_RESPONSE,

 CEVT_SET_INPUT_FOCUS,	// Main thread to game thread.

 CEVT__MAX = 0xFFFF
};

void SendCEvent(unsigned int code, void *data1, void *data2, const uint16 idata16 = 0);

void PauseGameLoop(bool p);

extern int NoWaiting;
extern bool MDFNDHaveFocus;

extern MDFNGI *CurGame;
int CloseGame(void);

void RefreshThrottleFPS(double);
void PumpWrap(void);
void MainRequestExit(void);
bool MainExitPending(void);

extern bool pending_save_state, pending_ssnapshot, pending_snapshot, pending_save_movie;

void DoRunNormal(void);
void DoFrameAdvance(void);
bool IsInFrameAdvance(void);

void DebuggerFudge(void);

extern volatile int GameThreadRun;

void GT_SetWMInputBehavior(bool CursorNeeded, bool MouseAbsNeeded, bool MouseRelNeeded, bool GrabNeeded);
void GT_ToggleFS(void);
bool GT_ReinitVideo(void);
bool GT_ReinitSound(void);


void BuildSystemSetting(MDFNSetting *setting, const char *system_name, const char *name, const char *description, const char *description_extra, MDFNSettingType type, 
	const char *default_value, const char *minimum = NULL, const char *maximum = NULL,
	bool (*validate_func)(const char *name, const char *value) = NULL, void (*ChangeNotification)(const char *name) = NULL, 
        const MDFNSetting_EnumList *enum_list = NULL);
#endif
