#pragma once
#include <linux/input.h>
#include "types.h"

struct EvdevControllerMapping
{
	const string name;
	const int Btn_A;
	const int Btn_B;
	const int Btn_C;
	const int Btn_D;
	const int Btn_X;
	const int Btn_Y;
	const int Btn_Z;
	const int Btn_Start;
	const int Btn_Escape;
	const int Btn_DPad_Left;
	const int Btn_DPad_Right;
	const int Btn_DPad_Up;
	const int Btn_DPad_Down;
	const int Btn_DPad2_Left;
	const int Btn_DPad2_Right;
	const int Btn_DPad2_Up;
	const int Btn_DPad2_Down;
	const int Btn_Trigger_Left;
	const int Btn_Trigger_Right;
	const int Axis_DPad_X;
	const int Axis_DPad_Y;
	const int Axis_DPad2_X;
	const int Axis_DPad2_Y;
	const int Axis_Analog_X;
	const int Axis_Analog_Y;
	const int Axis_Trigger_Left;
	const int Axis_Trigger_Right;
	const bool Axis_Analog_X_Inverted;
	const bool Axis_Analog_Y_Inverted;
	const bool Axis_Trigger_Left_Inverted;
	const bool Axis_Trigger_Right_Inverted;
	const int Maple_Device1;
	const int Maple_Device2;
};

struct EvdevAxisData
{
	s32 range; // smaller size than 32 bit might cause integer overflows
	s32 min;
	void init(int fd, int code, bool inverted);
	s8 convert(int value);
};

struct EvdevController
{
	int fd;
	EvdevControllerMapping* mapping;
	EvdevAxisData data_x;
	EvdevAxisData data_y;
	EvdevAxisData data_trigger_left;
	EvdevAxisData data_trigger_right;
	int rumble_effect_id;
	void init();
};

#define EVDEV_DEVICE_CONFIG_KEY "evdev_device_id_%d"
#define EVDEV_MAPPING_CONFIG_KEY "evdev_mapping_%d"
#define EVDEV_DEVICE_STRING "/dev/input/event%d"
#define EVDEV_MAPPING_PATH "/mappings/%s"

#ifdef TARGET_PANDORA
	#define EVDEV_DEFAULT_DEVICE_ID_1 4
#else
	#define EVDEV_DEFAULT_DEVICE_ID_1 0
#endif

#define EVDEV_DEFAULT_DEVICE_ID(port) (port == 1 ? EVDEV_DEFAULT_DEVICE_ID_1 : -1)

extern void input_evdev_init();
extern void input_evdev_close();
extern bool input_evdev_handle(u32 port);
extern void input_evdev_rumble(u32 port, u16 pow_strong, u16 pow_weak);
