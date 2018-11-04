/*
 *	E_Special.h
 *
 */
#pragma once


namespace ARM
{
	
	
	
	
	
	EAPI ARMERROR()
	{
		DECL_Id(0xFFFFFFFF);
		EMIT_I;
	}


	EAPI NOP()
	{
		DECL_Id(0xE320F000);
		EMIT_I;
	}

	EAPI SVC(u32 code)
	{
		DECL_Id(0x0F000000);
		I |= code&0xFFFFFF;
		EMIT_I;
	}

	EAPI BKPT()
	{
		DECL_Id(0x01200070);
		EMIT_I;
	}

#define SWI SVC





	/*
	 *	Synchronization & Barrier Instructions.
	 *
	 */


	EAPI DSB()
	{
		DECL_Id(0xF57FF04F);
		EMIT_I;
	}

	EAPI DMB()
	{
		DECL_Id(0xF57FF05F);
		EMIT_I;
	}

	EAPI ISB()
	{
		DECL_Id(0xF57FF06F);
		EMIT_I;
	}



};

