
#ifndef _SNESREG_H
#define _SNESREG_H

typedef Uint8 SnesReg8T;
typedef Uint32 SnesReg32T;

// ppu register types
union SnesReg16T
{
	Uint16	w;
	struct
	{
		Uint8 l,h;
	} b;

	// write (lo then hi byte)
	void Write8LoHi(Uint8 uData)
	{
		w = (w>>8) | (uData<<8);
	}

	// write (hi then lo byte)
	void Write8HiLo(Uint8 uData)
	{
		w = (w<<8) | (uData&0xFF);
	}
};

struct SnesReg16FT
{
	SnesReg16T	Reg;
	Bool			bFlip;

	void Write8(Uint8 uData);
	Uint8 Read8();
	void Reset();
};

#endif
