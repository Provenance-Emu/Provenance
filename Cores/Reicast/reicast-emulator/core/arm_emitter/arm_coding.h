/*
 * coding.h,	arm binary instruction coding
 *
 */
#pragma once

namespace ARM
{
	

	/*
	 *	Encoding Hi-Order 4bits, ConditionCode
	 *
	 */

	enum ConditionCode
	{
		EQ = 0x00,	Equal		= EQ,	// 0000		Equal								Z set
		NE = 0x01,	NotEqual	= NE,   // 0001		Not equal							Z clear
		CS = 0x02,	CarrySet	= CS,   // 0010		Carry set/unsigned higher or same	C set
		CC = 0x03,	CarryClr	= CC,   // 0011		Carry clear/unsigned lowe			C clear
		MI = 0x04,	Minus		= MI,   // 0100		Minus/negative						N set
		PL = 0x05,	Plus		= PL,   // 0101		Plus/positive or zero				N clear
		VS = 0x06,	Overflow	= VS,   // 0110		Overflow							V set
		VC = 0x07,	NoOverflow	= VC,   // 0111		No overflow							V clear

		HI = 0x08,	UnHigher	= HI,   // 1000		Unsigned higher						C set and Z clear
		LS = 0x09,	UnLower		= LS,   // 1001		Unsigned lower or same				C clear or Z set

		GE = 0x0A,	GrOrEqual	= GE,   // 1010		Signed greater than or equal		N set and V set, or N clear and V clear (N == V)
		LT = 0x0B,	Less		= LT,   // 1011		Signed less than					N set and V clear, or N clear and V set (N != V)
		GT = 0x0C,	Greater		= GT,   // 1100		Signed greater than					Z clear, and either N set and V set, or N clear and V clear (Z == 0,N == V)
		LE = 0x0D,	LessOrEqual	= LE,   // 1101		Signed less than or equal			Z set, or N set and V clear, or N clear and V set (Z == 1 or N != V)

		AL = 0x0E,	Always		= AL,   // 1110		Always (unconditional) -


		UC = 0x0F, Unconditional= UC,	// 1111		Unconditional Special Instruction for ARMv5? and above

#define _ARM_COMPAT
#if defined(_ARM_COMPAT)
		CC_EQ=EQ, CC_NE=NE, CC_CS=CS, CC_CC=CC, CC_MI=MI, CC_PL=PL, CC_VS=VS, CC_VC=VC,
		CC_HI=HI, CC_LS=LS, CC_GE=GE, CC_LT=LT, CC_GT=GT, CC_LE=LE, CC_AL=AL, CC_UC=UC,

		CC_HS=CS, CC_LO=CC,
#endif

		ConditionCode_Size
	};

	
	
	/*
	 *	Data-processing OPCODE 4bits, DPOP
	 *
	 */

	enum DPOP
	{
		DP_AND,	// 0000		Logical AND             				Rd := Rn AND shifter_operand
		DP_EOR,	// 0001		Logical Exclusive OR    				Rd := Rn EOR shifter_operand
		DP_SUB,	// 0010		Subtract                				Rd := Rn - shifter_operand
		DP_RSB,	// 0011		Reverse Subtract        				Rd := shifter_operand - Rn
		DP_ADD,	// 0100		Add                     				Rd := Rn + shifter_operand
		DP_ADC,	// 0101		Add with Carry          				Rd := Rn + shifter_operand + Carry Flag
		DP_SBC,	// 0110		Subtract with Carry     				Rd := Rn - shifter_operand - NOT(Carry Flag)
		DP_RSC,	// 0111		Reverse Subtract with Carry				Rd := shifter_operand - Rn - NOT(Carry Flag)
		DP_TST,	// 1000		Test Update flags after					Rn AND shifter_operand
		DP_TEQ,	// 1001		Test Equivalence Update flags after		Rn EOR shifter_operand
		DP_CMP,	// 1010		Compare Update flags after				Rn - shifter_operand
		DP_CMN,	// 1011		Compare Negated Update flags after		Rn + shifter_operand
		DP_ORR,	// 1100		Logical (inclusive) OR					Rd := Rn OR shifter_operand
		DP_MOV,	// 1101		Move									Rd := shifter_operand (no first operand)
		DP_BIC,	// 1110		Bit Clear               				Rd := Rn AND NOT(shifter_operand)
		DP_MVN	// 1111		Move Not                				Rd := NOT shifter_operand (no first operand)
	};



	enum ShiftOp {
		S_LSL,
		S_LSR,
		S_ASR,
		S_ROR,
		S_RRX=S_ROR
	};

	
	/*
	 *	eReg:		ARM Register ID
	 *
	 */
	enum eReg
	{
		r0=0,r1,  r2,  r3,
		r4,  r5,  r6,  r7,
		r8,  r9,  r10, r11,
		r12, r13, r14, r15,

		R0=0,R1,  R2,  R3,
		R4,  R5,  R6,  R7,
		R8,  R9,  R10, R11,
		R12, R13, R14, R15,

		// Aliases

		a1 = r0,    a2 = r1,    a3 = r2,    a4 = r3,
		A1 = R0,    A2 = R1,    A3 = R2,    A4 = R3,

		v1 = r4,    v2 = r5,    v3 = r6,    v4 = r7,	v5 = r8,    v6 = r9,
		V1 = R4,    V2 = R5,    V3 = R6,    V4 = R7,	V5 = R8,    V6 = R9,
		
		rfp = r9,	sl = r10,	fp = r11,	ip = r12,	sp = r13,	lr = r14,	pc = r15,
		RFP = R9,	SL = R10,	FP = R11,	IP = R12,	SP = R13,	LR = R14,	PC = R15,
	};


	
	/*
	 *	eFQReg:		Float [Quad] Register ID		(A.SIMD)
	 *
	 */
	enum eFQReg
	{
		q0=0,q1,  q2,  q3,
		q4,  q5,  q6,  q7,
		q8,  q9,  q10, q11,
		q12, q13, q14, q15,

		Q0=0,Q1,  Q2,  Q3,
		Q4,  Q5,  Q6,  Q7,
		Q8,  Q9,  Q10, Q11,
		Q12, Q13, Q14, Q15
	};
	

	/*
	 *	eFDReg:		Float [Double] Register ID		(VFP / A.SIMD)
	 *
	 */
	enum eFDReg
	{
		d0=0,d1,  d2,  d3,
		d4,  d5,  d6,  d7,
		d8,  d9,  d10, d11,
		d12, d13, d14, d15,
		d16, d17, d18, d19,
		d20, d21, d22, d23,
		d24, d25, d26, d27,
		d28, d29, d30, d31,

		D0=0,D1,  D2,  D3,
		D4,  D5,  D6,  D7,
		D8,  D9,  D10, D11,
		D12, D13, D14, D15,
		D16, D17, D18, D19,
		D20, D21, D22, D23,
		D24, D25, D26, D27,
		D28, D29, D30, D31
	};


	/*
	 *	eFSReg:		Float [Single] Register ID	(VFP)
	 *
	 *		Note:  Using [f,F]regN syntax to avoid clash with s{8,16,32} types.
	 */
	enum eFSReg
	{
		f0=0,f1,  f2,  f3,
		f4,  f5,  f6,  f7,
		f8,  f9,  f10, f11,
		f12, f13, f14, f15,
		f16, f17, f18, f19,
		f20, f21, f22, f23,
		f24, f25, f26, f27,
		f28, f29, f30, f31,

		F0=0,F1,  F2,  F3,
		F4,  F5,  F6,  F7,
		F8,  F9,  F10, F11,
		F12, F13, F14, F15,
		F16, F17, F18, F19,
		F20, F21, F22, F23,
		F24, F25, F26, F27,
		F28, F29, F30, F31
	};



	enum eFSpecialReg
	{

		// VM**

		FPINST = 9,
		FPINST2=10,

		FP_R_ERROR=0xFF
	};


	enum ePushPopReg
	{
		_r0 =0x0001,    _r1 =0x0002,    _r2 =0x0004,    _r3 =0x0008,
		_r4 =0x0010,    _r5 =0x0020,    _r6 =0x0040,    _r7 =0x0080,
		_r8 =0x0100,    _r9 =0x0200,    _r10=0x0400,    _r11=0x0800,
		_r12=0x1000,    _r13=0x2000,    _r14=0x4000,    _r15=0x8000,

		_a1  = _r0,    _a2  = _r1,    _a3  = _r2,    _a4  = _r3,
		_v1  = _r4,    _v2  = _r5,    _v3  = _r6,    _v4  = _r7,
		_v5  = _r8,    _v6  = _r9,    _rfp = _r9,    _sl  = _r10,
		_fp  = _r11,   _ip  = _r12,   _sp  = _r13,   _lr  = _r14,
		_pc  = _r15,

		_push_all   = 0xFFFF,       // Save All 15
		_push_call  = _lr|_rfp,     // Save lr && _rfb(cycle count)

		_push_eabi  = _lr|_v1|_v2|_v3|_v4|_v5|_v6|_sl|_fp|_ip,  // this is guesswork ..
	};
	


	/// WIP ///

	struct FPReg
	{
		union
		{
			u8  vQ8[16];
			u8  vD8[8];
			u8  vS8[4];

			u16 vQ16[8];	// *VFP: If half-word extensions are enabled 
			u16 vD16[4];	// *VFP: If half-word extensions are enabled 
			u16 vS16[2];	// *VFP: If half-word extensions are enabled 

			u32 vQ32[4];
			u32 vD32[2];
			u32 S;

		//	u64 vQ64[2];
		//	u64 D;
		};

	};







};
