#include "common.h"

#include <commctrl.h>
#include <shlobj.h>     // For directories configuration dialog.

/**
* Centers a window relative to its parent window.
*
* @param hwndDlg Handle of the window to center.
**/
void CenterWindow(HWND hwndDlg)
{
	//TODO: This function should probably moved into the generic Win32 window file
	//move the window relative to its parent
	HWND hwndParent = GetParent(hwndDlg);
	RECT rect;
	RECT rectP;

	GetWindowRect(hwndDlg, &rect);
	GetWindowRect(hwndParent, &rectP);

	int width  = rect.right  - rect.left;
	int height = rect.bottom - rect.top;

	int x = ((rectP.right-rectP.left) -  width) / 2 + rectP.left;
	int y = ((rectP.bottom-rectP.top) - height) / 2 + rectP.top;

	int screenwidth  = GetSystemMetrics(SM_CXSCREEN);
	int screenheight = GetSystemMetrics(SM_CYSCREEN);

	//make sure that the dialog box never moves outside of the screen
	if(x < 0) x = 0;
	if(y < 0) y = 0;
	if(x + width  > screenwidth)  x = screenwidth  - width;
	if(y + height > screenheight) y = screenheight - height;

	MoveWindow(hwndDlg, x, y, width, height, FALSE);
}

/**
* Centers a window on the screen.
*
* @param hwnd The window handle.
**/
void CenterWindowOnScreen(HWND hwnd)
{
	RECT rect;

    GetWindowRect(hwnd, &rect);

    unsigned int screenwidth  = GetSystemMetrics(SM_CXSCREEN);
    unsigned int screenheight = GetSystemMetrics(SM_CYSCREEN);

    unsigned int width  = rect.right  - rect.left;
    unsigned height = rect.bottom - rect.top;

    unsigned x = (screenwidth -  width) / 2;
    unsigned y = (screenheight - height) / 2;

    MoveWindow(hwnd, x, y, width, height, FALSE);
}

/**
* Changes the state of the mouse cursor.
* 
* @param set_visible Determines the visibility of the cursor ( 1 or 0 )
**/
void ShowCursorAbs(int set_visible)
{
	static int stat = 0;

	if(set_visible)
	{
		if(stat == -1)
		{
			stat++;
			ShowCursor(1);
		}
	}
	else
	{
		if(stat == 0)
		{
			stat--;
			ShowCursor(0);
		}
	}
}

/**
* Displays a folder selection dialog.
* 
* @param hParent Handle of the parent window.
* @param htext Text
* @param buf Storage buffer for the name of the selected path.
*
* @return 0 or 1 to indicate failure or success.
**/
int BrowseForFolder(HWND hParent, const char *htext, char *buf)
{
	BROWSEINFO bi;
	LPCITEMIDLIST pidl;

	buf[0] = 0;

	memset(&bi, 0, sizeof(bi));

	bi.hwndOwner = hParent;
	bi.lpszTitle = htext;
	bi.ulFlags = BIF_RETURNONLYFSDIRS; 

	if(FAILED(CoInitialize(0)))
	{
		return 0;
	}

	if(!(pidl = SHBrowseForFolder(&bi)))
	{
		CoUninitialize();
		return 0;
	}

	if(!SHGetPathFromIDList(pidl, buf))
	{
		CoTaskMemFree((PVOID)pidl);
		CoUninitialize();

		return 0;
	}

	/* This probably isn't the best way to free the memory... */
	CoTaskMemFree((PVOID)pidl);
	CoUninitialize();

	return 1;
}

