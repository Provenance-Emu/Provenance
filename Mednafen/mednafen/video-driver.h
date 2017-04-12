#ifndef __VIDEO_DRIVER_H
#define __VIDEO_DRIVER_H

#include "video.h"

void MDFND_DispMessage(char* text);
void MDFNI_SaveSnapshot(const MDFN_Surface *src, const MDFN_Rect *rect, const int32 *LineWidths);

#endif
