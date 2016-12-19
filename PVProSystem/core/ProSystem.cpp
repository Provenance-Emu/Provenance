// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2003, 2004 Greg Stanton
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
// ProSystem.cpp
// ----------------------------------------------------------------------------
#include "ProSystem.h"
#define PRO_SYSTEM_STATE_HEADER "PRO-SYSTEM STATE"
#define PRO_SYSTEM_SOURCE "ProSystem.cpp"

bool prosystem_active = false;
bool prosystem_paused = false;
word prosystem_frequency = 60;
byte prosystem_frame = 0;
word prosystem_scanlines = 262;
uint prosystem_cycles = 0;
int lightgun_scanline = 0;
float lightgun_cycle = 0;

// Whether the last CPU operation resulted in a half cycle (need to take it
// into consideration)
extern bool half_cycle;

// ----------------------------------------------------------------------------
// Reset
// ----------------------------------------------------------------------------
void prosystem_Reset( ) {
  if(cartridge_IsLoaded( )) {
    prosystem_paused = false;
    prosystem_frame = 0;
    sally_Reset( );
    region_Reset( );
    tia_Clear( );
    tia_Reset( );
    pokey_Clear( );
    pokey_Reset( );
    memory_Reset( );
    maria_Clear( );
    maria_Reset( );
    riot_Reset( );
    if(bios_enabled) {
      bios_Store( );
    }
    else {
      cartridge_Store( );
    }
    prosystem_cycles = sally_ExecuteRES( );
    prosystem_active = true;
  }
}

/*
 * Strobe based on the current lightgun location
 */
static void prosystem_FireLightGun()
{
    if( ( ( maria_scanline >= lightgun_scanline ) && 
          ( maria_scanline <= ( lightgun_scanline + 3 ) ) ) && 
        ( prosystem_cycles >= ((int)lightgun_cycle ) - 1 ) )
    {
        memory_ram[INPT4] &= 0x7f;                        
    } 
    else 
    {
        memory_ram[INPT4] |= 0x80;                        
    }
}

uint prosystem_extra_cycles = 0;
// ----------------------------------------------------------------------------
// ExecuteFrame
// ----------------------------------------------------------------------------
void prosystem_ExecuteFrame(const byte* input) {
  // Is WSYNC enabled for the current frame?
  bool wsync = !(cartridge_flags & CARTRIDGE_WSYNC_MASK);

  // Is Maria cycle stealing enabled for the current frame?
  bool cycle_stealing = !(cartridge_flags & CARTRIDGE_CYCLE_STEALING_MASK);

  // Is the lightgun enabled for the current frame?
  bool lightgun = ((cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN) && (memory_ram[CTRL] & 96) != 64);

  riot_SetInput(input);

  prosystem_extra_cycles = 0;

  if(cartridge_pokey) pokey_Frame();

  for(maria_scanline = 1; maria_scanline <= prosystem_scanlines; maria_scanline++) {
    if(maria_scanline == maria_displayArea.top) {
      memory_ram[MSTAT] = 0;
    }
    else if(maria_scanline == maria_displayArea.bottom) {
      memory_ram[MSTAT] = 128;
    }

    // Was a WSYNC performed withing the current scanline?
    bool wsync_scanline = false;

    uint cycles = 0;    

    if(!cycle_stealing || (memory_ram[CTRL] & 96 ) != 64) {
      // Exact cycle counts when Maria is disabled
      prosystem_cycles %= CYCLES_PER_SCANLINE;
      prosystem_extra_cycles = 0;
    }
    else
    {
      prosystem_extra_cycles = (prosystem_cycles % CYCLES_PER_SCANLINE);

      // Some fudge for Maria cycles. Unfortunately Maria cycle counting
      // isn't exact (This adds some extra cycles).
      prosystem_cycles = 0;
    }

    // If lightgun is enabled, check to see if it should be fired
    if(lightgun) prosystem_FireLightGun();

    while(prosystem_cycles < cartridge_hblank) {
      cycles = sally_ExecuteInstruction( );
      prosystem_cycles += (cycles << 2);
      if(half_cycle) prosystem_cycles += 2;

      if(riot_timing) {
        riot_UpdateTimer(cycles);
      }

      // If lightgun is enabled, check to see if it should be fired
      if(lightgun) prosystem_FireLightGun();

      if(memory_ram[WSYNC] && wsync) {
        memory_ram[WSYNC] = false;
        wsync_scanline = true;
        break;
      }
    }    

    cycles = maria_RenderScanline( );

    if(cycle_stealing) {
      prosystem_cycles += cycles;

      if(riot_timing) {
        riot_UpdateTimer(cycles >> 2);
      }
    }

    while(!wsync_scanline && prosystem_cycles < CYCLES_PER_SCANLINE) {
      cycles = sally_ExecuteInstruction( );
      prosystem_cycles += (cycles << 2);
      if(half_cycle) prosystem_cycles += 2;

      // If lightgun is enabled, check to see if it should be fired
      if(lightgun) prosystem_FireLightGun();

      if(riot_timing) {
        riot_UpdateTimer(cycles);
      }

      if(memory_ram[WSYNC] && wsync) {
        memory_ram[WSYNC] = false;
        wsync_scanline = true;
        break;
      }
    }

    // If a WSYNC was performed and the current cycle count is less than
    // the cycles per scanline, add those cycles to current timers.
    if(wsync_scanline && prosystem_cycles < CYCLES_PER_SCANLINE) {
      if(riot_timing)
      {
        riot_UpdateTimer((CYCLES_PER_SCANLINE - prosystem_cycles) >> 2);
      }
      prosystem_cycles = CYCLES_PER_SCANLINE;
    }

    // If lightgun is enabled, check to see if it should be fired
    if(lightgun) prosystem_FireLightGun();

    tia_Process(2);
    if(cartridge_pokey) {
      pokey_Process(2);
    }

    if(cartridge_pokey) pokey_Scanline();
  }

  prosystem_frame++;
  if(prosystem_frame >= prosystem_frequency) {
    prosystem_frame = 0;
  }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------
bool prosystem_Save(std::string filename, bool compress) {
  if(filename.empty( ) || filename.length( ) == 0) {
    logger_LogError("Filename is invalid.", PRO_SYSTEM_SOURCE);
    return false;
  }

  logger_LogInfo("Saving game state to file " + filename + ".", PRO_SYSTEM_SOURCE);

  byte loc_buffer[33000] = {0};

  uint size = 0;
  
  uint index;
  for(index = 0; index < 16; index++) {
    loc_buffer[size + index] = PRO_SYSTEM_STATE_HEADER[index];
  }
  size += 16;
  
  loc_buffer[size++] = 1;
  for(index = 0; index < 4; index++) {
    loc_buffer[size + index] = 0;
  }
  size += 4;

  for(index = 0; index < 32; index++) {
    loc_buffer[size + index] = cartridge_digest[index];
  }
  size += 32;

  loc_buffer[size++] = sally_a;
  loc_buffer[size++] = sally_x;
  loc_buffer[size++] = sally_y;
  loc_buffer[size++] = sally_p;
  loc_buffer[size++] = sally_s;
  loc_buffer[size++] = sally_pc.b.l;
  loc_buffer[size++] = sally_pc.b.h;
  loc_buffer[size++] = cartridge_bank;

  for(index = 0; index < 16384; index++) {
    loc_buffer[size + index] = memory_ram[index];
  }
  size += 16384;
  
  if(cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM) {
    for(index = 0; index < 16384; index++) {
      loc_buffer[size + index] = memory_ram[16384 + index];
    } 
    size += 16384;
  }

  // RIOT state
  loc_buffer[size++] = riot_dra;
  loc_buffer[size++] = riot_drb;
  loc_buffer[size++] = riot_timing;
  loc_buffer[size++] = ( 0xff & ( riot_timer >> 8 ) );
  loc_buffer[size++] = ( 0xff & riot_timer );  
  loc_buffer[size++] = riot_intervals;
  loc_buffer[size++] = ( 0xff & ( riot_clocks >> 8 ) );
  loc_buffer[size++] = ( 0xff & riot_clocks );

#if 0
  if(!compress) {
#endif
    FILE* file = fopen(filename.c_str( ), "wb");
    if(file == NULL) {
      logger_LogError("Failed to open the file " + filename + " for writing.", PRO_SYSTEM_SOURCE);
      return false;
    }
  
    if(fwrite(loc_buffer, 1, size, file) != size) {
      fclose(file);
      logger_LogError("Failed to write the save state data to the file " + filename + ".", PRO_SYSTEM_SOURCE);
      return false;
    }
  
    fflush(file);
    fclose(file);
#if 0
  }
  else {
    if(!archive_Compress(filename.c_str( ), "Save.sav", loc_buffer, size)) {
      logger_LogError("Failed to compress the save state data to the file " + filename + ".", PRO_SYSTEM_SOURCE);
      return false;
    }
  }
#endif 

  return true;
}

bool prosystem_Save_buffer(byte *buffer)
{
    uint size = 0;
    uint index;

    for(index = 0; index < 16; index++) {
        buffer[size + index] = PRO_SYSTEM_STATE_HEADER[index];
    }
    size += 16;

    buffer[size++] = 1;
    for(index = 0; index < 4; index++) {
        buffer[size + index] = 0;
    }
    size += 4;

    for(index = 0; index < 32; index++) {
        buffer[size + index] = cartridge_digest[index];
    }
    size += 32;

    buffer[size++] = sally_a;
    buffer[size++] = sally_x;
    buffer[size++] = sally_y;
    buffer[size++] = sally_p;
    buffer[size++] = sally_s;
    buffer[size++] = sally_pc.b.l;
    buffer[size++] = sally_pc.b.h;
    buffer[size++] = cartridge_bank;

    for(index = 0; index < 16384; index++) {
        buffer[size + index] = memory_ram[index];
    }
    size += 16384;

    if(cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM) {
        for(index = 0; index < 16384; index++) {
            buffer[size + index] = memory_ram[16384 + index];
        }
        size += 16384;
    }

    // RIOT state
    buffer[size++] = riot_dra;
    buffer[size++] = riot_drb;
    buffer[size++] = riot_timing;
    buffer[size++] = ( 0xff & ( riot_timer >> 8 ) );
    buffer[size++] = ( 0xff & riot_timer );
    buffer[size++] = riot_intervals;
    buffer[size++] = ( 0xff & ( riot_clocks >> 8 ) );
    buffer[size++] = ( 0xff & riot_clocks );

    return true;
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
bool prosystem_Load(const std::string filename) {
  if(filename.empty( ) || filename.length( ) == 0) {
    logger_LogError("Filename is invalid.", PRO_SYSTEM_SOURCE);    
    return false;
  }

  logger_LogInfo("Loading game state from file " + filename + ".", PRO_SYSTEM_SOURCE);

  byte loc_buffer[33000] = {0};
  
  uint size = archive_GetUncompressedFileSize(filename);
  if(size == 0) {
    FILE* file = fopen(filename.c_str( ), "rb");
    if(file == NULL) {
      logger_LogError("Failed to open the file " + filename + " for reading.", PRO_SYSTEM_SOURCE);
      return false;
    }

    if(fseek(file, 0L, SEEK_END)) {
      fclose(file);
      logger_LogError("Failed to find the end of the file.", PRO_SYSTEM_SOURCE);
      return false;
    }
  
    size = ftell(file);
    if(fseek(file, 0L, SEEK_SET)) {
      fclose(file);
      logger_LogError("Failed to find the size of the file.", PRO_SYSTEM_SOURCE);
      return false;
    }

    if( size != 16445 && 
        size != 32829 && 
        size != 16453 && 
        size != 32837 ) {
      fclose(file);
      logger_LogError("Save state file has an invalid size.", PRO_SYSTEM_SOURCE);
      return false;
    }
  
    if(fread(loc_buffer, 1, size, file) != size && ferror(file)) {
      fclose(file);
      logger_LogError("Failed to read the file data.", PRO_SYSTEM_SOURCE);
      return false;
    }
    fclose(file);
  }  
  else if(size == 16445 || size == 32829) {
    archive_Uncompress(filename, loc_buffer, size);
  }
  else {
    logger_LogError("Save state file has an invalid size.", PRO_SYSTEM_SOURCE);
    return false;
  }

  uint offset = 0;
  uint index;
  for(index = 0; index < 16; index++) {
    if(loc_buffer[offset + index] != PRO_SYSTEM_STATE_HEADER[index]) {
      logger_LogError("File is not a valid ProSystem save state.", PRO_SYSTEM_SOURCE);
      return false;
    }
  }
  offset += 16;
  byte version = loc_buffer[offset++];
  
  uint date = 0;
  for(index = 0; index < 4; index++) {
  }
  offset += 4;
  
  prosystem_Reset( );
  
  char digest[33] = {0};
  for(index = 0; index < 32; index++) {
    digest[index] = loc_buffer[offset + index];
  }
  offset += 32;
  if(cartridge_digest != std::string(digest)) {
    logger_LogError("Load state digest [" + std::string(digest) + "] does not match loaded cartridge digest [" + cartridge_digest + "].", PRO_SYSTEM_SOURCE);
    return false;
  }
  
  sally_a = loc_buffer[offset++];
  sally_x = loc_buffer[offset++];
  sally_y = loc_buffer[offset++];
  sally_p = loc_buffer[offset++];
  sally_s = loc_buffer[offset++];
  sally_pc.b.l = loc_buffer[offset++];
  sally_pc.b.h = loc_buffer[offset++];
  
  cartridge_StoreBank(loc_buffer[offset++]);

  for(index = 0; index < 16384; index++) {
    memory_ram[index] = loc_buffer[offset + index];
  }
  offset += 16384;

  if(cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM) {
    if(size != 32829 && size != 32837) {
      logger_LogError("Save state file has an invalid size.", PRO_SYSTEM_SOURCE);
      return false;
    }
    for(index = 0; index < 16384; index++) {
      memory_ram[16384 + index] = loc_buffer[offset + index];
    }
    offset += 16384; 
  }  

  if( size == 16453 || size == 32837 )
  {
      // RIOT state
      riot_dra = loc_buffer[offset++];
      riot_drb = loc_buffer[offset++];
      riot_timing = loc_buffer[offset++];
      riot_timer = ( loc_buffer[offset++] << 8 );
      riot_timer |= loc_buffer[offset++];
      riot_intervals = loc_buffer[offset++];
      riot_clocks = ( loc_buffer[offset++] << 8 );
      riot_clocks |= loc_buffer[offset++];

  }

  return true;
}

bool prosystem_Load_buffer(const byte *buffer)
{
    uint size = cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM ? 32837 : 16453;
    uint offset = 0;
    uint index;

    for(index = 0; index < 16; index++) {
        if(buffer[offset + index] != PRO_SYSTEM_STATE_HEADER[index]) {
            logger_LogError("File is not a valid ProSystem save state.", PRO_SYSTEM_SOURCE);
            return false;
        }
    }
    offset += 16;

    byte version = buffer[offset++];
    //uint date = 0;

    offset += 4;

    //prosystem_Reset(); // TODO doesn't seem necessary but needs investigation

    char digest[33] = {0};
    for(index = 0; index < 32; index++) {
        digest[index] = buffer[offset + index];
    }
    offset += 32;
    if(cartridge_digest != std::string(digest)) {
        logger_LogError("Load state digest [" + std::string(digest) + "] does not match loaded cartridge digest [" + cartridge_digest + "].", PRO_SYSTEM_SOURCE);
        return false;
    }

    sally_a = buffer[offset++];
    sally_x = buffer[offset++];
    sally_y = buffer[offset++];
    sally_p = buffer[offset++];
    sally_s = buffer[offset++];
    sally_pc.b.l = buffer[offset++];
    sally_pc.b.h = buffer[offset++];

    cartridge_StoreBank(buffer[offset++]);

    for(index = 0; index < 16384; index++) {
        memory_ram[index] = buffer[offset + index];
    }
    offset += 16384;

    if(cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM) {
        if(size != 32829 && size != 32837) {
            logger_LogError("Save state file has an invalid size.", PRO_SYSTEM_SOURCE);
            return false;
        }
        for(index = 0; index < 16384; index++) {
            memory_ram[16384 + index] = buffer[offset + index];
        }
        offset += 16384;
    }

    // RIOT state
    riot_dra = buffer[offset++];
    riot_drb = buffer[offset++];
    riot_timing = buffer[offset++];
    riot_timer = ( buffer[offset++] << 8 );
    riot_timer |= buffer[offset++];
    riot_intervals = buffer[offset++];
    riot_clocks = ( buffer[offset++] << 8 );
    riot_clocks |= buffer[offset++];

    return true;
}

// ----------------------------------------------------------------------------
// Pause
// ----------------------------------------------------------------------------
void prosystem_Pause(bool pause) {
  if(prosystem_active) {
    prosystem_paused = pause;
  }
}

// ----------------------------------------------------------------------------
// Close
// ----------------------------------------------------------------------------
void prosystem_Close( ) {
  prosystem_active = false;
  prosystem_paused = false;
  cartridge_Release( );
  maria_Reset( );
  maria_Clear( );
  memory_Reset( );
  tia_Reset( );
  tia_Clear( );
}
