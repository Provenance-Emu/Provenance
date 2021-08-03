#ifndef __MDFN_VIDEO_H
#define __MDFN_VIDEO_H

#include "video/surface.h"
#include "video/primitives.h"
#include "video/text.h"

namespace Mednafen
{
void MDFN_InitFontData(void) MDFN_COLD;
void MDFN_RunVideoBenchmarks(void) MDFN_COLD;
}

#endif
