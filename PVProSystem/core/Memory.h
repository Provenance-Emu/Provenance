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
// Memory.h
// ----------------------------------------------------------------------------
#ifndef MEMORY_H
#define MEMORY_H
#define MEMORY_SIZE 65536

#include "Equates.h"
#include "Bios.h"
#include "Cartridge.h"
#include "Tia.h"
#include "Riot.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern void memory_Reset( );
extern byte memory_Read(word address);
extern void memory_Write(word address, byte data);
extern void memory_WriteROM(word address, word size, const byte* data);
extern void memory_ClearROM(word address, word size);
extern byte memory_ram[MEMORY_SIZE];
extern byte memory_rom[MEMORY_SIZE];

#endif
