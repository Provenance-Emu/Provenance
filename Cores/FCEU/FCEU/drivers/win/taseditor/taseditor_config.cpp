/* ---------------------------------------------------------------------------------
Implementation file of TASEDITOR_CONFIG class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Config - Current settings
[Single instance]

* stores current state of all TAS Editor settings
* all TAS Editor modules can get or set any data within Config
* when launching FCEUX, the emulator writes data from fceux.cfg file to the Config, when exiting it reads the data back to fceux.cfg
* stores resources: default values of all settings, min/max values of settings
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"

TASEDITOR_CONFIG::TASEDITOR_CONFIG()
{
	// set default values
	windowX = 0;
	windowY = 0;
	windowWidth = 0;
	windowHeight = 0;
	savedWindowX = 0;
	savedWindowY = 0;
	savedWindowWidth = 0;
	savedWindowHeight = 0;
	windowIsMaximized = false;

	findnoteWindowX = 0;
	findnoteWindowY = 0;
	findnoteMatchCase = false;
	findnoteSearchUp = false;

	followPlaybackCursor = true;
	turboSeek = false;
	autoRestoreLastPlaybackPosition = false;
	superimpose = SUPERIMPOSE_UNCHECKED;
	recordingUsePattern = false;
	enableLuaAutoFunction = true;

	displayBranchesTree = false;
	displayBranchScreenshots = true;
	displayBranchDescriptions = true;
	enableHotChanges = true;
	followUndoContext = true;
	followMarkerNoteContext = true;

	greenzoneCapacity = GREENZONE_CAPACITY_DEFAULT;
	maxUndoLevels = UNDO_LEVELS_DEFAULT;
	enableGreenzoning = true;
	autofirePatternSkipsLag = true;
	autoAdjustInputAccordingToLag = true;
	drawInputByDragging = true;
	combineConsecutiveRecordingsAndDraws = false;
	use1PKeysForAllSingleRecordings = true;
	useInputKeysForColumnSet = false;
	bindMarkersToInput = true;
	emptyNewMarkerNotes = true;
	oldControlSchemeForBranching = false;
	branchesRestoreEntireMovie = true;
	HUDInBranchScreenshots = true;
	autopauseAtTheEndOfMovie = true;

	lastExportedInputType = INPUT_TYPE_1P;
	lastExportedSubtitlesStatus = false;

	projectSavingOptions_SaveInBinary = true;
	projectSavingOptions_SaveMarkers = true;
	projectSavingOptions_SaveBookmarks = true;
	projectSavingOptions_SaveHistory = true;
	projectSavingOptions_SavePianoRoll = true;
	projectSavingOptions_SaveSelection = true;
	projectSavingOptions_GreenzoneSavingMode = GREENZONE_SAVING_MODE_ALL;

	saveCompact_SaveInBinary = true;
	saveCompact_SaveMarkers = true;
	saveCompact_SaveBookmarks = true;
	saveCompact_SaveHistory = false;
	saveCompact_SavePianoRoll = true;
	saveCompact_SaveSelection = false;
	saveCompact_GreenzoneSavingMode = GREENZONE_SAVING_MODE_NO;

	autosaveEnabled = true;
	autosavePeriod = AUTOSAVE_PERIOD_DEFAULT;
	autosaveSilent = true;

	tooltipsEnabled = true;

	currentPattern = 0;
	lastAuthorName[0] = 0;			// empty name

}




