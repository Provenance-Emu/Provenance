#ifndef __MDFN_STATE_REWIND_H
#define __MDFN_STATE_REWIND_H

bool MDFNSRW_IsRunning(void) noexcept;
void MDFNSRW_Begin(void) noexcept;
void MDFNSRW_End(void) noexcept;
bool MDFNSRW_Frame(bool) noexcept;

#endif
