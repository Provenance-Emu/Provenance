#include "types.h"
#include "linux-dist/main.h"

#pragma once
#define JOYSTICK_DEVICE_STRING "/dev/input/js%d"
#define JOYSTICK_DEFAULT_DEVICE_ID -1
#define JOYSTICK_MAP_SIZE 32

extern int input_joystick_init(const char* device);
extern bool input_joystick_handle(int fd, u32 port);
