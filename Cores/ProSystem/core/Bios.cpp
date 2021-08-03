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
// Bios.cpp
// ----------------------------------------------------------------------------
#include "Bios.h"
#define BIOS_SOURCE "Bios.cpp"

bool bios_enabled = false;
std::string bios_filename;

static byte* bios_data = NULL;
static word bios_size = 0;

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
bool bios_Load(std::string filename) {
  if(filename.empty( ) || filename.length( ) == 0) {
    logger_LogError("Bios filename is invalid.", BIOS_SOURCE);
    return false;
  }
  
  bios_Release( );
  logger_LogInfo("Opening bios file " + filename + ".", BIOS_SOURCE);

  bios_size = archive_GetUncompressedFileSize(filename);
  if(bios_size == 0) {
    FILE* file = fopen(filename.c_str( ), "rb");
    if(file == NULL) {
#ifndef WII
      logger_LogError("Failed to open the bios file " + filename + " for reading.", BIOS_SOURCE);
#endif
      return false;
    } 
  
    if(fseek(file, 0L, SEEK_END)) {
      fclose(file);
      logger_LogError("Failed to find the end of the bios file.", BIOS_SOURCE);
      return false;
    }
  
    bios_size = ftell(file);
    if(fseek(file, 0L, SEEK_SET)) {
      fclose(file);
      logger_LogError("Failed to find the size of the bios file.", BIOS_SOURCE);
      return false;
    }
  
    bios_data = new byte[bios_size];
    if(fread(bios_data, 1, bios_size, file) != bios_size && ferror(file)) {
      fclose(file);
      logger_LogError("Failed to read the bios data.", BIOS_SOURCE);
      bios_Release( );
      return false;
    }
  
    fclose(file);
  }
  else {
    bios_data = new byte[bios_size];
    archive_Uncompress(filename, bios_data, bios_size);
  }

  bios_filename = filename;
  return true; 
}

// ----------------------------------------------------------------------------
// IsLoaded
// ----------------------------------------------------------------------------
bool bios_IsLoaded( ) {
  return (bios_data != NULL)? true: false;
}

// ----------------------------------------------------------------------------
// Release
// ----------------------------------------------------------------------------
void bios_Release( ) {
  if(bios_data) {
    delete [ ] bios_data;
    bios_size = 0;
    bios_data = NULL;
  }
}

// ----------------------------------------------------------------------------
// Store
// ----------------------------------------------------------------------------
void bios_Store( ) {
  if(bios_data != NULL && bios_enabled) {
    memory_WriteROM(65536 - bios_size, bios_size, bios_data);
  }
}
