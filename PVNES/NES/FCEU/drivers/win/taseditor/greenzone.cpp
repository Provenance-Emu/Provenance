/* ---------------------------------------------------------------------------------
Implementation file of Greenzone class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Greenzone - Access zone
[Single instance]

* stores array of savestates, used for faster movie navigation by Playback cursor
* also stores LagLog of current movie Input
* saves and loads the data from a project file. On error: truncates Greenzone to last successfully read savestate
* regularly checks if there's a savestate of current emulation state, if there's no such savestate in array then creates one and updates lag info for previous frame
* implements the working of "Auto-adjust Input according to lag" feature
* regularly runs gradual cleaning of the savestates array (for memory saving), deleting oldest savestates
* on demand: (when movie Input was changed) truncates the size of Greenzone, deleting savestates that became irrelevant because of new Input. After truncating it may also move Playback cursor (which must always reside within Greenzone) and may launch Playback seeking
* stores resources: save id, properties of gradual cleaning, timing of cleaning
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "state.h"
#include "zlib.h"

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_PROJECT project;
extern PLAYBACK playback;
extern HISTORY history;
extern BOOKMARKS bookmarks;
extern MARKERS_MANAGER markersManager;
extern PIANO_ROLL pianoRoll;
extern SELECTION selection;

extern char lagFlag;

char greenzone_save_id[GREENZONE_ID_LEN] = "GREENZONE";
char greenzone_skipsave_id[GREENZONE_ID_LEN] = "GREENZONX";

GREENZONE::GREENZONE()
{
}

void GREENZONE::init()
{
	reset();
	nextCleaningTime = clock() + TIME_BETWEEN_CLEANINGS;
}
void GREENZONE::free()
{
	savestates.resize(0);
	greenzoneSize = 0;
	lagLog.reset();
}
void GREENZONE::reset()
{
	free();
}
void GREENZONE::update()
{
	// keep collecting savestates, this code must be executed at the end of every frame
	if (taseditorConfig.enableGreenzoning)
	{
		collectCurrentState();
	} else
	{
		// just update Greenzone upper limit
		if (greenzoneSize <= currFrameCounter)
			greenzoneSize = currFrameCounter + 1;
	}

	// run cleaning from time to time
	if (clock() > nextCleaningTime)
		runGreenzoneCleaning();

	// also log lag frames
	if (currFrameCounter > 0)
	{
		// lagFlag indicates that lag was in previous frame
		int old_lagFlag = lagLog.getLagInfoAtFrame(currFrameCounter - 1);
		// Auto-adjust Input according to lag
		if (taseditorConfig.autoAdjustInputAccordingToLag && old_lagFlag != LAGGED_UNKNOWN)
		{
			if ((old_lagFlag == LAGGED_YES) && !lagFlag)
			{
				// there's no more lag on previous frame - shift Input up 1 or more frames
				adjustUp();
			} else if ((old_lagFlag == LAGGED_NO) && lagFlag)
			{
				// there's new lag on previous frame - shift Input down 1 frame
				adjustDown();
			}
		} else
		{
			if (lagFlag && (old_lagFlag != LAGGED_YES))
			{
				lagLog.setLagInfo(currFrameCounter - 1, true);
				// keep current snapshot laglog in touch
				history.getCurrentSnapshot().laglog.setLagInfo(currFrameCounter - 1, true);
			} else if (!lagFlag && old_lagFlag != LAGGED_NO)
			{
				lagLog.setLagInfo(currFrameCounter - 1, false);
				// keep current snapshot laglog in touch
				history.getCurrentSnapshot().laglog.setLagInfo(currFrameCounter - 1, false);
			}
		}
	}
}

void GREENZONE::collectCurrentState()
{
	if ((int)savestates.size() <= currFrameCounter)
		savestates.resize(currFrameCounter + 1);
	// if frame is not saved - log savestate
	if (!savestates[currFrameCounter].size())
	{
		EMUFILE_MEMORY ms(&savestates[currFrameCounter]);
		FCEUSS_SaveMS(&ms, Z_DEFAULT_COMPRESSION);
		ms.trim();
	}
	if (greenzoneSize <= currFrameCounter)
		greenzoneSize = currFrameCounter + 1;
}

bool GREENZONE::loadSavestateOfFrame(unsigned int frame)
{
	if (frame >= savestates.size() || !savestates[frame].size())
		return false;
	EMUFILE_MEMORY ms(&savestates[frame]);
	return FCEUSS_LoadFP(&ms, SSLOADPARAM_NOBACKUP);
}

void GREENZONE::runGreenzoneCleaning()
{
	bool changed = false;
	int i = currFrameCounter - taseditorConfig.greenzoneCapacity;
	if (i <= 0) goto finish;	// zeroth frame should not be cleaned
	int limit;
	// 2x of 1/2
	limit = i - 2 * taseditorConfig.greenzoneCapacity;
	if (limit < 0) limit = 0;
	for (; i > limit; i--)
	{
		if (i & 0x1)
			changed = changed | clearSavestateAndFreeMemory(i);
	}
	if (i < 0) goto finish;
	// 4x of 1/4
	limit = i - 4 * taseditorConfig.greenzoneCapacity;
	if (limit < 0) limit = 0;
	for (; i > limit; i--)
	{
		if (i & 0x3)
			changed = changed | clearSavestateAndFreeMemory(i);
	}
	if (i < 0) goto finish;
	// 8x of 1/8
	limit = i - 8 * taseditorConfig.greenzoneCapacity;
	if (limit < 0) limit = 0;
	for (; i > limit; i--)
	{
		if (i & 0x7)
			changed = changed | clearSavestateAndFreeMemory(i);
	}
	if (i < 0) goto finish;
	// 16x of 1/16
	limit = i - 16 * taseditorConfig.greenzoneCapacity;
	if (limit < 0) limit = 0;
	for (; i > limit; i--)
	{
		if (i & 0xF)
			changed = changed | clearSavestateAndFreeMemory(i);
	}
	// clear all remaining
	for (; i > 0; i--)
	{
		changed = changed | clearSavestateAndFreeMemory(i);
	}
finish:
	if (changed)
	{
		pianoRoll.redraw();
		bookmarks.redrawBookmarksList();
	}
	// shedule next cleaning
	nextCleaningTime = clock() + TIME_BETWEEN_CLEANINGS;
}

// returns true if actually cleared savestate data
bool GREENZONE::clearSavestateOfFrame(unsigned int frame)
{
	if (frame < savestates.size() && savestates[frame].size())
	{
	    savestates[frame].resize(0);
		return true;
	} else
	{
		return false;
	}
}
bool GREENZONE::clearSavestateAndFreeMemory(unsigned int frame)
{
	if (frame < savestates.size() && savestates[frame].size())
	{
	    savestates[frame].swap(std::vector<uint8>());
		return true;
	} else
	{
		return false;
	}
}

void GREENZONE::ungreenzoneSelectedFrames()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return;
	bool changed = false;
	int size = savestates.size();
	int start_index = *current_selection->begin();
	int end_index = *current_selection->rbegin();
	RowsSelection::reverse_iterator current_selection_rend = current_selection->rend();
	// degreenzone frames, going backwards
	for (RowsSelection::reverse_iterator it(current_selection->rbegin()); it != current_selection_rend; it++)
		changed = changed | clearSavestateAndFreeMemory(*it);
	if (changed)
	{
		pianoRoll.redraw();
		bookmarks.redrawBookmarksList();
	}
}

void GREENZONE::save(EMUFILE *os, int save_type)
{
	if (save_type != GREENZONE_SAVING_MODE_NO)
	{
		collectCurrentState();		// in case the project is being saved before the greenzone.update() was called within current frame
		runGreenzoneCleaning();
		if (greenzoneSize > (int)savestates.size())
			greenzoneSize = savestates.size();
		// write "GREENZONE" string
		os->fwrite(greenzone_save_id, GREENZONE_ID_LEN);
		// write LagLog
		lagLog.save(os);
		// write size
		write32le(greenzoneSize, os);
		// write Playback cursor position
		write32le(currFrameCounter, os);
	}
	int frame, size;
	int last_tick = 0;

	switch (save_type)
	{
		case GREENZONE_SAVING_MODE_ALL:
		{
			// write savestates
			for (frame = 0; frame < greenzoneSize; ++frame)
			{
				// update TASEditor progressbar from time to time
				if (frame / PROGRESSBAR_UPDATE_RATE > last_tick)
				{
					playback.setProgressbar(frame, greenzoneSize);
					last_tick = frame / PROGRESSBAR_UPDATE_RATE;
				}
				if (!savestates[frame].size()) continue;
				write32le(frame, os);
				// write savestate
				size = savestates[frame].size();
				write32le(size, os);
				os->fwrite(&savestates[frame][0], size);
			}
			// write -1 as eof for greenzone
			write32le(-1, os);
			break;
		}
		case GREENZONE_SAVING_MODE_16TH:
		{
			// write savestates
			for (frame = 0; frame < greenzoneSize; ++frame)
			{
				if (!(frame & 0xF) || frame == currFrameCounter)
				{
					// update TASEditor progressbar from time to time
					if (frame / PROGRESSBAR_UPDATE_RATE > last_tick)
					{
						playback.setProgressbar(frame, greenzoneSize);
						last_tick = frame / PROGRESSBAR_UPDATE_RATE;
					}
					if (!savestates[frame].size()) continue;
					write32le(frame, os);
					// write savestate
					size = savestates[frame].size();
					write32le(size, os);
					os->fwrite(&savestates[frame][0], size);
				}
			}
			// write -1 as eof for greenzone
			write32le(-1, os);
			break;
		}
		case GREENZONE_SAVING_MODE_MARKED:
		{
			// write savestates
			for (frame = 0; frame < greenzoneSize; ++frame)
			{
				if (markersManager.getMarkerAtFrame(frame) || frame == currFrameCounter)
				{
					// update TASEditor progressbar from time to time
					if (frame / PROGRESSBAR_UPDATE_RATE > last_tick)
					{
						playback.setProgressbar(frame, greenzoneSize);
						last_tick = frame / PROGRESSBAR_UPDATE_RATE;
					}
					if (!savestates[frame].size()) continue;
					write32le(frame, os);
					// write savestate
					size = savestates[frame].size();
					write32le(size, os);
					os->fwrite(&savestates[frame][0], size);
				}
			}
			// write -1 as eof for greenzone
			write32le(-1, os);
			break;
		}
		case GREENZONE_SAVING_MODE_NO:
		{
			// write "GREENZONX" string
			os->fwrite(greenzone_skipsave_id, GREENZONE_ID_LEN);
			// write LagLog
			lagLog.save(os);
			// write Playback cursor position
			write32le(currFrameCounter, os);
			if (currFrameCounter > 0)
			{
				// write ONE savestate for currFrameCounter
				collectCurrentState();
				int size = savestates[currFrameCounter].size();
				write32le(size, os);
				os->fwrite(&savestates[currFrameCounter][0], size);
			}
			break;
		}
	}
}
// returns true if couldn't load
bool GREENZONE::load(EMUFILE *is, unsigned int offset)
{
	free();
	if (offset)
	{
		if (is->fseek(offset, SEEK_SET)) goto error;
	} else
	{
		reset();
		playback.restartPlaybackFromZeroGround();		// reset Playback cursor to frame 0
		return false;
	}
	int frame = 0, prev_frame = -1, size = 0;
	int last_tick = 0;
	// read "GREENZONE" string
	char save_id[GREENZONE_ID_LEN];
	if ((int)is->fread(save_id, GREENZONE_ID_LEN) < GREENZONE_ID_LEN) goto error;
	if (!strcmp(greenzone_skipsave_id, save_id))
	{
		// string says to skip loading Greenzone
		// read LagLog
		lagLog.load(is);
		// read Playback cursor position
		if (read32le(&frame, is))
		{
			currFrameCounter = frame;
			greenzoneSize = currFrameCounter + 1;
			savestates.resize(greenzoneSize);
			if (currFrameCounter)
			{
				// there must be one savestate in the file
				if (read32le(&size, is) && size >= 0)
				{
					savestates[frame].resize(size);
					if (is->fread(&savestates[frame][0], size) == size)
					{
						if (loadSavestateOfFrame(currFrameCounter))
						{
							FCEU_printf("No Greenzone in the file\n");
							return false;
						}
					}
				}
			} else
			{
				// literally no Greenzone in the file, but this is still not a error
				reset();
				playback.restartPlaybackFromZeroGround();		// reset Playback cursor to frame 0
				FCEU_printf("No Greenzone in the file, Playback at frame 0\n");
				return false;
			}
		}
		goto error;
	}
	if (strcmp(greenzone_save_id, save_id)) goto error;		// string is not valid
	// read LagLog
	lagLog.load(is);
	// read size
	if (read32le(&size, is) && size >= 0 && size <= currMovieData.getNumRecords())
	{
		greenzoneSize = size;
		savestates.resize(greenzoneSize);
		// read Playback cursor position
		if (read32le(&frame, is))
		{
			currFrameCounter = frame;
			int greenzone_tail_frame = currFrameCounter - taseditorConfig.greenzoneCapacity;
			int greenzone_tail_frame2 = greenzone_tail_frame - 2 * taseditorConfig.greenzoneCapacity;
			int greenzone_tail_frame4 = greenzone_tail_frame - 4 * taseditorConfig.greenzoneCapacity;
			int greenzone_tail_frame8 = greenzone_tail_frame - 8 * taseditorConfig.greenzoneCapacity;
			int greenzone_tail_frame16 = greenzone_tail_frame - 16 * taseditorConfig.greenzoneCapacity;
			// read savestates
			while(1)
			{
				if (!read32le(&frame, is)) break;
				if (frame < 0) break;		// -1 = eof
				// update TASEditor progressbar from time to time
				if (frame / PROGRESSBAR_UPDATE_RATE > last_tick)
				{
					playback.setProgressbar(frame, greenzoneSize);
					last_tick = frame / PROGRESSBAR_UPDATE_RATE;
				}
				// read savestate
				if (!read32le(&size, is)) break;
				if (size < 0) break;
				if (frame <= greenzone_tail_frame16
					|| (frame <= greenzone_tail_frame8 && (frame & 0xF))
					|| (frame <= greenzone_tail_frame4 && (frame & 0x7))
					|| (frame <= greenzone_tail_frame2 && (frame & 0x3))
					|| (frame <= greenzone_tail_frame && (frame & 0x1)))
				{
					// skip loading this savestate
					if (is->fseek(size, SEEK_CUR) != 0) break;
				} else
				{
					// load this savestate
					if ((int)savestates.size() <= frame)
						savestates.resize(frame + 1);
					savestates[frame].resize(size);
					if ((int)is->fread(&savestates[frame][0], size) < size) break;
					prev_frame = frame;			// successfully read one Greenzone frame info
				}
			}
			if (prev_frame+1 == greenzoneSize)
			{
				// everything went fine - load savestate at cursor position
				if (loadSavestateOfFrame(currFrameCounter))
					return false;
			}
			// uh, okay, but maybe we managed to read at least something useful from the file
			// first see if original position of currFrameCounter was read successfully
			if (loadSavestateOfFrame(currFrameCounter))
			{
				greenzoneSize = prev_frame+1;		// cut greenZoneCount to last good frame
				FCEU_printf("Greenzone loaded partially\n");
				return false;
			}
			// then at least jump to some frame that was read successfully
			for (; prev_frame >= 0; prev_frame--)
			{
				if (loadSavestateOfFrame(prev_frame))
				{
					currFrameCounter = prev_frame;
					greenzoneSize = prev_frame+1;		// cut greenZoneCount to this good frame
					FCEU_printf("Greenzone loaded partially, Playback moved to the end of greenzone\n");
					return false;
				}
			}
		}
	}
error:
	FCEU_printf("Error loading Greenzone\n");
	reset();
	playback.restartPlaybackFromZeroGround();		// reset Playback cursor to frame 0
	return true;
}
// -------------------------------------------------------------------------------------------------
void GREENZONE::adjustUp()
{
	int at = currFrameCounter - 1;		// at = the frame above currFrameCounter
	// find how many consequent lag frames there are
	int num_frames_to_erase = 0;
	while (lagLog.getLagInfoAtFrame(at++) == LAGGED_YES)
		num_frames_to_erase++;

	if (num_frames_to_erase > 0)
	{
		bool markers_changed = false;
		// delete these frames of lag
		currMovieData.eraseRecords(currFrameCounter - 1, num_frames_to_erase);
		lagLog.eraseFrame(currFrameCounter - 1, num_frames_to_erase);
		if (taseditorConfig.bindMarkersToInput)
		{
			if (markersManager.eraseMarker(currFrameCounter - 1, num_frames_to_erase))
				markers_changed = true;
		}
		// update movie data size, because Playback cursor must always be inside the movie
		// if movie length is less or equal to currFrame, pad it with empty frames
		if (((int)currMovieData.records.size() - 1) <= currFrameCounter)
			currMovieData.insertEmpty(-1, currFrameCounter - ((int)currMovieData.records.size() - 1));
		// update Piano Roll (reduce it if needed)
		pianoRoll.updateLinesCount();
		// register changes
		int first_input_changes = history.registerAdjustLag(currFrameCounter - 1, 0 - num_frames_to_erase);
		// if Input in the frame above currFrameCounter has changed then invalidate Greenzone (rewind 1 frame back)
		// also if the frame above currFrameCounter is lag frame then rewind 1 frame (invalidate Greenzone), because maybe this frame also needs lag removal
		if ((first_input_changes >= 0 && first_input_changes < currFrameCounter) || (lagLog.getLagInfoAtFrame(currFrameCounter - 1) != LAGGED_NO))
		{
			// custom invalidation procedure, not retriggering LostPosition/PauseFrame
			invalidate(first_input_changes);
			bool emu_was_paused = (FCEUI_EmulationPaused() != 0);
			int saved_pause_frame = playback.getPauseFrame();
			playback.ensurePlaybackIsInsideGreenzone();
			if (saved_pause_frame >= 0)
				playback.startSeekingToFrame(saved_pause_frame);
			if (emu_was_paused)
				playback.pauseEmulation();
		} else
		{
			// just invalidate Greenzone after currFrameCounter (this is necessary in order to force user to re-emulate everything after the point, because the lag log data after the currFrameCounter is now in unknown state and it should be collected again)
			invalidate(currFrameCounter);
		}
		if (markers_changed)
			selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
	}
}
void GREENZONE::adjustDown()
{
	int at = currFrameCounter - 1;
	bool markers_changed = false;
	// clone frame and insert lag
	currMovieData.cloneRegion(at, 1);
	lagLog.insertFrame(at, true, 1);
	if (taseditorConfig.bindMarkersToInput)
	{
		if (markersManager.insertEmpty(at, 1))
			markers_changed = true;
	}
	// register changes
	int first_input_changes = history.registerAdjustLag(at, +1);
	// If Input in the frame above currFrameCounter has changed then invalidate Greenzone (rewind 1 frame back)
	// This should never actually happen, because we clone the frame, so the Input doesn't change
	// But the check should remain, in case we decide to insert blank frame instead of cloning
	if (first_input_changes >= 0 && first_input_changes < currFrameCounter)
	{
		// custom invalidation procedure, not retriggering LostPosition/PauseFrame
		invalidate(first_input_changes);
		bool emu_was_paused = (FCEUI_EmulationPaused() != 0);
		int saved_pause_frame = playback.getPauseFrame();
		playback.ensurePlaybackIsInsideGreenzone();
		if (saved_pause_frame >= 0)
			playback.startSeekingToFrame(saved_pause_frame);
		if (emu_was_paused)
			playback.pauseEmulation();
	} else
	{
		// just invalidate Greenzone after currFrameCounter
		invalidate(currFrameCounter);
	}
	if (markers_changed)
		selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
}
// -------------------------------------------------------------------------------------------------
// This version doesn't restore playback, may be used only by Branching, Recording and AdjustLag functions!
void GREENZONE::invalidate(int after)
{
	if (after >= 0)
	{
		if (after >= currMovieData.getNumRecords())
			after = currMovieData.getNumRecords() - 1;
		// clear all savestates that became irrelevant
		for (int i = savestates.size() - 1; i > after; i--)
			clearSavestateOfFrame(i);
		if (greenzoneSize > after + 1)
		{
			greenzoneSize = after + 1;
			FCEUMOV_IncrementRerecordCount();
		}
	}
	// redraw Piano Roll even if Greenzone didn't change
	pianoRoll.redraw();
	bookmarks.redrawBookmarksList();
}
// invalidate and restore playback
void GREENZONE::invalidateAndUpdatePlayback(int after)
{
	if (after >= 0)
	{
		if (after >= currMovieData.getNumRecords())
			after = currMovieData.getNumRecords() - 1;
		// clear all savestates that became irrelevant
		for (int i = savestates.size() - 1; i > after; i--)
			clearSavestateOfFrame(i);
		if (greenzoneSize > after + 1 || currFrameCounter > after)
		{
			greenzoneSize = after + 1;
			FCEUMOV_IncrementRerecordCount();
			// either set Playback cursor to be inside the Greenzone or run seeking to restore Playback cursor position
			if (currFrameCounter >= greenzoneSize)
			{
				if (playback.getPauseFrame() >= 0 && !FCEUI_EmulationPaused())
				{
					// emulator was running, so continue seeking, but don't follow the Playback cursor
					playback.jump(playback.getPauseFrame(), false, true, false);
				} else
				{
					playback.setLastPosition(currFrameCounter);
					if (taseditorConfig.autoRestoreLastPlaybackPosition)
						// start seeking to the green arrow, but don't follow the Playback cursor
						playback.jump(playback.getLastPosition(), false, true, false);
					else
						playback.ensurePlaybackIsInsideGreenzone();
				}
			}
		}
	}
	// redraw Piano Roll even if Greenzone didn't change
	pianoRoll.redraw();
	bookmarks.redrawBookmarksList();
}
// -------------------------------------------------------------------------------------------------
int GREENZONE::findFirstGreenzonedFrame(int starting_index)
{
	for (int i = starting_index; i < greenzoneSize; ++i)
		if (savestates[i].size()) return i;
	return -1;	// error
}

// getters
int GREENZONE::getSize()
{
	return greenzoneSize;
}

// this should only be used by Bookmark Set procedure
std::vector<uint8>& GREENZONE::getSavestateOfFrame(int frame)
{
	return savestates[frame];
}
// this function should only be used by Bookmark Deploy procedure
void GREENZONE::writeSavestateForFrame(int frame, std::vector<uint8>& savestate)
{
	if ((int)savestates.size() <= frame)
		savestates.resize(frame + 1);
	savestates[frame] = savestate;
	if (greenzoneSize <= frame)
		greenzoneSize = frame + 1;
}

bool GREENZONE::isSavestateEmpty(unsigned int frame)
{
	if ((int)frame < greenzoneSize && frame < savestates.size() && savestates[frame].size())
		return false;
	else
		return true;
}

