#include "common.h"
#include "main.h"
#include "gui.h"
#include "resource.h"

/**
* This function is called when the dialog closes.
*
* @param hwndDlg Handle of the timing dialog.
**/
void CloseTimingDialog(HWND hwndDlg)
{
	if(IsDlgButtonChecked(hwndDlg, CB_SET_HIGH_PRIORITY) == BST_CHECKED)
	{
		eoptions |= EO_HIGHPRIO;
	}
	else
	{
		eoptions &= ~EO_HIGHPRIO;
	}

	if(IsDlgButtonChecked(hwndDlg, CB_DISABLE_SPEED_THROTTLING)==BST_CHECKED)
	{
		eoptions |= EO_NOTHROTTLE;
	}
	else
	{
		eoptions &= ~EO_NOTHROTTLE;
	}

	EndDialog(hwndDlg, 0);
}

/**
* Callback function of the Timing configuration dialog.
**/
BOOL CALLBACK TimingConCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_INITDIALOG:            

			// Update controls to the current settings.
			if(eoptions & EO_HIGHPRIO)
			{
				CheckDlgButton(hwndDlg, CB_SET_HIGH_PRIORITY, BST_CHECKED);
			}

			if(eoptions & EO_NOTHROTTLE)
			{
				CheckDlgButton(hwndDlg, CB_DISABLE_SPEED_THROTTLING, BST_CHECKED);
			}

			CenterWindowOnScreen(hwndDlg);

			break;

		case WM_CLOSE:
		case WM_QUIT:
			CloseTimingDialog(hwndDlg);
			break;

		case WM_COMMAND:

			if(!(wParam >> 16))
			{
				switch(wParam & 0xFFFF)
				{
					case 1:
						CloseTimingDialog(hwndDlg);
						break;
				}
			}
	}

	return 0;
}

void DoTimingConfigFix()
{
	DoPriority();
}

/**
* Shows the Timing configuration dialog.
**/
void ConfigTiming()
{
	DialogBox(fceu_hInstance, "TIMINGCONFIG", hAppWnd, TimingConCallB);  
	DoTimingConfigFix();
}

