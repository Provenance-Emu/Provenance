/* ---------------------------------------------------------------------------------
Implementation file of Markers_manager class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Markers_manager - Manager of Markers
[Single instance]

* stores one snapshot of Markers, representing current state of Markers in the project
* saves and loads the data from a project file. On error: clears the data
* regularly ensures that the size of current Markers array is not less than the number of frames in current Input
* implements all operations with Markers: setting Marker to a frame, removing Marker, inserting/deleting frames between Markers, truncating Markers array, changing Notes, finding frame for any given Marker, access to the data of Snapshot of Markers state
* implements full/partial copying of data between two Snapshots of Markers state, and searching for first difference between two Snapshots of Markers state
* also here's the code of searching for "similar" Notes
* also here's the code of editing Marker Notes
* also here's the code of Find Note dialog 
* stores resources: save id, properties of searching for similar Notes
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include <Shlwapi.h>		// for StrStrI

#pragma comment(lib, "Shlwapi.lib")

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern PLAYBACK playback;
extern SELECTION selection;
extern HISTORY history;

// resources
char markers_save_id[MARKERS_ID_LEN] = "MARKERS";
char markers_skipsave_id[MARKERS_ID_LEN] = "MARKERX";
char keywordDelimiters[] = " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";

MARKERS_MANAGER::MARKERS_MANAGER()
{
	memset(findNoteString, 0, MAX_NOTE_LEN);
}

void MARKERS_MANAGER::init()
{
	reset();
}
void MARKERS_MANAGER::free()
{
	markers.markersArray.resize(0);
	markers.notes.resize(0);
}
void MARKERS_MANAGER::reset()
{
	free();
	markerNoteEditMode = MARKER_NOTE_EDIT_NONE;
	currentIterationOfFindSimilar = 0;
	markers.notes.resize(1);
	markers.notes[0] = "Power on";
	update();
}
void MARKERS_MANAGER::update()
{
	// the size of current markers_array must be no less then the size of Input
	if ((int)markers.markersArray.size() < currMovieData.getNumRecords())
		markers.markersArray.resize(currMovieData.getNumRecords());
}

void MARKERS_MANAGER::save(EMUFILE *os, bool really_save)
{
	if (really_save)
	{
		// write "MARKERS" string
		os->fwrite(markers_save_id, MARKERS_ID_LEN);
		markers.resetCompressedStatus();		// must recompress data, because most likely it has changed since last compression
		markers.save(os);
	} else
	{
		// write "MARKERX" string, meaning that Markers are not saved
		os->fwrite(markers_skipsave_id, MARKERS_ID_LEN);
	}
}
// returns true if couldn't load
bool MARKERS_MANAGER::load(EMUFILE *is, unsigned int offset)
{
	if (offset)
	{
		if (is->fseek(offset, SEEK_SET)) goto error;
	} else
	{
		reset();
		return false;
	}
	// read "MARKERS" string
	char save_id[MARKERS_ID_LEN];
	if ((int)is->fread(save_id, MARKERS_ID_LEN) < MARKERS_ID_LEN) goto error;
	if (!strcmp(markers_skipsave_id, save_id))
	{
		// string says to skip loading Markers
		FCEU_printf("No Markers in the file\n");
		reset();
		return false;
	}
	if (strcmp(markers_save_id, save_id)) goto error;		// string is not valid
	if (markers.load(is)) goto error;
	// all ok
	return false;
error:
	FCEU_printf("Error loading Markers\n");
	reset();
	return true;
}
// -----------------------------------------------------------------------------------------
int MARKERS_MANAGER::getMarkersArraySize()
{
	return markers.markersArray.size();
}
bool MARKERS_MANAGER::setMarkersArraySize(int newSize)
{
	// if we are truncating, clear Markers that are gonna be erased (so that obsolete notes will be erased too)
	bool markers_changed = false;
	for (int i = markers.markersArray.size() - 1; i >= newSize; i--)
	{
		if (markers.markersArray[i])
		{
			removeMarkerFromFrame(i);
			markers_changed = true;
		}
	}
	markers.markersArray.resize(newSize);
	return markers_changed;
}

int MARKERS_MANAGER::getMarkerAtFrame(int frame)
{
	if (frame >= 0 && frame < (int)markers.markersArray.size())
		return markers.markersArray[frame];
	else
		return 0;
}
// finds and returns # of Marker starting from start_frame and searching up
int MARKERS_MANAGER::getMarkerAboveFrame(int startFrame)
{
	if (startFrame >= (int)markers.markersArray.size())
		startFrame = markers.markersArray.size() - 1;
	for (; startFrame >= 0; startFrame--)
		if (markers.markersArray[startFrame]) return markers.markersArray[startFrame];
	return 0;
}
// special version of the function
int MARKERS_MANAGER::getMarkerAboveFrame(MARKERS& targetMarkers, int startFrame)
{
	if (startFrame >= (int)targetMarkers.markersArray.size())
		startFrame = targetMarkers.markersArray.size() - 1;
	for (; startFrame >= 0; startFrame--)
		if (targetMarkers.markersArray[startFrame]) return targetMarkers.markersArray[startFrame];
	return 0;
}
// finds frame where the Marker is set
int MARKERS_MANAGER::getMarkerFrameNumber(int marker_id)
{
	for (int i = markers.markersArray.size() - 1; i >= 0; i--)
		if (markers.markersArray[i] == marker_id) return i;
	// didn't find
	return -1;
}
// returns number of new Marker
int MARKERS_MANAGER::setMarkerAtFrame(int frame)
{
	if (frame < 0)
		return 0;
	else if (frame >= (int)markers.markersArray.size())
		markers.markersArray.resize(frame + 1);
	else if (markers.markersArray[frame])
		return markers.markersArray[frame];

	int marker_num = getMarkerAboveFrame(frame) + 1;
	markers.markersArray[frame] = marker_num;
	if (taseditorConfig.emptyNewMarkerNotes)
		markers.notes.insert(markers.notes.begin() + marker_num, 1, "");
	else
		// copy previous Marker note
		markers.notes.insert(markers.notes.begin() + marker_num, 1, markers.notes[marker_num - 1]);
	// increase following Markers' ids
	int size = markers.markersArray.size();
	for (frame++; frame < size; ++frame)
		if (markers.markersArray[frame])
			markers.markersArray[frame]++;
	return marker_num;
}
void MARKERS_MANAGER::removeMarkerFromFrame(int frame)
{
	if (markers.markersArray[frame])
	{
		// erase corresponding note
		markers.notes.erase(markers.notes.begin() + markers.markersArray[frame]);
		// clear Marker
		markers.markersArray[frame] = 0;
		// decrease following Markers' ids
		int size = markers.markersArray.size();
		for (frame++; frame < size; ++frame)
			if (markers.markersArray[frame])
				markers.markersArray[frame]--;
	}
}
void MARKERS_MANAGER::toggleMarkerAtFrame(int frame)
{
	if (frame >= 0 && frame < (int)markers.markersArray.size())
	{
		if (markers.markersArray[frame])
			removeMarkerFromFrame(frame);
		else
			setMarkerAtFrame(frame);
	}
}

bool MARKERS_MANAGER::eraseMarker(int frame, int numFrames)
{
	bool markers_changed = false;
	if (frame < (int)markers.markersArray.size())
	{
		if (numFrames == 1)
		{
			// erase 1 frame
			// if there's a Marker, first clear it
			if (markers.markersArray[frame])
			{
				removeMarkerFromFrame(frame);
				markers_changed = true;
			}
			// erase 1 frame
			markers.markersArray.erase(markers.markersArray.begin() + frame);
		} else
		{
			// erase many frames
			if (frame + numFrames > (int)markers.markersArray.size())
				numFrames = (int)markers.markersArray.size() - frame;
			// if there are Markers at those frames, first clear them
			for (int i = frame; i < (frame + numFrames); ++i)
			{
				if (markers.markersArray[i])
				{
					removeMarkerFromFrame(i);
					markers_changed = true;
				}
			}
			// erase frames
			markers.markersArray.erase(markers.markersArray.begin() + frame, markers.markersArray.begin() + (frame + numFrames));
		}
		// check if there were some Markers after this frame
		// since these Markers were shifted, markers_changed should be set to true
		if (!markers_changed)
		{
			for (int i = markers.markersArray.size() - 1; i >= frame; i--)
			{
				if (markers.markersArray[i])
				{
					markers_changed = true;		// Markers moved
					break;
				}
			}
		}
	}
	return markers_changed;
}
bool MARKERS_MANAGER::insertEmpty(int at, int numFrames)
{
	if (at == -1) 
	{
		// append blank frames
		markers.markersArray.resize(markers.markersArray.size() + numFrames);
		return false;
	} else
	{
		bool markers_changed = false;
		// first check if there are Markers after the frame
		for (int i = markers.markersArray.size() - 1; i >= at; i--)
		{
			if (markers.markersArray[i])
			{
				markers_changed = true;		// Markers moved
				break;
			}
		}
		markers.markersArray.insert(markers.markersArray.begin() + at, numFrames, 0);
		return markers_changed;
	}
}

int MARKERS_MANAGER::getNotesSize()
{
	return markers.notes.size();
}
std::string MARKERS_MANAGER::getNoteCopy(int index)
{
	if (index >= 0 && index < (int)markers.notes.size())
		return markers.notes[index];
	else
		return markers.notes[0];
}
// special version of the function
std::string MARKERS_MANAGER::getNoteCopy(MARKERS& targetMarkers, int index)
{
	if (index >= 0 && index < (int)targetMarkers.notes.size())
		return targetMarkers.notes[index];
	else
		return targetMarkers.notes[0];
}
void MARKERS_MANAGER::setNote(int index, const char* newText)
{
	if (index >= 0 && index < (int)markers.notes.size())
		markers.notes[index] = newText;
}
// ---------------------------------------------------------------------------------------
void MARKERS_MANAGER::makeCopyOfCurrentMarkersTo(MARKERS& destination)
{
	destination.markersArray = markers.markersArray;
	destination.notes = markers.notes;
	destination.resetCompressedStatus();
}
void MARKERS_MANAGER::restoreMarkersFromCopy(MARKERS& source)
{
	markers.markersArray = source.markersArray;
	markers.notes = source.notes;
}

// return true only when difference is found before end frame (not including end frame)
bool MARKERS_MANAGER::checkMarkersDiff(MARKERS& theirMarkers)
{
	int end_my = getMarkersArraySize() - 1;
	int end_their = theirMarkers.markersArray.size() - 1;
	int min_end = end_my;
	int i;
	// 1 - check if there are any Markers after min_end
	if (end_my < end_their)
	{
		for (i = end_their; i > min_end; i--)
			if (theirMarkers.markersArray[i])
				return true;
	} else if (end_my > end_their)
	{
		min_end = end_their;
		for (i = end_my; i > min_end; i--)
			if (markers.markersArray[i])
				return true;
	}
	// 2 - check if there's any difference before min_end
	for (i = min_end; i >= 0; i--)
	{
		if (markers.markersArray[i] != theirMarkers.markersArray[i])
			return true;
		else if (markers.markersArray[i] &&	// not empty
			markers.notes[markers.markersArray[i]].compare(theirMarkers.notes[theirMarkers.markersArray[i]]))	// notes differ
			return true;
	}
	// 3 - check if there's difference between 0th Notes
	if (markers.notes[0].compare(theirMarkers.notes[0]))
		return true;
	// no difference found
	return false;
}
// ------------------------------------------------------------------------------------
// custom ordering function, used by std::sort
bool ordering(const std::pair<int, double>& d1, const std::pair<int, double>& d2)
{
  return d1.second < d2.second;
}

void MARKERS_MANAGER::findSimilarNote()
{
	currentIterationOfFindSimilar = 0;
	findNextSimilarNote();
}
void MARKERS_MANAGER::findNextSimilarNote()
{
	int i, t;
	int sourceMarker = playback.displayedMarkerNumber;
	char sourceNote[MAX_NOTE_LEN];
	strcpy(sourceNote, getNoteCopy(sourceMarker).c_str());

	// check if playback_marker_text is empty
	if (!sourceNote[0])
	{
		MessageBox(taseditorWindow.hwndTASEditor, "Marker Note under Playback cursor is empty!", "Find Similar Note", MB_OK);
		return;
	}
	// check if there's at least one note (not counting zeroth note)
	if (markers.notes.size() <= 0)
	{
		MessageBox(taseditorWindow.hwndTASEditor, "This project doesn't have any Markers!", "Find Similar Note", MB_OK);
		return;
	}

	// 0 - divide source string into keywords
	int totalSourceKeywords = 0;
	char sourceKeywords[MAX_NUM_KEYWORDS][MAX_NOTE_LEN] = {0};
	int current_line_pos = 0;
	char sourceKeywordsLine[MAX_NUM_KEYWORDS] = {0};
	char* pch;
	// divide into tokens
	pch = strtok(sourceNote, keywordDelimiters);
	while (pch != NULL)
	{
		if (strlen(pch) >= KEYWORD_MIN_LEN)
		{
			// check if same keyword already appeared in the string
			for (t = totalSourceKeywords - 1; t >= 0; t--)
				if (!_stricmp(sourceKeywords[t], pch)) break;
			if (t < 0)
			{
				// save new keyword
				strcpy(sourceKeywords[totalSourceKeywords], pch);
				// also set its id into the line
				sourceKeywordsLine[current_line_pos++] = totalSourceKeywords + 1;
				totalSourceKeywords++;
			} else
			{
				// same keyword found
				sourceKeywordsLine[current_line_pos++] = t + 1;
			}
		}
		pch = strtok(NULL, keywordDelimiters);
	}
	// we found the line (sequence) of keywords
	sourceKeywordsLine[current_line_pos] = 0;
	
	if (!totalSourceKeywords)
	{
		MessageBox(taseditorWindow.hwndTASEditor, "Marker Note under Playback cursor doesn't have keywords!", "Find Similar Note", MB_OK);
		return;
	}

	// 1 - find how frequently each keyword appears in notes
	std::vector<int> keywordFound(totalSourceKeywords);
	char checkedNote[MAX_NOTE_LEN];
	for (i = markers.notes.size() - 1; i > 0; i--)
	{
		if (i != sourceMarker)
		{
			strcpy(checkedNote, markers.notes[i].c_str());
			for (t = totalSourceKeywords - 1; t >= 0; t--)
				if (StrStrI(checkedNote, sourceKeywords[t]))
					keywordFound[t]++;
		}
	}
	// findmax
	int maxFound = 0;
	for (t = totalSourceKeywords - 1; t >= 0; t--)
		if (maxFound < keywordFound[t])
			maxFound = keywordFound[t];
	// and then calculate weight of each keyword: the more often it appears in Markers, the less weight it has
	std::vector<double> keywordWeight(totalSourceKeywords);
	for (t = totalSourceKeywords - 1; t >= 0; t--)
		keywordWeight[t] = KEYWORD_WEIGHT_BASE + KEYWORD_WEIGHT_FACTOR * (keywordFound[t] / (double)maxFound);

	// start accumulating priorities
	std::vector<std::pair<int, double>> notePriority(markers.notes.size());

	// 2 - find keywords in notes (including cases when keyword appears inside another word)
	for (i = notePriority.size() - 1; i > 0; i--)
	{
		notePriority[i].first = i;
		if (i != sourceMarker)
		{
			strcpy(checkedNote, markers.notes[i].c_str());
			for (t = totalSourceKeywords - 1; t >= 0; t--)
			{
				if (StrStrI(checkedNote, sourceKeywords[t]))
					notePriority[i].second += KEYWORD_CASEINSENTITIVE_BONUS_PER_CHAR * keywordWeight[t] * strlen(sourceKeywords[t]);
				if (strstr(checkedNote, sourceKeywords[t]))
					notePriority[i].second += KEYWORD_CASESENTITIVE_BONUS_PER_CHAR * keywordWeight[t] * strlen(sourceKeywords[t]);
			}
		}
	}

	// 3 - search sequences of keywords from all other notes
	current_line_pos = 0;
	char checkedKeywordsLine[MAX_NUM_KEYWORDS] = {0};
	int keyword_id;
	for (i = markers.notes.size() - 1; i > 0; i--)
	{
		if (i != sourceMarker)
		{
			strcpy(checkedNote, markers.notes[i].c_str());
			// divide into tokens
			pch = strtok(checkedNote, keywordDelimiters);
			while (pch != NULL)
			{
				if (strlen(pch) >= KEYWORD_MIN_LEN)
				{
					// check if the keyword is one of sourceKeywords
					for (t = totalSourceKeywords - 1; t >= 0; t--)
						if (!_stricmp(sourceKeywords[t], pch)) break;
					if (t >= 0)
					{
						// the keyword is one of sourceKeywords - set its id into the line
						checkedKeywordsLine[current_line_pos++] = t + 1;
					} else
					{
						// found keyword that doesn't appear in sourceNote, give penalty
						notePriority[i].second -= KEYWORD_PENALTY_FOR_STRANGERS * strlen(pch);
						// since the keyword breaks our sequence of coincident keywords, check if that sequence is similar to sourceKeywordsLine
						if (current_line_pos >= KEYWORDS_LINE_MIN_SEQUENCE)
						{
							checkedKeywordsLine[current_line_pos] = 0;
							// search checkedKeywordsLine in sourceKeywordsLine
							if (strstr(sourceKeywordsLine, checkedKeywordsLine))
							{
								// found same sequence of keywords! add priority to this checkedNote
								for (t = current_line_pos - 1; t >= 0; t--)
								{
									// add bonus for every keyword in the sequence
									keyword_id = checkedKeywordsLine[t] - 1;
									notePriority[i].second += current_line_pos * KEYWORD_SEQUENCE_BONUS_PER_CHAR * keywordWeight[keyword_id] * strlen(sourceKeywords[keyword_id]);
								}
							}
						}
						// clear checkedKeywordsLine
						memset(checkedKeywordsLine, 0, MAX_NUM_KEYWORDS);
						current_line_pos = 0;
					}
				}
				pch = strtok(NULL, keywordDelimiters);
			}
			// finished dividing into tokens
			if (current_line_pos >= KEYWORDS_LINE_MIN_SEQUENCE)
			{
				checkedKeywordsLine[current_line_pos] = 0;
				// search checkedKeywordsLine in sourceKeywordsLine
				if (strstr(sourceKeywordsLine, checkedKeywordsLine))
				{
					// found same sequence of keywords! add priority to this checkedNote
					for (t = current_line_pos - 1; t >= 0; t--)
					{
						// add bonus for every keyword in the sequence
						keyword_id = checkedKeywordsLine[t] - 1;
						notePriority[i].second += current_line_pos * KEYWORD_SEQUENCE_BONUS_PER_CHAR * keywordWeight[keyword_id] * strlen(sourceKeywords[keyword_id]);
					}
				}
			}
			// clear checkedKeywordsLine
			memset(checkedKeywordsLine, 0, MAX_NUM_KEYWORDS);
			current_line_pos = 0;
		}
	}

	// 4 - sort notePriority by second member of the pair
	std::sort(notePriority.begin(), notePriority.end(), ordering);

	/*
	// debug trace
	FCEU_printf("\n\n\n\n\n\n\n\n\n\n");
	for (t = totalSourceKeywords - 1; t >= 0; t--)
		FCEU_printf("Keyword: %s, %d, %f\n", sourceKeywords[t], keywordFound[t], keywordWeight[t]);
	for (i = notePriority.size() - 1; i > 0; i--)
	{
		int marker_id = notePriority[i].first;
		FCEU_printf("Result: %s, %d, %f\n", notes[marker_id].c_str(), marker_id, notePriority[i].second);
	}
	*/

	// Send Selection to the Marker found
	int index = notePriority.size()-1 - currentIterationOfFindSimilar;
	if (index >= 0 && notePriority[index].second >= MIN_PRIORITY_TRESHOLD)
	{
		int marker_id = notePriority[index].first;
		int frame = getMarkerFrameNumber(marker_id);
		if (frame >= 0)
			selection.jumpToFrame(frame);
	} else
	{
		if (currentIterationOfFindSimilar)
			MessageBox(taseditorWindow.hwndTASEditor, "Could not find more Notes similar to Marker Note under Playback cursor!", "Find Similar Note", MB_OK);
		else
			MessageBox(taseditorWindow.hwndTASEditor, "Could not find anything similar to Marker Note under Playback cursor!", "Find Similar Note", MB_OK);
	}

	// increase currentIterationOfFindSimilar so that next time we'll find another note
	currentIterationOfFindSimilar++;
}
// ------------------------------------------------------------------------------------
void MARKERS_MANAGER::updateEditedMarkerNote()
{
	if (!markerNoteEditMode) return;
	char new_text[MAX_NOTE_LEN];
	if (markerNoteEditMode == MARKER_NOTE_EDIT_UPPER)
	{
		int len = SendMessage(playback.hwndPlaybackMarkerEditField, WM_GETTEXT, MAX_NOTE_LEN, (LPARAM)new_text);
		new_text[len] = 0;
		// check changes
		if (strcmp(getNoteCopy(playback.displayedMarkerNumber).c_str(), new_text))
		{
			setNote(playback.displayedMarkerNumber, new_text);
			if (playback.displayedMarkerNumber)
				history.registerMarkersChange(MODTYPE_MARKER_RENAME, getMarkerFrameNumber(playback.displayedMarkerNumber), -1, new_text);
			else
				// zeroth Marker - just assume it's set on frame 0
				history.registerMarkersChange(MODTYPE_MARKER_RENAME, 0, -1, new_text);
			// notify Selection to change text in the lower Marker (in case both are showing same Marker)
			selection.mustFindCurrentMarker = true;
		}
	} else if (markerNoteEditMode == MARKER_NOTE_EDIT_LOWER)
	{
		int len = SendMessage(selection.hwndSelectionMarkerEditField, WM_GETTEXT, MAX_NOTE_LEN, (LPARAM)new_text);
		new_text[len] = 0;
		// check changes
		if (strcmp(getNoteCopy(selection.displayedMarkerNumber).c_str(), new_text))
		{
			setNote(selection.displayedMarkerNumber, new_text);
			if (selection.displayedMarkerNumber)
				history.registerMarkersChange(MODTYPE_MARKER_RENAME, getMarkerFrameNumber(selection.displayedMarkerNumber), -1, new_text);
			else
				// zeroth Marker - just assume it's set on frame 0
				history.registerMarkersChange(MODTYPE_MARKER_RENAME, 0, -1, new_text);
			// notify Playback to change text in upper Marker (in case both are showing same Marker)
			playback.mustFindCurrentMarker = true;
		}
	}
}
// ------------------------------------------------------------------------------------
BOOL CALLBACK findNoteWndProc(HWND hwndDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	extern MARKERS_MANAGER markersManager;
	switch (message)
	{
		case WM_INITDIALOG:
		{
			if (taseditorConfig.findnoteWindowX == -32000) taseditorConfig.findnoteWindowX = 0; //Just in case
			if (taseditorConfig.findnoteWindowY == -32000) taseditorConfig.findnoteWindowY = 0;
			SetWindowPos(hwndDlg, 0, taseditorConfig.findnoteWindowX, taseditorConfig.findnoteWindowY, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);

			CheckDlgButton(hwndDlg, IDC_MATCH_CASE, taseditorConfig.findnoteMatchCase?MF_CHECKED : MF_UNCHECKED);
			if (taseditorConfig.findnoteSearchUp)
				Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_UP), BST_CHECKED);
			else
				Button_SetCheck(GetDlgItem(hwndDlg, IDC_RADIO_DOWN), BST_CHECKED);
			HWND hwndEdit = GetDlgItem(hwndDlg, IDC_NOTE_TO_FIND);
			SendMessage(hwndEdit, EM_SETLIMITTEXT, MAX_NOTE_LEN - 1, 0);
			SetWindowText(hwndEdit, markersManager.findNoteString);
			if (GetDlgCtrlID((HWND)wParam) != IDC_NOTE_TO_FIND)
		    {
				SetFocus(hwndEdit);
				return false;
			}
			return true;
		}
		case WM_MOVE:
		{
			if (!IsIconic(hwndDlg))
			{
				RECT wrect;
				GetWindowRect(hwndDlg, &wrect);
				taseditorConfig.findnoteWindowX = wrect.left;
				taseditorConfig.findnoteWindowY = wrect.top;
				WindowBoundsCheckNoResize(taseditorConfig.findnoteWindowX, taseditorConfig.findnoteWindowY, wrect.right);
			}
			break;
		}
		case WM_COMMAND:
		{
			switch (LOWORD(wParam))
			{
				case IDC_NOTE_TO_FIND:
				{
					if (HIWORD(wParam) == EN_CHANGE) 
					{
						if (GetWindowTextLength(GetDlgItem(hwndDlg, IDC_NOTE_TO_FIND)))
							EnableWindow(GetDlgItem(hwndDlg, IDOK), true);
						else
							EnableWindow(GetDlgItem(hwndDlg, IDOK), false);
					}
					break;
				}
				case IDC_RADIO_UP:
					taseditorConfig.findnoteSearchUp = true;
					break;
				case IDC_RADIO_DOWN:
					taseditorConfig.findnoteSearchUp = false;
					break;
				case IDC_MATCH_CASE:
					taseditorConfig.findnoteMatchCase ^= 1;
					CheckDlgButton(hwndDlg, IDC_MATCH_CASE, taseditorConfig.findnoteMatchCase?MF_CHECKED : MF_UNCHECKED);
					break;
				case IDOK:
				{
					int len = SendMessage(GetDlgItem(hwndDlg, IDC_NOTE_TO_FIND), WM_GETTEXT, MAX_NOTE_LEN, (LPARAM)markersManager.findNoteString);
					markersManager.findNoteString[len] = 0;
					// scan frames from current Selection to the border
					int cur_marker = 0;
					bool result;
					int movie_size = currMovieData.getNumRecords();
					int current_frame = selection.getCurrentRowsSelectionBeginning();
					if (current_frame < 0 && taseditorConfig.findnoteSearchUp)
						current_frame = movie_size;
					while (true)
					{
						// move forward
						if (taseditorConfig.findnoteSearchUp)
						{
							current_frame--;
							if (current_frame < 0)
							{
								MessageBox(taseditorWindow.hwndFindNote, "Nothing was found.", "Find Note", MB_OK);
								break;
							}
						} else
						{
							current_frame++;
							if (current_frame >= movie_size)
							{
								MessageBox(taseditorWindow.hwndFindNote, "Nothing was found!", "Find Note", MB_OK);
								break;
							}
						}
						// scan marked frames
						cur_marker = markersManager.getMarkerAtFrame(current_frame);
						if (cur_marker)
						{
							if (taseditorConfig.findnoteMatchCase)
								result = (strstr(markersManager.getNoteCopy(cur_marker).c_str(), markersManager.findNoteString) != 0);
							else
								result = (StrStrI(markersManager.getNoteCopy(cur_marker).c_str(), markersManager.findNoteString) != 0);
							if (result)
							{
								// found note containing searched string - jump there
								selection.jumpToFrame(current_frame);
								break;
							}
						}
					}
					return TRUE;
				}
				case IDCANCEL:
					DestroyWindow(taseditorWindow.hwndFindNote);
					taseditorWindow.hwndFindNote = 0;
					return TRUE;
			}
			break;
		}
		case WM_CLOSE:
		case WM_QUIT:
		{
			DestroyWindow(taseditorWindow.hwndFindNote);
			taseditorWindow.hwndFindNote = 0;
			break;
		}
	}
	return FALSE; 
} 


