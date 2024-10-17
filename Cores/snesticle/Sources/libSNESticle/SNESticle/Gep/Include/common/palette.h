

#ifndef _PALETTE_H
#define _PALETTE_H

struct Color32T
{
	Uint8 r,g,b,a;
};

struct PaletteT
{
	union
	{
		Uint8		Color8[256];
		Uint16		Color16[256];
		Uint32		Color32[256];
		Color32T	Color[256];
	};
};

#endif
