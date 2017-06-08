/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef POKEMINI_DEBUG
#define POKEMINI_DEBUG

extern const char *AppName;	// Application name
extern int PMZoom;		// Pokemon-Mini LCD Zoom (Safe)
extern char argv0[PMTMPV];	// Argument 0

extern int clc_zoom;			// Command-Line: Zoom
extern int clc_bpp;			// Command-Line: Bits-Per-Pixel
extern int clc_fullscreen;		// Command-Line: Fullscreen
extern int clc_autorun;			// Command-Line: Autorun

extern int dclc_fullrange;		// Debugger Conf: Full range (Physical range)
extern int dclc_followPC;		// Debugger Conf: Follow PC
extern int dclc_followSP;		// Debugger Conf: Follow SP
extern int dclc_PRC_bg;			// Debugger Conf: PRC Background
extern int dclc_PRC_spr;		// Debugger Conf: PRC Sprites
extern int dclc_PRC_stallcpu;		// Debugger Conf: PRC Stall CPU
extern int dclc_PRC_stallcycles;	// Debugger Conf: PRC Stall Idle Cycles
extern int dclc_cpuwin_refresh;		// Debugger Conf: CPU Window refresh
extern int dclc_cpuwin_winx, dclc_cpuwin_winy;
extern int dclc_cpuwin_winw, dclc_cpuwin_winh;
extern int dclc_memwin_refresh;		// Debugger Conf: Memory Window refresh
extern int dclc_memwin_winx, dclc_memwin_winy;
extern int dclc_memwin_winw, dclc_memwin_winh;
extern int dclc_prctileswin_refresh;	// Debugger Conf: PRC Tiles Window refresh
extern int dclc_prctileswin_winx, dclc_prctileswin_winy;
extern int dclc_prctileswin_winw, dclc_prctileswin_winh;
extern int dclc_prcmapwin_refresh;	// Debugger Conf: PRC Map Window refresh
extern int dclc_prcmapwin_winx, dclc_prcmapwin_winy;
extern int dclc_prcmapwin_winw, dclc_prcmapwin_winh;
extern int dclc_prcsprwin_refresh;	// Debugger Conf: PRC Sprites Window refresh
extern int dclc_prcsprwin_winx, dclc_prcsprwin_winy;
extern int dclc_prcsprwin_winw, dclc_prcsprwin_winh;
extern int dclc_timerswin_refresh;	// Debugger Conf: Timers Window refresh
extern int dclc_timerswin_winx, dclc_timerswin_winy;
extern int dclc_timerswin_winw, dclc_timerswin_winh;
extern int dclc_hardiowin_refresh;	// Debugger Conf: Hardware IO Window refresh
extern int dclc_hardiowin_winx, dclc_hardiowin_winy;
extern int dclc_hardiowin_winw, dclc_hardiowin_winh;
extern int dclc_irqwin_refresh;		// Debugger Conf: IRQ Window refresh
extern int dclc_irqwin_winx, dclc_irqwin_winy;
extern int dclc_irqwin_winw, dclc_irqwin_winh;
extern int dclc_miscwin_refresh;	// Debugger Conf: Misc Window refresh
extern int dclc_miscwin_winx, dclc_miscwin_winy;
extern int dclc_miscwin_winw, dclc_miscwin_winh;
extern int dclc_symbwin_refresh;	// Debugger Conf: Symbols List Window refresh
extern int dclc_symbwin_winx, dclc_symbwin_winy;
extern int dclc_symbwin_winw, dclc_symbwin_winh;
extern int dclc_tracewin_refresh;	// Debugger Conf: Code Trace Window refresh
extern int dclc_tracewin_winx, dclc_tracewin_winy;
extern int dclc_tracewin_winw, dclc_tracewin_winh;
extern int dclc_zoom_prctiles;		// Debugger Conf: Zoom (PRC Tiles)
extern int dclc_zoom_prcmap;		// Debugger Conf: Zoom (PRC Map)
extern int dclc_zoom_prcspr;		// Debugger Conf: Zoom (PRC Sprites)
extern int dclc_trans_prctiles;		// Debugger Conf: Transparency color (PRC Tiles)
extern int dclc_trans_prcspr;		// Debugger Conf: Transparency color (PRC Sprites)
extern int dclc_show_hspr;		// Debugger Conf: Show hidden sprites
extern int dclc_minimalist_sprview;	// Debugger Conf: Minimalist sprite view
extern int dclc_irqframes_on_1row;	// Debugger Conf: IRQ frames on single row
extern int dclc_autoread_minsym;	// Debugger Conf: Auto Read PMAS Symbols
extern int dclc_autorw_emusym;		// Debugger Conf: Auto Read/Write PokeMini Symbols
extern char dclc_extapp_title[10][PMTMPV];	// Debugger Conf: External application n title
extern char dclc_extapp_exec[10][PMTMPV];	// Debugger Conf: External application n executable
extern int dclc_extapp_atcurrdir[10];	// Debugger Conf: Launch at current directory
extern char dclc_recent[10][PMTMPV];	// Debugger Conf: Recent ROMs list
extern int dclc_debugout;		// Debugger Conf: Enable debug output
extern int dclc_autodebugout;		// Debugger Conf: Auto open debug output
extern int emurunning;		// Emulator running, set 0 to exit
extern int emulimiter;		// Emulator limiter

enum {
	EMUMODE_RESTORE = -1,		// Restore mode
	EMUMODE_STOP = 0,		// Stopped
	EMUMODE_STEP,			// Step into (Run single instruction)
	EMUMODE_STEPSKIP,		// Step skip (Jump over current instruction)
	EMUMODE_FRAME,			// Run single frame
	EMUMODE_RUNDEBSTEP,		// Run and refresh debugger in each step
	EMUMODE_RUNDEBFRAME,		// Run and refresh debugger in each frame
	EMUMODE_RUNDEBFRAMESND = 8,	// Run and refresh debugger in each frame (with sound)
	EMUMODE_RUNFULL,		// Run at full speed
	EMUMODE_SOUND = (1 << 3)	// AND to mask sound
};
extern volatile int emumode;	// Read-Only, current emulator mode

// Sound dump file
extern FILE *sdump;
extern double sdumptime;

// Setup screen
void setup_screen(void);

// Enable sound
void enablesound(int sound);

// Re-open joystick
void reopenjoystick(void);

// Set emulator mode
void set_emumode(int mode, int tempsave);

// Refresh all debug components
void refresh_debug(int now);

// "Run full" status changed
void sensitive_debug(int enable);

// Display command-line switches
void display_commandline(void);

#endif
