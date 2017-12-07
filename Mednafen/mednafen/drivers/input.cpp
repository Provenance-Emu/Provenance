/* Mednafen - Multi-system Emulator
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"

#include <string.h>
#include <ctype.h>
#include <trio/trio.h>
#include <map>

#include "input.h"
#include "input-config.h"
#include "sound.h"
#include "video.h"
#include "Joystick.h"
#include "netplay.h"
#include "cheat.h"
#include "fps.h"
#include "debugger.h"
#include "help.h"
#include "rmdui.h"

#include <math.h>

extern JoystickManager *joy_manager;

bool RewindState = true;
bool DNeedRewind = false;

static uint32 MouseData[3];
static double MouseDataRel[2];

static unsigned int autofirefreq;
static unsigned int ckdelay;

static bool fftoggle_setting;
static bool sftoggle_setting;

int ConfigDevice(int arg);
static void ConfigDeviceBegin(void);

static void subcon_begin(std::vector<ButtConfig> &bc);
static int subcon(const char *text, std::vector<ButtConfig> &bc, int commandkey);

static void ResyncGameInputSettings(unsigned port);

static char keys[MKK_COUNT];
static char keys_untouched[MKK_COUNT];

static std::string BCToString(const ButtConfig &bc)
{
 std::string string = "";
 char tmp[256];

 if(bc.ButtType == BUTTC_KEYBOARD)
 {
  trio_snprintf(tmp, 256, "keyboard %d", bc.ButtonNum & 0xFFFF);

  string = string + std::string(tmp);

  if(bc.ButtonNum & (4 << 24))
   string = string + "+ctrl";
  if(bc.ButtonNum & (1 << 24))
   string = string + "+alt";
  if(bc.ButtonNum & (2 << 24))
   string = string + "+shift";
 }
 else if(bc.ButtType == BUTTC_JOYSTICK)
 {
  trio_snprintf(tmp, 256, "joystick %016llx %08x", (unsigned long long)bc.DeviceID, bc.ButtonNum);

  string = string + std::string(tmp);
 }
 else if(bc.ButtType == BUTTC_MOUSE)
 {
  trio_snprintf(tmp, 256, "mouse %016llx %08x", (unsigned long long)bc.DeviceID, bc.ButtonNum);

  string = string + std::string(tmp);
 }
 return(string);
}

static std::string BCsToString(const ButtConfig *bc, unsigned int n)
{
 std::string ret = "";

 for(unsigned int x = 0; x < n; x++)
 {
  if(bc[x].ButtType)
  {
   if(x) ret += "~";
   ret += BCToString(bc[x]);
  }
 }

 return(ret);
}

static std::string BCsToString(const std::vector<ButtConfig> &bc, const bool AND_Mode = false)
{
 std::string ret = "";

 if(AND_Mode)
  ret += "/&&\\ ";

 for(unsigned int x = 0; x < bc.size(); x++)
 {
  if(x) ret += "~";
  ret += BCToString(bc[x]);
 }

 return(ret);
}


static bool StringToBC(const char *string, std::vector<ButtConfig> &bc)
{
 bool AND_Mode = false;
 char device_name[64];
 char extra[256];
 ButtConfig tmp_bc;

 while(*string && *string <= 0x20) string++;

 if(!strncmp(string, "/&&\\", 4))
 {
  AND_Mode = true;
  string += 4;
 }

 while(*string && *string <= 0x20) string++;

 do
 {
  if(trio_sscanf(string, "%63s %255[^~]", device_name, extra) == 2)
  {
   if(!strcasecmp(device_name, "keyboard"))
   {
    uint32 bnum = atoi(extra);
  
    if(strstr(extra, "+shift"))
     bnum |= 2 << 24;
    if(strstr(extra, "+alt"))
     bnum |= 1 << 24;
    if(strstr(extra, "+ctrl"))
     bnum |= 4 << 24;

    tmp_bc.ButtType = BUTTC_KEYBOARD;
    tmp_bc.DeviceNum = 0;
    tmp_bc.ButtonNum = bnum;
    tmp_bc.DeviceID = 0;

    bc.push_back(tmp_bc);
   }
   else if(!strcasecmp(device_name, "joystick"))
   {
    tmp_bc.ButtType = BUTTC_JOYSTICK;
    tmp_bc.DeviceNum = 0;
    tmp_bc.ButtonNum = 0;
    tmp_bc.DeviceID = 0;

    trio_sscanf(extra, "%016llx %08x", &tmp_bc.DeviceID, &tmp_bc.ButtonNum);

    tmp_bc.DeviceNum = joy_manager->GetIndexByUniqueID(tmp_bc.DeviceID);
    bc.push_back(tmp_bc);
   }
   else if(!strcasecmp(device_name, "mouse"))
   {
    tmp_bc.ButtType = BUTTC_MOUSE;
    tmp_bc.DeviceNum = 0;
    tmp_bc.ButtonNum = 0;
    tmp_bc.DeviceID = 0;
  
    if(trio_sscanf(extra, "%016llx %08x", &tmp_bc.DeviceID, &tmp_bc.ButtonNum) < 2)
     trio_sscanf(extra, "%d", &tmp_bc.ButtonNum);

    bc.push_back(tmp_bc);
   }
  }
  string = strchr(string, '~');
  if(string) string++;
 } while(string);

 return(AND_Mode);
}

static char *CleanSettingName(char *string)
{
 size_t x = 0;

 while(string[x])
 {
  if(string[x] == ' ')
   string[x] = '_';
  else if(string[x] >= 'A' && string[x] <= 'Z')
   string[x] = 'a' + string[x] - 'A';
  x++;
 }
 return string;
}

struct ButtonInfoCache
{
 char* SettingName = NULL;
 char* CPName = NULL;
 const InputDeviceInputInfoStruct* IDII = NULL;

 std::vector<ButtConfig> BC;
 int BCPrettyPrio = 0;

 unsigned Flags = 0;
 uint16 BitOffsets[4] = { 0, 0, 0, 0 };	// [rotated]
 uint16 ExclusionBitOffset = 0xFFFF;
 InputDeviceInputType Type = IDIT_BUTTON;
 bool Rapid = false;

 uint8 SwitchNumPos = 0;
 uint8 SwitchLastPos = 0;
 uint8 SwitchBitSize = 0;
 bool SwitchLastPress = false;
};

struct StatusInfoCache
{
 const InputDeviceInputInfoStruct* IDII = NULL;
 uint32 BitOffset = 0;

 uint32 StatusNumStates = 0;
 uint32 StatusLastState = 0;
 uint32 StatusBitSize = 0;
};

struct RumbleInfoCache
{
 const InputDeviceInputInfoStruct* IDII = NULL;
 uint32 BitOffset = 0;
 uint32 AssocBICIndex = 0;
};

struct PortInfoCache
{
 unsigned int CurrentDeviceIndex = 0; // index into [SOMETHING HERE]
 uint8 *Data = NULL;
 const InputDeviceInfoStruct* Device = NULL;

 std::vector<ButtonInfoCache> BIC;
 std::vector<StatusInfoCache> SIC;
 std::vector<RumbleInfoCache> RIC;

 float AxisScale = 0;
};

static PortInfoCache PIDC[16];

static void KillPortInfo(unsigned int port)
{
 PIDC[port].Data = NULL;
 PIDC[port].Device = NULL;

 for(unsigned int x = 0; x < PIDC[port].BIC.size(); x++)
 {
  free(PIDC[port].BIC[x].CPName);
  free(PIDC[port].BIC[x].SettingName);
 }

 PIDC[port].BIC.clear();
 PIDC[port].SIC.clear();
 PIDC[port].RIC.clear();
}

static void BuildPortInfo(MDFNGI *gi, const unsigned int port)
{
 const InputDeviceInfoStruct *zedevice = NULL;
 char *port_device_name;
 unsigned int device;
 
 PIDC[port].AxisScale = 1.0;

  if(gi->PortInfo[port].DeviceInfo.size() > 1)
  {  
   if(CurGame->DesiredInput.size() > port && CurGame->DesiredInput[port])
   {
    port_device_name = strdup(CurGame->DesiredInput[port]);
   }
   else
   {
    char tmp_setting_name[512];
    trio_snprintf(tmp_setting_name, 512, "%s.input.%s", gi->shortname, gi->PortInfo[port].ShortName);
    port_device_name = strdup(MDFN_GetSettingS(tmp_setting_name).c_str());
   }
  }
  else
  {
   port_device_name = strdup(gi->PortInfo[port].DeviceInfo[0].ShortName);
  }

  for(device = 0; device < gi->PortInfo[port].DeviceInfo.size(); device++)
  {
   if(!strcasecmp(gi->PortInfo[port].DeviceInfo[device].ShortName, port_device_name))
   {
    zedevice = &gi->PortInfo[port].DeviceInfo[device];
    break;
   }
  }
  free(port_device_name); port_device_name = NULL;

  PIDC[port].CurrentDeviceIndex = device;

  assert(zedevice);

  PIDC[port].Device = zedevice;

  // Figure out how much data should be allocated for each port
  bool analog_axis_scale_grabbed = false;

  for(auto const& idii : zedevice->IDII)
  {
   // Handle dummy/padding button entries(the setting name will be NULL in such cases)
   if(idii.SettingName == NULL)
    continue;   

   if(idii.Type == IDIT_BUTTON_ANALOG && (idii.Flags & IDIT_BUTTON_ANALOG_FLAG_SQLR) && !analog_axis_scale_grabbed)
   {
    char tmpsn[512];

    trio_snprintf(tmpsn, sizeof(tmpsn), "%s.input.%s.%s.axis_scale", gi->shortname, gi->PortInfo[port].ShortName, zedevice->ShortName);
    PIDC[port].AxisScale = MDFN_GetSettingF(tmpsn);
    analog_axis_scale_grabbed = true;
   }

   if(idii.Type == IDIT_BUTTON || idii.Type == IDIT_BUTTON_CAN_RAPID
	 || idii.Type == IDIT_BUTTON_ANALOG || idii.Type == IDIT_X_AXIS || idii.Type == IDIT_Y_AXIS
	 || idii.Type == IDIT_SWITCH)
   {
    for(unsigned r = 0; r < ((idii.Type == IDIT_BUTTON_CAN_RAPID) ? 2 : 1); r++)
    {
     ButtonInfoCache bic;

     bic.IDII = &idii;
     bic.SettingName = trio_aprintf("%s.input.%s.%s.%s%s", gi->shortname, gi->PortInfo[port].ShortName, zedevice->ShortName, (r ? "rapid_" : ""), idii.SettingName);
     CleanSettingName(bic.SettingName);
     StringToBC(MDFN_GetSettingS(bic.SettingName).c_str(), bic.BC);

     for(unsigned o = 0; o < 4; o++)
     {
      bic.BitOffsets[o] = idii.BitOffset;
     }

     if(idii.Type == IDIT_SWITCH)
     {
      bic.SwitchNumPos = idii.SwitchNumPos;
      bic.SwitchLastPos = 0;
      bic.SwitchBitSize = idii.BitSize;
      bic.SwitchLastPress = false;
     }
     else
     {
      bic.Rapid = r;
     }

     bic.Type = ((idii.Type == IDIT_BUTTON_CAN_RAPID) ? IDIT_BUTTON : idii.Type);
     bic.Flags = idii.Flags;

     bic.CPName = trio_aprintf(_("%s%s%s"), (r ? _("Rapid ") : ""), idii.Name, (bic.Type == IDIT_SWITCH) ? _(" Select") : "");

     bic.BCPrettyPrio = idii.ConfigOrder;
     PIDC[port].BIC.push_back(bic);
    }
   }
   else if(idii.Type == IDIT_STATUS)
   {
    StatusInfoCache sic;

    sic.IDII = &idii;
    sic.StatusLastState = 0;

    sic.StatusNumStates = idii.StatusNumStates;
    sic.StatusBitSize = idii.BitSize;
    sic.BitOffset = idii.BitOffset;

    PIDC[port].SIC.push_back(sic);
   }
   else if(idii.Type == IDIT_RUMBLE)
   {
    RumbleInfoCache ric;
    ric.IDII = &idii;
    ric.BitOffset = idii.BitOffset;
    ric.AssocBICIndex = PIDC[port].BIC.size() - 1;
    PIDC[port].RIC.push_back(ric);   
   }
  }

  for(unsigned int x = 0; x < PIDC[port].BIC.size(); x++)
  {
   int this_prio = PIDC[port].BIC[x].BCPrettyPrio;

   if(this_prio >= 0)
   {
    bool FooFound = FALSE;

    // First, see if any duplicate priorities come after this one! or something
    for(unsigned int i = x + 1; i < PIDC[port].BIC.size(); i++)
    {
     if(PIDC[port].BIC[i].BCPrettyPrio == this_prio)
     {
      FooFound = TRUE;
      break;
     }
    }

    // Now adjust all priorities >= this_prio except for 'x' by +1
    if(FooFound)
    {
     for(unsigned int i = 0; i < PIDC[port].BIC.size(); i++)
     {
      if(i != x && PIDC[port].BIC[i].BCPrettyPrio >= this_prio)
       PIDC[port].BIC[i].BCPrettyPrio++;
     }
    }
    
   } 
  }

  //
  // Now, search for exclusion buttons and rotated inputs.
  //
  for(auto& bic : PIDC[port].BIC)
  {
   if(bic.IDII->ExcludeName)
   {
    for(auto const& sub_bic : PIDC[port].BIC)
    {
     if(!strcasecmp(bic.IDII->ExcludeName, sub_bic.IDII->SettingName))
     {
      bic.ExclusionBitOffset = sub_bic.BitOffsets[0];
      break;
     }
    }
   }

   if(bic.IDII->RotateName[0])
   {
    for(auto const& sub_bic : PIDC[port].BIC)
    {
     for(int rodir = 0; rodir < 3; rodir++)
     {
      if(!strcasecmp(bic.IDII->RotateName[rodir], sub_bic.IDII->SettingName))
      {
       bic.BitOffsets[1 + rodir] = sub_bic.BitOffsets[0];
       // No break for you!
      }
     }
    }
   }
  }

 PIDC[port].Data = MDFNI_SetInput(port, device);
}

static void IncSelectedDevice(unsigned int port)
{
 if(MDFNDnetplay)
 {
  MDFN_DispMessage(_("Cannot change input device during netplay."));
 }
 else if(RewindState)
 {
  MDFN_DispMessage(_("Cannot change input device while state rewinding is active."));
 }
 else if(CurGame->PortInfo[port].DeviceInfo.size() > 1)
 {
  char tmp_setting_name[512];

  if(CurGame->DesiredInput.size() > port)
   CurGame->DesiredInput[port] = NULL;

  trio_snprintf(tmp_setting_name, 512, "%s.input.%s", CurGame->shortname, CurGame->PortInfo[port].ShortName);

  PIDC[port].CurrentDeviceIndex = (PIDC[port].CurrentDeviceIndex + 1) % CurGame->PortInfo[port].DeviceInfo.size();

  const char *devname = CurGame->PortInfo[port].DeviceInfo[PIDC[port].CurrentDeviceIndex].ShortName;

  KillPortInfo(port);
  MDFNI_SetSetting(tmp_setting_name, devname);
  BuildPortInfo(CurGame, port);

  MDFN_DispMessage(_("%s selected on port %d"), CurGame->PortInfo[port].DeviceInfo[PIDC[port].CurrentDeviceIndex].FullName, port + 1);
 }
}

#define MK(x)		{ BUTTC_KEYBOARD, 0, MKK(x) }

#define MK_CK(x)        { { BUTTC_KEYBOARD, 0, MKK(x) }, { 0, 0, 0 } }
#define MK_CK2(x,y)        { { BUTTC_KEYBOARD, 0, MKK(x) }, { BUTTC_KEYBOARD, 0, MKK(y) } }

#define MK_CK_SHIFT(x)	{ { BUTTC_KEYBOARD, 0, MKK(x) | (2<<24) }, { 0, 0, 0 } }
#define MK_CK_ALT(x)	{ { BUTTC_KEYBOARD, 0, MKK(x) | (1<<24) }, { 0, 0, 0 } }
#define MK_CK_ALT_SHIFT(x)    { { BUTTC_KEYBOARD, 0, MKK(x) | (3<<24) }, { 0, 0, 0 } }
#define MK_CK_CTRL(x)	{ { BUTTC_KEYBOARD, 0, MKK(x) | (4 << 24) },  { 0, 0, 0 } }
#define MK_CK_CTRL_SHIFT(x) { { BUTTC_KEYBOARD, 0, MKK(x) | (6 << 24) },  { 0, 0, 0 } }

#define MKZ()   {0, 0, 0}

enum CommandKey
{
	_CK_FIRST = 0,
        CK_SAVE_STATE = 0,
	CK_LOAD_STATE,
	CK_SAVE_MOVIE,
	CK_LOAD_MOVIE,
	CK_STATE_REWIND_TOGGLE,
	CK_0,CK_1,CK_2,CK_3,CK_4,CK_5,CK_6,CK_7,CK_8,CK_9,
	CK_M0,CK_M1,CK_M2,CK_M3,CK_M4,CK_M5,CK_M6,CK_M7,CK_M8,CK_M9,
	CK_TL1, CK_TL2, CK_TL3, CK_TL4, CK_TL5, CK_TL6, CK_TL7, CK_TL8, CK_TL9,
	CK_TAKE_SNAPSHOT,
	CK_TAKE_SCALED_SNAPSHOT,
	CK_TOGGLE_FS,
	CK_FAST_FORWARD,
	CK_SLOW_FORWARD,

	CK_INSERT_COIN,
	CK_TOGGLE_DIPVIEW,
	CK_SELECT_DISK,
	CK_INSERTEJECT_DISK,
	CK_ACTIVATE_BARCODE,

        CK_TOGGLE_GRAB_INPUT,
	CK_TOGGLE_CDISABLE,
	CK_INPUT_CONFIG1,
	CK_INPUT_CONFIG2,
        CK_INPUT_CONFIG3,
        CK_INPUT_CONFIG4,
	CK_INPUT_CONFIG5,
        CK_INPUT_CONFIG6,
        CK_INPUT_CONFIG7,
        CK_INPUT_CONFIG8,
        CK_INPUT_CONFIGC,
	CK_INPUT_CONFIGC_AM,
	CK_INPUT_CONFIG_ABD,

	CK_RESET,
	CK_POWER,
	CK_EXIT,
	CK_STATE_REWIND,
	CK_ROTATESCREEN,
	CK_TOGGLENETVIEW,
	CK_ADVANCE_FRAME,
	CK_RUN_NORMAL,
	CK_TOGGLECHEATVIEW,
	CK_TOGGLE_CHEAT_ACTIVE,
	CK_TOGGLE_FPS_VIEW,
	CK_TOGGLE_DEBUGGER,
	CK_STATE_SLOT_DEC,
        CK_STATE_SLOT_INC,
	CK_TOGGLE_HELP,
	CK_DEVICE_SELECT1,
        CK_DEVICE_SELECT2,
        CK_DEVICE_SELECT3,
        CK_DEVICE_SELECT4,
        CK_DEVICE_SELECT5,
        CK_DEVICE_SELECT6,
        CK_DEVICE_SELECT7,
        CK_DEVICE_SELECT8,

	_CK_COUNT
};

struct COKE
{
 ButtConfig bc[2];
 const char *text;
 bool BypassKeyZeroing;
 bool SkipCKDelay;
 const char *description;
};

static const COKE CKeys[_CK_COUNT]	=
{
	{ MK_CK(F5), 	   "save_state", false, 1, gettext_noop("Save state") },
	{ MK_CK(F7),	   "load_state", false, 0, gettext_noop("Load state") },
	{ MK_CK_SHIFT(F5), "save_movie", false, 1, gettext_noop("Save movie") },
	{ MK_CK_SHIFT(F7), "load_movie", false, 0, gettext_noop("Load movie") },
	{ MK_CK_ALT(s),     "toggle_state_rewind", false, 1, gettext_noop("Toggle state rewind functionality") },

	{ MK_CK(0), "0", false, 1, gettext_noop("Save state 0 select")},
        { MK_CK(1), "1", false, 1, gettext_noop("Save state 1 select")},
        { MK_CK(2), "2", false, 1, gettext_noop("Save state 2 select")},
        { MK_CK(3), "3", false, 1, gettext_noop("Save state 3 select")},
        { MK_CK(4), "4", false, 1, gettext_noop("Save state 4 select")},
        { MK_CK(5), "5", false, 1, gettext_noop("Save state 5 select")},
        { MK_CK(6), "6", false, 1, gettext_noop("Save state 6 select")},
        { MK_CK(7), "7", false, 1, gettext_noop("Save state 7 select")},
        { MK_CK(8), "8", false, 1, gettext_noop("Save state 8 select")},
        { MK_CK(9), "9", false, 1, gettext_noop("Save state 9 select")},

	{ MK_CK_SHIFT(0), "m0", false, 1, gettext_noop("Movie 0 select") },
        { MK_CK_SHIFT(1), "m1", false, 1, gettext_noop("Movie 1 select")  },
        { MK_CK_SHIFT(2), "m2", false, 1, gettext_noop("Movie 2 select")  },
        { MK_CK_SHIFT(3), "m3", false, 1, gettext_noop("Movie 3 select")  },
        { MK_CK_SHIFT(4), "m4", false, 1, gettext_noop("Movie 4 select")  },
        { MK_CK_SHIFT(5), "m5", false, 1, gettext_noop("Movie 5 select")  },
        { MK_CK_SHIFT(6), "m6", false, 1, gettext_noop("Movie 6 select")  },
        { MK_CK_SHIFT(7), "m7", false, 1, gettext_noop("Movie 7 select")  },
        { MK_CK_SHIFT(8), "m8", false, 1, gettext_noop("Movie 8 select")  },
        { MK_CK_SHIFT(9), "m9", false, 1, gettext_noop("Movie 9 select")  },

        { MK_CK_CTRL(1), "tl1", false, 1, gettext_noop("Toggle graphics layer 1")  },
        { MK_CK_CTRL(2), "tl2", false, 1, gettext_noop("Toggle graphics layer 2") },
        { MK_CK_CTRL(3), "tl3", false, 1, gettext_noop("Toggle graphics layer 3") },
        { MK_CK_CTRL(4), "tl4", false, 1, gettext_noop("Toggle graphics layer 4") },
        { MK_CK_CTRL(5), "tl5", false, 1, gettext_noop("Toggle graphics layer 5") },
        { MK_CK_CTRL(6), "tl6", false, 1, gettext_noop("Toggle graphics layer 6") },
        { MK_CK_CTRL(7), "tl7", false, 1, gettext_noop("Toggle graphics layer 7") },
        { MK_CK_CTRL(8), "tl8", false, 1, gettext_noop("Toggle graphics layer 8") },
        { MK_CK_CTRL(9), "tl9", false, 1, gettext_noop("Toggle graphics layer 9") },

	{ MK_CK(F9), "take_snapshot", false, 1, gettext_noop("Take screen snapshot") },
	{ MK_CK_SHIFT(F9), "take_scaled_snapshot", false, 1, gettext_noop("Take scaled(and filtered) screen snapshot") },

	{ MK_CK_ALT(RETURN), "toggle_fs", false, 1, gettext_noop("Toggle fullscreen mode") },
	{ MK_CK(BACKQUOTE), "fast_forward", false, 1, gettext_noop("Fast-forward") },
        { MK_CK(BACKSLASH), "slow_forward", false, 1, gettext_noop("Slow-forward") },

	{ MK_CK(F8), "insert_coin", false, 1, gettext_noop("Insert coin") },
	{ MK_CK(F6), "toggle_dipview", false, 1, gettext_noop("Toggle DIP switch view") },
	{ MK_CK(F6), "select_disk", false, 1, gettext_noop("Select disk/disc") },
	{ MK_CK(F8), "insert_eject_disk", false, 0, gettext_noop("Insert/Eject disk/disc") },
	{ MK_CK(F8), "activate_barcode", false, 1, gettext_noop("Activate barcode(for Famicom)") },
	{ MK_CK(SCROLLOCK), "toggle_grab_input", false, 1, gettext_noop("Grab input") },
	{ MK_CK_SHIFT(SCROLLOCK), "toggle_cidisable", false, 1, gettext_noop("Grab input and disable commands") },
	{ MK_CK_ALT_SHIFT(1), "input_config1", false, 0, gettext_noop("Configure buttons on virtual port 1") },
	{ MK_CK_ALT_SHIFT(2), "input_config2", false, 0, gettext_noop("Configure buttons on virtual port 2")  },
        { MK_CK_ALT_SHIFT(3), "input_config3", false, 0, gettext_noop("Configure buttons on virtual port 3")  },
        { MK_CK_ALT_SHIFT(4), "input_config4", false, 0, gettext_noop("Configure buttons on virtual port 4")  },
	{ MK_CK_ALT_SHIFT(5), "input_config5", false, 0, gettext_noop("Configure buttons on virtual port 5")  },
        { MK_CK_ALT_SHIFT(6), "input_config6", false, 0, gettext_noop("Configure buttons on virtual port 6")  },
        { MK_CK_ALT_SHIFT(7), "input_config7", false, 0, gettext_noop("Configure buttons on virtual port 7")  },
        { MK_CK_ALT_SHIFT(8), "input_config8", false, 0, gettext_noop("Configure buttons on virtual port 8")  },
        { MK_CK(F2), "input_configc", false, 0, gettext_noop("Configure command key") },
        { MK_CK_SHIFT(F2), "input_configc_am", false, 0, gettext_noop("Configure command key, for all-pressed-to-trigger mode") },

	{ MK_CK(F3), "input_config_abd", false, 0, gettext_noop("Detect analog buttons on physical joysticks/gamepads(for use with the input configuration process).") },

	{ MK_CK(F10), "reset", false, 0, gettext_noop("Reset") },
	{ MK_CK(F11), "power", false, 0, gettext_noop("Power toggle") },
	{ MK_CK2(F12, ESCAPE), "exit", true, 0, gettext_noop("Exit") },
	{ MK_CK(BACKSPACE), "state_rewind", false, 1, gettext_noop("Rewind") },
	{ MK_CK_ALT(o), "rotate_screen", false, 1, gettext_noop("Rotate screen") },

	{ MK_CK(t), "togglenetview", false, 1, gettext_noop("Toggle netplay console")},
	{ MK_CK_ALT(a), "advance_frame", false, 1, gettext_noop("Advance frame") },
	{ MK_CK_ALT(r), "run_normal", false, 1, gettext_noop("Return to normal mode after advancing frames") },
	{ MK_CK_ALT(c), "togglecheatview", true, 1, gettext_noop("Toggle cheat console") },
	{ MK_CK_ALT(t), "togglecheatactive", false, 1, gettext_noop("Enable/Disable cheats") },
        { MK_CK_SHIFT(F1), "toggle_fps_view", false, 1, gettext_noop("Toggle frames-per-second display") },
	{ MK_CK_ALT(d), "toggle_debugger", true, 1, gettext_noop("Toggle debugger") },
	{ MK_CK(MINUS), "state_slot_dec", false, 1, gettext_noop("Decrease selected save state slot by 1") },
	{ MK_CK(EQUALS), "state_slot_inc", false, 1, gettext_noop("Increase selected save state slot by 1") },
	{ MK_CK(F1), "toggle_help", true, 1, gettext_noop("Toggle help screen") },
	{ MK_CK_CTRL_SHIFT(1), "device_select1", false, 1, gettext_noop("Select virtual device on virtual input port 1") },
        { MK_CK_CTRL_SHIFT(2), "device_select2", false, 1, gettext_noop("Select virtual device on virtual input port 2") },
        { MK_CK_CTRL_SHIFT(3), "device_select3", false, 1, gettext_noop("Select virtual device on virtual input port 3") },
        { MK_CK_CTRL_SHIFT(4), "device_select4", false, 1, gettext_noop("Select virtual device on virtual input port 4") },
        { MK_CK_CTRL_SHIFT(5), "device_select5", false, 1, gettext_noop("Select virtual device on virtual input port 5") },
        { MK_CK_CTRL_SHIFT(6), "device_select6", false, 1, gettext_noop("Select virtual device on virtual input port 6") },
        { MK_CK_CTRL_SHIFT(7), "device_select7", false, 1, gettext_noop("Select virtual device on virtual input port 7") },
        { MK_CK_CTRL_SHIFT(8), "device_select8", false, 1, gettext_noop("Select virtual device on virtual input port 8") },
};

static const char *CKeysSettingName[_CK_COUNT];

struct CKeyConfig
{
 bool AND_Mode;
 std::vector<ButtConfig> bc;
};

static CKeyConfig CKeysConfig[_CK_COUNT];
static uint32 CKeysPressTime[_CK_COUNT];
static bool CKeysActive[_CK_COUNT];
static bool CKeysTrigger[_CK_COUNT];
static uint32 CurTicks = 0;	// Optimization, SDL_GetTicks() might be slow on some platforms?

static void CK_Init(void)
{
 ckdelay = MDFN_GetSettingUI("ckdelay");

 for(CommandKey i = _CK_FIRST; i < _CK_COUNT; i = (CommandKey)((unsigned)i + 1))
 {
  CKeysPressTime[i] = 0xFFFFFFFF;
  CKeysActive[i] = true;	// To prevent triggering when a button/key is held from before startup.
  CKeysTrigger[i] = false;
 }
}

static void CK_PostRemapUpdate(CommandKey which)
{
 CKeysActive[which] = DTestButtonCombo(CKeysConfig[which].bc, (CKeys[which].BypassKeyZeroing ? keys_untouched : keys), MouseData, CKeysConfig[which].AND_Mode);
 CKeysTrigger[which] = false;
 CKeysPressTime[which] = 0xFFFFFFFF;
}

static void CK_UpdateState(bool skipckd_tc)
{
 for(CommandKey i = _CK_FIRST; i < _CK_COUNT; i = (CommandKey)((unsigned)i + 1))
 {
  const bool prev_state = CKeysActive[i];
  const bool cur_state = DTestButtonCombo(CKeysConfig[i].bc, (CKeys[i].BypassKeyZeroing ? keys_untouched : keys), MouseData, CKeysConfig[i].AND_Mode);
  unsigned tmp_ckdelay = ckdelay;

  if(CKeys[i].SkipCKDelay || skipckd_tc)
   tmp_ckdelay = 0;

  if(cur_state)
  {
   if(!prev_state)
    CKeysPressTime[i] = CurTicks;
  }
  else
   CKeysPressTime[i] = 0xFFFFFFFF;

  CKeysTrigger[i] = false;

  if(CurTicks >= ((uint64)CKeysPressTime[i] + tmp_ckdelay))
  {
   CKeysTrigger[i] = true;
   CKeysPressTime[i] = 0xFFFFFFFF;
  }

  CKeysActive[i] = cur_state;
 }
}

static INLINE bool CK_Check(CommandKey which)
{
 return CKeysTrigger[which];
}

static INLINE bool CK_CheckActive(CommandKey which)
{
 return CKeysActive[which];
}

int NoWaiting = 0;

static bool ViewDIPSwitches = false;
static int cidisabled=0;

static bool inff = 0;
static bool insf = 0;

typedef enum
{
	none,
	Port1,
	Port2,
	Port3,
	Port4,
	Port5,
	Port6,
	Port7,
	Port8,
	Command,
	CommandAM
} ICType;

static ICType IConfig = none;
static int ICLatch;
static uint32 ICDeadDelay = 0;

static struct __MouseState
{
 int x, y;
 int xrel_accum;
 int yrel_accum;

 uint32 button;
 uint32 button_realstate;
 uint32 button_prevsent;
} MouseState = { 0, 0, 0, 0, 0, 0, 0 };

//#include "InputConfigurator.inc"
//static InputConfigurator *IConfigurator = NULL;
static int (*EventHook)(const SDL_Event *event) = NULL;
void MainSetEventHook(int (*eh)(const SDL_Event *event))
{
 EventHook = eh;
}

void Input_Event(const SDL_Event *event)
{
 switch(event->type)
 {
  case SDL_MOUSEBUTTONDOWN:
	if(event->button.state == SDL_PRESSED)
	{
	 MouseState.button |= 1 << (event->button.button - 1);
	 MouseState.button_realstate |= 1 << (event->button.button - 1);
	}
	break;

  case SDL_MOUSEBUTTONUP:
	if(event->button.state == SDL_RELEASED)
	{
	 MouseState.button_realstate &= ~(1 << (event->button.button - 1));
	}
        break;

  case SDL_MOUSEMOTION:
	MouseState.x = event->motion.x;
	MouseState.y = event->motion.y;
	MouseState.xrel_accum += event->motion.xrel;
	MouseState.yrel_accum += event->motion.yrel;
	break;
 }

 if(EventHook)
  EventHook(event);
}

/*
 The mouse button handling convolutedness is to make sure that extremely quick mouse button press and release
 still register as pressed for 1 emulated frame, and without otherwise increasing the lag of a mouse button release(which
 is what the button_prevsent is for).
*/
static void UpdatePhysicalDeviceState(void)
{
 const bool clearify_mdr = true;
 int mouse_x = MouseState.x, mouse_y = MouseState.y;

 //printf("%08x -- %08x %08x\n", MouseState.button & (MouseState.button_realstate | ~MouseState.button_prevsent), MouseState.button, MouseState.button_realstate);

 Video_PtoV(mouse_x, mouse_y, (int32*)&MouseData[0], (int32*)&MouseData[1]);
 MouseData[2] = MouseState.button & (MouseState.button_realstate | ~MouseState.button_prevsent);

 if(clearify_mdr)
 {
  MouseState.button_prevsent = MouseData[2];
  MouseState.button &= MouseState.button_realstate;
  MouseDataRel[0] -= (int32)MouseDataRel[0]; //floor(MouseDataRel[0]);
  MouseDataRel[1] -= (int32)MouseDataRel[1]; //floor(MouseDataRel[1]);
 }

 MouseDataRel[0] += CurGame->mouse_sensitivity * MouseState.xrel_accum;
 MouseDataRel[1] += CurGame->mouse_sensitivity * MouseState.yrel_accum;

 //
 //
 //
 MouseState.xrel_accum = 0;
 MouseState.yrel_accum = 0;
 //
 //
 //


 memcpy(keys_untouched, SDL_GetKeyState(0), MKK_COUNT);
 memcpy(keys, keys_untouched, MKK_COUNT);

 if(MDFNDHaveFocus || MDFN_GetSettingB("input.joystick.global_focus"))
  joy_manager->UpdateJoysticks();

 CurTicks = SDL_GetTicks();
}

static void RedoFFSF(void)
{
 if(inff)
  RefreshThrottleFPS(MDFN_GetSettingF("ffspeed"));
 else if(insf)
  RefreshThrottleFPS(MDFN_GetSettingF("sfspeed"));
 else
  RefreshThrottleFPS(1);
}


static void ToggleLayer(int which)
{
 static uint64 le_mask = ~0ULL; // FIXME/TODO: Init to ~0ULL on game load.

 if(CurGame && CurGame->LayerNames)
 {
  const char *goodies = CurGame->LayerNames;
  int x = 0;

  while(x != which)
  {
   while(*goodies)
    goodies++;
   goodies++;
   if(!*goodies) return; // ack, this layer doesn't exist.
   x++;
  }

  le_mask ^= (1ULL << which);
  MDFNI_SetLayerEnableMask(le_mask);

  if(le_mask & (1ULL << which))
   MDFN_DispMessage(_("%s enabled."), _(goodies));
  else
   MDFN_DispMessage(_("%s disabled."), _(goodies));
 }
}


// TODO: Remove this in the future when digit-string input devices are better abstracted.
static uint8 BarcodeWorldData[1 + 13];

static void DoKeyStateZeroing(void)
{
  if(IConfig == none && !(cidisabled & 0x1))
  {
   if(Netplay_IsTextInput() || CheatIF_Active())
   {
    memset(keys, 0, sizeof(keys)); // This effectively disables keyboard input, but still
                                   // allows physical joystick input when in the chat mode.
   }

   if(Debugger_IsActive())
   {
    memset(keys, 0, sizeof(keys));

    keys[SDLK_F1] = keys_untouched[SDLK_F1];
    keys[SDLK_F2] = keys_untouched[SDLK_F2];
    keys[SDLK_F3] = keys_untouched[SDLK_F3];
    keys[SDLK_F4] = keys_untouched[SDLK_F4];
    keys[SDLK_F5] = keys_untouched[SDLK_F5];
    keys[SDLK_F6] = keys_untouched[SDLK_F6];
    keys[SDLK_F7] = keys_untouched[SDLK_F7];
    keys[SDLK_F8] = keys_untouched[SDLK_F8];
    keys[SDLK_F9] = keys_untouched[SDLK_F9];
    keys[SDLK_F10] = keys_untouched[SDLK_F10];
    keys[SDLK_F11] = keys_untouched[SDLK_F11];
    keys[SDLK_F12] = keys_untouched[SDLK_F12];
    keys[SDLK_F13] = keys_untouched[SDLK_F13];
    keys[SDLK_F14] = keys_untouched[SDLK_F14];
    keys[SDLK_F15] = keys_untouched[SDLK_F15];
   }
 }
}

static void CheckCommandKeys(void)
{
  CK_UpdateState((IConfig == Command || IConfig == CommandAM) && ICLatch == -1);

  for(unsigned i = 0; i < 8; i++)
  {
   if(IConfig == Port1 + i)
   {
    if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
    {
     CK_PostRemapUpdate((CommandKey)(CK_INPUT_CONFIG1 + i));	// Kind of abusing that function if going by its name, but meh.

     ResyncGameInputSettings(i);
     IConfig = none;

     MDFNI_DispMessage(_("Configuration interrupted."));
    }
    else if(ConfigDevice(i))
    {
     ResyncGameInputSettings(i);
     ICDeadDelay = CurTicks + 300;
     IConfig = none;
    }
    break;
   }
  }

  if(IConfig == Command || IConfig == CommandAM)
  {
   if(ICLatch != -1)
   {
    if(subcon(CKeys[ICLatch].text, CKeysConfig[ICLatch].bc, 1))
    {
     MDFNI_DispMessage(_("Configuration finished."));

     MDFNI_SetSetting(CKeysSettingName[ICLatch], BCsToString(CKeysConfig[ICLatch].bc, CKeysConfig[ICLatch].AND_Mode));
     ICDeadDelay = CurTicks + 300;
     IConfig = none;

     // Prevent accidentally triggering the command
     CK_PostRemapUpdate((CommandKey)ICLatch);
    }
   }
   else
   {
    MDFNI_DispMessage(_("Press command key to remap now%s..."), (IConfig == CommandAM) ? _("(AND Mode)") : "");

    for(CommandKey x = _CK_FIRST; x < _CK_COUNT; x = (CommandKey)((unsigned)x + 1))
    {
     if(CK_Check((CommandKey)x))
     {
      ICLatch = x;
      CKeysConfig[ICLatch].AND_Mode = (IConfig == CommandAM);
      subcon_begin(CKeysConfig[ICLatch].bc);
      break;
     }
    }
   }
  }

  {
   bool cid_changed = false;

   if(CK_Check(CK_TOGGLE_GRAB_INPUT))
   {
    cidisabled = (cidisabled == 0x2) ? 0 : 0x2;
    cid_changed = true;
   }

   if(CK_Check(CK_TOGGLE_CDISABLE))
   {
    cidisabled = (cidisabled == 0x3) ? 0 : 0x3;
    cid_changed = true;
   }

   if(cid_changed)
   {
    SDL_Event evt;
    evt.user.type = SDL_USEREVENT;
    evt.user.code = CEVT_SET_GRAB_INPUT;
    evt.user.data1 = malloc(1);

    *(uint8 *)evt.user.data1 = cidisabled & 0x2;
    SDL_PushEvent(&evt);

    MDFNI_DispMessage(_("Input grabbing: %s, Command key processing: %s"), (cidisabled & 0x02) ? _("On") : _("Off"), !(cidisabled & 0x01) ? _("On") : _("Off"));
   }
  }

  if(cidisabled & 0x1)
   return;

  if(IConfig != none)
   return;

  if(!CheatIF_Active() && !MDFNDnetplay)
  {
   if(CK_Check(CK_TOGGLE_DEBUGGER))
   {
    Debugger_GT_Toggle();
   }
  }

  if(!Debugger_IsActive() && !MDFNDnetplay)
  {
   if(CK_Check(CK_TOGGLECHEATVIEW))
   {
    CheatIF_GT_Show(!CheatIF_Active());
   }
  }

  if(CK_Check(CK_EXIT))
  {
   SendCEvent(CEVT_WANT_EXIT, NULL, NULL);
  }

  if(CK_Check(CK_TOGGLE_HELP))
   Help_Toggle();

  if(!CheatIF_Active() && !Debugger_IsActive())
  {
   if(CK_Check(CK_TOGGLENETVIEW))
   {
    Netplay_ToggleTextView();
   }
  }

  if(CK_Check(CK_TOGGLE_CHEAT_ACTIVE))
  {
   bool isactive = MDFN_GetSettingB("cheats");
   
   isactive = !isactive;
   
   MDFNI_SetSettingB("cheats", isactive);

   if(isactive)
    MDFNI_DispMessage(_("Application of cheats enabled."));
   else
    MDFNI_DispMessage(_("Application of cheats disabled."));
  }

  if(CK_Check(CK_TOGGLE_FPS_VIEW))
   FPS_ToggleView();

  if(CK_Check(CK_TOGGLE_FS)) 
  {
   GT_ToggleFS();
  }

  if(!CurGame)
	return;
  
  if(!MDFNDnetplay)
  {
   bool ck_af = CK_Check(CK_ADVANCE_FRAME);
   bool ck_rn = CK_Check(CK_RUN_NORMAL);
   bool iifa = IsInFrameAdvance();

   //
   // Change the order of processing based on being in frame advance mode to allow for the derivation of single-key (un)pause functionality.
   //

   if(ck_af & iifa)
    DoFrameAdvance();

   if(ck_rn)
    DoRunNormal();

   if(ck_af & !iifa)
    DoFrameAdvance();
  }

  if(!Debugger_IsActive()) // We don't want to start button configuration when the debugger is active!
  {
   for(int i = 0; i < 8; i++)
   {
    if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
    {
     if(!PIDC[i].BIC.size())
     {
      MDFN_DispMessage(_("No buttons to configure for input port %u!"), i + 1);
     }
     else
     {
      //SetJoyReadMode(0);
      ConfigDeviceBegin();
      IConfig = (ICType)(Port1 + i);
     }
    }
   }

   if(CK_Check(CK_INPUT_CONFIGC))
   {
    //SetJoyReadMode(0);
    ConfigDeviceBegin();
    ICLatch = -1;
    IConfig = Command;
   }

   if(CK_Check(CK_INPUT_CONFIGC_AM))
   {
    //SetJoyReadMode(0);
    ConfigDeviceBegin();
    ICLatch = -1;
    IConfig = CommandAM;
   }

   if(CK_Check(CK_INPUT_CONFIG_ABD))
   {
    MDFN_DispMessage("%u joystick/gamepad analog button(s) detected.", joy_manager->DetectAnalogButtonsForChangeCheck());
   }
  }

  if(CK_Check(CK_ROTATESCREEN))
  {
   if(CurGame->rotated == MDFN_ROTATE0)
    CurGame->rotated = MDFN_ROTATE90;
   else if(CurGame->rotated == MDFN_ROTATE90)
    CurGame->rotated = MDFN_ROTATE270;
   else if(CurGame->rotated == MDFN_ROTATE270)
    CurGame->rotated = MDFN_ROTATE0;

   GT_ReinitVideo();
  }

  if(CK_CheckActive(CK_STATE_REWIND))
	DNeedRewind = true;
  else
	DNeedRewind = false;

  if(CK_Check(CK_STATE_REWIND_TOGGLE))
  {
   RewindState = !RewindState;
   MDFNI_EnableStateRewind(RewindState);

   MDFNI_DispMessage(RewindState ? _("State rewinding functionality enabled.") : _("State rewinding functionality disabled."));
  }

  {
   bool previous_ff = inff;
   bool previous_sf = insf;

   if(fftoggle_setting)
    inff ^= CK_Check(CK_FAST_FORWARD);
   else
    inff = CK_CheckActive(CK_FAST_FORWARD);

   if(sftoggle_setting)
    insf ^= CK_Check(CK_SLOW_FORWARD);
   else
    insf = CK_CheckActive(CK_SLOW_FORWARD);

   if(previous_ff != inff || previous_sf != insf)
    RedoFFSF();
  }

  if(CurGame->RMD->Drives.size())
  {
   if(CK_Check(CK_SELECT_DISK)) 
   {
    RMDUI_Select();
   }
   if(CK_Check(CK_INSERTEJECT_DISK)) 
   {
    RMDUI_Toggle_InsertEject();
   }
  }

  if(CurGame->GameType != GMT_PLAYER)
  {
   for(int i = 0; i < 8; i++)
   {
    if(CK_Check((CommandKey)(CK_DEVICE_SELECT1 + i)))
     IncSelectedDevice(i);
   }
  }

  if(CK_Check(CK_TAKE_SNAPSHOT)) 
	pending_snapshot = 1;

  if(CK_Check(CK_TAKE_SCALED_SNAPSHOT))
	pending_ssnapshot = 1;

  if(CK_Check(CK_SAVE_STATE))
	pending_save_state = 1;

  if(CK_Check(CK_SAVE_MOVIE))
	pending_save_movie = 1;

  if(CK_Check(CK_LOAD_STATE))
  {
	MDFNI_LoadState(NULL, NULL);
	Debugger_GT_SyncDisToPC();
  }

  if(CK_Check(CK_LOAD_MOVIE))
  {
	MDFNI_LoadMovie(NULL);
	Debugger_GT_SyncDisToPC();
  }

  if(CK_Check(CK_TL1))
    ToggleLayer(0);
  if(CK_Check(CK_TL2))
    ToggleLayer(1);
  if(CK_Check(CK_TL3))
    ToggleLayer(2);
  if(CK_Check(CK_TL4))
    ToggleLayer(3);
  if(CK_Check(CK_TL5))
    ToggleLayer(4);
  if(CK_Check(CK_TL6))
    ToggleLayer(5);
  if(CK_Check(CK_TL7))
    ToggleLayer(6);
  if(CK_Check(CK_TL8))
    ToggleLayer(7);
  if(CK_Check(CK_TL9))
    ToggleLayer(8);

  if(CK_Check(CK_STATE_SLOT_INC))
  {
   MDFNI_SelectState(666 + 1);
  }

  if(CK_Check(CK_STATE_SLOT_DEC))
  {
   MDFNI_SelectState(666 - 1);
  }

  if(CK_Check(CK_RESET))
  {
	MDFNI_Reset();
	Debugger_GT_ForceStepIfStepping();
  }

  if(CK_Check(CK_POWER))
  {
	MDFNI_Power();
	Debugger_GT_ForceStepIfStepping();
  }

  if(CurGame->GameType == GMT_ARCADE)
  {
	if(CK_Check(CK_INSERT_COIN))
		MDFNI_InsertCoin();

	if(CK_Check(CK_TOGGLE_DIPVIEW))
        {
	 ViewDIPSwitches = !ViewDIPSwitches;
	 MDFNI_ToggleDIPView();
	}

	if(!ViewDIPSwitches)
	 goto DIPSless;

	if(CK_Check(CK_1)) MDFNI_ToggleDIP(0);
	if(CK_Check(CK_2)) MDFNI_ToggleDIP(1);
	if(CK_Check(CK_3)) MDFNI_ToggleDIP(2);
	if(CK_Check(CK_4)) MDFNI_ToggleDIP(3);
	if(CK_Check(CK_5)) MDFNI_ToggleDIP(4);
	if(CK_Check(CK_6)) MDFNI_ToggleDIP(5);
	if(CK_Check(CK_7)) MDFNI_ToggleDIP(6);
	if(CK_Check(CK_8)) MDFNI_ToggleDIP(7);
  }
  else
  {
   #ifdef WANT_NES_EMU
   static uint8 bbuf[32];
   static int bbuft;
   static int barcoder = 0;

   if(!strcmp(CurGame->shortname, "nes") && (!strcmp(PIDC[4].Device->ShortName, "bworld") || (CurGame->cspecial && !strcasecmp(CurGame->cspecial, "datach"))))
   {
    if(CK_Check(CK_ACTIVATE_BARCODE))
    {
     barcoder ^= 1;
     if(!barcoder)
     {
      if(!strcmp(PIDC[4].Device->ShortName, "bworld"))
      {
       BarcodeWorldData[0] = 1;
       memset(BarcodeWorldData + 1, 0, 13);

       strncpy((char *)BarcodeWorldData + 1, (char *)bbuf, 13);
      }
      else
       MDFNI_DatachSet(bbuf);
      MDFNI_DispMessage(_("Barcode Entered"));
     } 
     else { bbuft = 0; MDFNI_DispMessage(_("Enter Barcode"));}
    }
   } 
   else 
    barcoder = 0;

   #define SSM(x) { if(bbuft < 13) {bbuf[bbuft++] = '0' + x; bbuf[bbuft] = 0;} MDFNI_DispMessage(_("Barcode: %s"),bbuf); }

   DIPSless:

   if(barcoder)
   {
    for(unsigned i = 0; i < 10; i++)
     if(CK_Check((CommandKey)(CK_0 + i)))
      SSM(i);
   }
   else
   #else
   DIPSless: ;
   #endif
   {
    for(unsigned i = 0; i < 10; i++)
    {
     if(CK_Check((CommandKey)(CK_0 + i)))
      MDFNI_SelectState(i);

     if(CK_Check((CommandKey)(CK_M0 + i)))
      MDFNI_SelectMovie(i);
    }
   }
   #undef SSM
 }
}

void MDFND_UpdateInput(bool VirtualDevicesOnly, bool UpdateRapidFire)
{
 static unsigned int rapid=0;

 UpdatePhysicalDeviceState();

 DoKeyStateZeroing();	// Call before CheckCommandKeys()

 //
 // CheckCommandKeys(), specifically MDFNI_LoadState(), should be called *before* we update the emulated device input data, as that data is 
 // stored/restored from save states(related: ALT+A frame advance, switch state).
 //
 if(!VirtualDevicesOnly)
  CheckCommandKeys();

 if(UpdateRapidFire)
  rapid = (rapid + 1) % (autofirefreq + 1);

 bool RotateInput = false;
 bool RotateInputSettingFetched = false;

 // Do stuff here
 for(unsigned int x = 0; x < CurGame->PortInfo.size(); x++)
 {
  if(!PIDC[x].Data)
   continue;

  //
  // Handle rumble(FIXME: Do we want rumble to work in frame advance mode too?)
  //
  for(auto const& ric : PIDC[x].RIC)
  {
   const uint16 rumble_data = MDFN_de16lsb(PIDC[x].Data + ric.BitOffset / 8);
   const uint8 weak = (rumble_data >> 0) & 0xFF;
   const uint8 strong = (rumble_data >> 8) & 0xFF;

   joy_manager->SetRumble(PIDC[x].BIC[ric.AssocBICIndex].BC, weak, strong);
   //printf("Rumble: %04x --- Weak: %02x, Strong: %02x\n", rumble_data, weak, strong);
  }

  if(IConfig != none)
   continue;

  if(ICDeadDelay > CurTicks)
   continue;
  else
   ICDeadDelay = 0;

  //
  // Handle configurable inputs/buttons.
  //
  for(auto& bic : PIDC[x].BIC)
  {
   if(!RotateInputSettingFetched)
   {
    if(bic.BitOffsets[CurGame->rotated] != bic.BitOffsets[0])
    {
     char tmp_setting_name[512];

     trio_snprintf(tmp_setting_name, 512, "%s.rotateinput", CurGame->shortname);
     RotateInput = MDFN_GetSettingB(tmp_setting_name);
     RotateInputSettingFetched = true;
    }
   }
   //
   //
   //
   uint8* tptr = PIDC[x].Data;
   const uint32 bo = bic.BitOffsets[RotateInput ? CurGame->rotated : 0];
   uint8* const btptr = &tptr[bo >> 3];


   //
   // Mice axes aren't buttons!  Oh well...
   //
   if(bic.Type == IDIT_X_AXIS || bic.Type == IDIT_Y_AXIS)
   {
    float tv = 0;

    if(bic.BC.size() > 0)
     tv = DTestMouseAxis(bic.BC[0], keys, MouseData, (bic.Type == IDIT_Y_AXIS));

    if(bic.Type == IDIT_Y_AXIS)
     tv = floor(0.5 + (tv * (1.0 / 65536) * CurGame->mouse_scale_y) + CurGame->mouse_offs_y);
    else
     tv = floor(0.5 + (tv * (1.0 / 65536) * CurGame->mouse_scale_x) + CurGame->mouse_offs_x);

    MDFN_en16lsb(btptr, (int16)std::max<float>(-32768, std::min<float>(tv, 32767)));
   }
   else if(bic.Type == IDIT_BUTTON_ANALOG)	// Analog button
   {
    uint32 intv;

    intv = DTestButton(bic.BC, keys, MouseData, true);
 
    if(bic.Flags & IDIT_BUTTON_ANALOG_FLAG_SQLR)
     intv = std::min<unsigned>((unsigned)floor(0.5 + intv * PIDC[x].AxisScale), 32767);

    MDFN_en16lsb(btptr, intv);
   }
   else if(bic.Type == IDIT_SWITCH)
   {
    const bool nps = DTestButton(bic.BC, keys, MouseData);
    uint8 cv = BitsExtract(tptr, bo, bic.SwitchBitSize);

    if(MDFN_UNLIKELY(!bic.SwitchLastPress && nps))
    {
     cv = (cv + 1) % bic.SwitchNumPos;
     BitsIntract(tptr, bo, bic.SwitchBitSize, cv);
    }

    if(MDFN_UNLIKELY(cv >= bic.SwitchNumPos))	// Can also be triggered intentionally by a bad save state/netplay.
     fprintf(stderr, "[BUG] cv(%u) >= bic.SwitchNumPos(%u)\n", cv, bic.SwitchNumPos);
    else if(MDFN_UNLIKELY(cv != bic.SwitchLastPos))
    {
     MDFN_DispMessage(_("%s %u: %s: %s selected."), PIDC[x].Device->FullName, x + 1, bic.IDII->Name, bic.IDII->SwitchPosName[cv]);
     bic.SwitchLastPos = cv;
    }

    bic.SwitchLastPress = nps;
   }
   else
   {
    if(!bic.Rapid)
     *btptr &= ~(1 << (bo & 7));

    if(DTestButton(bic.BC, keys, MouseData)) // boolean button
    {
     if(!bic.Rapid || rapid >= (autofirefreq + 1) / 2)
      *btptr |= 1 << (bo & 7);
    }
   }
  }

  //
  // Handle button exclusion!
  //
  for(auto& bic : PIDC[x].BIC)
  {
   if(bic.ExclusionBitOffset != 0xFFFF)
   {
    const uint32 bo[2] = { bic.BitOffsets[0], bic.ExclusionBitOffset };
    const uint32 bob[2] = { bo[0] >> 3, bo[1] >> 3 };
    const uint32 bom[2] = { 1U << (bo[0] & 0x7), 1U << (bo[1] & 0x7) };
    uint8 *tptr = PIDC[x].Data;

    if((tptr[bob[0]] & bom[0]) && (tptr[bob[1]] & bom[1]))
    {
     tptr[bob[0]] &= ~bom[0];
     tptr[bob[1]] &= ~bom[1];
    }
   }
  }

  //
  // Handle status indicators.
  //
  for(auto& sic : PIDC[x].SIC)
  {
   const uint32 bo = sic.BitOffset;
   const uint8* tptr = PIDC[x].Data;
   uint32 cv = 0;

   for(unsigned b = 0; b < sic.StatusBitSize; b++)
    cv |= ((tptr[(bo + b) >> 3] >> ((bo + b) & 7)) & 1) << b;

   if(MDFN_UNLIKELY(cv >= sic.StatusNumStates))
    fprintf(stderr, "[BUG] cv(%u) >= sic.StatusNumStates(%u)\n", cv,sic.StatusNumStates);
   else if(MDFN_UNLIKELY(cv != sic.StatusLastState))
   {
    MDFN_DispMessage(_("%s %u: %s: %s"), PIDC[x].Device->FullName, x + 1, sic.IDII->Name, sic.IDII->StatusStates[cv].Name);
    sic.StatusLastState = cv;
   }
  }

  //
  // Now, axis and misc data...
  //
  for(size_t tmi = 0; tmi < PIDC[x].Device->IDII.size(); tmi++)
  {
   switch(PIDC[x].Device->IDII[tmi].Type)
   {
    default: break;

    case IDIT_BYTE_SPECIAL:
			assert(tmi < 13 + 1);
			PIDC[x].Data[tmi] = BarcodeWorldData[tmi];
			break;

    case IDIT_X_AXIS_REL:
    case IDIT_Y_AXIS_REL:
                      MDFN_en32lsb((PIDC[x].Data + PIDC[x].Device->IDII[tmi].BitOffset / 8), (uint32)((PIDC[x].Device->IDII[tmi].Type == IDIT_Y_AXIS_REL) ? MouseDataRel[1] : MouseDataRel[0]));
		      break;
   }
  }
 }

 memset(BarcodeWorldData, 0, sizeof(BarcodeWorldData));
}

void InitGameInput(MDFNGI *gi)
{
 autofirefreq = MDFN_GetSettingUI("autofirefreq");
 fftoggle_setting = MDFN_GetSettingB("fftoggle");
 sftoggle_setting = MDFN_GetSettingB("sftoggle");

 CK_Init();

 //SetJoyReadMode(1); // Disable joystick event handling, and allow manual state updates.

 for(size_t p = 0; p < gi->PortInfo.size(); p++)
  BuildPortInfo(gi, p);
}

// Update setting strings with butt configs.
static void ResyncGameInputSettings(unsigned port)
{
 for(unsigned int x = 0; x < PIDC[port].BIC.size(); x++)
  MDFNI_SetSetting(PIDC[port].BIC[x].SettingName, BCsToString(PIDC[port].BIC[x].BC));
}


static ButtConfig subcon_bc;
static int subcon_tb;
static int subcon_wc;

static void subcon_begin(std::vector<ButtConfig> &bc)
{
 bc.clear();

 memset(&subcon_bc, 0, sizeof(subcon_bc));
 subcon_tb = -1;
 subcon_wc = 0;
}

/* Configures an individual virtual button. */
static int subcon(const char *text, std::vector<ButtConfig> &bc, int commandkey)
{
 while(1)
 {
  MDFNI_DispMessage("%s (%d)", text, subcon_wc + 1);

  if(subcon_tb != subcon_wc)
  {
   joy_manager->Reset_BC_ChangeCheck();
   DTryButtonBegin(&subcon_bc, commandkey);
   subcon_tb = subcon_wc;
  }

  if(DTryButton())
  {
   DTryButtonEnd(&subcon_bc);
  }
  else if(joy_manager->Do_BC_ChangeCheck(&subcon_bc))
  {

  }
  else
   return(0);

  if(subcon_wc && !memcmp(&subcon_bc, &bc[subcon_wc - 1], sizeof(ButtConfig)))
   break;

  bc.push_back(subcon_bc);
  subcon_wc++;
 }

 //puts("DONE");
 return(1);
}

static int cd_x;
static int cd_lx = -1;
static void ConfigDeviceBegin(void)
{
 cd_x = 0;
 cd_lx = -1;
}

int ConfigDevice(int arg)
{
 char buf[512];

 //for(int i = 0; i < PIDC[arg].Buttons.size(); i++)
 // printf("%d\n", PIDC[arg].BCPrettyPrio[i]);
 //exit(1);

 for(;cd_x < (int)PIDC[arg].BIC.size(); cd_x++)
 {
  int snooty = -1;

  for(unsigned int i = 0; i < PIDC[arg].BIC.size(); i++)
   if(PIDC[arg].BIC[i].BCPrettyPrio == cd_x)
    snooty = i;

  if(snooty < 0)
   continue;

  // For Lynx, GB, GBA, NGP, WonderSwan(especially wonderswan!)
  if(CurGame->PortInfo.size() == 1 && CurGame->PortInfo[0].DeviceInfo.size() == 1)
   trio_snprintf(buf, 512, "%s", PIDC[arg].BIC[snooty].CPName);
  else
   trio_snprintf(buf, 512, "%s %d: %s", PIDC[arg].Device->FullName, arg + 1, PIDC[arg].BIC[snooty].CPName);

  if(cd_x != cd_lx)
  {
   cd_lx = cd_x;
   subcon_begin(PIDC[arg].BIC[snooty].BC);
  }
  if(!subcon(buf, PIDC[arg].BIC[snooty].BC, 0))
   return(0);
 }

 MDFNI_DispMessage(_("Configuration finished."));

 return(1);
}

#include "input-default-buttons.h"
struct cstrcomp
{
 bool operator()(const char * const &a, const char * const &b) const
 {
  return(strcmp(a, b) < 0);
 }
};

static std::map<const char *, const DefaultSettingsMeow *, cstrcomp> DefaultButtonSettingsMap;
static std::vector<void *> PendingGarbage;

static void MakeSettingsForDevice(std::vector <MDFNSetting> &settings, const MDFNGI *system, const int w, const InputDeviceInfoStruct *info)
{
 const ButtConfig *def_bc = NULL;
 char setting_def_search[512];

 trio_snprintf(setting_def_search, 512, "%s.input.%s.%s", system->shortname, system->PortInfo[w].ShortName, info->ShortName);
 CleanSettingName(setting_def_search);

 {
  std::map<const char *, const DefaultSettingsMeow *, cstrcomp>::iterator fit = DefaultButtonSettingsMap.find(setting_def_search);
  if(fit != DefaultButtonSettingsMap.end())
   def_bc = fit->second->bc;
 }

 //for(unsigned int d = 0; d < sizeof(defset) / sizeof(DefaultSettingsMeow); d++)
 //{
 // if(!strcasecmp(setting_def_search, defset[d].base_name))
 // {
 //  def_bc = defset[d].bc;
 //  break;
 // }
 //}

 int butti = 0;
 bool analog_scale_made = false;
 for(size_t x = 0; x < info->IDII.size(); x++)
 {
  if(info->IDII[x].Type != IDIT_BUTTON && info->IDII[x].Type != IDIT_BUTTON_CAN_RAPID && info->IDII[x].Type != IDIT_BUTTON_ANALOG &&
	info->IDII[x].Type != IDIT_X_AXIS && info->IDII[x].Type != IDIT_Y_AXIS &&
	info->IDII[x].Type != IDIT_SWITCH)
   continue;

  if(NULL == info->IDII[x].SettingName)
   continue;

  MDFNSetting tmp_setting;

  const char *default_value = "";

  if(def_bc)
   PendingGarbage.push_back((void *)(default_value = strdup(BCToString(def_bc[butti]).c_str()) ));

  memset(&tmp_setting, 0, sizeof(tmp_setting));

  PendingGarbage.push_back((void *)(tmp_setting.name = CleanSettingName(trio_aprintf("%s.input.%s.%s.%s", system->shortname, system->PortInfo[w].ShortName, info->ShortName, info->IDII[x].SettingName)) ));
  PendingGarbage.push_back((void *)(tmp_setting.description = trio_aprintf("%s, %s, %s: %s", system->shortname, system->PortInfo[w].FullName, info->FullName, info->IDII[x].Name) ));
  tmp_setting.type = MDFNST_STRING;
  tmp_setting.default_value = default_value;
  
  tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
  tmp_setting.description_extra = NULL;

  //printf("Maketset: %s %s\n", tmp_setting.name, tmp_setting.default_value);

  settings.push_back(tmp_setting);

  // Now make a rapid butt-on-stick-on-watermelon
  if(info->IDII[x].Type == IDIT_BUTTON_CAN_RAPID)
  {
   memset(&tmp_setting, 0, sizeof(tmp_setting));

   PendingGarbage.push_back((void *)( tmp_setting.name = CleanSettingName(trio_aprintf("%s.input.%s.%s.rapid_%s", system->shortname, system->PortInfo[w].ShortName, info->ShortName, info->IDII[x].SettingName)) ));
   PendingGarbage.push_back((void *)( tmp_setting.description = trio_aprintf("%s, %s, %s: Rapid %s", system->shortname, system->PortInfo[w].FullName, info->FullName, info->IDII[x].Name) ));
   tmp_setting.type = MDFNST_STRING;

   tmp_setting.default_value = "";

   tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
   tmp_setting.description_extra = NULL;

   settings.push_back(tmp_setting);
  }
  else if(info->IDII[x].Type == IDIT_BUTTON_ANALOG)
  {
   if((info->IDII[x].Flags & IDIT_BUTTON_ANALOG_FLAG_SQLR) && !analog_scale_made)
   {
    memset(&tmp_setting, 0, sizeof(tmp_setting));

    PendingGarbage.push_back((void *)( tmp_setting.name = CleanSettingName(trio_aprintf("%s.input.%s.%s.axis_scale", system->shortname, system->PortInfo[w].ShortName, info->ShortName)) ));
    PendingGarbage.push_back((void *)( tmp_setting.description = trio_aprintf("Analog axis scale coefficient for %s on %s.", info->FullName, system->PortInfo[w].FullName) ));
    tmp_setting.description_extra = NULL;

    tmp_setting.type = MDFNST_FLOAT;
    tmp_setting.default_value = "1.00";
    tmp_setting.minimum = "1.00";
    tmp_setting.maximum = "1.50";

    settings.push_back(tmp_setting);
    analog_scale_made = true;
   }
  }
  butti++;
 }
}


static void MakeSettingsForPort(std::vector <MDFNSetting> &settings, const MDFNGI *system, const int w, const InputPortInfoStruct *info)
{
#if 1
 if(info->DeviceInfo.size() > 1)
 {
  MDFNSetting tmp_setting;
  MDFNSetting_EnumList *EnumList;

  memset(&tmp_setting, 0, sizeof(MDFNSetting));

  EnumList = (MDFNSetting_EnumList *)calloc(sizeof(MDFNSetting_EnumList), info->DeviceInfo.size() + 1);

  for(unsigned device = 0; device < info->DeviceInfo.size(); device++)
  {
   const InputDeviceInfoStruct *dinfo = &info->DeviceInfo[device];

   EnumList[device].string = strdup(dinfo->ShortName);
   EnumList[device].number = device;
   EnumList[device].description = strdup(info->DeviceInfo[device].FullName);
   EnumList[device].description_extra = info->DeviceInfo[device].Description ? strdup(info->DeviceInfo[device].Description) : NULL;

   PendingGarbage.push_back((void *)EnumList[device].string);
   PendingGarbage.push_back((void *)EnumList[device].description);
  }

  PendingGarbage.push_back(EnumList);

  tmp_setting.name = trio_aprintf("%s.input.%s", system->shortname, info->ShortName);
  PendingGarbage.push_back((void *)tmp_setting.name);

  tmp_setting.description = trio_aprintf("Input device for %s", info->FullName);
  PendingGarbage.push_back((void *)tmp_setting.description);

  tmp_setting.type = MDFNST_ENUM;
  tmp_setting.default_value = info->DefaultDevice;

  assert(info->DefaultDevice);

  tmp_setting.flags = MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE;
  tmp_setting.description_extra = NULL;
  tmp_setting.enum_list = EnumList;

  settings.push_back(tmp_setting);
 }
#endif

 for(unsigned device = 0; device < info->DeviceInfo.size(); device++)
 {
  MakeSettingsForDevice(settings, system, w, &info->DeviceInfo[device]);
 }
}

// Called on emulator startup
void MakeInputSettings(std::vector <MDFNSetting> &settings)
{
 // Construct default button group map
 for(unsigned int d = 0; d < sizeof(defset) / sizeof(DefaultSettingsMeow); d++)
  DefaultButtonSettingsMap[defset[d].base_name] = &defset[d];

 // First, build system settings
 for(unsigned int x = 0; x < MDFNSystems.size(); x++)
 {
  assert(MDFNSystems[x]->PortInfo.size() <= 16);

  for(unsigned port = 0; port < MDFNSystems[x]->PortInfo.size(); port++)
   MakeSettingsForPort(settings, MDFNSystems[x], port, &MDFNSystems[x]->PortInfo[port]);
 }
 DefaultButtonSettingsMap.clear();

 // Now build command key settings
 for(int x = 0; x < _CK_COUNT; x++)
 {
  MDFNSetting tmp_setting;

  memset(&tmp_setting, 0, sizeof(MDFNSetting));

  CKeysSettingName[x] = trio_aprintf("command.%s", CKeys[x].text);
  tmp_setting.name = CKeysSettingName[x];
  PendingGarbage.push_back((void *)( CKeysSettingName[x] ));

  tmp_setting.description = CKeys[x].description;
  tmp_setting.type = MDFNST_STRING;

  tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
  tmp_setting.description_extra = NULL;

  PendingGarbage.push_back((void *)( tmp_setting.default_value = strdup(BCsToString(CKeys[x].bc, 2).c_str()) ));
  settings.push_back(tmp_setting);
 }
}

void KillGameInput(void)
{
 for(size_t p = 0; p < CurGame->PortInfo.size(); p++)
  KillPortInfo(p);
}

bool InitCommandInput(MDFNGI* gi)
{
 // Load the command key mappings from settings
 for(int x = 0; x < _CK_COUNT; x++)
 {
  CKeysConfig[x].AND_Mode = StringToBC(MDFN_GetSettingS(CKeysSettingName[x]).c_str(), CKeysConfig[x].bc);
 }
 return(1);
}

void KillCommandInput(void)
{

}

void KillInputSettings(void)
{
 for(unsigned int x = 0; x < PendingGarbage.size(); x++)
  free(PendingGarbage[x]);

 PendingGarbage.clear();
}

