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
// TiaSound is Copyright(c) 1997 by Ron Fries                                
//                                                                           
// This library is free software; you can redistribute it and/or modify it   
// under the terms of version 2 of the GNU Library General Public License    
// as published by the Free Software Foundation.                             
//                                                                           
// This library is distributed in the hope that it will be useful, but       
// WITHOUT ANY WARRANTY; without even the implied warranty of                
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library 
// General Public License for more details.                                  
// To obtain a copy of the GNU Library General Public License, write to the  
// Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.   
//                                                                           
// Any permitted reproduction of these routines, in whole or in part, must   
// bear this legend.                                                         
// ----------------------------------------------------------------------------
// Tia.h
// ----------------------------------------------------------------------------
#ifndef TIA_H
#define TIA_H
#define TIA_BUFFER_SIZE 624

#include "Equates.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern void tia_Reset( );
extern void tia_SetRegister(word address, byte data);
extern void tia_Clear( );
extern void tia_Process(uint length);
extern byte tia_buffer[TIA_BUFFER_SIZE];
extern uint tia_size;

#endif