/*  This file was imported form CrabEmu ( http://crabemu.sourceforge.net/ ) --
    A Sega Master System emulator for Mac OS X (among other targets). The rest
    of the file is left intact from CrabEmu to make things easier if this were
    to be upgraded in the future. */

/*
    This file is part of CrabEmu.

    Copyright (C) 2008 Lawrence Sebald

    CrabEmu is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2 
    as published by the Free Software Foundation.

    CrabEmu is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with CrabEmu; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#ifndef JOYSTICK_H
#define JOYSTICK_H

#include <IOKit/hid/IOHIDLib.h>

/* Values for the joy_elemdata_t type element. */
#define JOY_TYPE_NOT_APPLICABLE 0
#define JOY_TYPE_X_AXIS         1
#define JOY_TYPE_Y_AXIS         2
#define JOY_TYPE_Z_AXIS         3
#define JOY_TYPE_X2_AXIS        4
#define JOY_TYPE_Y2_AXIS        5
#define JOY_TYPE_Z2_AXIS        6

/* Structure for holding basic information about each element. */
typedef struct joy_elemdata_s   {
    IOHIDElementCookie cookie;
    int type;
    int number;
    int min;
    int max;
} joy_elemdata_t;

/* Structure for holding information about each joystick connected. */
typedef struct joydata_s    {
    IOHIDDeviceInterface **iface;
    int open;
    int buttons_count;
    int axes_count;
    int hats_count;

    joy_elemdata_t *buttons;
    joy_elemdata_t *axes;
    joy_elemdata_t *hats;

    char name[256];
} joydata_t;

/* Values for hat switches. ORed together and returned from joy_read_hat. */
#define JOY_HAT_CENTER  0
#define JOY_HAT_UP      (1 << 0)
#define JOY_HAT_DOWN    (1 << 1)
#define JOY_HAT_RIGHT   (1 << 2)
#define JOY_HAT_LEFT    (1 << 3)

/* Scan the system for any joysticks connected. */
int joy_scan_joysticks(void);

/* Clean up any data allocated by the program for joysticks. */
void joy_release_joysticks(void);

/* Get the joystick at a given index in our list of joysticks. */
joydata_t *joy_get_joystick(int index);

/* Grab the device for exclusive use by this program. The device must be closed
   properly (with the joy_close_joystick function, or you may need to
   unplug/replug the joystick to get it to work again). */
int joy_open_joystick(joydata_t *joy);

/* Close the device and return its resources to the system. */
int joy_close_joystick(joydata_t *joy);

/* Read a given element from the joystick. The joystick must be open for this
   function to actually do anything useful. */
int joy_read_element(joydata_t *joy, joy_elemdata_t *elem);

/* Read the value of a given button. Returns -1 on failure. */
int joy_read_button(joydata_t *joy, int num);

/* Read the value of a given axis. Returns 0 on failure (or if the axis reports
   that its value is 0). */
int joy_read_axis(joydata_t *joy, int index);

/* Read the value of a given hat. Returns -1 on failure. */
int joy_read_hat(joydata_t *joy, int index);

#endif /* !JOYSTICK_H */
