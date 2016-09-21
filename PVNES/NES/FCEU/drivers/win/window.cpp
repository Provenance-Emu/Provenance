/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002 Xodnizel
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*f
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

//http://www.nubaria.com/en/blog/?p=289

// File description: Everything relevant for the main window should go here. This
//                   does not include functions relevant for dialog windows.

#include "../../input.h"
#include "../../state.h"
#include "../../cheat.h" //adelikat: For FCEU_LoadGameCheats()
#include "../../version.h"
#include "../../video.h" //adelikat: For ScreenshotAs Get/Set functions
#include "window.h"
#include "main.h"
#include "state.h"

#include "sound.h"
#include "wave.h"
#include "input.h"
#include "video.h"
#include "input.h"
#include "fceu.h"

#include "ram_search.h"
#include "ramwatch.h"
#include "memwatch.h"
#include "ppuview.h"
#include "debugger.h"
#include "cheat.h"
#include "debug.h"
#include "ntview.h"
#include "memview.h"
#include "tracer.h"
#include "cdlogger.h"
#include "throttle.h"
#include "monitor.h"
#include "keyboard.h"
#include "joystick.h"
#include "oldmovie.h"
#include "movie.h"
#include "texthook.h"
#include "guiconfig.h"
#include "timing.h"
#include "palette.h"
#include "directories.h"
#include "gui.h"
#include "help.h"
#include "movie.h"
#include "fceulua.h"
#include "utils/xstring.h"
#include "file.h"
#include "mapinput.h"
#include "movieoptions.h"
#include "config.h" //adelikat: For SaveConfigFile()

#include <fstream>
#include <sstream>
#include <cmath>

#include "taseditor/taseditor_window.h"
#include "taseditor/playback.h"
extern TASEDITOR_WINDOW taseditorWindow;
extern PLAYBACK playback;

#include "Win32InputBox.h"
extern int32 fps_scale_unpaused;

//extern void ToggleFullscreen();

using namespace std;

//----Context Menu - Some dynamically added menu items
#define FCEUX_CONTEXT_UNHIDEMENU        60000
#define FCEUX_CONTEXT_LOADLASTLUA       60001
#define FCEUX_CONTEXT_CLOSELUAWINDOWS   60002
#define FCEUX_CONTEXT_TOGGLESUBTITLES   60003
#define FCEUX_CONTEXT_DUMPSUBTITLES     60004


//********************************************************************************
//Globals
//********************************************************************************

//Handles----------------------------------------------
static HMENU fceumenu = 0;	  //Main menu.
HWND pwindow;				  //Client Area
HMENU recentmenu;				//Recent Menu
HMENU recentluamenu;			//Recent Lua Files Menu
HMENU recentmoviemenu;			//Recent Movie Files Menu
HMENU hfceuxcontext;		  //Handle to context menu
HMENU hfceuxcontextsub;		  //Handle to context sub menu
HWND MainhWnd;				  //Main FCEUX(Parent) window Handle.  Dialogs should use GetMainHWND() to get this

//Extern variables-------------------------------------
extern bool movieSubtitles;
extern FCEUGI *GameInfo;
extern int EnableAutosave;
extern bool frameAdvanceLagSkip;
extern bool turbo;
extern bool movie_readonly;
extern bool AutoSS;			//flag for whether an auto-save has been made
extern int newppu;
extern BOOL CALLBACK ReplayMetadataDialogProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);	//Metadata dialog
extern bool CheckFileExists(const char* filename);	//Receives a filename (fullpath) and checks to see if that file exists
extern bool oldInputDisplay;

//AutoFire-----------------------------------------------
void ShowNetplayConsole(void); //mbg merge 7/17/06 YECH had to add
void MapInput(void);
void SetAutoFirePattern(int onframes, int offframes);
void SetAutoFireOffset(int offset);
static int CheckedAutoFirePattern = MENU_AUTOFIRE_PATTERN_1;
static int CheckedAutoFireOffset = MENU_AUTOFIRE_OFFSET_1;
int GetCheckedAutoFirePattern();
int GetCheckedAutoFireOffset();

//Internal variables-------------------------------------
char *md5_asciistr(uint8 digest[16]);
static int winwidth, winheight;
static volatile int nofocus = 0;
static int tog = 0;					//Toggle for Hide Menu
static bool loggingSound = false;
static LONG WindowXC=1<<30,WindowYC;
int MainWindow_wndx, MainWindow_wndy;
static uint32 mousex,mousey,mouseb;
static int vchanged = 0;
int menuYoffset = 0;
bool wasPausedByCheats = false;		//For unpausing the emulator if paused by the cheats dialog
bool rightClickEnabled = true;		//If set to false, the right click context menu will be disabled.
bool fullscreenByDoubleclick = false;

//Function Prototypes
void ChangeMenuItemText(int menuitem, string text);			//Alters a menu item name
void ChangeContextMenuItemText(int menuitem, string text, HMENU menu);	//Alters a context menu item name
void SaveMovieAs();	//Gets a filename for Save Movie As...
void OpenRamSearch();
void OpenRamWatch();
void SaveSnapshotAs();

//Recent Menu Strings ------------------------------------
char *recent_files[] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const unsigned int MENU_FIRST_RECENT_FILE = 600;
const unsigned int MAX_NUMBER_OF_RECENT_FILES = sizeof(recent_files)/sizeof(*recent_files);

//Lua Console --------------------------------------------
//TODO: these need to be in a header file instead
extern HWND LuaConsoleHWnd;
extern INT_PTR CALLBACK DlgLuaScriptDialog(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam);
extern void UpdateLuaConsole(const char* fname);

//Recent Lua Menu ----------------------------------------
char *recent_lua[] = { 0, 0, 0, 0, 0 };
const unsigned int LUA_FIRST_RECENT_FILE = 50000;
const unsigned int MAX_NUMBER_OF_LUA_RECENT_FILES = sizeof(recent_lua)/sizeof(*recent_lua);

//Recent Movie Menu -------------------------------------
char *recent_movie[] = { 0, 0, 0, 0, 0 };
const unsigned int MOVIE_FIRST_RECENT_FILE = 51000;
const unsigned int MAX_NUMBER_OF_MOVIE_RECENT_FILES = sizeof(recent_movie)/sizeof(*recent_movie);

//Exported variables ------------------------------------

int EnableBackgroundInput = 0;
int ismaximized = 0;

//Help Menu subtopics
string moviehelp = "MovieRecording";		 //Movie Recording
string gettingstartedhelp = "Gettingstarted";//Getting Started

//********************************************************************************
void SetMainWindowText()
{
	string str = FCEU_NAME_AND_VERSION;
	if (newppu)
		str.append(" (New PPU)");
	if (GameInfo)
	{
		//Add the filename to the window caption
		extern char FileBase[];
		str.append(": ");
		str.append(FileBase);
		if (FCEUMOV_IsLoaded())
		{
			str.append(" Playing: ");
			str.append(StripPath(FCEUI_GetMovieName()));
		}
	}
	SetWindowText(hAppWnd, str.c_str());
}

bool HasRecentFiles()
{
	for (int x = 0; x < MAX_NUMBER_OF_RECENT_FILES; x++)
	{
		if (recent_files[x])
			return true;
	}
	return false;
}

HWND GetMainHWND()
{
	return MainhWnd;
}

int GetCheckedAutoFirePattern()
{
//adelikat: sorry, I'm sure there is an easier way to accomplish this.
//This function allows the proper check to be displayed on the auto-fire pattern offset at start up when another autofire pattern is saved in config
	if (AFon == 1 && AFoff == 2) return MENU_AUTOFIRE_PATTERN_2;
	if (AFon == 1 && AFoff == 3) return MENU_AUTOFIRE_PATTERN_3;
	if (AFon == 1 && AFoff == 4) return MENU_AUTOFIRE_PATTERN_4;
	if (AFon == 1 && AFoff == 5) return MENU_AUTOFIRE_PATTERN_5;
	if (AFon == 2 && AFoff == 1) return MENU_AUTOFIRE_PATTERN_6;
	if (AFon == 2 && AFoff == 2) return MENU_AUTOFIRE_PATTERN_7;
	if (AFon == 2 && AFoff == 3) return MENU_AUTOFIRE_PATTERN_8;
	if (AFon == 2 && AFoff == 4) return MENU_AUTOFIRE_PATTERN_9;
	if (AFon == 3 && AFoff == 1) return MENU_AUTOFIRE_PATTERN_10;
	if (AFon == 3 && AFoff == 2) return MENU_AUTOFIRE_PATTERN_11;
	if (AFon == 3 && AFoff == 3) return MENU_AUTOFIRE_PATTERN_12;
	if (AFon == 4 && AFoff == 1) return MENU_AUTOFIRE_PATTERN_13;
	if (AFon == 4 && AFoff == 2) return MENU_AUTOFIRE_PATTERN_14;
	if (AFon == 5 && AFoff == 1) return MENU_AUTOFIRE_PATTERN_15;

return MENU_AUTOFIRE_PATTERN_1;
}

int GetCheckedAutoFireOffset()
{
	if (AutoFireOffset == 1) return MENU_AUTOFIRE_OFFSET_2;
	if (AutoFireOffset == 2) return MENU_AUTOFIRE_OFFSET_3;
	if (AutoFireOffset == 3) return MENU_AUTOFIRE_OFFSET_4;
	if (AutoFireOffset == 4) return MENU_AUTOFIRE_OFFSET_5;
	if (AutoFireOffset == 5) return MENU_AUTOFIRE_OFFSET_6;
	return MENU_AUTOFIRE_OFFSET_1;
}

// Internal functions



static void ConvertFCM(HWND hwndOwner)
{
	std::string initdir = FCEU_GetPath(FCEUMKF_MOVIE);

	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hwndOwner;
	ofn.lpstrFilter = "FCEU <2.0 Movie Files (*.fcm)\0*.fcm\0All Files (*.*)\0*.*\0\0";
	ofn.lpstrFile = new char[640*1024]; //640K should be enough for anyone
	ofn.lpstrFile[0] = 0;
	ofn.nMaxFile = 640*1024;
	ofn.lpstrInitialDir = initdir.c_str();
	ofn.Flags = OFN_NOCHANGEDIR | OFN_HIDEREADONLY | OFN_ALLOWMULTISELECT | OFN_EXPLORER;
	ofn.lpstrDefExt = "fcm";
	ofn.lpstrTitle = "Select old movie(s) for conversion";

	if(GetOpenFileName(&ofn))
	{
		std::vector<std::string> todo;

		//build a list of movies to convert. this might be one, or it might be many, depending on what the user selected
		if(ofn.nFileExtension==0)
		{
			//multiselect
			std::string dir = ofn.lpstrFile;
			char* cp = ofn.lpstrFile + dir.size() + 1;
			while(*cp) 
			{
				std::string fname = cp;
				todo.push_back(dir + "/" + fname);
				cp += fname.size() + 1;
			}
		}
		else
		{
			todo.push_back(ofn.lpstrFile);
		}

		SetCursor(LoadCursor(0,IDC_WAIT));

		//convert each movie
		int okcount = 0;
		for(uint32 i=0;i<todo.size();i++)
		{
			std::string infname = todo[i];
			
			//produce output filename
			std::string outname;
			size_t dot = infname.find_last_of(".");
			if(dot == std::string::npos)
				outname = infname + ".fm2";
			else
				outname = infname.substr(0,dot) + ".fm2";

			MovieData md;
			EFCM_CONVERTRESULT result = convert_fcm(md, infname);
			if(result==FCM_CONVERTRESULT_SUCCESS)
			{
				okcount++;
				EMUFILE_FILE* outf = FCEUD_UTF8_fstream(outname, "wb");
				md.dump(outf,false);
				delete outf;
			} else {
				std::string msg = "Failure converting " + infname + "\r\n\r\n" + EFCM_CONVERTRESULT_message(result);
				MessageBox(hwndOwner,msg.c_str(),"Failure converting fcm", 0);
			}
		}

		std::string okmsg = "Converted " + stditoa(okcount) + " movie(s). There were " + stditoa(todo.size()-okcount) + " failure(s).";
		MessageBox(hwndOwner,okmsg.c_str(),"FCM Conversion results", 0);
	}

	delete[] ofn.lpstrFile;
}

void CalcWindowSize(RECT *al)
{
	int xres = 256;
	if(fullscreen && vmodes[0].special==3)
		xres=301;
	if(!fullscreen && winspecial==3)
		xres=301;

	double screen_width = VNSWID_NU(xres);
	double screen_height = FSettings.TotalScanlines();
	if (eoptions & EO_TVASPECT)
		screen_width = ceil(screen_height * (screen_width / xres) * (tvAspectX / tvAspectY));

	al->left = 0;
	al->top = 0;
	al->right = ceil(screen_width * winsizemulx);
	al->bottom = menuYoffset + ceil(screen_height * winsizemuly);

	AdjustWindowRectEx(al,
		GetWindowLong(hAppWnd, GWL_STYLE),
		GetMenu(hAppWnd) != NULL,
		GetWindowLong(hAppWnd, GWL_EXSTYLE)
		);

	al->right -= al->left;
	al->left = 0;
	al->bottom -= al->top;
	al->top=0;
}

/// Updates the menu items that should only be enabled if a game is loaded.
/// @param enable Flag that indicates whether the menus should be enabled (1) or disabled (0). 
void updateGameDependentMenus(unsigned int enable)
{
	const int menu_ids[]= {
		MENU_CLOSE_FILE,
		ID_FILE_SCREENSHOT,
		ID_FILE_SAVESCREENSHOTAS,
		MENU_RESET,
		MENU_POWER,
		MENU_INSERT_COIN,
		MENU_SWITCH_DISK,
		MENU_EJECT_DISK,
		MENU_RECORD_AVI,
		MENU_STOP_AVI,
		MENU_RECORD_WAV,
		MENU_STOP_WAV,
		MENU_HIDE_MENU,
		//MENU_DEBUGGER,
		MENU_PPUVIEWER,
		MENU_NAMETABLEVIEWER,
		MENU_HEXEDITOR,
		MENU_TRACELOGGER,
		MENU_CDLOGGER,
		MENU_GAMEGENIEDECODER,
		MENU_CHEATS,
		ID_RAM_SEARCH,
		ID_RAM_WATCH,
		ID_TOOLS_TEXTHOOKER
	};

	for (unsigned int i = 0; i < sizeof(menu_ids) / sizeof(*menu_ids); i++)
	{
			EnableMenuItem(fceumenu, menu_ids[i], MF_BYCOMMAND | (enable ? MF_ENABLED : MF_GRAYED));
	}
}

//Updates menu items which need to be checked or unchecked.
void UpdateCheckedMenuItems()
{
	bool spr, bg;
	FCEUI_GetRenderPlanes(spr,bg);

	static int *polo[] = { &genie, &status_icon};
	static int polo2[]={ MENU_GAME_GENIE, MENU_SHOW_STATUS_ICON };
	int x;

	// Check or uncheck the necessary menu items
	for(x = 0; x < sizeof(polo) / sizeof(*polo); x++)
	{
		CheckMenuItem(fceumenu, polo2[x], *polo[x] ? MF_CHECKED : MF_UNCHECKED);
	}
	//File Menu
	CheckMenuItem(fceumenu, ID_FILE_MOVIE_TOGGLEREAD, movie_readonly ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_FILE_OPENLUAWINDOW, LuaConsoleHWnd ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_AVI_ENABLEHUDRECORDING, FCEUI_AviEnableHUDrecording() ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_AVI_DISMOVIEMESSAGE, FCEUI_AviDisableMovieMessages() ? MF_CHECKED : MF_UNCHECKED);

	//NES Menu
	CheckMenuItem(fceumenu, ID_NES_PAUSE, EmulationPaused ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_NES_TURBO, turbo ? MF_CHECKED : MF_UNCHECKED);

	//Config Menu
	CheckMenuItem(fceumenu, MENU_RUN_IN_BACKGROUND, eoptions & EO_BGRUN ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_BACKGROUND_INPUT, EnableBackgroundInput ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_ENABLE_AUTOSAVE, EnableAutosave ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_DISPLAY_FA_LAGSKIP, frameAdvanceLagSkip?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_CONFIG_BINDSAVES, bindSavestate?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_ENABLE_BACKUPSAVESTATES, backupSavestates?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_ENABLE_COMPRESSSAVESTATES, compressSavestates?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_ENABLE_AUTORESUME, AutoResumePlay?MF_CHECKED : MF_UNCHECKED);

	//Config - Display SubMenu
	CheckMenuItem(fceumenu, MENU_DISPLAY_LAGCOUNTER, lagCounterDisplay?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_DISPLAY_FRAMECOUNTER, frame_display ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_DISPLAY_RERECORDCOUNTER, rerecord_display ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_DISPLAY_FPS, FCEUI_ShowFPS() ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_DISPLAY_MOVIESTATUSICON, status_icon ? MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_DISPLAY_BG, bg?MF_CHECKED:MF_UNCHECKED);
	CheckMenuItem(fceumenu, MENU_DISPLAY_OBJ, spr?MF_CHECKED:MF_UNCHECKED);
	CheckMenuItem(fceumenu, ID_INPUTDISPLAY_OLDSTYLEDISP, oldInputDisplay?MF_CHECKED:MF_UNCHECKED);

	//Config - Region SubMenu
	if (PAL)
		CheckMenuRadioItem(fceumenu, MENU_NTSC, MENU_DENDY, MENU_PAL, MF_BYCOMMAND);
	else if (dendy)
		CheckMenuRadioItem(fceumenu, MENU_NTSC, MENU_DENDY, MENU_DENDY, MF_BYCOMMAND);
	else		
		CheckMenuRadioItem(fceumenu, MENU_NTSC, MENU_DENDY, MENU_NTSC, MF_BYCOMMAND);

	// Tools Menu
	CheckMenuItem(fceumenu, MENU_ALTERNATE_AB, GetAutoFireDesynch() ? MF_CHECKED : MF_UNCHECKED);
	CheckedAutoFirePattern = GetCheckedAutoFirePattern();
	CheckMenuRadioItem(fceumenu, MENU_AUTOFIRE_PATTERN_1, MENU_AUTOFIRE_PATTERN_15, CheckedAutoFirePattern, MF_BYCOMMAND);
	CheckedAutoFireOffset = GetCheckedAutoFireOffset();
	CheckMenuRadioItem(fceumenu, MENU_AUTOFIRE_OFFSET_1, MENU_AUTOFIRE_OFFSET_6, CheckedAutoFireOffset, MF_BYCOMMAND);

	// Check input display
	switch (input_display)
	{
		case 0: // Off
			CheckMenuRadioItem(fceumenu, MENU_INPUTDISPLAY_0, MENU_INPUTDISPLAY_4, MENU_INPUTDISPLAY_0, MF_BYCOMMAND);
			break;
		case 1: // 1 player
			CheckMenuRadioItem(fceumenu, MENU_INPUTDISPLAY_0, MENU_INPUTDISPLAY_4, MENU_INPUTDISPLAY_1, MF_BYCOMMAND);
			break;
		case 2: // 2 player
			CheckMenuRadioItem(fceumenu, MENU_INPUTDISPLAY_0, MENU_INPUTDISPLAY_4, MENU_INPUTDISPLAY_2, MF_BYCOMMAND);
			break;
		// note: input display can actually have a 3 player display option but is skipped in the hotkey toggle so it is skipped here as well
		case 4: // 4 player
			CheckMenuRadioItem(fceumenu, MENU_INPUTDISPLAY_0, MENU_INPUTDISPLAY_4, MENU_INPUTDISPLAY_4, MF_BYCOMMAND);
			break;
		default:
			break;
	}
}

void UpdateContextMenuItems(HMENU context, int whichContext)
{
	string undoLoadstate = "Undo loadstate";
	string redoLoadstate = "Redo loadstate";
	string undoSavestate = "Undo savestate";
	string redoSavestate = "Redo savestate";

	CheckMenuItem(context,ID_CONTEXT_FULLSAVESTATES,MF_BYCOMMAND | (fullSaveStateLoads ? MF_CHECKED : MF_UNCHECKED));

	//Undo Loadstate
	if (CheckBackupSaveStateExist() && (undoLS || redoLS))
		EnableMenuItem(context,FCEUX_CONTEXT_UNDOLOADSTATE,MF_BYCOMMAND | MF_ENABLED);
	else
		EnableMenuItem(context,FCEUX_CONTEXT_UNDOLOADSTATE,MF_BYCOMMAND | MF_GRAYED);
	if (redoLS)
		ChangeContextMenuItemText(FCEUX_CONTEXT_UNDOLOADSTATE, redoLoadstate, context);
	else
		ChangeContextMenuItemText(FCEUX_CONTEXT_UNDOLOADSTATE, undoLoadstate, context);

	//Undo Savestate
	if (undoSS || redoSS)		//If undo or redo, enable Undo savestate, else keep it gray
		EnableMenuItem(context,FCEUX_CONTEXT_UNDOSAVESTATE,MF_BYCOMMAND | MF_ENABLED);
	else
		EnableMenuItem(context,FCEUX_CONTEXT_UNDOSAVESTATE,MF_BYCOMMAND | MF_GRAYED);
	if (redoSS)
		ChangeContextMenuItemText(FCEUX_CONTEXT_UNDOSAVESTATE, redoSavestate, context);
	else
		ChangeContextMenuItemText(FCEUX_CONTEXT_UNDOSAVESTATE, undoSavestate, context);
	
	//Rewind to last auto-save
	if(EnableAutosave && AutoSS)
		EnableMenuItem(context,FCEUX_CONTEXT_REWINDTOLASTAUTO,MF_BYCOMMAND | MF_ENABLED);
	else
		EnableMenuItem(context,FCEUX_CONTEXT_REWINDTOLASTAUTO,MF_BYCOMMAND | MF_GRAYED);

	//Load last ROM
	if (recent_files[0])
		EnableMenuItem(context,FCEUX_CONTEXT_RECENTROM1,MF_BYCOMMAND | MF_ENABLED);
	else
		EnableMenuItem(context,FCEUX_CONTEXT_RECENTROM1,MF_BYCOMMAND | MF_GRAYED);

	//Add Lua separator if either lua condition is true (yeah, a little ugly but it works)
	#ifdef _S9XLUA_H
	if (recent_lua[0] || FCEU_LuaRunning())
		InsertMenu(context, 0xFFFF, MF_SEPARATOR, 0, "");

	//If a recent lua file exists, add Load Last Lua
	if (recent_lua[0])
		InsertMenu(context, 0xFFFF, MF_BYCOMMAND, FCEUX_CONTEXT_LOADLASTLUA, "Load last Lua");
		
	//If lua is loaded, add a stop lua item
	if (FCEU_LuaRunning())
		InsertMenu(context, 0xFFFF, MF_BYCOMMAND, FCEUX_CONTEXT_CLOSELUAWINDOWS, "Close All Script Windows");
	#endif

	//If menu is hidden, add an Unhide menu option
	if (tog)
	{
		InsertMenu(context, 0xFFFF, MF_SEPARATOR, 0, "");
		InsertMenu(context,0xFFFF, MF_BYCOMMAND, FCEUX_CONTEXT_UNHIDEMENU, "Unhide Menu");
	}

	if ( ( (whichContext == 0) || (whichContext == 3) ) && (currMovieData.subtitles.size()) ){
		// At position 3 is "View comments and subtitles". Insert this there:
		
		InsertMenu(context,0x3, MF_BYPOSITION, FCEUX_CONTEXT_TOGGLESUBTITLES, movieSubtitles ? "Subtitle Display: On" : "Subtitle Display: Off");
		// At position 4(+1) is after View comments and subtitles. Insert this there:
		InsertMenu(context,0x5, MF_BYPOSITION, FCEUX_CONTEXT_DUMPSUBTITLES, "Dump Subtitles to SRT file");
	}
}


//adelikat: This removes a recent menu item from any recent menu, and shrinks the list accordingly
//The update recent menu function will need to be run after this
void RemoveRecentItem(unsigned int which, char**bufferArray, const unsigned int MAX)
{
	//which = array item to remove
	//buffer = char array of the recent menu
	//MAX = max number of array items

	//Just in case
	if (which >= MAX)
		return;
	
	//Remove the item
	if(bufferArray[which])
	{
		free(bufferArray[which]);
	}

	//If the item is not the last one in the list, shift the remaining ones up
	if (which < (MAX-1))
	{
		//Move the remaining items up
		for(unsigned int x = which+1; x < MAX; x++)
		{
			bufferArray[x-1] = bufferArray[x];	//Shift each remaining item up by 1
		}
	}
	
	bufferArray[MAX-1] = 0;	//Clear out the last item since it is empty now no matter what
}

/// Updates recent files / recent directories menu
/// @param menu Menu handle of the main window's menu
/// @param strs Strings to add to the menu
/// @param mitem Menu ID of the recent files / directory menu
/// @param baseid Menu ID of the first subitem
void UpdateRMenu(HMENU menu, char **strs, unsigned int mitem, unsigned int baseid)
{
	// UpdateRMenu(recentmenu, recent_files, MENU_RECENT_FILES, MENU_FIRST_RECENT_FILE);

	MENUITEMINFO moo;
	int x;

	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_SUBMENU | MIIM_STATE;

	GetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);
	moo.hSubMenu = menu;
	moo.fState = strs[0] ? MFS_ENABLED : MFS_GRAYED;

	SetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);

	// Remove all recent files submenus
	for(x = 0; x < MAX_NUMBER_OF_RECENT_FILES; x++)
	{
		RemoveMenu(menu, baseid + x, MF_BYCOMMAND);
	}

	// Recreate the menus
	for(x = MAX_NUMBER_OF_RECENT_FILES - 1; x >= 0; x--)
	{  
		// Skip empty strings
		if(!strs[x])
			continue;

		std::string tmp = strs[x];
		std::string archiveName, fileName, fileToOpen;
		FCEU_SplitArchiveFilename(tmp,archiveName,fileName,fileToOpen);
		if(archiveName != "")
			tmp = archiveName + " <" + fileName + ">";

		//clamp this string to 128 chars
		if(tmp.size()>128)
			tmp = tmp.substr(0,128);

		moo.cbSize = sizeof(moo);
		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;

		//// Fill in the menu text.
		//if(strlen(strs[x]) < 128)
		//{
		//	sprintf(tmp, "&%d. %s", ( x + 1 ) % 10, strs[x]);
		//}
		//else
		//{
		//	sprintf(tmp, "&%d. %s", ( x + 1 ) % 10, strs[x] + strlen( strs[x] ) - 127);
		//}

		// Insert the menu item
		moo.cch = tmp.size();
		moo.fType = 0;
		moo.wID = baseid + x;
		moo.dwTypeData = (LPSTR)tmp.c_str();
		InsertMenuItem(menu, 0, 1, &moo);
	}

	DrawMenuBar(hAppWnd);
}

/// Helper function to populate the recent directories and recent files arrays.
/// @param addString String to add to the array.
/// @param bufferArray Array where the string will be added.
/// @param arrayLen Length of the bufferArray.
/// @param menu Menu handle of the main menu.
/// @param menuItem
/// @param baseID
void UpdateRecentArray(const char* addString, char** bufferArray, unsigned int arrayLen, HMENU menu, unsigned int menuItem, unsigned int baseId)
{
	// Try to find out if the filename is already in the recent files list.
	for(unsigned int x = 0; x < arrayLen; x++)
	{
		if(bufferArray[x])
		{
			if(!strcmp(bufferArray[x], addString))    // Item is already in list.
			{
				// If the filename is in the file list don't add it again.
				// Move it up in the list instead.

				int y;
				char *tmp;

				// Save pointer.
				tmp = bufferArray[x];

				for(y = x; y; y--)
				{
					// Move items down.
					bufferArray[y] = bufferArray[y - 1];
				}

				// Put item on top.
				bufferArray[0] = tmp;

				// Update the recent files menu
				UpdateRMenu(menu, bufferArray, menuItem, baseId);

				return;
			}
		}
	}

	// The filename wasn't found in the list. That means we need to add it.

	// If there's no space left in the recent files list, get rid of the last
	// item in the list.
	if(bufferArray[arrayLen - 1])
	{
		free(bufferArray[arrayLen - 1]);
	}

	// Move the other items down.
	for(unsigned int x = arrayLen - 1; x; x--)
	{
		bufferArray[x] = bufferArray[x - 1];
	}

	// Add the new item.
	bufferArray[0] = (char*)malloc(strlen(addString) + 1); //mbg merge 7/17/06 added cast
	strcpy(bufferArray[0], addString);

	// Update the recent files menu
	UpdateRMenu(menu, bufferArray, menuItem, baseId);
}

/// Add a filename to the recent files list.
/// @param filename Name of the file to add.
void AddRecentFile(const char *filename)
{
	UpdateRecentArray(filename, recent_files, MAX_NUMBER_OF_RECENT_FILES, recentmenu, MENU_RECENT_FILES, MENU_FIRST_RECENT_FILE);
}

void LoadRecentRom(int slot)
{
	char*& fname = recent_files[slot];
	if(fname)
	{
		if (!ALoad(fname))
		{
			int result = MessageBox(hAppWnd, "Remove from list?", "Could Not Open Recent File", MB_YESNO);
			if (result == IDYES)
			{
				RemoveRecentItem(slot, recent_files, MAX_NUMBER_OF_RECENT_FILES);
				UpdateRMenu(recentmenu, recent_files, MENU_RECENT_FILES, MENU_FIRST_RECENT_FILE);
			}
		}
	}
}

void UpdateLuaRMenu(HMENU menu, char **strs, unsigned int mitem, unsigned int baseid)
{
	MENUITEMINFO moo;
	int x;

	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_SUBMENU | MIIM_STATE;

	GetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);
	moo.hSubMenu = menu;
	moo.fState = strs[0] ? MFS_ENABLED : MFS_GRAYED;

	SetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);

	// Remove all recent files submenus
	for(x = 0; x < MAX_NUMBER_OF_LUA_RECENT_FILES; x++)
	{
		RemoveMenu(menu, baseid + x, MF_BYCOMMAND);
	}

	// Recreate the menus
	for(x = MAX_NUMBER_OF_LUA_RECENT_FILES - 1; x >= 0; x--)
	{  
		// Skip empty strings
		if(!strs[x])
			continue;

		string tmp = strs[x];
		
		//clamp this string to 128 chars
		if(tmp.size()>128)
			tmp = tmp.substr(0,128);

		moo.cbSize = sizeof(moo);
		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;
		
		// Insert the menu item
		moo.cch = tmp.size();
		moo.fType = 0;
		moo.wID = baseid + x;
		moo.dwTypeData = (LPSTR)tmp.c_str();
		InsertMenuItem(menu, 0, 1, &moo);
	}

	DrawMenuBar(hAppWnd);
}

void UpdateRecentLuaArray(const char* addString, char** bufferArray, unsigned int arrayLen, HMENU menu, unsigned int menuItem, unsigned int baseId)
{
	// Try to find out if the filename is already in the recent files list.
	for(unsigned int x = 0; x < arrayLen; x++)
	{
		if(bufferArray[x])
		{
			if(!strcmp(bufferArray[x], addString))    // Item is already in list.
			{
				// If the filename is in the file list don't add it again.
				// Move it up in the list instead.

				int y;
				char *tmp;

				// Save pointer.
				tmp = bufferArray[x];

				for(y = x; y; y--)
				{
					// Move items down.
					bufferArray[y] = bufferArray[y - 1];
				}

				// Put item on top.
				bufferArray[0] = tmp;

				// Update the recent files menu
				UpdateLuaRMenu(menu, bufferArray, menuItem, baseId);

				return;
			}
		}
	}

	// The filename wasn't found in the list. That means we need to add it.

	// If there's no space left in the recent files list, get rid of the last
	// item in the list.
	if(bufferArray[arrayLen - 1])
	{
		free(bufferArray[arrayLen - 1]);
	}

	// Move the other items down.
	for(unsigned int x = arrayLen - 1; x; x--)
	{
		bufferArray[x] = bufferArray[x - 1];
	}

	// Add the new item.
	bufferArray[0] = (char*)malloc(strlen(addString) + 1); //mbg merge 7/17/06 added cast
	strcpy(bufferArray[0], addString);

	// Update the recent files menu
	UpdateLuaRMenu(menu, bufferArray, menuItem, baseId);

}

void AddRecentLuaFile(const char *filename)
{
	UpdateRecentLuaArray(filename, recent_lua, MAX_NUMBER_OF_LUA_RECENT_FILES, recentluamenu, MENU_LUA_RECENT, LUA_FIRST_RECENT_FILE); 
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void UpdateMovieRMenu(HMENU menu, char **strs, unsigned int mitem, unsigned int baseid)
{
	MENUITEMINFO moo;
	int x;

	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_SUBMENU | MIIM_STATE;

	GetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);
	moo.hSubMenu = menu;
	moo.fState = strs[0] ? MFS_ENABLED : MFS_GRAYED;

	SetMenuItemInfo(GetSubMenu(fceumenu, 0), mitem, FALSE, &moo);

	// Remove all recent files submenus
	for(x = 0; x < MAX_NUMBER_OF_MOVIE_RECENT_FILES; x++)
	{
		RemoveMenu(menu, baseid + x, MF_BYCOMMAND);
	}

	// Recreate the menus
	for(x = MAX_NUMBER_OF_MOVIE_RECENT_FILES - 1; x >= 0; x--)
	{  
		// Skip empty strings
		if(!strs[x])
			continue;

		string tmp = strs[x];
		
		//clamp this string to 128 chars
		if(tmp.size()>128)
			tmp = tmp.substr(0,128);

		moo.cbSize = sizeof(moo);
		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;
		
		// Insert the menu item
		moo.cch = tmp.size();
		moo.fType = 0;
		moo.wID = baseid + x;
		moo.dwTypeData = (LPSTR)tmp.c_str();
		InsertMenuItem(menu, 0, 1, &moo);
	}

	DrawMenuBar(hAppWnd);
}

void UpdateRecentMovieArray(const char* addString, char** bufferArray, unsigned int arrayLen, HMENU menu, unsigned int menuItem, unsigned int baseId)
{
	// Try to find out if the filename is already in the recent files list.
	for(unsigned int x = 0; x < arrayLen; x++)
	{
		if(bufferArray[x])
		{
			if(!strcmp(bufferArray[x], addString))    // Item is already in list.
			{
				// If the filename is in the file list don't add it again.
				// Move it up in the list instead.

				int y;
				char *tmp;

				// Save pointer.
				tmp = bufferArray[x];

				for(y = x; y; y--)
				{
					// Move items down.
					bufferArray[y] = bufferArray[y - 1];
				}

				// Put item on top.
				bufferArray[0] = tmp;

				// Update the recent files menu
				UpdateMovieRMenu(menu, bufferArray, menuItem, baseId);

				return;
			}
		}
	}

	// The filename wasn't found in the list. That means we need to add it.

	// If there's no space left in the recent files list, get rid of the last
	// item in the list.
	if(bufferArray[arrayLen - 1])
	{
		free(bufferArray[arrayLen - 1]);
	}

	// Move the other items down.
	for(unsigned int x = arrayLen - 1; x; x--)
	{
		bufferArray[x] = bufferArray[x - 1];
	}

	// Add the new item.
	bufferArray[0] = (char*)malloc(strlen(addString) + 1); //mbg merge 7/17/06 added cast
	strcpy(bufferArray[0], addString);

	// Update the recent files menu
	UpdateMovieRMenu(menu, bufferArray, menuItem, baseId);

}

void AddRecentMovieFile(const char *filename)
{
	UpdateRecentMovieArray(filename, recent_movie, MAX_NUMBER_OF_MOVIE_RECENT_FILES, recentmoviemenu, MENU_MOVIE_RECENT, MOVIE_FIRST_RECENT_FILE); 
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Hides the main menu.
//@param hide_menu Flag to turn the main menu on (0) or off (1) 
void HideMenu(unsigned int hide_menu)
{
	if(hide_menu)
	{
		SetMenu(hAppWnd, 0);
	}
	else
	{
		SetMenu(hAppWnd, fceumenu);
	}
}

void HideFWindow(int h)
{
	LONG desa;

	if (h)  /* Full-screen. */
	{
		RECT bo;
		GetWindowRect(hAppWnd, &bo);
		WindowXC = bo.left;
		WindowYC = bo.top;

		SetMenu(hAppWnd, 0);
		desa=WS_POPUP | WS_CLIPSIBLINGS;  
	} else
	{
		desa = WS_OVERLAPPEDWINDOW | WS_CLIPSIBLINGS;
		HideMenu(tog);

		/* Stupid DirectDraw bug(I think?) requires this.  Need to investigate it. */
		SetWindowPos(hAppWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOCOPYBITS | SWP_NOMOVE | SWP_NOREPOSITION | SWP_NOSIZE);
	}

	SetWindowLong(hAppWnd, GWL_STYLE, desa | ( GetWindowLong(hAppWnd, GWL_STYLE) & WS_VISIBLE ));
	SetWindowPos(hAppWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOCOPYBITS | SWP_NOMOVE | SWP_NOREPOSITION | SWP_NOSIZE | SWP_NOZORDER);
}

//Toggles the display status of the main menu.
void ToggleHideMenu(void)
{ 
	if(!fullscreen && !nofocus && (GameInfo || tog))
	{
		tog ^= 1;
		HideMenu(tog);
		SetMainWindowStuff();
	}
}

//Toggles the display status of the main menu.
//TODO: We could get rid of this one.
void FCEUD_HideMenuToggle(void)
{
	ToggleHideMenu();
}

void CloseGame()
{
	if (GameInfo)
	{
		FCEUI_CloseGame();
		KillMemView();
		updateGameDependentMenus(GameInfo != 0);
		updateGameDependentMenusDebugger(GameInfo != 0);
		SetMainWindowText();
	}
}

bool ALoad(const char *nameo, char* innerFilename, bool silent)
{
	int oldPaused = EmulationPaused;

	if (GameInfo) FCEUI_CloseGame();

	if (FCEUI_LoadGameVirtual(nameo, 1, silent))
	{
		pal_emulation = FCEUI_GetCurrentVidSystem(0, 0);

		UpdateCheckedMenuItems();

		PushCurrentVideoSettings();

		std::string recentFileName = nameo;
		if(GameInfo->archiveFilename && GameInfo->archiveCount>1)
			recentFileName = (std::string)GameInfo->archiveFilename + "|" + GameInfo->filename;
		else
			recentFileName = nameo;
		
		AddRecentFile(recentFileName.c_str());

		RefreshThrottleFPS();

		if(eoptions & EO_HIDEMENU && !tog)
		{
			ToggleHideMenu();
		}

		if(eoptions & EO_FSAFTERLOAD)
		{
			SetFSVideoMode();
		}
		
		
		if (AutoRWLoad)
		{
			OpenRWRecentFile(0);	//adelikat: TODO: This command should be called internally from the RamWatch dialog in order for it to be more portable
			OpenRamWatch();
		}
		if (debuggerAutoload)
		{
			DoDebug(0);
		}
	}
	else
	{
		SetWindowText(hAppWnd, FCEU_NAME_AND_VERSION);	//adelikat: If game fails to load while a previous one was open, the previous would have been closed, so reflect that in the window caption
		return false;
	}
	
	SetMainWindowText();
	ParseGIInput(GameInfo);

	updateGameDependentMenus(GameInfo != 0);
	updateGameDependentMenusDebugger(GameInfo != 0);
	EmulationPaused = oldPaused;
	return true;
}

/// Shows an Open File dialog and opens the ROM if the user selects a ROM file.
/// @param hParent Handle of the main window
/// @param initialdir Directory that's pre-selected in the Open File dialog.
void LoadNewGamey(HWND hParent, const char *initialdir)
{
	const char filter[] = "All usable files (*.nes,*.nsf,*.fds,*.unf,*.zip,*.rar,*.7z,*.gz)\0*.nes;*.nsf;*.fds;*.unf;*.zip;*.rar;*.7z;*.gz\0All non-compressed usable files (*.nes,*.nsf,*.fds,*.unf)\0*.nes;*.nsf;*.fds;*.unf\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];

	// Create the Open File dialog
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));

	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle=FCEU_NAME" Open File...";
	ofn.lpstrFilter=filter;
	nameo[0]=0;
	ofn.hwndOwner=hParent;
	ofn.lpstrFile=nameo;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY; //OFN_EXPLORER|OFN_ENABLETEMPLATE|OFN_ENABLEHOOK;
	string stdinitdir = FCEU_GetPath(FCEUMKF_ROMS);
	
	if (initialdir)					//adelikat: If a directory is specified in the function parameter, it should take priority
		ofn.lpstrInitialDir = initialdir;
	else							//adelikat: Else just use the override, if no override it will default to 0 - last directory used.
		ofn.lpstrInitialDir = stdinitdir.c_str();
	
	// Show the Open File dialog
	if(GetOpenFileName(&ofn))
	{
		ALoad(nameo);
	}
}

void GetMouseData(uint32 (&md)[3])
{
	extern RECT bestfitRect;

	int xres = 256;
	if(fullscreen && vmodes[0].special==3)
		xres=301;
	if(!fullscreen && winspecial==3)
		xres=301;

	double screen_width = VNSWID_NU(xres);
	double screen_height = FSettings.TotalScanlines();

	if (eoptions & EO_BESTFIT && (bestfitRect.top || bestfitRect.left))
	{
		if ((int)mousex <= bestfitRect.left)
		{
			md[0] = 0;
		} else if ((int)mousex >= bestfitRect.right)
		{
			md[0] = screen_width - 1;
		} else
		{
			md[0] = screen_width * (mousex - bestfitRect.left) / (bestfitRect.right - bestfitRect.left);
		}
		if ((int)mousey <= bestfitRect.top)
		{
			md[1] = 0;
		} else if ((int)mousey >= bestfitRect.bottom)
		{
			md[1] = screen_height - 1;
		} else
		{
			md[1] = screen_height * (mousey - bestfitRect.top) / (bestfitRect.bottom - bestfitRect.top);
		}
	} else
	{
		RECT client_rect;
		GetClientRect(hAppWnd, &client_rect);
		if ((int)mousex <= client_rect.left)
		{
			md[0] = 0;
		} else if ((int)mousex >= client_rect.right)
		{
			md[0] = screen_width - 1;
		} else
		{
			md[0] = screen_width * (mousex - client_rect.left) / (client_rect.right - client_rect.left);
		}
		if ((int)mousey <= client_rect.top)
		{
			md[1] = 0;
		} else if ((int)mousey >= client_rect.bottom)
		{
			md[1] = screen_height - 1;
		} else
		{
			md[1] = screen_height * (mousey - client_rect.top) / (client_rect.bottom - client_rect.top);
		}
	}
	md[0] += VNSCLIP;
	md[1] += FSettings.FirstSLine;
	md[2] = ((mouseb == MK_LBUTTON) ? 1 : 0) | (( mouseb == MK_RBUTTON ) ? 2 : 0);
}

void DumpSubtitles(HWND hWnd)
{ 
	const char filter[]="Subtitles files (*.srt)\0*.srt\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];

	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hWnd;
	ofn.lpstrTitle="Save Subtitles as...";
	ofn.lpstrFilter = filter;
	strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	ofn.lpstrFile = nameo;
	ofn.nMaxFile = 256;
	ofn.Flags = OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.lpstrDefExt = "srt";

	if (GetSaveFileName(&ofn))
	{
		FILE *srtfile;
		srtfile = fopen(nameo, "w");
		if (srtfile) 
		{
			extern std::vector<int> subtitleFrames;
			extern std::vector<std::string> subtitleMessages;
			float fps = (currMovieData.palFlag == 0 ? 60.0988 : 50.0069); // NTSC vs PAL
			float subduration = 3; // seconds for the subtitles to be displayed

			for (unsigned int i = 0; i < subtitleFrames.size(); i++)
			{
				fprintf(srtfile, "%i\n", i+1); // starts with 1, not 0
				double seconds, ms, endseconds, endms;
				seconds = subtitleFrames[i]/fps;
				if (i+1 < subtitleFrames.size()) // there's another subtitle coming after this one
				{
					if (subtitleFrames[i+1]-subtitleFrames[i] < subduration*fps) // avoid two subtitles at the same time
					{
						endseconds = (subtitleFrames[i+1]-1)/fps; // frame x: subtitle1; frame x+1 subtitle2
					} else {
						endseconds = seconds+subduration;
					}
				} else {
					endseconds = seconds+subduration;
				}
				
				ms = modf(seconds, &seconds);
				endms = modf(endseconds, &endseconds);
				// this is just beyond ugly, don't show it to your kids
				fprintf(srtfile,
				"%02.0f:%02d:%02d,%03d --> %02.0f:%02d:%02d,%03d\n", // hh:mm:ss,ms --> hh:mm:ss,ms
				floor(seconds/3600),	(int)floor(seconds/60   ) % 60, (int)floor(seconds)	% 60, (int)(ms*1000),
				floor(endseconds/3600), (int)floor(endseconds/60) % 60, (int)floor(endseconds) % 60, (int)(endms*1000));
				fprintf(srtfile, "%s\n\n", subtitleMessages[i].c_str()); // new line for every subtitle
			}
		}
	fclose(srtfile);
	}

	return;

}


//Message loop of the main window
LRESULT FAR PASCAL AppWndProc(HWND hWnd,UINT msg,WPARAM wParam,LPARAM lParam)
{
	MainhWnd = hWnd;
	int whichContext = 0;
	POINT pt;
	RECT file_rect;
	RECT help_rect;
	int x = 0;
	
	char TempArray[2048];
	PCOPYDATASTRUCT pcData;

	switch(msg)
	{
	case WM_COPYDATA:

		pcData = (PCOPYDATASTRUCT) lParam;

	    switch ( pcData->dwData )
		{ 
	    case 1: //cData.dwData = 1; (can use for other types as well)
			if (!ALoad((LPSTR) ( (DATA *) (pcData->lpData) )-> strFilePath))
				MessageBox(hWnd,"File from second instance failed to open", "Failed to open file", MB_OK);
			break;
		}
		break;

	case WM_LBUTTONDBLCLK:
	{
		if (fullscreenByDoubleclick)
		{
			extern void ToggleFullscreen();
			ToggleFullscreen();
			return 0;
		} else
		{
			mouseb=wParam;
			goto proco;
		}
		break;
	}

	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP:
	case WM_RBUTTONDOWN:
		mouseb=wParam;
		goto proco;

	case WM_MOUSEWHEEL:
	{
		// send the message to TAS Editor
		if (taseditorWindow.hwndTASEditor)
			SendMessage(taseditorWindow.hwndTASEditor, msg, wParam, lParam);
		return 0;
	}

	case WM_MBUTTONDOWN:
	{
		if (FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
			playback.handleMiddleButtonClick();
		return 0;
	}

	case WM_RBUTTONUP:
	{
		// If TAS Editor is engaged, rightclick shouldn't popup menus, because right button is used with wheel input for TAS Editor's own purposes
		if (!FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		{
			if (rightClickEnabled)
			{
				//If There is a movie loaded in read only
				if (GameInfo && FCEUMOV_Mode(MOVIEMODE_PLAY|MOVIEMODE_RECORD|MOVIEMODE_FINISHED) && movie_readonly)
					whichContext = 0; // Game+Movie+readonly
				//If there is a movie loaded in read+write
				else if (GameInfo && FCEUMOV_Mode(MOVIEMODE_PLAY|MOVIEMODE_RECORD|MOVIEMODE_FINISHED) && !movie_readonly)
					whichContext = 3; // Game+Movie+readwrite
				//If there is a ROM loaded but no movie
				else if (GameInfo)
					whichContext = 1; // Game+NoMovie
				//Else no ROM
				else
					whichContext = 2; // NoGame

				hfceuxcontext = LoadMenu(fceu_hInstance,"FCEUCONTEXTMENUS");
				hfceuxcontextsub = GetSubMenu(hfceuxcontext, whichContext);
				UpdateContextMenuItems(hfceuxcontextsub, whichContext);
				pt.x = LOWORD(lParam);		//Get mouse x in terms of client area
				pt.y = HIWORD(lParam);		//Get mouse y in terms of client area
				ClientToScreen(hAppWnd, (LPPOINT) &pt);	//Convert client area x,y to screen x,y
				TrackPopupMenu(hfceuxcontextsub,TPM_RIGHTBUTTON,(pt.x),(pt.y),0,hWnd,0);	//Create menu
			} else
			{
				mouseb=wParam;
			}
		}
		goto proco;
	}

	case WM_MOVE: 
	{
		if (!IsIconic(hWnd)) {
		RECT wrect;
		GetWindowRect(hWnd,&wrect);
		MainWindow_wndx = wrect.left;
		MainWindow_wndy = wrect.top;

		#ifdef WIN32
		WindowBoundsCheckNoResize(MainWindow_wndx,MainWindow_wndy,wrect.right);
		#endif
		}
		goto proco;
	}

	case WM_MOUSEMOVE:
	{
		mousex=LOWORD(lParam);
		mousey=HIWORD(lParam);
		goto proco;
	}

	case WM_ERASEBKGND:
		if(xbsave)
			return(0);
		else
			goto proco;

	case WM_PAINT:
		if (xbsave)
		{
			InvalidateRect(hWnd, NULL, false);		// AnS: HACK in order to force the entire client area to be redrawn; this fixes the bug with DIRECTDRAWCLIPPER sometimes calculating wrong region
			PAINTSTRUCT ps;
			BeginPaint(hWnd,&ps);
			FCEUD_BlitScreen(xbsave);
			EndPaint(hWnd,&ps);
			return(0);
		}
		goto proco;

	case WM_SIZE:
		if (!fullscreen && !changerecursive && !windowedfailed)
		{
			switch(wParam)
			{
			case SIZE_MAXIMIZED: 
				ismaximized = 1;
				changerecursive = 1;
				SetMainWindowStuff();
				changerecursive = 0;
				break;
			case SIZE_RESTORED: 
				ismaximized = 0;
				changerecursive = 1;
				SetMainWindowStuff();
				changerecursive = 0;
				break;
			}
		}
		break;
	case WM_SIZING:
		{
			RECT *wrect=(RECT *)lParam;
			RECT srect;

			int h=wrect->bottom-wrect->top;
			int w=wrect->right-wrect->left;
			int how = 0;

			if(wParam == WMSZ_BOTTOM || wParam == WMSZ_TOP)
				how = 2;
			else if(wParam == WMSZ_LEFT || wParam == WMSZ_RIGHT)
				how = 1;
			else if(wParam == WMSZ_BOTTOMLEFT || wParam == WMSZ_BOTTOMRIGHT
				|| wParam == WMSZ_TOPRIGHT || wParam == WMSZ_TOPLEFT)
				how = 3;
			if(how & 1)
				winsizemulx*= (double)w/winwidth;
			if(how & 2)
				winsizemuly*= (double)h/winheight;

			bool shift_held = (GetAsyncKeyState(VK_SHIFT) < 0);
			if(how & 1)
				FixWXY(0, shift_held);
			else
				FixWXY(1, shift_held);

			CalcWindowSize(&srect);
			winwidth=srect.right;
			winheight=srect.bottom;
			wrect->right = wrect->left + srect.right;
			wrect->bottom = wrect->top + srect.bottom;
		
			GetMenuItemRect(hWnd, fceumenu, 0, &file_rect);
			GetMenuItemRect(hWnd, fceumenu, 5, &help_rect);
			menuYoffset = help_rect.top-file_rect.top;
		}
		//sizchange=1;
		//break;
		goto proco;
	case WM_DISPLAYCHANGE:
		if(!fullscreen && !changerecursive)
			vchanged=1;
		goto proco;
	case WM_DROPFILES:
		{
			UINT len;

			len=DragQueryFileW((HDROP)wParam,0,0,0)+1; 
			wchar_t* wftmp = new wchar_t[len];
			{
				DragQueryFileW((HDROP)wParam,0,wftmp,len); 
				std::string fileDropped = wcstombs(wftmp);
				delete[] wftmp;
				//adelikat:  Drag and Drop only checks file extension, the internal functions are responsible for file error checking
				
				//-------------------------------------------------------
				//Check if a cheats (.cht) file
				//-------------------------------------------------------
				if (!(fileDropped.find(".cht") == string::npos) && (fileDropped.find(".cht") == fileDropped.length()-4))
				{
					FILE* file = FCEUD_UTF8fopen(fileDropped.c_str(),"rb");
					FCEU_LoadGameCheats(file);
				}
				
				//-------------------------------------------------------
				//Check if .fcm file, if so, convert it and play the resulting .fm2
				//-------------------------------------------------------
				else if (!(fileDropped.find(".fcm") == string::npos) && (fileDropped.find(".fcm") == fileDropped.length()-4))
				{
					//produce output filename
					std::string outname;
					size_t dot = fileDropped.find_last_of(".");
					if(dot == std::string::npos)
						outname = fileDropped + ".fm2";
					else
						outname = fileDropped.substr(0,dot) + ".fm2";

					MovieData md;
					EFCM_CONVERTRESULT result = convert_fcm(md, fileDropped.c_str());
					if(result==FCM_CONVERTRESULT_SUCCESS)
					{
						EMUFILE* outf = FCEUD_UTF8_fstream(outname, "wb");
						md.dump(outf,false);
						delete outf;
						if (!GameInfo)				//If no game is loaded, load the Open Game dialog
							LoadNewGamey(hWnd, 0);
						FCEUI_LoadMovie(outname.c_str(), 1, false);
						FCEUX_LoadMovieExtras(outname.c_str());
					} else
					{
						std::string msg = "Failure converting " + fileDropped + "\r\n\r\n" + EFCM_CONVERTRESULT_message(result);
						MessageBox(hWnd,msg.c_str(),"Failure converting fcm", 0);
					}
				}

				//-------------------------------------------------------
				//Check if Palette file
				//-------------------------------------------------------
				else if (!(fileDropped.find(".pal") == string::npos) && (fileDropped.find(".pal") == fileDropped.length()-4))
				{
					SetPalette(fileDropped.c_str());	
				}

				//-------------------------------------------------------
				//Check if Movie file
				//-------------------------------------------------------
				else if (!(fileDropped.find(".fm2") == string::npos) && (fileDropped.find(".fm2") == fileDropped.length()-4))	 //ROM is already loaded and .fm2 in filename
				{
					if (!GameInfo)				//If no game is loaded, load the Open Game dialog
						LoadNewGamey(hWnd, 0);
					if (GameInfo && !(fileDropped.find(".fm2") == string::npos))
					{
						//.fm2 is at the end of the filename so that must be the extension		
						FCEUI_LoadMovie(fileDropped.c_str(), 1, false);		 //We are convinced it is a movie file, attempt to load it
						FCEUX_LoadMovieExtras(fileDropped.c_str());
					}
				}
				//-------------------------------------------------------
				//Check if TAS Editor project file
				//-------------------------------------------------------
				else if (!(fileDropped.find(".fm3") == string::npos) && (fileDropped.find(".fm3") == fileDropped.length()-4))	 //ROM is already loaded and .fm3 in filename
				{
					if (!GameInfo)				//If no game is loaded, load the Open Game dialog
						LoadNewGamey(hWnd, 0);
					if (GameInfo && !(fileDropped.find(".fm3") == string::npos))
					{
						//.fm3 is at the end of the filename so that must be the extension
						extern bool enterTASEditor();
						extern bool loadProject(const char* fullname);
						extern bool askToSaveProject();
						if (enterTASEditor())					//We are convinced it is a TAS Editor project file, attempt to load in TAS Editor
							if (askToSaveProject())		// in case there's unsaved project
								loadProject(fileDropped.c_str());
					}
				}
				//-------------------------------------------------------
				//Check if Savestate file
				//-------------------------------------------------------
				else if (!(fileDropped.find(".fc") == string::npos))
				{
					if (fileDropped.find(".fc") == fileDropped.length()-4)	//Check to see it is both at the end (file extension) and there is on more character
					{
						if (fileDropped[fileDropped.length()-1] >= '0' && fileDropped[fileDropped.length()-1] <= '9')	//If last character is 0-9 (making .fc0 - .fc9)
						{
							FCEUI_LoadState(fileDropped.c_str());
						}
					}
				}
				//-------------------------------------------------------
				//Check if Lua file
				//-------------------------------------------------------
#ifdef _S9XLUA_H
				else if (!(fileDropped.find(".lua") == string::npos) && (fileDropped.find(".lua") == fileDropped.length()-4))	
				{
					// HACK because luaL_loadfile doesn't work with multibyte paths
					char *ftmp;
					len = DragQueryFile((HDROP)wParam, 0, 0, 0) + 1; 
					if ((ftmp=(char*)malloc(len))) 
					{
						DragQueryFile((HDROP)wParam, 0, ftmp, len); 
						fileDropped = ftmp;
						free(ftmp);
					}
					FCEU_LoadLuaCode(fileDropped.c_str());
					UpdateLuaConsole(fileDropped.c_str());
				}
#endif
				//-------------------------------------------------------
				//Check if Ram Watch file
				//-------------------------------------------------------
				else if (!(fileDropped.find(".wch") == string::npos) && (fileDropped.find(".wch") == fileDropped.length()-4)) {
					if (GameInfo) {
						SendMessage(hWnd, WM_COMMAND, (WPARAM)ID_RAM_WATCH,(LPARAM)(NULL));
						Load_Watches(true, fileDropped.c_str());
					}
				}
				//-------------------------------------------------------
				//If not a movie, Load it as a ROM file
				//-------------------------------------------------------
				else
				{
					ALoad(fileDropped.c_str());
				}	
			}
		}
		break;

	case WM_COMMAND:

		if(HIWORD(wParam) == 0 || HIWORD(wParam) == 1)
		{
			wParam &= 0xFFFF;

			// A menu item from the recent files menu was clicked.
			if(wParam >= MENU_FIRST_RECENT_FILE && wParam < MENU_FIRST_RECENT_FILE + MAX_NUMBER_OF_RECENT_FILES)
			{
				LoadRecentRom(wParam - MENU_FIRST_RECENT_FILE);
			}
			
			// A menu item for the recent lua files menu was clicked.
			#ifdef _S9XLUA_H
			if(wParam >= LUA_FIRST_RECENT_FILE && wParam < LUA_FIRST_RECENT_FILE + MAX_NUMBER_OF_LUA_RECENT_FILES)
			{
				char*& fname = recent_lua[wParam - LUA_FIRST_RECENT_FILE];
				if(fname)
				{
					UpdateLuaConsole(fname);
					if (!FCEU_LoadLuaCode(fname))
					{
						//int result = MessageBox(hWnd,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
						//if (result == IDYES)
						//{
						//	RemoveRecentItem((wParam - LUA_FIRST_RECENT_FILE), recent_lua, MAX_NUMBER_OF_LUA_RECENT_FILES);
						//	UpdateLuaRMenu(recentluamenu, recent_lua, MENU_LUA_RECENT, LUA_FIRST_RECENT_FILE);
						//}
						//adelikat: Commenting this code out because it is annoying in context lua scripts since lua scripts will frequently give errors to those developing them.  It is frustrating for this to pop up every time.
					}
				}
			}
			#endif

			// A menu item for the recent movie files menu was clicked.
			if(wParam >= MOVIE_FIRST_RECENT_FILE && wParam < MOVIE_FIRST_RECENT_FILE + MAX_NUMBER_OF_MOVIE_RECENT_FILES)
			{
				char*& fname = recent_movie[wParam - MOVIE_FIRST_RECENT_FILE];
				if(fname)
				{
					if (!FCEUI_LoadMovie(fname, 1, false))
					{
						int result = MessageBox(hWnd,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
						if (result == IDYES)
						{
							RemoveRecentItem((wParam - MOVIE_FIRST_RECENT_FILE), recent_movie, MAX_NUMBER_OF_MOVIE_RECENT_FILES);
							UpdateMovieRMenu(recentmoviemenu, recent_movie, MENU_MOVIE_RECENT, MOVIE_FIRST_RECENT_FILE);
						}
					} else {
						FCEUX_LoadMovieExtras(fname);
					}
				}
			}

			switch(LOWORD(wParam))
			{
			//File Menu-------------------------------------------------------------
			case FCEU_CONTEXT_OPENROM:
			case MENU_OPEN_FILE:
				LoadNewGamey(hWnd, 0);
				break;
			case FCEU_CONTEXT_CLOSEROM:
			case MENU_CLOSE_FILE:
				CloseGame();
				break;
			//Savestate Submenu
			case MENU_SAVESTATE:	//Save State
				FCEUI_SaveState(0);
				break;
			case MENU_LOADSTATE:	//Load State
				FCEUI_LoadState(0);
				break;
			case MENU_SAVE_STATE:	//Save state as
				FCEUD_SaveStateAs();
				break;
			case MENU_LOAD_STATE:	//Load state as
				FCEUD_LoadStateFrom();
				break;
			case MENU_NEXTSAVESTATE:	//Next Save slot
				FCEUI_SelectStateNext(1);
				break;
			case MENU_PREVIOUSSAVESTATE: //Previous Save slot
				FCEUI_SelectStateNext(-1);
				break;
			case MENU_VIEWSAVESLOTS:	//View save slots
				FCEUI_SelectState(CurrentState, 1);
				break;

			//Movie submenu
			case FCEUX_CONTEXT_RECORDMOVIE:
			case MENU_RECORD_MOVIE:
				FCEUD_MovieRecordTo();
				break;
			case FCEUX_CONTEXT_REPLAYMOVIE:
			case MENU_REPLAY_MOVIE:
				// Replay movie menu was selected
				FCEUD_MovieReplayFrom();
				break;
			case FCEU_CONTEXT_STOPMOVIE:
			case MENU_STOP_MOVIE:
				FCEUI_StopMovie();
				break;
			case FCEU_CONTEXT_PLAYMOVIEFROMBEGINNING:
			case ID_FILE_PLAYMOVIEFROMBEGINNING:
				FCEUI_MoviePlayFromBeginning();
				break;
			case FCEUX_CONTEXT_READONLYTOGGLE:
			case ID_FILE_MOVIE_TOGGLEREAD:
				FCEUI_MovieToggleReadOnly();
				break;

			//Record Avi/Wav submenu
			case MENU_RECORD_AVI:
				FCEUD_AviRecordTo();
				break;
			case MENU_STOP_AVI:
				FCEUD_AviStop();
				break;
			case MENU_RECORD_WAV: 
				loggingSound = CreateSoundSave();
				break;
			case MENU_STOP_WAV: 
				CloseWave();
				loggingSound = false;
				break;
			case ID_AVI_ENABLEHUDRECORDING:
			{
				bool AVIenableHUDrecording = FCEUI_AviEnableHUDrecording();
				AVIenableHUDrecording ^= 1;
				FCEUI_SetAviEnableHUDrecording(AVIenableHUDrecording);
				break;
			}
			case ID_AVI_DISMOVIEMESSAGE:
			{
				bool AVIdisableMovieMessages = FCEUI_AviDisableMovieMessages();
				AVIdisableMovieMessages ^= 1;
				FCEUI_SetAviDisableMovieMessages(AVIdisableMovieMessages);
				break;
			}
			case FCEUX_CONTEXT_SCREENSHOT:
			case ID_FILE_SCREENSHOT:
				FCEUI_SaveSnapshot(); 
				break;
			case ID_FILE_SAVESCREENSHOTAS:
				SaveSnapshotAs();
				break;

			//Lua submenu
			case ID_FILE_OPENLUAWINDOW:
				if (!LuaConsoleHWnd)
				{
					LuaConsoleHWnd = CreateDialog(fceu_hInstance, MAKEINTRESOURCE(IDD_LUA), hWnd, (DLGPROC) DlgLuaScriptDialog);
				} else
				{
					ShowWindow(LuaConsoleHWnd, SW_SHOWNORMAL);
					SetForegroundWindow(LuaConsoleHWnd);
				}
				break;
			case FCEUX_CONTEXT_CLOSELUAWINDOWS:
			case ID_FILE_CLOSELUAWINDOWS:
				if(LuaConsoleHWnd)
					PostMessage(LuaConsoleHWnd, WM_CLOSE, 0, 0);
				break;
			//Recent Lua 1
			#ifdef _S9XLUA_H
			case FCEUX_CONTEXT_LOADLASTLUA:
				ShowWindow(LuaConsoleHWnd, SW_SHOWNORMAL);
				SetForegroundWindow(LuaConsoleHWnd);
				if(recent_lua[0])
				{
					if (!FCEU_LoadLuaCode(recent_lua[0]))
					{
						//int result = MessageBox(hWnd,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
						//if (result == IDYES)
						//{
						//	RemoveRecentItem(0, recent_lua, MAX_NUMBER_OF_LUA_RECENT_FILES);
						//	UpdateLuaRMenu(recentluamenu, recent_lua, MENU_LUA_RECENT, LUA_FIRST_RECENT_FILE);
						//}
						//adelikat: Forgot to comment this out for 2.1.2 release.  FCEUX shouldn't ask in this case because it is too likely that lua script will error many times for a user developing a lua script.
					}
				}
				break;
			#endif

			case MENU_EXIT:
				DoFCEUExit();
				break;

			//NES Menu--------------------------------------------------------------
			case MENU_RESET:
				FCEUI_ResetNES();
				break;
			case MENU_POWER:
				FCEUI_PowerNES();
				break;
			case MENU_EJECT_DISK:
				FCEUI_FDSInsert();
				break;
			case MENU_SWITCH_DISK:
				FCEUI_FDSSelect();
				break;
			case MENU_INSERT_COIN:
				FCEUI_VSUniCoin();
				break;
			
			//Emulation submenu
			case ID_NES_PAUSE:
				FCEUI_ToggleEmulationPause();
				UpdateCheckedMenuItems();
				break;
			case ID_NES_TURBO:
				FCEUD_TurboToggle();
				break;

			//Emulation speed submenu
			case ID_NES_SPEEDUP:
				FCEUD_SetEmulationSpeed(3);
				break;
			case ID_NES_SLOWDOWN:
				FCEUD_SetEmulationSpeed(1);
				break;
			case ID_NES_SLOWESTSPEED:
				FCEUD_SetEmulationSpeed(0);
				break;
			case ID_NES_NORMALSPEED:
				FCEUD_SetEmulationSpeed(2);
				break;
			case ID_EMULATIONSPEED_CUSTOMSPEED:
			{
				int new_value = fps_scale / 2.56;
				if ((CWin32InputBox::GetInteger("Emulation Speed", "Enter a number of percents from 1 to 1000.", new_value, hWnd) == IDOK))
				{
					fps_scale_unpaused = new_value * 2.56 + 1;
					if (fps_scale_unpaused / 2.56 > 1000 || fps_scale_unpaused <= 0)
						fps_scale_unpaused = 256;
					fps_scale = fps_scale_unpaused;
					RefreshThrottleFPS();
					FCEU_DispMessage("Emulation speed %d%%", 0, (fps_scale_unpaused * 100) >> 8);
				}
				break;
			}

			case ID_EMULATIONSPEED_SETFRAMEADVANCEDELAY:
			{
				extern int frameAdvance_Delay;
				int new_value = frameAdvance_Delay;
				if((CWin32InputBox::GetInteger("FrameAdvance Delay", "How much time should elapse before\nholding the Frame Advance\nunpauses emulation?", new_value, hWnd) == IDOK))
				{
					if (new_value < 0)
						new_value = FRAMEADVANCE_DELAY_DEFAULT;
					frameAdvance_Delay = new_value;
				}
				break;
			}
			case ID_EMULATIONSPEED_SETCUSTOMSPEEDFORFRAMEADVANCE:
			{
				extern int32 fps_scale_frameadvance;
				int new_value = fps_scale_frameadvance / 2.56;
				if ((CWin32InputBox::GetInteger("FrameAdvance Custom Speed", "Enter 0 to use the current emulation speed when\nthe Frame Advance is held. Or enter the number\nof percents (1-1000) to use different speed.", new_value, hWnd) == IDOK))
				{
					if (new_value > 1000)
						new_value = 1000;
					if (new_value > 0)
					{
						fps_scale_frameadvance = new_value * 2.56 + 1;
					} else
					{
						fps_scale_frameadvance = 0;
						fps_scale = fps_scale_unpaused;
						RefreshThrottleFPS();
					}
				}
				break;
			}

			//Config Menu-----------------------------------------------------------
			case FCEUX_CONTEXT_UNHIDEMENU:
			case MENU_HIDE_MENU:
				ToggleHideMenu();
				break;
			case MENU_RUN_IN_BACKGROUND:
				eoptions ^= EO_BGRUN;
				if((eoptions & EO_BGRUN) == 0)
				{
					EnableBackgroundInput = 0;
					KeyboardSetBackgroundAccess(EnableBackgroundInput!=0);
					JoystickSetBackgroundAccess(EnableBackgroundInput!=0);
				}
				UpdateCheckedMenuItems();
				break;
			case MENU_BACKGROUND_INPUT:
				EnableBackgroundInput ^= 1;
				eoptions |= EO_BGRUN * EnableBackgroundInput;
				KeyboardSetBackgroundAccess(EnableBackgroundInput!=0);
				JoystickSetBackgroundAccess(EnableBackgroundInput!=0);
				UpdateCheckedMenuItems();
				break;
			case MENU_ENABLE_AUTOSAVE:
				EnableAutosave ^= 1;
				UpdateCheckedMenuItems();
				break;
			case MENU_DISPLAY_FA_LAGSKIP:
				frameAdvanceLagSkip ^= 1;
				UpdateCheckedMenuItems();
				break;
			case ID_ENABLE_BACKUPSAVESTATES:
				backupSavestates ^=1;
				UpdateCheckedMenuItems();
				break;
			case ID_ENABLE_COMPRESSSAVESTATES:
				compressSavestates ^=1;
				UpdateCheckedMenuItems();
				break;
			case ID_ENABLE_AUTORESUME:
				AutoResumePlay ^=1;
				UpdateCheckedMenuItems();
				break;

			//Display submenu
			case MENU_INPUTDISPLAY_0: //Input display off
				input_display = 0;
				UpdateCheckedMenuItems();
				break;
			case MENU_INPUTDISPLAY_1: //Input display - 1 player
				input_display = 1;
				UpdateCheckedMenuItems();
				break;
			case MENU_INPUTDISPLAY_2: //Input display - 2 player
				input_display = 2;
				UpdateCheckedMenuItems();
				break;
			case MENU_INPUTDISPLAY_4: //Input display - 4 player
				input_display = 4;
				UpdateCheckedMenuItems();
				break;
			case ID_INPUTDISPLAY_OLDSTYLEDISP:
				oldInputDisplay ^= 1;
				UpdateCheckedMenuItems();
				break;
			case MENU_DISPLAY_LAGCOUNTER:
				LagCounterToggle();
				UpdateCheckedMenuItems();
				break;
			case ID_DISPLAY_FRAMECOUNTER:
				FCEUI_MovieToggleFrameDisplay();
				UpdateCheckedMenuItems();
				break;
			case ID_DISPLAY_RERECORDCOUNTER:
				FCEUI_MovieToggleRerecordDisplay();
				UpdateCheckedMenuItems();
				break;
			case ID_DISPLAY_MOVIESTATUSICON:
				FCEUD_ToggleStatusIcon();
				break;
			case ID_DISPLAY_FPS:
				FCEUI_ToggleShowFPS();
				break;
			case MENU_DISPLAY_BG:
			case MENU_DISPLAY_OBJ:
				{
					bool spr, bg;
					FCEUI_GetRenderPlanes(spr,bg);
					if(LOWORD(wParam)==MENU_DISPLAY_BG)
						bg = !bg;
					else
						spr = !spr;
					FCEUI_SetRenderPlanes(spr,bg);
				}
				break;

			case ID_NEWPPU:
			case ID_OLDPPU:
				FCEU_TogglePPU();
				break;
			case MENU_GAME_GENIE:
				genie ^= 1;
				FCEUI_SetGameGenie(genie!=0);
				UpdateCheckedMenuItems();
				break;
			case MENU_NTSC:
				FCEUI_SetRegion(0);
				break;
			case MENU_PAL:
				FCEUI_SetRegion(1);
				break;
			case MENU_DENDY:
				FCEUI_SetRegion(2);
				break;
			case MENU_DIRECTORIES:
				ConfigDirectories();
				break;
			case MENU_GUI_OPTIONS:
				ConfigGUI();
				break;
			case MENU_INPUT:
				ConfigInput(hWnd);
				break;
			case MENU_NETWORK:
				ShowNetplayConsole();
				break;
			case MENU_PALETTE:
				ConfigPalette();
				break;
			case MENU_SOUND:
				ConfigSound();
				break;
			case MENU_TIMING:
				ConfigTiming();
				break;
			case MENU_VIDEO:
				ConfigVideo();
				break;
			case MENU_HOTKEYS:
				MapInput();
				break;
			case MENU_MOVIEOPTIONS:
				OpenMovieOptions();
				break;

			case ID_CONFIG_SAVECONFIGFILE:
				{
					extern string cfgFile;
					sprintf(TempArray, "%s/%s", BaseDirectory.c_str(),cfgFile.c_str());
					SaveConfig(TempArray);
					break;
				}

			//Tools Menu---------------------------------------------------------------
			case MENU_CHEATS:
				ConfigCheats(hWnd);
				break;
			case MENU_MEMORY_WATCH:
				CreateMemWatch();
				break;
			
			case ID_RAM_SEARCH:
				if(!RamSearchHWnd)
				{
					OpenRamSearch();
				} else
				{
					ShowWindow(RamSearchHWnd, SW_SHOWNORMAL);
					SetForegroundWindow(RamSearchHWnd);
				}
				break;

			case ID_RAM_WATCH:
				if(!RamWatchHWnd)
				{
					OpenRamWatch();
				}
				else
					SetForegroundWindow(RamWatchHWnd);
				break;	
			//case MENU_RAMFILTER:
			//	DoByteMonitor(); 
			//	break;
			//  Removing this tool since it is redundant to both 
			case MENU_TASEDITOR:
				extern bool enterTASEditor();
				enterTASEditor();
				break;
			case MENU_CONVERT_MOVIE:
				ConvertFCM(hWnd);
				break;

			//AutoFire Pattern submenu
			case MENU_AUTOFIRE_PATTERN_1:
				SetAutoFirePattern(1,1);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_2:
				SetAutoFirePattern(1,2);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_3:
				SetAutoFirePattern(1,3);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_4:
				SetAutoFirePattern(1,4);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_5:
				SetAutoFirePattern(1,5);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_6:
				SetAutoFirePattern(2,1);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_7:
				SetAutoFirePattern(2,2);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_8:
				SetAutoFirePattern(2,3);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_9:
				SetAutoFirePattern(2,4);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_10:
				SetAutoFirePattern(3,1);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_11:
				SetAutoFirePattern(3,2);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_12:
				SetAutoFirePattern(3,3);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_13:
				SetAutoFirePattern(4,1);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_14:
				SetAutoFirePattern(4,2);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_AUTOFIRE_PATTERN_15:
				SetAutoFirePattern(5,1);
				CheckedAutoFirePattern = wParam;
				UpdateCheckedMenuItems();
				break;
			//Autofire Offset submenu
			case MENU_AUTOFIRE_OFFSET_1:
			case MENU_AUTOFIRE_OFFSET_2:
			case MENU_AUTOFIRE_OFFSET_3:
			case MENU_AUTOFIRE_OFFSET_4:
			case MENU_AUTOFIRE_OFFSET_5:
			case MENU_AUTOFIRE_OFFSET_6:
				SetAutoFireOffset(wParam - MENU_AUTOFIRE_OFFSET_1);
				CheckedAutoFireOffset = wParam;
				UpdateCheckedMenuItems();
				break;
			case MENU_ALTERNATE_AB:
				SetAutoFireDesynch(GetAutoFireDesynch()^1);
				UpdateCheckedMenuItems();
				break;
			case ID_TOOLS_TEXTHOOKER:
				DoTextHooker();
				break;

			//Debug Menu-------------------------------------------------------------
			case MENU_DEBUGGER:
				DoDebug(0);
				break;
			case MENU_PPUVIEWER:
				DoPPUView();
				break;
			case MENU_NAMETABLEVIEWER:
				DoNTView();
				break;
			case MENU_HEXEDITOR:
				DoMemView();
				break;
			case MENU_TRACELOGGER:
				DoTracer();
				break;
			case MENU_CDLOGGER:
				DoCDLogger();
				break;
			case MENU_GAMEGENIEDECODER:
				DoGGConv();
				break;

			//Help Menu--------------------------------------------------------------
			case MENU_HELP:
				OpenHelpWindow();
				break;
			case MENU_MSGLOG:
				MakeLogWindow();
				break;
			case MENU_ABOUT:
				ShowAboutBox();
				break;
			
			//Context Menus------------------------------------------------------
			
			//Recent ROM 1
			case FCEUX_CONTEXT_RECENTROM1:
				if(recent_files[0])
				{
				if (!ALoad(recent_files[0]))
					{
						int result = MessageBox(hWnd,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
						if (result == IDYES)
						{
							RemoveRecentItem(0, recent_files, MAX_NUMBER_OF_RECENT_FILES);
							UpdateRMenu(recentmenu, recent_files, MENU_RECENT_FILES, MENU_FIRST_RECENT_FILE);
						}
					}
				}
				break;

			//Recent Movie 1
			case FCEUX_CONTEXT_LOADLASTMOVIE:
				if(recent_movie[0])
				{
					if (!FCEUI_LoadMovie(recent_movie[0], 1, false))
					{
						int result = MessageBox(hWnd,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
						if (result == IDYES)
						{
							RemoveRecentItem(0, recent_movie, MAX_NUMBER_OF_MOVIE_RECENT_FILES);
							UpdateMovieRMenu(recentmoviemenu, recent_movie, MENU_MOVIE_RECENT, MOVIE_FIRST_RECENT_FILE);
						}
					} else
					{
						FCEUX_LoadMovieExtras(recent_movie[0]);
					}
				}
				break;

			//Toggle subtitles
			case FCEUX_CONTEXT_TOGGLESUBTITLES:
				movieSubtitles ^= 1;
				break;

			case FCEUX_CONTEXT_DUMPSUBTITLES:
				DumpSubtitles(hWnd);
				break;

			//View comments and subtitles
			case FCEUX_CONTEXT_VIEWCOMMENTSSUBTITLES:
				CreateDialog(fceu_hInstance, "IDD_REPLAY_METADATA", hWnd, ReplayMetadataDialogProc);
				break;

			//Undo Savestate
			case FCEUX_CONTEXT_UNDOSAVESTATE:
				if (undoSS || redoSS)
					SwapSaveState();
				break;

			//Undo Loadstate
			case FCEUX_CONTEXT_UNDOLOADSTATE:
				if (CheckBackupSaveStateExist() && redoLS)
					RedoLoadState();
				else if (CheckBackupSaveStateExist() && undoLS)
					LoadBackup();
				break;

			//Load last auto-save
			case FCEUX_CONTEXT_REWINDTOLASTAUTO:
				FCEUI_RewindToLastAutosave();
				break;

			//Create a backup movie file
			case FCEUX_CONTEXT_MAKEBACKUP:
				FCEUI_MakeBackupMovie(true);
				break;

			//Create a backup based on user entering a filename
			case FCEUX_CONTEXT_SAVEMOVIEAS:
				SaveMovieAs();
				break;

			//Game + Movie - Help
			case FCEU_CONTEXT_MOVIEHELP:
				OpenHelpWindow(moviehelp);
				break;

			case ID_CONTEXT_FULLSAVESTATES:
				fullSaveStateLoads ^= 1;
				break;
			
			//No Game - Help
			case FCEU_CONTEXT_FCEUHELP:
				OpenHelpWindow(gettingstartedhelp);
				break;

            case FCEUX_CONTEXT_GUICONFIG:
                ConfigGUI();
                break;
			}
		}
		break;

	case WM_SYSCOMMAND:
		if(GameInfo && wParam == SC_SCREENSAVE && (goptions & GOO_DISABLESS))
			return(0);

		//adelikat: If we are going to disable screensave, we should disable monitor off as well
		if(GameInfo && wParam == SC_MONITORPOWER && (goptions & GOO_DISABLESS))
			return(0);

		if(wParam==SC_KEYMENU)
		{
			if(GameInfo && ((InputType[2]==SIFC_FKB) || (InputType[2]==SIFC_SUBORKB) || (InputType[2]==SIFC_PEC586KB)) && cidisabled)
				break;
			if(lParam == VK_RETURN || fullscreen || tog) break;
		}
		goto proco;
	case WM_SYSKEYDOWN:
		if(GameInfo && ((InputType[2]==SIFC_FKB) || (InputType[2]==SIFC_SUBORKB) || (InputType[2]==SIFC_PEC586KB)) && cidisabled)
			break; // Hopefully this won't break DInput...

		if(fullscreen || tog)
		{
			if(wParam==VK_MENU)
				break;
		}

        if(wParam==VK_F10)
            break;			// 11.12.08 CH4 Disable F10 as System Key dammit
/*
		if(wParam == VK_RETURN)
		{
			if(!(lParam&(1<<30)))
			{
				UpdateCheckedMenuItems();
				changerecursive=1;
				if(!SetVideoMode(fullscreen^1))
					SetVideoMode(fullscreen);
				changerecursive=0;
			}
			break;
		}
adelikat: Outsourced this to a remappable hotkey
*/
		goto proco;

	case WM_KEYDOWN:
		if(GameInfo)
		{
			//Only disable command keys if a game is loaded(and the other conditions are right, of course).
			if((InputType[2]==SIFC_FKB) || (InputType[2]==SIFC_SUBORKB) || (InputType[2]==SIFC_PEC586KB))
			{
				if(wParam==VK_SCROLL)
				{
					cidisabled^=1;
					FCEUI_DispMessage("%s Keyboard %sabled.",0,InputType[2]==SIFC_FKB?"Family":(InputType[2]==SIFC_SUBORKB?"Subor":"PEC586"),cidisabled?"en":"dis");
				}
				if(cidisabled)
					break; // Hopefully this won't break DInput...
			}
		}
		goto proco;

	case WM_CLOSE:
	case WM_DESTROY:
	case WM_QUIT:
		DoFCEUExit();
		break;
	case WM_SETFOCUS:
		if (wasPausedByCheats)
		{
			EmulationPaused = 0;
			wasPausedByCheats = false;
		}
		break;
	case WM_ACTIVATEAPP:
		if((BOOL)wParam)
			nofocus = 0;
		else
			nofocus = 1;
		goto proco;
	case WM_ENTERMENULOOP:
		UpdateCheckedMenuItems();
		UpdateMenuHotkeys();
		EnableMenuItem(fceumenu,MENU_RESET,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_RESET)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_POWER,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_POWER)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_EJECT_DISK,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_EJECT_DISK)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_SWITCH_DISK,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_SWITCH_DISK)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_INSERT_COIN,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_INSERT_COIN)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_TASEDITOR,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_TASEDITOR)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_CLOSE_FILE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_CLOSEGAME) && GameInfo ?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_RECENT_FILES,MF_BYCOMMAND | ((FCEU_IsValidUI(FCEUI_OPENGAME) && HasRecentFiles()) ?MF_ENABLED:MF_GRAYED)); //adelikat - added && recent_files, otherwise this line prevents recent from ever being gray when TAS Editor is not engaged
		EnableMenuItem(fceumenu,MENU_OPEN_FILE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_OPENGAME)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_RECORD_MOVIE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_RECORDMOVIE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_REPLAY_MOVIE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_PLAYMOVIE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_MOVIE_RECENT,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_PLAYMOVIE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_STOP_MOVIE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_STOPMOVIE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,ID_FILE_PLAYMOVIEFROMBEGINNING,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_PLAYFROMBEGINNING)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_SAVESTATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_QUICKSAVE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_LOADSTATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_QUICKLOAD)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_SAVE_STATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_SAVESTATE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_LOAD_STATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_LOADSTATE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_NEXTSAVESTATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_NEXTSAVESTATE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_PREVIOUSSAVESTATE,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_PREVIOUSSAVESTATE)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_VIEWSAVESLOTS,MF_BYCOMMAND | (FCEU_IsValidUI(FCEUI_VIEWSLOTS)?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_STOP_AVI,MF_BYCOMMAND | (FCEUI_AviIsRecording()?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,MENU_STOP_WAV,MF_BYCOMMAND | (loggingSound?MF_ENABLED:MF_GRAYED));
		EnableMenuItem(fceumenu,ID_FILE_CLOSELUAWINDOWS,MF_BYCOMMAND | (LuaConsoleHWnd?MF_ENABLED:MF_GRAYED));
		// PAL and PPU should not be changed while a movie is recorded/played
		if (FCEUMOV_Mode(MOVIEMODE_INACTIVE))
		{
			EnableMenuItem(fceumenu, MENU_PAL, MF_ENABLED);
			EnableMenuItem(fceumenu, ID_NEWPPU, MF_ENABLED);
			EnableMenuItem(fceumenu, ID_OLDPPU, MF_ENABLED);
		} else
		{
			EnableMenuItem(fceumenu, MENU_PAL, MF_GRAYED);
			EnableMenuItem(fceumenu, ID_NEWPPU, MF_GRAYED);
			EnableMenuItem(fceumenu, ID_OLDPPU, MF_GRAYED);
		}
		CheckMenuRadioItem(fceumenu, ID_NEWPPU, ID_OLDPPU, newppu ? ID_NEWPPU : ID_OLDPPU, MF_BYCOMMAND);
		// when TASEditor is engaged, some settings should not be changeable
		if (FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		{
			EnableMenuItem(fceumenu, MENU_ENABLE_AUTOSAVE, MF_GRAYED);
			EnableMenuItem(fceumenu, ID_ENABLE_BACKUPSAVESTATES, MF_GRAYED);
			EnableMenuItem(fceumenu, ID_ENABLE_COMPRESSSAVESTATES, MF_GRAYED);
		} else
		{
			EnableMenuItem(fceumenu, MENU_ENABLE_AUTOSAVE, MF_ENABLED);
			EnableMenuItem(fceumenu, ID_ENABLE_BACKUPSAVESTATES, MF_ENABLED);
			EnableMenuItem(fceumenu, ID_ENABLE_COMPRESSSAVESTATES, MF_ENABLED);
		}

	default:
proco:
		return DefWindowProc(hWnd,msg,wParam,lParam);
	}
	return 0;
}

void FixWXY(int pref, bool shift_held)
{
	if (eoptions & EO_FORCEASPECT)
	{
		if (pref == 0)
			winsizemuly = winsizemulx;
		else
			winsizemulx = winsizemuly;
	}
	if (winsizemulx < 0.1)
		winsizemulx = 0.1;
	if (winsizemuly < 0.1)
		winsizemuly = 0.1;

	// round to integer values
	if (((eoptions & EO_FORCEISCALE) && !shift_held) || (!(eoptions & EO_FORCEISCALE) && shift_held))
	{
		int x,y;

		x = winsizemulx * 2;
		y = winsizemuly * 2;

		x = (x>>1) + (x&1);
		y = (y>>1) + (y&1);

		if(!x) x=1;
		if(!y) y=1;

		winsizemulx = x;
		winsizemuly = y;    
	}

	/*
	// is this really necessary?
	if (winsizemulx > 100)
		winsizemulx = 100;
	if (winsizemuly > 100)
		winsizemuly = 100;
	*/
}

void UpdateFCEUWindow(void)
{
	if(vchanged && !fullscreen && !changerecursive && !nofocus)
	{
		SetVideoMode(0);
		vchanged = 0;
	}

	BlockingCheck();

	if(!(eoptions & EO_BGRUN))
	{
		while(nofocus)
		{

			Sleep(75);
			BlockingCheck();
		}
	}
}


//Destroys the main window
void ByebyeWindow()
{
	SetMenu(hAppWnd, 0);
	DestroyMenu(fceumenu);
	DestroyWindow(hAppWnd);
}

/// reates the main window.
/// @return Flag that indicates failure (0) or success (1)
int CreateMainWindow()
{
	WNDCLASSEX winclass;
	RECT tmp;

	// Create and register the window class

	memset(&winclass, 0, sizeof(winclass));
	winclass.cbSize = sizeof(WNDCLASSEX);
	winclass.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;	// AnS: removed CS_SAVEBITS
	winclass.lpfnWndProc = AppWndProc;
	winclass.cbClsExtra = 0;
	winclass.cbWndExtra = 0;
	winclass.hInstance = fceu_hInstance;
	winclass.hIcon = LoadIcon(fceu_hInstance, "ICON_1");
	winclass.hIconSm = LoadIcon(fceu_hInstance, "ICON_1");
	winclass.hCursor = LoadCursor(NULL, IDC_ARROW);
	winclass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH); //mbg merge 7/17/06 added cast
	winclass.lpszClassName = "FCEUXWindowClass";

	if(!RegisterClassEx(&winclass))
	{
		return FALSE;
	}

	AdjustWindowRectEx(&tmp, WS_OVERLAPPEDWINDOW, 1, 0);

	fceumenu = LoadMenu(fceu_hInstance,"FCEUMENU");

	recentmenu = CreateMenu();
	recentluamenu = CreateMenu();
	recentmoviemenu = CreateMenu();

	// Update recent files menu
	UpdateRMenu(recentmenu, recent_files, MENU_RECENT_FILES, MENU_FIRST_RECENT_FILE);
	UpdateLuaRMenu(recentluamenu, recent_lua, MENU_LUA_RECENT, LUA_FIRST_RECENT_FILE);
	UpdateMovieRMenu(recentmoviemenu, recent_movie, MENU_MOVIE_RECENT, MOVIE_FIRST_RECENT_FILE);

	updateGameDependentMenus(0);
	updateGameDependentMenusDebugger(0);
	if (MainWindow_wndx==-32000) MainWindow_wndx=0; //Just in case
	if (MainWindow_wndy==-32000) MainWindow_wndy=0;
	hAppWnd = CreateWindowEx(
		0,
		"FCEUXWindowClass",
		FCEU_NAME_AND_VERSION,
		WS_OVERLAPPEDWINDOW | WS_CLIPSIBLINGS,  /* Style */
		MainWindow_wndx,
		MainWindow_wndy,
		256,
		FSettings.TotalScanlines(),  /* X,Y ; Width, Height */
		NULL,
		fceumenu,
		fceu_hInstance,
		NULL );  

	//CenterWindowOnScreen(hAppWnd);
	DragAcceptFiles(hAppWnd, 1);

	SetMainWindowStuff();

	return 1;
}

void SetMainWindowStuff()
{
	RECT tmp;

	GetWindowRect(hAppWnd, &tmp);

	if (ismaximized)
	{
		winwidth = tmp.right - tmp.left;
		winheight = tmp.bottom - tmp.top;

		ShowWindow(hAppWnd, SW_SHOWMAXIMIZED);
	} else
	{
		RECT srect;

		if(WindowXC != ( 1 << 30 ))
		{
			/* Subtracting and adding for if(eoptions&EO_USERFORCE) below. */
			tmp.bottom -= tmp.top;
			tmp.bottom += WindowYC;

			tmp.right -= tmp.left;
			tmp.right += WindowXC;


			tmp.left = WindowXC;
			tmp.top = WindowYC;
			WindowXC = 1 << 30;
		}

		CalcWindowSize(&srect);

		SetWindowPos(
			hAppWnd,
			HWND_TOP,
			tmp.left,
			tmp.top,
			srect.right,
			srect.bottom,
			SWP_SHOWWINDOW
			);

		winwidth = srect.right;
		winheight = srect.bottom;

		ShowWindow(hAppWnd, SW_SHOWNORMAL);
	}

	if (eoptions & EO_BESTFIT && !windowedfailed)
	{
		RECT client_recr;
		GetClientRect(hAppWnd, &client_recr);
		recalculateBestFitRect(client_recr.right - client_recr.left, client_recr.bottom - client_recr.top);
	}
}

/// @return Flag that indicates failure (0) or success (1).
int GetClientAbsRect(LPRECT lpRect)
{
	POINT point;
	point.x = point.y = 0;

	if(!ClientToScreen(hAppWnd, &point))
	{
		return 0;
	}

	lpRect->top = point.y;
	lpRect->left = point.x;

	//if(ismaximized)
	//{
		RECT al;
		GetClientRect(hAppWnd, &al);
		lpRect->right = point.x + al.right;
		lpRect->bottom = point.y + al.bottom;
	//}
	//else
	//{
	//	lpRect->right = point.x + VNSWID * winsizemulx;
	//	lpRect->bottom = point.y + FSettings.TotalScanlines() * winsizemuly;
	//}
	return 1;
}

//Shows an Open File menu and starts recording an AVI
void FCEUD_AviRecordTo(void)
{
	OPENFILENAME ofn;
	char szChoice[MAX_PATH];

	string tempFilename, aviFilename;
		
	std::string aviDirectory = FCEU_GetPath(21);  //21 = FCEUMKF_AVI
	if (aviDirectory.find_last_of("\\") != (aviDirectory.size()-1))
		aviDirectory.append("\\");			//if directory override has no \ then add one

	//if we are playing a movie, construct the filename from the current movie.
	if(FCEUMOV_Mode(MOVIEMODE_PLAY|MOVIEMODE_RECORD)) //adelikat: TOOD: Think about this.  I think MOVIEMODE_FINISHED shouldn't not be included here.  Am I wrong?
	{
		tempFilename = GetMfn();	//get movie filename
		tempFilename.erase(0,1);	//remove dot
	}
	//else construct it from the ROM name.
	else
		tempFilename = mass_replace(GetRomName(), "|", ".").c_str();
	
	aviFilename = aviDirectory + tempFilename;	//concate avi directory and movie filename
				
	strcpy(szChoice, aviFilename.c_str());
	char* dot = strrchr(szChoice,'.');

	if (dot) *dot='\0';
	strcat(szChoice, ".avi");

	// avi record file browser
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hAppWnd;
	ofn.lpstrFilter = "AVI Files (*.avi)\0*.avi\0All Files (*.*)\0*.*\0\0";
	ofn.lpstrFile = szChoice;
	ofn.lpstrDefExt = "avi";
	ofn.lpstrTitle = "Save AVI as";

	ofn.nMaxFile = MAX_PATH;
	ofn.Flags = OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT;

	if(GetSaveFileName(&ofn))
		FCEUI_AviBegin(szChoice);
}

//Stop AVI recording
void FCEUD_AviStop(void)
{
	FCEUI_AviEnd();
}

void FCEUD_CmdOpen(void)
{
	LoadNewGamey(hAppWnd, 0);
}

bool FCEUD_PauseAfterPlayback()
{
	return pauseAfterPlayback!=0;
}

void ChangeContextMenuItemText(int menuitem, string text, HMENU menu)
{
	MENUITEMINFO moo;
	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_TYPE;
	moo.cch = NULL;
	GetMenuItemInfo(menu, menuitem, FALSE, &moo);
	moo.dwTypeData = (LPSTR)text.c_str();
	SetMenuItemInfo(menu, menuitem, FALSE, &moo);
}

void ChangeMenuItemText(int menuitem, string text)
{
	MENUITEMINFO moo;
	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_TYPE;
	moo.cch = NULL;
	GetMenuItemInfo(fceumenu, menuitem, FALSE, &moo);
	moo.dwTypeData = (LPSTR)text.c_str();
	SetMenuItemInfo(fceumenu, menuitem, FALSE, &moo);
}

void UpdateMenuHotkeys()
{
	//Update all menu items that can be called from a hotkey to include the current hotkey assignment
	string combo, combined;

	//-------------------------------FILE---------------------------------------
	//Open ROM
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_OPENROM]);
	combined = "&Open ROM...\t" + combo;
	ChangeMenuItemText(MENU_OPEN_FILE, combined);

	//Close ROM
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_CLOSEROM]);
	combined = "&Close\t" + combo;
	ChangeMenuItemText(MENU_CLOSE_FILE, combined);

	//Load State
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_LOAD_STATE]);
	combined = "&Load State\t" + combo;
	ChangeMenuItemText(MENU_LOADSTATE, combined);

	//Save State
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SAVE_STATE]);
	combined = "&Save State\t" + combo;
	ChangeMenuItemText(MENU_SAVESTATE, combined);

	//Loadstate from
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_LOAD_STATE_FROM]);
	combined = "Load State &From...\t" + combo;
	ChangeMenuItemText(MENU_LOAD_STATE, combined);

	//Savestate as
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SAVE_STATE_AS]);
	combined = "Save State &As...\t" + combo;
	ChangeMenuItemText(MENU_SAVE_STATE, combined);

	//Next Save Slot
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SAVE_SLOT_NEXT]);
	combined = "&Next save slot\t" + combo;
	ChangeMenuItemText(MENU_NEXTSAVESTATE, combined);

	//Previous Save Slot
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SAVE_SLOT_PREV]);
	combined = "&Previous save slot\t" + combo;
	ChangeMenuItemText(MENU_PREVIOUSSAVESTATE, combined);

	//View Save Slots
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MISC_SHOWSTATES]);
	combined = "&View save slots\t" + combo;
	ChangeMenuItemText(MENU_VIEWSAVESLOTS, combined);

	//Record Movie
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_RECORD_TO]);
	combined = "&Record Movie...\t" + combo;
	ChangeMenuItemText(MENU_RECORD_MOVIE, combined);

	//Play movie
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_REPLAY_FROM]);
	combined = "&Play Movie...\t" + combo;
	ChangeMenuItemText(MENU_REPLAY_MOVIE, combined); 

	//Stop movie
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_STOP]);
	combined = "&Stop Movie\t" + combo;
	ChangeMenuItemText(MENU_STOP_MOVIE, combined); 

	//Play Movie from Beginning
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_PLAY_FROM_BEGINNING]);
	combined = "Play from &Beginning\t" + combo;
	ChangeMenuItemText(ID_FILE_PLAYMOVIEFROMBEGINNING, combined); 

	//Read only
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_READONLY_TOGGLE]);
	combined = "&Read only\t" + combo;
	ChangeMenuItemText(ID_FILE_MOVIE_TOGGLEREAD, combined); 

	//Screenshot
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SCREENSHOT]);
	combined = "&Screenshot\t" + combo;
	ChangeMenuItemText(ID_FILE_SCREENSHOT, combined); 

	//Record AVI
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_AVI_RECORD_AS]);
	combined = "&Record AVI...\t" + combo;
	ChangeMenuItemText(MENU_RECORD_AVI, combined); 

	//Stop AVI
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_AVI_STOP]);
	combined = "&Stop AVI\t" + combo;
	ChangeMenuItemText(MENU_STOP_AVI, combined); 
	
	//-------------------------------NES----------------------------------------
	//Reset
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_RESET]);
	combined = "&Reset\t" + combo;
	ChangeMenuItemText(MENU_RESET, combined); 

	//Power
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_POWER]);
	combined = "&Power\t" + combo;
	ChangeMenuItemText(MENU_POWER, combined);

	//Eject/Insert Disk
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_FDS_EJECT_INSERT]);
	combined = "&Eject/Insert Disk\t" + combo;
	ChangeMenuItemText(MENU_EJECT_DISK, combined);

	//Switch Disk Side
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_FDS_SIDE_SELECT]);
	combined = "&Switch Disk Side\t" + combo;
	ChangeMenuItemText(MENU_SWITCH_DISK, combined);
	
	//Insert Coin
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_VSUNI_COIN]);
	combined = "&Insert Coin\t" + combo;
	ChangeMenuItemText(MENU_INSERT_COIN, combined);
		
	//Speed Up
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SPEED_FASTER]);
	combined = "Speed &Up\t" + combo;
	ChangeMenuItemText(ID_NES_SPEEDUP, combined);

	//Slow Down
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SPEED_SLOWER]);
	combined = "Slow &Down\t" + combo;
	ChangeMenuItemText(ID_NES_SLOWDOWN, combined);

	//Pause
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_PAUSE]);
	combined = "&Pause\t" + combo;
	ChangeMenuItemText(ID_NES_PAUSE, combined);
	
	//Slowest Speed
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SPEED_SLOWEST]);
	combined = "&Slowest Speed\t" + combo;
	ChangeMenuItemText(ID_NES_SLOWESTSPEED, combined);

	//Normal Speed
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SPEED_NORMAL]);
	combined = "&Normal Speed\t" + combo;
	ChangeMenuItemText(ID_NES_NORMALSPEED, combined);

	//Turbo
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_SPEED_TURBO_TOGGLE]);
	combined = "&Turbo\t" + combo;
	ChangeMenuItemText(ID_NES_TURBO, combined);

	//-------------------------------Config-------------------------------------
	//Hide Menu
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_HIDE_MENU_TOGGLE]);
	combined = "&Hide Menu\t" + combo;
	ChangeMenuItemText(MENU_HIDE_MENU, combined);

	//Frame Adv. skip lag
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_FRAMEADV_SKIPLAG]);
	combined = "&Frame Adv. - Skip Lag\t" + combo;
	ChangeMenuItemText(MENU_DISPLAY_FA_LAGSKIP, combined);

	//Lag Counter
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MISC_DISPLAY_LAGCOUNTER_TOGGLE]);
	combined = "&Lag Counter\t" + combo;
	ChangeMenuItemText(MENU_DISPLAY_LAGCOUNTER, combined);

	//Frame Counter
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_FRAME_DISPLAY_TOGGLE]);
	combined = "&Frame Counter\t" + combo;
	ChangeMenuItemText(ID_DISPLAY_FRAMECOUNTER, combined);

	//Rerecord Counter
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_RERECORD_DISPLAY_TOGGLE]);
	combined = "&Rerecord Counter\t" + combo;
	ChangeMenuItemText(ID_DISPLAY_RERECORDCOUNTER, combined);

	//Movie status icon
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MOVIE_ICON_DISPLAY_TOGGLE]);
	combined = "&Movie status icon\t" + combo;
	ChangeMenuItemText(ID_DISPLAY_MOVIESTATUSICON, combined);

	//FPS counter
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_FPS_DISPLAY_TOGGLE]);
	combined = "FPS\t" + combo;
	ChangeMenuItemText(ID_DISPLAY_FPS, combined);

	//Graphics: BG
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MISC_DISPLAY_BG_TOGGLE]);
	combined = "Graphics: &BG\t" + combo;
	ChangeMenuItemText(MENU_DISPLAY_BG, combined);

	//Graphics: OBJ
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MISC_DISPLAY_OBJ_TOGGLE]);
	combined = "Graphics: &OBJ\t" + combo;
	ChangeMenuItemText(MENU_DISPLAY_OBJ, combined);

	//-------------------------------Tools--------------------------------------
	//Open Cheats
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENCHEATS]);
	combined = "&Cheats...\t" + combo;
	ChangeMenuItemText(MENU_CHEATS, combined);

	//Open RAM Search
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENRAMSEARCH]);
	combined = "&RAM Search...\t" + combo;
	ChangeMenuItemText(ID_RAM_SEARCH, combined);

	//Open RAM Watch
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENRAMWATCH]);
	combined = "&RAM Watch...\t" + combo;
	ChangeMenuItemText(ID_RAM_WATCH, combined);

	//Open Memory Watch
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENMEMORYWATCH]);
	combined = "&Memory Watch...\t" + combo;
	ChangeMenuItemText(MENU_MEMORY_WATCH, combined);

	//Open TAS Editor
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_MISC_OPENTASEDITOR]);
	combined = "&TAS Editor...\t" + combo;
	ChangeMenuItemText(MENU_TASEDITOR, combined);

	//-------------------------------Debug--------------------------------------
	//Open Debugger
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENDEBUGGER]);
	combined = "&Debugger...\t" + combo;
	ChangeMenuItemText(MENU_DEBUGGER, combined);

	//Open PPU Viewer
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENPPU]);
	combined = "&PPU Viewer...\t" + combo;
	ChangeMenuItemText(MENU_PPUVIEWER, combined);

	//Open Nametable Viewer 
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENNTVIEW]);
	combined = "&Name table Viewer...\t" + combo;
	ChangeMenuItemText(MENU_NAMETABLEVIEWER, combined);

	//Open Hex editor
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENHEX]);
	combined = "&Hex Editor...\t" + combo;
	ChangeMenuItemText(MENU_HEXEDITOR, combined);

	//Open Trace Logger
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENTRACELOGGER]);
	combined = "&Trace Logger...\t" + combo;
	ChangeMenuItemText(MENU_TRACELOGGER, combined);
	
	//Open Code/Data Logger
	combo = GetKeyComboName(FCEUD_CommandMapping[EMUCMD_TOOL_OPENCDLOGGER]);
	combined = "&Code/Data Logger...\t" + combo;
	ChangeMenuItemText(MENU_CDLOGGER, combined);
}

//This function is for the context menu item Save Movie As...
//It gets a filename from the user then calls CreateMovie()
void SaveMovieAs()
{
	const char filter[]="NES Movie file (*.fm2)\0*.fm2\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	std::string tempName;

	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Save Movie as...";
	ofn.lpstrFilter=filter;
	strcpy(nameo,curMovieFilename);
	ofn.lpstrFile=nameo;
	ofn.lpstrDefExt="fm2";
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hMemView;
	if (GetSaveFileName(&ofn))
	{
		tempName = nameo;

		FCEUI_CreateMovieFile(tempName);
	}
}

void OpenRamSearch()
{
	if (GameInfo)
	{
		reset_address_info();
		RamSearchHWnd = CreateDialog(fceu_hInstance, MAKEINTRESOURCE(IDD_RAMSEARCH), MainhWnd, (DLGPROC) RamSearchProc);
	}
}

void OpenRamWatch()
{
	if (GameInfo)
		RamWatchHWnd = CreateDialog(fceu_hInstance, MAKEINTRESOURCE(IDD_RAMWATCH), MainhWnd, (DLGPROC) RamWatchProc);
}

void SaveSnapshotAs()
{
	const char filter[] = "Snapshot (*.png)\0*.png\0All Files (*.*)\0*.*\0\0";
	char nameo[512];
	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = "Save Snapshot As...";
	ofn.lpstrFilter = filter;
	strcpy(nameo,FCEU_MakeFName(FCEUMKF_SNAP,0,"png").c_str());

	nameo[strlen(nameo)-6] = '\0';

	ofn.lpstrFile = nameo;
	ofn.lpstrDefExt = "fcs";
	std::string initdir = FCEU_GetPath(FCEUMKF_SNAP);
	ofn.lpstrInitialDir = initdir.c_str();
	ofn.nMaxFile = 256;
	ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;
	ofn.lpstrDefExt = "png";
	
	if(GetSaveFileName(&ofn))
		FCEUI_SetSnapshotAsName(nameo);
	FCEUI_SaveSnapshotAs();
}