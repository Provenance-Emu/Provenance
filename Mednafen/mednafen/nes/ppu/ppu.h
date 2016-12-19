#ifndef __MDFN_NES_PPU_H
#define __MDFN_NES_PPU_H

namespace MDFN_IEN_NES
{
void MDFNPPU_Init(void) MDFN_COLD;
void MDFNPPU_Close(void) MDFN_COLD;
void MDFNPPU_Reset(void) MDFN_COLD;
void MDFNPPU_Power(void) MDFN_COLD;
int MDFNPPU_Loop(EmulateSpecStruct *espec);

void MDFNPPU_LineUpdate();

void NESPPU_GetDisplayRect(MDFN_Rect *DisplayRect);


extern void (*PPU_hook)(uint32 A);
extern void (*GameHBIRQHook)(void), (*GameHBIRQHook2)(void);

/* For cart.c and banksw.h, mostly */
extern uint8 NTARAM[0x800],*vnapage[4];
extern uint8 PPUNTARAM;
extern uint8 PPUCHRRAM;

extern int scanline;

void MDFNNES_SetPixelFormat(const MDFN_PixelFormat &nf) MDFN_COLD;
void MDFNPPU_StateAction(StateMem *sm, const unsigned load, const bool data_only);
void MDFNNES_SetLayerEnableMask(uint64 mask);

enum
{
 PPU_GSREG_PPU0 = 0,
 PPU_GSREG_PPU1,
 PPU_GSREG_PPU2,
 PPU_GSREG_PPU3,
 PPU_GSREG_XOFFSET,
 PPU_GSREG_RADDR,
 PPU_GSREG_TADDR,
 PPU_GSREG_VRAMBUF,
 PPU_GSREG_VTOGGLE,
 PPU_GSREG_SCANLINE
};

uint32 NESPPU_GetRegister(const unsigned int id, char *special, const uint32 special_len) MDFN_COLD;
void NESPPU_SetRegister(const unsigned int id, uint32 value) MDFN_COLD;


void NESPPU_SetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn) MDFN_COLD;
void NESPPU_SettingChanged(const char *name) MDFN_COLD;

void NESPPU_GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer) MDFN_COLD;
void NESPPU_PutAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint32 Granularity, bool hl, const uint8 *Buffer) MDFN_COLD;
}
#endif
