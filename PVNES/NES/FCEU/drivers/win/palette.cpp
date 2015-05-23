#include "../../version.h"
#include "common.h"
#include "main.h"
#include "window.h"
#include "gui.h"

uint8 cpalette[192] = {0};

bool SetPalette(const char* nameo)
{
	FILE *fp;
	if((fp = FCEUD_UTF8fopen(nameo, "rb")))
	{
		fread(cpalette, 1, 192, fp);
		fclose(fp);
		FCEUI_SetPaletteArray(cpalette);
		eoptions |= EO_CPALETTE;
		return true;
	}
	else
	{
		FCEUD_PrintError("Error opening palette file!");
		return false;
	}
}

/**
* Prompts the user for a palette file and opens that file.
*
* @return Flag that indicates failure (0) or success (1)
**/
int LoadPaletteFile()
{
	const char filter[]="All usable files (*.pal)\0*.pal\0All Files (*.*)\0*.*\0\0";

	bool success = false;
	char nameo[2048];

	// Display open file dialog
	OPENFILENAME ofn;
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = FCEU_NAME" Open Palette File...";
	ofn.lpstrFilter = filter;
	nameo[0] = 0;
	ofn.lpstrFile = nameo;
	ofn.nMaxFile = 256;
	ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;
	ofn.lpstrInitialDir = 0;

	if(GetOpenFileName(&ofn))
	{
		success = SetPalette(nameo);
	}

	return success;
}

/**
* Callback function for the palette configuration dialog.
**/
BOOL CALLBACK PaletteConCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_INITDIALOG:

			if(ntsccol)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_ENABLED, BST_CHECKED);

			SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR, TBM_SETRANGE, 1, MAKELONG(0, 128));
			SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR, TBM_SETRANGE, 1, MAKELONG(0, 128));

			FCEUI_GetNTSCTH(&ntsctint, &ntschue);

			SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR, TBM_SETPOS, 1, ntsctint);
			SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR, TBM_SETPOS, 1, ntschue);

			if(force_grayscale)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_GRAYSCALE, BST_CHECKED);

			if (eoptions & EO_CPALETTE)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_CUSTOM, BST_CHECKED);

			CenterWindowOnScreen(hwndDlg);

			break;

		case WM_HSCROLL:
			ntsctint = SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR, TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			ntschue = SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR, TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			FCEUI_SetNTSCTH(ntsccol, ntsctint, ntschue);
			break;

		case WM_CLOSE:
		case WM_QUIT:
			goto gornk;

		case WM_COMMAND:
			if(!(wParam>>16))
			{
				switch(wParam&0xFFFF)
				{
					case CHECK_PALETTE_ENABLED:
						ntsccol ^= 1;
						FCEUI_SetNTSCTH(ntsccol, ntsctint, ntschue);
						break;

					case CHECK_PALETTE_GRAYSCALE:
						force_grayscale ^= 1;
						FCEUI_SetNTSCTH(ntsccol, ntsctint, ntschue);
						break;

					case BTN_PALETTE_LOAD:
						if(LoadPaletteFile())
							CheckDlgButton(hwndDlg, CHECK_PALETTE_CUSTOM, BST_CHECKED);
						break;

					case CHECK_PALETTE_CUSTOM:
					{
						if (eoptions & EO_CPALETTE)
						{
							// switch back to default palette
							FCEUI_SetPaletteArray(0);
							eoptions &= ~EO_CPALETTE;
						} else
						{
							// switch to custom, even if it isn't loaded yet
							FCEUI_SetPaletteArray(cpalette);
							eoptions |= EO_CPALETTE;
						}
						break;
					}

					case BUTTON_CLOSE:
gornk:
						DestroyWindow(hwndDlg);
						pwindow = 0; // Yay for user race conditions.
						break;
				}
			}
	}

	return 0;
}

/**
* Shows palette configuration dialog.
**/
void ConfigPalette()
{
	if(!pwindow)
	{
		pwindow=CreateDialog(fceu_hInstance, "PALCONFIG" ,0 , PaletteConCallB);
	}
	else
	{
		SetFocus(pwindow);
	}
}

