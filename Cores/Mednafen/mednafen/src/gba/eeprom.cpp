// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2005 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#include "GBA.h"
#include "eeprom.h"

#include <mednafen/FileStream.h>


#define EEPROM_IDLE           0
#define EEPROM_READADDRESS    1
#define EEPROM_READDATA       2
#define EEPROM_READDATA2      3
#define EEPROM_WRITEDATA      4

namespace MDFN_IEN_GBA
{

extern int cpuDmaCount;

static int eepromMode = EEPROM_IDLE;
static int eepromByte = 0;
static int eepromBits = 0;
static int eepromAddress = 0;
static uint8 eepromData[0x2000];
static uint8 eepromBuffer[16];
static int eepromSize = 512;

static bool eepromInUse = false;

int EEPROM_StateAction(StateMem *sm, int load, int data_only)
{
 const bool prev_eepromInUse = eepromInUse;
 const int prev_eepromSize = eepromSize;

 SFORMAT eepromSaveData[] = 
 {
  SFVAR(eepromMode),
  SFVAR(eepromByte),
  SFVAR(eepromBits),
  SFVAR(eepromAddress),
  SFVAR(eepromInUse),
  SFVAR(eepromSize),
  SFPTR8N(eepromData, 0x2000, "eepromData"),
  SFPTR8N(eepromBuffer, 16, "eepromBuffer"),
  SFEND
 };
 int ret = MDFNSS_StateAction(sm, load, data_only, eepromSaveData, "EEPR");

 if(load)
 {
  if(eepromSize != 512 && eepromSize != 0x2000)
   eepromSize = 0x2000;

  if(prev_eepromSize > eepromSize)
   eepromSize = prev_eepromSize;

  eepromInUse |= prev_eepromInUse;

  //printf("InUse: %d\n", eepromInUse);
 }

 return(ret);
}

bool EEPROM_SaveFile(const std::string& path)
{
 if(eepromInUse)
 {
  if(!MDFN_DumpToFile(path, eepromData, eepromSize))
   return(0);
 }

 return(1);
}

void EEPROM_LoadFile(const std::string& path)
{
 try
 {
  FileStream fp(path, FileStream::MODE_READ);
  int64 size;

  size = fp.size();

  if(size != 512 && size != 0x2000)
   throw MDFN_Error(0, _("EEPROM file \"%s\" is an invalid size."), path.c_str());

  fp.read(eepromData, size);

  eepromSize = size;
  eepromInUse = true;
 }
 catch(MDFN_Error &e)
 {
  if(e.GetErrno() != ENOENT)
   throw;
 }
}

void EEPROM_Init(void)
{
 memset(eepromData, 0xFF, sizeof(eepromData));
 memset(eepromBuffer, 0, sizeof(eepromBuffer));
 eepromMode = EEPROM_IDLE;
 eepromByte = 0;
 eepromBits = 0;
 eepromAddress = 0;
 eepromInUse = false;
 eepromSize = 512;
}

void EEPROM_Reset(void)
{
 eepromMode = EEPROM_IDLE;
 eepromByte = 0;
 eepromBits = 0;
 eepromAddress = 0;
}

int eepromRead(uint32 /* address */)
{
  switch(eepromMode) {
  case EEPROM_IDLE:
  case EEPROM_READADDRESS:
  case EEPROM_WRITEDATA:
    return 1;
  case EEPROM_READDATA:
    {
      eepromBits++;
      if(eepromBits == 4) {
        eepromMode = EEPROM_READDATA2;
        eepromBits = 0;
        eepromByte = 0;
      }
      return 0;
    }
  case EEPROM_READDATA2:
    {
      int data = 0;
      int address = eepromAddress << 3;
      int mask = 1 << (7 - (eepromBits & 7));
      data = (eepromData[(address + eepromByte) & 0x1FFF] & mask) ? 1 : 0;
      eepromBits++;
      if((eepromBits & 7) == 0)
        eepromByte++;
      if(eepromBits == 0x40)
        eepromMode = EEPROM_IDLE;
      return data;
    }
  default:
      return 0;
  }
  return 1;
}

void eepromWrite(uint32 /* address */, uint8 value)
{
  if(cpuDmaCount == 0)
    return;
  int bit = value & 1;
  switch(eepromMode) {
  case EEPROM_IDLE:
    eepromByte = 0;
    eepromBits = 1;
    eepromBuffer[eepromByte & 0xF] = bit;
    eepromMode = EEPROM_READADDRESS;
    break;
  case EEPROM_READADDRESS:
    eepromBuffer[eepromByte & 0xF] <<= 1;
    eepromBuffer[eepromByte & 0xF] |= bit;
    eepromBits++;
    if((eepromBits & 7) == 0) {
      eepromByte++;
    }
    if(cpuDmaCount == 0x11 || cpuDmaCount == 0x51) {
      if(eepromBits == 0x11) {
        eepromSize = 0x2000;
        eepromAddress = ((eepromBuffer[0] & 0x3F) << 8) |
          ((eepromBuffer[1] & 0xFF));
        if(!(eepromBuffer[0] & 0x40)) {
          eepromBuffer[0] = bit;          
          eepromBits = 1;
          eepromByte = 0;
          eepromMode = EEPROM_WRITEDATA;
        } else {
          eepromMode = EEPROM_READDATA;
          eepromByte = 0;
          eepromBits = 0;
        }
      }
    } else {
      if(eepromBits == 9) {
        eepromAddress = (eepromBuffer[0] & 0x3F);
        if(!(eepromBuffer[0] & 0x40)) {
          eepromBuffer[0] = bit;
          eepromBits = 1;
          eepromByte = 0;         
          eepromMode = EEPROM_WRITEDATA;
        } else {
          eepromMode = EEPROM_READDATA;
          eepromByte = 0;
          eepromBits = 0;
        }
      }
    }
    break;
  case EEPROM_READDATA:
  case EEPROM_READDATA2:
    // should we reset here?
    eepromMode = EEPROM_IDLE;
    break;
  case EEPROM_WRITEDATA:
    eepromBuffer[eepromByte & 0xF] <<= 1;
    eepromBuffer[eepromByte & 0xF] |= bit;
    eepromBits++;
    if((eepromBits & 7) == 0) {
      eepromByte++;
    }
    if(eepromBits == 0x40) {
      eepromInUse = true;
      // write data;
      for(int i = 0; i < 8; i++) {
        eepromData[((eepromAddress << 3) + i) & 0x1FFF] = eepromBuffer[i];
      }
    } else if(eepromBits == 0x41) {
      eepromMode = EEPROM_IDLE;
      eepromByte = 0;
      eepromBits = 0;
    }
    break;
  }
}

}
