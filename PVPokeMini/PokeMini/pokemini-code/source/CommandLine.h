/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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

#ifndef COMMAND_LINE
#define COMMAND_LINE

#include <stdio.h>
#include <stdint.h>

typedef struct {
	char name[32];	// Flag name
	int *ref;	// Reference pointer of the variable
	int type;	// Type (Bool or Integer)
	int numa;	// Minimum value for integer / Value to set
	int numb;	// Maximum value for integer
} TCommandLineCustom;

enum {
	COMMANDLINE_EOL,     // End-Of-List
	COMMANDLINE_BOOL,    // Boolean
	COMMANDLINE_INT,     // Integer, NumA = Minimum, NumB = Maximum
	COMMANDLINE_INTSET,  // Set value (custom only), NumA = Value
	COMMANDLINE_STR,     // String, NumA = String size minus NULL
};

typedef struct {
	int forcefreebios;
	char min_file[PMTMPV];
	char bios_file[PMTMPV];
	char eeprom_file[PMTMPV];
	char state_file[PMTMPV];
	char rom_dir[PMTMPV];
	int updatertc;
	int eeprom_share;
	int sound;
	int piezofilter;
	int lcdfilter;
	int lcdmode;
	int low_battery;
	int palette;
	int rumblelvl;
	int joyenabled;
	int joyid;
	int joyaxis_dpad;
	int joyhats_dpad;
	char joyplatform[32];
	int joybutton[10];
	int multicart;
	int synccycles;
	int keyb_a[10];
	int keyb_b[10];
	uint32_t custompal[4];
	int lcdcontrast;
	int lcdbright;
	const char *pokefile;
	const char *conffile;
	const TCommandLineCustom *confcustom;
} TCommandLine;

// Extern command line structure
extern TCommandLine CommandLine;

// Callbacks
extern int (*PokeMini_PreConfigLoad)(const char *filename, const char *platcfgfile);
extern int (*PokeMini_PostConfigSave)(int success, const char *filename, const char *platcfgfile);

// Unknown key callback, return false to abort loading
typedef int (*TCustomConfCallback)(char *key, char *value, const TCommandLineCustom *custom);

// Process arguments parsing into the command line structure
void CommandLineInit(void);
int CommandLineArgs(int argc, char **argv, const TCommandLineCustom *custom);
int CommandLineConfFile(const char *filename, const char *platcfgfile, const TCommandLineCustom *custom);
int CommandLineConfSave(void);

// Process custom config file
int CustomConfFile(const char *filename, const TCommandLineCustom *custom, TCustomConfCallback unknown);
int CustomConfSave(const char *filename, const TCommandLineCustom *custom, const char *description);

// Write into a stream/string the command line help usage
// PrintHelpUsageStr return number of bytes required for the output, "out" can be NULL
void PrintHelpUsage(FILE *fout);
int PrintHelpUsageStr(char *out);

#endif
