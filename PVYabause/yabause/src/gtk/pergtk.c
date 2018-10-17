/*  Copyright 2005-2006 Guillaume Duhamel
    Copyright 2005-2006 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "pergtk.h"
#include <gtk/gtk.h>
#include "../yabause.h"
#include "../vdp2.h"
#include "../yui.h"

int PERGTKInit(void);
void PERGTKDeInit(void);
int PERGTKHandleEvents(void);

u32 PERGTKScan(u32 flags);
void PERGTKFlush(void);
void PERGTKKeyName(u32 key, char * name, int size);

PerInterface_struct PERGTK = {
PERCORE_GTK,
"GTK Input Interface",
PERGTKInit,
PERGTKDeInit,
PERGTKHandleEvents,
PERGTKScan,
0,
PERGTKFlush,
PERGTKKeyName
};

//////////////////////////////////////////////////////////////////////////////

int PERGTKInit(void) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERGTKDeInit(void) {
}

//////////////////////////////////////////////////////////////////////////////

int PERGTKHandleEvents(void) {
   YabauseExec();

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 PERGTKScan(u32 flags) {
	g_print("this is wrong, the gtk peripheral can't scan\n");
	return 1;
}

//////////////////////////////////////////////////////////////////////////////

void PERGTKFlush(void) {
}

//////////////////////////////////////////////////////////////////////////////

void PERGTKKeyName(u32 key, char * name, int size)
{
   g_strlcpy(name, gdk_keyval_name(key), size);
}
