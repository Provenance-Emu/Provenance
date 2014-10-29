#ifndef __MDFN_DRIVERS_DEBUGGER_H
#define __MDFN_DRIVERS_DEBUGGER_H

#ifdef WANT_DEBUGGER
// _GT_ = call from game thread
// _MT_ = call from main(video blitting) thread.

void Debugger_GT_Draw(void);
void Debugger_GT_Event(const SDL_Event* event);
bool Debugger_GT_Toggle(void);
void Debugger_GT_ModOpacity(int deltalove);

bool Debugger_GT_IsInSteppingMode(void);
void Debugger_GT_ForceSteppingMode(void);
void Debugger_GT_ForceStepIfStepping(void); // For synchronizations with save state loading and reset/power toggles.
void Debugger_GT_SyncDisToPC(void);	// Synch disassembly address to current PC/IP/whatever.

// Must be called in a specific place in the game thread's execution path.
void Debugger_GTR_PassBlit(void);

void Debugger_MT_DrawToScreen(const MDFN_PixelFormat& pf, signed screen_w, signed screen_h);

bool Debugger_IsActive(void);

void Debugger_Init(void);

void Debugger_Kill(void);
#else

static INLINE void Debugger_GT_Draw(void) { }
static INLINE void Debugger_GT_Event(const SDL_Event* event) { }
static INLINE bool Debugger_GT_Toggle(void) { return(false); }
static INLINE void Debugger_GT_ModOpacity(int deltalove) { }

static INLINE bool Debugger_GT_IsInSteppingMode(void) { return(false); }
static INLINE void Debugger_GT_ForceSteppingMode(void) { }
static INLINE void Debugger_GT_ForceStepIfStepping(void) { }
static INLINE void Debugger_GT_SyncDisToPC(void) { }
static INLINE void Debugger_GTR_PassBlit(void) { }
static INLINE void Debugger_MT_DrawToScreen(const MDFN_PixelFormat& pf, signed screen_w, signed screen_h) { }
static INLINE bool Debugger_IsActive(void) { return(false); }

static INLINE void Debugger_Init(void) { }
static INLINE void Debugger_Kill(void) { }
#endif

#endif
