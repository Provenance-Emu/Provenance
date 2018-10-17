/*  Copyright 2005 Guillaume Duhamel
    Copyright 2005-2006, 2013 Theo Berkau

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

#ifndef PERIPHERAL_H
#define PERIPHERAL_H

#include "core.h"
#include "smpc.h"
#include "yabause.h"

/** @defgroup peripheral Peripheral
 *
 * @brief This module provides two kind of functions
 * - peripheral core management functions
 * - controller ports management functions
 *
 * @{
 */

#define PERPAD				0x02
#define PERWHEEL			0x13
#define PERMISSIONSTICK	0x15
#define PER3DPAD			0x16
#define PERTWINSTICKS	0x19
#define PERGUN				0x25
#define PERKEYBOARD		0x34
#define PERMOUSE			0xE3

#define PERCORE_DEFAULT -1
#define PERCORE_DUMMY 0

extern PortData_struct PORTDATA1;
extern PortData_struct PORTDATA2;

#define PERSF_ALL       (0xFFFFFFFF)
#define PERSF_KEY       (1 << 0)
#define PERSF_BUTTON    (1 << 1)
#define PERSF_HAT       (1 << 2)
#define PERSF_AXIS      (1 << 3)
#define PERSF_MOUSEMOVE (1 << 4)

typedef struct
{
   int id;
   const char * Name;
   int (*Init)(void);
   void (*DeInit)(void);
   int (*HandleEvents)(void);
   u32 (*Scan)(u32 flags);
   int canScan;
   void (*Flush)(void);
   void (*KeyName)(u32 key, char * name, int size);
} PerInterface_struct;

/** @brief Pointer to the current peripheral core.
 *
 * You should not set this manually but use
 * PerInit() and PerDeInit() instead. */
extern PerInterface_struct * PERCore;

extern PerInterface_struct PERDummy;

/**
 * @brief Init a peripheral core
 *
 * Searches through the PERCoreList array for the given coreid.
 * If found, PERCore is set to the address of that core and
 * the core's Init function is called.
 * 
 * @param coreid the peripheral core to be used
 * @return 0 if core has been inited, -1 otherwise
 */
int PerInit(int coreid);
/**
 * @brief De-init a peripheral core
 *
 * Calls the core's DeInit callback and set PERCore to NULL.
 */
void PerDeInit(void);

/** @brief Adds a peripheral
 *
 * You shouldn't directly use this function but
 * PerPadAdd() or PerMouseAdd() instead.
 */
void * PerAddPeripheral(PortData_struct *port, int perid);
int PerGetId(void * peripheral);
void PerPortReset(void);
/**
 * Iterate the list of peripherals connected to a port
 * and flush them if necesseray. This is needed for mouses.
 */
void PerFlush(PortData_struct * port);

void PerKeyDown(u32 key);
void PerKeyUp(u32 key);
void PerSetKey(u32 key, u8 name, void * controller);
void PerAxisValue(u32 key, u8 val);
void PerAxisMove(u32 key, s32 dispx, s32 dispy);

/** @defgroup pad Pad
 *
 * @{
 */
#define PERPAD_UP	0
#define PERPAD_RIGHT	1
#define PERPAD_DOWN	2
#define PERPAD_LEFT	3
#define PERPAD_RIGHT_TRIGGER 4
#define PERPAD_LEFT_TRIGGER 5
#define PERPAD_START	6
#define PERPAD_A	7
#define PERPAD_B	8
#define PERPAD_C	9
#define PERPAD_X	10
#define PERPAD_Y	11
#define PERPAD_Z	12

extern const char * PerPadNames[14];

typedef struct
{
   u8 perid;
   u8 padbits[2];
} PerPad_struct;

/** @brief Adds a pad to one of the controller ports.
 *
 * @param port can be either &PORTDATA1 or &PORTDATA2
 * @return pointer to a PerPad_struct or NULL if it fails
 * */
PerPad_struct * PerPadAdd(PortData_struct * port);

void PerPadUpPressed(PerPad_struct * pad);
void PerPadUpReleased(PerPad_struct * pad);

void PerPadDownPressed(PerPad_struct * pad);
void PerPadDownReleased(PerPad_struct * pad);

void PerPadRightPressed(PerPad_struct * pad);
void PerPadRightReleased(PerPad_struct * pad);

void PerPadLeftPressed(PerPad_struct * pad);
void PerPadLeftReleased(PerPad_struct * pad);

void PerPadStartPressed(PerPad_struct * pad);
void PerPadStartReleased(PerPad_struct * pad);

void PerPadAPressed(PerPad_struct * pad);
void PerPadAReleased(PerPad_struct * pad);

void PerPadBPressed(PerPad_struct * pad);
void PerPadBReleased(PerPad_struct * pad);

void PerPadCPressed(PerPad_struct * pad);
void PerPadCReleased(PerPad_struct * pad);

void PerPadXPressed(PerPad_struct * pad);
void PerPadXReleased(PerPad_struct * pad);

void PerPadYPressed(PerPad_struct * pad);
void PerPadYReleased(PerPad_struct * pad);

void PerPadZPressed(PerPad_struct * pad);
void PerPadZReleased(PerPad_struct * pad);

void PerPadRTriggerPressed(PerPad_struct * pad);
void PerPadRTriggerReleased(PerPad_struct * pad);

void PerPadLTriggerPressed(PerPad_struct * pad);
void PerPadLTriggerReleased(PerPad_struct * pad);
/** @} */

/** @defgroup mouse Mouse
 *
 * @{
 * */
#define PERMOUSE_LEFT	13
#define PERMOUSE_MIDDLE	14
#define PERMOUSE_RIGHT	15
#define PERMOUSE_START	16
#define PERMOUSE_AXIS	17

extern const char * PerMouseNames[5];

typedef struct
{
   u8 perid;
   u8 mousebits[3];
} PerMouse_struct;

/** @brief Adds a mouse to one of the controller ports.
 *
 * @param port can be either &PORTDATA1 or &PORTDATA2
 * @return pointer to a PerMouse_struct or NULL if it fails
 * */
PerMouse_struct * PerMouseAdd(PortData_struct * port);

void PerMouseLeftPressed(PerMouse_struct * mouse);
void PerMouseLeftReleased(PerMouse_struct * mouse);

void PerMouseMiddlePressed(PerMouse_struct * mouse);
void PerMouseMiddleReleased(PerMouse_struct * mouse);

void PerMouseRightPressed(PerMouse_struct * mouse);
void PerMouseRightReleased(PerMouse_struct * mouse);

void PerMouseStartPressed(PerMouse_struct * mouse);
void PerMouseStartReleased(PerMouse_struct * mouse);

void PerMouseMove(PerMouse_struct * mouse, s32 dispx, s32 dispy);
/** @} */

/** @defgroup 3danalog 3DAnalog
 *
 * @{
 * */

#define PERANALOG_AXIS1	18
#define PERANALOG_AXIS2	19
#define PERANALOG_AXIS3	20
#define PERANALOG_AXIS4	21
#define PERANALOG_AXIS5	22
#define PERANALOG_AXIS6	23
#define PERANALOG_AXIS7	24

typedef struct
{
   u8 perid;
   u8 analogbits[9];
} PerAnalog_struct;

/** @brief Adds a Analog control pad to one of the controller ports.
 *
 * @param port can be either &PORTDATA1 or &PORTDATA2
 * @return pointer to a Per3DAnalog_struct or NULL if it fails
 * */

PerAnalog_struct * PerWheelAdd(PortData_struct * port);
PerAnalog_struct * PerMissionStickAdd(PortData_struct * port);
PerAnalog_struct * Per3DPadAdd(PortData_struct * port);
PerAnalog_struct * PerTwinSticksAdd(PortData_struct * port);

void PerAxis1Value(PerAnalog_struct * analog, u32 val);
void PerAxis2Value(PerAnalog_struct * analog, u32 val);
void PerAxis3Value(PerAnalog_struct * analog, u32 val);
void PerAxis4Value(PerAnalog_struct * analog, u32 val);
void PerAxis5Value(PerAnalog_struct * analog, u32 val);
void PerAxis6Value(PerAnalog_struct * analog, u32 val);
void PerAxis7Value(PerAnalog_struct * analog, u32 val);

/** @} */

/** @defgroup gun Gun
 *
 * @{
 * */

#define PERGUN_TRIGGER	25
#define PERGUN_START		27
#define PERGUN_AXIS		28

typedef struct
{
   u8 perid;
   u8 gunbits[5];
} PerGun_struct;

/** @brief Adds a Gun to one of the controller ports up to a maximum of one per port.
 *
 * @param port can be either &PORTDATA1 or &PORTDATA2
 * @return pointer to a PerGun_struct or NULL if it fails
 * */

PerGun_struct * PerGunAdd(PortData_struct * port);

void PerGunTriggerPressed(PerGun_struct * gun);
void PerGunTriggerReleased(PerGun_struct * gun);

void PerGunStartPressed(PerGun_struct * gun);
void PerGunStartReleased(PerGun_struct * gun);

void PerGunMove(PerGun_struct * gun, s32 dispx, s32 dispy);

/** @} */

/** @} */

#endif
