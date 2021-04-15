#ifndef __WSWAN_GFX_H
#define __WSWAN_GFX_H

namespace MDFN_IEN_WSWAN
{


void WSWan_TCacheInvalidByAddr(uint32);

MDFN_HIDE extern uint8	wsTCache[512*64];		  //tiles cache
MDFN_HIDE extern uint8	wsTCacheFlipped[512*64];  	  //tiles cache (H flip)
MDFN_HIDE extern uint8	wsTileRow[8];		  //extracted 8 pixels (tile row)
MDFN_HIDE extern uint8	wsTCacheUpdate[512];	  //tiles cache flags
MDFN_HIDE extern uint8	wsTCache2[512*64];		  //tiles cache
MDFN_HIDE extern uint8	wsTCacheFlipped2[512*64];  	  //tiles cache (H flip)
MDFN_HIDE extern uint8	wsTCacheUpdate2[512];	  //tiles cache flags
MDFN_HIDE extern int	wsVMode;			  //Video Mode	

void wsMakeTiles(void);
void wsGetTile(uint32,uint32,int,int,int);
void wsSetVideo(int, bool);

MDFN_HIDE extern uint32	dx_r,dx_g,dx_b,dx_sr,dx_sg,dx_sb;
MDFN_HIDE extern uint32	dx_bits,dx_pitch,cmov,dx_linewidth_blit,dx_buffer_line;


void WSwan_SetPixelFormat(const MDFN_PixelFormat &format);

void WSwan_GfxInit(void) MDFN_COLD;
void WSwan_GfxReset(void);
void WSwan_GfxWrite(uint32 A, uint8 V);
uint8 WSwan_GfxRead(uint32 A);
void WSwan_GfxWSCPaletteRAMWrite(uint32 ws_offset, uint8 data);

bool wsExecuteLine(MDFN_Surface *surface, bool skip);

void WSwan_SetLayerEnableMask(uint64 mask);
void WSwan_GfxStateAction(StateMem *sm, const unsigned load, const bool data_only);

#ifdef WANT_DEBUGGER
void WSwan_GfxSetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn);
#endif

}

#endif
