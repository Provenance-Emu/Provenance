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
#include "fps.h"
#include "help.h"

#include <math.h>


extern JoystickManager *joy_manager;

static bool RewindState = false;
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

bool DNeedRewind = FALSE;

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
  trio_snprintf(tmp, 256, "joystick %016llx %08x", bc.DeviceID, bc.ButtonNum);

  string = string + std::string(tmp);
 }
 else if(bc.ButtType == BUTTC_MOUSE)
 {
  trio_snprintf(tmp, 256, "mouse %d", bc.ButtonNum);

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


// We have a hardcoded limit of 16 ports here for simplicity.
static unsigned int NumPorts;

//static std::vector<const InputDeviceInfoStruct*> PortPossibleDevices[MDFN_EMULATED_SYSTEM_COUNT][16];
//typedef std::vector<const InputDeviceInfoStruct*>[16]
// An unpacked list of possible devices for each port.

typedef std::vector<const InputDeviceInfoStruct*> SnugglyWuggly;
static std::map<const char *, SnugglyWuggly *> PortPossibleDevices;

static unsigned int PortCurrentDeviceIndex[16]; // index into PortPossibleDevices
static void *PortData[16];
static uint32 PortDataSize[16]; // In bytes, not bits!

static const InputDeviceInfoStruct *PortDevice[16];
static std::vector<char *>PortButtons[16];

static std::vector<std::vector<ButtConfig> > PortButtConfig[16];
static std::vector<int> PortButtConfigOffsets[16];
static std::vector<int> PortButtConfigPrettyPrio[16];

static std::vector<uint32> PortBitOffsets[16]; // within PortData, mask with 0x80000000 for rapid buttons
static std::vector<uint32> PortButtBitOffsets[16];
static std::vector<bool> PortButtIsAnalog[16];

typedef struct
{
 uint32 rotate[3];
} RotateOffsets_t;

static std::vector<RotateOffsets_t> PortButtRotateOffsets[16];


static std::vector<uint32> PortButtExclusionBitOffsets[16]; // 0xFFFFFFFF represents none
static std::vector<char *> PortButtSettingNames[16];

static void KillPortInfo(unsigned int port)
{
 if(PortData[port])
  free(PortData[port]);
 PortData[port] = NULL;
 PortDataSize[port] = 0;
 PortDevice[port] = NULL;

 for(unsigned int x = 0; x < PortButtons[port].size(); x++)
  free(PortButtons[port][x]);

 PortButtons[port].clear();
 PortButtConfig[port].clear();
 PortButtConfigOffsets[port].clear();
 PortButtConfigPrettyPrio[port].clear();

 PortBitOffsets[port].clear();
 PortButtBitOffsets[port].clear();
 PortButtRotateOffsets[port].clear();
 PortButtExclusionBitOffsets[port].clear();
 PortButtIsAnalog[port].clear();

 for(unsigned int x = 0; x < PortButtSettingNames[port].size(); x++)
  free(PortButtSettingNames[port][x]);

 PortButtSettingNames[port].clear();
}

static void KillPortsInfo(void) // Murder it!!
{
 for(unsigned int port = 0; port < NumPorts; port++)
  KillPortInfo(port);

 NumPorts = 0;
}


static void BuildPortInfo(MDFNGI *gi, const unsigned int port)
{
 const RotateOffsets_t NullRotate = { { ~0U, ~0U, ~0U } };
 const InputDeviceInfoStruct *zedevice = NULL;
 char *port_device_name;
 unsigned int device;
 

  if(PortPossibleDevices[gi->shortname][port].size() > 1)
  {  
   if(CurGame->DesiredInput.size() > port && CurGame->DesiredInput[port])
   {
    port_device_name = strdup(CurGame->DesiredInput[port]);
   }
   else
   {
    char tmp_setting_name[512];
    trio_snprintf(tmp_setting_name, 512, "%s.input.%s", gi->shortname, gi->InputInfo->Types[port].ShortName);
    port_device_name = strdup(MDFN_GetSettingS(tmp_setting_name).c_str());
   }
  }
  else
  {
   port_device_name = strdup(PortPossibleDevices[gi->shortname][port][0]->ShortName);
  }

  for(device = 0; device < PortPossibleDevices[gi->shortname][port].size(); device++)
  {
   //printf("Port: %d, Dev: %d, Meow: %s\n", port, device, PortPossibleDevices[gi->shortname][port][device]->ShortName);
   if(!strcasecmp(PortPossibleDevices[gi->shortname][port][device]->ShortName, port_device_name))
   {
    zedevice = PortPossibleDevices[gi->shortname][port][device];
    break;
   }
  }
  free(port_device_name); port_device_name = NULL;

  PortCurrentDeviceIndex[port] = device;

  assert(zedevice);

  PortDevice[port] = zedevice;

  // Figure out how much data should be allocated for each port
  int bit_offset = 0;
  int buttconfig_offset = 0;

  if(!zedevice->PortExpanderDeviceInfo)
  for(int x = 0; x < zedevice->NumInputs; x++)
  {
   // Handle dummy/padding button entries(the setting name will be NULL in such cases)
   if(NULL == zedevice->IDII[x].SettingName)
   {
    //printf("%s Dummy: %s, %u\n", zedevice->FullName, zedevice->IDII[x].Name, zedevice->IDII[x].Type);
    switch(zedevice->IDII[x].Type)
    {
     default: bit_offset = ((bit_offset + 31) &~ 31) + 32;
	      break;

     case IDIT_BUTTON:
     case IDIT_BUTTON_CAN_RAPID: bit_offset += 1;
				 break;

     case IDIT_BYTE_SPECIAL: bit_offset += 8;
			       break;
    }
    continue;
   }   // End of handling dummy/padding entries
   

   if(zedevice->IDII[x].Type == IDIT_BUTTON || zedevice->IDII[x].Type == IDIT_BUTTON_CAN_RAPID
	 || zedevice->IDII[x].Type == IDIT_BUTTON_ANALOG)
   {
    if(zedevice->IDII[x].Type == IDIT_BUTTON_ANALOG)
     bit_offset = (bit_offset + 31) &~ 31; // Align to a 32-bit boundary

    std::vector<ButtConfig> buttc;
    char buttsn[512];

    trio_snprintf(buttsn, 512, "%s.input.%s.%s.%s", gi->shortname, gi->InputInfo->Types[port].ShortName, zedevice->ShortName, zedevice->IDII[x].SettingName);
    CleanSettingName(buttsn);

    //printf("Buttsn: %s, %s\n", buttsn, MDFN_GetSettingS(buttsn).c_str());
    PortButtSettingNames[port].push_back(strdup(buttsn));
    StringToBC(MDFN_GetSettingS(buttsn).c_str(), buttc);

    PortButtConfig[port].push_back(buttc);
    PortBitOffsets[port].push_back(bit_offset);
    PortButtBitOffsets[port].push_back(bit_offset);
    PortButtIsAnalog[port].push_back(zedevice->IDII[x].Type == IDIT_BUTTON_ANALOG);

    PortButtons[port].push_back(strdup(zedevice->IDII[x].Name));
    PortButtConfigOffsets[port].push_back(buttconfig_offset);

    PortButtConfigPrettyPrio[port].push_back(zedevice->IDII[x].ConfigOrder);
    buttconfig_offset++;

    if(zedevice->IDII[x].Type == IDIT_BUTTON_CAN_RAPID)
    {
     buttc.clear();

     trio_snprintf(buttsn, 512, "%s.input.%s.%s.rapid_%s", gi->shortname, gi->InputInfo->Types[port].ShortName, zedevice->ShortName, zedevice->IDII[x].SettingName);
     CleanSettingName(buttsn);
     PortButtSettingNames[port].push_back(strdup(buttsn));
     StringToBC(MDFN_GetSettingS(buttsn).c_str(), buttc);

     PortButtConfig[port].push_back(buttc);
     //WRONG: PortBitOffsets[port].push_back(bit_offset | 0x80000000);
     PortButtBitOffsets[port].push_back(bit_offset | 0x80000000);
     PortButtIsAnalog[port].push_back(false);

     PortButtons[port].push_back(trio_aprintf("Rapid %s", zedevice->IDII[x].Name));
     PortButtConfigOffsets[port].push_back(buttconfig_offset);

     PortButtConfigPrettyPrio[port].push_back(zedevice->IDII[x].ConfigOrder);
     buttconfig_offset++;
    }

    if(zedevice->IDII[x].Type == IDIT_BUTTON_ANALOG)
    {
     bit_offset += 32;
    }
    else
    {
     bit_offset += 1;
    }
   }
   else if(zedevice->IDII[x].Type == IDIT_BYTE_SPECIAL)
   {
    PortBitOffsets[port].push_back(bit_offset);
    bit_offset += 8;
   }
   else // axis and misc, uint32!
   {
    bit_offset = (bit_offset + 31) &~ 31; // Align it to a 32-bit boundary

    PortBitOffsets[port].push_back(bit_offset);
    bit_offset += 32;
   }
  }
  //printf("Love: %d %d %d %s\n", port, bit_offset, zedevice->NumInputs, zedevice->ShortName);

  for(unsigned int x = 0; x < PortButtConfigPrettyPrio[port].size(); x++)
  {
   int this_prio = PortButtConfigPrettyPrio[port][x];

   if(this_prio >= 0)
   {
    bool FooFound = FALSE;

    // First, see if any duplicate priorities come after this one! or something
    for(unsigned int i = x + 1; i < PortButtConfigPrettyPrio[port].size(); i++)
     if(PortButtConfigPrettyPrio[port][i] == this_prio)
     {
      FooFound = TRUE;
      break;
     }

    // Now adjust all priorities >= this_prio except for 'x' by +1
    if(FooFound)
    {
     for(unsigned int i = 0; i < PortButtConfigPrettyPrio[port].size(); i++)
      if(i != x && PortButtConfigPrettyPrio[port][i] >= this_prio)
       PortButtConfigPrettyPrio[port][i]++;
    }
    
   } 
  }

  PortDataSize[port] = (bit_offset + 7) / 8;

  if(!PortDataSize[port])
   PortData[port] = NULL;
  else
  {
   PortData[port] = malloc(PortDataSize[port]);
   memset(PortData[port], 0, PortDataSize[port]);
  }

  // Now, search for exclusion buttons and rotated inputs.
  if(!zedevice->PortExpanderDeviceInfo)
  {
   for(int x = 0; x < zedevice->NumInputs; x++)
   {
    if(NULL == zedevice->IDII[x].SettingName)
     continue;

    if(zedevice->IDII[x].Type == IDIT_BUTTON || zedevice->IDII[x].Type == IDIT_BUTTON_CAN_RAPID || zedevice->IDII[x].Type == IDIT_BUTTON_ANALOG)
    {
     if(zedevice->IDII[x].ExcludeName)
     {
      int bo = 0xFFFFFFFF;

      for(unsigned int sub_x = 0; sub_x < PortButtSettingNames[port].size(); sub_x++)
      {
       if(!strcasecmp(zedevice->IDII[x].ExcludeName, strrchr(PortButtSettingNames[port][sub_x], '.') + 1 ))
        bo = PortButtBitOffsets[port][sub_x];
      }
      //printf("%s %s %d\n", zedevice->IDII[x].SettingName, zedevice->IDII[x].ExcludeName, bo);
      PortButtExclusionBitOffsets[port].push_back(bo);
     }
     else
      PortButtExclusionBitOffsets[port].push_back(0xFFFFFFFF);

     if(zedevice->IDII[x].RotateName[0])
     {
      RotateOffsets_t RotoCat = NullRotate;

      for(int rodir = 0; rodir < 3; rodir++)
      {
       for(unsigned int sub_x = 0; sub_x < PortButtSettingNames[port].size(); sub_x++)
       {
        if(!strcasecmp(zedevice->IDII[x].RotateName[rodir], strrchr(PortButtSettingNames[port][sub_x], '.') + 1 ))
        {
         RotoCat.rotate[rodir] = PortButtBitOffsets[port][sub_x];
         break;
        }
       }
       //printf("%s %s %d\n", zedevice->IDII[x].SettingName, zedevice->IDII[x].ExcludeName, bo);
      }
      PortButtRotateOffsets[port].push_back(RotoCat);
     }
     else
      PortButtRotateOffsets[port].push_back(NullRotate);

     if(zedevice->IDII[x].Type == IDIT_BUTTON_CAN_RAPID) // FIXME in the future, but I doubt we'll ever have rapid-fire directional buttons!
     {
      PortButtExclusionBitOffsets[port].push_back(0xFFFFFFFF);
      PortButtRotateOffsets[port].push_back(NullRotate);
     }
    }
   }
  } // End search for exclusion buttons and rotated inputs.

  assert(PortButtExclusionBitOffsets[port].size() == PortButtBitOffsets[port].size());
  assert(PortButtRotateOffsets[port].size() == PortButtBitOffsets[port].size());
  assert(PortButtBitOffsets[port].size() == PortButtIsAnalog[port].size());

  MDFNI_SetInput(port, zedevice->ShortName, PortData[port], PortDataSize[port]);
}

static void BuildPortsInfo(MDFNGI *gi)
{
 NumPorts = 0;
 while(PortPossibleDevices[gi->shortname][NumPorts].size())
 {
  BuildPortInfo(gi, NumPorts);
  NumPorts++;
 }
}

static void IncSelectedDevice(unsigned int port)
{
 if(RewindState)
 {
  MDFN_DispMessage(_("Cannot change input device while state rewinding is active."));
 }
 else if(PortPossibleDevices[CurGame->shortname][port].size() > 1)
 {
  char tmp_setting_name[512];

  if(CurGame->DesiredInput.size() > port)
   CurGame->DesiredInput[port] = NULL;

  trio_snprintf(tmp_setting_name, 512, "%s.input.%s", CurGame->shortname, CurGame->InputInfo->Types[port].ShortName);

  PortCurrentDeviceIndex[port] = (PortCurrentDeviceIndex[port] + 1) % PortPossibleDevices[CurGame->shortname][port].size();

  const char *devname = PortPossibleDevices[CurGame->shortname][port][PortCurrentDeviceIndex[port]]->ShortName;

  KillPortInfo(port);
  MDFNI_SetSetting(tmp_setting_name, devname);
  BuildPortInfo(CurGame, port);

  MDFN_DispMessage(_("%s selected on port %d"), PortPossibleDevices[CurGame->shortname][port][PortCurrentDeviceIndex[port]]->FullName, port + 1);
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

typedef enum {
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
	CK_FAST_FORWARD,
	CK_SLOW_FORWARD,

	CK_INSERT_COIN,
	CK_TOGGLE_DIPVIEW,
	CK_SELECT_DISK,
	CK_INSERTEJECT_DISK,
	CK_ACTIVATE_BARCODE,

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
	CK_ADVANCE_FRAME,
	CK_RUN_NORMAL,
	CK_TOGGLE_FPS_VIEW,
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
} CommandKey;

typedef struct __COKE
{
 ButtConfig bc[2];
 const char *text;
 unsigned int system;
 bool SkipCKDelay;
 const char *description;
} COKE;

static const COKE CKeys[_CK_COUNT]	=
{
	{ MK_CK(F5), "save_state", ~0U, 1, gettext_noop("Save state") },
	{ MK_CK(F7), "load_state", ~0U, 0, gettext_noop("Load state") },
	{ MK_CK_SHIFT(F5), "save_movie", ~0U, 1, gettext_noop("Save movie") },
	{ MK_CK_SHIFT(F7), "load_movie", ~0U, 0, gettext_noop("Load movie") },
	{ MK_CK_ALT(s), "toggle_state_rewind", ~0U, 1, gettext_noop("Toggle state rewind functionality") },

	{ MK_CK(0), "0", ~0U, 1, gettext_noop("Save state 0 select")},
        { MK_CK(1), "1", ~0U, 1, gettext_noop("Save state 1 select")},
        { MK_CK(2), "2", ~0U, 1, gettext_noop("Save state 2 select")},
        { MK_CK(3), "3", ~0U, 1, gettext_noop("Save state 3 select")},
        { MK_CK(4), "4", ~0U, 1, gettext_noop("Save state 4 select")},
        { MK_CK(5), "5", ~0U, 1, gettext_noop("Save state 5 select")},
        { MK_CK(6), "6", ~0U, 1, gettext_noop("Save state 6 select")},
        { MK_CK(7), "7", ~0U, 1, gettext_noop("Save state 7 select")},
        { MK_CK(8), "8", ~0U, 1, gettext_noop("Save state 8 select")},
        { MK_CK(9), "9", ~0U, 1, gettext_noop("Save state 9 select")},

	{ MK_CK_SHIFT(0), "m0", ~0U, 1, gettext_noop("Movie 0 select") },
        { MK_CK_SHIFT(1), "m1", ~0U, 1, gettext_noop("Movie 1 select")  },
        { MK_CK_SHIFT(2), "m2", ~0U, 1, gettext_noop("Movie 2 select")  },
        { MK_CK_SHIFT(3), "m3", ~0U, 1, gettext_noop("Movie 3 select")  },
        { MK_CK_SHIFT(4), "m4", ~0U, 1, gettext_noop("Movie 4 select")  },
        { MK_CK_SHIFT(5), "m5", ~0U, 1, gettext_noop("Movie 5 select")  },
        { MK_CK_SHIFT(6), "m6", ~0U, 1, gettext_noop("Movie 6 select")  },
        { MK_CK_SHIFT(7), "m7", ~0U, 1, gettext_noop("Movie 7 select")  },
        { MK_CK_SHIFT(8), "m8", ~0U, 1, gettext_noop("Movie 8 select")  },
        { MK_CK_SHIFT(9), "m9", ~0U, 1, gettext_noop("Movie 9 select")  },

        { MK_CK_CTRL(1), "tl1", ~0U, 1, gettext_noop("Toggle graphics layer 1")  },
        { MK_CK_CTRL(2), "tl2", ~0U, 1, gettext_noop("Toggle graphics layer 2") },
        { MK_CK_CTRL(3), "tl3", ~0U, 1, gettext_noop("Toggle graphics layer 3") },
        { MK_CK_CTRL(4), "tl4", ~0U, 1, gettext_noop("Toggle graphics layer 4") },
        { MK_CK_CTRL(5), "tl5", ~0U, 1, gettext_noop("Toggle graphics layer 5") },
        { MK_CK_CTRL(6), "tl6", ~0U, 1, gettext_noop("Toggle graphics layer 6") },
        { MK_CK_CTRL(7), "tl7", ~0U, 1, gettext_noop("Toggle graphics layer 7") },
        { MK_CK_CTRL(8), "tl8", ~0U, 1, gettext_noop("Toggle graphics layer 8") },
        { MK_CK_CTRL(9), "tl9", ~0U, 1, gettext_noop("Toggle graphics layer 9") },

	{ MK_CK(F9), "take_snapshot", ~0U, 1, gettext_noop("Take screen snapshot") },

	{ MK_CK_ALT(RETURN), "toggle_fs", ~0U, 1, gettext_noop("Toggle fullscreen mode") },
	{ MK_CK(BACKQUOTE), "fast_forward", ~0U, 1, gettext_noop("Fast-forward") },
        { MK_CK(BACKSLASH), "slow_forward", ~0U, 1, gettext_noop("Slow-forward") },

	{ MK_CK(F8), "insert_coin", ~0U, 1, gettext_noop("Insert coin") },
	{ MK_CK(F6), "toggle_dipview", ~0U, 1, gettext_noop("Toggle DIP switch view") },
	{ MK_CK(F6), "select_disk", ~0U, 1, gettext_noop("Select disk/disc") },
	{ MK_CK(F8), "insert_eject_disk", ~0U, 0, gettext_noop("Insert/Eject disk/disc") },
	{ MK_CK(F8), "activate_barcode", ~0U, 1, gettext_noop("Activate barcode(for Famicom)") },
	{ MK_CK_SHIFT(SCROLLOCK), "toggle_cidisable", ~0U, 1, gettext_noop("Grab input and disable commands") },
	{ MK_CK_ALT_SHIFT(1), "input_config1", ~0U, 0, gettext_noop("Configure buttons on virtual port 1") },
	{ MK_CK_ALT_SHIFT(2), "input_config2", ~0U, 0, gettext_noop("Configure buttons on virtual port 2")  },
        { MK_CK_ALT_SHIFT(3), "input_config3", ~0U, 0, gettext_noop("Configure buttons on virtual port 3")  },
        { MK_CK_ALT_SHIFT(4), "input_config4", ~0U, 0, gettext_noop("Configure buttons on virtual port 4")  },
	{ MK_CK_ALT_SHIFT(5), "input_config5", ~0U, 0, gettext_noop("Configure buttons on virtual port 5")  },
        { MK_CK_ALT_SHIFT(6), "input_config6", ~0U, 0, gettext_noop("Configure buttons on virtual port 6")  },
        { MK_CK_ALT_SHIFT(7), "input_config7", ~0U, 0, gettext_noop("Configure buttons on virtual port 7")  },
        { MK_CK_ALT_SHIFT(8), "input_config8", ~0U, 0, gettext_noop("Configure buttons on virtual port 8")  },
        { MK_CK(F2), "input_configc", ~0U, 0, gettext_noop("Configure command key") },
        { MK_CK_SHIFT(F2), "input_configc_am", ~0U, 0, gettext_noop("Configure command key, for all-pressed-to-trigger mode") },

	{ MK_CK(F3), "input_config_abd", ~0U, 0, gettext_noop("Detect analog buttons on physical joysticks/gamepads(for use with the input configuration process).") },

	{ MK_CK(F10), "reset", ~0U, 0, gettext_noop("Reset") },
	{ MK_CK(F11), "power", ~0U, 0, gettext_noop("Power toggle") },
	{ MK_CK2(F12, ESCAPE), "exit", ~0U, 0, gettext_noop("Exit") },
	{ MK_CK(BACKSPACE), "state_rewind", ~0U, 1, gettext_noop("Rewind") },
	{ MK_CK_ALT(o), "rotate_screen", ~0U, 1, gettext_noop("Rotate screen") },

	{ MK_CK_ALT(a), "advance_frame", ~0U, 1, gettext_noop("Advance frame") },
	{ MK_CK_ALT(r), "run_normal", ~0U, 1, gettext_noop("Return to normal mode after advancing frames") },
        { MK_CK_SHIFT(F1), "toggle_fps_view", ~0U, 1, gettext_noop("Toggle frames-per-second display") },
	{ MK_CK(MINUS), "state_slot_dec", ~0U, 1, gettext_noop("Decrease selected save state slot by 1") },
	{ MK_CK(EQUALS), "state_slot_inc", ~0U, 1, gettext_noop("Increase selected save state slot by 1") },
	{ MK_CK(F1), "toggle_help", ~0U, 1, gettext_noop("Toggle help screen") },
	{ MK_CK_CTRL_SHIFT(1), "device_select1", ~0U, 1, gettext_noop("Select virtual device on virtual input port 1") },
        { MK_CK_CTRL_SHIFT(2), "device_select2", ~0U, 1, gettext_noop("Select virtual device on virtual input port 2") },
        { MK_CK_CTRL_SHIFT(3), "device_select3", ~0U, 1, gettext_noop("Select virtual device on virtual input port 3") },
        { MK_CK_CTRL_SHIFT(4), "device_select4", ~0U, 1, gettext_noop("Select virtual device on virtual input port 4") },
        { MK_CK_CTRL_SHIFT(5), "device_select5", ~0U, 1, gettext_noop("Select virtual device on virtual input port 5") },
        { MK_CK_CTRL_SHIFT(6), "device_select6", ~0U, 1, gettext_noop("Select virtual device on virtual input port 6") },
        { MK_CK_CTRL_SHIFT(7), "device_select7", ~0U, 1, gettext_noop("Select virtual device on virtual input port 7") },
        { MK_CK_CTRL_SHIFT(8), "device_select8", ~0U, 1, gettext_noop("Select virtual device on virtual input port 8") },
};

static const char *CKeysSettingName[_CK_COUNT];

struct CKeyConfig
{
 bool AND_Mode;
 std::vector<ButtConfig> bc;
};

static CKeyConfig CKeysConfig[_CK_COUNT];
static int CKeysLastState[_CK_COUNT];
static uint32 CKeysPressTime[_CK_COUNT];
static uint32 CurTicks = 0;	// Optimization.

static int CK_Check(CommandKey which)
{
 int last = CKeysLastState[which];
 int tmp_ckdelay = ckdelay;

 if(CKeys[which].SkipCKDelay)
  tmp_ckdelay = 0;

 if((CKeysLastState[which] = DTestButtonCombo(CKeysConfig[which].bc, keys, MouseData, CKeysConfig[which].AND_Mode)))
 {
  if(!last)
   CKeysPressTime[which] = CurTicks;
 }
 else
  CKeysPressTime[which] = 0xFFFFFFFF;

 if(CurTicks >= ((int64)CKeysPressTime[which] + tmp_ckdelay))
 {
  CKeysPressTime[which] = 0xFFFFFFFF;
  return(1);
 }
 return(0);
}

static int CK_CheckActive(CommandKey which)
{
 return(DTestButtonCombo(CKeysConfig[which].bc, keys, MouseData, CKeysConfig[which].AND_Mode));
}

static bool ViewDIPSwitches = false;

#define KEY(__a) keys[MKK(__a)]

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

#if 0
static struct __MouseState
{
 int x, y;
 int xrel_accum;
 int yrel_accum;

 uint32 button;
 uint32 button_realstate;
 uint32 button_prevsent;
} MouseState = { 0, 0, 0, 0, 0, 0, 0 };

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
#endif

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

 PtoV(mouse_x, mouse_y, (int32*)&MouseData[0], (int32*)&MouseData[1]);
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


 memcpy(keys, SDL_GetKeyState(0), MKK_COUNT);

 joy_manager->UpdateJoysticks();

 CurTicks = MDFND_GetTime();
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

static void CheckCommandKeys(void)
{
  if(IConfig == none && !(cidisabled & 0x1))
  {
   if(CK_Check(CK_TOGGLE_HELP))
    Help_Toggle();

   if(!(cidisabled & 1))
   {
    if(CK_Check(CK_EXIT))
    {
     SendCEvent(CEVT_WANT_EXIT, NULL, NULL);
    }
   }
  }

   for(int i = 0; i < 8; i++)
   {
    if(IConfig == Port1 + i)
    {
     if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
     {
      ResyncGameInputSettings(i);
      IConfig = none;
      //SetJoyReadMode(1);
      MDFNI_DispMessage(_("Configuration interrupted."));
     }
     else if(ConfigDevice(i))
     {
      ResyncGameInputSettings(i);
      ICDeadDelay = CurTicks + 300;
      IConfig = none;
      //SetJoyReadMode(1);
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

      MDFNI_SetSetting(CKeysSettingName[ICLatch], BCsToString(CKeysConfig[ICLatch].bc, CKeysConfig[ICLatch].AND_Mode).c_str());
      ICDeadDelay = CurTicks + 300;
      IConfig = none;
      //SetJoyReadMode(1);
      CKeysLastState[ICLatch] = 1;	// We don't want to accidentally trigger the command. :b
      return;
     }
    }
    else
    {
     int x;
     MDFNI_DispMessage(_("Press command key to remap now%s..."), (IConfig == CommandAM) ? _("(AND Mode)") : "");
     for(x = (int)_CK_FIRST; x < (int)_CK_COUNT; x++)
      if(CK_Check((CommandKey)x))
      {
       ICLatch = x;
       CKeysConfig[ICLatch].AND_Mode = (IConfig == CommandAM);
       subcon_begin(CKeysConfig[ICLatch].bc);
       break;
      }
    }
   }

  if(CK_Check(CK_TOGGLE_CDISABLE))
  {
   cidisabled = cidisabled ? 0 : 0x3;

   if(cidisabled)
    MDFNI_DispMessage(_("Command processing disabled."));
   else
    MDFNI_DispMessage(_("Command processing enabled."));
  }

  if(cidisabled & 0x1) return;

  if(IConfig != none)
   return;

  if(CK_Check(CK_TOGGLE_FPS_VIEW))
   FPS_ToggleView();

  if(!CurGame)
	return;
  
  if(CK_Check(CK_ADVANCE_FRAME))
   DoFrameAdvance();

  if(CK_Check(CK_RUN_NORMAL))
   DoRunNormal();

  {
   for(int i = 0; i < 8; i++)
   {
    if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
    {
     if(!PortButtConfig[i].size())
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
	DNeedRewind = TRUE;
  else
	DNeedRewind = FALSE;

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

  if(CurGame->GameType == GMT_DISK || CurGame->GameType == GMT_CDROM)
  {
   if(CK_Check(CK_SELECT_DISK)) 
   {
    MDFNI_DiskSelect();
   }
   if(CK_Check(CK_INSERTEJECT_DISK)) 
   {
    MDFNI_DiskInsert();
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

//  if(CurGame->GameType != GMT_PLAYER)
  {
   if(CK_Check(CK_SAVE_STATE))
	pending_save_state = 1;

   if(CK_Check(CK_SAVE_MOVIE))
	pending_save_movie = 1;

   if(CK_Check(CK_LOAD_STATE))
   {
	MDFNI_LoadState(NULL, NULL);
   }

   if(CK_Check(CK_LOAD_MOVIE))
   {
	MDFNI_LoadMovie(NULL);
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
  }

  if(CK_Check(CK_RESET))
  {
	MDFNI_Reset();
  }

  if(CK_Check(CK_POWER))
  {
	MDFNI_Power();
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

   if(!strcmp(CurGame->shortname, "nes") && (!strcmp(PortDevice[4]->ShortName, "bworld") || (CurGame->cspecial && !strcasecmp(CurGame->cspecial, "datach"))))
   {
    if(CK_Check(CK_ACTIVATE_BARCODE))
    {
     barcoder ^= 1;
     if(!barcoder)
     {
      if(!strcmp(PortDevice[4]->ShortName, "bworld"))
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
    if(CK_Check(CK_0)) SSM(0);
    if(CK_Check(CK_1)) SSM(1);
    if(CK_Check(CK_2)) SSM(2);
    if(CK_Check(CK_3)) SSM(3);
    if(CK_Check(CK_4)) SSM(4);
    if(CK_Check(CK_5)) SSM(5);
    if(CK_Check(CK_6)) SSM(6);
    if(CK_Check(CK_7)) SSM(7);
    if(CK_Check(CK_8)) SSM(8);
    if(CK_Check(CK_9)) SSM(9);
   }
   else
   #else
   DIPSless: ;
   #endif
   {
    //if(CurGame->GameType != GMT_PLAYER)
    {
     if(CK_Check(CK_0)) MDFNI_SelectState(0);
     if(CK_Check(CK_1)) MDFNI_SelectState(1);
     if(CK_Check(CK_2)) MDFNI_SelectState(2);
     if(CK_Check(CK_3)) MDFNI_SelectState(3);
     if(CK_Check(CK_4)) MDFNI_SelectState(4);
     if(CK_Check(CK_5)) MDFNI_SelectState(5);
     if(CK_Check(CK_6)) MDFNI_SelectState(6);
     if(CK_Check(CK_7)) MDFNI_SelectState(7);
     if(CK_Check(CK_8)) MDFNI_SelectState(8);
     if(CK_Check(CK_9)) MDFNI_SelectState(9);

     if(CK_Check(CK_M0)) MDFNI_SelectMovie(0);
     if(CK_Check(CK_M1)) MDFNI_SelectMovie(1);
     if(CK_Check(CK_M2)) MDFNI_SelectMovie(2);
     if(CK_Check(CK_M3)) MDFNI_SelectMovie(3);
     if(CK_Check(CK_M4)) MDFNI_SelectMovie(4);
     if(CK_Check(CK_M5)) MDFNI_SelectMovie(5);
     if(CK_Check(CK_M6)) MDFNI_SelectMovie(6);
     if(CK_Check(CK_M7)) MDFNI_SelectMovie(7);
     if(CK_Check(CK_M8)) MDFNI_SelectMovie(8);
     if(CK_Check(CK_M9)) MDFNI_SelectMovie(9);
    }
   }
   #undef SSM
 }
}

void MDFND_UpdateInput(bool VirtualDevicesOnly, bool UpdateRapidFire)
{
 static unsigned int rapid=0;

 UpdatePhysicalDeviceState();

 //
 // Check command keys/buttons.  CheckCommandKeys() may modify(such as memset to 0) the state of the "keys" array
 // under certain circumstances.
 //
 if(VirtualDevicesOnly)
  DoKeyStateZeroing();	// Normally called from CheckCommandKeys(), but since we're not calling CheckCommandKeys() here...
 else
  CheckCommandKeys();

 if(UpdateRapidFire)
  rapid = (rapid + 1) % (autofirefreq + 1);

 int RotateInput = -1;

 // Do stuff here
 for(unsigned int x = 0; x < NumPorts; x++)
 {
  if(!PortData[x])
   continue;

  // Handle rumbles before we wipe the port data(FIXME: Do we want rumble to work in frame advance mode too?)!
  for(int tmi = 0; tmi < PortDevice[x]->NumInputs; tmi++)
  {
   switch(PortDevice[x]->IDII[tmi].Type)
   {
    default:
	break;

    case IDIT_RUMBLE:
	{
	 uint32 rumble_data = MDFN_de32lsb(((uint8 *)PortData[x] + PortBitOffsets[x][tmi] / 8));
	 uint8 weak = (rumble_data >> 0) & 0xFF;
	 uint8 strong = (rumble_data >> 8) & 0xFF;

	 joy_manager->SetRumble(PortButtConfig[x][PortButtConfig[x].size() - 1], weak, strong);

	 //printf("Weak: %02x, Strong: %02x\n", weak, strong);
	}
	break;
   }
  }

  memset(PortData[x], 0, PortDataSize[x]);

  if(IConfig != none)
   continue;

  if(ICDeadDelay > CurTicks)
   continue;
  else
   ICDeadDelay = 0;

  // First, handle buttons
  for(unsigned int butt = 0; butt < PortButtConfig[x].size(); butt++)
  {
   if(CurGame->rotated && PortButtRotateOffsets[x][butt].rotate[CurGame->rotated - 1] != 0xFFFFFFFF)
   {
    if(RotateInput < 0)
    {
     char tmp_setting_name[512];

     trio_snprintf(tmp_setting_name, 512, "%s.rotateinput", CurGame->shortname);
     RotateInput = MDFN_GetSettingB(tmp_setting_name);
    }
   }

   //
   // Analog button
   //
   if(PortButtIsAnalog[x][butt])
   {
    uint8 *tptr = (uint8 *)PortData[x];
    uint32 bo = PortButtBitOffsets[x][butt];
    uint32 tv;

    if(CurGame->rotated && PortButtRotateOffsets[x][butt].rotate[CurGame->rotated - 1] != 0xFFFFFFFF)
    {
     if(RotateInput)
      bo = PortButtRotateOffsets[x][butt].rotate[CurGame->rotated - 1];
    }

    tv = std::min<int>(MDFN_de32lsb(&tptr[(bo & 0x7FFFFFFF) / 8]) + DTestButton(PortButtConfig[x][butt], keys, MouseData, true), 32767);

    MDFN_en32lsb(&tptr[(bo & 0x7FFFFFFF) / 8], tv);
   }
   else if(DTestButton(PortButtConfig[x][butt], keys, MouseData)) // boolean button
   {
    uint8 *tptr = (uint8 *)PortData[x];
    uint32 bo = PortButtBitOffsets[x][butt];

    if(CurGame->rotated && PortButtRotateOffsets[x][butt].rotate[CurGame->rotated - 1] != 0xFFFFFFFF)
    {
     if(RotateInput)
      bo = PortButtRotateOffsets[x][butt].rotate[CurGame->rotated - 1];
    }
    if(!(bo & 0x80000000) || rapid >= (autofirefreq + 1) / 2)
     tptr[(bo & 0x7FFFFFFF) / 8] |= 1 << (bo & 7);
   }
  }

  // Handle button exclusion!
  for(unsigned int butt = 0; butt < PortButtConfig[x].size(); butt++)
  {
   uint32 bo[2];
   uint8 *tptr = (uint8 *)PortData[x];

   bo[0] = PortButtBitOffsets[x][butt];
   bo[1] = PortButtExclusionBitOffsets[x][butt];

   if(bo[1] != 0xFFFFFFFF)
   {
    //printf("%08x %08x\n", bo[0], bo[1]);
    if( (tptr[(bo[0] & 0x7FFFFFFF) / 8] & (1 << (bo[0] & 7))) && (tptr[(bo[1] & 0x7FFFFFFF) / 8] & (1 << (bo[1] & 7))) )
    {
     tptr[(bo[0] & 0x7FFFFFFF) / 8] &= ~(1 << (bo[0] & 7));
     tptr[(bo[1] & 0x7FFFFFFF) / 8] &= ~(1 << (bo[1] & 7));
    }
   }
  }

  // Now, axis and misc data...
  for(int tmi = 0; tmi < PortDevice[x]->NumInputs; tmi++)
  {
   switch(PortDevice[x]->IDII[tmi].Type)
   {
    default: break;

    case IDIT_BYTE_SPECIAL:
			assert(tmi < 13 + 1);
			((uint8 *)PortData[x])[tmi] = BarcodeWorldData[tmi];
			break;

    case IDIT_X_AXIS_REL:
    case IDIT_Y_AXIS_REL:
                      MDFN_en32lsb(((uint8 *)PortData[x] + PortBitOffsets[x][tmi] / 8), (uint32)((PortDevice[x]->IDII[tmi].Type == IDIT_Y_AXIS_REL) ? MouseDataRel[1] : MouseDataRel[0]));
		      break;
    case IDIT_X_AXIS:
    case IDIT_Y_AXIS:
		     {
		      MDFN_en32lsb(((uint8 *)PortData[x] + PortBitOffsets[x][tmi] / 8), (uint32)((PortDevice[x]->IDII[tmi].Type == IDIT_Y_AXIS) ? MouseData[1] : MouseData[0]));
		     }
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

 ckdelay = MDFN_GetSettingUI("ckdelay");

 memset(CKeysPressTime, 0xff, sizeof(CKeysPressTime));
 memset(CKeysLastState, 0, sizeof(CKeysLastState));

 //SetJoyReadMode(1); // Disable joystick event handling, and allow manual state updates.

 BuildPortsInfo(gi);
}

// Update setting strings with butt configs.
static void ResyncGameInputSettings(unsigned port)
{
 for(unsigned int x = 0; x < PortButtSettingNames[port].size(); x++)
  MDFNI_SetSetting(PortButtSettingNames[port][x], BCsToString( PortButtConfig[port][x] ).c_str());
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

 //for(int i = 0; i < PortButtons[arg].size(); i++)
 // printf("%d\n", PortButtConfigPrettyPrio[arg][i]);
 //exit(1);

 for(;cd_x < (int)PortButtons[arg].size(); cd_x++)
 {
  int snooty = 0;

  for(unsigned int i = 0; i < PortButtons[arg].size(); i++)
   if(PortButtConfigPrettyPrio[arg][i] == cd_x)
    snooty = i;

  // For Lynx, GB, GBA, NGP, WonderSwan(especially wonderswan!)
  //if(!strcasecmp(PortDevice[arg]->ShortName, "builtin")) // && !arg)
  if(NumPorts == 1 && PortPossibleDevices[CurGame->shortname][0].size() == 1)
   trio_snprintf(buf, 512, "%s", PortButtons[arg][snooty]);
  else
   trio_snprintf(buf, 512, "%s %d: %s", PortDevice[arg]->FullName, arg + 1, PortButtons[arg][snooty]);

  if(cd_x != cd_lx)
  {
   cd_lx = cd_x;
   subcon_begin(PortButtConfig[arg][snooty]);
  }
  if(!subcon(buf, PortButtConfig[arg][snooty], 0))
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

 PortPossibleDevices[system->shortname][w].push_back(info);

 trio_snprintf(setting_def_search, 512, "%s.input.%s.%s", system->shortname, system->InputInfo->Types[w].ShortName, info->ShortName);
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

 for(int x = 0; x < info->NumInputs; x++)
 {
  if(info->IDII[x].Type != IDIT_BUTTON && info->IDII[x].Type != IDIT_BUTTON_CAN_RAPID && info->IDII[x].Type != IDIT_BUTTON_ANALOG)
   continue;

  if(NULL == info->IDII[x].SettingName)
   continue;

  MDFNSetting tmp_setting;

  const char *default_value = "";

  if(def_bc)
   PendingGarbage.push_back((void *)(default_value = strdup(BCToString(def_bc[butti]).c_str()) ));

  //printf("Maketset: %s %s\n", setting_name, default_value);

  memset(&tmp_setting, 0, sizeof(tmp_setting));

  PendingGarbage.push_back((void *)(tmp_setting.name = CleanSettingName(trio_aprintf("%s.input.%s.%s.%s", system->shortname, system->InputInfo->Types[w].ShortName, info->ShortName, info->IDII[x].SettingName)) ));
  PendingGarbage.push_back((void *)(tmp_setting.description = trio_aprintf("%s, %s, %s: %s", system->shortname, system->InputInfo->Types[w].FullName, info->FullName, info->IDII[x].Name) ));
  tmp_setting.type = MDFNST_STRING;
  tmp_setting.default_value = default_value;
  
  tmp_setting.flags = MDFNSF_SUPPRESS_DOC;
  tmp_setting.description_extra = NULL;

  settings.push_back(tmp_setting);

  // Now make a rapid butt-on-stick-on-watermelon
  if(info->IDII[x].Type == IDIT_BUTTON_CAN_RAPID)
  {
   memset(&tmp_setting, 0, sizeof(tmp_setting));

   PendingGarbage.push_back((void *)( tmp_setting.name = CleanSettingName(trio_aprintf("%s.input.%s.%s.rapid_%s", system->shortname, system->InputInfo->Types[w].ShortName, info->ShortName, info->IDII[x].SettingName)) ));
   PendingGarbage.push_back((void *)( tmp_setting.description = trio_aprintf("%s, %s, %s: Rapid %s", system->shortname, system->InputInfo->Types[w].FullName, info->FullName, info->IDII[x].Name) ));
   tmp_setting.type = MDFNST_STRING;

   tmp_setting.default_value = "";

   tmp_setting.flags = MDFNSF_SUPPRESS_DOC;
   tmp_setting.description_extra = NULL;

   settings.push_back(tmp_setting);
  }
  butti++;
 }
}


static void MakeSettingsForPort(std::vector <MDFNSetting> &settings, const MDFNGI *system, const int w, const InputPortInfoStruct *info)
{
#if 1
 if(info->NumTypes > 1)
 {
  MDFNSetting tmp_setting;
  MDFNSetting_EnumList *EnumList;

  memset(&tmp_setting, 0, sizeof(MDFNSetting));

  EnumList = (MDFNSetting_EnumList *)calloc(sizeof(MDFNSetting_EnumList), info->NumTypes + 1);

  for(int device = 0; device < info->NumTypes; device++)
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

 for(int device = 0; device < info->NumTypes; device++)
 {
  const InputDeviceInfoStruct *dinfo = &info->DeviceInfo[device];

  if(dinfo->PortExpanderDeviceInfo)
  {
   fprintf(stderr, "PortExpanderDeviceInfo support is incomplete.");
   abort();

   const InputPortInfoStruct *sub_ports = (const InputPortInfoStruct *)dinfo->PortExpanderDeviceInfo;
   const int sub_port_count = dinfo->NumInputs;

   PortPossibleDevices[system->shortname][w].push_back(&info->DeviceInfo[device]);

   for(int sub_port = 0; sub_port < sub_port_count; sub_port++)
   {
    MakeSettingsForPort(settings, system, w + sub_port, &sub_ports[sub_port]);
   }
   //for(int sub_device = 0; sub_device < dinfo->PortExp
  }
  else
  {
   MakeSettingsForDevice(settings, system, w, &info->DeviceInfo[device]);
  }
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
  if(MDFNSystems[x]->InputInfo)
  {
   PortPossibleDevices[MDFNSystems[x]->shortname] = new SnugglyWuggly[16];

   assert(MDFNSystems[x]->InputInfo->InputPorts <= 16);

   for(int port = 0; port < MDFNSystems[x]->InputInfo->InputPorts; port++)
    MakeSettingsForPort(settings, MDFNSystems[x], port, &MDFNSystems[x]->InputInfo->Types[port]);
  }
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

  tmp_setting.flags = MDFNSF_SUPPRESS_DOC;
  tmp_setting.description_extra = NULL;

  PendingGarbage.push_back((void *)( tmp_setting.default_value = strdup(BCsToString(CKeys[x].bc, 2).c_str()) ));
  settings.push_back(tmp_setting);
 }
}

void KillGameInput(void)
{
 KillPortsInfo();
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

