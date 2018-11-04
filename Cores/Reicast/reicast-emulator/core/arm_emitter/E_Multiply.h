/*
 *	E_Multiply.h
 *
 */
#pragma once



namespace ARM
{
	
	EAPI MLA(eReg Rd, eReg Rn, eReg Rs, eReg Rm, ConditionCode CC=AL)   //     *FIXME* S
	{
		DECL_Id(0x00200090);

		SET_CC;
		I |= (Rd&15)<<16;
		I |= (Rn&15)<<12;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI MUL(eReg Rd, eReg Rs, eReg Rm, ConditionCode CC=AL)   //     *FIXME* S
	{
		DECL_Id(0x00000090);

		SET_CC;
		I |= (Rd&15)<<16;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UMULL(eReg Rdhi, eReg Rdlo, eReg Rs, eReg Rm, ConditionCode CC=AL)   //     *FIXME* S
	{
		DECL_Id(0x00800090);
		
		SET_CC;
		I |= (Rdhi&15)<<16;
		I |= (Rdlo&15)<<12;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}
	
	EAPI SMULL(eReg Rdhi, eReg Rdlo, eReg Rs, eReg Rm, ConditionCode CC=AL)   //     *FIXME* S
	{
		DECL_Id(0x00C00090);
		
		SET_CC;
		I |= (Rdhi&15)<<16;
		I |= (Rdlo&15)<<12;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}
	
	



	
#if 0
SMLA<x><y>	Signed halfword Multiply Accumulate.
SMLAD		Signed halfword Multiply Accumulate, Dual.
SMLAL		Signed Multiply Accumulate Long.
SMLAL<x><y>	Signed halfword Multiply Accumulate Long.
SMLALD		Signed halfword Multiply Accumulate Long, Dual.
SMLAW<y>	Signed halfword by word Multiply Accumulate.
SMLSD		Signed halfword Multiply Subtract, Dual.
SMLSLD		Signed halfword Multiply Subtract Long Dual.
SMMLA		Signed Most significant word Multiply Accumulate.
SMMLS		Signed Most significant word Multiply Subtract.
SMMUL		Signed Most significant word Multiply.
SMUAD		Signed halfword Multiply, Add, Dual.
SMUL<x><y>	Signed halfword Multiply.
SMULL		Signed Multiply Long.
SMULW<y>	Signed halfword by word Multiply.
SMUSD		Signed halfword Multiply, Subtract, Dual.
UMAAL		Unsigned Multiply Accumulate significant Long.
UMLAL		Unsigned Multiply Accumulate Long.
UMULL		Unsigned Multiply Long.
#endif














};