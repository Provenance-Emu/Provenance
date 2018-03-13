/* ---------------------------------------------------------------------------------
Implementation file of Bookmarks class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Bookmarks/Branches - Manager of Bookmarks
[Single instance]

* stores 10 Bookmarks
* implements all operations with Bookmarks: initialization, setting Bookmarks, jumping to Bookmarks, deploying Branches
* saves and loads the data from a project file. On error: resets all Bookmarks and Branches
* implements the working of Bookmarks List: creating, redrawing, mouseover, clicks
* regularly updates flashings in Bookmarks List
* on demand: updates colors of rows in Bookmarks List, reflecting conditions of respective Piano Roll rows
* stores resources: save id, ids of commands, captions for panel, gradients for flashings, id of default slot
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "utils/xstring.h"
#include "zlib.h"

#pragma comment(lib, "msimg32.lib")

LRESULT APIENTRY BookmarksListWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC hwndBookmarksList_oldWndProc;

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern POPUP_DISPLAY popupDisplay;
extern PLAYBACK playback;
extern RECORDER recorder;
extern SELECTION selection;
extern GREENZONE greenzone;
extern TASEDITOR_PROJECT project;
extern HISTORY history;
extern PIANO_ROLL pianoRoll;
extern MARKERS_MANAGER markersManager;
extern BRANCHES branches;

// resources
char bookmarks_save_id[BOOKMARKS_ID_LEN] = "BOOKMARKS";
char bookmarks_skipsave_id[BOOKMARKS_ID_LEN] = "BOOKMARKX";
char bookmarksCaption[3][23] = { " Bookmarks ", " Bookmarks / Branches ", " Branches " };
// color tables for flashing when saving/loading bookmarks
COLORREF bookmark_flash_colors[TOTAL_BOOKMARK_COMMANDS][FLASH_PHASE_MAX+1] = {
	// set
	//0x122330, 0x1b3541, 0x254753, 0x2e5964, 0x376b75, 0x417e87, 0x4a8f97, 0x53a1a8, 0x5db3b9, 0x66c5cb, 0x70d7dc, 0x79e9ed, 
	0x0d1241, 0x111853, 0x161e64, 0x1a2575, 0x1f2b87, 0x233197, 0x2837a8, 0x2c3db9, 0x3144cb, 0x354adc, 0x3a50ed, 0x3f57ff, 
	// jump
	0x14350f, 0x1c480f, 0x235a0f, 0x2a6c0f, 0x317f10, 0x38910f, 0x3fa30f, 0x46b50f, 0x4dc80f, 0x54da0f, 0x5bec0f, 0x63ff10, 
	// deploy
	0x43171d, 0x541d21, 0x652325, 0x762929, 0x872f2c, 0x983530, 0xa93b34, 0xba4137, 0xcb463b, 0xdc4c3f, 0xed5243, 0xff5947 };

BOOKMARKS::BOOKMARKS()
{
	// fill TrackMouseEvent struct
	tme.cbSize = sizeof(tme);
	tme.dwFlags = TME_LEAVE;
	tme.hwndTrack = NULL;
	tmeList.cbSize = sizeof(tme);
	tmeList.dwFlags = TME_LEAVE;
	tmeList.hwndTrack = NULL;
}

void BOOKMARKS::init()
{
	free();
	hwndBookmarksList = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_BOOKMARKSLIST);
	hwndBranchesBitmap = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_BRANCHES_BITMAP);
	hwndBookmarks = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_BOOKMARKS_BOX);

	// prepare bookmarks listview
	ListView_SetExtendedListViewStyleEx(hwndBookmarksList, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES);
	// subclass the listview
	hwndBookmarksList_oldWndProc = (WNDPROC)SetWindowLong(hwndBookmarksList, GWL_WNDPROC, (LONG)BookmarksListWndProc);
	// setup images for the listview
	hImgList = ImageList_Create(11, 13, ILC_COLOR8 | ILC_MASK, 1, 1);
	HBITMAP bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP0));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP1));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP2));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP3));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP4));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP5));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP6));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP7));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP8));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP9));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP10));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP11));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP12));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP13));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP14));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP15));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP16));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP17));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP18));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP19));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED0));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED1));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED2));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED3));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED4));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED5));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED6));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED7));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED8));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED9));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED10));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED11));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED12));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED13));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED14));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED15));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED16));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED17));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED18));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BITMAP_SELECTED19));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	ListView_SetImageList(hwndBookmarksList, hImgList, LVSIL_SMALL);
	// setup columns
	LVCOLUMN lvc;
	// icons column
	lvc.mask = LVCF_WIDTH;
	lvc.cx = BOOKMARKSLIST_COLUMN_ICONS_WIDTH;
	ListView_InsertColumn(hwndBookmarksList, 0, &lvc);
	// keyframe column
	lvc.mask = LVCF_WIDTH | LVCF_FMT;
	lvc.fmt = LVCFMT_CENTER;
	lvc.cx = BOOKMARKSLIST_COLUMN_FRAMENUM_WIDTH;
	ListView_InsertColumn(hwndBookmarksList, 1, &lvc);
	// time column
	lvc.cx = BOOKMARKSLIST_COLUMN_TIMESTAMP_WIDTH;
	ListView_InsertColumn(hwndBookmarksList, 2, &lvc);
	// create 10 rows
	ListView_SetItemCountEx(hwndBookmarksList, TOTAL_BOOKMARKS, LVSICF_NOSCROLL | LVSICF_NOINVALIDATEALL);

	reset();
	selectedSlot = DEFAULT_SLOT;
	// find the top/height of the "Time" cell of the 1st row (for mouseover hittest calculations)
	RECT temp_rect, wrect;
	if (ListView_GetSubItemRect(hwndBookmarksList, 0, 2, LVIR_BOUNDS, &temp_rect) && temp_rect.bottom != temp_rect.top)
	{
		listTopMargin = temp_rect.top;
		listRowLeft = temp_rect.left;
		listRowHeight = temp_rect.bottom - temp_rect.top;
	} else
	{
		// couldn't get rect, set default values
		listTopMargin = 0;
		listRowLeft = BOOKMARKSLIST_COLUMN_ICONS_WIDTH + BOOKMARKSLIST_COLUMN_FRAMENUM_WIDTH;
		listRowHeight = 14;
	}
	// calculate the needed height of client area (so that all 10 rows fir the screen)
	int total_list_height = listTopMargin + listRowHeight * TOTAL_BOOKMARKS;
	// find the difference between Bookmarks List window and Bookmarks List client area
	GetWindowRect(hwndBookmarksList, &wrect);
	GetClientRect(hwndBookmarksList, &temp_rect);
	total_list_height += (wrect.bottom - wrect.top) - (temp_rect.bottom - temp_rect.top);
	// change the height
	taseditorWindow.changeBookmarksListHeight(total_list_height);



	redrawBookmarksSectionCaption();
}
void BOOKMARKS::free()
{
	bookmarksArray.resize(0);
	if (hImgList)
	{
		ImageList_Destroy(hImgList);
		hImgList = 0;
	}
}
void BOOKMARKS::reset()
{
	// delete all commands if there are any
	commands.resize(0);
	// init bookmarks
	bookmarksArray.resize(0);
	bookmarksArray.resize(TOTAL_BOOKMARKS);
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		bookmarksArray[i].init();
	reset_vars();
}
void BOOKMARKS::reset_vars()
{
	mouseX = mouseY = -1;
	itemUnderMouse = ITEM_UNDER_MOUSE_NONE;
	mouseOverBranchesBitmap = false;
	mustCheckItemUnderMouse = true;
	bookmarkLeftclicked = bookmarkRightclicked = ITEM_UNDER_MOUSE_NONE;
	nextFlashUpdateTime = clock() + BOOKMARKS_FLASH_TICK;
}

void BOOKMARKS::update()
{
	// execute all commands accumulated during last frame
	for (int i = 0; (i + 1) < (int)commands.size(); )	// FIFO
	{
		int command_id = commands[i++];
		int slot = commands[i++];
		switch (command_id)
		{
			case COMMAND_SET:
				set(slot);
				break;
			case COMMAND_JUMP:
				jump(slot);
				break;
			case COMMAND_DEPLOY:
				deploy(slot);
				break;
			case COMMAND_SELECT:
				if (selectedSlot != slot)
				{
					int old_selected_slot = selectedSlot;
					selectedSlot = slot;
					redrawBookmark(old_selected_slot);
					redrawBookmark(selectedSlot);
				}
				break;
		}
	}
	commands.resize(0);

	// once per 100 milliseconds update bookmark flashes
	if (clock() > nextFlashUpdateTime)
	{
		nextFlashUpdateTime = clock() + BOOKMARKS_FLASH_TICK;
		for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		{
			if (bookmarkRightclicked == i || bookmarkLeftclicked == i)
			{
				if (bookmarksArray[i].flashPhase != FLASH_PHASE_BUTTONHELD)
				{
					bookmarksArray[i].flashPhase = FLASH_PHASE_BUTTONHELD;
					redrawBookmark(i);
					branches.mustRedrawBranchesBitmap = true;		// because border of branch digit has changed
				}
			} else
			{
				if (bookmarksArray[i].flashPhase > 0)
				{
					bookmarksArray[i].flashPhase--;
					redrawBookmark(i);
					branches.mustRedrawBranchesBitmap = true;		// because border of branch digit has changed
				}
			}
		}
	}

	// controls
	if (mustCheckItemUnderMouse)
	{
		if (editMode == EDIT_MODE_BRANCHES)
			itemUnderMouse = branches.findItemUnderMouse(mouseX, mouseY);
		else if (editMode == EDIT_MODE_BOTH)
			itemUnderMouse = findItemUnderMouse();
		else
			itemUnderMouse = ITEM_UNDER_MOUSE_NONE;
		mustCheckItemUnderMouse = false;
	}
}

// stores commands in array for update() function
void BOOKMARKS::command(int command_id, int slot)
{
	if (slot < 0)
		slot = selectedSlot;
	if (slot >= 0 && slot < TOTAL_BOOKMARKS)
	{
		commands.push_back(command_id);
		commands.push_back(slot);
	}
}

void BOOKMARKS::set(int slot)
{
	if (slot < 0 || slot >= TOTAL_BOOKMARKS) return;

	// First save changes in edited note (in case it's being currently edited)
	markersManager.updateEditedMarkerNote();

	int previous_frame = bookmarksArray[slot].snapshot.keyFrame;
	if (bookmarksArray[slot].isDifferentFromCurrentMovie())
	{
		BOOKMARK backup_copy(bookmarksArray[slot]);
		bookmarksArray[slot].set();
		// rebuild Branches Tree
		int old_current_branch = branches.getCurrentBranch();
		branches.handleBookmarkSet(slot);
		if (slot != old_current_branch && old_current_branch != ITEM_UNDER_MOUSE_CLOUD)
		{
			// current_branch was switched to slot, redraw Bookmarks List to change the color of digits
			pianoRoll.redrawRow(bookmarksArray[old_current_branch].snapshot.keyFrame);
			redrawChangedBookmarks(bookmarksArray[old_current_branch].snapshot.keyFrame);
		}
		// also redraw List rows
		if (previous_frame >= 0 && previous_frame != currFrameCounter)
		{
			pianoRoll.redrawRow(previous_frame);
			redrawChangedBookmarks(previous_frame);
		}
		pianoRoll.redrawRow(currFrameCounter);
		redrawChangedBookmarks(currFrameCounter);
		// if screenshot of the slot is currently shown - reinit and redraw the picture
		if (popupDisplay.currentlyDisplayedBookmark == slot)
			popupDisplay.currentlyDisplayedBookmark = ITEM_UNDER_MOUSE_NONE;

		history.registerBookmarkSet(slot, backup_copy, old_current_branch);
		mustCheckItemUnderMouse = true;
		FCEU_DispMessage("Branch %d saved.", 0, slot);
	}
}

void BOOKMARKS::jump(int slot)
{
	if (slot < 0 || slot >= TOTAL_BOOKMARKS) return;
	if (bookmarksArray[slot].notEmpty)
	{
		int frame = bookmarksArray[slot].snapshot.keyFrame;
		playback.jump(frame);
		bookmarksArray[slot].handleJump();
	}
}

void BOOKMARKS::deploy(int slot)
{
	recorder.stateWasLoadedInReadWriteMode = true;
	if (taseditorConfig.oldControlSchemeForBranching && movie_readonly)
	{
		jump(slot);
		return;
	}
	if (slot < 0 || slot >= TOTAL_BOOKMARKS) return;
	if (!bookmarksArray[slot].notEmpty) return;

	int keyframe = bookmarksArray[slot].snapshot.keyFrame;
	bool markers_changed = false;
	// revert Markers to the Bookmarked state
	if (bookmarksArray[slot].snapshot.areMarkersDifferentFromCurrentMarkers())
	{
		bookmarksArray[slot].snapshot.copyToCurrentMarkers();
		markers_changed = true;
	}
	// revert current movie data to the Bookmarked state
	if (taseditorConfig.branchesRestoreEntireMovie)
	{
		bookmarksArray[slot].snapshot.inputlog.toMovie(currMovieData);
	} else
	{
		// restore movie up to and not including bookmarked frame (simulating old TASing method)
		if (keyframe)
			bookmarksArray[slot].snapshot.inputlog.toMovie(currMovieData, 0, keyframe - 1);
		else
			currMovieData.truncateAt(0);
		// add empty frame at the end (at keyframe)
		currMovieData.insertEmpty(-1, 1);
	}

	int first_change = history.registerBranching(slot, markers_changed);	// this also reverts Greenzone's LagLog if needed
	if (first_change >= 0)
	{
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		pianoRoll.updateLinesCount();
		greenzone.invalidate(first_change);
		bookmarksArray[slot].handleDeploy();
	} else if (markers_changed)
	{
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		bookmarksArray[slot].handleDeploy();
	} else
	{
		// didn't change anything in current movie
		bookmarksArray[slot].handleJump();
	}

	// jump to the target (bookmarked frame)
	if (greenzone.isSavestateEmpty(keyframe))
		greenzone.writeSavestateForFrame(keyframe, bookmarksArray[slot].savestate);
	playback.jump(keyframe, true);
	// switch current branch to this branch
	int old_current_branch = branches.getCurrentBranch();
	branches.handleBookmarkDeploy(slot);
	if (slot != old_current_branch && old_current_branch != ITEM_UNDER_MOUSE_CLOUD)
	{
		pianoRoll.redrawRow(bookmarksArray[old_current_branch].snapshot.keyFrame);
		redrawChangedBookmarks(bookmarksArray[old_current_branch].snapshot.keyFrame);
		pianoRoll.redrawRow(keyframe);
		redrawChangedBookmarks(keyframe);
	}
	FCEU_DispMessage("Branch %d loaded.", 0, slot);
	pianoRoll.redraw();	// even though the Greenzone invalidation most likely have already sent the command to redraw
}

void BOOKMARKS::save(EMUFILE *os, bool really_save)
{
	if (really_save)
	{
		// write "BOOKMARKS" string
		os->fwrite(bookmarks_save_id, BOOKMARKS_ID_LEN);
		// write all 10 bookmarks
		for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
			bookmarksArray[i].save(os);
		// write branches
		branches.save(os);
	} else
	{
		// write "BOOKMARKX" string
		os->fwrite(bookmarks_skipsave_id, BOOKMARKS_ID_LEN);
	}
}
// returns true if couldn't load
bool BOOKMARKS::load(EMUFILE *is, unsigned int offset)
{
	if (offset)
	{
		if (is->fseek(offset, SEEK_SET)) goto error;
	} else
	{
		reset();
		branches.reset();
		return false;
	}
	// read "BOOKMARKS" string
	char save_id[BOOKMARKS_ID_LEN];
	if ((int)is->fread(save_id, BOOKMARKS_ID_LEN) < BOOKMARKS_ID_LEN) goto error;
	if (!strcmp(bookmarks_skipsave_id, save_id))
	{
		// string says to skip loading Bookmarks
		FCEU_printf("No Bookmarks in the file\n");
		reset();
		branches.reset();
		return false;
	}
	if (strcmp(bookmarks_save_id, save_id)) goto error;		// string is not valid
	// read all 10 bookmarks
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		if (bookmarksArray[i].load(is)) goto error;
	// read branches
	if (branches.load(is)) goto error;
	// all ok
	reset_vars();
	redrawBookmarksSectionCaption();
	return false;
error:
	FCEU_printf("Error loading Bookmarks\n");
	reset();
	branches.reset();
	return true;
}
// ----------------------------------------------------------
void BOOKMARKS::redrawBookmarksSectionCaption()
{
	int prev_edit_mode = editMode;
	if (taseditorConfig.displayBranchesTree)
	{
		editMode = EDIT_MODE_BRANCHES;
		ShowWindow(hwndBookmarksList, SW_HIDE);
		ShowWindow(hwndBranchesBitmap, SW_SHOW);
	} else if (taseditorConfig.oldControlSchemeForBranching && movie_readonly)
	{
		editMode = EDIT_MODE_BOOKMARKS;
		ShowWindow(hwndBranchesBitmap, SW_HIDE);
		ShowWindow(hwndBookmarksList, SW_SHOW);
		redrawBookmarksList();
	} else
	{
		editMode = EDIT_MODE_BOTH;
		ShowWindow(hwndBranchesBitmap, SW_HIDE);
		ShowWindow(hwndBookmarksList, SW_SHOW);
		redrawBookmarksList();
	}
	if (prev_edit_mode != editMode)
		mustCheckItemUnderMouse = true;
	SetWindowText(hwndBookmarks, bookmarksCaption[editMode]);
}
void BOOKMARKS::redrawBookmarksList(bool eraseBG)
{
	if (editMode != EDIT_MODE_BRANCHES)
		InvalidateRect(hwndBookmarksList, 0, eraseBG);
}
void BOOKMARKS::redrawChangedBookmarks(int frame)
{
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
	{
		if (bookmarksArray[i].snapshot.keyFrame == frame)
			redrawBookmark(i);
	}
}
void BOOKMARKS::redrawBookmark(int bookmarkNumber)
{
	redrawBookmarksListRow((bookmarkNumber + TOTAL_BOOKMARKS - 1) % TOTAL_BOOKMARKS);
}
void BOOKMARKS::redrawBookmarksListRow(int rowIndex)
{
	ListView_RedrawItems(hwndBookmarksList, rowIndex, rowIndex);
}

void BOOKMARKS::handleMouseMove(int newX, int newY)
{
	mouseX = newX;
	mouseY = newY;
	mustCheckItemUnderMouse = true;
}
int BOOKMARKS::findItemUnderMouse()
{
	int item = ITEM_UNDER_MOUSE_NONE;
	RECT wrect;
	GetClientRect(hwndBookmarksList, &wrect);
	if (mouseX >= listRowLeft && mouseX < wrect.right - wrect.left && mouseY >= listTopMargin && mouseY < wrect.bottom - wrect.top)
	{
		int row_under_mouse = (mouseY - listTopMargin) / listRowHeight;
		if (row_under_mouse >= 0 && row_under_mouse < TOTAL_BOOKMARKS)
			item = (row_under_mouse + 1) % TOTAL_BOOKMARKS;
	}
	return item;
}

int BOOKMARKS::getSelectedSlot()
{
	return selectedSlot;
}
// ----------------------------------------------------------------------------------------
void BOOKMARKS::getDispInfo(NMLVDISPINFO* nmlvDispInfo)
{
	LVITEM& item = nmlvDispInfo->item;
	if (item.mask & LVIF_TEXT)
	{
		switch(item.iSubItem)
		{
			case BOOKMARKSLIST_COLUMN_ICON:
			{
				if ((item.iItem + 1) % TOTAL_BOOKMARKS == branches.getCurrentBranch())
					item.iImage = ((item.iItem + 1) % TOTAL_BOOKMARKS) + TOTAL_BOOKMARKS;
				else
					item.iImage = (item.iItem + 1) % TOTAL_BOOKMARKS;
				if (taseditorConfig.oldControlSchemeForBranching)
				{
					if ((item.iItem + 1) % TOTAL_BOOKMARKS == selectedSlot)
						item.iImage += BOOKMARKS_BITMAPS_SELECTED;
				}
				break;
			}
			case BOOKMARKSLIST_COLUMN_FRAME:
			{
				if (bookmarksArray[(item.iItem + 1) % TOTAL_BOOKMARKS].notEmpty)
					U32ToDecStr(item.pszText, bookmarksArray[(item.iItem + 1) % TOTAL_BOOKMARKS].snapshot.keyFrame, DIGITS_IN_FRAMENUM);
				break;
			}
			case BOOKMARKSLIST_COLUMN_TIME:
			{
				if (bookmarksArray[(item.iItem + 1) % TOTAL_BOOKMARKS].notEmpty)
					strcpy(item.pszText, bookmarksArray[(item.iItem + 1) % TOTAL_BOOKMARKS].snapshot.description);
			}
			break;
		}
	}
}

LONG BOOKMARKS::handleCustomDraw(NMLVCUSTOMDRAW* msg)
{
	int cell_x, cell_y;
	switch(msg->nmcd.dwDrawStage)
	{
	case CDDS_PREPAINT:
		return CDRF_NOTIFYITEMDRAW;
	case CDDS_ITEMPREPAINT:
		return CDRF_NOTIFYSUBITEMDRAW;
	case CDDS_SUBITEMPREPAINT:
		cell_x = msg->iSubItem;
		cell_y = (msg->nmcd.dwItemSpec + 1) % TOTAL_BOOKMARKS;
		
		// flash with text color when needed
		if (bookmarksArray[cell_y].flashPhase)
			msg->clrText = bookmark_flash_colors[bookmarksArray[cell_y].flashType][bookmarksArray[cell_y].flashPhase];

		if (cell_x == BOOKMARKSLIST_COLUMN_FRAME || (taseditorConfig.oldControlSchemeForBranching && movie_readonly && cell_x == BOOKMARKSLIST_COLUMN_TIME))
		{
			if (bookmarksArray[cell_y].notEmpty)
			{
				// frame number
				SelectObject(msg->nmcd.hdc, pianoRoll.hMainListFont);
				int frame = bookmarksArray[cell_y].snapshot.keyFrame;
				if (frame == currFrameCounter || frame == (playback.getFlashingPauseFrame() - 1))
				{
					// current frame
					msg->clrTextBk = CUR_FRAMENUM_COLOR;
				} else if (frame < greenzone.getSize())
				{
					if (!greenzone.isSavestateEmpty(frame))
					{
						if (greenzone.lagLog.getLagInfoAtFrame(frame) == LAGGED_YES)
							msg->clrTextBk = LAG_FRAMENUM_COLOR;
						else
							msg->clrTextBk = GREENZONE_FRAMENUM_COLOR;
					} else if (!greenzone.isSavestateEmpty(cell_y & EVERY16TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY8TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY4TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY2ND))
					{
						if (greenzone.lagLog.getLagInfoAtFrame(frame) == LAGGED_YES)
							msg->clrTextBk = PALE_LAG_FRAMENUM_COLOR;
						else
							msg->clrTextBk = PALE_GREENZONE_FRAMENUM_COLOR;
					} else msg->clrTextBk = NORMAL_FRAMENUM_COLOR;
				} else msg->clrTextBk = NORMAL_FRAMENUM_COLOR;
			} else msg->clrTextBk = NORMAL_BACKGROUND_COLOR;	// empty bookmark
		} else if (cell_x == BOOKMARKSLIST_COLUMN_TIME)
		{
			if (bookmarksArray[cell_y].notEmpty)
			{
				// frame number
				SelectObject(msg->nmcd.hdc, pianoRoll.hMainListFont);
				int frame = bookmarksArray[cell_y].snapshot.keyFrame;
				if (frame == currFrameCounter || frame == (playback.getFlashingPauseFrame() - 1))
				{
					// current frame
					msg->clrTextBk = CUR_INPUT_COLOR1;
				} else if (frame < greenzone.getSize())
				{
					if (!greenzone.isSavestateEmpty(frame))
					{
						if (greenzone.lagLog.getLagInfoAtFrame(frame) == LAGGED_YES)
							msg->clrTextBk = LAG_INPUT_COLOR1;
						else
							msg->clrTextBk = GREENZONE_INPUT_COLOR1;
					} else if (!greenzone.isSavestateEmpty(cell_y & EVERY16TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY8TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY4TH)
						|| !greenzone.isSavestateEmpty(cell_y & EVERY2ND))
					{
						if (greenzone.lagLog.getLagInfoAtFrame(frame) == LAGGED_YES)
							msg->clrTextBk = PALE_LAG_INPUT_COLOR1;
						else
							msg->clrTextBk = PALE_GREENZONE_INPUT_COLOR1;
					} else msg->clrTextBk = NORMAL_INPUT_COLOR1;
				} else msg->clrTextBk = NORMAL_INPUT_COLOR1;
			} else msg->clrTextBk = NORMAL_BACKGROUND_COLOR;		// empty bookmark
		}
	default:
		return CDRF_DODEFAULT;
	}
}

void BOOKMARKS::handleLeftClick()
{
	if (columnClicked <= BOOKMARKSLIST_COLUMN_FRAME || (taseditorConfig.oldControlSchemeForBranching && movie_readonly))
		command(COMMAND_JUMP, bookmarkLeftclicked);
	else if (columnClicked == BOOKMARKSLIST_COLUMN_TIME && (!taseditorConfig.oldControlSchemeForBranching || !movie_readonly))
		command(COMMAND_DEPLOY, bookmarkLeftclicked);
}
void BOOKMARKS::handleRightClick()
{
	if (bookmarkRightclicked >= 0)
		command(COMMAND_SET, bookmarkRightclicked);
}

int BOOKMARKS::findBookmarkAtFrame(int frame)
{
	int cur_bookmark = branches.getCurrentBranch();
	if (cur_bookmark != ITEM_UNDER_MOUSE_CLOUD && bookmarksArray[cur_bookmark].snapshot.keyFrame == frame)
		return cur_bookmark + TOTAL_BOOKMARKS;	// blue digit has highest priority when drawing
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
	{
		cur_bookmark = (i + 1) % TOTAL_BOOKMARKS;
		if (bookmarksArray[cur_bookmark].notEmpty && bookmarksArray[cur_bookmark].snapshot.keyFrame == frame)
			return cur_bookmark;	// green digit
	}
	return -1;		// no Bookmarks at the frame
}
// ----------------------------------------------------------------------------------------
LRESULT APIENTRY BookmarksListWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern BOOKMARKS bookmarks;
	switch(msg)
	{
		case WM_CHAR:
		case WM_KEYDOWN:
		case WM_KEYUP:
		case WM_SETFOCUS:
		case WM_KILLFOCUS:
			return 0;
		case WM_MOUSEMOVE:
		{
			if (!bookmarks.mouseOverBookmarksList)
			{
				bookmarks.mouseOverBookmarksList = true;
				bookmarks.tmeList.hwndTrack = hWnd;
				TrackMouseEvent(&bookmarks.tmeList);
			}
			bookmarks.handleMouseMove(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam));
			break;
		}
		case WM_MOUSELEAVE:
		{
			bookmarks.mouseOverBookmarksList = false;
			bookmarks.handleMouseMove(-1, -1);
			break;
		}
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			ListView_SubItemHitTest(hWnd, (LPARAM)&info);
			if (info.iItem >= 0 && bookmarks.bookmarkRightclicked < 0)
			{
				bookmarks.bookmarkLeftclicked = (info.iItem + 1) % TOTAL_BOOKMARKS;
				bookmarks.columnClicked = info.iSubItem;
				if (bookmarks.columnClicked <= BOOKMARKSLIST_COLUMN_FRAME || (taseditorConfig.oldControlSchemeForBranching && movie_readonly))
					bookmarks.bookmarksArray[bookmarks.bookmarkLeftclicked].flashType = FLASH_TYPE_JUMP;
				else if (bookmarks.columnClicked == BOOKMARKSLIST_COLUMN_TIME && (!taseditorConfig.oldControlSchemeForBranching || !movie_readonly))
					bookmarks.bookmarksArray[bookmarks.bookmarkLeftclicked].flashType = FLASH_TYPE_DEPLOY;
				SetCapture(hWnd);
			}
			return 0;
		}
		case WM_LBUTTONUP:
		{
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			RECT wrect;
			GetClientRect(hWnd, &wrect);
			if (info.pt.x >= 0 && info.pt.x < wrect.right - wrect.left && info.pt.y >= 0 && info.pt.y < wrect.bottom - wrect.top)
			{
				ListView_SubItemHitTest(hWnd, (LPARAM)&info);
				if (bookmarks.bookmarkLeftclicked == (info.iItem + 1) % TOTAL_BOOKMARKS && bookmarks.columnClicked == info.iSubItem)
					bookmarks.handleLeftClick();
			}
			ReleaseCapture();
			bookmarks.bookmarkLeftclicked = -1;
			return 0;
		}
		case WM_RBUTTONDOWN:
		case WM_RBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			ListView_SubItemHitTest(hWnd, (LPARAM)&info);
			if (info.iItem >= 0 && bookmarks.bookmarkLeftclicked < 0)
			{
				bookmarks.bookmarkRightclicked = (info.iItem + 1) % TOTAL_BOOKMARKS;
				bookmarks.columnClicked = info.iSubItem;
				bookmarks.bookmarksArray[bookmarks.bookmarkRightclicked].flashType = FLASH_TYPE_SET;
				SetCapture(hWnd);
			}
			return 0;
		}
		case WM_RBUTTONUP:
		{
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			RECT wrect;
			GetClientRect(hWnd, &wrect);
			if (info.pt.x >= 0 && info.pt.x < wrect.right - wrect.left && info.pt.y >= 0 && info.pt.y < wrect.bottom - wrect.top)
			{
				ListView_SubItemHitTest(hWnd, (LPARAM)&info);
				if (bookmarks.bookmarkRightclicked == (info.iItem + 1) % TOTAL_BOOKMARKS && bookmarks.columnClicked == info.iSubItem)
					bookmarks.handleRightClick();
			}
			ReleaseCapture();
			bookmarks.bookmarkRightclicked = ITEM_UNDER_MOUSE_NONE;
			return 0;
		}
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			playback.handleMiddleButtonClick();
			return 0;
		}
		case WM_MOUSEWHEEL:
		{
			bookmarks.bookmarkRightclicked = ITEM_UNDER_MOUSE_NONE;	// ensure that accidental rightclick on BookmarksList won't set Bookmarks when user does rightbutton + wheel
			return SendMessage(pianoRoll.hwndList, msg, wParam, lParam);
		}
	}
	return CallWindowProc(hwndBookmarksList_oldWndProc, hWnd, msg, wParam, lParam);
}

