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
#include "CustomPalEdit.h"

static int custompal[4];

LRESULT CALLBACK CustomPalEdit_cpaleditProc(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	HDC hDC;
	HBRUSH hOldBrs, hBrs;
	COLORREF bgcolor;
    PAINTSTRUCT ps;
	RECT rect;

	switch (Msg) {
	    case WM_NCCREATE:
			SetWindowLong(hWnd, 0, 0xFFFFFF);
			break;
		case WM_NCDESTROY:
			break;
		case WM_PAINT:
			hDC = BeginPaint(hWnd, &ps);
			GetClientRect(hWnd, &rect);

			// Draw the background
			bgcolor = (COLORREF)GetWindowLong(hWnd, 0);
			hBrs = CreateSolidBrush(bgcolor);
			hOldBrs = SelectObject(hDC, hBrs);
			Rectangle(hDC, 0, 0, rect.right, rect.bottom);
			SelectObject(hDC, hOldBrs);
			DeleteObject(hDC);

			EndPaint(hWnd, &ps);
			return FALSE;
		case WMC_SETCOLOR:
			bgcolor = (COLORREF)wParam;
			bgcolor = RGB(GetBValue(bgcolor), GetGValue(bgcolor), GetRValue(bgcolor));
			SetWindowLong(hWnd, 0, (LONG)bgcolor);
			return TRUE;
	}
	return DefWindowProc(hWnd, Msg, wParam, lParam);
}

void CustomPalEdit_Register(HINSTANCE hInst)
{
	WNDCLASSEX wcex;

	// Register Main Window Class
	ZeroMemory(&wcex, sizeof(WNDCLASSEX));
	wcex.cbSize = sizeof(WNDCLASSEX); 
	wcex.lpfnWndProc    = (WNDPROC)CustomPalEdit_cpaleditProc;
	wcex.hInstance      = hInst;
	wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
	wcex.lpszClassName  = "POKEMINI_cpaledit";
	wcex.cbWndExtra     = sizeof(COLORREF);
	RegisterClassEx(&wcex);
}

static void SetTrackbarSpecs(HWND hWndDlg, int DlgID_L, int DlgID_S, int colortype, int spos)
{
	char tmp[PMTMPV];

	SendDlgItemMessage(hWndDlg, DlgID_S, TBM_SETRANGE, FALSE, MAKELONG(0, 255));
	SendDlgItemMessage(hWndDlg, DlgID_S, TBM_SETPOS, TRUE, spos);
	switch (colortype) {
		case 2:
			sprintf_s(tmp, PMTMPV, "Blue: %i", spos);
			break;
		case 1:
			sprintf_s(tmp, PMTMPV, "Green: %i", spos);
			break;
		default:
			sprintf_s(tmp, PMTMPV, "Red: %i", spos);
			break;
	}
	SetDlgItemText(hWndDlg, DlgID_L, tmp);
}

LRESULT CALLBACK CustomPalEdit_DlgProc(HWND hWndDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	int spos, scolor;

	switch(Msg) {
		case WM_INITDIALOG:
			CopyMemory(custompal, CommandLine.custompal, sizeof(CommandLine.custompal));
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTRL, IDC_CUSTOM1LIGHTRS, 0, (custompal[0] >> 16) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTGL, IDC_CUSTOM1LIGHTGS, 1, (custompal[0] >> 8) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTBL, IDC_CUSTOM1LIGHTBS, 2, custompal[0] & 255);
			SendDlgItemMessage(hWndDlg, IDC_CUSTOM1LIGHTP, WMC_SETCOLOR, custompal[0], 0);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKRL, IDC_CUSTOM1DARKRS, 0, (custompal[1] >> 16) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKGL, IDC_CUSTOM1DARKGS, 1, (custompal[1] >> 8) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKBL, IDC_CUSTOM1DARKBS, 2, custompal[1] & 255);
			SendDlgItemMessage(hWndDlg, IDC_CUSTOM1DARKP, WMC_SETCOLOR, custompal[1], 0);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTRL, IDC_CUSTOM2LIGHTRS, 0, (custompal[2] >> 16) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTGL, IDC_CUSTOM2LIGHTGS, 1, (custompal[2] >> 8) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTBL, IDC_CUSTOM2LIGHTBS, 2, custompal[2] & 255);
			SendDlgItemMessage(hWndDlg, IDC_CUSTOM2LIGHTP, WMC_SETCOLOR, custompal[2], 0);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKRL, IDC_CUSTOM2DARKRS, 0, (custompal[3] >> 16) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKGL, IDC_CUSTOM2DARKGS, 1, (custompal[3] >> 8) & 255);
			SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKBL, IDC_CUSTOM2DARKBS, 2, custompal[3] & 255);
			SendDlgItemMessage(hWndDlg, IDC_CUSTOM2DARKP, WMC_SETCOLOR, custompal[3], 0);
			return TRUE;
		case WM_COMMAND:
			switch(wParam) {
				case IDOK:
					CopyMemory(CommandLine.custompal, custompal, sizeof(CommandLine.custompal));
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
				case IDC_CUSTOM1LIGHTRS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1LIGHTRS, TBM_GETPOS, 0, 0) & 255;
					custompal[0] &= 0x00FFFF;
					custompal[0] |= spos << 16;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTRL, IDC_CUSTOM1LIGHTRS, 0, spos);
					scolor = 0;
					break;
				case IDC_CUSTOM1LIGHTGS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1LIGHTGS, TBM_GETPOS, 0, 0) & 255;
					custompal[0] &= 0xFF00FF;
					custompal[0] |= spos << 8;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTGL, IDC_CUSTOM1LIGHTGS, 1, spos);
					scolor = 0;
					break;
				case IDC_CUSTOM1LIGHTBS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1LIGHTBS, TBM_GETPOS, 0, 0) & 255;
					custompal[0] &= 0xFFFF00;
					custompal[0] |= spos;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1LIGHTBL, IDC_CUSTOM1LIGHTBS, 2, spos);
					scolor = 0;
					break;
				case IDC_CUSTOM1DARKRS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1DARKRS, TBM_GETPOS, 0, 0) & 255;
					custompal[1] &= 0x00FFFF;
					custompal[1] |= spos << 16;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKRL, IDC_CUSTOM1DARKRS, 0, spos);
					scolor = 1;
					break;
				case IDC_CUSTOM1DARKGS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1DARKGS, TBM_GETPOS, 0, 0) & 255;
					custompal[1] &= 0xFF00FF;
					custompal[1] |= spos << 8;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKGL, IDC_CUSTOM1DARKGS, 1, spos);
					scolor = 1;
					break;
				case IDC_CUSTOM1DARKBS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM1DARKBS, TBM_GETPOS, 0, 0) & 255;
					custompal[1] &= 0xFFFF00;
					custompal[1] |= spos;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM1DARKBL, IDC_CUSTOM1DARKBS, 2, spos);
					scolor = 1;
					break;
				case IDC_CUSTOM2LIGHTRS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2LIGHTRS, TBM_GETPOS, 0, 0) & 255;
					custompal[2] &= 0x00FFFF;
					custompal[2] |= spos << 16;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTRL, IDC_CUSTOM2LIGHTRS, 0, spos);
					scolor = 2;
					break;
				case IDC_CUSTOM2LIGHTGS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2LIGHTGS, TBM_GETPOS, 0, 0) & 255;
					custompal[2] &= 0xFF00FF;
					custompal[2] |= spos << 8;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTGL, IDC_CUSTOM2LIGHTGS, 1, spos);
					scolor = 2;
					break;
				case IDC_CUSTOM2LIGHTBS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2LIGHTBS, TBM_GETPOS, 0, 0) & 255;
					custompal[2] &= 0xFFFF00;
					custompal[2] |= spos;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2LIGHTBL, IDC_CUSTOM2LIGHTBS, 2, spos);
					scolor = 2;
					break;
				case IDC_CUSTOM2DARKRS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2DARKRS, TBM_GETPOS, 0, 0) & 255;
					custompal[3] &= 0x00FFFF;
					custompal[3] |= spos << 16;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKRL, IDC_CUSTOM2DARKRS, 0, spos);
					scolor = 3;
					break;
				case IDC_CUSTOM2DARKGS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2DARKGS, TBM_GETPOS, 0, 0) & 255;
					custompal[3] &= 0xFF00FF;
					custompal[3] |= spos << 8;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKGL, IDC_CUSTOM2DARKGS, 0, spos);
					scolor = 3;
					break;
				case IDC_CUSTOM2DARKBS:
					spos = (int)SendDlgItemMessage(hWndDlg, IDC_CUSTOM2DARKBS, TBM_GETPOS, 0, 0) & 255;
					custompal[3] &= 0xFFFF00;
					custompal[3] |= spos;
					SetTrackbarSpecs(hWndDlg, IDC_CUSTOM2DARKBL, IDC_CUSTOM2DARKBS, 0, spos);
					scolor = 3;
					break;
			}
			switch (scolor) {
				case 0:
					SendDlgItemMessage(hWndDlg, IDC_CUSTOM1LIGHTP, WMC_SETCOLOR, custompal[0], 0);
					InvalidateRect(GetDlgItem(hWndDlg, IDC_CUSTOM1LIGHTP), NULL, FALSE);
				    UpdateWindow(GetDlgItem(hWndDlg, IDC_CUSTOM1LIGHTP));
					break;
				case 1:
					SendDlgItemMessage(hWndDlg, IDC_CUSTOM1DARKP, WMC_SETCOLOR, custompal[1], 0);
					InvalidateRect(GetDlgItem(hWndDlg, IDC_CUSTOM1DARKP), NULL, FALSE);
				    UpdateWindow(GetDlgItem(hWndDlg, IDC_CUSTOM1DARKP));
					break;
				case 2:
					SendDlgItemMessage(hWndDlg, IDC_CUSTOM2LIGHTP, WMC_SETCOLOR, custompal[2], 0);
					InvalidateRect(GetDlgItem(hWndDlg, IDC_CUSTOM2LIGHTP), NULL, FALSE);
				    UpdateWindow(GetDlgItem(hWndDlg, IDC_CUSTOM2LIGHTP));
					break;
				case 3:
					SendDlgItemMessage(hWndDlg, IDC_CUSTOM2DARKP, WMC_SETCOLOR, custompal[3], 0);
					InvalidateRect(GetDlgItem(hWndDlg, IDC_CUSTOM2DARKP), NULL, FALSE);
				    UpdateWindow(GetDlgItem(hWndDlg, IDC_CUSTOM2DARKP));
					break;
			}
			PokeMini_VideoPalette_Index(CommandLine.palette, custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
			render_dummyframe();
			break;
	}

	return FALSE;
}

void CustomPalEdit_Dialog(HINSTANCE hInst, HWND hParentWnd)
{
	CustomPalEdit_Register(hInst);
	DialogBox(hInst, MAKEINTRESOURCE(IDD_CUSTOMPALEDIT), hParentWnd, (DLGPROC)CustomPalEdit_DlgProc);
}
