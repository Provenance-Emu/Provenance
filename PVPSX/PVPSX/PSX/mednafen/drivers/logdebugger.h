#ifndef __MDFN_DRIVERS_LOGDEBUGGER_H
#define __MDFN_DRIVERS_LOGDEBUGGER_H

void LogDebugger_Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect);
int LogDebugger_Event(const SDL_Event *event);
void LogDebugger_SetActive(bool newia);

#endif

