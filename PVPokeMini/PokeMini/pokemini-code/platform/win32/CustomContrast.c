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
#include <commctrl.h>
#include <stdio.h>

#include "PokeMini.h"
#include "PokeMini_Win32.h"
#include "CustomContrast.h"

int newcontrast;

static void SetTrackbarSpecs(HWND hWndDlg, int DlgID_T, int DlgID_S, int spos)
{
	char tmp[PMTMPV];
	SendDlgItemMessage(hWndDlg, DlgID_S, TBM_SETRANGE, FALSE, MAKELONG(0, 100));
	SendDlgItemMessage(hWndDlg, DlgID_S, TBM_SETPOS, TRUE, spos);
	sprintf_s(tmp, PMTMPV, "Contrast: %i%%", spos);
	SetDlgItemText(hWndDlg, DlgID_T, tmp);
}

LRESULT CALLBACK CustomContrast_DlgProc(HWND hWndDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	int spos;

	switch(Msg) {
		case WM_INITDIALOG:
			SetWindowText(hWndDlg, "Set new contrast...");
			newcontrast = CommandLine.lcdcontrast;
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOMSLIDERT, IDC_CUSTOMSLIDER, newcontrast);
			return TRUE;
		case WM_COMMAND:
			switch(wParam) {
				case IDOK:
					CommandLine.lcdcontrast = newcontrast;
					PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
					EndDialog(hWndDlg, 1);
					return TRUE;
				case IDCANCEL:
					PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
					EndDialog(hWndDlg, 0);
					return TRUE;
			}
			break;
		case WM_HSCROLL:
			switch (GetDlgCtrlID((HWND)lParam)) {
				case IDC_CUSTOMSLIDER:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOMSLIDER, TBM_GETPOS, 0, 0);
					if ((spos >= 0) && (spos <= 100)) newcontrast = spos;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOMSLIDERT, IDC_CUSTOMSLIDER, newcontrast);
					break;
			}
			PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, newcontrast, CommandLine.lcdbright);
			render_dummyframe();
			break;
	}

	return FALSE;
}

void CustomContrast_Dialog(HINSTANCE hInst, HWND hParentWnd)
{
	DialogBox(hInst, MAKEINTRESOURCE(IDD_CUSTOMSLIDER), hParentWnd, (DLGPROC)CustomContrast_DlgProc);
}
