//      gui.h
//      
//      Copyright 2009 Lukas <lukas@LTx3-64>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.

#ifndef FCEUX_GUI_H
#define FCEUX_GUI_H

#define GTK

#ifdef _GTK
#include <gtk/gtk.h>
#endif
extern GtkWidget* MainWindow;
extern GtkWidget* evbox;
extern GtkRadioAction* stateSlot;
extern int GtkMouseData[3];
extern bool gtkIsStarted;

int InitGTKSubsystem(int argc, char** argv);
void pushOutputToGTK(const char* str);
void showGui(bool b);

bool checkGTKVersion(int major_required, int minor_required);

int configHotkey(char* hotkeyString);
int configGamepadButton(GtkButton* button, gpointer p);

void resetVideo();
void closeVideoWin(GtkWidget* w, GdkEvent* e, gpointer p);
void closeDialog(GtkWidget* w, GdkEvent* e, gpointer p);

void toggleLowPass(GtkWidget* w, gpointer p);
void toggleOption(GtkWidget* w, gpointer p);

int setTint(GtkWidget* w, gpointer p);
int setHue(GtkWidget* w, gpointer p);
void loadPalette (GtkWidget* w, gpointer p);
void clearPalette(GtkWidget* w, gpointer p);
void openPaletteConfig();

void launchNet(GtkWidget* w, gpointer p);
void setUsername(GtkWidget* w, gpointer p);
void netResponse(GtkWidget* w, gint response_id, gpointer p);
void openNetworkConfig();
void flushGtkEvents();

void openHotkeyConfig();
int setInputDevice(GtkWidget* w, gpointer p);
void updateGamepadConfig(GtkWidget* w, gpointer p);
void openGamepadConfig();

int setBufSize(GtkWidget* w, gpointer p);
void setRate(GtkWidget* w, gpointer p);
void setQuality(GtkWidget* w, gpointer p);
void resizeGtkWindow();
void setScaler(GtkWidget* w, gpointer p);
int setXscale(GtkWidget* w, gpointer p);
int setYscale(GtkWidget* w, gpointer p);

#ifdef OPENGL
void setGl(GtkWidget* w, gpointer p);
void setDoubleBuffering(GtkWidget* w, gpointer p);
#endif

void openVideoConfig();
int mixerChanged(GtkWidget* w, gpointer p);
void openSoundConfig();
void quit ();
void openAbout ();
void toggleSound(GtkWidget* check, gpointer data);

void emuReset ();
void hardReset ();
void enableFullscreen ();
void toggleAutoResume (GtkToggleAction *action);

void recordMovie();
void recordMovieAs ();
void loadMovie ();
#ifdef _S9XLUA_H
void loadLua ();
#endif
void loadFdsBios ();

void enableGameGenie(int enabled);
void toggleGameGenie(GtkToggleAction *action);
void togglePause(GtkAction *action);
void loadGameGenie ();

void loadNSF ();
void closeGame();
void loadGame ();
void saveStateAs();
void loadStateFrom();
void quickLoad();
void quickSave();
void changeState(GtkAction *action, GtkRadioAction *current, gpointer data);
unsigned short GDKToSDLKeyval(int gdk_key);
gint convertKeypress(GtkWidget *grab, GdkEventKey *event, gpointer user_data);
gint handleMouseClick(GtkWidget* widget, GdkEvent *event, gpointer callback_data);
void handle_resize(GtkWindow* win, GdkEvent* event, gpointer data);
int InitGTKSubsystem(int argc, char** argv);

#endif // ifndef FCEUX_GUI_H
