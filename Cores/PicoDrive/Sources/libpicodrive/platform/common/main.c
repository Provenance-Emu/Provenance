/*
 * PicoDrive
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#ifdef USE_SDL
#include <SDL.h>
#endif

#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "menu_pico.h"
#include "emu.h"
#include "version.h"
#include <cpu/debug.h>

static int load_state_slot = -1;
char **g_argv;

void parse_cmd_line(int argc, char *argv[])
{
	int x, unrecognized = 0;

	for (x = 1; x < argc && !unrecognized; x++)
	{
		if (argv[x][0] == '-')
		{
			if (strcasecmp(argv[x], "-config") == 0) {
				if (x+1 < argc) { ++x; PicoConfigFile = argv[x]; }
			}
			else if (strcasecmp(argv[x], "-loadstate") == 0
				 || strcasecmp(argv[x], "-load") == 0)
			{
				if (x+1 < argc) { ++x; load_state_slot = atoi(argv[x]); }
			}
			else if (strcasecmp(argv[x], "-pdb") == 0) {
				if (x+1 < argc) { ++x; pdb_command(argv[x]); }
			}
			else if (strcasecmp(argv[x], "-pdb_connect") == 0) {
				if (x+2 < argc) { pdb_net_connect(argv[x+1], argv[x+2]); x += 2; }
			}
			else {
				unrecognized = plat_parse_arg(argc, argv, &x);
			}
		} else {
			FILE *f = fopen(argv[x], "rb");
			if (f) {
				fclose(f);
				rom_fname_reload = argv[x];
			}
			else
				unrecognized = 1;
			break;
		}
	}

	if (unrecognized) {
		printf("\n\n\nPicoDrive v" VERSION " (c) notaz, 2006-2009,2013\n");
		printf("usage: %s [options] [romfile]\n", argv[0]);
		printf("options:\n"
			" -config <file>    use specified config file instead of default 'config.cfg'\n"
			" -loadstate <num>  if ROM is specified, try loading savestate slot <num>\n");
		exit(1);
	}
}


int main(int argc, char *argv[])
{
	g_argv = argv;

	plat_early_init();

	in_init();
	//in_probe();

	plat_target_init();
	if (argc > 1)
		parse_cmd_line(argc, argv);

	plat_init();
	menu_init();

	emu_prep_defconfig(); // depends on input
	emu_read_config(NULL, 0);

	emu_init();

	engineState = rom_fname_reload ? PGS_ReloadRom : PGS_Menu;
	plat_video_menu_enter(0);

	if (engineState == PGS_ReloadRom)
	{
		plat_video_menu_begin();
		if (emu_reload_rom(rom_fname_reload)) {
			engineState = PGS_Running;
			if (load_state_slot >= 0) {
				state_slot = load_state_slot;
				emu_save_load_game(1, 0);
			}
		}
		plat_video_menu_end();
	}
	plat_video_menu_leave();

	for (;;)
	{
		switch (engineState)
		{
			case PGS_Menu:
				menu_loop();
				break;

			case PGS_TrayMenu:
				menu_loop_tray();
				break;

			case PGS_ReloadRom:
				if (emu_reload_rom(rom_fname_reload))
					engineState = PGS_Running;
				else {
					printf("PGS_ReloadRom == 0\n");
					engineState = PGS_Menu;
				}
				break;

			case PGS_RestartRun:
				engineState = PGS_Running;
				/* vvv fallthrough */

			case PGS_Running:
#ifdef GPERF
	ProfilerStart("gperf.out");
#endif
				emu_loop();
#ifdef GPERF
	ProfilerStop();
#endif
				break;

			case PGS_Quit:
				goto endloop;

			default:
				printf("engine got into unknown state (%i), exitting\n", engineState);
				goto endloop;
		}
	}

	endloop:

	emu_finish();
	plat_finish();
	plat_target_finish();

	return 0;
}
