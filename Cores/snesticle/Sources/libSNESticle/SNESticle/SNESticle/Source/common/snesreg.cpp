

#include "types.h"
#include "snesreg.h"


void SnesReg16FT::Write8(Uint8 uData)
{
	if (!bFlip)
	{
		Reg.b.l = uData;
		bFlip = 1;
	} else
	{
		Reg.b.h = uData;
		bFlip = 0;
	}
}


Uint8 SnesReg16FT::Read8()
{
	if (!bFlip)
	{
		bFlip = 1;
		return Reg.b.l;
	} else
	{
		bFlip = 0;
		return Reg.b.h;
	}
}




void SnesReg16FT::Reset()
{
	bFlip = 0;
}




