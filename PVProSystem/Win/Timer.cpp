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
// Timer.cpp
// ----------------------------------------------------------------------------
#include "Timer.h"

static LONGLONG timer_currentTime;
static LONGLONG timer_nextTime;
static LONGLONG timer_counterFrequency;
static uint timer_frameTime;
static bool timer_usingCounter = false;

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
void timer_Initialize( ) {
  timer_usingCounter = (QueryPerformanceFrequency((LARGE_INTEGER*)&timer_counterFrequency))? true: false;
  timeBeginPeriod(1);
}

// ----------------------------------------------------------------------------
// Reset
// ----------------------------------------------------------------------------
void timer_Reset( ) {
  if(timer_usingCounter) {
    QueryPerformanceCounter((LARGE_INTEGER*)&timer_nextTime);
    timer_frameTime = timer_counterFrequency / prosystem_frequency;
    timer_nextTime += timer_frameTime;
  }
  else {
    timer_frameTime = (1000.0 / (double)prosystem_frequency) * 1000;
    timer_currentTime = timeGetTime( ) * 1000;
    timer_nextTime = timer_currentTime + timer_frameTime;
  }
}

// ----------------------------------------------------------------------------
// IsTime
// ----------------------------------------------------------------------------
bool timer_IsTime( ) {
  if(timer_usingCounter) {
    QueryPerformanceCounter((LARGE_INTEGER*)&timer_currentTime);
  }
  else {
    timer_currentTime = timeGetTime( ) * 1000;
  }
  
  if(timer_currentTime >= timer_nextTime) {
    timer_nextTime += timer_frameTime;
    return true;
  }
  return false;
}
