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
#include <glob.h>

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

typedef struct
{
   int fd;
   int * axis;
   int axiscount;
} perlinuxjoy_struct;

static perlinuxjoy_struct * joysticks = NULL;
static int joycount = 0;

#define PACKEVENT(evt) ((evt.value < 0 ? 0x10000 : 0) | (evt.type << 8) | (evt.number))
#define THRESHOLD 1000
#define MAXAXIS 256

//////////////////////////////////////////////////////////////////////////////

static void LinuxJoyInit(perlinuxjoy_struct * joystick, const char * path)
{
   int i;
   int fd;
   int axisinit[MAXAXIS];
   struct js_event evt;
   size_t num_read;

   joystick->fd = open(path, O_RDONLY | O_NONBLOCK);

   if (joystick->fd == -1) return;

   joystick->axiscount = 0;

   while ((num_read = read(joystick->fd, &evt, sizeof(struct js_event))) > 0)
   {
      if (evt.type == (JS_EVENT_AXIS | JS_EVENT_INIT))
      {
         axisinit[evt.number] = evt.value;
         if (evt.number + 1 > joystick->axiscount)
         {
            joystick->axiscount = evt.number + 1;
         }
      }
   }

   if (joystick->axiscount > MAXAXIS) joystick->axiscount = MAXAXIS;

   joystick->axis = malloc(sizeof(int) * joystick->axiscount);
   for(i = 0;i < joystick->axiscount;i++)
   {
      joystick->axis[i] = axisinit[i];
   }
}

static void LinuxJoyDeInit(perlinuxjoy_struct * joystick)
{
   if (joystick->fd == -1) return;

   close(joystick->fd);
   free(joystick->axis);
}

static void LinuxJoyHandleEvents(perlinuxjoy_struct * joystick)
{
   struct js_event evt;
   size_t num_read;

   if (joystick->fd == -1) return;

   while ((num_read = read(joystick->fd, &evt, sizeof(struct js_event))) > 0)
   {
      if (evt.type == JS_EVENT_AXIS)
      {
         int initvalue;
         int disp;
         u8 axis = evt.number;

         if (axis >= joystick->axiscount) return;

         initvalue = joystick->axis[axis];
         disp = abs(initvalue - evt.value);
         if (disp < THRESHOLD) evt.value = 0;
         else if (evt.value < initvalue) evt.value = -1;
         else evt.value = 1;
      }

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
}

static int LinuxJoyScan(perlinuxjoy_struct * joystick)
{
   struct js_event evt;
   size_t num_read;

   if (joystick->fd == -1) return 0;

   if ((num_read = read(joystick->fd, &evt, sizeof(struct js_event))) <= 0) return 0;

   if (evt.type == JS_EVENT_AXIS)
   {
      int initvalue;
      int disp;
      u8 axis = evt.number;

      if (axis >= joystick->axiscount) return 0;

      initvalue = joystick->axis[axis];
      disp = abs(initvalue - evt.value);
      if (disp < THRESHOLD) return 0;
      else if (evt.value < initvalue) evt.value = -1;
      else evt.value = 1;
   }

   return PACKEVENT(evt);
}

static void LinuxJoyFlush(perlinuxjoy_struct * joystick)
{
   struct js_event evt;
   size_t num_read;

   if (joystick->fd == -1) return;

   while ((num_read = read(joystick->fd, &evt, sizeof(struct js_event))) > 0);
}

//////////////////////////////////////////////////////////////////////////////

int PERLinuxJoyInit(void)
{
   int i;
   int fd;
   glob_t globbuf;

   glob("/dev/input/js*", 0, NULL, &globbuf);

   joycount = globbuf.gl_pathc;
   joysticks = malloc(sizeof(perlinuxjoy_struct) * joycount);

   for(i = 0;i < globbuf.gl_pathc;i++)
      LinuxJoyInit(joysticks + i, globbuf.gl_pathv[i]);

   globfree(&globbuf);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxJoyDeInit(void)
{
   int i;

   for(i = 0;i < joycount;i++)
      LinuxJoyDeInit(joysticks + i);

   free(joysticks);
}

//////////////////////////////////////////////////////////////////////////////

int PERLinuxJoyHandleEvents(void)
{
   int i;

   for(i = 0;i < joycount;i++)
      LinuxJoyHandleEvents(joysticks + i);

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
   int i;

   for(i = 0;i < joycount;i++)
   {
      int ret = LinuxJoyScan(joysticks + i);
      if (ret != 0) return ret;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxJoyFlush(void) {
   int i;

   for (i = 0;i < joycount;i++)
      LinuxJoyFlush(joysticks + i);
}

//////////////////////////////////////////////////////////////////////////////

void PERLinuxKeyName(u32 key, char * name, UNUSED int size)
{
   sprintf(name, "%x", (int)key);
}
