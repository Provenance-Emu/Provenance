#pragma once
#include "types.h"
#include "types.h"
#include "maple_devs.h"

extern maple_device* MapleDevices[4][6];

void maple_Init();
void maple_Reset(bool Manual);
void maple_Term();

void maple_vblank();