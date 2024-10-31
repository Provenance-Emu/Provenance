#ifndef __MDFN_NES_VSUNI_H
#define __MDFN_NES_VSUNI_H

namespace MDFN_IEN_NES
{

void MDFN_VSUniPower(void) MDFN_COLD;
void MDFN_VSUniCheck(uint64 md5partial, int *, int *) MDFN_COLD;
void MDFN_VSUniDraw(MDFN_Surface *surface);

void MDFN_VSUniToggleDIPView(void);
void MDFN_VSUniToggleDIP(int);	/* For movies and netplay */
void MDFN_VSUniCoin(void);
void MDFN_VSUniSwap(uint8 *j0, uint8 *j1);

void MDFNNES_VSUNIStateAction(StateMem *sm, const unsigned load, const bool data_only);

void MDFN_VSUniInstallRWHooks(void);

unsigned int MDFN_VSUniGetPaletteNum(void);

}

#endif
