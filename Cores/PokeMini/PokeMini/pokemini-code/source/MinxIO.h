/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef MINXHW_IO
#define MINXHW_IO

#include <stdio.h>
#include <stdint.h>

typedef struct {
	// Internal processing
	uint8_t EEPLastPins;
	uint8_t ListenState;
	uint8_t OperState;
	uint8_t EEPData;
	int32_t EEPBit;
	uint16_t EEPAddress;
} TMinxIO;

// Export IO state
extern TMinxIO MinxIO;

// EEPROM Data
extern uint8_t *EEPROM;

// Rumbling & EEPROM written state
extern int PokeMini_Rumbling;
extern int PokeMini_RumblingLatch;
extern int PokeMini_EEPROMWritten;
extern int PokeMini_BatteryStatus;  // 0 = Full, 1 = Low

enum {
	// EEPROM Listen State
	MINX_EEPROM_IDLE = 0,    // Idle
	MINX_EEPROM_LISTEN = 1,  // Listening

	// EEPROM Data State
	MINX_EEPROM_DEVICE = 0,  // Device ID
	MINX_EEPROM_ADDRHI = 1,  // High Address Byte
	MINX_EEPROM_ADDRLO = 2,  // Low Address Byte
	MINX_EEPROM_WBYTE = 3,   // Write Byte
	MINX_EEPROM_RBYTE = 4,   // Read Byte

	// Keypad 
	MINX_KEY_NONE = 0,
	MINX_KEY_A = 1,
	MINX_KEY_B = 2,
	MINX_KEY_C = 3,
	MINX_KEY_UP = 4,
	MINX_KEY_DOWN = 5,
	MINX_KEY_LEFT = 6,
	MINX_KEY_RIGHT = 7,
	MINX_KEY_POWER = 8,
	MINX_KEY_SHOCK = 9       // Not real key, reserved for handling key event
};

// Interrupt table
enum {
	MINX_INTR_0F = 0x0F,     // IR Receiver
	MINX_INTR_10 = 0x10,     // Shock Sensor
	MINX_INTR_15 = 0x15,     // A key
	MINX_INTR_16 = 0x16,     // B key
	MINX_INTR_17 = 0x17,     // C key
	MINX_INTR_18 = 0x18,     // Up key
	MINX_INTR_19 = 0x19,     // Down key
	MINX_INTR_1A = 0x1A,     // Left key
	MINX_INTR_1B = 0x1B,     // Right key
	MINX_INTR_1C = 0x1C,     // Power key
};

#define MINX_IO_PULL_UPS	0x40	// Pull-up when direction create a Z

#define MINX_EEPROM_DAT		0x04
#define MINX_EEPROM_CLK		0x08


int MinxIO_Create(void);

void MinxIO_Destroy(void);

void MinxIO_Reset(int hardreset);

int MinxIO_LoadState(FILE *fi, uint32_t bsize);

int MinxIO_SaveState(FILE *fi);

int MinxIO_FormatEEPROM(void);

void MinxIO_Keypad(uint8_t key, int pressed);

void MinxIO_BatteryLow(int low);

void MinxIO_SetTimeStamp(uint8_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t min, uint8_t sec);

uint8_t MinxIO_ReadReg(int cpu, uint8_t reg);

void MinxIO_WriteReg(int cpu, uint8_t reg, uint8_t val);

#endif
