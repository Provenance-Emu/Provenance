#pragma once
#include "types.h"
#include "maple_devs.h"

enum PlainJoystickButtonId
{
	PJBI_B = 1,
	PJBI_A = 2,
	PJBI_START = 3,
	PJBI_DPAD_UP = 4,
	PJBI_DPAD_DOWN = 5,
	PJBI_DPAD_LEFT = 6,
	PJBI_DPAD_RIGHT = 7,
	PJBI_Y = 9,
	PJBI_X = 10,

	PJBI_Count=16
};

enum PlainJoystickAxisId
{
	PJAI_X1 = 0,
	PJAI_Y1 = 1,
	PJAI_X2 = 2,
	PJAI_Y2 = 3,

	PJAI_Count = 4
};

enum PlainJoystickTriggerId
{
	PJTI_L = 0,
	PJTI_R = 1,

	PJTI_Count = 2
};

struct PlainJoystickState
{
	PlainJoystickState()
	{
		kcode=0xFFFF;
		joy[0]=joy[1]=joy[2]=joy[3]=0x80;
		trigger[0]=trigger[1]=0;
	}
	static const u32 ButtonMask = PJBI_B | PJBI_A | PJBI_START | PJBI_DPAD_UP |
	                              PJBI_DPAD_DOWN | PJBI_DPAD_LEFT | PJBI_DPAD_RIGHT | PJBI_Y | PJBI_X;

	static const u32 AxisMask = PJAI_X1 | PJAI_Y1;

	static const u32 TriggerMask = PJTI_L | PJTI_R;

	u32 kcode;

	u8 joy[PJAI_Count];
	u8 trigger[PJTI_Count];
};

struct IMapleConfigMap
{
	virtual void SetVibration(u32 value) = 0;
	virtual void GetInput(PlainJoystickState* pjs)=0;
	virtual void SetImage(void* img)=0;
	virtual ~IMapleConfigMap() {}
};

#if DC_PLATFORM == DC_PLATFORM_DREAMCAST
void mcfg_CreateDevicesFromConfig();
void mcfg_CreateController(u32 bus, MapleDeviceType maple_type1, MapleDeviceType maple_type2);
#else
void mcfg_CreateNAOMIJamma();
#endif

void mcfg_DestroyDevices();
