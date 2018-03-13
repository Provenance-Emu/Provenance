#include "common.h"
#include "monitor.h"
#include "debugger.h"
#include "debuggersp.h"
#include "memwatch.h"
#include "../../fceu.h"
#include "../../debug.h"
#include "../../conddebug.h"
#include <assert.h>

HWND hMonitor = 0;
int monitor_open = 0;

#define NUMBER_OF_RULES 10

#define SIZE_OF_RAM 0x800

#define RULE_BOX_1 3000
#define RULE_INPUT_1 3010
#define RULE_BUTTON_1 3020
#define RESULTS_BOX 3100
#define RESULTS_LABEL 3101

#define RULE_UNKNOWN 0
#define RULE_EXACT 1
#define RULE_EXACT_NOT 2
#define RULE_LESS 3
#define RULE_LESS_EQUAL 4
#define RULE_EQUAL 5
#define RULE_NOT_EQUAL 6
#define RULE_GREATER_EQUAL 7
#define RULE_GREATER 8

const char* rule_strings[] = { "Any", "Exact value", "All but value", "Less than last value", "Less than or equal to last value", "Equal to last value", "Not equal to last value", "Greater than or equal to last value", "Greater than last value"  };

unsigned char snapshots[NUMBER_OF_RULES][SIZE_OF_RAM];// = { first_snapshot, second_snapshot, third_snapshot, fourth_snapshot, fifth_snapshot };

int Monitor_wndx=0, Monitor_wndy=0;
unsigned int last_button = 0;

BOOL verify_rule(unsigned int rule_number, unsigned int chosen_rule, unsigned int offset, unsigned int value)
{
	if ( chosen_rule == RULE_UNKNOWN )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_EXACT && snapshots[rule_number][offset] == value )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_EXACT_NOT && snapshots[rule_number][offset] != value )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_LESS && snapshots[rule_number][offset] < snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_LESS_EQUAL && snapshots[rule_number][offset] <= snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_GREATER && snapshots[rule_number][offset] > snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_GREATER_EQUAL && snapshots[rule_number][offset] >= snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_EQUAL && snapshots[rule_number][offset] == snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	else if ( chosen_rule == RULE_NOT_EQUAL && snapshots[rule_number][offset] != snapshots[rule_number - 1][offset] )
	{
		return TRUE;
	}
	
	return FALSE;
}

void UpdateControls(HWND hwndDlg, unsigned int rule)
{
	unsigned int i;
	
	for (i=RULE_BUTTON_1;i<RULE_BUTTON_1 + NUMBER_OF_RULES;i++)
	{
		EnableWindow( GetDlgItem( hwndDlg, i), i - RULE_BUTTON_1 <= rule + 1);
		EnableWindow( GetDlgItem( hwndDlg, i - RULE_BUTTON_1 + RULE_BOX_1), i - RULE_BUTTON_1 <= rule + 1);
	}
	
	char buffer[8];
	
	unsigned int results = SendDlgItemMessage(hwndDlg, RESULTS_BOX, LB_GETCOUNT, 0, 0);
	
	sprintf(buffer, "%u", results);
	
	SendDlgItemMessage(hwndDlg, RESULTS_LABEL, WM_SETTEXT, 0, (LPARAM)buffer);
}

BOOL updateResults(HWND hwndDlg, int rule)
{
	char buff[0x100];
	char buff2[0x100];
	char input_buff[8] = { 0 };
	
	int chosen_rules[NUMBER_OF_RULES] = { 0 };
	unsigned int values[NUMBER_OF_RULES] = { 0 };
	
	for (int i=0;i<sizeof(chosen_rules) && i <= rule;i++)
	{
		chosen_rules[i] = SendDlgItemMessage(hwndDlg, RULE_BOX_1 + i, CB_GETCURSEL, 0, 0);
		
		if ( chosen_rules[i] == RULE_EXACT || chosen_rules[i] == RULE_EXACT_NOT )
		{
			SendDlgItemMessage( hwndDlg, RULE_INPUT_1 + i, WM_GETTEXT, sizeof(buff) - 1, (LPARAM) input_buff );
			
			unsigned int len = strlen(input_buff);
			
			for (unsigned int j=0;j<len;j++)
			{
				if (isHex(input_buff[j]) == FALSE)
				{
					return FALSE;
				}
			}
			
			if (sscanf(input_buff, "%X", &values[i]) != 1)
			{
				return FALSE;
			}
		}
	}

	for (int i=0;i<SIZE_OF_RAM;i++)
	{
		snapshots[rule][i] = GetMem(i);
	}
	
	SendDlgItemMessage( hwndDlg, RESULTS_BOX, LB_RESETCONTENT, 0, 0 );
	
	for (int i=0;i<SIZE_OF_RAM;i++)
	{
		BOOL all_valid = TRUE;
	
		for (int current_rule=0;current_rule<=rule && all_valid;current_rule++)
		{
			all_valid = all_valid & verify_rule(current_rule, chosen_rules[current_rule], i, values[current_rule]);
		}
		
		if ( all_valid )
		{
			sprintf(buff, "%04X: %02X", i, snapshots[0][i]);
			
			for (int j=1;j<=rule;j++)
			{
				sprintf(buff2, " -> %02X", snapshots[j][i]);
				strcat(buff, buff2);
			}
			
			SendDlgItemMessage(hwndDlg, RESULTS_BOX, LB_ADDSTRING, 0, (LPARAM) buff);
		}
	}
	
	UpdateControls(hwndDlg, rule);
	
	return TRUE;
}

HFONT hNewFont;

void InitControls(HWND hwndDlg)
{
	int i, j;
	
	for (i=RULE_BOX_1;i<RULE_BOX_1 + NUMBER_OF_RULES;i++)
	{
		for (j=0;j<sizeof(rule_strings) / sizeof(*rule_strings);j++)
		{
			if ( i == RULE_BOX_1 && j > 2)
				break;
				
			SendDlgItemMessage( hwndDlg, i, (UINT) CB_ADDSTRING, 0,(LPARAM) rule_strings[j] );
		}
		
		SendDlgItemMessage(hwndDlg, i, CB_SETCURSEL, 0, 0);
		
		SendMessage(GetDlgItem(hwndDlg, i - RULE_BOX_1 + RULE_INPUT_1), EM_LIMITTEXT, 2, 0);
		
		EnableWindow( GetDlgItem( hwndDlg, i - RULE_BOX_1 + RULE_INPUT_1), FALSE );
		
		if ( i != RULE_BOX_1 )
		{
			EnableWindow( GetDlgItem( hwndDlg, i ), FALSE );
			EnableWindow( GetDlgItem( hwndDlg, i - RULE_BOX_1 + RULE_BUTTON_1), FALSE );
		}
	}
	
	LOGFONT lf;
	HFONT hFont = (HFONT)SendMessage(hwndDlg, WM_GETFONT, 0, 0);
	GetObject(hFont, sizeof(LOGFONT), &lf);
	strcpy(lf.lfFaceName,"Courier New");
	hNewFont = CreateFontIndirect(&lf);

//	HFONT hFont = CreateFont(0, 0, 0, 0, FW_THIN, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, 0, PROOF_QUALITY, DEFAULT_PITCH | FF_MODERN, "Courier New" ); 
	SendDlgItemMessage(hwndDlg, RESULTS_BOX, WM_SETFONT, (WPARAM)hNewFont, TRUE);
}

BOOL handleButtonClick(HWND hwndDlg, unsigned int button_id)
{
	unsigned int rule = button_id - RULE_BUTTON_1;
	
	return updateResults(hwndDlg, rule);
}

unsigned int ruleBox_to_ruleInput(unsigned int ruleBox)
{
	return ruleBox - RULE_BOX_1 + RULE_INPUT_1;
}

BOOL CALLBACK MonitorCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg) {
		case WM_MOVE: {
			if (!IsIconic(hwndDlg)) {
			RECT wrect;
			GetWindowRect(hwndDlg,&wrect);
			Monitor_wndx = wrect.left;
			Monitor_wndy = wrect.top;

			#ifdef WIN32
			WindowBoundsCheckNoResize(Monitor_wndx,Monitor_wndy,wrect.right);
			#endif
			}
			break;
		};

		case WM_INITDIALOG:
			if (Monitor_wndx==-32000) Monitor_wndx=0; //Just in case
			if (Monitor_wndy==-32000) Monitor_wndy=0;
			SetWindowPos(hwndDlg,0,Monitor_wndx,Monitor_wndy,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
			monitor_open = 1;
//			CenterWindow(hwndDlg);

			InitControls(hwndDlg);
			break;
		case WM_COMMAND:
			switch(HIWORD(wParam))
			{
				case BN_CLICKED:
					if ( GameInfo )
					{
						if ( !handleButtonClick(hwndDlg, LOWORD(wParam)) )
						{
							MessageBox(hwndDlg, "Invalid byte value", "Error", MB_OK | MB_ICONERROR);
						}
					}
					break;
				case CBN_SELCHANGE:
				{
					unsigned int sl = SendMessage((HWND)lParam, CB_GETCURSEL, 0, 0);
					
					EnableWindow(GetDlgItem(hwndDlg, ruleBox_to_ruleInput(LOWORD(wParam))), sl == RULE_EXACT || sl == RULE_EXACT_NOT);

					break;
				}
				case LBN_DBLCLK:
				{
					if (LOWORD(wParam) == RESULTS_BOX)
					{
						char str[259] = { 0 },str2[259] = { 0 };
						SendDlgItemMessage(hwndDlg,RESULTS_BOX,LB_GETTEXT,SendDlgItemMessage(hwndDlg,RESULTS_BOX,LB_GETCURSEL,0,0),(LPARAM)(LPCTSTR)str);
						strcpy(str2,str);
						str2[4] = 0;
						AddMemWatch(str2);
					}
				}
			}
			break;
		case WM_CLOSE:
		case WM_QUIT:
			DeleteObject(hNewFont);
			monitor_open = 0;
			DestroyWindow(hwndDlg);
			break;
	}
	return FALSE;
}

void DoByteMonitor()
{
	if (!monitor_open)
	{
		hMonitor = CreateDialog(fceu_hInstance,"MONITOR",NULL,MonitorCallB);
		ShowWindow(hMonitor, SW_SHOW);
//		SetWindowPos(hMonitor, HWND_TOP,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOOWNERZORDER);
	}
}
