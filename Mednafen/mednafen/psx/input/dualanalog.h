#ifndef __MDFN_PSX_INPUT_DUALANALOG_H
#define __MDFN_PSX_INPUT_DUALANALOG_H

namespace MDFN_IEN_PSX
{

InputDevice *Device_DualAnalog_Create(bool joystick_mode);
extern IDIISG Device_DualAnalog_IDII;
extern IDIISG Device_AnalogJoy_IDII;
}
#endif
