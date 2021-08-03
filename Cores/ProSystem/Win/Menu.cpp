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
// Menu.cpp
// ----------------------------------------------------------------------------
#include "Menu.h"

HACCEL menu_hAccel = NULL;

static HMENU menu_hMenu = NULL;
static HMENU menu_hFileMenu = NULL;
static HMENU menu_hOptionsMenu = NULL;
static HMENU menu_hRecentMenu = NULL;
static HMENU menu_hDisplayMenu = NULL;
static HMENU menu_hScreenshotMenu = NULL;
static HMENU menu_hModesMenu = NULL;
static HMENU menu_hSoundMenu = NULL;
static HMENU menu_hSampleRateMenu = NULL;
static HMENU menu_hLatencyMenu = NULL;
static HMENU menu_hEmulationMenu = NULL;
static HMENU menu_hFrameSkipMenu = NULL;
static HMENU menu_hRegionsMenu = NULL;
static HMENU menu_hInputMenu = NULL;
static HMENU menu_hHelpMenu = NULL;
static HWND menu_hWnd = NULL;

// ----------------------------------------------------------------------------
// RefreshDisplayMenu
// ----------------------------------------------------------------------------
static void menu_RefreshDisplayMenu( ) {
//Leonis
  CheckMenuItem(menu_hScreenshotMenu, 0, MF_BYPOSITION | ((screenshot1)? MF_CHECKED: MF_UNCHECKED));
  CheckMenuItem(menu_hScreenshotMenu, 1, MF_BYPOSITION | ((screenshot2)? MF_CHECKED: MF_UNCHECKED));

  CheckMenuItem(menu_hDisplayMenu, 0, MF_BYPOSITION | MF_UNCHECKED);  
  CheckMenuItem(menu_hDisplayMenu, 2, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hDisplayMenu, 5, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hDisplayMenu, 6, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hDisplayMenu, 7, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hDisplayMenu, 8, MF_BYPOSITION | MF_UNCHECKED);
  if(display_IsFullscreen( )) {
    CheckMenuItem(menu_hDisplayMenu, 0, MF_BYPOSITION | MF_CHECKED);
  }
  if(display_stretched) {
    CheckMenuItem(menu_hDisplayMenu, 2, MF_BYPOSITION | MF_CHECKED);
  }
  CheckMenuItem(menu_hDisplayMenu, display_zoom + 4, MF_BYPOSITION | MF_CHECKED);

  if(cartridge_IsLoaded( )) {
    EnableMenuItem(menu_hDisplayMenu, 10, MF_BYPOSITION | MF_ENABLED);
  }
  else {
    EnableMenuItem(menu_hDisplayMenu, 10, MF_BYPOSITION | MF_GRAYED);  
  }
}

// ----------------------------------------------------------------------------
// RefreshModesMenu
// ----------------------------------------------------------------------------
static void menu_RefreshModesMenu( ) {
  int count = GetMenuItemCount(menu_hModesMenu);
  int index;
  for(index = count - 1; index >= 0; index--) {
    DeleteMenu(menu_hModesMenu, index, MF_BYPOSITION);
  }

  count = 0;
  for(index = 0; index < display_modes.size( ); index++) {
    Mode mode = display_modes[index];
    if(mode.bpp == 8) {
      std::string description = common_Format(mode.width) + " x " + common_Format(mode.height);
      MENUITEMINFO item_info = {0};
      item_info.cbSize = sizeof(MENUITEMINFO);
      item_info.fMask = MIIM_DATA | MIIM_TYPE | MIIM_ID;
      item_info.dwItemData = (DWORD)&display_modes[index];
      item_info.dwTypeData = (char*)description.c_str( );
      item_info.wID = IDM_MODES_BASE + index;
      InsertMenuItem(menu_hModesMenu, count, TRUE, &item_info);
      if(display_mode.height == mode.height && display_mode.width == mode.width) {
        CheckMenuItem(menu_hModesMenu, count, MF_BYPOSITION | MF_CHECKED);
      }
      count++;
    }
  }    
}

// ----------------------------------------------------------------------------
// RefreshOptionsMenu
// ----------------------------------------------------------------------------
static void menu_RefreshOptionsMenu( ) {
  if(cartridge_IsLoaded( )) {
    EnableMenuItem(menu_hOptionsMenu, 0, MF_BYPOSITION | MF_ENABLED);
    EnableMenuItem(menu_hOptionsMenu, 1, MF_BYPOSITION | MF_ENABLED);
    CheckMenuItem(menu_hOptionsMenu, 1, MF_BYPOSITION | ((prosystem_paused)? MF_CHECKED: MF_UNCHECKED));
  }
  else {
    EnableMenuItem(menu_hOptionsMenu, 0, MF_BYPOSITION | MF_GRAYED);  
    EnableMenuItem(menu_hOptionsMenu, 1, MF_BYPOSITION | MF_GRAYED);
    CheckMenuItem(menu_hOptionsMenu, 1, MF_BYPOSITION | MF_UNCHECKED);
  }  
}

// ----------------------------------------------------------------------------
// RefreshRecentMenu
// ----------------------------------------------------------------------------
static void menu_RefreshRecentMenu( ) {
  for(uint slot = 0; slot < 10; slot++) {
    ModifyMenu(menu_hRecentMenu, slot, MF_BYPOSITION, IDM_RECENT_SLOT0 + slot, std::string("&" + common_Format(slot) + "  " + console_recent[slot]).c_str( ));
  }
}

// ----------------------------------------------------------------------------
// RefreshSoundMenu
// ----------------------------------------------------------------------------
static void menu_RefreshSoundMenu( ) {
  CheckMenuItem(menu_hSoundMenu, 0, MF_BYPOSITION | ((sound_IsMuted( ))? MF_CHECKED: MF_UNCHECKED));

  CheckMenuItem(menu_hSampleRateMenu, 0, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hSampleRateMenu, 1, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hSampleRateMenu, 2, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hSampleRateMenu, 3, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hSampleRateMenu, 4, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hSampleRateMenu, 5, MF_BYPOSITION | MF_UNCHECKED);

  switch(sound_GetSampleRate( )) {
    case 11025:
      CheckMenuItem(menu_hSampleRateMenu, 0, MF_BYPOSITION | MF_CHECKED);
      break;
    case 22050:
      CheckMenuItem(menu_hSampleRateMenu, 1, MF_BYPOSITION | MF_CHECKED);
      break;
    case 31440:
      CheckMenuItem(menu_hSampleRateMenu, 2, MF_BYPOSITION | MF_CHECKED);
      break;
    case 44100:
      CheckMenuItem(menu_hSampleRateMenu, 3, MF_BYPOSITION | MF_CHECKED);
      break;
    case 48000:
      CheckMenuItem(menu_hSampleRateMenu, 4, MF_BYPOSITION | MF_CHECKED);
      break;
    case 96000:
      CheckMenuItem(menu_hSampleRateMenu, 5, MF_BYPOSITION | MF_CHECKED);
      break;
  }

  CheckMenuItem(menu_hLatencyMenu, 0, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, 1, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, 2, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, 3, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, 4, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, 5, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hLatencyMenu, sound_latency, MF_BYPOSITION | MF_CHECKED);
}

// ----------------------------------------------------------------------------
// RefreshRegionsMenu
// ----------------------------------------------------------------------------
void menu_RefreshRegionsMenu( ) {
  CheckMenuItem(menu_hRegionsMenu, 0, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hRegionsMenu, 2, MF_BYPOSITION | MF_UNCHECKED);
  CheckMenuItem(menu_hRegionsMenu, 3, MF_BYPOSITION | MF_UNCHECKED);
  switch(region_type) {
    case REGION_AUTO:
      CheckMenuItem(menu_hRegionsMenu, 0, MF_BYPOSITION | MF_CHECKED);      
      break;
    case REGION_NTSC:
      CheckMenuItem(menu_hRegionsMenu, 2, MF_BYPOSITION | MF_CHECKED);
      break;
    case REGION_PAL:
      CheckMenuItem(menu_hRegionsMenu, 3, MF_BYPOSITION | MF_CHECKED);
      break;
  }  
}

// ----------------------------------------------------------------------------
// RefreshEmulationMenu
// ----------------------------------------------------------------------------
void menu_RefreshEmulationMenu( ) {
  CheckMenuItem(menu_hEmulationMenu, 2, MF_BYPOSITION | ((bios_enabled)? MF_CHECKED: MF_UNCHECKED));
  if(!cartridge_IsLoaded( )) {
    EnableMenuItem(menu_hEmulationMenu, 0, MF_BYPOSITION | MF_ENABLED);
    EnableMenuItem(menu_hEmulationMenu, 2, MF_BYPOSITION | MF_ENABLED);
  }
  else {
    EnableMenuItem(menu_hEmulationMenu, 0, MF_BYPOSITION | MF_GRAYED);
    EnableMenuItem(menu_hEmulationMenu, 2, MF_BYPOSITION | MF_GRAYED);
  }

  CheckMenuItem(menu_hEmulationMenu, 3, MF_BYPOSITION | ((database_enabled)? MF_CHECKED: MF_UNCHECKED));
  for(int index = 0; index < 15; index++) {
    CheckMenuItem(menu_hFrameSkipMenu, index, MF_BYPOSITION | MF_UNCHECKED);
  }
  switch(console_frameSkip) {
    case 0:
    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
    case 6:
    case 7:
    case 8:
    case 9:
    case 10:
      CheckMenuItem(menu_hFrameSkipMenu, console_frameSkip, MF_BYPOSITION | MF_CHECKED);
      break;
    case 15:
      CheckMenuItem(menu_hFrameSkipMenu, 11, MF_BYPOSITION | MF_CHECKED);      
      break;
    case 20:
      CheckMenuItem(menu_hFrameSkipMenu, 12, MF_BYPOSITION | MF_CHECKED);
      break;
    case 25:
      CheckMenuItem(menu_hFrameSkipMenu, 13, MF_BYPOSITION | MF_CHECKED);
      break;
    case 30:
      CheckMenuItem(menu_hFrameSkipMenu, 14, MF_BYPOSITION | MF_CHECKED);
      break;
  }
}

// ----------------------------------------------------------------------------
// RefreshFileMenu
// ----------------------------------------------------------------------------
void menu_RefreshFileMenu( ) {
  if(cartridge_IsLoaded( )) {
    EnableMenuItem(menu_hFileMenu, 1, MF_BYPOSITION | MF_ENABLED);
    EnableMenuItem(menu_hFileMenu, 4, MF_BYPOSITION | MF_ENABLED);
    EnableMenuItem(menu_hFileMenu, 5, MF_BYPOSITION | MF_ENABLED);
  }
  else {
    EnableMenuItem(menu_hFileMenu, 1, MF_BYPOSITION | MF_GRAYED);
    EnableMenuItem(menu_hFileMenu, 4, MF_BYPOSITION | MF_GRAYED);
    EnableMenuItem(menu_hFileMenu, 5, MF_BYPOSITION | MF_GRAYED);
  }
}

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
bool menu_Initialize(HWND hWnd, HINSTANCE hInstance) {
  if(hWnd == NULL) {
    logger_LogError(IDS_INPUT1,"");
  }
  if(hInstance == NULL) {
    logger_LogError(IDS_INPUT2,"");
    return false;
  }
  
  menu_hMenu = LoadMenu(hInstance, MAKEINTRESOURCE(IDR_MENU_MAIN));
  if(menu_hMenu == NULL) {
    logger_LogError(IDS_MENU2,"");
    logger_LogError("",common_GetErrorMessage( ));
    return false;
  }
  
  if(!SetMenu(hWnd, menu_hMenu)) {
    logger_LogError(IDS_MENU3,"");
    logger_LogError("",common_GetErrorMessage( ));
    return false;
  }
  
  menu_hAccel = LoadAccelerators(hInstance, MAKEINTRESOURCE(IDR_ACCELERATOR));
  if(menu_hAccel == NULL) {
    logger_LogError(IDS_MENU4,"");
    logger_LogError("",common_GetErrorMessage( ));
    return false;
  }

  menu_hFileMenu = GetSubMenu(menu_hMenu, 0);
  if(menu_hFileMenu == NULL) {
    logger_LogError(IDS_MENU5,"");
    return false;
  }     
  
  menu_hRecentMenu = GetSubMenu(menu_hFileMenu, 2);
  if(menu_hRecentMenu == NULL) {
    logger_LogError(IDS_MENU6,"");
    return false;
  }
  
  menu_hOptionsMenu = GetSubMenu(menu_hMenu, 1);
  if(menu_hOptionsMenu == NULL) {
    logger_LogError(IDS_MENU7,"");
    return false;
  }
  
  menu_hDisplayMenu = GetSubMenu(menu_hOptionsMenu, 3);
  if(menu_hDisplayMenu == NULL) {
    logger_LogError(IDS_MENU8,"");
    return false;
  }

  menu_hScreenshotMenu = GetSubMenu(menu_hDisplayMenu, 10);
  if(menu_hScreenshotMenu == NULL) {
    logger_LogError(IDS_MENU8,"");
    return false;
  }
  
  menu_hModesMenu = GetSubMenu(menu_hDisplayMenu, 1);
  if(menu_hModesMenu == NULL) {
    logger_LogError(IDS_MENU9,"");
    return false;
  }
  
  menu_hSoundMenu = GetSubMenu(menu_hOptionsMenu, 4);
  if(menu_hSoundMenu == NULL) {
    logger_LogError(IDS_MENU10,"");
    return false;
  }
  
  menu_hSampleRateMenu = GetSubMenu(menu_hSoundMenu, 2);
  if(menu_hSampleRateMenu == NULL) {
    logger_LogError(IDS_MENU11,"");
    return false;
  }
  
  menu_hLatencyMenu = GetSubMenu(menu_hSoundMenu, 3);
  if(menu_hLatencyMenu == NULL) {
    logger_LogError(IDS_MENU11,"");
    return false;
  }
  
  menu_hEmulationMenu = GetSubMenu(menu_hOptionsMenu, 5);
  if(menu_hEmulationMenu == NULL) {
    logger_LogError(IDS_MENU12,"");
    return false;
  }
  
  menu_hRegionsMenu = GetSubMenu(menu_hEmulationMenu, 0);
  if(menu_hRegionsMenu == NULL) {
    logger_LogError(IDS_MENU13,"");
    return false;
  }
  
  menu_hFrameSkipMenu = GetSubMenu(menu_hEmulationMenu, 1);
  if(menu_hFrameSkipMenu == NULL) {
    logger_LogError(IDS_MENU14,"");
    return false;
  }

  menu_hInputMenu = GetSubMenu(menu_hOptionsMenu, 6);
  if(menu_hInputMenu == NULL) {
    logger_LogError(IDS_MENU15,"");
    return false;  
  }
  
  menu_hHelpMenu = GetSubMenu(menu_hMenu, 2);
  if(menu_hHelpMenu == NULL) {
    logger_LogError(IDS_MENU16,"");
    return false;
  }

  menu_hWnd = hWnd;
  return true;
}

// ----------------------------------------------------------------------------
// Refresh
// ----------------------------------------------------------------------------
void menu_Refresh( ) {
  menu_RefreshFileMenu( );
  menu_RefreshDisplayMenu( );
  menu_RefreshModesMenu( );
  menu_RefreshRecentMenu( );
  menu_RefreshOptionsMenu( );
  menu_RefreshSoundMenu( );
  menu_RefreshRegionsMenu( );
  menu_RefreshEmulationMenu( );
}

// ----------------------------------------------------------------------------
// SetEnabled
// ----------------------------------------------------------------------------
void menu_SetEnabled(bool enabled) {
  if(enabled) {
    SetMenu(menu_hWnd, menu_hMenu);  
  }
  else {
    SetMenu(menu_hWnd, NULL);
  }  
}

// ----------------------------------------------------------------------------
// IsEnabled
// ----------------------------------------------------------------------------
bool menu_IsEnabled( ) {
  return (GetMenu(menu_hWnd) == NULL)? false: true;
}