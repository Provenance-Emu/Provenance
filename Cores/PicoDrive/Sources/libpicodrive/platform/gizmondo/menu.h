/*
 * PicoDrive
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

void menu_loop(void);
int  menu_loop_tray(void);
void menu_romload_prepare(const char *rom_name);
void menu_romload_end(void);


#define CONFIGURABLE_KEYS \
	(PBTN_UP|PBTN_DOWN|PBTN_LEFT|PBTN_RIGHT|PBTN_STOP|PBTN_PLAY|PBTN_FWD|PBTN_REW| \
		PBTN_L|PBTN_R|PBTN_VOLUME|PBTN_BRIGHTNESS|PBTN_ALARM)

