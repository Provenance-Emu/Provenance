/* FCEUXD SP - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 Sebastian Porst
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */
 
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "utils/xstring.h"
#include <assert.h>
#include "common.h"
#include "debugger.h"
#include "debuggersp.h"
#include "memviewsp.h"
#include "../../debug.h"

extern bool break_on_cycles;
extern uint64 break_cycles_limit;
extern bool break_on_instructions;
extern uint64 break_instructions_limit;

/**
* Stores debugger preferences in a file
*
* @param f File to write the preferences to
* @return 0 if everything went fine. An error code if something went wrong.
**/	
int storeDebuggerPreferences(FILE* f)
{
	int i;
	unsigned int size, len;
	uint8 tmp;

	// Write the number of CPU bookmarks
	size = bookmarks_addr.size();
	bookmarks_name.resize(size);
	if (fwrite(&size, sizeof(unsigned int), 1, f) != 1) return 1;
	// Write the data of those bookmarks
	for (i = 0; i < (int)size; ++i)
	{
		if (fwrite(&bookmarks_addr[i], sizeof(unsigned int), 1, f) != 1) return 1;
		len = bookmarks_name[i].size();
		if (fwrite(&len, sizeof(unsigned int), 1, f) != 1) return 1;
		if (fwrite(bookmarks_name[i].c_str(), 1, len, f) != len) return 1;
	}

	// Write all breakpoints
	for (i=0;i<65;i++)
	{
		unsigned int len;

		// Write the start address of a BP
		if (fwrite(&watchpoint[i].address, sizeof(watchpoint[i].address), 1, f) != 1) return 1;
		// Write the end address of a BP
		if (fwrite(&watchpoint[i].endaddress, sizeof(watchpoint[i].endaddress), 1, f) != 1) return 1;
		// Write the flags of a BP
		if (fwrite(&watchpoint[i].flags, sizeof(watchpoint[i].flags), 1, f) != 1) return 1;
		
		// Write the length of the BP condition
		len = watchpoint[i].condText ? strlen(watchpoint[i].condText) : 0;
		if (fwrite(&len, sizeof(len), 1, f) != 1) return 1;
		
		// Write the text of the BP condition
		if (len)
		{
			if (fwrite(watchpoint[i].condText, 1, len, f) != len) return 1;
		}
		
		len = watchpoint[i].desc ? strlen(watchpoint[i].desc) : 0;
		
		// Write the length of the BP description
		if (fwrite(&len, sizeof(len), 1, f) != 1) return 1;
		
		// Write the actual BP description
		if (len)
		{
			if (fwrite(watchpoint[i].desc, 1, len, f) != len) return 1;
		}
	}

	// write "Break on Bad Opcode" flag
	if (FCEUI_Debugger().badopbreak)
		tmp = 1;
	else
		tmp = 0;
	if (fwrite(&tmp, 1, 1, f) != 1) return 1;
	// write "Break when exceed" data
	if (break_on_cycles)
		tmp = 1;
	else
		tmp = 0;
	if (fwrite(&tmp, 1, 1, f) != 1) return 1;
	if (fwrite(&break_cycles_limit, sizeof(break_cycles_limit), 1, f) != 1) return 1;
	if (break_on_instructions)
		tmp = 1;
	else
		tmp = 0;
	if (fwrite(&tmp, 1, 1, f) != 1) return 1;
	if (fwrite(&break_instructions_limit, sizeof(break_instructions_limit), 1, f) != 1) return 1;
	
	return 0;
}

/**
* Stores the preferences from the Hex window
*
* @param f File to write the preferences to
* @return 0 if everything went fine. An error code if something went wrong.
**/
int storeHexPreferences(FILE* f)
{
	int i;

	// Writes the number of bookmarks to save
	if (fwrite(&nextBookmark, sizeof(nextBookmark), 1, f) != 1) return 1;
	
	for (i=0;i<nextBookmark;i++)
	{
		unsigned int len;

		// Writes the bookmark address
		if (fwrite(&hexBookmarks[i].address, sizeof(hexBookmarks[i].address), 1, f) != 1) return 1;
		
		len = strlen(hexBookmarks[i].description);
		// Writes the length of the bookmark description
		if (fwrite(&len, sizeof(len), 1, f) != 1) return 1;
		// Writes the actual bookmark description
		if (fwrite(hexBookmarks[i].description, 1, len, f) != len) return 1;
	}
	
	return 0;
}

/**
* Stores the debugging preferences to a file name romname.nes.deb
*
* @param romname Name of the ROM
* @return 0 on success or an error code.
**/
int storePreferences(const char* romname)
{

	if (debuggerSaveLoadDEBFiles == false)
		return 0;

	FILE* f;
	char* filename;
	int result;
	int Counter = 0;
	
	// Prevent any attempts at file usage if the debugger is open
	// Moved debugger exit code due to complaints and the Debugger menu option being enabled

	if (!debuggerWasActive)
		return 0;

	/*
	// With some work, this could be made to prevent writing empty .deb files.
	// Currently, it doesn't account for fully-deleted lists when deciding to write.
	int i;
	int makeDebugFile = 0;

	for (i=0;i<65;i++)
	{
		if (watchpoint[i].address || watchpoint[i].endaddress || watchpoint[i].flags || hexBookmarks[i].address || hexBookmarks[i].description[0])
		makeDebugFile = 1;	
	}

	if (!makeDebugFile) 
	{
		return 0;
	}
	*/

	filename = (char*)malloc(strlen(romname) + 5);
	strcpy(filename, romname);
	strcat(filename, ".deb");

	f = fopen(filename, "wb");

	free(filename);
	
	result = !f || storeDebuggerPreferences(f) || storeHexPreferences(f);

	if (f) {
		fclose(f);
	}

	return result;
}

void DoDebuggerDataReload()
{
	if (debuggerSaveLoadDEBFiles == false)
		return;
	
	extern HWND hDebug;
	LoadGameDebuggerData(hDebug);
}

int myNumWPs = 0;
int loadDebugDataFailed = 0;

/**
* Loads debugger preferences from a file
*
* @param f File to write the preferences to
* @return 0 if everything went fine. An error code if something went wrong.
**/	
int loadDebuggerPreferences(FILE* f)
{
	unsigned int i, size, len;
	uint8 tmp;

	// Read the number of CPU bookmarks
	if (fread(&size, sizeof(unsigned int), 1, f) != 1) return 1;
	bookmarks_addr.resize(size);
	bookmarks_name.resize(size);
	// Read the data of those bookmarks
	char buffer[256];
	for (i = 0; i < (int)size; ++i)
	{
		if (fread(&bookmarks_addr[i], sizeof(unsigned int), 1, f) != 1) return 1;
		if (fread(&len, sizeof(unsigned int), 1, f) != 1) return 1;
		if (len >= 256) return 1;
		if (fread(&buffer, 1, len, f) != len) return 1;
		buffer[len] = 0;
		bookmarks_name[i] = buffer;
	}

	myNumWPs = 0;
	// Ugetab:
	// This took far too long to figure out...
	// Nullifying the data is better than using free(), because
	// a simple if(watchpoint[i].cond) can still evaluate to true.
	// This causes several tests to fail, one of which kills
	// conditional text loading when reusing a used condText.
	for (i=0;i<65;i++)
	{
		watchpoint[i].cond = 0;
		watchpoint[i].condText = 0;
		watchpoint[i].desc = 0;
	}

	// Read the breakpoints
	for (i=0;i<65;i++)
	{
		uint16 start, end;
		uint8 flags;
		unsigned int len;
		
		// Read the start address of the BP
		if (fread(&start, sizeof(start), 1, f) != 1) return 1;
		// Read the end address of the BP
		if (fread(&end, sizeof(end), 1, f) != 1) return 1;
		// Read the flags of the BP
		if (fread(&flags, sizeof(flags), 1, f) != 1) return 1;
		
		// Read the length of the BP condition
		if (fread(&len, sizeof(len), 1, f) != 1) return 1;
		
		// Delete eventual older conditions
		if (watchpoint[myNumWPs].condText)
			free(watchpoint[myNumWPs].condText);
				
		watchpoint[myNumWPs].condText = (char*)malloc(len + 1);
		watchpoint[myNumWPs].condText[len] = 0;
		if (len)
		{
			// Read the breakpoint condition
			if (fread(watchpoint[myNumWPs].condText, 1, len, f) != len) return 1;
			// TODO: Check return value
			checkCondition(watchpoint[myNumWPs].condText, myNumWPs);
		}
		
		// Read length of the BP description
		if (fread(&len, sizeof(len), 1, f) != 1) return 1;
		
		// Delete eventual older description
		if (watchpoint[myNumWPs].desc)
			free(watchpoint[myNumWPs].desc);
				
		watchpoint[myNumWPs].desc = (char*)malloc(len + 1);
		watchpoint[myNumWPs].desc[len] = 0;
		if (len)
		{
			// Read breakpoint description
			if (fread(watchpoint[myNumWPs].desc, 1, len, f) != len) return 1;
		}
		
		watchpoint[i].address = 0;
		watchpoint[i].endaddress = 0;
		watchpoint[i].flags = 0;

		// Activate breakpoint
		if (start || end || flags)
		{
			watchpoint[myNumWPs].address = start;
			watchpoint[myNumWPs].endaddress = end;
			watchpoint[myNumWPs].flags = flags;

			myNumWPs++;
		}
	}

	// Read "Break on Bad Opcode" flag
	if (fread(&tmp, 1, 1, f) != 1) return 1;
	FCEUI_Debugger().badopbreak = (tmp != 0);
	// Read "Break when exceed" data
	if (fread(&tmp, 1, 1, f) != 1) return 1;
	break_on_cycles = (tmp != 0);
	if (fread(&break_cycles_limit, sizeof(break_cycles_limit), 1, f) != 1) return 1;
	if (fread(&tmp, 1, 1, f) != 1) return 1;
	break_on_instructions = (tmp != 0);
	if (fread(&break_instructions_limit, sizeof(break_instructions_limit), 1, f) != 1) return 1;

	return 0;
}


/**
* Loads HexView preferences from a file
*
* @param f File to write the preferences to
* @return 0 if everything went fine. An error code if something went wrong.
**/	
int loadHexPreferences(FILE* f)
{
	int i;

	// Read number of bookmarks
	if (fread(&nextBookmark, sizeof(nextBookmark), 1, f) != 1) return 1;
	if (nextBookmark >= 64) return 1;

	for (i=0;i<nextBookmark;i++)
	{
		unsigned int len;
		
		// Read address
		if (fread(&hexBookmarks[i].address, sizeof(hexBookmarks[i].address), 1, f) != 1) return 1;
		// Read length of description
		if (fread(&len, sizeof(len), 1, f) != 1) return 1;
		// Read the bookmark description
		if (fread(hexBookmarks[i].description, 1, len, f) != len) return 1;
	}
	
	return 0;
}

/**
* Loads the debugging preferences from disk
*
* @param romname Name of the active ROM file
* @return 0 or an error code.
**/
int loadPreferences(const char* romname)
{
	if (debuggerSaveLoadDEBFiles == false) {
		return 0;
	}

	FILE* f;
	int result;
	int i;

	myNumWPs = 0;

	// Get the name of the preferences file
	char* filename = (char*)malloc(strlen(romname) + 5);
	strcpy(filename, romname);
	strcat(filename, ".deb");
	
	f = fopen(filename, "rb");
	free(filename);
	
	if (f)
	{
		result = loadDebuggerPreferences(f) || loadHexPreferences(f);
		if (result)
		{
			// there was error when loading the .deb, reset the data to default
			DeleteAllDebuggerBookmarks();
			myNumWPs = 0;
			break_on_instructions = break_on_cycles = FCEUI_Debugger().badopbreak = false;
			break_instructions_limit = break_cycles_limit = 0;
			nextBookmark = 0;
		}
		fclose(f);
	} else
	{
		result = 0;
	}

	// This prevents information from traveling between debugger interations.
	// It needs to be run pretty much regardless of whether there's a .deb file or not,
	// successful read or failure. Otherwise, it's basically leaving previous info around.
	for (i=myNumWPs;i<=64;i++)
	{
		watchpoint[i].address = 0;
		watchpoint[i].endaddress = 0;
		watchpoint[i].flags = 0;
	}

	// Attempt to load the preferences
	return result;
}
