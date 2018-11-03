/* ---------------------------------------------------------------------------------
Implementation file of Playback class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Playback - Player of emulation states
[Single instance]

* implements the working of movie player: show any frame (jump), run/cancel seekng. pause, rewinding
* regularly tracks and controls emulation process, prompts redrawing of Piano Roll List rows, finishes seeking when reaching target frame, animates target frame, makes Piano Roll follow Playback cursor, detects if Playback cursor moved to another Marker and updates Note in the upper text field
* implements the working of upper buttons << and >> (jumping on Markers)
* implements the working of buttons < and > (frame-by-frame movement)
* implements the working of button || (pause) and middle mouse button, also reacts on external changes of emulation pause
* implements the working of progressbar: init, reset, set value, click (cancel seeking)
* also here's the code of upper text field (for editing Marker Notes)
* stores resources: upper text field prefix, timings of target frame animation, response times of GUI buttons, progressbar scale
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "../taseditor.h"
#include "../../../fceu.h"

#ifdef _S9XLUA_H
extern void ForceExecuteLuaFrameFunctions();
#endif

extern bool mustRewindNow;
extern bool turbo;

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern SELECTION selection;
extern MARKERS_MANAGER markersManager;
extern GREENZONE greenzone;
extern PIANO_ROLL pianoRoll;
extern BOOKMARKS bookmarks;

extern void Update_RAM_Search();

LRESULT APIENTRY UpperMarkerEditWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC playbackMarkerEdit_oldWndproc;

// resources
char upperMarkerText[] = "Marker ";

PLAYBACK::PLAYBACK()
{
}

void PLAYBACK::init()
{
	hwndProgressbar = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_PROGRESS1);
	SendMessage(hwndProgressbar, PBM_SETRANGE, 0, MAKELPARAM(0, PROGRESSBAR_WIDTH)); 
	hwndRewind = GetDlgItem(taseditorWindow.hwndTASEditor, TASEDITOR_REWIND);
	hwndForward = GetDlgItem(taseditorWindow.hwndTASEditor, TASEDITOR_FORWARD);
	hwndRewindFull = GetDlgItem(taseditorWindow.hwndTASEditor, TASEDITOR_REWIND_FULL);
	hwndForwardFull = GetDlgItem(taseditorWindow.hwndTASEditor, TASEDITOR_FORWARD_FULL);
	hwndPlaybackMarkerNumber = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_PLAYBACK_MARKER);
	SendMessage(hwndPlaybackMarkerNumber, WM_SETFONT, (WPARAM)pianoRoll.hMarkersFont, 0);
	hwndPlaybackMarkerEditField = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_PLAYBACK_MARKER_EDIT);
	SendMessage(hwndPlaybackMarkerEditField, EM_SETLIMITTEXT, MAX_NOTE_LEN - 1, 0);
	SendMessage(hwndPlaybackMarkerEditField, WM_SETFONT, (WPARAM)pianoRoll.hMarkersEditFont, 0);
	// subclass the edit control
	playbackMarkerEdit_oldWndproc = (WNDPROC)SetWindowLong(hwndPlaybackMarkerEditField, GWL_WNDPROC, (LONG)UpperMarkerEditWndProc);

	reset();
}
void PLAYBACK::reset()
{
	mustAutopauseAtTheEnd = true;
	mustFindCurrentMarker = true;
	displayedMarkerNumber = 0;
	lastCursorPos = currFrameCounter;
	lastPositionFrame = pauseFrame = oldPauseFrame = 0;
	lastPositionIsStable = oldStateOfShowPauseFrame = showPauseFrame = false;
	rewindButtonOldState = rewindButtonState = false;
	forwardButtonOldState = forwardButtonState = false;
	rewindFullButtonOldState = rewindFullButtonState = false;
	forwardFullButtonOldState = forwardFullButtonState = false;
	emuPausedOldState = emuPausedState = true;
	stopSeeking();
}
void PLAYBACK::update()
{
	// controls:
	// update < and > buttons
	rewindButtonOldState = rewindButtonState;
	rewindButtonState = ((Button_GetState(hwndRewind) & BST_PUSHED) != 0 || mustRewindNow);
	if (rewindButtonState)
	{
		if (!rewindButtonOldState)
		{
			buttonHoldTimer = clock();
			handleRewindFrame();
		} else if (buttonHoldTimer + BUTTON_HOLD_REPEAT_DELAY < clock())
		{
			handleRewindFrame();
		}
	}
	forwardButtonOldState = forwardButtonState;
	forwardButtonState = (Button_GetState(hwndForward) & BST_PUSHED) != 0;
	if (forwardButtonState && !rewindButtonState)
	{
		if (!forwardButtonOldState)
		{
			buttonHoldTimer = clock();
			handleForwardFrame();
		} else if (buttonHoldTimer + BUTTON_HOLD_REPEAT_DELAY < clock())
		{
			handleForwardFrame();
		}
	}
	// update << and >> buttons
	rewindFullButtonOldState = rewindFullButtonState;
	rewindFullButtonState = ((Button_GetState(hwndRewindFull) & BST_PUSHED) != 0);
	if (rewindFullButtonState && !rewindButtonState && !forwardButtonState)
	{
		if (!rewindFullButtonOldState)
		{
			buttonHoldTimer = clock();
			handleRewindFull();
		} else if (buttonHoldTimer + BUTTON_HOLD_REPEAT_DELAY < clock())
		{
			handleRewindFull();
		}
	}
	forwardFullButtonOldState = forwardFullButtonState;
	forwardFullButtonState = (Button_GetState(hwndForwardFull) & BST_PUSHED) != 0;
	if (forwardFullButtonState && !rewindButtonState && !forwardButtonState && !rewindFullButtonState)
	{
		if (!forwardFullButtonOldState)
		{
			buttonHoldTimer = clock();
			handleForwardFull();
		} else if (buttonHoldTimer + BUTTON_HOLD_REPEAT_DELAY < clock())
		{
			handleForwardFull();
		}
	}

	// update the Playback cursor
	if (currFrameCounter != lastCursorPos)
	{
		// update gfx of the old and new rows
		pianoRoll.redrawRow(lastCursorPos);
		bookmarks.redrawChangedBookmarks(lastCursorPos);
		pianoRoll.redrawRow(currFrameCounter);
		bookmarks.redrawChangedBookmarks(currFrameCounter);
		lastCursorPos = currFrameCounter;
		// follow the Playback cursor, but in case of seeking don't follow it
		pianoRoll.followPlaybackCursorIfNeeded(false);	//pianoRoll.updatePlaybackCursorPositionInPianoRoll();	// an unfinished experiment
		// enforce redrawing now
		UpdateWindow(pianoRoll.hwndList);
		// lazy update of "Playback's Marker text"
		int current_marker = markersManager.getMarkerAboveFrame(currFrameCounter);
		if (displayedMarkerNumber != current_marker)
		{
			markersManager.updateEditedMarkerNote();
			displayedMarkerNumber = current_marker;
			redrawMarkerData();
			mustFindCurrentMarker = false;
		}
	}
	// [non-lazy] update "Playback's Marker text" if needed
	if (mustFindCurrentMarker)
	{
		markersManager.updateEditedMarkerNote();
		displayedMarkerNumber = markersManager.getMarkerAboveFrame(currFrameCounter);
		redrawMarkerData();
		mustFindCurrentMarker = false;
	}

	// pause when seeking hits pause_frame
	if (pauseFrame && currFrameCounter + 1 >= pauseFrame)
		stopSeeking();
	else if (currFrameCounter >= getLastPosition() && currFrameCounter >= currMovieData.getNumRecords() - 1 && mustAutopauseAtTheEnd && taseditorConfig.autopauseAtTheEndOfMovie && !isTaseditorRecording())
		// pause at the end of the movie
		pauseEmulation();

	// update flashing pauseframe
	if (oldPauseFrame != pauseFrame && oldPauseFrame)
	{
		// pause_frame was changed, clear old_pauseframe gfx
		pianoRoll.redrawRow(oldPauseFrame-1);
		bookmarks.redrawChangedBookmarks(oldPauseFrame-1);
	}
	oldPauseFrame = pauseFrame;
	oldStateOfShowPauseFrame = showPauseFrame;
	if (pauseFrame)
	{
		if (emuPausedState)
			showPauseFrame = (int)(clock() / PAUSEFRAME_BLINKING_PERIOD_WHEN_PAUSED) & 1;
		else
			showPauseFrame = (int)(clock() / PAUSEFRAME_BLINKING_PERIOD_WHEN_SEEKING) & 1;
	} else showPauseFrame = false;
	if (oldStateOfShowPauseFrame != showPauseFrame)
	{
		// update pauseframe gfx
		pianoRoll.redrawRow(pauseFrame - 1);
		bookmarks.redrawChangedBookmarks(pauseFrame - 1);
	}

	// update seeking progressbar
	emuPausedOldState = emuPausedState;
	emuPausedState = (FCEUI_EmulationPaused() != 0);
	if (pauseFrame)
	{
		if (oldStateOfShowPauseFrame != showPauseFrame)		// update progressbar from time to time
			// display seeking progress
			setProgressbar(currFrameCounter - seekingBeginningFrame, pauseFrame - seekingBeginningFrame);
	} else if (emuPausedOldState != emuPausedState)
	{
		// emulator got paused/unpaused externally
		if (emuPausedOldState && !emuPausedState)
		{
			// externally unpaused - show empty progressbar
			setProgressbar(0, 1);
		} else
		{
			// externally paused - progressbar should be full
			setProgressbar(1, 1);
		}
	}

	// prepare to stop at the end of the movie in case user unpauses emulator
	if (emuPausedState)
	{
		if (currFrameCounter < currMovieData.getNumRecords() - 1)
			mustAutopauseAtTheEnd = true;
		else
			mustAutopauseAtTheEnd = false;
	}

	// this little statement is very important for adequate work of the "green arrow" and "Restore last position"
	if (!emuPausedState)
		// when emulating, lost_position_frame becomes unstable (which means that it's probably not equal to the end of current segment anymore)
		lastPositionIsStable = false;
}

// called after saving the project, because saving uses the progressbar for itself
void PLAYBACK::updateProgressbar()
{
	if (pauseFrame)
	{
		setProgressbar(currFrameCounter - seekingBeginningFrame, pauseFrame - seekingBeginningFrame);
	} else
	{
		if (emuPausedState)
			// full progressbar
			setProgressbar(1, 1);
		else
			// cleared progressbar
			setProgressbar(0, 1);
	}
	RedrawWindow(hwndProgressbar, NULL, NULL, RDW_INVALIDATE);
}

void PLAYBACK::toggleEmulationPause()
{
	if (FCEUI_EmulationPaused())
		unpauseEmulation();
	else
		pauseEmulation();
}
void PLAYBACK::pauseEmulation()
{
	FCEUI_SetEmulationPaused(EMULATIONPAUSED_PAUSED);
}
void PLAYBACK::unpauseEmulation()
{
	FCEUI_SetEmulationPaused(0);
}
void PLAYBACK::restoreLastPosition()
{
	if (getLastPosition() > currFrameCounter)
	{
		if (emuPausedState)
			startSeekingToFrame(getLastPosition());
		else
			pauseEmulation();
	}
}
void PLAYBACK::handleMiddleButtonClick()
{
	if (emuPausedState)
	{
		// Unpause or start seeking
		// works only when right mouse button is released
		if (GetAsyncKeyState(GetSystemMetrics(SM_SWAPBUTTON) ? VK_LBUTTON : VK_RBUTTON) >= 0)
		{
			if (GetAsyncKeyState(VK_SHIFT) < 0)
			{
				// if Shift is held, seek to nearest Marker
				int last_frame = markersManager.getMarkersArraySize() - 1;	// the end of movie Markers
				int target_frame = currFrameCounter + 1;
				for (; target_frame <= last_frame; ++target_frame)
					if (markersManager.getMarkerAtFrame(target_frame)) break;
				if (target_frame <= last_frame)
					startSeekingToFrame(target_frame);
			} else if (GetAsyncKeyState(VK_CONTROL) < 0)
			{
				// if Ctrl is held, seek to Selection cursor or replay from Selection cursor
				int selection_beginning = selection.getCurrentRowsSelectionBeginning();
				if (selection_beginning > currFrameCounter)
				{
					startSeekingToFrame(selection_beginning);
				} else if (selection_beginning < currFrameCounter)
				{
					int saved_currFrameCounter = currFrameCounter;
					if (selection_beginning < 0)
						selection_beginning = 0;
					jump(selection_beginning);
					startSeekingToFrame(saved_currFrameCounter);
				}
			} else if (getPauseFrame() < 0 && getLastPosition() >= greenzone.getSize())
			{
				restoreLastPosition();
			} else
			{
				unpauseEmulation();
			}
		}
	} else
	{
		pauseEmulation();
	}
}

void PLAYBACK::startSeekingToFrame(int frame)
{
	if ((pauseFrame - 1) != frame)
	{
		seekingBeginningFrame = currFrameCounter;
		pauseFrame = frame + 1;
	}
	if (taseditorConfig.turboSeek)
		turbo = true;
	unpauseEmulation();
}
void PLAYBACK::stopSeeking()
{
	pauseFrame = 0;
	turbo = false;
	pauseEmulation();
	setProgressbar(1, 1);
}

void PLAYBACK::handleRewindFrame()
{
	if (pauseFrame && !emuPausedState) return;
	if (currFrameCounter > 0)
		jump(currFrameCounter - 1);
	else
		// cursor is at frame 0 - can't rewind, but still must make cursor visible if needed
		pianoRoll.followPlaybackCursorIfNeeded(true);
	if (!pauseFrame)
		pauseEmulation();
}
void PLAYBACK::handleForwardFrame()
{
	if (pauseFrame && !emuPausedState) return;
	jump(currFrameCounter + 1);
	if (!pauseFrame)
		pauseEmulation();
	turbo = false;
}
void PLAYBACK::handleRewindFull(int speed)
{
	int index = currFrameCounter - 1;
	// jump trough "speed" amount of previous Markers
	while (speed > 0)
	{
		for (; index >= 0; index--)
			if (markersManager.getMarkerAtFrame(index)) break;
		speed--;
	}
	if (index >= 0)
		jump(index);						// jump to the Marker
	else
		jump(0);							// jump to the beginning of Piano Roll
}
void PLAYBACK::handleForwardFull(int speed)
{
	int last_frame = markersManager.getMarkersArraySize() - 1;	// the end of movie Markers
	int index = currFrameCounter + 1;
	// jump trough "speed" amount of next Markers
	while (speed > 0)
	{
		for (; index <= last_frame; ++index)
			if (markersManager.getMarkerAtFrame(index)) break;
		speed--;
	}
	if (index <= last_frame)
		jump(index);								// jump to Marker
	else
		jump(currMovieData.getNumRecords() - 1);	// jump to the end of Piano Roll
}

void PLAYBACK::redrawMarkerData()
{
	// redraw Marker num
	char new_text[MAX_NOTE_LEN] = {0};
	if (displayedMarkerNumber <= 9999)		// if there's too many digits in the number then don't show the word "Marker" before the number
		strcpy(new_text, upperMarkerText);
	char num[11];
	_itoa(displayedMarkerNumber, num, 10);
	strcat(new_text, num);
	strcat(new_text, " ");
	SetWindowText(hwndPlaybackMarkerNumber, new_text);
	// change Marker Note
	strcpy(new_text, markersManager.getNoteCopy(displayedMarkerNumber).c_str());
	SetWindowText(hwndPlaybackMarkerEditField, new_text);
	// reset search_similar_marker, because source Marker changed
	markersManager.currentIterationOfFindSimilar = 0;
}

void PLAYBACK::restartPlaybackFromZeroGround()
{
	poweron(true);
	FCEUMOV_ClearCommands();		// clear POWER SWITCH command caused by poweron()
	currFrameCounter = 0;
	// if there's no frames in current movie, create initial frame record
	if (currMovieData.getNumRecords() == 0)
		currMovieData.insertEmpty(-1, 1);
}

void PLAYBACK::ensurePlaybackIsInsideGreenzone(bool executeLua)
{
	// set the Playback cursor to the frame or at least above the frame
	if (setPlaybackAboveOrToFrame(greenzone.getSize() - 1))
	{
		// since the game state was changed by this jump, we must update possible Lua callbacks and other tools that would normally only update in FCEUI_Emulate
		if (executeLua)
			ForceExecuteLuaFrameFunctions();
		Update_RAM_Search(); // Update_RAM_Watch() is also called.
	}
	// follow the Playback cursor, but in case of seeking don't follow it
	pianoRoll.followPlaybackCursorIfNeeded(false);
}

// an interface for sending Playback cursor to any frame
void PLAYBACK::jump(int frame, bool forceStateReload, bool executeLua, bool followPauseframe)
{
	if (frame < 0) return;

	int lastCursor = currFrameCounter;

	// 1 - set the Playback cursor to the frame or at least above the frame
	if (setPlaybackAboveOrToFrame(frame, forceStateReload))
	{
		// since the game state was changed by this jump, we must update possible Lua callbacks and other tools that would normally only update in FCEUI_Emulate
		if (executeLua)
			ForceExecuteLuaFrameFunctions();
		Update_RAM_Search(); // Update_RAM_Watch() is also called.
	}

	// 2 - seek from the current frame if we still aren't at the needed frame
	if (frame > currFrameCounter)
	{
		startSeekingToFrame(frame);
	} else
	{
		// the Playback is already at the needed frame
		if (pauseFrame)	// if Playback was seeking, pause emulation right here
			stopSeeking();
	}

	// follow the Playback cursor, and optionally follow pauseframe (if seeking was launched)
	pianoRoll.followPlaybackCursorIfNeeded(followPauseframe);

	// redraw respective Piano Roll lines if needed
	if (lastCursor != currFrameCounter)
	{
		// redraw row where Playback cursor was (in case there's two or more drags before playback.update())
		pianoRoll.redrawRow(lastCursor);
		bookmarks.redrawChangedBookmarks(lastCursor);
	}
}

// returns true if the game state was changed (loaded)
bool PLAYBACK::setPlaybackAboveOrToFrame(int frame, bool forceStateReload)
{
	bool state_changed = false;
	// search backwards for an earlier frame with valid savestate
	int i = greenzone.getSize() - 1;
	if (i > frame)
		i = frame;
	for (; i >= 0; i--)
	{
		if (!forceStateReload && !state_changed && i == currFrameCounter)
		{
			// we can remain at current game state
			break;
		} else if (!greenzone.isSavestateEmpty(i))
		{
			state_changed = true;	// after we once tried loading a savestate, we cannot use currFrameCounter state anymore, because the game state might have been corrupted by this loading attempt
			if (greenzone.loadSavestateOfFrame(i))
				break;
		}
	}
	if (i < 0)
	{
		// couldn't find a savestate
		restartPlaybackFromZeroGround();
		state_changed = true;
	}
	return state_changed;
}

void PLAYBACK::setLastPosition(int frame)
{
	if ((lastPositionFrame - 1 < frame) || (lastPositionFrame - 1 >= frame && !lastPositionIsStable))
	{
		if (lastPositionFrame)
			pianoRoll.redrawRow(lastPositionFrame - 1);
		lastPositionFrame = frame + 1;
		lastPositionIsStable = true;
	}
}
int PLAYBACK::getLastPosition()
{
	return lastPositionFrame - 1;
}

int PLAYBACK::getPauseFrame()
{
	return pauseFrame - 1;
}
int PLAYBACK::getFlashingPauseFrame()
{
	if (showPauseFrame)
		return pauseFrame;
	else
		return 0;
}

void PLAYBACK::setProgressbar(int a, int b)
{
	SendMessage(hwndProgressbar, PBM_SETPOS, PROGRESSBAR_WIDTH * a / b, 0);
}
void PLAYBACK::cancelSeeking()
{
	if (pauseFrame)
		stopSeeking();
}
// -------------------------------------------------------------------------
LRESULT APIENTRY UpperMarkerEditWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern PLAYBACK playback;
	extern SELECTION selection;
	switch(msg)
	{
		case WM_SETFOCUS:
		{
			markersManager.markerNoteEditMode = MARKER_NOTE_EDIT_UPPER;
			// enable editing
			SendMessage(playback.hwndPlaybackMarkerEditField, EM_SETREADONLY, false, 0);
			// disable FCEUX keyboard
			disableGeneralKeyboardInput();
			break;
		}
		case WM_KILLFOCUS:
		{
			// if we were editing, save and finish editing
			if (markersManager.markerNoteEditMode == MARKER_NOTE_EDIT_UPPER)
			{
				markersManager.updateEditedMarkerNote();
				markersManager.markerNoteEditMode = MARKER_NOTE_EDIT_NONE;
			}
			// disable editing (make the bg grayed)
			SendMessage(playback.hwndPlaybackMarkerEditField, EM_SETREADONLY, true, 0);
			// enable FCEUX keyboard
			if (taseditorWindow.TASEditorIsInFocus)
				enableGeneralKeyboardInput();
			break;
		}
		case WM_CHAR:
		case WM_KEYDOWN:
		{
			if (markersManager.markerNoteEditMode == MARKER_NOTE_EDIT_UPPER)
			{
				switch(wParam)
				{
					case VK_ESCAPE:
						// revert text to original note text
						SetWindowText(playback.hwndPlaybackMarkerEditField, markersManager.getNoteCopy(playback.displayedMarkerNumber).c_str());
						SetFocus(pianoRoll.hwndList);
						return 0;
					case VK_RETURN:
						// exit and save text changes
						SetFocus(pianoRoll.hwndList);
						return 0;
					case VK_TAB:
					{
						// switch to lower edit control (also exit and save text changes)
						SetFocus(selection.hwndSelectionMarkerEditField);
						// scroll to the Marker
						if (taseditorConfig.followMarkerNoteContext)
							pianoRoll.followMarker(selection.displayedMarkerNumber);
						return 0;
					}
				}
			}
			break;
		}
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
		{
			playback.handleMiddleButtonClick();
			return 0;
		}
		case WM_LBUTTONDOWN:
		case WM_RBUTTONDOWN:
		{
			// scroll to the Marker
			if (taseditorConfig.followMarkerNoteContext)
				pianoRoll.followMarker(playback.displayedMarkerNumber);
			break;
		}
	}
	return CallWindowProc(playbackMarkerEdit_oldWndproc, hWnd, msg, wParam, lParam);
}

