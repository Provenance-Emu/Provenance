#pragma once
#include "drkPvr.h"

bool spg_Init();
void spg_Term();
void spg_Reset(bool Manual);

//#define Frame_Cycles (DCclock/60)

//need to replace 511 with correct value
//#define Line_Cycles (Frame_Cycles/511)

void spgUpdatePvr(u32 cycles);
bool spg_Init();
void spg_Term();
void spg_Reset(bool Manual);
void CalculateSync();