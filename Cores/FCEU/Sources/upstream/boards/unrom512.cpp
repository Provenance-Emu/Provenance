/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2014 CaitSith2
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

/*
 * Roms still using NES 1.0 format should be loaded as 32K CHR RAM.
 * Roms defined under NES 2.0 should use the VRAM size field, defining 7, 8 or 9, based on how much VRAM should be present.
 * UNIF doesn't have this problem, because unique board names can define this information.
 * The UNIF names are UNROM-512-8K, UNROM-512-16K and UNROM-512-32K
 *
 * The battery flag in the NES header enables flash,  Mirrror mode 2 Enables MI_0 and MI_1 mode.
 * Known games to use this board are: 
 *    Battle Kid 2: Mountain of Torment (512K PRG, 8K CHR RAM, Horizontal Mirroring, Flash disabled)
 *    Study Hall (128K PRG (in 512K flash chip), 8K CHR RAM, Horizontal Mirroring, Flash enabled)
 * Although Xmas 2013 uses a different board, where LEDs can be controlled (with writes to the $8000-BFFF space),
 * it otherwise functions identically.
*/

#include "mapinc.h"
#include "../ines.h"

static uint8 latche, latcheinit, bus_conflict, chrram_mask, software_id=false;
static uint16 latcha;
static uint8 *flashdata;
static uint32 *flash_write_count;
static uint8 *FlashPage[32];
static uint32 *FlashWriteCountPage[32];
static uint8 flashloaded = false;

static uint8 flash_save=0, flash_state=0, flash_mode=0, flash_bank;
static void (*WLSync)(void);
static void (*WHSync)(void);

static INLINE void setfpageptr(int s, uint32 A, uint8 *p) {
	uint32 AB = A >> 11;
	int x;

	if (p)
		for (x = (s >> 1) - 1; x >= 0; x--) {
			FlashPage[AB + x] = p - A;
		}
	else
		for (x = (s >> 1) - 1; x >= 0; x--) {
			FlashPage[AB + x] = 0;
		}
}

void setfprg16(uint32 A, uint32 V) {
	if (PRGsize[0] >= 16384) {
		V &= PRGmask16[0];
		setfpageptr(16, A, flashdata ? (&flashdata[V << 14]) : 0);
	} else {
		uint32 VA = V << 3;
		int x;

		for (x = 0; x < 8; x++)
			setfpageptr(2, A + (x << 11), flashdata ? (&flashdata[((VA + x) & PRGmask2[0]) << 11]) : 0);
	}
}

void inc_flash_write_count(uint8 bank, uint32 A)
{
	flash_write_count[(bank*4) + ((A&0x3000)>>12)]++;
	if(!flash_write_count[(bank*4) + ((A&0x3000)>>12)])
		flash_write_count[(bank*4) + ((A&0x3000)>>12)]++;
}

uint32 GetFlashWriteCount(uint8 bank, uint32 A)
{
	return flash_write_count[(bank*4) + ((A&0x3000)>>12)];
}

static void StateRestore(int version) {
	WHSync();
}

static DECLFW(UNROM512LLatchWrite)
{
	latche = V;
	latcha = A;
	WLSync();
}

static DECLFW(UNROM512HLatchWrite)
{
	if (bus_conflict)
		latche = (V == CartBR(A)) ? V : 0;
	else
		latche = V;
	latcha = A;
	WHSync();
}

static DECLFR(UNROM512LatchRead)
{
	uint8 flash_id[3]={0xB5,0xB6,0xB7};
	if(software_id)
	{
		if(A&1)
			return flash_id[ROM_size>>4];
		else
			return 0xBF;
	}
	if(flash_save)
	{
		if(A < 0xC000)
		{
			if(GetFlashWriteCount(flash_bank,A))
				return FlashPage[A >> 11][A];
		}
		else
		{
			if(GetFlashWriteCount(ROM_size-1,A))
				return FlashPage[A >> 11][A];
		}
	}
	return Page[A >> 11][A];
}

static void UNROM512LatchPower(void) {
	latche = latcheinit;
	WHSync();
	SetReadHandler(0x8000, 0xFFFF, UNROM512LatchRead);
	if(!flash_save)
		SetWriteHandler(0x8000, 0xFFFF, UNROM512HLatchWrite);
	else
	{
		SetWriteHandler(0x8000,0xBFFF,UNROM512LLatchWrite);
		SetWriteHandler(0xC000,0xFFFF,UNROM512HLatchWrite);
	}
}

static void UNROM512LatchClose(void) {
	if(flash_write_count)
		FCEU_gfree(flash_write_count);
	if(flashdata)
		FCEU_gfree(flashdata);
	flash_write_count = NULL;
	flashdata = NULL;
}


static void UNROM512LSync() {
	int erase_a[5]={0x9555,0xAAAA,0x9555,0x9555,0xAAAA};
	int erase_d[5]={0xAA,0x55,0x80,0xAA,0x55};
	int erase_b[5]={1,0,1,1,0};

	if(flash_mode==0)
	{
		if((latcha == erase_a[flash_state]) && (latche == erase_d[flash_state]) && (flash_bank == erase_b[flash_state]))
		{
			flash_state++;
			if(flash_state == 5)
			{
				flash_mode=1;
			}
		}
		else if ((flash_state==2)&&(latcha==0x9555)&&(latche==0xA0)&&(flash_bank==1))
		{
			flash_state++;
			flash_mode=2;
		}
		else if ((flash_state==2)&&(latcha==0x9555)&&(latche==0x90)&&(flash_bank==1))
		{
			flash_state=0;
			software_id=true;
		}
		else
		{
			if(latche==0xF0)
				software_id=false;
			flash_state=0;
		}
	}
	else if(flash_mode==1)	//Chip Erase or Sector Erase
	{
		if(latche==0x30)
		{
			inc_flash_write_count(flash_bank,latcha);
			memset(&FlashPage[(latcha & 0xF000) >> 11][latcha & 0xF000],0xFF,0x1000);
		}
		else if (latche==0x10)
		{
			for(uint32 i=0;i<(ROM_size*4);i++)
				inc_flash_write_count(i>>2,i<<12);
			memset(flashdata,0xFF,ROM_size*0x4000);	//Erasing the rom chip as instructed. Crash rate calulated to be 99.9% :)
		}
		flash_state=0;
		flash_mode=0;
	}
	else if(flash_mode==2)	//Byte Program
	{
		if(!GetFlashWriteCount(flash_bank,latcha))
		{
			inc_flash_write_count(flash_bank,latcha);
			memcpy(&FlashPage[(latcha & 0xF000) >> 11][latcha & 0xF000],&Page[(latcha & 0xF000)>>11][latcha & 0xF000],0x1000);
		}
		FlashPage[latcha>>11][latcha]&=latche;
		flash_state=0;
		flash_mode=0;
	}
}

static void UNROM512HSync()
{
	flash_bank=latche&(ROM_size-1);
	
	setprg16(0x8000, flash_bank);
	setprg16(0xc000, ~0);
	setfprg16(0x8000, flash_bank);
	setfprg16(0xC000, ~0);
	setchr8r(0, (latche & chrram_mask) >> 5);
	setmirror(MI_0+(latche>>7));
}

void UNROM512_Init(CartInfo *info) {
	flash_state=0;
	flash_bank=0;
	flash_save=info->battery;

	if(info->vram_size == 8192)
		chrram_mask = 0;
	else if (info->vram_size == 16384)
		chrram_mask = 0x20;
	else
		chrram_mask = 0x60;
	
	SetupCartMirroring(info->mirror,(info->mirror>=MI_0)?0:1,0);
	bus_conflict = !info->battery;
	latcheinit = 0;
	WLSync = UNROM512LSync;
	WHSync = UNROM512HSync;
	info->Power = UNROM512LatchPower;
	info->Close = UNROM512LatchClose;
	GameStateRestore = StateRestore;
	if(flash_save)
	{
		flashdata = (uint8*)FCEU_gmalloc(ROM_size*0x4000);
		flash_write_count = (uint32*)FCEU_gmalloc(ROM_size*4*sizeof(uint32));
		info->SaveGame[0] = (uint8*)flash_write_count;
		info->SaveGame[1] = flashdata;
		info->SaveGameLen[0] = ROM_size*4*sizeof(uint32);
		info->SaveGameLen[1] = ROM_size*0x4000;
		AddExState(flash_write_count,ROM_size*4*sizeof(uint32),0,"FLASH_WRITE_COUNT");
		AddExState(flashdata,ROM_size*0x4000,0,"FLASH_DATA");
		AddExState(&flash_state,1,0,"FLASH_STATE");
		AddExState(&flash_mode,1,0,"FLASH_MODE");
		AddExState(&flash_bank,1,0,"FLASH_BANK");
		AddExState(&latcha,2,0,"LATA");
	}
	AddExState(&latche, 1, 0, "LATC");
	AddExState(&bus_conflict, 1, 0, "BUSC");
}