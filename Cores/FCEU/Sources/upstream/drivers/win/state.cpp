#include "common.h"
#include "../../version.h"
#include "../../state.h"
#include <string>
#include <string.h>
#include <fstream>

using namespace std;

//Externs
extern string GetBackupFileName();			//Declared in src/state.cpp

/**
* Show an Save File dialog and save a savegame state to the selected file.
**/
void FCEUD_SaveStateAs()
{
	const char filter[] = FCEU_NAME" Save State (*.fc?)\0*.fc?\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	OPENFILENAME ofn;

	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hInstance = fceu_hInstance;
	ofn.lpstrTitle = "Save State As...";
	ofn.lpstrFilter = filter;
	strcpy(nameo,FCEU_MakeFName(FCEUMKF_STATE,CurrentState,0).c_str());
	ofn.lpstrFile = nameo;
	ofn.lpstrDefExt = "fcs";
	std::string initdir = FCEU_GetPath(FCEUMKF_STATE);
	ofn.lpstrInitialDir = initdir.c_str();
	ofn.nMaxFile = 256;
	ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;

	if(GetSaveFileName(&ofn))
		FCEUI_SaveState(nameo);
}

/**
* Show an Open File dialog and load a savegame state from the selected file.
**/
void FCEUD_LoadStateFrom()
{
	const char filter[]= FCEU_NAME" Save State (*.fc?)\0*.fc?\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	OPENFILENAME ofn;

	// Create and show an Open File dialog.
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Load State From...";
	ofn.lpstrFilter=filter;
	nameo[0]=0;
	ofn.lpstrFile=nameo;
	std::string initdir = FCEU_GetPath(FCEUMKF_STATE);
	ofn.lpstrInitialDir = initdir.c_str();
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;

	if(GetOpenFileName(&ofn))
	{
		// Load save state if a file was selected.
		FCEUI_LoadState(nameo);
	}
}