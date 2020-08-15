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

#include "common.h"
#include "utils/xstring.h"
#include "debuggersp.h"
#include "debugger.h"
#include "../../fceu.h"
#include "../../debug.h"
#include "../../conddebug.h"

#include <stdio.h>
#include <string.h>
#include <assert.h>

int GetNesFileAddress(int A);

inline int RomPageIndexForAddress(int addr) { return (addr-0x8000)>>(debuggerPageSize); }

//old
//Name* lastBankNames = 0;
//Name* loadedBankNames = 0;

//new
Name* pageNames[32] = {0}; //the maximum number of pages we could have is 32, based on 1KB debuggerPageSize

//old
//int lastBank = -1;
//int loadedBank = -1;

//new
int pageNumbersLoaded[32] = {
	-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
};

Name* ramBankNames = 0;
bool ramBankNamesLoaded = false;

extern char LoadedRomFName[2048];
char NLfilename[2048];
bool symbDebugEnabled = true;
bool symbRegNames = true;
int debuggerWasActive = 0;
char temp_chr[40] = {0};
char delimiterChar[2] = "#";

extern BOOL CALLBACK nameBookmarkCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
extern char bookmarkDescription[];

MemoryMappedRegister RegNames[] = {
	{"$2000", "PPU_CTRL"},
	{"$2001", "PPU_MASK"},
	{"$2002", "PPU_STATUS"},
	{"$2003", "PPU_OAM_ADDR"},
	{"$2004", "PPU_OAM_DATA"},
	{"$2005", "PPU_SCROLL"},
	{"$2006", "PPU_ADDRESS"},
	{"$2007", "PPU_DATA"},
	{"$4000", "SQ1_VOL"},
	{"$4001", "SQ1_SWEEP"},
	{"$4002", "SQ1_LO"},
	{"$4003", "SQ1_HI"},
	{"$4004", "SQ2_VOL"},
	{"$4005", "SQ2_SWEEP"},
	{"$4006", "SQ2_LO"},
	{"$4007", "SQ2_HI"},
	{"$4008", "TRI_LINEAR"},
//	{"$4009", "UNUSED"},
	{"$400A", "TRI_LO"},
	{"$400B", "TRI_HI"},
	{"$400C", "NOISE_VOL"},
//	{"$400D", "UNUSED"},
	{"$400E", "NOISE_LO"},
	{"$400F", "NOISE_HI"},
	{"$4010", "DMC_FREQ"},
	{"$4011", "DMC_RAW"},
	{"$4012", "DMC_START"},
	{"$4013", "DMC_LEN"},
	{"$4014", "OAM_DMA"},
	{"$4015", "APU_STATUS"},
	{"$4016", "JOY1"},
	{"$4017", "JOY2_FRAME"}
};

int RegNameCount = sizeof(RegNames)/sizeof(MemoryMappedRegister);

/**
* Tests whether a char is a valid hexadecimal character.
* 
* @param c The char to test
* @return True or false.
**/
int isHex(char c)
{
	return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

/**
* Parses a line from a NL file.
* @param line The line to parse
* @param n The name structure to write the information to
*
* @return 0 if everything went OK. Otherwise an error code is returned.
**/
int parseLine(char* line, Name* n)
{
	char* pos;
	int llen;

	// Check parameters
	
	if (!line)
	{
		MessageBox(0, "Invalid parameter \"line\" in function parseLine", "Error", MB_OK | MB_ICONERROR);
		return 1;
	}
	
	if (!n)
	{
		MessageBox(0, "Invalid parameter \"n\" in function parseLine", "Error", MB_OK | MB_ICONERROR);
		return 2;
	}
	
	// Allow empty lines
	if (*line == '\r' || *line == '\n')
	{
		return -1;
	}
	
	// Attempt to tokenize the given line
	
	pos = strstr(line, delimiterChar);

	if (!pos)
	{
		// Found an invalid line
		return 3;
	}
	
	// Check if the first tokenized part (the offset) is valid
	
	*pos = 0;
	
	llen = (int)strlen(line);
	
	if (llen == 5) // Offset size of normal lines of the form $XXXX
	{
		if (line[0] != '$'
			|| !isHex(line[1])
			|| !isHex(line[2])
			|| !isHex(line[3])
			|| !isHex(line[4])
		)
		{
			return 4;
		}
	}
	else if (llen >= 7) // Offset size of array definition lines of the form $XXXX/YY
	{
		int i;
		if (line[0] != '$'
			|| !isHex(line[1])
			|| !isHex(line[2])
			|| !isHex(line[3])
			|| !isHex(line[4])
			|| line[5] != '/'
		)
		{
			return 5;
		}
		
		for (i=6;line[i];i++)
		{
			if (!isHex(line[i]))
			{
				return 6;
			}
		}
	}
	else // Lines that have an invalid size
	{
		return 7;
	}
	
	
	// TODO: Validate if the offset is in the correct NL file.

	// After validating the offset it's OK to store it
	n->offset = (char*)malloc(strlen(line) + 1);
	strcpy(n->offset, line);
	line = pos + 1;
	
	// Attempt to tokenize the string again to find the name of the address

	pos = strstr(line, delimiterChar);

	if (!pos)
	{
		// Found an invalid line
		return 8;
	}

	*pos = 0;
	
	if (*line)
	{
		if (strlen(line) > NL_MAX_NAME_LEN)
			line[NL_MAX_NAME_LEN + 1] = 0;
		n->name = (char*)malloc(strlen(line) + 1);
		strcpy(n->name, line);
	}
	else
	{
		// Properly initialize zero-length names too
		n->name = 0;
	}
	
	// Now it's clear that the line was valid. The rest of the line is the comment
	// that belongs to that line. Once again a real string is required though.
	
	line = pos + 1;

	if (*line > 0x0D)
	{
		if (strlen(line) > NL_MAX_MULTILINE_COMMENT_LEN)
			line[NL_MAX_MULTILINE_COMMENT_LEN + 1] = 0;
		// remove all backslashes after \r\n
		char* crlf_pos = strstr(line, "\r\n\\");
		while (crlf_pos)
		{
			strcpy(crlf_pos + 2, crlf_pos + 3);
			crlf_pos = strstr(crlf_pos + 2, "\r\n\\");
		}

		n->comment = (char*)malloc(strlen(line) + 1);
		strcpy(n->comment, line);
	}
	else
	{
		// Properly initialize zero-length comments too
		n->comment = 0;
	}
	
	// Everything went fine.
	return 0;
}

/**
* Parses an array of lines read from a NL file.
* @param lines The lines to parse
* @param filename The name of the file the lines were read from.
* 
* @return A pointer to the first Name structure built from the parsed lines.
**/
Name* parse(char* lines, const char* filename)
{
	char* pos, *size;
	Name* prev = 0, *cur, *first = 0;

	// Check the parameters
	if (!lines)
	{
		MessageBox(0, "Invalid parameter \"lines\" in function parse", "Error", MB_OK | MB_ICONERROR);
		return 0;
	}
	
	if (!filename)
	{
		MessageBox(0, "Invalid parameter \"filename\" in function parse", "Error", MB_OK | MB_ICONERROR);
		return 0;
	}
	
	// Begin the actual parsing
	
	do
	{
		int fail;

		// Allocate a name structure to hold the parsed data from the next line
		
		cur = (Name*)malloc(sizeof(Name));
		cur->offsetNumeric = 0;
		cur->offset = 0;
		cur->next = 0;
		cur->name = 0;
		cur->comment = 0;
		
		pos = lines;

		// This first loop attempts to read potential multi-line comments and add them
		// into a single comment.
		for(;;)
		{
			// Get the end of the next line
			pos = strstr(pos, "\n");

			// If there's no end of line or if the next line does not begin with a \ character
			// we can stop.
			if (!pos || pos[1] != '\\') break;
			
			// At this point we have the following situation. pos[0] and pos[1] can be overwritten
			/*
				pos	-1	0	1	2
					 ?	\n	\   ?
			*/
			
			// \r\n is needed in text boxes
			if (pos[-1] != '\r')
			{
				pos[0] = '\r';
				pos[1] = '\n';
			}
			pos += 2;
		}
		
		if (!pos)
		{
			// All lines were parsed
			break;
		}

		if (pos[-1] == '\r')
			pos[-1] = 0;
		else
			*pos = 0;

		// Attempt to parse the current line
		fail = parseLine(lines, cur);
		
		if (fail == -1)
		{
			continue;
		} else if (fail)
		{
			// Show an error to allow the user to correct the defect line
			const char* fmtString = "Error (Code: %d): Invalid line \"%s\" in NL file \"%s\"\n";
			char* msg = (char*)malloc(strlen(fmtString) + 8 + strlen(lines) + strlen(filename) + 1);
			sprintf(msg, fmtString, fail, lines, filename);
			MessageBox(0, msg, "Error", MB_OK | MB_ICONERROR);
			free(msg);
			lines = pos + 1;
			//MessageBox(0, lines, "Error", MB_OK | MB_ICONERROR);
			continue;
		}
		
		lines = pos + 1;
		
		// Check if the line is an array definition line
		
		size = strstr(cur->offset, "/");
			
		if (size) // Array definition line
		{
			int arrlen, offset;
			
			*size = 0;
			
			// Attempt to read the length of the array and the array offset
			if (sscanf(size + 1, "%x", &arrlen) > 0 && sscanf(cur->offset + 1, "%x", &offset) > 0)
			{
				Name* nn = 0;
				int i;
				
				// Create a node for each element of the array
				for (i=0;i<=arrlen;i++)
				{
					char numbuff[10] = {0};

					nn = (Name*)malloc(sizeof(Name));
					nn->next = 0;
					
					// The comment is the same for each array element
					nn->comment = strdup(cur->comment);
					
					// The offset of the node
					nn->offset = (char*)malloc(6);
					sprintf(nn->offset, "$%04X", offset + i);
					nn->offsetNumeric = offset + i;
					
					// The name of an array address is of the form NAME[INDEX]
					sprintf(numbuff, "[%X]", i);
					
					nn->name = (char*)malloc(strlen(cur->name) + strlen(numbuff) + 1);
					strcpy(nn->name, cur->name);
					strcat(nn->name, numbuff);
					
					// Add the new node to the list of address nodes
					if (prev)
					{
						prev->next = nn;
						prev = prev->next;
					} else
					{
						first = prev = nn;
					}
				}
				
				// Free the allocated node
				free(cur->name);
				free(cur->comment);
				free(cur->offset);
				free(cur);
				
				cur = nn;
			}
			else
			{
				// I don't think it's possible to get here as the validity of
				// offset and array size has already been validated in parseLine
				continue;
			}
		} else
		{
			sscanf(cur->offset, "%*[$]%4X", &(cur->offsetNumeric));
			// Add the node to the list of address nodes
			if (prev)
			{
				prev->next = cur;
				prev = prev->next;
			}
			else
			{
				first = prev = cur;
			}
		}
	} while (pos);

	// Return the first node in the list of address nodes
	return first;
}

/**
* Load and parse an entire NL file
* @param filename Name of the file to parse
*
* @return A pointer to the first Name structure built from the file data.
**/
Name* parseNameFile(const char* filename)
{
	char* buffer;
	Name* n = 0;

	// Attempt to read the file
	FILE* f = fopen(filename, "rb");

	if (f)
	{
//		__asm (".byte 0xcc");
		// Get the file size
		int lSize;
		fseek (f , 0 , SEEK_END);
		lSize = ftell(f) + 1;
		
		// Allocate sufficient buffer space
		rewind (f);
		
		buffer = (char*)malloc(lSize);

		if (buffer)
		{
			// Read the file and parse it
			memset(buffer, 0, lSize);
			fread(buffer, 1, lSize - 1, f);
			n = parse(buffer, filename);

			fclose(f);
			
			free(buffer);
		}
	}

	return n;
}

/**
* Frees an entire list of Name nodes starting with the given node.
* 
* @param n The node to start with (0 is a valid value)
**/
void freeList(Name* n)
{
	Name* next;
	
	while (n)
	{
		if (n->offset) free(n->offset);
		if (n->name) free(n->name);
		if (n->comment) free(n->comment);
		
		next = n->next;
		free(n);
		n = next;
	}
}

/**
* Replaces all offsets in a string with the names that were given to those offsets
* The caller needs to make sure that str is large enough.
* 
* @param list NL list of address definitions
* @param str The string where replacing takes place.
* @param addressesLog Vector for collecting addresses that were replaced by names
**/
void replaceNames(Name* list, char* str, std::vector<uint16>* addressesLog)
{
	static char buff[1001];
	char* pos;
	char* src;

	while (list)
	{
		if (list->name)
		{
			// find and replace substrings
			*buff = 0;
			src = str;

			while (pos = strstr(src, list->offset))
			{
				*pos = 0;
				strcat(buff, src);
				strcat(buff, list->name);
				src = pos + 5;	// 5 = strlen(beg->offset), because all offsets are in "$XXXX" format
				if (addressesLog)
					addressesLog->push_back(list->offsetNumeric);
			}
			// if any offsets were changed, replace str by buff
			if (*buff)
			{
				strcat(buff, src);
				// replace whole str
				strcpy(str, buff);
			}
		}
		list = list->next;
	}

	for (int i = 0; i < RegNameCount; i++) {
		if (!symbRegNames) break;
		// copypaste, because Name* is too complex to abstract
		*buff = 0;
		src = str;

		while (pos = strstr(src, RegNames[i].offset)) {
			*pos = 0;
			strcat(buff, src);
			strcat(buff, RegNames[i].name);
			src = pos + 5;
		}
		if (*buff) {
			strcat(buff, src);
			strcpy(str, buff);
		}
	}
}

/**
* Searches an address node in a list of address nodes. The found node
* has the same offset as the passed parameter offs.
*
* @param node The address node list
* @offs The offset to search
* @return The node that has the given offset or 0.
**/
Name* findNode(Name* node, const char* offset)
{
	while (node)
	{
		if (!strcmp(node->offset, offset))
			return node;
		
		node = node->next;
	}
	return 0;
}
// same, but with offsetNumeric
Name* findNode(Name* node, uint16 offsetNumeric)
{
	while (node)
	{
		if (node->offsetNumeric == offsetNumeric)
			return node;
		
		node = node->next;
	}
	return 0;
}

char* generateNLFilenameForAddress(uint16 address)
{
	if (address < 0x8000)
	{
		// The NL file for the RAM addresses has the name nesrom.nes.ram.nl
		strcpy(NLfilename, mass_replace(LoadedRomFName, "|", ".").c_str());
		strcat(NLfilename, ".ram.nl");
	} else
	{
		int bank = getBank(address);
		#ifdef DW3_NL_0F_1F_HACK
		if(bank == 0x0F)
			bank = 0x1F;
		#endif
		sprintf(NLfilename, "%s.%X.nl", mass_replace(LoadedRomFName, "|", ".").c_str(), bank);
	}
	return NLfilename;
}
Name* getNamesPointerForAddress(uint16 address)
{
	if(address >= 0x8000)
	{
		return pageNames[RomPageIndexForAddress(address)];
	}
	else
	{
		return ramBankNames;
	}
}
void setNamesPointerForAddress(uint16 address, Name* newNode)
{
	if (address >= 0x8000)
	{
		pageNames[RomPageIndexForAddress(address)] = newNode;
	}
	else
	{
		ramBankNames = newNode;
	}
}

/**
* Loads the necessary NL files
**/
// TODO: instead of loading from disk every time the "loadedBankNames" changes, it's better to cache loaded linkedlists in memory
void loadNameFiles()
{
	int cb;

	if (!ramBankNamesLoaded)
	{
		ramBankNamesLoaded = true;
		// load RAM names
		if (ramBankNames)
			free(ramBankNames);
		
		// Load the address descriptions for the RAM addresses
		ramBankNames = parseNameFile(generateNLFilenameForAddress(0x0000));
	}

	int nPages = 1<<(15-debuggerPageSize);

	for(int i=0;i<nPages;i++)
	{
		int pageIndexAddress = 0x8000 + (1<<debuggerPageSize)*i;

		// Find out which bank is loaded at the page index
		cb = getBank(pageIndexAddress);
		if (cb == -1) // No bank was loaded at that offset
		{
			free(pageNames[i]);
			pageNames[i] = 0;
		}
		else if (cb != pageNumbersLoaded[i])
		{
			// If the bank changed since loading the NL files the last time it's necessary
			// to load the address descriptions of the new bank.
			pageNumbersLoaded[i] = cb;

			if (pageNames[i])
				freeList(pageNames[i]);

			// Load new address definitions
			pageNames[i] = parseNameFile(generateNLFilenameForAddress(pageIndexAddress));
		}
	} //loop across pages
}

// bookmarks
std::vector<unsigned int> bookmarks_addr;
std::vector<std::string> bookmarks_name;

/**
* Returns the bookmark address of a CPU bookmark identified by its index.
* The caller must make sure that the index is valid.
*
* @param hwnd HWND of the debugger window
* @param index Index of the bookmark
**/
unsigned int getBookmarkAddress(unsigned int index)
{
	if (index < bookmarks_addr.size())
		return bookmarks_addr[index];
	else
		return 0;
}

/**
* Adds a debugger bookmark to the list on the debugger window.
*
* @param hwnd HWMD of the debugger window
* @param buffer Text of the debugger bookmark
**/
void AddDebuggerBookmark2(HWND hwnd, unsigned int addr)
{
	int index = bookmarks_addr.size();
	bookmarks_addr.push_back(addr);
	// try to find Symbolic name for this address
	Name* node = findNode(getNamesPointerForAddress(addr), addr);
	if (node && node->name)
		bookmarks_name.push_back(node->name);
	else
		bookmarks_name.push_back("");

	// add new item to ListBox
	char buffer[256];
	sprintf(buffer, "%04X %s", bookmarks_addr[index], bookmarks_name[index].c_str());
	SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_ADDSTRING, 0, (LPARAM)buffer);
	// select this item
	SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_SETCURSEL, index, 0);
}

/**
* Takes the offset from the debugger bookmark edit field and adds a debugger
* bookmark with that offset to the bookmark list if the offset is valid.
*
* @param hwnd HWMD of the debugger window
**/
void AddDebuggerBookmark(HWND hwnd)
{
	int n;
	char buffer[5] = {0};
	
	GetDlgItemText(hwnd, IDC_DEBUGGER_BOOKMARK, buffer, 5);
	n = offsetStringToInt(BT_C, buffer);
	// Make sure the offset is valid
	if (n == -1 || n > 0xFFFF)
	{
		MessageBox(hwnd, "Invalid offset", "Error", MB_OK | MB_ICONERROR);
		return;
	}
	AddDebuggerBookmark2(hwnd, n);
}

/**
* Removes a debugger bookmark
* 
* @param hwnd HWND of the debugger window
**/
void DeleteDebuggerBookmark(HWND hwnd)
{
	// Get the selected bookmark
	unsigned int selectedItem = SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_GETCURSEL, 0, 0);
	
	if (selectedItem == LB_ERR)
	{
		MessageBox(hwnd, "Please select a bookmark from the list", "Error", MB_OK | MB_ICONERROR);
		return;
	} else
	{
		// Erase the selected bookmark
		bookmarks_addr.erase(bookmarks_addr.begin() + selectedItem);
		bookmarks_name.erase(bookmarks_name.begin() + selectedItem);
		SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_DELETESTRING, selectedItem, 0);
		// Select next item
		if (selectedItem >= (bookmarks_addr.size() - 1))
			// select last item
			SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_SETCURSEL, bookmarks_addr.size() - 1, 0);
		else
			SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_SETCURSEL, selectedItem, 0);

	}
}

void NameDebuggerBookmark(HWND hwnd)
{
	// Get the selected bookmark
	int selectedItem = SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_GETCURSEL, 0, 0);
	if (selectedItem == LB_ERR || selectedItem >= (int)bookmarks_name.size())
	{
		MessageBox(hwnd, "Please select a bookmark from the list", "Error", MB_OK | MB_ICONERROR);
		return;
	} else
	{
		if (bookmarks_name[selectedItem].size())
		{
			strcpy(bookmarkDescription, bookmarks_name[selectedItem].c_str());
		} else
		{
			bookmarkDescription[0] = 0;
			// try to find the same address in bookmarks
			for (int i = bookmarks_addr.size() - 1; i>= 0; i--)
			{
				if (i != selectedItem && bookmarks_addr[i] == bookmarks_addr[selectedItem] && bookmarks_name[i].size())
				{
					strcpy(bookmarkDescription, bookmarks_name[i].c_str());
					break;
				}
			}
		}
		// Show the bookmark name dialog
		if (DialogBox(fceu_hInstance, "NAMEBOOKMARKDLG", hwnd, nameBookmarkCallB))
		{
			// Rename the selected bookmark
			bookmarks_name[selectedItem] = bookmarkDescription;
			SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_DELETESTRING, selectedItem, 0);
			char buffer[256];
			sprintf(buffer, "%04X %s", bookmarks_addr[selectedItem], bookmarks_name[selectedItem].c_str());
			SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_INSERTSTRING, selectedItem, (LPARAM)buffer);
			// Reselect the item (selection disappeared when it was deleted)
			SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_SETCURSEL, selectedItem, 0);
		}
	}
}

void DeleteAllDebuggerBookmarks()
{
	bookmarks_addr.resize(0);
	bookmarks_name.resize(0);
}

void FillDebuggerBookmarkListbox(HWND hwnd)
{		
	SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_RESETCONTENT, 0, 0);
	char buffer[256];
	for (unsigned int i = 0; i < bookmarks_addr.size(); ++i)
	{
		sprintf(buffer, "%04X %s", bookmarks_addr[i], bookmarks_name[i].c_str());
		SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_ADDSTRING, 0, (LPARAM)buffer);
	}
}

/**
* Shows the code at the bookmark address in the disassembly window
*
* @param hwnd HWND of the debugger window
**/
void GoToDebuggerBookmark(HWND hwnd)
{
	int selectedItem = SendDlgItemMessage(hwnd, LIST_DEBUGGER_BOOKMARKS, LB_GETCURSEL, 0, 0);
	// If no bookmark is selected just return
	if (selectedItem == LB_ERR) return;
	unsigned int n = getBookmarkAddress(selectedItem);
	Disassemble(hwnd, IDC_DEBUGGER_DISASSEMBLY, IDC_DEBUGGER_DISASSEMBLY_VSCR, n);
}

BOOL CALLBACK SymbolicNamingCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_INITDIALOG:
		{
			CenterWindow(hwndDlg);
			unsigned int newAddress = lParam;
			// filename
			generateNLFilenameForAddress(newAddress);
			SetDlgItemText(hwndDlg, IDC_SYMBOLIC_FILENAME, NLfilename);
			// offset
			sprintf(temp_chr, "$%04X", newAddress);
			SetDlgItemText(hwndDlg, IDC_SYMBOLIC_ADDRESS, temp_chr);
			Name* node = findNode(getNamesPointerForAddress(newAddress), newAddress);
			if (node)
			{
				if (node->name && node->name[0])
					SetDlgItemText(hwndDlg, IDC_SYMBOLIC_NAME, node->name);
				if (node->comment && node->comment[0])
					SetDlgItemText(hwndDlg, IDC_SYMBOLIC_COMMENT, node->comment);
			}
			// set focus to IDC_SYMBOLIC_NAME
			SendMessage(hwndDlg, WM_NEXTDLGCTL, (WPARAM)GetDlgItem(hwndDlg, IDC_SYMBOLIC_NAME), true);
			//always set the limits
			SendDlgItemMessage(hwndDlg, IDC_SYMBOLIC_NAME, EM_SETLIMITTEXT, NL_MAX_NAME_LEN, 0);
			SendDlgItemMessage(hwndDlg, IDC_SYMBOLIC_COMMENT, EM_SETLIMITTEXT, NL_MAX_MULTILINE_COMMENT_LEN, 0);
			break;
		}
		case WM_CLOSE:
		case WM_QUIT:
			break;
		case WM_COMMAND:
		{
			switch(HIWORD(wParam))
			{
				case BN_CLICKED:
				{
					switch(LOWORD(wParam))
					{
						case IDOK:
						{
							unsigned int newAddress = 0;
							char newOffset[6] = {0};
							GetDlgItemText(hwndDlg, IDC_SYMBOLIC_ADDRESS, newOffset, 6);
							if (sscanf(newOffset, "%*[$]%4X", &newAddress) != EOF)
							{
								char newName[NL_MAX_NAME_LEN + 1] = {0};
								GetDlgItemText(hwndDlg, IDC_SYMBOLIC_NAME, newName, NL_MAX_NAME_LEN + 1);
								char newComment[NL_MAX_MULTILINE_COMMENT_LEN + 1] = {0};
								GetDlgItemText(hwndDlg, IDC_SYMBOLIC_COMMENT, newComment, NL_MAX_MULTILINE_COMMENT_LEN + 1);
								
								AddNewSymbolicName(newAddress, newOffset, newName, newComment);
								WriteNameFileToDisk(generateNLFilenameForAddress(newAddress), getNamesPointerForAddress(newAddress));
							}
							EndDialog(hwndDlg, 1);
							break;
						}
						case IDCANCEL:
						{
							EndDialog(hwndDlg, 0);
							break;
						}
					}
					break;
				}
			}
        	break;
		}
	}
	return FALSE;
}

// returns true if user pressed OK, false if Cancel
bool DoSymbolicDebugNaming(int offset, HWND parentHWND)
{
	if (!FCEUI_EmulationPaused())
		FCEUI_ToggleEmulationPause();
	loadNameFiles();
	if (DialogBoxParam(fceu_hInstance, MAKEINTRESOURCE(IDD_SYMBOLIC_DEBUG_NAMING), parentHWND, SymbolicNamingCallB, offset))
		return true;
	return false;
}

void AddNewSymbolicName(uint16 newAddress, char* newOffset, char* newName, char* newComment)
{
	Name* initialNode = getNamesPointerForAddress(newAddress);
	Name* node = initialNode;
	
	// remove all delimiterChars from name and comment
	char* pos = newName;
	while (pos < newName + strlen(newName))
	{
		pos = strstr(pos, delimiterChar);
		if (pos)
			strcpy(pos, pos + 1);
		else
			break;
	}
	pos = newComment;
	while (pos < newComment + strlen(newComment))
	{
		pos = strstr(pos, delimiterChar);
		if (pos)
			strcpy(pos, pos + 1);
		else
			break;
	}

	if (*newName)
	{
		if (!initialNode)
		{
			// no previous data, create new list
			node = (Name*)malloc(sizeof(Name));
			node->offset = (char*)malloc(strlen(newOffset) + 1);
			strcpy(node->offset, newOffset);
			node->offsetNumeric = newAddress;
			node->name = (char*)malloc(strlen(newName) + 1);
			strcpy(node->name, newName);
			if (strlen(newComment))
			{
				node->comment = (char*)malloc(strlen(newComment) + 1);
				strcpy(node->comment, newComment);
			} else
			{
				node->comment = 0;
			}
			node->next = 0;
			setNamesPointerForAddress(newAddress, node);
		} else
		{
			// search the list
			while (node)
			{
				if (node->offsetNumeric == newAddress)
				{
					// found matching address - replace its name and comment
					if (node->name)
						free(node->name);
					node->name = (char*)malloc(strlen(newName) + 1);
					strcpy(node->name, newName);
					if (node->comment)
					{
						free(node->comment);
						node->comment = 0;
					}
					if (strlen(newComment))
					{
						node->comment = (char*)malloc(strlen(newComment) + 1);
						strcpy(node->comment, newComment);
					}
					break;
				}
				if (node->next)
				{
					node = node->next;
				} else
				{
					// this is the last node in the list - so just append the address
					Name* newNode = (Name*)malloc(sizeof(Name));
					node->next = newNode;
					newNode->offset = (char*)malloc(strlen(newOffset) + 1);
					strcpy(newNode->offset, newOffset);
					newNode->offsetNumeric = newAddress;
					newNode->name = (char*)malloc(strlen(newName) + 1);
					strcpy(newNode->name, newName);
					if (strlen(newComment))
					{
						newNode->comment = (char*)malloc(strlen(newComment) + 1);
						strcpy(newNode->comment, newComment);
					} else
					{
						newNode->comment = 0;
					}
					newNode->next = 0;
					break;
				}
			}
		}
	} else
	{
		// name field is empty - remove the address from the list
		Name* previousNode = 0;
		while (node)
		{
			if (node->offsetNumeric == newAddress)
			{
				// found matching address - delete it
				if (node->offset)
					free(node->offset);
				if (node->name)
					free(node->name);
				if (node->comment)
					free(node->comment);
				if (previousNode)
					previousNode->next = node->next;
				if (node == initialNode)
					setNamesPointerForAddress(newAddress, node->next);
				free(node);
				break;
			}
			previousNode = node;
			node = node->next;
		}
	}
}

void WriteNameFileToDisk(const char* filename, Name* node)
{
	FILE* f = fopen(filename, "wb");
	char tempComment[NL_MAX_MULTILINE_COMMENT_LEN + 10];
	if (f)
	{
		char tempString[10 + 1 + NL_MAX_NAME_LEN + 1 + NL_MAX_MULTILINE_COMMENT_LEN + 1];
		while (node)
		{
			strcpy(tempString, node->offset);
			strcat(tempString, delimiterChar);
			if (node->name)
				strcat(tempString, node->name);
			strcat(tempString, delimiterChar);
			if (node->comment)
			{
				// dump multiline comment
				strcpy(tempComment, node->comment);
				char* remainder_pos = tempComment;
				char* crlf_pos = strstr(tempComment, "\r\n");
				while (crlf_pos)
				{
					*crlf_pos = 0;
					strcat(tempString, remainder_pos);
					strcat(tempString, "\r\n\\");
					crlf_pos = remainder_pos = crlf_pos + 2;
					crlf_pos = strstr(crlf_pos, "\r\n");
				}
				strcat(tempString, remainder_pos);
				strcat(tempString, "\r\n");
			} else
			{
				strcat(tempString, "\r\n");
			}
			// write to the file
			fwrite(tempString, 1, strlen(tempString), f);
			node = node->next;
		}
		fclose(f);
	}
}


