/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2006 Luke Gustafson
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
#include "../../fceu.h"
#include "memwatch.h"
#include "../../debug.h"
#include "debugger.h"
#include "cheat.h"
#include "../../utils/xstring.h"
#include "help.h"
#include <string>
#include "main.h"
#include "window.h" //adelikat: For GetMainHWDN()

using namespace std;

//Memory Watch named constants-----------------------------------
const int NUMWATCHES = 24;		//Maximum Number of Watches
const int LABELLENGTH = 64;		//Maximum Length of a Watch label
const int ADDRESSLENGTH = 16;	//Maximum Length of a Ram Address

//Prototypes
void RamChangeReset(int x);	//Called when user hits reset button
void CollapseWindow(void);	//Called when user collapses or expands window

//Memory Watch GUI Handles & Globals---------------------------
HWND hwndMemWatch=0;		//Handle to Memwatch Window
static HDC hdc;				//Handle to to Device Context
static HMENU memwmenu = 0;	//Handle to Memwatch Menu
static HMENU memwrecentmenu;//Handle to Recent Files Menu

int MemWatch_wndx=0, MemWatch_wndy=0; //Window Position
bool MemWCollapsed = false;		//Flag to determine if window is currently collapsed

static char addresses[NUMWATCHES][ADDRESSLENGTH];	//Stores all address labels
static char labels[NUMWATCHES][LABELLENGTH];		//Stores all label lengths
static int NeedsInit = 1;							//Determines if Memwatch has been initialized (used so you don't lose data if you close memwatch)
char *MemWatchDir = 0;								//Last directory used by memwatch
char memwLastFilename[2048];						//Last watch file used by memwatch
bool fileChanged = false;							//Determines if Save Changes should appear
bool MemWatchLoadOnStart = false;					//Load on Start Flag
bool MemWatchLoadFileOnStart = false;				//Load last file Flag
bool BindToMain = false;							//Whether or not FCEUX is in control of this dialog (by default all dialogs in FCEUX aren't)

string memwhelp = "MemoryWatch";

//Recent Files Menu globals------------------------------------
char *memw_recent_files[] = { 0 ,0 ,0 ,0 ,0 };
const unsigned int MEMW_MENU_FIRST_RECENT_FILE = 600;
const unsigned int MEMW_MAX_NUMBER_OF_RECENT_FILES = sizeof(memw_recent_files)/sizeof(*memw_recent_files);

extern void RemoveRecentItem(unsigned int which, char**bufferArray, const unsigned int MAX);	//For removing erroneous recent files

//Ram change monitor globals-----------------------------------
bool RamChangeInitialize = false;		//Set true during memw WM_INIT
const int MAX_RAMMONITOR = 4;			//Maximum number of Ram values that can be monitored
char editboxnow[MAX_RAMMONITOR][5];		//current address put into editbox 00
char editboxlast[MAX_RAMMONITOR][5];	//last address put into editbox (1 frame ago)
int editlast[MAX_RAMMONITOR];			//last address value (1 frame ago)
int editnow[MAX_RAMMONITOR];			//current address value
unsigned int editcount[MAX_RAMMONITOR];	//Current counter value
char editchangem[MAX_RAMMONITOR][5];	//counter converted to string

//-------------------------------------------------

void UpdateMemw_RMenu(HMENU menu, char **strs, unsigned int mitem, unsigned int baseid)
{
	MENUITEMINFO moo;
	int x;

	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_SUBMENU | MIIM_STATE;

	GetMenuItemInfo(GetSubMenu(memwmenu, 0), mitem, FALSE, &moo);
	moo.hSubMenu = menu;
	moo.fState = strs[0] ? MFS_ENABLED : MFS_GRAYED;

	SetMenuItemInfo(GetSubMenu(memwmenu, 0), mitem, FALSE, &moo);

	// Remove all recent files submenus
	for(x = 0; x < MEMW_MAX_NUMBER_OF_RECENT_FILES; x++)
	{
		RemoveMenu(menu, baseid + x, MF_BYCOMMAND);
	}

	// Recreate the menus
	for(x = MEMW_MAX_NUMBER_OF_RECENT_FILES - 1; x >= 0; x--)
	{  
		char tmp[128 + 5];

		// Skip empty strings
		if(!strs[x])
		{
			continue;
		}

		moo.cbSize = sizeof(moo);
		moo.fMask = MIIM_DATA | MIIM_ID | MIIM_TYPE;

		// Fill in the menu text.
		if(strlen(strs[x]) < 128)
		{
			sprintf(tmp, "&%d. %s", ( x + 1 ) % 10, strs[x]);
		}
		else
		{
			sprintf(tmp, "&%d. %s", ( x + 1 ) % 10, strs[x] + strlen( strs[x] ) - 127);
		}

		// Insert the menu item
		moo.cch = strlen(tmp);
		moo.fType = 0;
		moo.wID = baseid + x;
		moo.dwTypeData = tmp;
		InsertMenuItem(menu, 0, 1, &moo);
	}

	DrawMenuBar(hAppWnd);
}

//Updates the Recent Files array
void UpdateMemwRecentArray(const char* addString, char** bufferArray, unsigned int arrayLen, HMENU menu, unsigned int menuItem, unsigned int baseId)
{
	// Try to find out if the filename is already in the recent files list.
	for(unsigned int x = 0; x < arrayLen; x++)
	{
		if(bufferArray[x])
		{
			if(!strcmp(bufferArray[x], addString))    // Item is already in list.
			{
				// If the filename is in the file list don't add it again.
				// Move it up in the list instead.

				int y;
				char *tmp;

				// Save pointer.
				tmp = bufferArray[x];
				
				for(y = x; y; y--)
				{
					// Move items down.
					bufferArray[y] = bufferArray[y - 1];
				}

				// Put item on top.
				bufferArray[0] = tmp;

				// Update the recent files menu
				UpdateMemw_RMenu(menu, bufferArray, menuItem, baseId);

				return;
			}
		}
	}

	// The filename wasn't found in the list. That means we need to add it.

	// If there's no space left in the recent files list, get rid of the last
	// item in the list.
	if(bufferArray[arrayLen - 1])
	{
		free(bufferArray[arrayLen - 1]);
	}

	// Move the other items down.
	for(unsigned int x = arrayLen - 1; x; x--)
	{
		bufferArray[x] = bufferArray[x - 1];
	}

	// Add the new item.
	bufferArray[0] = (char*)malloc(strlen(addString) + 1);
	strcpy(bufferArray[0], addString);

	// Update the recent files menu
	UpdateMemw_RMenu(menu, bufferArray, menuItem, baseId);
}

//Add a filename to the recent files list.
void MemwAddRecentFile(const char *filename)
{
	UpdateMemwRecentArray(filename, memw_recent_files, MEMW_MAX_NUMBER_OF_RECENT_FILES, memwrecentmenu, ID_FILE_RECENT, MEMW_MENU_FIRST_RECENT_FILE);
}

static const int MW_ADDR_Lookup[] = {
	MW_ADDR00,MW_ADDR01,MW_ADDR02,MW_ADDR03,
	MW_ADDR04,MW_ADDR05,MW_ADDR06,MW_ADDR07,
	MW_ADDR08,MW_ADDR09,MW_ADDR10,MW_ADDR11,
	MW_ADDR12,MW_ADDR13,MW_ADDR14,MW_ADDR15,
	MW_ADDR16,MW_ADDR17,MW_ADDR18,MW_ADDR19,
	MW_ADDR20,MW_ADDR21,MW_ADDR22,MW_ADDR23
};
inline int MW_ADDR(int i) { return MW_ADDR_Lookup[i]  ; }
inline int MW_NAME(int i) { return MW_ADDR_Lookup[i]-1; }
inline int MW_VAL (int i) { return MW_ADDR_Lookup[i]+1; }

static const int MWNUM = ARRAY_SIZE(MW_ADDR_Lookup);

static int yPositions[MWNUM];
static int xPositions[MWNUM];

static struct MWRec
{
	static int findIndex(WORD ctl)
	{
		for(int i=0;i<MWNUM;i++)
			if(MW_ADDR(i) == ctl)
				return i;
		return -1;
	}

	void parse(WORD ctl)
	{
		char TempArray[16];
		GetDlgItemText(hwndMemWatch,ctl,TempArray,16);
		TempArray[15]=0;
		
		int x = 0;
		for (x = 0; x < 15; x++)
		{
			if (!(TempArray[x] == ' '))
				break;
		}	//The point of this loop is to ignore spaces at the begginning of a address box

		valid = hex = twobytes = false;
		switch(TempArray[x])
		{
			case 0:
				break;
			case '!':
				twobytes=true;
				addr=FastStrToU16(TempArray+x+1,valid);
				break;
			case 'x':
				hex = true;
				valid = true;
				addr=FastStrToU16(TempArray+x+1,valid);
				break;
			case 'X':
				hex = twobytes = true;
				valid = true;
				addr = FastStrToU16(TempArray+x+1,valid);
				break;
			default:
				valid = true;
				addr=FastStrToU16(TempArray+x,valid);
				break;
			}
	}
	bool valid, twobytes, hex;
	uint16 addr;
} mwrecs[MWNUM];

//Update the values in the Memory Watch window
void UpdateMemWatch()
{
	if(hwndMemWatch && GameInfo)
	{
		//SetTextColor(hdc,RGB(0,0,0));
		SetTextColor(hdc,GetSysColor(COLOR_WINDOWTEXT));	//adelikat-changed colors to Windows System Colors.  Hardcoded colors run the risk of incompatibiliy (for instance if someone uses custom colors and makes dialogs black, addresses would be unreadable)
		SetBkColor(hdc,GetSysColor(COLOR_3DFACE));

		for(int i = 0; i < MWNUM; i++)
		{
			MWRec& mwrec = mwrecs[i];

			//Display blue if address is frozen
			if (FrozenAddressCount && FrozenAddresses.size())
			{
			for (unsigned int x = 0; x < FrozenAddressCount; x++)
			{
				if (mwrec.addr == FrozenAddresses[x])
				{
					//SetTextColor(hdc,RGB(0,0,255));
					SetTextColor(hdc,GetSysColor(COLOR_HIGHLIGHT));
				}
			}
			}

			char* text;
			if(mwrec.valid && GameInfo)
			{
				if(mwrec.hex)
				{
					if(mwrec.twobytes)
					{
						text = U16ToHexStr(GetMem(mwrec.addr)+(GetMem(mwrec.addr+1)<<8));
					}
					else
					{
						text = U8ToHexStr(GetMem(mwrec.addr));
					}
				}
				else
				{
					if(mwrec.twobytes)
					{
						text = U16ToDecStr(GetMem(mwrec.addr)+(GetMem(mwrec.addr+1)<<8));
					}
					else
					{
						text = U8ToDecStr(GetMem(mwrec.addr));
					}
				}

				int len = strlen(text);
				for(int i=len;i<5;i++)
					text[i] = ' ';
				text[5] = 0;
			}
			else
			{
				text = "-    ";
			}

			MoveToEx(hdc,xPositions[i],yPositions[i],NULL);
			TextOut(hdc,0,0,text,strlen(text));
			SetTextColor(hdc,RGB(0,0,0));
		}
		
	}
}

//Save labels/addresses so next time dialog is opened,
//you don't lose what you've entered.
static void SaveStrings()
{
	int i;
	for(i=0;i<MWNUM;i++)
	{
		GetDlgItemText(hwndMemWatch,MW_ADDR(i),addresses[i],ADDRESSLENGTH);
		GetDlgItemText(hwndMemWatch,MW_NAME(i),labels[i],LABELLENGTH);
	}
}

//replaces spaces with a dummy character
static void TakeOutSpaces(int i)
{
	int j;
	for(j=0;j<ADDRESSLENGTH;j++)
	{
		if(addresses[i][j] == ' ') addresses[i][j] = '|';
		if(labels[i][j] == ' ') labels[i][j] = '|';
	}
	for(;j<LABELLENGTH;j++)
	{
		if(labels[i][j] == ' ') labels[i][j] = '|';
	}
}

//replaces dummy characters with spaces
static void PutInSpaces(int i)
{
	int j;
	for(j=0;j<ADDRESSLENGTH;j++)
	{
		if(addresses[i][j] == '|') addresses[i][j] = ' ';
		if(labels[i][j] == '|') labels[i][j] = ' ';
	}
	for(;j<LABELLENGTH;j++)
	{
		if(labels[i][j] == '|') labels[i][j] = ' ';
	}
}

//Decides if any edit box has anything	
bool iftextchanged()
{
	int i,j;
	for(i=0;i<NUMWATCHES;i++)
	{
		for(j=0;j<LABELLENGTH;j++)
		{
			if(addresses[i][j] != NULL || labels [i][j] != NULL)
				return true;
		}
		for(;j<LABELLENGTH;j++)
		{
			if(labels[i][j] != NULL)
				return true;
		}
	}
	return false;
}

//Save as...
static void SaveMemWatch()
{
	const char filter[]="Memory address list (*.txt)\0*.txt\0All Files (*.*)\0*.*\0\0";
	 
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Save Memory Watch As...";
	ofn.lpstrFilter=filter;
	ofn.lpstrDefExt="txt";
	char nameo[2048];
	if (!memwLastFilename[0])
		strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	else
		strcpy(nameo, memwLastFilename);
	ofn.lpstrFile=nameo;
	ofn.lpstrDefExt="txt";
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
	string initdir =  FCEU_GetPath(FCEUMKF_MEMW);
	ofn.lpstrInitialDir=initdir.c_str();
	if(GetSaveFileName(&ofn))
	{
		int i;

		//Save the directory
		if(ofn.nFileOffset < 1024)
		{
			free(MemWatchDir);
			MemWatchDir=(char*)malloc(strlen(ofn.lpstrFile)+1);
			strcpy(MemWatchDir,ofn.lpstrFile);
			MemWatchDir[ofn.nFileOffset]=0;
		}

		strcpy(memwLastFilename,nameo);

		SaveStrings();
		FILE *fp=FCEUD_UTF8fopen(memwLastFilename,"w");
		for(i=0;i<NUMWATCHES;i++)
		{
			//Use dummy strings to fill empty slots
			if(labels[i][0] == 0)
			{
				labels[i][0] = '|';
				labels[i][1] = 0;
			}
			if(addresses[i][0] == 0)
			{
				addresses[i][0] = '|';
				addresses[i][1] = 0;
			}
			//spaces can be a problem for scanf so get rid of them
			TakeOutSpaces(i);
			fprintf(fp, "%s %s\n", addresses[i], labels[i]);
			PutInSpaces(i);
		}
		fileChanged=false;
		fclose(fp);
	}
}

static void QuickSaveMemWatch() //Save rather than Save as
{
	if (fileChanged==false) //Checks if current watch has been changed, if so quick save has no effect.
		return;	
	if (memwLastFilename[0]!=NULL) // Check if there is there something to save else default to save as
	{
		SaveStrings();
		FILE *fp=FCEUD_UTF8fopen(memwLastFilename,"w");
		for(int i=0;i<NUMWATCHES;i++)
		{
			//Use dummy strings to fill empty slots
			if(labels[i][0] == 0)
			{
				labels[i][0] = '|';
				labels[i][1] = 0;
			}
			if(addresses[i][0] == 0)
			{
				addresses[i][0] = '|';
				addresses[i][1] = 0;
			}
			//spaces can be a problem for scanf so get rid of them
			TakeOutSpaces(i);
			fprintf(fp, "%s %s\n", addresses[i], labels[i]);
			PutInSpaces(i);
			
		}
		fileChanged = false;
		fclose (fp);
	}
	else
		SaveMemWatch();
}

//Open Memwatch File
static void LoadMemWatch()
{
	const char filter[]="Memory address list (*.txt)\0*.txt\0All Files (*.*)\0*.*\0\0";
	char watchfcontents[2048]; 
	
	//Now clear last file used variable (memwLastFilename)
	//This might be unecessary
		for (int i=0;i<2048;i++)
		{
			memwLastFilename[i] = NULL;
		}
	
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Load Memory Watch...";
	ofn.lpstrFilter=filter;
	memwLastFilename[0]=0;
	ofn.lpstrFile=memwLastFilename;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	string initdir = FCEU_GetPath(FCEUMKF_MEMW);
	ofn.lpstrInitialDir=initdir.c_str();

	if(GetOpenFileName(&ofn))
	{
		int i,j;

		//Save the directory
		if(ofn.nFileOffset < 1024)
		{
			free(MemWatchDir);
			MemWatchDir=(char*)malloc(strlen(ofn.lpstrFile)+1);
			strcpy(MemWatchDir,ofn.lpstrFile);
			MemWatchDir[ofn.nFileOffset]=0;
		}
			
		FILE *fp=FCEUD_UTF8fopen(memwLastFilename,"r");
			MemwAddRecentFile(memwLastFilename);

		for(i=0;i<NUMWATCHES;i++)
		{
			fscanf(fp, "%s ", watchfcontents); //Reads contents of newly opened file
			for(j = 0; j < ADDRESSLENGTH; j++)
				addresses[i][j] = watchfcontents[j];
			fscanf(fp, "%s\n", watchfcontents);
			for(j = 0; j < LABELLENGTH; j++)
				labels[i][j] = watchfcontents[j];

			//Replace dummy strings with empty strings
			if(addresses[i][0] == '|')
			{
				addresses[i][0] = 0;
			}
			if(labels[i][0] == '|')
			{
				labels[i][0] = 0;
			}
			PutInSpaces(i);

			int templl = LABELLENGTH - 1;
			int tempal = ADDRESSLENGTH - 1;
			addresses[i][tempal] = 0;
			labels[i][templl] = 0; //just in case

			SetDlgItemText(hwndMemWatch,MW_VAL (i),(LPTSTR) "---");
			SetDlgItemText(hwndMemWatch,MW_ADDR(i),(LPTSTR) addresses[i]);
			SetDlgItemText(hwndMemWatch,MW_NAME(i),(LPTSTR) labels[i]);
		}
		fclose(fp);
	}
fileChanged = false;
}

//Loads a recent file given the recent files array number(0-4) 
void OpenMemwatchRecentFile(int memwRFileNumber)
{
	if (memwRFileNumber > MEMW_MAX_NUMBER_OF_RECENT_FILES) return; //just in case
		
	char* x = memw_recent_files[memwRFileNumber];
	if (x == NULL) return; //If no recent files exist just return.  Useful for Load last file on startup (or if something goes screwy)
	char watchfcontents[2048];

	FILE *fp=FCEUD_UTF8fopen(x,"r");	//Open the recent file
	if (fp)		//Check if file opening was successful, if not, abort
	{
		strcpy(memwLastFilename,x);
		if (memwRFileNumber != 0) //Change order of recent files if not most recent
			MemwAddRecentFile(x);
		int i,j;
		for(i=0;i<NUMWATCHES;i++)
			{
				fscanf(fp, "%s ", watchfcontents); //Reads contents of newly opened file
				for(j = 0; j < ADDRESSLENGTH; j++)
					addresses[i][j] = watchfcontents[j];
				fscanf(fp, "%s\n", watchfcontents);
				for(j = 0; j < LABELLENGTH; j++)
					labels[i][j] = watchfcontents[j];

				//Replace dummy strings with empty strings
				if(addresses[i][0] == '|')
				{
					addresses[i][0] = 0;
				}
				if(labels[i][0] == '|')
				{
					labels[i][0] = 0;
				}
				PutInSpaces(i);

				int templl = LABELLENGTH - 1;
				int tempal = ADDRESSLENGTH - 1;
				addresses[i][tempal] = 0;
				labels[i][templl] = 0; //just in case

				SetDlgItemText(hwndMemWatch,MW_VAL (i),(LPTSTR) "---");
				SetDlgItemText(hwndMemWatch,MW_ADDR(i),(LPTSTR) addresses[i]);
				SetDlgItemText(hwndMemWatch,MW_NAME(i),(LPTSTR) labels[i]);
		}
		fclose(fp);				//Close the file
		fileChanged = false;	//Flag that the memwatch file has not been changed since last save
	}
	else		//Opening fp failed
	{
		int result = MessageBox(hwndMemWatch,"Remove from list?", "Could Not Open Recent File", MB_YESNO);
		if (result == IDYES)
		{
			RemoveRecentItem(memwRFileNumber, memw_recent_files, MEMW_MAX_NUMBER_OF_RECENT_FILES);
			UpdateMemw_RMenu(memwrecentmenu, memw_recent_files, ID_FILE_RECENT, MEMW_MENU_FIRST_RECENT_FILE);
		}
	}
}

bool CloseMemoryWatch()
{
	int result = 0;	//Flag for asking to save changes

	if(hwndMemWatch)
	{
		SaveStrings();

		if (fileChanged)
		{
			result = MessageBox(hwndMemWatch, "Save Changes?", "Memory Watch Settings", MB_YESNOCANCEL);
			if (result == IDYES)
			{
				QuickSaveMemWatch();
				DestroyWindow(hwndMemWatch);
				hwndMemWatch=0;
				return true;	//true = User did not choose to cancel operation
			}
			else if (result == IDNO)
			{
				DestroyWindow(hwndMemWatch);
				hwndMemWatch=0;
				return true;	//Don't run SaveMemWatch, but return true
			}
			else
				return false;	//User requested cancel, so abort the attempt to close
		}
		else	//File was not changed so just close
		{
			DestroyWindow(hwndMemWatch);
			hwndMemWatch=0;
		}
	}
	return true;
}

//New File
void ClearAllText()
{
	//Ask to save changes first, if necessary
	if (fileChanged==true) //If contents have changed
	{
		int result = MessageBox(hwndMemWatch, "Save Changes?", "Save", MB_YESNOCANCEL);
		if(result==IDCANCEL)
			return;
		else if (result == IDYES)
			SaveMemWatch();
	}
	//Clear all strings			
	for(int i=0;i<MWNUM;i++)
	{
		addresses[i][0] = 0;
		labels[i][0] = 0;
		SetDlgItemText(hwndMemWatch,MW_ADDR(i),(LPTSTR) addresses[i]);
		SetDlgItemText(hwndMemWatch,MW_NAME(i),(LPTSTR) labels[i]);
	}
	//Now clear last file used variable (memwLastFilename)
	for (int i=0;i<2048;i++)
		memwLastFilename[i] = NULL;
	
	//A new file, so file has not changed
	fileChanged = false;				
}

static BOOL CALLBACK MemWatchCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	const int FMAX = 6;
	string formula[FMAX] = {"> than", "> by 1", "< than", "< by 1", "equal", "!equal"};
	
	const int kLabelControls[] = {MW_ValueLabel1,MW_ValueLabel2};

	switch(uMsg)
	{
	case WM_ENTERMENULOOP:
		EnableMenuItem(memwmenu,MEMW_FILE_SAVE,MF_BYCOMMAND | (fileChanged ? MF_ENABLED : MF_GRAYED));
		break;
	case WM_MOVE: {
		if (!IsIconic(hwndDlg)) {
		RECT wrect;
		GetWindowRect(hwndDlg,&wrect);
		MemWatch_wndx = wrect.left;
		MemWatch_wndy = wrect.top;

		#ifdef WIN32
		WindowBoundsCheckNoResize(MemWatch_wndx,MemWatch_wndy,wrect.right);
		#endif
		}
		break;
	};

	case WM_INITDIALOG:
		if (MemWatch_wndx==-32000) MemWatch_wndx=0; //Just in case
		if (MemWatch_wndy==-32000) MemWatch_wndy=0; //-32000 bugs can happen as it is a special windows value
		SetWindowPos(hwndDlg,0,MemWatch_wndx,MemWatch_wndy,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
		hdc = GetDC(hwndDlg);
		SelectObject (hdc, debugSystem->hFixedFont);
		SetTextAlign(hdc,TA_UPDATECP | TA_TOP | TA_LEFT);
		
		//Collapse window if necesasry
		if (MemWCollapsed) 
		{
			MemWCollapsed = false;  //This is necessary in order for CollapseWindow to collapse properly
			CollapseWindow();		//If flagged as collapsed mode collapse
		}

		//find the positions where we should draw string values
		for(int i=0;i<MWNUM;i++) {
			int col=0;
			if(i>=MWNUM/2)
				col=1;
			RECT r;
			GetWindowRect(GetDlgItem(hwndDlg,MW_ADDR(i)),&r);
			ScreenToClient(hwndDlg,(LPPOINT)&r);
			ScreenToClient(hwndDlg,(LPPOINT)&r.right);
			yPositions[i] = r.top;
			yPositions[i] += ((r.bottom-r.top)-debugSystem->fixedFontHeight)/2; //vertically center
			GetWindowRect(GetDlgItem(hwndDlg,kLabelControls[col]),&r);
			ScreenToClient(hwndDlg,(LPPOINT)&r);
			xPositions[i] = r.left;
		}

		//Populate Formula pulldown menus
		for (int x = 0; x < MAX_RAMMONITOR; x++)
		{
			for (int y = 0; y < FMAX; y++)
			{
				SendDlgItemMessage(hwndDlg, MEMW_EDIT00FORMULA+x,(UINT) CB_ADDSTRING, 0,(LPARAM) formula[y].c_str() );
			}
			SendDlgItemMessage(hwndDlg, MEMW_EDIT00FORMULA+x, CB_SETCURSEL, 0, 0);
		}
		

		//Initialize RAM Change monitor globals
		for (int x = 0; x < MAX_RAMMONITOR; x++)
		{
			editnow[x] = 0;
			editlast[x]= 0;
		}
		RamChangeInitialize = true;
		break;

	case WM_PAINT:
		PAINTSTRUCT ps;
		BeginPaint(hwndDlg, &ps);
		EndPaint(hwndDlg, &ps);
		UpdateMemWatch();
		break;
	case WM_INITMENU:
		CheckMenuItem(memwmenu, MEMW_OPTIONS_LOADSTART, MemWatchLoadOnStart ? MF_CHECKED : MF_UNCHECKED);
		CheckMenuItem(memwmenu, MEMW_OPTIONS_LOADLASTFILE, MemWatchLoadFileOnStart ? MF_CHECKED : MF_UNCHECKED);
		CheckMenuItem(memwmenu, ID_OPTIONS_BINDTOMAINWINDOW, BindToMain ? MF_CHECKED : MF_UNCHECKED);
		break;
	case WM_CLOSE:
	case WM_QUIT:
		CloseMemoryWatch();
		break;

	case WM_DROPFILES:
	{
		unsigned int len;
		char *ftmp;

		len=DragQueryFile((HDROP)wParam,0,0,0)+1; 
		if((ftmp=(char*)malloc(len))) 
		{
			DragQueryFile((HDROP)wParam,0,ftmp,len); 
			string fileDropped = ftmp;
			
			//-------------------------------------------------------
			//Check if .txt file
			//-------------------------------------------------------
			if (!(fileDropped.find(".txt") == string::npos))	 //ROM is already loaded and .txt in filename
			{
				if (GameInfo && !(fileDropped.find(".txt") == string::npos)) //.txt is at the end of the filename so that must be the extension
				{
					MemwAddRecentFile(ftmp);
					OpenMemwatchRecentFile(0);
				}
			}
		}            
	}
	break;

	case WM_COMMAND:

		//Menu Items
		switch(LOWORD(wParam))
		{
		case MEMW_FILE_CLOSE:  
			if (CloseMemoryWatch())
				RamChangeInitialize = false;
			break;

		case ACCEL_CTRL_O:
		case MEMW_FILE_OPEN:
			LoadMemWatch();
			break;
		
		case ACCEL_CTRL_S:
		case MEMW_FILE_SAVE:
			QuickSaveMemWatch();
			break;

		case ACCEL_CTRL_SHIFT_S:
		case MEMW_FILE_SAVEAS:
			SaveMemWatch();
			break;
		
		case ACCEL_CTRL_N:
		case MEMW_FILE_NEW:
			ClearAllText();
			RamChange();
			break;
		
		case MEMW_FILE_RECENT:
			break;

		case MEMW_OPTIONS_LOADSTART:	//Load on Start up
			MemWatchLoadOnStart ^= 1;
			CheckMenuItem(memwmenu, MEMW_OPTIONS_LOADSTART, MemWatchLoadOnStart ? MF_CHECKED : MF_UNCHECKED);
			break;

		case MEMW_OPTIONS_LOADLASTFILE: //Load last file when opening memwatch
			MemWatchLoadFileOnStart ^= 1;
			CheckMenuItem(memwmenu, MEMW_OPTIONS_LOADLASTFILE, MemWatchLoadFileOnStart ? MF_CHECKED : MF_UNCHECKED);
			break;

		case ID_OPTIONS_BINDTOMAINWINDOW:	//adelikat: This option will attach/detach memwatch from the main window, if attached it doesn't not have its own taskbar item and will minimize when FCEUX is minimized
			BindToMain ^= 1;
			CheckMenuItem(memwmenu, ID_OPTIONS_BINDTOMAINWINDOW, BindToMain ? MF_CHECKED : MF_UNCHECKED);
			break;

		case MEMW_HELP_WCOMMANDS:
			OpenHelpWindow(memwhelp);
			break;

		case MEMW_OPTIONS_EXPANDCOLLAPSE:
		case MEMW_EXPANDCOLLAPSE:
			CollapseWindow();
			break;
			
		case MEMW_EDIT00RESET:
			RamChangeReset(0);	
			break;
		case MEMW_EDIT01RESET:
			RamChangeReset(1);
			break;
		case MEMW_EDIT02RESET:
			RamChangeReset(2);
			break;
		case MEMW_EDIT03RESET:
			RamChangeReset(3);
			break;
		default:
			if (LOWORD(wParam) >= MEMW_MENU_FIRST_RECENT_FILE && LOWORD(wParam) < MEMW_MENU_FIRST_RECENT_FILE+MEMW_MAX_NUMBER_OF_RECENT_FILES)
				OpenMemwatchRecentFile(LOWORD(wParam) - MEMW_MENU_FIRST_RECENT_FILE);
		break;
		}

		switch(HIWORD(wParam))
		{
		
		case EN_CHANGE:
			{
				fileChanged = iftextchanged();			
				//the contents of an address box changed. re-parse it.
				//first, find which address changed
				int changed = MWRec::findIndex(LOWORD(wParam));
				if(changed==-1) break;
				mwrecs[changed].parse(LOWORD(wParam));
				break;
			}
		
#if 0
		case BN_CLICKED:
			
			switch(LOWORD(wParam))
			{
			case 101: //Save button clicked
				//StopSound(); //mbg 5/7/08
				//SaveMemWatch();  //5/13/08 Buttons removed (I didn't remove the code so it would be easy to add them back one day)
				break;			
			case 102: //Load button clicked
				//StopSound(); //mbg 5/7/08
				//LoadMemWatch();  //5/13/08 Buttons removed
				break;
			case 103: //Clear button clicked
				//ClearAllText();  //5/13/08 Buttons removed
				break;
			default:
				break;
			} 
#endif
		}
		
#if 0
		if(!(wParam>>16)) //Close button clicked
		{
			switch(wParam&0xFFFF)
			{
			case 1:
				//CloseMemoryWatch();  //5/13/08 Buttons removed
				break;
			}
		}
#endif
		
		break;
	default:
		break;
		
	}
	return 0;
}

//Open the Memory Watch dialog
void CreateMemWatch()
{
	if(NeedsInit) //Clear the strings
	{
		NeedsInit = 0;
		int i,j;
		for(i=0;i<NUMWATCHES;i++)
		{
			for(j=0;j<LABELLENGTH;j++)
			{
				addresses[i][j] = 0;
				labels[i][j] = 0;
			}
		}
	}

	if(hwndMemWatch) //If already open, give focus
	{
		ShowWindow(hwndMemWatch, SW_SHOWNORMAL);
		SetForegroundWindow(hwndMemWatch);
		return;
	}

	//Create
	HWND Parent;
	if (BindToMain)
		Parent = GetMainHWND();
	else
		Parent = NULL;

	hwndMemWatch=CreateDialog(fceu_hInstance,"MEMWATCH",Parent,MemWatchCallB);
	memwmenu=GetMenu(hwndMemWatch);
	UpdateMemWatch();
	memwrecentmenu = CreateMenu();

	// Update recent files menu
	UpdateMemw_RMenu(memwrecentmenu, memw_recent_files, ID_FILE_RECENT, MEMW_MENU_FIRST_RECENT_FILE);
		
	//Initialize values to previous entered addresses/labels
	{
		int i;
		for(i = 0; i < MWNUM; i++)
		{
			SetDlgItemText(hwndMemWatch,MW_VAL (i),(LPTSTR) "---");
			SetDlgItemText(hwndMemWatch,MW_ADDR(i),(LPTSTR) addresses[i]);
			SetDlgItemText(hwndMemWatch,MW_NAME(i),(LPTSTR) labels[i]);
		}
	}
	if (MemWatchLoadFileOnStart) OpenMemwatchRecentFile(0);
	else fileChanged = false;

	if (MemWCollapsed) 
	{
		MemWCollapsed = false;  //This is necessary in order for CollapseWindow to collapse properly
		CollapseWindow();		//If flagged as collapsed mode collapse
	}
}
void AddMemWatch(char memaddress[32])
{
 char TempArray[32];
	int i;
 CreateMemWatch();
	for(i = 0; i < MWNUM; i++)
	{
	 GetDlgItemText(hwndMemWatch,MW_ADDR(i),TempArray,32);
	 if (TempArray[0] == 0)
	 {
		 SetDlgItemText(hwndMemWatch,MW_ADDR(i),memaddress);
		 break;
		}
	}
}

void RamChange()
{
	if (!RamChangeInitialize) return;
	for (int x = 0; x < MAX_RAMMONITOR; x++)
	{
		int whichRec;
		if (x<2) whichRec = x;
		else whichRec = x+10;	//If ramchange monitor 3 or 4, must use 1st two of 2nd column (12 & 13)
		MWRec& mwrec = mwrecs[whichRec];
		
		if(mwrec.valid && GameInfo)
		{
			int whichADDR = 0;
			//Get proper Addr edit box
			switch (x)
			{
			case 0:
				whichADDR = 0; break;	//Addr 1
			case 1:
				whichADDR = 3; break;	//Addr 2
			case 2:
				whichADDR = 36; break;	//Addr 12
			case 3:
				whichADDR = 39; break;	//Addr 13
			}
			GetDlgItemText(hwndMemWatch, MW_ADDR00+(whichADDR), editboxnow[x], 6);	//Get Address value of edit00
			SetDlgItemText(hwndMemWatch, MEMW_EDIT00RMADDRESS+x, editboxnow[x]); //Put Address value
			editlast[x] = editnow[x];											//Update last value
			editnow[x] = GetMem(mwrec.addr);									//Update now value
					
			
			//Calculate Ram Change
			int z = SendDlgItemMessage(hwndMemWatch, MEMW_EDIT00FORMULA+x,(UINT) CB_GETTOPINDEX, 0,0);
			switch (z)
			{
			//Greater than------------------------------------
			case 0:
				if (editnow[x] > editlast[x])	editcount[x]++;
				break;
			//Greater by 1------------------------------------
			case 1:
				if (editnow[x]-editlast[x] == 1) editcount[x]++;
				else if ((editnow[x] == 0 && editlast[x]==255) || (editnow[x] == 0 && editlast[x]==65535)) editcount[x]++;
				break;
			//Less than---------------------------------------
			case 2:
				if (editnow[x]<editlast[x]) editcount[x]++;
				break;
			//Less by 1---------------------------------------
			case 3:
				if (editlast[x]-editnow[x] == 1) editcount[x]++;
				else if ((editlast[x] == 0 && editnow[x]==255) || (editlast[x] == 0 && editnow[x]==65535)) editcount[x]++;
				break;
			//Equal-------------------------------------------
			case 4:	
				if (editnow[x] == editlast[x]) editcount[x]++;
				break;
			//Not Equal---------------------------------------
			case 5:
				if (editnow[x] != editlast[x]) editcount[x]++;
				break;
			default:
				break;

			}
			sprintf(editchangem[x], "%d", editcount[x]);	//Convert counter to text
			SetDlgItemText(hwndMemWatch, EDIT00_RESULTS+x, editchangem[x]);	//Display text in results box
		}
		else
		{
			SetDlgItemText(hwndMemWatch, MEMW_EDIT00RMADDRESS+x, "");
		}
	} //End of for loop	
}

void RamChangeReset(int x)
{
	editcount[x] = 0;
	sprintf(editchangem[x], "%d", editcount[x]);					//Convert counter to text
	SetDlgItemText(hwndMemWatch, EDIT00_RESULTS+x, editchangem[x]);	//Display text in results box
}

void ChangeMemwMenuItemText(int menuitem, string text)
{
	MENUITEMINFO moo;
	moo.cbSize = sizeof(moo);
	moo.fMask = MIIM_TYPE;
	moo.cch = NULL;
	GetMenuItemInfo(memwmenu, menuitem, FALSE, &moo);
	moo.dwTypeData = (LPSTR)text.c_str();
	SetMenuItemInfo(memwmenu, menuitem, FALSE, &moo);
}

void CollapseWindow(void)
{
	RECT wrect;
		
	GetWindowRect(hwndMemWatch,&wrect);	//Get currect window size
		
	if (!MemWCollapsed)						//If window is full size collapse it
	{
		wrect.right = (wrect.right - ((wrect.right-wrect.left)/2));
		MemWCollapsed = true;
		SetDlgItemText(hwndMemWatch, MEMW_EXPANDCOLLAPSE, ">");
		ChangeMemwMenuItemText(MEMW_OPTIONS_EXPANDCOLLAPSE, "&Expand to 2 columns");
	}
	else									//Else expand it
	{
		wrect.right = (wrect.right + (wrect.right-wrect.left));
		MemWCollapsed = false;
		SetDlgItemText(hwndMemWatch, MEMW_EXPANDCOLLAPSE, "<");
		ChangeMemwMenuItemText(MEMW_OPTIONS_EXPANDCOLLAPSE, "&Collapse to 1 column");
	}
	
	SetWindowPos(hwndMemWatch,NULL,MemWatch_wndx,MemWatch_wndy,(wrect.right-wrect.left),(wrect.bottom-wrect.top),NULL);	
}