/*
 *	Emitter.h
 *
 *		ARMv7 ISA Emitter for code generation.
 *
 *		David Miller, 2011.
 */
#pragma once


#include "arm_coding.h"
#include "arm_registers.h"
//#include "arm_disasm.h"


namespace ARM
{

	/*
	 *	Emitter		- Reserved for use w/ static members ..
	 *
	 *
	 */

	class Emitter
	{

	};






#if defined(_DEBUG) || defined(DEBUG)

	#define EAPI static void
	
	#define DECL_I				\
	    u32 Instruction=0

	#define DECL_Id(d)			\
	    u32 Instruction=(d)

#else
	
//	#define _inlineExSVoidA __extension__ static __inline void __attribute__ ((__always_inline__))

	#define EAPI				\
	    inline static void

	#define DECL_I				\
	    static u32 Instruction; \
	        Instruction=0

	#define DECL_Id(d)			\
	    static u32 Instruction; \
	        Instruction=(d)

#endif


	/*
	 *	TEMP
	 */
	
	
#define I			(Instruction)

#define SET_CC		I |= (((u32)CC&15)<<28)

#ifndef EMIT_I
#define EMIT_I		emit_Write32((I));
#endif

#ifndef EMIT_GET_PTR
#define EMIT_GET_PTR()	emit_GetCCPtr()
#endif

};






/*
 *	ARM Core Instructions
 */

#include "E_Branches.h"
#include "E_DataOp.h"
#include "E_Multiply.h"
#include "E_Parallel.h"
#include "E_Extend.h"
#include "E_Misc.h"
#include "E_Status.h"
#include "E_LoadStore.h"
#include "E_Special.h"


/*
 *	ARM VFP/A.SIMD Extension Instructions
 */

#include "E_VLoadStore.h"
#include "E_VRegXfer.h"
#include "E_VDataOp.h"


/*
 *	Helper Routines & Psuedo-Instructions
 */

#include "H_psuedo.h"

#include "H_Branches.h"
#include "H_LoadStore.h"

//#include "H_state.h"
//#include "H_fp.h"







