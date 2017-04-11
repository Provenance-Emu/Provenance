/*  Copyright 2009 Guillaume Duhamel

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
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "debug.h"
#include "perlinuxjoy.h"
#include <linux/joystick.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int  PERLinuxJoyInit(void);
void PERLinuxJoyDeInit(void);
int  PERLinuxJoyHandleEvents(void);
u32  PERLinuxJoyScan(u32 flags);
void PERLinuxJoyFlush(void);
void PERLinuxKeyName(u32 key, char * name, int size);

PerInterface_struct PERLinuxJoy = {
PERCORE_LINUXJOY,
"Linux Joystick Interface",
PERLinuxJoyInit,
PERLinuxJoyDeInit,
PERLinuxJoyHandleEvents,
PERLinuxJoyScan,
1,
PERLinuxJoyFlush,
PERLinuxKeyName
};

static int hJOY = -1;

#define PACKEVENT(evt) ((evt.value < 0 ? 0x10000 : 0) | (evt.type << 8) | (evt.number))

//////////////////////////////////////////////////////////////////////////////

int PERLinuxJoyInit(void)
{
   hJOY = open("/dev/input/js0", O_RDONLY | O_NONBLOCK);

   if (hJOY == -1) return -1;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxJoyDeInit(void)
{
   if (hJOY != -1) close(hJOY);
}

//////////////////////////////////////////////////////////////////////////////

int PERLinuxJoyHandleEvents(void)
{
   struct js_event evt;

   if (hJOY == -1) return -1;

   while (read(hJOY, &evt, sizeof(struct js_event)) > 0)
   {
      if (evt.value != 0)
      {
         PerKeyDown(PACKEVENT(evt));
      }
      else
      {
         PerKeyUp(PACKEVENT(evt));
         PerKeyUp(0x10000 | PACKEVENT(evt));
      }
   }

   // execute yabause
   if ( YabauseExec() != 0 )
   {
      return -1;
   }
   
   // return success
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 PERLinuxJoyScan(u32 flags) {
   struct js_event evt;

   if (hJOY == -1) return 0;

   if (read(hJOY, &evt, sizeof(struct js_event)) <= 0) return 0;

   return PACKEVENT(evt);
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxJoyFlush(void) {
   struct js_event evt;

   if (hJOY == -1) return;

   while (read(hJOY, &evt, sizeof(struct js_event)) > 0);
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxKeyName(u32 key, char * name, UNUSED int size)
{
   sprintf(name, "%x", (int)key);
}
