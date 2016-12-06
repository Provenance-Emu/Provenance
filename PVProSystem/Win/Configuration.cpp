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
// Configuration.cpp
// ----------------------------------------------------------------------------
#include "Configuration.h"
#include "Console.h"


bool configuration_enabled = true;
bool screenshot1=false;
bool screenshot2=false;
uint samplerate;


static const std::string CONFIGURATION_SECTION_CONSOLE = "Console";
static const std::string CONFIGURATION_SECTION_RECENT = "Recent";
static const std::string CONFIGURATION_SECTION_DISPLAY = "Display";
static const std::string CONFIGURATION_SECTION_SOUND = "Sound";
static const std::string CONFIGURATION_SECTION_EMULATION = "Emulation";
static const std::string CONFIGURATION_SECTION_INPUT = "Input";

static std::string configuration_filename;

// ----------------------------------------------------------------------------
// CommandLine
// ----------------------------------------------------------------------------
std::string configuration_CommandLine(std::string commandLine) {
  char **argv;
  int argc,i;
  std::string tmp_string;

  argc = __argc;
  argv = __argv;
  for ( i = 1; i < argc; ++i ) {
      if ( strstr(argv[i],"-Fullscreen") || strstr(argv[i],"-fullscreen") ) {
        if ( ++i < argc ) {
          if ( atoi(argv[i]) )
            display_fullscreen = true;
		  else
            display_fullscreen = false;
		}
      }

	  else if ( strstr(argv[i],"-MenuEnabled") || strstr(argv[i],"-menuenabled") ) {
        if ( ++i < argc ) {
          if ( atoi(argv[i]) )
            display_menuenabled = true;
		  else
            display_menuenabled = false;
		}
      }

	  else if ( strstr(argv[i],"-Palette") || strstr(argv[i],"-palette") ) {
        if ( ++i < argc ) {
          tmp_string = argv[i];
		  palette_default = false;
          palette_Load(common_Remove(tmp_string,'"'));
		}
      }

	  else if ( strstr(argv[i],"-Zoom") || strstr(argv[i],"-zoom") ) {
        if ( ++i < argc ) {
          display_zoom = atoi(argv[i]);
		}
      }

	  else if ( strstr(argv[i],"-Mute") || strstr(argv[i],"-mute") ) {
        if ( ++i < argc ) {
          if ( atoi(argv[i]) )
            sound_SetMuted(true);
		  else
            sound_SetMuted(false);
		}
      }

	  else if ( strstr(argv[i],"-Latency") || strstr(argv[i],"-latency") ) {
        if ( ++i < argc ) {
          sound_latency = atoi(argv[i]);
		}
      }

	  else if ( strstr(argv[i],"-SampleRate") || strstr(argv[i],"-samplerate") ) {
        if ( ++i < argc ) {
          sound_SetSampleRate ( atoi(argv[i]) );
		  samplerate=atoi(argv[i]);
		}
      }

	  else if ( strstr(argv[i],"-Region") || strstr(argv[i],"-region") ) {
        if ( ++i < argc ) {
          if ( strstr(argv[i],"PAL") )
            region_type = REGION_PAL;
		  else if ( strstr(argv[i],"NTSC") )
            region_type = REGION_NTSC;
          else
            region_type = REGION_AUTO;
		}
      }

	  else {
        return tmp_string = argv[i];
      }

  } /* end for each argument */
  menu_Refresh( );
  return tmp_string = "";
}

// ----------------------------------------------------------------------------
// HasKey
// ----------------------------------------------------------------------------
static bool configuration_HasKey(std::string section, std::string name) {
  char value[128];
  GetPrivateProfileString(section.c_str( ), name.c_str( ), "__TEST__", value, 128, configuration_filename.c_str( ));
  std::string test = value;
  if(test != "__TEST__") {
    return true;
  }
  return false;
}

// ----------------------------------------------------------------------------
// WritePrivatePath
// ----------------------------------------------------------------------------
static void configuration_WritePrivatePath(std::string section, std::string name, std::string path) {
  WritePrivateProfileString(section.c_str( ), name.c_str( ), path.c_str( ), configuration_filename.c_str( ));
}

// ----------------------------------------------------------------------------
// WritePrivateBool
// ----------------------------------------------------------------------------
static void configuration_WritePrivateBool(std::string section, std::string name, bool value) {
  WritePrivateProfileString(section.c_str( ), name.c_str( ), common_Format(value).c_str( ), configuration_filename.c_str( ));
}

// ----------------------------------------------------------------------------
// WritePrivateUint
// ----------------------------------------------------------------------------
static void configuration_WritePrivateUint(std::string section, std::string name, uint value) {
  WritePrivateProfileString(section.c_str( ), name.c_str( ), common_Format(value).c_str( ), configuration_filename.c_str( ));
}

// ----------------------------------------------------------------------------
// ReadPrivatePath
// ----------------------------------------------------------------------------
static std::string configuration_ReadPrivatePath(std::string section, std::string name, std::string defaultValue) {
  char path[_MAX_PATH];
  GetPrivateProfileString(section.c_str( ), name.c_str( ), defaultValue.c_str( ), path, _MAX_PATH, configuration_filename.c_str( ));
  return path;
}

// ----------------------------------------------------------------------------
// ReadPrivateBool
// ----------------------------------------------------------------------------
static bool configuration_ReadPrivateBool(std::string section, std::string name, std::string defaultValue) {
  char value[6];
  GetPrivateProfileString(section.c_str( ), name.c_str( ), defaultValue.c_str( ), value, 6, configuration_filename.c_str( ));
  return common_ParseBool(value);
}

// ----------------------------------------------------------------------------
// ReadPrivateUint
// ----------------------------------------------------------------------------
static uint configuration_ReadPrivateUint(std::string section, std::string name, uint value) {
  return GetPrivateProfileInt(section.c_str( ), name.c_str( ), value, configuration_filename.c_str( ));
}

// ----------------------------------------------------------------------------
// Load
// ----------------------------------------------------------------------------
std::string configuration_Load(std::string filename, std::string commandLine) {
  configuration_filename = filename; 
  for(uint index = 0; index < 10; index++) {
    console_recent[index] = configuration_ReadPrivatePath(CONFIGURATION_SECTION_RECENT, "Recent" + common_Format(index), "");
  }
  
  RECT windowRect = {0};
  windowRect.left = configuration_ReadPrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Left", 0);
  windowRect.top = configuration_ReadPrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Top", 0);
  windowRect.right = configuration_ReadPrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Right", 0);
  windowRect.bottom = configuration_ReadPrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Bottom", 0);
  console_SetWindowRect(windowRect);

  display_stretched = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "Stretched", "false");
//Leonis
  screenshot1 = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "Screenshot1", "false");
  screenshot2 = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "Screenshot2", "false");

  display_mode.width = configuration_ReadPrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.Width", 640);
  display_mode.height = configuration_ReadPrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.Height", 480);
  display_mode.bpp = configuration_ReadPrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.BPP", 8);
  
  if(configuration_HasKey(CONFIGURATION_SECTION_DISPLAY, "Palette.Default") && configuration_HasKey(CONFIGURATION_SECTION_DISPLAY, "Palette.Filename")) {
    palette_default = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "Palette.Default", "true");
    if(!palette_default) {
      palette_Load(configuration_ReadPrivatePath(CONFIGURATION_SECTION_DISPLAY, "Palette.Filename", ""));
    }
  }

  display_zoom = configuration_ReadPrivateUint(CONFIGURATION_SECTION_DISPLAY, "Zoom", 1);
  if ( !strstr(commandLine.c_str(),"Fullscreen") && 
       !strstr(commandLine.c_str(),"fullscreen") )
  display_fullscreen = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "Fullscreen", "false");
  if ( !strstr(commandLine.c_str(),"MenuEnabled") && 
       !strstr(commandLine.c_str(),"menuenabled") )
  display_menuenabled = configuration_ReadPrivateBool(CONFIGURATION_SECTION_DISPLAY, "MenuEnabled", "true");
  
  sound_SetMuted(configuration_ReadPrivateBool(CONFIGURATION_SECTION_SOUND, "Mute", "false"));
  sound_latency = configuration_ReadPrivateUint(CONFIGURATION_SECTION_SOUND, "Latency", 1);
  sound_SetSampleRate(configuration_ReadPrivateUint(CONFIGURATION_SECTION_SOUND, "Sample.Rate", 44100));
  samplerate=configuration_ReadPrivateUint(CONFIGURATION_SECTION_SOUND, "Sample.Rate", 44100);

  region_type = configuration_ReadPrivateUint(CONFIGURATION_SECTION_EMULATION, "Region", 2);
  console_frameSkip = configuration_ReadPrivateUint(CONFIGURATION_SECTION_EMULATION, "Frame.Skip", 0);
  
  if(configuration_HasKey(CONFIGURATION_SECTION_EMULATION, "Bios.Enabled") && configuration_HasKey(CONFIGURATION_SECTION_EMULATION, "Bios.Filename")) {
    bios_enabled = configuration_ReadPrivateBool(CONFIGURATION_SECTION_EMULATION, "Bios.Enabled", "false");
    if(bios_enabled) {
      bios_Load(configuration_ReadPrivatePath(CONFIGURATION_SECTION_EMULATION, "Bios.Filename", ""));
    }
  }
  
  if(configuration_HasKey(CONFIGURATION_SECTION_EMULATION, "Database.Enabled") && configuration_HasKey(CONFIGURATION_SECTION_EMULATION, "Database.Filename")) {
    database_enabled = configuration_ReadPrivateBool(CONFIGURATION_SECTION_EMULATION, "Database.Enabled", "true");
    if(database_enabled) {
      database_filename = configuration_ReadPrivatePath(CONFIGURATION_SECTION_EMULATION, "Database.Filename", "");
    }
  }
  
  for(index = 0; index < 17; index++) {
    input_keys[index] = configuration_ReadPrivateUint(CONFIGURATION_SECTION_INPUT, "Key" + common_Format(index), input_keys[index]);
    input_devices[index] = configuration_ReadPrivateUint(CONFIGURATION_SECTION_INPUT, "Device" + common_Format(index), input_devices[index]);
  }
  for(index = 0; index < 2; index++) {
    user_keys[index] = configuration_ReadPrivateUint(CONFIGURATION_SECTION_INPUT, "User_Key" + common_Format(index), user_keys[index]);
    user_devices[index] = configuration_ReadPrivateUint(CONFIGURATION_SECTION_INPUT, "User_Device" + common_Format(index), user_devices[index]);
    user_modifiers[index] = configuration_ReadPrivateUint(CONFIGURATION_SECTION_INPUT, "User_Modifier" + common_Format(index), user_modifiers[index]);
  }

  console_savePath = configuration_ReadPrivatePath(CONFIGURATION_SECTION_CONSOLE, "Save.Path", "");
  
  return configuration_CommandLine(commandLine);
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------
void configuration_Save(std::string filename) {
  configuration_filename = filename; 
  for(uint index = 0; index < 10; index++) {
    configuration_WritePrivatePath(CONFIGURATION_SECTION_RECENT, "Recent" + common_Format(index), console_recent[index]);
  }

  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "Fullscreen", display_IsFullscreen( ));
  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "MenuEnabled", menu_IsEnabled( ));
  configuration_WritePrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.Height", display_mode.height);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.Width", display_mode.width);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_DISPLAY, "Mode.BPP", display_mode.bpp);
  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "Palette.Default", palette_default);
  configuration_WritePrivatePath(CONFIGURATION_SECTION_DISPLAY, "Palette.Filename", palette_filename);
  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "Stretched", display_stretched);

//Leonis
  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "Screenshot1", screenshot1);
  configuration_WritePrivateBool(CONFIGURATION_SECTION_DISPLAY, "Screenshot2", screenshot2);
  
  configuration_WritePrivateUint(CONFIGURATION_SECTION_DISPLAY, "Zoom", display_zoom);
  
  configuration_WritePrivateBool(CONFIGURATION_SECTION_SOUND, "Mute", sound_IsMuted( ));

  configuration_WritePrivateUint(CONFIGURATION_SECTION_SOUND, "Sample.Rate", sound_GetSampleRate( ));
  configuration_WritePrivateUint(CONFIGURATION_SECTION_SOUND, "Latency", sound_latency);

  configuration_WritePrivateUint(CONFIGURATION_SECTION_EMULATION, "Region", region_type);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_EMULATION, "Frame.Skip", console_frameSkip);
  configuration_WritePrivatePath(CONFIGURATION_SECTION_EMULATION, "Bios.Filename", bios_filename);
  configuration_WritePrivateBool(CONFIGURATION_SECTION_EMULATION, "Bios.Enabled", bios_enabled);
  configuration_WritePrivatePath(CONFIGURATION_SECTION_EMULATION, "Database.Filename", database_filename);
  configuration_WritePrivateBool(CONFIGURATION_SECTION_EMULATION, "Database.Enabled", database_enabled);

  for(index = 0; index < 17; index++) {
    configuration_WritePrivateUint(CONFIGURATION_SECTION_INPUT, "Key" + common_Format(index), input_keys[index]);
    configuration_WritePrivateUint(CONFIGURATION_SECTION_INPUT, "Device" + common_Format(index), input_devices[index]);
  }
  for(index = 0; index < 2; index++) {
    configuration_WritePrivateUint(CONFIGURATION_SECTION_INPUT, "User_Key" + common_Format(index), user_keys[index]);
    configuration_WritePrivateUint(CONFIGURATION_SECTION_INPUT, "User_Device" + common_Format(index), user_devices[index]);
    configuration_WritePrivateUint(CONFIGURATION_SECTION_INPUT, "User_Modifier" + common_Format(index), user_modifiers[index]);
  }
  configuration_WritePrivatePath(CONFIGURATION_SECTION_CONSOLE, "Save.Path", console_savePath);

  RECT windowRect = console_GetWindowRect( );
  configuration_WritePrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Left", windowRect.left);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Top", windowRect.top);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Right", windowRect.right);
  configuration_WritePrivateUint(CONFIGURATION_SECTION_CONSOLE, "Window.Bottom", windowRect.bottom);
}
