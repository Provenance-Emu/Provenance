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

#include <trio/trio.h>
#include <map>

#include "input.h"
#include "sound.h"
#include "video.h"
#include "Joystick.h"
#include "mouse.h"
#include "keyboard.h"
#include "netplay.h"
#include "cheat.h"
#include "fps.h"
#include "debugger.h"
#include "help.h"
#include "rmdui.h"

int NoWaiting = 0;

static bool ViewDIPSwitches = false;
static bool InputGrab = false;
static bool EmuKeyboardKeysGrabbed = false;
static bool NPCheatDebugKeysGrabbed = false;

static bool inff = 0;
static bool insf = 0;

bool RewindState = true;
bool DNeedRewind = false;

static unsigned int autofirefreq;
static unsigned int ckdelay;

static bool fftoggle_setting;
static bool sftoggle_setting;

static int ConfigDevice(int arg);
static void ConfigDeviceBegin(void);

static void subcon_begin(void);
static bool subcon(const char *text, std::vector<ButtConfig> &bc, const bool commandkey, const bool AND_Mode);

static void ResyncGameInputSettings(unsigned port);
static void CalcWMInputBehavior(void);

static bool DTestButton(const std::vector<ButtConfig>& bc, const bool bypass_key_masking)
{
 size_t match_count = 0;
 bool invert = false;

 for(size_t i = 0; i < bc.size(); i++)
 {
  auto const& bce = bc[i];

  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:
	match_count += invert ^ (bool)KBMan::TestButton(bce, bypass_key_masking);
	break;

   case BUTTC_JOYSTICK:
	match_count += invert ^ (bool)JoystickManager::TestButton(bce);
	break;

   case BUTTC_MOUSE:
	match_count += invert ^ (bool)MouseMan::TestButton(bce);
	break;
  }
  invert = (bce.ANDGroupCont < 0);

  if(!bce.ANDGroupCont)
  {
   if(match_count > i)
    return true;

   match_count = i + 1;
  }
 }

 return false;
}

static INLINE int32 DTestAnalogButton(const std::vector<ButtConfig>& bc, const bool bypass_key_masking)
{
 int32 accum = 0;

 for(auto const& bce : bc)
 {
  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:	accum += KBMan::TestAnalogButton(bce, bypass_key_masking); break;
   case BUTTC_JOYSTICK:	accum += JoystickManager::TestAnalogButton(bce); break;
   case BUTTC_MOUSE:	accum += MouseMan::TestAnalogButton(bce); break;
  }
 }

 return std::min<int32>(32767, accum);
}

static INLINE uint32 DTestAxis(const std::vector<ButtConfig>& neg_bc, const std::vector<ButtConfig>& pos_bc, const bool bypass_key_masking, const float dev_axis_scale)
{
 int32 accum = 0;

 for(auto const& bce : neg_bc)
 {
  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:	accum -= KBMan::TestAnalogButton(bce, bypass_key_masking); break;
   case BUTTC_JOYSTICK:	accum -= JoystickManager::TestAnalogButton(bce); break;
   case BUTTC_MOUSE:	accum -= MouseMan::TestAnalogButton(bce); break;
  }
 }

 for(auto const& bce : pos_bc)
 {
  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:	accum += KBMan::TestAnalogButton(bce, bypass_key_masking); break;
   case BUTTC_JOYSTICK:	accum += JoystickManager::TestAnalogButton(bce); break;
   case BUTTC_MOUSE:	accum += MouseMan::TestAnalogButton(bce); break;
  }
 }

 return 32768 + std::max<int32>(-32768, std::min<int32>(32767, floor(0.5 + accum * dev_axis_scale)));
}

// Returns 1.51.12 value
static int64 DTestAxisRel(const std::vector<ButtConfig>& neg_bc, const std::vector<ButtConfig>& pos_bc, const bool bypass_key_masking)
{
 int64 accum = 0;

 for(auto const& bce : neg_bc)
 {
  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:	accum -= KBMan::TestAxisRel(bce, bypass_key_masking); break;
   case BUTTC_JOYSTICK: accum -= JoystickManager::TestAxisRel(bce); break;
   case BUTTC_MOUSE:	accum -= MouseMan::TestAxisRel(bce); break;
  }
 }

 for(auto const& bce : pos_bc)
 {
  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:	accum += KBMan::TestAxisRel(bce, bypass_key_masking); break;
   case BUTTC_JOYSTICK: accum += JoystickManager::TestAxisRel(bce); break;
   case BUTTC_MOUSE:	accum += MouseMan::TestAxisRel(bce); break;
  }
 }

 return accum;
}

static float DTestPointer(const std::vector<ButtConfig>& bc, const bool bypass_key_masking, const bool axis_hint)
{
 if(MDFN_LIKELY(bc.size()))
 {
  const ButtConfig& bce = bc[0];

  switch(bce.DeviceType)
  {
   case BUTTC_JOYSTICK:
	printf("%d %d %f\n", axis_hint, JoystickManager::TestAnalogButton(bce), Video_PtoV_J(JoystickManager::TestAnalogButton(bce), axis_hint, bce.ButtonNum & JoystickManager::JOY_BN_GUN_TRANSLATE));
	return Video_PtoV_J(JoystickManager::TestAnalogButton(bce), axis_hint, bce.ButtonNum & JoystickManager::JOY_BN_GUN_TRANSLATE);

   case BUTTC_MOUSE:
	return MouseMan::TestPointer(bce);
  }
 }

 return 0;
}

/* Used for command keys */
static bool DTestButtonCombo(std::vector<ButtConfig> &bc, const bool bypass_key_masking, const bool ignore_ralt)
{
 size_t match_count = 0;
 bool invert = false;

 for(size_t i = 0; i < bc.size(); i++)
 {
  auto const& bce = bc[i];

  switch(bce.DeviceType)
  {
   case BUTTC_KEYBOARD:
	match_count += invert ^ (bool)KBMan::TestButtonWithMods(bce, bypass_key_masking, ignore_ralt);
	break;

   case BUTTC_JOYSTICK:
	match_count += invert ^ (bool)JoystickManager::TestButton(bce);
	break;

   case BUTTC_MOUSE:
	match_count += invert ^ (bool)MouseMan::TestButton(bce);
	break;
  }
  invert = (bce.ANDGroupCont < 0);

  if(!bce.ANDGroupCont)
  {
   if(match_count > i)
    return true;

   match_count = i + 1;
  }
 }

 return false;
}


//
//
//
static std::string BCGToString(const std::vector<ButtConfig>& bcg)
{
 std::string ret;

 for(size_t i = 0; i < bcg.size(); i++)
 {
  char tmp[256] = { 0 };
  char devidstr[2 + 32 + 1];
  const ButtConfig& bc = bcg[i];
  char scalestr[32];

  if(!MDFN_de64msb(&bc.DeviceID[0]) && !MDFN_de64msb(&bc.DeviceID[8]))
   trio_snprintf(devidstr, sizeof(devidstr), "0x0");
  else
   trio_snprintf(devidstr, sizeof(devidstr), "0x%016llx%016llx", (unsigned long long)MDFN_de64msb(&bc.DeviceID[0]), (unsigned long long)MDFN_de64msb(&bc.DeviceID[8]));

  if(bc.Scale == 4096)
   scalestr[0] = 0;
  else
   trio_snprintf(scalestr, sizeof(scalestr), " %u", bc.Scale);

  if(bc.DeviceType == BUTTC_KEYBOARD)
   trio_snprintf(tmp, sizeof(tmp), "keyboard %s %s%s", devidstr, KBMan::BNToString(bc.ButtonNum).c_str(), scalestr);
  else if(bc.DeviceType == BUTTC_JOYSTICK)
   trio_snprintf(tmp, sizeof(tmp), "joystick %s %s%s", devidstr, JoystickManager::BNToString(bc.ButtonNum).c_str(), scalestr);
  else if(bc.DeviceType == BUTTC_MOUSE)
   trio_snprintf(tmp, sizeof(tmp), "mouse %s %s%s", devidstr, MouseMan::BNToString(bc.ButtonNum).c_str(), scalestr);

  if(tmp[0])
  {
   if(i)
   {
    const int agc = bcg[i - 1].ANDGroupCont;

    if(agc < 0)
     ret += " &! ";
    else if(agc > 0)
     ret += " && ";
    else
     ret += " || ";
   }

   ret += tmp;
  }
 }

 return ret;
}

static bool StringToDeviceID(const char* s, size_t len, std::array<uint8, 16>* device_id)
{
 uint64 a = 0, b = 0;

 while(len--)
 {
  int nyb;

  if(*s >= '0' && *s <= '9')
   nyb = *s - '0';
  else if(*s >= 'A' && *s <= 'F')
   nyb = 0xA + (*s - 'A');
  else if(*s >= 'a' && *s <= 'f')
   nyb = 0xA + (*s - 'a');
  else
   return false;

  a <<= 4;
  a |= b >> 60;
  b <<= 4;
  b |= nyb;

  s++;
 }

 //printf("HOW: %016llx%016llx\n", a, b);

 MDFN_en64msb(&(*device_id)[0], a);
 MDFN_en64msb(&(*device_id)[8], b);

 return true;
}

//
//
//
static bool StringToBCG(std::vector<ButtConfig>* bcg, const char* s, const char* defs = "", const bool abs_pointer_axis_thing = false)
{
 if(bcg)
  bcg->clear();

#if 1
 if(strstr(s, "0x") == NULL)
 {
  //
  // Backwards-compat for 0.9.x joystick mappings
  //
  bool AND_Mode = false;
  char device_name[64];
  char extra[256];
  bool any_kb = false;
  bool any_mouse = false;
  bool any_joy = false;

  s = MDFN_strskipspace(s);

  if(!strncmp(s, "/&&\\", 4))
  {
   AND_Mode = true;
   s += 4;
  }

  s = MDFN_strskipspace(s);

  do
  {
   if(trio_sscanf(s, "%63s %255[^~]", device_name, extra) == 2)
   {
    if(!MDFN_strazicmp(device_name, "keyboard"))
     any_kb = true;
    else
    {
     ButtConfig bc;

     bc.ANDGroupCont = AND_Mode;
     bc.Scale = 4096;

     if(!MDFN_strazicmp(device_name, "joystick"))
     {
      any_joy = true;
      //
      unsigned long long devid = 0;
      unsigned bn = 0;

      if(trio_sscanf(extra, "%016llx %08x", &devid, &bn) == 2)
      {
       bc.DeviceType = BUTTC_JOYSTICK;
       bc.DeviceNum = JoystickManager::GetIndexByUniqueID_09x(devid);
       bc.DeviceID = JoystickManager::GetUniqueIDByIndex(bc.DeviceNum);	// Not perfect, but eh...

       if(!JoystickManager::Translate09xBN(bn, &bc.ButtonNum, abs_pointer_axis_thing))
        return false;
      }
      else
       return false;
     }
     else if(!MDFN_strazicmp(device_name, "mouse"))
     {
      any_mouse = true;
      //
      unsigned long long dummy_devid = 0;
      unsigned bn = 0;

      if(trio_sscanf(extra, "%016llx %08x", &dummy_devid, &bn) == 2 || trio_sscanf(extra, "%d", &bn) == 1)
      {
       bc.DeviceID = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
       bc.DeviceType = BUTTC_MOUSE;
       bc.DeviceNum = 0;

       if(!MouseMan::Translate09xBN(bn, &bc.ButtonNum))
        return false;
      }
      else
       return false;
     }
     else
      return false;

     if(bcg)
      bcg->push_back(bc);
    }
   }
   s = strchr(s, '~');
   if(s) s++;
  } while(s);

  if(bcg)
  {
   if(bcg->size())
    bcg->back().ANDGroupCont = false;
   //
   //
   //
   if(any_kb)
   {
    bool need_mouse_defaults = false;

    if(AND_Mode && (any_mouse || any_joy))
    {
     need_mouse_defaults = any_mouse;
     bcg->clear();
    }

    std::vector<ButtConfig> defbc;

    if(!StringToBCG(&defbc, defs))
    {
     assert(0);
    }

    for(auto const& bc : defbc)
    {
     assert(!bc.ANDGroupCont);
     if(bc.DeviceType == BUTTC_KEYBOARD || (bc.DeviceType == BUTTC_MOUSE && need_mouse_defaults))
     {
      bcg->push_back(bc);
     }
    }
   }
  }

  //printf("\"%s\" ---> \"%s\"\n", s.c_str(), BCGToString(ret).c_str());

  return true;
 }
#endif
 //
 // 
 //
 unsigned which_part = 0;
 ButtConfig bc;
 size_t len;

 do
 {
  const char* start_s;
  int agc = INT_MAX;

  s = MDFN_strskipspace(s);
  start_s = s;

  s = MDFN_strskipnonspace(s);
  len = s - start_s;

  if(len == 2)
  {
   if(start_s[0] == '&' && start_s[1] == '&')
    agc = true;
   else if(start_s[0] == '|' && start_s[1] == '|')
    agc = false;
   else if(start_s[0] == '&' && start_s[1] == '!')
    agc = -1;
  }
  else if(!len)
   agc = false;

  if(agc != INT_MAX)
  {
   if(which_part < 3)
   {
    printf("Incomplete?\n");
    return false;
   }
   else if(which_part < 4)
    bc.Scale = 4096;

   bc.ANDGroupCont = agc;

   if(bcg)
    bcg->push_back(bc);

   which_part = 0;
  }
  else if(which_part == 0)
  {
   if(len == 8 && !MDFN_memazicmp(start_s, "keyboard", 8))
    bc.DeviceType = BUTTC_KEYBOARD;
   else if(len == 8 && !MDFN_memazicmp(start_s, "joystick", 8))
    bc.DeviceType = BUTTC_JOYSTICK;
   else if(len == 5 && !MDFN_memazicmp(start_s, "mouse", 5))
    bc.DeviceType = BUTTC_MOUSE;
   else
   {
    printf("Unknown device type\n");
    return false;
   }

   which_part++;
  }
  else if(which_part == 1)
  {
   if(len < (2 + 1) || start_s[0] != '0' || start_s[1] != 'x' || !StringToDeviceID(start_s + 2, len - 2, &bc.DeviceID))
   {
    printf("Bad device id\n");
    return false;
   }

   which_part++;
  }
  else if(which_part == 2)
  {
   char bnstr[256];

   if((len + 1) > sizeof(bnstr))
   {
    printf("bn string too long.");
    return false;
   }

   memcpy(bnstr, start_s, len);
   bnstr[len] = 0;

   if(bc.DeviceType == BUTTC_KEYBOARD)
   {
    if(!KBMan::StringToBN(bnstr, &bc.ButtonNum))
    {
     printf("Bad keyboard bn string\n");
     return false;
    }

    bc.DeviceNum = 0;	// TODO
   }
   else if(bc.DeviceType == BUTTC_JOYSTICK)
   {
    if(!JoystickManager::StringToBN(bnstr, &bc.ButtonNum))
    {
     printf("Bad joystick bn string\n");
     return false;
    }

    bc.DeviceNum = JoystickManager::GetIndexByUniqueID(bc.DeviceID);
   }
   else if(bc.DeviceType == BUTTC_MOUSE)
   {
    if(!MouseMan::StringToBN(bnstr, &bc.ButtonNum))
    {
     printf("Bad mouse bn string\n");
     return false;
    }

    bc.DeviceNum = 0;	// TODO
   }
   which_part++;
  }
  else if(which_part == 3)
  {
   unsigned scale = 0;

   for(const char* sls = start_s; sls != (start_s + len); sls++)
   {
    if(*sls >= '0' && *sls <= '9')
    {
     scale = (scale * 10) + (*sls - '0');
     if(scale > 0xFFFF) 
     {
      printf("Scale overflow\n");
      return false;
     }
    }
    else
    {
     printf("Bad scale value\n");
     return false;
    }
   }

   bc.Scale = scale;
   which_part++;
  }
  else if(which_part == 4)
  {
   printf("Junk at end of input mapping?\n");
   return false;
  }
 } while(len);

 if(bcg && bcg->size() > 0)
  bcg->back().ANDGroupCont = false;

 return true;
}

static bool ValidateIMSetting(const char* name, const char* value)
{
#if 0
 {
  std::vector<ButtConfig> m;
  StringToBCG(&m, value, MDFNI_GetSettingDefault(name).c_str());

  std::string tmp = BCGToString(m);
  printf("%s -------- %s\n", value, tmp.c_str());
  assert(tmp == value);
 }
#endif

 return StringToBCG(nullptr, value);
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

enum InputMappingType : unsigned
{
 IMTYPE_UNKNOWN = 0,
 IMTYPE_BUTTON,
 IMTYPE_BUTTON_RAPID,
 IMTYPE_BUTTON_ANALOG,
 IMTYPE_AXIS_NEG,
 IMTYPE_AXIS_POS,
 IMTYPE_AXIS_REL_POS,
 IMTYPE_AXIS_REL_NEG,
 IMTYPE_POINTER_X,
 IMTYPE_POINTER_Y,
 IMTYPE_SWITCH,
 //IMTYPE_STATUS
};

struct ButtonInfoCache
{
 char* SettingName = nullptr;
 char* CPName = nullptr;
 const InputDeviceInputInfoStruct* IDII = nullptr;
 InputMappingType IMType = IMTYPE_UNKNOWN;
 uint16 BitOffset = 0;
 uint16 ExclusionBitOffset = 0xFFFF;
 std::vector<ButtConfig> BC;

 struct
 {
  uint8 NumPos = 0;
  uint8 LastPos = 0;
  uint8 BitSize = 0;
  bool LastPress = false;
 } Switch;

 struct
 {
  int64 AccumError = 0;
 } AxisRel;
};

//static_assert(sizeof(ButtonInfoCache) == 64, "hm");

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
 std::vector<unsigned> BCC; // Button config cache

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
 PIDC[port].BCC.clear();
}


//
// trio_aprintf() was taking too long when building all the input mapping settings we have now from Saturn keyboards...
//
static char* build_string(const char *s0, const char* s1, const char* s2 = "", const char* s3 = "", const char* s4 = "", const char* s5 = "", const char *s6 = "", const char* s7 = "", const char* s8 = "")
{
 const size_t s0_len = strlen(s0);
 const size_t s1_len = strlen(s1);
 const size_t s2_len = strlen(s2);
 const size_t s3_len = strlen(s3);
 const size_t s4_len = strlen(s4);
 const size_t s5_len = strlen(s5);
 const size_t s6_len = strlen(s6);
 const size_t s7_len = strlen(s7);
 const size_t s8_len = strlen(s8);

 char* ret = (char*)malloc(s0_len + s1_len + s2_len + s3_len + s4_len + s5_len + s6_len + s7_len + s8_len + 1);
 char* t = ret;

 t = (char*)memcpy(t, s0, s0_len) + s0_len;
 t = (char*)memcpy(t, s1, s1_len) + s1_len;
 t = (char*)memcpy(t, s2, s2_len) + s2_len;
 t = (char*)memcpy(t, s3, s3_len) + s3_len;
 t = (char*)memcpy(t, s4, s4_len) + s4_len;
 t = (char*)memcpy(t, s5, s5_len) + s5_len;
 t = (char*)memcpy(t, s6, s6_len) + s6_len;
 t = (char*)memcpy(t, s7, s7_len) + s7_len;
 t = (char*)memcpy(t, s8, s8_len) + s8_len;
 *t = 0;

 return ret;
}


//
// Only call on init, or when the device on a port changes.
//
static void BuildPortInfo(MDFNGI *gi, const unsigned int port)
{
 const InputDeviceInfoStruct *zedevice = NULL;
 char *port_device_name;
 unsigned int device;

 std::vector<std::pair<uint64, size_t>> bcc_stmp;

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
   if(!MDFN_strazicmp(gi->PortInfo[port].DeviceInfo[device].ShortName, port_device_name))
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
   //
   char sname_pdpfx[384];

   trio_snprintf(sname_pdpfx, sizeof(sname_pdpfx), "%s.input.%s.%s", gi->shortname, gi->PortInfo[port].ShortName, zedevice->ShortName);

   if(idii.Type == IDIT_AXIS && (idii.Flags & IDIT_AXIS_FLAG_SQLR) && !analog_axis_scale_grabbed)
   {
    char tmpsn[512];

    trio_snprintf(tmpsn, sizeof(tmpsn), "%s.axis_scale", sname_pdpfx);
    PIDC[port].AxisScale = MDFN_GetSettingF(tmpsn);
    analog_axis_scale_grabbed = true;
   }

   if(idii.Type == IDIT_BUTTON || idii.Type == IDIT_BUTTON_CAN_RAPID ||
	 idii.Type == IDIT_BUTTON_ANALOG ||
	 idii.Type == IDIT_AXIS || 
	 idii.Type == IDIT_POINTER_X || idii.Type == IDIT_POINTER_Y ||
	 idii.Type == IDIT_AXIS_REL ||
	 idii.Type == IDIT_SWITCH)
   {
    for(unsigned part = 0; part < ((idii.Type == IDIT_BUTTON_CAN_RAPID || idii.Type == IDIT_AXIS || idii.Type == IDIT_AXIS_REL) ? 2 : 1); part++)
    {
     ButtonInfoCache bic;

     bic.IDII = &idii;

     switch(idii.Type)
     {
      default:
	break;

      case IDIT_BUTTON:
	bic.IMType = IMTYPE_BUTTON;
	break;

      case IDIT_BUTTON_CAN_RAPID:
	bic.IMType = part ? IMTYPE_BUTTON_RAPID : IMTYPE_BUTTON;
	break;

      case IDIT_BUTTON_ANALOG:
	bic.IMType = IMTYPE_BUTTON_ANALOG;
	break;

      case IDIT_AXIS:
	bic.IMType = part ? IMTYPE_AXIS_POS : IMTYPE_AXIS_NEG;
	break;

      case IDIT_AXIS_REL:
	bic.IMType = part ? IMTYPE_AXIS_REL_POS : IMTYPE_AXIS_REL_NEG;
	break;

      case IDIT_POINTER_X:
	bic.IMType = IMTYPE_POINTER_X;
	break;

      case IDIT_POINTER_Y:
	bic.IMType = IMTYPE_POINTER_Y;
	break;

      case IDIT_SWITCH:
	bic.IMType = IMTYPE_SWITCH;
	bic.Switch.NumPos = idii.Switch.NumPos;
	bic.Switch.LastPos = 0;
	bic.Switch.BitSize = idii.BitSize;
	bic.Switch.LastPress = false;
	break;
     }
     //
     //
     //
     if(idii.Type == IDIT_AXIS_REL)
     {
      bic.SettingName = build_string(sname_pdpfx, ".", idii.SettingName, idii.SettingName[0] ? "_" : "", idii.AxisRel.sname_dir[part]);
      bic.CPName = build_string(idii.Name, " ", idii.AxisRel.name_dir[part]);
     }
     else if(idii.Type == IDIT_AXIS)
     {
      bic.SettingName = build_string(sname_pdpfx, ".", idii.SettingName, idii.SettingName[0] ? "_" : "", idii.Axis.sname_dir[part]);
      bic.CPName = build_string(idii.Name, " ", idii.Axis.name_dir[part]);
     }
     else
     {
      bic.SettingName = build_string(sname_pdpfx, ".", bic.IMType == IMTYPE_BUTTON_RAPID ? "rapid_" : "", idii.SettingName);
      bic.CPName = trio_aprintf(_("%s%s%s"), (bic.IMType == IMTYPE_BUTTON_RAPID ? _("Rapid ") : ""), idii.Name, (bic.IMType == IMTYPE_SWITCH) ? _(" Select") : "");
     }
     CleanSettingName(bic.SettingName);
     if(!StringToBCG(&bic.BC, MDFN_GetSettingS(bic.SettingName).c_str(), MDFNI_GetSettingDefault(bic.SettingName).c_str(), (idii.Type == IDIT_POINTER_X || idii.Type == IDIT_POINTER_Y)))
      abort();
     bic.BitOffset = idii.BitOffset;

     if(idii.ConfigOrder >= 0 && idii.Type != IDIT_AXIS_REL)
     {
      std::pair<uint64, size_t> pot;

      pot.first = ((uint64)idii.ConfigOrder << 32) + (part ^ (idii.Type == IDIT_AXIS && (idii.Flags & IDIT_AXIS_FLAG_INVERT_CO)) ^ (idii.Type == IDIT_AXIS_REL && (idii.Flags & IDIT_AXIS_REL_FLAG_INVERT_CO)));
      pot.second = PIDC[port].BIC.size();

      bcc_stmp.push_back(pot);
     }
     //
     PIDC[port].BIC.push_back(bic);
    }
   }
   else if(idii.Type == IDIT_STATUS)
   {
    StatusInfoCache sic;

    sic.IDII = &idii;
    sic.StatusLastState = 0;

    sic.StatusNumStates = idii.Status.NumStates;
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


 //
 // Calculate configuration order.
 //
 std::sort(bcc_stmp.begin(), bcc_stmp.end(),
	[](const std::pair<uint64, size_t>& a, const std::pair<uint64, size_t>& b) { return a.first < b.first || (a.first == b.first && a.second < b.second); });

 for(const auto& p : bcc_stmp)
  PIDC[port].BCC.push_back(p.second);

 //
 // Now, search for exclusion buttons.
 //
 for(auto& bic : PIDC[port].BIC)
 {
  if((bic.IDII->Type == IDIT_BUTTON || bic.IDII->Type == IDIT_BUTTON_CAN_RAPID) && bic.IDII->Button.ExcludeName)
  {
   bool found = false;

   for(auto const& sub_bic : PIDC[port].BIC)
   {
    if(!MDFN_strazicmp(bic.IDII->Button.ExcludeName, sub_bic.IDII->SettingName))
    {
     assert(sub_bic.IDII->Type == IDIT_BUTTON || sub_bic.IDII->Type == IDIT_BUTTON_CAN_RAPID);
     bic.ExclusionBitOffset = sub_bic.BitOffset;
     found = true;
     break;
    }
   }
   assert(found);
  }
 }

 PIDC[port].Data = MDFNI_SetInput(port, device);

 //
 // Set default switch positions.
 //
 for(auto& bic : PIDC[port].BIC)
 {
  if(bic.IMType == IMTYPE_SWITCH)
  {
   char tmpsn[512];
   trio_snprintf(tmpsn, sizeof(tmpsn), "%s.defpos", bic.SettingName);
   bic.Switch.LastPos = MDFN_GetSettingUI(tmpsn);
   BitsIntract(PIDC[port].Data, bic.BitOffset, bic.Switch.BitSize, bic.Switch.LastPos);
  }
 }
}

static void IncSelectedDevice(unsigned int port)
{
 if(MDFNDnetplay)
 {
  MDFN_Notify(MDFN_NOTICE_STATUS, _("Cannot change input device during netplay."));
 }
 else if(RewindState)
 {
  MDFN_Notify(MDFN_NOTICE_STATUS, _("Cannot change input device while state rewinding is active."));
 }
 else if(port >= CurGame->PortInfo.size())
  MDFN_Notify(MDFN_NOTICE_STATUS, _("Port %u does not exist."), port + 1);
 else if(CurGame->PortInfo[port].DeviceInfo.size() <= 1)
  MDFN_Notify(MDFN_NOTICE_STATUS, _("Port %u device not selectable."), port + 1);
 else
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
  CalcWMInputBehavior();

  MDFN_Notify(MDFN_NOTICE_STATUS, _("%s selected on port %d"), CurGame->PortInfo[port].DeviceInfo[PIDC[port].CurrentDeviceIndex].FullName, port + 1);
 }
}

//
// Don't use CTRL+ALT modifier for any defaults(due to AltGr on Windows, and usage as WM/OS-level hotkeys).
//
#define MK(x)			"keyboard 0x0 " KBD_SCANCODE_STRING(x)

#define MK_CK_(x)		MK(x)
#define MK_CK_ALT_(x)		MK(x) "+alt"
#define MK_CK_SHIFT_(x)		MK(x) "+shift"
#define MK_CK_CTRL_(x)		MK(x) "+ctrl"
#define MK_CK_ALT_SHIFT_(x)	MK(x) "+alt+shift"
#define MK_CK_CTRL_SHIFT_(x)	MK(x) "+ctrl+shift"
//
#define MK_CK(x)		MK_CK_(x)
#define MK_CK_SHIFT(x)		MK_CK_SHIFT_(x)
#define MK_CK_ALT(x)		MK_CK_ALT_(x)
#define MK_CK_ALT_SHIFT(x)	MK_CK_ALT_SHIFT_(x)
#define MK_CK_CTRL(x)		MK_CK_CTRL_(x)
#define MK_CK_CTRL_SHIFT(x)	MK_CK_CTRL_SHIFT_(x)
//
#define MK_CK2(x,y)		MK_CK_(x) " || " MK_CK_(y)
#define MK_CK_ALT2(x,y)		MK_CK_ALT_(x) " || " MK_CK_ALT_(y)

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

	CK_SELECT_DISK,
	CK_TOGGLE_DIPVIEW,
	CK_INSERT_COIN,
	CK_INSERTEJECT_DISK,
	CK_ACTIVATE_BARCODE,

        CK_TOGGLE_GRAB,
	CK_INPUT_CONFIG1,
	CK_INPUT_CONFIG2,
        CK_INPUT_CONFIG3,
        CK_INPUT_CONFIG4,
	CK_INPUT_CONFIG5,
        CK_INPUT_CONFIG6,
        CK_INPUT_CONFIG7,
        CK_INPUT_CONFIG8,
        CK_INPUT_CONFIG9,
        CK_INPUT_CONFIG10,
        CK_INPUT_CONFIG11,
        CK_INPUT_CONFIG12,
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
	CK_PAUSE,
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
        CK_DEVICE_SELECT9,
        CK_DEVICE_SELECT10,
        CK_DEVICE_SELECT11,
        CK_DEVICE_SELECT12,

	_CK_COUNT
};

struct COKE
{
 const char* text;
 const char* description;
 const char* setting_name;
 const char* setting_default;

 bool BypassKeyZeroing;
 bool SkipCKDelay;
 bool TextInputExit;
};

#define CKEYDEF_BYPASSKEYZEROING 1
#define CKEYDEF_DANGEROUS	 2	// For CK delay
#define CKEYDEF_TEXTINPUTEXIT	 4	// Set with with cheat interface and debugger; for AltGr madness.

#define CKEYDEF(n, d, f, c)	{ n, gettext_noop(d), "command." n, c, (bool)((f) & CKEYDEF_BYPASSKEYZEROING), (bool)!((f) & CKEYDEF_DANGEROUS), (bool)((f) & CKEYDEF_TEXTINPUTEXIT) }

static const COKE CKeys[_CK_COUNT]	=
{
	CKEYDEF( "save_state", "Save state", 0, 		MK_CK(F5) ),
	CKEYDEF( "load_state", "Load state", CKEYDEF_DANGEROUS, MK_CK(F7) ),
	CKEYDEF( "save_movie", "Save movie", 0, 		MK_CK_SHIFT(F5) ),
	CKEYDEF( "load_movie", "Load movie", CKEYDEF_DANGEROUS, MK_CK_SHIFT(F7) ),
	CKEYDEF( "toggle_state_rewind", "Toggle state rewind functionality", 0, MK_CK_ALT(S) ),

	CKEYDEF( "0", "Save state 0 select", 0, MK_CK(0) ),
        CKEYDEF( "1", "Save state 1 select", 0, MK_CK(1) ),
        CKEYDEF( "2", "Save state 2 select", 0, MK_CK(2) ),
        CKEYDEF( "3", "Save state 3 select", 0, MK_CK(3) ),
        CKEYDEF( "4", "Save state 4 select", 0, MK_CK(4) ),
        CKEYDEF( "5", "Save state 5 select", 0, MK_CK(5) ),
        CKEYDEF( "6", "Save state 6 select", 0, MK_CK(6) ),
        CKEYDEF( "7", "Save state 7 select", 0, MK_CK(7) ),
        CKEYDEF( "8", "Save state 8 select", 0, MK_CK(8) ),
        CKEYDEF( "9", "Save state 9 select", 0, MK_CK(9) ),

	CKEYDEF( "m0", "Movie 0 select", 0, MK_CK_SHIFT(0) ),
        CKEYDEF( "m1", "Movie 1 select", 0, MK_CK_SHIFT(1) ),
        CKEYDEF( "m2", "Movie 2 select", 0, MK_CK_SHIFT(2) ),
        CKEYDEF( "m3", "Movie 3 select", 0, MK_CK_SHIFT(3) ),
        CKEYDEF( "m4", "Movie 4 select", 0, MK_CK_SHIFT(4) ),
        CKEYDEF( "m5", "Movie 5 select", 0, MK_CK_SHIFT(5) ),
        CKEYDEF( "m6", "Movie 6 select", 0, MK_CK_SHIFT(6) ),
        CKEYDEF( "m7", "Movie 7 select", 0, MK_CK_SHIFT(7) ),
        CKEYDEF( "m8", "Movie 8 select", 0, MK_CK_SHIFT(8) ),
        CKEYDEF( "m9", "Movie 9 select", 0, MK_CK_SHIFT(9) ),

        CKEYDEF( "tl1", "Toggle graphics layer 1", 0, MK_CK_CTRL(1) ),
        CKEYDEF( "tl2", "Toggle graphics layer 2", 0, MK_CK_CTRL(2) ),
        CKEYDEF( "tl3", "Toggle graphics layer 3", 0, MK_CK_CTRL(3) ),
        CKEYDEF( "tl4", "Toggle graphics layer 4", 0, MK_CK_CTRL(4) ),
        CKEYDEF( "tl5", "Toggle graphics layer 5", 0, MK_CK_CTRL(5) ),
        CKEYDEF( "tl6", "Toggle graphics layer 6", 0, MK_CK_CTRL(6) ),
        CKEYDEF( "tl7", "Toggle graphics layer 7", 0, MK_CK_CTRL(7) ),
        CKEYDEF( "tl8", "Toggle graphics layer 8", 0, MK_CK_CTRL(8) ),
        CKEYDEF( "tl9", "Toggle graphics layer 9", 0, MK_CK_CTRL(9) ),

	CKEYDEF( "take_snapshot", 	 "Take screen snapshot", 0, MK_CK(F9) ),
	CKEYDEF( "take_scaled_snapshot", "Take scaled(and filtered) screen snapshot", 0, MK_CK_SHIFT(F9) ),

	CKEYDEF( "toggle_fs", "Toggle fullscreen mode", 0, MK_CK_ALT(RETURN) ),
	CKEYDEF( "fast_forward", "Fast-forward", 0, 	   MK_CK(GRAVE) ),
        CKEYDEF( "slow_forward", "Slow-forward", 0, 	   MK_CK(BACKSLASH) ),

	CKEYDEF( "select_disk", "Select disk/disc", 0, 		MK_CK(F6) ),
	CKEYDEF( "toggle_dipview", "Toggle DIP switch view", 0, MK_CK(F6) ),
	CKEYDEF( "insert_coin", "Insert coin", 0, 		MK_CK(F8) ),
	CKEYDEF( "insert_eject_disk", "Insert/Eject disk/disc", CKEYDEF_DANGEROUS, MK_CK(F8) ),
	CKEYDEF( "activate_barcode", "Activate barcode(for Famicom)", 0, 	   MK_CK(F8) ),
	CKEYDEF( "toggle_grab", "Grab input", CKEYDEF_BYPASSKEYZEROING, MK_CK_CTRL_SHIFT(APPLICATION) ),

	CKEYDEF( "input_config1",  "Configure buttons on virtual port 1",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(1) ),
	CKEYDEF( "input_config2",  "Configure buttons on virtual port 2",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(2) ),
        CKEYDEF( "input_config3",  "Configure buttons on virtual port 3",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(3) ),
        CKEYDEF( "input_config4",  "Configure buttons on virtual port 4",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(4) ),
	CKEYDEF( "input_config5",  "Configure buttons on virtual port 5",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(5) ),
        CKEYDEF( "input_config6",  "Configure buttons on virtual port 6",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(6) ),
        CKEYDEF( "input_config7",  "Configure buttons on virtual port 7",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(7) ),
        CKEYDEF( "input_config8",  "Configure buttons on virtual port 8",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(8) ),
        CKEYDEF( "input_config9",  "Configure buttons on virtual port 9",  CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(9) ),
        CKEYDEF( "input_config10", "Configure buttons on virtual port 10", CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(0) ),
        CKEYDEF( "input_config11", "Configure buttons on virtual port 11", CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(KP_1) ),
        CKEYDEF( "input_config12", "Configure buttons on virtual port 12", CKEYDEF_DANGEROUS, MK_CK_ALT_SHIFT(KP_2) ),

        CKEYDEF( "input_configc", "Configure command key", 				       CKEYDEF_DANGEROUS, MK_CK(F2) ),
        CKEYDEF( "input_configc_am", "Configure command key, for all-pressed-to-trigger mode", CKEYDEF_DANGEROUS, MK_CK_SHIFT(F2) ),

	CKEYDEF( "input_config_abd", "Detect analog buttons on physical joysticks/gamepads(for use with the input configuration process).", CKEYDEF_DANGEROUS, MK_CK(F3) ),

	CKEYDEF( "reset", "Reset", CKEYDEF_DANGEROUS, MK_CK(F10) ),
	CKEYDEF( "power", "Power toggle", CKEYDEF_DANGEROUS, MK_CK(F11) ),
	CKEYDEF( "exit", "Exit", CKEYDEF_BYPASSKEYZEROING | CKEYDEF_DANGEROUS, MK_CK2(F12, ESCAPE) ),
	CKEYDEF( "state_rewind", "Rewind", 0, MK_CK(BACKSPACE) ),
	CKEYDEF( "rotate_screen", "Rotate screen", 0, MK_CK_ALT(O) ),

	CKEYDEF( "togglenetview", "Toggle netplay console", 0, MK_CK(T) ),
	CKEYDEF( "advance_frame", "Advance frame", 0, MK_CK_ALT(A) ),
	CKEYDEF( "run_normal", "Return to normal mode after advancing frames", 0, MK_CK_ALT(R) ),
	CKEYDEF( "pause", "Pause/Unpause", 0, MK_CK(PAUSE) ),
	CKEYDEF( "togglecheatview", "Toggle cheat console", CKEYDEF_BYPASSKEYZEROING | CKEYDEF_TEXTINPUTEXIT, MK_CK_ALT(C) ),
	CKEYDEF( "togglecheatactive", "Enable/Disable cheats", 0, MK_CK_ALT(T) ),
        CKEYDEF( "toggle_fps_view", "Toggle frames-per-second display", 0, MK_CK_SHIFT(F1) ),
	CKEYDEF( "toggle_debugger", "Toggle debugger", CKEYDEF_BYPASSKEYZEROING | CKEYDEF_TEXTINPUTEXIT, MK_CK_ALT(D) ),
	CKEYDEF( "state_slot_dec", "Decrease selected save state slot by 1", 0, MK_CK(MINUS) ),
	CKEYDEF( "state_slot_inc", "Increase selected save state slot by 1", 0, MK_CK(EQUALS) ),
	CKEYDEF( "toggle_help", "Toggle help screen", CKEYDEF_BYPASSKEYZEROING, MK_CK(F1) ),

	CKEYDEF( "device_select1",  "Select virtual device on virtual input port 1",  0, MK_CK_CTRL_SHIFT(1) ),
        CKEYDEF( "device_select2",  "Select virtual device on virtual input port 2",  0, MK_CK_CTRL_SHIFT(2) ),
        CKEYDEF( "device_select3",  "Select virtual device on virtual input port 3",  0, MK_CK_CTRL_SHIFT(3) ),
        CKEYDEF( "device_select4",  "Select virtual device on virtual input port 4",  0, MK_CK_CTRL_SHIFT(4) ),
        CKEYDEF( "device_select5",  "Select virtual device on virtual input port 5",  0, MK_CK_CTRL_SHIFT(5) ),
        CKEYDEF( "device_select6",  "Select virtual device on virtual input port 6",  0, MK_CK_CTRL_SHIFT(6) ),
        CKEYDEF( "device_select7",  "Select virtual device on virtual input port 7",  0, MK_CK_CTRL_SHIFT(7) ),
        CKEYDEF( "device_select8",  "Select virtual device on virtual input port 8",  0, MK_CK_CTRL_SHIFT(8) ),
        CKEYDEF( "device_select9",  "Select virtual device on virtual input port 9",  0, MK_CK_CTRL_SHIFT(9) ),
        CKEYDEF( "device_select10", "Select virtual device on virtual input port 10", 0, MK_CK_CTRL_SHIFT(0) ),
        CKEYDEF( "device_select11", "Select virtual device on virtual input port 11", 0, MK_CK_CTRL_SHIFT(KP_1) ),
        CKEYDEF( "device_select12", "Select virtual device on virtual input port 12", 0, MK_CK_CTRL_SHIFT(KP_2) ),
};
#undef CKEYDEF_BYPASSKEYZEROING
#undef CKEYDEF_DANGEROUS
#undef CKEYDEF_TEXTINPUTEXIT
#undef CKEYDEF

static std::vector<ButtConfig> CKeysConfig[_CK_COUNT];
static uint32 CKeysPressTime[_CK_COUNT];
static bool CKeysActive[_CK_COUNT];
static bool CKeysTrigger[_CK_COUNT];
static uint32 CurTicks = 0;	// Optimization, Time::MonoMS() might be slow on some platforms?

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
 CKeysActive[which] = DTestButtonCombo(CKeysConfig[which], (CKeys[which].BypassKeyZeroing && (!EmuKeyboardKeysGrabbed || which == CK_TOGGLE_GRAB)), CKeys[which].TextInputExit);
 CKeysTrigger[which] = false;
 CKeysPressTime[which] = 0xFFFFFFFF;
}

static void CK_ClearTriggers(void)
{
 memset(CKeysTrigger, 0, sizeof(CKeysTrigger));
}

static void CK_UpdateState(bool skipckd_tc)
{
 for(CommandKey i = _CK_FIRST; i < _CK_COUNT; i = (CommandKey)((unsigned)i + 1))
 {
  const bool prev_state = CKeysActive[i];
  const bool cur_state = DTestButtonCombo(CKeysConfig[i], (CKeys[i].BypassKeyZeroing && (!EmuKeyboardKeysGrabbed || i == CK_TOGGLE_GRAB)), CKeys[i].TextInputExit);
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
	Port9,
	Port10,
	Port11,
	Port12,
	Command,
	CommandAM
} ICType;

static ICType IConfig = none;
static int ICLatch;
static uint32 ICDeadDelay = 0;

//#include "InputConfigurator.inc"
//static InputConfigurator *IConfigurator = NULL;

// Can be called from MDFND_MidSync(), so be careful.
void Input_Event(const SDL_Event *event)
{
 switch(event->type)
 {
  case SDL_KEYDOWN:
  case SDL_KEYUP:
	KBMan::Event(event);
	break;

  case SDL_MOUSEBUTTONDOWN:
  case SDL_MOUSEBUTTONUP:
  case SDL_MOUSEMOTION:
  case SDL_MOUSEWHEEL:
	MouseMan::Event(event);
	break;
 }
}

/*
 Note: Don't call this function frivolously or any more than needed, or else the logic to prevent lost key and mouse button
 presses won't work properly in regards to emulated input devices(has particular significance with the "Pause" key and the emulated
 Saturn keyboard).
*/
static void UpdatePhysicalDeviceState(void)
{
 MouseMan::UpdateMice();
 KBMan::UpdateKeyboards();

 if(MDFNDHaveFocus || MDFN_GetSettingB("input.joystick.global_focus"))
  JoystickManager::UpdateJoysticks();

 CurTicks = Time::MonoMS();
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
   MDFN_Notify(MDFN_NOTICE_STATUS, _("%s enabled."), _(goodies));
  else
   MDFN_Notify(MDFN_NOTICE_STATUS, _("%s disabled."), _(goodies));
 }
}


// TODO: Remove this in the future when digit-string input devices are better abstracted.
static uint8 BarcodeWorldData[1 + 13];

static void DoKeyStateZeroing(void)
{
 EmuKeyboardKeysGrabbed = false;
 NPCheatDebugKeysGrabbed = false;

 if(IConfig == none)
 {
  if(Debugger_IsActive())
  {
   static const unsigned sc_um[] =
   {
    SDL_SCANCODE_F1, SDL_SCANCODE_F2, SDL_SCANCODE_F3, SDL_SCANCODE_F4, SDL_SCANCODE_F5, SDL_SCANCODE_F6, SDL_SCANCODE_F7, SDL_SCANCODE_F8,
    SDL_SCANCODE_F9, SDL_SCANCODE_F10, SDL_SCANCODE_F11, SDL_SCANCODE_F12, SDL_SCANCODE_F13, SDL_SCANCODE_F14, SDL_SCANCODE_F15, SDL_SCANCODE_F16,
    SDL_SCANCODE_F17, SDL_SCANCODE_F18, SDL_SCANCODE_F19, SDL_SCANCODE_F20, SDL_SCANCODE_F21, SDL_SCANCODE_F22, SDL_SCANCODE_F23, SDL_SCANCODE_F24
   };

   KBMan::MaskSysKBKeys();
   NPCheatDebugKeysGrabbed = true;
   KBMan::UnmaskSysKBKeys(sc_um, sizeof(sc_um) / sizeof(sc_um[0]));
  }
  else if(Netplay_IsTextInput() || CheatIF_Active())
  {
   // This effectively disables keyboard input, but still
   // allows physical joystick input when in the chat mode
   KBMan::MaskSysKBKeys();
   NPCheatDebugKeysGrabbed = true;
  }
  else if(InputGrab)
  {
   for(unsigned int x = 0; x < CurGame->PortInfo.size(); x++)
   {
    if(!(PIDC[x].Device->Flags & InputDeviceInfoStruct::FLAG_KEYBOARD))
     continue;

    for(auto& bic : PIDC[x].BIC)
    {
     for(auto& b : bic.BC)
     {
      if(b.DeviceType != BUTTC_KEYBOARD)
       continue;

      EmuKeyboardKeysGrabbed = true;

      KBMan::MaskSysKBKeys();
      goto IGrabEnd;
     }
    }
   }
   IGrabEnd:;
  }
 }
}

static void CheckCommandKeys(void)
{
  for(unsigned i = 0; i < 12; i++)
  {
   if(IConfig == Port1 + i)
   {
    if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
    {
     CK_PostRemapUpdate((CommandKey)(CK_INPUT_CONFIG1 + i));	// Kind of abusing that function if going by its name, but meh.

     ResyncGameInputSettings(i);
     CalcWMInputBehavior();
     IConfig = none;

     MDFN_Notify(MDFN_NOTICE_STATUS, _("Configuration interrupted."));
    }
    else if(ConfigDevice(i))
    {
     ResyncGameInputSettings(i);
     CalcWMInputBehavior();
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
    if(subcon(CKeys[ICLatch].text, CKeysConfig[ICLatch], true, IConfig == CommandAM))
    {
     MDFN_Notify(MDFN_NOTICE_STATUS, _("Configuration finished."));

     MDFNI_SetSetting(CKeys[ICLatch].setting_name, BCGToString(CKeysConfig[ICLatch]));
     ICDeadDelay = CurTicks + 300;
     IConfig = none;

     // Prevent accidentally triggering the command
     CK_PostRemapUpdate((CommandKey)ICLatch);
     CalcWMInputBehavior();
    }
   }
   else
   {
    MDFN_Notify(MDFN_NOTICE_STATUS, _("Press command key to remap now%s..."), (IConfig == CommandAM) ? _("(AND Mode)") : "");

    for(CommandKey x = _CK_FIRST; x < _CK_COUNT; x = (CommandKey)((unsigned)x + 1))
    {
     if(CK_Check((CommandKey)x))
     {
      ICLatch = x;
      subcon_begin();
      break;
     }
    }
   }
  }

  if(IConfig != none)
   return;

  if(CK_Check(CK_TOGGLE_GRAB))
  {
   InputGrab = !InputGrab;
   CalcWMInputBehavior();

   MDFN_Notify(MDFN_NOTICE_STATUS, _("Input grabbing: %s"), InputGrab ? _("On") : _("Off"));
  }

  if(!MDFNDnetplay && !Netplay_IsTextInput())
  {
   if(!CheatIF_Active())
   {
    if(CK_Check(CK_TOGGLE_DEBUGGER))
    {
     Debugger_GT_Toggle();
     CalcWMInputBehavior();
    }
   }

   if(!Debugger_IsActive() && !MDFNDnetplay)
   {
    if(CK_Check(CK_TOGGLECHEATVIEW))
    {
     CheatIF_GT_Show(!CheatIF_Active());
    }
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
    MDFN_Notify(MDFN_NOTICE_STATUS, _("Application of cheats enabled."));
   else
    MDFN_Notify(MDFN_NOTICE_STATUS, _("Application of cheats disabled."));
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
   if(CK_Check(CK_PAUSE))
   {
    if(IsInFrameAdvance())
     DoRunNormal();
    else
     DoFrameAdvance();
   }
   else
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
  }

  if(!Debugger_IsActive()) // We don't want to start button configuration when the debugger is active!
  {
   for(unsigned i = 0; i < 12; i++)
   {
    if(CK_Check((CommandKey)(CK_INPUT_CONFIG1 + i)))
    {
     if(i >= CurGame->PortInfo.size())
      MDFN_Notify(MDFN_NOTICE_STATUS, _("Port %u does not exist."), i + 1);
     else if(!PIDC[i].BIC.size())
     {
      MDFN_Notify(MDFN_NOTICE_STATUS, _("No buttons to configure on port %u device \"%s\"!"), i + 1, PIDC[i].Device->FullName);
     }
     else
     {
      //SetJoyReadMode(0);
      ConfigDeviceBegin();
      IConfig = (ICType)(Port1 + i);
     }
     break;
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
    MDFN_Notify(MDFN_NOTICE_STATUS, "%u joystick/gamepad analog button(s) detected.", JoystickManager::DetectAnalogButtonsForChangeCheck());
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
  }

  if(CK_CheckActive(CK_STATE_REWIND))
	DNeedRewind = true;
  else
	DNeedRewind = false;

  if(CK_Check(CK_STATE_REWIND_TOGGLE))
  {
   RewindState = !RewindState;
   MDFNI_EnableStateRewind(RewindState);

   MDFN_Notify(MDFN_NOTICE_STATUS, RewindState ? _("State rewinding functionality enabled.") : _("State rewinding functionality disabled."));
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
   for(int i = 0; i < 12; i++)
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

   if(!strcmp(CurGame->shortname, "nes") && (!strcmp(PIDC[4].Device->ShortName, "bworld") || (CurGame->cspecial && !MDFN_strazicmp(CurGame->cspecial, "datach"))))
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
      MDFN_Notify(MDFN_NOTICE_STATUS, _("Barcode Entered"));
     } 
     else { bbuft = 0; MDFN_Notify(MDFN_NOTICE_STATUS, _("Enter Barcode"));}
    }
   } 
   else 
    barcoder = 0;

   #define SSM(x) { if(bbuft < 13) {bbuf[bbuft++] = '0' + x; bbuf[bbuft] = 0;} MDFN_Notify(MDFN_NOTICE_STATUS, _("Barcode: %s"),bbuf); }

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

void Input_Update(bool VirtualDevicesOnly, bool UpdateRapidFire)
{
 static unsigned int rapid=0;

 UpdatePhysicalDeviceState();

 DoKeyStateZeroing();	// Call before CheckCommandKeys()

 //
 // CheckCommandKeys(), specifically MDFNI_LoadState(), should be called *before* we update the emulated device input data, as that data is 
 // stored/restored from save states(related: ALT+A frame advance, switch state).
 //
 CK_UpdateState((IConfig == Command || IConfig == CommandAM) && ICLatch == -1);
 if(!VirtualDevicesOnly)
 {
  CheckCommandKeys();
  CK_ClearTriggers();
 }

 if(UpdateRapidFire)
  rapid = (rapid + 1) % (autofirefreq + 1);

 // Do stuff here
 for(unsigned int x = 0; x < CurGame->PortInfo.size(); x++)
 {
  bool bypass_key_masking = false;

  if(!PIDC[x].Data)
   continue;

  if(PIDC[x].Device->Flags & InputDeviceInfoStruct::FLAG_KEYBOARD)
  {
   if(!InputGrab || NPCheatDebugKeysGrabbed)
    continue;
   else
    bypass_key_masking = true;
  }

  //
  // Handle rumble(FIXME: Do we want rumble to work in frame advance mode too?)
  //
  for(auto const& ric : PIDC[x].RIC)
  {
   const uint16 rumble_data = MDFN_de16lsb(PIDC[x].Data + ric.BitOffset / 8);
   const uint8 weak = (rumble_data >> 0) & 0xFF;
   const uint8 strong = (rumble_data >> 8) & 0xFF;

   JoystickManager::SetRumble(PIDC[x].BIC[ric.AssocBICIndex].BC, weak, strong);
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
  for(size_t bic_i = 0; bic_i < PIDC[x].BIC.size(); bic_i++)
  {
   auto& bic = PIDC[x].BIC[bic_i];
   uint8* tptr = PIDC[x].Data;
   const uint32 bo = bic.BitOffset;
   uint8* const btptr = &tptr[bo >> 3];

   switch(bic.IMType)
   {
    default:
	break;

    case IMTYPE_BUTTON:
	*btptr &= ~(1 << (bo & 7));
	*btptr |= DTestButton(bic.BC, bypass_key_masking) << (bo & 7);
	break;

    case IMTYPE_BUTTON_RAPID:
	*btptr |= (DTestButton(bic.BC, bypass_key_masking) & (rapid >= ((autofirefreq + 1) >> 1))) << (bo & 7);
	break;

    case IMTYPE_AXIS_NEG:
	break;

    case IMTYPE_AXIS_POS:
	//assert(PIDC[x].BIC[bic_i - 1].IMType == IMTYPE_AXIS_NEG);
	MDFN_en16lsb(btptr, DTestAxis(PIDC[x].BIC[bic_i - 1].BC, bic.BC, bypass_key_masking, PIDC[x].AxisScale));
	break;

    case IMTYPE_BUTTON_ANALOG:
	MDFN_en16lsb(btptr, DTestAnalogButton(bic.BC, bypass_key_masking) << 1);
	break;

    // Ordered before IMTYPE_AXIS_REL_POS
    case IMTYPE_AXIS_REL_NEG:
	break;

    // Ordered after IMPTYPE_AXIS_REL_NEG
    case IMTYPE_AXIS_REL_POS:
	//assert(PIDC[x].BIC[bic_i - 1].IMType == IMTYPE_AXIS_REL_NEG);
	bic.AxisRel.AccumError += (int64)DTestAxisRel(PIDC[x].BIC[bic_i - 1].BC, bic.BC, bypass_key_masking) * (int64)floor(0.5 + CurGame->mouse_sensitivity * (1 << 20));
	{
	 int32 tosend = bic.AxisRel.AccumError / ((int64)1 << 32);	// Division, not simple right arithmetic shift.
	 //printf("%lld, %d\n", tosend, bic.AxisRel.AccumError >> 32);
	 MDFN_en16lsb(btptr, std::max<int32>(-32768, std::min<int32>(32767, tosend)));	// don't assign result of min/max to tosend
	 bic.AxisRel.AccumError -= tosend * ((int64)1 << 32);
	}
	break;

    //
    // Mice axes aren't buttons!  Oh well...
    //
    case IMTYPE_POINTER_X:
    case IMTYPE_POINTER_Y:
	{
	 float tv = DTestPointer(bic.BC, bypass_key_masking, (bic.IMType == IMTYPE_POINTER_Y));

	 if(bic.IMType == IMTYPE_POINTER_Y)
	  tv = floor(0.5 + (tv * CurGame->mouse_scale_y) + CurGame->mouse_offs_y);
	 else
	  tv = floor(0.5 + (tv * CurGame->mouse_scale_x) + CurGame->mouse_offs_x);

	 //printf("msx: %f, msy: %f --- %f\n", CurGame->mouse_scale_x, CurGame->mouse_scale_y, tv);

	 MDFN_en16lsb(btptr, (int16)std::max<float>(-32768, std::min<float>(tv, 32767)));
	}
	break;

    case IMTYPE_SWITCH:
	{
	 const bool nps = DTestButton(bic.BC, bypass_key_masking);
	 uint8 cv = BitsExtract(tptr, bo, bic.Switch.BitSize);

	 if(MDFN_UNLIKELY(!bic.Switch.LastPress && nps))
	 {
	  cv = (cv + 1) % bic.Switch.NumPos;
	  BitsIntract(tptr, bo, bic.Switch.BitSize, cv);
	 }

	 if(MDFN_UNLIKELY(cv >= bic.Switch.NumPos))	// Can also be triggered intentionally by a bad save state/netplay.
	  fprintf(stderr, "[BUG] cv(%u) >= bic.Switch.NumPos(%u)\n", cv, bic.Switch.NumPos);
	 else if(MDFN_UNLIKELY(cv != bic.Switch.LastPos))
	 {
	  MDFN_Notify(MDFN_NOTICE_STATUS, _("%s %u: %s: %s selected."), PIDC[x].Device->FullName, x + 1, bic.IDII->Name, bic.IDII->Switch.Pos[cv].Name);
	  bic.Switch.LastPos = cv;
	 }

	 bic.Switch.LastPress = nps;
	}
	break;
   }
  }

  //
  // Handle button exclusion!
  //
  for(auto& bic : PIDC[x].BIC)
  {
   if(bic.ExclusionBitOffset != 0xFFFF)
   {
    const uint32 bo[2] = { bic.BitOffset, bic.ExclusionBitOffset };
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
    MDFN_Notify(MDFN_NOTICE_STATUS, _("%s %u: %s: %s"), PIDC[x].Device->FullName, x + 1, sic.IDII->Name, sic.IDII->Status.States[cv].Name);
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

    case IDIT_RESET_BUTTON:
	{
	 const uint32 bo = PIDC[x].Device->IDII[tmi].BitOffset;
	 uint8* const btptr = PIDC[x].Data + (bo >> 3);
	 const unsigned sob = bo & 0x7;

	 *btptr = (*btptr &~ (1U << sob)) | (CK_CheckActive(CK_RESET) << sob);
	}
	break;

    case IDIT_BYTE_SPECIAL:
	assert(tmi < 13 + 1);
	PIDC[x].Data[tmi] = BarcodeWorldData[tmi];
	break;
   }
  }
 }

 memset(BarcodeWorldData, 0, sizeof(BarcodeWorldData));
}

void Input_GameLoaded(MDFNGI *gi)
{
 autofirefreq = MDFN_GetSettingUI("autofirefreq");
 fftoggle_setting = MDFN_GetSettingB("fftoggle");
 sftoggle_setting = MDFN_GetSettingB("sftoggle");

 CK_Init();

 for(size_t p = 0; p < gi->PortInfo.size(); p++)
  BuildPortInfo(gi, p);

 // Load the command key mappings from settings
 for(int x = 0; x < _CK_COUNT; x++)
 {
  const char* const sname = CKeys[x].setting_name;

  if(!StringToBCG(&CKeysConfig[x], MDFN_GetSettingS(sname).c_str(), MDFNI_GetSettingDefault(sname).c_str()))
   abort();
 }
 //
 //
 CalcWMInputBehavior();
}

// Update setting strings with butt configs.
static void ResyncGameInputSettings(unsigned port)
{
 for(unsigned int x = 0; x < PIDC[port].BIC.size(); x++)
  MDFNI_SetSetting(PIDC[port].BIC[x].SettingName, BCGToString(PIDC[port].BIC[x].BC));
}


static std::vector<ButtConfig> subcon_bcg;
static ButtConfig subcon_bc;
static size_t subcon_tb;

static void subcon_begin(void)
{
 subcon_bcg.clear();

 memset(&subcon_bc, 0, sizeof(subcon_bc));
 subcon_tb = ~(size_t)0;
}

/* Configures an individual virtual button. */
static bool subcon(const char *text, std::vector<ButtConfig>& bcg, const bool commandkey, const bool AND_Mode)
{
 while(1)
 {
  MDFN_Notify(MDFN_NOTICE_STATUS, "%s (%zu)", text, subcon_bcg.size() + 1);

  if(subcon_tb != subcon_bcg.size())
  {
   JoystickManager::Reset_BC_ChangeCheck();
   MouseMan::Reset_BC_ChangeCheck();
   KBMan::Reset_BC_ChangeCheck(commandkey);
   subcon_tb = subcon_bcg.size();
  }

  if(!KBMan::Do_BC_ChangeCheck(&subcon_bc) && !MouseMan::Do_BC_ChangeCheck(&subcon_bc) && !JoystickManager::Do_BC_ChangeCheck(&subcon_bc))
   return false;
  //
  //
  if(subcon_bcg.size())
  {
   auto const& c = subcon_bc;
   auto const& p = subcon_bcg.back();

   if(c.DeviceType == p.DeviceType && c.DeviceNum == p.DeviceNum && c.ButtonNum == p.ButtonNum && c.DeviceID == p.DeviceID)
    break;
  }

  subcon_bc.ANDGroupCont = AND_Mode;
  subcon_bc.Scale = 4096;
  subcon_bcg.push_back(subcon_bc);
 }

 if(subcon_bcg.size())
  subcon_bcg.back().ANDGroupCont = false;

 bcg = subcon_bcg;

 return true;
}

static int cd_x;
static int cd_lx = -1;
static void ConfigDeviceBegin(void)
{
 cd_x = 0;
 cd_lx = -1;
}

static int ConfigDevice(int arg)
{
 char buf[512];

 //for(int i = 0; i < PIDC[arg].Buttons.size(); i++)
 // printf("%d\n", PIDC[arg].BCPrettyPrio[i]);
 //exit(1);

 for(;cd_x < (int)PIDC[arg].BCC.size(); cd_x++)
 {
  size_t snooty = PIDC[arg].BCC[cd_x];

  // For Lynx, GB, GBA, NGP, WonderSwan(especially wonderswan!)
  if(CurGame->PortInfo.size() == 1 && CurGame->PortInfo[0].DeviceInfo.size() == 1)
   trio_snprintf(buf, 512, "%s", PIDC[arg].BIC[snooty].CPName);
  else
   trio_snprintf(buf, 512, "%s %d: %s", PIDC[arg].Device->FullName, arg + 1, PIDC[arg].BIC[snooty].CPName);

  if(cd_x != cd_lx)
  {
   cd_lx = cd_x;
   subcon_begin();
  }
  if(!subcon(buf, PIDC[arg].BIC[snooty].BC, false, false))
   return(0);
 }

 MDFN_Notify(MDFN_NOTICE_STATUS, _("Configuration finished."));

 return(1);
}


struct DefaultSettingsMeow
{
 const char*const* bc;
 size_t count;
};

/*
static std::map<const char *, const DefaultSettingsMeow *, cstrcomp> DefaultButtonSettingsMap;
*/

static INLINE void MakeSettingsForDevice(std::vector <MDFNSetting> &settings, const MDFNGI *system, const int w, const InputDeviceInfoStruct *info, const DefaultSettingsMeow* defs)
{
 size_t def_butti = 0;
 bool analog_scale_made = false;
 for(size_t x = 0; x < info->IDII.size(); x++)
 {
  if(info->IDII[x].Type != IDIT_BUTTON && info->IDII[x].Type != IDIT_BUTTON_CAN_RAPID && info->IDII[x].Type != IDIT_BUTTON_ANALOG && info->IDII[x].Type != IDIT_AXIS &&
	info->IDII[x].Type != IDIT_POINTER_X && info->IDII[x].Type != IDIT_POINTER_Y && info->IDII[x].Type != IDIT_AXIS_REL &&
	info->IDII[x].Type != IDIT_SWITCH)
   continue;

  if(NULL == info->IDII[x].SettingName)
   continue;

  if(info->IDII[x].Type == IDIT_AXIS)
  {
   for(unsigned part = 0; part < 2; part++)
   {
    MDFNSetting tmp_setting;
    memset(&tmp_setting, 0, sizeof(tmp_setting));

    tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".", info->IDII[x].SettingName, info->IDII[x].SettingName[0] ? "_" : "", info->IDII[x].Axis.sname_dir[part]));
    tmp_setting.description = build_string(system->shortname, ", ", system->PortInfo[w].FullName, ", ", info->FullName, ": ", info->IDII[x].Name, info->IDII[x].Name[0] ? " " : "", info->IDII[x].Axis.name_dir[part]);
    tmp_setting.type = MDFNST_STRING;
    tmp_setting.default_value = "";
  
    tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
    tmp_setting.description_extra = NULL;
    tmp_setting.validate_func = ValidateIMSetting;
    settings.push_back(tmp_setting);
   }

   if((info->IDII[x].Flags & IDIT_AXIS_FLAG_SQLR) && !analog_scale_made)
   {
    MDFNSetting tmp_setting;
    memset(&tmp_setting, 0, sizeof(tmp_setting));

    tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".axis_scale"));
    tmp_setting.description = trio_aprintf(gettext_noop("Analog axis scale coefficient for %s on %s."), info->FullName, system->PortInfo[w].FullName);
    tmp_setting.description_extra = NULL;

    tmp_setting.type = MDFNST_FLOAT;
    tmp_setting.default_value = "1.00";
    tmp_setting.minimum = "1.00";
    tmp_setting.maximum = "1.50";

    settings.push_back(tmp_setting);
    analog_scale_made = true;
   }
  }
  else if(info->IDII[x].Type == IDIT_AXIS_REL)
  {
   for(unsigned part = 0; part < 2; part++)
   {
    const char *default_value = "";
    MDFNSetting tmp_setting;
    memset(&tmp_setting, 0, sizeof(tmp_setting));

    if(defs)
    {
     assert(def_butti < defs->count);
     default_value = defs->bc[def_butti];
    }

    tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".", info->IDII[x].SettingName, info->IDII[x].SettingName[0] ? "_" : "", info->IDII[x].AxisRel.sname_dir[part]));
    tmp_setting.description = build_string(system->shortname, ", ", system->PortInfo[w].FullName, ", ", info->FullName, ": ", info->IDII[x].Name, info->IDII[x].Name[0] ? " " : "", info->IDII[x].AxisRel.name_dir[part]);

    tmp_setting.type = MDFNST_STRING;
    tmp_setting.default_value = default_value;
  
    tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
    tmp_setting.description_extra = NULL;
    tmp_setting.validate_func = ValidateIMSetting;
    settings.push_back(tmp_setting);
    def_butti++;
   }
  }
  else
  {
   const char *default_value = "";
   MDFNSetting tmp_setting;

   memset(&tmp_setting, 0, sizeof(tmp_setting));

   if(defs)
   {
    assert(def_butti < defs->count);
    default_value = defs->bc[def_butti];
   }

   tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".", info->IDII[x].SettingName));
   tmp_setting.description = build_string(system->shortname, ", ", system->PortInfo[w].FullName, ", ", info->FullName, ": ", info->IDII[x].Name);

   tmp_setting.type = MDFNST_STRING;
   tmp_setting.default_value = default_value;
  
   tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
   tmp_setting.description_extra = NULL;
   tmp_setting.validate_func = ValidateIMSetting;
   settings.push_back(tmp_setting);
   def_butti++;
  }
  //printf("Maketset: %s %s\n", tmp_setting.name, tmp_setting.default_value);

  // Now make a rapid butt-on-stick-on-watermelon
  if(info->IDII[x].Type == IDIT_BUTTON_CAN_RAPID)
  {
   MDFNSetting tmp_setting;

   memset(&tmp_setting, 0, sizeof(tmp_setting));

   tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".rapid_", info->IDII[x].SettingName));
   tmp_setting.description = build_string(system->shortname, ", ", system->PortInfo[w].FullName, ", ", info->FullName, ": Rapid ", info->IDII[x].Name);
   tmp_setting.type = MDFNST_STRING;

   tmp_setting.default_value = "";

   tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
   tmp_setting.description_extra = NULL;
   tmp_setting.validate_func = ValidateIMSetting;

   settings.push_back(tmp_setting);
  }
  else if(info->IDII[x].Type == IDIT_SWITCH)
  {
   MDFNSetting tmp_setting;

   memset(&tmp_setting, 0, sizeof(tmp_setting));

   tmp_setting.name = CleanSettingName(build_string(system->shortname, ".input.", system->PortInfo[w].ShortName, ".", info->ShortName, ".", info->IDII[x].SettingName, ".defpos"));
   tmp_setting.description = trio_aprintf(gettext_noop("Default position for switch \"%s\"."), info->IDII[x].Name);
   tmp_setting.description_extra = gettext_noop("Sets the position for the switch to the value specified upon startup and virtual input device change.");

   tmp_setting.flags = (info->IDII[x].Flags & IDIT_FLAG_AUX_SETTINGS_UNDOC) ? MDFNSF_SUPPRESS_DOC : 0;
   {
    MDFNSetting_EnumList* el = (MDFNSetting_EnumList*)calloc(info->IDII[x].Switch.NumPos + 1, sizeof(MDFNSetting_EnumList));
    const uint32 snp = info->IDII[x].Switch.NumPos;

    for(uint32 i = 0; i < snp; i++)
    {
     el[i].string = info->IDII[x].Switch.Pos[i].SettingName;
     el[i].number = i;
     el[i].description = info->IDII[x].Switch.Pos[i].Name;
     el[i].description_extra = info->IDII[x].Switch.Pos[i].Description;
    }
    el[snp].string = NULL;
    el[snp].number = 0;
    el[snp].description = NULL;
    el[snp].description_extra = NULL;

    tmp_setting.enum_list = el;
    tmp_setting.type = MDFNST_ENUM;
    tmp_setting.default_value = el[0].string;
   }

   settings.push_back(tmp_setting);
  }
 }
 if(defs)
 {
  //printf("%s --- %zu, %zu\n", setting_def_search, def_butti, defs->count);
  assert(def_butti == defs->count);
 }
}

template<typename T>
static INLINE void MakeSettingsForPort(std::vector <MDFNSetting> &settings, const MDFNGI *system, const int w, const InputPortInfoStruct *info, const T& defset)
{
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

   EnumList[device].description_extra = NULL;
   if(info->DeviceInfo[device].Description || (info->DeviceInfo[device].Flags & InputDeviceInfoStruct::FLAG_KEYBOARD))
   {
    EnumList[device].description_extra = build_string(
	 info->DeviceInfo[device].Description ? info->DeviceInfo[device].Description : "",
	(info->DeviceInfo[device].Description && (info->DeviceInfo[device].Flags & InputDeviceInfoStruct::FLAG_KEYBOARD)) ? "\n" : "",
	(info->DeviceInfo[device].Flags & InputDeviceInfoStruct::FLAG_KEYBOARD) ? _("Emulated keyboard key state is not updated unless input grabbing(by default, mapped to CTRL+SHIFT+Menu) is toggled on; refer to the main documentation for details.") : "");
   }
  }

  tmp_setting.name = build_string(system->shortname, ".input.", info->ShortName);
  tmp_setting.description = trio_aprintf("Input device for %s", info->FullName);

  tmp_setting.type = MDFNST_ENUM;
  tmp_setting.default_value = info->DefaultDevice;

  assert(info->DefaultDevice);

  tmp_setting.flags = MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE;
  tmp_setting.description_extra = NULL;
  tmp_setting.enum_list = EnumList;

  settings.push_back(tmp_setting);
 }

 for(unsigned device = 0; device < info->DeviceInfo.size(); device++)
 {
  const DefaultSettingsMeow* defs = nullptr;
  char setting_def_search[256];
  trio_snprintf(setting_def_search, sizeof(setting_def_search), "%s.input.%s.%s", system->shortname, system->PortInfo[w].ShortName, info->DeviceInfo[device].ShortName);
  CleanSettingName(setting_def_search);

  {
   auto fit = defset.find(setting_def_search);
   if(fit != defset.end())
    defs = &fit->second;
  }

  MakeSettingsForDevice(settings, system, w, &info->DeviceInfo[device], defs);
 }
}

// Called on emulator startup
void Input_MakeSettings(std::vector <MDFNSetting> &settings)
{
 //uint64 st = Time::MonoUS();

 {
  #include "input-default-buttons.h"

  // First, build system settings
  for(unsigned int x = 0; x < MDFNSystems.size(); x++)
  {
   assert(MDFNSystems[x]->PortInfo.size() <= 16);

   for(unsigned port = 0; port < MDFNSystems[x]->PortInfo.size(); port++)
    MakeSettingsForPort(settings, MDFNSystems[x], port, &MDFNSystems[x]->PortInfo[port], defset);
  }
 }

 //printf("%llu\n", Time::MonoUS() - st);

 // Now build command key settings
 for(int x = 0; x < _CK_COUNT; x++)
 {
  MDFNSetting tmp_setting;

  memset(&tmp_setting, 0, sizeof(MDFNSetting));

  tmp_setting.name = CKeys[x].setting_name;

  tmp_setting.description = CKeys[x].description;
  tmp_setting.type = MDFNST_STRING;

  tmp_setting.flags = MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_INPUT_MAPPING;
  tmp_setting.description_extra = NULL;
  tmp_setting.validate_func = ValidateIMSetting;

  tmp_setting.default_value = CKeys[x].setting_default;
  settings.push_back(tmp_setting);
 }

#if 0
 for(auto const& sys : MDFNSystems)
 {
  for(auto const& port : sys->PortInfo)
  {
   for(auto const& dev : port.DeviceInfo)
   {
    fprintf(stderr, "Input size: %u (%s)\n", (unsigned)dev.IDII.InputByteSize, dev.FullName);
    for(auto const& idii : dev.IDII)
    {
     if(idii.Type == IDIT_BUTTON || idii.Type == IDIT_BUTTON_CAN_RAPID)
      fprintf(stderr, "%s %s(%s) %s(%s) %s(%s): %u %u %s %u --- co=%d\n", sys->shortname, port.ShortName, port.FullName, dev.ShortName, dev.FullName, idii.SettingName, idii.Name, idii.BitSize, idii.BitOffset, (idii.Type == IDIT_BUTTON && idii.Button.ExcludeName) ? idii.Button.ExcludeName : "", idii.Flags, idii.ConfigOrder);
    }
   }
  }
 }
#endif
}

void Input_GameClosed(void)
{
 for(size_t p = 0; p < CurGame->PortInfo.size(); p++)
  KillPortInfo(p);
 //
 CalcWMInputBehavior();
}

// TODO: multiple mice support
static void CalcWMInputBehavior_Sub(const InputMappingType IMType, const ButtConfig& bc, bool* CursorNeeded, bool* MouseAbsNeeded, bool* MouseRelNeeded)
{
 const bool is_mouse_mapping = (bc.DeviceType == BUTTC_MOUSE);
 const bool is_mouse_cursor_mapping = is_mouse_mapping && ((bc.ButtonNum & MouseMan::MOUSE_BN_TYPE_MASK) == MouseMan::MOUSE_BN_TYPE_CURSOR);
 const bool is_mouse_rel_mapping = is_mouse_mapping && ((bc.ButtonNum & MouseMan::MOUSE_BN_TYPE_MASK) == MouseMan::MOUSE_BN_TYPE_REL);

 if(is_mouse_cursor_mapping)
 {
  *MouseAbsNeeded = true;
  if(IMType != IMTYPE_POINTER_X && IMType != IMTYPE_POINTER_Y)
   *CursorNeeded = true;
 }

 if(is_mouse_rel_mapping)
  *MouseRelNeeded = true;
}

static void CalcWMInputBehavior(void)
{
 const uint32 lpm = Netplay_GetLPM();
 bool CursorNeeded = false;
 bool MouseAbsNeeded = false;
 bool MouseRelNeeded = false;
 bool GrabNeeded = InputGrab;

 for(size_t p = 0; p < (CurGame ? CurGame->PortInfo.size() : 0); p++)
 {
  if(!(lpm & (1U << p)))
   continue;

  //
  auto const& pic = PIDC[p];
  for(auto const& bic : pic.BIC)
  {
   for(auto const& bc : bic.BC)
   {
    CalcWMInputBehavior_Sub(bic.IMType, bc, &CursorNeeded, &MouseAbsNeeded, &MouseRelNeeded);
   }
  }
 }

 for(int x = 0; x < _CK_COUNT; x++)
 {
  for(auto const& bc : CKeysConfig[x])
  {
   CalcWMInputBehavior_Sub(IMTYPE_BUTTON, bc, &CursorNeeded, &MouseAbsNeeded, &MouseRelNeeded);
  }
 }

 if(Debugger_IsActive())
 {
  MouseAbsNeeded = true;
  CursorNeeded = true;
 }
 //
 //
 //
 GT_SetWMInputBehavior(CursorNeeded, MouseAbsNeeded, MouseRelNeeded, GrabNeeded);
}

void Input_NetplayLPMChanged(void)
{
 CalcWMInputBehavior();
}

