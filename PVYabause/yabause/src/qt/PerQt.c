/*  Copyright 2005 Guillaume Duhamel
	Copyright 2005-2006 Theo Berkau
	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>

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
#include "PerQt.h"

int PERQTInit(void);
void PERQTDeInit(void);
int PERQTHandleEvents(void);

u32 PERQTScan(u32 flags);
void PERQTFlush(void);
void PERQTKeyName(u32 key, char *name, int size);

PerInterface_struct PERQT = {
PERCORE_QT,
"Qt Keyboard Input Interface",
PERQTInit,
PERQTDeInit,
PERQTHandleEvents,
PERQTScan,
0,
PERQTFlush,
PERQTKeyName
};

int PERQTInit(void)
{ return 0; }

void PERQTDeInit(void)
{}

int PERQTHandleEvents(void)
{
	if ( YabauseExec() != 0 )
		return -1;
	return 0;
}

u32 PERQTScan(u32 flags)
{ return 0; }

void PERQTFlush(void)
{}

void PERQTKeyName(u32 key, char *name, int size)    {
    snprintf(name, size, "%x", (unsigned int)key);
}
