#ifndef __MDFN_PCE_INPUT_H
#define __MDFN_PCE_INPUT_H

namespace MDFN_IEN_PCE
{

class PCE_Input_Device
{
 public:
// PCE_Input_Device(int which);	// "which" is advisory and only should be used in status messages.
 virtual ~PCE_Input_Device();
 virtual void TransformInput(uint8* data, const bool DisableSR);
 virtual void AdjustTS(int32 delta);
 virtual void Write(int32 timestamp, bool old_SEL, bool new_SEL, bool old_CLR, bool new_CLR);
 virtual uint8 Read(int32 timestamp);
 virtual void Power(int32 timestamp);
 virtual void Update(const uint8* data);
 virtual int StateAction(StateMem *sm, int load, int data_only, const char *section_name);
};

void PCEINPUT_Power(int32 timestamp);
void PCEINPUT_Init(void) MDFN_COLD;
void PCEINPUT_SettingChanged(const char *name);
void PCEINPUT_TransformInput(void);
void PCEINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);
uint8 INPUT_Read(int32 timestamp, unsigned int A);
void INPUT_Write(int32 timestamp, unsigned int A, uint8 V);
void INPUT_Frame(void);
int INPUT_StateAction(StateMem *sm, int load, int data_only);
extern const std::vector<InputPortInfoStruct> PCEPortInfo;
void INPUT_AdjustTS(int32 delta_timestamp);

uint16 INPUT_HESHack(void);

};

#endif
