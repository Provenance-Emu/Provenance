/* ---------------------------------------------------------------------------------
Implementation file of TASEDITOR_PROJECT class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Project - Manager of working project
[Single instance]

* stores the info about current project filename and about having unsaved changes
* implements saving and loading project files from filesystem
* implements autosave function
* stores resources: autosave period scale, default filename, fm3 format offsets
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "utils/xstring.h"
#include "version.h"

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern MARKERS_MANAGER markersManager;
extern BOOKMARKS bookmarks;
extern POPUP_DISPLAY popupDisplay;
extern GREENZONE greenzone;
extern PLAYBACK playback;
extern RECORDER recorder;
extern HISTORY history;
extern PIANO_ROLL pianoRoll;
extern SELECTION selection;
extern SPLICER splicer;

extern FCEUGI *GameInfo;

extern void FCEU_PrintError(char *format, ...);
extern bool saveProject(bool save_compact = false);
extern bool saveProjectAs(bool save_compact = false);
extern int getInputType(MovieData& md);
extern void setInputType(MovieData& md, int new_input_type);

TASEDITOR_PROJECT::TASEDITOR_PROJECT()
{
}

void TASEDITOR_PROJECT::init()
{
	// default filename for a new project is blank
	projectFile = "";
	projectName = "";
	fm2FileName = "";
	reset();
}
void TASEDITOR_PROJECT::reset()
{
	changed = false;
}
void TASEDITOR_PROJECT::update()
{
	// if it's time to autosave - pop Save As dialog
	if (changed && taseditorWindow.TASEditorIsInFocus && taseditorConfig.autosaveEnabled && !projectFile.empty() && clock() >= nextSaveShedule && pianoRoll.dragMode == DRAG_MODE_NONE)
	{
		if (taseditorConfig.autosaveSilent)
			saveProject();
		else
			saveProjectAs();
		// in case user pressed Cancel, postpone saving to next time
		sheduleNextAutosave();
	}
}

bool TASEDITOR_PROJECT::save(const char* differentName, bool inputInBinary, bool saveMarkers, bool saveBookmarks, int saveGreenzone, bool saveHistory, bool savePianoRoll, bool saveSelection)
{
	if (!differentName && getProjectFile().empty())
		// no different name specified, and there's no current filename of the project
		return false;
	
	// check MD5
	char md5OfMovie[256];
	char md5OfRom[256];
	strcpy(md5OfMovie, md5_asciistr(currMovieData.romChecksum));
	strcpy(md5OfRom, md5_asciistr(GameInfo->MD5));
	if (strcmp(md5OfMovie, md5OfRom))
	{
		// checksums mismatch, check if they both aren't zero
		unsigned int k, count1 = 0, count2 = 0;
		for(k = 0; k < strlen(md5OfMovie); k++) count1 += md5OfMovie[k] - '0';
		for(k = 0; k < strlen(md5OfRom); k++) count2 += md5OfRom[k] - '0';
		if (count1 && count2)
		{
			// ask user if he wants to fix the checksum before saving
			char message[2048] = {0};
			strcpy(message, "Movie ROM:\n");
			strncat(message, currMovieData.romFilename.c_str(), 2047 - strlen(message));
			strncat(message, "\nMD5: ", 2047 - strlen(message));
			strncat(message, md5OfMovie, 2047 - strlen(message));
			strncat(message, "\n\nCurrent ROM:\n", 2047 - strlen(message));
			strncat(message, GameInfo->filename, 2047 - strlen(message));
			strncat(message, "\nMD5: ", 2047 - strlen(message));
			strncat(message, md5OfRom, 2047 - strlen(message));
			strncat(message, "\n\nFix the movie header before saving? ", 2047 - strlen(message));
			int answer = MessageBox(taseditorWindow.hwndTASEditor, message, "ROM Checksum Mismatch", MB_YESNOCANCEL);
			if (answer == IDCANCEL)
			{
				// cancel saving
				return false;
			} else if (answer == IDYES)
			{
				// change ROM data in the movie to current ROM
				currMovieData.romFilename = GameInfo->filename;
				currMovieData.romChecksum = GameInfo->MD5;
			}
		}
	}
	// open file for write
	EMUFILE_FILE* ofs = 0;
	if (differentName)
		ofs = FCEUD_UTF8_fstream(differentName, "wb");
	else
		ofs = FCEUD_UTF8_fstream(getProjectFile().c_str(), "wb");
	if (ofs)
	{
		// change cursor to hourglass
		SetCursor(LoadCursor(0, IDC_WAIT));
		// save fm2 data to the project file
		currMovieData.loadFrameCount = currMovieData.records.size();
		currMovieData.emuVersion = FCEU_VERSION_NUMERIC;
		currMovieData.dump(ofs, inputInBinary);
		unsigned int taseditorDataOffset = ofs->ftell();
		// save header: fm3 version + saved_stuff
		write32le(PROJECT_FILE_CURRENT_VERSION, ofs);
		unsigned int savedStuffMap = 0;
		if (saveMarkers) savedStuffMap |= MARKERS_SAVED;
		if (saveBookmarks) savedStuffMap |= BOOKMARKS_SAVED;
		if (saveGreenzone != GREENZONE_SAVING_MODE_NO) savedStuffMap |= GREENZONE_SAVED;
		if (saveHistory) savedStuffMap |= HISTORY_SAVED;
		if (savePianoRoll) savedStuffMap |= PIANO_ROLL_SAVED;
		if (saveSelection) savedStuffMap |= SELECTION_SAVED;
		write32le(savedStuffMap, ofs);
		unsigned int numberOfPointers = DEFAULT_NUMBER_OF_POINTERS;
		write32le(numberOfPointers, ofs);
		// write dummy zeros to the file, where the offsets will be
		for (unsigned int i = 0; i < numberOfPointers; ++i)
			write32le(0, ofs);
		// save specified modules
		unsigned int markersOffset = ofs->ftell();
		markersManager.save(ofs, saveMarkers);
		unsigned int bookmarksOffset = ofs->ftell();
		bookmarks.save(ofs, saveBookmarks);
		unsigned int greenzoneOffset = ofs->ftell();
		greenzone.save(ofs, saveGreenzone);
		unsigned int historyOffset = ofs->ftell();
		history.save(ofs, saveHistory);
		unsigned int pianoRollOffset = ofs->ftell();
		pianoRoll.save(ofs, savePianoRoll);
		unsigned int selectionOffset = ofs->ftell();
		selection.save(ofs, saveSelection);
		// now write offsets (pointers)
		ofs->fseek(taseditorDataOffset + PROJECT_FILE_OFFSET_OF_POINTERS_DATA, SEEK_SET);
		write32le(markersOffset, ofs);
		write32le(bookmarksOffset, ofs);
		write32le(greenzoneOffset, ofs);
		write32le(historyOffset, ofs);
		write32le(pianoRollOffset, ofs);
		write32le(selectionOffset, ofs);
		// finish
		delete ofs;
		playback.updateProgressbar();
		// also set project.changed to false, unless it was SaveCompact
		if (!differentName)
			reset();
		// restore cursor
		taseditorWindow.mustUpdateMouseCursor = true;
		return true;
	} else
	{
		return false;
	}
}
bool TASEDITOR_PROJECT::load(const char* fullName)
{
	bool loadAll = true;
	unsigned int taseditorDataOffset = 0;
	EMUFILE_FILE ifs(fullName, "rb");

	if (ifs.fail())
	{
		FCEU_PrintError("Error opening %s!", fullName);
		return false;
	}

	// change cursor to hourglass
	SetCursor(LoadCursor(0, IDC_WAIT));
	// load fm2 data from the project file
	MovieData tempMovieData = MovieData();
	extern bool LoadFM2(MovieData& movieData, EMUFILE* fp, int size, bool stopAfterHeader);
	if (LoadFM2(tempMovieData, &ifs, ifs.size(), false))
	{
		// check MD5
		char md5OfOriginal[256];
		char md5OfCurrent[256];
		strcpy(md5OfOriginal, md5_asciistr(tempMovieData.romChecksum));
		strcpy(md5OfCurrent, md5_asciistr(GameInfo->MD5));
		if (strcmp(md5OfOriginal, md5OfCurrent))
		{
			// checksums mismatch, check if they both aren't zero
			unsigned int k, count1 = 0, count2 = 0;
			for(k = 0; k < strlen(md5OfOriginal); k++) count1 += md5OfOriginal[k] - '0';
			for(k = 0; k < strlen(md5OfCurrent); k++) count2 += md5OfCurrent[k] - '0';
			if (count1 && count2)
			{
				// ask user if he really wants to load the project
				char message[2048] = {0};
				strcpy(message, "This project was made using different ROM!\n\n");
				strcat(message, "Original ROM:\n");
				strncat(message, tempMovieData.romFilename.c_str(), 2047 - strlen(message));
				strncat(message, "\nMD5: ", 2047 - strlen(message));
				strncat(message, md5OfOriginal, 2047 - strlen(message));
				strncat(message, "\n\nCurrent ROM:\n", 2047 - strlen(message));
				strncat(message, GameInfo->filename, 2047 - strlen(message));
				strncat(message, "\nMD5: ", 2047 - strlen(message));
				strncat(message, md5OfCurrent, 2047 - strlen(message));
				strncat(message, "\n\nLoad the project anyway?", 2047 - strlen(message));
				int answer = MessageBox(taseditorWindow.hwndTASEditor, message, "ROM Checksum Mismatch", MB_YESNO);
				if (answer == IDNO)
					return false;
			}
		}
		taseditorDataOffset = ifs.ftell();
		// load fm3 version from header and check it
		unsigned int projectFileVersion;
		if (read32le(&projectFileVersion, &ifs))
		{
			if (projectFileVersion != PROJECT_FILE_CURRENT_VERSION)
			{
				char message[2048] = {0};
				strcpy(message, "This project was saved using different version of TAS Editor!\n\n");
				strcat(message, "Original version: ");
				char versionNum[11];
				_itoa(projectFileVersion, versionNum, 10);
				strncat(message, versionNum, 2047 - strlen(message));
				strncat(message, "\nCurrent version: ", 2047 - strlen(message));
				_itoa(PROJECT_FILE_CURRENT_VERSION, versionNum, 10);
				strncat(message, versionNum, 2047 - strlen(message));
				strncat(message, "\n\nClick Yes to try loading all data from the file (may crash).\n", 2047 - strlen(message));
				strncat(message, "Click No to only load movie data.\n", 2047 - strlen(message));
				strncat(message, "Click Cancel to abort loading.", 2047 - strlen(message));
				int answer = MessageBox(taseditorWindow.hwndTASEditor, message, "FM3 Version Mismatch", MB_YESNOCANCEL);
				if (answer == IDCANCEL)
					return false;
				else if (answer == IDNO)
					loadAll = false;
			}
		} else
		{
			// couldn't even load header, this seems like an FM2
			loadAll = false;
			char message[2048];
			strcpy(message, "This file doesn't seem to be an FM3 project.\nIt only contains FM2 movie data. Load it anyway?");
			int answer = MessageBox(taseditorWindow.hwndTASEditor, message, "Opening FM2 file", MB_YESNO);
			if (answer == IDNO)
				return false;
		}
		// save data to currMovieData and continue loading
		FCEU_printf("\nLoading TAS Editor project %s...\n", fullName);
		currMovieData = tempMovieData;
		LoadSubtitles(currMovieData);
		// ensure that movie has correct set of ports/fourscore
		setInputType(currMovieData, getInputType(currMovieData));
	} else
	{
		FCEU_PrintError("Error loading movie data from %s!", fullName);
		// do not alter the project
		return false;
	}

	unsigned int savedStuff = 0;
	unsigned int numberOfPointers = 0;
	unsigned int dataOffset = 0;
	unsigned int pointerOffset = taseditorDataOffset + PROJECT_FILE_OFFSET_OF_POINTERS_DATA;
	if (loadAll)
	{
		read32le(&savedStuff, &ifs);
		read32le(&numberOfPointers, &ifs);
		// load modules
		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		markersManager.load(&ifs, dataOffset);

		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		bookmarks.load(&ifs, dataOffset);

		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		greenzone.load(&ifs, dataOffset);

		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		history.load(&ifs, dataOffset);

		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		pianoRoll.load(&ifs, dataOffset);

		if (numberOfPointers-- && !(ifs.fseek(pointerOffset, SEEK_SET)) && read32le(&dataOffset, &ifs))
			pointerOffset += sizeof(unsigned int);
		else
			dataOffset = 0;
		selection.load(&ifs, dataOffset);
	} else
	{
		// reset modules
		markersManager.load(&ifs, 0);
		bookmarks.load(&ifs, 0);
		greenzone.load(&ifs, 0);
		history.load(&ifs, 0);
		pianoRoll.load(&ifs, 0);
		selection.load(&ifs, 0);
	}
	// reset other modules
	playback.reset();
	recorder.reset();
	splicer.reset();
	popupDisplay.reset();
	reset();
	renameProject(fullName, loadAll);
	// restore mouse cursor shape
	taseditorWindow.mustUpdateMouseCursor = true;
	return true;
}

void TASEDITOR_PROJECT::renameProject(const char* newFullName, bool filenameIsCorrect)
{
	projectFile = newFullName;
	char drv[512], dir[512], name[512], ext[512];		// For getting the filename
	splitpath(newFullName, drv, dir, name, ext);
	projectName = name;
	std::string thisfm2name = name;
	thisfm2name.append(".fm2");
	fm2FileName = thisfm2name;
	// if filename is not correct (for example, user opened a corrupted FM3) clear the filename, so on Ctrl+S user will be forwarded to SaveAs
	if (!filenameIsCorrect)
		projectFile.clear();
}
// -----------------------------------------------------------------
std::string TASEDITOR_PROJECT::getProjectFile()
{
	return projectFile;
}
std::string TASEDITOR_PROJECT::getProjectName()
{
	return projectName;
}
std::string TASEDITOR_PROJECT::getFM2Name()
{
	return fm2FileName;
}

void TASEDITOR_PROJECT::setProjectChanged()
{
	if (!changed)
	{
		changed = true;
		taseditorWindow.updateCaption();
		sheduleNextAutosave();
	}
}
bool TASEDITOR_PROJECT::getProjectChanged()
{
	return changed;
}

void TASEDITOR_PROJECT::sheduleNextAutosave()
{
	nextSaveShedule = clock() + taseditorConfig.autosavePeriod * AUTOSAVE_PERIOD_SCALE;
}

