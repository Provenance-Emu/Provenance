#ifndef _JOYSTICK_H_
#define _JOYSTICK_H_

#include "common.h"
#include "dinput.h"
#include "input.h"
#include "joystick.h"

int InitJoysticks(HWND wnd);
int KillJoysticks(void);

void BeginJoyWait(HWND hwnd);
int DoJoyWaitTest(GUID *guid, uint8 *devicenum, uint16 *buttonnum);
void EndJoyWait(HWND hwnd);

void JoyClearBC(ButtConfig *bc);

void UpdateJoysticks(void);
int DTestButtonJoy(ButtConfig *bc);

#define JOYBACKACCESS_OLDSTYLE 1
#define JOYBACKACCESS_TASEDITOR 2
void JoystickSetBackgroundAccessBit(int bit);
void JoystickClearBackgroundAccessBit(int bit);
void JoystickSetBackgroundAccess(bool on);

#endif
