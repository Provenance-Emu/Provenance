/******************************************************************************
 *
 * CZ80 opcode include source file
 * CZ80 emulator version 0.9
 * Copyright 2004-2005 Stéphane Dallongeville
 *
 * (Modified by NJ)
 *
 *****************************************************************************/

#if CZ80_USE_JUMPTABLE
	goto *JumpTable[Opcode];
#else
switch (Opcode)
{
#endif

/*-----------------------------------------
 NOP
-----------------------------------------*/

	OP(0x00):   // NOP

/*-----------------------------------------
 LD r8 (same register)
-----------------------------------------*/

	OP(0x40):   // LD   B,B
	OP(0x49):   // LD   C,C
	OP(0x52):   // LD   D,D
	OP(0x5b):   // LD   E,E
	OP(0x64):   // LD   H,H
	OP(0x6d):   // LD   L,L
	OP(0x7f):   // LD   A,A
		RET(4)

/*-----------------------------------------
 LD r8
-----------------------------------------*/

	OP(0x41):   // LD   B,C
	OP(0x42):   // LD   B,D
	OP(0x43):   // LD   B,E
	OP(0x44):   // LD   B,H
	OP(0x45):   // LD   B,L
	OP(0x47):   // LD   B,A

	OP(0x48):   // LD   C,B
	OP(0x4a):   // LD   C,D
	OP(0x4b):   // LD   C,E
	OP(0x4c):   // LD   C,H
	OP(0x4d):   // LD   C,L
	OP(0x4f):   // LD   C,A

	OP(0x50):   // LD   D,B
	OP(0x51):   // LD   D,C
	OP(0x53):   // LD   D,E
	OP(0x54):   // LD   D,H
	OP(0x55):   // LD   D,L
	OP(0x57):   // LD   D,A

	OP(0x58):   // LD   E,B
	OP(0x59):   // LD   E,C
	OP(0x5a):   // LD   E,D
	OP(0x5c):   // LD   E,H
	OP(0x5d):   // LD   E,L
	OP(0x5f):   // LD   E,A

	OP(0x60):   // LD   H,B
	OP(0x61):   // LD   H,C
	OP(0x62):   // LD   H,D
	OP(0x63):   // LD   H,E
	OP(0x65):   // LD   H,L
	OP(0x67):   // LD   H,A

	OP(0x68):   // LD   L,B
	OP(0x69):   // LD   L,C
	OP(0x6a):   // LD   L,D
	OP(0x6b):   // LD   L,E
	OP(0x6c):   // LD   L,H
	OP(0x6f):   // LD   L,A

	OP(0x78):   // LD   A,B
	OP(0x79):   // LD   A,C
	OP(0x7a):   // LD   A,D
	OP(0x7b):   // LD   A,E
	OP(0x7c):   // LD   A,H
	OP(0x7d):   // LD   A,L
OP_LD_R_R:
		zR8((Opcode >> 3) & 7) = zR8(Opcode & 7);
		RET(4)

	OP(0x06):   // LD   B,#imm
	OP(0x0e):   // LD   C,#imm
	OP(0x16):   // LD   D,#imm
	OP(0x1e):   // LD   E,#imm
	OP(0x26):   // LD   H,#imm
	OP(0x2e):   // LD   L,#imm
	OP(0x3e):   // LD   A,#imm
OP_LD_R_imm:
		zR8(Opcode >> 3) = READ_ARG();
		RET(7)

	OP(0x46):   // LD   B,(HL)
	OP(0x4e):   // LD   C,(HL)
	OP(0x56):   // LD   D,(HL)
	OP(0x5e):   // LD   E,(HL)
	OP(0x66):   // LD   H,(HL)
	OP(0x6e):   // LD   L,(HL)
	OP(0x7e):   // LD   A,(HL)
		zR8((Opcode >> 3) & 7) = READ_MEM8(zHL);
		RET(7)

	OP(0x70):   // LD   (HL),B
	OP(0x71):   // LD   (HL),C
	OP(0x72):   // LD   (HL),D
	OP(0x73):   // LD   (HL),E
	OP(0x74):   // LD   (HL),H
	OP(0x75):   // LD   (HL),L
	OP(0x77):   // LD   (HL),A
		WRITE_MEM8(zHL, zR8(Opcode & 7));
		RET(7)

	OP(0x36):   // LD (HL), #imm
		WRITE_MEM8(zHL, READ_ARG());
		RET(10)

	OP(0x0a):   // LD   A,(BC)
OP_LOAD_A_mBC:
		adr = zBC;
		goto OP_LOAD_A_mxx;

	OP(0x1a):   // LD   A,(DE)
OP_LOAD_A_mDE:
		adr = zDE;

OP_LOAD_A_mxx:
		zA = READ_MEM8(adr);
		RET(7)

	OP(0x3a):   // LD   A,(nn)
OP_LOAD_A_mNN:
		adr = READ_ARG16();
		zA = READ_MEM8(adr);
		RET(13)

	OP(0x02):   // LD   (BC),A
OP_LOAD_mBC_A:
		adr = zBC;
		goto OP_LOAD_mxx_A;

	OP(0x12):   // LD   (DE),A
OP_LOAD_mDE_A:
		adr = zDE;

OP_LOAD_mxx_A:
		WRITE_MEM8(adr, zA);
		RET(7)

	OP(0x32):   // LD   (nn),A
OP_LOAD_mNN_A:
		adr = READ_ARG16();
		WRITE_MEM8(adr, zA);
		RET(13)

/*-----------------------------------------
 LD r16
-----------------------------------------*/

	OP(0x01):   // LD   BC,nn
	OP(0x11):   // LD   DE,nn
	OP(0x21):   // LD   HL,nn
OP_LOAD_RR_imm16:
		zR16(Opcode >> 4) = READ_ARG16();
		RET(10)

	OP(0x31):   // LD   SP,nn
OP_LOAD_SP_imm16:
		zSP = READ_ARG16();
		RET(10)

	OP(0xf9):   // LD   SP,HL
OP_LD_SP_xx:
		zSP = data->W;
		RET(6)

	OP(0x2a):   // LD   HL,(nn)
OP_LD_xx_mNN:
		adr = READ_ARG16();
		data->W = READ_MEM16(adr);
		RET(16)

	OP(0x22):   // LD   (nn),HL
OP_LD_mNN_xx:
		adr = READ_ARG16();
		WRITE_MEM16(adr, data->W);
		RET(16)

/*-----------------------------------------
 POP
-----------------------------------------*/

	OP(0xc1):   // POP  BC
	OP(0xd1):   // POP  DE
	OP(0xf1):   // POP  AF
OP_POP_RR:
		data = CPU->pzR16[(Opcode >> 4) & 3];

	OP(0xe1):   // POP  HL
OP_POP:
		POP_16(data->W)
		RET(10)

/*-----------------------------------------
 PUSH
-----------------------------------------*/

	OP(0xc5):   // PUSH BC
	OP(0xd5):   // PUSH DE
	OP(0xf5):   // PUSH AF
OP_PUSH_RR:
		data = CPU->pzR16[(Opcode >> 4) & 3];

	OP(0xe5):   // PUSH HL
OP_PUSH:
		PUSH_16(data->W);
		RET(11)

/*-----------------------------------------
 EX
-----------------------------------------*/

	OP(0x08):   // EX   AF,AF'
OP_EX_AF_AF2:
		res = zAF;
		zAF = zAF2;
		zAF2 = res;
		RET(4)

	OP(0xeb):   // EX   DE,HL
OP_EX_DE_HL:
		res = zDE;
		zDE = zHL;
		zHL = res;
		RET(4)

	OP(0xd9):   // EXX
OP_EXX:
		res = zBC;
		zBC = zBC2;
		zBC2 = res;
		res = zDE;
		zDE = zDE2;
		zDE2 = res;
		res = zHL;
		zHL = zHL2;
		zHL2 = res;
		RET(4)

	OP(0xe3):   // EX   HL,(SP)
OP_EX_xx_mSP:
		adr = zSP;
		res = data->W;
		data->W = READ_MEM16(adr);
		WRITE_MEM16(adr, res);
		RET(19)

/*-----------------------------------------
 INC r8
-----------------------------------------*/

	OP(0x04):   // INC  B
	OP(0x0c):   // INC  C
	OP(0x14):   // INC  D
	OP(0x1c):   // INC  E
	OP(0x24):   // INC  H
	OP(0x2c):   // INC  L
	OP(0x3c):   // INC  A
OP_INC_R:
		zR8(Opcode >> 3)++;
		zF = (zF & CF) | SZHV_inc[zR8(Opcode >> 3)];
		RET(4)

	OP(0x34):   // INC  (HL)
		adr = zHL;

OP_INC_m:
		res = READ_MEM8(adr);
		res = (res + 1) & 0xff;
		zF = (zF & CF) | SZHV_inc[res];
		WRITE_MEM8(adr, res);
		RET(11)

/*-----------------------------------------
 DEC r8
-----------------------------------------*/

	OP(0x05):   // DEC  B
	OP(0x0d):   // DEC  C
	OP(0x15):   // DEC  D
	OP(0x1d):   // DEC  E
	OP(0x25):   // DEC  H
	OP(0x2d):   // DEC  L
	OP(0x3d):   // DEC  A
OP_DEC_R:
		zR8(Opcode >> 3)--;
		zF = (zF & CF) | SZHV_dec[zR8(Opcode >> 3)];
		RET(4)

	OP(0x35):   // DEC  (HL)
		adr = zHL;

OP_DEC_m:
		res = READ_MEM8(adr);
		res = (res - 1) & 0xff;
		zF = (zF & CF) | SZHV_dec[res];
		WRITE_MEM8(adr, res);
		RET(11)

/*-----------------------------------------
 ADD r8
-----------------------------------------*/

	OP(0x86):   // ADD  A,(HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_ADD;

	OP(0xc6):   // ADD  A,n
OP_ADD_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_ADD;

	OP(0x80):   // ADD  A,B
	OP(0x81):   // ADD  A,C
	OP(0x82):   // ADD  A,D
	OP(0x83):   // ADD  A,E
	OP(0x84):   // ADD  A,H
	OP(0x85):   // ADD  A,L
	OP(0x87):   // ADD  A,A
OP_ADD_R:
		val = zR8(Opcode & 7);

OP_ADD:
#if CZ80_BIG_FLAGS_ARRAY
		{
			UINT16 A = zA;
			res = (UINT8)(A + val);
			zF = SZHVC_add[(A << 8) | res];
			zA = res;
		}
#else
		res = zA + val;
		zF = SZ[(UINT8)res] | ((res >> 8) & CF) |
			((zA ^ res ^ val) & HF) |
			(((val ^ zA ^ 0x80) & (val ^ res) & 0x80) >> 5);
		zA = res;
#endif
		RET(4)

/*-----------------------------------------
 ADC r8
-----------------------------------------*/

	OP(0x8e):   // ADC  A,(HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_ADC;

	OP(0xce):   // ADC  A,n
OP_ADC_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_ADC;

	OP(0x88):   // ADC  A,B
	OP(0x89):   // ADC  A,C
	OP(0x8a):   // ADC  A,D
	OP(0x8b):   // ADC  A,E
	OP(0x8c):   // ADC  A,H
	OP(0x8d):   // ADC  A,L
	OP(0x8f):   // ADC  A,A
OP_ADC_R:
		val = zR8(Opcode & 7);

OP_ADC:
#if CZ80_BIG_FLAGS_ARRAY
		{
			UINT8 A = zA;
			UINT8 c = zF & CF;
			res = (UINT8)(A + val + c);
			zF = SZHVC_add[(c << 16) | (A << 8) | res];
			zA = res;
		}
#else
		res = zA + val + (zF & CF);
		zF = SZ[res & 0xff] | ((res >> 8) & CF) |
			((zA ^ res ^ val) & HF) |
			(((val ^ zA ^ 0x80) & (val ^ res) & 0x80) >> 5);
		zA = res;
#endif
		RET(4)

/*-----------------------------------------
 SUB r8
-----------------------------------------*/

	OP(0x96):   // SUB  (HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_SUB;

	OP(0xd6):   // SUB  A,n
OP_SUB_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_SUB;

	OP(0x90):   // SUB  B
	OP(0x91):   // SUB  C
	OP(0x92):   // SUB  D
	OP(0x93):   // SUB  E
	OP(0x94):   // SUB  H
	OP(0x95):   // SUB  L
	OP(0x97):   // SUB  A
OP_SUB_R:
		val = zR8(Opcode & 7);

OP_SUB:
#if CZ80_BIG_FLAGS_ARRAY
		{
			UINT8 A = zA;
			res = (UINT8)(A - val);
			zF = SZHVC_sub[(A << 8) | res];
			zA = res;
		}
#else
		res = zA - val;
		zF = SZ[res & 0xff] | ((res >> 8) & CF) | NF |
			((zA ^ res ^ val) & HF) |
			(((val ^ zA) & (zA ^ res) & 0x80) >> 5);
		zA = res;
#endif
		RET(4)

/*-----------------------------------------
 SBC r8
-----------------------------------------*/

	OP(0x9e):   // SBC  A,(HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_SBC;

	OP(0xde):   // SBC  A,n
OP_SBC_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_SBC;

	OP(0x98):   // SBC  A,B
	OP(0x99):   // SBC  A,C
	OP(0x9a):   // SBC  A,D
	OP(0x9b):   // SBC  A,E
	OP(0x9c):   // SBC  A,H
	OP(0x9d):   // SBC  A,L
	OP(0x9f):   // SBC  A,A
OP_SBC_R:
		val = zR8(Opcode & 7);

OP_SBC:
#if CZ80_BIG_FLAGS_ARRAY
		{
			UINT8 A = zA;
			UINT8 c = zF & CF;
			res = (UINT8)(A - val - c);
			zF = SZHVC_sub[(c << 16) | (A << 8) | res];
			zA = res;
		}
#else
		res = zA - val - (zF & CF);
		zF = SZ[res & 0xff] | ((res >> 8) & CF) | NF |
			((zA ^ res ^ val) & HF) |
			(((val ^ zA) & (zA ^ res) & 0x80) >> 5);
		zA = res;
#endif
		RET(4)

/*-----------------------------------------
 CP r8
-----------------------------------------*/

	OP(0xbe):   // CP   (HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_CP;

	OP(0xfe):   // CP   n
OP_CP_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_CP;

	OP(0xb8):   // CP   B
	OP(0xb9):   // CP   C
	OP(0xba):   // CP   D
	OP(0xbb):   // CP   E
	OP(0xbc):   // CP   H
	OP(0xbd):   // CP   L
	OP(0xbf):   // CP   A
OP_CP_R:
		val = zR8(Opcode & 7);

OP_CP:
#if CZ80_BIG_FLAGS_ARRAY
		{
			UINT8 A = zA;
			res = (UINT8)(A - val);
			zF = (SZHVC_sub[(A << 8) | res] & ~(YF | XF)) |
				 (val & (YF | XF));
		}
#else
		res = zA - val;
		zF = (SZ[res & 0xff] & (SF | ZF)) |
			(val & (YF | XF)) | ((res >> 8) & CF) | NF |
			((zA ^ res ^ val) & HF) |
			(((val ^ zA) & (zA ^ res) >> 5) & VF);
#endif
		RET(4)

/*-----------------------------------------
 AND r8
-----------------------------------------*/

	OP(0xa6):   // AND  (HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_AND;

	OP(0xe6):   // AND  A,n
OP_AND_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_AND;

	OP(0xa0):   // AND  B
	OP(0xa1):   // AND  C
	OP(0xa2):   // AND  D
	OP(0xa3):   // AND  E
	OP(0xa4):   // AND  H
	OP(0xa5):   // AND  L
	OP(0xa7):   // AND  A
OP_AND_R:
		val = zR8(Opcode & 7);

OP_AND:
		zA &= val;
		zF = SZP[zA] | HF;
		RET(4)

/*-----------------------------------------
 XOR r8
-----------------------------------------*/

	OP(0xae):   // XOR  (HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_XOR;

	OP(0xee):   // XOR  A,n
OP_XOR_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_XOR;

	OP(0xa8):   // XOR  B
	OP(0xa9):   // XOR  C
	OP(0xaa):   // XOR  D
	OP(0xab):   // XOR  E
	OP(0xac):   // XOR  H
	OP(0xad):   // XOR  L
	OP(0xaf):   // XOR  A
OP_XOR_R:
		val = zR8(Opcode & 7);

OP_XOR:
		zA ^= val;
		zF = SZP[zA];
		RET(4)

/*-----------------------------------------
 OR r8
-----------------------------------------*/

	OP(0xb6):   // OR   (HL)
		val = READ_MEM8(zHL);
		USE_CYCLES(3)
		goto OP_OR;

	OP(0xf6):   // OR   A,n
OP_OR_imm:
		val = READ_ARG();
		USE_CYCLES(3)
		goto OP_OR;

	OP(0xb0):   // OR   B
	OP(0xb1):   // OR   C
	OP(0xb2):   // OR   D
	OP(0xb3):   // OR   E
	OP(0xb4):   // OR   H
	OP(0xb5):   // OR   L
	OP(0xb7):   // OR   A
OP_OR_R:
		val = zR8(Opcode & 7);

OP_OR:
		zA |= val;
		zF = SZP[zA];
		RET(4)

/*-----------------------------------------
 MISC ARITHMETIC & CPU CONTROL
-----------------------------------------*/

	OP(0x27):   // DAA
OP_DAA:
	{
		UINT8 F;
		UINT8 cf, nf, hf, lo, hi, diff;

		F = zF;
		cf = F & CF;
		nf = F & NF;
		hf = F & HF;
		lo = zA & 0x0f;
		hi = zA >> 4;

		if (cf)
		{
			diff = (lo <= 9 && !hf) ? 0x60 : 0x66;
		}
		else
		{
			if (lo >= 10)
			{
				diff = hi <= 8 ? 0x06 : 0x66;
			}
			else
			{
				if (hi >= 10)
				{
					diff = hf ? 0x66 : 0x60;
				}
				else
				{
					diff = hf ? 0x06 : 0x00;
				}
			}
		}
		if (nf) zA -= diff;
		else zA += diff;

		F = SZP[zA] | (F & NF);
		if (cf || (lo <= 9 ? hi >= 10 : hi >= 9)) F |= CF;
		if (nf ? hf && lo <= 5 : lo >= 10) F |= HF;
		zF = F;
		RET(4)
	}

	OP(0x2f):   // CPL
OP_CPL:
		zA ^= 0xff;
		zF = (zF & (SF | ZF | PF | CF)) | HF | NF | (zA & (YF | XF));
		RET(4)

	OP(0x37):   // SCF
OP_SCF:
		zF = (zF & (SF | ZF | PF)) | CF | (zA & (YF | XF));
		RET(4)

	OP(0x3f):   // CCF
OP_CCF:
		zF = ((zF & (SF | ZF | PF | CF)) | ((zF & CF) << 4) | (zA & (YF | XF))) ^ CF;
		RET(4)

	OP(0x76):   // HALT
OP_HALT:
		CPU->HaltState = 1;
		CPU->ICount = 0;
		goto Cz80_Check_Interrupt;

	OP(0xf3):   // DI
OP_DI:
		zIFF = 0;
		RET(4)

	OP(0xfb):   // EI
OP_EI:
		USE_CYCLES(4)
		if (!zIFF1)
		{
			zIFF1 = zIFF2 = (1 << 2);
			while (GET_OP() == 0xfb)
			{
				USE_CYCLES(4)
				PC++;
#if CZ80_EMULATE_R_EXACTLY
				zR++;
#endif
			}
			if (CPU->IRQState)
			{
				afterEI = 1;
				CPU->ExtraCycles += 1 - CPU->ICount;
				CPU->ICount = 1;
			}
		}
		else zIFF2 = (1 << 2);
		goto Cz80_Exec_nocheck;

/*-----------------------------------------
 INC r16
-----------------------------------------*/

	OP(0x03):   // INC  BC
OP_INC_BC:
		zBC++;
		RET(6)

	OP(0x13):   // INC  DE
OP_INC_DE:
		zDE++;
		RET(6)

	OP(0x23):   // INC  HL
OP_INC_xx:
		data->W++;
		RET(6)

	OP(0x33):   // INC  SP
OP_INC_SP:
		zSP++;
		RET(6)

/*-----------------------------------------
 DEC r16
-----------------------------------------*/

	OP(0x0b):   // DEC  BC
OP_DEC_BC:
		zBC--;
		RET(6)

	OP(0x1b):   // DEC  DE
OP_DEC_DE:
		zDE--;
		RET(6)

	OP(0x2b):   // DEC  HL
OP_DEC_xx:
		data->W--;
		RET(6)

	OP(0x3b):   // DEC  SP
OP_DEC_SP:
		zSP--;
		RET(6)

/*-----------------------------------------
 ADD r16
-----------------------------------------*/

	OP(0x39):   // ADD  xx,SP
OP_ADD16_xx_SP:
		val = zSP;
		goto OP_ADD16;

	OP(0x29):   // ADD  xx,xx
OP_ADD16_xx_xx:
		val = data->W;
		goto OP_ADD16;

	OP(0x09):   // ADD  xx,BC
OP_ADD16_xx_BC:
		val = zBC;
		goto OP_ADD16;

	OP(0x19):   // ADD  xx,DE
OP_ADD16_xx_DE:
		val = zDE;

OP_ADD16:
		res = data->W + val;
		zF = (zF & (SF | ZF | VF)) |
			(((data->W ^ res ^ val) >> 8) & HF) |
			((res >> 16) & CF) | ((res >> 8) & (YF | XF));
		data->W = (UINT16)res;
		RET(11)

/*-----------------------------------------
 ROTATE
-----------------------------------------*/

	{
		UINT8 A;
		UINT8 F;

	OP(0x07):   // RLCA
OP_RLCA:
		A = zA;
		zA = (A << 1) | (A >> 7);
		zF = (zF & (SF | ZF | PF)) | (zA & (YF | XF | CF));
		RET(4)

	OP(0x0f):   // RRCA
OP_RRCA:
		A = zA;
		F = zF;
		F = (F & (SF | ZF | PF)) | (A & CF);
		zA = (A >> 1) | (A << 7);
		zF = F | (zA & (YF | XF));
		RET(4)

	OP(0x17):   // RLA
OP_RLA:
		A = zA;
		F = zF;
		zA = (A << 1) | (F & CF);
		zF = (F & (SF | ZF | PF)) | (A >> 7) | (zA & (YF | XF));
		RET(4)

	OP(0x1f):   // RRA
OP_RRA:
		A = zA;
		F = zF;
		zA = (A >> 1) | (F << 7);
		zF = (F & (SF | ZF | PF)) | (A & CF) | (zA & (YF | XF));
		RET(4)
	}

/*-----------------------------------------
 JP
-----------------------------------------*/

	OP(0xc3):   // JP   nn
OP_JP:
		res = READ_ARG16();
		SET_PC(res);
		RET(10)

	OP(0xc2):   // JP   NZ,nn
OP_JP_NZ:
		if (!(zF & ZF)) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xca):   // JP   Z,nn
OP_JP_Z:
		if (zF & ZF) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xd2):   // JP   NC,nn
OP_JP_NC:
		if (!(zF & CF)) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xda):   // JP   C,nn
OP_JP_C:
		if (zF & CF) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xe2):   // JP   PO,nn
OP_JP_PO:
		if (!(zF & VF)) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xea):   // JP   PE,nn
OP_JP_PE:
		if (zF & VF) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xf2):   // JP   P,nn
OP_JP_P:
		if (!(zF & SF)) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xfa):   // JP   M,nn
OP_JP_M:
		if (zF & SF) goto OP_JP;
		PC += 2;
		RET(10)

	OP(0xe9):   // JP   (xx)
OP_JP_xx:
		res = data->W;
		SET_PC(res);
		RET(4)

/*-----------------------------------------
 JR
-----------------------------------------*/

	OP(0x10):   // DJNZ n
OP_DJNZ:
		USE_CYCLES(1)
		if (--zB) goto OP_JR;
		PC++;
		RET(7)

	OP(0x18):   // JR   n
OP_JR:
		adr = (INT8)READ_ARG();
		PC += (INT8)adr;
		RET(12)

	OP(0x20):   // JR   NZ,n
OP_JR_NZ:
		if (!(zF & ZF)) goto OP_JR;
		PC++;
		RET(7)

	OP(0x28):   // JR   Z,n
OP_JR_Z:
		if (zF & ZF) goto OP_JR;
		PC++;
		RET(7)

	OP(0x38):   // JR   C,n
OP_JR_C:
		if (zF & CF) goto OP_JR;
		PC++;
		RET(7)

	OP(0x30):   // JR   NC,n
OP_JR_NC:
		if (!(zF & CF)) goto OP_JR;
		PC++;
		RET(7)

/*-----------------------------------------
 CALL
-----------------------------------------*/

	OP(0xcd):   // CALL nn
OP_CALL:
		res = READ_ARG16();
		val = zRealPC;
		PUSH_16(val);
		SET_PC(res);
		RET(17)

	OP(0xc4):   // CALL NZ,nn
OP_CALL_NZ:
		if (!(zF & ZF)) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xcc):   // CALL Z,nn
OP_CALL_Z:
		if (zF & ZF) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xd4):   // CALL NC,nn
OP_CALL_NC:
		if (!(zF & CF)) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xdc):   // CALL C,nn
OP_CALL_C:
		if (zF & CF) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xe4):   // CALL PO,nn
OP_CALL_PO:
		if (!(zF & VF)) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xec):   // CALL PE,nn
OP_CALL_PE:
		if (zF & VF) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xf4):   // CALL P,nn
OP_CALL_P:
		if (!(zF & SF)) goto OP_CALL;
		PC += 2;
		RET(10)

	OP(0xfc):   // CALL M,nn
OP_CALL_M:
		if (zF & SF) goto OP_CALL;
		PC += 2;
		RET(10)

/*-----------------------------------------
 RET
-----------------------------------------*/

OP_RET_COND:
		USE_CYCLES(1)

	OP(0xc9):   // RET
OP_RET:
		POP_16(res);
		SET_PC(res);
		RET(10)

	OP(0xc0):   // RET  NZ
OP_RET_NZ:
		if (!(zF & ZF)) goto OP_RET_COND;
		RET(5)

	OP(0xc8):   // RET  Z
OP_RET_Z:
		if (zF & ZF) goto OP_RET_COND;
		RET(5)

	OP(0xd0):   // RET  NC
OP_RET_NC:
		if (!(zF & CF)) goto OP_RET_COND;
		RET(5)

	OP(0xd8):   // RET  C
OP_RET_C:
		if (zF & CF) goto OP_RET_COND;
		RET(5)

	OP(0xe0):   // RET  PO
OP_RET_PO:
		if (!(zF & VF)) goto OP_RET_COND;
		RET(5)

	OP(0xe8):   // RET  PE
OP_RET_PE:
		if (zF & VF) goto OP_RET_COND;
		RET(5)

	OP(0xf0):   // RET  P
OP_RET_P:
		if (!(zF & SF)) goto OP_RET_COND;
		RET(5)

	OP(0xf8):   // RET  M
OP_RET_M:
		if (zF & SF) goto OP_RET_COND;
		RET(5)

/*-----------------------------------------
 RST
-----------------------------------------*/

	OP(0xc7):   // RST  0
	OP(0xcf):   // RST  1
	OP(0xd7):   // RST  2
	OP(0xdf):   // RST  3
	OP(0xe7):   // RST  4
	OP(0xef):   // RST  5
	OP(0xf7):   // RST  6
	OP(0xff):   // RST  7
OP_RST:
		res = zRealPC;
		PUSH_16(res);
		res = Opcode & 0x38;
		SET_PC(res);
		RET(11)

/*-----------------------------------------
 OUT
-----------------------------------------*/

	OP(0xd3):   // OUT  (n),A
OP_OUT_mN_A:
		adr = (zA << 8) | READ_ARG();
		OUT(adr, zA);
		RET(11)

/*-----------------------------------------
 IN
-----------------------------------------*/

	OP(0xdb):   // IN   A,(n)
OP_IN_A_mN:
		adr = (zA << 8) | READ_ARG();
		zA = IN(adr);
		RET(11)

/*-----------------------------------------
 PREFIX
-----------------------------------------*/

	OP(0xcb):   // CB prefix (BIT & SHIFT INSTRUCTIONS)
	{
		UINT8 src;
		UINT8 res;

		Opcode = READ_OP();
#if CZ80_EMULATE_R_EXACTLY
		zR++;
#endif
		#include "cz80_opCB.c"
	}

	OP(0xed):   // ED prefix
ED_PREFIX:
		USE_CYCLES(4)
		Opcode = READ_OP();
#if CZ80_EMULATE_R_EXACTLY
		zR++;
#endif
		#include "cz80_opED.c"

	OP(0xdd):   // DD prefix (IX)
DD_PREFIX:
		data = pzIX;
		goto XY_PREFIX;

	OP(0xfd):   // FD prefix (IY)
FD_PREFIX:
		data = pzIY;

XY_PREFIX:
		USE_CYCLES(4)
		Opcode = READ_OP();
#if CZ80_EMULATE_R_EXACTLY
		zR++;
#endif
		#include "cz80_opXY.c"

#if !CZ80_USE_JUMPTABLE
}
#endif
