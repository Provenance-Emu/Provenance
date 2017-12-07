#ifndef __MDFN_DRIVERS_JOYSTICK_XINPUT_H
#define __MDFN_DRIVERS_JOYSTICK_XINPUT_H
// Returns NULL if XInput is not available, or if no attached XInput controllers were found.
JoystickDriver *JoystickDriver_XInput_New(void);
#endif
