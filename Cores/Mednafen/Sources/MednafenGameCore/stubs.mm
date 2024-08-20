#include <mednafen/types.h>
#include <mednafen/git.h>
//#include <mednafen/mednafen-driver.h>
#include <mednafen/mednafen.h>
#include "thread.h"

#include <iostream>
#include <sys/time.h>
#include <unistd.h>
#include <semaphore.h>

#import <PVLogging/PVLogging.h>
#import <Foundation/Foundation.h>
void MDFND_DispMessage(char *str)
{
	ILOG(@"Mednafen: %s", str);
}

void MDFND_PrintError(const char* err)
{
	ELOG(@"Mednafen: %s", err);
}

namespace Mednafen {
void MDFND_MidSync(EmulateSpecStruct *espec, const unsigned flags) {}

void MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{}
void MDFND_NetplayText(const char* text, bool NetEcho)
{}

void MDFND_SetMovieStatus(StateStatusStruct *) {}
void MDFND_SetStateStatus(StateStatusStruct *) {}

void MDFND_NetplaySetHints(bool active, bool behind, uint32 local_players_mask){}
bool MDFND_CheckNeedExit(void){ return false; }
void MDFND_OutputInfo(const char *s) noexcept {
    ILOG(@"Mednafen: %s", s);
}
void MDFND_OutputNotice(MDFN_NoticeType t, const char* s) noexcept {
    switch(t) {
        case MDFN_NOTICE_STATUS :
            DLOG(@"Mednafen: %s" s);
            break;
        case MDFN_NOTICE_WARNING :
            WLOG(@"Mednafen: %s", s);
            break;
        case MDFN_NOTICE_ERROR :
            ELOG(@"Mednafen: %s", s);
            break;
        default:
            VLOG(@"Mednafen: %s", s);
    }
}
}

uint32 MDFND_GetTime()
{
    static bool first = true;
    static uint32_t start_ms;

    struct timeval val;
    gettimeofday(&val, NULL);
    uint32_t ms = val.tv_sec * 1000 + val.tv_usec / 1000;

    if(first)
    {
        start_ms = ms;
        first = false;
    }
    
    return ms - start_ms;
}
