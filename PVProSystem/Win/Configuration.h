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
// Configuration.h
// ----------------------------------------------------------------------------
#ifndef CONFIGURATION_H
#define CONFIGURATION_H

#include <Windows.h>
#include <String>
#include "Console.h"


typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern std::string configuration_CommandLine(std::string commandLine);
extern std::string configuration_Load(std::string filename, std::string commandLine);
extern void configuration_Save(std::string filename);
extern bool configuration_enabled;
extern uint samplerate;

#endif