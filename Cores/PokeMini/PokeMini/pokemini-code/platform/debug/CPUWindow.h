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

#ifndef CPUWINDOW_H
#define CPUWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"
#include "InstructionProc.h"

extern GtkWindow *MainWindow;

typedef struct {
	int key;
	int modifier;
	GtkItemFactoryCallback callback;
} TMenu_items_accel;
extern TMenu_items_accel Menu_item_accel[];

// Loaded color info file
extern char ColorInfoFile[256];

// Process menu item accelerator, execute callback and return if match
int ProcessMenuItemAccel(int key, int modifier, TMenu_items_accel *list);

// Messaging
void Set_StatusLabel(const char *format, ...);
void Add_InfoMessage(const char *format, ...);
void Cmd_DebugOutput(int ctrl);
void Add_DebugOutputChar(unsigned char ch);
void Add_DebugOutputBinary(unsigned char bin);
void Add_DebugOutputNumber8(unsigned char num, int reg);
void Add_DebugOutputNumber16(unsigned char num, int reg);
void Add_DebugOutputFixed8_8(unsigned char num, int reg);

// Callbacks
void PMDebug_OnLoadBIOSFile(const char *filename, int success);
void PMDebug_OnLoadMINFile(const char *filename, int success);
void PMDebug_OnLoadColorFile(const char *filename, int success);
void PMDebug_OnLoadEEPROMFile(const char *filename, int success);
void PMDebug_OnSaveEEPROMFile(const char *filename, int success);
void PMDebug_OnLoadStateFile(const char *filename, int success);
void PMDebug_OnSaveStateFile(const char *filename, int success);
void PMDebug_OnReset(int hardreset);

// Get physical address of program view top
uint32_t ProgramView_GetTop(void);

// Recalculate program view table
uint32_t ProgramView_Recalc(uint32_t addr);

// Syncronize program view
int ProgramView_Sync(void);

// Program view go to addr
void ProgramView_GotoAddr(uint32_t addr, int highlight);

// Program view go to SP
void StackView_GotoSP(void);

// RAM view go to addr
void RAMView_GotoAddr(uint32_t addr, int highlight);

// Disassembler with color codes
TSOpcDec CDisAsm_SOpcDec;

// Any view trap colors
uint32_t AnyView_TrapColor[8];

// Any view new value custom dialog
extern GtkXCustomDialog AnyView_NewValue_CD[];
extern GtkXCustomDialog AnyView_AddWPAt_CD[];

// Any view helpers
void AnyView_DrawBackground(SGtkXDrawingView *widg, int width, int height, int zoom);
void AnyView_DrawDisableMask(SGtkXDrawingView *widg);

// Any view callbacks events
int AnyView_scroll(SGtkXDrawingView *widg, int value, int min, int max);
int AnyView_resize(SGtkXDrawingView *widg, int width, int height, int _c);
int AnyView_enterleave(SGtkXDrawingView *widg, int inside, int _b, int _c);
int AnyView_motion(SGtkXDrawingView *widg, int x, int y, int _c);

// Common menus
void Menu_Debug_RunFull(GtkWidget *widget, gpointer data);
void Menu_Debug_RunDFrameSnd(GtkWidget *widget, gpointer data);
void Menu_Debug_RunDFrame(GtkWidget *widget, gpointer data);
void Menu_Debug_RunDStep(GtkWidget *widget, gpointer data);
void Menu_Debug_SingleFrame(GtkWidget *widget, gpointer data);
void Menu_Debug_SingleStep(GtkWidget *widget, gpointer data);
void Menu_Debug_StepSkip(GtkWidget *widget, gpointer data);
void Menu_Debug_Stop(GtkWidget *widget, gpointer data);

// For min on command-line
void CPUWindow_AddMinOnRecent(const char *filename);

// This window management
int CPUWindow_Create(void);
void CPUWindow_Destroy(void);
void CPUWindow_Activate(void);
void CPUWindow_UpdateConfigs(void);
void CPUWindow_ROMResized(void);
void CPUWindow_EmumodeChanged(void);
void CPUWindow_Refresh(int now);
void CPUWindow_FrameRendered(void);

#endif
