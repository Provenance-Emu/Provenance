#ifndef WIN_WINDOW_H
#define WIN_WINDOW_H

#include "common.h"
#include <string>

using namespace std;

// Type definitions

struct CreateMovieParameters
{
	std::string szFilename;				// on Dialog creation, this is the default filename to display.  On return, this is the filename that the user chose.
	int recordFrom;				// 0 = "Power-On", 1 = "Reset", 2 = "Now", 3+ = savestate file in szSavestateFilename
	std::string szSavestateFilename;
	std::wstring authorName;
};

extern char *recent_files[];
extern char *recent_lua[];
extern char *recent_movie[];
extern HWND pwindow;

HWND GetMainHWND();

void SetMainWindowText();
void HideFWindow(int h);
void SetMainWindowStuff();
int GetClientAbsRect(LPRECT lpRect);
void FixWXY(int pref, bool shift_held = false);
void ByebyeWindow();
void DoTimingConfigFix();
int CreateMainWindow();
void UpdateCheckedMenuItems();
void LoadNewGamey(HWND hParent, const char *initialdir);
int BrowseForFolder(HWND hParent, const char *htext, char *buf);
void SetMainWindowStuff();
void GetMouseData(uint32 (&md)[3]);
//void ChangeMenuItemText(int menuitem, string text);
void UpdateMenuHotkeys();

template<int BUFSIZE>
inline std::string GetDlgItemText(HWND hDlg, int nIDDlgItem) {
	char buf[BUFSIZE];
	GetDlgItemText(hDlg, nIDDlgItem, buf, BUFSIZE);
	return buf;
}

template<int BUFSIZE>
inline std::wstring GetDlgItemTextW(HWND hDlg, int nIDDlgItem) {
	wchar_t buf[BUFSIZE];
	GetDlgItemTextW(hDlg, nIDDlgItem, buf, BUFSIZE);
	return buf;
}

#endif
