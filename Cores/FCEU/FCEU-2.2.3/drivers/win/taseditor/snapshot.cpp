/* ---------------------------------------------------------------------------------
Implementation file of Snapshot class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Snapshot - Snapshot of all edited data

* stores the data of specific snapshot of the movie: InputLog, LagLog, Markers at the moment of creating the snapshot, keyframe, start and end frame of operation, type of operation and description of the snapshot (including the time of creation)
* also stores info about sequential recording/drawing of Input
* streamlines snapshot creation: copying Input from movie data, copying LagLog from Greenzone, copying Markers from Markers Manager, setting time of creation
* streamlines restoring Markers data from snapshot
* saves and loads stored data from a project file. On error: sends warning to caller
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "zlib.h"

extern MARKERS_MANAGER markersManager;
extern SELECTION selection;
extern GREENZONE greenzone;

extern int getInputType(MovieData& md);

SNAPSHOT::SNAPSHOT()
{
}

void SNAPSHOT::init(MovieData& md, LAGLOG& lagLog, bool hotchanges, int enforceInputType)
{
	inputlog.init(md, hotchanges, enforceInputType);

	// make a copy of the given laglog
	laglog = lagLog;
	laglog.resetCompressedStatus();

	// take a copy of markers_manager.markers
	markersManager.makeCopyOfCurrentMarkersTo(markers);
	if ((int)markers.markersArray.size() < inputlog.size)
		markers.markersArray.resize(inputlog.size);

	// save current time to description
	time_t raw_time;
	time(&raw_time);
	struct tm * timeinfo = localtime(&raw_time);
	strftime(description, 10, "%H:%M:%S", timeinfo);
}

void SNAPSHOT::reinit(MovieData& md, LAGLOG& lagLog, bool hotchanges, int frameOfChanges)
{
	inputlog.reinit(md, hotchanges, frameOfChanges);

	// do not copy laglog, because it will be updated later, when Greenzone will sync its data with the current history snapshot

	// Markers are supposed to be the same, because this is consecutive Recording

	// save current time to description
	time_t raw_time;
	time(&raw_time);
	struct tm * timeinfo = localtime(&raw_time);
	strftime(description, 10, "%H:%M:%S", timeinfo);
}

bool SNAPSHOT::areMarkersDifferentFromCurrentMarkers()
{
	return markersManager.checkMarkersDiff(markers);
}
void SNAPSHOT::copyToCurrentMarkers()
{
	markersManager.restoreMarkersFromCopy(markers);
}
// -----------------------------------------------------------------------------------------
void SNAPSHOT::compressData()
{
	if (!inputlog.isAlreadyCompressed())
		inputlog.compressData();
	if (!laglog.isAlreadyCompressed())
		laglog.compressData();
	if (!markers.isAalreadyCompressed())
		markers.compressData();
}
bool SNAPSHOT::isAlreadyCompressed()
{
	// only consider this snapshot fully compressed when all of InputLog, LagLog and Markers are compressed
	return (inputlog.isAlreadyCompressed() && laglog.isAlreadyCompressed() && markers.isAalreadyCompressed());
}

void SNAPSHOT::save(EMUFILE *os)
{
	// write vars
	write32le(keyFrame, os);
	write32le(startFrame, os);
	write32le(endFrame, os);
	write32le(consecutivenessTag, os);
	write32le(recordedJoypadDifferenceBits, os);
	write32le(modificationType, os);
	// write description
	int len = strlen(description);
	write8le(len, os);
	os->fwrite(&description[0], len);
	// save InputLog data
	inputlog.save(os);
	// save LagLog data
	laglog.save(os);
	// save Markers data
	markers.save(os);
}
// returns true if couldn't load
bool SNAPSHOT::load(EMUFILE *is)
{
	uint8 tmp;
	// read vars
	if (!read32le(&keyFrame, is)) return true;
	if (!read32le(&startFrame, is)) return true;
	if (!read32le(&endFrame, is)) return true;
	if (!read32le(&consecutivenessTag, is)) return true;
	if (!read32le(&recordedJoypadDifferenceBits, is)) return true;
	if (!read32le(&modificationType, is)) return true;
	// read description
	if (!read8le(&tmp, is)) return true;
	if (tmp >= SNAPSHOT_DESCRIPTION_MAX_LEN) return true;
	if (is->fread(&description[0], tmp) != tmp) return true;
	description[tmp] = 0;		// add '0' because it wasn't saved in the file
	// load InputLog data
	if (inputlog.load(is)) return true;
	// load LagLog data
	if (laglog.load(is)) return true;
	// load Markers data
	if (markers.load(is)) return true;
	return false;
}
bool SNAPSHOT::skipLoad(EMUFILE *is)
{
	uint8 tmp1;
	// skip vars
	if (is->fseek(sizeof(int) +	// keyframe
				sizeof(int) +	// start_frame
				sizeof(int) +	// end_frame
				sizeof(int) +	// consecutivenessTag
				sizeof(int) +	// recordedJoypadDifferenceBits
				sizeof(int)		// mod_type
				, SEEK_CUR)) return true;
	// skip description
	if (!read8le(&tmp1, is)) return true;
	if (tmp1 >= SNAPSHOT_DESCRIPTION_MAX_LEN) return true;
	if (is->fseek(tmp1, SEEK_CUR) != 0) return true;
	// skip InputLog data
	if (inputlog.skipLoad(is)) return true;
	// skip LagLog data
	if (laglog.skipLoad(is)) return true;
	// skip Markers data
	if (markers.skipLoad(is)) return true;
	return false;
}

