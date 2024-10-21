

#include "../common/snspcdefs.h"
#include "ps2reg.h"


		.file		1 "snspc700.S"
    	.text	
    	.p2align	3
    	.globl 		SNSPCExecute_ASM
        .globl		_SNSPC_OpTable

		.set noreorder    



//
// cpu structure offsets
//

#define SNSPC_rPC  			0(R_pCpu)
#define SNSPC_rA  			2(R_pCpu)
#define SNSPC_rY  			3(R_pCpu)
#define SNSPC_rX  			4(R_pCpu)
#define SNSPC_rSP  			5(R_pCpu)
#define SNSPC_rPSW 			6(R_pCpu)

#define SNSPC_Cycles 		8(R_pCpu)
#define SNSPC_Counter0 		12(R_pCpu)
#define SNSPC_Counter1 		16(R_pCpu)
#define SNSPC_pUserData		20(R_pCpu)

#define SNSPC_ReadTrap		24(R_pCpu)
#define SNSPC_WriteTrap		28(R_pCpu)
#define SNSPC_Mem			32



//
// temporary storage on stack
//

#define SP_RA0   	0x50(sp)
#define SP_RA1   	0x54(sp)
#define SP_SaveTrap 0x5C(sp)

#define SP_Save0   	0x60(sp)
#define SP_Save1   	0x64(sp)
#define SP_Save2   	0x68(sp)
#define SP_Save3   	0x6C(sp)
#define SP_Save4   	0x70(sp)
  
#define SP_Data0   	0x78(sp)
#define SP_Data1   	0x79(sp)
#define SP_Data2   	0x7A(sp)
#define SP_Data3   	0x7B(sp)


//
// register definitions
//


//
// these registers must S0-S7
// they are not saved during a trap function
//

// pointer to current cpu state
#define	R_pCpu			$16

// address/data for mem i/o
#define R_Addr			$17	

// decomposed flags
#define R_fN			$18	
#define R_fZ			$19	
#define R_fC			$20	

// temporary registers for instruction processing
#define R_t0			$21
#define R_t1			$22
#define R_t2			$23




//
// these registers are saved/restored when a trap function is called
// t0-t2 are reserved

#define R_Cycles		$2
#define R_PC			$3
#define R_A				$4
#define R_X				$5
#define R_Y				$6
#define R_SP			$7

#define R_pMem			$11
#define R_P				$12
#define R_DP			$13
#define R_pOpTable		$15
#define R_Data			$24



//unused by 
//#define R_DB			$14
//#define R_DPMASK		$25
//#define R_PCCycles		$30



//
//
//


#define SNSPC_OP(_opcode)  	\
		op_##_opcode:		

#define SNSPC_OPTABLE_BEGIN()  _SNSPC_OpTable:
#define SNSPC_OPTABLE_OP(_opcode)  .word op_##_opcode
#define SNSPC_OPTABLE_END()  

#define SNSPC_SUBCYCLES(_nCycles) addiu	R_Cycles,R_Cycles, -(_nCycles * SNSPC_CYCLE)	

#define SNSPC_ENDOP(_nCycles)		\
		j		_SNSPCExecute_Loop	;	\
		addiu	R_Cycles,R_Cycles, -(_nCycles * SNSPC_CYCLE)	\


#define SNSPC_ABORTOP() \
		j		_SNSPCExecute_Done	;\
        addi	R_PC, R_PC,-1		\


//
//
//

#define SNSPC_ADD(_dest, _src) 		addu	_dest,_dest,_src
#define SNSPC_SUB(_dest, _src) 		subu	_dest,_dest,_src
#define SNSPC_AND(_dest, _src) 		and		_dest,_dest,_src
#define SNSPC_OR(_dest, _src) 		or		_dest,_dest,_src
#define SNSPC_XOR(_dest, _src) 		xor		_dest,_dest,_src
#define SNSPC_SHR(_dest, _src) 		srlv	_dest,_dest,_src
#define SNSPC_SHL(_dest, _src) 		sllv	_dest,_dest,_src

#define SNSPC_ADDI(_dest, _src) 	addiu	_dest,_dest,_src
#define SNSPC_SUBI(_dest, _src) 	addiu	_dest,_dest,-(_src)
#define SNSPC_ANDI(_dest, _src) 	andi	_dest,_dest,_src
#define SNSPC_ORI(_dest, _src) 	    ori		_dest,_dest,_src
#define SNSPC_XORI(_dest, _src)    	xori	_dest,_dest,_src
#define SNSPC_SHRI(_dest, _src)    	srl		_dest,_dest,_src
#define SNSPC_SRAI(_dest, _src)    	sra		_dest,_dest,_src
#define SNSPC_SHLI(_dest, _src)    	sll		_dest,_dest,_src
#define SNSPC_NOT16(_dest)    		xori	_dest,_dest,0xFFFF
#define SNSPC_NOT8(_dest)    		xori	_dest,_dest,0xFF


#define SNSPC_ADC8(_dest,_src)					\
		move	t0,_dest						;\
        addu	_dest,_dest,_src				;\
        xor		t1,t0,_src						;\
        xor		t2,t0,_dest						;\
        nor		t1,t1,zr						;\
        andi	R_P,R_P,SNSPC_FLAG_V ^ 0xFF		;\
        and		t1,t1,t2						;\
        srl		t1,t1,1							;\
        andi	t1,t1,SNSPC_FLAG_V	  			;\
        or		R_P,R_P,t1

#define SNSPC_ADC16(_dest,_src)					\
		move	t0,_dest						;\
        addu	_dest,_dest,_src				;\
        xor		t1,t0,_src						;\
        xor		t2,t0,_dest						;\
        nor		t1,t1,zr						;\
        andi	R_P,R_P,SNSPC_FLAG_V ^ 0xFF		;\
        and		t1,t1,t2						;\
        srl		t1,t1,9							;\
        andi	t1,t1,SNSPC_FLAG_V	  			;\
        or		R_P,R_P,t1





#define SNSPC_SETFLAG_I()   		ori		R_P,R_P,SNSPC_FLAG_I
#define SNSPC_CLRFLAG_I()   		andi 	R_P,R_P,SNSPC_FLAG_I^0xFFFF
#define SNSPC_SETFLAG_P()   		\
	ori		R_P,R_P,SNSPC_FLAG_P	;\
    li		R_DP,0x100			
    
#define SNSPC_CLRFLAG_P()   		\
	andi 	R_P,R_P,SNSPC_FLAG_P^0xFFFF   ;\
    li		R_DP,0x000			

#define SNSPC_SETFLAG_Z8(_src)   	sll		R_fZ,_src,8
#define SNSPC_SETFLAG_Z16(_src)   	sll		R_fZ,_src,0
#define SNSPC_SETFLAG_N8(_src)   	sll		R_fN,_src,8
#define SNSPC_SETFLAG_N16(_src)   	sll		R_fN,_src,0
#define SNSPC_SETFLAG_C(_src)   	andi	R_fC,_src,1
#define SNSPC_GETFLAG_C(_dest)   	andi	_dest,R_fC,1
#define SNSPC_SETFLAGI_C(_src)   	ori		R_fC,zr,1&(_src)

#define SNSPC_GETFLAG_V(_dest)   	andi	_dest,R_P,SNSPC_FLAG_V
#define SNSPC_GETFLAG_N(_dest)   	andi	_dest,R_fN,0x8000
#define SNSPC_GETFLAG_Z(_dest)   	\
		andi	R_fZ,R_fZ,0xFFFF	;\
        sltiu	_dest,R_fZ,1		;\

#define SNSPC_SETFLAGI_V(_src)   					\
        andi	R_P,R_P,SNSPC_FLAG_V ^ 0xFFFF  ;	\
        or		R_P,R_P,(_src) << 6							

#define SNSPC_SETFLAGI_H(_src)   					\
        andi	R_P,R_P,SNSPC_FLAG_H ^ 0xFFFF  ;	\
        or		R_P,R_P,(_src) << 3							


#define SNSPC_SETFLAG_V(_src)   					\
		andi	t0,_src,1 					   ;	\
        andi	R_P,R_P,SNSPC_FLAG_V ^ 0xFFFF  ;	\
        sll		t0,t0,6						   ;	\
        or		R_P,R_P,t0							

#define SNSPC_SETFLAG_H(_src)   					\
		andi	t0,_src,1 					   ;	\
        andi	R_P,R_P,SNSPC_FLAG_H ^ 0xFFFF  ;	\
        sll		t0,t0,3						   ;	\
        or		R_P,R_P,t0							


#define SNSPC_BREAK_TRUE(_reg)  	bne		_reg,zr,_SNSPCExecute_Loop
#define SNSPC_BREAK_FALSE(_reg)  	beq		_reg,zr,_SNSPCExecute_Loop


#define SNSPC_SET_X8(_src)   		andi	R_X,_src,0xFF
#define SNSPC_SET_Y8(_src)   		andi	R_Y,_src,0xFF
#define SNSPC_SET_A8(_src)   		andi	R_A,_src,0xFF
#define SNSPC_SET_SP8(_src)   		andi	R_SP,_src,0xFF

#define SNSPC_GETI(_dest, _imm) 	li		_dest,_imm

#define SNSPC_GET_X8(_dest)   		andi	_dest,R_X,0xFF
#define SNSPC_GET_Y8(_dest)   		andi	_dest,R_Y,0xFF
#define SNSPC_GET_A8(_dest)   		andi	_dest,R_A,0xFF
#define SNSPC_GET_SP8(_dest)   		andi	_dest,R_S,0xFF


#define SNSPC_GET_P(_dest)   				\
			jal		_SNSPC_ComposeFlags	 ;	\
            nop							 ;	\
			move	_dest,R_P			
            
            	
#define SNSPC_SET_P(_src)   		  		;	\
			jal		_SNSPC_DecomposeFlags	;	\
			move	R_P,_src

#define SNSPC_GET_PC(_dest)   	   andi    _dest,R_PC,0xFFFF
#define SNSPC_SET_PC(_src)   	   andi    R_PC,_src,0xFFFF

#define SNSPC_BREL_PC16(_rel)				\
		addu	R_PC,R_PC,_rel				;\


#define SNSPC_FETCH8(_dest)  		   \
		jal		_SNSPC_Fetch8		;  \
        nop							;  \
        move	_dest,R_Data

#define SNSPC_FETCH16(_dest)  		   \
		jal		_SNSPC_Fetch16		;  \
        nop							;  \
        move	_dest,R_Data

#define SNSPC_READ8(_addr,_data)  	   \
		jal		_SNSPC_Read8		;  \
		move	R_Addr, _addr		;  \
		move	_data,R_Data		   \

#define SNSPC_READ16(_addr,_data)  	   \
		jal		_SNSPC_Read16		;  \
		move	R_Addr, _addr		;  \
		move	_data,R_Data		   \

#define SNSPC_WRITE8(_addr,_data)  	   \
		move	R_Addr, _addr		;  \
		jal		_SNSPC_Write8		;  \
		move	R_Data, _data		   \

#define SNSPC_WRITE16(_addr,_data)     \
		move	R_Addr, _addr		;  \
		jal		_SNSPC_Write16		;  \
		move	R_Data, _data		   \


#define SNSPC_POP8(_dest)  		   \
		jal		_SNSPC_Read8		;  \
		addiu	R_Addr, R_S,1		;  \
        addiu	R_S,R_S,1			;  \
		move	_dest,R_Data		

#define SNSPC_POP16(_dest)  		   \
		jal		_SNSPC_Read16		;  \
		addiu	R_Addr, R_S,1		;  \
        addiu	R_S,R_S,2			;  \
		move	_dest,R_Data		

#define SNSPC_PUSH8(_src)  	   \
		addiu	R_Addr, R_S, 0		;  \
		jal		_SNSPC_Write8		;  \
		srl		R_Data, _src,0		;  \
		addiu	R_S,R_S,-1			;  \

#define SNSPC_PUSH16(_src)  	   \
		addiu	R_Addr, R_S, 0		;  \
		jal		_SNSPC_Write8		;  \
		srl		R_Data, _src,8		;  \
		addiu	R_Addr, R_S, -1		;  \
		jal		_SNSPC_Write8		;  \
		srl		R_Data, _src,0		;  \
		addiu	R_S,R_S,-2			;  \



#define SNSPC_SAVEREGSTATE() 				\
		sw		R_pOpTable, SP_Save0 	   ; \
		sw		R_pMem, SP_Save1 		   ; \
		sh		R_PC, SNSPC_rPC			   ; \
        sb		R_P, SNSPC_rP			   ; \
        sh		R_A, SNSPC_rA			   ; \
        sh		R_X, SNSPC_rX			   ; \
        sh		R_Y, SNSPC_rY			   ; \
        sh		R_SP, SNSPC_rSP			   ; \
		sw		R_Cycles, SNSPC_Cycles		


#define SNSPC_LOADREGSTATE()			    \
		lw		R_pOpTable, SP_Save0 	   ; \
		lw		R_pMem, SP_Save1 		   ; \
		lhu		R_PC, SNSPC_rPC			   ; \
        lbu		R_P, SNSPC_rP			   ; \
        lhu		R_A, SNSPC_rA			   ; \
        lhu		R_X, SNSPC_rX			   ; \
        lhu		R_Y, SNSPC_rY			   ; \
        lhu		R_SP, SNSPC_rSP			   ; \
        andi	R_DP, R_P, SNSPC_FLAG_P    ; \
		lw		R_Cycles,SNSPC_Cycles	   ; \
        sll		R_DP, R_DP, 3 




/*
//
// _SNSPC_Write8
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_Addr = ??aaaaaa
//  	R_Data = 000000dd
//
//  Destroyed:
//		t0,t1
//
*/

_SNSPC_Write8:
        
_SNSPC_Write8Trap:
        lw		t1,SNSPC_WriteTrap					// t1 -> trap handler

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
		sw		R_Data,SP_Data0				   
        SNSPC_SAVEREGSTATE()

		// call trap handler
		move	a0, R_pCpu
		move	a1, R_Addr
		jalr	t1
        andi	a2,R_Data, 0xFF

		// restore volatile and temporary registers
		lw		ra,SP_RA1
		lw		R_Data,SP_Data0				   
        SNSPC_LOADREGSTATE()

		jr		ra
        nop

/*
//
// _SNSPC_Write16
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_Addr = ??aaaaaa
//  	R_Data = 0000dddd
//
//  Destroyed:
//		t0,t1,t2
//		R_Data
//		SP_RA0
//
*/


_SNSPC_Write16:
		sw		ra, SP_RA0

		jal		_SNSPC_Write8		// write addr + 0 (00XX)
        addiu	R_Addr,R_Addr,0
        
        srl		R_Data,R_Data,8
		jal		_SNSPC_Write8		// write addr + 1 (XX00)
        addiu	R_Addr,R_Addr,1

		lw		ra, SP_RA0
        addiu	R_Addr,R_Addr,-1
        
        jr		ra					// return
        nop

/*
//
// _SNSPC_Read8
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_Addr = ??aaaaaa
//
//	Outputs:
//  	R_Data = 000000dd
//
//  Destroyed:
//		t0-t2
//
*/

_SNSPC_Read8:
        
_SNSPC_Read8Trap:
        lw		t1,SNSPC_ReadTrap					// t1 -> trap handler

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
        SNSPC_SAVEREGSTATE()
        
		// call trap handler
		move	a0, R_pCpu
		jalr	t1
		move	a1, R_Addr

        andi	R_Data, v0, 0xFF

		lw		ra,SP_RA1				   
        SNSPC_LOADREGSTATE()

		jr		ra
        nop



/*
//
// _SNSPC_Read16
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_Addr = ??aaaaaa
//
//	Outputs:
//  	R_Data = 0000dddd
//
//  Destroyed:
//		t0-t2
//		SP_RA0
//
*/

_SNSPC_Read16:
		sw		ra, SP_RA0

		jal		_SNSPC_Read8		// read addr + 0(00XX)
        addiu	R_Addr,R_Addr,0
        sb		R_Data,SP_Data0
        

		jal		_SNSPC_Read8		// read addr + 1  (XX00)
        addiu	R_Addr,R_Addr,1
        sb		R_Data,SP_Data1
        
		lw		ra, SP_RA0
        lhu		R_Data,SP_Data0
        
        jr		ra					// return
        addiu	R_Addr,R_Addr,-1




/*
//
// _SNSPC_Fetch8
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_PC   = 24-bit PC
//
//	Outputs:
//  	R_Data = 000000dd
//
//  Destroyed:
//		t0-t2
//		R_Addr
//
*/

_SNSPC_Fetch8:
_SNSPC_Fetch8Fast:
		addiu	t0,R_pMem, R_PC
		lbu		R_Data,0(t0)
		jr		ra
        addiu	R_PC,R_PC,1


/*
//
// _SNSPC_Fetch16
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_PC   = 24-bit PC
//
//	Outputs:
//  	R_Data = 0000dddd
//
//  Destroyed:
//		t0-t2
//		R_Addr
//		SP_RA0
//
//
*/


_SNSPC_Fetch16:
_SNSPC_Fetch16Fast:
		addiu	t0,R_pMem, R_PC
        lwr		R_Data, 0(t0)							// load word
        lwl		R_Data, 3(t0)							
        addiu	R_PC,R_PC,2
		jr		ra
        andi	R_Data,R_Data,0xFFFF


/*
//
// _SNSPC_ComposeFlags
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_P 	= processor flags
//  	R_fN = N???????
//  	R_fZ = ZZZZZZZZ
//  	R_fC = 0000000C
//	
//
//	Outputs:
//		R_P = flags | N | Z | C	
//
//  Destroyed:
//
//
*/

_SNSPC_ComposeFlags:
		andi	R_P, R_P, (SNSPC_FLAG_C | SNSPC_FLAG_Z |SNSPC_FLAG_N) ^ 0xFFFF
        andi	R_fC, R_fC,1

        srl		t0,R_fN,8
        or		R_P, R_P, R_fC

        andi	t0,t0,0x80
        andi	R_fZ,R_fZ,0xFFFF

        or		R_P,R_P,t0

        or		t1,R_P,SNSPC_FLAG_Z

		jr		ra
        movz	R_P,t1,R_fZ
        


/*
//
// _SNSPC_DecomposeFlags
//
//  Inputs:
//		R_pSPC -> cpu state
//		R_P 	= processor flags (NZC)
//
//	Outputs:
//  	R_fN = N???????
//  	R_fZ = ZZZZZZZZ
//  	R_fC = 0000000C
//
//  Destroyed:
//		t0-t2
//
*/

_SNSPC_DecomposeFlags:
		andi	R_fZ, R_P, SNSPC_FLAG_Z
		andi	R_fC, R_P, SNSPC_FLAG_C
		sll		R_fN, R_P, 8
        xori	R_fZ, R_fZ, SNSPC_FLAG_Z
        andi	R_DP, R_P, SNSPC_FLAG_P
		jr		ra
        sll		R_DP, R_DP, 3 
        







/*
//
//	 _SNSPCExecute_ASM
//
//	 Inputs:
//
//	    a0 -> cpu state
//
//	 Outputs:
//
//	    none
//
//   Destroyed:
//
//
//
*/


SNSPCExecute_ASM:
		addiu	sp,sp,-0x80
        sd		s0,0x00(sp)
        sd		s1,0x08(sp)
        sd		s2,0x10(sp)
        sd		s3,0x18(sp)
        sd		s4,0x20(sp)
        sd		s5,0x28(sp)
        sd		s6,0x30(sp)
        sd		s7,0x38(sp)
        sd		ra,0x40(sp)
        sd		fp,0x48(sp)

		move	R_pCpu, a0


//
//
//

		SNSPC_LOADREGSTATE();

        
        jal		_SNSPC_DecomposeFlags		// decompose flags
        nop
        

// setup optable pointer
// setup memory pointer
  

//
// interpreter loop
//



	// fetch opcode

_SNSPCExecute_Loop:
		bltz	R_Cycles, _SNSPCExecute_Done
        nop
        
		jal		_SNSPC_Fetch8
        nop		

		sll		t0, R_Data, 2							// R_Data = opcode * 4

        addu	t0, t0, R_pOpTable  					// t0 = OpTable + opcode * 4

        lw		t0, 0x00(t0)							// t0 -> opcode function
        
        jr		t0
        nop


_SNSPC_FetchPCTrap:



//
//
//


_SNSPCExecute_Done:

        jal		_SNSPC_ComposeFlags		// decompose flags
        nop
	  
		SNSPC_SAVEREGSTATE();


//
// cleanup stack frame
//

        ld		fp,0x48(sp)
        ld		ra,0x40(sp)
        ld		s7,0x38(sp)
        ld		s6,0x30(sp)
        ld		s5,0x28(sp)
        ld		s4,0x20(sp)
        ld		s3,0x18(sp)
        ld		s2,0x10(sp)
        ld		s1,0x08(sp)
        ld		s0,0x00(sp)
		jr		ra
		addiu	sp,sp,0x80






	SNSPC_OP(0x10);
		// BPL N=0
        SNSPC_GETFLAG_N(R_t1);
       SNSPC_BREL_IFFALSE(R_t1)



	SNSPC_OP(0x30);
		// BMI N=1
        SNSPC_GETFLAG_N(R_t1);
       SNSPC_BREL_IFTRUE(R_t1)

	SNSPC_OP(0xf0);
		// BEQ Z=1
        SNSPC_GETFLAG_Z(R_t1);
       SNSPC_BREL_IFTRUE(R_t1)

	SNSPC_OP(0xd0);
		// BNE Z=0
        SNSPC_GETFLAG_Z(R_t1);
       SNSPC_BREL_IFFALSE(R_t1)

	SNSPC_OP(0x90);
		// BCC
        SNSPC_GETFLAG_C(R_t1);
       SNSPC_BREL_IFFALSE(R_t1)

	SNSPC_OP(0xb0);
		// BCS
        SNSPC_GETFLAG_C(R_t1);
       SNSPC_BREL_IFTRUE(R_t1)

	SNSPC_OP(0x50);
		// BVC
        SNSPC_GETFLAG_V(R_t1);
       SNSPC_BREL_IFFALSE(R_t1)

	SNSPC_OP(0x70);
		// BVS
        SNSPC_GETFLAG_V(R_t1);
       SNSPC_BREL_IFTRUE(R_t1)


	SNSPC_OP(0x2F);
		// BRA
		SNSPC_FETCH8(R_t0)

        SNSPC_SHLI(R_t0,24)
        SNSPC_SRAI(R_t0,24)

		SNSPC_BREL_PC16(R_t0);
	SNSPC_ENDOP(1)
        
//
// unimplemented, unused in mario
//

	SNSPC_OP(0x00);
		// BRK


        SNSPC_ABORTOP()

	SNSPC_ENDOP(1)



#include "../../XML/opspc700_mips.h"



