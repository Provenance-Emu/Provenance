#ifndef __PCE_INPUT_H
#define __PCE_INPUT_H

namespace MDFN_IEN_PCE_FAST
{

void PCEINPUT_Init(void) MDFN_COLD;
void PCEINPUT_SettingChanged(const char *name);
void PCEINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);
uint8 INPUT_Read(unsigned int A);
void INPUT_Write(unsigned int A, uint8 V);
void INPUT_Frame(void);
void INPUT_TransformInput(void);
void INPUT_StateAction(StateMem *sm, int load, int data_only);
MDFN_HIDE extern const std::vector<InputPortInfoStruct> PCEPortInfo;
void INPUT_FixTS(void);

};

#endif
