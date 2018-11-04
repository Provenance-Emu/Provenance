#pragma once
#include "types.h"

void asic_RaiseInterrupt(HollyInterruptID inter);
void asic_CancelInterrupt(HollyInterruptID inter);

//Init/Res/Term for regs
void asic_reg_Init();
void asic_reg_Term();
void asic_reg_Reset(bool Manual);
