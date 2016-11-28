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
// Database.cpp
// ----------------------------------------------------------------------------
#include "Database.h"

bool database_enabled = true;
std::string database_filename;

static std::string database_GetValue(std::string entry) {
  int index = entry.rfind('=');
  return entry.substr(index + 1);
}

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
void database_Initialize( ) {
  database_filename = common_defaultPath + "ProSystem.dat";
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
bool database_Load(std::string digest) {
  if(database_enabled) {
    logger_LogInfo(IDS_DATABASE1, database_filename);
    
    FILE* file = fopen(database_filename.c_str( ), "r");
    if(file == NULL) {
      logger_LogError(IDS_DATABASE2,"");
      return false;  
    }

    char buffer[256];
    while(fgets(buffer, 256, file) != NULL) {
      std::string line = buffer;
      if(line.compare(1, 32, digest.c_str( )) == 0) {
        std::string entry[7];
        for(int index = 0; index < 7; index++) {
          fgets(buffer, 256, file);
          entry[index] = common_Remove(buffer, '\n');  
        }
        
        cartridge_title = database_GetValue(entry[0]);
        cartridge_type = common_ParseByte(database_GetValue(entry[1]));
        cartridge_pokey = common_ParseBool(database_GetValue(entry[2]));
        cartridge_controller[0] = common_ParseByte(database_GetValue(entry[3]));
        cartridge_controller[1] = common_ParseByte(database_GetValue(entry[4]));
        cartridge_region = common_ParseByte(database_GetValue(entry[5]));
        cartridge_flags = common_ParseUint(database_GetValue(entry[6]));
        break;
      }
    }    
    
    fclose(file);  
  }
  return true;
}


