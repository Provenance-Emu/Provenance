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
// Main.cpp
// ----------------------------------------------------------------------------
#include <Windows.h>
#include <String>
#include "Console.h"
#include "Common.h"
#include "Logger.h"
#include "Input.h"
#define NULL 0

// ----------------------------------------------------------------------------
// ParseDefaultPath
// ----------------------------------------------------------------------------
void main_ParseDefaultPath( ) {
  std::string commandLine = GetCommandLine( );
  if(commandLine[0] == '"') {
    common_defaultPath = common_Remove(commandLine.substr(0, commandLine.find('"', 1)), '"');
    common_defaultPath = common_defaultPath.substr(0, common_defaultPath.rfind("\\") + 1);
  }
  else {
    common_defaultPath = commandLine.substr(0, commandLine.find(' '));
    common_defaultPath = common_defaultPath.substr(0, common_defaultPath.rfind("\\") + 1);
  }
}

// ----------------------------------------------------------------------------
// WinMain
// ----------------------------------------------------------------------------
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR commandLine, int showCommand) {
  main_ParseDefaultPath( );  
  logger_Initialize(common_defaultPath + "ProSystem.log");
  logger_level = LOGGER_LEVEL_DEBUG;

  console_Initialize(hInstance, commandLine);

  console_Run( );
  
  logger_Release( );
  return 1;
}
