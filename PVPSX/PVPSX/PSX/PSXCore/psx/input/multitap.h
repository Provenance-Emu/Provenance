#ifndef __MDFN_PSX_INPUT_MULTITAP_H
#define __MDFN_PSX_INPUT_MULTITAP_H

namespace MDFN_IEN_PSX
{

class InputDevice_Multitap : public InputDevice
{
 public:

 InputDevice_Multitap();
 virtual ~InputDevice_Multitap();
 virtual void Power(void);
 virtual int StateAction(StateMem* sm, int load, int data_only, const char* section_name);

 void SetSubDevice(unsigned int sub_index, InputDevice *device, InputDevice *mc_device);

 //
 //
 //
 virtual void SetDTR(bool new_dtr);
 virtual bool GetDSR(void);
 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay);

 private:

 InputDevice *pad_devices[4];
 InputDevice *mc_devices[4];

 bool dtr;

 int selected_device;
 bool full_mode_setting;

 bool full_mode;
 bool mc_mode;

 uint8 fm_dp;	// Device-present.
 uint8 fm_buffer[4][8];

 bool fm_deferred_error_temp;
 bool fm_deferred_error;
 bool fm_command_error;

 uint8 command;
 uint8 receive_buffer;
 uint8 bit_counter;
 uint8 byte_counter;
};

}

#endif
