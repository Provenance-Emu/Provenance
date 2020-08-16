/* ---------------------------------------------------------------------------------
Main TAS Editor file
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Main - Main gate between emulator and Taseditor
[Single instance]

* the point of launching TAS Editor from emulator
* the point of quitting from TAS Editor
* regularly (at the end of every frame) updates all modules that need regular update
* implements operations of the "File" menu: creating New project, opening a file, saving, compact saving, import, export
* handles some FCEUX hotkeys
------------------------------------------------------------------------------------ */

#include "taseditor/taseditor_project.h"
#include "utils/xstring.h"
#include "main.h"			// for GetRomName
#include "taseditor.h"
#include "window.h"
#include "../../input.h"
#include "../keyboard.h"
#include "../joystick.h"

using namespace std;

// TAS Editor data
bool mustEngageTaseditor = false;
bool mustRewindNow = false;
bool mustCallManualLuaFunction = false;
bool taseditorEnableAcceleratorKeys = false;

// all Taseditor functional modules
TASEDITOR_CONFIG taseditorConfig;
TASEDITOR_WINDOW taseditorWindow;
TASEDITOR_PROJECT project;
HISTORY history;
PLAYBACK playback;
RECORDER recorder;
GREENZONE greenzone;
MARKERS_MANAGER markersManager;
BOOKMARKS bookmarks;
BRANCHES branches;
POPUP_DISPLAY popupDisplay;
PIANO_ROLL pianoRoll;
TASEDITOR_LUA taseditor_lua;
SELECTION selection;
SPLICER splicer;
EDITOR editor;

extern int joysticksPerFrame[INPUT_TYPES_TOTAL];
extern bool turbo;
extern int pal_emulation;
extern int newppu;
extern void PushCurrentVideoSettings();
extern void RefreshThrottleFPS();
extern bool LoadFM2(MovieData& movieData, EMUFILE* fp, int size, bool stopAfterHeader);
// temporarily saved FCEUX config
int saved_eoptions;
int saved_EnableAutosave;
extern int EnableAutosave;
int saved_frame_display;
// FCEUX
extern EMOVIEMODE movieMode;	// maybe we need normal setter for movieMode, to encapsulate it
// lua engine
extern void TaseditorAutoFunction();
extern void TaseditorManualFunction();

// returns true if Taseditor is engaged at the end of the function
bool enterTASEditor()
{
	if (taseditorWindow.hwndTASEditor)
	{
		// TAS Editor is already engaged, just set focus to its window
		if (!taseditorConfig.windowIsMaximized)
			ShowWindow(taseditorWindow.hwndTASEditor, SW_SHOWNORMAL);
		SetForegroundWindow(taseditorWindow.hwndTASEditor);
		return true;
	} else if (FCEU_IsValidUI(FCEUI_TASEDITOR))
	{
		// start TAS Editor
		// create window
		taseditorWindow.init();
		if (taseditorWindow.hwndTASEditor)
		{
			enableGeneralKeyboardInput();
			// save "eoptions"
			saved_eoptions = eoptions;
			// set "Run in background"
			eoptions |= EO_BGRUN;
			// "Set high-priority thread"
			eoptions |= EO_HIGHPRIO;
			DoPriority();
			// switch off autosaves
			saved_EnableAutosave = EnableAutosave;
			EnableAutosave = 0;
			// switch on frame_display
			saved_frame_display = frame_display;
			frame_display = 1;
			UpdateCheckedMenuItems();
			
			// init modules
			editor.init();
			pianoRoll.init();
			selection.init();
			splicer.init();
			playback.init();
			greenzone.init();
			recorder.init();
			markersManager.init();
			project.init();
			bookmarks.init();
			branches.init();
			popupDisplay.init();
			history.init();
			taseditor_lua.init();
			// either start new movie or use current movie
			if (!FCEUMOV_Mode(MOVIEMODE_RECORD|MOVIEMODE_PLAY) || currMovieData.savestate.size() != 0)
			{
				if (currMovieData.savestate.size() != 0)
					FCEUD_PrintError("This version of TAS Editor doesn't work with movies starting from savestate.");
				// create new movie
				FCEUI_StopMovie();
				movieMode = MOVIEMODE_TASEDITOR;
				FCEUMOV_CreateCleanMovie();
				playback.restartPlaybackFromZeroGround();
			} else
			{
				// use current movie to create a new project
				FCEUI_StopMovie();
				movieMode = MOVIEMODE_TASEDITOR;
			}
			// if movie length is less or equal to currFrame, pad it with empty frames
			if (((int)currMovieData.records.size() - 1) < currFrameCounter)
				currMovieData.insertEmpty(-1, currFrameCounter - ((int)currMovieData.records.size() - 1));
			// ensure that movie has correct set of ports/fourscore
			setInputType(currMovieData, getInputType(currMovieData));
			// force the input configuration stored in the movie to apply to FCEUX config
			applyMovieInputConfig();
			// reset some modules that need MovieData info
			pianoRoll.reset();
			recorder.reset();
			// create initial snapshot in history
			history.reset();
			// reset Taseditor variables
			mustCallManualLuaFunction = false;
			
			SetFocus(history.hwndHistoryList);		// set focus only once, to show blue selection cursor
			SetFocus(pianoRoll.hwndList);
			FCEU_DispMessage("TAS Editor engaged", 0);
			taseditorWindow.redraw();
			return true;
		} else
		{
			// couldn't init window
			return false;
		}
	} else
	{
		// right now TAS Editor launch is not allowed by emulator
		return true;
	}
}

bool exitTASEditor()
{
	if (!askToSaveProject()) return false;

	// destroy window
	taseditorWindow.exit();
	disableGeneralKeyboardInput();
	// release memory
	editor.free();
	pianoRoll.free();
	markersManager.free();
	greenzone.free();
	bookmarks.free();
	branches.free();
	popupDisplay.free();
	history.free();
	playback.stopSeeking();
	selection.free();

	// restore "eoptions"
	eoptions = saved_eoptions;
	// restore autosaves
	EnableAutosave = saved_EnableAutosave;
	DoPriority();
	// restore frame_display
	frame_display = saved_frame_display;
	UpdateCheckedMenuItems();
	// switch off TAS Editor mode
	movieMode = MOVIEMODE_INACTIVE;
	FCEU_DispMessage("TAS Editor disengaged", 0);
	FCEUMOV_CreateCleanMovie();
	return true;
}

// everyframe function
void updateTASEditor()
{
	if (taseditorWindow.hwndTASEditor)
	{
		// TAS Editor is engaged
		// update all modules that need to be updated every frame
		// the order is somewhat important, e.g. Greenzone must update before Bookmark Set, Piano Roll must update before Selection
		taseditorWindow.update();
		greenzone.update();
		recorder.update();
		pianoRoll.update();
		markersManager.update();
		playback.update();
		bookmarks.update();
		branches.update();
		popupDisplay.update();
		selection.update();
		splicer.update();
		history.update();
		project.update();
		// run Lua functions if needed
		if (taseditorConfig.enableLuaAutoFunction)
			TaseditorAutoFunction();
		if (mustCallManualLuaFunction)
		{
			TaseditorManualFunction();
			mustCallManualLuaFunction = false;
		}
	} else
	{
		// TAS Editor is not engaged
		TaseditorAutoFunction();	// but we still should run Lua auto function
		if (mustEngageTaseditor)
		{
			char fullname[1000];
			strcpy(fullname, curMovieFilename);
			if (enterTASEditor())
				loadProject(fullname);
			mustEngageTaseditor = false;
		}
	}
}

BOOL CALLBACK newProjectProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	static struct NewProjectParameters* p = NULL;
	switch (message)
	{
		case WM_INITDIALOG:
			p = (struct NewProjectParameters*)lParam;
			p->inputType = getInputType(currMovieData);
			p->copyCurrentInput = p->copyCurrentMarkers = false;
			if (strlen(taseditorConfig.lastAuthorName))
			{
				// convert UTF8 char* string to Unicode wstring
				wchar_t savedAuthorName[AUTHOR_NAME_MAX_LEN] = {0};
				MultiByteToWideChar(CP_UTF8, 0, taseditorConfig.lastAuthorName, -1, savedAuthorName, AUTHOR_NAME_MAX_LEN);
				p->authorName = savedAuthorName;
			} else
			{
				p->authorName = L"";
			}
			switch (p->inputType)
			{
			case INPUT_TYPE_1P:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_1PLAYER), BST_CHECKED);
					break;
				}
			case INPUT_TYPE_2P:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_2PLAYERS), BST_CHECKED);
					break;
				}
			case INPUT_TYPE_FOURSCORE:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_FOURSCORE), BST_CHECKED);
					break;
				}
			}
			SendMessage(GetDlgItem(hwndDlg, IDC_EDIT_AUTHOR), CCM_SETUNICODEFORMAT, TRUE, 0);
			SetDlgItemTextW(hwndDlg, IDC_EDIT_AUTHOR, (LPCWSTR)(p->authorName.c_str()));
			return 0;
		case WM_COMMAND:
			switch (LOWORD(wParam))
			{
				case IDC_RADIO_1PLAYER:
					p->inputType = INPUT_TYPE_1P;
					break;
				case IDC_RADIO_2PLAYERS:
					p->inputType = INPUT_TYPE_2P;
					break;
				case IDC_RADIO_FOURSCORE:
					p->inputType = INPUT_TYPE_FOURSCORE;
					break;
				case IDC_COPY_INPUT:
					p->copyCurrentInput ^= 1;
					CheckDlgButton(hwndDlg, IDC_COPY_INPUT, p->copyCurrentInput?MF_CHECKED : MF_UNCHECKED);
					break;
				case IDC_COPY_MARKERS:
					p->copyCurrentMarkers ^= 1;
					CheckDlgButton(hwndDlg, IDC_COPY_MARKERS, p->copyCurrentMarkers?MF_CHECKED : MF_UNCHECKED);
					break;
				case IDOK:
				{
					// save author name in params and in taseditor_config (converted to multibyte char*)
					wchar_t authorName[AUTHOR_NAME_MAX_LEN] = {0};
					GetDlgItemTextW(hwndDlg, IDC_EDIT_AUTHOR, (LPWSTR)authorName, AUTHOR_NAME_MAX_LEN);
					p->authorName = authorName;
					if (p->authorName == L"")
						taseditorConfig.lastAuthorName[0] = 0;
					else
						// convert Unicode wstring to UTF8 char* string
						WideCharToMultiByte(CP_UTF8, 0, (p->authorName).c_str(), -1, taseditorConfig.lastAuthorName, AUTHOR_NAME_MAX_LEN, 0, 0);
					EndDialog(hwndDlg, 1);
					return TRUE;
				}
				case IDCANCEL:
					EndDialog(hwndDlg, 0);
					return TRUE;
			}
			break;
	}
	return FALSE; 
}

void createNewProject()
{
	if (!askToSaveProject()) return;

	static struct NewProjectParameters params;
	if (DialogBoxParam(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_NEWPROJECT), taseditorWindow.hwndTASEditor, newProjectProc, (LPARAM)&params) > 0)
	{
		FCEUMOV_CreateCleanMovie();
		// apply selected options
		setInputType(currMovieData, params.inputType);
		applyMovieInputConfig();
		if (params.copyCurrentInput)
			// copy Input from current snapshot (from history)
			history.getCurrentSnapshot().inputlog.toMovie(currMovieData);
		if (!params.copyCurrentMarkers)
			markersManager.reset();
		if (params.authorName != L"") currMovieData.comments.push_back(L"author " + params.authorName);
		
		// reset Taseditor
		project.init();			// new project has blank name
		greenzone.reset();
		if (params.copyCurrentInput)
			// copy LagLog from current snapshot (from history)
			greenzone.lagLog = history.getCurrentSnapshot().laglog;
		playback.reset();
		playback.restartPlaybackFromZeroGround();
		bookmarks.reset();
		branches.reset();
		history.reset();
		pianoRoll.reset();
		selection.reset();
		editor.reset();
		splicer.reset();
		recorder.reset();
		popupDisplay.reset();
		taseditorWindow.redraw();
		taseditorWindow.updateCaption();
	}
}

void openProject()
{
	if (!askToSaveProject()) return;

	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = taseditorWindow.hwndTASEditor;
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = "Open TAS Editor Project";
	const char filter[] = "TAS Editor Projects (*.fm3)\0*.fm3\0All Files (*.*)\0*.*\0\0";
	ofn.lpstrFilter = filter;

	char nameo[2048];
	strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());	//convert | to . for archive filenames

	ofn.lpstrFile = nameo;							
	ofn.nMaxFile = 2048;
	ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT|OFN_FILEMUSTEXIST;
	string initdir = FCEU_GetPath(FCEUMKF_MOVIE);	
	ofn.lpstrInitialDir = initdir.c_str();

	if (GetOpenFileName(&ofn))							// If it is a valid filename
	{
		loadProject(nameo);
	}
}
bool loadProject(const char* fullname)
{
	// try to load project
	if (project.load(fullname))
	{
		// loaded successfully
		applyMovieInputConfig();
		// add new file to Recent menu
		taseditorWindow.updateRecentProjectsArray(fullname);
		taseditorWindow.redraw();
		taseditorWindow.updateCaption();
		return true;
	} else
	{
		// failed to load
		taseditorWindow.redraw();
		taseditorWindow.updateCaption();
		return false;
	}
}

// Saves current project
bool saveProjectAs(bool save_compact)
{
	const char filter[] = "TAS Editor Projects (*.fm3)\0*.fm3\0All Files (*.*)\0*.*\0\0";
	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = taseditorWindow.hwndTASEditor;
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = "Save TAS Editor Project As...";
	ofn.lpstrFilter = filter;

	char nameo[2048];
	if (project.getProjectName().empty())
	{
		// suggest ROM name for this project
		strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());	//convert | to . for archive filenames
		// add .fm3 extension
		strncat(nameo, ".fm3", 2047);
	} else
	{
		// suggest current name
		strncpy(nameo, project.getProjectName().c_str(), 2047);
	}

	ofn.lpstrFile = nameo;
	ofn.lpstrDefExt = "fm3";
	ofn.nMaxFile = 2048;
	ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
	string initdir = FCEU_GetPath(FCEUMKF_MOVIE);			// initial directory
	ofn.lpstrInitialDir = initdir.c_str();

	if (GetSaveFileName(&ofn))								// if it is a valid filename
	{
		project.renameProject(nameo, true);
		if (save_compact)
			project.save(nameo, taseditorConfig.saveCompact_SaveInBinary, taseditorConfig.saveCompact_SaveMarkers, taseditorConfig.saveCompact_SaveBookmarks, taseditorConfig.saveCompact_GreenzoneSavingMode, taseditorConfig.saveCompact_SaveHistory, taseditorConfig.saveCompact_SavePianoRoll, taseditorConfig.saveCompact_SaveSelection);
		else
			project.save(nameo, taseditorConfig.projectSavingOptions_SaveInBinary, taseditorConfig.projectSavingOptions_SaveMarkers, taseditorConfig.projectSavingOptions_SaveBookmarks, taseditorConfig.projectSavingOptions_GreenzoneSavingMode, taseditorConfig.projectSavingOptions_SaveHistory, taseditorConfig.projectSavingOptions_SavePianoRoll, taseditorConfig.projectSavingOptions_SaveSelection);
		taseditorWindow.updateRecentProjectsArray(nameo);
		// saved successfully - remove * mark from caption
		taseditorWindow.updateCaption();
	} else return false;
	return true;
}
bool saveProject(bool save_compact)
{
	if (project.getProjectFile().empty())
	{
		return saveProjectAs(save_compact);
	} else
	{
		if (save_compact)
			project.save(0, taseditorConfig.saveCompact_SaveInBinary, taseditorConfig.saveCompact_SaveMarkers, taseditorConfig.saveCompact_SaveBookmarks, taseditorConfig.saveCompact_GreenzoneSavingMode, taseditorConfig.saveCompact_SaveHistory, taseditorConfig.saveCompact_SavePianoRoll, taseditorConfig.saveCompact_SaveSelection);
		else
			project.save(0, taseditorConfig.projectSavingOptions_SaveInBinary, taseditorConfig.projectSavingOptions_SaveMarkers, taseditorConfig.projectSavingOptions_SaveBookmarks, taseditorConfig.projectSavingOptions_GreenzoneSavingMode, taseditorConfig.projectSavingOptions_SaveHistory, taseditorConfig.projectSavingOptions_SavePianoRoll, taseditorConfig.projectSavingOptions_SaveSelection);
		taseditorWindow.updateCaption();
	}
	return true;
}
// --------------------------------------------------
void SaveCompact_SetDialogItems(HWND hwndDlg)
{
	CheckDlgButton(hwndDlg, IDC_CHECK_BINARY, taseditorConfig.saveCompact_SaveInBinary?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndDlg, IDC_CHECK_MARKERS, taseditorConfig.saveCompact_SaveMarkers?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndDlg, IDC_CHECK_BOOKMARKS, taseditorConfig.saveCompact_SaveBookmarks?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndDlg, IDC_CHECK_HISTORY, taseditorConfig.saveCompact_SaveHistory?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndDlg, IDC_CHECK_PIANO_ROLL, taseditorConfig.saveCompact_SavePianoRoll?BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hwndDlg, IDC_CHECK_SELECTION, taseditorConfig.saveCompact_SaveSelection?BST_CHECKED : BST_UNCHECKED);
	CheckRadioButton(hwndDlg, IDC_RADIO1, IDC_RADIO4, IDC_RADIO1 + (taseditorConfig.saveCompact_GreenzoneSavingMode % GREENZONE_SAVING_MODES_TOTAL));
}
void SaveCompact_GetDialogItems(HWND hwndDlg)
{
	taseditorConfig.saveCompact_SaveInBinary = (SendDlgItemMessage(hwndDlg, IDC_CHECK_BINARY, BM_GETCHECK, 0, 0) == BST_CHECKED);
	taseditorConfig.saveCompact_SaveMarkers = (SendDlgItemMessage(hwndDlg, IDC_CHECK_MARKERS, BM_GETCHECK, 0, 0) == BST_CHECKED);
	taseditorConfig.saveCompact_SaveBookmarks = (SendDlgItemMessage(hwndDlg, IDC_CHECK_BOOKMARKS, BM_GETCHECK, 0, 0) == BST_CHECKED);
	taseditorConfig.saveCompact_SaveHistory = (SendDlgItemMessage(hwndDlg, IDC_CHECK_HISTORY, BM_GETCHECK, 0, 0) == BST_CHECKED);
	taseditorConfig.saveCompact_SavePianoRoll = (SendDlgItemMessage(hwndDlg, IDC_CHECK_PIANO_ROLL, BM_GETCHECK, 0, 0) == BST_CHECKED);
	taseditorConfig.saveCompact_SaveSelection = (SendDlgItemMessage(hwndDlg, IDC_CHECK_SELECTION, BM_GETCHECK, 0, 0) == BST_CHECKED);
	if (SendDlgItemMessage(hwndDlg, IDC_RADIO1, BM_GETCHECK, 0, 0) == BST_CHECKED)
		taseditorConfig.saveCompact_GreenzoneSavingMode = GREENZONE_SAVING_MODE_ALL;
	else if (SendDlgItemMessage(hwndDlg, IDC_RADIO2, BM_GETCHECK, 0, 0) == BST_CHECKED)
		taseditorConfig.saveCompact_GreenzoneSavingMode = GREENZONE_SAVING_MODE_16TH;
	else if (SendDlgItemMessage(hwndDlg, IDC_RADIO3, BM_GETCHECK, 0, 0) == BST_CHECKED)
		taseditorConfig.saveCompact_GreenzoneSavingMode = GREENZONE_SAVING_MODE_MARKED;
	else
		taseditorConfig.saveCompact_GreenzoneSavingMode = GREENZONE_SAVING_MODE_NO;
}
BOOL CALLBACK SaveCompactProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG:
		{
			SetWindowPos(hwndDlg, 0, taseditorConfig.windowX + 100, taseditorConfig.windowY + 200, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
			SaveCompact_SetDialogItems(hwndDlg);
			return TRUE;
		}
		case WM_COMMAND:
		{
			switch (LOWORD(wParam))
			{
				case IDOK:
					SaveCompact_GetDialogItems(hwndDlg);
					EndDialog(hwndDlg, 1);
					return TRUE;
				case IDCANCEL:
					SaveCompact_GetDialogItems(hwndDlg);
					EndDialog(hwndDlg, 0);
					return TRUE;
			}
			break;
		}
		case WM_CLOSE:
		case WM_QUIT:
		{
			SaveCompact_GetDialogItems(hwndDlg);
			break;
		}
	}
	return FALSE; 
}
void saveCompact()
{
	if (DialogBox(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_SAVECOMPACT), taseditorWindow.hwndTASEditor, SaveCompactProc) > 0)
	{
		const char filter[] = "TAS Editor Projects (*.fm3)\0*.fm3\0All Files (*.*)\0*.*\0\0";
		OPENFILENAME ofn;
		memset(&ofn, 0, sizeof(ofn));
		ofn.lStructSize = sizeof(ofn);
		ofn.hwndOwner = taseditorWindow.hwndTASEditor;
		ofn.hInstance = fceu_hInstance;
		ofn.lpstrTitle = "Save Compact";
		ofn.lpstrFilter = filter;

		char nameo[2048];
		if (project.getProjectName().empty())
			// suggest ROM name for this project
			strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());	//convert | to . for archive filenames
		else
			// suggest current name
			strcpy(nameo, project.getProjectName().c_str());
		// add "-compact" if there's no such suffix
		if (!strstr(nameo, "-compact"))
			strcat(nameo, "-compact");

		ofn.lpstrFile = nameo;
		ofn.lpstrDefExt = "fm3";
		ofn.nMaxFile = 2048;
		ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
		string initdir = FCEU_GetPath(FCEUMKF_MOVIE);			// initial directory
		ofn.lpstrInitialDir = initdir.c_str();

		if (GetSaveFileName(&ofn))
		{
			project.save(nameo, taseditorConfig.saveCompact_SaveInBinary, taseditorConfig.saveCompact_SaveMarkers, taseditorConfig.saveCompact_SaveBookmarks, taseditorConfig.saveCompact_GreenzoneSavingMode, taseditorConfig.saveCompact_SaveHistory, taseditorConfig.saveCompact_SavePianoRoll, taseditorConfig.saveCompact_SaveSelection);
			taseditorWindow.updateCaption();
		}
	}
}
// --------------------------------------------------
// returns false if user doesn't want to exit
bool askToSaveProject()
{
	bool changesFound = false;
	if (project.getProjectChanged())
		changesFound = true;

	// ask saving project
	if (changesFound)
	{
		int answer = MessageBox(taseditorWindow.hwndTASEditor, "Save Project changes?", "TAS Editor", MB_YESNOCANCEL);
		if (answer == IDYES)
			return saveProject();
		return (answer != IDCANCEL);
	}
	return true;
}

void importInputData()
{
	const char filter[] = "FCEUX Movie Files (*.fm2), TAS Editor Projects (*.fm3)\0*.fm2;*.fm3\0All Files (*.*)\0*.*\0\0";
	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = taseditorWindow.hwndTASEditor;
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = "Import";
	ofn.lpstrFilter = filter;
	char nameo[2048] = {0};
	ofn.lpstrFile = nameo;							
	ofn.nMaxFile = 2048;
	ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT|OFN_FILEMUSTEXIST;
	string initdir = FCEU_GetPath(FCEUMKF_MOVIE);	
	ofn.lpstrInitialDir = initdir.c_str();

	if (GetOpenFileName(&ofn))
	{							
		EMUFILE_FILE ifs(nameo, "rb");
		// Load Input to temporary moviedata
		MovieData md;
		if (LoadFM2(md, &ifs, ifs.size(), false))
		{
			// loaded successfully, now register Input changes
			char drv[512], dir[512], name[1024], ext[512];
			splitpath(nameo, drv, dir, name, ext);
			strcat(name, ext);
			int result = history.registerImport(md, name);
			if (result >= 0)
			{
				greenzone.invalidateAndUpdatePlayback(result);
				greenzone.lagLog.invalidateFromFrame(result);
				// keep current snapshot laglog in touch
				history.getCurrentSnapshot().laglog.invalidateFromFrame(result);
			} else
			{
				MessageBox(taseditorWindow.hwndTASEditor, "Imported movie has the same Input.\nNo changes were made.", "TAS Editor", MB_OK);
			}
		} else
		{
			FCEUD_PrintError("Error loading movie data!");
		}
	}
}

BOOL CALLBACK aboutWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG:
		{
			SendMessage(GetDlgItem(hWnd, IDC_TASEDITOR_NAME), WM_SETFONT, (WPARAM)pianoRoll.hTaseditorAboutFont, 0);
			break;
		}
		case WM_COMMAND:
		{
			switch (LOWORD(wParam))
			{
				case IDCANCEL:
					EndDialog(hWnd, 0);
					return TRUE;
			}
			break;
		}
	}
	return FALSE; 
}

BOOL CALLBACK savingOptionsWndProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG:
		{
			CheckDlgButton(hwndDlg, IDC_AUTOSAVE_PROJECT, taseditorConfig.autosaveEnabled?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_SILENT_AUTOSAVE, taseditorConfig.autosaveSilent?BST_CHECKED : BST_UNCHECKED);
			char buf[16] = {0};
			sprintf(buf, "%u", taseditorConfig.autosavePeriod);
			SetDlgItemText(hwndDlg, IDC_AUTOSAVE_PERIOD, buf);
			CheckDlgButton(hwndDlg, IDC_CHECK_BINARY, taseditorConfig.projectSavingOptions_SaveInBinary?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_MARKERS, taseditorConfig.projectSavingOptions_SaveMarkers?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_BOOKMARKS, taseditorConfig.projectSavingOptions_SaveBookmarks?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_HISTORY, taseditorConfig.projectSavingOptions_SaveHistory?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_PIANO_ROLL, taseditorConfig.projectSavingOptions_SavePianoRoll?BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_SELECTION, taseditorConfig.projectSavingOptions_SaveSelection?BST_CHECKED : BST_UNCHECKED);
			CheckRadioButton(hwndDlg, IDC_RADIO1, IDC_RADIO4, IDC_RADIO1 + (taseditorConfig.projectSavingOptions_GreenzoneSavingMode % GREENZONE_SAVING_MODES_TOTAL));
			return TRUE;
		}
		case WM_COMMAND:
		{
			switch (LOWORD(wParam))
			{
				case IDOK:
				{
					taseditorConfig.autosaveEnabled = (SendDlgItemMessage(hwndDlg, IDC_AUTOSAVE_PROJECT, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.autosaveSilent = (SendDlgItemMessage(hwndDlg, IDC_SILENT_AUTOSAVE, BM_GETCHECK, 0, 0) == BST_CHECKED);
					char buf[16] = {0};
					GetDlgItemText(hwndDlg, IDC_AUTOSAVE_PERIOD, buf, 16 * sizeof(char));
					int new_period = taseditorConfig.autosavePeriod;
					sscanf(buf, "%u", &new_period);
					if (new_period < AUTOSAVE_PERIOD_MIN)
						new_period = AUTOSAVE_PERIOD_MIN;
					else if (new_period > AUTOSAVE_PERIOD_MAX)
						new_period = AUTOSAVE_PERIOD_MAX;
					taseditorConfig.autosavePeriod = new_period;
					project.sheduleNextAutosave();	
					taseditorConfig.projectSavingOptions_SaveInBinary = (SendDlgItemMessage(hwndDlg, IDC_CHECK_BINARY, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.projectSavingOptions_SaveMarkers = (SendDlgItemMessage(hwndDlg, IDC_CHECK_MARKERS, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.projectSavingOptions_SaveBookmarks = (SendDlgItemMessage(hwndDlg, IDC_CHECK_BOOKMARKS, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.projectSavingOptions_SaveHistory = (SendDlgItemMessage(hwndDlg, IDC_CHECK_HISTORY, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.projectSavingOptions_SavePianoRoll = (SendDlgItemMessage(hwndDlg, IDC_CHECK_PIANO_ROLL, BM_GETCHECK, 0, 0) == BST_CHECKED);
					taseditorConfig.projectSavingOptions_SaveSelection = (SendDlgItemMessage(hwndDlg, IDC_CHECK_SELECTION, BM_GETCHECK, 0, 0) == BST_CHECKED);
					if (SendDlgItemMessage(hwndDlg, IDC_RADIO1, BM_GETCHECK, 0, 0) == BST_CHECKED)
						taseditorConfig.projectSavingOptions_GreenzoneSavingMode = GREENZONE_SAVING_MODE_ALL;
					else if (SendDlgItemMessage(hwndDlg, IDC_RADIO2, BM_GETCHECK, 0, 0) == BST_CHECKED)
						taseditorConfig.projectSavingOptions_GreenzoneSavingMode = GREENZONE_SAVING_MODE_16TH;
					else if (SendDlgItemMessage(hwndDlg, IDC_RADIO3, BM_GETCHECK, 0, 0) == BST_CHECKED)
						taseditorConfig.projectSavingOptions_GreenzoneSavingMode = GREENZONE_SAVING_MODE_MARKED;
					else
						taseditorConfig.projectSavingOptions_GreenzoneSavingMode = GREENZONE_SAVING_MODE_NO;
					EndDialog(hwndDlg, 1);
					return TRUE;
				}
				case IDCANCEL:
					EndDialog(hwndDlg, 0);
					return TRUE;
			}
			break;
		}
	}
	return FALSE; 
}

BOOL CALLBACK ExportProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG:
			SetWindowPos(hwndDlg, 0, taseditorConfig.windowX + 100, taseditorConfig.windowY + 200, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
			switch (taseditorConfig.lastExportedInputType)
			{
			case INPUT_TYPE_1P:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_1PLAYER), BST_CHECKED);
					break;
				}
			case INPUT_TYPE_2P:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_2PLAYERS), BST_CHECKED);
					break;
				}
			case INPUT_TYPE_FOURSCORE:
				{
					Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_FOURSCORE), BST_CHECKED);
					break;
				}
			}
			CheckDlgButton(hwndDlg, IDC_NOTES_TO_SUBTITLES, taseditorConfig.lastExportedSubtitlesStatus?MF_CHECKED : MF_UNCHECKED);
			return TRUE;
		case WM_COMMAND:
			switch (LOWORD(wParam))
			{
				case IDC_RADIO_1PLAYER:
					taseditorConfig.lastExportedInputType = INPUT_TYPE_1P;
					break;
				case IDC_RADIO_2PLAYERS:
					taseditorConfig.lastExportedInputType = INPUT_TYPE_2P;
					break;
				case IDC_RADIO_FOURSCORE:
					taseditorConfig.lastExportedInputType = INPUT_TYPE_FOURSCORE;
					break;
				case IDC_NOTES_TO_SUBTITLES:
					taseditorConfig.lastExportedSubtitlesStatus ^= 1;
					CheckDlgButton(hwndDlg, IDC_NOTES_TO_SUBTITLES, taseditorConfig.lastExportedSubtitlesStatus?MF_CHECKED : MF_UNCHECKED);
					break;
				case IDOK:
					EndDialog(hwndDlg, 1);
					return TRUE;
				case IDCANCEL:
					EndDialog(hwndDlg, 0);
					return TRUE;
			}
			break;
	}
	return FALSE; 
} 

void exportToFM2()
{
	if (DialogBox(fceu_hInstance, MAKEINTRESOURCE(IDD_TASEDITOR_EXPORT), taseditorWindow.hwndTASEditor, ExportProc) > 0)
	{
		const char filter[] = "FCEUX Movie File (*.fm2)\0*.fm2\0All Files (*.*)\0*.*\0\0";
		char fname[2048];
		strcpy(fname, project.getFM2Name().c_str());
		OPENFILENAME ofn;
		memset(&ofn, 0, sizeof(ofn));
		ofn.lStructSize = sizeof(ofn);
		ofn.hwndOwner = taseditorWindow.hwndTASEditor;
		ofn.hInstance = fceu_hInstance;
		ofn.lpstrTitle = "Export to FM2";
		ofn.lpstrFilter = filter;
		ofn.lpstrFile = fname;
		ofn.lpstrDefExt = "fm2";
		ofn.nMaxFile = 2048;
		ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
		std::string initdir = FCEU_GetPath(FCEUMKF_MOVIE);
		ofn.lpstrInitialDir = initdir.c_str();
		if (GetSaveFileName(&ofn))
		{
			EMUFILE* osRecordingMovie = FCEUD_UTF8_fstream(fname, "wb");
			// create copy of current movie data
			MovieData temp_md = currMovieData;
			// modify the copy according to selected type of export
			setInputType(temp_md, taseditorConfig.lastExportedInputType);
			temp_md.loadFrameCount = -1;
			// also add subtitles if needed
			if (taseditorConfig.lastExportedSubtitlesStatus)
			{
				// convert Marker Notes to Movie Subtitles
				char framenum[11];
				std::string subtitle;
				int markerID;
				for (int i = 0; i < markersManager.getMarkersArraySize(); ++i)
				{
					markerID = markersManager.getMarkerAtFrame(i);
					if (markerID)
					{
						_itoa(i, framenum, 10);
						strcat(framenum, " ");
						subtitle = framenum;
						subtitle.append(markersManager.getNoteCopy(markerID));
						temp_md.subtitles.push_back(subtitle);
					}
				}
			}
			// dump to disk
			temp_md.dump(osRecordingMovie, false);
			delete osRecordingMovie;
			osRecordingMovie = 0;
		}
	}
}

int getInputType(MovieData& md)
{
	if (md.fourscore)
		return INPUT_TYPE_FOURSCORE;
	else if (md.ports[0] == md.ports[1] == SI_GAMEPAD)
		return INPUT_TYPE_2P;
	else
		return INPUT_TYPE_1P;
}
void setInputType(MovieData& md, int newInputType)
{
	switch (newInputType)
	{
		case INPUT_TYPE_1P:
		{
			md.fourscore = false;
			md.ports[0] = SI_GAMEPAD;
			md.ports[1] = SI_NONE;
			break;
		}
		case INPUT_TYPE_2P:
		{
			md.fourscore = false;
			md.ports[0] = SI_GAMEPAD;
			md.ports[1] = SI_GAMEPAD;
			break;
		}
		case INPUT_TYPE_FOURSCORE:
		{
			md.fourscore = true;
			md.ports[0] = SI_GAMEPAD;
			md.ports[1] = SI_GAMEPAD;
			break;
		}
	}
}

void applyMovieInputConfig()
{
	// update FCEUX input config
	FCEUD_SetInput(currMovieData.fourscore, currMovieData.microphone, (ESI)currMovieData.ports[0], (ESI)currMovieData.ports[1], (ESIFC)currMovieData.ports[2]);
	// update PAL flag
	pal_emulation = currMovieData.palFlag;
	if (pal_emulation)
		dendy = 0;
	FCEUI_SetVidSystem(pal_emulation);
	RefreshThrottleFPS();
	PushCurrentVideoSettings();
	// update PPU type
	newppu = currMovieData.PPUflag;
	SetMainWindowText();
	// return focus to TAS Editor window
	SetFocus(taseditorWindow.hwndTASEditor);
}

// this getter contains formula to decide whether to record or replay movie
bool isTaseditorRecording()
{
	if (movie_readonly || playback.getPauseFrame() >= 0 || (taseditorConfig.oldControlSchemeForBranching && !recorder.stateWasLoadedInReadWriteMode))
		return false;		// replay
	return true;			// record
}
void recordInputByTaseditor()
{
	recorder.recordInput();
}

// this gate handles some FCEUX hotkeys (EMUCMD)
void handleEmuCmdByTaseditor(int command)
{
	switch (command)
	{
		case EMUCMD_SAVE_SLOT_0:
		case EMUCMD_SAVE_SLOT_1:
		case EMUCMD_SAVE_SLOT_2:
		case EMUCMD_SAVE_SLOT_3:
		case EMUCMD_SAVE_SLOT_4:
		case EMUCMD_SAVE_SLOT_5:
		case EMUCMD_SAVE_SLOT_6:
		case EMUCMD_SAVE_SLOT_7:
		case EMUCMD_SAVE_SLOT_8:
		case EMUCMD_SAVE_SLOT_9:
		{
			if (taseditorConfig.oldControlSchemeForBranching)
				bookmarks.command(COMMAND_SELECT, command - EMUCMD_SAVE_SLOT_0);
			else
				bookmarks.command(COMMAND_JUMP, command - EMUCMD_SAVE_SLOT_0);
			break;
		}
		case EMUCMD_SAVE_SLOT_NEXT:
		{
			int slot = bookmarks.getSelectedSlot() + 1;
			if (slot >= TOTAL_BOOKMARKS) slot = 0;
			bookmarks.command(COMMAND_SELECT, slot);
			break;
		}
		case EMUCMD_SAVE_SLOT_PREV:
		{
			int slot = bookmarks.getSelectedSlot() - 1;
			if (slot < 0) slot = TOTAL_BOOKMARKS - 1;
			bookmarks.command(COMMAND_SELECT, slot);
			break;
		}
		case EMUCMD_SAVE_STATE:
			bookmarks.command(COMMAND_SET);
			break;
		case EMUCMD_SAVE_STATE_SLOT_0:
		case EMUCMD_SAVE_STATE_SLOT_1:
		case EMUCMD_SAVE_STATE_SLOT_2:
		case EMUCMD_SAVE_STATE_SLOT_3:
		case EMUCMD_SAVE_STATE_SLOT_4:
		case EMUCMD_SAVE_STATE_SLOT_5:
		case EMUCMD_SAVE_STATE_SLOT_6:
		case EMUCMD_SAVE_STATE_SLOT_7:
		case EMUCMD_SAVE_STATE_SLOT_8:
		case EMUCMD_SAVE_STATE_SLOT_9:
			bookmarks.command(COMMAND_SET, command - EMUCMD_SAVE_STATE_SLOT_0);
			break;
		case EMUCMD_LOAD_STATE:
			bookmarks.command(COMMAND_DEPLOY);
			break;
		case EMUCMD_LOAD_STATE_SLOT_0:
		case EMUCMD_LOAD_STATE_SLOT_1:
		case EMUCMD_LOAD_STATE_SLOT_2:
		case EMUCMD_LOAD_STATE_SLOT_3:
		case EMUCMD_LOAD_STATE_SLOT_4:
		case EMUCMD_LOAD_STATE_SLOT_5:
		case EMUCMD_LOAD_STATE_SLOT_6:
		case EMUCMD_LOAD_STATE_SLOT_7:
		case EMUCMD_LOAD_STATE_SLOT_8:
		case EMUCMD_LOAD_STATE_SLOT_9:
			bookmarks.command(COMMAND_DEPLOY, command - EMUCMD_LOAD_STATE_SLOT_0);
			break;
		case EMUCMD_MOVIE_PLAY_FROM_BEGINNING:
			movie_readonly = true;
			playback.jump(0);
			break;
		case EMUCMD_RELOAD:
			taseditorWindow.loadRecentProject(0);
			break;
		case EMUCMD_TASEDITOR_RESTORE_PLAYBACK:
			playback.restoreLastPosition();
			break;
		case EMUCMD_TASEDITOR_CANCEL_SEEKING:
			playback.cancelSeeking();
			break;
		case EMUCMD_TASEDITOR_SWITCH_AUTORESTORING:
			taseditorConfig.autoRestoreLastPlaybackPosition ^= 1;
			taseditorWindow.updateCheckedItems();
			break;
		case EMUCMD_TASEDITOR_SWITCH_MULTITRACKING:
			recorder.multitrackRecordingJoypadNumber++;
			if (recorder.multitrackRecordingJoypadNumber > joysticksPerFrame[getInputType(currMovieData)])
				recorder.multitrackRecordingJoypadNumber = 0;
			break;
		case EMUCMD_TASEDITOR_RUN_MANUAL_LUA:
			// the function will be called in next window update
			mustCallManualLuaFunction = true;
			break;

	}
}
// these functions allow/disallow some FCEUX hotkeys and TAS Editor accelerators
void enableGeneralKeyboardInput()
{
	taseditorEnableAcceleratorKeys = true;
	// set "Background TAS Editor input"
	KeyboardSetBackgroundAccessBit(KEYBACKACCESS_TASEDITOR);
	JoystickSetBackgroundAccessBit(JOYBACKACCESS_TASEDITOR);
}
void disableGeneralKeyboardInput()
{
	taseditorEnableAcceleratorKeys = false;
	// clear "Background TAS Editor input"
	KeyboardClearBackgroundAccessBit(KEYBACKACCESS_TASEDITOR);
	JoystickClearBackgroundAccessBit(JOYBACKACCESS_TASEDITOR);
}
