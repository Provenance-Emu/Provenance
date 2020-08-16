/* ---------------------------------------------------------------------------------
Implementation file of SPLICER class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Splicer - Tool for montage
[Single instance]

* implements operations of mass-changing Input: copy/paste, cloning, clearing region, insertion and deletion of frames, truncating
* stores data about the Selection used in last "Copy to Clipboard" operation
* regularly checks the state of current Selection and displays info on GUI, also displays info about Input in Clipboard
* when launching TAS Editor, it checks Clipboard contents
* stores resources: mnemonics of buttons, texts for selection/clipboard info on GUI
------------------------------------------------------------------------------------ */

#include <sstream>
#include "taseditor_project.h"
#include "../Win32InputBox.h"

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
char buttonNames[NUM_JOYPAD_BUTTONS][2] = {"A", "B", "S", "T", "U", "D", "L", "R"};
char selectionText[] = "Selection: ";
char selectionEmptyText[] = "Selection: no";
char numTextRow[] = "1 row, ";
char numTextRows[] = " rows, ";
char numTextColumn[] = "1 column";
char numTextColumns[] = " columns";
char clipboardText[] = "Clipboard: ";
char clipboardEmptyText[] = "Clipboard: empty";

SPLICER::SPLICER()
{
}

void SPLICER::init()
{
	hwndSelectionInfo = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_TEXT_SELECTION);
	hwndClipboardInfo = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_TEXT_CLIPBOARD);

	reset();
	if (clipboardSelection.empty())
		checkClipboardContents();
	redrawInfoAboutClipboard();
}
void SPLICER::reset()
{
	mustRedrawInfoAboutSelection = true;
}
void SPLICER::update()
{
	// redraw Selection info text of needed
	if (mustRedrawInfoAboutSelection)
	{
		int size = selection.getCurrentRowsSelectionSize();
		if (size)
		{
			char new_text[100];
			strcpy(new_text, selectionText);
			char num[11];
			// rows
			if (size > 1)
			{
				_itoa(size, num, 10);
				strcat(new_text, num);
				strcat(new_text, numTextRows);
			} else
			{
				strcat(new_text, numTextRow);
			}
			// columns
			int columns = NUM_JOYPAD_BUTTONS * joysticksPerFrame[getInputType(currMovieData)];	// in future the number of columns will depend on selected columns
			if (columns > 1)
			{
				_itoa(columns, num, 10);
				strcat(new_text, num);
				strcat(new_text, numTextColumns);
			} else
			{
				strcat(new_text, numTextColumn);
			}
			SetWindowText(hwndSelectionInfo, new_text);
		} else
		{
			SetWindowText(hwndSelectionInfo, selectionEmptyText);
		}
		mustRedrawInfoAboutSelection = false;
	}
}
// ----------------------------------------------------------------------------------------------
void SPLICER::cloneSelectedFrames()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	int frames = current_selection->size();
	if (!frames) return;

	selection.clearAllRowsSelection();			// Selection will be moved down, so that same frames are selected
	bool markers_changed = false;
	currMovieData.records.reserve(currMovieData.getNumRecords() + frames);
	// insert frames before each selection, but consecutive Selection lines are accounted as single region
	RowsSelection::reverse_iterator next_it;
	RowsSelection::reverse_iterator current_selection_rend = current_selection->rend();
	int shift = frames;
	frames = 1;
	for(RowsSelection::reverse_iterator it(current_selection->rbegin()); it != current_selection_rend; it++)
	{
		next_it = it;
		next_it++;
		if (next_it == current_selection_rend || (int)*next_it < ((int)*it - 1))
		{
			// end of current region
			currMovieData.cloneRegion(*it, frames);
			greenzone.lagLog.insertFrame(*it, false, frames);
			if (taseditorConfig.bindMarkersToInput)
			{
				// Markers are not cloned
				if (markersManager.insertEmpty(*it,frames))
					markers_changed = true;
			}
			selection.setRegionOfRowsSelection((*it) + shift, (*it) + shift + frames);
			shift -= frames;
			// start accumulating next region
			frames = 1;
		} else frames++;
	}
	// check and register changes
	int first_changes = history.registerChanges(MODTYPE_CLONE, *current_selection->begin(), -1, 0, NULL, 0, current_selection);
	if (first_changes >= 0)
	{
		greenzone.invalidateAndUpdatePlayback(first_changes);
	} else if (markers_changed)
	{
		history.registerMarkersChange(MODTYPE_MARKER_SHIFT, *current_selection->begin());
		pianoRoll.redraw();
	}
	if (markers_changed)
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
}

void SPLICER::insertSelectedFrames()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	int frames = current_selection->size();
	if (!frames) return;

	selection.clearAllRowsSelection();			// Selection will be moved down, so that same frames are selected
	bool markers_changed = false;
	currMovieData.records.reserve(currMovieData.getNumRecords() + frames);
	// insert frames before each selection, but consecutive Selection lines are accounted as single region
	RowsSelection::reverse_iterator next_it;
	RowsSelection::reverse_iterator current_selection_rend = current_selection->rend();
	int shift = frames;
	frames = 1;
	for(RowsSelection::reverse_iterator it(current_selection->rbegin()); it != current_selection_rend; it++)
	{
		next_it = it;
		next_it++;
		if (next_it == current_selection_rend || (int)*next_it < ((int)*it - 1))
		{
			// end of current region
			currMovieData.insertEmpty(*it, frames);
			greenzone.lagLog.insertFrame(*it, false, frames);
			if (taseditorConfig.bindMarkersToInput)
			{
				if (markersManager.insertEmpty(*it, frames))
					markers_changed = true;
			}
			selection.setRegionOfRowsSelection((*it) + shift, (*it) + shift + frames);
			shift -= frames;
			// start accumulating next region
			frames = 1;
		} else frames++;
	}
	// check and register changes
	int first_changes = history.registerChanges(MODTYPE_INSERT, *current_selection->begin(), -1, 0, NULL, 0, current_selection);
	if (first_changes >= 0)
	{
		greenzone.invalidateAndUpdatePlayback(first_changes);
	} else if (markers_changed)
	{
		history.registerMarkersChange(MODTYPE_MARKER_SHIFT, *current_selection->begin());
		pianoRoll.redraw();
	}
	if (markers_changed)
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
}

void SPLICER::insertNumberOfFrames()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	int frames = current_selection->size();
	if (CWin32InputBox::GetInteger("Insert number of Frames", "How many frames?", frames, taseditorWindow.hwndTASEditor) == IDOK)
	{
		if (frames > 0)
		{
			bool markers_changed = false;
			int index;
			if (current_selection->size())
			{
				// insert at selection
				index = *current_selection->begin();
			} else
			{
				// insert at Playback cursor
				index = currFrameCounter;
			}
			currMovieData.insertEmpty(index, frames);
			greenzone.lagLog.insertFrame(index, false, frames);
			if (taseditorConfig.bindMarkersToInput)
			{
				if (markersManager.insertEmpty(index, frames))
					markers_changed = true;
			}
			if (current_selection->size())
			{
				// shift Selection down, so that same frames are selected
				pianoRoll.updateLinesCount();
				selection.clearAllRowsSelection();
				RowsSelection::iterator current_selection_end = current_selection->end();
				for(RowsSelection::iterator it(current_selection->begin()); it != current_selection_end; it++)
					selection.setRowSelection((*it) + frames);
			}
			// check and register changes
			int first_changes = history.registerChanges(MODTYPE_INSERTNUM, index, -1, frames);
			if (first_changes >= 0)
			{
				greenzone.invalidateAndUpdatePlayback(first_changes);
			} else if (markers_changed)
			{
				history.registerMarkersChange(MODTYPE_MARKER_SHIFT, index);
				pianoRoll.redraw();
			}
			if (markers_changed)
				selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
		}
	}
}

void SPLICER::deleteSelectedFrames()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return;

	bool markers_changed = false;
	int start_index = *current_selection->begin();
	int end_index = *current_selection->rbegin();
	RowsSelection::reverse_iterator current_selection_rend = current_selection->rend();
	// delete frames on each selection, going backwards
	for(RowsSelection::reverse_iterator it(current_selection->rbegin()); it != current_selection_rend; it++)
	{
		currMovieData.eraseRecords(*it);
		greenzone.lagLog.eraseFrame(*it);
		if (taseditorConfig.bindMarkersToInput)
		{
			if (markersManager.eraseMarker(*it))
				markers_changed = true;
		}
	}
	// check if user deleted all frames
	if (!currMovieData.getNumRecords())
		playback.restartPlaybackFromZeroGround();
	// reduce Piano Roll
	pianoRoll.updateLinesCount();
	// check and register changes
	int result = history.registerChanges(MODTYPE_DELETE, start_index, -1, 0, NULL, 0, current_selection);
	if (result >= 0)
	{
		greenzone.invalidateAndUpdatePlayback(result);
	} else
	{
		// check for special case: user deleted a bunch of empty frames the end of the movie
		greenzone.invalidateAndUpdatePlayback(currMovieData.getNumRecords() - 1);
		if (markers_changed)
			history.registerMarkersChange(MODTYPE_MARKER_SHIFT, start_index);
	}
	if (markers_changed)
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
}

void SPLICER::clearSelectedFrames(RowsSelection* currentSelectionOverride)
{
	bool cut = true;
	if (!currentSelectionOverride)
	{
		cut = false;
		currentSelectionOverride = selection.getCopyOfCurrentRowsSelection();
		if (currentSelectionOverride->size() == 0) return;
	}

	// clear Input on each selected frame
	RowsSelection::iterator current_selection_end(currentSelectionOverride->end());
	for(RowsSelection::iterator it(currentSelectionOverride->begin()); it != current_selection_end; it++)
	{
		currMovieData.records[*it].clear();
	}
	if (cut)
		greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_CUT, *currentSelectionOverride->begin(), *currentSelectionOverride->rbegin()));
	else
		greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_CLEAR, *currentSelectionOverride->begin(), *currentSelectionOverride->rbegin()));
}

void SPLICER::truncateMovie()
{
	int frame = selection.getCurrentRowsSelectionBeginning();
	if (frame < 0) frame = currFrameCounter;

	if (currMovieData.getNumRecords() > frame+1)
	{
		int last_frame_was = currMovieData.getNumRecords() - 1;
		currMovieData.truncateAt(frame+1);
		bool markers_changed = false;
		if (taseditorConfig.bindMarkersToInput)
		{
			if (markersManager.setMarkersArraySize(frame+1))
			{
				markers_changed = true;
				selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
			}
		}
		pianoRoll.updateLinesCount();
		int result = history.registerChanges(MODTYPE_TRUNCATE, frame + 1);
		if (result >= 0)
		{
			greenzone.invalidateAndUpdatePlayback(result);
		} else
		{
			// check for special case: user truncated empty frames of the movie
			greenzone.invalidateAndUpdatePlayback(currMovieData.getNumRecords() - 1);
			if (markers_changed)
				history.registerMarkersChange(MODTYPE_MARKER_REMOVE, frame+1, last_frame_was);
		}
	}
}

bool SPLICER::copySelectedInputToClipboard(RowsSelection* currentSelectionOverride)
{
	if (!currentSelectionOverride)
	{
		currentSelectionOverride = selection.getCopyOfCurrentRowsSelection();
		if (currentSelectionOverride->size() == 0) return false;
	}

	RowsSelection::iterator current_selection_begin(currentSelectionOverride->begin());
	RowsSelection::iterator current_selection_end(currentSelectionOverride->end());
	int num_joypads = joysticksPerFrame[getInputType(currMovieData)];
	int cframe = (*current_selection_begin) - 1;
    try 
	{
		int range = (*currentSelectionOverride->rbegin() - *current_selection_begin) + 1;

		std::stringstream clipString;
		clipString << "TAS " << range << std::endl;

		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (*it > cframe+1)
			{
				clipString << '+' << (*it-cframe) << '|';
			}
			cframe=*it;

			int cjoy=0;
			for (int joy = 0; joy < num_joypads; ++joy)
			{
				while (currMovieData.records[*it].joysticks[joy] && cjoy<joy) 
				{
					clipString << '|';
					++cjoy;
				}
				for (int bit=0; bit<NUM_JOYPAD_BUTTONS; ++bit)
				{
					if (currMovieData.records[*it].joysticks[joy] & (1<<bit))
					{
						clipString << buttonNames[bit];
					}
				}
			}
			clipString << std::endl;
		}
		// write data to clipboard
		if (!OpenClipboard(taseditorWindow.hwndTASEditor))
			return false;
		EmptyClipboard();

		HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, clipString.str().size()+1);
		if (hGlobal==INVALID_HANDLE_VALUE)
		{
			CloseClipboard();
			return false;
		}
		char *pGlobal = (char*)GlobalLock(hGlobal);
		strcpy(pGlobal, clipString.str().c_str());
		GlobalUnlock(hGlobal);
		SetClipboardData(CF_TEXT, hGlobal);

		CloseClipboard();
	}
	catch (std::bad_alloc e)
	{
		return false;
	}
	// copied successfully
	// memorize currently strobed Selection data to clipboard_selection
	clipboardSelection = *currentSelectionOverride;
	redrawInfoAboutClipboard();
	return true;
}
void SPLICER::cutSelectedInputToClipboard()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return;

	if (copySelectedInputToClipboard(current_selection))
	{
		clearSelectedFrames(current_selection);
	}
}
bool SPLICER::pasteInputFromClipboard()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;

	if (!OpenClipboard(taseditorWindow.hwndTASEditor)) return false;

	int num_joypads = joysticksPerFrame[getInputType(currMovieData)];
	bool result = false;
	int pos = *(current_selection->begin());
	HANDLE hGlobal = GetClipboardData(CF_TEXT);
	if (hGlobal)
	{
		char *pGlobal = (char*)GlobalLock((HGLOBAL)hGlobal);

		// TAS recording info starts with "TAS "
		if (pGlobal[0]=='T' && pGlobal[1]=='A' && pGlobal[2]=='S')
		{
			// Extract number of frames
			int range;
			sscanf (pGlobal+3, "%d", &range);
			if (currMovieData.getNumRecords() < pos+range)
			{
				currMovieData.insertEmpty(currMovieData.getNumRecords(),pos+range-currMovieData.getNumRecords());
				markersManager.update();
			}

			pGlobal = strchr(pGlobal, '\n');
			int joy = 0;
			uint8 new_buttons = 0;
			std::vector<uint8> flash_joy(num_joypads);
			char* frame;
			pos--;
			while (pGlobal++ && *pGlobal!='\0')
			{
				// Detect skipped frames in paste
				frame = pGlobal;
				if (frame[0]=='+')
				{
					pos += atoi(frame+1);
					while (*frame && *frame != '\n' && *frame!='|')
						++frame;
					if (*frame=='|') ++frame;
				} else
				{
					pos++;
				}
				
				if (taseditorConfig.superimpose == SUPERIMPOSE_UNCHECKED)
				{
					currMovieData.records[pos].joysticks[0] = 0;
					currMovieData.records[pos].joysticks[1] = 0;
					currMovieData.records[pos].joysticks[2] = 0;
					currMovieData.records[pos].joysticks[3] = 0;
				}
				// read this frame Input
				joy = 0;
				new_buttons = 0;
				while (*frame && *frame != '\n' && *frame !='\r')
				{
					switch (*frame)
					{
					case '|': // Joystick mark
						// flush buttons to movie data
						if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED || (taseditorConfig.superimpose == SUPERIMPOSE_INDETERMINATE && new_buttons == 0))
						{
							flash_joy[joy] |= (new_buttons & (~currMovieData.records[pos].joysticks[joy]));		// highlight buttons that are new
							currMovieData.records[pos].joysticks[joy] |= new_buttons;
						} else
						{
							flash_joy[joy] |= new_buttons;		// highlight buttons that were added
							currMovieData.records[pos].joysticks[joy] = new_buttons;
						}
						joy++;
						new_buttons = 0;
						break;
					default:
						for (int bit = 0; bit < NUM_JOYPAD_BUTTONS; ++bit)
						{
							if (*frame == buttonNames[bit][0])
							{
								new_buttons |= (1<<bit);
								break;
							}
						}
						break;
					}
					frame++;
				}
				// before going to next frame, flush buttons to movie data
				if (taseditorConfig.superimpose == SUPERIMPOSE_CHECKED || (taseditorConfig.superimpose == SUPERIMPOSE_INDETERMINATE && new_buttons == 0))
				{
					flash_joy[joy] |= (new_buttons & (~currMovieData.records[pos].joysticks[joy]));		// highlight buttons that are new
					currMovieData.records[pos].joysticks[joy] |= new_buttons;
				} else
				{
					flash_joy[joy] |= new_buttons;		// highlight buttons that were added
					currMovieData.records[pos].joysticks[joy] = new_buttons;
				}
				// find CRLF
				pGlobal = strchr(pGlobal, '\n');
			}

			greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_PASTE, *(current_selection->begin()), pos));
			// flash Piano Roll header columns that were changed during paste
			for (int joy = 0; joy < num_joypads; ++joy)
			{
				for (int btn = 0; btn < NUM_JOYPAD_BUTTONS; ++btn)
				{
					if (flash_joy[joy] & (1 << btn))
						pianoRoll.setLightInHeaderColumn(COLUMN_JOYPAD1_A + joy * NUM_JOYPAD_BUTTONS + btn, HEADER_LIGHT_MAX);
				}
			}
			result = true;
		} else
		{
			SetWindowText(hwndClipboardInfo, clipboardEmptyText);
		}
		GlobalUnlock(hGlobal);
	}
	CloseClipboard();
	return result;
}
bool SPLICER::pasteInsertInputFromClipboard()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return false;

	if (!OpenClipboard(taseditorWindow.hwndTASEditor)) return false;

	RowsSelection::iterator current_selection_begin(current_selection->begin());
	int num_joypads = joysticksPerFrame[getInputType(currMovieData)];
	bool result = false;
	bool markers_changed = false;
	int pos = *current_selection_begin;
	HANDLE hGlobal = GetClipboardData(CF_TEXT);
	if (hGlobal)
	{
		char *pGlobal = (char*)GlobalLock((HGLOBAL)hGlobal);

		// TAS recording info starts with "TAS "
		if (pGlobal[0]=='T' && pGlobal[1]=='A' && pGlobal[2]=='S')
		{
			// make sure Markers have the same size as movie
			markersManager.update();
			// create inserted_set (for Input history hot changes)
			RowsSelection inserted_set;

			// Extract number of frames
			int range;
			sscanf (pGlobal+3, "%d", &range);

			pGlobal = strchr(pGlobal, '\n');
			char* frame;
			int joy=0;
			std::vector<uint8> flash_joy(num_joypads);
			pos--;
			while (pGlobal++ && *pGlobal!='\0')
			{
				// Detect skipped frames in paste
				frame = pGlobal;
				if (frame[0]=='+')
				{
					pos += atoi(frame+1);
					if (currMovieData.getNumRecords() < pos)
					{
						currMovieData.insertEmpty(currMovieData.getNumRecords(), pos - currMovieData.getNumRecords());
						markersManager.update();
					}
					while (*frame && *frame != '\n' && *frame != '|')
						++frame;
					if (*frame=='|') ++frame;
				} else
				{
					pos++;
				}
				
				// insert new frame
				currMovieData.insertEmpty(pos, 1);
				greenzone.lagLog.insertFrame(pos, false, 1);
				if (taseditorConfig.bindMarkersToInput)
				{
					if (markersManager.insertEmpty(pos, 1))
						markers_changed = true;
				}
				inserted_set.insert(pos);

				// read this frame Input
				int joy = 0;
				while (*frame && *frame != '\n' && *frame !='\r')
				{
					switch (*frame)
					{
					case '|': // Joystick mark
						joy++;
						break;
					default:
						for (int bit = 0; bit < NUM_JOYPAD_BUTTONS; ++bit)
						{
							if (*frame == buttonNames[bit][0])
							{
								currMovieData.records[pos].joysticks[joy] |= (1<<bit);
								flash_joy[joy] |= (1<<bit);		// highlight buttons
								break;
							}
						}
						break;
					}
					frame++;
				}

				pGlobal = strchr(pGlobal, '\n');
			}
			markersManager.update();
			int first_changes = history.registerChanges(MODTYPE_PASTEINSERT, *current_selection_begin, -1, 0, NULL, 0, &inserted_set);
			if (first_changes >= 0)
			{
				greenzone.invalidateAndUpdatePlayback(first_changes);
			} else if (markers_changed)
			{
				history.registerMarkersChange(MODTYPE_MARKER_SHIFT, *current_selection->begin());
				pianoRoll.redraw();
			}
			if (markers_changed)
				selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
			// flash Piano Roll header columns that were changed during paste
			for (int joy = 0; joy < num_joypads; ++joy)
			{
				for (int btn = 0; btn < NUM_JOYPAD_BUTTONS; ++btn)
				{
					if (flash_joy[joy] & (1 << btn))
						pianoRoll.setLightInHeaderColumn(COLUMN_JOYPAD1_A + joy * NUM_JOYPAD_BUTTONS + btn, HEADER_LIGHT_MAX);
				}
			}
			result = true;
		} else
		{
			SetWindowText(hwndClipboardInfo, clipboardEmptyText);
		}
		GlobalUnlock(hGlobal);
	}
	CloseClipboard();
	return result;
}
// ----------------------------------------------------------------------------------------------
// retrieves some information from clipboard to clipboard_selection
void SPLICER::checkClipboardContents()
{
	if (OpenClipboard(taseditorWindow.hwndTASEditor))
	{
		// check if clipboard contains TAS Editor Input data
		HANDLE hGlobal = GetClipboardData(CF_TEXT);
		if (hGlobal)
		{
			clipboardSelection.clear();
			int current_pos = -1;
			char *pGlobal = (char*)GlobalLock((HGLOBAL)hGlobal);
			// TAS recording info starts with "TAS "
			if (pGlobal[0]=='T' && pGlobal[1]=='A' && pGlobal[2]=='S')
			{
				// Extract number of frames
				int range;
				sscanf (pGlobal+3, "%d", &range);
				pGlobal = strchr(pGlobal, '\n');
			
				while (pGlobal++ && *pGlobal!='\0')
				{
					// Detect skipped frames in paste
					char *frame = pGlobal;
					if (frame[0]=='+')
					{
						current_pos += atoi(frame+1);
						while (*frame && *frame != '\n' && *frame != '|')
							++frame;
						if (*frame=='|') ++frame;
					} else
						current_pos++;
					clipboardSelection.insert(current_pos);
					// skip Input
					pGlobal = strchr(pGlobal, '\n');
				}
			}
			GlobalUnlock(hGlobal);
		}
		CloseClipboard();
	}
}

void SPLICER::redrawInfoAboutClipboard()
{
	if (clipboardSelection.size())
	{
		char new_text[100];
		strcpy(new_text, clipboardText);
		char num[11];
		// rows
		if (clipboardSelection.size() > 1)
		{
			_itoa(clipboardSelection.size(), num, 10);
			strcat(new_text, num);
			strcat(new_text, numTextRows);
		} else
		{
			strcat(new_text, numTextRow);
		}
		// columns
		int columns = NUM_JOYPAD_BUTTONS * joysticksPerFrame[getInputType(currMovieData)];	// in future the number of columns will depend on selected columns
		if (columns > 1)
		{
			_itoa(columns, num, 10);
			strcat(new_text, num);
			strcat(new_text, numTextColumns);
		} else
		{
			strcat(new_text, numTextColumn);
		}
		SetWindowText(hwndClipboardInfo, new_text);
	} else
		SetWindowText(hwndClipboardInfo, clipboardEmptyText);
}

RowsSelection& SPLICER::getClipboardSelection()
{
	return clipboardSelection;
}


