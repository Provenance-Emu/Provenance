/* ---------------------------------------------------------------------------------
Implementation file of TASEDITOR_WINDOW class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Window - User Interface
[Single instance]

* implements all operations with TAS Editor window: creating, redrawing, resizing, moving, tooltips, clicks
* subclasses all buttons and checkboxes in TAS Editor window GUI in order to disable Spacebar key and process Middle clicks
* processes OS messages and sends signals from user to TAS Editor modules (also implements some minor commands on-site, like Greenzone capacity dialog and such)
* switches off/on emulator's keyboard input when the window loses/gains focus
* on demand: updates the window caption; updates mouse cursor icon
* updates all checkboxes and menu items when some settings change
* stores info about 10 last projects (File->Recent) and updates it when saving/loading files
* stores resources: window caption, help filename, size and other properties of all GUI items
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "../main.h"
#include "../Win32InputBox.h"
#include "../taseditor.h"
#include <htmlhelp.h>
#include "../../input.h"	// for EMUCMD

//compile for windows 2000 target
#if (_WIN32_WINNT < 0x501)
#define LVN_BEGINSCROLL          (LVN_FIRST-80)          
#define LVN_ENDSCROLL            (LVN_FIRST-81)
#endif

extern TASEDITOR_CONFIG taseditorConfig;
extern PLAYBACK playback;
extern GREENZONE greenzone;
extern RECORDER recorder;
extern TASEDITOR_PROJECT project;
extern PIANO_ROLL pianoRoll;
extern SELECTION selection;
extern EDITOR editor;
extern SPLICER splicer;
extern MARKERS_MANAGER markersManager;
extern BOOKMARKS bookmarks;
extern BRANCHES branches;
extern HISTORY history;
extern POPUP_DISPLAY popupDisplay;

extern bool turbo;
extern bool mustCallManualLuaFunction;

extern char* GetKeyComboName(int c);

extern BOOL CALLBACK findNoteWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
extern BOOL CALLBACK aboutWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
extern BOOL CALLBACK savingOptionsWndProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam);

// main window wndproc
BOOL CALLBACK TASEditorWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
// wndprocs for "Marker X" text fields
LRESULT APIENTRY IDC_PLAYBACK_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_SELECTION_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC IDC_PLAYBACK_MARKER_oldWndProc = 0, IDC_SELECTION_MARKER_oldWndProc = 0;
// wndprocs for all buttons and checkboxes
LRESULT APIENTRY IDC_PROGRESS_BUTTON_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_BRANCHES_BUTTON_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_REWIND_FULL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_REWIND_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_PLAYSTOP_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_FORWARD_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_FORWARD_FULL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY CHECK_FOLLOW_CURSOR_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY CHECK_AUTORESTORE_PLAYBACK_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RADIO_ALL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RADIO_1P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RADIO_2P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RADIO_3P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RADIO_4P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_SUPERIMPOSE_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_USEPATTERN_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_PREV_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_FIND_BEST_SIMILAR_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_FIND_NEXT_SIMILAR_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_NEXT_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY CHECK_TURBO_SEEK_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RECORDING_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY TASEDITOR_RUN_MANUAL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY IDC_RUN_AUTO_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
// variables storing old wndprocs
WNDPROC IDC_PROGRESS_BUTTON_oldWndProc = 0,
		IDC_BRANCHES_BUTTON_oldWndProc = 0,
		TASEDITOR_REWIND_FULL_oldWndProc = 0,
		TASEDITOR_REWIND_oldWndProc = 0,
		TASEDITOR_PLAYSTOP_oldWndProc = 0,
		TASEDITOR_FORWARD_oldWndProc = 0,
		TASEDITOR_FORWARD_FULL_oldWndProc = 0,
		CHECK_FOLLOW_CURSOR_oldWndProc = 0,
		CHECK_AUTORESTORE_PLAYBACK_oldWndProc = 0,
		IDC_RADIO_ALL_oldWndProc = 0,
		IDC_RADIO_1P_oldWndProc = 0,
		IDC_RADIO_2P_oldWndProc = 0,
		IDC_RADIO_3P_oldWndProc = 0,
		IDC_RADIO_4P_oldWndProc = 0,
		IDC_SUPERIMPOSE_oldWndProc = 0,
		IDC_USEPATTERN_oldWndProc = 0,
		TASEDITOR_PREV_MARKER_oldWndProc = 0,
		TASEDITOR_FIND_BEST_SIMILAR_MARKER_oldWndProc = 0,
		TASEDITOR_FIND_NEXT_SIMILAR_MARKER_oldWndProc = 0,
		TASEDITOR_NEXT_MARKER_oldWndProc = 0,
		CHECK_TURBO_SEEK_oldWndProc = 0,
		IDC_RECORDING_oldWndProc = 0,
		TASEDITOR_RUN_MANUAL_oldWndProc = 0,
		IDC_RUN_AUTO_oldWndProc = 0;

// Recent Menu
HMENU hRecentProjectsMenu;
char* recentProjectsArray[] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const unsigned int MENU_FIRST_RECENT_PROJECT = 55000;
const unsigned int MAX_NUMBER_OF_RECENT_PROJECTS = sizeof(recentProjectsArray) / sizeof(*recentProjectsArray);
// Patterns Menu
const unsigned int MENU_FIRST_PATTERN = MENU_FIRST_RECENT_PROJECT + MAX_NUMBER_OF_RECENT_PROJECTS;

// resources
char windowCaptioBase[] = "TAS Editor";
char patternsMenuPrefix[] = "Pattern: ";
char taseditorHelpFilename[] = "\\taseditor.chm";
// all items of the window (used for resizing) and their default x,y,w,h
// actual x,y,w,h are calculated at the beginning from screen
// "x < 0" means that the coordinate is counted from the right border of the window (right-aligned)
// "y < 0" means that the coordinate is counted from the lower border of the window (bottom-aligned)
// The items in this array MUST be sorted by the same order as the Window_items_enum!
WindowItemData windowItems[TASEDITOR_WINDOW_TOTAL_ITEMS] = {
	WINDOWITEMS_PIANO_ROLL, IDC_LIST1, 0, 0, -1, -1, "", "", false, 0, 0,
	WINDOWITEMS_PLAYBACK_MARKER, IDC_PLAYBACK_MARKER, 0, 0, 0, 0, "Click here to scroll Piano Roll to Playback cursor (hotkey: tap Shift twice)", "", false, 0, 0,
	WINDOWITEMS_PLAYBACK_MARKER_EDIT, IDC_PLAYBACK_MARKER_EDIT, 0, 0, -1, 0, "Click to edit text", "", false, 0, 0,
	WINDOWITEMS_SELECTION_MARKER, IDC_SELECTION_MARKER, 0, -1, 0, -1, "Click here to scroll Piano Roll to Selection (hotkey: tap Ctrl twice)", "", false, 0, 0,
	WINDOWITEMS_SELECTION_MARKER_EDIT, IDC_SELECTION_MARKER_EDIT, 0, -1, -1, -1, "Click to edit text", "", false, 0, 0,
	WINDOWITEMS_PLAYBACK_BOX, IDC_PLAYBACK_BOX, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_PROGRESS_BUTTON, IDC_PROGRESS_BUTTON, -1, 0, 0, 0, "Click here when you want to abort seeking", "", false, EMUCMD_TASEDITOR_CANCEL_SEEKING, 0,
	WINDOWITEMS_REWIND_FULL, TASEDITOR_REWIND_FULL, -1, 0, 0, 0, "Send Playback to previous Marker (mouse: Shift+Wheel up) (hotkey: Shift+PageUp)", "", false, 0, 0,
	WINDOWITEMS_REWIND, TASEDITOR_REWIND, -1, 0, 0, 0, "Rewind 1 frame (mouse: Right button+Wheel up) (hotkey: Shift+Up)", "", false, EMUCMD_TASEDITOR_REWIND, 0,
	WINDOWITEMS_PAUSE, TASEDITOR_PLAYSTOP, -1, 0, 0, 0, "Pause/Unpause Emulation (mouse: Middle button)", "", false, EMUCMD_PAUSE, 0,
	WINDOWITEMS_FORWARD, TASEDITOR_FORWARD, -1, 0, 0, 0, "Advance 1 frame (mouse: Right button+Wheel down) (hotkey: Shift+Down)", "", false, EMUCMD_FRAME_ADVANCE, 0,
	WINDOWITEMS_FORWARD_FULL, TASEDITOR_FORWARD_FULL, -1, 0, 0, 0, "Send Playback to next Marker (mouse: Shift+Wheel down) (hotkey: Shift+PageDown)", "", false, 0, 0,
	WINDOWITEMS_PROGRESS_BAR, IDC_PROGRESS1, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_FOLLOW_CURSOR, CHECK_FOLLOW_CURSOR, -1, 0, 0, 0, "The Piano Roll will follow Playback cursor movements", "", false, 0, 0,
	WINDOWITEMS_TURBO_SEEK, CHECK_TURBO_SEEK, -1, 0, 0, 0, "Uncheck when you need to watch seeking in slow motion", "", false, 0, 0,
	WINDOWITEMS_AUTORESTORE_PLAYBACK, CHECK_AUTORESTORE_PLAYBACK, -1, 0, 0, 0, "Whenever you change Input above Playback cursor, the cursor returns to where it was before the change", "", false, EMUCMD_TASEDITOR_SWITCH_AUTORESTORING, 0,
	WINDOWITEMS_RECORDER_BOX, IDC_RECORDER_BOX, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_RECORDING, IDC_RECORDING, -1, 0, 0, 0, "Switch Input Recording on/off", "", false, EMUCMD_MOVIE_READONLY_TOGGLE, 0,
	WINDOWITEMS_RECORD_ALL, IDC_RADIO_ALL, -1, 0, 0, 0, "Switch off Multitracking", "", false, 0, 0,
	WINDOWITEMS_RECORD_1P, IDC_RADIO_1P, -1, 0, 0, 0, "Select Joypad 1 as current", "", false, EMUCMD_TASEDITOR_SWITCH_MULTITRACKING, 0,
	WINDOWITEMS_RECORD_2P, IDC_RADIO_2P, -1, 0, 0, 0, "Select Joypad 2 as current", "", false, EMUCMD_TASEDITOR_SWITCH_MULTITRACKING, 0,
	WINDOWITEMS_RECORD_3P, IDC_RADIO_3P, -1, 0, 0, 0, "Select Joypad 3 as current", "", false, EMUCMD_TASEDITOR_SWITCH_MULTITRACKING, 0,
	WINDOWITEMS_RECORD_4P, IDC_RADIO_4P, -1, 0, 0, 0, "Select Joypad 4 as current", "", false, EMUCMD_TASEDITOR_SWITCH_MULTITRACKING, 0,
	WINDOWITEMS_SUPERIMPOSE, IDC_SUPERIMPOSE, -1, 0, 0, 0, "Allows to superimpose old Input with new buttons, instead of overwriting", "", false, 0, 0,
	WINDOWITEMS_USE_PATTERN, IDC_USEPATTERN, -1, 0, 0, 0, "Applies current Autofire Pattern to Input recording", "", false, 0, 0,
	WINDOWITEMS_SPLICER_BOX, IDC_SPLICER_BOX, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_SELECTION_TEXT, IDC_TEXT_SELECTION, -1, 0, 0, 0, "Current size of Selection", "", false, 0, 0,
	WINDOWITEMS_CLIPBOARD_TEXT, IDC_TEXT_CLIPBOARD, -1, 0, 0, 0, "Current size of Input in the Clipboard", "", false, 0, 0,
	WINDOWITEMS_LUA_BOX, IDC_LUA_BOX, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_RUN_MANUAL, TASEDITOR_RUN_MANUAL, -1, 0, 0, 0, "Press the button to execute Lua Manual Function", "", false, EMUCMD_TASEDITOR_RUN_MANUAL_LUA, 0,
	WINDOWITEMS_RUN_AUTO, IDC_RUN_AUTO, -1, 0, 0, 0, "Enable Lua Auto Function (but first it must be registered by Lua script)", "", false, 0, 0,
	WINDOWITEMS_BRANCHES_BUTTON, IDC_BRANCHES_BUTTON, -1, 0, 0, 0, "Click here to switch between Bookmarks List and Branches Tree", "", false, 0, 0,
	WINDOWITEMS_BOOKMARKS_BOX, IDC_BOOKMARKS_BOX, -1, 0, 0, 0, "", "", false, 0, 0,
	WINDOWITEMS_BOOKMARKS_LIST, IDC_BOOKMARKSLIST, -1, 0, 0, 0, "Right click = set Bookmark, Left click = jump to Bookmark or load Branch", "", false, 0, 0,
	WINDOWITEMS_BRANCHES_BITMAP, IDC_BRANCHES_BITMAP, -1, 0, 0, 0, "Right click = set Bookmark, single Left click = jump to Bookmark, double Left click = load Branch", "", false, 0, 0,
	WINDOWITEMS_HISTORY_BOX, IDC_HISTORY_BOX, -1, 0, 0, -1, "", "", false, 0, 0,
	WINDOWITEMS_HISTORY_LIST, IDC_HISTORYLIST, -1, 0, 0, -1, "Click to revert the project back to that time", "", false, 0, 0,
	WINDOWITEMS_PREVIOUS_MARKER, TASEDITOR_PREV_MARKER, -1, -1, 0, -1, "Send Selection to previous Marker (mouse: Ctrl+Wheel up) (hotkey: Ctrl+PageUp)", "", false, 0, 0,
	WINDOWITEMS_SIMILAR, TASEDITOR_FIND_BEST_SIMILAR_MARKER, -1, -1, 0, -1, "Auto-search for Marker Note", "", false, 0, 0,
	WINDOWITEMS_MORE, TASEDITOR_FIND_NEXT_SIMILAR_MARKER, -1, -1, 0, -1, "Continue Auto-search", "", false, 0, 0,
	WINDOWITEMS_NEXT_MARKER, TASEDITOR_NEXT_MARKER, -1, -1, 0, -1, "Send Selection to next Marker (mouse: Ctrl+Wheel up) (hotkey: Ctrl+PageDown)", "", false, 0, 0,
};

TASEDITOR_WINDOW::TASEDITOR_WINDOW()
{
	hwndTASEditor = 0;
	hwndFindNote = 0;
	hTaseditorIcon = 0;
	TASEditorIsInFocus = false;
	isReadyForResizing = false;
	minWidth = 0;
	minHeight = 0;
}

void TASEDITOR_WINDOW::init()
{
	isReadyForResizing = false;
	bool windowIsMaximized = taseditorConfig.windowIsMaximized;
	hTaseditorIcon = (HICON)LoadImage(fceu_hInstance, MAKEINTRESOURCE(IDI_ICON3), IMAGE_ICON, 16, 16, LR_DEFAULTSIZE);
	hwndTASEditor = CreateDialog(fceu_hInstance, "TASEDITOR", hAppWnd, TASEditorWndProc);
	SendMessage(hwndTASEditor, WM_SETICON, ICON_SMALL, (LPARAM)hTaseditorIcon);
	calculateItems();
	// restore position and size from config, also bring the window on top
	SetWindowPos(hwndTASEditor, HWND_TOP, taseditorConfig.savedWindowX, taseditorConfig.savedWindowY, taseditorConfig.savedWindowWidth, taseditorConfig.savedWindowHeight, SWP_NOOWNERZORDER);
	if (windowIsMaximized)
		ShowWindow(hwndTASEditor, SW_SHOWMAXIMIZED);
	// menus and checked items
	hMainMenu = GetMenu(hwndTASEditor);
	updateCheckedItems();
	hPatternsMenu = GetSubMenu(hMainMenu, PATTERNS_MENU_POS);
	// tooltips
	for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
	{
		if (windowItems[i].tooltipTextBase[0])
		{
			windowItems[i].tooltipHWND = CreateWindowEx(NULL, TOOLTIPS_CLASS, NULL,
									  WS_POPUP | TTS_ALWAYSTIP | TTS_BALLOON | TTS_NOANIMATE | TTS_NOFADE,
									  CW_USEDEFAULT, CW_USEDEFAULT,
									  CW_USEDEFAULT, CW_USEDEFAULT,
									  hwndTASEditor, NULL, 
									  fceu_hInstance, NULL);
			if (windowItems[i].tooltipHWND)
			{
				// Associate the tooltip with the tool
				TOOLINFO toolInfo = {0};
				toolInfo.cbSize = sizeof(toolInfo);
				toolInfo.hwnd = hwndTASEditor;
				toolInfo.uId = (UINT_PTR)GetDlgItem(hwndTASEditor, windowItems[i].id);
				if (windowItems[i].isStaticRect)
				{
					// for static text we specify rectangle
					toolInfo.uFlags = TTF_SUBCLASS;
					RECT toolRect;
					GetWindowRect(GetDlgItem(hwndTASEditor, windowItems[i].id), &toolRect);
					POINT pt;
					pt.x = toolRect.left;
					pt.y = toolRect.top;
					ScreenToClient(hwndTASEditor, &pt);
					toolInfo.rect.left = pt.x;
					toolInfo.rect.right = toolInfo.rect.left + (toolRect.right - toolRect.left);
					toolInfo.rect.top = pt.y;
					toolInfo.rect.bottom = toolInfo.rect.top + (toolRect.bottom - toolRect.top);
				} else
				{
					// for other controls we provide hwnd
					toolInfo.uFlags = TTF_IDISHWND | TTF_SUBCLASS;
				}
				// add hotkey mapping if needed
				if (windowItems[i].hotkeyEmuCmd && FCEUD_CommandMapping[windowItems[i].hotkeyEmuCmd])
				{
					windowItems[i].tooltipText[0] = 0;
					strcpy(windowItems[i].tooltipText, windowItems[i].tooltipTextBase);
					strcat(windowItems[i].tooltipText, " (hotkey: ");
					strncat(windowItems[i].tooltipText, GetKeyComboName(FCEUD_CommandMapping[windowItems[i].hotkeyEmuCmd]), TOOLTIP_TEXT_MAX_LEN - strlen(windowItems[i].tooltipText) - 1);
					strncat(windowItems[i].tooltipText, ")", TOOLTIP_TEXT_MAX_LEN - strlen(windowItems[i].tooltipText) - 1);
					toolInfo.lpszText = windowItems[i].tooltipText;
				} else
				{
					toolInfo.lpszText = windowItems[i].tooltipTextBase;
				}
				SendMessage(windowItems[i].tooltipHWND, TTM_ADDTOOL, 0, (LPARAM)&toolInfo);
				SendMessage(windowItems[i].tooltipHWND, TTM_SETDELAYTIME, TTDT_AUTOPOP, TOOLTIPS_AUTOPOP_TIMEOUT);
			}
		}
	}
	updateTooltips();
	// subclass "Marker X" text fields
	IDC_PLAYBACK_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_PLAYBACK_MARKER), GWL_WNDPROC, (LONG)IDC_PLAYBACK_MARKER_WndProc);
	IDC_SELECTION_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_SELECTION_MARKER), GWL_WNDPROC, (LONG)IDC_SELECTION_MARKER_WndProc);
	// subclass all buttons
	IDC_PROGRESS_BUTTON_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_PROGRESS_BUTTON), GWL_WNDPROC, (LONG)IDC_PROGRESS_BUTTON_WndProc);
	IDC_BRANCHES_BUTTON_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_BRANCHES_BUTTON), GWL_WNDPROC, (LONG)IDC_BRANCHES_BUTTON_WndProc);
	TASEDITOR_REWIND_FULL_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_REWIND_FULL), GWL_WNDPROC, (LONG)TASEDITOR_REWIND_FULL_WndProc);
	TASEDITOR_REWIND_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_REWIND), GWL_WNDPROC, (LONG)TASEDITOR_REWIND_WndProc);
	TASEDITOR_PLAYSTOP_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_PLAYSTOP), GWL_WNDPROC, (LONG)TASEDITOR_PLAYSTOP_WndProc);
	TASEDITOR_FORWARD_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_FORWARD), GWL_WNDPROC, (LONG)TASEDITOR_FORWARD_WndProc);
	TASEDITOR_FORWARD_FULL_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_FORWARD_FULL), GWL_WNDPROC, (LONG)TASEDITOR_FORWARD_FULL_WndProc);
	CHECK_FOLLOW_CURSOR_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, CHECK_FOLLOW_CURSOR), GWL_WNDPROC, (LONG)CHECK_FOLLOW_CURSOR_WndProc);
	CHECK_AUTORESTORE_PLAYBACK_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, CHECK_AUTORESTORE_PLAYBACK), GWL_WNDPROC, (LONG)CHECK_AUTORESTORE_PLAYBACK_WndProc);
	IDC_RADIO_ALL_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RADIO_ALL), GWL_WNDPROC, (LONG)IDC_RADIO_ALL_WndProc);
	IDC_RADIO_1P_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RADIO_1P), GWL_WNDPROC, (LONG)IDC_RADIO_1P_WndProc);
	IDC_RADIO_2P_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RADIO_2P), GWL_WNDPROC, (LONG)IDC_RADIO_2P_WndProc);
	IDC_RADIO_3P_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RADIO_3P), GWL_WNDPROC, (LONG)IDC_RADIO_3P_WndProc);
	IDC_RADIO_4P_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RADIO_4P), GWL_WNDPROC, (LONG)IDC_RADIO_4P_WndProc);
	IDC_SUPERIMPOSE_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_SUPERIMPOSE), GWL_WNDPROC, (LONG)IDC_SUPERIMPOSE_WndProc);
	IDC_USEPATTERN_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_USEPATTERN), GWL_WNDPROC, (LONG)IDC_USEPATTERN_WndProc);
	TASEDITOR_PREV_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_PREV_MARKER), GWL_WNDPROC, (LONG)TASEDITOR_PREV_MARKER_WndProc);
	TASEDITOR_FIND_BEST_SIMILAR_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_FIND_BEST_SIMILAR_MARKER), GWL_WNDPROC, (LONG)TASEDITOR_FIND_BEST_SIMILAR_MARKER_WndProc);
	TASEDITOR_FIND_NEXT_SIMILAR_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_FIND_NEXT_SIMILAR_MARKER), GWL_WNDPROC, (LONG)TASEDITOR_FIND_NEXT_SIMILAR_MARKER_WndProc);
	TASEDITOR_NEXT_MARKER_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_NEXT_MARKER), GWL_WNDPROC, (LONG)TASEDITOR_NEXT_MARKER_WndProc);
	CHECK_TURBO_SEEK_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, CHECK_TURBO_SEEK), GWL_WNDPROC, (LONG)CHECK_TURBO_SEEK_WndProc);
	IDC_RECORDING_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RECORDING), GWL_WNDPROC, (LONG)IDC_RECORDING_WndProc);
	TASEDITOR_RUN_MANUAL_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, TASEDITOR_RUN_MANUAL), GWL_WNDPROC, (LONG)TASEDITOR_RUN_MANUAL_WndProc);
	IDC_RUN_AUTO_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndTASEditor, IDC_RUN_AUTO), GWL_WNDPROC, (LONG)IDC_RUN_AUTO_WndProc);
	// create "Recent" submenu
	hRecentProjectsMenu = CreateMenu();
	updateRecentProjectsMenu();

	reset();
}
void TASEDITOR_WINDOW::exit()
{
	for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
	{
		if (windowItems[i].tooltipHWND)
		{
			DestroyWindow(windowItems[i].tooltipHWND);
			windowItems[i].tooltipHWND = 0;
		}
	}
	if (hwndFindNote)
	{
		DestroyWindow(hwndFindNote);
		hwndFindNote = 0;
	}
	if (hwndTASEditor)
	{
		DestroyWindow(hwndTASEditor);
		hwndTASEditor = 0;
		TASEditorIsInFocus = false;
	}
	if (hTaseditorIcon)
	{
		DestroyIcon(hTaseditorIcon);
		hTaseditorIcon = 0;
	}
}
void TASEDITOR_WINDOW::reset()
{
	mustUpdateMouseCursor = true;
}
void TASEDITOR_WINDOW::update()
{
	if (mustUpdateMouseCursor)
	{
		// change mouse cursor depending on what it points at
		LPCSTR cursorIcon = IDC_ARROW;
		switch (pianoRoll.dragMode)
		{
			case DRAG_MODE_NONE:
			{
				// normal mouseover
				if (bookmarks.editMode == EDIT_MODE_BRANCHES)
				{
					int branchUnderMouse = bookmarks.itemUnderMouse;
					if (branchUnderMouse >= 0 && branchUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[branchUnderMouse].notEmpty)
					{
						int currentBranch = branches.getCurrentBranch();
						if (currentBranch >= 0 && currentBranch < TOTAL_BOOKMARKS)
						{
							// find if the Branch belongs to the current timeline
							int timelineBranch = branches.findFullTimelineForBranch(currentBranch);
							while (timelineBranch != ITEM_UNDER_MOUSE_CLOUD)
							{
								if (timelineBranch == branchUnderMouse)
									break;
								timelineBranch = branches.getParentOf(timelineBranch);
							}
							if (timelineBranch == ITEM_UNDER_MOUSE_CLOUD)
								// branchUnderMouse wasn't found in current timeline - change mouse cursor to a "?" mark
								cursorIcon = IDC_HELP;
						}
					}
				}
				break;
			}
			case DRAG_MODE_PLAYBACK:
			{
				// user is dragging Playback cursor - show either normal arrow or arrow+wait
				if (playback.getPauseFrame() >= 0)
					cursorIcon = IDC_APPSTARTING;
				break;
			}
			case DRAG_MODE_MARKER:
			{
				// user is dragging Marker
				cursorIcon = IDC_SIZEALL;
				break;
			}
			case DRAG_MODE_OBSERVE:
			case DRAG_MODE_SET:
			case DRAG_MODE_UNSET:
			case DRAG_MODE_SELECTION:
			case DRAG_MODE_DESELECTION:
				// user is drawing/selecting - show normal arrow
				break;
		}
		SetCursor(LoadCursor(0, cursorIcon));
		mustUpdateMouseCursor = false;
	}
}
// --------------------------------------------------------------------------------
void TASEDITOR_WINDOW::calculateItems()
{
	RECT r, mainRect;
	POINT p;
	HWND hCtrl;

	// set min size to current size
	GetWindowRect(hwndTASEditor, &mainRect);
	minWidth = mainRect.right - mainRect.left;
	minHeight = mainRect.bottom - mainRect.top;
	// check if wndwidth and wndheight weren't initialized
	if (taseditorConfig.windowWidth < minWidth)
		taseditorConfig.windowWidth = minWidth;
	if (taseditorConfig.windowHeight < minHeight)
		taseditorConfig.windowHeight = minHeight;
	if (taseditorConfig.savedWindowWidth < minWidth)
		taseditorConfig.savedWindowWidth = minWidth;
	if (taseditorConfig.savedWindowHeight < minHeight)
		taseditorConfig.savedWindowHeight = minHeight;
	// find current client area of Taseditor window
	int mainWidth = mainRect.right - mainRect.left;
	int mainHeight = mainRect.bottom - mainRect.top;

	// calculate current positions for all items
	for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
	{
		hCtrl = GetDlgItem(hwndTASEditor, windowItems[i].id);

		GetWindowRect(hCtrl, &r);
		p.x = r.left;
		p.y = r.top;
		ScreenToClient(hwndTASEditor, &p);
		if (windowItems[i].x < 0)
			// right-aligned
			windowItems[i].x = -(mainWidth - p.x);
		else
			// left-aligned
			windowItems[i].x = p.x;
		if (windowItems[i].y < 0)
			// bottom-aligned
			windowItems[i].y = -(mainHeight - p.y);
		else
			// top-aligned
			windowItems[i].y = p.y;
		if (windowItems[i].width < 0)
			// width is right-aligned (may be dynamic width)
			windowItems[i].width = -(mainWidth - (p.x + (r.right - r.left)));
		else
			// fixed width
			windowItems[i].width = r.right - r.left;
		if (windowItems[i].height < 0)
			// height is bottom-aligned (may be dynamic height)
			windowItems[i].height = -(mainHeight - (p.y + (r.bottom - r.top)));
		else
			// fixed height
			windowItems[i].height = r.bottom - r.top;
	}
	isReadyForResizing = true;
}
void TASEDITOR_WINDOW::resizeWindowItems()
{
	HWND hCtrl;
	int x, y, width, height;
	for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
	{
		hCtrl = GetDlgItem(hwndTASEditor, windowItems[i].id);
		if (windowItems[i].x < 0)
			// right-aligned
			x = taseditorConfig.windowWidth + windowItems[i].x;
		else
			// left-aligned
			x = windowItems[i].x;
		if (windowItems[i].y < 0)
			// bottom-aligned
			y = taseditorConfig.windowHeight + windowItems[i].y;
		else
			// top-aligned
			y = windowItems[i].y;
		if (windowItems[i].width < 0)
			// width is right-aligned (may be dynamic width)
			width = (taseditorConfig.windowWidth + windowItems[i].width) - x;
		else
			// normal width
			width = windowItems[i].width;
		if (windowItems[i].height < 0)
			// height is bottom-aligned (may be dynamic height)
			height = (taseditorConfig.windowHeight + windowItems[i].height) - y;
		else
			// normal height
			height = windowItems[i].height;
		SetWindowPos(hCtrl, 0, x, y, width, height, SWP_NOZORDER | SWP_NOOWNERZORDER);
	}
	redraw();
}
void TASEDITOR_WINDOW::handleWindowMovingOrResizing()
{
	RECT wrect;
	GetWindowRect(hwndTASEditor, &wrect);
	taseditorConfig.windowX = wrect.left;
	taseditorConfig.windowY = wrect.top;
	WindowBoundsCheckNoResize(taseditorConfig.windowX, taseditorConfig.windowY, wrect.right);
	taseditorConfig.windowWidth = wrect.right - wrect.left;
	if (taseditorConfig.windowWidth < minWidth)
		taseditorConfig.windowWidth = minWidth;
	taseditorConfig.windowHeight = wrect.bottom - wrect.top;
	if (taseditorConfig.windowHeight < minHeight)
		taseditorConfig.windowHeight = minHeight;

	if (IsZoomed(hwndTASEditor))
	{
		taseditorConfig.windowIsMaximized = true;
	} else
	{
		taseditorConfig.windowIsMaximized = false;
		taseditorConfig.savedWindowX = taseditorConfig.windowX;
		taseditorConfig.savedWindowY = taseditorConfig.windowY;
		taseditorConfig.savedWindowWidth = taseditorConfig.windowWidth;
		taseditorConfig.savedWindowHeight = taseditorConfig.windowHeight;
	}
}

void TASEDITOR_WINDOW::changeBookmarksListHeight(int newHeight)
{
	// the Bookmarks List height should not be less than the height of the Branches Bitmap, because they are switchable
	if (newHeight < BRANCHES_BITMAP_HEIGHT)
		newHeight = BRANCHES_BITMAP_HEIGHT;

	int delta = newHeight - windowItems[WINDOWITEMS_BOOKMARKS_LIST].height;
	if (!delta)
		return;
	// shift down all items that are below the Bookmarks List
	int BookmarksListBottom = windowItems[WINDOWITEMS_BOOKMARKS_LIST].y + windowItems[WINDOWITEMS_BOOKMARKS_LIST].height;
	for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
	{
		if (windowItems[i].y > BookmarksListBottom)
			windowItems[i].y += delta;
	}
	// adjust Bookmarks List size
	windowItems[WINDOWITEMS_BOOKMARKS_LIST].height += delta;
	windowItems[WINDOWITEMS_BOOKMARKS_BOX].height += delta;
	// adjust window size
	minHeight += delta;
	taseditorConfig.windowHeight += delta;
	taseditorConfig.savedWindowHeight += delta;
	// apply changes
	bool wndmaximized = taseditorConfig.windowIsMaximized;
	SetWindowPos(hwndTASEditor, HWND_TOP, taseditorConfig.windowX, taseditorConfig.windowY, taseditorConfig.windowWidth, taseditorConfig.windowHeight, SWP_NOOWNERZORDER);
	if (wndmaximized)
		ShowWindow(hwndTASEditor, SW_SHOWMAXIMIZED);
}

void TASEDITOR_WINDOW::updateTooltips()
{
	if (taseditorConfig.tooltipsEnabled)
	{
		for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
		{
			if (windowItems[i].tooltipHWND)
				SendMessage(windowItems[i].tooltipHWND, TTM_ACTIVATE, true, 0);
		}
	} else
	{
		for (int i = 0; i < TASEDITOR_WINDOW_TOTAL_ITEMS; ++i)
		{
			if (windowItems[i].tooltipHWND)
				SendMessage(windowItems[i].tooltipHWND, TTM_ACTIVATE, false, 0);
		}
	}
}

void TASEDITOR_WINDOW::updateCaption()
{
	char newCaption[300];
	strcpy(newCaption, windowCaptioBase);
	if (!movie_readonly)
		strcat(newCaption, recorder.getRecordingCaption());
	// add project name
	std::string projectname = project.getProjectName();
	if (!projectname.empty())
	{
		strcat(newCaption, " - ");
		strcat(newCaption, projectname.c_str());
	}
	// and * if project has unsaved changes
	if (project.getProjectChanged())
		strcat(newCaption, "*");
	SetWindowText(hwndTASEditor, newCaption);
}
void TASEDITOR_WINDOW::redraw()
{
	InvalidateRect(hwndTASEditor, 0, FALSE);
}

void TASEDITOR_WINDOW::updateCheckedItems()
{
	// check option ticks
	CheckDlgButton(hwndTASEditor, CHECK_FOLLOW_CURSOR, taseditorConfig.followPlaybackCursor?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndTASEditor, CHECK_AUTORESTORE_PLAYBACK, taseditorConfig.autoRestoreLastPlaybackPosition?BST_CHECKED:BST_UNCHECKED);
	if (taseditorConfig.superimpose == SUPERIMPOSE_UNCHECKED)
		CheckDlgButton(hwndTASEditor, IDC_SUPERIMPOSE, BST_UNCHECKED);
	else if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED)
		CheckDlgButton(hwndTASEditor, IDC_SUPERIMPOSE, BST_CHECKED);
	else
		CheckDlgButton(hwndTASEditor, IDC_SUPERIMPOSE, BST_INDETERMINATE);
	CheckDlgButton(hwndTASEditor, IDC_USEPATTERN, taseditorConfig.recordingUsePattern?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndTASEditor, IDC_RUN_AUTO, taseditorConfig.enableLuaAutoFunction?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndTASEditor, CHECK_TURBO_SEEK, taseditorConfig.turboSeek?BST_CHECKED : BST_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIEW_SHOWBRANCHSCREENSHOTS, taseditorConfig.displayBranchScreenshots?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIEW_SHOWBRANCHTOOLTIPS, taseditorConfig.displayBranchDescriptions?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIEW_ENABLEHOTCHANGES, taseditorConfig.enableHotChanges?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIEW_JUMPWHENMAKINGUNDO, taseditorConfig.followUndoContext?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_VIEW_FOLLOWMARKERNOTECONTEXT, taseditorConfig.followMarkerNoteContext?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_ENABLEGREENZONING, taseditorConfig.enableGreenzoning?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_PATTERNSKIPSLAG, taseditorConfig.autofirePatternSkipsLag?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_ADJUSTLAG, taseditorConfig.autoAdjustInputAccordingToLag?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_DRAWINPUTBYDRAGGING, taseditorConfig.drawInputByDragging?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_COMBINECONSECUTIVERECORDINGS, taseditorConfig.combineConsecutiveRecordingsAndDraws?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_USE1PFORRECORDING, taseditorConfig.use1PKeysForAllSingleRecordings?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_USEINPUTKEYSFORCOLUMNSET, taseditorConfig.useInputKeysForColumnSet?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_BINDMARKERSTOINPUT, taseditorConfig.bindMarkersToInput?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_EMPTYNEWMARKERNOTES, taseditorConfig.emptyNewMarkerNotes?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_OLDBRANCHINGCONTROLS, taseditorConfig.oldControlSchemeForBranching?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_BRANCHESRESTOREFULLMOVIE, taseditorConfig.branchesRestoreEntireMovie?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_HUDINBRANCHSCREENSHOTS, taseditorConfig.HUDInBranchScreenshots?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_CONFIG_AUTOPAUSEATTHEENDOFMOVIE, taseditorConfig.autopauseAtTheEndOfMovie?MF_CHECKED : MF_UNCHECKED);
	CheckMenuItem(hMainMenu, ID_HELP_TOOLTIPS, taseditorConfig.tooltipsEnabled?MF_CHECKED : MF_UNCHECKED);
}

// --------------------------------------------------------------------------------------------
void TASEDITOR_WINDOW::updateRecentProjectsMenu()
{
	MENUITEMINFO moo;
	int x;
	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_SUBMENU | MIIM_STATE;
	GetMenuItemInfo(GetSubMenu(hMainMenu, 0), ID_FILE_RECENT, FALSE, &moo);
	moo.hSubMenu = hRecentProjectsMenu;
	moo.fState = recentProjectsArray[0] ? MFS_ENABLED : MFS_GRAYED;
	SetMenuItemInfo(GetSubMenu(hMainMenu, 0), ID_FILE_RECENT, FALSE, &moo);

	// Remove all recent files submenus
	for(x = 0; x < MAX_NUMBER_OF_RECENT_PROJECTS; x++)
	{
		RemoveMenu(hRecentProjectsMenu, MENU_FIRST_RECENT_PROJECT + x, MF_BYCOMMAND);
	}
	// Recreate the menus
	for(x = MAX_NUMBER_OF_RECENT_PROJECTS - 1; x >= 0; x--)
	{  
		// Skip empty strings
		if (!recentProjectsArray[x]) continue;

		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;
		moo.fType = 0;
		moo.wID = MENU_FIRST_RECENT_PROJECT + x;
		std::string tmp = recentProjectsArray[x];
		// clamp this string to 128 chars
		if (tmp.size() > 128)
			tmp = tmp.substr(0, 128);
		moo.cch = tmp.size();
		moo.dwTypeData = (LPSTR)tmp.c_str();
		InsertMenuItem(hRecentProjectsMenu, 0, true, &moo);
	}

	// if recentProjectsArray is empty, the "Recent" item of the main menu should be grayed
	int i;
	for (i = 0; i < MAX_NUMBER_OF_RECENT_PROJECTS; ++i)
		if (recentProjectsArray[i]) break;
	if (i < MAX_NUMBER_OF_RECENT_PROJECTS)
		EnableMenuItem(hMainMenu, ID_FILE_RECENT, MF_ENABLED);
	else
		EnableMenuItem(hMainMenu, ID_FILE_RECENT, MF_GRAYED);

	DrawMenuBar(hwndTASEditor);
}
void TASEDITOR_WINDOW::updateRecentProjectsArray(const char* addString)
{
	// find out if the filename is already in the recent files list
	for(unsigned int x = 0; x < MAX_NUMBER_OF_RECENT_PROJECTS; x++)
	{
		if (recentProjectsArray[x])
		{
			if (!strcmp(recentProjectsArray[x], addString))    // Item is already in list
			{
				// If the filename is in the file list don't add it again, move it up in the list instead
				char* tmp = recentProjectsArray[x];			// save pointer
				for(int y = x; y; y--)
					// Move items down.
					recentProjectsArray[y] = recentProjectsArray[y - 1];
				// Put item on top.
				recentProjectsArray[0] = tmp;
				updateRecentProjectsMenu();
				return;
			}
		}
	}
	// The filename wasn't found in the list. That means we need to add it.
	// If there's no space left in the recent files list, get rid of the last item in the list
	if (recentProjectsArray[MAX_NUMBER_OF_RECENT_PROJECTS-1])
		free(recentProjectsArray[MAX_NUMBER_OF_RECENT_PROJECTS-1]);
	// Move other items down
	for(unsigned int x = MAX_NUMBER_OF_RECENT_PROJECTS-1; x; x--)
		recentProjectsArray[x] = recentProjectsArray[x-1];
	// Add new item
	recentProjectsArray[0] = (char*)malloc(strlen(addString) + 1);
	strcpy(recentProjectsArray[0], addString);

	updateRecentProjectsMenu();
}
void TASEDITOR_WINDOW::removeRecentProject(unsigned int which)
{
	if (which >= MAX_NUMBER_OF_RECENT_PROJECTS) return;
	// Remove the item
	if (recentProjectsArray[which])
		free(recentProjectsArray[which]);
	// If the item is not the last one in the list, shift the remaining ones up
	if (which < MAX_NUMBER_OF_RECENT_PROJECTS-1)
	{
		// Move the remaining items up
		for(unsigned int x = which+1; x < MAX_NUMBER_OF_RECENT_PROJECTS; ++x)
		{
			recentProjectsArray[x-1] = recentProjectsArray[x];	// Shift each remaining item up by 1
		}
	}
	recentProjectsArray[MAX_NUMBER_OF_RECENT_PROJECTS-1] = 0;	// Clear out the last item since it is empty now

	updateRecentProjectsMenu();
}
void TASEDITOR_WINDOW::loadRecentProject(int slot)
{
	char*& fname = recentProjectsArray[slot];
	if (fname && askToSaveProject())
	{
		if (!loadProject(fname))
		{
			int result = MessageBox(hwndTASEditor, "Remove from list?", "Could Not Open Recent Project", MB_YESNO);
			if (result == IDYES)
				removeRecentProject(slot);
		}
	}
}

void TASEDITOR_WINDOW::updatePatternsMenu()
{
	MENUITEMINFO moo;
	int x;
	moo.cbSize = sizeof(moo);

	// remove old items from the menu
	for(x = GetMenuItemCount(hPatternsMenu); x > 0 ; x--)
		RemoveMenu(hPatternsMenu, 0, MF_BYPOSITION);
	// fill the menu
	for(x = editor.patterns.size() - 1; x >= 0; x--)
	{  
		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;
		moo.fType = 0;
		moo.wID = MENU_FIRST_PATTERN + x;
		std::string tmp = editor.patternsNames[x];
		// clamp this string to 50 chars
		if (tmp.size() > PATTERNS_MAX_VISIBLE_NAME)
			tmp = tmp.substr(0, PATTERNS_MAX_VISIBLE_NAME);
		moo.dwTypeData = (LPSTR)tmp.c_str();
		moo.cch = tmp.size();
		InsertMenuItem(hPatternsMenu, 0, true, &moo);
	}
	recheckPatternsMenu();
}
void TASEDITOR_WINDOW::recheckPatternsMenu()
{
	CheckMenuRadioItem(hPatternsMenu, MENU_FIRST_PATTERN, MENU_FIRST_PATTERN + GetMenuItemCount(hPatternsMenu) - 1, MENU_FIRST_PATTERN + taseditorConfig.currentPattern, MF_BYCOMMAND);
	// change menu title ("Patterns")
	MENUITEMINFO moo;
	memset(&moo, 0, sizeof(moo));
	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_TYPE;
	moo.fType = MFT_STRING;
	moo.cch = PATTERNS_MAX_VISIBLE_NAME;
	int x;
	x = GetMenuItemInfo(hMainMenu, PATTERNS_MENU_POS, true, &moo);
	std::string tmp = patternsMenuPrefix;
	tmp += editor.patternsNames[taseditorConfig.currentPattern];
	// clamp this string
	if (tmp.size() > PATTERNS_MAX_VISIBLE_NAME)
		tmp = tmp.substr(0, PATTERNS_MAX_VISIBLE_NAME);
	moo.dwTypeData = (LPSTR)tmp.c_str();
	moo.cch = tmp.size();
	x = SetMenuItemInfo(hMainMenu, PATTERNS_MENU_POS, true, &moo);

	DrawMenuBar(hwndTASEditor);
}

// ====================================================================================================
BOOL CALLBACK TASEditorWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	extern TASEDITOR_WINDOW taseditorWindow;
	switch(uMsg)
	{
		case WM_PAINT:
			break;
		case WM_INITDIALOG:
		{
			if (taseditorConfig.windowX == -32000) taseditorConfig.windowX = 0;	//Just in case
			if (taseditorConfig.windowY == -32000) taseditorConfig.windowY = 0;
			break;
		}
		case WM_WINDOWPOSCHANGED:
		{
			WINDOWPOS* windowpos = (WINDOWPOS*)lParam;
			if (!(windowpos->flags & SWP_NOSIZE))
			{
				// window was resized
				if (!IsIconic(hWnd))
				{
					taseditorWindow.handleWindowMovingOrResizing();
					if (taseditorWindow.isReadyForResizing)
						taseditorWindow.resizeWindowItems();
					// also change coordinates of popup display (and move if it's open)
					popupDisplay.updateBecauseParentWindowMoved();
				}
			} else if (!(windowpos->flags & SWP_NOMOVE))
			{
				// window was moved
				if (!IsIconic(hWnd) && !IsZoomed(hWnd))
					taseditorWindow.handleWindowMovingOrResizing();
				// also change coordinates of popup display (and move if it's open)
				popupDisplay.updateBecauseParentWindowMoved();
			}
			break;
		}
		case WM_GETMINMAXINFO:
		{
			if (taseditorWindow.isReadyForResizing)
			{
				((MINMAXINFO*)lParam)->ptMinTrackSize.x = taseditorWindow.minWidth;
				((MINMAXINFO*)lParam)->ptMinTrackSize.y = taseditorWindow.minHeight;
			}
			break;
		}
		case WM_NOTIFY:
			switch(wParam)
			{
			case IDC_LIST1:
				switch(((LPNMHDR)lParam)->code)
				{
				case NM_CUSTOMDRAW:
					SetWindowLong(hWnd, DWL_MSGRESULT, pianoRoll.handleCustomDraw((NMLVCUSTOMDRAW*)lParam));
					return TRUE;
				case LVN_GETDISPINFO:
					pianoRoll.getDispInfo((NMLVDISPINFO*)lParam);
					break;
				case LVN_ITEMCHANGED:
					selection.noteThatItemChanged((LPNMLISTVIEW) lParam);
					break;
				case LVN_ODSTATECHANGED:
					selection.noteThatItemRangeChanged((LPNMLVODSTATECHANGE) lParam);
					break;
				case LVN_ENDSCROLL:
					pianoRoll.mustCheckItemUnderMouse = true;
					//pianoRoll.recalculatePlaybackCursorOffset();	// an unfinished experiment
					break;
				}
				break;
			case IDC_BOOKMARKSLIST:
				switch(((LPNMHDR)lParam)->code)
				{
				case NM_CUSTOMDRAW:
					SetWindowLong(hWnd, DWL_MSGRESULT, bookmarks.handleCustomDraw((NMLVCUSTOMDRAW*)lParam));
					return TRUE;
				case LVN_GETDISPINFO:
					bookmarks.getDispInfo((NMLVDISPINFO*)lParam);
					break;
				}
				break;
			case IDC_HISTORYLIST:
				switch(((LPNMHDR)lParam)->code)
				{
				case NM_CUSTOMDRAW:
					SetWindowLong(hWnd, DWL_MSGRESULT, history.handleCustomDraw((NMLVCUSTOMDRAW*)lParam));
					return TRUE;
				case LVN_GETDISPINFO:
					history.getDispInfo((NMLVDISPINFO*)lParam);
					break;
				}
				break;
			}
			break;
		case WM_CLOSE:
		case WM_QUIT:
			exitTASEditor();
			break;
		case WM_ACTIVATE:
			if (LOWORD(wParam))
			{
				taseditorWindow.TASEditorIsInFocus = true;
				enableGeneralKeyboardInput();
			} else
			{
				taseditorWindow.TASEditorIsInFocus = false;
				disableGeneralKeyboardInput();
			}
			break;
		case WM_CTLCOLORSTATIC:
			// change color of static text fields
			if ((HWND)lParam == playback.hwndPlaybackMarkerNumber)
			{
				SetTextColor((HDC)wParam, PLAYBACK_MARKER_COLOR);
				SetBkMode((HDC)wParam, TRANSPARENT);
				return (BOOL)(pianoRoll.bgBrush);
			} else if ((HWND)lParam == selection.hwndSelectionMarkerNumber)
			{
				SetTextColor((HDC)wParam, GetSysColor(COLOR_HIGHLIGHT));
				SetBkMode((HDC)wParam, TRANSPARENT);
				return (BOOL)pianoRoll.bgBrush;
			}
			break;
		case WM_COMMAND:
			{
				unsigned int loword_wparam = LOWORD(wParam);
				// first check clicking Recent submenu item
				if (loword_wparam >= MENU_FIRST_RECENT_PROJECT && loword_wparam < MENU_FIRST_RECENT_PROJECT + MAX_NUMBER_OF_RECENT_PROJECTS)
				{
					taseditorWindow.loadRecentProject(loword_wparam - MENU_FIRST_RECENT_PROJECT);
					break;
				}
				// then check clicking Patterns menu item
				if (loword_wparam >= MENU_FIRST_PATTERN && loword_wparam < MENU_FIRST_PATTERN + editor.patterns.size())
				{
					taseditorConfig.currentPattern = loword_wparam - MENU_FIRST_PATTERN;
					recorder.patternOffset = 0;
					taseditorWindow.recheckPatternsMenu();
					break;
				}
				// finally check all other commands
				switch(loword_wparam)
				{
				case ID_FILE_NEW:
					createNewProject();
					break;
				case ID_FILE_OPENPROJECT:
					openProject();
					break;
				case ACCEL_CTRL_S:
					saveProject();
					break;
				case ID_FILE_SAVEPROJECT:
					saveProject();
					break;
				case ID_FILE_SAVEPROJECTAS:
					saveProjectAs();
					break;
				case ID_FILE_SAVECOMPACT:
					saveCompact();
					break;
				case ID_FILE_IMPORT:
					importInputData();
					break;
				case ID_FILE_EXPORTFM2:
						exportToFM2();
					break;
				case ID_FILE_CLOSE:
					exitTASEditor();
					break;
				case ID_EDIT_DESELECT:
				case ID_SELECTED_DESELECT:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.clearAllRowsSelection();
					break;
				case ID_EDIT_SELECTALL:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.selectAllRows();
					break;
				case ID_SELECTED_UNGREENZONE:
					greenzone.ungreenzoneSelectedFrames();
					break;
				case ACCEL_CTRL_X:
				case ID_EDIT_CUT:
					splicer.cutSelectedInputToClipboard();
					break;
				case ACCEL_CTRL_C:
				case ID_EDIT_COPY:
					splicer.copySelectedInputToClipboard();
					break;
				case ACCEL_CTRL_V:
				case ID_EDIT_PASTE:
					splicer.pasteInputFromClipboard();
					break;
				case ACCEL_CTRL_SHIFT_V:
				case ID_EDIT_PASTEINSERT:
					splicer.pasteInsertInputFromClipboard();
					break;
				case ACCEL_CTRL_DELETE:
				case ID_EDIT_DELETE:
				case ID_CONTEXT_SELECTED_DELETEFRAMES:
					splicer.deleteSelectedFrames();
					break;
				case ID_EDIT_TRUNCATE:
				case ID_CONTEXT_SELECTED_TRUNCATE:
					splicer.truncateMovie();
					break;
				case ACCEL_INS:
				case ID_EDIT_INSERT:
				case ID_CONTEXT_SELECTED_INSERTFRAMES2:
					splicer.insertNumberOfFrames();
					break;
				case ACCEL_CTRL_SHIFT_INS:
				case ID_EDIT_INSERTFRAMES:
				case ID_CONTEXT_SELECTED_INSERTFRAMES:
					splicer.insertSelectedFrames();
					break;
				case ACCEL_DEL:
					splicer.clearSelectedFrames();
					break;
				case ID_EDIT_CLEAR:
				case ID_CONTEXT_SELECTED_CLEARFRAMES:
						splicer.clearSelectedFrames();
					break;
				case CHECK_FOLLOW_CURSOR:
					taseditorConfig.followPlaybackCursor ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case CHECK_TURBO_SEEK:
					taseditorConfig.turboSeek ^= 1;
					taseditorWindow.updateCheckedItems();
					// if currently seeking, apply this option immediately
					if (playback.getPauseFrame() >= 0)
						turbo = taseditorConfig.turboSeek;
					break;
				case ID_VIEW_SHOWBRANCHSCREENSHOTS:
					taseditorConfig.displayBranchScreenshots ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_VIEW_SHOWBRANCHTOOLTIPS:
					taseditorConfig.displayBranchDescriptions ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_VIEW_ENABLEHOTCHANGES:
					taseditorConfig.enableHotChanges ^= 1;
					taseditorWindow.updateCheckedItems();
					pianoRoll.redraw();		// redraw buttons text
					break;
				case ID_VIEW_JUMPWHENMAKINGUNDO:
					taseditorConfig.followUndoContext ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_VIEW_FOLLOWMARKERNOTECONTEXT:
					taseditorConfig.followMarkerNoteContext ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case CHECK_AUTORESTORE_PLAYBACK:
					taseditorConfig.autoRestoreLastPlaybackPosition ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_ADJUSTLAG:
					taseditorConfig.autoAdjustInputAccordingToLag ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_SETGREENZONECAPACITY:
					{
						int newValue = taseditorConfig.greenzoneCapacity;
						if (CWin32InputBox::GetInteger("Greenzone capacity", "Keep savestates for how many frames?\n(actual limit of savestates can be 5 times more than the number provided)", newValue, hWnd) == IDOK)
						{
							if (newValue < GREENZONE_CAPACITY_MIN)
								newValue = GREENZONE_CAPACITY_MIN;
							else if (newValue > GREENZONE_CAPACITY_MAX)
								newValue = GREENZONE_CAPACITY_MAX;
							if (newValue < taseditorConfig.greenzoneCapacity)
							{
								taseditorConfig.greenzoneCapacity = newValue;
								greenzone.runGreenzoneCleaning();
							} else taseditorConfig.greenzoneCapacity = newValue;
						}
						break;
					}
				case ID_CONFIG_SETMAXUNDOLEVELS:
					{
						int newValue = taseditorConfig.maxUndoLevels;
						if (CWin32InputBox::GetInteger("Max undo levels", "Keep history of how many changes?", newValue, hWnd) == IDOK)
						{
							if (newValue < UNDO_LEVELS_MIN)
								newValue = UNDO_LEVELS_MIN;
							else if (newValue > UNDO_LEVELS_MAX)
								newValue = UNDO_LEVELS_MAX;
							if (newValue != taseditorConfig.maxUndoLevels)
							{
								taseditorConfig.maxUndoLevels = newValue;
								history.updateHistoryLogSize();
								selection.updateHistoryLogSize();
							}
						}
						break;
					}
				case ID_CONFIG_SAVING_OPTIONS:
					{
						DialogBox(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_SAVINGOPTIONS), taseditorWindow.hwndTASEditor, savingOptionsWndProc);
						break;
					}
				case ID_CONFIG_ENABLEGREENZONING:
					taseditorConfig.enableGreenzoning ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_BRANCHESRESTOREFULLMOVIE:
					taseditorConfig.branchesRestoreEntireMovie ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_OLDBRANCHINGCONTROLS:
					taseditorConfig.oldControlSchemeForBranching ^= 1;
					taseditorWindow.updateCheckedItems();
					bookmarks.redrawBookmarksSectionCaption();
					break;
				case ID_CONFIG_HUDINBRANCHSCREENSHOTS:
					taseditorConfig.HUDInBranchScreenshots ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_BINDMARKERSTOINPUT:
					taseditorConfig.bindMarkersToInput ^= 1;
					taseditorWindow.updateCheckedItems();
					pianoRoll.redraw();
					break;
				case ID_CONFIG_EMPTYNEWMARKERNOTES:
					taseditorConfig.emptyNewMarkerNotes ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_COMBINECONSECUTIVERECORDINGS:
					taseditorConfig.combineConsecutiveRecordingsAndDraws ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_USE1PFORRECORDING:
					taseditorConfig.use1PKeysForAllSingleRecordings ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_USEINPUTKEYSFORCOLUMNSET:
					taseditorConfig.useInputKeysForColumnSet ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_PATTERNSKIPSLAG:
					taseditorConfig.autofirePatternSkipsLag ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_DRAWINPUTBYDRAGGING:
					taseditorConfig.drawInputByDragging ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_CONFIG_AUTOPAUSEATTHEENDOFMOVIE:
					taseditorConfig.autopauseAtTheEndOfMovie ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case IDC_RECORDING:
					FCEUI_MovieToggleReadOnly();
					CheckDlgButton(taseditorWindow.hwndTASEditor, IDC_RECORDING, movie_readonly?BST_UNCHECKED : BST_CHECKED);
					break;
				case IDC_RADIO2:
					recorder.multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_ALL;
					break;
				case IDC_RADIO3:
					recorder.multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_1P;
					break;
				case IDC_RADIO4:
					recorder.multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_2P;
					break;
				case IDC_RADIO5:
					recorder.multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_3P;
					break;
				case IDC_RADIO6:
					recorder.multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_4P;
					break;
				case IDC_SUPERIMPOSE:
					// 3 states of "Superimpose" checkbox
					if (taseditorConfig.superimpose == SUPERIMPOSE_UNCHECKED)
						taseditorConfig.superimpose = SUPERIMPOSE_CHECKED;
					else if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED)
						taseditorConfig.superimpose = SUPERIMPOSE_INDETERMINATE;
					else taseditorConfig.superimpose = SUPERIMPOSE_UNCHECKED;
					taseditorWindow.updateCheckedItems();
					break;
				case IDC_USEPATTERN:
					taseditorConfig.recordingUsePattern ^= 1;
					recorder.patternOffset = 0;
					taseditorWindow.updateCheckedItems();
					break;
				case ACCEL_CTRL_A:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.selectAllRowsBetweenMarkers();
					break;
				case ID_EDIT_SELECTMIDMARKERS:
				case ID_SELECTED_SELECTMIDMARKERS:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.selectAllRowsBetweenMarkers();
					break;
				case ACCEL_CTRL_INSERT:
				case ID_EDIT_CLONEFRAMES:
				case ID_SELECTED_CLONE:
					splicer.cloneSelectedFrames();
					break;
				case ACCEL_CTRL_Z:
				case ID_EDIT_UNDO:
					history.undo();
					break;
				case ACCEL_CTRL_Y:
				case ID_EDIT_REDO:
					history.redo();
					break;
				case ID_EDIT_SELECTIONUNDO:
				case ACCEL_CTRL_Q:
					{
						if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						{
							selection.undo();
							pianoRoll.followSelection();
						}
						break;
					}
				case ID_EDIT_SELECTIONREDO:
				case ACCEL_CTRL_W:
					{
						if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						{
							selection.redo();
							pianoRoll.followSelection();
						}
						break;
					}
				case ID_EDIT_RESELECTCLIPBOARD:
				case ACCEL_CTRL_B:
					{
						if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						{
							selection.reselectClipboard();
							pianoRoll.followSelection();
						}
						break;
					}
				case ID_SELECTED_SETMARKERS:
					{
						editor.setMarkers();
						break;
					}
				case ID_SELECTED_REMOVEMARKERS:
					{
						editor.removeMarkers();
						break;
					}
				case ACCEL_CTRL_F:
				case ID_VIEW_FINDNOTE:
					{
						if (taseditorWindow.hwndFindNote)
							// set focus to the text field
							SendMessage(taseditorWindow.hwndFindNote, WM_NEXTDLGCTL, (WPARAM)GetDlgItem(taseditorWindow.hwndFindNote, IDC_NOTE_TO_FIND), true);
						else
							taseditorWindow.hwndFindNote = CreateDialog(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_FINDNOTE), taseditorWindow.hwndTASEditor, findNoteWndProc);
						break;
					}
				case TASEDITOR_FIND_BEST_SIMILAR_MARKER:
					markersManager.findSimilarNote();
					break;
				case TASEDITOR_FIND_NEXT_SIMILAR_MARKER:
					markersManager.findNextSimilarNote();
					break;
				case TASEDITOR_RUN_MANUAL:
					// the function will be called in next window update
					mustCallManualLuaFunction = true;
					break;
				case IDC_RUN_AUTO:
					taseditorConfig.enableLuaAutoFunction ^= 1;
					taseditorWindow.updateCheckedItems();
					break;
				case ID_HELP_OPEN_MANUAL:
					{
						std::string helpFileName = BaseDirectory;
						helpFileName.append(taseditorHelpFilename);
						HtmlHelp(GetDesktopWindow(), helpFileName.c_str(), HH_DISPLAY_TOPIC, (DWORD)NULL);
						break;
					}
				case ID_HELP_TOOLTIPS:
					taseditorConfig.tooltipsEnabled ^= 1;
					taseditorWindow.updateCheckedItems();
					taseditorWindow.updateTooltips();
					break;
				case ID_HELP_ABOUT:
					DialogBox(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_ABOUT), taseditorWindow.hwndTASEditor, aboutWndProc);
					break;
				case ACCEL_HOME:
				{
					// scroll Piano Roll to the beginning
					ListView_Scroll(pianoRoll.hwndList, 0, -pianoRoll.listRowHeight * ListView_GetTopIndex(pianoRoll.hwndList));
					break;
				}
				case ACCEL_END:
				{
					// scroll Piano Roll to the end
					ListView_Scroll(pianoRoll.hwndList, 0, pianoRoll.listRowHeight * currMovieData.getNumRecords());
					break;
				}
				case ACCEL_PGUP:
					// scroll Piano Roll 1 page up
					ListView_Scroll(pianoRoll.hwndList, 0, -pianoRoll.listRowHeight * ListView_GetCountPerPage(pianoRoll.hwndList));
					break;
				case ACCEL_PGDN:
					// scroll Piano Roll 1 page up
					ListView_Scroll(pianoRoll.hwndList, 0, pianoRoll.listRowHeight * ListView_GetCountPerPage(pianoRoll.hwndList));
					break;
				case ACCEL_CTRL_HOME:
				{
					// transpose Selection to the beginning and scroll to it
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
					{
						int selectionBeginning = selection.getCurrentRowsSelectionBeginning();
						if (selectionBeginning >= 0)
						{
							selection.transposeVertically(-selectionBeginning);
							pianoRoll.ensureTheLineIsVisible(0);
						}
					}
					break;
				}
				case ACCEL_CTRL_END:
				{
					// transpose Selection to the end and scroll to it
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
					{
						int selectionEnd = selection.getCurrentRowsSelectionEnd();
						if (selectionEnd >= 0)
						{
							selection.transposeVertically(currMovieData.getNumRecords() - 1 - selectionEnd);
							pianoRoll.ensureTheLineIsVisible(currMovieData.getNumRecords() - 1);
						}
					}
					break;
				}
				case ACCEL_CTRL_PGUP:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.jumpToPreviousMarker();
					break;
				case ACCEL_CTRL_PGDN:
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
						selection.jumpToNextMarker();
					break;
				case ACCEL_CTRL_UP:
					// transpose Selection 1 frame up and scroll to it
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
					{
						selection.transposeVertically(-1);
						int selectionBeginning = selection.getCurrentRowsSelectionBeginning();
						if (selectionBeginning >= 0)
							pianoRoll.ensureTheLineIsVisible(selectionBeginning);
					}
					break;
				case ACCEL_CTRL_DOWN:
					// transpose Selection 1 frame down and scroll to it
					if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
					{
						selection.transposeVertically(1);
						int selectionEnd = selection.getCurrentRowsSelectionEnd();
						if (selectionEnd >= 0)
							pianoRoll.ensureTheLineIsVisible(selectionEnd);
					}
					break;
				case ACCEL_CTRL_LEFT:
				case ACCEL_SHIFT_LEFT:
				{
					// scroll Piano Roll horizontally to the left
					ListView_Scroll(pianoRoll.hwndList, -COLUMN_BUTTON_WIDTH, 0);
					break;
				}
				case ACCEL_CTRL_RIGHT:
				case ACCEL_SHIFT_RIGHT:
					// scroll Piano Roll horizontally to the right
					ListView_Scroll(pianoRoll.hwndList, COLUMN_BUTTON_WIDTH, 0);
					break;
				case ACCEL_SHIFT_HOME:
					// send Playback to the beginning
					playback.jump(0);
					break;
				case ACCEL_SHIFT_END:
					// send Playback to the end
					playback.jump(currMovieData.getNumRecords() - 1);
					break;
				case ACCEL_SHIFT_PGUP:
					playback.handleRewindFull();
					break;
				case ACCEL_SHIFT_PGDN:
					playback.handleForwardFull();
					break;
				case ACCEL_SHIFT_UP:
					// rewind 1 frame
					playback.handleRewindFrame();
					break;
				case ACCEL_SHIFT_DOWN:
					// step forward 1 frame
					playback.handleForwardFrame();
					break;

				}
				break;
			}
		case WM_SYSCOMMAND:
		{
			switch (wParam)
	        {
				// Disable entering menu by Alt or F10
			    case SC_KEYMENU:
		            return true;
			}
	        break;
		}
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
		{
			// if user clicked on a narrow space to the left of Piano Roll
			// consider this as a "misclick" on Piano Roll's first column
			int x = GET_X_LPARAM(lParam);
			int y = GET_Y_LPARAM(lParam);
			RECT wrect;
			GetWindowRect(pianoRoll.hwndList, &wrect);
			if (x > 0
				&& x <= windowItems[WINDOWITEMS_PIANO_ROLL].x
				&& y > windowItems[WINDOWITEMS_PIANO_ROLL].y
				&& y < windowItems[WINDOWITEMS_PIANO_ROLL].y + (wrect.bottom - wrect.top))
			{
				pianoRoll.startDraggingPlaybackCursor();
			}
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			break;
		}
		case WM_RBUTTONDOWN:
		case WM_RBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			break;
		}
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
		{
			playback.handleMiddleButtonClick();
			break;
		}
		case WM_MOUSEWHEEL:
			return SendMessage(pianoRoll.hwndList, uMsg, wParam, lParam);

		default:
			break;
	}
	return FALSE;
}
// -----------------------------------------------------------------------------------------------
// implementation of wndprocs for "Marker X" text
LRESULT APIENTRY IDC_PLAYBACK_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
			pianoRoll.followPlaybackCursor();
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
	}
	return CallWindowProc(IDC_PLAYBACK_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_SELECTION_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
			if (pianoRoll.dragMode != DRAG_MODE_SELECTION && pianoRoll.dragMode != DRAG_MODE_DESELECTION)
				pianoRoll.followSelection();
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
	}
	return CallWindowProc(IDC_SELECTION_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
// -----------------------------------------------------------------------------------------------
// implementation of wndprocs for all buttons and checkboxes
LRESULT APIENTRY IDC_PROGRESS_BUTTON_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
			playback.cancelSeeking();
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_PROGRESS_BUTTON_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_BRANCHES_BUTTON_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
			// click on "Bookmarks/Branches" - switch between Bookmarks List and Branches Tree
			taseditorConfig.displayBranchesTree ^= 1;
			bookmarks.redrawBookmarksSectionCaption();
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_BRANCHES_BUTTON_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_REWIND_FULL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_REWIND_FULL_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_REWIND_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_REWIND_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_PLAYSTOP_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
			playback.toggleEmulationPause();
			break;
	}
	return CallWindowProc(TASEDITOR_PLAYSTOP_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_FORWARD_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_FORWARD_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_FORWARD_FULL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_FORWARD_FULL_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY CHECK_FOLLOW_CURSOR_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(CHECK_FOLLOW_CURSOR_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY CHECK_AUTORESTORE_PLAYBACK_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(CHECK_AUTORESTORE_PLAYBACK_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RADIO_ALL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RADIO_ALL_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RADIO_1P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RADIO_1P_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RADIO_2P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RADIO_2P_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RADIO_3P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RADIO_3P_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RADIO_4P_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RADIO_4P_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_SUPERIMPOSE_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_SUPERIMPOSE_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_USEPATTERN_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_USEPATTERN_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_PREV_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_PREV_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_FIND_BEST_SIMILAR_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_FIND_BEST_SIMILAR_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_FIND_NEXT_SIMILAR_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_FIND_NEXT_SIMILAR_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_NEXT_MARKER_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_NEXT_MARKER_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY CHECK_TURBO_SEEK_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(CHECK_TURBO_SEEK_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RECORDING_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RECORDING_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY TASEDITOR_RUN_MANUAL_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(TASEDITOR_RUN_MANUAL_oldWndProc, hWnd, msg, wParam, lParam);
}
LRESULT APIENTRY IDC_RUN_AUTO_WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
			playback.handleMiddleButtonClick();
			return 0;
		case WM_KEYDOWN:
			return 0;		// disable Spacebar
	}
	return CallWindowProc(IDC_RUN_AUTO_oldWndProc, hWnd, msg, wParam, lParam);
}

