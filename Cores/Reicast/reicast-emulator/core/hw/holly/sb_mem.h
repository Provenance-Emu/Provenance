#pragma once
#include "types.h"

void map_area0_init();
void map_area0(u32 base);

//Init/Res/Term
void sh4_area0_Init();
void sh4_area0_Reset(bool Manual);
void sh4_area0_Term();