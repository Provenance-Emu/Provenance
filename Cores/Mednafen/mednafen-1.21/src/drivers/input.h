#ifndef __MDFN_DRIVERS_INPUT_H
#define __MDFN_DRIVERS_INPUT_H

enum : uint8
{
 BUTTC_NONE 	= 0,	// Must be zero.
 BUTTC_KEYBOARD,
 BUTTC_JOYSTICK,
 BUTTC_MOUSE
};

struct ButtConfig
{
 uint8 DeviceType;
 uint8 DeviceNum;
 int8 ANDGroupCont;
 uint16 ButtonNum;
 uint16 Scale;
 std::array<uint8, 16> DeviceID;
};

void Input_Event(const SDL_Event* event);

void Input_GameLoaded(MDFNGI* gi) MDFN_COLD;
void Input_GameClosed(void) MDFN_COLD;

void Input_Update(bool VirtualDevicesOnly = false, bool UpdateRapidFire = true);

void Input_MakeSettings(std::vector <MDFNSetting> &settings);

void Input_NetplayLPMChanged(void);

extern bool DNeedRewind; // Only read/write in game thread(or before creating game thread).
extern bool RewindState; // " " " "

#endif
