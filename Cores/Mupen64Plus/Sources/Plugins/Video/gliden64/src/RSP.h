#ifndef RSP_H
#define RSP_H

#include "Types.h"
#include "N64.h"

typedef struct
{
	u32 PC[18], PCi;
	u32 F5DL[10];
	u32 uc_start, uc_dstart, cmd, nextCmd;
	u32 w0, w1;
	s32 count;
	bool busy, halt, infloop;
	bool LLE;
	char romname[21];
	wchar_t pluginpath[PLUGIN_PATH_SIZE];
} RSPInfo;

extern RSPInfo RSP;

extern u32 DepthClearColor;
extern u32 rectDepthBufferCopyFrame;

#define RSP_SegmentToPhysical( segaddr ) ((gSP.segment[(segaddr >> 24) & 0x0F] + (segaddr & RDRAMSize)) & RDRAMSize)

void RSP_Init();
void RSP_ProcessDList();
void RSP_LoadMatrix( f32 mtx[4][4], u32 address );
void RSP_CheckDLCounter();

#endif
