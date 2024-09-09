

#include "../common/sncpudefs.h"
#include "ps2reg.h"


		.file		1 "sn65816.S"
    	.text	
    	.p2align	3
    	.globl 		SNCPUExecute_ASM
        .globl		_SNCPU_OpTable

		.set noreorder    



//
// cpu structure offsets
//

#define SNCPU_rA  			0(R_pCpu)
#define SNCPU_rX  			2(R_pCpu)
#define SNCPU_rY  			4(R_pCpu)
#define SNCPU_rS  			6(R_pCpu)
#define SNCPU_rP  			8(R_pCpu)
#define SNCPU_rE  			9(R_pCpu)
#define SNCPU_rDP  			10(R_pCpu)
#define SNCPU_rPC  			12(R_pCpu)
#define SNCPU_rDB  			16(R_pCpu)

#define SNCPU_Cycles 		20(R_pCpu)
#define SNCPU_Counter0 		24(R_pCpu)
#define SNCPU_Counter1 		28(R_pCpu)
#define SNCPU_Counter2 		32(R_pCpu)
#define SNCPU_Counter3 		36(R_pCpu)
#define SNCPU_pUserData		40(R_pCpu)

#define SNCPU_nAbortCycles	44(R_pCpu)
#define SNCPU_bRunning      48(R_pCpu)
#define SNCPU_uSignal       49(R_pCpu)
#define SNCPU_uPad0         50(R_pCpu)
#define SNCPU_uPad1         51(R_pCpu)

#define SNCPU_MemIO			52


#define SNCPU_pMem			(SNCPU_MemIO+0)
#define SNCPU_ReadTrap		(SNCPU_MemIO+4)
#define SNCPU_WriteTrap		(SNCPU_MemIO+8)
#define SNCPU_uBankCycle	(SNCPU_MemIO+12)
#define SNCPU_bRAM			(SNCPU_MemIO+13)



//
// temporary storage on stack
//

#define SP_RA0   	0x50(sp)
#define SP_RA1   	0x54(sp)
#define SP_PCBank  	0x58(sp)
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
#define R_S				$7

#define R_PCCount		$11
#define R_P				$12
#define R_DP			$13
#define R_DB			$14
#define R_pOpTable		$15
#define R_Data			$24
#define R_DPMASK		$25

#define R_PCCycles		$30





//
//
//


#define SNCPU_OP(_opcode)  	\
		op_##_opcode:		

#define SNCPU_OPTABLE_BEGIN()  _SNCPU_OpTable:
#define SNCPU_OPTABLE_OP(_opcode)  .word op_##_opcode
#define SNCPU_OPTABLE_END()  

#define SNCPU_SUBCYCLES(_nCycles)		\
		addiu	R_Cycles,R_Cycles, -(_nCycles * SNCPU_CYCLE_FAST)	
//#define SNCPU_SUBCYCLES(_nCycles)		


#define SNCPU_ENDOP(_nCycles)		\
		j		_SNCPUExecute_Loop	;	\
		addiu	R_Cycles,R_Cycles, -(_nCycles * SNCPU_CYCLE_FAST)	\


#define SNCPU_ABORTOP() \
		j		_SNCPUExecute_Abort	;\
        nop		

#define SNCPU_OP_ALL(_Opcode) \
	SNCPU_OP(0x0##_Opcode)	\
	SNCPU_OP(0x1##_Opcode)	\
	SNCPU_OP(0x2##_Opcode)	\
	SNCPU_OP(0x3##_Opcode)	\
	SNCPU_OP(0x4##_Opcode)	

#define SNCPU_OP_E0(_Opcode) \
	SNCPU_OP(0x0##_Opcode)	\
	SNCPU_OP(0x1##_Opcode)	\
	SNCPU_OP(0x2##_Opcode)	\
	SNCPU_OP(0x3##_Opcode)	\

#define SNCPU_OP_E1(_Opcode) \
	SNCPU_OP(0x4##_Opcode)	

#define SNCPU_OP_X0(_Opcode) \
	SNCPU_OP(0x0##_Opcode)	\
	SNCPU_OP(0x2##_Opcode)	\

#define SNCPU_OP_X1E1(_Opcode) \
	SNCPU_OP(0x1##_Opcode)	\
	SNCPU_OP(0x3##_Opcode)	\
	SNCPU_OP(0x4##_Opcode)	



//
//
//

#define SNCPU_ADD(_dest, _src) 		addu	_dest,_dest,_src
#define SNCPU_SUB(_dest, _src) 		subu	_dest,_dest,_src
#define SNCPU_AND(_dest, _src) 		and		_dest,_dest,_src
#define SNCPU_OR(_dest, _src) 		or		_dest,_dest,_src
#define SNCPU_XOR(_dest, _src) 		xor		_dest,_dest,_src
#define SNCPU_SHR(_dest, _src) 		srlv	_dest,_dest,_src
#define SNCPU_SHL(_dest, _src) 		sllv	_dest,_dest,_src

#define SNCPU_ADDI(_dest, _src) 	addiu	_dest,_dest,_src
#define SNCPU_SUBI(_dest, _src) 	addiu	_dest,_dest,-(_src)
#define SNCPU_ANDI(_dest, _src) 	andi	_dest,_dest,_src
#define SNCPU_ORI(_dest, _src) 	    ori		_dest,_dest,_src
#define SNCPU_XORI(_dest, _src)    	xori	_dest,_dest,_src
#define SNCPU_SHRI(_dest, _src)    	srl		_dest,_dest,_src
#define SNCPU_SRAI(_dest, _src)    	sra		_dest,_dest,_src
#define SNCPU_SHLI(_dest, _src)    	sll		_dest,_dest,_src
#define SNCPU_NOT16(_dest)    		xori	_dest,_dest,0xFFFF
#define SNCPU_NOT8(_dest)    		xori	_dest,_dest,0xFF


#define SNCPU_ADC8(_dest,_src)					\
		jal		_SNCPU_ADC8						;\
        nop

#define SNCPU_ADC16(_dest,_src)					\
		jal		_SNCPU_ADC16					;\
        nop

#define SNCPU_SBC8(_dest,_src)					\
		jal		_SNCPU_SBC8						;\
        nop

#define SNCPU_SBC16(_dest,_src)					\
		jal		_SNCPU_SBC16					;\
        nop




#define SNCPU_SETFLAG_I()   		ori		R_P,R_P,SNCPU_FLAG_I
#define SNCPU_CLRFLAG_I()   		andi 	R_P,R_P,SNCPU_FLAG_I^0xFFFF
#define SNCPU_SETFLAG_D()   		ori		R_P,R_P,SNCPU_FLAG_D
#define SNCPU_CLRFLAG_D()   		andi 	R_P,R_P,SNCPU_FLAG_D^0xFFFF

#define SNCPU_SETFLAG_Z8(_src)   	sll		R_fZ,_src,8
#define SNCPU_SETFLAG_Z16(_src)   	sll		R_fZ,_src,0
#define SNCPU_SETFLAG_N8(_src)   	sll		R_fN,_src,8
#define SNCPU_SETFLAG_N16(_src)   	sll		R_fN,_src,0
#define SNCPU_SETFLAG_C(_src)   	andi	R_fC,_src,1
#define SNCPU_GETFLAG_C(_dest)   	andi	_dest,R_fC,1
#define SNCPU_SETFLAGI_C(_src)   	ori		R_fC,zr,1&(_src)

#define SNCPU_GETFLAG_V(_dest)   	andi	_dest,R_P,SNCPU_FLAG_V
#define SNCPU_GETFLAG_N(_dest)   	andi	_dest,R_fN,0x8000
#define SNCPU_GETFLAG_Z(_dest)   	\
		andi	R_fZ,R_fZ,0xFFFF	;\
        sltiu	_dest,R_fZ,1		;\

#define SNCPU_GETFLAG_E(_dest)   	lbu		_dest,SNCPU_rE		
#define SNCPU_SETFLAG_E(_src)   	\
		jal		_SNCPU_UpdateOpTable	   ;\
		sb		_src,SNCPU_rE		


#define SNCPU_SETFLAGI_V(_src)   					\
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFFFF  ;	\
        or		R_P,R_P,(_src) << 6							


#define SNCPU_SETFLAG_V(_src)   					\
		andi	t0,_src,1 					   ;	\
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFFFF  ;	\
        sll		t0,t0,6						   ;	\
        or		R_P,R_P,t0							


#define SNCPU_BREAK_TRUE(_reg)  	bne		_reg,zr,_SNCPUExecute_Loop
#define SNCPU_BREAK_FALSE(_reg)  	beq		_reg,zr,_SNCPUExecute_Loop


#define SNCPU_SET_X16(_src)   		andi	R_X,_src,0xFFFF
#define SNCPU_SET_Y16(_src)   		andi	R_Y,_src,0xFFFF
#define SNCPU_SET_X8(_src)   		andi	R_X,_src,0xFF
#define SNCPU_SET_Y8(_src)   		andi	R_Y,_src,0xFF
#define SNCPU_SET_A16(_src)   		andi	R_A,_src,0xFFFF
#define SNCPU_SET_A8(_src)   		\
		andi	t0,_src,0xFF	   ;	\
		andi	R_A,R_A,0xFF00	   ;	\
        or		R_A,R_A,t0					

#define SNCPU_SET_S16(_src)   		andi	R_S,_src,0xFFFF
#define SNCPU_SET_S8(_src)   		\
		andi	t0,_src,0xFF	   ;	\
		andi	R_S,R_S,0xFF00	   ;	\
        or		R_S,R_S,t0					


#define SNCPU_GET_DB(_src)   		move	_src,R_DB
#define SNCPU_SET_DB(_src)   		move	R_DB,_src


#define SNCPU_GETI(_dest, _imm) 	li		_dest,_imm

#define SNCPU_GET_X16(_dest)   		andi	_dest,R_X,0xFFFF
#define SNCPU_GET_X8(_dest)   		andi	_dest,R_X,0xFF
#define SNCPU_GET_Y16(_dest)   		andi	_dest,R_Y,0xFFFF
#define SNCPU_GET_Y8(_dest)   		andi	_dest,R_Y,0xFF
#define SNCPU_GET_A16(_dest)   		andi	_dest,R_A,0xFFFF
#define SNCPU_GET_A8(_dest)   		andi	_dest,R_A,0xFF
#define SNCPU_GET_S16(_dest)   		andi	_dest,R_S,0xFFFF
#define SNCPU_GET_S8(_dest)   		andi	_dest,R_S,0xFF


#define SNCPU_GET_DP(_dest)   		move	_dest,R_DP
#define SNCPU_SET_DP(_src)   		move	R_DP,_src

#define SNCPU_GET_P(_dest)   				\
			jal		_SNCPU_ComposeFlags	 ;	\
            nop							 ;	\
			move	_dest,R_P			
            
            	
#define SNCPU_SET_P(_src)   		  		;	\
			jal		_SNCPU_DecomposeFlags	;	\
			move	R_P,_src

#define SNCPU_GET_PC(_dest)   		\
		lwu		t0,SP_PCBank	   ;\
        subu	_dest, R_PC, t0

// set lower 16-bits of PC and 8-bit PB         
// PB is always stored in CPU struct
#define SNCPU_SET_PC24(_src)   		\
		move	R_PC,_src		   ;\
        sw		zr, SP_PCBank	   ;\
		lui		R_PCCount,0xC000   ;\
        sw		R_PC,SNCPU_rPC	   

// set lower 16-bits of PC while preserving 8-bit PB         
// PB is always stored in CPU struct
// set PCCount to force bankswitch
#define SNCPU_SET_PC16(_src)   		\
        sh		_src,SNCPU_rPC	   ;\
        sw		zr, SP_PCBank	   ;\
		lui		R_PCCount,0xC000   ;\
        lwu		R_PC,SNCPU_rPC	   



// branch relative
// add rel to PC
// subtract rel from pccount. 
// if pccount >= SNCPU_BANK_SIZE then force bankswitch
#define SNCPU_BREL_PC16(_rel)				\
        subu	R_PCCount,R_PCCount,_rel				;\
        lui		t1,0xC000								;\
        sltiu	t0, R_PCCount,SNCPU_BANK_SIZE			;\
		addu	R_PC,R_PC,_rel							;\
        movz	R_PCCount,t1,t0 


#define SNCPU_FETCH8(_dest)  		   \
		jal		_SNCPU_Fetch8		;  \
        nop							;  \
        move	_dest,R_Data

#define SNCPU_FETCH16(_dest)  		   \
		jal		_SNCPU_Fetch16		;  \
        nop							;  \
        move	_dest,R_Data

#define SNCPU_FETCH24(_dest)  		   \
		jal		_SNCPU_Fetch24		;  \
        nop							;  \
        move	_dest,R_Data


#define SNCPU_READ8(_addr,_data)  	   \
		jal		_SNCPU_Read8		;  \
		move	R_Addr, _addr		;  \
		move	_data,R_Data		   \

#define SNCPU_READ16(_addr,_data)  	   \
		jal		_SNCPU_Read16		;  \
		move	R_Addr, _addr		;  \
		move	_data,R_Data		   \

#define SNCPU_READ24(_addr,_data)  	   \
		jal		_SNCPU_Read24		;  \
		move	R_Addr, _addr		;  \
		move	_data,R_Data		   \

#define SNCPU_WRITE8(_addr,_data)  	   \
		move	R_Addr, _addr		;  \
		jal		_SNCPU_Write8		;  \
		move	R_Data, _data		   \

#define SNCPU_WRITE16(_addr,_data)     \
		move	R_Addr, _addr		;  \
		jal		_SNCPU_Write16		;  \
		move	R_Data, _data		   \

#define SNCPU_WRITE24(_addr,_data)     \
		move	R_Addr, _addr		;  \
		jal		_SNCPU_Write24		;  \
		move	R_Data, _data		   \




#define SNCPU_POP8(_dest)  		   \
		jal		_SNCPU_Read8		;  \
		addiu	R_Addr, R_S,1		;  \
        addiu	R_S,R_S,1			;  \
		move	_dest,R_Data		

#define SNCPU_POP16(_dest)  		   \
		jal		_SNCPU_Read16		;  \
		addiu	R_Addr, R_S,1		;  \
        addiu	R_S,R_S,2			;  \
		move	_dest,R_Data		

#define SNCPU_POP24(_dest)  		   \
		jal		_SNCPU_Read24		;  \
		addiu	R_Addr, R_S,1		;  \
        addiu	R_S,R_S,3			;  \
		move	_dest,R_Data		


#define SNCPU_PUSH8(_src)  	   \
		addiu	R_Addr, R_S, 0		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,0		;  \
		addiu	R_S,R_S,-1			;  \

#define SNCPU_PUSH16(_src)  	   \
		addiu	R_Addr, R_S, 0		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,8		;  \
		addiu	R_Addr, R_S, -1		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,0		;  \
		addiu	R_S,R_S,-2			;  \

#define SNCPU_PUSH24(_src)  	   \
		addiu	R_Addr, R_S, 0		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,16		;  \
		addiu	R_Addr, R_S, -1		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,8		;  \
		addiu	R_Addr, R_S, -2		;  \
		jal		_SNCPU_Write8		;  \
		srl		R_Data, _src,0		;  \
		addiu	R_S,R_S,-3			;  \




#define SNCPU_SAVEREGSTATE() 				\
		sw		R_PCCount, SP_Save0		   ; \
		sw		R_DPMASK, SP_Save1		   ; \
		sw		R_pOpTable, SP_Save2 	   ; \
		sw		R_PCCycles, SP_Save3 	   ; \
		sw		R_PC, SP_Save4			   ; \
        sh		R_A, SNCPU_rA			   ; \
        sh		R_X, SNCPU_rX			   ; \
        sh		R_Y, SNCPU_rY			   ; \
        sh		R_S, SNCPU_rS			   ; \
        sh		R_DP, SNCPU_rDP			   ; \
        sw		R_DB, SNCPU_rDB			   ; \
        sb		R_P, SNCPU_rP			   ; \
		sw		R_Cycles, SNCPU_Cycles		



#define SNCPU_LOADREGSTATE()			    \
		lw		R_PCCount, SP_Save0		   ; \
		lwu		R_DPMASK, SP_Save1		   ; \
		lwu		R_pOpTable, SP_Save2 	   ; \
		lwu		R_PCCycles, SP_Save3 	   ; \
		lwu		R_PC, SP_Save4			   ; \
        lhu		R_A, SNCPU_rA			   ; \
        lhu		R_X, SNCPU_rX			   ; \
        lhu		R_Y, SNCPU_rY			   ; \
        lhu		R_S, SNCPU_rS			   ; \
        lhu		R_DP, SNCPU_rDP			   ; \
        lwu		R_DB, SNCPU_rDB			   ; \
        lbu		R_P, SNCPU_rP			   ; \
		lw		R_Cycles,SNCPU_Cycles	   




/*
//
// _SNCPU_Write8
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_Addr = ??aaaaaa
//  	R_Data = 000000dd
//
//  Destroyed:
//		t0,t1
//
*/

_SNCPU_Write8:
		srl		t0,R_Addr,SNCPU_BANK_SHIFT				// t0 = bank 

		beq		t0,zr,_SNCPU_Write8ZeroBank
        sll		t0,t0,4									// t0 = (bank << 4) 

        addu	t0,t0,R_pCpu							// t0 -> Bank[bank]

        lh		t2,SNCPU_uBankCycle(t0)					// t2 = bank cycle count | (bRAM << 8)
        lw		t1,SNCPU_pMem(t0)						// t1 = bank addr

        bgez	t2,_SNCPU_Write8Trap					// if !RAM goto write trap
        andi	t2,t2,0xFF								// t2 = nCycles
        
        addu	t0,t1,R_Addr							// t0 = bank read addr +  R_Addr
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

		jr		ra										
        sb		R_Data, 0(t0)							// load byte unsigned
        

_SNCPU_Write8ZeroBank:
        lw		t0,SNCPU_pMem(R_pCpu)	 				// t0 = bank addr
        addiu	R_Cycles,R_Cycles,-SNCPU_CYCLE_SLOW		// zero bank is slow
        addu	t0,t0,R_Addr
		jr		ra										
        sb		R_Data, 0(t0)							// load byte unsigned
        
_SNCPU_Write8Trap:
        lw		t1,SNCPU_WriteTrap(t0)					// t1 -> trap handler
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
		sw		R_Data,SP_Data0				   
        SNCPU_SAVEREGSTATE()

		// call trap handler
		move	a0, R_pCpu
		move	a1, R_Addr
		jalr	t1
        andi	a2,R_Data, 0xFF

		// restore volatile and temporary registers
		lw		ra,SP_RA1
		lw		R_Data,SP_Data0				   
        SNCPU_LOADREGSTATE()

		jr		ra
        nop

/*
//
// _SNCPU_Write16
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_Addr = ??aaaaaa
//  	R_Data = 0000dddd
//
//  Destroyed:
//		t0,t1,t2
//		R_Data
//		SP_RA0
//
*/


_SNCPU_Write16_Slow:
		sw		ra, SP_RA0

		jal		_SNCPU_Write8		// write addr + 0 (00XX)
        addiu	R_Addr,R_Addr,0
        
        srl		R_Data,R_Data,8
		jal		_SNCPU_Write8		// write addr + 1 (XX00)
        addiu	R_Addr,R_Addr,1

		lw		ra, SP_RA0
        addiu	R_Addr,R_Addr,-1
        
        jr		ra					// return
        nop

_SNCPU_Write16:

_SNCPU_Write16_Fast:
        addiu	t1,R_Addr,1								// t1 = addr + 1
		srl		t2,R_Addr,SNCPU_BANK_SHIFT				// t2 = bank 

        srl		t1,t1,SNCPU_BANK_SHIFT					// t1 = second bank
        sll		t0,t2,4									// t0 = (bank << 4) & bank mask

		bne		t1,t2,_SNCPU_Write16_Slow				// reads from different banks? go to slow version
        addu	t0,t0,R_pCpu							// t0 -> Bank[bank]

        lh		t2,SNCPU_uBankCycle(t0)					// t2 = bank cycle count | (bRAM << 8)
        lw		t1,SNCPU_pMem(t0)						// t1 = bank addr

        bgez	t2,_SNCPU_Write16Trap					// if !RAM goto write trap
        andi	t2,t2,0xFF								// t2 = nCycles
        
        addu	t0,t1,R_Addr							// t0 = bank read addr +  R_Addr
        srl		t1,R_Data,8								// t1 = high byte
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

        sb		R_Data, 0(t0)							// store low byte 
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

		jr		ra										
        sb		t1, 1(t0)								// store high byte 


_SNCPU_Write16Trap:
        lw		t1,SNCPU_WriteTrap(t0)					// t1 -> trap handler
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
		sw		R_Data,SP_Data0				   
        SNCPU_SAVEREGSTATE()

        sw		t1, SP_SaveTrap

		// call trap handler
		move	a0, R_pCpu
		addiu	a1, R_Addr, 0
		jalr	t1
        andi	a2,R_Data, 0xFF

		lw		R_Data,SP_Data0				   
        lw		t1, SP_SaveTrap


		// call trap handler
		move	a0, R_pCpu
		addiu	a1, R_Addr, 1
        srl		a2,R_Data,8
		jalr	t1
        andi	a2,a2, 0xFF

		// restore volatile and temporary registers
		lw		ra,SP_RA1				   
		lw		R_Data,SP_Data0				   
        SNCPU_LOADREGSTATE()

		jr		ra
        nop


        



/*
//
// _SNCPU_Read8
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_Addr = ??aaaaaa
//
//	Outputs:
//  	R_Data = 000000dd
//
//  Destroyed:
//		t0-t2
//
*/

_SNCPU_Read8:
		srl		t0,R_Addr,SNCPU_BANK_SHIFT				// t0 = bank 
        
        beq		t0,zr,_SNCPU_Read8ZeroBank
        sll		t0,t0,4									// t0 = (bank << 4) & bank mask

        addu	t0,t0,R_pCpu							// t0 -> Bank[bank]

        lw		t1,SNCPU_pMem(t0)						// t1 = bank addr
        lbu		t2,SNCPU_uBankCycle(t0)					// t2 = bank cycle count

        beq		t1,zr,_SNCPU_Read8Trap					// if bankaddr==0 goto trap
		subu	R_Cycles, R_Cycles, t2					// consume cycles for memory access

        addu	t0,t1,R_Addr							// t0 = bank read addr +  R_Addr

		jr		ra										
        lbu		R_Data, 0(t0)							// load byte unsigned


_SNCPU_Read8ZeroBank:
        lw		t0,SNCPU_pMem(R_pCpu)	 				// t0 = bank addr
        addiu	R_Cycles,R_Cycles,-SNCPU_CYCLE_SLOW		// zero bank is slow
        addu	t0,t0,R_Addr
		jr		ra										
        lbu		R_Data, 0(t0)							// load byte unsigned

        
_SNCPU_Read8Trap:
        lw		t1,SNCPU_ReadTrap(t0)					// t1 -> trap handler

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
        SNCPU_SAVEREGSTATE()
        
		// call trap handler
		move	a0, R_pCpu
		jalr	t1
		move	a1, R_Addr

        andi	R_Data, v0, 0xFF

		lw		ra,SP_RA1				   
        SNCPU_LOADREGSTATE()

		jr		ra
        nop



/*
//
// _SNCPU_Read16
//
//  Inputs:
//		R_pCPU -> cpu state
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

_SNCPU_Read16_Slow:
		sw		ra, SP_RA0

		jal		_SNCPU_Read8		// read addr + 0(00XX)
        addiu	R_Addr,R_Addr,0
        sb		R_Data,SP_Data0
        

		jal		_SNCPU_Read8		// read addr + 1  (XX00)
        addiu	R_Addr,R_Addr,1
        sb		R_Data,SP_Data1
        
		lw		ra, SP_RA0
        lhu		R_Data,SP_Data0
        
        jr		ra					// return
        addiu	R_Addr,R_Addr,-1



_SNCPU_Read16:
_SNCPU_Read16_Fast:
        addiu	t1,R_Addr,1								// t1 = addr + 1
		srl		t2,R_Addr,SNCPU_BANK_SHIFT				// t2 = bank 

        srl		t1,t1,SNCPU_BANK_SHIFT					// t1 = second bank
        sll		t0,t2,4									// t0 = (bank << 4) & bank mask

		bne		t1,t2,_SNCPU_Read16_Slow				// reads from different banks? go to slow version
        addu	t0,t0,R_pCpu							// t0 -> Bank[bank]

        lw		t1,SNCPU_pMem(t0)						// t1 = bank addr
        lbu		t2,SNCPU_uBankCycle(t0)					// t2 = bank cycle count

        beq		t1,zr,_SNCPU_Read16Trap					// if bankaddr==0 goto trap
		subu	R_Cycles, R_Cycles, t2					// consume cycles for first memory access

        addu	t0,t1,R_Addr							// t0 = bank read addr +  R_Addr
		subu	R_Cycles, R_Cycles, t2					// consume cycles for second memory access

        lwr		R_Data, 0(t0)							// load word
        lwl		R_Data, 3(t0)							

		jr		ra	
        andi	R_Data,R_Data,0xFFFF
        
        
_SNCPU_Read16Trap:
        lw		t1,SNCPU_ReadTrap(t0)					// t1 -> trap handler
		subu	R_Cycles, R_Cycles, t2					// consume cycles for second memory access

		// save volatile and temporary registers
		sw		ra,SP_RA1				   
        SNCPU_SAVEREGSTATE()

        sw		t1, SP_SaveTrap
        
		// read lower byte
		move	a0, R_pCpu
		jalr	t1
		addiu	a1, R_Addr,0
        sb		v0,SP_Data0

        lw		t1, SP_SaveTrap
        
		// read upper byte
		move	a0, R_pCpu
		jalr	t1
		addiu	a1, R_Addr,1
        sb		v0,SP_Data1

		lw		ra,SP_RA1				   
        lhu		R_Data,SP_Data0						
        SNCPU_LOADREGSTATE()

		jr		ra
        nop




/*
//
// _SNCPU_Read24
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_Addr = ??aaaaaa
//
//	Outputs:
//  	R_Data = 00dddddd
//
//  Destroyed:
//		t0-t2
//		SP_RA0
//
*/

_SNCPU_Read24:
		sw		ra, SP_RA0
        sw		zr,SP_Data0

		jal		_SNCPU_Read8		// read addr + 0  (0000XX)
        addiu	R_Addr,R_Addr,0
        sb		R_Data,SP_Data0

		jal		_SNCPU_Read8		// read addr + 1  (00XX00)
        addiu	R_Addr,R_Addr,1
        sb		R_Data,SP_Data1

		jal		_SNCPU_Read8		// read addr + 2  (XX0000)
        addiu	R_Addr,R_Addr,1
        sb		R_Data,SP_Data2
        
		lw		ra, SP_RA0
        lw		R_Data,SP_Data0
        
        jr		ra					// return
        addiu	R_Addr,R_Addr,-2	






/*
//
// _SNCPU_Fetch8
//
//  Inputs:
//		R_pCPU -> cpu state
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

_SNCPU_Fetch8:
_SNCPU_Fetch8Fast:
		bltz	R_PCCount,_SNCPU_Fetch8Update
		addiu	R_PCCount,R_PCCount,-1

		lbu		R_Data,0(R_PC)
        addiu	R_PC,R_PC,1

		jr		ra
        subu	R_Cycles,R_Cycles,R_PCCycles


_SNCPU_Fetch8Update:
		lwu		t0,SP_PCBank			// restore PC to normal

        subu	R_PC, R_PC, t0

        sh		R_PC,SNCPU_rPC	  		// dont allow PB to change. It may only change by a SETPC24
        lwu		R_PC,SNCPU_rPC	   

		srl		t0,R_PC,SNCPU_BANK_SHIFT					// t0 = pc bank 
        sll		t0,t0,4										// t0 = (bank << 4) & bank mask
        addu	t0,t0,R_pCpu								// t0 -> Bank[bank]

        lw		t1,SNCPU_pMem(t0)							// t1 = bank read addr
        lbu		R_PCCycles,SNCPU_uBankCycle(t0)				// R_PCCycles = bank cycle count

        beq		t1,zr,_SNCPU_Fetch8Trap   					// if bankaddr==0 goto trap
        sw		t1,SP_PCBank								// save pcbank

        andi	R_PCCount, R_PC, SNCPU_BANK_MASK		// R_PCCount = PC & 0x1FFF ^ 0x1FFF
        xori	R_PCCount, R_PCCount, SNCPU_BANK_MASK 

		j		_SNCPU_Fetch8Fast        					// refetch byte
        addu	R_PC,t1,R_PC  								// R_PC -> bank read addr +  R_PC

_SNCPU_Fetch8Trap:
		lui		R_PCCount,0xC000							// invalidate PCCount 
        move	R_Addr, R_PC								// perform trap at PC address
		j		_SNCPU_Read8
        addiu	R_PC,R_PC,1



_SNCPU_Fetch8Slow:
		move	R_Addr, R_PC

		j		_SNCPU_Read8
        addiu	R_PC,R_PC,1		// increment pc




/*
//
// _SNCPU_Fetch16
//
//  Inputs:
//		R_pCPU -> cpu state
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



_SNCPU_Fetch16:

_SNCPU_Fetch16Fast:
		blez	R_PCCount,_SNCPU_Fetch16Trap
		addiu	R_PCCount,R_PCCount,-2

        subu	R_Cycles,R_Cycles,R_PCCycles

        lwr		R_Data, 0(R_PC)							// load word
        lwl		R_Data, 3(R_PC)							

        addiu	R_PC,R_PC,2
        subu	R_Cycles,R_Cycles,R_PCCycles


		jr		ra
        andi	R_Data,R_Data,0xFFFF


_SNCPU_Fetch16Trap:
		sw		ra, SP_RA0
        
        jal		_SNCPU_Fetch8
		addiu	R_PCCount,R_PCCount,2

        jal		_SNCPU_Fetch8
        sb		R_Data,SP_Data0

        lw		ra, SP_RA0
        sb		R_Data,SP_Data1
        
        jr		ra
        lhu		R_Data,SP_Data0



_SNCPU_Fetch16Slow:
		move	R_Addr, R_PC

		j		_SNCPU_Read16
        addiu	R_PC,R_PC,2		// increment pc



/*
//
// _SNCPU_Fetch24
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_PC   = 24-bit PC
//
//	Outputs:
//  	R_Data = 00dddddd
//
//  Destroyed:
//		t0-t2
//		R_Addr
//		SP_RA0
//
//
*/


_SNCPU_Fetch24:
_SNCPU_Fetch24Fast:
		addiu	R_PCCount,R_PCCount,-1

		blez	R_PCCount,_SNCPU_Fetch24Trap
		addiu	R_PCCount,R_PCCount,-2

        subu	R_Cycles,R_Cycles,R_PCCycles

        lwr		R_Data, 0(R_PC)							// load word
        lwl		R_Data, 3(R_PC)							

        addiu	R_PC,R_PC,3
        subu	R_Cycles,R_Cycles,R_PCCycles
        sll		R_Data,R_Data,8
        subu	R_Cycles,R_Cycles,R_PCCycles

		jr		ra
        srl		R_Data,R_Data,8

_SNCPU_Fetch24Trap:
		sw		ra, SP_RA0
        sw		zr, SP_Data0
        
        jal		_SNCPU_Fetch8
		addiu	R_PCCount,R_PCCount,3

        jal		_SNCPU_Fetch8
        sb		R_Data,SP_Data0

        jal		_SNCPU_Fetch8
        sb		R_Data,SP_Data1

        lw		ra, SP_RA0
        sb		R_Data,SP_Data2
        
        jr		ra
        lw		R_Data,SP_Data0



_SNCPU_Fetch24Slow:
		move	R_Addr, R_PC

		j		_SNCPU_Read24
        addiu	R_PC,R_PC,3		// increment pc
        

/*
//
// _SNCPU_ComposeFlags
//
//  Inputs:
//		R_pCPU -> cpu state
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

_SNCPU_ComposeFlags:
		andi	R_P, R_P, (SNCPU_FLAG_C | SNCPU_FLAG_Z |SNCPU_FLAG_N) ^ 0xFFFF
        andi	R_fC, R_fC,1

        srl		t0,R_fN,8
        or		R_P, R_P, R_fC

        andi	t0,t0,0x80
        andi	R_fZ,R_fZ,0xFFFF

        or		R_P,R_P,t0

        or		t1,R_P,SNCPU_FLAG_Z

		jr		ra
        movz	R_P,t1,R_fZ
        


/*
//
// _SNCPU_DecomposeFlags
//
//  Inputs:
//		R_pCPU -> cpu state
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

_SNCPU_DecomposeFlags:
		andi	R_fZ, R_P, SNCPU_FLAG_Z
		andi	R_fC, R_P, SNCPU_FLAG_C
		sll		R_fN, R_P, 8
        xori	R_fZ, R_fZ, SNCPU_FLAG_Z
        
        andi	t0,R_P, SNCPU_FLAG_X
        andi	t1,R_X, 0xFF
        andi	t2,R_Y, 0xFF
        movn	R_X,t1,t0
		j		_SNCPU_UpdateOpTable
        movn	R_Y,t2,t0







/*
//
// _SNCPU_UpdateOpTable
//
//  Inputs:
//		R_pCPU -> cpu state
//		R_P 		= processor flags
//		SNCPU_rE 	= E-bit
//
//	Outputs:		   
//		R_pOpTable	-> opcode table
//
//	if e=0
//		R_DPMASK 	=  0xFFFF 
//
//	if e=1
//		R_DPMASK 	= 0x00FF
//		R_DP		= 0
//		R_S		    = 0x01??
//		R_P		   |= SNCPU_FLAG_M | SNCPU_FLAG_X 
//
//  Destroyed:
//		t0-t2
//
*/

_SNCPU_UpdateOpTable:
		lbu		t0, SNCPU_rE				// t0 = E bit
		andi	t1, R_P, 0x30				// t1 = M and X bits
        
        bne		t0,zr, _E1
        li		R_DPMASK,0xFFFF

// E=0
_E0:
		la		R_pOpTable, _SNCPU_OpTable	// get pointer to optable base
		sll		t1,t1, 4 + 2				// t1 = opcode table offset

		jr		ra
        addu	R_pOpTable,R_pOpTable,t1


// E=1
_E1:
		la		R_pOpTable, _SNCPU_OpTable	// get pointer to optable base
        li		R_DPMASK,0x00FF
        li		R_DP,0x0000
        addiu	R_pOpTable,R_pOpTable, 0x400*4	// point to E=1 instructions
        ori		R_P,R_P, SNCPU_FLAG_M | SNCPU_FLAG_X 
        andi	R_S,0x00FF
		jr		ra
        ori		R_S,0x0100



//
// adc sbc functions
//
//  R_t2 = R_t2 + R_t1
//

_SNCPU_ADC8:
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFF		 // clear overflow flag
		move	t0,R_t2						     // t0 = target
        addu	R_t2,R_t2,R_t1					 // dest = target + src
        addu	R_t2,R_t2,R_fC					 // dest+= carry
        xor		t1,t0,R_t1						 // t1= target ^ src
        xor		t2,t0,R_t2						 // t2= target ^ dest
        nor		t1,t1,zr						 // t1= ~(target ^ src)
        and		t1,t1,t2						 // t1 = (dest ^ target) &	~(target ^ src)
        srl		t1,t1,1							 // shift into bit position
        andi	t1,t1,SNCPU_FLAG_V	  			
        or		R_P,R_P,t1

		andi	t1,R_P,SNCPU_FLAG_D
        bne		t1,zr,_SNCPU_ADC8_DECIMAL
		nop

		jr		ra
		nop


_SNCPU_ADC16:
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFF		
		move	t0,R_t2						
        addu	R_t2,R_t2,R_t1				
        addu	R_t2,R_t2,R_fC					 // dest+= carry
        xor		t1,t0,R_t1						
        xor		t2,t0,R_t2						
        nor		t1,t1,zr						
        and		t1,t1,t2						
        srl		t1,t1,9							
        andi	t1,t1,SNCPU_FLAG_V	  			
        or		R_P,R_P,t1

		andi	t1,R_P,SNCPU_FLAG_D
        bne		t1,zr,_SNCPU_ADC16_DECIMAL
		nop

		jr		ra
		nop



_SNCPU_SBC8:
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFF		
		move	t0,R_t2						
        addu	R_t2,R_t2,R_t1				
        addu	R_t2,R_t2,R_fC					 // dest+= carry
        xor		t1,t0,R_t1						
        xor		t2,t0,R_t2						
        nor		t1,t1,zr						
        and		t1,t1,t2						
        srl		t1,t1,1							
        andi	t1,t1,SNCPU_FLAG_V	  			
        or		R_P,R_P,t1

		andi	t1,R_P,SNCPU_FLAG_D
        bne		t1,zr,_SNCPU_SBC8_DECIMAL
		nop

		jr		ra
		nop

_SNCPU_SBC16:
        andi	R_P,R_P,SNCPU_FLAG_V ^ 0xFF		
		move	t0,R_t2						
        addu	R_t2,R_t2,R_t1				
        addu	R_t2,R_t2,R_fC					 // dest+= carry
        xor		t1,t0,R_t1						
        xor		t2,t0,R_t2						
        nor		t1,t1,zr						
        and		t1,t1,t2						
        srl		t1,t1,9							
        andi	t1,t1,SNCPU_FLAG_V	  			
        or		R_P,R_P,t1

		andi	t1,R_P,SNCPU_FLAG_D
        bne		t1,zr,_SNCPU_SBC16_DECIMAL
		nop

		jr		ra
		nop


#define _SNCPU_ADC_DIGIT(_digit)	\
		andi	t0,R_t1,(0xF<<_digit)	   	;\
		andi	t1,R_t2,(0xF<<_digit)		;\
        addu	t2,t2,t0					;\
        addu	t2,t2,t1					;\
        srl		t0,t2,_digit	 			;\
        sltiu	t0,t0,10		 			;\
        addiu	t1,t2,-(10<<_digit)	 		;\
		andi	t1,t1,(0xFFFF >> (12-_digit))		;\
		addiu	t1,t1,(0x10 << _digit)		;\
        movz	t2,t1,t0					;\


#define _SNCPU_ADC_DIGIT_CRAP(_digit)	\
		andi	t0,R_t1,(0xF<<_digit)	   	;\
		andi	t1,R_t2,(0xF<<_digit)		;\
        addu	t2,t2,t0					;\
        addu	t2,t2,t1					;\
        srl		t0,t2,_digit	 			;\
        sltiu	t0,t0,10		 			;\
        addiu	t1,t2,-(5<<_digit)	 		;\
        addiu	t1,t1,-(5<<_digit)	 		;\
		andi	t1,t1,(0xFFFF >> (12-_digit))		;\
		addiu	t1,t1,(0x4 << _digit)		;\
		addiu	t1,t1,(0x4 << _digit)		;\
		addiu	t1,t1,(0x4 << _digit)		;\
		addiu	t1,t1,(0x4 << _digit)		;\
        movz	t2,t1,t0					;\


#define _SNCPU_SBC_DIGIT(_digit)	\
		andi	t0,R_t1,(0xF<<_digit)	   	;\
		andi	t1,R_t2,(0xF<<_digit)		;\
        addu	t2,t2,t0					;\
        subu	t2,t2,t1					;\
        srl		t0,t2,_digit	 			;\
        sltiu	t0,t0,10		 			;\
        addiu	t1,t2,(10<<_digit)	 		;\
		andi	t1,t1,(0xFFFF >> (12-_digit))		;\
		addiu	t1,t1,-(0x10 << _digit)		;\
        movz	t2,t1,t0					;\


#define _SNCPU_SBC_DIGIT_CRAP(_digit)	\
		andi	t0,R_t1,(0xF<<_digit)	   	;\
		andi	t1,R_t2,(0xF<<_digit)		;\
        addu	t2,t2,t0					;\
        subu	t2,t2,t1					;\
        srl		t0,t2,_digit	 			;\
        sltiu	t0,t0,10		 			;\
        addiu	t1,t2,(5<<_digit)	 		;\
        addiu	t1,t1,(5<<_digit)	 		;\
		andi	t1,t1,(0xFFFF >> (12-_digit))		;\
		addiu	t1,t1,-(0x4 << _digit)		;\
		addiu	t1,t1,-(0x4 << _digit)		;\
		addiu	t1,t1,-(0x4 << _digit)		;\
		addiu	t1,t1,-(0x4 << _digit)		;\
        movz	t2,t1,t0					;\



_SNCPU_ADC8_DECIMAL:
		move	R_t2,t0					// restore t2
        andi	t2,R_fC,1					 // dest==carry
					 
        _SNCPU_ADC_DIGIT(0)
        _SNCPU_ADC_DIGIT(4)
        
		jr		ra
        move	R_t2,t2			// set dest

_SNCPU_ADC16_DECIMAL:
		move	R_t2,t0					// restore t2
        andi	t2,R_fC,1					 // dest==carry
        
        _SNCPU_ADC_DIGIT(0)
        _SNCPU_ADC_DIGIT(4)
        _SNCPU_ADC_DIGIT(8)
        _SNCPU_ADC_DIGIT_CRAP(12)
        
		jr		ra
        move	R_t2,t2			// set dest


_SNCPU_SBC8_DECIMAL:
		move	R_t2,t0					// restore t2
        andi	t2,R_fC,1					 // dest==carry

		xori    R_t2,R_t2,0x00FF       // restore src back to normal
		addiu	t2,t2,-1			   // invert carry
        
        _SNCPU_SBC_DIGIT(0)
        _SNCPU_SBC_DIGIT(4)

		xori	t2,t2,0x100			// invert carry

		jr		ra
        move	R_t2,t2			// set dest



_SNCPU_SBC16_DECIMAL:
		move	R_t2,t0					// restore t2
        andi	t2,R_fC,1					 // dest==carry

		xori    R_t2,R_t2,0xFFFF	   // restore src back to normal	
		addiu	t2,t2,-1			   // invert carry
        
        _SNCPU_SBC_DIGIT(0)
        _SNCPU_SBC_DIGIT(4)
        _SNCPU_SBC_DIGIT(8)
        _SNCPU_SBC_DIGIT_CRAP(12)

		li		t0,0x10000				// invert carry
		xor		t2,t2,t0
        
		jr		ra
        move	R_t2,t2			// set dest




/*
//
//	 _SNCPUExecute_ASM
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


SNCPUExecute_ASM:
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

		SNCPU_LOADREGSTATE();

        
        jal		_SNCPU_DecomposeFlags		// decompose flags
        nop
        
        // setup PC
		lwu		R_PC, SNCPU_rPC
		sw		zr,SP_PCBank
        move	R_PCCycles,zr
		lui		R_PCCount,0xC000							// invalidate PCCount 
  

//
// interpreter loop
//



	// fetch opcode
_SNCPUExecute_Loop:
        
		bltz	R_PCCount,_SNCPU_ExecuteFetchUpdate
		addiu	R_PCCount,R_PCCount,-1

		lbu		R_Data,0(R_PC)

		blez	R_Cycles, _SNCPUExecute_Done
        addiu	R_PC,R_PC,1


		sll		t0, R_Data, 2							// R_Data = opcode * 4

        addu	t0, t0, R_pOpTable  					// t0 = OpTable + opcode * 4

        lw		t0, 0x00(t0)							// t0 -> opcode function
        subu	R_Cycles,R_Cycles,R_PCCycles
        
        jr		t0
        nop


_SNCPU_ExecuteFetchUpdate:
		blez	R_Cycles, _SNCPUExecute_Done
        addiu	R_PC,R_PC,1


		jal		_SNCPU_Fetch8Update				// reads data, pc+=1
        addiu	R_PC,R_PC,-1
        

		sll		t0, R_Data, 2							// R_Data = opcode * 4
        addu	t0, t0, R_pOpTable  					// t0 = OpTable + opcode * 4
        lw		t0, 0x00(t0)							// t0 -> opcode function
        jr		t0
        nop
        

		
  /*

_SNCPUExecute_Loop:
		blez	R_Cycles, _SNCPUExecute_Done
        nop
        
		jal		_SNCPU_Fetch8
        nop		

		sll		t0, R_Data, 2							// R_Data = opcode * 4

        addu	t0, t0, R_pOpTable  					// t0 = OpTable + opcode * 4

        lw		t0, 0x00(t0)							// t0 -> opcode function
        
        jr		t0
        nop
*/        		 



_SNCPUExecute_Abort:



//
//
//


_SNCPUExecute_Done:
        addiu	R_PC,R_PC,-1

		lw		t0,SP_PCBank
        subu	R_PC, R_PC, t0
		sh		R_PC, SNCPU_rPC     // remember, the PB is never updated! only the lower 16-bits of the PC are significant in the register

        jal		_SNCPU_ComposeFlags		// decompose flags
        nop
	  
		SNCPU_SAVEREGSTATE();


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





		// addr_imm8_SEP_
	SNCPU_OP_E0(e2);
		SNCPU_FETCH8(R_t0);
        SNCPU_OR(R_P,R_t0);

		la		R_pOpTable, _SNCPU_OpTable	// get pointer to optable base

        // set C flag
        andi 	t0,R_t0,SNCPU_FLAG_C
        or		R_fC, R_fC, t0

		// set N flag
        sll 	t1,R_t0,8
        or		R_fN, R_fN, t1

		// set Z flag
        andi 	t2,R_t0,SNCPU_FLAG_Z
        movn	R_fZ, zr, t2

        andi	t0,R_P, SNCPU_FLAG_X
        andi	t1,R_X, 0xFF
        andi	t2,R_Y, 0xFF
        movn	R_X,t1,t0
        movn	R_Y,t2,t0

		andi	t1, R_P, 0x30				// t1 = M and X bits

		sll		t1,t1, 4 + 2				// t1 = opcode table offset

        addu	R_pOpTable,R_pOpTable,t1


	SNCPU_ENDOP(1)

        
		// addr_imm8_REP_
	SNCPU_OP_E0(c2);
		SNCPU_FETCH8(R_t0);
        SNCPU_NOT8(R_t0);       // R_t0 = ~rep bits
        SNCPU_AND(R_P,R_t0);

		la		R_pOpTable, _SNCPU_OpTable	// get pointer to optable base
        
        // clear C flag
        and		R_fC, R_fC, R_t0

		// clear N flag
        sll 	t1,R_t0,8
        and		R_fN, R_fN, t1

		// clear Z flag
        andi 	t2,R_t0,SNCPU_FLAG_Z
        movz	R_fZ, R_pOpTable, t2

		andi	t1, R_P, 0x30				// t1 = M and X bits

		sll		t1,t1, 4 + 2				// t1 = opcode table offset

        addu	R_pOpTable,R_pOpTable,t1

	SNCPU_ENDOP(1)



		// addr_imm8_SEP_
	SNCPU_OP_E1(e2);
		SNCPU_FETCH8(R_t0);

        // set bits of P
        SNCPU_OR(R_P,R_t0);

        // set C flag
        andi 	t0,R_t0,SNCPU_FLAG_C
        or		R_fC, R_fC, t0

		// set N flag
        sll 	t1,R_t0,8
        or		R_fN, R_fN, t1

		// set Z flag
        andi 	t2,R_t0,SNCPU_FLAG_Z
        movn	R_fZ, zr, t2

        andi	t0,R_P, SNCPU_FLAG_X
        andi	t1,R_X, 0xFF
        andi	t2,R_Y, 0xFF
        movn	R_X,t1,t0
        movn	R_Y,t2,t0

		jal		_SNCPU_UpdateOpTable		
        nop


	SNCPU_ENDOP(1)

        
		// addr_imm8_REP_
	SNCPU_OP_E1(c2);
		SNCPU_FETCH8(R_t0);
        
        // clear bits of P
        SNCPU_OR(R_P,R_t0);
        SNCPU_XOR(R_P,R_t0);
        
        // clear C flag
        andi 	t0,R_t0,SNCPU_FLAG_C
        or		R_fC, R_fC, t0
        xor		R_fC, R_fC, t0

		// clear N flag
        sll 	t1,R_t0,8
        or		R_fN, R_fN, t1
        xor		R_fN, R_fN, t1

		// clear Z flag
        andi 	t2,R_t0,SNCPU_FLAG_Z
        movn	R_fZ, R_t0, t2

		jal		_SNCPU_UpdateOpTable		
        nop

	SNCPU_ENDOP(1)




	SNCPU_OP_ALL(10);
		// BPL N=0
        SNCPU_GETFLAG_N(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_TRUE(R_t1)
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)



	SNCPU_OP_ALL(30);
		// BMI N=1
        SNCPU_GETFLAG_N(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_FALSE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)

	SNCPU_OP_ALL(f0);
		// BEQ Z=1
        SNCPU_GETFLAG_Z(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_FALSE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)

	SNCPU_OP_ALL(d0);
		// BNE Z=0
        SNCPU_GETFLAG_Z(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_TRUE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)


	SNCPU_OP_ALL(90);
		// BCC
        SNCPU_GETFLAG_C(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_TRUE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)

	SNCPU_OP_ALL(b0);
		// BCS
        SNCPU_GETFLAG_C(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_FALSE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)

	SNCPU_OP_ALL(50);
		// BVC
        SNCPU_GETFLAG_V(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_TRUE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)

	SNCPU_OP_ALL(70);
		// BVS
        SNCPU_GETFLAG_V(R_t1);
		SNCPU_FETCH8(R_t0)
        
        SNCPU_BREAK_FALSE(R_t1);
        
        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)


	SNCPU_OP_ALL(80);
		// BRA
		SNCPU_FETCH8(R_t0)

        SNCPU_SHLI(R_t0,24)
        SNCPU_SRAI(R_t0,24)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)
        





	SNCPU_OP_ALL(82);

		// BRL
		SNCPU_FETCH16(R_t0)

        SNCPU_SHLI(R_t0,16)
        SNCPU_SRAI(R_t0,16)

		SNCPU_BREL_PC16(R_t0);
	SNCPU_ENDOP(1)


	SNCPU_OP_X0(54);

		// MVN
        SNCPU_FETCH8(R_t0)		// dest bank
        SNCPU_FETCH8(R_t1)		// src bank

        SNCPU_SHLI(R_t0,16)
        SNCPU_SHLI(R_t1,16)
        
        SNCPU_SET_DB(R_t0)		// set DB 
        
        SNCPU_OR(R_t0, R_Y)
        SNCPU_OR(R_t1, R_X)
        
        SNCPU_READ8(R_t1, R_t2)
        SNCPU_WRITE8(R_t0,R_t2)
        
        SNCPU_ADDI(R_X, 1)
        SNCPU_ADDI(R_Y, 1)
        SNCPU_ANDI(R_X,0xFFFF)
        SNCPU_ANDI(R_Y,0xFFFF)
        
        addiu	t0,R_PC,-3			// if A!=0, PC-=3
        addiu	t1,R_PCCount, 3		//  PCCount+=3 also
        movn	R_PC,t0,R_A
        movn	R_PCCount,t1,R_A
        
        SNCPU_ADDI(R_A, -1)
	SNCPU_ENDOP(2)
        

	SNCPU_OP_X1E1(54);

		// MVN
        SNCPU_FETCH8(R_t0)		// dest bank
        SNCPU_FETCH8(R_t1)		// src bank

        SNCPU_SHLI(R_t0,16)
        SNCPU_SHLI(R_t1,16)
        
        SNCPU_SET_DB(R_t0)		// set DB 
        
        SNCPU_OR(R_t0, R_Y)
        SNCPU_OR(R_t1, R_X)
        
        SNCPU_READ8(R_t1, R_t2)
        SNCPU_WRITE8(R_t0,R_t2)
        
        SNCPU_ADDI(R_X, 1)
        SNCPU_ADDI(R_Y, 1)
        SNCPU_ANDI(R_X,0xFF)
        SNCPU_ANDI(R_Y,0xFF)
        
        addiu	t0,R_PC,-3			// if A!=0, PC-=3
        addiu	t1,R_PCCount, 3		//  PCCount+=3 also
        movn	R_PC,t0,R_A
        movn	R_PCCount,t1,R_A
        
        SNCPU_ADDI(R_A, -1)
	SNCPU_ENDOP(2)


	SNCPU_OP_X0(44);

		// MVP
        SNCPU_FETCH8(R_t0)		// dest bank
        SNCPU_FETCH8(R_t1)		// src bank

        SNCPU_SHLI(R_t0,16)
        SNCPU_SHLI(R_t1,16)
        
        SNCPU_SET_DB(R_t0)		// set DB 
        
        SNCPU_OR(R_t0, R_Y)
        SNCPU_OR(R_t1, R_X)
        
        SNCPU_READ8(R_t1, R_t2)
        SNCPU_WRITE8(R_t0,R_t2)
        
        SNCPU_ADDI(R_X, -1)
        SNCPU_ADDI(R_Y, -1)
        SNCPU_ANDI(R_X,0xFFFF)
        SNCPU_ANDI(R_Y,0xFFFF)
        
        addiu	t0,R_PC,-3			// if A!=0, PC-=3
        addiu	t1,R_PCCount, 3		//  PCCount+=3 also
        movn	R_PC,t0,R_A
        movn	R_PCCount,t1,R_A
        
        SNCPU_ADDI(R_A, -1)
	SNCPU_ENDOP(2)
        

	SNCPU_OP_X1E1(44);

		// MVP
        SNCPU_FETCH8(R_t0)		// dest bank
        SNCPU_FETCH8(R_t1)		// src bank

        SNCPU_SHLI(R_t0,16)
        SNCPU_SHLI(R_t1,16)
        
        SNCPU_SET_DB(R_t0)		// set DB 
        
        SNCPU_OR(R_t0, R_Y)
        SNCPU_OR(R_t1, R_X)
        
        SNCPU_READ8(R_t1, R_t2)
        SNCPU_WRITE8(R_t0,R_t2)
        
        SNCPU_ADDI(R_X, -1)
        SNCPU_ADDI(R_Y, -1)
        SNCPU_ANDI(R_X,0xFF)
        SNCPU_ANDI(R_Y,0xFF)
        
        addiu	t0,R_PC,-3			// if A!=0, PC-=3
        addiu	t1,R_PCCount, 3		//  PCCount+=3 also
        movn	R_PC,t0,R_A
        movn	R_PCCount,t1,R_A
        
        SNCPU_ADDI(R_A, -1)
	SNCPU_ENDOP(2)


	SNCPU_OP_ALL(cb);
		lbu		t0,SNCPU_uSignal

		andi	t1,t0,SNCPU_SIGNAL_IRQ		// isolate irq signal bit
		ori 	t0,t0,SNCPU_SIGNAL_WAI		// clear wai signal
		xori 	t0,t0,SNCPU_SIGNAL_WAI		// clear wai signal

		bne		t1,zr, _WAI_SkipIRQ
		nop

		// WAI
        addiu	R_PC,R_PC,-1				// PC--
        addiu	R_PCCount,R_PCCount,1		// PCCount++

		ori		t0,t0,SNCPU_SIGNAL_WAI		// set wai signal

_WAI_SkipIRQ:

		sb		t0,SNCPU_uSignal			// store new wai signal

	SNCPU_ENDOP(2)

//
// unimplemented, unused in mario
//

	SNCPU_OP_ALL(42);
		// WDM


	SNCPU_OP_ALL(db);
		// STP


        SNCPU_ABORTOP()

	SNCPU_ENDOP(1)



#include "../../XML/op65816_mips.h"















