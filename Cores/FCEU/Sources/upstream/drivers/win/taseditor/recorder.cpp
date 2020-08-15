/* ---------------------------------------------------------------------------------
Implementation file of RECORDER class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Recorder - Tool for Input recording
[Single instance]

* at the moment of recording movie Input (at the very end of a frame) by emulator's call the Recorder intercepts Input data and applies its filters (multitracking/etc), then reflects Input changes into History and Greenzone
* regularly tracks virtual joypad buttonpresses and provides data for Piano Roll List Header lights. Also reacts on external changes of Recording status, and updates GUI (Recorder panel and Bookmarks/Branches caption)
* implements Input editing in Read-only mode (ColumnSet by pressing buttons on virtual joypad)
* stores resources: ids and names of multitracking modes, suffixes for TAS Editor window caption
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"

extern int joysticksPerFrame[INPUT_TYPES_TOTAL];

extern uint32 GetGamepadPressedImmediate();
extern int getInputType(MovieData& md);

extern char lagFlag;

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern BOOKMARKS bookmarks;
extern HISTORY history;
extern GREENZONE greenzone;
extern PIANO_ROLL pianoRoll;
extern EDITOR editor;

// resources
const char recordingCheckbox[11] = " Recording";
const char recordingCheckboxBlankPattern[17] = " Recording blank";

const char recordingModes[5][4] = {	"All",
								"1P",
								"2P",
								"3P",
								"4P"};
const char recordingCaptions[5][17] = {	" (Recording All)",
									" (Recording 1P)",
									" (Recording 2P)",
									" (Recording 3P)",
									" (Recording 4P)"};
RECORDER::RECORDER()
{
}

void RECORDER::init()
{
	hwndRecordingCheckbox = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RECORDING);
	hwndRadioButtonRecordAll = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RADIO_ALL);
	hwndRadioButtonRecord1P = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RADIO_1P);
	hwndRadioButtonRecord2P = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RADIO_2P);
	hwndRadioButtonRecord3P = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RADIO_3P);
	hwndRadioButtonRecord4P = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_RADIO_4P);
	oldMultitrackRecordingJoypadNumber = multitrackRecordingJoypadNumber;
	oldCurrentPattern = oldPatternOffset = 0;
	mustIncreasePatternOffset = false;
	oldStateOfMovieReadonly = movie_readonly;
	oldJoyData.resize(MAX_NUM_JOYPADS);
	newJoyData.resize(MAX_NUM_JOYPADS);
	currentJoypadData.resize(MAX_NUM_JOYPADS);
}
void RECORDER::reset()
{
	movie_readonly = true;
	stateWasLoadedInReadWriteMode = false;
	multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_ALL;
	patternOffset = 0;
	mustIncreasePatternOffset = false;
	uncheckRecordingRadioButtons();
	recheckRecordingRadioButtons();
	switch (getInputType(currMovieData))
	{
		case INPUT_TYPE_FOURSCORE:
		{
			// enable all 4 radiobuttons
			EnableWindow(hwndRadioButtonRecord1P, true);
			EnableWindow(hwndRadioButtonRecord2P, true);
			EnableWindow(hwndRadioButtonRecord3P, true);
			EnableWindow(hwndRadioButtonRecord4P, true);
			break;
		}
		case INPUT_TYPE_2P:
		{
			// enable radiobuttons 1 and 2
			EnableWindow(hwndRadioButtonRecord1P, true);
			EnableWindow(hwndRadioButtonRecord2P, true);
			// disable radiobuttons 3 and 4
			EnableWindow(hwndRadioButtonRecord3P, false);
			EnableWindow(hwndRadioButtonRecord4P, false);
			break;
		}
		case INPUT_TYPE_1P:
		{
			// enable radiobutton 1
			EnableWindow(hwndRadioButtonRecord1P, true);
			// disable radiobuttons 2, 3 and 4
			EnableWindow(hwndRadioButtonRecord2P, false);
			EnableWindow(hwndRadioButtonRecord3P, false);
			EnableWindow(hwndRadioButtonRecord4P, false);
			break;
		}
	}
}
void RECORDER::update()
{
	// update window caption if needed
	if (oldStateOfMovieReadonly != movie_readonly || oldMultitrackRecordingJoypadNumber != multitrackRecordingJoypadNumber)
		taseditorWindow.updateCaption();
	// update Bookmarks/Branches groupbox caption if needed
	if (taseditorConfig.oldControlSchemeForBranching && oldStateOfMovieReadonly != movie_readonly)
		bookmarks.redrawBookmarksSectionCaption();
	// update "Recording" checkbox state
	if (oldStateOfMovieReadonly != movie_readonly)
	{
		Button_SetCheck(hwndRecordingCheckbox, movie_readonly?BST_UNCHECKED : BST_CHECKED);
		oldStateOfMovieReadonly = movie_readonly;
		if (movie_readonly)
			stateWasLoadedInReadWriteMode = false;
	}
	// reset pattern_offset if current_pattern has changed
	if (oldCurrentPattern != taseditorConfig.currentPattern)
		patternOffset = 0;
	// increase pattern_offset if needed
	if (mustIncreasePatternOffset)
	{
		mustIncreasePatternOffset = false;
		if (!taseditorConfig.autofirePatternSkipsLag || lagFlag == 0)
		{
			patternOffset++;
			if (patternOffset >= (int)editor.patterns[oldCurrentPattern].size())
				patternOffset -= editor.patterns[oldCurrentPattern].size();
		}
	}
	// update "Recording" checkbox text if something changed in pattern
	if (oldCurrentPattern != taseditorConfig.currentPattern || oldPatternOffset != patternOffset)
	{
		oldCurrentPattern = taseditorConfig.currentPattern;
		oldPatternOffset = patternOffset;
		if (!taseditorConfig.recordingUsePattern || editor.patterns[oldCurrentPattern][patternOffset])
			// either not using Patterns or current pattern has 1 in current offset
			SetWindowText(hwndRecordingCheckbox, recordingCheckbox);
		else
			// current pattern has 0 in current offset, this means next recorded frame will be blank
			SetWindowText(hwndRecordingCheckbox, recordingCheckboxBlankPattern);
	}
	// update recording radio buttons if user changed multitrack_recording_joypad
	if (oldMultitrackRecordingJoypadNumber != multitrackRecordingJoypadNumber)
	{
		uncheckRecordingRadioButtons();
		recheckRecordingRadioButtons();
	}

	int num_joys = joysticksPerFrame[getInputType(currMovieData)];
	// save previous state
	oldJoyData[0] = currentJoypadData[0];
	oldJoyData[1] = currentJoypadData[1];
	oldJoyData[2] = currentJoypadData[2];
	oldJoyData[3] = currentJoypadData[3];
	// fill current_joy data for Piano Roll header lights
	uint32 joypads = GetGamepadPressedImmediate();
	currentJoypadData[0] = (joypads & 0xFF);
	currentJoypadData[1] = ((joypads >> 8) & 0xFF);
	currentJoypadData[2] = ((joypads >> 16) & 0xFF);
	currentJoypadData[3] = ((joypads >> 24) & 0xFF);
	// filter out joysticks that should not be recorded (according to multitrack_recording_joypad)
	if (multitrackRecordingJoypadNumber != MULTITRACK_RECORDING_ALL)
	{
		int joy = multitrackRecordingJoypadNumber - 1;
		// substitute target joypad with 1p joypad
		if (multitrackRecordingJoypadNumber > MULTITRACK_RECORDING_1P && taseditorConfig.use1PKeysForAllSingleRecordings)
			currentJoypadData[joy] = currentJoypadData[0];
		// clear all other joypads (pressing them does not count)
		for (int i = 0; i < num_joys; ++i)
			if (i != joy)
				currentJoypadData[i] = 0;
	}
	// call ColumnSet if needed
	if (taseditorConfig.useInputKeysForColumnSet && movie_readonly && taseditorWindow.TASEditorIsInFocus)
	{
		// if Ctrl or Shift is held, do not call ColumnSet, because maybe this is accelerator
		if ((GetAsyncKeyState(VK_CONTROL) >= 0) && (GetAsyncKeyState(VK_SHIFT) >= 0))
		{
			bool alt_pressed = ((GetAsyncKeyState(VK_MENU) & 0x8000) != 0);
			for (int joy = 0; joy < num_joys; ++joy)
			{
				for (int button = 0; button < NUM_JOYPAD_BUTTONS; ++button)
				{
					// if the button was pressed right now
					if ((currentJoypadData[joy] & (1 << button)) && !(oldJoyData[joy] & (1 << button)))
						pianoRoll.handleColumnSet(COLUMN_JOYPAD1_A + joy * NUM_JOYPAD_BUTTONS + button, alt_pressed);
				}
			}
		}
	}
}
// ------------------------------------------------------------------------------------
void RECORDER::uncheckRecordingRadioButtons()
{
	Button_SetCheck(hwndRadioButtonRecordAll, BST_UNCHECKED);
	Button_SetCheck(hwndRadioButtonRecord1P, BST_UNCHECKED);
	Button_SetCheck(hwndRadioButtonRecord2P, BST_UNCHECKED);
	Button_SetCheck(hwndRadioButtonRecord3P, BST_UNCHECKED);
	Button_SetCheck(hwndRadioButtonRecord4P, BST_UNCHECKED);
}
void RECORDER::recheckRecordingRadioButtons()
{
	oldMultitrackRecordingJoypadNumber = multitrackRecordingJoypadNumber;
	switch(multitrackRecordingJoypadNumber)
	{
	case MULTITRACK_RECORDING_ALL:
		Button_SetCheck(hwndRadioButtonRecordAll, BST_CHECKED);
		break;
	case MULTITRACK_RECORDING_1P:
		Button_SetCheck(hwndRadioButtonRecord1P, BST_CHECKED);
		break;
	case MULTITRACK_RECORDING_2P:
		Button_SetCheck(hwndRadioButtonRecord2P, BST_CHECKED);
		break;
	case MULTITRACK_RECORDING_3P:
		Button_SetCheck(hwndRadioButtonRecord3P, BST_CHECKED);
		break;
	case MULTITRACK_RECORDING_4P:
		Button_SetCheck(hwndRadioButtonRecord4P, BST_CHECKED);
		break;
	default:
		multitrackRecordingJoypadNumber = MULTITRACK_RECORDING_ALL;
		Button_SetCheck(hwndRadioButtonRecordAll, BST_CHECKED);
		break;
	}
}

void RECORDER::recordInput()
{
	bool changes_made = false;
	uint32 joypad_diff_bits = 0;
	int num_joys = joysticksPerFrame[getInputType(currMovieData)];
	// take previous values from current snapshot, new Input from current movie
	for (int i = 0; i < num_joys; ++i)
	{
		oldJoyData[i] = history.getCurrentSnapshot().inputlog.getJoystickData(currFrameCounter, i);
		if (!taseditorConfig.recordingUsePattern || editor.patterns[oldCurrentPattern][patternOffset])
			newJoyData[i] = currMovieData.records[currFrameCounter].joysticks[i];
		else
			newJoyData[i] = 0;		// blank
	}
	if (taseditorConfig.recordingUsePattern)
		// postpone incrementing pattern_offset to the end of the frame (when lagFlag will be known)
		mustIncreasePatternOffset = true;
	// combine old and new data (superimpose) and filter out joystics that should not be recorded
	if (multitrackRecordingJoypadNumber == MULTITRACK_RECORDING_ALL)
	{
		for (int i = num_joys-1; i >= 0; i--)
		{
			// superimpose (bitwise OR) if needed
			if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED || (taseditorConfig.superimpose == SUPERIMPOSE_INDETERMINATE && newJoyData[i] == 0))
				newJoyData[i] |= oldJoyData[i];
			// change this joystick
			currMovieData.records[currFrameCounter].joysticks[i] = newJoyData[i];
			if (newJoyData[i] != oldJoyData[i])
			{
				changes_made = true;
				joypad_diff_bits |= (1 << (i + 1));		// bit 0 = Commands, bit 1 = Joypad 1, bit 2 = Joypad 2, bit 3 = Joypad 3, bit 4 = Joypad 4
				// set lights for changed buttons
				for (int button = 0; button < NUM_JOYPAD_BUTTONS; ++button)
					if ((newJoyData[i] & (1 << button)) && !(oldJoyData[i] & (1 << button)))
						pianoRoll.setLightInHeaderColumn(COLUMN_JOYPAD1_A + i * NUM_JOYPAD_BUTTONS + button, HEADER_LIGHT_MAX);
			}
		}
	} else
	{
		int joy = multitrackRecordingJoypadNumber - 1;
		// substitute target joypad with 1p joypad
		if (multitrackRecordingJoypadNumber > MULTITRACK_RECORDING_1P && taseditorConfig.use1PKeysForAllSingleRecordings)
			newJoyData[joy] = newJoyData[0];
		// superimpose (bitwise OR) if needed
		if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED || (taseditorConfig.superimpose == SUPERIMPOSE_INDETERMINATE && newJoyData[joy] == 0))
			newJoyData[joy] |= oldJoyData[joy];
		// other joysticks should not be changed
		for (int i = num_joys-1; i >= 0; i--)
			currMovieData.records[currFrameCounter].joysticks[i] = oldJoyData[i];	// revert to old
		// change only this joystick
		currMovieData.records[currFrameCounter].joysticks[joy] = newJoyData[joy];
		if (newJoyData[joy] != oldJoyData[joy])
		{
			changes_made = true;
			joypad_diff_bits |= (1 << (joy + 1));		// bit 0 = Commands, bit 1 = Joypad 1, bit 2 = Joypad 2, bit 3 = Joypad 3, bit 4 = Joypad 4
			// set lights for changed buttons
			for (int button = 0; button < NUM_JOYPAD_BUTTONS; ++button)
				if ((newJoyData[joy] & (1 << button)) && !(oldJoyData[joy] & (1 << button)))
					pianoRoll.setLightInHeaderColumn(COLUMN_JOYPAD1_A + joy * NUM_JOYPAD_BUTTONS + button, HEADER_LIGHT_MAX);
		}
	}

	// check if new commands were recorded
	if (currMovieData.records[currFrameCounter].commands != history.getCurrentSnapshot().inputlog.getCommandsData(currFrameCounter))
	{
		changes_made = true;
		joypad_diff_bits |= 1;		// bit 0 = Commands, bit 1 = Joypad 1, bit 2 = Joypad 2, bit 3 = Joypad 3, bit 4 = Joypad 4
	}

	// register changes
	if (changes_made)
	{
		history.registerRecording(currFrameCounter, joypad_diff_bits);
		greenzone.invalidate(currFrameCounter);
	}
}

// getters
const char* RECORDER::getRecordingMode()
{
	return recordingModes[multitrackRecordingJoypadNumber];
}
const char* RECORDER::getRecordingCaption()
{
	return recordingCaptions[multitrackRecordingJoypadNumber];
}

