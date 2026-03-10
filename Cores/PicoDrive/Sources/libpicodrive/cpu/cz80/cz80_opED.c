/******************************************************************************
 *
 * CZ80 ED opcode include source file
 * CZ80 emulator version 0.9
 * Copyright 2004-2005 Stéphane Dallongeville
 *
 * (Modified by NJ)
 *
 *****************************************************************************/

#if CZ80_USE_JUMPTABLE
	goto *JumpTableED[Opcode];
#else
switch (Opcode)
{
#endif

/*-----------------------------------------
 ILLEGAL
-----------------------------------------*/

	OPED(0x00):
	OPED(0x01):
	OPED(0x02):
	OPED(0x03):
	OPED(0x04):
	OPED(0x05):
	OPED(0x06):
	OPED(0x07):
	OPED(0x08):
	OPED(0x09):
	OPED(0x0a):
	OPED(0x0b):
	OPED(0x0c):
	OPED(0x0d):
	OPED(0x0e):
	OPED(0x0f):

	OPED(0x10):
	OPED(0x11):
	OPED(0x12):
	OPED(0x13):
	OPED(0x14):
	OPED(0x15):
	OPED(0x16):
	OPED(0x17):
	OPED(0x18):
	OPED(0x19):
	OPED(0x1a):
	OPED(0x1b):
	OPED(0x1c):
	OPED(0x1d):
	OPED(0x1e):
	OPED(0x1f):

	OPED(0x20):
	OPED(0x21):
	OPED(0x22):
	OPED(0x23):
	OPED(0x24):
	OPED(0x25):
	OPED(0x26):
	OPED(0x27):
	OPED(0x28):
	OPED(0x29):
	OPED(0x2a):
	OPED(0x2b):
	OPED(0x2c):
	OPED(0x2d):
	OPED(0x2e):
	OPED(0x2f):

	OPED(0x30):
	OPED(0x31):
	OPED(0x32):
	OPED(0x33):
	OPED(0x34):
	OPED(0x35):
	OPED(0x36):
	OPED(0x37):
	OPED(0x38):
	OPED(0x39):
	OPED(0x3a):
	OPED(0x3b):
	OPED(0x3c):
	OPED(0x3d):
	OPED(0x3e):
	OPED(0x3f):

	OPED(0x77):
	OPED(0x7f):

	OPED(0x80):
	OPED(0x81):
	OPED(0x82):
	OPED(0x83):
	OPED(0x84):
	OPED(0x85):
	OPED(0x86):
	OPED(0x87):
	OPED(0x88):
	OPED(0x89):
	OPED(0x8a):
	OPED(0x8b):
	OPED(0x8c):
	OPED(0x8d):
	OPED(0x8e):
	OPED(0x8f):

	OPED(0x90):
	OPED(0x91):
	OPED(0x92):
	OPED(0x93):
	OPED(0x94):
	OPED(0x95):
	OPED(0x96):
	OPED(0x97):
	OPED(0x98):
	OPED(0x99):
	OPED(0x9a):
	OPED(0x9b):
	OPED(0x9c):
	OPED(0x9d):
	OPED(0x9e):
	OPED(0x9f):

	OPED(0xa4):
	OPED(0xa5):
	OPED(0xa6):
	OPED(0xa7):

	OPED(0xac):
	OPED(0xad):
	OPED(0xae):
	OPED(0xaf):

	OPED(0xb4):
	OPED(0xb5):
	OPED(0xb6):
	OPED(0xb7):

	OPED(0xbc):
	OPED(0xbd):
	OPED(0xbe):
	OPED(0xbf):

	OPED(0xc0):
	OPED(0xc1):
	OPED(0xc2):
	OPED(0xc3):
	OPED(0xc4):
	OPED(0xc5):
	OPED(0xc6):
	OPED(0xc7):
	OPED(0xc8):
	OPED(0xc9):
	OPED(0xca):
	OPED(0xcb):
	OPED(0xcc):
	OPED(0xcd):
	OPED(0xce):
	OPED(0xcf):

	OPED(0xd0):
	OPED(0xd1):
	OPED(0xd2):
	OPED(0xd3):
	OPED(0xd4):
	OPED(0xd5):
	OPED(0xd6):
	OPED(0xd7):
	OPED(0xd8):
	OPED(0xd9):
	OPED(0xda):
	OPED(0xdb):
	OPED(0xdc):
	OPED(0xdd):
	OPED(0xde):
	OPED(0xdf):

	OPED(0xe0):
	OPED(0xe1):
	OPED(0xe2):
	OPED(0xe3):
	OPED(0xe4):
	OPED(0xe5):
	OPED(0xe6):
	OPED(0xe7):
	OPED(0xe8):
	OPED(0xe9):
	OPED(0xea):
	OPED(0xeb):
	OPED(0xec):
	OPED(0xed):
	OPED(0xee):
	OPED(0xef):

	OPED(0xf0):
	OPED(0xf1):
	OPED(0xf2):
	OPED(0xf3):
	OPED(0xf4):
	OPED(0xf5):
	OPED(0xf6):
	OPED(0xf7):
	OPED(0xf8):
	OPED(0xf9):
	OPED(0xfa):
	OPED(0xfb):
	OPED(0xfc):
	OPED(0xfd):
	OPED(0xfe):
	OPED(0xff):
		RET(4)

/*-----------------------------------------
 LD r8
-----------------------------------------*/

	OPED(0x47): // LD   I,A
		zI = zA;
		RET(5)

	OPED(0x4f): // LD   R,A
#if CZ80_EMULATE_R_EXACTLY
		zR = zA;
#else
		zR = zA - ((cycles - CPU->ICount) >> 2);
#endif
		zR2 = zA & 0x80;
		RET(5)

	OPED(0x57): // LD   A,I
		zA = zI;
		zF = (zF & CF) | SZ[zA] | zIFF2;
		RET(5)

	OPED(0x5f): // LD   A,R
#if CZ80_EMULATE_R_EXACTLY
		zA = (zR & 0x7f) | zR2;
#else
		zA = ((zR + ((cycles - CPU->ICount) >> 2)) & 0x7f) | zR2;
#endif
		zF = (zF & CF) | SZ[zA] | zIFF2;
		RET(5)

/*-----------------------------------------
 LD r16
-----------------------------------------*/

	OPED(0x43): // LD   (w),BC
		data = pzBC;
		goto OP_LD_mNN_xx;

	OPED(0x53): // LD   (w),DE
		data = pzDE;
		goto OP_LD_mNN_xx;

	OPED(0x63): // LD   (w),HL
		data = pzHL;
		goto OP_LD_mNN_xx;

	OPED(0x73): // LD   (w),SP
		data = pzSP;
		goto OP_LD_mNN_xx;

	OPED(0x4b): // LD   BC,(w)
		data = pzBC;
		goto OP_LD_xx_mNN;

	OPED(0x5b): // LD   DE,(w)
		data = pzDE;
		goto OP_LD_xx_mNN;

	OPED(0x6b): // LD   HL,(w)
		data = pzHL;
		goto OP_LD_xx_mNN;

	OPED(0x7b): // LD   SP,(w)
		data = pzSP;
		goto OP_LD_xx_mNN;

/*-----------------------------------------
 NEG
-----------------------------------------*/

	OPED(0x44): // NEG
	OPED(0x4c): // NEG
	OPED(0x54): // NEG
	OPED(0x5c): // NEG
	OPED(0x64): // NEG
	OPED(0x6c): // NEG
	OPED(0x74): // NEG
	OPED(0x7c): // NEG
		val = zA;
		zA = 0;
		goto OP_SUB;

/*-----------------------------------------
 RRD
-----------------------------------------*/

	OPED(0x67): // RRD  (HL)
		adr = zHL;
		val = READ_MEM8(adr);
		WRITE_MEM8(adr, (val >> 4) | (zA << 4));
		zA = (zA & 0xf0) | (val & 0x0f);
		zF = (zF & CF) | SZP[zA];
		RET(14)

/*-----------------------------------------
 RLD
-----------------------------------------*/

	OPED(0x6f): // RLD  (HL)
		adr = zHL;
		val = READ_MEM8(adr);
		WRITE_MEM8(adr, (val << 4) | (zA & 0x0f));
		zA = (zA & 0xf0) | (val >> 4);
		zF = (zF & CF) | SZP[zA];
		RET(14)

/*-----------------------------------------
 ADC 16
-----------------------------------------*/

	OPED(0x7a): // ADC  HL,SP
		val = zSP;
		goto OP_ADC16;

	OPED(0x4a): // ADC  HL,BC
	OPED(0x5a): // ADC  HL,DE
	OPED(0x6a): // ADC  HL,HL
		val = zR16((Opcode >> 4) & 3);

OP_ADC16:
		res = zHL + val + (zF & CF);
		zF = (((zHL ^ res ^ val) >> 8) & HF) |
			((res >> 16) & CF) |
			((res >> 8) & (SF | YF | XF)) |
			((res & 0xffff) ? 0 : ZF) |
			(((val ^ zHL ^ 0x8000) & (val ^ res) & 0x8000) >> 13);
		zHL = (UINT16)res;
		RET(11)

/*-----------------------------------------
 SBC 16
-----------------------------------------*/

	OPED(0x72): // SBC  HL,SP
		val = zSP;
		goto OP_SBC16;

	OPED(0x42): // SBC  HL,BC
	OPED(0x52): // SBC  HL,DE
	OPED(0x62): // SBC  HL,HL
		val = zR16((Opcode >> 4) & 3);

OP_SBC16:
		res = zHL - val - (zF & CF);
		zF = (((zHL ^ res ^ val) >> 8) & HF) | NF |
			((res >> 16) & CF) |
			((res >> 8) & (SF | YF | XF)) |
			((res & 0xffff) ? 0 : ZF) |
			(((val ^ zHL) & (zHL ^ res) & 0x8000) >> 13);
		zHL = (UINT16)res;
		RET(11)

/*-----------------------------------------
 IN
-----------------------------------------*/

	OPED(0x40): // IN   B,(C)
	OPED(0x48): // IN   C,(C)
	OPED(0x50): // IN   D,(C)
	OPED(0x58): // IN   E,(C)
	OPED(0x60): // IN   H,(C)
	OPED(0x68): // IN   L,(C)
	OPED(0x78): // IN   E,(C)
		res = IN(zBC);
		zR8((Opcode >> 3) & 7) = res;
		zF = (zF & CF) | SZP[res];
		RET(8)

	OPED(0x70): // IN   0,(C)
		res = IN(zBC);
		zF = (zF & CF) | SZP[res];
		RET(8)

/*-----------------------------------------
 OUT
-----------------------------------------*/

	OPED(0x51): // OUT  (C),D
	OPED(0x41): // OUT  (C),B
	OPED(0x49): // OUT  (C),C
	OPED(0x59): // OUT  (C),E
	OPED(0x61): // OUT  (C),H
	OPED(0x69): // OUT  (C),L
	OPED(0x79): // OUT  (C),E
		res = zR8((Opcode >> 3) & 7);
		OUT(zBC, res);
		RET(8)

	OPED(0x71): // OUT  (C),0
		OUT(zBC, 0);
		RET(8)

/*-----------------------------------------
 RETI/RETN
-----------------------------------------*/

	// works the same, but Z80 PIO can detect the opcode
	OPED(0x45): // RETN
	OPED(0x55): // RETN
	OPED(0x65): // RETN
	OPED(0x75): // RETN

	OPED(0x4d): // RETI
	OPED(0x5d): // RETI
	OPED(0x6d): // RETI
	OPED(0x7d): // RETI
		POP_16(res);
		SET_PC(res);
		if (!zIFF1 && zIFF2)
		{
			if (CPU->IRQState)
			{
				CPU->Status |= CZ80_HAS_INT;
			}
		}
		zIFF1 = zIFF2;
		RET(10)

/*-----------------------------------------
 IM
-----------------------------------------*/

	OPED(0x46): // IM   0
	OPED(0x4e): // IM   0
	OPED(0x66): // IM   0
	OPED(0x6e): // IM   0
		zIM = 0;
		RET(4)

	OPED(0x56): // IM   1
	OPED(0x76): // IM   1
		zIM = 1;
		RET(4)

	OPED(0x5e): // IM   2
	OPED(0x7e): // IM   2
		zIM = 2;
		RET(4)

	{
		UINT8 val;
		UINT8 res;
		UINT8 F;

/*-----------------------------------------
 LDI/LDD
-----------------------------------------*/

	OPED(0xa0): // LDI
		val = READ_MEM8(zHL++);
		WRITE_MEM8(zDE++, val);
		goto OP_LDX;

	OPED(0xa8): // LDD
		val = READ_MEM8(zHL--);
		WRITE_MEM8(zDE--, val);

OP_LDX:
		F = zF & (SF | ZF | CF);
		if ((zA + val) & 0x02) F |= YF;
		if ((zA + val) & 0x08) F |= XF;
		if (--zBC) F |= VF;
		zF = F;
		RET(12)

/*-----------------------------------------
 LDIR/LDDR
-----------------------------------------*/

	OPED(0xb0): // LDIR
		do
		{
			val = READ_MEM8(zHL++);
			WRITE_MEM8(zDE++, val);
			zBC--;
			USE_CYCLES(21)
		} while (zBC && (CPU->ICount > -4) && !CPU->Status);
		goto OP_LDXR;

	OPED(0xb8): // LDDR
		do
		{
			val = READ_MEM8(zHL--);
			WRITE_MEM8(zDE--, val);
			zBC--;
			USE_CYCLES(21)
		} while (zBC && (CPU->ICount > -4) && !CPU->Status);

OP_LDXR:
		F = zF & (SF | ZF | CF);
		if ((zA + val) & 0x02) F |= YF;
		if ((zA + val) & 0x08) F |= XF;
		if (zBC)
		{
			zF = F | VF;
			PC -= 2;
#if CZ80_EMULATE_R_EXACTLY
			zR--;
#endif
			ADD_CYCLES(4)
			goto Cz80_Exec;
		}
		zF = F;
		ADD_CYCLES(4+5)
		goto Cz80_Exec;

/*-----------------------------------------
 CPI/CPD
-----------------------------------------*/

	OPED(0xa1): // CPI
		val = READ_MEM8(zHL++);
		goto OP_CPX;

	OPED(0xa9): // CPD
		val = READ_MEM8(zHL--);

OP_CPX:
		res = zA - val;
		F = (zF & CF) | (SZ[res] & ~(YF | XF)) | ((zA ^ val ^ res) & HF) | NF;
		if (F & HF) res--;
		if (res & 0x02) F |= YF;
		if (res & 0x08) F |= XF;
		if (--zBC) F |= VF;
		zF = F;
		RET(12)

/*-----------------------------------------
 CPIR/CPDR
-----------------------------------------*/

	OPED(0xb1): // CPIR
		do
		{
			val = READ_MEM8(zHL++);
			res = zA - val;
			zBC--;
			F = (zF & CF) | (SZ[res] & ~(YF | XF)) | ((zA ^ val ^ res) & HF) | NF;
			if (F & HF) res--;
			if (res & 0x02) F |= YF;
			if (res & 0x08) F |= XF;
			if (zBC) F |= VF;
			zF = F;
			USE_CYCLES(21)
		} while (zBC && !(F & ZF) && (CPU->ICount > -4) && !CPU->Status);
		goto OP_CPXR;

	OPED(0xb9): // CPDR
		do
		{
			val = READ_MEM8(zHL--);
			res = zA - val;
			zBC--;
			F = (zF & CF) | (SZ[res] & ~(YF | XF)) | ((zA ^ val ^ res) & HF) | NF;
			if (F & HF) res--;
			if (res & 0x02) F |= YF;
			if (res & 0x08) F |= XF;
			if (zBC) F |= VF;
			zF = F;
			USE_CYCLES(21)
		} while (zBC && !(F & ZF) && (CPU->ICount > -4) && !CPU->Status);

OP_CPXR:
		if (zBC && !(F & ZF))
		{
			PC -= 2;
#if CZ80_EMULATE_R_EXACTLY
			zR--;
#endif
			ADD_CYCLES(4)
			goto Cz80_Exec;
		}
		ADD_CYCLES(4+5)
		goto Cz80_Exec;

/*-----------------------------------------
 INI/IND
-----------------------------------------*/

	OPED(0xa2): // INI
		val = IN(zBC);
		zB--;
		WRITE_MEM8(zHL++, val);
		goto OP_INX;

	OPED(0xaa): // IND
		val = IN(zBC);
		zB--;
		WRITE_MEM8(zHL--, val);

OP_INX:
		F = SZ[zB];
		res = ((UINT32)(zC - 1) & 0xff) + (UINT32)val;
		if (val & SF) F |= NF;
		if (res < val) F |= HF | CF;
		F |= SZP[(UINT8)(res & 0x07) ^ zB] & PF;
		zF = F;
		RET(12)

/*-----------------------------------------
 INIR/INDR
-----------------------------------------*/

	OPED(0xb2): // INIR
		do
		{
			val = IN(zBC);
			zB--;
			WRITE_MEM8(zHL++, val);
			USE_CYCLES(21)
		} while (zB && (CPU->ICount > -4) && !CPU->Status);
		goto OP_INXR;

	OPED(0xba): // INDR
		do
		{
			val = IN(zBC);
			zB--;
			WRITE_MEM8(zHL--, val);
			USE_CYCLES(21)
		} while (zB && (CPU->ICount > -4) && !CPU->Status);

OP_INXR:
		F = SZ[zB];
		res = ((UINT32)(zC - 1) & 0xff) + (UINT32)val;
		if (val & SF) F |= NF;
		if (res < val) F |= HF | CF;
		F |= SZP[(UINT8)(res & 0x07) ^ zB] & PF;
		zF = F;
		if (zB)
		{
			PC -= 2;
#if CZ80_EMULATE_R_EXACTLY
			zR--;
#endif
			ADD_CYCLES(4)
			goto Cz80_Exec;
		}
		ADD_CYCLES(4+5);
		goto Cz80_Exec;

/*-----------------------------------------
 OUTI/OUTD
-----------------------------------------*/

	OPED(0xa3): // OUTI
		val = READ_MEM8(zHL++);
		zB--;
		OUT(zBC, val);
		goto OP_OUTX;

	OPED(0xab): // OUTD
		val = READ_MEM8(zHL--);
		zB--;
		OUT(zBC, val);

OP_OUTX:
		F = SZ[zB];
		res = (UINT32)zL + (UINT32)val;
		if (val & SF) F |= NF;
		if (res < val) F |= HF | CF;
		F |= SZP[(UINT8)(res & 0x07) ^ zB] & PF;
		zF = F;
		RET(12)

/*-----------------------------------------
 OTIR/OTDR
-----------------------------------------*/

	OPED(0xb3): // OTIR
		do
		{
			val = READ_MEM8(zHL++);
			zB--;
			OUT(zBC, val);
			USE_CYCLES(21)
		} while (zB && (CPU->ICount > -4) && !CPU->Status);
		goto OP_OTXR;

	OPED(0xbb): // OTDR
		do
		{
			val = READ_MEM8(zHL--);
			zB--;
			OUT(zBC, val);
			USE_CYCLES(21)
		} while (zB && (CPU->ICount > -4) && !CPU->Status);

OP_OTXR:
		F = SZ[zB];
		res = (UINT32)zL + (UINT32)val;
		if (val & SF) F |= NF;
		if (res < val) F |= HF | CF;
		F |= SZP[(UINT8)(res & 0x07) ^ zB] & PF;
		zF = F;
		if (zB)
		{
			PC -= 2;
#if CZ80_EMULATE_R_EXACTLY
			zR--;
#endif
			ADD_CYCLES(4)
			goto Cz80_Exec;
		}
		ADD_CYCLES(4+5)
		goto Cz80_Exec;
	}

#if !CZ80_USE_JUMPTABLE
}
#endif
