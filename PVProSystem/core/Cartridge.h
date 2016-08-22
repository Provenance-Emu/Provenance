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
// Cartridge.h
// ----------------------------------------------------------------------------
#ifndef CARTRIDGE_H
#define CARTRIDGE_H
#define CARTRIDGE_TYPE_NORMAL 0
#define CARTRIDGE_TYPE_SUPERCART 1
#define CARTRIDGE_TYPE_SUPERCART_LARGE 2
#define CARTRIDGE_TYPE_SUPERCART_RAM 3
#define CARTRIDGE_TYPE_SUPERCART_ROM 4
#define CARTRIDGE_TYPE_ABSOLUTE 5
#define CARTRIDGE_TYPE_ACTIVISION 6
#define CARTRIDGE_CONTROLLER_NONE 0
#define CARTRIDGE_CONTROLLER_JOYSTICK 1
#define CARTRIDGE_CONTROLLER_LIGHTGUN 2
#define CARTRIDGE_WSYNC_MASK 2
#define CARTRIDGE_CYCLE_STEALING_MASK 1

#include <stdio.h>
#include <string>
#include "Equates.h"
#include "Memory.h"
#include "Hash.h"
#include "Logger.h"
#include "Pokey.h"
#include "Archive.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern bool cartridge_Load(std::string filename);
extern void cartridge_Store( );
extern void cartridge_StoreBank(byte bank);
extern void cartridge_Write(word address, byte data);
extern bool cartridge_IsLoaded( );
extern void cartridge_Release( );
extern std::string cartridge_digest;
extern std::string cartridge_title;
extern std::string cartridge_description;
extern std::string cartridge_year;
extern std::string cartridge_maker;
extern std::string cartridge_filename;
extern byte cartridge_type;
extern byte cartridge_region;
extern bool cartridge_pokey;
extern byte cartridge_controller[2];
extern byte cartridge_bank;
extern uint cartridge_flags;

// The x offset for the lightgun crosshair (allows per cartridge adjustments)
extern int cartridge_crosshair_x;
// The y offset for the lightgun crosshair (allows per cartridge adjustments)
extern int cartridge_crosshair_y;
// The hblank prior to DMA
extern uint cartridge_hblank;
// Whether the cartridge supports dual analog
extern bool cartridge_dualanalog;

#endif