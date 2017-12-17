#ifndef _PPU_PALETTEH
#define _PPU_PALETTEH

namespace MDFN_IEN_NES
{

typedef struct {
        uint8 r,g,b;
} MDFNPalStruct;

extern MDFNPalStruct ActiveNESPalette[0x200];

extern const CustomPalette_Spec NES_CPInfo[];

void MDFN_InitPalette(const unsigned int which, const uint8* custom_palette, const unsigned cp_numentries);

}

#endif
