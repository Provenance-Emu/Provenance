#ifndef __MDFN_DRIVERS_NETPLAY_H
#define __MDFN_DRIVERS_NETPLAY_H

void NetplayText_InMainThread(uint8 *text, bool NetEcho);

int NetplayEventHook(const SDL_Event *event);
int NetplayEventHook_GT(const SDL_Event *event);

void Netplay_ToggleTextView(void);
int Netplay_GetTextView(void);
bool Netplay_IsTextInput(void);
bool Netplay_TryTextExit(void);

// Returns local player mask if netplay is active, ~(uint32)0 otherwise
uint32 Netplay_GetLPM(void);

extern int MDFNDnetplay;


//
//
//
void Netplay_GT_CheckPendingLine(void);

//
//
//

void Netplay_MT_Draw(const MDFN_PixelFormat& pformat, const int32 screen_w, const int32 screen_h);

#endif
