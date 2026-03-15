#include <mednafen/types.h>
#include <mednafen/git.h>
#include <mednafen/mednafen-driver.h>
#include <mednafen/mednafen.h>
//#include "thread.h"
@import mednafen;

#include <iostream>
#include <sys/time.h>
#include <unistd.h>
#include <semaphore.h>

#import <PVLogging/PVLogging.h>
#import <Foundation/Foundation.h>

// OSD helper — posts NSNotification that PVEmulatorViewController+OSD observes.
// Keys match PVOSDNotification.m constants; no extra header dependency needed.
// type: 0=info 1=success 2=warning 3=error
static void PVPostOSD(NSString *msg, int type, NSTimeInterval duration) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"PVOSDMessageNotification"
                      object:nil
                    userInfo:@{ @"PVOSDMessage":   msg,
                                @"PVOSDType":      @(type),
                                @"PVOSDDuration":  @(duration > 0 ? duration : 3.0) }];
}

void MDFND_DispMessage(char *str) {
    ILOG(@"Mednafen: %s", str);
    NSString *msg = [NSString stringWithUTF8String:str ?: ""];
    if (msg.length > 0) {
        PVPostOSD(msg, 0, 3.0);
    }
}

void MDFND_PrintError(const char* err) {
    ELOG(@"Mednafen: %s", err);
    NSString *msg = [NSString stringWithUTF8String:err ?: ""];
    if (msg.length > 0) {
        PVPostOSD(msg, 3, 4.0);
    }
}

namespace Mednafen {

void MDFND_MidSync(EmulateSpecStruct *espec, const unsigned flags) {

}
void MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx) {

}
void MDFND_NetplayText(const char* text, bool NetEcho){

}
void MDFND_SetMovieStatus(StateStatusStruct *) noexcept {

}
void MDFND_SetStateStatus(StateStatusStruct *) noexcept {

}
void MDFND_NetplaySetHints(bool active, bool behind, uint32 local_players_mask){

}
bool MDFND_CheckNeedExit(void){
    return false;
}
void MDFND_OutputInfo(const char *s) noexcept {
    ILOG(@"Mednafen: %s", s);
}
void MDFND_OutputNotice(MDFN_NoticeType t, const char* s) noexcept {
    NSString *msg = [NSString stringWithUTF8String:s ?: ""];
    switch(t) {
        case MDFN_NOTICE_STATUS :
            DLOG(@"Mednafen: %s", s);
            if (msg.length > 0) { PVPostOSD(msg, 0, 3.0); }
            break;
        case MDFN_NOTICE_WARNING :
            WLOG(@"Mednafen: %s", s);
            if (msg.length > 0) { PVPostOSD(msg, 2, 4.0); }
            break;
        case MDFN_NOTICE_ERROR :
            ELOG(@"Mednafen: %s", s);
            if (msg.length > 0) { PVPostOSD(msg, 3, 5.0); }
            break;
        default:
            VLOG(@"Mednafen: %s", s);
    }
}
}

uint32 MDFND_GetTime() {
    static bool first = true;
    static uint32_t start_ms;

    struct timeval val;
    gettimeofday(&val, NULL);
    uint32_t ms = val.tv_sec * 1000 + val.tv_usec / 1000;

    if(first) {
        start_ms = ms;
        first = false;
    }

    return ms - start_ms;
}
