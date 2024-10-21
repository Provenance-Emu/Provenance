// -*- C++ -*-
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004 Forgotten and the VBA development team

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

namespace MDFN_IEN_GB
{

struct mapperMBC1 {
  int mapperRAMEnable;
  int mapperROMBank;
  int mapperRAMBank;
  int mapperMemoryModel;
};

struct mapperMBC2 {
  int mapperRAMEnable;
  int mapperROMBank;
};

struct mapperMBC3 {
  int mapperRAMEnable;
  int mapperROMBank;
  int mapperRAMBank;
  int mapperClockLatch;
  int mapperClockRegister;
  int mapperSeconds;
  int mapperMinutes;
  int mapperHours;
  int mapperDays;
  int mapperControl;
  int mapperLSeconds;
  int mapperLMinutes;
  int mapperLHours;
  int mapperLDays;
  int mapperLControl;
  uint64 mapperLastTime;
};

struct mapperMBC5 {
  int mapperRAMEnable;
  int mapperROMBank;
  int mapperRAMBank;
  int mapperROMHighAddress;
  int isRumbleCartridge;
};

struct mapperMBC7 {
  int mapperROMBank;
  int cs;
  int sk;
  int state;
  int buffer;
  int idle;
  int count;
  int code;
  uint8 address;
  int writeEnable;
  int value;
  int curtiltx;
  int curtilty;
};

struct mapperHuC1 {
  int mapperRAMEnable;
  int mapperROMBank;
  int mapperRAMBank;
  int mapperMemoryModel;
  int mapperROMHighAddress;
};

struct mapperHuC3 {
  int mapperRAMEnable;
  int mapperROMBank;
  int mapperRAMBank;
  int mapperAddress;
  int mapperRAMFlag;
  int mapperRAMValue;
  int mapperRegister1;
  int mapperRegister2;
  int mapperRegister3;
  int mapperRegister4;
  int mapperRegister5;
  int mapperRegister6;
  int mapperRegister7;
  int mapperRegister8;
};

MDFN_HIDE extern mapperMBC1 gbDataMBC1;
MDFN_HIDE extern mapperMBC2 gbDataMBC2;
MDFN_HIDE extern mapperMBC3 gbDataMBC3;
MDFN_HIDE extern mapperMBC5 gbDataMBC5;
MDFN_HIDE extern mapperMBC7 gbDataMBC7;

MDFN_HIDE extern mapperHuC1 gbDataHuC1;
MDFN_HIDE extern mapperHuC3 gbDataHuC3;

void mapperMBC1ROM(uint16,uint8);
void mapperMBC1RAM(uint16,uint8);
void mapperMBC2ROM(uint16,uint8);
void mapperMBC2RAM(uint16,uint8);
void mapperMBC3ROM(uint16,uint8);
void mapperMBC3RAM(uint16,uint8);
uint8 mapperMBC3ReadRAM(uint16);
void mapperMBC5ROM(uint16,uint8);
void mapperMBC5RAM(uint16,uint8);
void mapperMBC7ROM(uint16,uint8);
void mapperMBC7RAM(uint16,uint8);
uint8 mapperMBC7ReadRAM(uint16);
void mapperHuC1ROM(uint16,uint8);
void mapperHuC1RAM(uint16,uint8);
void mapperHuC3ROM(uint16,uint8);
void mapperHuC3RAM(uint16,uint8);
uint8 mapperHuC3ReadRAM(uint16);

void memoryUpdateMapMBC1();
void memoryUpdateMapMBC2();
void memoryUpdateMapMBC3();
void memoryUpdateMapMBC5();
void memoryUpdateMapMBC7();
void memoryUpdateMapHuC1();
void memoryUpdateMapHuC3();

}
