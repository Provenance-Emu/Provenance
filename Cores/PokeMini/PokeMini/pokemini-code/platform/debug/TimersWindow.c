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

#include "TimersWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int TimersWindow_InConfigs = 0;

GtkWindow *TimersWindow;
static int TimersWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkScrolledWindow *TimersSW;
static GtkBox *VBox2;
static GtkBox *HBox1;
static GtkBox *HBox2;
static GtkFrame *FrameOsc;
static GtkBox *VBoxOsc;
static GtkLabel *LabelsOsc[2];
static GtkFrame *FrameTmrF;
static GtkBox *VBoxTmrF;
static GtkLabel *LabelsTmrF[4];
static GtkFrame *FrameTmr1;
static GtkBox *VBoxTmr1;
static GtkLabel *LabelsTmr1[15];
static GtkFrame *FrameTmr2;
static GtkBox *VBoxTmr2;
static GtkLabel *LabelsTmr2[15];
static GtkFrame *FrameTmr3;
static GtkBox *VBoxTmr3;
static GtkLabel *LabelsTmr3[15];

// Enable/Disable frames
static int TimersShow_Osc = 1;
static int TimersShow_F = 1;
static int TimersShow_1 = 1;
static int TimersShow_2 = 1;
static int TimersShow_3 = 1;

// ---------------
// Get information
// ---------------

static char *TmrScalar_Txt[32] = {
	"Disabled", "Disabled", "Disabled", "Disabled",
	"Disabled", "Disabled", "Disabled", "Disabled",
	"/2 - 2000000 Hz",
	"/8 - 500000 Hz",
	"/32 - 125000 Hz",
	"/64 - 62500 Hz",
	"/128 - 31250 Hz",
	"/256 - 15625 Hz",
	"/1024 - 3906.25 Hz",
	"/4096 - 976.5625 Hz",
	"Disabled", "Disabled", "Disabled", "Disabled",
	"Disabled", "Disabled", "Disabled", "Disabled",
	"/1 - 32768 Hz",
	"/2 - 16384 Hz",
	"/4 - 8192 Hz",
	"/8 - 4096 Hz",
	"/16 - 2048 Hz",
	"/32 - 1024 Hz",
	"/64 - 512 Hz",
	"/128 - 256 Hz"
};

static void TimersWindow_Render(int force)
{
	char tmp[PMTMPV];
	int val, pre, piv, lopx, hipx;
	double fl;

	// Oscillators
	if (TimersShow_Osc) {
		sprintf(tmp, "2MHz for Timers 1~3: %s", MinxTimers.TmrXEna1 ? "Yes" : "No");
		gtk_label_set_text(LabelsOsc[0], tmp);
		sprintf(tmp, "32KHz for Timers 1~3: %s", MinxTimers.TmrXEna2 ? "Yes" : "No");
		gtk_label_set_text(LabelsOsc[1], tmp);
	}

	// Fixed Timers
	if (TimersShow_F) {
		sprintf(tmp, "Seconds Timer Enabled: %s", (PMR_SEC_CTRL & 0x01) ? "Yes" : "No");
		gtk_label_set_text(LabelsTmrF[0], tmp);
		val = (int)MinxTimers.SecTimerCnt;
		sprintf(tmp, "Seconds Timer Counter: $%06X, %i", val, val);
		gtk_label_set_text(LabelsTmrF[1], tmp);
		sprintf(tmp, "256 Hz Enabled: %s", (PMR_TMR256_CTRL & 0x01) ? "Yes" : "No");
		gtk_label_set_text(LabelsTmrF[2], tmp);
		val = (int)(MinxTimers.Tmr8Cnt >> 24);
		sprintf(tmp, "256 Hz Counter: $%02X, %i", val, val);
		gtk_label_set_text(LabelsTmrF[3], tmp);
		val = (int)(MinxPRC.PRCCnt >> 24);
	}

	// Timer 1
	if (TimersShow_1) {
		lopx = (PMR_TMR1_SCALE & 0x0F) + ((PMR_TMR1_ENA_OSC & 0x01) ? 16 : 0);
		hipx = (PMR_TMR1_SCALE >> 4) + ((PMR_TMR1_ENA_OSC & 0x02) ? 16 : 0);
		sprintf(tmp, "16-Bits Mode: %s", (PMR_TMR1_CTRL_L & 0x80) ? "Yes" : "No");
		gtk_label_set_text(LabelsTmr1[0], tmp);
		if (PMR_TMR1_CTRL_L & 0x80) {
			sprintf(tmp, "Oscillator: %s", (PMR_TMR1_ENA_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr1[1], tmp);
			sprintf(tmp, "Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr1[2], tmp);
			sprintf(tmp, "Enabled: %s", (PMR_TMR1_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr1[3], tmp);
			pre = (int)((MinxTimers.Tmr1PreA >> 24) + ((MinxTimers.Tmr1PreB >> 24) << 8));
			sprintf(tmp, "Preset: $%04X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr1[4], tmp);
			piv = ((int)PMR_TMR1_PVT_L) + ((int)PMR_TMR1_PVT_H << 8);
			sprintf(tmp, "Pivot: $%04X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr1[5], tmp);
			val = (int)((MinxTimers.Tmr1CntA >> 24) + ((MinxTimers.Tmr1CntB >> 24) << 8));
			sprintf(tmp, "Count: $%04X, %i", val, val);
			gtk_label_set_text(LabelsTmr1[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr1[7], tmp);
			gtk_label_set_text(LabelsTmr1[8], "---");
			gtk_label_set_text(LabelsTmr1[9], "---");
			gtk_label_set_text(LabelsTmr1[10], "---");
			gtk_label_set_text(LabelsTmr1[11], "---");
			gtk_label_set_text(LabelsTmr1[12], "---");
			gtk_label_set_text(LabelsTmr1[13], "---");
			gtk_label_set_text(LabelsTmr1[14], "---");
		} else {
			sprintf(tmp, "Lo Oscillator: %s", (PMR_TMR1_ENA_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr1[1], tmp);
			sprintf(tmp, "Lo Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr1[2], tmp);
			sprintf(tmp, "Lo Enabled: %s", (PMR_TMR1_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr1[3], tmp);
			pre = (int)(MinxTimers.Tmr1PreA >> 24);
			sprintf(tmp, "Lo Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr1[4], tmp);
			piv = (int)PMR_TMR1_PVT_L;
			sprintf(tmp, "Lo Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr1[5], tmp);
			val = (int)(MinxTimers.Tmr1CntA >> 24);
			sprintf(tmp, "Lo Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr1[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Lo Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr1[7], tmp);
			sprintf(tmp, "Hi Oscillator: %s", (PMR_TMR1_ENA_OSC & 0x02) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr1[8], tmp);
			sprintf(tmp, "Hi Scalar: %s", TmrScalar_Txt[hipx]);
			gtk_label_set_text(LabelsTmr1[9], tmp);
			sprintf(tmp, "Hi Enabled: %s", (PMR_TMR1_CTRL_H & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr1[10], tmp);
			pre = (int)(MinxTimers.Tmr1PreB >> 24);
			sprintf(tmp, "Hi Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr1[11], tmp);
			piv = (int)PMR_TMR1_PVT_H;
			sprintf(tmp, "Hi Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr1[12], tmp);
			val = (int)(MinxTimers.Tmr1CntB >> 24);
			sprintf(tmp, "Hi Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr1[13], tmp);
			fl = (double)MinxTimers_CountFreq[hipx] / (double)(pre + 1);
			sprintf(tmp, "Hi Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr1[14], tmp);
		}
	}

	// Timer 2
	if (TimersShow_2) {
		lopx = (PMR_TMR2_SCALE & 0x0F) + ((PMR_TMR2_OSC & 0x01) ? 16 : 0);
		hipx = (PMR_TMR2_SCALE >> 4) + ((PMR_TMR2_OSC & 0x02) ? 16 : 0);
		sprintf(tmp, "16-Bits Mode: %s", (PMR_TMR2_CTRL_L & 0x80) ? "Yes" : "No");
		gtk_label_set_text(LabelsTmr2[0], tmp);
		if (PMR_TMR2_CTRL_L & 0x80) {
			sprintf(tmp, "Oscillator: %s", (PMR_TMR2_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr2[1], tmp);
			sprintf(tmp, "Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr2[2], tmp);
			sprintf(tmp, "Enabled: %s", (PMR_TMR2_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr2[3], tmp);
			pre = (int)((MinxTimers.Tmr2PreA >> 24) + ((MinxTimers.Tmr2PreB >> 24) << 8));
			sprintf(tmp, "Preset: $%04X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr2[4], tmp);
			piv = ((int)PMR_TMR2_PVT_L) + ((int)PMR_TMR2_PVT_H << 8);
			sprintf(tmp, "Pivot: $%04X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr2[5], tmp);
			val = (int)((MinxTimers.Tmr2CntA >> 24) + ((MinxTimers.Tmr2CntB >> 24) << 8));
			sprintf(tmp, "Count: $%04X, %i", val, val);
			gtk_label_set_text(LabelsTmr2[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr2[7], tmp);
			gtk_label_set_text(LabelsTmr2[8], "---");
			gtk_label_set_text(LabelsTmr2[9], "---");
			gtk_label_set_text(LabelsTmr2[10], "---");
			gtk_label_set_text(LabelsTmr2[11], "---");
			gtk_label_set_text(LabelsTmr2[12], "---");
			gtk_label_set_text(LabelsTmr2[13], "---");
			gtk_label_set_text(LabelsTmr2[14], "---");
		} else {
			sprintf(tmp, "Lo Oscillator: %s", (PMR_TMR2_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr2[1], tmp);
			sprintf(tmp, "Lo Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr2[2], tmp);
			sprintf(tmp, "Lo Enabled: %s", (PMR_TMR2_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr2[3], tmp);
			pre = (int)(MinxTimers.Tmr2PreA >> 24);
			sprintf(tmp, "Lo Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr2[4], tmp);
			piv = (int)PMR_TMR2_PVT_L;
			sprintf(tmp, "Lo Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr2[5], tmp);
			val = (int)(MinxTimers.Tmr2CntA >> 24);
			sprintf(tmp, "Lo Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr2[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Lo Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr2[7], tmp);
			sprintf(tmp, "Hi Oscillator: %s", (PMR_TMR2_OSC & 0x02) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr2[8], tmp);
			sprintf(tmp, "Hi Scalar: %s", TmrScalar_Txt[hipx]);
			gtk_label_set_text(LabelsTmr2[9], tmp);
			sprintf(tmp, "Hi Enabled: %s", (PMR_TMR2_CTRL_H & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr2[10], tmp);
			pre = (int)(MinxTimers.Tmr2PreB >> 24);
			sprintf(tmp, "Hi Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr2[11], tmp);
			piv = (int)PMR_TMR2_PVT_H;
			sprintf(tmp, "Hi Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr2[12], tmp);
			val = (int)(MinxTimers.Tmr2CntB >> 24);
			sprintf(tmp, "Hi Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr2[13], tmp);
			fl = (double)MinxTimers_CountFreq[hipx] / (double)(pre + 1);
			sprintf(tmp, "Hi Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr2[14], tmp);
		}
	}

	// Timer 3 + Sound
	if (TimersShow_3) {
		lopx = (PMR_TMR3_SCALE & 0x0F) + ((PMR_TMR3_OSC & 0x01) ? 16 : 0);
		hipx = (PMR_TMR3_SCALE >> 4) + ((PMR_TMR3_OSC & 0x02) ? 16 : 0);
		sprintf(tmp, "16-Bits Mode: %s", (PMR_TMR3_CTRL_L & 0x80) ? "Yes" : "No");
		gtk_label_set_text(LabelsTmr3[0], tmp);
		if (PMR_TMR3_CTRL_L & 0x80) {
			sprintf(tmp, "Oscillator: %s", (PMR_TMR3_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr3[1], tmp);
			sprintf(tmp, "Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr3[2], tmp);
			sprintf(tmp, "Enabled: %s", (PMR_TMR3_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr3[3], tmp);
			pre = (int)((MinxTimers.Tmr3PreA >> 24) + ((MinxTimers.Tmr3PreB >> 24) << 8));
			sprintf(tmp, "Preset: $%04X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr3[4], tmp);
			piv = (int)MinxTimers.Timer3Piv;
			sprintf(tmp, "Pivot: $%04X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr3[5], tmp);
			val = (int)((MinxTimers.Tmr3CntA >> 24) + ((MinxTimers.Tmr3CntB >> 24) << 8));
			sprintf(tmp, "Count: $%04X, %i", val, val);
			gtk_label_set_text(LabelsTmr3[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr3[7], tmp);
			if (pre) fl = 100.0 - ((double)piv / (double)pre * 100.0);
			else fl = 0.0;
			if (fl < 0.0) fl = 0.0;
			sprintf(tmp, "Pulse Width: %.4f%%", fl);
			gtk_label_set_text(LabelsTmr3[8], tmp);
			switch (PMR_AUD_VOL & 3) {
				case 0: val = 0; break;
				case 1: case 2: val = 50; break;
				default: val = 100; break;
			}
			sprintf(tmp, "Volume: %i%%", val);
			gtk_label_set_text(LabelsTmr3[9], tmp);
			gtk_label_set_text(LabelsTmr3[10], "---");
			gtk_label_set_text(LabelsTmr3[11], "---");
			gtk_label_set_text(LabelsTmr3[12], "---");
			gtk_label_set_text(LabelsTmr3[13], "---");
			gtk_label_set_text(LabelsTmr3[14], "---");
		} else {
			sprintf(tmp, "Lo Oscillator: %s", (PMR_TMR3_OSC & 0x01) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr3[1], tmp);
			sprintf(tmp, "Lo Scalar: %s", TmrScalar_Txt[lopx]);
			gtk_label_set_text(LabelsTmr3[2], tmp);
			sprintf(tmp, "Lo Enabled: %s", (PMR_TMR3_CTRL_L & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr3[3], tmp);
			pre = (int)(MinxTimers.Tmr3PreA >> 24);
			sprintf(tmp, "Lo Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr3[4], tmp);
			piv = (int)(MinxTimers.Timer3Piv & 0xFF);
			sprintf(tmp, "Lo Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr3[5], tmp);
			val = (int)(MinxTimers.Tmr3CntA >> 24);
			sprintf(tmp, "Lo Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr3[6], tmp);
			fl = (double)MinxTimers_CountFreq[lopx] / (double)(pre + 1);
			sprintf(tmp, "Lo Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr3[7], tmp);
			sprintf(tmp, "Hi Oscillator: %s", (PMR_TMR3_OSC & 0x02) ? "32Khz" : "2Mhz");
			gtk_label_set_text(LabelsTmr3[8], tmp);
			sprintf(tmp, "Hi Scalar: %s", TmrScalar_Txt[hipx]);
			gtk_label_set_text(LabelsTmr3[9], tmp);
			sprintf(tmp, "Hi Enabled: %s", (PMR_TMR3_CTRL_H & 0x04) ? "Yes" : "No");
			gtk_label_set_text(LabelsTmr3[10], tmp);
			pre = (int)(MinxTimers.Tmr3PreB >> 24);
			sprintf(tmp, "Hi Preset: $%02X, %i", pre, pre);
			gtk_label_set_text(LabelsTmr3[11], tmp);
			piv = (int)(MinxTimers.Timer3Piv >> 8);
			sprintf(tmp, "Hi Pivot: $%02X, %i", piv, piv);
			gtk_label_set_text(LabelsTmr3[12], tmp);
			val = (int)(MinxTimers.Tmr3CntB >> 24);
			sprintf(tmp, "Hi Count: $%02X, %i", val, val);
			gtk_label_set_text(LabelsTmr3[13], tmp);
			fl = (double)MinxTimers_CountFreq[hipx] / (double)(pre + 1);
			sprintf(tmp, "Hi Underflow Freq.: %.2f Hz", fl);
			gtk_label_set_text(LabelsTmr3[14], tmp);
		}
	}
}

// --------------
// Menu callbacks
// --------------

static void TimersW_View_Osc(GtkWidget *widget, gpointer data)
{
	if (TimersWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Oscillators");
	TimersShow_Osc = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (TimersShow_Osc) gtk_widget_show(GTK_WIDGET(FrameOsc));
	else gtk_widget_hide(GTK_WIDGET(FrameOsc));
	TimersWindow_Refresh(1);
}

static void TimersW_View_TmrF(GtkWidget *widget, gpointer data)
{
	if (TimersWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Fixed Timers");
	TimersShow_F = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (TimersShow_F) gtk_widget_show(GTK_WIDGET(FrameTmrF));
	else gtk_widget_hide(GTK_WIDGET(FrameTmrF));
	TimersWindow_Refresh(1);
}

static void TimersW_View_Tmr1(GtkWidget *widget, gpointer data)
{
	if (TimersWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 1");
	TimersShow_1 = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (TimersShow_1) gtk_widget_show(GTK_WIDGET(FrameTmr1));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr1));
	TimersWindow_Refresh(1);
}

static void TimersW_View_Tmr2(GtkWidget *widget, gpointer data)
{
	if (TimersWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 2");
	TimersShow_2 = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (TimersShow_2) gtk_widget_show(GTK_WIDGET(FrameTmr2));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr2));
	TimersWindow_Refresh(1);
}

static void TimersW_View_Tmr3(GtkWidget *widget, gpointer data)
{
	if (TimersWindow_InConfigs) return;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 3 + Sound");
	TimersShow_3 = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	if (TimersShow_3) gtk_widget_show(GTK_WIDGET(FrameTmr3));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr3));
	TimersWindow_Refresh(1);
}

static void TimersW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void TimersW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (TimersWindow_InConfigs) return;

	if (index >= 0) {
		dclc_timerswin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(TimersWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_timerswin_refresh, 4, 0, 0, 1000)) {
			dclc_timerswin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint TimersWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(TimersWindow));
	return TRUE;
}

static gboolean TimersWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) TimersWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry TimersWindow_MenuItems[] = {
	{ "/_View",                              NULL,           NULL,                     0, "<Branch>" },
	{ "/View/Oscillators",                   NULL,           TimersW_View_Osc,         0, "<CheckItem>" },
	{ "/View/Fixed Timers",                  NULL,           TimersW_View_TmrF,        0, "<CheckItem>" },
	{ "/View/Timer 1",                       NULL,           TimersW_View_Tmr1,        0, "<CheckItem>" },
	{ "/View/Timer 2",                       NULL,           TimersW_View_Tmr2,        0, "<CheckItem>" },
	{ "/View/Timer 3 + Sound",               NULL,           TimersW_View_Tmr3,        0, "<CheckItem>" },

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
	{ "/Refresh/Now!",                       NULL,           TimersW_RefreshNow,       0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           TimersW_Refresh,          0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           TimersW_Refresh,          1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           TimersW_Refresh,          2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           TimersW_Refresh,          3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           TimersW_Refresh,          5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           TimersW_Refresh,          7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           TimersW_Refresh,         11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           TimersW_Refresh,         35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           TimersW_Refresh,         71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           TimersW_Refresh,         -1, "/Refresh/100% 72fps" },
};
static gint TimersWindow_MenuItemsNum = sizeof(TimersWindow_MenuItems) / sizeof(*TimersWindow_MenuItems);

// -------------
// Timers Window
// -------------

int TimersWindow_Create(void)
{
	int i;

	// Window
	TimersWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(TimersWindow), "Timers View");
	gtk_widget_set_size_request(GTK_WIDGET(TimersWindow), 200, 100);
	gtk_window_set_default_size(TimersWindow, 480, 240);
	g_signal_connect(TimersWindow, "delete_event", G_CALLBACK(TimersWindow_delete_event), NULL);
	g_signal_connect(TimersWindow, "window-state-event", G_CALLBACK(TimersWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(TimersWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, TimersWindow_MenuItemsNum, TimersWindow_MenuItems, NULL);
	gtk_window_add_accel_group(TimersWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Scrolling window with vertical box
	TimersSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(TimersSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(TimersSW));
	gtk_widget_show(GTK_WIDGET(TimersSW));
	VBox2 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_scrolled_window_add_with_viewport(TimersSW, GTK_WIDGET(VBox2));
	gtk_widget_show(GTK_WIDGET(VBox2));
	
	// 1st Row
	HBox1 = GTK_BOX(gtk_hbox_new(TRUE, 0));
	gtk_box_pack_start(VBox2, GTK_WIDGET(HBox1), FALSE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(HBox1));

	// Oscillators
	FrameOsc = GTK_FRAME(gtk_frame_new(" Oscillators "));
	gtk_box_pack_start(HBox1, GTK_WIDGET(FrameOsc), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(FrameOsc));
	VBoxOsc = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameOsc), GTK_WIDGET(VBoxOsc));
	gtk_widget_show(GTK_WIDGET(VBoxOsc));
	for (i=0; i<2; i++) {
		LabelsOsc[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsOsc[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsOsc[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxOsc, GTK_WIDGET(LabelsOsc[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsOsc[i]));
	}

	// Fixed Timers
	FrameTmrF = GTK_FRAME(gtk_frame_new(" Fixed Timers "));
	gtk_box_pack_start(HBox1, GTK_WIDGET(FrameTmrF), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(FrameTmrF));
	VBoxTmrF = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameTmrF), GTK_WIDGET(VBoxTmrF));
	gtk_widget_show(GTK_WIDGET(VBoxTmrF));
	for (i=0; i<4; i++) {
		LabelsTmrF[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsTmrF[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsTmrF[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxTmrF, GTK_WIDGET(LabelsTmrF[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsTmrF[i]));
	}

	// 2nd Row
	HBox2 = GTK_BOX(gtk_hbox_new(TRUE, 0));
	gtk_box_pack_start(VBox2, GTK_WIDGET(HBox2), FALSE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(HBox2));

	// Timer 1
	FrameTmr1 = GTK_FRAME(gtk_frame_new(" Timer 1 "));
	gtk_box_pack_start(HBox2, GTK_WIDGET(FrameTmr1), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(FrameTmr1));
	VBoxTmr1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameTmr1), GTK_WIDGET(VBoxTmr1));
	gtk_widget_show(GTK_WIDGET(VBoxTmr1));
	for (i=0; i<15; i++) {
		LabelsTmr1[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsTmr1[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsTmr1[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxTmr1, GTK_WIDGET(LabelsTmr1[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsTmr1[i]));
	}

	// Timer 2
	FrameTmr2 = GTK_FRAME(gtk_frame_new(" Timer 2 "));
	gtk_box_pack_start(HBox2, GTK_WIDGET(FrameTmr2), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(FrameTmr2));
	VBoxTmr2 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameTmr2), GTK_WIDGET(VBoxTmr2));
	gtk_widget_show(GTK_WIDGET(VBoxTmr2));
	for (i=0; i<15; i++) {
		LabelsTmr2[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsTmr2[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsTmr2[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxTmr2, GTK_WIDGET(LabelsTmr2[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsTmr2[i]));
	}

	// Timer 3 + Sound
	FrameTmr3 = GTK_FRAME(gtk_frame_new(" Timer 3 + Sound "));
	gtk_box_pack_start(HBox2, GTK_WIDGET(FrameTmr3), TRUE, TRUE, 2);
	gtk_widget_show(GTK_WIDGET(FrameTmr3));
	VBoxTmr3 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(FrameTmr3), GTK_WIDGET(VBoxTmr3));
	gtk_widget_show(GTK_WIDGET(VBoxTmr3));
	for (i=0; i<15; i++) {
		LabelsTmr3[i] = GTK_LABEL(gtk_label_new("???"));
		gtk_misc_set_alignment(GTK_MISC(LabelsTmr3[i]), 0.0, 0.5);
		gtk_label_set_justify(LabelsTmr3[i], GTK_JUSTIFY_LEFT);
		gtk_box_pack_start(VBoxTmr3, GTK_WIDGET(LabelsTmr3[i]), TRUE, TRUE, 2);
		gtk_widget_show(GTK_WIDGET(LabelsTmr3[i]));
	}

	return 1;
}

void TimersWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(TimersWindow))) {
		gtk_widget_show(GTK_WIDGET(TimersWindow));
		gtk_window_deiconify(TimersWindow);
		gtk_window_get_position(TimersWindow, &x, &y);
		gtk_window_get_size(TimersWindow, &width, &height);
		dclc_timerswin_winx = x;
		dclc_timerswin_winy = y;
		dclc_timerswin_winw = width;
		dclc_timerswin_winh = height;
	}
}

void TimersWindow_Activate(void)
{
	TimersWindow_Render(1);
	if (TimersShow_Osc) gtk_widget_show(GTK_WIDGET(FrameOsc));
	else gtk_widget_hide(GTK_WIDGET(FrameOsc));
	if (TimersShow_F) gtk_widget_show(GTK_WIDGET(FrameTmrF));
	else gtk_widget_hide(GTK_WIDGET(FrameTmrF));
	if (TimersShow_1) gtk_widget_show(GTK_WIDGET(FrameTmr1));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr1));
	if (TimersShow_2) gtk_widget_show(GTK_WIDGET(FrameTmr2));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr2));
	if (TimersShow_3) gtk_widget_show(GTK_WIDGET(FrameTmr3));
	else gtk_widget_hide(GTK_WIDGET(FrameTmr3));
	gtk_widget_realize(GTK_WIDGET(TimersWindow));
	if ((dclc_timerswin_winx > -15) && (dclc_timerswin_winy > -16)) {
		gtk_window_move(TimersWindow, dclc_timerswin_winx, dclc_timerswin_winy);
	}
	if ((dclc_timerswin_winw > 0) && (dclc_timerswin_winh > 0)) {
		gtk_window_resize(TimersWindow, dclc_timerswin_winw, dclc_timerswin_winh);
	}
	gtk_widget_show(GTK_WIDGET(TimersWindow));
	gtk_window_present(TimersWindow);
}

void TimersWindow_UpdateConfigs(void)
{
	GtkWidget *widg;

	TimersWindow_InConfigs = 1;

	widg = gtk_item_factory_get_item(ItemFactory, "/View/Oscillators");
	if (TimersShow_Osc) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Fixed Timers");
	if (TimersShow_F) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 1");
	if (TimersShow_1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 2");
	if (TimersShow_2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/View/Timer 3 + Sound");
	if (TimersShow_3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	switch (dclc_timerswin_refresh) {
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

	TimersWindow_InConfigs = 0;
}

void TimersWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(TimersSW));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(TimersSW));
	}
}

void TimersWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_timerswin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(TimersWindow)) || TimersWindow_minimized) return;
		}
		TimersWindow_Render(0);
	} else refreshcnt--;
}
