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

#include "PokeMini.h"

TMinxIO MinxIO;
uint8_t *EEPROM = NULL;
int PokeMini_Rumbling = 0;
int PokeMini_RumblingLatch = 0;
int PokeMini_EEPROMWritten = 0;
int PokeMini_BatteryStatus = 0;  // 0 = Full, 1 = Low
int PokeMini_ShockKey = 0;

uint8_t MinxIO_IODataRead(void);
void MinxIO_IODataWrite(void);
void MinxIO_EEPROM_WEvent(uint8_t bits);
int MinxIO_EEPROM_REvent(void);
void MinxIO_EEPROM_Write(uint8_t data);

//
// Functions
//

int MinxIO_Create(void)
{
	// Create EEPROM memory & format it
	EEPROM = (uint8_t *)malloc(8192);
	if (!EEPROM) return 0;
	MinxIO_FormatEEPROM();

	// Reset
	MinxIO_Reset(1);

	return 1;
}

void MinxIO_Destroy(void)
{
	if (EEPROM) {
		free(EEPROM);
		EEPROM = NULL;
	}
}

void MinxIO_Reset(int hardreset)
{
	// Initialize State
	memset(&MinxIO, 0, sizeof(TMinxIO));
	PokeMini_Rumbling = 0;
	PokeMini_RumblingLatch = 0;
	PokeMini_ShockKey = 0;

	// Init variables
	PMR_KEY_PAD = 0xFF;
	MinxIO.ListenState = MINX_EEPROM_IDLE;
	MinxIO.OperState = MINX_EEPROM_DEVICE;

	// Restore battery status
	MinxIO_BatteryLow(PokeMini_BatteryStatus);
}

int MinxIO_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(32+8192);
	PokeMini_Rumbling = 0;
	PokeMini_RumblingLatch = 0;
	PokeMini_EEPROMWritten = 1;
	POKELOADSS_8(MinxIO.EEPLastPins);
	POKELOADSS_8(MinxIO.ListenState);
	POKELOADSS_8(MinxIO.OperState);
	POKELOADSS_8(MinxIO.EEPData);
	POKELOADSS_32(MinxIO.EEPBit);
	POKELOADSS_16(MinxIO.EEPAddress);
	POKELOADSS_X(22);
	POKELOADSS_A(EEPROM, 8192);
	POKELOADSS_END(32+8192);
}

int MinxIO_SaveState(FILE *fi)
{
	POKESAVESS_START(32+8192);
	POKESAVESS_8(MinxIO.EEPLastPins);
	POKESAVESS_8(MinxIO.ListenState);
	POKESAVESS_8(MinxIO.OperState);
	POKESAVESS_8(MinxIO.EEPData);
	POKESAVESS_32(MinxIO.EEPBit);
	POKESAVESS_16(MinxIO.EEPAddress);
	POKESAVESS_X(22);
	POKESAVESS_A(EEPROM, 8192);
	POKESAVESS_END(32+8192);
}

int MinxIO_FormatEEPROM(void)
{
	if (!EEPROM) return 0;
	memset(EEPROM, 0xFF, 8192);
	return 1;
}

void MinxIO_Keypad(uint8_t key, int pressed)
{
	if (!EEPROM) return;
	switch (key) {
		case MINX_KEY_A:	// Key A
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x01)) return;
				MinxCPU_OnIRQAct(MINX_INTR_1C);
				PMR_KEY_PAD &= ~0x01;
			} else PMR_KEY_PAD |= 0x01;
			break;
		case MINX_KEY_B:	// Key B
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x02)) return;
				MinxCPU_OnIRQAct(MINX_INTR_1B);
				PMR_KEY_PAD &= ~0x02;
			} else PMR_KEY_PAD |= 0x02;
			break;
		case MINX_KEY_C:	// Key C
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x04)) return;
				MinxCPU_OnIRQAct(MINX_INTR_1A);
				PMR_KEY_PAD &= ~0x04;
			} else PMR_KEY_PAD |= 0x04;
			break;
		case MINX_KEY_UP:	// Dpad Up
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x08)) return;
				MinxCPU_OnIRQAct(MINX_INTR_19);
				PMR_KEY_PAD &= ~0x08;
			} else PMR_KEY_PAD |= 0x08;
			break;
		case MINX_KEY_DOWN:	// Dpad Down
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x10)) return;
				MinxCPU_OnIRQAct(MINX_INTR_18);
				PMR_KEY_PAD &= ~0x10;
			} else PMR_KEY_PAD |= 0x10;
			break;
		case MINX_KEY_LEFT:	// Dpad Left
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x20)) return;
				MinxCPU_OnIRQAct(MINX_INTR_17);
				PMR_KEY_PAD &= ~0x20;
			} else PMR_KEY_PAD |= 0x20;
			break;
		case MINX_KEY_RIGHT:	// Dpad Right
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x40)) return;
				MinxCPU_OnIRQAct(MINX_INTR_16);
				PMR_KEY_PAD &= ~0x40;
			} else PMR_KEY_PAD |= 0x40;
			break;
		case MINX_KEY_POWER:	// Power key
			if (pressed) {
				if (!(PMR_KEY_PAD & 0x80)) return;
				MinxCPU_OnIRQAct(MINX_INTR_15);
				PMR_KEY_PAD &= ~0x80;
			} else PMR_KEY_PAD |= 0x80;
			break;
		case MINX_KEY_SHOCK:	// Shock key
			if (!PokeMini_ShockKey && pressed) {
				MinxCPU_OnIRQAct(MINX_INTR_10);
			}
			PokeMini_ShockKey = pressed;
			break;
	}
}

void MinxIO_BatteryLow(int low)
{
	PokeMini_BatteryStatus = low;
	if (low) PMR_SYS_BATT |= 0x20;
	else PMR_SYS_BATT &= 0x1F;
}

void MinxIO_SetTimeStamp(uint8_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t min, uint8_t sec)
{
	uint8_t checksum;
	if (!EEPROM) return;
	checksum = year + month + day + hour + min + sec;
	PMR_SYS_CTRL3 |= 0x02;
	EEPROM[0x1FF6] = 0x00;
	EEPROM[0x1FF7] = 0x00;
	EEPROM[0x1FF8] = 0x00;
	EEPROM[0x1FF9] = year;
	EEPROM[0x1FFA] = month;
	EEPROM[0x1FFB] = day;
	EEPROM[0x1FFC] = hour;
	EEPROM[0x1FFD] = min;
	EEPROM[0x1FFE] = sec;
	EEPROM[0x1FFF] = checksum;
}

uint8_t MinxIO_ReadReg(int cpu, uint8_t reg)
{
	// 0x10, 0x52, 0x60 to 0x62
	switch(reg) {
		case 0x10: // Low Battery
			return PMR_SYS_BATT;
		case 0x44: // Unknown
			return PMR_REG_44;
		case 0x45: // Unknown
			return PMR_REG_45;
		case 0x46: // Unknown
			return PMR_REG_46;
		case 0x47: // Unknown
			return PMR_REG_47;
		case 0x50: // Unknown (related to power management?)
			return PMR_REG_50;
		case 0x51: // Unknown (related to power management?)
			return PMR_REG_51;
		case 0x52: // Keypad
			return PMR_KEY_PAD;
		case 0x53: // Unknown
			return PMR_REG_53;
		case 0x54: // Unknown
			return PMR_REG_54;
		case 0x55: // Unknown
			return PMR_REG_55;
		case 0x60: // I/O Direction Select ( 0 = Input, 1 = Output )
			return PMR_IO_DIR;
		case 0x61: // I/O Data Register
			return MinxIO_IODataRead();
		case 0x62: // Unknown
			return PMR_REG_62;
		default:   // Unused
			return 0;
	}
}

void MinxIO_WriteReg(int cpu, uint8_t reg, uint8_t val)
{
	// 0x10, 0x52, 0x60 to 0x62
	switch(reg) {
		case 0x10: // Low Battery
			PMR_SYS_BATT = (PMR_SYS_BATT & 0x20) | (val & 0x1F);
			return;
		case 0x44: // Unknown
			PMR_REG_44 = val & 0xF7;
			return;
		case 0x45: // Unknown
			PMR_REG_45 = val & 0x0F;
			return;
		case 0x46: // Unknown
			PMR_REG_46 = val;
			return;
		case 0x47: // Unknown
			PMR_REG_47 = val & 0x0F;
			return;
		case 0x50: // Unknown (related to power management?)
			PMR_REG_50 = val;
			return;
		case 0x51: // Unknown (related to power management?)
			PMR_REG_51 = val & 0x03;
			return;
		case 0x52: // Keypad
			return;
		case 0x53: // Unknown
			PMR_REG_53 = 0x00;
		case 0x54: // Unknown
			PMR_REG_54 = val & 0x77;
		case 0x55: // Unknown
			PMR_REG_55 = val & 0x07;
		case 0x60: // I/O Direction Select ( 0 = Input, 1 = Output )
			PMR_IO_DIR = val;
			MinxIO_IODataWrite();
			return;
		case 0x61: // I/O Data Register
			PMR_IO_DATA = val;
			MinxIO_IODataWrite();
			return;
		case 0x62: // Unknown
			PMR_REG_62 = val & 0xF0;
			return;
	}
}

//
// Internal
//

uint8_t MinxIO_IODataRead(void)
{
	uint8_t Input = MINX_IO_PULL_UPS;

	// Update all I/Os
	Input = MinxIO_EEPROM_REvent() ? MINX_EEPROM_DAT : 0;

	return (PMR_IO_DATA & PMR_IO_DIR) | (Input & ~PMR_IO_DIR);
}

void MinxIO_IODataWrite(void)
{
	uint8_t Output;
	Output = (MINX_IO_PULL_UPS & ~PMR_IO_DIR) | (PMR_IO_DATA & PMR_IO_DIR);

	// Update all I/Os
	PokeMini_Rumbling = Output & 0x10;
	if (PokeMini_Rumbling) PokeMini_RumblingLatch = 1;
	MinxIO_EEPROM_WEvent(Output);
}

void MinxIO_EEPROM_WEvent(uint8_t bits)
{
	uint8_t rise = bits & ~MinxIO.EEPLastPins;
	uint8_t fall = ~bits & MinxIO.EEPLastPins;
	MinxIO.EEPLastPins = bits;

	// "Start" Command
	if ((fall & MINX_EEPROM_DAT) && (bits & MINX_EEPROM_CLK)) {
		MinxIO.ListenState = MINX_EEPROM_LISTEN;
		MinxIO.OperState = MINX_EEPROM_DEVICE;
		MinxIO.EEPBit = 8;
		MinxIO.EEPData = 0x00;
		return;
	}

	// "Stop" Command
	if ((rise & MINX_EEPROM_DAT) && (bits & MINX_EEPROM_CLK)) {
		MinxIO.ListenState = MINX_EEPROM_IDLE;
		return;
	}

	// If it's Idle, there's nothing to do...
	if (MinxIO.ListenState == MINX_EEPROM_IDLE) return;

	// Process each bit on clock rise
	if (rise & MINX_EEPROM_CLK) {
		int dat = (bits & MINX_EEPROM_DAT) ? 1 : 0;
		if (MinxIO.EEPBit < 0) {
			MinxIO_EEPROM_Write(MinxIO.EEPData);
			MinxIO.EEPBit = 8;
			MinxIO.EEPData = 0x00;
		} else MinxIO.EEPData = (MinxIO.EEPData << 1) | dat;
	} else if (fall & MINX_EEPROM_CLK) {
		MinxIO.EEPBit = MinxIO.EEPBit - 1;
	}
}

int MinxIO_EEPROM_REvent(void)
{
	int valid = (MinxIO.EEPBit >= 0) && (MinxIO.EEPBit < 8);
	
	// If it's Idle, return high...
	if (MinxIO.ListenState == MINX_EEPROM_IDLE) return 1;

	// Process read
	if (MinxIO.OperState == MINX_EEPROM_RBYTE) {
		if (valid) return (EEPROM[MinxIO.EEPAddress & 0x1FFF] >> MinxIO.EEPBit) & 1;
		else return 0;
	}

	return valid;
}

void MinxIO_EEPROM_Write(uint8_t data)
{
	switch (MinxIO.OperState) {
	case MINX_EEPROM_DEVICE:
		if ((data & 0xF0) == 0xA0) {
			// EEPROM Device
			MinxIO.OperState = data & 0x01 ? MINX_EEPROM_RBYTE : MINX_EEPROM_ADDRHI;
		} else {
			// Unknown Devide
			PokeDPrint(POKEMSG_ERR, "Error: Accessing unknown I2C device: 0x%02X\n", (int)data);
		}
		break;
	case MINX_EEPROM_ADDRHI:
		MinxIO.EEPAddress = (MinxIO.EEPAddress & 0x00FF) | (data << 8);
		MinxIO.OperState = MINX_EEPROM_ADDRLO;
		break;
	case MINX_EEPROM_ADDRLO:
		MinxIO.EEPAddress = (MinxIO.EEPAddress & 0xFF00) | data;
		MinxIO.OperState = MINX_EEPROM_WBYTE;
		break;
	case MINX_EEPROM_WBYTE:
		PokeMini_EEPROMWritten = 1;
		EEPROM[MinxIO.EEPAddress & 0x1FFF] = data;
		MinxIO.EEPAddress++;
		break;
	case MINX_EEPROM_RBYTE:
		MinxIO.EEPAddress++;
		break;
	}
}
