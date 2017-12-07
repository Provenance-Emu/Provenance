/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

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

#include <nds.h>

void OpenNorWrite();
void CloseNorWrite();
uint32 ReadNorFlashID();

int rumbleType;

int RumbleCheck(void)
{
	sysSetCartOwner(BUS_OWNER_ARM9);

	if (isRumbleInserted()) {
		// Warioware / Official rumble
		rumbleType = 1;
	} else {
		// 3-in-1 found
		OpenNorWrite();
		uint32 rumbleID = ReadNorFlashID();
		CloseNorWrite();
		if (rumbleID != 0) rumbleType = 2; 
		else rumbleType = 0;
	}

	return rumbleType;
}

void RumbleEnable(int enable)
{
	if (rumbleType == 2) {
		GBA_BUS[0x1FE0000/2] = 0xD200;
		GBA_BUS[0x0000000/2] = 0x1500;
		GBA_BUS[0x0020000/2] = 0xD200;
		GBA_BUS[0x0040000/2] = 0x1500;
		GBA_BUS[0x1E20000/2] = enable ? 0x00F3 : 0x0008;
		GBA_BUS[0x1FC0000/2] = 0x1500;
	} else setRumble(enable);
}
