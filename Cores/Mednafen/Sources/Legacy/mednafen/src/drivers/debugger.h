/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* debugger.h:
**  Copyright (C) 2006-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

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

void Debugger_Init(void) MDFN_COLD;

void Debugger_Kill(void) MDFN_COLD;
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
