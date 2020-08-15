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
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include "memviewsp.h"
#include "common.h"

HexBookmark hexBookmarks[64];
int nextBookmark = 0;

/// Finds the bookmark for a given address
/// @param address The address to find.
/// @return The index of the bookmark at that address or -1 if there's no bookmark at that address.
int findBookmark(unsigned int address)
{
	int i;

	if (address > 0xFFFF)
	{
		MessageBox(0, "Error: Invalid address was specified as parameter to findBookmark", "Error", MB_OK | MB_ICONERROR);
		return -1;
	}
	
	for (i=0;i<nextBookmark;i++)
	{
		if (hexBookmarks[i].address == address)
			return i;
	}
	
	return -1;
}

char bookmarkDescription[51] = {0};

BOOL CenterWindow(HWND hwndDlg);

/// Callback function for the name bookmark dialog
BOOL CALLBACK nameBookmarkCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch (uMsg)
	{
		case WM_INITDIALOG:
			// Limit bookmark descriptions to 50 characters
			SendDlgItemMessage(hwndDlg,IDC_BOOKMARK_DESCRIPTION,EM_SETLIMITTEXT,50,0);
			
			// Put the current bookmark description into the edit field
			// and set focus to that edit field.
			SetDlgItemText(hwndDlg, IDC_BOOKMARK_DESCRIPTION, bookmarkDescription);
			SetFocus(GetDlgItem(hwndDlg, IDC_BOOKMARK_DESCRIPTION));
			break;
		case WM_CLOSE:
		case WM_QUIT:
			EndDialog(hwndDlg, 0);
			break;
		case WM_COMMAND:
			switch(HIWORD(wParam))
			{
				case BN_CLICKED:
					switch(LOWORD(wParam))
					{
						case IDOK:
						{
							// Update the bookmark description
							GetDlgItemText(hwndDlg, IDC_BOOKMARK_DESCRIPTION, bookmarkDescription, 50);
							EndDialog(hwndDlg, 1);
							break;
						}
					}
			}
			break;
	}
	
	return FALSE;
}

/// Attempts to add a new bookmark to the bookmark list.
/// @param hwnd HWND of the FCEU window
/// @param address Address of the new bookmark
/// @return Returns 0 if everything's OK and an error flag otherwise.
int addBookmark(HWND hwnd, unsigned int address)
{
	// Enforce a maximum of 64 bookmarks
	if (nextBookmark < 64)
	{
		sprintf(bookmarkDescription, "%04X", address);
	
		// Show the bookmark name dialog
		DialogBox(fceu_hInstance, "NAMEBOOKMARKDLG", hwnd, nameBookmarkCallB);
		
		// Update the bookmark description
		hexBookmarks[nextBookmark].address = address;
		strcpy(hexBookmarks[nextBookmark].description, bookmarkDescription);
		
		nextBookmark++;
		
		return 0;
	}
	else
	{
		return 1;
	}
}

/// Removes a bookmark from the bookmark list
/// @param index Index of the bookmark to remove
void removeBookmark(unsigned int index)
{
	// TODO: Range checking
	
	// At this point it's necessary to move the content of the bookmark list
	for (int i=index;i<nextBookmark - 1;i++)
	{
		hexBookmarks[i] = hexBookmarks[i+1];
	}
	
	--nextBookmark;
}

/// Adds or removes a bookmark from a given address
/// @param hwnd HWND of the emu window
/// @param address Address of the bookmark
int toggleBookmark(HWND hwnd, uint32 address)
{
	int val = findBookmark(address);
	
	// If there's no bookmark at the given address add one.
	if (val == -1)
	{
		return addBookmark(hwnd, address);
	}
	else // else remove the bookmark
	{
		removeBookmark(val);
		return 0;
	}
}

/// Updates the bookmark menu in the hex window
/// @param menu Handle of the bookmark menu
void updateBookmarkMenus(HMENU menu)
{
	int i;
	MENUITEMINFO mi;
	mi.cbSize = sizeof(MENUITEMINFO);
	mi.fMask = MIIM_TYPE | MIIM_ID | MIIM_DATA;
	mi.fType = MF_STRING;
	
	// Remove all bookmark menus
	for (i = 0;i<nextBookmark + 1;i++)
	{
		RemoveMenu(menu, ID_FIRST_BOOKMARK + i, MF_BYCOMMAND);
	}
	
	// Add the menus again
	for (i = 0;i<nextBookmark;i++)
	{
		// Get the text of the menu
		char buffer[0x100];
		sprintf(buffer, i < 10 ? "$%04X - %s\tCTRL-%d" : "$%04X - %s", hexBookmarks[i].address, hexBookmarks[i].description, i);
		
		mi.dwTypeData = buffer;
		mi.cch = strlen(buffer);
		mi.wID = ID_FIRST_BOOKMARK + i;
		
		InsertMenuItem(menu, 2 + i , TRUE, &mi);
	}
}

/// Returns the address to scroll to if a given bookmark was activated
/// @param bookmark Index of the bookmark
/// @return The address to scroll to or -1 if the bookmark index is invalid.
int handleBookmarkMenu(int bookmark)
{
	if (bookmark < nextBookmark)
	{
		return hexBookmarks[bookmark].address - (hexBookmarks[bookmark].address % 0x10);
	}
	
	return -1;
}

/// Removes all bookmarks
/// @param menu Handle of the bookmark menu
void removeAllBookmarks(HMENU menu)
{
	for (int i = 0;i<nextBookmark;i++)
	{
		RemoveMenu(menu, ID_FIRST_BOOKMARK + i, MF_BYCOMMAND);
	}
	
	nextBookmark = 0;
}
