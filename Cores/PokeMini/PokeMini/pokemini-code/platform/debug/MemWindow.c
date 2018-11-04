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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <math.h>
#include <unistd.h>

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"
#include "CPUWindow.h"

#include "MemWindow.h"
#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int MemWindow_InConfigs = 0;

GtkWindow *MemWindow;
static int MemWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static SGtkXDrawingView MemView;

static int CustomFont8x12Display = 0;
static uint32_t CustomFont8x12Addr = 0;
static uint8_t CustomFont8x12[8*12*256];

void WriteToPMMem(uint32_t addr, uint8_t data)
{
	if (addr < 0x1000) {
		// BIOS
		PM_BIOS[addr & 4095] = data;
	} else if (addr < 0x2000) {
		// RAM
		PM_RAM[addr & 4095] = data;
	} else if (addr < 0x2100) {
		// Hardware IO
		MinxCPU_OnWrite(0, addr, data);
	} else {
		// ROM
		PM_ROM[addr & PM_ROM_Mask] = data;
	}
}

static void GenerateFont8x12FromAddr(uint8_t *CustomFont8x12, uint32_t addr)
{
	int ch, tx;
	uint8_t dat, *ptr;
	memset(CustomFont8x12, 0, 8*12*256);
	for (ch=0; ch<256; ch++) {
		ptr = &CustomFont8x12[(ch >> 4) * 1536 + (ch & 15) * 8 + 2 * 128];
		for (tx=0; tx<8; tx++) {
			dat = MinxCPU_OnRead(0, addr++);
			ptr[0*128+tx] = dat & 0x01;
			ptr[1*128+tx] = dat & 0x02;
			ptr[2*128+tx] = dat & 0x04;
			ptr[3*128+tx] = dat & 0x08;
			ptr[4*128+tx] = dat & 0x10;
			ptr[5*128+tx] = dat & 0x20;
			ptr[6*128+tx] = dat & 0x40;
			ptr[7*128+tx] = dat & 0x80;
		}
	}
}

static void GenerateFont8x12FromPtr(uint8_t *CustomFont8x12, uint8_t *fontptr)
{
	int ch, tx;
	uint8_t dat, *ptr;
	memset(CustomFont8x12, 0, 8*12*256);
	for (ch=0; ch<256; ch++) {
		ptr = &CustomFont8x12[(ch >> 4) * 1536 + (ch & 15) * 8 + 2 * 128];
		for (tx=0; tx<8; tx++) {
			dat = *fontptr++;
			ptr[0*128+tx] = dat & 0x01;
			ptr[1*128+tx] = dat & 0x02;
			ptr[2*128+tx] = dat & 0x04;
			ptr[3*128+tx] = dat & 0x08;
			ptr[4*128+tx] = dat & 0x10;
			ptr[5*128+tx] = dat & 0x20;
			ptr[6*128+tx] = dat & 0x40;
			ptr[7*128+tx] = dat & 0x80;
		}
	}
}

// -------
// Viewers
// -------

// Memory view go to addr
static void MemView_GotoAddr(uint32_t addr, int highlight)
{
	int set_line = addr >> 4;

	// Don't do anything if it's outside range
	if ((addr < 0) || (addr > PM_ROM_Size)) return;

	// Highlight address
	if (highlight) {
		MemView.highlight_addr = addr;
		MemView.highlight_rem = 16;
	}

	// Try to point at the top
	if ((set_line < MemView.sboffset) || (set_line >= (MemView.sboffset + MemView.total_lines - 1))) {
		sgtkx_drawing_view_sbvalue(&MemView, set_line - (MemView.total_lines >> 1));
	}
}

// Memory view exposure event
static int MemView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	uint8_t dat, sdat, watch;
	int x, y, pp, spp;
	int yc, xs = -1, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		if ((widg->mousex >= 72) && (widg->mousex < 392)) {
			xs = (widg->mousex - 72) / 20;
			ys = (widg->mousey - 12) / 12;
		}
		if ((widg->mousex >= 392) && (widg->mousex < 520)) {
			xs = (widg->mousex - 392) / 8;
			ys = (widg->mousey - 12) / 12;
		}
	}

	// Decrement highlighting remain timer
	if (MemView.highlight_rem) {
		MemView.highlight_rem--;
		sgtkx_drawing_view_repaint_after(&MemView, 250);
	}

	// Draw content
	pp = spp = widg->sboffset * 16;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 16) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 16) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 16) color = 0x808064;
			else color = 0x808080;
		}

		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
		if (MemView.highlight_rem && ((MemView.highlight_addr & ~15) == pp)) {
			dat = MemView.highlight_addr & 15;
			sgtkx_drawing_view_drawfrect(widg, 72+dat*20, y * 12, 16, 12, 0xFFE060);
			sgtkx_drawing_view_drawfrect(widg, 392+dat*8, y * 12, 8, 12, 0xFFE060);
		}
		if (((y-1) == ys) && (xs >= 0)) {
			sgtkx_drawing_view_drawfrect(widg, 72+xs*20, y * 12, 16, 12, color - 0x181818);
			sgtkx_drawing_view_drawfrect(widg, 392+xs*8, y * 12, 8, 12, color - 0x181818);
		}

		if (pp >= PM_ROM_Size) continue;
		sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%06X:", pp);
		for (x=0; x<16; x++) {
			dat = MinxCPU_OnRead(0, pp);
			sdat = (dat < 0x01) ? '.' : dat;
			watch = PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_WATCH;
			if (watch) {
				sgtkx_drawing_view_drawfrect(widg, 72 + x * 20, y * 12, 16, 12, AnyView_TrapColor[watch]);
			}
			sgtkx_drawing_view_drawtext(widg, 72 + x * 20, y * 12, 0x4C4C00, "%02X", (int)dat);
			if (CustomFont8x12Display) sgtkx_drawing_view_setfont(CustomFont8x12);
			sgtkx_drawing_view_drawchar(widg, 392 + x * 8, y * 12, 0x304C00, sdat);
			sgtkx_drawing_view_setfont(NULL);
			pp++;
		}
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	pp = spp + ys * 16 + xs;
	if ((ys >= 0) && (pp < PM_ROM_Size)) {
		dat = MinxCPU_OnRead(0, pp);
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Memory Content  [ $%04X => $%02X, %i ]", pp, dat, dat);
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Memory Content");
	}

	return 1;
}

// Memory view button press
static int MemView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int result = 0, pp;
	int xs = -1, ys = -1;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	if ((widg->mousex >= 72) && (widg->mousex < 392)) {
		xs = (widg->mousex - 72) / 20;
		ys = (widg->mousey - 12) / 12;
	} else if ((widg->mousex >= 392) && (widg->mousex < 520)) {
		xs = (widg->mousex - 392) / 8;
		ys = (widg->mousey - 12) / 12;
	} else return 0;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = widg->sboffset * 16 + ys * 16 + xs;
	if (button == SGTKXDV_BLEFT) {
		if (pp < PM_ROM_Size) {
			AnyView_NewValue_CD[1].number = (int)MinxCPU_OnRead(0, pp);
			AnyView_NewValue_CD[3].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHREAD;
			AnyView_NewValue_CD[4].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHWRITE;
			sprintf(AnyView_NewValue_CD[0].text, "Set new value for $%04X:", pp);
			result = CustomDialog(MemWindow, "Change memory", AnyView_NewValue_CD);
			if (result == 1) {
				WriteToPMMem(pp, AnyView_NewValue_CD[1].number);
				PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
				if (AnyView_NewValue_CD[3].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHREAD;
				if (AnyView_NewValue_CD[4].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHWRITE;
				refresh_debug(1);
			} else if (result == -1) {
				MessageDialog(MemWindow, "Invalid number", "Change register", GTK_MESSAGE_ERROR, NULL);
			}
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// --------------
// Menu callbacks
// --------------

static void MemW_Goto_Address(GtkWidget *widget, gpointer data)
{
	int val = MemView.sboffset * 16;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MemWindow, "Go to address", "Set address to top of view:", &val, val, 6, 1, 0, PM_ROM_Size-1)) {
		MemView_GotoAddr(val, 1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void MemW_Goto_SAddress(GtkWidget *widget, gpointer data)
{
	int addr = (int)data;
	sgtkx_drawing_view_sbvalue(&MemView, addr/16);
}

static void MemW_Goto_BAddress(GtkWidget *widget, gpointer data)
{
	int val = MemView.sboffset * 16 / 0x8000;
	int mbanks = PM_ROM_Mask / 0x8000;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MemWindow, "Go to bank", "Set bank to top of view:", &val, val, 2, 0, 0, mbanks)) {
		if (val) sgtkx_drawing_view_sbvalue(&MemView, val*0x8000/16);
		else sgtkx_drawing_view_sbvalue(&MemView, 0x2100/16);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void MemW_Break_AddWPAt(GtkWidget *widget, gpointer data)
{
	int i, num;

	set_emumode(EMUMODE_STOP, 1);

	AnyView_AddWPAt_CD[1].number = 0x1000;
	AnyView_AddWPAt_CD[3].number = 1;
	AnyView_AddWPAt_CD[5].number = 1;
	AnyView_AddWPAt_CD[6].number = 1;
	if (CustomDialog(MainWindow, "Add watchpoing at...", AnyView_AddWPAt_CD)) {
		for (i=0; i<AnyView_AddWPAt_CD[3].number; i++) {
			num = AnyView_AddWPAt_CD[1].number + i;
			if ((num < 0) || (num >= PM_ROM_Size)) {
				MessageDialog(MemWindow, "Address out of range", "Add watchpoint at...", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			PMD_TrapPoints[num] &= ~TRAPPOINT_WATCH;
			if (AnyView_AddWPAt_CD[5].number) PMD_TrapPoints[num] |= TRAPPOINT_WATCHREAD;
			if (AnyView_AddWPAt_CD[6].number) PMD_TrapPoints[num] |= TRAPPOINT_WATCHWRITE;
		}
		refresh_debug(1);
	}

	set_emumode(EMUMODE_RESTORE, 1);
}

static void MemW_Break_DelAllWP(GtkWidget *widget, gpointer data)
{
	int i;
	for (i=0; i<PM_ROM_Size; i++) PMD_TrapPoints[i] &= ~TRAPPOINT_WATCH;
	refresh_debug(1);
}

static void MemW_CharSet_Default(GtkWidget *widget, gpointer data)
{
	CustomFont8x12Display = 0;
	refresh_debug(1);
}

static void MemW_CharSet_FromROM(GtkWidget *widget, gpointer data)
{
	int addr;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MemWindow, "Character set", "Type address of character set:", &addr, CustomFont8x12Addr, 6, 1, 0, PM_ROM_Size-1)) {
		CustomFont8x12Addr = addr;
		GenerateFont8x12FromAddr(CustomFont8x12, CustomFont8x12Addr);
		CustomFont8x12Display = 1;
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void MemW_CharSet_FromFile(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	uint8_t *fontdat;
	int readbytes;
	FILE *fi;

	set_emumode(EMUMODE_STOP, 1);
	if (OpenFileDialogEx(MemWindow, "Open Font data", tmp, "", "All (*.*)\0*.*\0", 0)) {
		fontdat = malloc(256*8);
		if (!fontdat) {
			MessageDialog(MemWindow, "No enough memory", "Font load error", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		fi = fopen(tmp, "rb");
		if (fi == NULL) {
			MessageDialog(MemWindow, "Can't open file", "Font load error", GTK_MESSAGE_ERROR, NULL);
			free(fontdat);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		readbytes = fread(fontdat, 1, 256*8, fi);
		if (readbytes != (256*8)) {
			MessageDialog(MemWindow, "File load error, must be 2048 bytes", "Font load error", GTK_MESSAGE_ERROR, NULL);
			fclose(fi);
			free(fontdat);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		GenerateFont8x12FromPtr(CustomFont8x12, fontdat);
		CustomFont8x12Display = 1;
		refresh_debug(1);
		fclose(fi);
		free(fontdat);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static GtkXCustomDialog MemView_ImportData[] = {
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Size:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 1, 2097151},
	{GTKXCD_CHECK, "Whole file, ignore Size", 1},
	{GTKXCD_LABEL, "File offset:"},
	{GTKXCD_NUMIN, "", 0, 6, 0, 0, 2147483647},
	{GTKXCD_LABEL, "Type \"0x\" for hexadecimal numbers"},
	{GTKXCD_EOL, ""}
};

static void MemW_ImportData(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	int i, size, readbytes;
	FILE *fi;
	uint8_t dat;

	set_emumode(EMUMODE_STOP, 1);
	if (OpenFileDialogEx(MemWindow, "Import memory data", tmp, "", "All (*.*)\0*.*\0", 0)) {
		fi = fopen(tmp, "rb");
		if (fi == NULL) {
			MessageDialog(MemWindow, "Can't open file", "Memory import error", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		fseek(fi, 0L, SEEK_END);
		size = ftell(fi);
		if (CustomDialog(MemWindow, "Import memory", MemView_ImportData)) {
			fseek(fi, MemView_ImportData[6].number, SEEK_SET);
			if (MemView_ImportData[4].number) {
				size -= MemView_ImportData[6].number;
			} else {
				size = MemView_ImportData[3].number;
			}
			if (size < 0) {
				MessageDialog(MemWindow, "File offset out of range", "Import memory error", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			for (i=0; i<size; i++) {
				readbytes = fread(&dat, 1, 1, fi);
				WriteToPMMem(MemView_ImportData[1].number + i, dat);
				if (readbytes != 1) {
					MessageDialog(MemWindow, "Read error", "Import memory error", GTK_MESSAGE_ERROR, NULL);
					break;
				}
			}
			refresh_debug(1);
		}
		fclose(fi);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static GtkXCustomDialog MemView_ExportData[] = {
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Size:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 1, 2097151},
	{GTKXCD_LABEL, "Type \"0x\" for hexadecimal numbers"},
	{GTKXCD_EOL, ""}
};

static void MemW_ExportData(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	int i, size;
	FILE *fi;
	uint8_t dat;

	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(MemWindow, "Export memory data", tmp, "", "All (*.*)\0*.*\0", 0)) {
		if (CustomDialog(MemWindow, "Export memory", MemView_ExportData)) {
			fi = fopen(tmp, "wb");
			if (fi == NULL) {
				MessageDialog(MemWindow, "Can't open file", "Memory export error", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			size = MemView_ExportData[3].number;
			for (i=0; i<size; i++) {
				dat = MinxCPU_OnRead(0, MemView_ExportData[1].number + i);
				fwrite(&dat, 1, 1, fi);
			}
			fclose(fi);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static GtkXCustomDialog MemView_CopyData[] = {
	{GTKXCD_LABEL, "Source address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Destination address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Size:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 1, 2097151},
	{GTKXCD_LABEL, "Type \"0x\" for hexadecimal numbers"},
	{GTKXCD_EOL, ""}
};

static void MemW_CopyData(GtkWidget *widget, gpointer data)
{
	uint8_t *mdat;
	int i, size;

	set_emumode(EMUMODE_STOP, 1);
	if (CustomDialog(MemWindow, "Copy memory", MemView_CopyData)) {
		size = MemView_CopyData[5].number;
		mdat = (uint8_t *)malloc(size);
		for (i=0; i<size; i++) {
			mdat[i] = MinxCPU_OnRead(0, MemView_CopyData[1].number + i);
		}
		for (i=0; i<size; i++) {
			WriteToPMMem(MemView_CopyData[3].number + i, mdat[i]);
		}
		free(mdat);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static GtkXCustomDialog MemView_FillData8[] = {
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0x1000, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Size in bytes:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 1, 2097151},
	{GTKXCD_LABEL, "8-Bits value:"},
	{GTKXCD_NUMIN, "", 0, 2, 1, -128, 255},
	{GTKXCD_LABEL, "Type \"0x\" for hexadecimal numbers"},
	{GTKXCD_EOL, ""}
};

static void MemW_FillData8(GtkWidget *widget, gpointer data)
{
	uint8_t dat;
	int i, size;

	set_emumode(EMUMODE_STOP, 1);
	if (CustomDialog(MemWindow, "Fill memory", MemView_FillData8)) {
		size = MemView_FillData8[3].number;
		dat = MemView_FillData8[5].number & 0xFF;
		for (i=0; i<size; i++) {
			WriteToPMMem(MemView_FillData8[1].number + i, dat);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static GtkXCustomDialog MemView_FillData16[] = {
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0x1000, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Size in bytes:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 1, 2097151},
	{GTKXCD_LABEL, "16-Bits value:"},
	{GTKXCD_NUMIN, "", 0, 4, 1, -32768, 65535},
	{GTKXCD_CHECK, "Big-Endian mode", 0},
	{GTKXCD_LABEL, "Type \"0x\" for hexadecimal numbers"},
	{GTKXCD_EOL, ""}
};

static void MemW_FillData16(GtkWidget *widget, gpointer data)
{
	uint16_t dat;
	int i, size;

	set_emumode(EMUMODE_STOP, 1);
	if (CustomDialog(MemWindow, "Fill memory", MemView_FillData16)) {
		size = MemView_FillData16[3].number;
		dat = MemView_FillData16[5].number & 0xFFFF;
		for (i=0; i<size; i++) {
			if ((i & 1) ^ MemView_FillData16[6].number)
				WriteToPMMem(MemView_FillData16[1].number + i, dat >> 8);
			else	WriteToPMMem(MemView_FillData16[1].number + i, dat & 0xFF);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void MemW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void MemW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (MemWindow_InConfigs) return;

	if (index >= 0) {
		dclc_memwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(MemWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_memwin_refresh, 4, 0, 0, 1000)) {
			dclc_memwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint MemWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(MemWindow));
	return TRUE;
}

static gboolean MemWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) MemWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry MemWindow_MenuItems[] = {
	{ "/_Go to",                             NULL,           NULL,                     0, "<Branch>" },
	{ "/Go to/_Address...",                  "<CTRL>G",      MemW_Goto_Address,        0, "<Item>" },
	{ "/Go to/_BIOS top",                    "<SHIFT>B",     MemW_Goto_SAddress,  0x0000, "<Item>" },
	{ "/Go to/RA_M top",                     "<SHIFT>M",     MemW_Goto_SAddress,  0x1000, "<Item>" },
	{ "/Go to/_Hardware IO top",             "<SHIFT>H",     MemW_Goto_SAddress,  0x2000, "<Item>" },
	{ "/Go to/Cartridge R_OM top",           "<SHIFT>O",     MemW_Goto_SAddress,  0x2100, "<Item>" },
	{ "/Go to/Cartridge _Bank n top",        "<CTRL>B",      MemW_Goto_BAddress,       0, "<Item>" },

	{ "/_Break",                             NULL,           NULL,                     0, "<Branch>" },
	{ "/Break/_Add Watchpoint at...",        "<SHIFT>W",     MemW_Break_AddWPAt,       0, "<Item>" },
	{ "/Break/_Delete all watchpoints",      NULL,           MemW_Break_DelAllWP,      0, "<Item>" },

	{ "/_Character set",                     NULL,           NULL,                     0, "<Branch>" },
	{ "/Character set/_Default",             "<SHIFT>C",     MemW_CharSet_Default,     0, "<Item>" },
	{ "/Character set/From _ROM...",         "<CTRL>C",      MemW_CharSet_FromROM,     0, "<Item>" },
	{ "/Character set/From _file...",        "<SHIFT><CTRL>C",MemW_CharSet_FromFile,   0, "<Item>" },

	{ "/_Memory data",                       NULL,           NULL,                     0, "<Branch>" },
	{ "/Memory data/_Import from file...",   "<CTRL>I",      MemW_ImportData,          0, "<Item>" },
	{ "/Memory data/_Export to file...",     "<CTRL>E",      MemW_ExportData,          0, "<Item>" },
	{ "/Memory data/_Copy block",            "<CTRL>V",      MemW_CopyData,            0, "<Item>" },
	{ "/Memory data/_Fill 8-bits value",     "<CTRL>X",      MemW_FillData8,           0, "<Item>" },
	{ "/Memory data/_Fill 16-bits value",    "<CTRL>Y",      MemW_FillData16,          0, "<Item>" },

	{ "/_Debugger",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/Debugger/Run full speed",            "F5",           Menu_Debug_RunFull,       0, "<Item>" },
	{ "/Debugger/Run debug frames (Sound)",  "<SHIFT>F5",    Menu_Debug_RunDFrameSnd,  0, "<Item>" },
	{ "/Debugger/Run debug frames",          "<CTRL>F5",     Menu_Debug_RunDFrame,     0, "<Item>" },
	{ "/Debugger/Run debug steps",           "<CTRL>F3",     Menu_Debug_RunDStep,      0, "<Item>" },
	{ "/Debugger/Single frame",              "F4",           Menu_Debug_SingleFrame,   0, "<Item>" },
	{ "/Debugger/Single step",               "F3",           Menu_Debug_SingleStep,    0, "<Item>" },
	{ "/Debugger/Step skip",                 "<SHIFT>F3",    Menu_Debug_StepSkip,      0, "<Item>" },
	{ "/Debugger/Stop",                      "F2",           Menu_Debug_Stop,          0, "<Item>" },

	{ "/_Refresh",                           NULL,           NULL,                     0, "<Branch>" },
	{ "/Refresh/Now!",                       NULL,           MemW_RefreshNow,          0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           MemW_Refresh,             0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           MemW_Refresh,             1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           MemW_Refresh,             2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           MemW_Refresh,             3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           MemW_Refresh,             5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           MemW_Refresh,             7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           MemW_Refresh,            11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           MemW_Refresh,            35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           MemW_Refresh,            71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           MemW_Refresh,            -1, "/Refresh/100% 72fps" },
};
static gint MemWindow_MenuItemsNum = sizeof(MemWindow_MenuItems) / sizeof(*MemWindow_MenuItems);

// ----------
// Mem Window
// ----------

int MemWindow_Create(void)
{
	// Window
	MemWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(MemWindow), "Memory View");
	gtk_widget_set_size_request(GTK_WIDGET(MemWindow), 200, 100);
	gtk_window_set_default_size(MemWindow, 420, 200);
	g_signal_connect(MemWindow, "delete_event", G_CALLBACK(MemWindow_delete_event), NULL);
	g_signal_connect(MemWindow, "window-state-event", G_CALLBACK(MemWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(MemWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, MemWindow_MenuItemsNum, MemWindow_MenuItems, NULL);
	gtk_window_add_accel_group(MemWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Mem View
	MemView.on_exposure = SGtkXDVCB(MemView_exposure);
	MemView.on_scroll = SGtkXDVCB(AnyView_scroll);
	MemView.on_resize = SGtkXDVCB(AnyView_resize);
	MemView.on_motion = SGtkXDVCB(AnyView_motion);
	MemView.on_buttonpress = SGtkXDVCB(MemView_buttonpress);
	MemView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&MemView, 1);
	sgtkx_drawing_view_sbminmax(&MemView, 0, 255);	// $1000 to $1FFF
	gtk_widget_set_size_request(GTK_WIDGET(MemView.box), 64, 64);
	gtk_box_pack_start(VBox1, GTK_WIDGET(MemView.box), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MemView.box));

	return 1;
}

void MemWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(MemWindow))) {
		gtk_widget_show(GTK_WIDGET(MemWindow));
		gtk_window_deiconify(MemWindow);
		gtk_window_get_position(MemWindow, &x, &y);
		gtk_window_get_size(MemWindow, &width, &height);
		dclc_memwin_winx = x;
		dclc_memwin_winy = y;
		dclc_memwin_winw = width;
		dclc_memwin_winh = height;
	}
}

void MemWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(MemWindow));
	if ((dclc_memwin_winx > -15) && (dclc_memwin_winy > -16)) {
		gtk_window_move(MemWindow, dclc_memwin_winx, dclc_memwin_winy);
	}
	if ((dclc_memwin_winw > 0) && (dclc_memwin_winh > 0)) {
		gtk_window_resize(MemWindow, dclc_memwin_winw, dclc_memwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(MemWindow));
	gtk_window_present(MemWindow);
}

void MemWindow_UpdateConfigs(void)
{
	MemWindow_InConfigs = 1;

	switch (dclc_memwin_refresh) {
		case 0: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/100% 72fps")), 1);
			break;
		case 1: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 50% 36fps")), 1);
			break;
		case 2: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 33% 24fps")), 1);
			break;
		case 3: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 25% 18fps")), 1);
			break;
		case 5: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 17% 12fps")), 1);
			break;
		case 7: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 12%  9fps")), 1);
			break;
		case 11: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  8%  6fps")), 1);
			break;
		case 19: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  6%  3fps")), 1);
			break;
		default: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/Custom...")), 1);
			break;
	}

	MemWindow_InConfigs = 0;
}

void MemWindow_ROMResized(void)
{
	sgtkx_drawing_view_sbminmax(&MemView, 0, (PM_ROM_Size/16)-1);
}

void MemWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(MemView.box));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(MemView.box));
	}
}

void MemWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_memwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(MemWindow)) || MemWindow_minimized) return;
		}
		sgtkx_drawing_view_refresh(&MemView);
	} else refreshcnt--;
}
