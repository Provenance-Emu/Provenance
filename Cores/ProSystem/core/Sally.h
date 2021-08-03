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
// Sally.h
// ----------------------------------------------------------------------------
#ifndef SALLY_H
#define SALLY_H

#include "Memory.h"
#include "Pair.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern void sally_Reset( );
extern uint sally_ExecuteInstruction( );
extern uint sally_ExecuteRES( );
extern uint sally_ExecuteNMI( );
extern uint sally_ExecuteIRQ( );
extern byte sally_a;
extern byte sally_x;
extern byte sally_y;
extern byte sally_p;
extern byte sally_s;
extern pair sally_pc;

#endif