#ifndef RDP_H
#define RDP_H

#define MAXCMD 0x100000
const unsigned int maxCMDMask = MAXCMD - 1;

typedef struct
{
	u32 w0, w1, w2, w3;
	u32 cmd_ptr;
	u32 cmd_cur;
	u32 cmd_data[MAXCMD + 32];
} RDPInfo;

extern RDPInfo RDP;

void RDP_Init();
void RDP_Half_1(u32 _c);
void RDP_TexRect(u32 w0, u32 w1);
void RDP_ProcessRDPList();
void RDP_RepeatLastLoadBlock();
void RDP_SetScissor(u32 w0, u32 w1);
void RDP_SetTImg(u32 w0, u32 w1);
void RDP_LoadBlock(u32 w0, u32 w1);
void RDP_SetTile(u32 w0, u32 w1);
void RDP_SetTileSize(u32 w0, u32 w1);

#endif

