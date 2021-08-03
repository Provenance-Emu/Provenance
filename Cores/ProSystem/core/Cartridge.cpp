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
// Cartridge.cpp
// ----------------------------------------------------------------------------
#include "Cartridge.h"
#define CARTRIDGE_SOURCE "Cartridge.cpp"

std::string cartridge_title;
std::string cartridge_description;
std::string cartridge_year;
std::string cartridge_maker;
std::string cartridge_digest;
std::string cartridge_filename;
byte cartridge_type;
byte cartridge_region;
bool cartridge_pokey;
byte cartridge_controller[2];
byte cartridge_bank;
uint cartridge_flags;
int cartridge_crosshair_x;
int cartridge_crosshair_y;
bool cartridge_dualanalog = false;
uint cartridge_hblank = 34;

static byte* cartridge_buffer = NULL;
static uint cartridge_size = 0;

// ----------------------------------------------------------------------------
// HasHeader
// ----------------------------------------------------------------------------
static bool cartridge_HasHeader(const byte* header) {
  const char HEADER_ID[ ] = {"ATARI7800"};
  for(int index = 0; index < 9; index++) {
    if(HEADER_ID[index] != header[index + 1]) {
      return false;
    }
  }
  return true;
}

// ----------------------------------------------------------------------------
// Header for CC2 hack
// ----------------------------------------------------------------------------
static bool cartridge_CC2(const byte* header) {
  const char HEADER_ID[ ] = {">>"};
  for(int index = 0; index < 2; index++) {
    if(HEADER_ID[index] != header[index+1]) {
      return false;
    }
  }
  return true;
}

// ----------------------------------------------------------------------------
// GetBankOffset
// ----------------------------------------------------------------------------
static uint cartridge_GetBankOffset(byte bank) {
  if ((cartridge_type == CARTRIDGE_TYPE_SUPERCART || cartridge_type == CARTRIDGE_TYPE_SUPERCART_ROM || cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM) && cartridge_size <= 65536) {
    // for some of these carts, there are only 4 banks. in this case we ignore bit 3
    // previously, games of this type had to be doubled. The first 4 banks needed to be duplicated at the end of the ROM
      return (bank & 3) * 16384;
  }

  return bank * 16384;
}

// ----------------------------------------------------------------------------
// WriteBank
// ----------------------------------------------------------------------------
static void cartridge_WriteBank(word address, byte bank) {
  uint offset = cartridge_GetBankOffset(bank);
  if(offset < cartridge_size) {
    memory_WriteROM(address, 16384, cartridge_buffer + offset);
    cartridge_bank = bank;
  }
}

// ----------------------------------------------------------------------------
// ReadHeader
// ----------------------------------------------------------------------------
static void cartridge_ReadHeader(const byte* header) {
  char temp[33] = {0};
  for(int index = 0; index < 32; index++) {
    temp[index] = header[index + 17];  
  }
  cartridge_title = temp;
  
  cartridge_size  = header[49] << 24;
  cartridge_size |= header[50] << 16;
  cartridge_size |= header[51] << 8;
  cartridge_size |= header[52];

  if(header[53] == 0) {
    if(cartridge_size > 131072) {
      cartridge_type = CARTRIDGE_TYPE_SUPERCART_LARGE;
    }
    else if(header[54] == 2 || header[54] == 3) {
      cartridge_type = CARTRIDGE_TYPE_SUPERCART;
    }
    else if(header[54] == 4 || header[54] == 5 || header[54] == 6 || header[54] == 7) {
      cartridge_type = CARTRIDGE_TYPE_SUPERCART_RAM;
    }
    else if(header[54] == 8 || header[54] == 9 || header[54] == 10 || header[54] == 11) {
      cartridge_type = CARTRIDGE_TYPE_SUPERCART_ROM;
    }
    else {
      cartridge_type = CARTRIDGE_TYPE_NORMAL;
    }
  }
  else {
    if(header[53] == 1) {
      cartridge_type = CARTRIDGE_TYPE_ABSOLUTE;
    }
    else if(header[53] == 2) {
      cartridge_type = CARTRIDGE_TYPE_ACTIVISION;
    }
    else {
      cartridge_type = CARTRIDGE_TYPE_NORMAL;
    }
  }
  
  cartridge_pokey = (header[54] & 1)? true: false;
  cartridge_controller[0] = header[55];
  cartridge_controller[1] = header[56];
  cartridge_region = header[57];
  cartridge_flags = 0;
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
static bool cartridge_Load(const byte* data, uint size) {
  if(size <= 128) {
    logger_LogError("Cartridge data is invalid.", CARTRIDGE_SOURCE);
    return false;
  }

  cartridge_Release( );
  
  byte header[128] = {0};
  for(int index = 0; index < 128; index++) {
    header[index] = data[index];
  }

if (cartridge_CC2(header)) {
    logger_LogError("Prosystem doesn't support CC2 hacks.", CARTRIDGE_SOURCE);
    return false;
  }

  uint offset = 0;
  if(cartridge_HasHeader(header)) {
    cartridge_ReadHeader(header);
    size -= 128;
    offset = 128;
    cartridge_size = size;
  }
  else {
    cartridge_size = size;
  }
  
  cartridge_buffer = new byte[cartridge_size];
  for(int index = 0; index < cartridge_size; index++) {
    cartridge_buffer[index] = data[index + offset];
  }
  
  cartridge_digest = hash_Compute(cartridge_buffer, cartridge_size);
  
  return true;
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
bool cartridge_Load(std::string filename) {
  if(filename.empty( ) || filename.length( ) == 0) {
    logger_LogError("Cartridge filename is invalid.", CARTRIDGE_SOURCE);
    return false;
  }
  
  cartridge_Release( );
  logger_LogInfo("Opening cartridge file " + filename + ".", CARTRIDGE_SOURCE);
  
  byte* data = NULL;
  //uint size = archive_GetUncompressedFileSize(filename);
  uint size = 0;

  if(size == 0) {
    FILE *file = fopen(filename.c_str( ), "rb");
    if(file == NULL) {
      logger_LogError("Failed to open the cartridge file " + filename + " for reading.", CARTRIDGE_SOURCE);
      return false;  
    }

    if(fseek(file, 0L, SEEK_END)) {
      fclose(file);
      logger_LogError("Failed to find the end of the cartridge file.", CARTRIDGE_SOURCE);
      return false;
    }
    size = ftell(file);
    if(fseek(file, 0L, SEEK_SET)) {
      fclose(file);
      logger_LogError("Failed to find the size of the cartridge file.", CARTRIDGE_SOURCE);
      return false;
    }
  
    data = new byte[size];
    if(fread(data, 1, size, file) != size && ferror(file)) {
      fclose(file);
      logger_LogError("Failed to read the cartridge data.", CARTRIDGE_SOURCE);
      cartridge_Release( );
      delete [ ] data;
      return false;
    }    

    fclose(file);    
  }
  else {
    data = new byte[size];
    //archive_Uncompress(filename, data, size);
  }
  
  if(!cartridge_Load(data, size)) {
    logger_LogError("Failed to load the cartridge data into memory.", CARTRIDGE_SOURCE);
    delete [ ] data;
    return false;
  }
  if(data != NULL) {
    delete [ ] data;
  }
  
  cartridge_filename = filename;
  return true;
}

// ----------------------------------------------------------------------------
// Store
// ----------------------------------------------------------------------------
void cartridge_Store( ) {
  switch(cartridge_type) {
    case CARTRIDGE_TYPE_NORMAL:
      memory_WriteROM(65536 - cartridge_size, cartridge_size, cartridge_buffer);
      break;
    case CARTRIDGE_TYPE_SUPERCART:
      if(cartridge_GetBankOffset(7) < cartridge_size) {
        memory_WriteROM(49152, 16384, cartridge_buffer + cartridge_GetBankOffset(7));
      }
      break;
    case CARTRIDGE_TYPE_SUPERCART_LARGE:
      if(cartridge_GetBankOffset(8) < cartridge_size) {
        memory_WriteROM(49152, 16384, cartridge_buffer + cartridge_GetBankOffset(8));
        memory_WriteROM(16384, 16384, cartridge_buffer + cartridge_GetBankOffset(0));
      }
      break;
    case CARTRIDGE_TYPE_SUPERCART_RAM:
      if(cartridge_GetBankOffset(7) < cartridge_size) {
        memory_WriteROM(49152, 16384, cartridge_buffer + cartridge_GetBankOffset(7));
        memory_ClearROM(16384, 16384);
      }
      break;
    case CARTRIDGE_TYPE_SUPERCART_ROM:
      if(cartridge_GetBankOffset(7) < cartridge_size && cartridge_GetBankOffset(6) < cartridge_size) {
        memory_WriteROM(49152, 16384, cartridge_buffer + cartridge_GetBankOffset(7));
        memory_WriteROM(16384, 16384, cartridge_buffer + cartridge_GetBankOffset(6));
      }
      break;
    case CARTRIDGE_TYPE_ABSOLUTE:
      memory_WriteROM(16384, 16384, cartridge_buffer);
      memory_WriteROM(32768, 32768, cartridge_buffer + cartridge_GetBankOffset(2));
      break;
    case CARTRIDGE_TYPE_ACTIVISION:
      if(122880 < cartridge_size) {
        memory_WriteROM(40960, 16384, cartridge_buffer);
        memory_WriteROM(16384, 8192, cartridge_buffer + 106496);
        memory_WriteROM(24576, 8192, cartridge_buffer + 98304);
        memory_WriteROM(32768, 8192, cartridge_buffer + 122880);
        memory_WriteROM(57344, 8192, cartridge_buffer + 114688);
      }
      break;
  }
}

// ----------------------------------------------------------------------------
// Write
// ----------------------------------------------------------------------------
void cartridge_Write(word address, byte data) {
  switch(cartridge_type) {
    case CARTRIDGE_TYPE_SUPERCART:
    case CARTRIDGE_TYPE_SUPERCART_RAM:
    case CARTRIDGE_TYPE_SUPERCART_ROM:
      if(address >= 32768 && address < 49152 && data < 9) {
        cartridge_StoreBank(data);
      }
      break;
    case CARTRIDGE_TYPE_SUPERCART_LARGE:
      if(address >= 32768 && address < 49152 && data < 9) {
        cartridge_StoreBank(data + 1);
      }
      break;
    case CARTRIDGE_TYPE_ABSOLUTE:
      if(address == 32768 && (data == 1 || data == 2)) {
        cartridge_StoreBank(data - 1);
      }
      break;
    case CARTRIDGE_TYPE_ACTIVISION:
      if(address >= 65408) {
        cartridge_StoreBank(address & 7);
      }
      break;
  }

  if(cartridge_pokey && address >= 0x4000 && address <= 0x400f) {
    switch(address) {
      case POKEY_AUDF1:
        pokey_SetRegister(POKEY_AUDF1, data);
        break;
      case POKEY_AUDC1:
        pokey_SetRegister(POKEY_AUDC1, data);
        break;
      case POKEY_AUDF2:
        pokey_SetRegister(POKEY_AUDF2, data);
        break;
      case POKEY_AUDC2:
        pokey_SetRegister(POKEY_AUDC2, data);
        break;
      case POKEY_AUDF3:
        pokey_SetRegister(POKEY_AUDF3, data);
        break;
      case POKEY_AUDC3:
        pokey_SetRegister(POKEY_AUDC3, data);
        break;
      case POKEY_AUDF4:
        pokey_SetRegister(POKEY_AUDF4, data);
        break;
      case POKEY_AUDC4:
        pokey_SetRegister(POKEY_AUDC4, data);
        break;
      case POKEY_AUDCTL:
        pokey_SetRegister(POKEY_AUDCTL, data);
        break;
      case POKEY_SKCTLS:
        pokey_SetRegister(POKEY_SKCTLS, data);
        break;
    }
  }
}

// ----------------------------------------------------------------------------
// StoreBank
// ----------------------------------------------------------------------------
void cartridge_StoreBank(byte bank) {
  switch(cartridge_type) {
    case CARTRIDGE_TYPE_SUPERCART:
      cartridge_WriteBank(32768, bank);
      break;
    case CARTRIDGE_TYPE_SUPERCART_RAM:
      cartridge_WriteBank(32768, bank);
      break;
    case CARTRIDGE_TYPE_SUPERCART_ROM:
      cartridge_WriteBank(32768, bank);
      break;
    case CARTRIDGE_TYPE_SUPERCART_LARGE:
      cartridge_WriteBank(32768, bank);        
      break;
    case CARTRIDGE_TYPE_ABSOLUTE:
      cartridge_WriteBank(16384, bank);
      break;
    case CARTRIDGE_TYPE_ACTIVISION:
      cartridge_WriteBank(40960, bank);
      break;
  }  
}

// ----------------------------------------------------------------------------
// IsLoaded
// ----------------------------------------------------------------------------
bool cartridge_IsLoaded( ) {
  return (cartridge_buffer != NULL)? true: false;
}

// ----------------------------------------------------------------------------
// Release
// ----------------------------------------------------------------------------
void cartridge_Release( ) {
  if(cartridge_buffer != NULL) {
    delete [ ] cartridge_buffer;
    cartridge_size = 0;
    cartridge_buffer = NULL;

    cartridge_type = 0;
    cartridge_region = 0;
    cartridge_pokey = 0;
    memset(cartridge_controller, 0, sizeof(cartridge_controller));
    cartridge_bank = 0;
    cartridge_flags = 0;
    cartridge_crosshair_x = 0;
    cartridge_crosshair_y = 0;
    cartridge_hblank = 34;
    cartridge_dualanalog = false;
  }
}
