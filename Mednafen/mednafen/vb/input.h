#ifndef __VB_INPUT_H
#define __VB_INPUT_H

namespace MDFN_IEN_VB
{

void VBINPUT_Init(void);
void VBINPUT_SetInstantReadHack(bool);

void VBINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);

uint8 VBINPUT_Read(v810_timestamp_t &timestamp, uint32 A);

void VBINPUT_Write(v810_timestamp_t &timestamp, uint32 A, uint8 V);

void VBINPUT_Frame(void);
void VBINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only);

int32 VBINPUT_Update(const int32 timestamp);
void VBINPUT_ResetTS(void);


void VBINPUT_Power(void);


int VBINPUT_StateAction(StateMem *sm, int load, int data_only);

}
#endif
