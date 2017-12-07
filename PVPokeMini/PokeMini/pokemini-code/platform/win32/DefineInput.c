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

#include <windows.h>
#include <stdio.h>

#include "PokeMini.h"
#include "PokeMini_Win32.h"
#include "Joystick_DInput.h"
#include "Joystick.h"
#include "Keyboard.h"

static void ComboSetIndex(HWND hWndDlg, int nIDDlgItem, int index)
{
	SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_SETCURSEL, index, 0);
}

static int ComboGetIndex(HWND hWndDlg, int nIDDlgItem)
{
	return (int)SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_GETCURSEL, 0, 0);
}

// ----- Keyboard -----

static void ComboFillKeyAndSet(HWND hWndDlg, int nIDDlgItem, int index)
{
	int i;
	for (i=0; i<PMKEYB_EOL; i++) {
		SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_ADDSTRING, 0, (LPARAM)KeyboardMapStr[i]);
	}
	SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_SETCURSEL, index, 0);
}


LRESULT CALLBACK DefineKeyboard_DlgProc(HWND hWndDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	switch(Msg) {
		case WM_INITDIALOG:
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_MENU, CommandLine.keyb_a[0]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_MENU, CommandLine.keyb_b[0]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_A, CommandLine.keyb_a[1]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_A, CommandLine.keyb_b[1]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_B, CommandLine.keyb_a[2]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_B, CommandLine.keyb_b[2]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_C, CommandLine.keyb_a[3]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_C, CommandLine.keyb_b[3]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_UP, CommandLine.keyb_a[4]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_UP, CommandLine.keyb_b[4]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_DOWN, CommandLine.keyb_a[5]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_DOWN, CommandLine.keyb_b[5]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_LEFT, CommandLine.keyb_a[6]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_LEFT, CommandLine.keyb_b[6]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_RIGHT, CommandLine.keyb_a[7]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_RIGHT, CommandLine.keyb_b[7]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_POWER, CommandLine.keyb_a[8]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_POWER, CommandLine.keyb_b[8]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC1_SHAKE, CommandLine.keyb_a[9]);
			ComboFillKeyAndSet(hWndDlg, IDC_KEYC2_SHAKE, CommandLine.keyb_b[9]);
			return TRUE;
		case WM_COMMAND:
			switch(wParam) {
				case IDOK:
					CommandLine.keyb_a[0] = ComboGetIndex(hWndDlg, IDC_KEYC1_MENU);
					CommandLine.keyb_b[0] = ComboGetIndex(hWndDlg, IDC_KEYC2_MENU);
					CommandLine.keyb_a[1] = ComboGetIndex(hWndDlg, IDC_KEYC1_A);
					CommandLine.keyb_b[1] = ComboGetIndex(hWndDlg, IDC_KEYC2_A);
					CommandLine.keyb_a[2] = ComboGetIndex(hWndDlg, IDC_KEYC1_B);
					CommandLine.keyb_b[2] = ComboGetIndex(hWndDlg, IDC_KEYC2_B);
					CommandLine.keyb_a[3] = ComboGetIndex(hWndDlg, IDC_KEYC1_C);
					CommandLine.keyb_b[3] = ComboGetIndex(hWndDlg, IDC_KEYC2_C);
					CommandLine.keyb_a[4] = ComboGetIndex(hWndDlg, IDC_KEYC1_UP);
					CommandLine.keyb_b[4] = ComboGetIndex(hWndDlg, IDC_KEYC2_UP);
					CommandLine.keyb_a[5] = ComboGetIndex(hWndDlg, IDC_KEYC1_DOWN);
					CommandLine.keyb_b[5] = ComboGetIndex(hWndDlg, IDC_KEYC2_DOWN);
					CommandLine.keyb_a[6] = ComboGetIndex(hWndDlg, IDC_KEYC1_LEFT);
					CommandLine.keyb_b[6] = ComboGetIndex(hWndDlg, IDC_KEYC2_LEFT);
					CommandLine.keyb_a[7] = ComboGetIndex(hWndDlg, IDC_KEYC1_RIGHT);
					CommandLine.keyb_b[7] = ComboGetIndex(hWndDlg, IDC_KEYC2_RIGHT);
					CommandLine.keyb_a[8] = ComboGetIndex(hWndDlg, IDC_KEYC1_POWER);
					CommandLine.keyb_b[8] = ComboGetIndex(hWndDlg, IDC_KEYC2_POWER);
					CommandLine.keyb_a[9] = ComboGetIndex(hWndDlg, IDC_KEYC1_SHAKE);
					CommandLine.keyb_b[9] = ComboGetIndex(hWndDlg, IDC_KEYC2_SHAKE);
					KeyboardRemap(NULL);
					EndDialog(hWndDlg, 1);
					return TRUE;
				case IDCANCEL:
					EndDialog(hWndDlg, 0);
					return TRUE;
			}
			break;
	}

	return FALSE;
}

void DefineKeyboard_Dialog(HINSTANCE hInst, HWND hParentWnd)
{
	DialogBox(hInst, MAKEINTRESOURCE(IDD_KEYDEF), hParentWnd, (DLGPROC)DefineKeyboard_DlgProc);
}

// ----- Joystick -----

static void ComboFillJoyDeviceAndSet(HWND hWndDlg, int nIDDlgItem, int index)
{
	int i;
	for (i=0; i<8; i++) {
		SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_ADDSTRING, 0, (LPARAM)Joystick_DInput_JoystickName(i));
	}
	SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_SETCURSEL, index, 0);
}

static void ComboFillJoyAndSet(HWND hWndDlg, int nIDDlgItem, int index)
{
	char tmp[PMTMPV];
	int i;
	for (i=-1; i<32; i++) {
		if (i == -1) strcpy_s(tmp, PMTMPV, "Off");
		else sprintf_s(tmp, PMTMPV, "Button %i", i);
		SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_ADDSTRING, 0, (LPARAM)tmp);
	}
	SendDlgItemMessage(hWndDlg, nIDDlgItem, CB_SETCURSEL, index, 0);
}

LRESULT CALLBACK DefineJoystick_DlgProc(HWND hWndDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	switch(Msg) {
		case WM_INITDIALOG:
			if (CommandLine.joyenabled) SendDlgItemMessage(hWndDlg, IDC_ENABLEJOY, BM_SETCHECK, BST_CHECKED, 0);
			ComboFillJoyDeviceAndSet(hWndDlg, IDC_JOYDEVSELECT, CommandLine.joyid);
			if (CommandLine.joyaxis_dpad) SendDlgItemMessage(hWndDlg, IDC_AXISASDPAD, BM_SETCHECK, BST_CHECKED, 0);
			if (CommandLine.joyhats_dpad) SendDlgItemMessage(hWndDlg, IDC_HATSASDPAD, BM_SETCHECK, BST_CHECKED, 0);
			if (wclc_forcefeedback) SendDlgItemMessage(hWndDlg, IDC_FORCEFEEDBACK, BM_SETCHECK, BST_CHECKED, 0);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_MENU, CommandLine.joybutton[0]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_A, CommandLine.joybutton[1]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_B, CommandLine.joybutton[2]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_C, CommandLine.joybutton[3]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_UP, CommandLine.joybutton[4]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_DOWN, CommandLine.joybutton[5]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_LEFT, CommandLine.joybutton[6]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_RIGHT, CommandLine.joybutton[7]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_POWER, CommandLine.joybutton[8]);
			ComboFillJoyAndSet(hWndDlg, IDC_KEYC1_SHAKE, CommandLine.joybutton[9]);
			return TRUE;
		case WM_COMMAND:
			switch(wParam) {
				case IDOK:
					CommandLine.joyenabled = SendDlgItemMessage(hWndDlg, IDC_ENABLEJOY, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0;
					CommandLine.joyaxis_dpad = SendDlgItemMessage(hWndDlg, IDC_AXISASDPAD, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0;
					CommandLine.joyhats_dpad = SendDlgItemMessage(hWndDlg, IDC_HATSASDPAD, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0;
					wclc_forcefeedback = SendDlgItemMessage(hWndDlg, IDC_FORCEFEEDBACK, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0;
					CommandLine.joybutton[0] = ComboGetIndex(hWndDlg, IDC_KEYC1_MENU);
					CommandLine.joybutton[1] = ComboGetIndex(hWndDlg, IDC_KEYC1_A);
					CommandLine.joybutton[2] = ComboGetIndex(hWndDlg, IDC_KEYC1_B);
					CommandLine.joybutton[3] = ComboGetIndex(hWndDlg, IDC_KEYC1_C);
					CommandLine.joybutton[4] = ComboGetIndex(hWndDlg, IDC_KEYC1_UP);
					CommandLine.joybutton[5] = ComboGetIndex(hWndDlg, IDC_KEYC1_DOWN);
					CommandLine.joybutton[6] = ComboGetIndex(hWndDlg, IDC_KEYC1_LEFT);
					CommandLine.joybutton[7] = ComboGetIndex(hWndDlg, IDC_KEYC1_RIGHT);
					CommandLine.joybutton[8] = ComboGetIndex(hWndDlg, IDC_KEYC1_POWER);
					CommandLine.joybutton[9] = ComboGetIndex(hWndDlg, IDC_KEYC1_SHAKE);
					Joystick_DInput_JoystickClose();
					if (CommandLine.joyenabled) {
						if (!Joystick_DInput_JoystickOpen(CommandLine.joyid)) {
							MessageBox(hWndDlg, "Couldn't open joystick", "Warning", MB_ICONWARNING);
						}
					}
					EndDialog(hWndDlg, 1);
					return TRUE;
				case IDCANCEL:
					EndDialog(hWndDlg, 0);
					return TRUE;
			}
			break;
	}

	return FALSE;
}

void DefineJoystick_Dialog(HINSTANCE hInst, HWND hParentWnd)
{
	DialogBox(hInst, MAKEINTRESOURCE(IDD_JOYDEF), hParentWnd, (DLGPROC)DefineJoystick_DlgProc);
}
