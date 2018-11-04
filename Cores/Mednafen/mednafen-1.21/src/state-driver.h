#ifndef __MDFN_STATE_DRIVER_H
#define __MDFN_STATE_DRIVER_H

#include "video.h"
#include "state-common.h"

//
// "fname", when non-NULL, overrides the default save state filename generation.
// "suffix", when non-NULL, just override the default suffix(mc0-mc9).
//
// Returns true on success, false on failure.  Error messages outputted via MDFND_PrintError() as usual.
//
bool MDFNI_SaveState(const char *fname, const char *suffix, const MDFN_Surface *surface, const MDFN_Rect *DisplayRect, const int32 *LineWidths) noexcept;
bool MDFNI_LoadState(const char *fname, const char *suffix) noexcept;

void MDFNI_SelectState(int) noexcept;

void MDFND_SetStateStatus(StateStatusStruct *status) noexcept;
void MDFND_SetMovieStatus(StateStatusStruct *status) noexcept;

#endif
