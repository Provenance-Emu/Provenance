/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "PokeMini.h"
#include "CommandLine.h"

#include "Joystick.h"

// Temp joystick map
static int TMP_enable;
static int TMP_deviceid;
static int TMP_axis_dpad;
static int TMP_hats_dpad;
static int TMP_joy[10];
static int JoyTestMode = 0;
static int JoyLastButton = -1;
static int JoyLastXAxis = 0;
static int JoyLastYAxis = 0;
static int JoyLastHat = 0;
static int JoyDeadZone = 30000;
static int JoyAllowDisable = 1;
static char **Joybuttons_names = NULL;
static int Joybuttons_num = JOY_BUTTONS;
static TJoystickUpdateCB JoystickUpdateCB = NULL;
static const char *JoyLastIndexStr[] = {
	"None",
	"Left",
	"Right",
	"Up",
	"Down"
};

// Joystick menu
int UIItems_JoystickC(int index, int reason);
TUIMenu_Item UIItems_Joystick[] = {
	{ 0,  0, "Go back...", UIItems_JoystickC },
	{ 0,  1, "Apply changes...", UIItems_JoystickC },
	{ 0, 21, "Check inputs...", UIItems_JoystickC },
	{ 0,  2, "Enable Joystick: %s", UIItems_JoystickC },
	{ 0, 20, "Device Index: %i", UIItems_JoystickC },
	{ 0,  3, "Axis as D-Pad: %s", UIItems_JoystickC },
	{ 0,  4, "Hats as D-Pad: %s", UIItems_JoystickC },
	{ 0,  8, "Menu", UIItems_JoystickC },
	{ 0,  9, "A", UIItems_JoystickC },
	{ 0, 10, "B", UIItems_JoystickC },
	{ 0, 11, "C", UIItems_JoystickC },
	{ 0, 12, "Up", UIItems_JoystickC },
	{ 0, 13, "Down", UIItems_JoystickC },
	{ 0, 14, "Left", UIItems_JoystickC },
	{ 0, 15, "Right", UIItems_JoystickC },
	{ 0, 16, "Power", UIItems_JoystickC },
	{ 0, 17, "Shake", UIItems_JoystickC },
	{ 9,  0, "Joystick", UIItems_JoystickC }
};

static const char *PM_Keys[] = {
	"Menu",
	"A",
	"B",
	"C",
	"Up",
	"Down",
	"Left",
	"Right",
	"Power",
	"Shake"
};

int JoyTestButtons(int line, char *outtext)
{
	if (outtext == NULL) {
		JoyTestMode = line;
		return 0;
	}
	if (line == 0) {
		if (JoyLastButton == -1) {
			sprintf(outtext, "Last button: None");
		} else if (Joybuttons_names && (JoyLastButton < Joybuttons_num)) {
			sprintf(outtext, "Last button: %s", Joybuttons_names[JoyLastButton+1]);
		} else {
			sprintf(outtext, "Last button: %i", JoyLastButton);
		}
	}
	if (line == 1) sprintf(outtext, "Last hat: %s", JoyLastIndexStr[JoyLastHat]);
	if (line == 2) sprintf(outtext, "X-Axis: %i", JoyLastXAxis);
	if (line == 3) sprintf(outtext, "Y-Axis: %i", JoyLastYAxis);
	return line < 4;
}

int UIItems_JoystickC(int index, int reason)
{
	int i;
	if (reason == UIMENU_OK) {
		reason = UIMENU_RIGHT;
	}
	if (reason == UIMENU_CANCEL) {
		UIMenu_PrevMenu();
		return 1;
	}
	if (reason == UIMENU_LEFT) {
		switch (index) {
			case 2:
				TMP_enable = !TMP_enable;
				break;
			case 3:
				TMP_axis_dpad = !TMP_axis_dpad;
				break;
			case 4:
				TMP_hats_dpad = !TMP_hats_dpad;
				break;
			case 8: case 9: case 10: case 11:
			case 12: case 13: case 14: case 15:
			case 16: case 17:
				if (Joybuttons_names) {
					do {
						TMP_joy[index-8]--;
						if (TMP_joy[index-8] < -1) TMP_joy[index-8] = Joybuttons_num-1;
					} while (!Joybuttons_names[TMP_joy[index-8]+1]);
				} else {
					TMP_joy[index-8]--;
					if (TMP_joy[index-8] < -1) TMP_joy[index-8] = Joybuttons_num-1;
				}
				break;
			case 20:
				TMP_deviceid--;
				if (TMP_deviceid < 0) TMP_deviceid = 0;
				break;
		}
	}
	if (reason == UIMENU_RIGHT) {
		switch (index) {
			case 0: UIMenu_PrevMenu();
				break;
			case 1: CommandLine.joyenabled = TMP_enable;
				CommandLine.joyaxis_dpad = TMP_axis_dpad;
				CommandLine.joyhats_dpad = TMP_hats_dpad;
				CommandLine.joyid = TMP_deviceid;
				for (i=0; i<10; i++) {
					CommandLine.joybutton[i] = TMP_joy[i];
				}
				UIMenu_BeginMessage();
				UIMenu_SetMessage("Joystick definition..", 1);
				UIMenu_SetMessage("", 1);
				UIMenu_SetMessage("Changes applied!", 0);
				UIMenu_EndMessage(60);
				if (JoystickUpdateCB) JoystickUpdateCB(CommandLine.joyenabled, CommandLine.joyid);
				break;
			case 2:
				TMP_enable = !TMP_enable;
				break;
			case 3:
				TMP_axis_dpad = !TMP_axis_dpad;
				break;
			case 4:
				TMP_hats_dpad = !TMP_hats_dpad;
				break;
			case 8: case 9: case 10: case 11:
			case 12: case 13: case 14: case 15:
			case 16: case 17:
				if (Joybuttons_names) {
					do {
						TMP_joy[index-8]++;
						if (TMP_joy[index-8] >= Joybuttons_num) TMP_joy[index-8] = -1;
					} while (!Joybuttons_names[TMP_joy[index-8]+1]);
				} else {
					TMP_joy[index-8]++;
					if (TMP_joy[index-8] >= Joybuttons_num) TMP_joy[index-8] = -1;
				}
				break;
			case 20:
				TMP_deviceid++;
				if (TMP_deviceid >= 32) TMP_deviceid = 31;
				break;
			case 21:
				JoyLastButton = -1;
				JoyLastXAxis = 0;
				JoyLastYAxis = 0;
				JoyLastHat = 0;
				UIMenu_RealTimeMessage(JoyTestButtons);
				break;
		}
	}
	if (JoyAllowDisable) UIMenu_ChangeItem(UIItems_Joystick, 2, "Enable Joystick: %s", TMP_enable ? "Yes" : "No");
	else UIMenu_ChangeItem(UIItems_Joystick, 2, "Enable Joystick: Yes");
	UIMenu_ChangeItem(UIItems_Joystick, 3, "Axis as D-Pad: %s", TMP_axis_dpad ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Joystick, 4, "Hats as D-Pad: %s", TMP_hats_dpad ? "Yes" : "No");
	UIMenu_ChangeItem(UIItems_Joystick, 20, "Device Index: %i", TMP_deviceid);
	if (Joybuttons_names) {
		for (i=0; i<10; i++) {
			if (Joybuttons_names[TMP_joy[i]+1]) UIMenu_ChangeItem(UIItems_Joystick, i+8, "%s Key: %s", PM_Keys[i], Joybuttons_names[TMP_joy[i]+1]);
			else UIMenu_ChangeItem(UIItems_Joystick, i+8, "%s Key: Invalid", PM_Keys[i]);
		}
	} else {
		for (i=0; i<10; i++) {
			if (TMP_joy[i] == -1) UIMenu_ChangeItem(UIItems_Joystick, i+8, "%s Key: Off", PM_Keys[i]);
			else UIMenu_ChangeItem(UIItems_Joystick, i+8, "%s Key: Button %d", PM_Keys[i], TMP_joy[i]);
		}
	}
	return 1;
}

// Setup joystick
void JoystickSetup(char *platform, int allowdisable, int deadzone, char **bnames, int numbuttons, int *mapping)
{
	int i;
	if (strcmp(platform, CommandLine.joyplatform)) {
		// If platform doesn't match, load default buttons
		if (mapping) {
			for (i=0; i<10; i++) CommandLine.joybutton[i] = mapping[i];
		}
	}
	JoyAllowDisable = allowdisable;
	JoyDeadZone = deadzone;
	Joybuttons_names = bnames;
	Joybuttons_num = numbuttons;
	if (Joybuttons_num <= 0) Joybuttons_num = JOY_BUTTONS;
}

// Enter into the joystick menu
void JoystickEnterMenu(void)
{
	int i;
	TMP_enable = CommandLine.joyenabled;
	TMP_axis_dpad = CommandLine.joyaxis_dpad;
	TMP_hats_dpad = CommandLine.joyhats_dpad;
	for (i=0; i<10; i++) {
		if (CommandLine.joybutton[i] >= Joybuttons_num) TMP_joy[i] = -1;
		else TMP_joy[i] = CommandLine.joybutton[i];
	}
	UIMenu_LoadItems(UIItems_Joystick, 0);
}

// Register callback of when the joystick configs get updated
void JoystickUpdateCallback(TJoystickUpdateCB cb)
{
	JoystickUpdateCB = cb;
	if (JoystickUpdateCB) JoystickUpdateCB(CommandLine.joyenabled, CommandLine.joyid);
}

// Process joystick buttons packed in bits
void JoystickBitsEvent(uint32_t pressbits)
{
	static uint32_t lastpressbits;
	uint32_t maskbit, togglebits = pressbits ^ lastpressbits;
	int index, joybutton, pressed;

	if (!CommandLine.joyenabled && JoyAllowDisable) {
		lastpressbits = pressbits;
		return;
	}

	if (JoyTestMode) {
		pressed = pressbits & togglebits;
		for (index=0; index<32; index++) {
			if (pressed & (1 << index)) JoyLastButton = index;
		}
	}

	for (index=0; index<10; index++) {
		joybutton = CommandLine.joybutton[index];
		if (joybutton >= 0) {
			maskbit = (1 << joybutton);
			if (togglebits & maskbit) {
				if (index) {
					UIMenu_KeyEvent(index, (pressbits & maskbit) ? 1 : 0);
				} else {
					if (pressbits & maskbit) UI_Status = !UI_Status;
				}
			}
		}
	}

	lastpressbits = pressbits;
}

// Process joystick buttons
void JoystickButtonsEvent(int button, int pressed)
{
	int index;

	if (!CommandLine.joyenabled && JoyAllowDisable) return;

	if (pressed) JoyLastButton = button;

	for (index=0; index<10; index++) {
		if (CommandLine.joybutton[index] == button) {
			if (index) {
				UIMenu_KeyEvent(index, pressed);
			} else {
				if (pressed) UI_Status = !UI_Status;
			}
		}
	}
}

// Process joystick axis
void JoystickAxisEvent(int axis, int value)
{
	static int lastaxis0value = 0;
	static int lastaxis1value = 0;

	if (!CommandLine.joyenabled && JoyAllowDisable) {
		lastaxis1value = 0;
		lastaxis0value = 0;
		return;
	}

	if (axis) JoyLastYAxis = value;
	else JoyLastXAxis = value;

	if (CommandLine.joyaxis_dpad) {
		if (axis) {
			// Up and down
			if ((value < -JoyDeadZone) && (lastaxis1value >= -JoyDeadZone)) {
				UIMenu_KeyEvent(MINX_KEY_UP, 1);
			} else if ((value > JoyDeadZone) && (lastaxis1value <= JoyDeadZone)) {
				UIMenu_KeyEvent(MINX_KEY_DOWN, 1);
			} else if ((value > -JoyDeadZone) && (value <= JoyDeadZone) &&
				((lastaxis1value <= -JoyDeadZone) || (lastaxis1value >= JoyDeadZone))) {
				UIMenu_KeyEvent(MINX_KEY_UP, 0);
				UIMenu_KeyEvent(MINX_KEY_DOWN, 0);
			}
			lastaxis1value = value;
		} else {
			// Left and right
			if ((value < -JoyDeadZone) && (lastaxis0value >= -JoyDeadZone)) {
				UIMenu_KeyEvent(MINX_KEY_LEFT, 1);
			} else if ((value > JoyDeadZone) && (lastaxis0value <= JoyDeadZone)) {
				UIMenu_KeyEvent(MINX_KEY_RIGHT, 1);
			} else if ((value > -JoyDeadZone) && (value <= JoyDeadZone) &&
				((lastaxis0value <= -JoyDeadZone) || (lastaxis0value >= JoyDeadZone))) {
				UIMenu_KeyEvent(MINX_KEY_LEFT, 0);
				UIMenu_KeyEvent(MINX_KEY_RIGHT, 0);
			}
			lastaxis0value = value;
		}
	}
}

// Process joystick hats
#define HAT_ONPRESS(a)		((hatsbitfield & (a)) && !(lasthatvalue & (a)))
#define HAT_ONRELEASE(a)	(!(hatsbitfield & (a)) && (lasthatvalue & (a)))
#define HAT_ONCHANGE(a)		((hatsbitfield & (a)) ^ (lasthatvalue & (a)))
void JoystickHatsEvent(int hatsbitfield)
{
	static int lasthatvalue = 0;

	if (!CommandLine.joyenabled && JoyAllowDisable) {
		lasthatvalue = hatsbitfield;
		return;
	}

	if (CommandLine.joyhats_dpad) {
		if (HAT_ONCHANGE(JHAT_LEFT)) {
			if (HAT_ONPRESS(JHAT_LEFT)) { UIMenu_KeyEvent(MINX_KEY_LEFT, 1); JoyLastHat = 0; }
			if (HAT_ONRELEASE(JHAT_LEFT)) UIMenu_KeyEvent(MINX_KEY_LEFT, 0);
		}
		if (HAT_ONCHANGE(JHAT_RIGHT)) {
			if (HAT_ONPRESS(JHAT_RIGHT)) { UIMenu_KeyEvent(MINX_KEY_RIGHT, 1); JoyLastHat = 1; }
			if (HAT_ONRELEASE(JHAT_RIGHT)) UIMenu_KeyEvent(MINX_KEY_RIGHT, 0);
		}
		if (HAT_ONCHANGE(JHAT_UP)) {
			if (HAT_ONPRESS(JHAT_UP)) { UIMenu_KeyEvent(MINX_KEY_UP, 1); JoyLastHat = 2; }
			if (HAT_ONRELEASE(JHAT_UP)) UIMenu_KeyEvent(MINX_KEY_UP, 0);
		}
		if (HAT_ONCHANGE(JHAT_DOWN)) {
			if (HAT_ONPRESS(JHAT_DOWN)) { UIMenu_KeyEvent(MINX_KEY_DOWN, 1); JoyLastHat = 3; }
			if (HAT_ONRELEASE(JHAT_DOWN)) UIMenu_KeyEvent(MINX_KEY_DOWN, 0);
		}
	}
	lasthatvalue = hatsbitfield;
}
