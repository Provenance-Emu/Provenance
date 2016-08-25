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
#include "../../fceu.h"
#include "../../cart.h" //mbg merge 7/18/06 moved beneath fceu.h
#include "../../x6502.h"
#include "../../debug.h"
#include "debugger.h"
#include "tracer.h"
#include "cdlogger.h"
#include "main.h" //for GetRomName()
#include "utils/xstring.h"

#define INESPRIV
#include "../../ines.h"

#include "../../nsf.h"

using namespace std;

bool LoadCDLog(const char* nameo);
void LoadCDLogFile();
void SaveCDLogFileAs();
void SaveCDLogFile();
void SaveStrippedROM(int invert);
void CDLoggerROMClosed();
void CDLoggerROMChanged();
bool PauseCDLogging();
void StartCDLogging();
void FreeCDLog();
void InitCDLog();
void ResetCDLog();
void RenameCDLog(const char* newName);

extern iNES_HEADER head; //defined in ines.c
extern uint8 *trainerpoo;

//---------CDLogger VROM
extern volatile int rendercount, vromreadcount, undefinedvromcount;
extern unsigned char *cdloggervdata;
extern unsigned int cdloggerVideoDataSize;
extern int newppu;

extern uint8 *NSFDATA;
extern int NSFMaxBank;
static uint8 NSFLoadLow;
static uint8 NSFLoadHigh;

HWND hCDLogger;
int CDLogger_wndx=0, CDLogger_wndy=0;
bool autosaveCDL = true;
bool autoloadCDL = true;
bool autoresumeCDLogging = false;
char loadedcdfile[2048] = {0};

BOOL CALLBACK CDLoggerCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_DROPFILES:
			{
				UINT len;
				char *ftmp;

				len=DragQueryFile((HDROP)wParam,0,0,0)+1;
				if((ftmp=(char*)malloc(len)))
				{
					DragQueryFile((HDROP)wParam,0,ftmp,len);
					string fileDropped = ftmp;
					//adelikat:  Drag and Drop only checks file extension, the internal functions are responsible for file error checking
					//-------------------------------------------------------
					//Check if .tbl
					//-------------------------------------------------------
					if (!(fileDropped.find(".cdl") == string::npos) && (fileDropped.find(".cdl") == fileDropped.length()-4))
					{
						if(!LoadCDLog(fileDropped.c_str()))
							FCEUD_PrintError("Error Opening CDL File!");
					}
					else
					{
						std::string str = "Could not open " + fileDropped;
						MessageBox(hwndDlg, str.c_str(), "File error", 0);
					}
				}
			}

			break;

		case WM_MOVE:
		{
			if (!IsIconic(hwndDlg))
			{
				RECT wrect;
				GetWindowRect(hwndDlg,&wrect);
				CDLogger_wndx = wrect.left;
				CDLogger_wndy = wrect.top;
				WindowBoundsCheckNoResize(CDLogger_wndx,CDLogger_wndy,wrect.right);
			}
			break;
		};
		case WM_INITDIALOG:
			if (CDLogger_wndx==-32000) CDLogger_wndx=0; //Just in case
			if (CDLogger_wndy==-32000) CDLogger_wndy=0;
			SetWindowPos(hwndDlg, 0, CDLogger_wndx, CDLogger_wndy, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
			hCDLogger = hwndDlg;
			InitCDLog();
			ResetCDLog();
			RenameCDLog("");
			if (autoloadCDL)
			{
				char nameo[2048];
				strcpy(nameo, GetRomPath());
				strcat(nameo, mass_replace(GetRomName(), "|", ".").c_str());
				strcat(nameo, ".cdl");
				LoadCDLog(nameo);
			}
			SetDlgItemText(hCDLogger, ID_CDLFILENAME, loadedcdfile);
			CheckDlgButton(hCDLogger, IDC_AUTOSAVECDL, autosaveCDL ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hCDLogger, IDC_AUTOLOADCDL, autoloadCDL ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hCDLogger, IDC_AUTORESUMECDLOGGING, autoresumeCDLogging ? BST_CHECKED : BST_UNCHECKED);
			break;
		case WM_CLOSE:
		case WM_QUIT:
			if (PauseCDLogging())
			{
				if (autosaveCDL)
					SaveCDLogFile();
				FreeCDLog();
				RenameCDLog("");
				hCDLogger = 0;
				EndDialog(hwndDlg, 0);
			}
			break;
		case WM_COMMAND:
			switch(HIWORD(wParam))
			{
				case BN_CLICKED:
				{
					switch(LOWORD(wParam))
					{
						case BTN_CDLOGGER_RESET:
						{
							ResetCDLog();
							UpdateCDLogger();
							break;
						}
						case BTN_CDLOGGER_LOAD:
							LoadCDLogFile();
							break;
						case BTN_CDLOGGER_START_PAUSE:
							if (FCEUI_GetLoggingCD())
								PauseCDLogging();
							else
								StartCDLogging();
							break;
						case BTN_CDLOGGER_SAVE_AS:
							SaveCDLogFileAs();
							break;
						case BTN_CDLOGGER_SAVE:
							SaveCDLogFile();
							break;
						case BTN_CDLOGGER_SAVE_STRIPPED:
							SaveStrippedROM(0);
							break;
						case BTN_CDLOGGER_SAVE_UNUSED:
							SaveStrippedROM(1);
							break;
						case IDC_AUTOSAVECDL:
							autosaveCDL = (IsDlgButtonChecked(hCDLogger, IDC_AUTOSAVECDL) == BST_CHECKED);
							break;
						case IDC_AUTOLOADCDL:
							autoloadCDL = (IsDlgButtonChecked(hCDLogger, IDC_AUTOLOADCDL) == BST_CHECKED);
							break;
						case IDC_AUTORESUMECDLOGGING:
							autoresumeCDLogging = (IsDlgButtonChecked(hCDLogger, IDC_AUTORESUMECDLOGGING) == BST_CHECKED);
							break;
					}
					break;
				}
			}
			break;
		case WM_MOVING:
			break;
	}
	return FALSE;
}

bool LoadCDLog(const char* nameo)
{
	FILE *FP;
	int i,j;

	FP = fopen(nameo, "rb");
	if (FP == NULL)
		return false;

	for(i = 0;i < (int)cdloggerdataSize;i++)
	{
		j = fgetc(FP);
		if (j == EOF)
			break;
		if ((j & 1) && !(cdloggerdata[i] & 1))
			codecount++; //if the new byte has something logged and
		if ((j & 2) && !(cdloggerdata[i] & 2))
			datacount++; //and the old one doesn't. Then increment
		if ((j & 3) && !(cdloggerdata[i] & 3))
			undefinedcount--; //the appropriate counter.
		cdloggerdata[i] |= j;
	}

	if(cdloggerVideoDataSize != 0)
	{
		for(i = 0;i < (int)cdloggerVideoDataSize;i++)
		{
			j = fgetc(FP);
			if(j == EOF)break;
			if((j & 1) && !(cdloggervdata[i] & 1))rendercount++; //if the new byte has something logged and
			if((j & 2) && !(cdloggervdata[i] & 2))vromreadcount++; //if the new byte has something logged and
			if((j & 3) && !(cdloggervdata[i] & 3))undefinedvromcount--; //the appropriate counter.
			cdloggervdata[i] |= j;
		}
	}

	fclose(FP);
	RenameCDLog(nameo);
	UpdateCDLogger();
	return true;
}

void LoadCDLogFile()
{
	const char filter[]="Code Data Log File (*.CDL)\0*.cdl\0\0";
	char nameo[2048];
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Load Code Data Log File...";
	ofn.lpstrFilter=filter;
	nameo[0]=0;
	ofn.lpstrFile=nameo;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hCDLogger;
	if (!GetOpenFileName(&ofn))
		return;
	if(!LoadCDLog(nameo))
		FCEUD_PrintError("Error Opening CDL File!");
}

void SaveCDLogFileAs()
{
	const char filter[]="Code Data Log File (*.CDL)\0*.cdl\0All Files (*.*)\0*.*\0\0";
	char nameo[2048] = {0};
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Save Code Data Log File As...";
	ofn.lpstrFilter=filter;
	if (loadedcdfile[0])
	{
		strcpy(nameo, loadedcdfile);
	} else
	{
		strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
		strcat(nameo, ".cdl");
	}
	ofn.lpstrDefExt = "cdl";
	ofn.lpstrFile = nameo;
	ofn.nMaxFile = 256;
	ofn.Flags = OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hCDLogger;
	if (!GetSaveFileName(&ofn))
		return;
	RenameCDLog(nameo);
	SaveCDLogFile();
}

void SaveCDLogFile()
{
	if (loadedcdfile[0] == 0)
	{
		char nameo[2048];
		strcpy(nameo, GetRomPath());
		strcat(nameo, mass_replace(GetRomName(), "|", ".").c_str());
		strcat(nameo, ".cdl");
		RenameCDLog(nameo);
	}

	FILE *FP;
	FP = fopen(loadedcdfile, "wb");
	if (FP == NULL)
	{
		FCEUD_PrintError("Error Saving File");
		return;
	}
	fwrite(cdloggerdata, cdloggerdataSize, 1, FP);
	if(cdloggerVideoDataSize != 0)
		fwrite(cdloggervdata, cdloggerVideoDataSize, 1, FP);
	fclose(FP);
}

// returns false if refused to start
bool DoCDLogger()
{
	if (!GameInfo)
	{
		FCEUD_PrintError("You must have a game loaded before you can use the Code Data Logger.");
		return false;
	}

	if(!hCDLogger)
	{
		CreateDialog(fceu_hInstance,"CDLOGGER",NULL,CDLoggerCallB);
	} else
	{
		ShowWindow(hCDLogger, SW_SHOWNORMAL);
		SetForegroundWindow(hCDLogger);
	}
	return true;
}

void UpdateCDLogger()
{
	if(!hCDLogger) return;

	char str[50];
	float fcodecount = codecount;
	float fdatacount = datacount;
	float frendercount = rendercount;
	float fvromreadcount = vromreadcount;
	float fundefinedcount = undefinedcount;
	float fundefinedvromcount = undefinedvromcount;
	float fromsize = cdloggerdataSize;
	float fvromsize = (cdloggerVideoDataSize != 0) ? cdloggerVideoDataSize : 1;

	sprintf(str,"0x%06x  %.2f%%", codecount, (fcodecount / fromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_CODECOUNT, str);
	sprintf(str,"0x%06x  %.2f%%", datacount,(fdatacount / fromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_DATACOUNT, str);
	sprintf(str,"0x%06x  %.2f%%", undefinedcount, (fundefinedcount / fromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_UNDEFCOUNT, str);

	sprintf(str,"0x%06x  %.2f%%", rendercount, (frendercount / fvromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_RENDERCOUNT, str);
	sprintf(str,"0x%06x  %.2f%%", vromreadcount, (fvromreadcount / fvromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_VROMREADCOUNT, str);
	sprintf(str,"0x%06x  %.2f%%", undefinedvromcount, (fundefinedvromcount / fvromsize) * 100);
	SetDlgItemText(hCDLogger, LBL_CDLOGGER_UNDEFVROMCOUNT, str);
	return;
}

void SaveStrippedROM(int invert)
{
	//this is based off of iNesSave()
	//todo: make this support NSFs
	const char NESfilter[]="Stripped iNes Rom file (*.NES)\0*.nes\0All Files (*.*)\0*.*\0\0";
	const char NSFfilter[]="Stripped NSF file (*.NSF)\0*.nsf\0All Files (*.*)\0*.*\0\0";
	char sromfilename[MAX_PATH];
	FILE *fp;
	OPENFILENAME ofn;
	iNES_HEADER cdlhead;
	int i;

	if (!GameInfo)
		return;

	if (GameInfo->type==GIT_NSF)
	{
		MessageBox(NULL, "Sorry, you're not allowed to save optimized NSFs yet. Please don't optimize individual banks, as there are still some issues with several NSFs to be fixed, and it is easier to fix those issues with as much of the bank data intact as possible.", "Disallowed", MB_OK);
		return;
	}

	if(codecount == 0)
	{
		MessageBox(NULL, "Unable to Generate Stripped ROM. Get Something Logged and try again.", "Error", MB_OK);
		return;
	}
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Save Stripped File As...";
	strcpy(sromfilename, mass_replace(GetRomName(), "|", ".").c_str());
	if (GameInfo->type==GIT_NSF) {
		ofn.lpstrFilter=NSFfilter;
		ofn.lpstrDefExt = "nsf";
	}	else {
		ofn.lpstrFilter=NESfilter;
		ofn.lpstrDefExt = "nes";
	}
	ofn.lpstrFile=sromfilename;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hCDLogger;
	if(!GetSaveFileName(&ofn))return;

	fp = fopen(sromfilename,"wb");
	if(!fp) 
	{
		FCEUD_PrintError("Error opening target stripped rom file!");
		return;
	}

	if(GameInfo->type==GIT_NSF)
	{
		//Not used because if bankswitching, the addresses involved
		//could still end up being used through writes
		//static uint16 LoadAddr;
		//LoadAddr=NSFHeader.LoadAddressLow;
		//LoadAddr|=(NSFHeader.LoadAddressHigh&0x7F)<<8;

		//Simple store/restore for writing a working NSF header
		NSFLoadLow = NSFHeader.LoadAddressLow;
		NSFLoadHigh = NSFHeader.LoadAddressHigh;
		NSFHeader.LoadAddressLow=0;
		NSFHeader.LoadAddressHigh&=0xF0;
		fwrite(&NSFHeader,1,0x8,fp);
		NSFHeader.LoadAddressLow = NSFLoadLow;
		NSFHeader.LoadAddressHigh = NSFLoadHigh;

		fseek(fp,0x8,SEEK_SET);
		for(i = 0;i < ((NSFMaxBank+1)*4096);i++){
			unsigned char pchar;
			if(cdloggerdata[i] & 3)
				pchar = invert?0:NSFDATA[i];
			else
				pchar = invert?NSFDATA[i]:0;
			fputc(pchar, fp);
		}

	}
	else
	{
		cdlhead.ID[0] = 'N';
		cdlhead.ID[1] = 'E';
		cdlhead.ID[2] = 'S';
		cdlhead.ID[3] = 0x1A;

		cdlhead.ROM_size = cdloggerdataSize >> 14;
		cdlhead.VROM_size = cdloggerVideoDataSize >> 13;

		fwrite(&cdlhead,1,16,fp);

		for(i = 0; i < (int)cdloggerdataSize; i++){
			unsigned char pchar;
			if(cdloggerdata[i] & 3)
				pchar = invert?0:PRGptr[0][i];
			else
				pchar = invert?PRGptr[0][i]:0;
			fputc(pchar, fp);
		}

		if(cdloggerVideoDataSize != 0)
		{
			// since the OldPPU at least logs the $2007 read accesses, we should save the data anyway
			for(i = 0; i < (int)cdloggerVideoDataSize; i++) {
				unsigned char vchar;
				if(cdloggervdata[i] & 3)
					vchar = invert?0:CHRptr[0][i];
				else
					vchar = invert?CHRptr[0][i]:0;
				fputc(vchar, fp);
			}
		}
	}
	fclose(fp);
}

void CDLoggerROMClosed()
{
	if (hCDLogger)
	{
		PauseCDLogging();
		if (autosaveCDL)
			SaveCDLogFile();
	}
}

void CDLoggerROMChanged()
{
	if (hCDLogger)
	{
		FreeCDLog();
		InitCDLog();
		ResetCDLog();
		RenameCDLog("");
		UpdateCDLogger();
	}

	if (!autoresumeCDLogging)
		return;

	// try to load respective CDL file
	char nameo[2048];
	strcpy(nameo, GetRomPath());
	strcat(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	strcat(nameo, ".cdl");

	FILE *FP;
	FP = fopen(nameo, "rb");
	if (FP != NULL)
	{
		// .cdl file with this ROM name exists
		fclose(FP);
		if (!hCDLogger)
			DoCDLogger();
		if (LoadCDLog(nameo))
			StartCDLogging();
	}
}

bool PauseCDLogging()
{
	// can't pause while Trace Logger is using
	if ((logging) && (logging_options & LOG_NEW_INSTRUCTIONS))
	{
		MessageBox(hCDLogger, "The Trace Logger is currently using this for some of its features.\nPlease turn the Trace Logger off and try again.","Unable to Pause Code/Data Logger", MB_OK);
		return false;
	}
	FCEUI_SetLoggingCD(0);
	EnableTracerMenuItems();
	SetDlgItemText(hCDLogger, BTN_CDLOGGER_START_PAUSE, "Start");
	return true;
}

void StartCDLogging()
{
	FCEUI_SetLoggingCD(1);
	EnableTracerMenuItems();
	SetDlgItemText(hCDLogger, BTN_CDLOGGER_START_PAUSE, "Pause");
}

void FreeCDLog()
{
	if (cdloggerdata)
	{
		free(cdloggerdata);
		cdloggerdata = NULL;
		cdloggerdataSize = 0;
	}
	if (cdloggervdata)
	{
		free(cdloggervdata);
		cdloggervdata = NULL;
		cdloggerVideoDataSize = 0;
	}
}

void InitCDLog()
{
	cdloggerdataSize = PRGsize[0];
	cdloggerdata = (unsigned char*)malloc(cdloggerdataSize);
	if(!CHRram[0] || (CHRptr[0] == PRGptr[0])) {	// Some kind of workaround for my OneBus VRAM hack, will remove it if I find another solution for that
		cdloggerVideoDataSize = CHRsize[0];
		cdloggervdata = (unsigned char*)malloc(cdloggerVideoDataSize);
	} else {
		cdloggerVideoDataSize = 0;
		cdloggervdata = (unsigned char*)malloc(8192);
	}
}

void ResetCDLog()
{
	codecount = datacount = rendercount = vromreadcount = 0;
	undefinedcount = cdloggerdataSize;
	ZeroMemory(cdloggerdata, cdloggerdataSize);
	if(cdloggerVideoDataSize != 0) {
		undefinedvromcount = cdloggerVideoDataSize;
		ZeroMemory(cdloggervdata, cdloggerVideoDataSize);
	} else {
		undefinedvromcount = 8192;
		ZeroMemory(cdloggervdata, 8192);
	}
}

void RenameCDLog(const char* newName)
{
	strcpy(loadedcdfile, newName);
	if (hCDLogger)
	{
		SetDlgItemText(hCDLogger, ID_CDLFILENAME, loadedcdfile);
	}
}
