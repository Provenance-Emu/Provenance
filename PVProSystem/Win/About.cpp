// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// About.cpp
// ----------------------------------------------------------------------------
#include "About.h"

// ----------------------------------------------------------------------------
// Procedure
// ----------------------------------------------------------------------------
static BOOL CALLBACK about_Procedure(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
  if(message == WM_INITDIALOG) {
    HWND hStaticVersion = GetDlgItem(hWnd, IDC_STATIC_VERSION2);
    std::string versionText = "Version " + common_Format(CONSOLE_VERSION, "%1.1f");
    SetWindowText(hStaticVersion, versionText.c_str( ));
  }
  else if(message == WM_COMMAND) {
    if(LOWORD(wParam) == IDCANCEL || LOWORD(wParam) == IDC_BUTTON_ABOUT_OK) {
      EndDialog(hWnd, 0);
      return 1;
    }      
  }
  return 0;
}

// ----------------------------------------------------------------------------
// Show
// ----------------------------------------------------------------------------
void about_Show(HWND hWnd, HINSTANCE hInstance) {
  DialogBox(hInstance, MAKEINTRESOURCE(IDD_DIALOG_ABOUT), hWnd, (DLGPROC)about_Procedure);
}