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
// Region.h
// ----------------------------------------------------------------------------
#ifndef REGION_H
#define REGION_H
#define REGION_NTSC 0
#define REGION_PAL 1
#define REGION_AUTO 2

#include "Cartridge.h"
#include "ProSystem.h"
#include "Maria.h"
#include "Palette.h"
#include "Tia.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern void region_Reset( );
extern byte region_type;

#endif