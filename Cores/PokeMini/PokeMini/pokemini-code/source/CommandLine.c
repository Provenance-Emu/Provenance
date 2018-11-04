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

#include "PokeMini.h"
#include "Keyboard.h"

TCommandLine CommandLine;

int (*PokeMini_PreConfigLoad)(const char *filename, const char *platcfgfile) = NULL;
int (*PokeMini_PostConfigSave)(int success, const char *filename, const char *platcfgfile) = NULL;

void CommandLineInit(void)
{
	// Clear structure
	memset((void *)&CommandLine, 0, sizeof(TCommandLine));

	// Default strings
	CommandLine.min_file[0] = 0; 
	strcpy(CommandLine.bios_file, "bios.min");
	strcpy(CommandLine.eeprom_file, "PokeMini.eep");
	CommandLine.state_file[0] = 0;
	CommandLine.confcustom = NULL;
	strcpy(CommandLine.joyplatform, "default");
	CommandLine.rom_dir[0] = 0;

	// Default booleans / integers
	CommandLine.forcefreebios = 0;	// Force FreeBIOS
	CommandLine.updatertc = 2;	// Update RTC (0=Off, 1=State, 2=Host)
	CommandLine.eeprom_share = 0;	// EEPROM Share
#ifdef PERFORMANCE
	CommandLine.sound = MINX_AUDIO_GENERATED;
	CommandLine.piezofilter = 0;	// Piezo Filter
#else
	CommandLine.sound = MINX_AUDIO_DIRECTPWM;
	CommandLine.piezofilter = 1;	// Piezo Filter
#endif
	CommandLine.lcdfilter = 1;	// LCD Filter
	CommandLine.lcdmode = 0;	// LCD Mode
	CommandLine.low_battery = 0;	// Low Battery
	CommandLine.palette = 0;	// Palette Index
	CommandLine.rumblelvl = 3;	// Rumble level
	CommandLine.joyenabled = 0;	// Joystick Enabled
	CommandLine.joyid = 0;		// Joystick ID
	CommandLine.joyaxis_dpad = 1;	// Joystick Axis as DPad
	CommandLine.joyhats_dpad = 1;	// Joystick Hats as DPad
	// Joystick mapping
	CommandLine.joybutton[0] = 8;	// Menu:  Button 8
	CommandLine.joybutton[1] = 1;	// A:     Button 1
	CommandLine.joybutton[2] = 2;	// B:     Button 2
	CommandLine.joybutton[3] = 7;	// C:     Button 7
	CommandLine.joybutton[4] = 10;	// Up:    Button 10
	CommandLine.joybutton[5] = 11;	// Down:  Button 11
	CommandLine.joybutton[6] = 4;	// Left:  Button 4
	CommandLine.joybutton[7] = 5;	// Right: Button 5
	CommandLine.joybutton[8] = 9;	// Power: Button 9
	CommandLine.joybutton[9] = 6;	// Shake: Button 6
	// Keyboard mapping (Magic numbers!)
	CommandLine.keyb_a[0] = PMKEYB_ESCAPE;	// Menu:  ESCAPE
	CommandLine.keyb_a[1] = PMKEYB_X;	// A:     X
	CommandLine.keyb_a[2] = PMKEYB_Z;	// B:     Z
	CommandLine.keyb_a[3] = PMKEYB_C;	// C:     C
	CommandLine.keyb_a[4] = PMKEYB_UP;	// Up:    UP
	CommandLine.keyb_a[5] = PMKEYB_DOWN;	// Down:  DOWN
	CommandLine.keyb_a[6] = PMKEYB_LEFT;	// Left:  LEFT
	CommandLine.keyb_a[7] = PMKEYB_RIGHT;	// Right: RIGHT
	CommandLine.keyb_a[8] = PMKEYB_E;	// Power: E
	CommandLine.keyb_a[9] = PMKEYB_A;	// Shake: A
	// Keyboard alternative mapping (Magic numbers!)
	CommandLine.keyb_b[0] = PMKEYB_Q;	// Menu:  Q
	CommandLine.keyb_b[1] = PMKEYB_NONE;	// A:     NONE
	CommandLine.keyb_b[2] = PMKEYB_NONE;	// B:     NONE
	CommandLine.keyb_b[3] = PMKEYB_D;	// C:     D
	CommandLine.keyb_b[4] = PMKEYB_KP_8;	// Up:    KP_8
	CommandLine.keyb_b[5] = PMKEYB_KP_2;	// Down:  KP_2
	CommandLine.keyb_b[6] = PMKEYB_KP_4;	// Left:  KP_4
	CommandLine.keyb_b[7] = PMKEYB_KP_6;	// Right: KP_6
	CommandLine.keyb_b[8] = PMKEYB_P;	// Power: P
	CommandLine.keyb_b[9] = PMKEYB_S;	// Shake: S
	CommandLine.custompal[0] = 0xFFFFFF;	// Custom Palette 1 Light
	CommandLine.custompal[1] = 0x000000;	// Custom Palette 1 Dark
	CommandLine.custompal[2] = 0xFFFFFF;	// Custom Palette 2 Light
	CommandLine.custompal[3] = 0x000000;	// Custom Palette 2 Dark
	CommandLine.lcdcontrast = 64;		// LCD contrast
	CommandLine.lcdbright = 0;		// LCD bright offset
	CommandLine.multicart = 0;	// Multicart support
#ifdef PERFORMANCE
	CommandLine.synccycles = 64;	// Sync cycles to 64 (Performance)
#else
	CommandLine.synccycles = 8;	// Sync cycles to 8 (Accurant)
#endif
}

int CommandLineCustomArgs(int argc, char **argv, int *extra, const TCommandLineCustom *custom)
{
	int i;
	if ((!custom) || (!extra)) return 0;
	*extra = 0;
	for (i = 0; custom[i].type != COMMANDLINE_EOL; i++) {
		if ((argc > 0) && custom[i].name) {
			if (!strcasecmp(*argv, custom[i].name)) {
				if (custom[i].type == COMMANDLINE_BOOL) {
					if (--argc && custom[i].ref) *custom[i].ref = Str2Bool(*++argv);
					*extra = 1;
				} else if (custom[i].type == COMMANDLINE_INT) {
					if (--argc && custom[i].ref) *custom[i].ref = BetweenNum(atoi_Ex(*++argv, 0), custom[i].numa, custom[i].numb);
					*extra = 1;
				} else if (custom[i].type == COMMANDLINE_INTSET) {
					if (custom[i].ref) *custom[i].ref = custom[i].numa;
				} else if (custom[i].type == COMMANDLINE_STR) {
					if (--argc && custom[i].ref) strncpy((char *)custom[i].ref, *++argv, custom[i].numa);
					*extra = 1;
				}
				return 1;
			}
		}
	}
	return 0;
}

int CommandLineArgs(int argc, char **argv, const TCommandLineCustom *custom)
{
	int extra;

	// No arguments, return true
	if (argc <= 1) return 1;

	// Process each argument
	argv++;
	while (--argc > 0) {
		if (*argv[0] == '-') {
			// Assuming option
			if (!strcasecmp(*argv, "-nofreebios")) CommandLine.forcefreebios = 0;
			else if (!strcasecmp(*argv, "-freebios")) CommandLine.forcefreebios = 1;
			else if (!strcasecmp(*argv, "-nobios")) CommandLine.bios_file[0] = 0;
			else if (!strcasecmp(*argv, "-bios")) { if (--argc) strncpy(CommandLine.bios_file, *++argv, PMTMPV-1); }
			else if (!strcasecmp(*argv, "-noeeprom")) CommandLine.eeprom_file[0] = 0;
			else if (!strcasecmp(*argv, "-eeprom")) { if (--argc) strncpy(CommandLine.eeprom_file, *++argv, PMTMPV-1); }
			else if (!strcasecmp(*argv, "-nostate")) CommandLine.state_file[0] = 0;
			else if (!strcasecmp(*argv, "-state")) { if (--argc) strncpy(CommandLine.state_file, *++argv, PMTMPV-1); }
			else if (!strcasecmp(*argv, "-nortc")) CommandLine.updatertc = 0;
			else if (!strcasecmp(*argv, "-statertc")) CommandLine.updatertc = 1;
			else if (!strcasecmp(*argv, "-hostrtc")) CommandLine.updatertc = 2;
			else if (!strcasecmp(*argv, "-eepromshare")) CommandLine.eeprom_share = 1;
			else if (!strcasecmp(*argv, "-noeepromshare")) CommandLine.eeprom_share = 0;
			else if (!strcasecmp(*argv, "-nosound")) CommandLine.sound = 0;
			else if (!strcasecmp(*argv, "-sound")) CommandLine.sound = 4;
			else if (!strcasecmp(*argv, "-soundgenerate")) CommandLine.sound = 1;
			else if (!strcasecmp(*argv, "-sounddirect")) CommandLine.sound = 2;
			else if (!strcasecmp(*argv, "-soundemulate")) CommandLine.sound = 3;
			else if (!strcasecmp(*argv, "-sounddirectpwm")) CommandLine.sound = 4;
			else if (!strcasecmp(*argv, "-soundpwm")) CommandLine.sound = 4;
			else if (!strcasecmp(*argv, "-nopiezo")) CommandLine.piezofilter = 0;
			else if (!strcasecmp(*argv, "-piezo")) CommandLine.piezofilter = 1;
			else if (!strcasecmp(*argv, "-nofilter")) CommandLine.lcdfilter = 0;
			else if (!strcasecmp(*argv, "-filter")) CommandLine.lcdfilter = 1;
			else if (!strcasecmp(*argv, "-dotmatrix")) CommandLine.lcdfilter = 1;
			else if (!strcasecmp(*argv, "-scanline")) CommandLine.lcdfilter = 2;
			else if (!strcasecmp(*argv, "-2shades")) CommandLine.lcdmode = 2;
			else if (!strcasecmp(*argv, "-3shades")) CommandLine.lcdmode = 1;
			else if (!strcasecmp(*argv, "-analog")) CommandLine.lcdmode = 0;
			else if (!strcasecmp(*argv, "-fullbattery")) CommandLine.low_battery = 0;
			else if (!strcasecmp(*argv, "-lowbattery")) CommandLine.low_battery = 1;
			else if (!strcasecmp(*argv, "-autobattery")) CommandLine.low_battery = 2;
			else if (!strcasecmp(*argv, "-palette")) { if (--argc) CommandLine.palette = BetweenNum(atoi_Ex(*++argv, 0), 0, 15); }
			else if (!strcasecmp(*argv, "-rumblelvl")) { if (--argc) CommandLine.rumblelvl = BetweenNum(atoi_Ex(*++argv, 0), 0, 3); }
			else if (!strcasecmp(*argv, "-nojoystick")) CommandLine.joyenabled = 0;
			else if (!strcasecmp(*argv, "-joystick")) CommandLine.joyenabled = 1;
			else if (!strcasecmp(*argv, "-joyid")) { if (--argc) CommandLine.joyid = BetweenNum(atoi_Ex(*++argv, 0), 0, 15); }
			else if (!strcasecmp(*argv, "-custom1light")) { if (--argc) CommandLine.custompal[0] = BetweenNum(atoi_Ex(*++argv, 0xFFFFFF), 0x000000, 0xFFFFFF); }
			else if (!strcasecmp(*argv, "-custom1dark")) { if (--argc) CommandLine.custompal[1] = BetweenNum(atoi_Ex(*++argv, 0x000000), 0x000000, 0xFFFFFF); }
			else if (!strcasecmp(*argv, "-custom2light")) { if (--argc) CommandLine.custompal[2] = BetweenNum(atoi_Ex(*++argv, 0xFFFFFF), 0x000000, 0xFFFFFF); }
			else if (!strcasecmp(*argv, "-custom2dark")) { if (--argc) CommandLine.custompal[3] = BetweenNum(atoi_Ex(*++argv, 0x000000), 0x000000, 0xFFFFFF); }
			else if (!strcasecmp(*argv, "-synccycles")) { if (--argc) CommandLine.synccycles = BetweenNum(atoi_Ex(*++argv, 8), 8, 512); }
			else if (!strcasecmp(*argv, "-multicart")) { if (--argc) CommandLine.multicart = BetweenNum(atoi_Ex(*++argv, 0), 0, 2); }
			else if (!strcasecmp(*argv, "-lcdcontrast")) { if (--argc) CommandLine.lcdcontrast = BetweenNum(atoi_Ex(*++argv, 64), 0, 100); }
			else if (!strcasecmp(*argv, "-lcdbright")) { if (--argc) CommandLine.lcdbright = BetweenNum(atoi_Ex(*++argv, 0), -100, 100); }
			else if (CommandLineCustomArgs(argc, argv, &extra, custom)) { argc -= extra; argv += extra; }
			else return 0;
		} else {
			// Assuming rom
			if (strlen(CommandLine.min_file) == 0) strcpy(CommandLine.min_file, *argv);
		}
		if (argc) argv++;
	}

	return 1;
}

int CommandLineCustomConfFile(char *key, char *value, const TCommandLineCustom *custom)
{
	int i;
	if (!custom) return 0;
	for (i = 0; custom[i].type != COMMANDLINE_EOL; i++) {
		if (custom[i].name) {
			if (!strcasecmp(key, custom[i].name)) {
				if (custom[i].type == COMMANDLINE_BOOL) {
					if (custom[i].ref) *custom[i].ref = Str2Bool(value);
				} else if (custom[i].type == COMMANDLINE_INT) {
					if (custom[i].ref) *custom[i].ref = BetweenNum(atoi_Ex(value, 0), custom[i].numa, custom[i].numb);
				} else if (custom[i].type == COMMANDLINE_STR) {
					if (custom[i].ref) strcpy((char *)custom[i].ref, value);
				}
				return 1;
			}
		}
	}
	return 0;
}

int CommandLineConfFile(const char *filename, const char *platcfgfile, const TCommandLineCustom *custom)
{
	FILE *fi = NULL;
	char tmp[PMTMPV], *txt, *key, *value;

	CommandLine.pokefile = filename;
	CommandLine.conffile = platcfgfile;
	CommandLine.confcustom = custom;

	// Pre-load config callback
	if (PokeMini_PreConfigLoad) {
		if (!PokeMini_PreConfigLoad(filename, platcfgfile)) return 0;
	}

	// Pokemini config file
	PokeMini_GetCustomDir(tmp, PMTMPV);
	PokeMini_GotoExecDir();
	fi = fopen(filename, "r");
	PokeMini_GotoCustomDir(tmp);

	if (fi) {
		while ((txt = fgets(tmp, PMTMPV, fi)) != NULL) {
			// Remove comments
			RemoveComments(txt);

			// Break up key and value
			if (!SeparateAtChar(txt, '=', &key, &value)) continue;

			// Trim them
			key = TrimStr(key);
			value = TrimStr(value);

			// Decode key and set CommandLine
			if (!strcasecmp(key, "freebios")) CommandLine.forcefreebios = Str2Bool(value);
			else if (!strcasecmp(key, "biosfile")) strncpy(CommandLine.bios_file, value, PMTMPV-1);
			else if (!strcasecmp(key, "eepromfile")) strncpy(CommandLine.eeprom_file, value, PMTMPV-1);
			else if (!strcasecmp(key, "statefile")) strncpy(CommandLine.state_file, value, PMTMPV-1);
			else if (!strcasecmp(key, "romdir")) strncpy(CommandLine.rom_dir, value, PMTMPV-1);
			else if (!strcasecmp(key, "rtc")) CommandLine.updatertc = BetweenNum(atoi_Ex(value, 2), 0, 2);
			else if (!strcasecmp(key, "eepromshare")) CommandLine.eeprom_share = Str2Bool(value);
			else if (!strcasecmp(key, "soundengine")) {
				if (Str2Bool(value)) CommandLine.sound = 4;
				else if (!strcasecmp(value, "generated")) CommandLine.sound = 1;
				else if (!strcasecmp(value, "generate")) CommandLine.sound = 1;
				else if (!strcasecmp(value, "gen")) CommandLine.sound = 1;
				else if (!strcasecmp(value, "1")) CommandLine.sound = 1;
				else if (!strcasecmp(value, "direct")) CommandLine.sound = 2;
				else if (!strcasecmp(value, "2")) CommandLine.sound = 2;
				else if (!strcasecmp(value, "emulated")) CommandLine.sound = 3;
				else if (!strcasecmp(value, "emulate")) CommandLine.sound = 3;
				else if (!strcasecmp(value, "emu")) CommandLine.sound = 3;
				else if (!strcasecmp(value, "3")) CommandLine.sound = 3;
				else if (!strcasecmp(value, "directpwm")) CommandLine.sound = 4;
				else if (!strcasecmp(value, "pwm")) CommandLine.sound = 4;
				else if (!strcasecmp(value, "4")) CommandLine.sound = 4;
				else CommandLine.sound = 0;
			}
			else if (!strcasecmp(key, "piezo")) CommandLine.piezofilter = Str2Bool(value);
			else if (!strcasecmp(key, "dotmatrix")) CommandLine.lcdfilter = Str2Bool(value) ? 1 : 0;  // For compability
			else if (!strcasecmp(key, "lcdfilter")) {
				if (!strcasecmp(value, "scanline")) CommandLine.lcdfilter = 2;
				else if (!strcasecmp(value, "matrix")) CommandLine.lcdfilter = 1;
				else if (!strcasecmp(value, "none")) CommandLine.lcdfilter = 0;
				else PokeDPrint(POKEMSG_ERR, "Conf Error: Invalid 'lcdfilter' value\n");
			}
			else if (!strcasecmp(key, "lcdmode")) {
				if (!strcasecmp(value, "2shades")) CommandLine.lcdmode = 2;
				else if (!strcasecmp(value, "3shades")) CommandLine.lcdmode = 1;
				else if (!strcasecmp(value, "analog")) CommandLine.lcdmode = 0;
				else PokeDPrint(POKEMSG_ERR, "Conf Error: Invalid 'lcdmode' value\n");
			}
			else if (!strcasecmp(key, "lowbattery")) CommandLine.low_battery = BetweenNum(atoi_Ex(value, 0), 0, 2);
			else if (!strcasecmp(key, "palette")) CommandLine.palette = BetweenNum(atoi_Ex(value, 0), 0, 15);
			else if (!strcasecmp(key, "rumblelvl")) CommandLine.rumblelvl = BetweenNum(atoi_Ex(value, 0), 0, 3);
			else if (!strcasecmp(key, "joyenabled")) CommandLine.joyenabled = Str2Bool(value);
			else if (!strcasecmp(key, "joyid")) CommandLine.joyid = BetweenNum(atoi_Ex(value, 0), 0, 15);
			else if (!strcasecmp(key, "joyaxis_dpad")) CommandLine.joyaxis_dpad = Str2Bool(value);
			else if (!strcasecmp(key, "joyhats_dpad")) CommandLine.joyhats_dpad = Str2Bool(value);
			else if (!strcasecmp(key, "joyplatform")) strncpy(CommandLine.joyplatform, value, 31);
			else if (!strcasecmp(key, "joybutton_menu")) CommandLine.joybutton[0] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_a")) CommandLine.joybutton[1] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_b")) CommandLine.joybutton[2] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_c")) CommandLine.joybutton[3] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_up")) CommandLine.joybutton[4] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_down")) CommandLine.joybutton[5] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_left")) CommandLine.joybutton[6] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_right")) CommandLine.joybutton[7] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_power")) CommandLine.joybutton[8] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "joybutton_shock")) CommandLine.joybutton[9] = BetweenNum(atoi_Ex(value, -1), -1, 32);
			else if (!strcasecmp(key, "keyb_menu")) CommandLine.keyb_a[0] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_a")) CommandLine.keyb_a[1] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_b")) CommandLine.keyb_a[2] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_c")) CommandLine.keyb_a[3] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_up")) CommandLine.keyb_a[4] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_down")) CommandLine.keyb_a[5] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_left")) CommandLine.keyb_a[6] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_right")) CommandLine.keyb_a[7] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_power")) CommandLine.keyb_a[8] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_shock")) CommandLine.keyb_a[9] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_menu")) CommandLine.keyb_b[0] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_a")) CommandLine.keyb_b[1] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_b")) CommandLine.keyb_b[2] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_c")) CommandLine.keyb_b[3] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_up")) CommandLine.keyb_b[4] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_down")) CommandLine.keyb_b[5] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_left")) CommandLine.keyb_b[6] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_right")) CommandLine.keyb_b[7] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_power")) CommandLine.keyb_b[8] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "keyb_alt_shock")) CommandLine.keyb_b[9] = BetweenNum(atoi_Ex(value, 0), 0, PMKEYB_EOL-1);
			else if (!strcasecmp(key, "custom1light")) CommandLine.custompal[0] = BetweenNum(atoi_Ex(value, 0xFFFFFF), 0x000000, 0xFFFFFF);
			else if (!strcasecmp(key, "custom1dark")) CommandLine.custompal[1] = BetweenNum(atoi_Ex(value, 0x000000), 0x000000, 0xFFFFFF);
			else if (!strcasecmp(key, "custom2light")) CommandLine.custompal[2] = BetweenNum(atoi_Ex(value, 0xFFFFFF), 0x000000, 0xFFFFFF);
			else if (!strcasecmp(key, "custom2dark")) CommandLine.custompal[3] = BetweenNum(atoi_Ex(value, 0x000000), 0x000000, 0xFFFFFF);
			else if (!strcasecmp(key, "multicart")) CommandLine.multicart = BetweenNum(atoi_Ex(value, 0), 0, 2);
			else if (!strcasecmp(key, "synccycles")) CommandLine.synccycles = BetweenNum(atoi_Ex(value, 8), 8, 512);
			else if (!strcasecmp(key, "lcdcontrast")) CommandLine.lcdcontrast = BetweenNum(atoi_Ex(value, 64), 0, 100);
			else if (!strcasecmp(key, "lcdbright")) CommandLine.lcdbright = BetweenNum(atoi_Ex(value, 0), -100, 100);
			else PokeDPrint(POKEMSG_ERR, "Conf warning: Unknown '%s' key\n", key);
		}
		fclose(fi);
	}

	// Platform config file
	if (platcfgfile && custom) {
		PokeMini_GetCustomDir(tmp, PMTMPV);
		PokeMini_GotoExecDir();
		fi = fopen(platcfgfile, "r");
		PokeMini_GotoCustomDir(tmp);

		if (fi) {
			while ((txt = fgets(tmp, PMTMPV, fi)) != NULL) {
				// Remove comments
				RemoveComments(txt);

				// Break up key and value
				if (!SeparateAtChar(txt, '=', &key, &value)) continue;

				// Trim them
				key = TrimStr(key);
				value = TrimStr(value);

				// Decode key and set CommandLine
				if (!CommandLineCustomConfFile(key, value, custom)) {
					PokeDPrint(POKEMSG_ERR, "Platform conf warning: Unknown '%s' key\n", key);
				}
			}
			fclose(fi);
		}
	}

	return (fi != NULL);
}

int CommandLineConfSave(void)
{
	const TCommandLineCustom *custom;
	char tmp[PMTMPV];
	FILE *fo = NULL;
	int i;

	// Pokemini config file
	if (CommandLine.pokefile) {
		PokeMini_GetCustomDir(tmp, PMTMPV);
		PokeMini_GotoExecDir();
		fo = fopen(CommandLine.pokefile, "w");
		PokeMini_GotoCustomDir(tmp);

		if (fo) {
			fprintf(fo, "# Config file generated by PokeMini %s\n", PokeMini_Version);
			fprintf(fo, "# Read the documentation for full description of each item\n");
			fprintf(fo, "# Note that command-line will take priority\n\n");
			fprintf(fo, "# Default options\n");
			fprintf(fo, "freebios=%s\n", Bool2StrAf(CommandLine.forcefreebios));
			fprintf(fo, "biosfile=%s\n", CommandLine.bios_file);
			fprintf(fo, "eepromfile=%s\n", CommandLine.eeprom_file);
			fprintf(fo, "statefile=%s\n", CommandLine.state_file);
			fprintf(fo, "romdir=%s\n", CommandLine.rom_dir);
			fprintf(fo, "rtc=%d\n", CommandLine.updatertc);
			fprintf(fo, "eepromshare=%s\n", Bool2StrAf(CommandLine.eeprom_share));
			if (CommandLine.sound == 4) fprintf(fo, "soundengine=directpwm\n");
			else if (CommandLine.sound == 3) fprintf(fo, "soundengine=emulated\n");
			else if (CommandLine.sound == 2) fprintf(fo, "soundengine=direct\n");
			else if (CommandLine.sound == 1) fprintf(fo, "soundengine=generated\n");
			else fprintf(fo, "soundengine=off\n");
			fprintf(fo, "piezo=%s\n", Bool2StrAf(CommandLine.piezofilter));
			if (CommandLine.lcdfilter == 2) fprintf(fo, "lcdfilter=scanline\n");
			else if (CommandLine.lcdfilter == 1) fprintf(fo, "lcdfilter=matrix\n");
			else fprintf(fo, "lcdfilter=none\n");
			if (CommandLine.lcdmode == 2) fprintf(fo, "lcdmode=2shades\n");
			else if (CommandLine.lcdmode == 1) fprintf(fo, "lcdmode=3shades\n");
			else fprintf(fo, "lcdmode=analog\n");
			fprintf(fo, "lowbattery=%d\n", CommandLine.low_battery);
			fprintf(fo, "palette=%d\n", CommandLine.palette);
			fprintf(fo, "rumblelvl=%d\n", CommandLine.rumblelvl);
			fprintf(fo, "joyenabled=%s\n", Bool2StrAf(CommandLine.joyenabled));
			fprintf(fo, "joyid=%d\n", CommandLine.joyid);
			fprintf(fo, "joyaxis_dpad=%s\n", Bool2StrAf(CommandLine.joyaxis_dpad));
			fprintf(fo, "joyhats_dpad=%s\n", Bool2StrAf(CommandLine.joyhats_dpad));
			fprintf(fo, "joyplatform=%s\n", CommandLine.joyplatform);
			fprintf(fo, "joybutton_menu=%d\n", CommandLine.joybutton[0]);
			fprintf(fo, "joybutton_a=%d\n", CommandLine.joybutton[1]);
			fprintf(fo, "joybutton_b=%d\n", CommandLine.joybutton[2]);
			fprintf(fo, "joybutton_c=%d\n", CommandLine.joybutton[3]);
			fprintf(fo, "joybutton_up=%d\n", CommandLine.joybutton[4]);
			fprintf(fo, "joybutton_down=%d\n", CommandLine.joybutton[5]);
			fprintf(fo, "joybutton_left=%d\n", CommandLine.joybutton[6]);
			fprintf(fo, "joybutton_right=%d\n", CommandLine.joybutton[7]);
			fprintf(fo, "joybutton_power=%d\n", CommandLine.joybutton[8]);
			fprintf(fo, "joybutton_shock=%d\n", CommandLine.joybutton[9]);
			fprintf(fo, "keyb_menu=%d\n", CommandLine.keyb_a[0]);
			fprintf(fo, "keyb_a=%d\n", CommandLine.keyb_a[1]);
			fprintf(fo, "keyb_b=%d\n", CommandLine.keyb_a[2]);
			fprintf(fo, "keyb_c=%d\n", CommandLine.keyb_a[3]);
			fprintf(fo, "keyb_up=%d\n", CommandLine.keyb_a[4]);
			fprintf(fo, "keyb_down=%d\n", CommandLine.keyb_a[5]);
			fprintf(fo, "keyb_left=%d\n", CommandLine.keyb_a[6]);
			fprintf(fo, "keyb_right=%d\n", CommandLine.keyb_a[7]);
			fprintf(fo, "keyb_power=%d\n", CommandLine.keyb_a[8]);
			fprintf(fo, "keyb_shock=%d\n", CommandLine.keyb_a[9]);
			fprintf(fo, "keyb_alt_menu=%d\n", CommandLine.keyb_b[0]);
			fprintf(fo, "keyb_alt_a=%d\n", CommandLine.keyb_b[1]);
			fprintf(fo, "keyb_alt_b=%d\n", CommandLine.keyb_b[2]);
			fprintf(fo, "keyb_alt_c=%d\n", CommandLine.keyb_b[3]);
			fprintf(fo, "keyb_alt_up=%d\n", CommandLine.keyb_b[4]);
			fprintf(fo, "keyb_alt_down=%d\n", CommandLine.keyb_b[5]);
			fprintf(fo, "keyb_alt_left=%d\n", CommandLine.keyb_b[6]);
			fprintf(fo, "keyb_alt_right=%d\n", CommandLine.keyb_b[7]);
			fprintf(fo, "keyb_alt_power=%d\n", CommandLine.keyb_b[8]);
			fprintf(fo, "keyb_alt_shock=%d\n", CommandLine.keyb_b[9]);
			fprintf(fo, "custom1light=0x%06X\n", (unsigned int)CommandLine.custompal[0]);
			fprintf(fo, "custom1dark=0x%06X\n", (unsigned int)CommandLine.custompal[1]);
			fprintf(fo, "custom2light=0x%06X\n", (unsigned int)CommandLine.custompal[2]);
			fprintf(fo, "custom2dark=0x%06X\n", (unsigned int)CommandLine.custompal[3]);
			fprintf(fo, "multicart=%d\n", CommandLine.multicart);
			fprintf(fo, "synccycles=%d\n", CommandLine.synccycles);
			fprintf(fo, "lcdcontrast=%d\n", CommandLine.lcdcontrast);
			fprintf(fo, "lcdbright=%d\n", CommandLine.lcdbright);
			fclose(fo);
		}
	}

	// Platform config file
	if (CommandLine.conffile && CommandLine.confcustom) {
		PokeMini_GetCustomDir(tmp, PMTMPV);
		PokeMini_GotoExecDir();
		fo = fopen(CommandLine.conffile, "w");
		PokeMini_GotoCustomDir(tmp);

		if (fo) {
			fprintf(fo, "# Config file generated by PokeMini %s\n", PokeMini_Version);
			fprintf(fo, "# Read the documentation for full description of each item\n");
			fprintf(fo, "# Note that command-line will take priority\n\n");
			fprintf(fo, "# Platform options\n");
			custom = CommandLine.confcustom;
			for (i = 0; custom[i].type != COMMANDLINE_EOL; i++) {
				if (custom[i].name) {
					if (custom[i].type == COMMANDLINE_BOOL) {
						fprintf(fo, "%s=%s\n", custom[i].name, *custom[i].ref ? "yes" : "no");
					} else if (custom[i].type == COMMANDLINE_INT) {
						fprintf(fo, "%s=%d\n", custom[i].name, *custom[i].ref);
					} else if (custom[i].type == COMMANDLINE_STR) {
						fprintf(fo, "%s=%s\n", custom[i].name, (char *)custom[i].ref);
					}
				}
			}
			fclose(fo);
		}
	}

	// Post-save config callback
	if (PokeMini_PostConfigSave) {
		return PokeMini_PostConfigSave(fo != NULL, CommandLine.pokefile, CommandLine.conffile);
	}

	return (fo != NULL);
}

int CustomConfFile(const char *filename, const TCommandLineCustom *custom, TCustomConfCallback unknown)
{
	FILE *fi;
	char tmp[PMTMPV], *txt, *key, *value;

	fi = fopen(filename, "r");
	if (!fi) return 0;

	while ((txt = fgets(tmp, PMTMPV, fi)) != NULL) {
		// Remove comments
		RemoveComments(txt);

		// Break up key and value
		if (!SeparateAtChar(txt, '=', &key, &value)) continue;

		// Trim them
		key = TrimStr(key);
		value = TrimStr(value);

		// Decode key and set CommandLine
		if (!CommandLineCustomConfFile(key, value, custom)) {
			if (unknown) {
				if (!unknown(key, value, custom)) {
					fclose(fi);
					return 0;
				}
			}
		}
	}
	fclose(fi);

	return 1;
}

int CustomConfSave(const char *filename, const TCommandLineCustom *custom, const char *description)
{
	FILE *fo;
	int i;

	fo = fopen(filename, "w");
	if (!fo) return 0;

	fprintf(fo, "# Generated by PokeMini %s\n", PokeMini_Version);
	fprintf(fo, "# %s\n", description);
	for (i = 0; custom[i].type != COMMANDLINE_EOL; i++) {
		if (custom[i].name) {
			if (custom[i].type == COMMANDLINE_BOOL) {
				fprintf(fo, "%s=%s\n", custom[i].name, *custom[i].ref ? "yes" : "no");
			} else if (custom[i].type == COMMANDLINE_INT) {
				fprintf(fo, "%s=%d\n", custom[i].name, *custom[i].ref);
			} else if (custom[i].type == COMMANDLINE_STR) {
				fprintf(fo, "%s=%s\n", custom[i].name, (char *)custom[i].ref);
			}
		}
	}
	fclose(fo);

	return 1;
}

void PrintHelpUsage(FILE *fout)
{
	fprintf(fout, "Usage:\n");
	fprintf(fout, "PokeMini [Options] rom.min\n\n");
	fprintf(fout, "Options:\n");
	fprintf(fout, "  -freebios              Force FreeBIOS\n");
	fprintf(fout, "  -bios otherbios.min    Load BIOS file\n");
	fprintf(fout, "  -noeeprom              Discard EEPROM data\n");
	fprintf(fout, "  -eeprom pokemini.eep   Load/Save EEPROM file\n");
	fprintf(fout, "  -eepromshare           Share EEPROM to all ROMs\n");
	fprintf(fout, "  -noeepromshare         Individual EEPROM for each ROM (def)\n");
	fprintf(fout, "  -nostate               Discard auto-state save (def)\n");
	fprintf(fout, "  -state pokemini.sta    Load/Save auto-state file\n");
	fprintf(fout, "  -nortc                 No RTC\n");
	fprintf(fout, "  -statertc              RTC time difference in savestates\n");
	fprintf(fout, "  -hostrtc               RTC match the Host clock (def)\n");
	fprintf(fout, "  -nosound               Disable sound\n");
	fprintf(fout, "  -sound                 Same as -sounddirectpwm (def)\n");
	fprintf(fout, "  -sounddirect           Use timer 3 directly for sound (def)\n");
	fprintf(fout, "  -soundemulate          Emulate sound circuit\n");
	fprintf(fout, "  -sounddirectpwm        Same as direct, can play PWM samples\n");
	fprintf(fout, "  -nopiezo               Disable piezo speaker filter\n");
	fprintf(fout, "  -piezo                 Enable piezo speaker filter (def)\n");
	fprintf(fout, "  -scanline              50%% Scanline LCD filter\n");
	fprintf(fout, "  -dotmatrix             LCD dot-matrix filter (def)\n");
	fprintf(fout, "  -nofilter              No LCD filter\n");
	fprintf(fout, "  -2shades               LCD Mode: No mixing\n");
	fprintf(fout, "  -3shades               LCD Mode: Grey emulation\n");
	fprintf(fout, "  -analog                LCD Mode: Pretend real LCD (def)\n");
	fprintf(fout, "  -fullbattery           Emulate with a full battery (def)\n");
	fprintf(fout, "  -lowbattery            Emulate with a weak battery\n");
	fprintf(fout, "  -palette 0             Select palette for colors (0 to 15)\n");
	fprintf(fout, "  -rumblelvl 3           Rumble level (0 to 3)\n");
	fprintf(fout, "  -nojoystick            Disable joystick (def)\n");
	fprintf(fout, "  -joystick              Enable joystick\n");
	fprintf(fout, "  -joyid 0               Set joystick ID\n");
	fprintf(fout, "  -custom1light 0xFFFFFF Palette Custom 1 Light\n");
	fprintf(fout, "  -custom1dark 0x000000  Palette Custom 1 Dark\n");
	fprintf(fout, "  -custom2light 0xFFFFFF Palette Custom 2 Light\n");
	fprintf(fout, "  -custom2dark 0x000000  Palette Custom 2 Dark\n");
	fprintf(fout, "  -synccycles 8          Number of cycles per hardware sync.\n");
	fprintf(fout, "  -multicart 0           Multicart type (0 to 2)\n");
	fprintf(fout, "  -lcdcontrast 64        LCD contrast boost in percent\n");
	fprintf(fout, "  -lcdbright 0           LCD brightness offset in percent\n");
}

int PrintHelpUsageStr(char *out)
{
	if (out) {
		strcpy(out, "Usage:\n");
		strcat(out, "PokeMini [Options] rom.min\n\n");
		strcat(out, "Options:\n");
		strcat(out, "  -freebios              Force FreeBIOS\n");
		strcat(out, "  -bios otherbios.min    Load BIOS file\n");
		strcat(out, "  -noeeprom              Discard EEPROM data\n");
		strcat(out, "  -eeprom pokemini.eep   Load/Save EEPROM file\n");
		strcat(out, "  -eepromshare           Share EEPROM to all ROMs (def)\n");
		strcat(out, "  -noeepromshare         Individual EEPROM for each ROM (def)\n");
		strcat(out, "  -nostate               Discard auto-state save (def)\n");
		strcat(out, "  -state pokemini.sta    Load/Save auto-state file\n");
		strcat(out, "  -nortc                 No RTC\n");
		strcat(out, "  -statertc              RTC time difference in savestates\n");
		strcat(out, "  -hostrtc               RTC match the Host clock (def)\n");
		strcat(out, "  -nosound               Disable sound\n");
		strcat(out, "  -sound                 Same as -sounddirectpwm (def)\n");
		strcat(out, "  -sounddirect           Use timer 3 directly for sound (def)\n");
		strcat(out, "  -soundemulate          Emulate sound circuit\n");
		strcat(out, "  -sounddirectpwm        Same as direct, can play PWM samples\n");
		strcat(out, "  -nopiezo               Disable piezo speaker filter\n");
		strcat(out, "  -piezo                 Enable piezo speaker filter (def)\n");
		strcat(out, "  -scanline              50%% Scanline LCD filter\n");
		strcat(out, "  -dotmatrix             LCD dot-matrix filter (def)\n");
		strcat(out, "  -nofilter              No LCD filter\n");
		strcat(out, "  -2shades               LCD Mode: No mixing\n");
		strcat(out, "  -3shades               LCD Mode: Grey emulation\n");
		strcat(out, "  -analog                LCD Mode: Pretend real LCD (def)\n");
		strcat(out, "  -fullbattery           Emulate with a full battery (def)\n");
		strcat(out, "  -lowbattery            Emulate with a weak battery\n");
		strcat(out, "  -palette 0             Select palette for colors (0 to 15)\n");
		strcat(out, "  -rumblelvl 3           Rumble level (0 to 3)\n");
		strcat(out, "  -nojoystick            Disable joystick (def)\n");
		strcat(out, "  -joystick              Enable joystick\n");
		strcat(out, "  -joyid 0               Set joystick ID\n");
		strcat(out, "  -custom1light 0xFFFFFF Palette Custom 1 Light\n");
		strcat(out, "  -custom1dark 0x000000  Palette Custom 1 Dark\n");
		strcat(out, "  -custom2light 0xFFFFFF Palette Custom 2 Light\n");
		strcat(out, "  -custom2dark 0x000000  Palette Custom 2 Dark\n");
		strcat(out, "  -synccycles 8          Number of cycles per hardware sync.\n");
		strcat(out, "  -multicart 0           Multicart type (0 to 2)\n");
		strcat(out, "  -lcdcontrast 64        LCD contrast boost in percent\n");
		strcat(out, "  -lcdbright 0           LCD brightness offset in percent\n");
	}
	return 4096;
}
