#include "common.h"
#include "main.h"
#include "gui.h"

extern bool rightClickEnabled;	//Declared in window.cpp and only an extern here
extern bool fullscreenByDoubleclick;
extern bool SingleInstanceOnly;
char ManifestFilePath[2048];

bool ManifestFileExists()
{
			long endPos = 0;

			FILE * stream = fopen( ManifestFilePath, "r" );
			if (stream) {
			fseek( stream, 0L, SEEK_END );
			endPos = ftell( stream );
			fclose( stream );
			}

			return (endPos > 0);
}

/**
* Processes information from the GUI options dialog after
* the dialog was closed.
*
* @param hwndDlg Handle of the dialog window.
**/
void CloseGuiDialog(HWND hwndDlg)
{
	if(IsDlgButtonChecked(hwndDlg, CB_LOAD_FILE_OPEN) == BST_CHECKED)
	{
		eoptions |= EO_FOAFTERSTART;
	}
	else
	{
		eoptions &= ~EO_FOAFTERSTART;
	}

	if(IsDlgButtonChecked(hwndDlg, CB_AUTO_HIDE_MENU) == BST_CHECKED)
	{
		eoptions |= EO_HIDEMENU;
	}
	else
	{
		eoptions &= ~EO_HIDEMENU;
	}

	goptions &= ~(GOO_CONFIRMEXIT | GOO_DISABLESS);

	if(IsDlgButtonChecked(hwndDlg, CB_ASK_EXIT)==BST_CHECKED)
	{
		goptions |= GOO_CONFIRMEXIT;
	}

	if(IsDlgButtonChecked(hwndDlg, CB_DISABLE_SCREEN_SAVER)==BST_CHECKED)
	{
		goptions |= GOO_DISABLESS;
	}

	if(IsDlgButtonChecked(hwndDlg, CB_ENABLECONTEXTMENU)==BST_CHECKED)
		rightClickEnabled = true;
	else
		rightClickEnabled = false;

	if(IsDlgButtonChecked(hwndDlg, CB_FS_BY_DOUBLECLICK)==BST_CHECKED)
		fullscreenByDoubleclick = true;
	else
		fullscreenByDoubleclick = false;

	if(IsDlgButtonChecked(hwndDlg, IDC_SINGLEINSTANCE)==BST_CHECKED)
		SingleInstanceOnly = true;
	else
		SingleInstanceOnly = false;

	if(IsDlgButtonChecked(hwndDlg, CB_PARTIALVISUALTHEME)==BST_CHECKED)
	{
		FILE * stream = fopen( ManifestFilePath, "w" );
		if (stream) {
			fputs ("<\?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"\?>\n<assembly\n  xmlns=\"urn:schemas-microsoft-com:asm.v1\"\n  manifestVersion=\"1.0\">\n<assemblyIdentity\n    name=\"FCEUX\"\n    processorArchitecture=\"x86\"\n    version=\"1.0.0.0\"\n    type=\"win32\"/>\n<description>FCEUX</description>\n</assembly>\n",stream);
			fclose(stream);
		}
	}

	else
	{
		remove(ManifestFilePath);
	}


	EndDialog(hwndDlg,0);
}

/**
* Message loop of the GUI configuration dialog.
**/
BOOL CALLBACK GUIConCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_INITDIALOG:

			if(eoptions & EO_FOAFTERSTART)
			{
				CheckDlgButton(hwndDlg, CB_LOAD_FILE_OPEN, BST_CHECKED);
			}

			if(eoptions&EO_HIDEMENU)
			{
				CheckDlgButton(hwndDlg, CB_AUTO_HIDE_MENU, BST_CHECKED);
			}

			if(goptions & GOO_CONFIRMEXIT)
			{
				CheckDlgButton(hwndDlg, CB_ASK_EXIT, BST_CHECKED);
			}

			if(goptions & GOO_DISABLESS)
			{
				CheckDlgButton(hwndDlg, CB_DISABLE_SCREEN_SAVER, BST_CHECKED);
			}

			if(rightClickEnabled)
				CheckDlgButton(hwndDlg, CB_ENABLECONTEXTMENU, BST_CHECKED);

			if(fullscreenByDoubleclick)
				CheckDlgButton(hwndDlg, CB_FS_BY_DOUBLECLICK, BST_CHECKED);

			GetModuleFileName(0, ManifestFilePath, 2048);

			strcat((char*)ManifestFilePath,".manifest");

			if(ManifestFileExists()) {
				CheckDlgButton(hwndDlg, CB_PARTIALVISUALTHEME, BST_CHECKED);
			}

			if(SingleInstanceOnly){
				CheckDlgButton(hwndDlg, IDC_SINGLEINSTANCE, BST_CHECKED);
			}

			CenterWindowOnScreen(hwndDlg);

			break;

		case WM_CLOSE:
		case WM_QUIT:
			CloseGuiDialog(hwndDlg);

		case WM_COMMAND:
			if(!(wParam >> 16))
			{
				switch(wParam & 0xFFFF)
				{
					case BUTTON_CLOSE:
						CloseGuiDialog(hwndDlg);
				}
			}
	}

	return 0;
}

/**
* Shows the GUI configuration dialog.
**/
void ConfigGUI()
{
	DialogBox(fceu_hInstance, "GUICONFIG", hAppWnd, GUIConCallB);  
}