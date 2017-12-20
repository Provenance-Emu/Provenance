#ifndef __MDFN_SNES_FAUST_INPUT_H
#define __MDFN_SNES_FAUST_INPUT_H

namespace MDFN_IEN_SNES_FAUST
{
 void INPUT_Init(void);
 void INPUT_Kill(void);
 void INPUT_Reset(bool powering_up);
 void INPUT_StateAction(StateMem* sm, const unsigned load, const bool data_only);
 void INPUT_Set(unsigned port, const char* type, uint8* ptr);
 void INPUT_UpdatePhysicalState(void);


 void INPUT_AutoRead(void);

 extern const std::vector<InputPortInfoStruct> INPUT_PortInfo;
}

#endif
