/* ---------------------------------------------------------------------------------
Implementation file of Bookmark class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Bookmark - Single Bookmark data

* stores all info of one specific Bookmark: movie snapshot, a savestate of 1 frame, a screenshot of the frame, a state of flashing for this Bookmark's row
* saves and loads the data from a project file. On error: sends warning to caller
* implements procedure of "Bookmark set": creating movie snapshot, setting key frame on current Playback position, copying savestate from Greenzone, making and compressing screenshot, launching flashing animation
* launches respective flashings for "Bookmark jump" and "Branch deploy"
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "zlib.h"

extern TASEDITOR_CONFIG taseditorConfig;
extern GREENZONE greenzone;
extern HISTORY history;

extern uint8 *XBuf;
extern uint8 *XBackBuf;

BOOKMARK::BOOKMARK()
{
	notEmpty = false;
}

void BOOKMARK::init()
{
	free();
}
void BOOKMARK::free()
{
	notEmpty = false;
	flashType = flashPhase = floatingPhase = 0;
	SNAPSHOT tmp;
	snapshot = tmp;
	savestate.resize(0);
	savedScreenshot.resize(0);
}

bool BOOKMARK::isDifferentFromCurrentMovie()
{
	// check if the Bookmark data differs from current project/MovieData/Markers/settings
	if (notEmpty && snapshot.keyFrame == currFrameCounter)
	{
		if (snapshot.inputlog.size == currMovieData.getNumRecords() && snapshot.inputlog.findFirstChange(currMovieData) < 0)
		{
			if (!snapshot.areMarkersDifferentFromCurrentMarkers())
			{
				if (snapshot.inputlog.hasHotChanges == taseditorConfig.enableHotChanges)
				{
					return false;
				}
			}
		}
	}
	return true;
}

void BOOKMARK::set()
{
	// copy Input and Hotchanges
	snapshot.init(currMovieData, greenzone.lagLog, taseditorConfig.enableHotChanges);
	snapshot.keyFrame = currFrameCounter;
	if (taseditorConfig.enableHotChanges)
		snapshot.inputlog.copyHotChanges(&history.getCurrentSnapshot().inputlog);
	// copy savestate
	savestate = greenzone.getSavestateOfFrame(currFrameCounter);
	// save screenshot
	uLongf comprlen = (SCREENSHOT_SIZE>>9)+12 + SCREENSHOT_SIZE;
	savedScreenshot.resize(comprlen);
	// compress screenshot data
	if (taseditorConfig.HUDInBranchScreenshots)
		compress(&savedScreenshot[0], &comprlen, XBuf, SCREENSHOT_SIZE);
	else
		compress(&savedScreenshot[0], &comprlen, XBackBuf, SCREENSHOT_SIZE);
	savedScreenshot.resize(comprlen);

	notEmpty = true;
	flashPhase = FLASH_PHASE_MAX;
	flashType = FLASH_TYPE_SET;
}

void BOOKMARK::handleJump()
{
	flashPhase = FLASH_PHASE_MAX;
	flashType = FLASH_TYPE_JUMP;
}

void BOOKMARK::handleDeploy()
{
	flashPhase = FLASH_PHASE_MAX;
	flashType = FLASH_TYPE_DEPLOY;
}

void BOOKMARK::save(EMUFILE *os)
{
	if (notEmpty)
	{
		write8le(1, os);
		// write snapshot
		snapshot.save(os);
		// write savestate
		int size = savestate.size();
		write32le(size, os);
		os->fwrite(&savestate[0], size);
		// write saved_screenshot
		size = savedScreenshot.size();
		write32le(size, os);
		os->fwrite(&savedScreenshot[0], size);
	} else write8le((uint8)0, os);
}
// returns true if couldn't load
bool BOOKMARK::load(EMUFILE *is)
{
	uint8 tmp;
	if (!read8le(&tmp, is)) return true;
	notEmpty = (tmp != 0);
	if (notEmpty)
	{
		// read snapshot
		if (snapshot.load(is)) return true;
		// read savestate
		int size;
		if (!read32le(&size, is)) return true;
		savestate.resize(size);
		if ((int)is->fread(&savestate[0], size) < size) return true;
		// read saved_screenshot
		if (!read32le(&size, is)) return true;
		savedScreenshot.resize(size);
		if ((int)is->fread(&savedScreenshot[0], size) < size) return true;
	} else
	{
		free();
	}
	// all ok - reset vars
	flashType = flashPhase = floatingPhase = 0;
	return false;
}
bool BOOKMARK::skipLoad(EMUFILE *is)
{
	uint8 tmp;
	if (!read8le(&tmp, is)) return true;
	if (tmp != 0)
	{
		// read snapshot
		if (snapshot.skipLoad(is)) return true;
		// read savestate
		int size;
		if (!read32le(&size, is)) return true;
		if (is->fseek(size, SEEK_CUR)) return true;
		// read saved_screenshot
		if (!read32le(&size, is)) return true;
		if (is->fseek(size, SEEK_CUR)) return true;
	}
	// all ok
	return false;
}
// ----------------------------------------------------------

