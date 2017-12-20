#ifndef __PCFX_RAINBOW_H
#define __PCFX_RAINBOW_H

void RAINBOW_Write8(uint32 A, uint8 V);
void RAINBOW_Write16(uint32 A, uint16 V);

void RAINBOW_ForceTransferReset(void);
void RAINBOW_SwapBuffers(void);
void RAINBOW_DecodeBlock(bool arg_FirstDecode, bool Skip);

int RAINBOW_FetchRaster(uint32 *, uint32 layer_or, uint32 *palette_ptr);
void RAINBOW_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void RAINBOW_Init(bool arg_ChromaIP);
void RAINBOW_Close(void);
void RAINBOW_Reset(void);

#ifdef WANT_DEBUGGER
enum
{
 RAINBOW_GSREG_RSCRLL,
 RAINBOW_GSREG_RCTRL,
 RAINBOW_GSREG_RNRY,
 RAINBOW_GSREG_RNRU,
 RAINBOW_GSREG_RNRV,
 RAINBOW_GSREG_RHSYNC,
};
uint32 RAINBOW_GetRegister(const unsigned int id, char* special, const uint32 special_len);
void RAINBOW_SetRegister(const unsigned int id, uint32 value);
#endif

#endif
