#include "../../version.h"
#include "common.h"
#include "main.h"
#include "window.h"
#include "gui.h"

int cpalette_count = 0;
u8 cpalette[64*8*3] = {0};
extern int palnotch;
extern int palsaturation;
extern int palsharpness;
extern int palcontrast;
extern int palbrightness;
extern bool paldeemphswap;

bool SetPalette(const char* nameo)
{
	FILE *fp;
	if((fp = FCEUD_UTF8fopen(nameo, "rb")))
	{
		int readed = fread(cpalette, 1, sizeof(cpalette), fp);
		fclose(fp);
		cpalette_count = readed/3;
		FCEUI_SetUserPalette(cpalette,cpalette_count);
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
	char text[40];
	switch(uMsg)
	{
		case WM_INITDIALOG:

			if(ntsccol_enable)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_ENABLED, BST_CHECKED);

			if(paldeemphswap)
				CheckDlgButton(hwndDlg, CHECK_DEEMPH_SWAP, BST_CHECKED);

			if(force_grayscale)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_GRAYSCALE, BST_CHECKED);

			if (eoptions & EO_CPALETTE)
				CheckDlgButton(hwndDlg, CHECK_PALETTE_CUSTOM, BST_CHECKED);

			SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR,       TBM_SETRANGE, 1, MAKELONG(0, 128));
			SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR,        TBM_SETRANGE, 1, MAKELONG(0, 128));
			SendDlgItemMessage(hwndDlg, CTL_PALNOTCH_TRACKBAR,   TBM_SETRANGE, 1, MAKELONG(0, 100));
			SendDlgItemMessage(hwndDlg, CTL_PALSAT_TRACKBAR,     TBM_SETRANGE, 1, MAKELONG(0, 200));
			SendDlgItemMessage(hwndDlg, CTL_PALSHARP_TRACKBAR,   TBM_SETRANGE, 1, MAKELONG(0,  50));
			SendDlgItemMessage(hwndDlg, CTL_PALCONTRAST_TRACKBAR,TBM_SETRANGE, 1, MAKELONG(0, 200));
			SendDlgItemMessage(hwndDlg, CTL_PALBRIGHT_TRACKBAR,  TBM_SETRANGE, 1, MAKELONG(0, 100));

			FCEUI_GetNTSCTH(&ntsctint, &ntschue);
			sprintf(text, "Notch: %d%", palnotch);
			SendDlgItemMessage(hwndDlg, STATIC_NOTCHVALUE,   WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Saturation: %d%%", palsaturation);
			SendDlgItemMessage(hwndDlg, STATIC_SATVALUE,     WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Sharpness: %d%", palsharpness);
			SendDlgItemMessage(hwndDlg, STATIC_SHARPVALUE,   WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Contrast: %d%", palcontrast);
			SendDlgItemMessage(hwndDlg, STATIC_CONTRASTVALUE,WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Brightness: %d%", palbrightness);
			SendDlgItemMessage(hwndDlg, STATIC_BRIGHTVALUE,  WM_SETTEXT, 0, (LPARAM) text);

			SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR,       TBM_SETPOS, 1, ntsctint);
			SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR,        TBM_SETPOS, 1, ntschue);
			SendDlgItemMessage(hwndDlg, CTL_PALNOTCH_TRACKBAR,   TBM_SETPOS, 1, palnotch);
			SendDlgItemMessage(hwndDlg, CTL_PALSAT_TRACKBAR,     TBM_SETPOS, 1, palsaturation);
			SendDlgItemMessage(hwndDlg, CTL_PALSHARP_TRACKBAR,   TBM_SETPOS, 1, palsharpness);
			SendDlgItemMessage(hwndDlg, CTL_PALCONTRAST_TRACKBAR,TBM_SETPOS, 1, palcontrast);
			SendDlgItemMessage(hwndDlg, CTL_PALBRIGHT_TRACKBAR,  TBM_SETPOS, 1, palbrightness);

			CenterWindowOnScreen(hwndDlg);

			break;

		case WM_HSCROLL:
			ntsctint      = SendDlgItemMessage(hwndDlg, CTL_TINT_TRACKBAR,       TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			ntschue       = SendDlgItemMessage(hwndDlg, CTL_HUE_TRACKBAR,        TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			palnotch      = SendDlgItemMessage(hwndDlg, CTL_PALNOTCH_TRACKBAR,   TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			palsaturation = SendDlgItemMessage(hwndDlg, CTL_PALSAT_TRACKBAR,     TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			palsharpness  = SendDlgItemMessage(hwndDlg, CTL_PALSHARP_TRACKBAR,   TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			palcontrast   = SendDlgItemMessage(hwndDlg, CTL_PALCONTRAST_TRACKBAR,TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			palbrightness = SendDlgItemMessage(hwndDlg, CTL_PALBRIGHT_TRACKBAR,  TBM_GETPOS, 0, (LPARAM)(LPSTR)0);
			FCEUI_SetNTSCTH(ntsccol_enable, ntsctint, ntschue);

			sprintf(text, "Notch: %d%", palnotch);
			SendDlgItemMessage(hwndDlg, STATIC_NOTCHVALUE,   WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Saturation: %d%%", palsaturation);
			SendDlgItemMessage(hwndDlg, STATIC_SATVALUE,     WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Sharpness: %d%", palsharpness);
			SendDlgItemMessage(hwndDlg, STATIC_SHARPVALUE,   WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Contrast: %d%", palcontrast);
			SendDlgItemMessage(hwndDlg, STATIC_CONTRASTVALUE,WM_SETTEXT, 0, (LPARAM) text);
			sprintf(text, "Brightness: %d%", palbrightness);
			SendDlgItemMessage(hwndDlg, STATIC_BRIGHTVALUE,  WM_SETTEXT, 0, (LPARAM) text);
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
						ntsccol_enable ^= 1;
						FCEUI_SetNTSCTH(ntsccol_enable, ntsctint, ntschue); // it recalculates everything, use it for PAL block too!
						break;

					case CHECK_PALETTE_GRAYSCALE:
						force_grayscale ^= 1;
						FCEUI_SetNTSCTH(ntsccol_enable, ntsctint, ntschue);
						break;

					case CHECK_DEEMPH_SWAP:
						paldeemphswap ^= 1;
						FCEUI_SetNTSCTH(ntsccol_enable, ntsctint, ntschue);
						break;

					case CHECK_PALETTE_CUSTOM:
					{
						if (eoptions & EO_CPALETTE)
						{
							//disable user palette
							FCEUI_SetUserPalette(0,0);
							eoptions &= ~EO_CPALETTE;
						} else
						{
							//switch to user palette (even if it isn't loaded yet!?)
							FCEUI_SetUserPalette(cpalette,64); //just have to guess the size I guess
							eoptions |= EO_CPALETTE;
						}
						break;
					}

					case BTN_PALETTE_LOAD:
						if(LoadPaletteFile())
							CheckDlgButton(hwndDlg, CHECK_PALETTE_CUSTOM, BST_CHECKED);
						break;

					case BTN_PALETTE_RESET:
						palnotch      = 90;
						palsaturation = 100;
						palsharpness  = 50;
						palcontrast   = 100;
						palbrightness = 50;

						sprintf(text, "Notch: %d%", palnotch);
						SendDlgItemMessage(hwndDlg, STATIC_NOTCHVALUE, WM_SETTEXT, 0, (LPARAM) text);
						sprintf(text, "Saturation: %d%%", palsaturation);
						SendDlgItemMessage(hwndDlg, STATIC_SATVALUE, WM_SETTEXT, 0, (LPARAM) text);
						sprintf(text, "Sharpness: %d%", palsharpness);
						SendDlgItemMessage(hwndDlg, STATIC_SHARPVALUE, WM_SETTEXT, 0, (LPARAM) text);
						sprintf(text, "Contrast: %d%", palcontrast);
						SendDlgItemMessage(hwndDlg, STATIC_CONTRASTVALUE,WM_SETTEXT, 0, (LPARAM) text);
						sprintf(text, "Brightness: %d%", palbrightness);
						SendDlgItemMessage(hwndDlg, STATIC_BRIGHTVALUE,  WM_SETTEXT, 0, (LPARAM) text);

						SendDlgItemMessage(hwndDlg, CTL_PALNOTCH_TRACKBAR,   TBM_SETPOS, 1, palnotch);
						SendDlgItemMessage(hwndDlg, CTL_PALSAT_TRACKBAR,     TBM_SETPOS, 1, palsaturation);
						SendDlgItemMessage(hwndDlg, CTL_PALSHARP_TRACKBAR,   TBM_SETPOS, 1, palsharpness);
						SendDlgItemMessage(hwndDlg, CTL_PALCONTRAST_TRACKBAR,TBM_SETPOS, 1, palcontrast);
						SendDlgItemMessage(hwndDlg, CTL_PALBRIGHT_TRACKBAR,  TBM_SETPOS, 1, palbrightness);

						FCEUI_SetNTSCTH(ntsccol_enable, ntsctint, ntschue);
						break;

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

