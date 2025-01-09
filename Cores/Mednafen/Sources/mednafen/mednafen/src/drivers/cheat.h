#ifndef __MDFN_DRIVERS_CHEAT_H
#define __MDFN_DRIVERS_CHEAT_H

void CheatIF_GT_Show(bool show);
bool CheatIF_Active(void);
void CheatIF_MT_Draw(const MDFN_PixelFormat& pformat, const int32 screen_w, const int32 screen_h);
int CheatIF_MT_EventHook(const SDL_Event *event);

#endif
