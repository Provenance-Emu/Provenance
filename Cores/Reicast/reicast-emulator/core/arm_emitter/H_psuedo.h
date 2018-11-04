/*
 *	H_psuedo.h
 *
 */

#pragma once

namespace ARM
{

	EAPI MOV32(eReg Rd, u32 Imm32, ConditionCode CC=AL)
	{
		MOVW(Rd,((Imm32)&0xFFFF),CC);
		if (Imm32>>16)
			MOVT(Rd,((Imm32>>16)&0xFFFF),CC);
	}
#if 0
	EAPI NEG(eReg Rd,eReg Rs)
	{
		RSB(Rd,Rs,0);
	}
#endif
	EAPI NOT(eReg Rd,eReg Rs)
	{
		MVN(Rd,Rs);
	}


}