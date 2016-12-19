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
// Help.cpp
// ----------------------------------------------------------------------------
#include "Help.h"

static std::string help_filename;
static HWND common_hWnd = NULL;

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
void help_Initialize(HWND hWnd) {
  help_filename = common_defaultPath + "ProSystem.chm";
  common_hWnd = hWnd;
}

// ----------------------------------------------------------------------------
// ShowContents
// ----------------------------------------------------------------------------
void help_ShowContents( ) {
  HtmlHelp(common_hWnd, help_filename.c_str( ), HH_DISPLAY_TOC, NULL);
}

// ----------------------------------------------------------------------------
// ShowIndex
// ----------------------------------------------------------------------------
void help_ShowIndex( ) {
  HtmlHelp(common_hWnd, help_filename.c_str( ), HH_DISPLAY_INDEX, NULL);
}

