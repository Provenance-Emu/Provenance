/*
  _____     ___ ____
   ____|   |    ____|      PS2LIB OpenSource Project
  |     ___|   |____       (C)2002, Pukko 
  ------------------------------------------------------------------------
  pad.h
                           Pad externals 
                           rev 1.2 (20020113)
*/

#ifndef _XMTAP_H_
#define _XMTAP_H_

#ifdef __cplusplus
extern "C" {
#endif

int xmtapInit(int a);
int xmtapPortOpen(int port, int slot);
int xmtapPortClose(int port, int slot);

#ifdef __cplusplus
}
#endif

#endif



