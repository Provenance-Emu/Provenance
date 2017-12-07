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

#include "SymbWindow.h"
#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int SymbWindow_InConfigs = 0;

GtkWindow *SymbWindow;
static int SymbWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkNotebook *ViewNB;
static SGtkXDrawingView CodeView;
static SGtkXDrawingView DataView;
static GtkLabel *PMSymbFile;

static int SymbsModified = 0;
static SymbItem *FirstCode = NULL;
static SymbItem *FirstData = NULL;

static char pmsymbfile[PMTMPV];

static GtkXCustomDialog SymbView_NewValue_CD[] = {
	{GTKXCD_LABEL, "Set new value for $XXXX:"},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_LABEL, "Prefix \"$\" for hexadecimal numbers"},
	{GTKXCD_CHECK, "Watchpoint Read access", 1},
	{GTKXCD_CHECK, "Watchpoint Write access", 1},
	{GTKXCD_LABEL, "Warning: Watchpoints are only triggered at\nthe end of the instruction causing it."},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog SymbView_AddSetCode_CD[] = {
	{GTKXCD_LABEL, "Symbol name:"},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "NOTE: If symbol already exists\nit will be overwritten."},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog SymbView_AddSetData_CD[] = {
	{GTKXCD_LABEL, "Symbol name:"},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_RADIO, "8-Bits", 1},
	{GTKXCD_RADIO, "16-Bits", 0},
	{GTKXCD_RADIO, "24-Bits", 0},
	{GTKXCD_RADIO, "32-Bits", 0},
	{GTKXCD_HSEP, ""},
	{GTKXCD_RADIO2, "Hide number", 0},
	{GTKXCD_RADIO2, "Hexadecimal", 1},
	{GTKXCD_RADIO2, "Signed number", 0},
	{GTKXCD_RADIO2, "Unsigned number", 0},
	{GTKXCD_LABEL, "NOTE: If symbol already exists\nit will be overwritten."},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog SymbView_ManageCode_CD[] = {
	{GTKXCD_RADIO2, "Modify symbol", 1},
	{GTKXCD_LABEL, "Symbol name:"},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "NOTE: If symbol already exists\nit will be overwritten."},
	{GTKXCD_HSEP, ""},
	{GTKXCD_HSEP, ""},
	{GTKXCD_RADIO2, "Delete symbol", 0},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog SymbView_ManageData_CD[] = {
	{GTKXCD_RADIO2, "Modify symbol", 1},
	{GTKXCD_LABEL, "Symbol name:"},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_LABEL, "Address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_RADIO, "8-Bits", 1},
	{GTKXCD_RADIO, "16-Bits", 0},
	{GTKXCD_RADIO, "24-Bits", 0},
	{GTKXCD_RADIO, "32-Bits", 0},
	{GTKXCD_HSEP, ""},
	{GTKXCD_RADIO3, "Hide number", 0},
	{GTKXCD_RADIO3, "Hexadecimal", 1},
	{GTKXCD_RADIO3, "Signed number", 0},
	{GTKXCD_RADIO3, "Unsigned number", 0},
	{GTKXCD_LABEL, "NOTE: If symbol already exists\nit will be overwritten."},
	{GTKXCD_HSEP, ""},
	{GTKXCD_HSEP, ""},
	{GTKXCD_RADIO2, "Delete symbol", 0},
	{GTKXCD_EOL, ""}
};

// -------------------
// Symb items handlers
// -------------------

void SymbItemsClearAll(SymbItem **list)
{
	SymbItem *next, *item = *list;
	while (item != NULL) {
		next = item->next;
		free(item);
		item = next;
	}
	*list = NULL;
}

SymbItem *SymbItemsGetIndex(SymbItem **list, int index)
{
	SymbItem *item = *list;
	if (index < 0) return NULL;
	while (item != NULL) {
		if (index-- == 0) return item;
		item = item->next;
	}
	return NULL;
}

SymbItem *SymbItemsGet(SymbItem **list, char *symbname)
{
	SymbItem *item = *list;
	while (item != NULL) {
		if (!strcmp(item->name, symbname)) return item;
		item = item->next;
	}
	return NULL;
}

void SymbItemsSet(SymbItem **list, SymbItem *setitem, int updateex)
{
	SymbItem *item, *pitem, *newitem;
	item = SymbItemsGet(list, setitem->name);
	if (item != NULL) {
		item->addr = setitem->addr;
		if (updateex) {
			item->size = setitem->size;
			item->ctrl = setitem->ctrl;
		}
		return;
	}
	newitem = (SymbItem *)malloc(sizeof(SymbItem));
	memcpy(newitem, setitem, sizeof(SymbItem));
	if (*list == NULL) {
		*list = newitem;
		newitem->prev = NULL;
		newitem->next = NULL;
		return;
	}
	pitem = NULL;
	item = *list;
	while (item != NULL) {
		if (strcmp(item->name, newitem->name) < 0) {
			pitem = item;
			item = item->next;
		} else break;
	}
	newitem->prev = pitem;
	newitem->next = item;
	if (pitem) {
		pitem->next = newitem;
	} else {
		*list = newitem;
	}
	if (item) item->prev = newitem;
}

void SymbItemsDelete(SymbItem **list, SymbItem *item)
{
	if (!item) return;
	if (item->prev) {
		item->prev->next = item->next;
	} else {
		*list = item->next;
	}
	if (item->next) item->next->prev = item->prev;
	free(item);
}

int SymbItemsLength(SymbItem **list)
{
	int count = 0;
	SymbItem *item = *list;
	while (item != NULL) {
		count++;
		item = item->next;
	}
	return count;
}

int SymbItemsSetFromFile(char *filename)
{
	FILE *fi;
	char tmp[PMTMPV];
	char stype[PMTMPV];
	char sval[PMTMPV];
	char ssize[PMTMPV];
	char ssymb[PMTMPV];
	uint32_t value;
	int32_t size;
	SymbItem item;

	fi = fopen(filename, "r");
	if (!fi) return 0;

	while (fgets(tmp, PMTMPV, fi) != NULL) {
		if (sscanf(tmp, "%s %s %s %s", stype, sval, ssize, ssymb) == 4) {
			// Some future PMAS version
			value = atoi_Ex(sval, 0);
			size = atoi_Ex(ssize, -1);
			if (!strcasecmp(stype, "LAB")) {
				// Code
				strcpy(item.name, ssymb);
				item.addr = value;
				SymbItemsSet(&FirstCode, &item, 0);
			} else if (!strcasecmp(stype, "RAM")) {
				// Data
				strcpy(item.name, ssymb);
				item.addr = value;
				item.size = 0;
				if (size == 2) item.size = 1;
				else if (size == 3) item.size = 2;
				else if (size == 4) item.size = 3;
				item.ctrl = 1;
				SymbItemsSet(&FirstData, &item, 0);
			}
		} else if (sscanf(tmp, "%s %s %s", stype, sval, ssymb) == 3) {
			// PMAS == v0.20 Symbols
			value = atoi_Ex(sval, 0);
			if (!strcasecmp(stype, "LAB")) {
				// Code
				strcpy(item.name, ssymb);
				item.addr = value;
				SymbItemsSet(&FirstCode, &item, 0);
			} else if (!strcasecmp(stype, "RAM")) {
				// Data
				strcpy(item.name, ssymb);
				item.addr = value;
				item.size = 0;
				item.ctrl = 1;
				SymbItemsSet(&FirstData, &item, 0);
			}
		} else if (sscanf(tmp, "%s %s", sval, ssymb) == 2) {
			// PMAS <= 0.19 Symbols
			// Code and Data
			value = atoi_Ex(sval, 0);
			strcpy(item.name, ssymb);
			item.addr = value;
			item.size = 0;
			item.ctrl = 1;
			SymbItemsSet(&FirstCode, &item, 0);
			SymbItemsSet(&FirstData, &item, 0);
		}
	}
	fclose(fi);

	return 1;
}

int SymbItemsLoadFromFile(char *filename)
{
	char tmp[PMTMPV], *txt;
	char par[PMTMPV];
	char tok;
	SymbItem item;
	FILE *fi;

	SymbItemsClearAll(&FirstCode);
	SymbItemsClearAll(&FirstData);

	fi = fopen(filename, "r");
	if (!fi) return 0;

	while (fgets(tmp, PMTMPV, fi) != NULL) {
		RemoveComments(tmp);
		txt = TrimStr(tmp);
		txt = UpToToken(par, txt, " \t\n", &tok);
		if (tok == '\n') continue;
		if (!strcasecmp(par, "CODE1")) {
			txt = UpToToken(par, txt, " \t\n", &tok);
			if (tok == '\n') continue;
			item.addr = atoi_Ex(par, 0);
			txt = UpToToken(item.name, txt, " \t\n", &tok);
			SymbItemsSet(&FirstCode, &item, 1);
		} else if (!strcasecmp(par, "DATA1")) {
			txt = UpToToken(par, txt, " \t\n", &tok);
			if (tok == '\n') continue;
			item.addr = atoi_Ex(par, 0);
			txt = UpToToken(par, txt, " \t\n", &tok);
			if (tok == '\n') continue;
			item.size = atoi_Ex(par, 0);
			if ((item.size < 0) || (item.size > 3)) item.size = 0;
			txt = UpToToken(par, txt, " \t\n", &tok);
			if (tok == '\n') continue;
			item.ctrl = atoi_Ex(par, 0);
			txt = UpToToken(item.name, txt, " \t\n", &tok);
			SymbItemsSet(&FirstData, &item, 1);
		}
	}

	return 1;
}

int SymbItemsSaveToFile(char *filename)
{
	SymbItem *item;
	FILE *fo;

	fo = fopen(filename, "w");
	if (!fo) return 0;

	// Write header
	fprintf(fo, "# Symbols list generated by PokeMini %s\n", PokeMini_Version);
	fprintf(fo, "# Min file: %s\n", GetFilename(CommandLine.min_file));

	// Write code
	item = FirstCode;
	while (item != NULL) {
		fprintf(fo, "CODE1 $%06X %s\n", item->addr, item->name);
		item = item->next;
	}

	// Write data
	item = FirstData;
	while (item != NULL) {
		fprintf(fo, "DATA1 $%06X %i %i %s\n", item->addr, item->size, item->ctrl, item->name);
		item = item->next;
	}

	fclose(fo);

	return 1;
}

void SymbWindow_Reload(void)
{
	char tmp[PMTMPV];
	if (!strlen(pmsymbfile)) SymbsModified = 0;
	sprintf(tmp, "%c%s", (SymbsModified) ? '*' : ' ', pmsymbfile);
	gtk_label_set_text(PMSymbFile, tmp);

	sgtkx_drawing_view_sbminmax(&CodeView, 0, SymbItemsLength(&FirstCode));
	sgtkx_drawing_view_sbminmax(&DataView, 0, SymbItemsLength(&FirstData));
	SymbWindow_Refresh(1);
}

static void SymbWindow_AddSetCode()
{
	SymbItem item;
	int result;

	SymbView_AddSetCode_CD[3].number = PhysicalPC();
	sprintf(SymbView_AddSetCode_CD[1].text, "L%06X", SymbView_AddSetCode_CD[3].number);
	result = CustomDialog(SymbWindow, "Add/set code symbol", SymbView_AddSetCode_CD);
	if (result == 1) {
		if (strlen(SymbView_AddSetCode_CD[1].text)) {
			strcpy(item.name, SymbView_AddSetCode_CD[1].text);
			item.addr = SymbView_AddSetCode_CD[3].number;
			SymbItemsSet(&FirstCode, &item, 1);
			SymbsModified = 1;
			SymbWindow_Reload();
		} else {
			MessageDialog(SymbWindow, "Missing symbol name", "Add/set code symbol", GTK_MESSAGE_ERROR, NULL);
		}
	} else if (result == -1) {
		MessageDialog(SymbWindow, "Invalid number", "Add/set code symbol", GTK_MESSAGE_ERROR, NULL);
	}
}

static void SymbWindow_AddSetData()
{
	SymbItem item;
	int result;

	SymbView_AddSetData_CD[3].number = 0x1000;
	SymbView_AddSetData_CD[1].text[0] = 0;
	result = CustomDialog(SymbWindow, "Add/set data symbol", SymbView_AddSetData_CD);
	if (result == 1) {
		if (strlen(SymbView_AddSetData_CD[1].text)) {
			strcpy(item.name, SymbView_AddSetData_CD[1].text);
			item.addr = SymbView_AddSetData_CD[3].number;
			item.size = 0;
			if (SymbView_AddSetData_CD[5].number) item.size = 1;
			if (SymbView_AddSetData_CD[6].number) item.size = 2;
			if (SymbView_AddSetData_CD[7].number) item.size = 3;
			item.ctrl = 1;
			if (SymbView_AddSetData_CD[9].number) item.ctrl = 0;
			if (SymbView_AddSetData_CD[11].number) item.ctrl = 2;
			if (SymbView_AddSetData_CD[12].number) item.ctrl = 3;
			SymbItemsSet(&FirstData, &item, 1);
			SymbsModified = 1;
			SymbWindow_Reload();
		} else {
			MessageDialog(SymbWindow, "Missing symbol name", "Add/set data symbol", GTK_MESSAGE_ERROR, NULL);
		}
	} else if (result == -1) {
		MessageDialog(SymbWindow, "Invalid number", "Add/set data symbol", GTK_MESSAGE_ERROR, NULL);
	}
}

// -------
// Viewers
// -------

// Code view exposure event
static int CodeView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	int y, pp;
	int yc, ys = -1;
	SymbItem *item;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		ys = (widg->mousey - 12) / 12;
	}

	// Draw content
	pp = widg->sboffset;
	item = SymbItemsGetIndex(&FirstCode, pp);
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 1) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 1) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);

		if (item == NULL) {
			pp++;
			continue;
		}

		// Draw trap
		if (PMD_TrapPoints[item->addr & PM_ROM_Mask] & TRAPPOINT_BREAK) {
			sgtkx_drawing_view_drawfrect(widg, 2, y * 12, 72, 12, 0xFF2000);
		}

		// Draw symbol
		if (item->addr >= 0x01000000) sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%08X", item->addr);
		else sgtkx_drawing_view_drawtext(widg, 20, y * 12, 0x4C3000, "$%06X", item->addr);
		sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "-----------");
		sgtkx_drawing_view_drawtext(widg, 180, y * 12, 0x402090, "%s", item->name);

		// Next item
		item = item->next;
		pp++;
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Left click => Go to address  -:-  Right click => Manage symbol(s)  -:-  Middle click => Toggle breakpoint");

	return 1;
}

// Code view button press
static int CodeView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int result, pp, ys = -1;
	SymbItem *item;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;

	pp = widg->sboffset + ys;
	item = SymbItemsGetIndex(&FirstCode, pp);
	if ((item == NULL) || (item->addr >= PM_ROM_Size)) {
		if (button == SGTKXDV_BRIGHT) {
			set_emumode(EMUMODE_STOP, 1);
			SymbWindow_AddSetCode();
			set_emumode(EMUMODE_RESTORE, 1);
		}
		return 1;
	}

	set_emumode(EMUMODE_STOP, 1);

	if (button == SGTKXDV_BLEFT) {
		// Go to address
		ProgramView_GotoAddr(item->addr, 1);
		refresh_debug(1);
	} else if (button == SGTKXDV_BMIDDLE) {
		// Toggle breakpoint
		PMD_TrapPoints[item->addr & PM_ROM_Mask] ^= TRAPPOINT_BREAK;
		refresh_debug(1);
	} else if (button == SGTKXDV_BRIGHT) {
		// Manage symbol
		SymbView_ManageCode_CD[0].number = 1;
		SymbView_ManageCode_CD[8].number = 0;
		SymbView_ManageCode_CD[4].number = item->addr;
		strcpy(SymbView_ManageCode_CD[2].text, item->name);
		result = CustomDialog(SymbWindow, "Manage code symbol", SymbView_ManageCode_CD);
		if (result == 1) {
			if (strlen(SymbView_ManageCode_CD[2].text)) {
				if (SymbView_ManageCode_CD[0].number) {
					// Modify symbol
					if (strcmp(item->name, SymbView_ManageCode_CD[2].text) && SymbItemsGet(&FirstCode, SymbView_ManageCode_CD[2].text)) {
						MessageDialog(SymbWindow, "Symbol already exists", "Manage code symbol", GTK_MESSAGE_ERROR, NULL);
					} else {
						strcpy(item->name, SymbView_ManageCode_CD[2].text);
						item->addr = SymbView_ManageCode_CD[4].number;
						SymbsModified = 1;
						SymbWindow_Reload();
					}
				} else {
					// Delele symbol
					SymbItemsDelete(&FirstCode, item);
					SymbsModified = 1;
					SymbWindow_Reload();
				}
			} else {
				MessageDialog(SymbWindow, "Missing symbol name", "Manage code symbol", GTK_MESSAGE_ERROR, NULL);
			}
		} else if (result == -1) {
			MessageDialog(SymbWindow, "Invalid number", "Manage code symbol", GTK_MESSAGE_ERROR, NULL);
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// Data view exposure event
static int DataView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{

	uint32_t color, val;
	int y, pp, watch;
	int yc, ys = -1;
	SymbItem *item;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		ys = (widg->mousey - 12) / 12;
	}

	// Draw content
	pp = widg->sboffset;
	item = SymbItemsGetIndex(&FirstData, pp);
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 1) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 1) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);

		if (item == NULL) {
			pp++;
			continue;
		}

		// Draw trap
		watch = PMD_TrapPoints[item->addr & PM_ROM_Mask] & TRAPPOINT_WATCH;
		if (watch) {
			sgtkx_drawing_view_drawfrect(widg, 82, y * 12, 72, 12, AnyView_TrapColor[watch]);
		}

		// Draw symbol
		if (item->addr >= 0x01000000) sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%08X", item->addr);
		else sgtkx_drawing_view_drawtext(widg, 20, y * 12, 0x4C3000, "$%06X", item->addr);
		if (item->size == 0) {
			val = MinxCPU_OnRead(0, item->addr);
			switch (item->ctrl & 3) {
				case 1: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "$%02X", val); break;
				case 2: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%i", (int)((int8_t)val)); break;
				case 3: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%u", (unsigned int)val); break;
			}
		} else if (item->size == 1) {
			val = MinxCPU_OnRead(0, item->addr) +
			     (MinxCPU_OnRead(0, item->addr+1) << 8);
			switch (item->ctrl & 3) {
				case 1: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "$%04X", val); break;
				case 2: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%i", (int)((int16_t)val)); break;
				case 3: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%u", (unsigned int)val); break;
			}
		} else if (item->size == 2) {
			val = MinxCPU_OnRead(0, item->addr) +
			     (MinxCPU_OnRead(0, item->addr+1) << 8) + 
			     (MinxCPU_OnRead(0, item->addr+2) << 16);
			switch (item->ctrl & 3) {
				case 1: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "$%06X", val); break;
				case 2: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%i", (int)((int32_t)(val << 8)) >> 8); break;
				case 3: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%u", (unsigned int)val); break;
			}
		} else if (item->size == 3) {
			val = MinxCPU_OnRead(0, item->addr) +
			     (MinxCPU_OnRead(0, item->addr+1) << 8) + 
			     (MinxCPU_OnRead(0, item->addr+2) << 16) + 
			     (MinxCPU_OnRead(0, item->addr+3) << 24);
			switch (item->ctrl & 3) {
				case 1: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "$%08X", val); break;
				case 2: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%i", (int)val); break;
				case 3: sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605080, "%u", (unsigned int)val); break;
			}
		}
		sgtkx_drawing_view_drawtext(widg, 180, y * 12, 0x402090, "%s", item->name);

		// Next item
		item = item->next;
		pp++;
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Left click => Edit value  -:-  Right click => Manage symbol(s)  -:-  Middle click => Toggle watchpoints");

	return 1;
}

// Data view button press
static int DataView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int result, pp, ys = -1;
	SymbItem *item;
	uint32_t val;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;

	pp = widg->sboffset + ys;
	item = SymbItemsGetIndex(&FirstData, pp);
	if ((item == NULL) || (item->addr >= PM_ROM_Size)) {
		if (button == SGTKXDV_BRIGHT) {
			set_emumode(EMUMODE_STOP, 1);
			SymbWindow_AddSetData();
			set_emumode(EMUMODE_RESTORE, 1);
		}
		return 1;
	}

	set_emumode(EMUMODE_STOP, 1);

	if (button == SGTKXDV_BLEFT) {
		// Edit value
		val = (uint32_t)MinxCPU_OnRead(0, item->addr);
		if (item->size >= 1) val += (uint32_t)MinxCPU_OnRead(0, item->addr+1) << 8;
		if (item->size >= 2) val += (uint32_t)MinxCPU_OnRead(0, item->addr+2) << 16;
		if (item->size >= 3) val += (uint32_t)MinxCPU_OnRead(0, item->addr+3) << 24;
		if ((item->ctrl & 3) == 1) {
			sprintf(SymbView_NewValue_CD[1].text, "$%02X", val);
			if (item->size == 1) sprintf(SymbView_NewValue_CD[1].text, "$%04X", val);
			if (item->size == 2) sprintf(SymbView_NewValue_CD[1].text, "$%06X", val);
			if (item->size == 3) sprintf(SymbView_NewValue_CD[1].text, "$%08X", val);
		} else {
			sprintf(SymbView_NewValue_CD[1].text, "%i", val);
		}
		SymbView_NewValue_CD[3].number = PMD_TrapPoints[item->addr] & TRAPPOINT_WATCHREAD;
		SymbView_NewValue_CD[4].number = PMD_TrapPoints[item->addr] & TRAPPOINT_WATCHWRITE;
		sprintf(SymbView_NewValue_CD[0].text, "Set new value for $%04X (%s):", item->addr, item->name);
		result = CustomDialog(SymbWindow, "Change memory", SymbView_NewValue_CD);
		if (result == 1) {
			val = atoi_Ex(SymbView_NewValue_CD[1].text, 0);
			WriteToPMMem(item->addr, val);
			PMD_TrapPoints[item->addr] &= ~TRAPPOINT_WATCH;
			if (SymbView_NewValue_CD[3].number) PMD_TrapPoints[item->addr] |= TRAPPOINT_WATCHREAD;
			if (SymbView_NewValue_CD[4].number) PMD_TrapPoints[item->addr] |= TRAPPOINT_WATCHWRITE;
			if (item->size >= 1) {
				WriteToPMMem(item->addr+1, val >> 8);
				PMD_TrapPoints[item->addr+1] &= ~TRAPPOINT_WATCH;
				if (SymbView_NewValue_CD[3].number) PMD_TrapPoints[item->addr+1] |= TRAPPOINT_WATCHREAD;
				if (SymbView_NewValue_CD[4].number) PMD_TrapPoints[item->addr+1] |= TRAPPOINT_WATCHWRITE;
			}
			if (item->size >= 2) {
				WriteToPMMem(item->addr+2, val >> 16);
				PMD_TrapPoints[item->addr+2] &= ~TRAPPOINT_WATCH;
				if (SymbView_NewValue_CD[3].number) PMD_TrapPoints[item->addr+2] |= TRAPPOINT_WATCHREAD;
				if (SymbView_NewValue_CD[4].number) PMD_TrapPoints[item->addr+2] |= TRAPPOINT_WATCHWRITE;
			}
			if (item->size >= 3) {
				WriteToPMMem(item->addr+3, val >> 24);
				PMD_TrapPoints[item->addr+3] &= ~TRAPPOINT_WATCH;
				if (SymbView_NewValue_CD[3].number) PMD_TrapPoints[item->addr+3] |= TRAPPOINT_WATCHREAD;
				if (SymbView_NewValue_CD[4].number) PMD_TrapPoints[item->addr+3] |= TRAPPOINT_WATCHWRITE;
			}
			refresh_debug(1);
		} else if (result == -1) {
			MessageDialog(SymbWindow, "Invalid number", "Change memory", GTK_MESSAGE_ERROR, NULL);
		}
	} else if (button == SGTKXDV_BMIDDLE) {
		val = PMD_TrapPoints[item->addr];
		switch (val & TRAPPOINT_WATCH) {
			case 0: val = TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE; break;
			case TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE: val = TRAPPOINT_WATCHREAD; break;
			case TRAPPOINT_WATCHREAD: val = TRAPPOINT_WATCHWRITE; break;
			case TRAPPOINT_WATCHWRITE: val = 0; break;
		}
		PMD_TrapPoints[item->addr] &= ~TRAPPOINT_WATCH;
		PMD_TrapPoints[item->addr] |= val;
		if (item->size >= 1) {
			PMD_TrapPoints[item->addr+1] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[item->addr+1] |= val;
		}
		if (item->size >= 2) {
			PMD_TrapPoints[item->addr+2] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[item->addr+2] |= val;
		}
		if (item->size >= 3) {
			PMD_TrapPoints[item->addr+3] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[item->addr+3] |= val;
		}
		refresh_debug(1);
	} else if (button == SGTKXDV_BRIGHT) {
		// Manage symbol
		SymbView_ManageData_CD[0].number = 1;
		SymbView_ManageData_CD[17].number = 0;
		SymbView_ManageData_CD[4].number = item->addr;
		SymbView_ManageData_CD[5].number = (item->size == 0) ? 1 : 0;
		SymbView_ManageData_CD[6].number = (item->size == 1) ? 1 : 0;
		SymbView_ManageData_CD[7].number = (item->size == 2) ? 1 : 0;
		SymbView_ManageData_CD[8].number = (item->size == 3) ? 1 : 0;
		SymbView_ManageData_CD[10].number = (item->ctrl == 0) ? 1 : 0;
		SymbView_ManageData_CD[11].number = (item->ctrl == 1) ? 1 : 0;
		SymbView_ManageData_CD[12].number = (item->ctrl == 2) ? 1 : 0;
		SymbView_ManageData_CD[13].number = (item->ctrl == 3) ? 1 : 0;
		strcpy(SymbView_ManageData_CD[2].text, item->name);
		result = CustomDialog(SymbWindow, "Manage data symbol", SymbView_ManageData_CD);
		if (result == 1) {
			if (strlen(SymbView_ManageData_CD[2].text)) {
				if (SymbView_ManageData_CD[0].number) {
					// Modify symbol
					if (strcmp(item->name, SymbView_ManageData_CD[2].text) && SymbItemsGet(&FirstData, SymbView_ManageData_CD[2].text)) {
						MessageDialog(SymbWindow, "Symbol already exists", "Manage data symbol", GTK_MESSAGE_ERROR, NULL);
					} else {
						strcpy(item->name, SymbView_ManageData_CD[2].text);
						item->addr = SymbView_ManageData_CD[4].number;
						item->size = 0;
						if (SymbView_ManageData_CD[6].number) item->size = 1;
						if (SymbView_ManageData_CD[7].number) item->size = 2;
						if (SymbView_ManageData_CD[8].number) item->size = 3;
						item->ctrl = 1;
						if (SymbView_ManageData_CD[10].number) item->ctrl = 0;
						if (SymbView_ManageData_CD[12].number) item->ctrl = 2;
						if (SymbView_ManageData_CD[13].number) item->ctrl = 3;
						SymbsModified = 1;
						SymbWindow_Reload();
					}
				} else {
					// Delele symbol
					SymbItemsDelete(&FirstData, item);
					SymbsModified = 1;
					SymbWindow_Reload();
				}

			} else {
				MessageDialog(SymbWindow, "Missing symbol name", "Manage data symbol", GTK_MESSAGE_ERROR, NULL);
			}
		} else if (result == -1) {
			MessageDialog(SymbWindow, "Invalid number", "Manage data symbol", GTK_MESSAGE_ERROR, NULL);
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// --------------
// Menu callbacks
// --------------

static void SymbW_ImportSym(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	strcpy(tmp, CommandLine.min_file);
	RemoveExtension(tmp);
	strcat(tmp, ".sym");
	if (OpenFileDialogEx(SymbWindow, "Import SYM", tmp, tmp, "PMAS symbols (*.sym)\0*.sym\0All (*.*)\0*.*\0", 0)) {
		if (!SymbItemsSetFromFile(tmp)) {
			MessageDialog(SymbWindow, "Error loading PMAS symbols list from ROM", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
		} else SymbsModified = 1;
		SymbWindow_Reload();
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_LoadPMSymbols(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	strcpy(tmp, CommandLine.min_file);
	RemoveExtension(tmp);
	strcat(tmp, ".pmsymbols");
	if (SymbsModified && !YesNoDialog(MainWindow, "Changes not saved\nLoad anyway?", "Load pmsymbols", GTK_MESSAGE_QUESTION, NULL)) {
		set_emumode(EMUMODE_RESTORE, 1);
		return;
	}
	if (OpenFileDialogEx(SymbWindow, "Load PokeMini Symbols", tmp, tmp, "PokeMini Symbols (*.pmsymbols)\0*.pmsymbols\0All (*.*)\0*.*\0", 0)) {
		if (!SymbItemsLoadFromFile(tmp)) {
			MessageDialog(SymbWindow, "Error loading PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
		} else {
			strcpy(pmsymbfile, tmp);
			SymbsModified = 0;
		}
		SymbWindow_Reload();
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_SavePMSymbols(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	if (strlen(pmsymbfile)) {
		if (!SymbItemsSaveToFile(pmsymbfile)) {
			MessageDialog(SymbWindow, "Error saving PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	SymbsModified = 0;
	SymbWindow_Reload();
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_SaveAsPMSymbols(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	strcpy(tmp, CommandLine.min_file);
	RemoveExtension(tmp);
	strcat(tmp, ".pmsymbols");
	if (SaveFileDialogEx(SymbWindow, "Save PokeMini Symbols", tmp, tmp, "PokeMini Symbols (*.pmsymbols)\0*.pmsymbols\0All (*.*)\0*.*\0", 0)) {
		if (!SymbItemsSaveToFile(tmp)) {
			MessageDialog(SymbWindow, "Error saving PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_AutoReadSym(GtkWidget *widget, gpointer data)
{
	if (SymbWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/File/Auto read .sym");
	dclc_autoread_minsym = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void SymbW_AutoRWPMSym(GtkWidget *widget, gpointer data)
{
	if (SymbWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/File/Auto rw .pmsymbols");
	dclc_autorw_emusym = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void SymbW_AddSetCode(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	SymbWindow_AddSetCode();
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_AddSetData(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	SymbWindow_AddSetData();
	set_emumode(EMUMODE_RESTORE, 1);
}

static void SymbW_ClrAllCode(GtkWidget *widget, gpointer data)
{
	if (SymbItemsLength(&FirstCode)) {
		SymbItemsClearAll(&FirstCode);
		SymbsModified = 1;
		SymbWindow_Reload();
	}
}

static void SymbW_ClrAllData(GtkWidget *widget, gpointer data)
{
	if (SymbItemsLength(&FirstData)) {
		SymbItemsClearAll(&FirstData);
		SymbsModified = 1;
		SymbWindow_Reload();
	}
}

static void SymbW_ClrAll(GtkWidget *widget, gpointer data)
{
	if (SymbItemsLength(&FirstCode) || SymbItemsLength(&FirstData)) {
		SymbItemsClearAll(&FirstCode);
		SymbItemsClearAll(&FirstData);
		SymbsModified = 1;
		SymbWindow_Reload();
	}
}

static void SymbW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void SymbW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (SymbWindow_InConfigs) return;

	if (index >= 0) {
		dclc_symbwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(SymbWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_symbwin_refresh, 4, 0, 0, 1000)) {
			dclc_symbwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint SymbWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(SymbWindow));
	return TRUE;
}

static gboolean SymbWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) SymbWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry SymbWindow_MenuItems[] = {

	{ "/_File",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/File/_Import sym...",                "<CTRL>I",      SymbW_ImportSym,          0, "<Item>" },
	{ "/File/_Load pmsymbols...",            "<CTRL>L",      SymbW_LoadPMSymbols,      0, "<Item>" },
	{ "/File/_Save pmsymbols",               "<CTRL>S",      SymbW_SavePMSymbols,      0, "<Item>" },
	{ "/File/S_ave pmsymbols as...",         "<CTRL><ALT>S", SymbW_SaveAsPMSymbols,    0, "<Item>" },
	{ "/File/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/File/Auto read .sym",                NULL,           SymbW_AutoReadSym,        0, "<CheckItem>" },
	{ "/File/Auto rw .pmsymbols",            NULL,           SymbW_AutoRWPMSym,        0, "<CheckItem>" },

	{ "/_Symbols",                           NULL,           NULL,                     0, "<Branch>" },
	{ "/Symbols/Add code symbol...",         "<CTRL>C",      SymbW_AddSetCode,         0, "<Item>" },
	{ "/Symbols/Add data symbol...",         "<CTRL>D",      SymbW_AddSetData,         0, "<Item>" },
	{ "/Symbols/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Symbols/Clear all",                  NULL,           NULL,                     0, "<Branch>" },
	{ "/Symbols/Clear all/Code symbols",     NULL,           SymbW_ClrAllCode,         0, "<Item>" },
	{ "/Symbols/Clear all/Data symbols",     NULL,           SymbW_ClrAllData,         0, "<Item>" },
	{ "/Symbols/Clear all/Code and data",    NULL,           SymbW_ClrAll,             0, "<Item>" },

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
	{ "/Refresh/Now!",                       NULL,           SymbW_RefreshNow,         0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           SymbW_Refresh,            0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           SymbW_Refresh,            1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           SymbW_Refresh,            2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           SymbW_Refresh,            3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           SymbW_Refresh,            5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           SymbW_Refresh,            7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           SymbW_Refresh,           11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           SymbW_Refresh,           35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           SymbW_Refresh,           71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           SymbW_Refresh,           -1, "/Refresh/100% 72fps" },
};
static gint SymbWindow_MenuItemsNum = sizeof(SymbWindow_MenuItems) / sizeof(*SymbWindow_MenuItems);

// -----------
// Symb Window
// -----------

int SymbWindow_Create(void)
{
	// Window
	SymbWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(SymbWindow), "Symbols List View");
	gtk_widget_set_size_request(GTK_WIDGET(SymbWindow), 200, 100);
	gtk_window_set_default_size(SymbWindow, 420, 200);
	g_signal_connect(SymbWindow, "delete_event", G_CALLBACK(SymbWindow_delete_event), NULL);
	g_signal_connect(SymbWindow, "window-state-event", G_CALLBACK(SymbWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(SymbWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, SymbWindow_MenuItemsNum, SymbWindow_MenuItems, NULL);
	gtk_window_add_accel_group(SymbWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Code View
	CodeView.on_exposure = SGtkXDVCB(CodeView_exposure);
	CodeView.on_scroll = SGtkXDVCB(AnyView_scroll);
	CodeView.on_resize = SGtkXDVCB(AnyView_resize);
	CodeView.on_motion = SGtkXDVCB(AnyView_motion);
	CodeView.on_buttonpress = SGtkXDVCB(CodeView_buttonpress);
	CodeView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&CodeView, 1);
	sgtkx_drawing_view_sbminmax(&CodeView, 0, 255);
	gtk_widget_set_size_request(GTK_WIDGET(CodeView.box), 64, 64);
	gtk_widget_show(GTK_WIDGET(CodeView.box));

	// Data View
	DataView.on_exposure = SGtkXDVCB(DataView_exposure);
	DataView.on_scroll = SGtkXDVCB(AnyView_scroll);
	DataView.on_resize = SGtkXDVCB(AnyView_resize);
	DataView.on_motion = SGtkXDVCB(AnyView_motion);
	DataView.on_buttonpress = SGtkXDVCB(DataView_buttonpress);
	DataView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&DataView, 1);
	sgtkx_drawing_view_sbminmax(&DataView, 0, 255);
	gtk_widget_set_size_request(GTK_WIDGET(DataView.box), 64, 64);
	gtk_widget_show(GTK_WIDGET(DataView.box));

	// View Notebook
	ViewNB = GTK_NOTEBOOK(gtk_notebook_new());
	gtk_box_pack_start(VBox1, GTK_WIDGET(ViewNB), TRUE, TRUE, 0);
	gtk_notebook_append_page(GTK_NOTEBOOK(ViewNB), GTK_WIDGET(CodeView.box), gtk_label_new("Code / Labels"));
	gtk_notebook_append_page(GTK_NOTEBOOK(ViewNB), GTK_WIDGET(DataView.box), gtk_label_new("Data / RAM"));
	gtk_widget_show(GTK_WIDGET(ViewNB));

	// Write file
	pmsymbfile[0] = 0;
	PMSymbFile = GTK_LABEL(gtk_label_new(pmsymbfile));
	gtk_misc_set_alignment(GTK_MISC(PMSymbFile), 0.5, 0.0);
	gtk_label_set_justify(PMSymbFile, GTK_JUSTIFY_CENTER);
	gtk_box_pack_start(VBox1, GTK_WIDGET(PMSymbFile), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(PMSymbFile));

	return 1;
}

void SymbWindow_Destroy(void)
{
	int x, y, width, height;
	if (SymbsModified) {
		if (strlen(pmsymbfile) && (SymbItemsLength(&FirstCode) || SymbItemsLength(&FirstData))) {
			if (!SymbItemsSaveToFile(pmsymbfile)) {
				MessageDialog(SymbWindow, "Error saving PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
			}
		}
	}
	if (gtk_widget_get_realized(GTK_WIDGET(SymbWindow))) {
		gtk_widget_show(GTK_WIDGET(SymbWindow));
		gtk_window_deiconify(SymbWindow);
		gtk_window_get_position(SymbWindow, &x, &y);
		gtk_window_get_size(SymbWindow, &width, &height);
		dclc_symbwin_winx = x;
		dclc_symbwin_winy = y;
		dclc_symbwin_winw = width;
		dclc_symbwin_winh = height;
	}
}

void SymbWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(SymbWindow));
	if ((dclc_symbwin_winx > -15) && (dclc_symbwin_winy > -16)) {
		gtk_window_move(SymbWindow, dclc_symbwin_winx, dclc_symbwin_winy);
	}
	if ((dclc_symbwin_winw > 0) && (dclc_symbwin_winh > 0)) {
		gtk_window_resize(SymbWindow, dclc_symbwin_winw, dclc_symbwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(SymbWindow));
	gtk_window_present(SymbWindow);
}

void SymbWindow_UpdateConfigs(void)
{
	GtkWidget *widg;

	SymbWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/File/Auto read .sym");
	if (dclc_autoread_minsym) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/File/Auto rw .pmsymbols");
	if (dclc_autorw_emusym) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	switch (dclc_symbwin_refresh) {
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

	SymbWindow_InConfigs = 0;
}

void SymbWindow_ROMLoaded(const char *filename)
{
	char tmp[PMTMPV];
	if (dclc_autorw_emusym) {
		if (SymbsModified) {
			if (strlen(pmsymbfile) && (SymbItemsLength(&FirstCode) || SymbItemsLength(&FirstData))) {
				if (!SymbItemsSaveToFile(pmsymbfile)) {
					MessageDialog(SymbWindow, "Error saving PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
				}
			}
		}
		SymbItemsClearAll(&FirstCode);
		SymbItemsClearAll(&FirstData);
		strcpy(tmp, filename);
		RemoveExtension(tmp);
		strcat(tmp, ".pmsymbols");
		strcpy(pmsymbfile, tmp);
		if (FileExist(tmp)) {
			if (!SymbItemsLoadFromFile(tmp)) {
				MessageDialog(SymbWindow, "Error loading PokeMini symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
			}
		}
	} else pmsymbfile[0] = 0;
	if (dclc_autoread_minsym) {
		strcpy(tmp, filename);
		RemoveExtension(tmp);
		strcat(tmp, ".sym");
		if (FileExist(tmp)) {
			if (!SymbItemsSetFromFile(tmp)) {
				MessageDialog(SymbWindow, "Error loading PMAS symbols list", "Symbols List Error", GTK_MESSAGE_ERROR, NULL);
			}
		}
	}
	SymbsModified = 0;
	SymbWindow_Reload();
}

void SymbWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(ViewNB));
		gtk_widget_show(GTK_WIDGET(PMSymbFile));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(ViewNB));
		gtk_widget_hide(GTK_WIDGET(PMSymbFile));
	}
}

void SymbWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_symbwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(SymbWindow)) || SymbWindow_minimized) return;
		}
		sgtkx_drawing_view_refresh(&CodeView);
		sgtkx_drawing_view_refresh(&DataView);
	} else refreshcnt--;
}
