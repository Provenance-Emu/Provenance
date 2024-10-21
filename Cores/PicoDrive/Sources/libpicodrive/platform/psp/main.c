/*
 * PicoDrive
 * (C) notaz, 2007,2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "psp.h"
#include "emu.h"
#include "menu.h"
#include "mp3.h"
#include "../common/menu.h"
#include "../common/emu.h"
#include "../common/config.h"
#include "../common/lprintf.h"

#ifdef GPROF
#include <pspprof.h>
#endif

#ifdef GCOV
#include <stdio.h>
#include <stdlib.h>

void dummy(void)
{
	engineState = atoi(rom_fname_reload);
	setbuf(NULL, NULL);
	getenv(NULL);
}
#endif

int pico_main(void)
{
	psp_init();

	emu_prepareDefaultConfig();
	emu_ReadConfig(0, 0);
	config_readlrom(PicoConfigFile);

	emu_Init();
	menu_init();
	// moved to emu_Loop(), after CPU clock change..
	//mp3_init();

	engineState = PGS_Menu;

	for (;;)
	{
		switch (engineState)
		{
			case PGS_Menu:
#ifndef GPROF
				menu_loop();
#else
				strcpy(rom_fname_reload, rom_fname_loaded);
				engineState = PGS_ReloadRom;
#endif
				break;

			case PGS_ReloadRom:
				if (emu_reload_rom(rom_fname_reload)) {
					engineState = PGS_Running;
					if (mp3_last_error != 0)
						engineState = PGS_Menu; // send to menu to display mp3 error
				} else {
					lprintf("PGS_ReloadRom == 0\n");
					engineState = PGS_Menu;
				}
				break;

			case PGS_Suspending:
				while (engineState == PGS_Suspending)
					psp_wait_suspend();
				break;

			case PGS_SuspendWake:
				psp_unhandled_suspend = 0;
				psp_resume_suspend();
				emu_HandleResume();
				engineState = engineStateSuspend;
				break;

			case PGS_RestartRun:
				engineState = PGS_Running;

			case PGS_Running:
				if (psp_unhandled_suspend) {
					psp_unhandled_suspend = 0;
					psp_resume_suspend();
					emu_HandleResume();
					break;
				}
				pemu_loop();
#ifdef GPROF
				goto endloop;
#endif
				break;

			case PGS_Quit:
				goto endloop;

			default:
				lprintf("engine got into unknown state (%i), exitting\n", engineState);
				goto endloop;
		}
	}

	endloop:

	mp3_deinit();
	emu_Deinit();
#ifdef GPROF
	gprof_cleanup();
#endif
#ifndef GCOV
	psp_finish();
#endif

	return 0;
}

