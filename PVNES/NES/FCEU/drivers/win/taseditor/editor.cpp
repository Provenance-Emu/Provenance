/* ---------------------------------------------------------------------------------
Implementation file of EDITOR class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Editor - Interface for editing Input and Markers
[Single instance]

* implements operations of changing Input: toggle Input in region, set Input by pattern, toggle selected region, apply pattern to Input selection
* implements operations of changing Markers: toggle Markers in selection, apply patern to Markers in selection, mark/unmark all selected frames
* stores Autofire Patterns data and their loading/generating code
* stores resources: patterns filename, id of buttonpresses in patterns
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"

extern TASEDITOR_WINDOW taseditorWindow;
extern TASEDITOR_CONFIG taseditorConfig;
extern HISTORY history;
extern MARKERS_MANAGER markersManager;
extern PLAYBACK playback;
extern GREENZONE greenzone;
extern PIANO_ROLL pianoRoll;
extern SELECTION selection;

extern int joysticksPerFrame[INPUT_TYPES_TOTAL];
extern int getInputType(MovieData& md);

// resources
char patternsFilename[] = "\\taseditor_patterns.txt";
char autofire_patterns_flagpress = 49;	//	"1"

EDITOR::EDITOR()
{
}

void EDITOR::init()
{
	free();
	// load autofire_patterns
	int total_patterns = 0;
	char nameo[2048];
	strncpy(nameo, FCEU_GetPath(FCEUMKF_TASEDITOR).c_str(), 2047);
	strncat(nameo, patternsFilename, 2047 - strlen(nameo));
	EMUFILE_FILE ifs(nameo, "rb");
	if (!ifs.fail())
	{
		std::string tempstr1, tempstr2;
		while (readStringFromPatternsFile(&ifs, tempstr1))
		{
			if (readStringFromPatternsFile(&ifs, tempstr2))
			{
				total_patterns++;
				// save the name
				patternsNames.push_back(tempstr1);
				// parse 2nd string to sequence of 1s and 0s
				patterns.resize(total_patterns);
				patterns[total_patterns - 1].resize(tempstr2.size());
				for (int i = tempstr2.size() - 1; i >= 0; i--)
				{
					if (tempstr2[i] == autofire_patterns_flagpress)
						patterns[total_patterns - 1][i] = 1;
					else
						patterns[total_patterns - 1][i] = 0;
				}
			}
		}
	} else
	{
		FCEU_printf("Could not load tools\\taseditor_patterns.txt!\n");
	}
	if (patterns.size() == 0)
	{
		FCEU_printf("Will be using default set of patterns...\n");
		patterns.resize(4);
		patternsNames.resize(4);
		// Default Pattern 0: Alternating (1010...)
		patternsNames[0] = "Alternating (1010...)";
		patterns[0].resize(2);
		patterns[0][0] = 1;
		patterns[0][1] = 0;
		// Default Pattern 1: Alternating at 30FPS (11001100...)
		patternsNames[1] = "Alternating at 30FPS (11001100...)";
		patterns[1].resize(4);
		patterns[1][0] = 1;
		patterns[1][1] = 1;
		patterns[1][2] = 0;
		patterns[1][3] = 0;
		// Default Pattern 2: One Quarter (10001000...)
		patternsNames[2] = "One Quarter (10001000...)";
		patterns[2].resize(4);
		patterns[2][0] = 1;
		patterns[2][1] = 0;
		patterns[2][2] = 0;
		patterns[2][3] = 0;
		// Default Pattern 3: Tap'n'Hold (1011111111111111111111111111111111111...)
		patternsNames[3] = "Tap'n'Hold (101111111...)";
		patterns[3].resize(1000);
		patterns[3][0] = 1;
		patterns[3][1] = 0;
		for (int i = 2; i < 1000; ++i)
			patterns[3][i] = 1;
	}
	// reset current_pattern if it's outside the range
	if (taseditorConfig.currentPattern < 0 || taseditorConfig.currentPattern >= (int)patterns.size())
		taseditorConfig.currentPattern = 0;
	taseditorWindow.updatePatternsMenu();

	reset();
}
void EDITOR::free()
{
	patterns.resize(0);
	patternsNames.resize(0);
}
void EDITOR::reset()
{

}
void EDITOR::update()
{



}
// ----------------------------------------------------------------------------------------------
// returns false if couldn't read a string containing at least one char
bool EDITOR::readStringFromPatternsFile(EMUFILE *is, std::string& dest)
{
	dest.resize(0);
	int charr;
	while (true)
	{
		charr = is->fgetc();
		if (charr < 0) break;
		if (charr == 10 || charr == 13)		// end of line
		{
			if (dest.size())
				break;		// already collected at least one char
			else
				continue;	// skip the char and continue searching
		} else
		{
			dest.push_back(charr);
		}
	}
	return dest.size() != 0;
}
// ----------------------------------------------------------------------------------------------
// following functions use function parameters to determine range of frames
void EDITOR::toggleInput(int start, int end, int joy, int button, int consecutivenessTag)
{
	if (joy < 0 || joy >= joysticksPerFrame[getInputType(currMovieData)]) return;

	int check_frame = end;
	if (start > end)
	{
		// swap
		int temp_start = start;
		start = end;
		end = temp_start;
	}
	if (start < 0) start = end;
	if (end >= currMovieData.getNumRecords())
		return;

	if (currMovieData.records[check_frame].checkBit(joy, button))
	{
		// clear range
		for (int i = start; i <= end; ++i)
			currMovieData.records[i].clearBit(joy, button);
		greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_UNSET, start, end, 0, NULL, consecutivenessTag));
	} else
	{
		// set range
		for (int i = start; i <= end; ++i)
			currMovieData.records[i].setBit(joy, button);
		greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_SET, start, end, 0, NULL, consecutivenessTag));
	}
}
void EDITOR::setInputUsingPattern(int start, int end, int joy, int button, int consecutivenessTag)
{
	if (joy < 0 || joy >= joysticksPerFrame[getInputType(currMovieData)]) return;

	if (start > end)
	{
		// swap
		int temp_start = start;
		start = end;
		end = temp_start;
	}
	if (start < 0) start = end;
	if (end >= currMovieData.getNumRecords())
		return;

	int pattern_offset = 0, current_pattern = taseditorConfig.currentPattern;
	bool changes_made = false;
	bool value;

	for (int i = start; i <= end; ++i)
	{
		// skip lag frames
		if (taseditorConfig.autofirePatternSkipsLag && greenzone.lagLog.getLagInfoAtFrame(i) == LAGGED_YES)
			continue;
		value = (patterns[current_pattern][pattern_offset] != 0);
		if (currMovieData.records[i].checkBit(joy, button) != value)
		{
			changes_made = true;
			currMovieData.records[i].setBitValue(joy, button, value);
		}
		pattern_offset++;
		if (pattern_offset >= (int)patterns[current_pattern].size())
			pattern_offset -= patterns[current_pattern].size();
	}
	if (changes_made)
		greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_PATTERN, start, end, 0, patternsNames[current_pattern].c_str(), consecutivenessTag));
}

// following functions use current Selection to determine range of frames
bool EDITOR::handleColumnSet()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;
	RowsSelection::iterator current_selection_begin(current_selection->begin());
	RowsSelection::iterator current_selection_end(current_selection->end());

	// inspect the selected frames, if they are all set, then unset all, else set all
	bool unset_found = false, changes_made = false;
	for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
	{
		if (!markersManager.getMarkerAtFrame(*it))
		{
			unset_found = true;
			break;
		}
	}
	if (unset_found)
	{
		// set all
		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (!markersManager.getMarkerAtFrame(*it))
			{
				if (markersManager.setMarkerAtFrame(*it))
				{
					changes_made = true;
					pianoRoll.redrawRow(*it);
				}
			}
		}
		if (changes_made)
			history.registerMarkersChange(MODTYPE_MARKER_SET, *current_selection_begin, *current_selection->rbegin());
	} else
	{
		// unset all
		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (markersManager.getMarkerAtFrame(*it))
			{
				markersManager.removeMarkerFromFrame(*it);
				changes_made = true;
				pianoRoll.redrawRow(*it);
			}
		}
		if (changes_made)
			history.registerMarkersChange(MODTYPE_MARKER_REMOVE, *current_selection_begin, *current_selection->rbegin());
	}
	if (changes_made)
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
	return changes_made;
}
bool EDITOR::handleColumnSetUsingPattern()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;
	RowsSelection::iterator current_selection_begin(current_selection->begin());
	RowsSelection::iterator current_selection_end(current_selection->end());
	int pattern_offset = 0, current_pattern = taseditorConfig.currentPattern;
	bool changes_made = false;

	for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
	{
		// skip lag frames
		if (taseditorConfig.autofirePatternSkipsLag && greenzone.lagLog.getLagInfoAtFrame(*it) == LAGGED_YES)
			continue;
		if (patterns[current_pattern][pattern_offset])
		{
			if (!markersManager.getMarkerAtFrame(*it))
			{
				if (markersManager.setMarkerAtFrame(*it))
				{
					changes_made = true;
					pianoRoll.redrawRow(*it);
				}
			}
		} else
		{
			if (markersManager.getMarkerAtFrame(*it))
			{
				markersManager.removeMarkerFromFrame(*it);
				changes_made = true;
				pianoRoll.redrawRow(*it);
			}
		}
		pattern_offset++;
		if (pattern_offset >= (int)patterns[current_pattern].size())
			pattern_offset -= patterns[current_pattern].size();
	}
	if (changes_made)
	{
		history.registerMarkersChange(MODTYPE_MARKER_PATTERN, *current_selection_begin, *current_selection->rbegin(), patternsNames[current_pattern].c_str());
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		return true;
	} else
		return false;
}

bool EDITOR::handleInputColumnSet(int joy, int button)
{
	if (joy < 0 || joy >= joysticksPerFrame[getInputType(currMovieData)]) return false;

	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;
	RowsSelection::iterator current_selection_begin(current_selection->begin());
	RowsSelection::iterator current_selection_end(current_selection->end());

	//inspect the selected frames, if they are all set, then unset all, else set all
	bool newValue = false;
	for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
	{
		if (!(currMovieData.records[*it].checkBit(joy,button)))
		{
			newValue = true;
			break;
		}
	}
	// apply newValue
	for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		currMovieData.records[*it].setBitValue(joy,button,newValue);

	int first_changes;
	if (newValue)
	{
		first_changes = history.registerChanges(MODTYPE_SET, *current_selection_begin, *current_selection->rbegin());
	} else
	{
		first_changes = history.registerChanges(MODTYPE_UNSET, *current_selection_begin, *current_selection->rbegin());
	}
	if (first_changes >= 0)
	{
		greenzone.invalidateAndUpdatePlayback(first_changes);
		return true;
	} else
		return false;
}
bool EDITOR::handleInputColumnSetUsingPattern(int joy, int button)
{
	if (joy < 0 || joy >= joysticksPerFrame[getInputType(currMovieData)]) return false;

	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;
	RowsSelection::iterator current_selection_begin(current_selection->begin());
	RowsSelection::iterator current_selection_end(current_selection->end());
	int pattern_offset = 0, current_pattern = taseditorConfig.currentPattern;

	for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
	{
		// skip lag frames
		if (taseditorConfig.autofirePatternSkipsLag && greenzone.lagLog.getLagInfoAtFrame(*it) == LAGGED_YES)
			continue;
		currMovieData.records[*it].setBitValue(joy, button, patterns[current_pattern][pattern_offset] != 0);
		pattern_offset++;
		if (pattern_offset >= (int)patterns[current_pattern].size())
			pattern_offset -= patterns[current_pattern].size();
	}
	int first_changes = history.registerChanges(MODTYPE_PATTERN, *current_selection_begin, *current_selection->rbegin(), 0, patternsNames[current_pattern].c_str());
	if (first_changes >= 0)
	{
		greenzone.invalidateAndUpdatePlayback(first_changes);
		return true;
	} else
		return false;
}
void EDITOR::setMarkers()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size())
	{
		RowsSelection::iterator current_selection_begin(current_selection->begin());
		RowsSelection::iterator current_selection_end(current_selection->end());
		bool changes_made = false;
		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (!markersManager.getMarkerAtFrame(*it))
			{
				if (markersManager.setMarkerAtFrame(*it))
				{
					changes_made = true;
					pianoRoll.redrawRow(*it);
				}
			}
		}
		if (changes_made)
		{
			selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
			history.registerMarkersChange(MODTYPE_MARKER_SET, *current_selection_begin, *current_selection->rbegin());
		}
	}
}
void EDITOR::removeMarkers()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size())
	{
		RowsSelection::iterator current_selection_begin(current_selection->begin());
		RowsSelection::iterator current_selection_end(current_selection->end());
		bool changes_made = false;
		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (markersManager.getMarkerAtFrame(*it))
			{
				markersManager.removeMarkerFromFrame(*it);
				changes_made = true;
				pianoRoll.redrawRow(*it);
			}
		}
		if (changes_made)
		{
			selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
			history.registerMarkersChange(MODTYPE_MARKER_REMOVE, *current_selection_begin, *current_selection->rbegin());
		}
	}
}
// ----------------------------------------------------------------------------------------------

