/*
 * PicoDrive
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <windows.h>

#include "giz.h"
#include "menu.h"
#include "emu.h"
#include "../common/menu.h"
#include "../common/emu.h"
#include "../common/config.h"
#include "version.h"


int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow)
{
	emu_prepareDefaultConfig();
	emu_ReadConfig(0, 0);
	config_readlrom(PicoConfigFile);
	giz_init(hInstance, hPrevInstance);
	emu_Init();
	menu_init();

	engineState = PGS_Menu;

	for (;;)
	{
		switch (engineState)
		{
			case PGS_Menu:
				menu_loop();
				break;

			case PGS_ReloadRom:
				if (emu_reload_rom(romFileName))
					engineState = PGS_Running;
				else {
					lprintf("PGS_ReloadRom == 0\n");
					engineState = PGS_Menu;
				}
				break;

			case PGS_RestartRun:
				engineState = PGS_Running;

			case PGS_Running:
				pemu_loop();
				break;

			case PGS_Quit:
				goto endloop;

			default:
				lprintf("engine got into unknown state (%i), exitting\n", engineState);
				goto endloop;
		}
	}

	endloop:

	emu_Deinit();
	giz_deinit();

	return 0;
}
