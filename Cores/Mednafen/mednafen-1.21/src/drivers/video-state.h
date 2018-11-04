#ifndef __MDFN_DRIVERS_VIDEO_STATE_H
#define __MDFN_DRIVERS_VIDEO_STATE_H

void DrawSaveStates(int32 screen_w, int32 screen_h, double, double, int, int, int, int);
bool SaveStatesActive(void);

void MT_SetStateStatus(StateStatusStruct *status);
void MT_SetMovieStatus(StateStatusStruct *status);

#endif
