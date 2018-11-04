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
#include "Multicart.h"

// Multicart Read/Write
TMulticartRead MulticartRead = NULL;
TMulticartWrite MulticartWrite = NULL;

// Multicart state
int PM_MM_Type = 0;		// Multicart Type
int PM_MM_Dirty = 0;		// ROM Dirty?
int PM_MM_BusCycle = 0;		// Flash cart state
int PM_MM_GetID = 0;		// Get ID on next read
int PM_MM_Bypass = 0;		// Flash Bypass
int PM_MM_Command = 0;		// 0 = None, 1 = Write, 2 = Erase
uint32_t PM_MM_Offset = 0;	// ROM Offset in bytes

// For misc information
uint32_t PM_MM_LastErase_Start = 0;	// Last erased start
uint32_t PM_MM_LastErase_End = 0;	// Last erased end
uint32_t PM_MM_LastProg = 0;		// Last programmed offset

static int Multicart_AM29LV040B_Sectors[8][2] = {
	{0x00000, 0x00000},
	{0x10000, 0x1FFFF},
	{0x20000, 0x2FFFF},
	{0x30000, 0x3FFFF},
	{0x40000, 0x4FFFF},
	{0x50000, 0x5FFFF},
	{0x60000, 0x6FFFF},
	{0x70000, 0x7FFFF}
};

// Normal cartridge (Commercial / Prototype Flash Cart)
uint8_t Multicart_T0R(uint32_t addr)
{
	return PM_ROM[addr & PM_ROM_Mask];
}

void Multicart_T0W(uint32_t addr, uint8_t data)
{
	// Ignored
}

// Normal Flash 512KB
uint8_t Multicart_T1R(uint32_t addr)
{
	if (!PM_MM_GetID) return PM_ROM[(addr + PM_MM_Offset) & PM_ROM_Mask];
	PM_MM_GetID = 0;
	switch (addr & 3) {
		case 0: return 0x01;	// Manufacturer ID
		case 1: return 0x4F;	// Device ID
		case 2: return 0x00;	// Sector protect
	}
	return 0xFF;
}

void Multicart_T1W(uint32_t addr, uint8_t data)
{
	uint32_t faddr = addr & 0x7FF;
	int i, secstart, secend;

	// Cartridge
	if (faddr == 0x555) {
		if (data == 0x90) PM_MM_Offset = 0;
	} else if (addr == 0x7FFFF) {
		if (CommandLine.multicart) {
			PM_MM_Offset = (((data ^ 0x04) & 0x07) << 16) | ((data & 0x38) << 10);
		}
	}

	// Flash I/O
	if (PM_MM_BusCycle == 5) {
		PM_MM_BusCycle = 0;
		if ((faddr == 0x555) && (data == 0x10)) {
			// Chip erase (destroy everything!)
			PM_MM_LastErase_Start = 0;
			PM_MM_LastErase_End = PM_ROM_Size;
			for (i=0; i<PM_ROM_Size; i++) PM_ROM[i] = 0xFF;
			PM_MM_Dirty = 1;
		} else if (data == 0x30) {
			// Sector erase
			secstart = Multicart_AM29LV040B_Sectors[(addr >> 16) & 7][0];
			secend = Multicart_AM29LV040B_Sectors[(addr >> 16) & 7][1];
			PM_MM_LastErase_Start = secstart;
			PM_MM_LastErase_End = secend;
			for (i=secstart; i<=secend; i++) PM_ROM[i] = 0xFF;
			PM_MM_Dirty = 1;
		}
	}
	if (PM_MM_BusCycle == 4) {
		if ((faddr == 0x2AA) && (data == 0x55)) PM_MM_BusCycle = 5;
		else PM_MM_BusCycle = 0;
	}
	if (PM_MM_BusCycle == 3) {
		PM_MM_BusCycle = 0;
		if (PM_MM_Command == 1) {
			// Program (Clear bits)
			PM_MM_LastProg = (addr + PM_MM_Offset) & PM_ROM_Mask;
			PM_ROM[PM_MM_LastProg] &= data;
			PM_MM_Dirty = 1;
		}
		if (PM_MM_Command == 2) {
			// Erase
			if ((faddr == 0x555) && (data == 0xAA)) PM_MM_BusCycle = 4;
		}
	}
	if (PM_MM_BusCycle == 2) {
		PM_MM_BusCycle = 0;
		if (faddr == 0x555) {
			if (data == 0x90) {
				PM_MM_GetID = 1;
			} else if (data == 0xA0) {
				PM_MM_Command = 1;
				PM_MM_BusCycle = 3;
			} else if (data == 0x80) {
				PM_MM_Command = 2;
				PM_MM_BusCycle = 3;
			} else if (data == 0x20) {
				PM_MM_Bypass = 1;
			}
		}
	}
	if (PM_MM_BusCycle == 1) {
		if ((faddr == 0x2AA) && (data == 0x55)) PM_MM_BusCycle = 2;
		else PM_MM_BusCycle = 0;
	}
	if (PM_MM_BusCycle == 0) {
		if (data == 0xF0) {
			PM_MM_GetID = 0;
			PM_MM_Bypass = 0;
		} else if (PM_MM_Bypass) {
			if (data == 0xA0) {
				PM_MM_Command = 1;
				PM_MM_BusCycle = 3;
			} else if (data == 0x20) {
				PM_MM_Bypass = 0;
			}
		} else if ((faddr == 0x555) && (data == 0xAA)) PM_MM_BusCycle = 1;
		PM_MM_Command = 0;
	}
}


// Lupin's Flash 512KB (Scrambled data)
// Data 0 -> Flash Data 7
// Data 1 -> Flash Data 5
// Data 2 -> Flash Data 3
// Data 3 -> Flash Data 1
// Data 4 -> Flash Data 0
// Data 5 -> Flash Data 2
// Data 6 -> Flash Data 4
// Data 7 -> Flash Data 6
uint8_t Multicart_T2R(uint32_t addr)
{
	if (!PM_MM_GetID) return PM_ROM[(addr + PM_MM_Offset) & PM_ROM_Mask];
//	Add_InfoMessage("[DEBUG] Getting ID $%06X\n", addr);
	switch (addr & 0xFF) {
		case 0x00: return 0x80;	// Manufacturer ID
		case 0x01: return 0xBA;	// Device ID
		case 0x02: return 0x00;	// Sector protect
	}
	return 0xFF;
}

void Multicart_T2W(uint32_t addr, uint8_t data)
{
	uint32_t faddr = addr & 0x7FF;
	int i, secstart, secend;

	// Cartridge
	if (faddr == 0x555) {
		if (data == 0x90) PM_MM_Offset = 0;
	} else if (addr == 0x7FFFF) {
		if (CommandLine.multicart) {
			PM_MM_Offset = (((data ^ 0x04) & 0x07) << 16) | ((data & 0x38) << 10);
		}
	}

//	Add_InfoMessage("[DEBUG] Write $%06X, $%02X\n", addr, data);

	// Flash I/O
	if (PM_MM_BusCycle == 5) {
		PM_MM_BusCycle = 0;
		if ((faddr == 0x555) && (data == 0x01)) {
			// Chip erase (destroy everything!)
			PM_MM_LastErase_Start = 0;
			PM_MM_LastErase_End = PM_ROM_Size;
			for (i=0; i<PM_ROM_Size; i++) PM_ROM[i] = 0xFF;
			PM_MM_Dirty = 1;
		} else if (data == 0x05) {
			// Sector erase
			secstart = Multicart_AM29LV040B_Sectors[(addr >> 16) & 7][0];
			secend = Multicart_AM29LV040B_Sectors[(addr >> 16) & 7][1];
			PM_MM_LastErase_Start = secstart;
			PM_MM_LastErase_End = secend;
			for (i=secstart; i<=secend; i++) PM_ROM[i] = 0xFF;
			PM_MM_Dirty = 1;
		}
	}
	if (PM_MM_BusCycle == 4) {
		if ((faddr == 0x2AA) && (data == 0x99)) PM_MM_BusCycle = 5;
		else PM_MM_BusCycle = 0;
	}
	if (PM_MM_BusCycle == 3) {
		PM_MM_BusCycle = 0;
		if (PM_MM_Command == 1) {
			// Program (Clear bits)
			PM_MM_LastProg = (addr + PM_MM_Offset) & PM_ROM_Mask;
			PM_ROM[PM_MM_LastProg] &= data;
			PM_MM_Dirty = 1;
		}
		if (PM_MM_Command == 2) {
			// Erase
			if ((faddr == 0x555) && (data == 0x66)) PM_MM_BusCycle = 4;
		}
	}
	if (PM_MM_BusCycle == 2) {
		PM_MM_BusCycle = 0;
		if (faddr == 0x555) {
			if (data == 0x41) {
				PM_MM_GetID = 1;
			} else if (data == 0x44) {
				PM_MM_Command = 1;
				PM_MM_BusCycle = 3;
			} else if (data == 0x40) {
				PM_MM_Command = 2;
				PM_MM_BusCycle = 3;
			} else if (data == 0x04) {
				PM_MM_Bypass = 1;
			}
		}
	}
	if (PM_MM_BusCycle == 1) {
		if ((faddr == 0x2AA) && (data == 0x99)) PM_MM_BusCycle = 2;
		else PM_MM_BusCycle = 0;
	}
	if (PM_MM_BusCycle == 0) {
		if (data == 0x55) {
			PM_MM_GetID = 0;
			PM_MM_Bypass = 0;
		} else if (PM_MM_Bypass) {
			if (data == 0x44) {
				PM_MM_Command = 1;
				PM_MM_BusCycle = 3;
			} else if (data == 0x04) {
				PM_MM_Bypass = 0;
			}
		} else if ((faddr == 0x555) && (data == 0x66)) PM_MM_BusCycle = 1;
		PM_MM_Command = 0;
	}

//	Add_InfoMessage("[DEBUG] Bus Cycle %i, Command %i, Offset $%06X\n", PM_MM_BusCycle, PM_MM_Command, PM_MM_Offset);
}

void NewMulticart(void)
{
	PM_MM_Dirty = 0;
}

void SetMulticart(int type)
{
	PM_MM_BusCycle = 0;
	PM_MM_GetID = 0;
	PM_MM_Bypass = 0;
	PM_MM_Command = 0;
	PM_MM_Offset = 0;
	if (type == 2) {
		PM_MM_Type = 2;
		MulticartRead = Multicart_T2R;
		MulticartWrite = Multicart_T2W;
	} else if (type == 1) {
		PM_MM_Type = 1;
		MulticartRead = Multicart_T1R;
		MulticartWrite = Multicart_T1W;
	} else {
		PM_MM_Type = 0;
		MulticartRead = Multicart_T0R;
		MulticartWrite = Multicart_T0W;
	}
}
