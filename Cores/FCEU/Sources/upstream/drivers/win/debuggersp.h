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
 
#include <windows.h>

#define NL_MAX_NAME_LEN 30
#define NL_MAX_MULTILINE_COMMENT_LEN 1000

//mbg merge 7/17/06 made struct sane c++
struct Name 
{
	Name* next;
	uint16 offsetNumeric;
	char* offset;
	char* name;
	char* comment;
};

struct MemoryMappedRegister
{
	char* offset;
	char* name;
};

extern bool symbDebugEnabled;
extern bool symbRegNames;
extern std::vector<unsigned int> bookmarks_addr;
extern std::vector<std::string> bookmarks_name;
extern int debuggerWasActive;

int checkCondition(const char* buffer, int num);

Name* findNode(Name* node, const char* offset);
Name* findNode(Name* node, uint16 offsetNumeric);

char* generateNLFilenameForAddress(uint16 address);
Name* getNamesPointerForAddress(uint16 address);
void setNamesPointerForAddress(uint16 address, Name* newNode);
void loadNameFiles();
void replaceNames(Name* list, char* str, std::vector<uint16>* addressesLog = 0);
void AddDebuggerBookmark(HWND hwnd);
void AddDebuggerBookmark2(HWND hwnd, unsigned int addr);
void DeleteDebuggerBookmark(HWND hwnd);
void NameDebuggerBookmark(HWND hwnd);
void DeleteAllDebuggerBookmarks();
void FillDebuggerBookmarkListbox(HWND hwnd);

void GoToDebuggerBookmark(HWND hwnd);
int isHex(char c);

bool DoSymbolicDebugNaming(int offset, HWND parentHWND);
void AddNewSymbolicName(uint16 newAddress, char* newOffset, char* newName, char* newComment);
void WriteNameFileToDisk(const char* filename, Name* node);
