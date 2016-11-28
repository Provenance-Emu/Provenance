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
// Tia.cpp
// ----------------------------------------------------------------------------
#include "Tia.h"
#define TIA_POLY4_SIZE 15
#define TIA_POLY5_SIZE 31
#define TIA_POLY9_SIZE 511

byte tia_buffer[TIA_BUFFER_SIZE] = {0};
uint tia_size = 524;

static const byte TIA_POLY4[ ] = {1,1,0,1,1,1,0,0,0,0,1,0,1,0,0};
static const byte TIA_POLY5[ ] = {0,0,1,0,1,1,0,0,1,1,1,1,1,0,0,0,1,1,0,1,1,1,0,1,0,1,0,0,0,0,1};
static const byte TIA_POLY9[ ] = {0,0,1,0,1,0,0,0,1,0,0,0,0,0,0,0,1,0,1,1,1,0,0,1,0,1,0,0,1,1,1,1,1,0,0,1,1,0,1,1,0,1,0,1,1,1,0,1,1,0,0,1,0,0,1,1,1,1,0,1,0,0,0,0,1,1,0,1,1,0,0,0,1,0,0,0,1,1,1,1,0,1,0,1,1,0,1,0,1,0,0,0,0,1,1,0,1,0,1,0,0,0,1,0,1,0,0,0,1,1,1,0,0,1,1,0,1,1,0,0,1,1,1,1,1,0,0,1,1,0,0,0,1,1,0,1,0,0,0,1,1,0,0,1,1,1,1,0,0,1,0,0,0,1,1,1,0,0,1,1,0,1,0,1,1,0,1,1,0,1,0,0,1,0,0,1,1,1,1,1,1,0,1,1,1,1,0,1,1,0,0,0,0,1,1,1,1,1,0,0,0,1,0,0,0,0,1,0,0,0,1,0,1,0,1,1,0,0,0,0,1,0,1,1,1,1,0,1,0,0,0,1,1,0,0,0,1,1,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,1,0,1,0,0,1,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,0,0,1,0,0,1,0,1,1,0,0,0,0,1,0,0,0,1,0,0,0,1,0,1,1,1,1,0,0,0,1,1,1,0,0,0,1,0,0,1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,1,1,0,1,0,1,1,1,1,0,0,1,0,1,0,1,1,1,0,0,0,0,0,1,1,0,1,1,0,0,0,1,0,1,0,1,0,0,0,0,1,0,1,1,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1,0,1,1,1,0,0,1,1,1,1,1,1,1,0,0,0,0,0,1,0,0,1,1,0,1,0,0,1,0,0,0,1,0,0,1,0,1,0,0,0,1,1,0,1,0,0,0,0,0,1,1,1,1,0,0,1,0,0,1,0,1,1,1,1,1,1,1,0,1,0,0,1,0,0,0,1,1,0,1,1,1,0,0,0,1,0,1,0,0,1,0,1,0,1,0,1,1,1,0,0,1,0,1,1,0,0,1,1,1,1,1,0,0,0,1,1,0};
static const byte TIA_DIV31[ ] = {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0};
static byte tia_volume[2] = {0};
static byte tia_counterMax[2] = {0};
static byte tia_counter[2] = {0};
static byte tia_audc[2] = {0};
static byte tia_audf[2] = {0};
static byte tia_audv[2] = {0};
static uint tia_poly4Cntr[2] = {0};
static uint tia_poly5Cntr[2] = {0};
static uint tia_poly9Cntr[2] = {0};
static uint tia_soundCntr = 0;

// ----------------------------------------------------------------------------
// ProcessChannel
// ----------------------------------------------------------------------------
static void tia_ProcessChannel(byte channel) {
  tia_poly5Cntr[channel]++;
  if(tia_poly5Cntr[channel] == TIA_POLY5_SIZE) {
    tia_poly5Cntr[channel] = 0;
  }
  if(((tia_audc[channel] & 2) == 0) || (((tia_audc[channel] & 1) == 0) && TIA_DIV31[tia_poly5Cntr[channel]]) || (((tia_audc[channel] & 1) == 1) && TIA_POLY5[tia_poly5Cntr[channel]])) {
    if(tia_audc[channel] & 4) {
      tia_volume[channel] = (!tia_volume[channel])? tia_audv[channel]: 0;
    }
    else if(tia_audc[channel] & 8) {
      if(tia_audc[channel] == 8) {
        tia_poly9Cntr[channel]++;
        if(tia_poly9Cntr[channel] == TIA_POLY9_SIZE) {
          tia_poly9Cntr[channel] = 0;
        }
        tia_volume[channel] = (TIA_POLY9[tia_poly9Cntr[channel]])? tia_audv[channel]: 0;
      }
      else {
        tia_volume[channel] = (TIA_POLY5[tia_poly5Cntr[channel]])? tia_audv[channel]: 0;
      }
    }
    else {
      tia_poly4Cntr[channel]++;
      if(tia_poly4Cntr[channel] == TIA_POLY4_SIZE) {
        tia_poly4Cntr[channel] = 0;
      }
      tia_volume[channel] = (TIA_POLY4[tia_poly4Cntr[channel]])? tia_audv[channel]: 0;
    }
  }
}


// ----------------------------------------------------------------------------
// Reset
// ----------------------------------------------------------------------------
void tia_Reset( ) {
  tia_soundCntr = 0;
  for(int index = 0; index < 2; index++) {
    tia_volume[index] = 0;
    tia_counterMax[index] = 0;
    tia_counter[index] = 0;
    tia_audc[index] = 0;
    tia_audf[index] = 0;
    tia_audv[index] = 0;
    tia_poly4Cntr[index] = 0;
    tia_poly5Cntr[index] = 0;
    tia_poly9Cntr[index] = 0;
  }
  tia_Clear( );
}

// ----------------------------------------------------------------------------
// Clear
// ----------------------------------------------------------------------------
void tia_Clear( ) {
  for(int index = 0; index < TIA_BUFFER_SIZE; index++) {
    tia_buffer[index] = 0;
  }
}

// ----------------------------------------------------------------------------
// SetRegister
// ----------------------------------------------------------------------------
void tia_SetRegister(word address, byte data) {
  byte channel;
  byte frequency;
    
  switch(address) {
    case AUDC0:
      tia_audc[0] = data & 15;
      channel = 0;
      break;
    case AUDC1:
      tia_audc[1] = data & 15;
      channel = 1;
      break;
    case AUDF0:
      tia_audf[0] = data & 31;
      channel = 0;
      break;
    case AUDF1:
      tia_audf[1] = data & 31;
      channel = 1;
      break;
    case AUDV0:
      tia_audv[0] = (data & 15) << 2;
      channel = 0;
      break;
    case AUDV1:
      tia_audv[1] = (data & 15) << 2;
      channel = 1;
      break;
    default:
      return;
  }

  if(tia_audc[channel] == 0) {
    frequency = 0;
    tia_volume[channel] = tia_audv[channel];
  }
  else {
    frequency = tia_audf[channel] + 1;
    if(tia_audc[channel] > 11) {
      frequency *= 3;
    }
  }

  if(frequency != tia_counterMax[channel]) {
    tia_counterMax[channel] = frequency;
    if(tia_counter[channel] == 0 || frequency == 0) {
      tia_counter[channel] = frequency;
    }
  }
}

// --------------------------------------------------------------------------------------
// Process
// --------------------------------------------------------------------------------------
void tia_Process(uint length) {
  for(uint index = 0; index < length; index++) {
    if(tia_counter[0] > 1) {
      tia_counter[0]--;
    }
    else if(tia_counter[0] == 1) {
      tia_counter[0] = tia_counterMax[0];
      tia_ProcessChannel(0);
    }
    if(tia_counter[1] > 1) {
      tia_counter[1]--;
    }
    else if(tia_counter[1] == 1) {
      tia_counter[1] = tia_counterMax[1];
      tia_ProcessChannel(1);
    }
    tia_buffer[tia_soundCntr++] = tia_volume[0] + tia_volume[1];
    if(tia_soundCntr >= tia_size) {
      tia_soundCntr = 0;
    }
  }
}