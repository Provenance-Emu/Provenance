/*
  PokeMini Color Mapper
  Copyright (C) 2011-2012  JustBurn

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
#include <math.h>

#include "color_mapper.h"
#include "color_info.h"
#include "color_display.h"
#include "gtkx_colormapper.h"
#include "gtkx_pickedcolor.h"
#include "gtkx_palettepicker.h"
#include "GtkXDialogs.h"

#include "PMCommon.h"
#include "CommandLine.h"
#include "PokeMini_ColorPal.h"
#include "PokeMiniIcon_96x128.h"
#include "ExportBMP.h"
#include "HelpSupport.h"

#define APPTITLE "PokeMini Color Mapper v1.3"

const char *AboutTxt = APPTITLE
	"\n\n"
	"Coded by JustBurn\n"
	"Thanks to p0p, Dave|X,\n"
	"Onori, goldmono, Agilo,\n"
	"DarkFader, asterick,\n"
	"MrBlinky, Wa, Lupin and\n"
	"everyone in #pmdev on\n"
	"IRC EFNET!\n\n"
	"Please check readme.txt\n\n"
	"For latest version visit:\n"
	"http://code.google.com/p/pokemini/\n";

GtkItemFactory *ItemFactory;
GtkAccelGroup *AccelGroup;
GtkWindow *MainWindow;
GtkBox *VBox1;
GtkSeparator *HSep1;
GtkMenuBar *MenuBar;
GtkBox *HBox1;
GtkSeparator *VSep2[3];
GtkLabel *LabelInfo;
GtkXcolormapper *ColorMapper;
GtkScrollbar *VScroll1;
GtkAdjustment *VScroll1_Adj;
GtkBox *HBox2;
GtkButtonBox *VButtonBox1;
GtkButtonBox *VButtonBox2;
GtkToggleButton *CheckBox_SpriteMode;
GtkToggleButton *CheckBox_Grid;
GtkToggleButton *CheckBox_Negative;
GtkToggleButton *CheckBox_DisplayBlend;
GtkButton *Button_SwapBlend;
GtkComboBox *ComboZoom;
GtkXpickedcolor *PickedColor;
GtkXpalettepicker *PalettePicker;
GtkFrame *StatusFrame;
GtkLabel *StatusLabel;
GtkAdjustment *Contrast_Adj;
GtkScale *Contrast;

int WidInConfigs;

char MINFile[256];
char ColorFile[256];

int SpriteMode = 0;
int Grid = 1;
int DispNegative = 0;
int DispBlend = 0;
int ChangesMade = 0;
int Zoom = 5;
int TransparencySelColor = 0xFF00FF;
int ContrastLevel = 0;
int WinX = -16;
int WinY = -16;
int WinW = -1;
int WinH = -1;

uint32_t CurrAddr = 0;
uint32_t MarkAddr[10] = {0};

unsigned char *MaskData = NULL;
int MaskSize = 0;

const TCommandLineCustom CustomConf[] = {
	{ "main_winx", &WinX, COMMANDLINE_INT, -16, 4095 },
	{ "main_winy", &WinY, COMMANDLINE_INT, -16, 4095 },
	{ "main_winw", &WinW, COMMANDLINE_INT, -1, 4095 },
	{ "main_winh", &WinH, COMMANDLINE_INT, -1, 4095 },
	{ "spritemode", &SpriteMode, COMMANDLINE_BOOL },
	{ "grid", &Grid, COMMANDLINE_BOOL },
	{ "disp_negative", &DispNegative, COMMANDLINE_BOOL },
	{ "disp_blend", &DispBlend, COMMANDLINE_BOOL },
	{ "zoom", &Zoom, COMMANDLINE_INT, 1, 8 },
	{ "transparency", &TransparencySelColor, COMMANDLINE_INT, 0x000000, 0xFFFFFF }
};

void SetChangesMade(int changesmade)
{
	PangoAttrList *attrs;
	PangoAttribute *pa;
	if (ChangesMade != changesmade) {
		ChangesMade = changesmade;
		if (ChangesMade) {
			attrs = pango_attr_list_new();
			pa = pango_attr_underline_new(PANGO_UNDERLINE_SINGLE);
			pango_attr_list_insert(attrs, pa);
			gtk_label_set_attributes(LabelInfo, attrs);
			pango_attr_list_unref(attrs);
		} else {
			attrs = pango_attr_list_new();
			gtk_label_set_attributes(LabelInfo, attrs);
			pango_attr_list_unref(attrs);
		}
	}
}

const char *ColorFormatStr[] = {
	"8x8 Attributes",
	"4x4 Attributes"
};

void LoadMINFromFile(char *filename)
{
	char tmp[256];
	strcpy(tmp, filename);
	if (ExtensionCheck(filename, ".minc")) {
		tmp[strlen(filename)-1] = 0;
	}
	if (!LoadMIN(tmp)) return;
	strcpy(MINFile, tmp);
	sprintf(ColorFile, "%sc", MINFile);
	if (FileExist(ColorFile)) LoadColorInfo(ColorFile);
	if (!PRCColorUMap) {
		NewColorInfo(PickColorFormatDialog(MainWindow, 0, 0x01));
		gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
		sprintf(tmp, "MIN Loaded!\n\nColor Format: %s\nROM size: %i Bytes\nTiles: %i (Maximum)", ColorFormatStr[PRCColorFormat], PM_ROM_FSize, PRCColorUTiles);
	} else {
		gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
		sprintf(tmp, "MIN and Color Info Loaded!\n\nColor Format: %s\nROM size: %i Bytes\nTiles: %i (Maximum)\nTiles: %i (Compressed, Offset %i)", ColorFormatStr[PRCColorFormat], PM_ROM_FSize, PRCColorUTiles, PRCColorCTiles, PRCColorCOffset);
	}
	SetChangesMade(0);
	gtk_adjustment_set_value(VScroll1_Adj, 0.0);
	gtk_adjustment_set_upper(VScroll1_Adj, (double)PRCColorUTiles);
	MessageDialog(MainWindow, tmp, "MIN Loaded!", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
}

gboolean MainWindow_delete_event(GtkWidget *widget, GdkEvent  *event, gpointer data)
{
	// Get position & size before closing
	gtk_window_deiconify(MainWindow);
	gtk_window_get_position(MainWindow, &WinX, &WinY);
	gtk_window_get_size(MainWindow, &WinW, &WinH);

	// Ask if file was modified
	if (ChangesMade) {
		if (YesNoDialog(MainWindow, "File has been changed, save before quitting?", "Save?", GTK_MESSAGE_QUESTION, NULL)) {
			if (SaveFileDialogEx(MainWindow, "Save Color Info", ColorFile, ColorFile, "Color Info (*.minc)\0*.minc\0All (*.*)\0*.*\0", 0)) {
				if (!SaveColorInfo(ColorFile)) return TRUE;
			} else return TRUE;
		}
	}
	return FALSE;
}

void MainWindow_destroy(GtkWidget *widget, gpointer data)
{
	gtk_main_quit();
}

void Menu_File_OpenMIN(GtkWidget *widget, gpointer data)
{
	char tmp[256];
	if (OpenFileDialogEx(MainWindow, "Open MIN", tmp, MINFile, "MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (!ExtensionCheck(tmp, ".min")) {
			if (!YesNoDialog(MainWindow, "File extension should be .min, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
				return;
			}	
		}
		LoadMINFromFile(tmp);
	}
}

void Menu_File_ResetColor(GtkWidget *widget, gpointer data)
{
	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM not loaded yet!", "Reset color", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	if (YesNoDialog(MainWindow, "Erase everything?", "Reset?", GTK_MESSAGE_QUESTION, NULL)) {
		SetChangesMade(0);
		NewColorInfo(PickColorFormatDialog(MainWindow, 0, 0x01));
		gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
	}
}

void Menu_File_LoadColor(GtkWidget *widget, gpointer data)
{
	char tmp[256];
	strcpy(tmp, ColorFile);
	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM not loaded yet!", "Load color", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	if (OpenFileDialogEx(MainWindow, "Load Color Info", tmp, ColorFile, "Color Info (*.minc)\0*.minc\0All (*.*)\0*.*\0", 0)) {
		if (!ExtensionCheck(tmp, ".minc")) {
			if (!YesNoDialog(MainWindow, "File extension should be .minc, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
				return;
			}	
		}
		if (LoadColorInfo(tmp)) {
			strcpy(ColorFile, tmp);
			SetChangesMade(0);
			gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
		}
	}
}

void Menu_File_SaveColorAs(GtkWidget *widget, gpointer data)
{
	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM not loaded yet!", "Save color as...", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	if (SaveFileDialogEx(MainWindow, "Save Color Info", ColorFile, ColorFile, "Color Info (*.minc)\0*.minc\0All (*.*)\0*.*\0", 0)) {
		if (SaveColorInfo(ColorFile)) {
			SetChangesMade(0);
		}
	}
}

void Menu_File_SaveColor(GtkWidget *widget, gpointer data)
{
	if (FileExist(ColorFile)) {
		if (SaveColorInfo(ColorFile)) {
			SetChangesMade(0);
		}
	} else Menu_File_SaveColorAs(widget, data);
}

void Menu_File_Export(GtkWidget *widget, gpointer data)
{
	int x, y, z, htiles, vtiles, vsingle;
	int monorender = (int)data;
	cairo_surface_t *tmpimg;
	uint32_t *ptr;
	char tmp[256];
	FILE *capf;

	if (!PRCColorUTiles) {
		MessageDialog(MainWindow, "Nothing to export", "Export image...", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	if (EnterNumberDialog(MainWindow, "Export image...", "Number of horizontal tiles:", &htiles, 16, 2, 0, 1, 8192)) {
		if (SpriteMode && (htiles & 1)) {
			MessageDialog(MainWindow, "Number of horizontal tiles must be an even number for sprites", "Export image...", GTK_MESSAGE_ERROR, NULL);
			return;
		}
		vtiles = (int)ceil((double)PRCColorUTiles / htiles);
		vtiles = SpriteMode ? ((vtiles / 2 + 1) & ~3) : vtiles;
		vsingle = SpriteMode ? 2 : 1;

		// Select filename to export
		if (!SaveFileDialogEx(MainWindow, "Save Color Info", tmp, "export.bmp", "Bitmap (*.bmp)\0*.bmp\0All (*.*)\0*.*\0", 0)) return;

		// Create image to hold the tiles to be extracted
		tmpimg = cairo_image_surface_create(CAIRO_FORMAT_RGB24, htiles * 8, vsingle * 8);
		if (!tmpimg) {
			MessageDialog(MainWindow, "Failed to allocate image\nTry to use a higher number of horizontal tiles", "Export image...", GTK_MESSAGE_ERROR, NULL);
			return;
		}
		ptr = (uint32_t *)cairo_image_surface_get_data(tmpimg);
		if (!ptr) {
			cairo_surface_destroy(tmpimg);
			MessageDialog(MainWindow, "Failed to allocate image\nTry to use a higher number of horizontal tiles", "Export image...", GTK_MESSAGE_ERROR, NULL);
			return;
		}

		// Open BMP for exportation
		capf = Open_ExportBMP(tmp, htiles * 8, vtiles * 8);
		if (!capf) {
			cairo_surface_destroy(tmpimg);
			MessageDialog(MainWindow, "Failed to save export", "Error", GTK_MESSAGE_ERROR, NULL);
			return;
		}

		// Export each single row
		z = SpriteMode ? (vtiles-2) : (vtiles-1);
		for (; z >= 0; z -= vsingle) {
			sprintf(tmp, "Exporting image... %i%%", 100 - (z * 100 / vtiles));
			gtk_label_set_text(StatusLabel, tmp);
			while (gtk_events_pending()) gtk_main_iteration();

			if (PRCColorFormat == 1) {
				colordisplay_4x4Attr(ptr, htiles * 8, vsingle * 8, htiles * 8,
					SpriteMode, 1, z * htiles * vsingle, 0, -8,
					DispNegative, TransparencySelColor, 0, monorender, 0);
			} else {
				colordisplay_8x8Attr(ptr, htiles * 8, vsingle * 8, htiles * 8,
					SpriteMode, 1, z * htiles * vsingle, 0, -8,
					DispNegative, TransparencySelColor, 0, monorender, 0);
			}
			for (y=0; y<vsingle * 8; y++) {
				for (x=0; x<htiles * 8; x++) {
					WritePixel_ExportBMP(capf, ptr[((vsingle * 8 - 1) - y) * (htiles * 8) + x]);
				}
			}
		}
		gtk_label_set_text(StatusLabel, "");

		Close_ExportBMP(capf);
		cairo_surface_destroy(tmpimg);
	}
}

void Menu_File_Information(GtkWidget *widget, gpointer data)
{
	uint32_t offset = -1, tiles = -1;
	char tmp[256];
	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM not loaded yet!", "Information", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	if (!CompressColorInfo(&offset, &tiles)) {
		MessageDialog(MainWindow, "Failed to get compression information", "Information", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	sprintf(tmp, "Color Format: %s\nROM size: %i Bytes\nTiles: %i (Maximum)\nTiles: %i (Compressed, Offset: %i)", ColorFormatStr[PRCColorFormat], PM_ROM_FSize, PRCColorUTiles, tiles, offset);
	MessageDialog(MainWindow, tmp, "Information", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
}

void Menu_File_ChangeFormat(GtkWidget *widget, gpointer data)
{
	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM not loaded yet!", "Change format", GTK_MESSAGE_ERROR, NULL);
		return;
	}
	int fmt = PickColorFormatDialog(MainWindow, PRCColorFormat, PRCColorFlags);
	int newcolorformat = (fmt & 0xFF);
	int newcolorflags = (fmt >> 8) & 0xFF;
	PRCColorFlags = newcolorflags;
	if ((PRCColorFormat == 0) && (newcolorformat == 1)) {
		// Convert 8x8 to 4x4
		if (YesNoDialog(MainWindow, "Convert from 8x8 Attributes to 4x4 Attributes?", "Convert?", GTK_MESSAGE_QUESTION, NULL)) {
			if (Convert8x8to4x4()) {
				gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
				MessageDialog(MainWindow, "Format change completed!\nFormat is now 4x4 Attributes", "Change format", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
			} else {
				MessageDialog(MainWindow, "Failed to convert!\nNot enough memory", "Change format", GTK_MESSAGE_ERROR, NULL);
			}
		}
	} else if ((PRCColorFormat == 1) && (newcolorformat == 0)) {
		// Convert 4x4 to 8x8
		if (YesNoDialog(MainWindow, "Convert from 4x4 Attributes to 8x8 Attributes?\n\nWARNING: Some information will be lost", "Convert?", GTK_MESSAGE_QUESTION, NULL)) {
			if (Convert4x4to8x8()) {
				gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
				MessageDialog(MainWindow, "Format change completed!\nFormat is now 8x8 Attributes", "Change format", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
			} else {
				MessageDialog(MainWindow, "Failed to convert!\nNot enough memory", "Change format", GTK_MESSAGE_ERROR, NULL);
			}
		}
	}
}

void Menu_File_Quit(GtkWidget *widget, gpointer data)
{
	if (MainWindow_delete_event(widget, NULL, data) == FALSE) gtk_main_quit();
}

void Menu_Edit_Deselect(GtkWidget *widget, gpointer data)
{
	ColorMapper->select_a = 0;
	ColorMapper->select_b = -8;
	gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
}

void Menu_Edit_Copy(GtkWidget *widget, gpointer data)
{
	int selectStart = min(ColorMapper->select_a, ColorMapper->select_b);
	int selectEnd = max(ColorMapper->select_a, ColorMapper->select_b);

	if (selectStart < 0) {
		MessageDialog(MainWindow, "Select copy area with the middle-button", "Copy", GTK_MESSAGE_WARNING, NULL);
		return;
	}
	if ((selectEnd - selectStart) <= 0) {
		MessageDialog(MainWindow, "Select area is empty", "Copy", GTK_MESSAGE_WARNING, NULL);
		return;
	}

	// Realloc mask data and copy it
	int datasize = GetColorData(NULL, selectStart, selectEnd - selectStart);
	if (MaskData) {
		free(MaskData);
		MaskData = NULL;
		MaskSize = 0;
	}
	MaskData = (uint8_t *)malloc(datasize);
	MaskSize = selectEnd - selectStart;
	GetColorData(MaskData, selectStart, MaskSize);
}

void Menu_Edit_Paste(GtkWidget *widget, gpointer data)
{
	int selectStart = min(ColorMapper->select_a, ColorMapper->select_b);

	if (selectStart < 0) {
		MessageDialog(MainWindow, "Select the paste start position with the middle-button", "Paste",GTK_MESSAGE_WARNING, NULL);
		return;
	}
	if (!MaskSize) {
		MessageDialog(MainWindow, "Nothing in memory to paste", "Paste", GTK_MESSAGE_WARNING, NULL);
		return;
	}

	// Realloc mask data and copy it
	SetColorData(MaskData, selectStart, MaskSize);
	gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
	SetChangesMade(1);
}

void Menu_Edit_Fill(GtkWidget *widget, gpointer data)
{
	int selectStart = min(ColorMapper->select_a, ColorMapper->select_b);
	int selectEnd = max(ColorMapper->select_a, ColorMapper->select_b);

	if (selectStart < 0) {
		MessageDialog(MainWindow, "Select fill area with the middle-button", "Fill", GTK_MESSAGE_WARNING, NULL);
		return;
	}
	if ((selectEnd - selectStart) <= 0) {
		MessageDialog(MainWindow, "Fill area is empty", "Clear", GTK_MESSAGE_WARNING, NULL);
		return;
	}

	// Fill area
	FillColorData(selectStart, selectEnd - selectStart, 
		PickedColor->color_off_enabled ? PickedColor->color_off : -1,
		PickedColor->color_on_enabled ? PickedColor->color_on : -1);
	gtk_widget_queue_draw(GTK_WIDGET(ColorMapper));
	SetChangesMade(1);
}

void Menu_Edit_Swap(GtkWidget *widget, gpointer data)
{
	gtkx_palettepicker_swapcolors(PalettePicker);
}

void Menu_About_Documentation(GtkWidget *widget, gpointer data)
{
	HelpLaunchDoc("TOOLS_colormapper");
}

void Menu_About_VisitWebsite(GtkWidget *widget, gpointer data)
{
	HelpLaunchURL("http://code.google.com/p/pokemini/");
}

void Menu_About_About(GtkWidget *widget, gpointer data)
{
	MessageDialog(MainWindow, AboutTxt, "About...", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
}

gboolean Widgets_leave(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "");
	return FALSE;
}

void PalettePicker_on_color(GtkWidget *widg, int type, int index)
{
	gtkx_pickedcolor_setcolorindex(PickedColor, type, index);
}

void VScroll1_Adj_changed(GtkAdjustment *adj, gpointer data)
{
	int value = (int)(adj->value);
	CurrAddr = value;
	gtkx_colormapper_settileoff(ColorMapper, value);
}

void CheckBox_SpriteMode_toggled(GtkWidget *widget, gpointer user_data)
{
	SpriteMode = (gtk_toggle_button_get_active(CheckBox_SpriteMode) == TRUE);
	gtkx_colormapper_setspritemode(ColorMapper, SpriteMode);
	// Update other components
	gtk_adjustment_set_step_increment(VScroll1_Adj, SpriteMode ?   8.0 :  1.0);
	gtk_adjustment_set_page_increment(VScroll1_Adj, SpriteMode ? 128.0 : 16.0);
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Sprite Mode");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), SpriteMode);
}

gboolean CheckBox_SpriteMode_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Display the mapper as sprites, allowing to draw sprites more easily.");
	return FALSE;
}

void Menu_Edit_SpriteMode(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Sprite Mode");
	SpriteMode = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	gtkx_colormapper_setspritemode(ColorMapper, SpriteMode);
	// Update other components
	gtk_adjustment_set_step_increment(VScroll1_Adj, SpriteMode ?   8.0 :  1.0);
	gtk_adjustment_set_page_increment(VScroll1_Adj, SpriteMode ? 128.0 : 16.0);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(CheckBox_SpriteMode), SpriteMode);
}

void CheckBox_Grid_toggled(GtkWidget *widget, gpointer user_data)
{
	Grid = (gtk_toggle_button_get_active(CheckBox_Grid) == TRUE);
	gtkx_colormapper_setgrid(ColorMapper, Grid);
	// Update other components
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Show Grid");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), Grid);
}

gboolean CheckBox_Grid_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Display grid.");
	return FALSE;
}

void Menu_Edit_ShowGrid(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Show Grid");
	Grid = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	gtkx_colormapper_setgrid(ColorMapper, Grid);
	// Update other components
	gtk_toggle_button_set_active(CheckBox_Grid, Grid);
}

void CheckBox_Negative_toggled(GtkWidget *widget, gpointer user_data)
{
	DispNegative = (gtk_toggle_button_get_active(CheckBox_Negative) == TRUE);
	gtkx_colormapper_setnegative(ColorMapper, DispNegative);
	// Update other components
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Display Negative");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), DispNegative);
}

gboolean CheckBox_Negative_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Display negated color attributes.");
	return FALSE;
}

void Menu_Edit_DispNegative(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Display Negative");
	DispNegative = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	gtkx_colormapper_setnegative(ColorMapper, DispNegative);
	// Update other components
	gtk_toggle_button_set_active(CheckBox_Negative, DispNegative);
}

void CheckBox_DisplayBlend_toggled(GtkWidget *widget, gpointer user_data)
{
	DispBlend = (gtk_toggle_button_get_active(CheckBox_DisplayBlend) == TRUE);
	gtkx_colormapper_setdispblend(ColorMapper, DispBlend);
	// Update other components
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Mark/Display Blend");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), DispBlend);
}

gboolean CheckBox_DisplayBlend_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Display blending, you must set blend mark (Ctrl + 0) on 2nd tile data");
	return FALSE;
}

void Menu_Mark_DispBlend(GtkWidget *widget, gpointer data)
{
	GtkCheckMenuItem *widg = GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Mark/Display Blend"));
	DispBlend = (gtk_check_menu_item_get_active(widg) == TRUE);
	gtkx_colormapper_setdispblend(ColorMapper, DispBlend);
	// Update other components
	gtk_toggle_button_set_active(CheckBox_DisplayBlend, DispBlend);
}

gboolean Button_SwapBlend_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Swap current location with blend mark");
	return FALSE;
}

void Menu_Mark_SwapBlend(GtkWidget *widget, gpointer data)
{
	int tmp;
	tmp = MarkAddr[0];
	MarkAddr[0] = CurrAddr;
	CurrAddr = tmp;
	gtk_adjustment_set_value(VScroll1_Adj, (double)CurrAddr);
	gtkx_colormapper_settileoff(ColorMapper, CurrAddr);
	gtkx_colormapper_settileblendoff(ColorMapper, MarkAddr[0]);
}

void ComboZoom_changed(GtkWidget *widget, gpointer user_data)
{
	GtkWidget *widg;
	int tmpzoom;
	char tmp[256];
	tmpzoom = gtk_combo_box_get_active(ComboZoom) + 1;
	if (tmpzoom != Zoom) {
		Zoom = tmpzoom;
		gtkx_colormapper_setzoom(ColorMapper, Zoom);
		// Update other components
		sprintf(tmp, "/Edit/Zoom/%i00%%", Zoom);
		widg = gtk_item_factory_get_item(ItemFactory, tmp);
		gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), TRUE);
	}
}

gboolean ComboZoom_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Change the zoom scale.");
	return FALSE;
}

void Menu_Edit_Zoom(GtkWidget *widget, gpointer data)
{
	if ((int)data != Zoom) {
		Zoom = (int)data;
		gtkx_colormapper_setzoom(ColorMapper, Zoom);
		// Update other components
		gtk_combo_box_set_active(ComboZoom, Zoom - 1);
	}
}

void Menu_Mark_GetMark(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	CurrAddr = MarkAddr[index];
	gtk_adjustment_set_value(VScroll1_Adj, (double)CurrAddr);
	gtkx_colormapper_settileoff(ColorMapper, CurrAddr);
}

void Menu_Mark_SetMark(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	MarkAddr[index] = CurrAddr;
	if (index == 0) gtkx_colormapper_settileblendoff(ColorMapper, MarkAddr[0]);
}

void Menu_Mark_JumpTopSelect(GtkWidget *widget, gpointer data)
{
	int selectStart = min(ColorMapper->select_a, ColorMapper->select_b);
	if (selectStart < 0) {
		MessageDialog(MainWindow, "Select cell to jump with the middle-button", "Top as selection", GTK_MESSAGE_WARNING, NULL);
		return;
	}
	CurrAddr = selectStart;
	gtk_adjustment_set_value(VScroll1_Adj, (double)CurrAddr);
	gtkx_colormapper_settileoff(ColorMapper, CurrAddr);
}

void Menu_Mark_JumpToTile(GtkWidget *widget, gpointer data)
{
	int number;
	if (EnterNumberDialog(MainWindow, "Jump to tile...", "Jump to tile index:", &number, (int)CurrAddr, 6, 1, 0, PRCColorUTiles-1)) {
		CurrAddr = number;
		gtk_adjustment_set_value(VScroll1_Adj, (double)CurrAddr);
		gtkx_colormapper_settileoff(ColorMapper, CurrAddr);
	}
}

void Menu_Mark_JumpToAddress(GtkWidget *widget, gpointer data)
{
	int number;
	if (EnterNumberDialog(MainWindow, "Jump to address...", "Jump to address:", &number, (int)(CurrAddr * 8), 6, 1, 0, PM_ROM_FSize-1)) {
		CurrAddr = (number >> 3);
		gtk_adjustment_set_value(VScroll1_Adj, (double)CurrAddr);
		gtkx_colormapper_settileoff(ColorMapper, CurrAddr);
	}
}

static const char *TransparencyColorMenu[16] = {
	"/Edit/Transparency/Pink",
	"/Edit/Transparency/Red",
	"/Edit/Transparency/Green",
	"/Edit/Transparency/Blue",
	"/Edit/Transparency/Yellow",
	"/Edit/Transparency/Orange",
	"/Edit/Transparency/Purple",
	"/Edit/Transparency/Bright Red",
	"/Edit/Transparency/Bright Green",
	"/Edit/Transparency/Bright Blue",
	"/Edit/Transparency/Bright Yellow",
	"/Edit/Transparency/Cyan",
	"/Edit/Transparency/Black",
	"/Edit/Transparency/Grey",
	"/Edit/Transparency/Silver",
	"/Edit/Transparency/White"
};
static const uint32_t TransparencyColor[16] = {
	0xFF00FF,	// Pink
	0xC00000,	// Red
	0x00C000,	// Green
	0x0000C0,	// Blue
	0xC0C000,	// Yellow
	0xFF8000,	// Orange
	0x800080,	// Purple
	0xFF0000,	// Bright Red
	0x00FF00,	// Bright Green
	0x0000FF,	// Bright Blue
	0xFFFF00,	// Bright Yellow
	0x00FFFF,	// Cyan
	0x000000,	// Black
	0x808080,	// Grey
	0xC0C0C0,	// Silver
	0xFFFFFF	// White
};

void Menu_Transparency(GtkWidget *widget, gpointer data)
{
	int number, index = (int)data;
	static int lasttransindex = -2;

	if (lasttransindex == index) return;
	lasttransindex = index;
	if (WidInConfigs) return;

	if (index >= 0) {
		TransparencySelColor = TransparencyColor[index];
		gtkx_colormapper_settransparency(ColorMapper, TransparencySelColor);
	} else {
		if (EnterNumberDialog(MainWindow, "Custom tranparent color", "Transparency value:", &number, TransparencySelColor, 6, 1, 0x000000, 0xFFFFFF)) {
			TransparencySelColor = number;
			gtkx_colormapper_settransparency(ColorMapper, TransparencySelColor);
		}
	}
}

void ColorMapper_on_motion(GtkWidget *widget, int valid, uint32_t tileaddr, uint32_t subtileidx)
{
	char txt[256];
	if (valid) {
		if (PRCColorFormat == 1) {
			sprintf(txt, "Tile=($%04X, %i), Quad=%i -:- Addr=($%06X, %i)", tileaddr, tileaddr, subtileidx, tileaddr * 8, tileaddr * 8);
		} else {
			sprintf(txt, "Tile=($%04X, %i) -:- Addr=($%06X, %i)", tileaddr, tileaddr, tileaddr * 8, tileaddr * 8);
		}
	} else strcpy(txt, "-:-");
	gtk_label_set_text(LabelInfo, txt);
}

int ColorMapper_on_lbutton(GtkWidget *widget, uint32_t tileidx, uint32_t subtileidx, int keystatus)
{
	uint32_t mapoff = tileidx * PRCColorBytesPerTile;
	uint8_t *ColorMap = (uint8_t *)PRCColorUMap + mapoff;

	if (keystatus == 2) return 0;	// Ignore release

	GTKX_COLORMAPPER(ColorMapper)->select_b = -16;
	if ((ColorMap[subtileidx<<1] != PickedColor->color_off) || (ColorMap[(subtileidx<<1)+1] != PickedColor->color_on)) {
		if (PickedColor->color_off_enabled) ColorMap[subtileidx<<1] = PickedColor->color_off;
		if (PickedColor->color_on_enabled)ColorMap[(subtileidx<<1)+1] = PickedColor->color_on;
		SetChangesMade(1);
		return 1;	
	}

	return 0;
}

int ColorMapper_on_mbutton(GtkWidget *widget, uint32_t tileidx, uint32_t subtileidx, int keystatus)
{
	if (keystatus == 1) {
		// Press
		ColorMapper->select_a = tileidx;
		ColorMapper->select_b = -8;
	} if (keystatus == 0) {
		// Moving
		if (ColorMapper->select_b < ColorMapper->select_a) {
			ColorMapper->select_b = tileidx;
		} else {
			ColorMapper->select_b = tileidx+1;
		}
	}
	return 1;
}

int ColorMapper_on_rbutton(GtkWidget *widget, uint32_t tileidx, uint32_t subtileidx, int keystatus)
{
	uint32_t mapoff = tileidx * PRCColorBytesPerTile;
	uint8_t *ColorMap = (uint8_t *)PRCColorUMap + mapoff;

	if (keystatus == 2) return 0;	// Ignore release

	if (PickedColor->color_off_enabled) gtkx_palettepicker_setcolorindex(PalettePicker, 0, ColorMap[subtileidx<<1]);
	if (PickedColor->color_on_enabled) gtkx_palettepicker_setcolorindex(PalettePicker, 1, ColorMap[(subtileidx<<1)+1]);
	
	return 0;
}

gboolean ColorMapper_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Left-Button = Paint    Middle-Button = Selection    Right-Button = Absorv");
	return FALSE;
}

gboolean PickedColor_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Colors: Left-Button = Enable/Disable   -///-   Mini Pal. Left-Button = Get palette    Right-Button = Set palette");
	return FALSE;
}

gboolean PalettePicker_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Left-Button = Set Dark Color    Right-Button = Set Light Color");
	return FALSE;
}

gboolean Contrast_enter(GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	gtk_label_set_text(StatusLabel, "Change contrast preview");
	return FALSE;
}

static gchar *Constrast_formatvalue(GtkScale *scale, gdouble value, gpointer user_data)
{
	int constrast = (int)value;
	return g_strdup_printf("Contrast: %i", constrast);
}

void Contrast_Adj_changed(GtkAdjustment *adj, gpointer user_data)
{
	int value = (int)(adj->value);
	ContrastLevel = value;
	gtkx_colormapper_setcontrast(ColorMapper, value);
}

GtkItemFactoryEntry Menu_items[] = {
	{ "/_File",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/File/_Open Min...",                  "<CTRL>O",      Menu_File_OpenMIN,        0, "<Item>" },
	{ "/File/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/File/_Reset Color File",             "<CTRL>R",      Menu_File_ResetColor,     0, "<Item>" },
	{ "/File/_Load Color File",              "<CTRL>L",      Menu_File_LoadColor,      0, "<Item>" },
	{ "/File/_Save Color File",              "<CTRL>S",      Menu_File_SaveColor,      0, "<Item>" },
	{ "/File/_Save Color File as...",        "<ALT><CTRL>S", Menu_File_SaveColorAs,    0, "<Item>" },
	{ "/File/sep2",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/File/_Export image... (Color)",      "<CTRL>E",      Menu_File_Export,         0, "<Item>" },
	{ "/File/_Export image... (Mono)",       "<ALT><CTRL>E", Menu_File_Export,         1, "<Item>" },
	{ "/File/sep3",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/File/_Information...",               "<CTRL>I",      Menu_File_Information,    0, "<Item>" },
	{ "/File/Change _format...",             "<ALT><CTRL>F", Menu_File_ChangeFormat,   0, "<Item>" },
	{ "/File/sep4",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/File/_Quit",                         "<CTRL>Q",      Menu_File_Quit,           0, "<Item>" },

	{ "/_Edit",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/Edit/_Deselect",                     "<CTRL>D",      Menu_Edit_Deselect,       0, "<Item>" },
	{ "/Edit/_Copy",                         "<CTRL>C",      Menu_Edit_Copy,           0, "<Item>" },
	{ "/Edit/Paste",                         "<CTRL>V",      Menu_Edit_Paste,          0, "<Item>" },
	{ "/Edit/_Fill",                         "<CTRL>F",      Menu_Edit_Fill,           0, "<Item>" },
	{ "/Edit/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Edit/S_wap Dark & Light",            "<CTRL>W",      Menu_Edit_Swap,           0, "<Item>" },
	{ "/Edit/sep2",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Edit/Sprite _Mode",                  "<CTRL>M",      Menu_Edit_SpriteMode,     0, "<CheckItem>" },
	{ "/Edit/Show _Grid",                    "<CTRL>G",      Menu_Edit_ShowGrid,       0, "<CheckItem>" },
	{ "/Edit/Display _Negative",             "<CTRL>N",      Menu_Edit_DispNegative,   0, "<CheckItem>" },
	{ "/Edit/sep3",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Edit/Transparency",                  NULL,           NULL,                     0, "<Branch>" },
	{ "/Edit/Transparency/Pink",             NULL,           Menu_Transparency,        0, "<RadioItem>" },
	{ "/Edit/Transparency/Red",              NULL,           Menu_Transparency,        1, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Green",            NULL,           Menu_Transparency,        2, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Blue",             NULL,           Menu_Transparency,        3, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Yellow",           NULL,           Menu_Transparency,        4, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Orange",           NULL,           Menu_Transparency,        5, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Purple",           NULL,           Menu_Transparency,        6, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Bright Red",       NULL,           Menu_Transparency,        7, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Bright Green",     NULL,           Menu_Transparency,        8, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Bright Blue",      NULL,           Menu_Transparency,        9, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Bright Yellow",    NULL,           Menu_Transparency,       10, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Cyan",             NULL,           Menu_Transparency,       11, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Black",            NULL,           Menu_Transparency,       12, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Grey",             NULL,           Menu_Transparency,       13, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Silver",           NULL,           Menu_Transparency,       14, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/White",            NULL,           Menu_Transparency,       15, "/Edit/Transparency/Pink" },
	{ "/Edit/Transparency/Custom",           NULL,           Menu_Transparency,       -1, "/Edit/Transparency/Pink" },
	{ "/Edit/Zoom",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/Edit/Zoom/100%",                     NULL,           Menu_Edit_Zoom,           1, "<RadioItem>" },
	{ "/Edit/Zoom/200%",                     NULL,           Menu_Edit_Zoom,           2, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/300%",                     NULL,           Menu_Edit_Zoom,           3, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/400%",                     NULL,           Menu_Edit_Zoom,           4, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/500%",                     NULL,           Menu_Edit_Zoom,           5, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/600%",                     NULL,           Menu_Edit_Zoom,           6, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/700%",                     NULL,           Menu_Edit_Zoom,           7, "/Edit/Zoom/100%" },
	{ "/Edit/Zoom/800%",                     NULL,           Menu_Edit_Zoom,           8, "/Edit/Zoom/100%" },

	{ "/_Mark",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/Mark/Display _Blend",                "<CTRL>B",      Menu_Mark_DispBlend,      0, "<CheckItem>" },
	{ "/Mark/Swap with _Blend",              "<ALT>B",       Menu_Mark_SwapBlend,      0, "<Item>" },
	{ "/Mark/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Mark/_Top as selection",             "<ALT>T",       Menu_Mark_JumpTopSelect,  0, "<Item>" },
	{ "/Mark/_Jump to tile...",              "<CTRL>J",      Menu_Mark_JumpToTile,     0, "<Item>" },
	{ "/Mark/_Jump to address...",           "<ALT>J",       Menu_Mark_JumpToAddress,  0, "<Item>" },
	{ "/Mark/sep2",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Mark/Get Mark",                      NULL,           NULL,                     0, "<Branch>" },
	{ "/Mark/Get Mark/Blend",                "<ALT>0",       Menu_Mark_GetMark,        0, "<Item>" },
	{ "/Mark/Get Mark/Custom _1",            "<ALT>1",       Menu_Mark_GetMark,        1, "<Item>" },
	{ "/Mark/Get Mark/Custom _2",            "<ALT>2",       Menu_Mark_GetMark,        2, "<Item>" },
	{ "/Mark/Get Mark/Custom _3",            "<ALT>3",       Menu_Mark_GetMark,        3, "<Item>" },
	{ "/Mark/Get Mark/Custom _4",            "<ALT>4",       Menu_Mark_GetMark,        4, "<Item>" },
	{ "/Mark/Get Mark/Custom _5",            "<ALT>5",       Menu_Mark_GetMark,        5, "<Item>" },
	{ "/Mark/Get Mark/Custom _6",            "<ALT>6",       Menu_Mark_GetMark,        6, "<Item>" },
	{ "/Mark/Get Mark/Custom _7",            "<ALT>7",       Menu_Mark_GetMark,        7, "<Item>" },
	{ "/Mark/Get Mark/Custom _8",            "<ALT>8",       Menu_Mark_GetMark,        8, "<Item>" },
	{ "/Mark/Get Mark/Custom _9",            "<ALT>9",       Menu_Mark_GetMark,        9, "<Item>" },
	{ "/Mark/Set Mark",                      NULL,           NULL,                     0, "<Branch>" },
	{ "/Mark/Set Mark/Blend",                "<CTRL>0",      Menu_Mark_SetMark,        0, "<Item>" },
	{ "/Mark/Set Mark/Custom _1",            "<CTRL>1",      Menu_Mark_SetMark,        1, "<Item>" },
	{ "/Mark/Set Mark/Custom _2",            "<CTRL>2",      Menu_Mark_SetMark,        2, "<Item>" },
	{ "/Mark/Set Mark/Custom _3",            "<CTRL>3",      Menu_Mark_SetMark,        3, "<Item>" },
	{ "/Mark/Set Mark/Custom _4",            "<CTRL>4",      Menu_Mark_SetMark,        4, "<Item>" },
	{ "/Mark/Set Mark/Custom _5",            "<CTRL>5",      Menu_Mark_SetMark,        5, "<Item>" },
	{ "/Mark/Set Mark/Custom _6",            "<CTRL>6",      Menu_Mark_SetMark,        6, "<Item>" },
	{ "/Mark/Set Mark/Custom _7",            "<CTRL>7",      Menu_Mark_SetMark,        7, "<Item>" },
	{ "/Mark/Set Mark/Custom _8",            "<CTRL>8",      Menu_Mark_SetMark,        8, "<Item>" },
	{ "/Mark/Set Mark/Custom _9",            "<CTRL>9",      Menu_Mark_SetMark,        9, "<Item>" },

	{ "/_Help",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/Help/_Documentation",                "F1",           Menu_About_Documentation, 0, "<Item>" },
	{ "/Help/_Visit website",                NULL,           Menu_About_VisitWebsite,  0, "<Item>" },
	{ "/Help/sep1",                          NULL,           NULL,                     0, "<Separator>" },
	{ "/Help/_About...",                     NULL,           Menu_About_About,         0, "<Item>" },
};
gint Menu_items_num = sizeof (Menu_items) / sizeof(*Menu_items);

int main(int argc, char **argv)
{
	GtkWidget *widg;
	char tmp[256];
	int i;

	gtk_init (&argc, &argv);
	PokeMini_InitDirs(argv[0], NULL);
	PokeMini_GetCurrentDir();
	PokeMini_GotoExecDir();
	CustomConfFile("colormapper.cfg", CustomConf, NULL);
	PokeMini_GotoCurrentDir();

	// Create our main window
	MainWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(MainWindow), APPTITLE);
	gtk_widget_set_size_request(GTK_WIDGET(MainWindow), 224, 240);
	gtk_window_set_default_size(MainWindow, 500, 450);
	g_signal_connect(MainWindow, "delete-event", G_CALLBACK(MainWindow_delete_event), NULL);
	g_signal_connect(MainWindow, "destroy", G_CALLBACK(MainWindow_destroy), NULL);

	// Create a vertical box for all components
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(MainWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Create the menu bar at the top
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, Menu_items_num, Menu_items, NULL);
	gtk_window_add_accel_group(MainWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Create a label above the color mapper
	LabelInfo = GTK_LABEL(gtk_label_new("-:-"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelInfo), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(LabelInfo));

	// Create horizontal box in the middle
	HBox1 = GTK_BOX(gtk_hbox_new(FALSE, 0));
	gtk_box_pack_start(VBox1, GTK_WIDGET(HBox1), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(HBox1));

	// Create mapper and scroll bar
	ColorMapper = GTKX_COLORMAPPER(gtkx_colormapper_new());
	ColorMapper->on_motion = ColorMapper_on_motion;
	ColorMapper->on_lbutton = ColorMapper_on_lbutton;
	ColorMapper->on_mbutton = ColorMapper_on_mbutton;
	ColorMapper->on_rbutton = ColorMapper_on_rbutton;
	g_signal_connect(ColorMapper, "enter-notify-event", G_CALLBACK(ColorMapper_enter), NULL);
	g_signal_connect(ColorMapper, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_box_pack_start(HBox1, GTK_WIDGET(ColorMapper), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(ColorMapper));
	VScroll1_Adj = GTK_ADJUSTMENT(gtk_adjustment_new(0.0, 0.0, 0.0, 1.0, 16.0, 0.0));
	g_signal_connect(VScroll1_Adj, "value_changed", G_CALLBACK (VScroll1_Adj_changed), NULL);
	VScroll1 = GTK_SCROLLBAR(gtk_vscrollbar_new(VScroll1_Adj));
	gtk_box_pack_start(HBox1, GTK_WIDGET(VScroll1), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(VScroll1));

	// Create separator
	HSep1 = GTK_SEPARATOR(gtk_hseparator_new());
	gtk_box_pack_start(VBox1, GTK_WIDGET(HSep1), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(HSep1));

	// Create horizontal box in the bottom
	HBox2 = GTK_BOX(gtk_hbox_new(FALSE, 0));
	gtk_box_pack_start(VBox1, GTK_WIDGET(HBox2), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(HBox2));

	// Create current selected color
	PickedColor = GTKX_PICKEDCOLOR(gtkx_pickedcolor_new());
	g_signal_connect(PickedColor, "enter-notify-event", G_CALLBACK(PickedColor_enter), NULL);
	g_signal_connect(PickedColor, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_box_pack_start(HBox2, GTK_WIDGET(PickedColor), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(PickedColor));
	VSep2[0] = GTK_SEPARATOR(gtk_vseparator_new());
	gtk_box_pack_start(HBox2, GTK_WIDGET(VSep2[0]), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(VSep2[0]));

	// Create palette picker
	PalettePicker = GTKX_PALETTEPICKER(gtkx_palettepicker_new());
	PalettePicker->on_color = PalettePicker_on_color;
	g_signal_connect(PalettePicker, "enter-notify-event", G_CALLBACK(PalettePicker_enter), NULL);
	g_signal_connect(PalettePicker, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_box_pack_start(HBox2, GTK_WIDGET(PalettePicker), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(PalettePicker));
	VSep2[1] = GTK_SEPARATOR(gtk_vseparator_new());
	gtk_box_pack_start(HBox2, GTK_WIDGET(VSep2[1]), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(VSep2[1]));

	// Create quick access buttons/checkboxes
	VButtonBox1 = GTK_BUTTON_BOX(gtk_vbutton_box_new());
	gtk_button_box_set_layout(GTK_BUTTON_BOX(VButtonBox1), GTK_BUTTONBOX_START);
	gtk_box_set_spacing(GTK_BOX(VButtonBox1), 0);
	gtk_box_pack_start(HBox2, GTK_WIDGET(VButtonBox1), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(VButtonBox1));
	CheckBox_SpriteMode = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Sprite Mode"));
	g_signal_connect(CheckBox_SpriteMode, "toggled", G_CALLBACK(CheckBox_SpriteMode_toggled), NULL);
	g_signal_connect(CheckBox_SpriteMode, "enter-notify-event", G_CALLBACK(CheckBox_SpriteMode_enter), NULL);
	g_signal_connect(CheckBox_SpriteMode, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckBox_SpriteMode), TRUE);
	gtk_container_add(GTK_CONTAINER(VButtonBox1), GTK_WIDGET(CheckBox_SpriteMode));
	gtk_widget_show(GTK_WIDGET(CheckBox_SpriteMode));
	CheckBox_Grid = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Show Grid"));
	g_signal_connect(CheckBox_Grid, "toggled", G_CALLBACK(CheckBox_Grid_toggled), NULL);
	g_signal_connect(CheckBox_Grid, "enter-notify-event", G_CALLBACK(CheckBox_Grid_enter), NULL);
	g_signal_connect(CheckBox_Grid, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckBox_Grid), TRUE);
	gtk_container_add(GTK_CONTAINER(VButtonBox1), GTK_WIDGET(CheckBox_Grid));
	gtk_widget_show(GTK_WIDGET(CheckBox_Grid));
	CheckBox_Negative = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Display Negative"));
	g_signal_connect(CheckBox_Negative, "toggled", G_CALLBACK(CheckBox_Negative_toggled), NULL);
	g_signal_connect(CheckBox_Negative, "enter-notify-event", G_CALLBACK(CheckBox_Negative_enter), NULL);
	g_signal_connect(CheckBox_Negative, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckBox_Negative), TRUE);
	gtk_container_add(GTK_CONTAINER(VButtonBox1), GTK_WIDGET(CheckBox_Negative));
	gtk_widget_show(GTK_WIDGET(CheckBox_Negative));
	CheckBox_DisplayBlend = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Display Blend"));
	g_signal_connect(CheckBox_DisplayBlend, "toggled", G_CALLBACK(CheckBox_DisplayBlend_toggled), NULL);
	g_signal_connect(CheckBox_DisplayBlend, "enter-notify-event", G_CALLBACK(CheckBox_DisplayBlend_enter), NULL);
	g_signal_connect(CheckBox_DisplayBlend, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(CheckBox_DisplayBlend), TRUE);
	gtk_container_add(GTK_CONTAINER(VButtonBox1), GTK_WIDGET(CheckBox_DisplayBlend));
	gtk_widget_show(GTK_WIDGET(CheckBox_DisplayBlend));
	Button_SwapBlend = GTK_BUTTON(gtk_button_new_with_label("Swap with Blend"));
	g_signal_connect(Button_SwapBlend, "clicked", G_CALLBACK(Menu_Mark_SwapBlend), NULL);
	g_signal_connect(Button_SwapBlend, "enter-notify-event", G_CALLBACK(Button_SwapBlend_enter), NULL);
	g_signal_connect(Button_SwapBlend, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_container_add(GTK_CONTAINER(VButtonBox1), GTK_WIDGET(Button_SwapBlend));
	gtk_widget_show(GTK_WIDGET(Button_SwapBlend));
	VSep2[2] = GTK_SEPARATOR(gtk_vseparator_new());
	gtk_box_pack_start(HBox2, GTK_WIDGET(VSep2[2]), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(VSep2[2]));

	// Create quick access buttons/checkboxes
	VButtonBox2 = GTK_BUTTON_BOX(gtk_vbutton_box_new());
	gtk_button_box_set_layout(GTK_BUTTON_BOX(VButtonBox2), GTK_BUTTONBOX_START);
	gtk_box_set_spacing(GTK_BOX(VButtonBox2), 4);
	gtk_box_pack_start(HBox2, GTK_WIDGET(VButtonBox2), FALSE, TRUE, 4);
	gtk_widget_show(GTK_WIDGET(VButtonBox2));
	Contrast_Adj = GTK_ADJUSTMENT(gtk_adjustment_new(0.0, -15.0, 15.0, 1.0, 1.0, 0.0));
	g_signal_connect(Contrast_Adj, "value_changed", G_CALLBACK(Contrast_Adj_changed), NULL);
	Contrast = GTK_SCALE(gtk_hscale_new(Contrast_Adj));
	g_signal_connect(Contrast, "format-value", G_CALLBACK(Constrast_formatvalue), NULL);
	g_signal_connect(Contrast, "enter-notify-event", G_CALLBACK(Contrast_enter), NULL);
	g_signal_connect(Contrast, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_container_add(GTK_CONTAINER(VButtonBox2), GTK_WIDGET(Contrast));
	gtk_widget_show(GTK_WIDGET(Contrast));
	ComboZoom = GTK_COMBO_BOX(gtk_combo_box_new_text());
	g_signal_connect(ComboZoom, "changed", G_CALLBACK(ComboZoom_changed), NULL);
	g_signal_connect(ComboZoom, "enter-notify-event", G_CALLBACK(ComboZoom_enter), NULL);
	g_signal_connect(ComboZoom, "leave-notify-event", G_CALLBACK(Widgets_leave), NULL);
	gtk_combo_box_append_text(ComboZoom, "Zoom 100%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 200%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 300%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 400%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 500%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 600%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 700%");
	gtk_combo_box_append_text(ComboZoom, "Zoom 800%");
	gtk_combo_box_set_active(ComboZoom, Zoom - 1);
	gtk_container_add(GTK_CONTAINER(VButtonBox2), GTK_WIDGET(ComboZoom));
	gtk_widget_show(GTK_WIDGET(ComboZoom));

	// Create a status bar at the bottom
	StatusFrame = GTK_FRAME(gtk_frame_new(NULL));
	gtk_box_pack_start(VBox1, GTK_WIDGET(StatusFrame), FALSE, FALSE, 0);
	gtk_widget_show(GTK_WIDGET(StatusFrame));
	StatusLabel = GTK_LABEL(gtk_label_new(""));
	gtk_label_set_justify(StatusLabel, GTK_JUSTIFY_LEFT);
	gtk_label_set_ellipsize(StatusLabel, PANGO_ELLIPSIZE_END);
	gtk_container_add(GTK_CONTAINER(StatusFrame), GTK_WIDGET(StatusLabel));
	gtk_widget_show(GTK_WIDGET(StatusLabel));

	// Initialize some items in the menu bar
	WidInConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Sprite Mode");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), SpriteMode);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(CheckBox_SpriteMode), SpriteMode);
	gtkx_colormapper_setspritemode(ColorMapper, SpriteMode);
	gtk_adjustment_set_step_increment(VScroll1_Adj, SpriteMode ?   8.0 :  1.0);
	gtk_adjustment_set_page_increment(VScroll1_Adj, SpriteMode ? 128.0 : 16.0);

	widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Show Grid");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), Grid);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(CheckBox_Grid), Grid);
	gtkx_colormapper_setgrid(ColorMapper, Grid);

	widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Display Negative");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), DispNegative);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(CheckBox_Negative), DispNegative);
	gtkx_colormapper_setnegative(ColorMapper, DispNegative);

	widg = gtk_item_factory_get_item(ItemFactory, "/Mark/Display Blend");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), DispBlend);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(CheckBox_DisplayBlend), DispBlend);
	gtkx_colormapper_setdispblend(ColorMapper, DispBlend);

	sprintf(tmp, "/Edit/Zoom/%i00%%", Zoom);
	widg = gtk_item_factory_get_item(ItemFactory, tmp);
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), TRUE);

	widg = gtk_item_factory_get_item(ItemFactory, "/Edit/Transparency/Custom");
	gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	for (i=0; i<16; i++) {
		widg = gtk_item_factory_get_item(ItemFactory, TransparencyColorMenu[i]);
		if (TransparencySelColor == TransparencyColor[i]) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	}

	WidInConfigs = 0;

	// Show main window and update position & size
	gtk_widget_realize(GTK_WIDGET(MainWindow));
	if ((WinX > -15) && (WinY > -16)) {
		gtk_window_move(MainWindow, WinX, WinY);
	}
	if ((WinW > 0) && (WinH > 0)) {
		gtk_window_resize(MainWindow, WinW, WinH);
	}
	gtk_widget_show(GTK_WIDGET(MainWindow));

	// Load filename in command-line
	if (argc > 1) {
		LoadMINFromFile(argv[1]);
	}

	// Main GTK+ loop
	gtk_main();

	// Free data
	FreeColorInfo();

	// Save settings
	PokeMini_GetCurrentDir();
	PokeMini_GotoExecDir();
	CustomConfSave("colormapper.cfg", CustomConf, "Color Mapper Settings");
	PokeMini_GotoCurrentDir();

	return 0;
}
