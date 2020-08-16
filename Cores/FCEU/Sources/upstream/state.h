/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

enum ENUM_SSLOADPARAMS
{
	SSLOADPARAM_NOBACKUP,
	SSLOADPARAM_BACKUP,
};

void FCEUSS_Save(const char *, bool display_message=true);
bool FCEUSS_Load(const char *, bool display_message=true);

 //zlib values: 0 (none) through 9 (max) or -1 (default)
bool FCEUSS_SaveMS(EMUFILE* outstream, int compressionLevel);

bool FCEUSS_LoadFP(EMUFILE* is, ENUM_SSLOADPARAMS params);

extern int CurrentState;
void FCEUSS_CheckStates(void);

struct SFORMAT
{
	//a void* to the data or a void** to the data
	void *v;

	//size, plus flags
	uint32 s;

	//a string description of the element
	char *desc;
};

void ResetExState(void (*PreSave)(void),void (*PostSave)(void));
void AddExState(void *v, uint32 s, int type, char *desc);

//indicates that the value is a multibyte integer that needs to be put in the correct byte order
#define FCEUSTATE_RLSB            0x80000000

//void*v is actually a void** which will be indirected before reading
#define FCEUSTATE_INDIRECT            0x40000000

//all FCEUSTATE flags together so that we can mask them out and get the size
#define FCEUSTATE_FLAGS (FCEUSTATE_RLSB|FCEUSTATE_INDIRECT)

void FCEU_DrawSaveStates(uint8 *XBuf);

void CreateBackupSaveState(const char *fname); //backsup a savestate before overwriting it with a new one
void BackupLoadState();				 //Makes a backup savestate before any loadstate
void LoadBackup();					 //Loads the backupsavestate
void RedoLoadState();				 //reloads a loadstate if backupsavestate was run
void SwapSaveState();				 //Swaps a savestate with its backup state

extern char lastSavestateMade[2048]; //Filename of last savestate used
extern bool undoSS;					 //undo savestate flag
extern bool redoSS;					 //redo savestate flag
extern char lastLoadstateMade[2048]; //Filename of last state loaded
extern bool undoLS;					 //undo loadstate flag
extern bool redoLS;					 //redo savestate flag
extern bool backupSavestates;		 //Whether or not to make backups, true by default
bool CheckBackupSaveStateExist();	 //Checks if backupsavestate exists

extern bool compressSavestates;		//Whether or not to compress non-movie savestates (by default, yes)
