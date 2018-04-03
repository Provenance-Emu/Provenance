#ifndef __MDFN_MOVIE_H
#define __MDFN_MOVIE_H

class MemoryStream;

#include "movie-driver.h"
#include "state.h"

void MDFNMOV_ProcessInput(uint8 *PortData[], uint32 PortLen[], int NumPorts) noexcept;
void MDFNMOV_Stop(void) noexcept;
void MDFNMOV_AddCommand(uint8 cmd, uint32 data_len = 0, uint8* data = NULL) noexcept;
bool MDFNMOV_IsPlaying(void) noexcept;
bool MDFNMOV_IsRecording(void) noexcept;
void MDFNMOV_RecordState(void) noexcept;

// For state rewinding only.
void MDFNMOV_StateAction(StateMem* sm, const unsigned load);

void MDFNI_SelectMovie(int);
void MDFNMOV_CheckMovies(void);
#endif
