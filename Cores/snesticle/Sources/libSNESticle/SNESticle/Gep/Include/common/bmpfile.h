

#ifndef _BMPFILE_H
#define _BMPFILE_H

class CSurface;
struct PaletteT;

Bool BMPWriteFile(Char *pFileName, CSurface *pSurface, PaletteT *pPalette);
Bool BMPReadFile(Char *pFileName, CSurface *pSurface);


#endif
