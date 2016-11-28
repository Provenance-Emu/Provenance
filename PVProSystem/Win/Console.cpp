// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Console.cpp
// ----------------------------------------------------------------------------
#include "Console.h"
#define WM_UNINITMENUPOPUP 0x125

std::string console_recent[10];
std::string console_savePath;
std::string console_SSS;

byte console_frameSkip = 0;
byte nf=0;

static const DWORD CONSOLE_WINDOW_STYLE = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
static const DWORD CONSOLE_WINDOW_STYLE_EX = WS_EX_CLIENTEDGE;
static HWND console_hWnd = NULL;
static HINSTANCE console_hInstance = NULL;
static bool console_suspended = false;
static bool console_rendering = false;
static RECT console_windowRect = {0};

// ----------------------------------------------------------------------------
// SetSize
// ----------------------------------------------------------------------------
static void console_SetSize(uint left, uint top, uint width, uint height) {
  if(!display_IsFullscreen( )) {
    GetWindowRect(console_hWnd, &console_windowRect);
    RECT resizeRect = {left, top, width - 1, height - 1};
    AdjustWindowRectEx(&resizeRect, CONSOLE_WINDOW_STYLE, menu_IsEnabled( ), CONSOLE_WINDOW_STYLE_EX);
    MoveWindow(console_hWnd, console_windowRect.left, console_windowRect.top, resizeRect.right - resizeRect.left, resizeRect.bottom - resizeRect.top, true);
  }  
}

// ----------------------------------------------------------------------------
// SetSuspended
// ----------------------------------------------------------------------------
static void console_SetSuspended(bool suspended) {
  console_suspended = suspended;
  if(suspended) {
    sound_Stop( );
  }
  else if(prosystem_active && !prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetCursorVisible
// ----------------------------------------------------------------------------
static void console_SetCursorVisible(bool visible) {
  if(visible) {
    ShowCursor(true);
  }
  else {
    while(ShowCursor(false) != -1) {
    }
  }
}

// ----------------------------------------------------------------------------
// Exit
// ----------------------------------------------------------------------------
void console_Exit( ) {
  configuration_Save(common_defaultPath + "ProSystem.ini");
  sound_Release( );
  display_Release( );
  input_Release( );
  DestroyWindow(console_hWnd);
}

// ----------------------------------------------------------------------------
// Close
// ----------------------------------------------------------------------------
static void console_Close( ) {
  prosystem_Close( );
  display_Clear( );
  sound_Stop( );
  sound_Clear( );
  SetWindowText(console_hWnd, CONSOLE_TITLE);
}

// ----------------------------------------------------------------------------
// Pause
// ----------------------------------------------------------------------------
static void console_Pause(bool pause) {
  prosystem_Pause(pause);
  if(pause) {
    sound_Stop( );
  }
  else {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// Reset
// ----------------------------------------------------------------------------
static void console_Reset( ) {
  sound_Stop( );
  prosystem_Reset( );
  sound_Play( );
}

// ----------------------------------------------------------------------------
// SetRegion
// ----------------------------------------------------------------------------
static void console_SetRegion(byte region) {
  sound_Stop( );
  region_type = region;
  region_Reset( );
  display_Clear( );
  display_ResetPalette( );
  console_SetZoom(display_zoom);
  display_Show( );
  if(!prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetMode
// ----------------------------------------------------------------------------
static void console_SetMode(Mode mode) {
  display_mode = mode;
  if(display_IsFullscreen( )) {
    console_SetFullscreen(true);
  }
}

// ----------------------------------------------------------------------------
// AddRecent
// ----------------------------------------------------------------------------
static void console_AddRecent(std::string filename) {
  byte slot;
  for(slot = 0; slot < 10; slot++) {
    if(console_recent[slot] == filename) {
      break;
    }
  }
  if(slot != 10) {
    for(byte index = 9; index > 0; index--) {
      std::string temp = (slot > index - 1)? console_recent[index - 1]: console_recent[index];
      console_recent[index] = temp;
    }      
  }
  else {
    for(byte index = 9; index > 0; index--) {
      console_recent[index] = console_recent[index - 1];
    }
  }
  console_recent[0] = filename;
}

// ----------------------------------------------------------------------------
// Open
// ----------------------------------------------------------------------------
static void console_Open( ) {
  console_SetCursorVisible(true);
  
  int filterIndex = 2;  
  char path[_MAX_PATH] = {0};
  if(cartridge_IsLoaded( )) {
    strcpy(path, cartridge_filename.c_str( ));
	nf=1;
    if(common_GetExtension(cartridge_filename) == ".zip") {
      filterIndex = 3;
    }
  }

  OPENFILENAME openDialog = {0};
  openDialog.lStructSize = sizeof(OPENFILENAME);
  openDialog.hwndOwner = console_hWnd;
  openDialog.lpstrFilter = "All Files (*.*)\0*.*\0Atari Files (*.a78)\0*.a78\0Zip Files (*.zip)\0*.zip\0";
  openDialog.nFilterIndex = filterIndex;
  openDialog.lpstrFile = path;
  openDialog.nMaxFile = _MAX_PATH;
  openDialog.nMaxFileTitle = _MAX_PATH;
  openDialog.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
  if(!cartridge_IsLoaded( )) {
    openDialog.lpstrInitialDir = console_recent[0].c_str( );
  }
  
  if(GetOpenFileName(&openDialog)) {
    console_Open(openDialog.lpstrFile);
	console_SSS=openDialog.lpstrFile;
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
static void console_Load( ) {
  console_SetCursorVisible(true);
  
  char path[_MAX_PATH] = {0};
  OPENFILENAME loadDialog = {0};
  loadDialog.lStructSize = sizeof(OPENFILENAME);
  loadDialog.hwndOwner = console_hWnd;
  loadDialog.lpstrFilter = "All Files (*.*)\0*.*\0Save Files (*.sav)\0*.sav\0Zip Files (*.zip)\0*.zip\0";
  loadDialog.nFilterIndex = 2;
  loadDialog.lpstrFile = path;
  loadDialog.nMaxFile = _MAX_PATH;
  loadDialog.nMaxFileTitle = _MAX_PATH;
  loadDialog.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
  loadDialog.lpstrInitialDir = console_savePath.c_str( );

  if(GetOpenFileName(&loadDialog)) {
    sound_Stop( );
    if(prosystem_Load(loadDialog.lpstrFile)) {
      console_savePath = loadDialog.lpstrFile;
      console_Pause(false);
    }
    sound_Play( );
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------
static void console_Save( ) {
  console_SetCursorVisible(true);  
  
  char buffer[_MAX_PATH] = {0};
  OPENFILENAME saveDialog = {0};
  saveDialog.lStructSize = sizeof(OPENFILENAME);
  saveDialog.hwndOwner = console_hWnd;
  saveDialog.lpstrFilter = "All Files (*.*)\0*.*\0Save Files (*.sav)\0*.sav\0Zip Files (*.zip)\0*.zip\0";
  saveDialog.nFilterIndex = 2;
  saveDialog.lpstrFile = buffer;
  saveDialog.nMaxFile = _MAX_PATH;
  saveDialog.nMaxFileTitle = _MAX_PATH;
  saveDialog.lpstrDefExt = "sav";
  saveDialog.lpstrInitialDir = console_savePath.c_str( );

  if(GetSaveFileName(&saveDialog)) {
    if(!prosystem_Save(saveDialog.lpstrFile, (saveDialog.nFilterIndex == 3)? true: false)) {
      logger_LogError(IDS_CONSOLE7,"");    
    }
    else {
      console_savePath = saveDialog.lpstrFile;
    }
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// SetMenuEnabled
// ----------------------------------------------------------------------------
void console_SetMenuEnabled(bool enabled) {
  sound_Stop( );
  menu_SetEnabled(enabled);
  if(!enabled && display_IsFullscreen( )) {
    console_SetCursorVisible(false);    
  }
  else {
    console_SetCursorVisible(true);
  }
  display_Clear( );
  console_SetZoom(display_zoom);
  display_Show( );
  if(!prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetUserInput
// ----------------------------------------------------------------------------
void console_SetUserInput(byte *data, int index) {

  static byte user_data[2];

  if ( user_data[index] != data[index] ) {
    user_data[index] = data[index];
    if ( data[index] ) {
      if ( index == 0 )
		console_SetMenuEnabled(!menu_IsEnabled( ));
      else
        console_Exit();
    }
  }
}

// ----------------------------------------------------------------------------
// SetDisplayStretched
// ----------------------------------------------------------------------------
static void console_SetDisplayStretched(bool stretched) {
  display_Clear( );
  display_stretched = stretched;
  display_Show( );
}

// ----------------------------------------------------------------------------
// OpenPaletteHook
// ----------------------------------------------------------------------------
static UINT CALLBACK console_OpenPaletteHook(HWND childDialog, UINT message, WPARAM wParam, LPARAM lParam) {
  switch(message) {
    case WM_INITDIALOG:
      SendMessage(GetParent(childDialog), CDM_SETCONTROLTEXT, 1038, (LONG)&"Default");
      break;
    case WM_NOTIFY:
      OFNOTIFY* notify = (OFNOTIFY*)lParam;
      if(notify->hdr.code == CDN_HELP) {
        notify->lpOFN->lCustData = true;
        PostMessage(GetParent(childDialog), WM_COMMAND, IDCANCEL, 0);
      }
      break;
  }
  return 0;
}

// ----------------------------------------------------------------------------
// OpenPalette
// ----------------------------------------------------------------------------
static void console_OpenPalette( ) {
  console_SetCursorVisible(true);
  
  char path[_MAX_PATH] = {0};
  strcpy(path, palette_filename.c_str( ));

  OPENFILENAME openDialog = {0};  
  openDialog.lStructSize = sizeof(OPENFILENAME);
  openDialog.hwndOwner = console_hWnd;
  openDialog.lpstrFilter = "All Files (*.*)\0*.*\0Palette Files (*.pal)\0*.pal\0";
  openDialog.nFilterIndex = 2;
  openDialog.lpstrFile = path;
  openDialog.nMaxFile = _MAX_PATH;
  openDialog.nMaxFileTitle = _MAX_PATH;
  openDialog.Flags = OFN_EXPLORER | OFN_ENABLEHOOK | OFN_SHOWHELP;
  openDialog.lpstrTitle = "Palette";
  openDialog.lCustData = false;
  openDialog.lpfnHook = console_OpenPaletteHook;
  
  if(GetOpenFileName(&openDialog) || openDialog.lCustData) {
    if(openDialog.lCustData) {
      palette_default = true;
      region_Reset( );
      display_ResetPalette( );
    }
    else {
      palette_default = false;
      palette_Load(openDialog.lpstrFile);
    }
    display_Clear( );
    display_ResetPalette( );
    display_Show( );
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }  
}

// ----------------------------------------------------------------------------
// SaveScreenshot
// ----------------------------------------------------------------------------
static void console_SaveScreenshot( ) {
  console_SetCursorVisible(true);  
  
   
  char buf[270];
  char bbf[20];
std::string console_S;  
  int position = console_SSS.rfind('.');
  if(position != -1) {
    console_S=console_SSS.substr(0, position);
  }
  if (screenshot1)
  {
  console_S=common_Remove(console_S,'!');
  console_S=common_Remove(console_S,'[');
  console_S=common_Remove(console_S,']');
  console_S=common_Remove(console_S,'(');
  console_S=common_Remove(console_S,')');
  console_S=common_Remove(console_S,',');
  }
  if (screenshot2)
  {
  console_S=common_Replace(console_S, ' ','_');
  }

  
  strcpy(buf,console_S.c_str());
  sprintf(bbf, "%.2d", nf);
  nf++;
  strcat(buf,"_");
  strcat(buf,bbf);
  strcat(buf,".bmp");
    

    if(!display_TakeScreenshot(buf)) {
      logger_LogError(IDS_CONSOLE1,"");
    }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// SaveScreenshot1
// ----------------------------------------------------------------------------
static void console_SaveScreenshot1( ) {
	screenshot1=! screenshot1;
  
}

// ----------------------------------------------------------------------------
// SaveScreenshot2
// ----------------------------------------------------------------------------
static void console_SaveScreenshot2( ) {
	screenshot2=! screenshot2;  
}

// ----------------------------------------------------------------------------
// OpenBiosHook
// ----------------------------------------------------------------------------
static UINT CALLBACK console_OpenHook(HWND childDialog, UINT message, WPARAM wParam, LPARAM lParam) {
  switch(message) {
    case WM_INITDIALOG:
      SendMessage(GetParent(childDialog), CDM_SETCONTROLTEXT, 1038, (LONG)&"Disable");    
      SendMessage(GetParent(childDialog), CDM_SETCONTROLTEXT, 1, (LONG)&"Enable");
      break;
    case WM_NOTIFY:
      OFNOTIFY* notify = (OFNOTIFY*)lParam;
      if(notify->hdr.code == CDN_HELP) {
        notify->lpOFN->lCustData = true;
        PostMessage(GetParent(childDialog), WM_COMMAND, IDCANCEL, 0);
      }
      break;
  }
  return 0;
}

// ----------------------------------------------------------------------------
// OpenBios
// ----------------------------------------------------------------------------
static void console_OpenBios( ) {
  console_SetCursorVisible(true);
  
  char path[_MAX_PATH] = {0};
  strcpy(path, bios_filename.c_str( ));
  
  int filterIndex = 2;
  if(common_GetExtension(bios_filename) == ".zip") {
    filterIndex = 3;
  }

  OPENFILENAME biosDialog = {0};  
  biosDialog.lStructSize = sizeof(OPENFILENAME);
  biosDialog.hwndOwner = console_hWnd;
  biosDialog.lpstrFilter = "All Files (*.*)\0*.*\0Bios Files (*.rom)\0*.rom\0Zip Files (*.zip)\0*.zip\0";
  biosDialog.nFilterIndex = filterIndex;
  biosDialog.lpstrFile = path;
  biosDialog.nMaxFile = _MAX_PATH;
  biosDialog.nMaxFileTitle = _MAX_PATH;
  biosDialog.Flags = OFN_EXPLORER | OFN_ENABLEHOOK | OFN_SHOWHELP;
  biosDialog.lpstrTitle = "Bios";
  biosDialog.lCustData = false;
  biosDialog.lpfnHook = console_OpenHook;  
  
  if(GetOpenFileName(&biosDialog) || biosDialog.lCustData) {
    if(biosDialog.lCustData) {
      bios_enabled = false;
    }
    else {
      bios_Load(biosDialog.lpstrFile);
      bios_enabled = true;
    }
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// SetSampleRate
// ----------------------------------------------------------------------------
static void console_SetSampleRate(uint sampleRate) {
  sound_Stop( );
  sound_SetSampleRate(sampleRate);
  menu_Refresh( );
  if(!prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetLatency
// ----------------------------------------------------------------------------
static void console_SetLatency(byte latency) {
  sound_Stop( );
  sound_latency = latency;
  if(!prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetMuted
// ----------------------------------------------------------------------------
static void console_SetMuted(bool muted) {
  sound_Stop( );
  sound_SetMuted(muted);
  if(!prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetFrameSkip
// ----------------------------------------------------------------------------
static void console_SetFrameSkip(byte frameSkip) {
  sound_Stop( );
  console_frameSkip = frameSkip;
  if(prosystem_active && !prosystem_paused) {
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// OpenDatabase
// ----------------------------------------------------------------------------
static void console_OpenDatabase( ) {
  console_SetCursorVisible(true);
  
  char path[_MAX_PATH] = {0};
  strcpy(path, database_filename.c_str( ));

  OPENFILENAME databaseDialog = {0};  
  databaseDialog.lStructSize = sizeof(OPENFILENAME);
  databaseDialog.hwndOwner = console_hWnd;
  databaseDialog.lpstrFilter = "All Files (*.*)\0*.*\0Database Files (*.dat)\0*.dat\0";
  databaseDialog.nFilterIndex = 2;
  databaseDialog.lpstrFile = path;
  databaseDialog.nMaxFile = _MAX_PATH;
  databaseDialog.nMaxFileTitle = _MAX_PATH;
  databaseDialog.Flags = OFN_EXPLORER | OFN_ENABLEHOOK | OFN_SHOWHELP;
  databaseDialog.lpstrTitle = "Database";
  databaseDialog.lCustData = false;
  databaseDialog.lpfnHook = console_OpenHook;  

  if(GetOpenFileName(&databaseDialog) || databaseDialog.lCustData) {
    if(databaseDialog.lCustData) {
      database_enabled = false;
    }
    else {
      database_filename = databaseDialog.lpstrFile;
      database_enabled = true;
    }
  }
  if(!menu_IsEnabled( ) && display_IsFullscreen( )) {
    console_SetCursorVisible(false);
  }
}

// ----------------------------------------------------------------------------
// Procedure
// ----------------------------------------------------------------------------
static LRESULT CALLBACK console_Procedure(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
  switch(message) {
    case WM_DESTROY:
      PostQuitMessage(0);
      break;
    case WM_CLOSE:
      console_Exit( );
      break;
    case WM_INITMENU:
      menu_Refresh( );
      break;
    case WM_UNINITMENUPOPUP:
      display_Show( );
      break;
    case WM_ENTERMENULOOP:
      console_SetSuspended(true);
      break;
    case WM_EXITMENULOOP:
      console_SetSuspended(false);
      break;
    case WM_COMMAND:
      switch((word)wParam) {
        case IDM_FILE_OPEN:
          console_Open( );
          break;
        case IDM_FILE_CLOSE:
          console_Close( );
          break;
        case IDM_RECENT_SLOT0:
          console_Open(console_recent[0]);
          break;
        case IDM_RECENT_SLOT1:
          console_Open(console_recent[1]);
          break;
        case IDM_RECENT_SLOT2:
          console_Open(console_recent[2]);
          break;
        case IDM_RECENT_SLOT3:
          console_Open(console_recent[3]);
          break;
        case IDM_RECENT_SLOT4:
          console_Open(console_recent[4]);
          break;
        case IDM_RECENT_SLOT5:
          console_Open(console_recent[5]);
          break;
        case IDM_RECENT_SLOT6:
          console_Open(console_recent[6]);
          break;
        case IDM_RECENT_SLOT7:
          console_Open(console_recent[7]);
          break;
        case IDM_RECENT_SLOT8:
          console_Open(console_recent[8]);
          break;
        case IDM_RECENT_SLOT9:
          console_Open(console_recent[9]);
          break;
        case IDM_FILE_SAVE:
          console_Save( );
          break;
        case IDM_FILE_LOAD:
          console_Load( );
          break;
        case IDM_FILE_EXIT:
          console_Exit( );
          break;
        case IDM_OPTIONS_RESET:
          console_Reset( );
          break;
        case IDM_OPTIONS_PAUSE:
          console_Pause(!prosystem_paused);
          break;
        case IDM_DISPLAY_FULLSCREEN:
          console_SetFullscreen(!display_IsFullscreen( ));
          break;
        case IDM_DISPLAY_STRETCHED:
          console_SetDisplayStretched(!display_stretched);
          break;
        case IDM_DISPLAY_PALETTE:
          console_OpenPalette( );
          break;
        case IDM_DISPLAY_ZOOM1:
          console_SetZoom(1);
          break;
        case IDM_DISPLAY_ZOOM2:
          console_SetZoom(2);
          break;
        case IDM_DISPLAY_ZOOM3:
          console_SetZoom(3);
          break;
        case IDM_DISPLAY_ZOOM4:
          console_SetZoom(4);
          break;
        case IDM_DISPLAY_SCREENSHOT:
          console_SaveScreenshot( );
          break;

//Leonis
        case ID_OPTIONS_DISPLAY_SCREENSHOT_REMOVENONWEBSYMBOLS:
          console_SaveScreenshot1( );
          break;
		case ID_OPTIONS_DISPLAY_SCREENSHOT_REPLACESPACESBY:
          console_SaveScreenshot2( );
          break;

        case IDM_SOUND_MUTE:
          console_SetMuted(!sound_IsMuted( ));
          break;
        case IDM_SAMPLERATE_11025:
          console_SetSampleRate(11025);
          break;
        case IDM_SAMPLERATE_22050:
          console_SetSampleRate(22050);
          break;
        case IDM_SAMPLERATE_31440:
          console_SetSampleRate(31440);
          break;
        case IDM_SAMPLERATE_44100:
          console_SetSampleRate(44100);
          break;
        case IDM_SAMPLERATE_48000:
          console_SetSampleRate(48000);
          break;
        case IDM_SAMPLERATE_96000:
          console_SetSampleRate(96000);
          break;
        case IDM_LATENCY_NONE:
          console_SetLatency(SOUND_LATENCY_NONE);
          break;
        case IDM_LATENCY_VERYLOW:
          console_SetLatency(SOUND_LATENCY_VERY_LOW);
          break;
        case IDM_LATENCY_LOW:
          console_SetLatency(SOUND_LATENCY_LOW);
          break;
        case IDM_LATENCY_MEDIUM:
          console_SetLatency(SOUND_LATENCY_MEDIUM);
          break;
        case IDM_LATENCY_HIGH:
          console_SetLatency(SOUND_LATENCY_HIGH);
          break;
        case IDM_LATENCY_VERYHIGH:
          console_SetLatency(SOUND_LATENCY_VERY_HIGH);
          break;
        case IDM_OPTIONS_MENU:
          console_SetMenuEnabled(!menu_IsEnabled( ));
          break;
        case IDM_REGION_AUTO:
          console_SetRegion(REGION_AUTO);
          break;
        case IDM_REGION_NTSC:
          console_SetRegion(REGION_NTSC);
          break;
        case IDM_REGION_PAL:
          console_SetRegion(REGION_PAL);
          break;
        case IDM_FRAMESKIP_0:
          console_SetFrameSkip(0);
          break;
        case IDM_FRAMESKIP_1:
          console_SetFrameSkip(1);
          break;
        case IDM_FRAMESKIP_2:
          console_SetFrameSkip(2);
          break;
        case IDM_FRAMESKIP_3:
          console_SetFrameSkip(3);
          break;
        case IDM_FRAMESKIP_4:
          console_SetFrameSkip(4);
          break;
        case IDM_FRAMESKIP_5:
          console_SetFrameSkip(5);
          break;
        case IDM_FRAMESKIP_6:
          console_SetFrameSkip(6);
          break;
        case IDM_FRAMESKIP_7:
          console_SetFrameSkip(7);
          break;
        case IDM_FRAMESKIP_8:
          console_SetFrameSkip(8);
          break;
        case IDM_FRAMESKIP_9:
          console_SetFrameSkip(9);
          break;
        case IDM_FRAMESKIP_10:
          console_SetFrameSkip(10);
          break;
        case IDM_FRAMESKIP_15:
          console_SetFrameSkip(15);
          break;
        case IDM_FRAMESKIP_20:
          console_SetFrameSkip(20);
          break;
        case IDM_FRAMESKIP_25:
          console_SetFrameSkip(25);
          break;
        case IDM_FRAMESKIP_30:
          console_SetFrameSkip(30);
          break;
        case IDM_EMULATION_BIOS:
          console_OpenBios( );
          break;
        case IDM_EMULATION_DATABASE:
          console_OpenDatabase( );
          break;
        case IDM_INPUT_CONTROLLER1:
          input_ShowController1Dialog(console_hWnd, console_hInstance);
          break;
        case IDM_INPUT_CONTROLLER2:
          input_ShowController2Dialog(console_hWnd, console_hInstance);
          break;
        case IDM_INPUT_CONSOLE:
          input_ShowConsoleDialog(console_hWnd, console_hInstance);
          break;
        case IDM_INPUT_USER:
          input_ShowUserDialog(console_hWnd, console_hInstance);
          break;
        case IDM_HELP_CONTENTS:
          help_ShowContents( );
          break;
        case IDM_HELP_ABOUT:
          about_Show(console_hWnd, console_hInstance);
          break;
        default:
          if((word)wParam >= IDM_MODES_BASE && (word)wParam < IDM_MODES_LAST) {
            int index = ((word)wParam) - IDM_MODES_BASE;
            if(index < display_modes.size( )) {
              console_SetMode(display_modes[index]);
            }
          }
          break;
      }
      break;
    case WM_ACTIVATE:
      console_SetSuspended(((word)(wParam) == WA_INACTIVE)? true: false);
      break;
    case WM_ENTERSIZEMOVE:
      console_SetSuspended(true);
      break;
    case WM_EXITSIZEMOVE:
      console_SetSuspended(false);
      break;
    case WM_ERASEBKGND:
      DefWindowProc(hWnd, message, wParam, lParam);
      if(!console_suspended) {
        display_Show( );
      }
      return 1;      
    case WM_PAINT:
      if(prosystem_paused || console_suspended) {
        display_Show( );
      }
      else {
        return DefWindowProc(hWnd, message, wParam, lParam);
      }
    default:
      return DefWindowProc(hWnd, message, wParam, lParam);
  }
  timer_Reset( );
  return 0;
}

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
bool console_Initialize(HINSTANCE hInstance, std::string commandLine) {
  std::string romfile;
  WNDCLASSEX wClass = {0};
  wClass.cbSize = sizeof(WNDCLASSEX);
  wClass.style = 0;
  wClass.lpfnWndProc = console_Procedure;
  wClass.cbClsExtra = 0;
  wClass.cbWndExtra = 0;
  wClass.hInstance = hInstance;
  wClass.hIconSm = (HICON)LoadImage(hInstance, MAKEINTRESOURCE(IDI_ICON_PROSYSTEM), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
  wClass.hIcon = (HICON)LoadImage(hInstance, MAKEINTRESOURCE(IDI_ICON_PROSYSTEM), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR);;
  wClass.hCursor = LoadCursor(NULL, IDC_ARROW);
  wClass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
  wClass.lpszMenuName = NULL;
  wClass.lpszClassName = CONSOLE_TITLE;
  
  if(!RegisterClassEx(&wClass)) {
    logger_LogError(IDS_CONSOLE2,"");
    logger_LogError(common_GetErrorMessage( ), "");
    return false;
  }
  
  database_Initialize( );
  timer_Initialize( );
  console_hInstance = hInstance;
  romfile = configuration_Load(common_defaultPath + "ProSystem.ini", commandLine);

  // Setup Display for Fullscreen or Windowed
  if ( display_fullscreen ) {
    console_hWnd = CreateWindowEx(WS_EX_TOPMOST, CONSOLE_TITLE, CONSOLE_TITLE, WS_POPUP, 0, 0, 0, 0, NULL, NULL, hInstance, NULL);
    if(!menu_Initialize(console_hWnd, hInstance)) {
      logger_LogError(IDS_CONSOLE3,"");
      return false;
	}
    menu_SetEnabled(display_menuenabled);
    if(!display_menuenabled) {
      console_SetCursorVisible(false);    
	}
	if(!display_Initialize(console_hWnd)) {
      logger_LogError(IDS_CONSOLE4,"");
      return false;
	}
    SetWindowPos(console_hWnd, NULL, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOMOVE);
    console_SetSize(0, 0, maria_visibleArea.GetLength( ) * display_zoom, maria_visibleArea.GetHeight( ) * display_zoom);
	if(!display_SetFullscreen( )) {
      logger_LogError(IDS_CONSOLE5,"");
      return false;
	}
  }
  else {
    console_hWnd = CreateWindowEx(CONSOLE_WINDOW_STYLE_EX, CONSOLE_TITLE, CONSOLE_TITLE, CONSOLE_WINDOW_STYLE, 0, 0, 0, 0, NULL, NULL, hInstance, NULL);
    if(!menu_Initialize(console_hWnd, hInstance)) {
      logger_LogError(IDS_CONSOLE3,"");
      return false;
	}
    menu_SetEnabled(display_menuenabled);
	if(!display_Initialize(console_hWnd)) {
      logger_LogError(IDS_CONSOLE4,"");
      return false;
	}
    SetWindowPos(console_hWnd, NULL, 0, 0, 0, 0, SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOMOVE | SWP_NOSIZE);
    console_SetSize(0, 0, maria_visibleArea.GetLength( ) * display_zoom, maria_visibleArea.GetHeight( ) * display_zoom);
	if(!display_SetWindowed( )) {
      logger_LogError(IDS_CONSOLE5,"");
      return false;
	}

  }
  if(!sound_Initialize(console_hWnd)) {
    logger_LogError(IDS_CONSOLE6,"");
    return false;
  }
  help_Initialize(console_hWnd);
  if(!input_Initialize(console_hWnd, hInstance)) {
    logger_LogError(IDS_CONSOLE6,"");
    return false;
  }

  ShowWindow(console_hWnd, SW_SHOW);
  display_Clear( );
  display_Show( );
  if ( !romfile.empty() )
    console_Open(common_Remove(romfile, '"'));
  else {
    console_SetMenuEnabled(true);
  }
  return true;
}

// ----------------------------------------------------------------------------
// Run
// ----------------------------------------------------------------------------
void console_Run( ) {
  MSG message;
  while(true) {
    if(PeekMessage(&message, NULL, 0, 0, PM_NOREMOVE( ))) {
      if(GetMessage(&message, NULL, 0, 0)) {
        if(!TranslateAccelerator(console_hWnd, menu_hAccel, &message)) {
          TranslateMessage(&message);
          DispatchMessage(&message);
        }
      }
      else {
        return;
      }
    }
    byte data[19];
    input_GetKeyboardState(data);
    if(prosystem_active && !prosystem_paused && !console_suspended) {
      if(!console_rendering) {
        prosystem_ExecuteFrame(data);
        console_rendering = true;
      }
      else if(timer_IsTime( )) {
        if(console_frameSkip == 0 || (prosystem_frame % (prosystem_frequency / console_frameSkip) != 0)) {
          display_Show( );
        }
        sound_Store( );
        console_rendering = false;
      }
    }
  }  
}

// ----------------------------------------------------------------------------
// Open
// ----------------------------------------------------------------------------
void console_Open(std::string filename) {
  if(cartridge_Load(filename)) {
    sound_Stop( );
    display_Clear( );
    database_Load(cartridge_digest);
    prosystem_Reset( );
    std::string title = std::string(CONSOLE_TITLE) + " - " + common_Trim(cartridge_title);
    SetWindowText(console_hWnd, title.c_str( ));
    console_AddRecent(filename);
    display_ResetPalette( );
    console_SetZoom(display_zoom);
    sound_Play( );
  }
}

// ----------------------------------------------------------------------------
// SetZoom
// ----------------------------------------------------------------------------
void console_SetZoom(byte zoom) {
  if(zoom >= 1 && zoom <= 4) {
    console_SetSize(0, 0, maria_visibleArea.GetLength( ) * zoom, maria_visibleArea.GetHeight( ) * zoom);
    display_zoom = zoom;
    display_Clear( );
    display_Show( );
  }
}

// ----------------------------------------------------------------------------
// SetFullscreen
// ----------------------------------------------------------------------------
void console_SetFullscreen(bool fullscreen) {
  if(fullscreen) {
    console_SetSuspended(true);
    GetWindowRect(console_hWnd, &console_windowRect);
	console_windowRect.left = 0;
	console_windowRect.right = 0;
	console_windowRect.bottom = display_mode.height;
	console_windowRect.right = display_mode.width;
	console_SetWindowRect(console_windowRect);
    display_SetFullscreen( );
	//SetWindowRect(console_hWnd, &console_windowRect);
    SetWindowLong(console_hWnd, GWL_EXSTYLE, WS_EX_TOPMOST);
    SetWindowLong(console_hWnd, GWL_STYLE, WS_POPUP);
    SetWindowPos(console_hWnd, NULL, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOMOVE);
    //SetWindowPos(console_hWnd, NULL, 0, 0, display_mode.width, display_mode.height, SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOMOVE);
	display_Clear( );
    if(!menu_IsEnabled( )) {
      console_SetCursorVisible(false);
    }
    console_SetZoom(display_zoom);
    display_Show( );
    console_SetSuspended(false);
  }
  else {
    console_SetSuspended(true);
    display_SetWindowed( );
    MoveWindow(console_hWnd, console_windowRect.left, console_windowRect.top, console_windowRect.right - console_windowRect.left, console_windowRect.bottom - console_windowRect.top, TRUE);
    SetWindowLong(console_hWnd, GWL_STYLE, CONSOLE_WINDOW_STYLE);
    SetWindowLong(console_hWnd, GWL_EXSTYLE, CONSOLE_WINDOW_STYLE_EX);
    SetWindowPos(console_hWnd, NULL, 0, 0, 0, 0, SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOMOVE | SWP_NOSIZE);
    console_SetCursorVisible(true);
    console_SetZoom(display_zoom);
    display_Show( );
    console_SetSuspended(false);
  }
}

// ----------------------------------------------------------------------------
// GetWindowRect
// ----------------------------------------------------------------------------
RECT console_GetWindowRect( ) {
  GetWindowRect(console_hWnd, &console_windowRect);
  return console_windowRect;
}

// ----------------------------------------------------------------------------
// SetWindowRect
// ----------------------------------------------------------------------------
void console_SetWindowRect(RECT windowRect) {
  console_windowRect = windowRect;
  MoveWindow(console_hWnd, console_windowRect.left, console_windowRect.top, console_windowRect.right - console_windowRect.left, console_windowRect.bottom - console_windowRect.top, true);
}
