/* ---------------------------------------------------------------------------------
Implementation file of InputLog class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
InputLog - Log of Input

* stores the data about Input state: size, type of Input, Input Log data (commands and joysticks)
* optionally can store map of Hot Changes
* implements InputLog creation: copying Input, copying Hot Changes
* implements full/partial restoring of data from InputLog: Input, Hot Changes
* implements compression and decompression of stored data
* saves and loads the data from a project file. On error: sends warning to caller
* implements searching of first mismatch comparing two InputLogs or comparing this InputLog to a movie
* provides interface for reading specific data: reading Input of any given frame, reading value at any point of Hot Changes map
* implements all operations with Hot Changes maps: copying (full/partial), updating/fading, setting new hot places by comparing two InputLogs
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "zlib.h"

extern SELECTION selection;
extern int getInputType(MovieData& md);

int joysticksPerFrame[INPUT_TYPES_TOTAL] = {1, 2, 4};

INPUTLOG::INPUTLOG()
{
}

void INPUTLOG::init(MovieData& md, bool hotchanges, int force_input_type)
{
	hasHotChanges = hotchanges;
	if (force_input_type < 0)
		inputType = getInputType(md);
	else
		inputType = force_input_type;
	int num_joys = joysticksPerFrame[inputType];
	// retrieve Input data from movie data
	size = md.getNumRecords();
	joysticks.resize(BYTES_PER_JOYSTICK * num_joys * size);		// it's much faster to have this format than have [frame][joy] or other structures
	commands.resize(size);				// commands take 1 byte per frame
	if (hasHotChanges)
		initHotChanges();

	// fill Input vector
	int joy;
	for (int frame = 0; frame < size; ++frame)
	{
		for (joy = num_joys - 1; joy >= 0; joy--)
			joysticks[frame * num_joys * BYTES_PER_JOYSTICK + joy * BYTES_PER_JOYSTICK] = md.records[frame].joysticks[joy];
		commands[frame] = md.records[frame].commands;
	}
	alreadyCompressed = false;
}

// this function only updates one frame of Input Log and Hot Changes data
// the function should only be used when combining consecutive Recordings
void INPUTLOG::reinit(MovieData& md, bool hotchanges, int frame_of_change)
{
	hasHotChanges = hotchanges;
	int num_joys = joysticksPerFrame[inputType];
	int joy;
	// retrieve Input data from movie data
	size = md.getNumRecords();
	joysticks.resize(BYTES_PER_JOYSTICK * num_joys * size, 0);
	commands.resize(size);
	if (hasHotChanges)
	{
		// resize Hot Changes
		initHotChanges();
		// compare current movie data at the frame_of_change to current state of InputLog at the frame_of_change
		uint8 my_joy, their_joy;
		for (joy = num_joys - 1; joy >= 0; joy--)
		{
			my_joy = getJoystickData(frame_of_change, joy);
			their_joy = md.records[frame_of_change].joysticks[joy];
			if (my_joy != their_joy)
				setMaxHotChangeBits(frame_of_change, joy, my_joy ^ their_joy);
		}
	} else
	{
		// if user switches Hot Changes off inbetween two consecutive Recordings
		hotChanges.resize(0);
	}

	// update Input vector
	for (joy = num_joys - 1; joy >= 0; joy--)
		joysticks[frame_of_change * num_joys * BYTES_PER_JOYSTICK + joy * BYTES_PER_JOYSTICK] = md.records[frame_of_change].joysticks[joy];
	commands[frame_of_change] = md.records[frame_of_change].commands;
	alreadyCompressed = false;
}

void INPUTLOG::toMovie(MovieData& md, int start, int end)
{
	if (end < 0 || end >= size) end = size - 1;
	// write Input data to movie data
	md.records.resize(end + 1);
	int num_joys = joysticksPerFrame[inputType];
	int joy;
	for (int frame = start; frame <= end; ++frame)
	{
		for (joy = num_joys - 1; joy >= 0; joy--)
			md.records[frame].joysticks[joy] = joysticks[frame * num_joys * BYTES_PER_JOYSTICK + joy * BYTES_PER_JOYSTICK];
		md.records[frame].commands = commands[frame];
	}
}

void INPUTLOG::compressData()
{
	// compress joysticks
	int len = joysticks.size();
	uLongf comprlen = (len>>9)+12 + len;
	compressedJoysticks.resize(comprlen);
	compress(&compressedJoysticks[0], &comprlen, &joysticks[0], len);
	compressedJoysticks.resize(comprlen);
	// compress commands
	len = commands.size();
	comprlen = (len>>9)+12 + len;
	compressedCommands.resize(comprlen);
	compress(&compressedCommands[0], &comprlen, &commands[0], len);
	compressedCommands.resize(comprlen);
	if (hasHotChanges)
	{
		// compress hot_changes
		len = hotChanges.size();
		comprlen = (len>>9)+12 + len;
		compressedHotChanges.resize(comprlen);
		compress(&compressedHotChanges[0], &comprlen, &hotChanges[0], len);
		compressedHotChanges.resize(comprlen);
	}
	// don't recompress anymore
	alreadyCompressed = true;
}
bool INPUTLOG::isAlreadyCompressed()
{
	return alreadyCompressed;
}

void INPUTLOG::save(EMUFILE *os)
{
	// write vars
	write32le(size, os);
	write8le(inputType, os);
	// write data
	if (!alreadyCompressed)
		compressData();
	// save joysticks data
	write32le(compressedJoysticks.size(), os);
	os->fwrite(&compressedJoysticks[0], compressedJoysticks.size());
	// save commands data
	write32le(compressedCommands.size(), os);
	os->fwrite(&compressedCommands[0], compressedCommands.size());
	if (hasHotChanges)
	{
		write8le((uint8)1, os);
		// save hot_changes data
		write32le(compressedHotChanges.size(), os);
		os->fwrite(&compressedHotChanges[0], compressedHotChanges.size());
	} else
	{
		write8le((uint8)0, os);
	}
}
// returns true if couldn't load
bool INPUTLOG::load(EMUFILE *is)
{
	uint8 tmp;
	// read vars
	if (!read32le(&size, is)) return true;
	if (!read8le(&tmp, is)) return true;
	inputType = tmp;
	// read data
	alreadyCompressed = true;
	int comprlen;
	uLongf destlen;
	// read and uncompress joysticks data
	destlen = size * BYTES_PER_JOYSTICK * joysticksPerFrame[inputType];
	joysticks.resize(destlen);
	// read size
	if (!read32le(&comprlen, is)) return true;
	if (comprlen <= 0) return true;
	compressedJoysticks.resize(comprlen);
	if (is->fread(&compressedJoysticks[0], comprlen) != comprlen) return true;
	int e = uncompress(&joysticks[0], &destlen, &compressedJoysticks[0], comprlen);
	if (e != Z_OK && e != Z_BUF_ERROR) return true;
	// read and uncompress commands data
	destlen = size;
	commands.resize(destlen);
	// read size
	if (!read32le(&comprlen, is)) return true;
	if (comprlen <= 0) return true;
	compressedCommands.resize(comprlen);
	if (is->fread(&compressedCommands[0], comprlen) != comprlen) return true;
	e = uncompress(&commands[0], &destlen, &compressedCommands[0], comprlen);
	if (e != Z_OK && e != Z_BUF_ERROR) return true;
	// read hotchanges
	if (!read8le(&tmp, is)) return true;
	hasHotChanges = (tmp != 0);
	if (hasHotChanges)
	{
		// read and uncompress hot_changes data
		destlen = size * joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		hotChanges.resize(destlen);
		// read size
		if (!read32le(&comprlen, is)) return true;
		if (comprlen <= 0) return true;
		compressedHotChanges.resize(comprlen);
		if (is->fread(&compressedHotChanges[0], comprlen) != comprlen) return true;
		e = uncompress(&hotChanges[0], &destlen, &compressedHotChanges[0], comprlen);
		if (e != Z_OK && e != Z_BUF_ERROR) return true;
	}
	return false;
}
bool INPUTLOG::skipLoad(EMUFILE *is)
{
	int tmp;
	uint8 tmp1;
	// skip vars
	if (is->fseek(sizeof(int) +	// size
				sizeof(uint8)	// input_type
				, SEEK_CUR)) return true;
	// skip joysticks data
	if (!read32le(&tmp, is)) return true;
	if (is->fseek(tmp, SEEK_CUR) != 0) return true;
	// skip commands data
	if (!read32le(&tmp, is)) return true;
	if (is->fseek(tmp, SEEK_CUR) != 0) return true;
	// skip hot_changes data
	if (!read8le(&tmp1, is)) return true;
	if (tmp1)
	{
		if (!read32le(&tmp, is)) return true;
		if (is->fseek(tmp, SEEK_CUR) != 0) return true;
	}
	return false;
}
// --------------------------------------------------------------------------------------------
// return number of first frame of difference between two InputLogs
int INPUTLOG::findFirstChange(INPUTLOG& theirLog, int start, int end)
{
	// search for differences to the specified end (or to the end of this InputLog)
	if (end < 0 || end >= size) end = size-1;
	int their_log_end = theirLog.size;

	int joy;
	int num_joys = joysticksPerFrame[inputType];
	for (int frame = start; frame <= end; ++frame)
	{
		for (joy = num_joys - 1; joy >= 0; joy--)
			if (getJoystickData(frame, joy) != theirLog.getJoystickData(frame, joy)) return frame;
		if (getCommandsData(frame) != theirLog.getCommandsData(frame)) return frame;
	}
	// no difference was found

	// if my_size is less then their_size, return last frame + 1 (= size) as the frame of difference
	if (size < their_log_end) return size;
	// no changes were found
	return -1;
}
// return number of first frame of difference between this InputLog and MovieData
int INPUTLOG::findFirstChange(MovieData& md, int start, int end)
{
	// search for differences to the specified end (or to the end of this InputLog / to the end of the movie data)
	if (end < 0 || end >= size) end = size - 1;
	if (end >= md.getNumRecords()) end = md.getNumRecords() - 1;

	int joy;
	int num_joys = joysticksPerFrame[inputType];
	for (int frame = start; frame <= end; ++frame)
	{
		for (joy = num_joys - 1; joy >= 0; joy--)
			if (getJoystickData(frame, joy) != md.records[frame].joysticks[joy]) return frame;
		if (getCommandsData(frame) != md.records[frame].commands) return frame;
	}
	// no difference was found

	// if sizes differ, return last frame + 1 from the lesser of them
	if (size < md.getNumRecords() && end >= size - 1)
		return size;
	else if (size > md.getNumRecords() && end >= md.getNumRecords() - 1)
		return md.getNumRecords();

	return -1;
}

int INPUTLOG::getJoystickData(int frame, int joy)
{
	if (frame < 0 || frame >= size)
		return 0;
	if (joy > joysticksPerFrame[inputType])
		return 0;
	return joysticks[frame * BYTES_PER_JOYSTICK * joysticksPerFrame[inputType] + joy];
}
int INPUTLOG::getCommandsData(int frame)
{
	if (frame < 0 || frame >= size)
		return 0;
	return commands[frame];
}

void INPUTLOG::insertFrames(int at, int frames)
{
	size += frames;
	if (at == -1) 
	{
		// append frames to the end
		commands.resize(size);
		joysticks.resize(BYTES_PER_JOYSTICK * joysticksPerFrame[inputType] * size);
		if (hasHotChanges)
		{
			hotChanges.resize(joysticksPerFrame[inputType] * size * HOTCHANGE_BYTES_PER_JOY);
			// fill new hotchanges with max value
			int lower_limit = joysticksPerFrame[inputType] * (size - frames) * HOTCHANGE_BYTES_PER_JOY;
			for (int i = hotChanges.size() - 1; i >= lower_limit; i--)
				hotChanges[i] = BYTE_VALUE_CONTAINING_MAX_HOTCHANGES;
		}
	} else
	{
		// insert frames
		// insert 1 byte of commands
		commands.insert(commands.begin() + at, frames, 0);
		// insert X bytes of joystics
		int bytes = BYTES_PER_JOYSTICK * joysticksPerFrame[inputType];
		joysticks.insert(joysticks.begin() + (at * bytes), frames * bytes, 0);
		if (hasHotChanges)
		{
			// insert X bytes of hot_changes
			bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
			hotChanges.insert(hotChanges.begin() + (at * bytes), frames * bytes, BYTE_VALUE_CONTAINING_MAX_HOTCHANGES);
		}
	}
	// data was changed
	alreadyCompressed = false;
}
void INPUTLOG::eraseFrame(int frame)
{
	// erase 1 byte of commands
	commands.erase(commands.begin() + frame);
	// erase X bytes of joystics
	int bytes = BYTES_PER_JOYSTICK * joysticksPerFrame[inputType];
	joysticks.erase(joysticks.begin() + (frame * bytes), joysticks.begin() + ((frame + 1) * bytes));
	if (hasHotChanges)
	{
		// erase X bytes of hot_changes
		bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		hotChanges.erase(hotChanges.begin() + (frame * bytes), hotChanges.begin() + ((frame + 1) * bytes));
	}
	size--;
	// data was changed
	alreadyCompressed = false;
}
// -----------------------------------------------------------------------------------------------
void INPUTLOG::initHotChanges()
{
	hotChanges.resize(joysticksPerFrame[inputType] * size * HOTCHANGE_BYTES_PER_JOY);
}

void INPUTLOG::copyHotChanges(INPUTLOG* sourceOfHotChanges, int limiterFrameOfSource)
{
	// copy hot changes from source InputLog
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int frames_to_copy = sourceOfHotChanges->size;
		if (frames_to_copy > size)
			frames_to_copy = size;
		// special case for Branches: if limit_frame if specified, then copy only hotchanges from 0 to limit_frame
		if (limiterFrameOfSource >= 0 && frames_to_copy > limiterFrameOfSource)
			frames_to_copy = limiterFrameOfSource;

		int bytes_to_copy = frames_to_copy * joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		memcpy(&hotChanges[0], &sourceOfHotChanges->hotChanges[0], bytes_to_copy);
	}
} 
void INPUTLOG::inheritHotChanges(INPUTLOG* sourceOfHotChanges)
{
	// copy hot changes from source InputLog and fade them
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int frames_to_copy = sourceOfHotChanges->size;
		if (frames_to_copy > size)
			frames_to_copy = size;

		int bytes_to_copy = frames_to_copy * joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		memcpy(&hotChanges[0], &sourceOfHotChanges->hotChanges[0], bytes_to_copy);
		fadeHotChanges();
	}
} 
void INPUTLOG::inheritHotChanges_DeleteSelection(INPUTLOG* sourceOfHotChanges, RowsSelection* frameset)
{
	// copy hot changes from source InputLog, but omit deleted frames (which are represented by the "frameset")
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		int frame = 0, pos = 0, source_pos = 0;
		int this_size = hotChanges.size(), source_size = sourceOfHotChanges->hotChanges.size();
		RowsSelection::iterator it(frameset->begin());
		RowsSelection::iterator frameset_end(frameset->end());
		while (pos < this_size && source_pos < source_size)
		{
			if (it != frameset_end && frame == *it)
			{
				// omit the frame
				it++;
				source_pos += bytes;
			} else
			{
				// copy hotchanges of this frame
				memcpy(&hotChanges[pos], &sourceOfHotChanges->hotChanges[source_pos], bytes);
				pos += bytes;
				source_pos += bytes;
			}
			frame++;
		}
		fadeHotChanges();
	}
} 
void INPUTLOG::inheritHotChanges_InsertSelection(INPUTLOG* sourceOfHotChanges, RowsSelection* frameset)
{
	// copy hot changes from source InputLog, but insert filled lines for inserted frames (which are represented by the "frameset")
	RowsSelection::iterator it(frameset->begin());
	RowsSelection::iterator frameset_end(frameset->end());
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		int frame = 0, region_len = 0, pos = 0, source_pos = 0;
		int this_size = hotChanges.size(), source_size = sourceOfHotChanges->hotChanges.size();
		while (pos < this_size)
		{
			if (it != frameset_end && frame == *it)
			{
				// omit the frame
				it++;
				region_len++;
				// set filled line to the frame
				memset(&hotChanges[pos], BYTE_VALUE_CONTAINING_MAX_HOTCHANGES, bytes);
			} else if (source_pos < source_size)
			{
				// this frame should be copied
				frame -= region_len;
				region_len = 0;
				// copy hotchanges of this frame
				memcpy(&hotChanges[pos], &sourceOfHotChanges->hotChanges[source_pos], bytes);
				fadeHotChanges(pos, pos + bytes);
				source_pos += bytes;
			}
			pos += bytes;
			frame++;
		}
	} else
	{
		// no old data, just fill "frameset" lines
		int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
		int frame = 0, region_len = 0, pos = 0;
		int this_size = hotChanges.size();
		while (pos < this_size)
		{
			if (it != frameset_end && frame == *it)
			{
				// this frame is selected
				it++;
				region_len++;
				// set filled line to the frame
				memset(&hotChanges[pos], BYTE_VALUE_CONTAINING_MAX_HOTCHANGES, bytes);
				// exit loop when all frames in the Selection are handled
				if (it == frameset_end) break;
			} else
			{
				// this frame is not selected
				frame -= region_len;
				region_len = 0;
				// leave zeros in this frame
			}
			pos += bytes;
			frame++;
		}
	}
}
void INPUTLOG::inheritHotChanges_DeleteNum(INPUTLOG* sourceOfHotChanges, int start, int frames, bool fadeOld)
{
	int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
	// copy hot changes from source InputLog up to "start" and from "start+frames" to end
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int this_size = hotChanges.size(), source_size = sourceOfHotChanges->hotChanges.size();
		int bytes_to_copy = bytes * start;
		int dest_pos = 0, source_pos = 0;
		if (bytes_to_copy > source_size)
			bytes_to_copy = source_size;
		memcpy(&hotChanges[dest_pos], &sourceOfHotChanges->hotChanges[source_pos], bytes_to_copy);
		dest_pos += bytes_to_copy;
		source_pos += bytes_to_copy + bytes * frames;
		bytes_to_copy = this_size - dest_pos;
		if (bytes_to_copy > source_size - source_pos)
			bytes_to_copy = source_size - source_pos;
		memcpy(&hotChanges[dest_pos], &sourceOfHotChanges->hotChanges[source_pos], bytes_to_copy);
		if (fadeOld)
			fadeHotChanges();
	}
} 
void INPUTLOG::inheritHotChanges_InsertNum(INPUTLOG* sourceOfHotChanges, int start, int frames, bool fadeOld)
{
	int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
	// copy hot changes from source InputLog up to "start", then make a gap, then copy from "start+frames" to end
	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int this_size = hotChanges.size(), source_size = sourceOfHotChanges->hotChanges.size();
		int bytes_to_copy = bytes * start;
		int dest_pos = 0, source_pos = 0;
		if (bytes_to_copy > source_size)
			bytes_to_copy = source_size;
		memcpy(&hotChanges[dest_pos], &sourceOfHotChanges->hotChanges[source_pos], bytes_to_copy);
		dest_pos += bytes_to_copy + bytes * frames;
		source_pos += bytes_to_copy;
		bytes_to_copy = this_size - dest_pos;
		if (bytes_to_copy > source_size - source_pos)
			bytes_to_copy = source_size - source_pos;
		memcpy(&hotChanges[dest_pos], &sourceOfHotChanges->hotChanges[source_pos], bytes_to_copy);
		if (fadeOld)
			fadeHotChanges();
	}
	// fill the gap with max_hot lines on frames from "start" to "start+frames"
	memset(&hotChanges[bytes * start], BYTE_VALUE_CONTAINING_MAX_HOTCHANGES, bytes * frames);
}
void INPUTLOG::inheritHotChanges_PasteInsert(INPUTLOG* sourceOfHotChanges, RowsSelection* insertedSet)
{
	// copy hot changes from source InputLog and insert filled lines for inserted frames (which are represented by "inserted_set")
	int bytes = joysticksPerFrame[inputType] * HOTCHANGE_BYTES_PER_JOY;
	int frame = 0, pos = 0;
	int this_size = hotChanges.size();
	RowsSelection::iterator it(insertedSet->begin());
	RowsSelection::iterator inserted_set_end(insertedSet->end());

	if (sourceOfHotChanges && sourceOfHotChanges->hasHotChanges && sourceOfHotChanges->inputType == inputType)
	{
		int source_pos = 0;
		int source_size = sourceOfHotChanges->hotChanges.size();
		while (pos < this_size)
		{
			if (it != inserted_set_end && frame == *it)
			{
				// this frame was inserted
				it++;
				// set filled line to the frame
				memset(&hotChanges[pos], BYTE_VALUE_CONTAINING_MAX_HOTCHANGES, bytes);
			} else if (source_pos < source_size)
			{
				// copy hotchanges of this frame
				memcpy(&hotChanges[pos], &sourceOfHotChanges->hotChanges[source_pos], bytes);
				fadeHotChanges(pos, pos + bytes);
				source_pos += bytes;
			}
			pos += bytes;
			frame++;
		}
	} else
	{
		// no old data, just fill selected lines
		while (pos < this_size)
		{
			if (it != inserted_set_end && frame == *it)
			{
				// this frame was inserted
				it++;
				// set filled line to the frame
				memset(&hotChanges[pos], BYTE_VALUE_CONTAINING_MAX_HOTCHANGES, bytes);
				pos += bytes;
				// exit loop when all inserted_set frames are handled
				if (it == inserted_set_end) break;
			} else
			{
				// leave zeros in this frame
				pos += bytes;
			}
			frame++;
		}
	}
} 
void INPUTLOG::fillHotChanges(INPUTLOG& theirLog, int start, int end)
{
	// compare InputLogs to the specified end (or to the end of this InputLog)
	if (end < 0 || end >= size) end = size-1;
	uint8 my_joy, their_joy;
	for (int joy = joysticksPerFrame[inputType] - 1; joy >= 0; joy--)
	{
		for (int frame = start; frame <= end; ++frame)
		{
			my_joy = getJoystickData(frame, joy);
			their_joy = theirLog.getJoystickData(frame, joy);
			if (my_joy != their_joy)
				setMaxHotChangeBits(frame, joy, my_joy ^ their_joy);
		}						
	}
}

void INPUTLOG::setMaxHotChangeBits(int frame, int joypad, uint8 joyBits)
{
	uint8 mask = 1;
	// check all 8 buttons and set max hot_changes for bits that are set
	for (int i = 0; i < BUTTONS_PER_JOYSTICK; ++i)
	{
		if (joyBits & mask)
			setMaxHotChanges(frame, joypad * BUTTONS_PER_JOYSTICK + i);
		mask <<= 1;
	}
}
void INPUTLOG::setMaxHotChanges(int frame, int absoluteButtonNumber)
{
	if (frame < 0 || frame >= size || !hasHotChanges) return;
	// set max value to the button hotness
	if (absoluteButtonNumber & 1)
		hotChanges[frame * (HOTCHANGE_BYTES_PER_JOY * joysticksPerFrame[inputType]) + (absoluteButtonNumber >> 1)] |= BYTE_VALUE_CONTAINING_MAX_HOTCHANGE_HI;
	else
		hotChanges[frame * (HOTCHANGE_BYTES_PER_JOY * joysticksPerFrame[inputType]) + (absoluteButtonNumber >> 1)] |= BYTE_VALUE_CONTAINING_MAX_HOTCHANGE_LO;
}

void INPUTLOG::fadeHotChanges(int startByte, int endByte)
{
	uint8 hi_half, low_half;
	if (endByte < 0)
		endByte = hotChanges.size();
	for (int i = endByte - 1; i >= startByte; i--)
	{
		if (hotChanges[i])
		{
			hi_half = hotChanges[i] >> HOTCHANGE_BITS_PER_VALUE;
			low_half = hotChanges[i] & HOTCHANGE_BITMASK;
			if (hi_half) hi_half--;
			if (low_half) low_half--;
			hotChanges[i] = (hi_half << HOTCHANGE_BITS_PER_VALUE) | low_half;
		}
	}
}

int INPUTLOG::getHotChangesInfo(int frame, int absoluteButtonNumber)
{
	if (!hasHotChanges || frame < 0 || frame >= size || absoluteButtonNumber < 0 || absoluteButtonNumber >= NUM_JOYPAD_BUTTONS * joysticksPerFrame[inputType])
		return 0;

	uint8 val = hotChanges[frame * (HOTCHANGE_BYTES_PER_JOY * joysticksPerFrame[inputType]) + (absoluteButtonNumber >> 1)];

	if (absoluteButtonNumber & 1)
		// odd buttons (B, T, D, R) take upper 4 bits of the byte 
		return val >> HOTCHANGE_BITS_PER_VALUE;
	else
		// even buttons (A, S, U, L) take lower 4 bits of the byte 
		return val & HOTCHANGE_BITMASK;
}

