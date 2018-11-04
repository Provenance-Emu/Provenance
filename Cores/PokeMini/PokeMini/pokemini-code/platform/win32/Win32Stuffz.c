/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <windows.h>

// Open file dialog
int OpenFileDialogEx(HWND parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx)
{
	OPENFILENAME ofn;
	char szFile[256];

	strcpy_s(szFile, 256, filein);
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = parentwindow;
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = exts;
	ofn.nFilterIndex = extidx + 1;
	ofn.lpstrFileTitle = (char *)title;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

	if (GetOpenFileName(&ofn)) {
		strcpy_s(fileout, 256, ofn.lpstrFile);
		return 1;
	}
	return 0;
}

// Save file dialog
int SaveFileDialogEx(HWND parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx)
{
	OPENFILENAME ofn;
	char szFile[256];

	strcpy_s(szFile, 256, filein);
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = parentwindow;
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = exts;
	ofn.nFilterIndex = extidx + 1;
	ofn.lpstrFileTitle = (char *)title;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST;

	if (GetSaveFileName(&ofn)) {
		strcpy_s(fileout, 256, ofn.lpstrFile);
		return 1;
	}
	return 0;
}

// For Visual C++ compability
#ifdef _MSC_VER
int strcasecmp(const char *s1, const char *s2)
{
	return _stricmp(s1, s2);
}
#endif

