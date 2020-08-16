/* ---------------------------------------------------------------------------------
Implementation file of LagLog class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
LagLog - Log of Lag appearance

* stores the frame-by-frame log of lag appearance
* implements compression and decompression of stored data
* saves and loads the data from a project file. On error: sends warning to caller
* provides interface for reading and writing log data
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "zlib.h"

LAGLOG::LAGLOG()
{
	alreadyCompressed = false;
}

void LAGLOG::reset()
{
	lagLog.resize(0);
	alreadyCompressed = false;
}

void LAGLOG::compressData()
{
	int len = lagLog.size() * sizeof(uint8);
	if (len)
	{
		uLongf comprlen = (len>>9)+12 + len;
		compressedLagLog.resize(comprlen, LAGGED_UNKNOWN);
		compress(&compressedLagLog[0], &comprlen, (uint8*)&lagLog[0], len);
		compressedLagLog.resize(comprlen);
	} else
	{
		// LagLog can even be empty
		compressedLagLog.resize(0);
	}
	alreadyCompressed = true;
}
bool LAGLOG::isAlreadyCompressed()
{
	return alreadyCompressed;
}
void LAGLOG::resetCompressedStatus()
{
	alreadyCompressed = false;
}

void LAGLOG::save(EMUFILE *os)
{
	// write size
	int size = lagLog.size();
	write32le(size, os);
	if (size)
	{
		// write array
		if (!alreadyCompressed)
			compressData();
		write32le(compressedLagLog.size(), os);
		os->fwrite(&compressedLagLog[0], compressedLagLog.size());
	}
}
// returns true if couldn't load
bool LAGLOG::load(EMUFILE *is)
{
	int size;
	if (read32le(&size, is))
	{
		alreadyCompressed = true;
		lagLog.resize(size, LAGGED_UNKNOWN);
		if (size)
		{
			// read and uncompress array
			int comprlen;
			uLongf destlen = size * sizeof(int);
			if (!read32le(&comprlen, is)) return true;
			if (comprlen <= 0) return true;
			compressedLagLog.resize(comprlen);
			if (is->fread(&compressedLagLog[0], comprlen) != comprlen) return true;
			int e = uncompress((uint8*)&lagLog[0], &destlen, &compressedLagLog[0], comprlen);
			if (e != Z_OK && e != Z_BUF_ERROR) return true;
		} else
		{
			compressedLagLog.resize(0);
		}
		// all ok
		return false;
	}
	return true;
}
bool LAGLOG::skipLoad(EMUFILE *is)
{
	int size;
	if (read32le(&size, is))
	{
		if (size)
		{
			// skip array
			if (!read32le(&size, is)) return true;
			if (is->fseek(size, SEEK_CUR) != 0) return true;
		}
		// all ok
		return false;
	}
	return true;
}
// -------------------------------------------------------------------------------------------------
void LAGLOG::invalidateFromFrame(int frame)
{
	if (frame >= 0 && frame < (int)lagLog.size())
	{
		lagLog.resize(frame);
		alreadyCompressed = false;
	}
}

void LAGLOG::setLagInfo(int frame, bool lagFlag)
{
	if ((int)lagLog.size() <= frame)
		lagLog.resize(frame + 1, LAGGED_UNKNOWN);

	if (lagFlag)
		lagLog[frame] = LAGGED_YES;
	else
		lagLog[frame] = LAGGED_NO;

	alreadyCompressed = false;
}
void LAGLOG::eraseFrame(int frame, int numFrames)
{
	if (frame < (int)lagLog.size())
	{
		if (numFrames == 1)
		{
			// erase 1 frame
			lagLog.erase(lagLog.begin() + frame);
			alreadyCompressed = false;
		} else if (numFrames > 1)
		{
			// erase many frames
			if (frame + numFrames > (int)lagLog.size())
				numFrames = (int)lagLog.size() - frame;
			lagLog.erase(lagLog.begin() + frame, lagLog.begin() + (frame + numFrames));
			alreadyCompressed = false;
		}
	}
}
void LAGLOG::insertFrame(int frame, bool lagFlag, int numFrames)
{
	if (frame < (int)lagLog.size())
	{
		// insert
		lagLog.insert(lagLog.begin() + frame, numFrames, (lagFlag) ? LAGGED_YES : LAGGED_NO);
	} else
	{
		// append
		lagLog.resize(frame + 1, LAGGED_UNKNOWN);
		if (lagFlag)
			lagLog[frame] = LAGGED_YES;
		else
			lagLog[frame] = LAGGED_NO;
	}
	alreadyCompressed = false;
}

// getters
int LAGLOG::getSize()
{
	return lagLog.size();
}
int LAGLOG::getLagInfoAtFrame(int frame)
{
	if (frame < (int)lagLog.size())
		return lagLog[frame];
	else
		return LAGGED_UNKNOWN;
}

int LAGLOG::findFirstChange(LAGLOG& theirLog)
{
	// search for differences to the end of this or their LagLog, whichever is less
	int end = lagLog.size() - 1;
	int their_log_end = theirLog.getSize() - 1;
	if (end > their_log_end)
		end = their_log_end;

	uint8 my_lag_info, their_lag_info;
	for (int i = 0; i <= end; ++i)
	{
		// if old info != new info and both infos are known
		my_lag_info = lagLog[i];
		their_lag_info = theirLog.getLagInfoAtFrame(i);
		if ((my_lag_info == LAGGED_YES && their_lag_info == LAGGED_NO) || (my_lag_info == LAGGED_NO && their_lag_info == LAGGED_YES))
			return i;
	}
	// no difference was found
	return -1;
}


