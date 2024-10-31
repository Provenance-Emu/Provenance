/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - debugger.c                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 DarkJeztr                                          *
 *   Copyright (C) 2002 davFr                                              *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include <SDL.h>

#include "api/debugger.h"
#include "dbg_breakpoints.h"
#include "dbg_debugger.h"
#include "dbg_memory.h"

#ifdef DBG

int g_DebuggerActive = 0;    // whether the debugger is enabled or not

m64p_dbg_runstate g_dbg_runstate;

// Holds the number of pending steps the debugger needs to perform.
static SDL_sem *sem_pending_steps;

uint32_t previousPC;

//]=-=-=-=-=-=-=-=-=-=-=[ Initialisation du Debugger ]=-=-=-=-=-=-=-=-=-=-=-=[

void init_debugger()
{
    g_DebuggerActive = 1;
    g_dbg_runstate = M64P_DBG_RUNSTATE_PAUSED;

    DebuggerCallback(DEBUG_UI_INIT, 0); /* call front-end to initialize user interface */

    init_host_disassembler();

    sem_pending_steps = SDL_CreateSemaphore(0);
}

void destroy_debugger()
{
    SDL_DestroySemaphore(sem_pending_steps);
    sem_pending_steps = NULL;
    g_DebuggerActive = 0;
}

//]=-=-=-=-=-=-=-=-=-=-=-=-=[ Mise-a-Jour Debugger ]=-=-=-=-=-=-=-=-=-=-=-=-=[

void update_debugger(uint32_t pc)
// Update debugger state and display.
// Should be called after each R4300 instruction
// Checks for breakpoint hits on PC
{
    int bpt;

    if (g_dbg_runstate != M64P_DBG_RUNSTATE_PAUSED) {
        bpt = check_breakpoints(pc);
        if (bpt != -1) {
            g_dbg_runstate = M64P_DBG_RUNSTATE_PAUSED;

            if (BPT_CHECK_FLAG(g_Breakpoints[bpt], M64P_BKP_FLAG_LOG))
                log_breakpoint(pc, M64P_BKP_FLAG_EXEC, 0);
        }
    }

    if (g_dbg_runstate != M64P_DBG_RUNSTATE_RUNNING) {
        DebuggerCallback(DEBUG_UI_UPDATE, pc);  /* call front-end to notify user interface to update */
    }
    if (g_dbg_runstate == M64P_DBG_RUNSTATE_PAUSED) {
        // The emulation thread is blocked until a step call via the API.
        SDL_SemWait(sem_pending_steps);
    }

    previousPC = pc;
}

void debugger_step()
{
    SDL_SemPost(sem_pending_steps);
}

#endif
