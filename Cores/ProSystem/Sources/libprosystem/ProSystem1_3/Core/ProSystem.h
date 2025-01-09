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
// ProSystem.h
// ----------------------------------------------------------------------------
#ifndef PRO_SYSTEM_H
#define PRO_SYSTEM_H
#define NULL 0

#include <String>
#include <Stdio.h>
#include "Equates.h"
#include "Bios.h"
#include "Cartridge.h"
#include "Maria.h"
#include "Memory.h"
#include "Region.h"
#include "Riot.h"
#include "Sally.h"
#include "Archive.h"
#include "Tia.h"
#include "Pokey.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern void prosystem_Reset( );
extern void prosystem_ExecuteFrame(const byte* input);
extern bool prosystem_Save(std::string filename, bool compress);
extern bool prosystem_Load(std::string filename);
extern void prosystem_Pause(bool pause);
extern void prosystem_Close( );
extern bool prosystem_active;
extern bool prosystem_paused;
extern word prosystem_frequency;
extern byte prosystem_frame;
extern word prosystem_scanlines;
extern uint prosystem_cycles;

#endif