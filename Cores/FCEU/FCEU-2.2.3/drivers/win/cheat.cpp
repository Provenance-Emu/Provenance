/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Ben Parnell
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "common.h"
#include "cheat.h"
#include "memview.h"
#include "memwatch.h"
#include "debugger.h"
#include "../../fceu.h"
#include "../../cart.h"
#include "../../cheat.h" // For FCEU_LoadGameCheats()

static HWND pwindow = 0;	    //Handle to Cheats dialog
HWND hCheat = 0;			    //mbg merge 7/19/06 had to add
static HMENU hCheatcontext;     //Handle to context menu
static HMENU hCheatcontextsub;  //Handle to context sub menu

void InitializeCheatsAdded(HWND hwndDlg);

bool pauseWhileActive = false;	//For checkbox "Pause while active"
extern bool wasPausedByCheats;

int CheatWindow;
int CheatStyle=1;

#define GGLISTSIZE 128 //hopefully this is enough for all cases

int selcheat;
int selcheatcount;
int ChtPosX,ChtPosY;
int GGConv_wndx=0, GGConv_wndy=0;
static HFONT hFont,hNewFont;

static int scrollindex;
static int scrollnum;
static int scrollmax;

int lbfocus=0;
int searchdone;
static int knownvalue=0;

int GGaddr, GGcomp, GGval;
char GGcode[10];
int GGlist[GGLISTSIZE];
static int dontupdateGG; //this eliminates recursive crashing

bool dodecode;

HWND hGGConv;

void EncodeGG(char *str, int a, int v, int c);
void ListGGAddresses();

uint16 StrToU16(char *s)
{
	unsigned int ret=0;
	sscanf(s,"%4x",&ret);
	return ret;
}

uint8 StrToU8(char *s)
{
	unsigned int ret=0;
	sscanf(s,"%2x",&ret);
	return ret;
}

char *U16ToStr(uint16 a)
{
	static char str[5];
	sprintf(str,"%04X",a);
	return str;
}

char *U8ToStr(uint8 a)
{
	static char str[3];
	sprintf(str,"%02X",a);
	return str;
}

static HWND hwndLB;
//int RedoCheatsCallB(char *name, uint32 a, uint8 v, int s) { //bbit edited: this commented out line was changed to the below for the new fceud
int RedoCheatsCallB(char *name, uint32 a, uint8 v, int c, int s, int type, void*data)
{
	char str[259] = { 0 };

	strcpy(str,(s?"* ":"  "));
	if(name[0] == 0) {
		if(a >= 0x8000) {
			EncodeGG(str+2, a, v, c);
		} else {
			if(c == -1) sprintf(str+2,"%04X:%02X",(int)a,(int)v);
			else sprintf(str+2,"%04X?%02X:%02X",(int)a,(int)c,(int)v);
		}
	}
	else strcat(str,name);

	SendDlgItemMessage(hwndLB,IDC_LIST_CHEATS,LB_ADDSTRING,0,(LPARAM)(LPSTR)str);
	return 1;
}

void RedoCheatsLB(HWND hwndDlg)
{
	SendDlgItemMessage(hwndDlg, IDC_LIST_CHEATS, LB_RESETCONTENT, 0, 0);
	hwndLB = hwndDlg;
	FCEUI_ListCheats(RedoCheatsCallB, 0);

	if (selcheat >= 0)
	{
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_DEL), TRUE);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_UPD), TRUE);
	} else
	{
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_DEL), FALSE);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_UPD), FALSE);
	}
}

int ShowResultsCallB(uint32 a, uint8 last, uint8 current)
{
	char temp[16];

	sprintf(temp,"$%04X:  %02X | %02X",(unsigned int)a,last,current);
	SendDlgItemMessage(hwndLB,IDC_CHEAT_LIST_POSSIBILITIES,LB_ADDSTRING,0,(LPARAM)(LPSTR)temp);
	return 1;
}

void ShowResults(HWND hwndDlg)
{
	int n=FCEUI_CheatSearchGetCount();
	int t;
	char str[20];

	scrollnum=n;
	scrollindex=-32768;

	hwndLB=hwndDlg;
	SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,0,0);
	FCEUI_CheatSearchGetRange(0,16,ShowResultsCallB);

	t=-32768+n-17;
	if (t<-32768) t=-32768;
	scrollmax=t;
	SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETRANGE,-32768,t);
	SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,-32768,1);

	sprintf(str,"%d Possibilities",n);
	SetDlgItemText(hwndDlg,IDC_CHEAT_BOX_POSSIBILITIES,str);
}

void EnableCheatButtons(HWND hwndDlg, int enable)
{
	EnableWindow(GetDlgItem(hwndDlg,IDC_CHEAT_VAL_KNOWN),enable);
	EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_KNOWN),enable);
	EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_EQ),enable);
	EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_NE),enable);
	EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_GT),enable);
	EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_LT),enable);
}

BOOL CALLBACK CheatConsoleCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	LOGFONT lf;
	RECT wrect;

	char str[259] = { 0 },str2[259] = { 0 };

	char *name;
	uint32 a;
	uint8 v;
	int c;
	int s;

	switch (uMsg)
	{
		case WM_INITDIALOG:
			if (ChtPosX==-32000) ChtPosX=0; //Just in case
			if (ChtPosY==-32000) ChtPosY=0;
			SetWindowPos(hwndDlg,0,ChtPosX,ChtPosY,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
			
			CheckDlgButton(hwndDlg, IDC_CHEAT_PAUSEWHENACTIVE, pauseWhileActive ? MF_CHECKED : MF_UNCHECKED);

			//setup font
			hFont = (HFONT)SendMessage(hwndDlg, WM_GETFONT, 0, 0);
			GetObject(hFont, sizeof(LOGFONT), &lf);
			strcpy(lf.lfFaceName,"Courier New");
			hNewFont = CreateFontIndirect(&lf);

			SendDlgItemMessage(hwndDlg,IDC_CHEAT_ADDR,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_COM,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_KNOWN,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_NE_BY,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_GT_BY,WM_SETFONT,(WPARAM)hNewFont,FALSE);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_LT_BY,WM_SETFONT,(WPARAM)hNewFont,FALSE);

			//text limits
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_ADDR,EM_SETLIMITTEXT,4,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL,EM_SETLIMITTEXT,2,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_COM,EM_SETLIMITTEXT,2,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_NAME,EM_SETLIMITTEXT,256,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_KNOWN,EM_SETLIMITTEXT,2,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_NE_BY,EM_SETLIMITTEXT,2,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_GT_BY,EM_SETLIMITTEXT,2,0);
			SendDlgItemMessage(hwndDlg,IDC_CHEAT_VAL_LT_BY,EM_SETLIMITTEXT,2,0);

			//disable or enable buttons
			EnableWindow(GetDlgItem(hwndDlg,IDC_CHEAT_VAL_KNOWN),FALSE);
			if (scrollnum)
			{
				EnableCheatButtons(hwndDlg,TRUE);
				ShowResults(hwndDlg);
				sprintf(str,"%d Possibilities",(int)FCEUI_CheatSearchGetCount());
				SetDlgItemText(hwndDlg,IDC_CHEAT_BOX_POSSIBILITIES,str);
			}
			else EnableCheatButtons(hwndDlg,FALSE);

			//misc setup
			searchdone=0;
			SetDlgItemText(hwndDlg,IDC_CHEAT_VAL_KNOWN,(LPTSTR)U8ToStr(knownvalue));
			// Enable Context Sub-Menus
			hCheatcontext = LoadMenu(fceu_hInstance,"CHEATCONTEXTMENUS");

			break;

		case WM_KILLFOCUS:
			break;

		case WM_NCACTIVATE:
			if (pauseWhileActive) 
			{
				if (EmulationPaused == 0) 
				{
					EmulationPaused = 1;
					wasPausedByCheats = true;
					FCEU_printf("Emulation paused: %d\n", EmulationPaused);
				}
			
			}
			if ((CheatStyle) && (scrollnum)) {
				if ((!wParam) && (searchdone)) {
					searchdone=0;
					FCEUI_CheatSearchSetCurrentAsOriginal();
				}
				ShowResults(hwndDlg);   
			}
			break;

		case WM_CLOSE:
		case WM_QUIT:
			CheatWindow=0;
			hCheat = 0;
			if (CheatStyle) DestroyWindow(hwndDlg);
			else EndDialog(hwndDlg,0);
			DeleteObject(hFont);
			DeleteObject(hNewFont);
			if (searchdone) FCEUI_CheatSearchSetCurrentAsOriginal();
			break;

		case WM_MOVE:
			if (!IsIconic(hwndDlg)) {
			GetWindowRect(hwndDlg,&wrect);
			ChtPosX = wrect.left;
			ChtPosY = wrect.top;

			#ifdef WIN32
			WindowBoundsCheckNoResize(ChtPosX,ChtPosY,wrect.right);
			#endif
			}
			break;

		case WM_VSCROLL:
			if (scrollnum > 16) {
 				switch (LOWORD(wParam)) {
					case SB_TOP:
						scrollindex=-32768;
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,16,0);
						FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						break;
					case SB_BOTTOM:
						scrollindex=scrollmax;
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,16,0);
						FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						break;
					case SB_LINEUP:
						if (scrollindex > -32768) {
							scrollindex--;
							SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
							SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,16,0);
							FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						}
						break;
					case SB_PAGEUP:
						scrollindex-=17;
						if(scrollindex<-32768) scrollindex=-32768;
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,16,0);
						FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						break;

					case SB_LINEDOWN:
						if (scrollindex<scrollmax) {
							scrollindex++;
							SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
							SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,0,0);
							FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						}
						break;
					case SB_PAGEDOWN:
						scrollindex+=17;
						if (scrollindex>scrollmax) scrollindex=scrollmax;
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,0,0);
						FCEUI_CheatSearchGetRange(scrollindex+32768,scrollindex+32768+16,ShowResultsCallB);
						break;
					case SB_THUMBPOSITION:
					case SB_THUMBTRACK:
						scrollindex=(short int)HIWORD(wParam);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_SCRL_POSSIBILITIES,SBM_SETPOS,scrollindex,1);
						SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_RESETCONTENT,0,0);
						FCEUI_CheatSearchGetRange(32768+scrollindex,32768+scrollindex+16,ShowResultsCallB);
						break;
				}

			}
			break;

		case WM_VKEYTOITEM:
			if (lbfocus) {
				int real;

				real=SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_GETCURSEL,0,0);
				switch (LOWORD(wParam)) {
					case VK_UP:
						// mmmm....recursive goodness
						if (real == 0) SendMessage(hwndDlg,WM_VSCROLL,SB_LINEUP,0);
						return -1;
						break;
					case VK_DOWN:
						if (real == 16) {
							SendMessage(hwndDlg,WM_VSCROLL,SB_LINEDOWN,0);
							SendDlgItemMessage(hwndDlg,IDC_CHEAT_LIST_POSSIBILITIES,LB_SETCURSEL,real,0);
						}
						return -1;
						break;
					case VK_PRIOR:
						SendMessage(hwndDlg,WM_VSCROLL,SB_PAGEUP,0);
						break;
					case VK_NEXT:
						SendMessage(hwndDlg,WM_VSCROLL,SB_PAGEDOWN,0);
						break;
					case VK_HOME:
						SendMessage(hwndDlg,WM_VSCROLL,SB_TOP,0);
						break;
					case VK_END:
						SendMessage(hwndDlg,WM_VSCROLL,SB_BOTTOM,0);
						break;
				}
				return -2;
			}
			break;

		case WM_CONTEXTMENU:
		{
			// Handle certain subborn context menus for nearly incapable controls.

			if (wParam == (uint32)GetDlgItem(hwndDlg,IDC_LIST_CHEATS)) {
				// Only open the menu if a cheat is selected
				if (selcheat >= 0) {
					// Open IDC_LIST_CHEATS Context Menu
					hCheatcontextsub = GetSubMenu(hCheatcontext,0);
					SetMenuDefaultItem(hCheatcontextsub, CHEAT_CONTEXT_TOGGLECHEAT, false);
					if (lParam != -1)
						TrackPopupMenu(hCheatcontextsub,TPM_RIGHTBUTTON,LOWORD(lParam),HIWORD(lParam),0,hwndDlg,0);	//Create menu
					else { // Handle the context menu keyboard key
						GetWindowRect(GetDlgItem(hwndDlg,IDC_LIST_CHEATS), &wrect);
						TrackPopupMenu(hCheatcontextsub,TPM_RIGHTBUTTON,wrect.left + int((wrect.right - wrect.left) / 3),wrect.top + int((wrect.bottom - wrect.top) / 3),0,hwndDlg,0);	//Create menu
					}

				}
			}
		
		}
		break;

		case WM_COMMAND:
			switch (HIWORD(wParam)) {
				case BN_CLICKED:
					switch (LOWORD(wParam)) {
						case CHEAT_CONTEXT_TOGGLECHEAT:
							CheatConsoleCallB(hwndDlg, WM_COMMAND, (LBN_DBLCLK * 0x10000) | (IDC_LIST_CHEATS), lParam);
						break;
						case CHEAT_CONTEXT_POKECHEATVALUE:
							FCEUI_GetCheat(selcheat,&name,&a,&v,NULL,&s,NULL);
							BWrite[a](a,v);
						break;
						case CHEAT_CONTEXT_GOTOINHEXEDITOR:
							DoMemView();
							FCEUI_GetCheat(selcheat,&name,&a,&v,NULL,&s,NULL);
							SetHexEditorAddress(a);
						break;
						case IDC_CHEAT_PAUSEWHENACTIVE:
							pauseWhileActive ^= 1;
							if ((EmulationPaused == 1 ? true : false) != pauseWhileActive) 
							{
								EmulationPaused = (pauseWhileActive ? 1 : 0);
								wasPausedByCheats = pauseWhileActive;
								if (EmulationPaused)
									FCEU_printf("Emulation paused: %d\n", EmulationPaused);
							}
						break;
						case IDC_BTN_CHEAT_ADD:
							dodecode = true;

							GetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,str,5);
							if(str[0] != 0) dodecode = false;
							a=StrToU16(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_VAL,str,3);
							if(str[0] != 0) dodecode = false;
							v=StrToU8(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_COM,str,3);
							if(str[0] != 0) dodecode = false;
							c=(str[0] == 0)?-1:StrToU8(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_NAME,str,256);
							if(dodecode && (strlen(str) == 6 || strlen(str) == 8)) {
								if(FCEUI_DecodeGG(str, &GGaddr, &GGval, &GGcomp)) {
									a = GGaddr;
									v = GGval;
									c = GGcomp;
								}
							}
//							if (FCEUI_AddCheat(str,a,v)) { //bbit edited: replaced this with the line below
							if (FCEUI_AddCheat(str,a,v,c,1)) {
								if(str[0] == 0) {
									if(a >= 0x8000) EncodeGG(str, a, v, c);
									else {
										if(c == -1) sprintf(str,"%04X:%02X",(int)a,(int)v); //bbit edited: added this line to give your cheat a name if you didn't supply one
										else sprintf(str,"%04X?%02X:%02X",(int)a,(int)c,(int)v);
									}
								}
								strcpy(str2,"* ");
								strcat(str2,str);
								SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_ADDSTRING,0,(LPARAM)(LPSTR)str2);
								selcheat = (SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETCOUNT,0,0) - 1);
								SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETCURSEL,selcheat,0);
								SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETSEL,(WPARAM)1,selcheat);

								SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)"");
								SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)"");
								SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
								SetDlgItemText(hwndDlg,IDC_CHEAT_NAME,(LPTSTR)"");
							}
							if (hMemView) UpdateColorTable(); //if the memory viewer is open then update any blue freeze locations in it as well
							UpdateCheatsAdded();
							break;
						case ID_CHEATLISTPOPUP_DELETESELECTEDCHEATS:
						case IDC_BTN_CHEAT_DEL:
							if (selcheatcount > 1)
							{
								if (IDYES == MessageBox(hwndDlg, "Multiple cheats selected. Continue with delete?", "Delete multiple cheats?", MB_ICONQUESTION | MB_YESNO)) { //Get message box
									selcheat=-1;
									for (int selcheattemp=SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETCOUNT,0,0)-1;selcheattemp>=0;selcheattemp--) {
										if (SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETSEL,selcheattemp,0)) {
											FCEUI_DelCheat(selcheattemp);
											SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_DELETESTRING,selcheattemp,0);
										}
									}
									SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_NAME,(LPTSTR)"");
									if (hMemView) UpdateColorTable(); //if the memory viewer is open then update any blue freeze locations in it as well
									UpdateCheatsAdded();
								}
							} else {
								if (selcheat >= 0) {
									FCEUI_DelCheat(selcheat);
									SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_DELETESTRING,selcheat,0);
									selcheat=-1;
									SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
									SetDlgItemText(hwndDlg,IDC_CHEAT_NAME,(LPTSTR)"");
								}
								if (hMemView) UpdateColorTable(); //if the memory viewer is open then update any blue freeze locations in it as well
								UpdateCheatsAdded();
							}
							break;
						case IDC_BTN_CHEAT_UPD:
							dodecode = true;

							if (selcheat < 0) break;
							GetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,str,5);
							if(str[0] != 0) dodecode = false;
							a=StrToU16(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_VAL,str,3);
							if(str[0] != 0) dodecode = false;
							v=StrToU8(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_COM,str,3);
							if(str[0] != 0) dodecode = false;
							c=(str[0] == 0)?-1:StrToU8(str);
							GetDlgItemText(hwndDlg,IDC_CHEAT_NAME,str,256);
							if(dodecode && (strlen(str) == 6 || strlen(str) == 8)) {
								if(FCEUI_DecodeGG(str, &GGaddr, &GGval, &GGcomp)) {
									a = GGaddr;
									v = GGval;
									c = GGcomp;
								}
							}
//							FCEUI_SetCheat(selcheat,str,a,v,-1); //bbit edited: replaced this with the line below
							FCEUI_SetCheat(selcheat,str,a,v,c,-1,1);
//							FCEUI_GetCheat(selcheat,&name,&a,&v,&s); //bbit edited: replaced this with the line below
							FCEUI_GetCheat(selcheat,&name,&a,&v,&c,&s,NULL);
							strcpy(str2,(s?"* ":"  "));
							if(str[0] == 0) {
								if(a >= 0x8000) EncodeGG(str, a, v, c);
								else {
									if(c == -1) sprintf(str,"%04X:%02X",(int)a,(int)v); //bbit edited: added this line to give your cheat a name if you didn't supply one
									else sprintf(str,"%04X?%02X:%02X",(int)a,(int)c,(int)v);
								}
							}
							strcat(str2,str);

							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_DELETESTRING,selcheat,0);
							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_INSERTSTRING,selcheat,(LPARAM)(LPSTR)str2);
							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETCURSEL,selcheat,0);
							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETSEL,(WPARAM)1,selcheat);

							SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)U16ToStr(a));
							SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)U8ToStr(v));
							if(c == -1)	SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
							else SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)U8ToStr(c));
							if(hMemView)UpdateColorTable(); //if the memory viewer is open then update any blue freeze locations in it as well
							break;
						case IDC_BTN_CHEAT_ADDFROMFILE:
						{
							OPENFILENAME ofn;
							memset(&ofn, 0, sizeof(ofn));
							ofn.lStructSize = sizeof(ofn);
							ofn.hwndOwner = hwndDlg;
							ofn.hInstance = fceu_hInstance;
							ofn.lpstrTitle = "Open Cheats file";
							const char filter[] = "Cheat files (*.cht)\0*.cht\0All Files (*.*)\0*.*\0\0";
							ofn.lpstrFilter = filter;

							char nameo[2048] = {0};
							ofn.lpstrFile = nameo;							
							ofn.nMaxFile = 2048;
							ofn.Flags = OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT|OFN_FILEMUSTEXIST;
							std::string initdir = FCEU_GetPath(FCEUMKF_CHEAT);
							ofn.lpstrInitialDir = initdir.c_str();

							if (GetOpenFileName(&ofn))
							{
								FILE* file = FCEUD_UTF8fopen(nameo, "rb");
								if (file)
								{
									FCEU_LoadGameCheats(file);
									if (hMemView) UpdateColorTable(); //if the memory viewer is open then update any blue freeze locations in it as well
									UpdateCheatsAdded();
									savecheats = 1;
								}
							}
							break;
						}
						case IDC_BTN_CHEAT_RESET:
							FCEUI_CheatSearchBegin();
							ShowResults(hwndDlg);
							EnableCheatButtons(hwndDlg,TRUE);
							break;
						case IDC_BTN_CHEAT_KNOWN:
							searchdone=1;
							GetDlgItemText(hwndDlg,IDC_CHEAT_VAL_KNOWN,str,3);
							knownvalue=StrToU8(str);
							FCEUI_CheatSearchEnd(4,knownvalue,0);
							ShowResults(hwndDlg);
							break;
						case IDC_BTN_CHEAT_EQ:
							searchdone=1;
							FCEUI_CheatSearchEnd(2,0,0);
							ShowResults(hwndDlg);
							break;
						case IDC_BTN_CHEAT_NE:
							searchdone=1;
							if (IsDlgButtonChecked(hwndDlg,IDC_CHEAT_CHECK_NE_BY) == BST_CHECKED) {
								GetDlgItemText(hwndDlg,IDC_CHEAT_VAL_NE_BY,str,3);
								FCEUI_CheatSearchEnd(2,0,StrToU8(str));
							}
							else FCEUI_CheatSearchEnd(3,0,0);
							ShowResults(hwndDlg);
							break;
						case IDC_BTN_CHEAT_GT:
							searchdone=1;
							if (IsDlgButtonChecked(hwndDlg,IDC_CHEAT_CHECK_GT_BY) == BST_CHECKED) {
								GetDlgItemText(hwndDlg,IDC_CHEAT_VAL_GT_BY,str,3);
								FCEUI_CheatSearchEnd(7,0,StrToU8(str));
							}
							else FCEUI_CheatSearchEnd(5,0,0);
							ShowResults(hwndDlg);
							break;
						case IDC_BTN_CHEAT_LT:
							searchdone=1;
							if (IsDlgButtonChecked(hwndDlg,IDC_CHEAT_CHECK_LT_BY) == BST_CHECKED) {
								GetDlgItemText(hwndDlg,IDC_CHEAT_VAL_LT_BY,str,3);
								FCEUI_CheatSearchEnd(8,0,StrToU8(str));
							}
							else FCEUI_CheatSearchEnd(6,0,0);
							ShowResults(hwndDlg);
							break;
					}
					break;
				case LBN_DBLCLK:
					switch (LOWORD(wParam)) { //disable/enable cheat
						case IDC_CHEAT_LIST_POSSIBILITIES:
							if (EmulationPaused == 1)	//We only want to send info to memwatch if paused
							{							//otherwise we will be sending info while it is updating causing unpredictable behavior
								lbfocus=1;				   
								SendDlgItemMessage(hwndDlg,
								IDC_CHEAT_LIST_POSSIBILITIES,
								LB_GETTEXT,
								SendDlgItemMessage(hwndDlg,
								IDC_CHEAT_LIST_POSSIBILITIES,
								LB_GETCURSEL,0,0),
								(LPARAM)(LPCTSTR)str);
								strcpy(str2,str+1);
								str2[4] = 0;
								AddMemWatch(str2);
							}
							break;
						case IDC_LIST_CHEATS:
							//SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETSEL,(WPARAM)x,(LPARAM)0);
							for (int selcheattemp=SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETCOUNT,0,0)-1;selcheattemp>=0;selcheattemp--) {
								if (SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_GETSEL,selcheattemp,0)) {
//									FCEUI_GetCheat(selcheattemp,&name,&a,&v,&s); //bbit edited: replaced this with the line below
									FCEUI_GetCheat(selcheattemp,&name,&a,&v,&c,&s,NULL);
//									FCEUI_SetCheat(selcheattemp,0,-1,-1,s^=1);//bbit edited: replaced this with the line below
									FCEUI_SetCheat(selcheattemp,0,-1,-1,-2,s^=1,1);
									strcpy(str,(s?"* ":"  "));
									if(name[0] == 0) {
										if(a >= 0x8000) EncodeGG(str+2, a, v, c);
										else {
											if(c == -1) sprintf(str+2,"%04X:%02X",(int)a,(int)v); //bbit edited: added this line to give your cheat a name if you didn't supply one
											else sprintf(str+2,"%04X?%02X:%02X",(int)a,(int)c,(int)v);
										}
									}
									else strcat(str,name);
									SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_DELETESTRING,selcheattemp,0);
									SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_INSERTSTRING,selcheattemp,(LPARAM)(LPSTR)str);
								}
							}
							UpdateCheatsAdded();
							UpdateColorTable();
							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETCURSEL,selcheat,0);
							SendDlgItemMessage(hwndDlg,IDC_LIST_CHEATS,LB_SETSEL,(WPARAM)1,selcheat);
							break;
					}
					break;
				case LBN_SELCHANGE:
					switch (LOWORD(wParam)) {
						case IDC_LIST_CHEATS:
							selcheat = SendDlgItemMessage(hwndDlg, IDC_LIST_CHEATS, LB_GETCURSEL, 0, 0);
							selcheatcount = SendDlgItemMessage(hwndDlg, IDC_LIST_CHEATS, LB_GETSELCOUNT, 0, 0);
							if (selcheat < 0) break;

							FCEUI_GetCheat(selcheat,&name,&a,&v,&c,&s,NULL);
							SetDlgItemText(hwndDlg,IDC_CHEAT_NAME,(LPTSTR)name);
							SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)U16ToStr(a));
							SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)U8ToStr(v));
							if (c == -1)
								SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
							else
								SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)U8ToStr(c));

							EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_DEL),TRUE);
							EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_UPD),TRUE);
							break;
						case IDC_CHEAT_LIST_POSSIBILITIES:
							lbfocus=1;
							SendDlgItemMessage(hwndDlg,
							                IDC_CHEAT_LIST_POSSIBILITIES,
							                LB_GETTEXT,
							                SendDlgItemMessage(hwndDlg,
							                                   IDC_CHEAT_LIST_POSSIBILITIES,
							                                   LB_GETCURSEL,0,0),
							                (LPARAM)(LPCTSTR)str);
							strcpy(str2,str+1);
							str2[4] = 0;
							SetDlgItemText(hwndDlg,IDC_CHEAT_ADDR,(LPTSTR)str2);
							strcpy(str2,str+13);
							SetDlgItemText(hwndDlg,IDC_CHEAT_VAL,(LPTSTR)str2);
							SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
							break;
					}
					break;
				case LBN_SELCANCEL:
					switch(LOWORD(wParam)) {
						case IDC_LIST_CHEATS:
							EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_DEL),FALSE);
							EnableWindow(GetDlgItem(hwndDlg,IDC_BTN_CHEAT_UPD),FALSE);
							break;
						case IDC_CHEAT_LIST_POSSIBILITIES:
							lbfocus=0;
							break;
					}
					break;

			}
			break;
	}
	return 0;
}


void ConfigCheats(HWND hParent)
{
	if (!GameInfo)
	{
		FCEUD_PrintError("You must have a game loaded before you can manipulate cheats.");
		return;
	}
	//if (GameInfo->type==GIT_NSF) {
	//	FCEUD_PrintError("Sorry, you can't cheat with NSFs.");
	//	return;
	//}

	if (!CheatWindow) 
	{
		selcheat=-1;
		CheatWindow=1;
		if (CheatStyle)
			pwindow = hCheat = CreateDialog(fceu_hInstance, "CHEATCONSOLE", NULL, CheatConsoleCallB);
		else
			DialogBox(fceu_hInstance,"CHEATCONSOLE",hParent,CheatConsoleCallB);
		UpdateCheatsAdded();
	} else
	{
		ShowWindow(hCheat, SW_SHOWNORMAL);
		SetForegroundWindow(hCheat);
	}
}

void UpdateCheatList()
{
	if(!pwindow)
		return;
	else
		ShowResults(pwindow);
}

//Used by cheats and external dialogs such as hex editor to update items in the cheat search dialog
void UpdateCheatsAdded()
{
	char temp[64];
	if (FrozenAddressCount < 256)
	{
		sprintf(temp,"Active Cheats %d", FrozenAddressCount);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADD), TRUE);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADDFROMFILE), TRUE);
	} else if (FrozenAddressCount == 256)
	{
		sprintf(temp,"Active Cheats %d (Max Limit)", FrozenAddressCount);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADD), FALSE);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADDFROMFILE), FALSE);
	}
	else
	{
		sprintf(temp,"%d Error: Too many cheats loaded!", FrozenAddressCount);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADD), FALSE);
		EnableWindow(GetDlgItem(hCheat, IDC_BTN_CHEAT_ADDFROMFILE), FALSE);
	}

	SetDlgItemText(hCheat,201,temp);
	RedoCheatsLB(hCheat);
}

BOOL CALLBACK GGConvCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	char str[100];
	int i;

	switch(uMsg) {
		case WM_MOVE: {
			if (!IsIconic(hwndDlg)) {
			RECT wrect;
			GetWindowRect(hwndDlg,&wrect);
			GGConv_wndx = wrect.left;
			GGConv_wndy = wrect.top;

			#ifdef WIN32
			WindowBoundsCheckNoResize(GGConv_wndx,GGConv_wndy,wrect.right);
			#endif
			}
			break;
		};
		case WM_INITDIALOG:
			//todo: set text limits
			if (GGConv_wndx==-32000) GGConv_wndx=0; //Just in case
			if (GGConv_wndy==-32000) GGConv_wndy=0;
			SetWindowPos(hwndDlg,0,GGConv_wndx,GGConv_wndy,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
			break;
		case WM_CREATE:

			break;
		case WM_PAINT:
			break;
		case WM_CLOSE:
		case WM_QUIT:
			DestroyWindow(hGGConv);
			hGGConv = 0;
			break;

		case WM_COMMAND:
				switch(HIWORD(wParam)) {
					case EN_UPDATE:
						if(dontupdateGG)break;
						dontupdateGG = 1;
						switch(LOWORD(wParam)){ //lets find out what edit control got changed
							case IDC_GAME_GENIE_CODE: //The Game Genie Code - in this case decode it.
								GetDlgItemText(hGGConv,IDC_GAME_GENIE_CODE,GGcode,9);
								if((strlen(GGcode) != 8) && (strlen(GGcode) != 6))break;

								FCEUI_DecodeGG(GGcode, &GGaddr, &GGval, &GGcomp);

								sprintf(str,"%04X",GGaddr);
								SetDlgItemText(hGGConv,IDC_GAME_GENIE_ADDR,str);

								if(GGcomp != -1)
									sprintf(str,"%02X",GGcomp);
								else str[0] = 0;
								SetDlgItemText(hGGConv,IDC_GAME_GENIE_COMP,str);

								sprintf(str,"%02X",GGval);
								SetDlgItemText(hGGConv,IDC_GAME_GENIE_VAL,str);
								//ListGGAddresses();
							break;

							case IDC_GAME_GENIE_ADDR:
							case IDC_GAME_GENIE_COMP:
							case IDC_GAME_GENIE_VAL:

								GetDlgItemText(hGGConv,IDC_GAME_GENIE_ADDR,str,5);
								if(strlen(str) != 4) break;

								GetDlgItemText(hGGConv,IDC_GAME_GENIE_VAL,str,5);
								if(strlen(str) != 2) {GGval = -1; break;}

								GGaddr = GetEditHex(hGGConv,IDC_GAME_GENIE_ADDR);
								GGval = GetEditHex(hGGConv,IDC_GAME_GENIE_VAL);

								GetDlgItemText(hGGConv,IDC_GAME_GENIE_COMP,str,5);
								if(strlen(str) != 2) GGcomp = -1;
								else GGcomp = GetEditHex(hGGConv,IDC_GAME_GENIE_COMP);

								EncodeGG(GGcode, GGaddr, GGval, GGcomp);
								SetDlgItemText(hGGConv,IDC_GAME_GENIE_CODE,GGcode);
								//ListGGAddresses();
							break;
						}
						ListGGAddresses();
						dontupdateGG = 0;
					break;
					case BN_CLICKED:
						switch (LOWORD(wParam)) {
							case IDC_BTN_ADD_TO_CHEATS:
								//ConfigCheats(fceu_hInstance);

								if(GGaddr < 0x8000)GGaddr += 0x8000;

								if (FCEUI_AddCheat(GGcode,GGaddr,GGval,GGcomp,1) && (hCheat != 0)) {
									strcpy(str,"* ");
									strcat(str,GGcode);
									SendDlgItemMessage(hCheat,IDC_LIST_CHEATS,LB_ADDSTRING,0,(LPARAM)(LPSTR)str);
									selcheat = (SendDlgItemMessage(hCheat,IDC_LIST_CHEATS,LB_GETCOUNT,0,0) - 1);
									SendDlgItemMessage(hCheat,IDC_LIST_CHEATS,LB_SETCURSEL,selcheat,0);

									SetDlgItemText(hCheat,IDC_CHEAT_ADDR,(LPTSTR)U16ToStr(GGaddr));
									SetDlgItemText(hCheat,IDC_CHEAT_VAL,(LPTSTR)U8ToStr(GGval));
									if(GGcomp == -1) SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)"");
									else SetDlgItemText(hwndDlg,IDC_CHEAT_COM,(LPTSTR)U8ToStr(GGcomp));

									EnableWindow(GetDlgItem(hCheat,IDC_BTN_CHEAT_DEL),TRUE);
									EnableWindow(GetDlgItem(hCheat,IDC_BTN_CHEAT_UPD),TRUE);
								}
						}
					break;

					case LBN_DBLCLK:
					switch (LOWORD(wParam)) {
						case IDC_LIST_GGADDRESSES:
							i = SendDlgItemMessage(hwndDlg,IDC_LIST_GGADDRESSES,LB_GETCURSEL,0,0);
							ChangeMemViewFocus(2,GGlist[i],-1);
						break;
					}
					break;
				}
			break;
		case WM_MOUSEMOVE:
			break;
		case WM_HSCROLL:
			break;
	}
	return FALSE;
}

//The code in this function is a modified version
//of Chris Covell's work - I'd just like to point that out
void EncodeGG(char *str, int a, int v, int c)
{
	uint8 num[8];
	static char lets[16]={'A','P','Z','L','G','I','T','Y','E','O','X','U','K','S','V','N'};
	int i;
	if(a > 0x8000)a-=0x8000;

	num[0]=(v&7)+((v>>4)&8);
	num[1]=((v>>4)&7)+((a>>4)&8);
	num[2]=((a>>4)&7);
	num[3]=(a>>12)+(a&8);
	num[4]=(a&7)+((a>>8)&8);
	num[5]=((a>>8)&7);

	if (c == -1){
		num[5]+=v&8;
		for(i = 0;i < 6;i++)str[i] = lets[num[i]];
		str[6] = 0;
	} else {
		num[2]+=8;
		num[5]+=c&8;
		num[6]=(c&7)+((c>>4)&8);
		num[7]=((c>>4)&7)+(v&8);
		for(i = 0;i < 8;i++)str[i] = lets[num[i]];
		str[8] = 0;
	}
	return;
}

void ListGGAddresses()
{
	uint32 i, j = 0; //mbg merge 7/18/06 changed from int
	char str[20];
	SendDlgItemMessage(hGGConv,IDC_LIST_GGADDRESSES,LB_RESETCONTENT,0,0);

	//also enable/disable the add GG button here
	GetDlgItemText(hGGConv,IDC_GAME_GENIE_CODE,GGcode,9);

	if((GGaddr < 0) || ((strlen(GGcode) != 8) && (strlen(GGcode) != 6)))EnableWindow(GetDlgItem(hGGConv,IDC_BTN_ADD_TO_CHEATS),FALSE);
	else EnableWindow(GetDlgItem(hGGConv,IDC_BTN_ADD_TO_CHEATS),TRUE);

	for(i = 0;i < PRGsize[0];i+=0x2000){
		if((PRGptr[0][i+(GGaddr&0x1FFF)] == GGcomp) || (GGcomp == -1)){
			GGlist[j] = i+(GGaddr&0x1FFF)+0x10;
			if(++j > GGLISTSIZE)return;
			sprintf(str,"%06X",i+(GGaddr&0x1FFF)+0x10);
			SendDlgItemMessage(hGGConv,IDC_LIST_GGADDRESSES,LB_ADDSTRING,0,(LPARAM)(LPSTR)str);
		}
	}
}

//A different model for this could be to have everything
//set in the INITDIALOG message based on the internal
//variables, and have this simply call that.
void SetGGConvFocus(int address,int compare)
{
	char str[10];
	if(!hGGConv)DoGGConv();
	GGaddr = address;
	GGcomp = compare;

	dontupdateGG = 1; //little hack to fix a nasty bug

	sprintf(str,"%04X",address);
	SetDlgItemText(hGGConv,IDC_GAME_GENIE_ADDR,str);

	dontupdateGG = 0;

	sprintf(str,"%02X",GGcomp);
	SetDlgItemText(hGGConv,IDC_GAME_GENIE_COMP,str);


	if(GGval < 0)SetDlgItemText(hGGConv,IDC_GAME_GENIE_CODE,"");
	else {
		EncodeGG(GGcode, GGaddr, GGval, GGcomp);
		SetDlgItemText(hGGConv,IDC_GAME_GENIE_CODE,GGcode);
	}

	SetFocus(GetDlgItem(hGGConv,IDC_GAME_GENIE_VAL));

	return;
}

void DoGGConv()
{
	if (hGGConv)
	{
		ShowWindow(hGGConv, SW_SHOWNORMAL);
		SetForegroundWindow(hGGConv);
	} else
	{
		hGGConv = CreateDialog(fceu_hInstance,"GGCONV",NULL,GGConvCallB);
	}
	return;
}

/*
void ListBox::OnRButtonDown(UINT nFlags, CPoint point)
{
CPoint test = point;
} */