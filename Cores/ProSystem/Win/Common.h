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
// Common.h
// ----------------------------------------------------------------------------
#ifndef COMMON_H
#define COMMON_H

#include <Windows.h>
#include <String>

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern std::string common_Format(double value);
extern std::string common_Format(double value, std::string specification);
extern std::string common_Format(uint value);
extern std::string common_Format(word value);
extern std::string common_Format(byte value);
extern std::string common_Format(bool value);
extern std::string common_Format(HRESULT result);
extern std::string common_Trim(std::string target);
extern std::string common_Remove(std::string target, char value);
extern std::string common_Replace(std::string target, char value1, char value2);
extern std::string common_GetErrorMessage( );
extern std::string common_GetErrorMessage(DWORD error);
extern std::string common_GetExtension(std::string filename);
extern uint common_ParseUint(std::string text);
extern word common_ParseWord(std::string text);
extern byte common_ParseByte(std::string text);
extern bool common_ParseBool(std::string text);
extern std::string common_defaultPath;

#endif
