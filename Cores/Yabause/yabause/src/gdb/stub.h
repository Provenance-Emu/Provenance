#ifndef GDB_STUB_H
#define GDB_STUB_H

#include "../sh2core.h"

int GdbStubInit(SH2_struct * context, int port);
int GdbStubDeInit();

#endif
