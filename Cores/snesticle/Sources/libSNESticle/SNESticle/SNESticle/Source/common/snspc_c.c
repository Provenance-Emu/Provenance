

/*
Todo: 
Half carry support

Read 16-bit value from dp does not wrap!

 
 */




#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "snspc.h"
#include "snspc_c.h"
#include "snspcdisasm.h"
#include "sndebug.h"


#define SNSPC_STATEDEBUG (SNES_DEBUG && 1)
#define SNSPC_HALFFLAG FALSE
#define SNSPC_PROFILE FALSE

//#define SNSPC_SUBCYCLES(_nCycles)			pCpu->Cycles-= ((_nCycles)*SNSPC_CYCLE) >> pCpu->uCycleShift;
#define SNSPC_SUBCYCLES(_nCycles)			nCycles-= ((_nCycles)*SNSPC_CYCLE);

#define SNSPC_FETCH8(_Reg)  _Reg=_SNSPCFetch8(pCpu, rPC);  rPC++;  
#define SNSPC_FETCH16(_Reg) _Reg=_SNSPCFetch16(pCpu, rPC); rPC+=2; 

#define SNSPC_WRITE8(_Addr, _Data)  pCpu->Cycles = nCycles; _SNSPCWrite8(pCpu, _Addr, _Data);  
#define SNSPC_WRITE16(_Addr, _Data) pCpu->Cycles = nCycles; _SNSPCWrite16(pCpu, _Addr, _Data); 

#define SNSPC_READ8(_Addr, _x)  pCpu->Cycles = nCycles; _x = _SNSPCRead8(pCpu, _Addr);  
#define SNSPC_READ16(_Addr, _x) pCpu->Cycles = nCycles; _x = _SNSPCRead16(pCpu, _Addr); 

#define SNSPC_PUSH8(_Data)	_SNSPCPush8(pCpu, _Data);  
#define SNSPC_PUSH16(_Data)	_SNSPCPush16(pCpu, _Data);  
#define SNSPC_POP8(_x)	_x = _SNSPCPop8(pCpu);  
#define SNSPC_POP16(_x)	_x = _SNSPCPop16(pCpu);  

// this macro assumes that the memory read/write cycle is the last cycle of an instruction
// this prevents the spc from executing "ahead" of the main cpu

#if 1
#define SNSPC_OP(_Opcode, _Cycles) \
	case (_Opcode):	\
	if (nCycles < ((_Cycles-0)*SNSPC_CYCLE)) goto done;	\

#define SNSPC_ENDOP(_Cycles) \
		SNSPC_SUBCYCLES(_Cycles);	\
		break;
#else
#define SNSPC_OP(_Opcode, _Cycles) \
	case (_Opcode):	\
	if (nCycles < ((_Cycles-1)*SNSPC_CYCLE)) goto done;	\

#define SNSPC_ENDOP(_Cycles) \
		SNSPC_SUBCYCLES(_Cycles);	\
		break;
#endif

#define SNSPC_SETFLAG_Z8(_x)  fZ = (_x) << 8;
#define SNSPC_SETFLAG_Z16(_x) fZ = (_x) << 0;
#define SNSPC_SETFLAG_N8(_x)  fN = (_x) << 8;
#define SNSPC_SETFLAG_N16(_x) fN = (_x) << 0;
#define SNSPC_SETFLAG_C(_x)  fC = (_x) & 1;
#define SNSPC_SETFLAGI_C(_x)  fC = (_x) & 1;
#define SNSPC_GETFLAG_C(_x)  _x = fC & 1;

#define SNSPC_SETFLAG_V() r_P |= SNSPC_FLAG_V;
#define SNSPC_CLRFLAG_V() r_P &= ~SNSPC_FLAG_V;
#define SNSPC_SETFLAG_I() r_P |= SNSPC_FLAG_I;
#define SNSPC_CLRFLAG_I() r_P &= ~SNSPC_FLAG_I;
#define SNSPC_SETFLAG_B() r_P |= SNSPC_FLAG_B;
#define SNSPC_SETFLAG_D() r_P |= SNSPC_FLAG_D;
#define SNSPC_CLRFLAG_D() r_P &= ~SNSPC_FLAG_D;
#define SNSPC_SETFLAGI_V(__V) r_P &= ~SNSPC_FLAG_V; r_P |= ((__V) & 1) << 6;
#if SNSPC_HALFFLAG
#define SNSPC_SETFLAG_H(__H) r_P &= ~SNSPC_FLAG_H; r_P |= ((__H) & 1) << 3;
#else
#define SNSPC_SETFLAG_H(__H) r_P &= ~SNSPC_FLAG_H; 
#endif

#define SNSPC_SETFLAG_P() r_P |= SNSPC_FLAG_P; r_DP=0x100;
#define SNSPC_CLRFLAG_P() r_P &= ~SNSPC_FLAG_P; r_DP=0x000;
#define SNSPC_SETPC(_Addr)	r_PC= _Addr;

#define SNSPC_UNPACKFLAGS()					\
	fC = (r_P & SNSPC_FLAG_C);					\
	r_DP = (r_P & SNSPC_FLAG_P) << 3;					\
	fZ = (r_P & SNSPC_FLAG_Z) ^ SNSPC_FLAG_Z;	\
	fN = (r_P << 8);							

#define SNSPC_PACKFLAGS()								\
	r_P &= ~(SNSPC_FLAG_C | SNSPC_FLAG_Z |SNSPC_FLAG_N);	\
	r_P |= fC & SNSPC_FLAG_C;												\
	r_P |= (fN >> 8) & SNSPC_FLAG_N;								\
	if (!(fZ&0xFFFF)) r_P|=SNSPC_FLAG_Z;		

#define SNSPC_SET_YA16(_x) r_A = (_x); r_Y=(_x)>>8;
#define SNSPC_SET_A8(_x) r_A = _x;
#define SNSPC_SET_X8(_x) r_X = _x;
#define SNSPC_SET_Y8(_x) r_Y = _x;
#define SNSPC_SET_SP8(_x) r_SP = _x;
#define SNSPC_SET_PSW8(_x) r_P = _x; SNSPC_UNPACKFLAGS();
#define SNSPC_SET_PC16(_x) r_PC = _x;

#define SNSPC_GET_YA16(_x) _x = r_A | (r_Y<<8);
#define SNSPC_GET_A8(_x) _x = r_A;
#define SNSPC_GET_X8(_x) _x = r_X;
#define SNSPC_GET_Y8(_x) _x = r_Y;
#define SNSPC_GET_SP8(_x) _x = r_SP;
#define SNSPC_GET_PSW8(_x) SNSPC_PACKFLAGS(); _x = r_P; 
#define SNSPC_GET_PC(_x) _x = r_PC;
#define SNSPC_GETI(_x,_imm) _x = _imm;

#define r_A    pCpu->Regs.rA
#define r_X    pCpu->Regs.rX
#define r_Y    pCpu->Regs.rY
#define r_SP   pCpu->Regs.rSP
#define r_P    pCpu->Regs.rPSW
#define r_PC   rPC
#define r_DP   rDP
#define r_C   fC

#define r_A8    pCpu->Regs.rA
#define r_X8    pCpu->Regs.rX
#define r_Y8    pCpu->Regs.rY
#define r_SP8   pCpu->Regs.rSP
#define r_PSW8   pCpu->Regs.rPSW

#define SNSPC_NOT8(_Dest) _Dest^=0xFF;
#define SNSPC_NOT16(_Dest) _Dest^=0xFFFF;

#define SNSPC_MOVE(_Dest, _Src) _Dest=_Src;
#define SNSPC_MUL(_Dest, _Src) _Dest*=_Src;
#define SNSPC_ADD(_Dest, _Src) _Dest+=_Src;
#define SNSPC_SUB(_Dest, _Src) _Dest-=_Src;

#define SNSPC_OR(_Dest, _Src) _Dest|=_Src;
#define SNSPC_XOR(_Dest, _Src) _Dest^=_Src;
#define SNSPC_AND(_Dest, _Src) _Dest&=_Src;
#define SNSPC_SHL(_Dest, _Src) _Dest<<=_Src;
#define SNSPC_SHR(_Dest, _Src) _Dest>>=_Src;

#define SNSPC_ADDI(_Dest, _Src) _Dest+=_Src;
#define SNSPC_SUBI(_Dest, _Src) _Dest-=_Src;
#define SNSPC_ORI(_Dest, _Src) _Dest|=_Src;
#define SNSPC_XORI(_Dest, _Src) _Dest^=_Src;
#define SNSPC_ANDI(_Dest, _Src) _Dest&=_Src;
#define SNSPC_SHLI(_Dest, _Src) _Dest<<=_Src;
#define SNSPC_SHRI(_Dest, _Src) _Dest>>=_Src;

#if SNSPC_HALFFLAG

#define SNSPC_ADC8(_Dest,_Src)						\
		{											\
			Uint32 _Target = _Dest;					\
			_Dest = _Target + _Src;					\
			r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
			if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x80 )	\
					r_P |= SNSPC_FLAG_V;		\
			if (((_Target&0xF) + (_Src & 0xF))&0x10) r_P|=SNSPC_FLAG_H; \
		}

#define SNSPC_ADC16(_Dest,_Src)						\
		{											\
			Uint32 _Target = _Dest;					\
			_Dest = _Target + _Src;					\
			r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
			if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x8000 )	\
					r_P |= SNSPC_FLAG_V;		\
			if (((_Target&0xF) + (_Src & 0xF))&0x10) r_P|=SNSPC_FLAG_H; \
		}
#else

#define SNSPC_ADC8(_Dest,_Src)						\
		{											\
		Uint32 _Target = _Dest;					\
		_Dest = _Target + _Src + (fC&1);					\
		r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
		if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x80 )	\
		r_P |= SNSPC_FLAG_V;		\
		}

#define SNSPC_ADC16(_Dest,_Src)						\
		{											\
		Uint32 _Target = _Dest;					\
		_Dest = _Target + _Src;					\
		r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
		if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x8000 )	\
		r_P |= SNSPC_FLAG_V;		\
		}


#define SNSPC_SBC8(_Dest,_Src)						\
		{											\
		Uint32 _Target = _Dest;					\
		_Dest = _Target + _Src + (fC&1);					\
		r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
		if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x80 )	\
		r_P |= SNSPC_FLAG_V;		\
		}

/*
#define SNSPC_SUB16(_Dest,_Src)						\
		{											\
		Uint32 _Target = _Dest;					\
		_Dest = _Target + _Src);					\
		r_P &= ~(SNSPC_FLAG_V|SNSPC_FLAG_H);	\
		if ( ~(_Target ^ _Src) & (_Target ^ _Dest) & 0x8000 )	\
		r_P |= SNSPC_FLAG_V;		\
		}
*/
#endif



// BPL
#define SNSPC_BRREL(_bTest)				\
		{								\
		Int32	iRel;				\
		SNSPC_FETCH8(iRel);			\
		if (_bTest)					\
			{							\
			iRel <<=24;				\
			iRel >>=24;				\
			rPC+= iRel;				\
			SNSPC_SUBCYCLES(2);		\
			}							\
		}

#define SNSPC_BRA()				\
		{								\
		Int32	iRel;				\
		SNSPC_FETCH8(iRel);			\
			iRel <<=24;				\
			iRel >>=24;				\
			rPC+= iRel;				\
		}


#define SNSPC_BBC(_Bit)			\
	SNSPC_FETCH8(t0);		\
	t0+=r_DP;				\
	SNSPC_READ8(t0,t1);	\
	t1&=1<<(_Bit);			\
	SNSPC_BRREL(!t1);		\
	SNSPC_SUBCYCLES(5);		

#define SNSPC_BBS(_Bit)			\
	SNSPC_FETCH8(t0);		\
	t0+=r_DP;				\
	SNSPC_READ8(t0,t1);	\
	t1&=1<<(_Bit);			\
	SNSPC_BRREL(t1);		\
	SNSPC_SUBCYCLES(5);		



// addr_abs_CALL_
#define SNSPC_TCALL(__n)	\
	SNSPC_READ16(0xFFC0 + ((15-(__n))*2), t0);\
	SNSPC_GET_PC(t2);\
	SNSPC_PUSH16(t2);\
	SNSPC_SET_PC16(t0);



//
//
//

static __inline Uint8 _SNSPCFetch8(SNSpcT *pCpu, Uint32 uAddr)
{
	return pCpu->Mem[uAddr];
}

static __inline Uint16 _SNSPCFetch16(SNSpcT *pCpu, Uint32 uAddr)
{
	return pCpu->Mem[uAddr] | (pCpu->Mem[uAddr+1]<<8);
}


static __inline Uint8 __SNSPCRead8(SNSpcT *pCpu, Uint32 uAddr)
{
	if (uAddr >= 0xF0 && uAddr < 0x100)
	{
		return pCpu->pReadTrapFunc(pCpu, uAddr);
	} else
	{
		return pCpu->Mem[uAddr];
	}
}

static Uint8 _SNSPCRead8(SNSpcT *pCpu, Uint32 Addr)
{
	Uint32 uData;
	uData =  __SNSPCRead8(pCpu, Addr);
	return  uData;
}

static Uint16 _SNSPCRead16(SNSpcT *pCpu, Uint32 Addr)
{
	Uint32 uData;
	uData =  __SNSPCRead8(pCpu, Addr);
	uData|= (__SNSPCRead8(pCpu, Addr+1)<<8);
	return  uData;
}

static __inline void  __SNSPCWrite8(SNSpcT *pCpu, Uint32 uAddr, Uint8 uData)
{
	// don't write to rom area
	if (uAddr < SNSPC_ROM_ADDR)
	{
		pCpu->Mem[uAddr] = uData;
	}
	else
	if (!pCpu->bRomEnable)
	{
		// rom is disabled
		pCpu->Mem[uAddr] = uData;
//		pCpu->pWriteTrapFunc(pCpu, uAddr, uData);
	} else
	{
		// rom is enabled
		pCpu->ShadowMem[uAddr & (SNSPC_ROM_SIZE -1)] = uData;
	}

	if (uAddr >= 0xF0 && uAddr < 0x100)
	{
		pCpu->pWriteTrapFunc(pCpu, uAddr, uData);
	}
}

static void  _SNSPCWrite8(SNSpcT *pCpu, Uint32 Addr, Uint8 Data)
{
	__SNSPCWrite8(pCpu, Addr + 0, Data >> 0);
}

static void  _SNSPCWrite16(SNSpcT *pCpu, Uint32 Addr, Uint16 Data)
{
	__SNSPCWrite8(pCpu, Addr + 0, Data >> 0);
	__SNSPCWrite8(pCpu, Addr + 1, Data >> 8);
}


static void _SNSPCPush8(SNSpcT *pCpu, Uint8 Data)
{
	pCpu->Mem[r_SP + 0x100] = Data;
	r_SP--;
}

static void _SNSPCPush16(SNSpcT *pCpu, Uint16 Data)
{
	pCpu->Mem[r_SP + 0x100] = (Uint8)(Data >> 8);
	r_SP--;
	pCpu->Mem[r_SP + 0x100] = (Uint8)(Data & 0xFF);
	r_SP--;
}

static Uint8 _SNSPCPop8(SNSpcT *pCpu)
{
	r_SP++;
	return pCpu->Mem[r_SP + 0x100];
}

static Uint16 _SNSPCPop16(SNSpcT *pCpu)
{
	Uint32 uData;
	r_SP++;
	uData = pCpu->Mem[r_SP + 0x100];
	r_SP++;
	uData|= pCpu->Mem[r_SP + 0x100] << 8;
	return uData;
}


//
//
//

#if 0
SNSpcRegsT _LastRegs[512];
#endif

#if  SNSPC_STATEDEBUG
#include "console.h"
#endif

Int32 SNSPCExecute_C(SNSpcT *pCpu)
{
	Int32	nCycles;
	Uint32	rPC;
	Uint32 fN; // N??????? ????????
	Uint32 fZ; // ZZZZZZZZ ZZZZZZZZ
	Uint32 fC; // 00000000 0000000C
	Uint32 rDP;
//	Uint32 bDone = FALSE;

	nCycles = pCpu->Cycles;
	
	if (nCycles <= 0) return 0;

	// registerize registers
	rPC			= pCpu->Regs.rPC;

	// UNPACK flags
	SNSPC_UNPACKFLAGS();

	// rePACK flags
	while (1)
	{
		Uint32 uOpcode;
		Uint32 t0,t1,t2;

#if  SNSPC_STATEDEBUG
		pCpu->Regs.rPC = rPC;
		if (g_bStateDebug)
		{
			Char str[64];
  
	  		SNSPCDisasm(str, pCpu->Mem + pCpu->Regs.rPC, pCpu->Regs.rPC);
            pCpu->Cycles = nCycles;

            ConDebug("%06d: spc %04X: %02X %02X %02X %02X %c%c%c%c %s (%d)\n", 
                SNSPCGetCounter(pCpu, SNSPC_COUNTER_FRAME),
                rPC, 
				pCpu->Regs.rA,
				pCpu->Regs.rX,
				pCpu->Regs.rY,
				pCpu->Regs.rSP,
				(fN&0x8000) ? 'N' : 'n',
				(pCpu->Regs.rPSW&SNSPC_FLAG_V) ? 'V' : 'v',
				((fZ&0xFFFF)==0) ? 'Z' : 'z',
				(fC&0x01) ? 'C' : 'c',
				str,
                nCycles
			);
		}
#endif

	#if 0
		int i;
		pCpu->Regs.rPC = rPC;
		for (i=511; i > 0; i--)
		{
			_LastRegs[i] = _LastRegs[i-1];
		}
		_LastRegs[0] = pCpu->Regs;

		if (rPC==0xC9C)
		{
			i++;
		}
#endif

		SNSPC_FETCH8(uOpcode);

		switch (uOpcode)
		{

#include "../../XML/opspc700_c.h"

	SNSPC_OP(0x10, 2);
		// BPL
		SNSPC_BRREL(!(fN & 0x8000));
       SNSPC_ENDOP(2);

	SNSPC_OP(0x30, 2);
		// BMI
		SNSPC_BRREL((fN & 0x8000));
       SNSPC_ENDOP(2);

	SNSPC_OP(0xF0, 2);
		// BEQ
		SNSPC_BRREL(!(fZ&0xFFFF));
       SNSPC_ENDOP(2);

	SNSPC_OP(0xD0, 2);
		// BNE
		SNSPC_BRREL((fZ&0xFFFF));
       SNSPC_ENDOP(2);

	SNSPC_OP(0x90, 2);
		// BCC
		SNSPC_BRREL(fC==0);
       SNSPC_ENDOP(2);

	SNSPC_OP(0xB0, 2);
		// BCS
		SNSPC_BRREL(fC!=0);
       SNSPC_ENDOP(2);

	SNSPC_OP(0x50, 2);
		// BVC
		SNSPC_BRREL(!(r_P&SNSPC_FLAG_V));
       SNSPC_ENDOP(2);

	SNSPC_OP(0x70, 2);
		// BVS
		SNSPC_BRREL((r_P&SNSPC_FLAG_V));
       SNSPC_ENDOP(2);

	SNSPC_OP(0x2F, 4);
		// BRA
		SNSPC_BRA();
       SNSPC_ENDOP(4);


	SNSPC_OP(0x2E, 5);
		// CBNE dp,rel
		SNSPC_FETCH8(t0);
		SNSPC_ADD(t0,r_DP);
		SNSPC_READ8(t0,t1);
		SNSPC_GET_A8(t2);
		SNSPC_BRREL(t1!=t2);
       SNSPC_ENDOP(5);

	SNSPC_OP(0xDE, 6);
		// CBNE dp+X,rel
		SNSPC_FETCH8(t0);
		SNSPC_ADD(t0,r_X);
		SNSPC_AND(t0,0xFF);
		SNSPC_ADD(t0,r_DP);
		SNSPC_READ8(t0,t1);
		SNSPC_GET_A8(t2);
		SNSPC_BRREL(t1!=t2);
       SNSPC_ENDOP(6);


	SNSPC_OP(0x6E, 5);
		// DBNZ dp,rel
		SNSPC_FETCH8(t0);
		SNSPC_ADD(t0,r_DP);
		SNSPC_READ8(t0,t1);
		SNSPC_SUB(t1,1);
		SNSPC_WRITE8(t0,t1);
		SNSPC_BRREL(t1!=0);
       SNSPC_ENDOP(5);

	SNSPC_OP(0xFE, 4);
		// DBNZ Y,rel
		SNSPC_GET_Y8(t1);
		SNSPC_SUB(t1,1);
		SNSPC_SET_Y8(t1);
		SNSPC_BRREL(t1!=0);
       SNSPC_ENDOP(4);


	SNSPC_OP(0x9E, 12);
		SNSPC_GET_YA16(t0);
		SNSPC_GET_X8(t1);
		SNSPC_CLRFLAG_V();

		if (t1!=0)
		{
			t2 = t0 / t1;
			t1 = t0 % t1;
		} else 
		{	
			t1 = 0x0000;
			t2 = 0xFFFF;
		}
		// set flag on overflow ??
		if (t2 >= 0x100) 
		{
			SNSPC_SETFLAG_V();
		}

		SNSPC_SET_A8(t2);
		SNSPC_SET_Y8(t1);
		SNSPC_SETFLAG_N8(t2);
		SNSPC_SETFLAG_Z8(t2);
        SNSPC_ENDOP(12);

	SNSPC_OP(0x03, 5);
		SNSPC_BBS(0);
		break;

	SNSPC_OP(0x23, 5);
		SNSPC_BBS(1);
		break;

	SNSPC_OP(0x43, 5);
		SNSPC_BBS(2);
		break;

	SNSPC_OP(0x63, 5);
		SNSPC_BBS(3);
		break;

	SNSPC_OP(0x83, 5);
		SNSPC_BBS(4);
		break;

	SNSPC_OP(0xA3, 5);
		SNSPC_BBS(5);
		break;

	SNSPC_OP(0xC3, 5);
		SNSPC_BBS(6);
		break;

	SNSPC_OP(0xE3, 5);
		SNSPC_BBS(7);
		break;

	SNSPC_OP(0x13, 5);
		SNSPC_BBC(0);
		break;

	SNSPC_OP(0x33, 5);
		SNSPC_BBC(1);
		break;

	SNSPC_OP(0x53, 5);
		SNSPC_BBC(2);
		break;

	SNSPC_OP(0x73, 5);
		SNSPC_BBC(3);
		break;

	SNSPC_OP(0x93, 5);
		SNSPC_BBC(4);
		break;

	SNSPC_OP(0xB3, 5);
		SNSPC_BBC(5);
		break;

	SNSPC_OP(0xD3, 5);
		SNSPC_BBC(6);
		break;
	
	SNSPC_OP(0xF3, 5);
		SNSPC_BBC(7);
		break;


	SNSPC_OP(0xEF, 3);
		// SLEEP
		SNSPC_SUBCYCLES(3);
		break;

	SNSPC_OP(0xFF, 3);
		// STOP
		rPC--;
		SNSPC_SUBCYCLES(3);
		break;



		// MOV1 membit, C
	SNSPC_OP(0x0ca,5)
		SNSPC_FETCH16(t0);
		SNSPC_MOVE(t1,t0);
		SNSPC_GETI(t2,1);
		SNSPC_ANDI(t0,0x1FFF);
		SNSPC_SHRI(t1,13);
		SNSPC_SHL(t2,t1);
		SNSPC_READ8(t0,t1);

		if (fC & 1)
		{
			SNSPC_OR(t1,t2);
		} else
		{
			SNSPC_OR(t1,t2);
			SNSPC_XOR(t1,t2);
		}

		SNSPC_WRITE8(t0,t1);
		SNSPC_ENDOP(5)


	SNSPC_OP(0x0F, 8);
		// BRK
		SNSPC_SETFLAG_I();
		SNSPC_SETFLAG_B();
		SNSPC_GET_PC(t0);
		SNSPC_PUSH16(t0);
		SNSPC_GET_PSW8(t1);
		SNSPC_PUSH8(t1);
		SNSPC_READ16(SNSPC_VECTOR_BRK,t0);
		SNSPC_SET_PC16(t0);
        SNSPC_ENDOP(8);

	SNSPC_OP(0x01, 8);	SNSPC_TCALL(0);      SNSPC_ENDOP(8);
	SNSPC_OP(0x11, 8);	SNSPC_TCALL(1);      SNSPC_ENDOP(8);
	SNSPC_OP(0x21, 8);	SNSPC_TCALL(2);      SNSPC_ENDOP(8);
	SNSPC_OP(0x31, 8);	SNSPC_TCALL(3);      SNSPC_ENDOP(8);
	SNSPC_OP(0x41, 8);	SNSPC_TCALL(4);      SNSPC_ENDOP(8);
	SNSPC_OP(0x51, 8);	SNSPC_TCALL(5);      SNSPC_ENDOP(8);
	SNSPC_OP(0x61, 8);	SNSPC_TCALL(6);      SNSPC_ENDOP(8);
	SNSPC_OP(0x71, 8);	SNSPC_TCALL(7);      SNSPC_ENDOP(8);
	SNSPC_OP(0x81, 8);	SNSPC_TCALL(8);      SNSPC_ENDOP(8);
	SNSPC_OP(0x91, 8);	SNSPC_TCALL(9);      SNSPC_ENDOP(8);
	SNSPC_OP(0xA1, 8);	SNSPC_TCALL(10);      SNSPC_ENDOP(8);
	SNSPC_OP(0xB1, 8);	SNSPC_TCALL(11);      SNSPC_ENDOP(8);
	SNSPC_OP(0xC1, 8);	SNSPC_TCALL(12);      SNSPC_ENDOP(8);
	SNSPC_OP(0xD1, 8);	SNSPC_TCALL(13);      SNSPC_ENDOP(8);
	SNSPC_OP(0xE1, 8);	SNSPC_TCALL(14);      SNSPC_ENDOP(8);
	SNSPC_OP(0xF1, 8);	SNSPC_TCALL(15);      SNSPC_ENDOP(8);

		default:	// unimplemented opcode
			SNSPC_SUBCYCLES(1);
		}
	}

done:
	// backup one!
	rPC--;

	// restore registers
	SNSPC_PACKFLAGS();
	pCpu->Cycles	= nCycles;
	pCpu->Regs.rPC	= rPC;

	return 0;
}

