/* ---------------------------------------------------------------------------------
Implementation file of History class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
History - History of movie modifications
[Single instance]

* stores array of History items (snapshots, backup_bookmarks, backup_current_branch) and pointer to current snapshot
* saves and loads the data from a project file. On error: clears the array and starts new history by making snapshot of current movie data
* on demand: checks the difference between the last snapshot's Inputlog and current movie Input, and makes a decision to create new point of rollback. In special cases it can create a point of rollback without checking the difference, assuming that caller already checked it
* implements all restoring operations: undo, redo, revert to any snapshot from the array
* also stores the state of "undo pointer"
* regularly updates the state of "undo pointer"
* regularly (when emulator is paused) searches for uncompressed items in the History Log and compresses first found item
* implements the working of History List: creating, redrawing, clicks, auto-scrolling
* stores resources: save id, ids and names of all possible types of modification, timings of "undo pointer"
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"

LRESULT APIENTRY historyListWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC hwndHistoryList_oldWndProc;

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern MARKERS_MANAGER markersManager;
extern BOOKMARKS bookmarks;
extern BRANCHES branches;
extern PLAYBACK playback;
extern SELECTION selection;
extern GREENZONE greenzone;
extern TASEDITOR_PROJECT project;
extern PIANO_ROLL pianoRoll;
extern POPUP_DISPLAY popupDisplay;
extern TASEDITOR_LUA taseditor_lua;

extern int joysticksPerFrame[INPUT_TYPES_TOTAL];
extern int getInputType(MovieData& md);

extern WindowItemData windowItems[];

char historySaveID[HISTORY_ID_LEN] = "HISTORY";
char historySkipSaveID[HISTORY_ID_LEN] = "HISTORX";
char modCaptions[MODTYPES_TOTAL][20] = {" Initialization",
										" Undefined",
										" Set",
										" Unset",			
										" Pattern",
										" Insert",
										" Insert#",
										" Delete",
										" Truncate",
										" Clear",
										" Cut",
										" Paste",
										" PasteInsert",
										" Clone",
										" Record",
										" Import",
										" Bookmark0",
										" Bookmark1",
										" Bookmark2",
										" Bookmark3",
										" Bookmark4",
										" Bookmark5",
										" Bookmark6",
										" Bookmark7",
										" Bookmark8",
										" Bookmark9",
										" Branch0 to ",
										" Branch1 to ",
										" Branch2 to ",
										" Branch3 to ",
										" Branch4 to ",
										" Branch5 to ",
										" Branch6 to ",
										" Branch7 to ",
										" Branch8 to ",
										" Branch9 to ",
										" Marker Branch0 to ",
										" Marker Branch1 to ",
										" Marker Branch2 to ",
										" Marker Branch3 to ",
										" Marker Branch4 to ",
										" Marker Branch5 to ",
										" Marker Branch6 to ",
										" Marker Branch7 to ",
										" Marker Branch8 to ",
										" Marker Branch9 to ",
										" Marker Set",
										" Marker Remove",
										" Marker Pattern",
										" Marker Rename",
										" Marker Drag",
										" Marker Swap",
										" Marker Shift",
										" LUA Marker Set",
										" LUA Marker Remove",
										" LUA Marker Rename",
										" LUA Change" };
char luaCaptionPrefix[6] = " LUA ";
char joypadCaptions[5][11] = {"(Commands)", "(1P)", "(2P)", "(3P)", "(4P)"};

HISTORY::HISTORY()
{
}

void HISTORY::init()
{
	// prepare the history listview
	hwndHistoryList = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_HISTORYLIST);
	ListView_SetExtendedListViewStyleEx(hwndHistoryList, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES);
	// subclass the listview
	hwndHistoryList_oldWndProc = (WNDPROC)SetWindowLong(hwndHistoryList, GWL_WNDPROC, (LONG)historyListWndProc);
	LVCOLUMN lvc;
	lvc.mask = LVCF_WIDTH | LVCF_FMT;
	lvc.cx = HISTORY_LIST_WIDTH;
	lvc.fmt = LVCFMT_LEFT;
	ListView_InsertColumn(hwndHistoryList, 0, &lvc);
	// shedule first autocompression
	nextAutocompressTime = clock() + TIME_BETWEEN_AUTOCOMPRESSIONS;
}
void HISTORY::free()
{
	snapshots.resize(0);
	bookmarkBackups.resize(0);
	currentBranchNumberBackups.resize(0);
	historyTotalItems = 0;
}
void HISTORY::reset()
{
	free();
	// init vars
	historySize = taseditorConfig.maxUndoLevels + 1;
	undoHintPos = oldUndoHintPos = undoHintTimer = -1;
	oldShowUndoHint = showUndoHint = false;
	snapshots.resize(historySize);
	bookmarkBackups.resize(historySize);
	currentBranchNumberBackups.resize(historySize);
	historyStartPos = 0;
	historyCursorPos = -1;
	// create initial snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	snap.modificationType = MODTYPE_INIT;
	strcat(snap.description, modCaptions[snap.modificationType]);
	snap.keyFrame = -1;
	snap.startFrame = 0;
	snap.endFrame = snap.inputlog.size - 1;
	addItemToHistoryLog(snap);
	updateList();
	redrawList();
}
void HISTORY::update()
{
	// Update undo_hint
	if (oldUndoHintPos != undoHintPos && oldUndoHintPos >= 0)
		pianoRoll.redrawRow(oldUndoHintPos);
	oldUndoHintPos = undoHintPos;
	oldShowUndoHint = showUndoHint;
	showUndoHint = false;
	if (undoHintPos >= 0)
	{
		if ((int)clock() < undoHintTimer)
			showUndoHint = true;
		else
			undoHintPos = -1;		// finished hinting
	}
	if (oldShowUndoHint != showUndoHint)
		pianoRoll.redrawRow(undoHintPos);

	// When CPU is idle, compress items from time to time
	if (clock() > nextAutocompressTime)
	{
		if (FCEUI_EmulationPaused())
		{
			// search for the first occurrence of an item containing non-compressed snapshot
			int real_pos;
			for (int i = historyTotalItems - 1; i >= 0; i--)
			{
				real_pos = (historyStartPos + i) % historySize;
				if (!snapshots[real_pos].isAlreadyCompressed())
				{
					snapshots[real_pos].compressData();
					break;
				} else if (bookmarkBackups[real_pos].notEmpty && bookmarkBackups[real_pos].snapshot.isAlreadyCompressed())
				{
					bookmarkBackups[real_pos].snapshot.compressData();
					break;
				}
			}
		}
		nextAutocompressTime = clock() + TIME_BETWEEN_AUTOCOMPRESSIONS;
	}
}

void HISTORY::updateHistoryLogSize()
{
	int newHistorySize = taseditorConfig.maxUndoLevels + 1;
	std::vector<SNAPSHOT> new_snapshots(newHistorySize);
	std::vector<BOOKMARK> new_backup_bookmarks(newHistorySize);
	std::vector<int8> new_backup_current_branch(newHistorySize);
	int pos = historyCursorPos, source_pos = historyCursorPos;
	if (pos >= newHistorySize)
		pos = newHistorySize - 1;
	int new_history_cursor_pos = pos;
	// copy old "undo" items
	while (pos >= 0)
	{
		new_snapshots[pos] = snapshots[(historyStartPos + source_pos) % historySize];
		new_backup_bookmarks[pos] = bookmarkBackups[(historyStartPos + source_pos) % historySize];
		new_backup_current_branch[pos] = currentBranchNumberBackups[(historyStartPos + source_pos) % historySize];
		pos--;
		source_pos--;
	}
	// copy old "redo" items
	int num_redo_items = historyTotalItems - (historyCursorPos + 1);
	int space_available = newHistorySize - (new_history_cursor_pos + 1);
	int i = (num_redo_items <= space_available) ? num_redo_items : space_available;
	int new_history_total_items = new_history_cursor_pos + i + 1;
	for (; i > 0; i--)
	{
		new_snapshots[new_history_cursor_pos + i] = snapshots[(historyStartPos + historyCursorPos + i) % historySize];
		new_backup_bookmarks[new_history_cursor_pos + i] = bookmarkBackups[(historyStartPos + historyCursorPos + i) % historySize];
		new_backup_current_branch[new_history_cursor_pos + i] = currentBranchNumberBackups[(historyStartPos + historyCursorPos + i) % historySize];
	}
	// finish
	snapshots = new_snapshots;
	bookmarkBackups = new_backup_bookmarks;
	currentBranchNumberBackups = new_backup_current_branch;
	historySize = newHistorySize;
	historyStartPos = 0;
	historyCursorPos = new_history_cursor_pos;
	historyTotalItems = new_history_total_items;
	updateList();
	redrawList();
}

// returns frame of first Input change (for Greenzone invalidation)
int HISTORY::jumpInTime(int new_pos)
{
	if (new_pos < 0)
		new_pos = 0;
	else if (new_pos >= historyTotalItems)
		new_pos = historyTotalItems - 1;
	// if nothing is done, do not invalidate Greenzone
	if (new_pos == historyCursorPos)
		return -1;

	// make jump
	int old_pos = historyCursorPos;
	historyCursorPos = new_pos;
	redrawList();

	int real_pos, mod_type, slot, current_branch = branches.getCurrentBranch();
	bool bookmarks_changed = false, changes_since_current_branch = false;
	bool old_changes_since_current_branch = branches.areThereChangesSinceCurrentBranch();
	// restore Bookmarks/Branches
	std::vector<uint8> bookmarks_to_redraw;
	std::vector<int> frames_to_redraw;
	if (new_pos > old_pos)
	{
		// redo
		for (int i = old_pos + 1; i <= new_pos; ++i)
		{
			real_pos = (historyStartPos + i) % historySize;
			mod_type = snapshots[real_pos].modificationType;
			if (mod_type >= MODTYPE_BOOKMARK_0 && mod_type <= MODTYPE_BRANCH_MARKERS_9)
			{
				current_branch = (mod_type - MODTYPE_BOOKMARK_0) % TOTAL_BOOKMARKS;
				changes_since_current_branch = false;
			} else
			{
				changes_since_current_branch = true;
			}
			if (mod_type >= MODTYPE_BOOKMARK_0 && mod_type <= MODTYPE_BOOKMARK_9)
			{
				// swap Bookmark and its backup version
				slot = (mod_type - MODTYPE_BOOKMARK_0) % TOTAL_BOOKMARKS;
				BOOKMARK temp_bookmark(bookmarks.bookmarksArray[slot]);
				frames_to_redraw.push_back(bookmarks.bookmarksArray[slot].snapshot.keyFrame);
				bookmarks.bookmarksArray[slot] = bookmarkBackups[real_pos];
				frames_to_redraw.push_back(bookmarks.bookmarksArray[slot].snapshot.keyFrame);
				bookmarks_to_redraw.push_back(slot);
				bookmarkBackups[real_pos] = temp_bookmark;
				branches.invalidateRelationsOfBranchSlot(slot);
				bookmarks_changed = true;
			}
		}
	} else
	{
		// undo
		for (int i = old_pos; i > new_pos; i--)
		{
			real_pos = (historyStartPos + i) % historySize;
			mod_type = snapshots[real_pos].modificationType;
			if (mod_type >= MODTYPE_BOOKMARK_0 && mod_type <= MODTYPE_BRANCH_MARKERS_9)
				current_branch = currentBranchNumberBackups[real_pos];
			if (mod_type >= MODTYPE_BOOKMARK_0 && mod_type <= MODTYPE_BOOKMARK_9)
			{
				// swap Bookmark and its backup version
				slot = (mod_type - MODTYPE_BOOKMARK_0) % TOTAL_BOOKMARKS;
				BOOKMARK temp_bookmark(bookmarks.bookmarksArray[slot]);
				frames_to_redraw.push_back(bookmarks.bookmarksArray[slot].snapshot.keyFrame);
				bookmarks.bookmarksArray[slot] = bookmarkBackups[real_pos];
				frames_to_redraw.push_back(bookmarks.bookmarksArray[slot].snapshot.keyFrame);
				bookmarks_to_redraw.push_back(slot);
				bookmarkBackups[real_pos] = temp_bookmark;
				branches.invalidateRelationsOfBranchSlot(slot);
				bookmarks_changed = true;
			}
		}
		real_pos = (historyStartPos + new_pos) % historySize;
		mod_type = snapshots[real_pos].modificationType;
		if (mod_type >= MODTYPE_BOOKMARK_0 && mod_type <= MODTYPE_BRANCH_MARKERS_9)
		{
			current_branch = (mod_type - MODTYPE_BOOKMARK_0) % TOTAL_BOOKMARKS;
			changes_since_current_branch = false;
		} else if (getCategoryOfOperation(mod_type) != CATEGORY_OTHER)
		{
			changes_since_current_branch = true;
		}
	}
	int old_current_branch = branches.getCurrentBranch();
	if (bookmarks_changed || current_branch != old_current_branch || changes_since_current_branch != old_changes_since_current_branch)
	{
		branches.handleHistoryJump(current_branch, changes_since_current_branch);
		if (current_branch != old_current_branch)
		{
			// current_branch was switched, redraw Bookmarks List to change the color of digits
			if (old_current_branch != ITEM_UNDER_MOUSE_CLOUD)
			{
				frames_to_redraw.push_back(bookmarks.bookmarksArray[old_current_branch].snapshot.keyFrame);
				bookmarks_to_redraw.push_back(old_current_branch);
			}
			if (current_branch != ITEM_UNDER_MOUSE_CLOUD)
			{
				frames_to_redraw.push_back(bookmarks.bookmarksArray[current_branch].snapshot.keyFrame);
				bookmarks_to_redraw.push_back(current_branch);
			}
		}
		bookmarks.mustCheckItemUnderMouse = true;
		project.setProjectChanged();
	}
	// redraw Piano Roll rows and Bookmarks List rows
	for (int i = frames_to_redraw.size() - 1; i >= 0; i--)
		pianoRoll.redrawRow(frames_to_redraw[i]);
	for (int i = bookmarks_to_redraw.size() - 1; i >= 0; i--)
	{
		bookmarks.redrawBookmark(bookmarks_to_redraw[i]);
		// if screenshot of the slot is currently shown - reinit and redraw the picture
		if (popupDisplay.currentlyDisplayedBookmark == bookmarks_to_redraw[i])
			popupDisplay.currentlyDisplayedBookmark = ITEM_UNDER_MOUSE_NONE;
	}

	// create undo_hint
	if (new_pos > old_pos)
		undoHintPos = getCurrentSnapshot().keyFrame;		// redo
	else
		undoHintPos = getNextToCurrentSnapshot().keyFrame;	// undo
	undoHintTimer = clock() + UNDO_HINT_TIME;
	showUndoHint = true;

	real_pos = (historyStartPos + historyCursorPos) % historySize;

	// update Markers
	bool markers_changed = false;
	if (snapshots[real_pos].areMarkersDifferentFromCurrentMarkers())
	{
		snapshots[real_pos].copyToCurrentMarkers();
		project.setProjectChanged();
		markers_changed = true;
	}

	// revert current movie data
	int first_changes = snapshots[real_pos].inputlog.findFirstChange(currMovieData);
	if (first_changes >= 0)
	{
		snapshots[real_pos].inputlog.toMovie(currMovieData, first_changes);
		if (markers_changed)
			markersManager.update();
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		project.setProjectChanged();
	} else if (markers_changed)
	{
		markersManager.update();
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		project.setProjectChanged();
	}

	// revert Greenzone's LagLog
	// but if Greenzone's LagLog has the same data + more lag data of the same timeline, then don't revert but truncate
	int first_lag_changes = greenzone.lagLog.findFirstChange(snapshots[real_pos].laglog);
	int greenzone_log_size = greenzone.lagLog.getSize();
	int new_log_size = snapshots[real_pos].laglog.getSize();
	if ((first_lag_changes < 0 || (first_lag_changes > new_log_size && first_lag_changes > greenzone_log_size)) && greenzone_log_size > new_log_size)
	{
		if (first_changes >= 0 && (first_lag_changes > first_changes || first_lag_changes < 0))
			// truncate after the timeline starts to differ
			first_lag_changes = first_changes;
		greenzone.lagLog.invalidateFromFrame(first_lag_changes);
		// keep current snapshot laglog in touch
		snapshots[real_pos].laglog = greenzone.lagLog;
	} else
	{
		greenzone.lagLog = snapshots[real_pos].laglog;
	}

	pianoRoll.updateLinesCount();
	pianoRoll.followUndoHint();
	pianoRoll.redraw();	// even though the Greenzone invalidation most likely will also sent the command to redraw

	// Greenzone should be invalidated after the frame of Lag changes if this frame is less than the frame of Input changes
	if (first_lag_changes >= 0 && (first_changes > first_lag_changes || first_changes < 0))
		first_changes = first_lag_changes;
	return first_changes;
}

void HISTORY::undo()
{
	int result = jumpInTime(historyCursorPos - 1);
	if (result >= 0)
		greenzone.invalidateAndUpdatePlayback(result);
	return;
}
void HISTORY::redo()
{
	int result = jumpInTime(historyCursorPos + 1);
	if (result >= 0)
		greenzone.invalidateAndUpdatePlayback(result);
	return;
}
// ----------------------------
void HISTORY::addItemToHistoryLog(SNAPSHOT &snap, int currentBranch)
{
	historyCursorPos++;
	historyTotalItems = historyCursorPos + 1;
	// history uses ring buffer to avoid frequent reallocations caused by vector resizing, which would be awfully expensive with such large objects as SNAPSHOT and BOOKMARK
	if (historyTotalItems >= historySize)
	{
		// reached the end of available history_size
		// move history_start_pos (thus deleting oldest snapshot)
		historyStartPos = (historyStartPos + 1) % historySize;
		// and restore history_cursor_pos and history_total_items
		historyCursorPos--;
		historyTotalItems--;
	}
	// write data
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	snapshots[real_pos] = snap;
	bookmarkBackups[real_pos].free();
	currentBranchNumberBackups[real_pos] = currentBranch;
	updateList();
	redrawList();
}
void HISTORY::addItemToHistoryLog(SNAPSHOT &snap, int cur_branch, BOOKMARK &bookm)
{
	// history uses ring buffer to avoid frequent reallocations caused by vector resizing, which would be awfully expensive with such large objects as SNAPSHOT and BOOKMARK
	if (historyTotalItems >= historySize)
	{
		// reached the end of available history_size - move history_start_pos (thus deleting oldest snapshot)
		historyCursorPos = historySize - 1;
		historyStartPos = (historyStartPos + 1) % historySize;
	} else
	{
		// didn't reach the end of history yet
		historyCursorPos++;
		historyTotalItems = historyCursorPos+1;
		updateList();
	}
	// write data
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	snapshots[real_pos] = snap;
	bookmarkBackups[real_pos] = bookm;
	currentBranchNumberBackups[real_pos] = cur_branch;
	redrawList();
}
// --------------------------------------------------------------------
// Here goes the set of functions that register project changes and log them into History log

// returns frame of first actual change
int HISTORY::registerChanges(int mod_type, int start, int end, int size, const char* comment, int consecutivenessTag, RowsSelection* frameset)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// check if there are Input differences from latest snapshot
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	int first_changes = snap.inputlog.findFirstChange(snapshots[real_pos].inputlog, start, end);
	// for lag-affecting operations only:
	// Greenzone should be invalidated after the frame of Lag changes if this frame is less than the frame of Input changes
	int first_lag_changes = -1;
	if (end == -1)
		first_lag_changes = snap.laglog.findFirstChange(snapshots[real_pos].laglog);

	if (first_changes >= 0)
	{
		// differences found
		char framenum[11];
		// fill description:
		snap.modificationType = mod_type;
		strcat(snap.description, modCaptions[snap.modificationType]);
		// set keyframe
		switch (mod_type)
		{
			case MODTYPE_SET:
			case MODTYPE_UNSET:
			case MODTYPE_TRUNCATE:
			case MODTYPE_CLEAR:
			case MODTYPE_CUT:
			{
				snap.keyFrame = first_changes;
				break;
			}
			case MODTYPE_INSERT:
			case MODTYPE_INSERTNUM:
			case MODTYPE_PASTEINSERT:
			case MODTYPE_PASTE:
			case MODTYPE_CLONE:
			case MODTYPE_DELETE:
			case MODTYPE_PATTERN:
			{
				// for these changes user prefers to see frame of attempted change (Selection cursor position), not frame of actual differences
				snap.keyFrame = start;
				break;
			}
		}
		// set start_frame, end_frame, consecutivenessTag
		// normal operations
		snap.startFrame = start;
		if (mod_type == MODTYPE_INSERTNUM)
		{
			snap.endFrame = start + size - 1;
			_itoa(size, framenum, 10);
			strcat(snap.description, framenum);
		} else
		{
			snap.endFrame = end;
		}
		snap.consecutivenessTag = consecutivenessTag;
		if (consecutivenessTag && taseditorConfig.combineConsecutiveRecordingsAndDraws && snapshots[real_pos].modificationType == snap.modificationType && snapshots[real_pos].consecutivenessTag == snap.consecutivenessTag)
		{
			// combine Drawing with previous snapshot
			if (snap.keyFrame > snapshots[real_pos].keyFrame)
				snap.keyFrame = snapshots[real_pos].keyFrame;
			if (snap.startFrame > snapshots[real_pos].startFrame)
				snap.startFrame = snapshots[real_pos].startFrame;
			if (snap.endFrame < snapshots[real_pos].endFrame)
				snap.endFrame = snapshots[real_pos].endFrame;
			// add upper and lower frame to description
			strcat(snap.description, " ");
			_itoa(snap.startFrame, framenum, 10);
			strcat(snap.description, framenum);
			if (snap.endFrame > snap.startFrame)
			{
				strcat(snap.description, "-");
				_itoa(snap.endFrame, framenum, 10);
				strcat(snap.description, framenum);
			}
			// add comment if there is one specified
			if (comment)
			{
				strcat(snap.description, " ");
				strncat(snap.description, comment, SNAPSHOT_DESCRIPTION_MAX_LEN - strlen(snap.description) - 1);
			}
			// set hotchanges
			if (taseditorConfig.enableHotChanges)
			{
				snap.inputlog.copyHotChanges(&snapshots[real_pos].inputlog);
				snap.inputlog.fillHotChanges(snapshots[real_pos].inputlog, first_changes, end);
			}
			// replace current snapshot with this cloned snapshot and truncate history here
			snapshots[real_pos] = snap;
			historyTotalItems = historyCursorPos+1;
			updateList();
			redrawList();
		} else
		{
			// don't combine
			// add upper and lower frame to description
			strcat(snap.description, " ");
			_itoa(snap.startFrame, framenum, 10);
			strcat(snap.description, framenum);
			if (snap.endFrame > snap.startFrame)
			{
				strcat(snap.description, "-");
				_itoa(snap.endFrame, framenum, 10);
				strcat(snap.description, framenum);
			}
			// add comment if there is one specified
			if (comment)
			{
				strcat(snap.description, " ");
				strncat(snap.description, comment, SNAPSHOT_DESCRIPTION_MAX_LEN - strlen(snap.description) - 1);
			}
			// set hotchanges
			if (taseditorConfig.enableHotChanges)
			{
				// inherit previous hotchanges and set new changes
				switch (mod_type)
				{
					case MODTYPE_DELETE:
						snap.inputlog.inheritHotChanges_DeleteSelection(&snapshots[real_pos].inputlog, frameset);
						break;
					case MODTYPE_INSERT:
					case MODTYPE_CLONE:
						snap.inputlog.inheritHotChanges_InsertSelection(&snapshots[real_pos].inputlog, frameset);
						break;
					case MODTYPE_INSERTNUM:
						snap.inputlog.inheritHotChanges_InsertNum(&snapshots[real_pos].inputlog, start, size, true);
						break;
					case MODTYPE_SET:
					case MODTYPE_UNSET:
					case MODTYPE_CLEAR:
					case MODTYPE_CUT:
					case MODTYPE_PASTE:
					case MODTYPE_PATTERN:
						snap.inputlog.inheritHotChanges(&snapshots[real_pos].inputlog);
						snap.inputlog.fillHotChanges(snapshots[real_pos].inputlog, first_changes, end);
						break;
					case MODTYPE_PASTEINSERT:
						snap.inputlog.inheritHotChanges_PasteInsert(&snapshots[real_pos].inputlog, frameset);
						break;
					case MODTYPE_TRUNCATE:
						snap.inputlog.copyHotChanges(&snapshots[real_pos].inputlog);
						// do not add new hotchanges and do not fade old hotchanges, because there was nothing added
						break;
				}
			}
			addItemToHistoryLog(snap);
		}
		branches.setChangesMadeSinceBranch();
		project.setProjectChanged();
	}
	if (first_lag_changes >= 0 && (first_changes > first_lag_changes || first_changes < 0))
		first_changes = first_lag_changes;
	return first_changes;
}
int HISTORY::registerAdjustLag(int start, int size)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// check if there are Input differences from latest snapshot
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	SNAPSHOT& current_snap = snapshots[real_pos];
	int first_changes = snap.inputlog.findFirstChange(current_snap.inputlog, start, -1);
	if (first_changes >= 0)
	{
		// differences found - combine Adjustment with current snapshot
		// copy all properties of current snapshot
		snap.keyFrame = current_snap.keyFrame;
		snap.startFrame = current_snap.startFrame;
		snap.endFrame = current_snap.endFrame;
		snap.consecutivenessTag = current_snap.consecutivenessTag;
		//if (current_snap.mod_type == MODTYPE_RECORD && size < 0 && current_snap.consecutivenessTag == first_changes) snap.consecutivenessTag--;		// make sure that consecutive Recordings work even when there's AdjustUp inbetween
		snap.recordedJoypadDifferenceBits = current_snap.recordedJoypadDifferenceBits;
		snap.modificationType = current_snap.modificationType;
		strcpy(snap.description, current_snap.description);
		// set hotchanges
		if (taseditorConfig.enableHotChanges)
		{
			if (size < 0)
				// it was Adjust Up
				snap.inputlog.inheritHotChanges_DeleteNum(&snapshots[real_pos].inputlog, start, 0 - size, false);
			else
				// it was Adjust Down
				snap.inputlog.inheritHotChanges_InsertNum(&snapshots[real_pos].inputlog, start, 1, false);
		}
		// replace current snapshot with this cloned snapshot and don't truncate history
		snapshots[real_pos] = snap;
		updateList();
		redrawList();
		branches.setChangesMadeSinceBranch();
		project.setProjectChanged();
	}
	return first_changes;
}
void HISTORY::registerMarkersChange(int modificationType, int start, int end, const char* comment)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// fill description:
	snap.modificationType = modificationType;
	strcat(snap.description, modCaptions[modificationType]);
	snap.keyFrame = start;
	snap.startFrame = start;
	snap.endFrame = end;
	// add the frame to description
	char framenum[11];
	strcat(snap.description, " ");
	_itoa(snap.startFrame, framenum, 10);
	strcat(snap.description, framenum);
	if (snap.endFrame > snap.startFrame || modificationType == MODTYPE_MARKER_DRAG || modificationType == MODTYPE_MARKER_SWAP)
	{
		if (modificationType == MODTYPE_MARKER_DRAG)
			strcat(snap.description, "->");
		else if (modificationType == MODTYPE_MARKER_SWAP)
			strcat(snap.description, "<->");
		else
			strcat(snap.description, "-");
		_itoa(snap.endFrame, framenum, 10);
		strcat(snap.description, framenum);
	}
	// add comment if there is one specified
	if (comment)
	{
		strcat(snap.description, " ");
		strncat(snap.description, comment, SNAPSHOT_DESCRIPTION_MAX_LEN - strlen(snap.description) - 1);
	}
	// Hotchanges aren't changed
	if (taseditorConfig.enableHotChanges)
		snap.inputlog.copyHotChanges(&getCurrentSnapshot().inputlog);
	addItemToHistoryLog(snap);
	branches.setChangesMadeSinceBranch();
	project.setProjectChanged();
}
void HISTORY::registerBookmarkSet(int slot, BOOKMARK& backupCopy, int oldCurrentBranch)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// fill description: modification type + keyframe of the Bookmark
	snap.modificationType = MODTYPE_BOOKMARK_0 + slot;
	strcat(snap.description, modCaptions[snap.modificationType]);
	snap.startFrame = snap.endFrame = snap.keyFrame = bookmarks.bookmarksArray[slot].snapshot.keyFrame;
	char framenum[11];
	strcat(snap.description, " ");
	_itoa(snap.keyFrame, framenum, 10);
	strcat(snap.description, framenum);
	if (taseditorConfig.enableHotChanges)
		snap.inputlog.copyHotChanges(&getCurrentSnapshot().inputlog);
	addItemToHistoryLog(snap, oldCurrentBranch, backupCopy);
	project.setProjectChanged();
}
int HISTORY::registerBranching(int slot, bool markers_changed)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// check if there are Input differences from latest snapshot
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	int first_changes = snap.inputlog.findFirstChange(snapshots[real_pos].inputlog);
	if (first_changes >= 0)
	{
		// differences found
		// fill description: modification type + time of the Branch
		snap.modificationType = MODTYPE_BRANCH_0 + slot;
		strcat(snap.description, modCaptions[snap.modificationType]);
		strcat(snap.description, bookmarks.bookmarksArray[slot].snapshot.description);
		snap.keyFrame = first_changes;
		snap.startFrame = first_changes;
		snap.endFrame = -1;
		if (taseditorConfig.enableHotChanges)
			// copy hotchanges of the Branch
			snap.inputlog.copyHotChanges(&bookmarks.bookmarksArray[slot].snapshot.inputlog);
		addItemToHistoryLog(snap, branches.getCurrentBranch());
		project.setProjectChanged();
	} else if (markers_changed)
	{
		// fill description: modification type + time of the Branch
		snap.modificationType = MODTYPE_BRANCH_MARKERS_0 + slot;
		strcat(snap.description, modCaptions[snap.modificationType]);
		strcat(snap.description, bookmarks.bookmarksArray[slot].snapshot.description);
		snap.keyFrame = bookmarks.bookmarksArray[slot].snapshot.keyFrame;
		snap.startFrame = 0;
		snap.endFrame = -1;
		// Input was not changed, only Markers were changed
		if (taseditorConfig.enableHotChanges)
			snap.inputlog.copyHotChanges(&getCurrentSnapshot().inputlog);
		addItemToHistoryLog(snap, branches.getCurrentBranch());
		project.setProjectChanged();
	}
	// revert Greenzone's LagLog (and snap's LagLog too) to bookmarked state
	// but if Greenzone's LagLog has the same data + more lag data of the same timeline, then don't revert but truncate
	int first_lag_changes = greenzone.lagLog.findFirstChange(bookmarks.bookmarksArray[slot].snapshot.laglog);
	int greenzone_log_size = greenzone.lagLog.getSize();
	int bookmarked_log_size = bookmarks.bookmarksArray[slot].snapshot.laglog.getSize();
	if ((first_lag_changes < 0 || (first_lag_changes > bookmarked_log_size && first_lag_changes > greenzone_log_size)) && greenzone_log_size > bookmarked_log_size)
	{
		if (first_changes >= 0 && (first_lag_changes > first_changes || first_lag_changes < 0))
			// truncate after the timeline starts to differ
			first_lag_changes = first_changes;
		greenzone.lagLog.invalidateFromFrame(first_lag_changes);
		// keep current snapshot laglog in touch
		snap.laglog.invalidateFromFrame(first_lag_changes);
	} else
	{
		greenzone.lagLog = bookmarks.bookmarksArray[slot].snapshot.laglog;
		// keep current snapshot laglog in touch
		snap.laglog = greenzone.lagLog;
	}
	// Greenzone should be invalidated after the frame of Lag changes if this frame is less than the frame of Input changes
	if (first_lag_changes >= 0 && (first_changes > first_lag_changes || first_changes < 0))
		first_changes = first_lag_changes;
	return first_changes;
}
void HISTORY::registerRecording(int frameOfChange, uint32 joypadDifferenceBits)
{
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	// check if current snapshot is also Recording and maybe it is consecutive recording
	if (taseditorConfig.combineConsecutiveRecordingsAndDraws
		&& snapshots[real_pos].modificationType == MODTYPE_RECORD					// a) also Recording
		&& snapshots[real_pos].consecutivenessTag == frameOfChange - 1		// b) consecutive (previous frame)
		&& snapshots[real_pos].recordedJoypadDifferenceBits == joypadDifferenceBits)	// c) recorded same set of joysticks/commands
	{
		// reinit current snapshot and set hotchanges
		SNAPSHOT* snap = &snapshots[real_pos];
		snap->reinit(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges, frameOfChange);
		// refill description
		strcat(snap->description, modCaptions[MODTYPE_RECORD]);
		char framenum[11];
		snap->endFrame = frameOfChange;
		snap->consecutivenessTag = frameOfChange;
		// add info if Commands were affected
		uint32 current_mask = 1;
		if ((snap->recordedJoypadDifferenceBits & current_mask))
			strcat(snap->description, joypadCaptions[0]);
		// add info which joypads were affected
		int num = joysticksPerFrame[snap->inputlog.inputType];
		current_mask <<= 1;
		for (int i = 0; i < num; ++i)
		{
			if ((snap->recordedJoypadDifferenceBits & current_mask))
				strcat(snap->description, joypadCaptions[i + 1]);
			current_mask <<= 1;
		}
		// add upper and lower frame to description
		strcat(snap->description, " ");
		_itoa(snap->startFrame, framenum, 10);
		strcat(snap->description, framenum);
		strcat(snap->description, "-");
		_itoa(snap->endFrame, framenum, 10);
		strcat(snap->description, framenum);
		// truncate history here
		historyTotalItems = historyCursorPos+1;
		updateList();
		redrawList();
	} else
	{
		// not consecutive - create new snapshot and add it to history
		SNAPSHOT snap;
		snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
		snap.recordedJoypadDifferenceBits = joypadDifferenceBits;
		// fill description:
		snap.modificationType = MODTYPE_RECORD;
		strcat(snap.description, modCaptions[MODTYPE_RECORD]);
		char framenum[11];
		snap.keyFrame = snap.startFrame = snap.endFrame = snap.consecutivenessTag = frameOfChange;
		// add info if Commands were affected
		uint32 current_mask = 1;
		if ((snap.recordedJoypadDifferenceBits & current_mask))
			strcat(snap.description, joypadCaptions[0]);
		// add info which joypads were affected
		int num = joysticksPerFrame[snap.inputlog.inputType];
		current_mask <<= 1;
		for (int i = 0; i < num; ++i)
		{
			if ((snap.recordedJoypadDifferenceBits & current_mask))
				strcat(snap.description, joypadCaptions[i + 1]);
			current_mask <<= 1;
		}
		// add upper frame to description
		strcat(snap.description, " ");
		_itoa(frameOfChange, framenum, 10);
		strcat(snap.description, framenum);
		// set hotchanges
		if (taseditorConfig.enableHotChanges)
		{
			snap.inputlog.inheritHotChanges(&snapshots[real_pos].inputlog);
			snap.inputlog.fillHotChanges(snapshots[real_pos].inputlog, frameOfChange, frameOfChange);
		}
		addItemToHistoryLog(snap);
	}
	branches.setChangesMadeSinceBranch();
	project.setProjectChanged();
}
int HISTORY::registerImport(MovieData& md, char* filename)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(md, greenzone.lagLog, taseditorConfig.enableHotChanges, getInputType(currMovieData));
	// check if there are Input differences from latest snapshot
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	int first_changes = snap.inputlog.findFirstChange(snapshots[real_pos].inputlog);
	if (first_changes >= 0)
	{
		// differences found
		snap.keyFrame = first_changes;
		snap.startFrame = 0;
		snap.endFrame = snap.inputlog.size - 1;
		// fill description:
		snap.modificationType = MODTYPE_IMPORT;
		strcat(snap.description, modCaptions[snap.modificationType]);
		// add filename to description
		strcat(snap.description, " ");
		strncat(snap.description, filename, SNAPSHOT_DESCRIPTION_MAX_LEN - strlen(snap.description) - 1);
		if (taseditorConfig.enableHotChanges)
		{
			// do not inherit old hotchanges, because imported Input (most likely) doesn't have direct connection with recent edits, so old hotchanges are irrelevant and should not be copied
			snap.inputlog.fillHotChanges(snapshots[real_pos].inputlog, first_changes);
		}
		addItemToHistoryLog(snap);
		// Replace current movie data with this snapshot's InputLog, not changing Greenzone's LagLog
		snap.inputlog.toMovie(currMovieData);
		pianoRoll.updateLinesCount();
		branches.setChangesMadeSinceBranch();
		project.setProjectChanged();
	}
	return first_changes;
}
int HISTORY::registerLuaChanges(const char* name, int start, bool insertionOrDeletionWasDone)
{
	// create new snapshot
	SNAPSHOT snap;
	snap.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	// check if there are Input differences from latest snapshot
	int real_pos = (historyStartPos + historyCursorPos) % historySize;
	int first_changes = snap.inputlog.findFirstChange(snapshots[real_pos].inputlog, start);
	// for lag-affecting operations only:
	// Greenzone should be invalidated after the frame of Lag changes if this frame is less than the frame of Input changes
	int first_lag_changes = -1;
	if (insertionOrDeletionWasDone)
		first_lag_changes = snap.laglog.findFirstChange(snapshots[real_pos].laglog);

	if (first_changes >= 0)
	{
		// differences found
		// fill description:
		snap.modificationType = MODTYPE_LUA_CHANGE;
		if (name[0])
		{
			// user provided custom name of operation
			strcat(snap.description, luaCaptionPrefix);
			strncat(snap.description, name, LUACHANGES_NAME_MAX_LEN);
		} else
		{
			// set default name
			strcat(snap.description, modCaptions[snap.modificationType]);
		}
		snap.keyFrame = first_changes;
		snap.startFrame = start;
		snap.endFrame = -1;
		// add upper frame to description
		char framenum[11];
		strcat(snap.description, " ");
		_itoa(first_changes, framenum, 10);
		strcat(snap.description, framenum);
		// set hotchanges
		if (taseditorConfig.enableHotChanges)
		{
			if (insertionOrDeletionWasDone)
			{
				// do it hard way: take old hot_changes and insert/delete rows to create a snapshot that is comparable to the snap
				if (snap.inputlog.inputType == snapshots[real_pos].inputlog.inputType)
				{
					// create temp copy of current snapshot (we need it as a container for hot_changes)
					SNAPSHOT hotchanges_snapshot = snapshots[real_pos];
					if (hotchanges_snapshot.inputlog.hasHotChanges)
					{
						hotchanges_snapshot.inputlog.fadeHotChanges();
					} else
					{
						hotchanges_snapshot.inputlog.hasHotChanges = true;
						hotchanges_snapshot.inputlog.initHotChanges();
					}
					// insert/delete frames in hotchanges_snapshot, so that it will be the same size as the snap
					taseditor_lua.insertAndDeleteRowsInSnaphot(hotchanges_snapshot);
					snap.inputlog.copyHotChanges(&hotchanges_snapshot.inputlog);
					snap.inputlog.fillHotChanges(hotchanges_snapshot.inputlog, first_changes);
				}
			} else
			{
				// easy way: snap.size is equal to currentsnapshot.size, so we can simply inherit hotchanges
				snap.inputlog.inheritHotChanges(&snapshots[real_pos].inputlog);
				snap.inputlog.fillHotChanges(snapshots[real_pos].inputlog, first_changes);
			}
		}
		addItemToHistoryLog(snap);
		branches.setChangesMadeSinceBranch();
		project.setProjectChanged();
	}
	if (first_lag_changes >= 0 && (first_changes > first_lag_changes || first_changes < 0))
		first_changes = first_lag_changes;
	return first_changes;
}

void HISTORY::save(EMUFILE *os, bool really_save)
{
	if (really_save)
	{
		int real_pos, last_tick = 0;
		// write "HISTORY" string
		os->fwrite(historySaveID, HISTORY_ID_LEN);
		// write vars
		write32le(historyCursorPos, os);
		write32le(historyTotalItems, os);
		// write items starting from history_start_pos
		for (int i = 0; i < historyTotalItems; ++i)
		{
			real_pos = (historyStartPos + i) % historySize;
			snapshots[real_pos].save(os);
			bookmarkBackups[real_pos].save(os);
			os->fwrite(&currentBranchNumberBackups[real_pos], 1);
			if (i / SAVING_HISTORY_PROGRESSBAR_UPDATE_RATE > last_tick)
			{
				playback.setProgressbar(i, historyTotalItems);
				last_tick = i / PROGRESSBAR_UPDATE_RATE;
			}
		}
	} else
	{
		// write "HISTORX" string
		os->fwrite(historySkipSaveID, HISTORY_ID_LEN);
	}
}
// returns true if couldn't load
bool HISTORY::load(EMUFILE *is, unsigned int offset)
{
	int i = -1;
	SNAPSHOT snap;
	BOOKMARK bookm;

	if (offset)
	{
		if (is->fseek(offset, SEEK_SET)) goto error;
	} else
	{
		reset();
		return false;
	}
	// read "HISTORY" string
	char save_id[HISTORY_ID_LEN];
	if ((int)is->fread(save_id, HISTORY_ID_LEN) < HISTORY_ID_LEN) goto error;
	if (!strcmp(historySkipSaveID, save_id))
	{
		// string says to skip loading History
		FCEU_printf("No History in the file\n");
		reset();
		return false;
	}
	if (strcmp(historySaveID, save_id)) goto error;		// string is not valid
	// delete old items
	snapshots.resize(historySize);
	bookmarkBackups.resize(historySize);
	currentBranchNumberBackups.resize(historySize);
	// read vars
	if (!read32le(&historyCursorPos, is)) goto error;
	if (!read32le(&historyTotalItems, is)) goto error;
	if (historyCursorPos > historyTotalItems) goto error;
	historyStartPos = 0;
	// read items
	int total = historyTotalItems;
	if (historyTotalItems > historySize)
	{
		// user can't afford that much undo levels, skip some items
		int num_items_to_skip = historyTotalItems - historySize;
		// first try to skip items over history_cursor_pos (future items), because "redo" is less important than "undo"
		int num_redo_items = historyTotalItems-1 - historyCursorPos;
		if (num_items_to_skip >= num_redo_items)
		{
			// skip all redo items
			historyTotalItems = historyCursorPos+1;
			num_items_to_skip -= num_redo_items;
			// and still need to skip some undo items
			for (i = 0; i < num_items_to_skip; ++i)
			{
				if (snap.skipLoad(is)) goto error;
				if (bookm.skipLoad(is)) goto error;
				if (is->fseek(1, SEEK_CUR)) goto error;		// backup_current_branch
			}
			total -= num_items_to_skip;
			historyCursorPos -= num_items_to_skip;
		}
		historyTotalItems -= num_items_to_skip;
	}
	// load items
	for (i = 0; i < historyTotalItems; ++i)
	{
		if (snapshots[i].load(is)) goto error;
		if (bookmarkBackups[i].load(is)) goto error;
		if (is->fread(&currentBranchNumberBackups[i], 1) != 1) goto error;
		playback.setProgressbar(i, historyTotalItems);
	}
	// skip redo items if needed
	for (; i < total; ++i)
	{
		if (snap.skipLoad(is)) goto error;
		if (bookm.skipLoad(is)) goto error;
		if (is->fseek(1, SEEK_CUR)) goto error;		// backup_current_branch
	}

	// everything went well
	// init vars
	undoHintPos = oldUndoHintPos = undoHintTimer = -1;
	oldShowUndoHint = showUndoHint = false;
	updateList();
	redrawList();
	return false;
error:
	FCEU_printf("Error loading History\n");
	reset();
	return true;
}
// ----------------------------
void HISTORY::getDispInfo(NMLVDISPINFO* nmlvDispInfo)
{
	LVITEM& item = nmlvDispInfo->item;
	if (item.mask & LVIF_TEXT)
		strcpy(item.pszText, getItemDesc(item.iItem));
}

LONG HISTORY::handleCustomDraw(NMLVCUSTOMDRAW* msg)
{
	switch(msg->nmcd.dwDrawStage)
	{
	case CDDS_PREPAINT:
		return CDRF_NOTIFYITEMDRAW;
	case CDDS_ITEMPREPAINT:
	{
		msg->clrText = HISTORY_NORMAL_COLOR;
		msg->clrTextBk = HISTORY_NORMAL_BG_COLOR;
		// if this row is not "current History item" then check if it's "related" to current
		int row = msg->nmcd.dwItemSpec;
		if (row != historyCursorPos)
		{
			int current_start_frame = snapshots[(historyStartPos + historyCursorPos) % historySize].startFrame;
			int current_end_frame = snapshots[(historyStartPos + historyCursorPos) % historySize].endFrame;
			int row_start_frame = snapshots[(historyStartPos + row) % historySize].startFrame;
			int row_end_frame = snapshots[(historyStartPos + row) % historySize].endFrame;
			if (current_end_frame >= 0)
			{
				if (row_end_frame >= 0)
				{
					// both items have defined ends, check if they intersect
					if (row_start_frame <= current_end_frame && row_end_frame >= current_start_frame)
						msg->clrTextBk = HISTORY_RELATED_BG_COLOR;
				} else
				{
					// current item has defined end, check if the row item falls into the segment
					if (row_start_frame >= current_start_frame && row_start_frame <= current_end_frame)
						msg->clrTextBk = HISTORY_RELATED_BG_COLOR;
				}
			} else
			{
				if (row_end_frame >= 0)
				{
					// row item has defined end, check if current item falls into the segment
					if (current_start_frame >= row_start_frame && current_start_frame <= row_end_frame)
						msg->clrTextBk = HISTORY_RELATED_BG_COLOR;
				} else
				{
					// both items don't have defined ends, check if they are at the same frame
					if (row_start_frame == current_start_frame)
						msg->clrTextBk = HISTORY_RELATED_BG_COLOR;
				}
			}
		}
	}
	default:
		return CDRF_DODEFAULT;
	}

}

void HISTORY::handleSingleClick(int row_index)
{
	// jump in time to pointed item
	if (row_index >= 0)
	{
		int result = jumpInTime(row_index);
		if (result >= 0)
			greenzone.invalidateAndUpdatePlayback(result);
	}
}

void HISTORY::updateList()
{
	//update the number of items in the history list
	int currLVItemCount = ListView_GetItemCount(hwndHistoryList);
	if (currLVItemCount != historyTotalItems)
		ListView_SetItemCountEx(hwndHistoryList, historyTotalItems, LVSICF_NOSCROLL | LVSICF_NOINVALIDATEALL);
}

void HISTORY::redrawList()
{
	ListView_SetItemState(hwndHistoryList, historyCursorPos, LVIS_FOCUSED|LVIS_SELECTED, LVIS_FOCUSED|LVIS_SELECTED);
	ListView_EnsureVisible(hwndHistoryList, historyCursorPos, FALSE);
	InvalidateRect(hwndHistoryList, 0, FALSE);
}
// ----------------------------
int HISTORY::getCategoryOfOperation(int modificationType)
{
	switch (modificationType)
	{
		case MODTYPE_INIT:
		case MODTYPE_UNDEFINED:
			return CATEGORY_OTHER;
		case MODTYPE_SET:
		case MODTYPE_UNSET:
		case MODTYPE_PATTERN:
			return CATEGORY_INPUT_CHANGE;
		case MODTYPE_INSERT:
		case MODTYPE_INSERTNUM:
		case MODTYPE_DELETE:
		case MODTYPE_TRUNCATE:
			return CATEGORY_INPUT_MARKERS_CHANGE;
		case MODTYPE_CLEAR:
		case MODTYPE_CUT:
		case MODTYPE_PASTE:
			return CATEGORY_INPUT_CHANGE;
		case MODTYPE_PASTEINSERT:
		case MODTYPE_CLONE:
			return CATEGORY_INPUT_MARKERS_CHANGE;
		case MODTYPE_RECORD:
		case MODTYPE_IMPORT:
			return CATEGORY_INPUT_CHANGE;
		case MODTYPE_BOOKMARK_0:
		case MODTYPE_BOOKMARK_1:
		case MODTYPE_BOOKMARK_2:
		case MODTYPE_BOOKMARK_3:
		case MODTYPE_BOOKMARK_4:
		case MODTYPE_BOOKMARK_5:
		case MODTYPE_BOOKMARK_6:
		case MODTYPE_BOOKMARK_7:
		case MODTYPE_BOOKMARK_8:
		case MODTYPE_BOOKMARK_9:
			return CATEGORY_OTHER;
		case MODTYPE_BRANCH_0:
		case MODTYPE_BRANCH_1:
		case MODTYPE_BRANCH_2:
		case MODTYPE_BRANCH_3:
		case MODTYPE_BRANCH_4:
		case MODTYPE_BRANCH_5:
		case MODTYPE_BRANCH_6:
		case MODTYPE_BRANCH_7:
		case MODTYPE_BRANCH_8:
		case MODTYPE_BRANCH_9:
			return CATEGORY_INPUT_MARKERS_CHANGE;
		case MODTYPE_BRANCH_MARKERS_0:
		case MODTYPE_BRANCH_MARKERS_1:
		case MODTYPE_BRANCH_MARKERS_2:
		case MODTYPE_BRANCH_MARKERS_3:
		case MODTYPE_BRANCH_MARKERS_4:
		case MODTYPE_BRANCH_MARKERS_5:
		case MODTYPE_BRANCH_MARKERS_6:
		case MODTYPE_BRANCH_MARKERS_7:
		case MODTYPE_BRANCH_MARKERS_8:
		case MODTYPE_BRANCH_MARKERS_9:
		case MODTYPE_MARKER_SET:
		case MODTYPE_MARKER_REMOVE:
		case MODTYPE_MARKER_PATTERN:
		case MODTYPE_MARKER_RENAME:
		case MODTYPE_MARKER_DRAG:
		case MODTYPE_MARKER_SWAP:
		case MODTYPE_MARKER_SHIFT:
		case MODTYPE_LUA_MARKER_SET:
		case MODTYPE_LUA_MARKER_REMOVE:
		case MODTYPE_LUA_MARKER_RENAME:
			return CATEGORY_MARKERS_CHANGE;
		case MODTYPE_LUA_CHANGE:
			return CATEGORY_INPUT_MARKERS_CHANGE;

	}
	// if undefined
	return CATEGORY_OTHER;
}

SNAPSHOT& HISTORY::getCurrentSnapshot()
{
	return snapshots[(historyStartPos + historyCursorPos) % historySize];
}
SNAPSHOT& HISTORY::getNextToCurrentSnapshot()
{
	if (historyCursorPos < historyTotalItems)
		return snapshots[(historyStartPos + historyCursorPos + 1) % historySize];
	else
		// return current snapshot
		return snapshots[(historyStartPos + historyCursorPos) % historySize];
}
char* HISTORY::getItemDesc(int pos)
{
	return snapshots[(historyStartPos + pos) % historySize].description;
}
int HISTORY::getUndoHint()
{
	if (showUndoHint)
		return undoHintPos;
	else
		return -1;
}
bool HISTORY::isCursorOverHistoryList()
{
	POINT p;
	if (GetCursorPos(&p))
	{
		ScreenToClient(hwndHistoryList, &p);
		RECT wrect;
		GetWindowRect(hwndHistoryList, &wrect);
		if (p.x >= 0
			&& p.y >= 0
			&& p.x < (wrect.right - wrect.left)
			&& p.y < (wrect.bottom - wrect.top))
			return true;
	}
	return false;
}
// ---------------------------------------------------------------------------------
LRESULT APIENTRY historyListWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern HISTORY history;
	switch(msg)
	{
		case WM_CHAR:
		case WM_KEYDOWN:
		case WM_KEYUP:
		case WM_KILLFOCUS:
			return 0;
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			// perform hit test
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			ListView_SubItemHitTest(hWnd, (LPARAM)&info);
			history.handleSingleClick(info.iItem);
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
		case WM_RBUTTONDOWN:
		case WM_RBUTTONDBLCLK:
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_MOUSEWHEEL:
		{
			if (!history.isCursorOverHistoryList())
				return SendMessage(pianoRoll.hwndList, msg, wParam, lParam);
			break;
		}
		case WM_MOUSEWHEEL_RESENT:
		{
			// this is message from Piano Roll
			// it means that cursor is currently over History List, and user scrolls the wheel (although focus may be on some other window)
			// ensure that wParam's low-order word is 0 (so fwKeys = 0)
			CallWindowProc(hwndHistoryList_oldWndProc, hWnd, WM_MOUSEWHEEL, wParam & ~(LOWORD(-1)), lParam);
			return 0;
		}
        case WM_MOUSEACTIVATE:
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
            break;

	}
	return CallWindowProc(hwndHistoryList_oldWndProc, hWnd, msg, wParam, lParam);
}


