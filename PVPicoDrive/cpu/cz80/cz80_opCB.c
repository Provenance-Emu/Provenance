/******************************************************************************
 *
 * CZ80 CB opcode include source file
 * CZ80 emulator version 0.9
 * Copyright 2004-2005 Stéphane Dallongeville
 *
 * (Modified by NJ)
 *
 *****************************************************************************/

#if CZ80_USE_JUMPTABLE
	goto *JumpTableCB[Opcode];
#else
switch (Opcode)
{
#endif

/*-----------------------------------------
 RLC
-----------------------------------------*/

	OPCB(0x00): // RLC  B
	OPCB(0x01): // RLC  C
	OPCB(0x02): // RLC  D
	OPCB(0x03): // RLC  E
	OPCB(0x04): // RLC  H
	OPCB(0x05): // RLC  L
	OPCB(0x07): // RLC  A
		src = zR8(Opcode);
		res = (src << 1) | (src >> 7);
		zF = SZP[res] | (src >> 7);
		zR8(Opcode) = res;
		RET(8)

	OPCB(0x06): // RLC  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src << 1) | (src >> 7);
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 RRC
-----------------------------------------*/

	OPCB(0x08): // RRC  B
	OPCB(0x09): // RRC  C
	OPCB(0x0a): // RRC  D
	OPCB(0x0b): // RRC  E
	OPCB(0x0c): // RRC  H
	OPCB(0x0d): // RRC  L
	OPCB(0x0f): // RRC  A
		src = zR8(Opcode & 7);
		res = (src >> 1) | (src << 7);
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x0e): // RRC  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src >> 1) | (src << 7);
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 RL
-----------------------------------------*/

	OPCB(0x10): // RL   B
	OPCB(0x11): // RL   C
	OPCB(0x12): // RL   D
	OPCB(0x13): // RL   E
	OPCB(0x14): // RL   H
	OPCB(0x15): // RL   L
	OPCB(0x17): // RL   A
		src = zR8(Opcode & 7);
		res = (src << 1) | (zF & CF);
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x16): // RL   (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src << 1) | (zF & CF);
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 RR
-----------------------------------------*/

	OPCB(0x18): // RR   B
	OPCB(0x19): // RR   C
	OPCB(0x1a): // RR   D
	OPCB(0x1b): // RR   E
	OPCB(0x1c): // RR   H
	OPCB(0x1d): // RR   L
	OPCB(0x1f): // RR   A
		src = zR8(Opcode & 7);
		res = (src >> 1) | (zF << 7);
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x1e): // RR   (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src >> 1) | (zF << 7);
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 SLA
-----------------------------------------*/

	OPCB(0x20): // SLA  B
	OPCB(0x21): // SLA  C
	OPCB(0x22): // SLA  D
	OPCB(0x23): // SLA  E
	OPCB(0x24): // SLA  H
	OPCB(0x25): // SLA  L
	OPCB(0x27): // SLA  A
		src = zR8(Opcode & 7);
		res = src << 1;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x26): // SLA  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = src << 1;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 SRA
-----------------------------------------*/

	OPCB(0x28): // SRA  B
	OPCB(0x29): // SRA  C
	OPCB(0x2a): // SRA  D
	OPCB(0x2b): // SRA  E
	OPCB(0x2c): // SRA  H
	OPCB(0x2d): // SRA  L
	OPCB(0x2f): // SRA  A
		src = zR8(Opcode & 7);
		res = (src >> 1) | (src & 0x80);
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x2e): // SRA  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src >> 1) | (src & 0x80);
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 SLL
-----------------------------------------*/

	OPCB(0x30): // SLL  B
	OPCB(0x31): // SLL  C
	OPCB(0x32): // SLL  D
	OPCB(0x33): // SLL  E
	OPCB(0x34): // SLL  H
	OPCB(0x35): // SLL  L
	OPCB(0x37): // SLL  A
		src = zR8(Opcode & 7);
		res = (src << 1) | 0x01;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x36): // SLL  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = (src << 1) | 0x01;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 SRL
-----------------------------------------*/

	OPCB(0x38): // SRL  B
	OPCB(0x39): // SRL  C
	OPCB(0x3a): // SRL  D
	OPCB(0x3b): // SRL  E
	OPCB(0x3c): // SRL  H
	OPCB(0x3d): // SRL  L
	OPCB(0x3f): // SRL  A
		src = zR8(Opcode & 7);
		res = src >> 1;
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		RET(8)

	OPCB(0x3e): // SRL  (HL)
		adr = zHL;
		src = READ_MEM8(adr);
		res = src >> 1;
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 BIT
-----------------------------------------*/

	OPCB(0x40): // BIT  0,B
	OPCB(0x41): // BIT  0,C
	OPCB(0x42): // BIT  0,D
	OPCB(0x43): // BIT  0,E
	OPCB(0x44): // BIT  0,H
	OPCB(0x45): // BIT  0,L
	OPCB(0x47): // BIT  0,A

	OPCB(0x48): // BIT  1,B
	OPCB(0x49): // BIT  1,C
	OPCB(0x4a): // BIT  1,D
	OPCB(0x4b): // BIT  1,E
	OPCB(0x4c): // BIT  1,H
	OPCB(0x4d): // BIT  1,L
	OPCB(0x4f): // BIT  1,A

	OPCB(0x50): // BIT  2,B
	OPCB(0x51): // BIT  2,C
	OPCB(0x52): // BIT  2,D
	OPCB(0x53): // BIT  2,E
	OPCB(0x54): // BIT  2,H
	OPCB(0x55): // BIT  2,L
	OPCB(0x57): // BIT  2,A

	OPCB(0x58): // BIT  3,B
	OPCB(0x59): // BIT  3,C
	OPCB(0x5a): // BIT  3,D
	OPCB(0x5b): // BIT  3,E
	OPCB(0x5c): // BIT  3,H
	OPCB(0x5d): // BIT  3,L
	OPCB(0x5f): // BIT  3,A

	OPCB(0x60): // BIT  4,B
	OPCB(0x61): // BIT  4,C
	OPCB(0x62): // BIT  4,D
	OPCB(0x63): // BIT  4,E
	OPCB(0x64): // BIT  4,H
	OPCB(0x65): // BIT  4,L
	OPCB(0x67): // BIT  4,A

	OPCB(0x68): // BIT  5,B
	OPCB(0x69): // BIT  5,C
	OPCB(0x6a): // BIT  5,D
	OPCB(0x6b): // BIT  5,E
	OPCB(0x6c): // BIT  5,H
	OPCB(0x6d): // BIT  5,L
	OPCB(0x6f): // BIT  5,A

	OPCB(0x70): // BIT  6,B
	OPCB(0x71): // BIT  6,C
	OPCB(0x72): // BIT  6,D
	OPCB(0x73): // BIT  6,E
	OPCB(0x74): // BIT  6,H
	OPCB(0x75): // BIT  6,L
	OPCB(0x77): // BIT  6,A

	OPCB(0x78): // BIT  7,B
	OPCB(0x79): // BIT  7,C
	OPCB(0x7a): // BIT  7,D
	OPCB(0x7b): // BIT  7,E
	OPCB(0x7c): // BIT  7,H
	OPCB(0x7d): // BIT  7,L
	OPCB(0x7f): // BIT  7,A
		zF = (zF & CF) | HF | SZ_BIT[zR8(Opcode & 7) & (1 << ((Opcode >> 3) & 7))];
		RET(8)

	OPCB(0x46): // BIT  0,(HL)
	OPCB(0x4e): // BIT  1,(HL)
	OPCB(0x56): // BIT  2,(HL)
	OPCB(0x5e): // BIT  3,(HL)
	OPCB(0x66): // BIT  4,(HL)
	OPCB(0x6e): // BIT  5,(HL)
	OPCB(0x76): // BIT  6,(HL)
	OPCB(0x7e): // BIT  7,(HL)
		src = READ_MEM8(zHL);
		zF = (zF & CF) | HF | SZ_BIT[src & (1 << ((Opcode >> 3) & 7))];
		RET(12)

/*-----------------------------------------
 RES
-----------------------------------------*/

	OPCB(0x80): // RES  0,B
	OPCB(0x81): // RES  0,C
	OPCB(0x82): // RES  0,D
	OPCB(0x83): // RES  0,E
	OPCB(0x84): // RES  0,H
	OPCB(0x85): // RES  0,L
	OPCB(0x87): // RES  0,A

	OPCB(0x88): // RES  1,B
	OPCB(0x89): // RES  1,C
	OPCB(0x8a): // RES  1,D
	OPCB(0x8b): // RES  1,E
	OPCB(0x8c): // RES  1,H
	OPCB(0x8d): // RES  1,L
	OPCB(0x8f): // RES  1,A

	OPCB(0x90): // RES  2,B
	OPCB(0x91): // RES  2,C
	OPCB(0x92): // RES  2,D
	OPCB(0x93): // RES  2,E
	OPCB(0x94): // RES  2,H
	OPCB(0x95): // RES  2,L
	OPCB(0x97): // RES  2,A

	OPCB(0x98): // RES  3,B
	OPCB(0x99): // RES  3,C
	OPCB(0x9a): // RES  3,D
	OPCB(0x9b): // RES  3,E
	OPCB(0x9c): // RES  3,H
	OPCB(0x9d): // RES  3,L
	OPCB(0x9f): // RES  3,A

	OPCB(0xa0): // RES  4,B
	OPCB(0xa1): // RES  4,C
	OPCB(0xa2): // RES  4,D
	OPCB(0xa3): // RES  4,E
	OPCB(0xa4): // RES  4,H
	OPCB(0xa5): // RES  4,L
	OPCB(0xa7): // RES  4,A

	OPCB(0xa8): // RES  5,B
	OPCB(0xa9): // RES  5,C
	OPCB(0xaa): // RES  5,D
	OPCB(0xab): // RES  5,E
	OPCB(0xac): // RES  5,H
	OPCB(0xad): // RES  5,L
	OPCB(0xaf): // RES  5,A

	OPCB(0xb0): // RES  6,B
	OPCB(0xb1): // RES  6,C
	OPCB(0xb2): // RES  6,D
	OPCB(0xb3): // RES  6,E
	OPCB(0xb4): // RES  6,H
	OPCB(0xb5): // RES  6,L
	OPCB(0xb7): // RES  6,A

	OPCB(0xb8): // RES  7,B
	OPCB(0xb9): // RES  7,C
	OPCB(0xba): // RES  7,D
	OPCB(0xbb): // RES  7,E
	OPCB(0xbc): // RES  7,H
	OPCB(0xbd): // RES  7,L
	OPCB(0xbf): // RES  7,A
		zR8(Opcode & 7) &= ~(1 << ((Opcode >> 3) & 7));
		RET(8)

	OPCB(0x86): // RES  0,(HL)
	OPCB(0x8e): // RES  1,(HL)
	OPCB(0x96): // RES  2,(HL)
	OPCB(0x9e): // RES  3,(HL)
	OPCB(0xa6): // RES  4,(HL)
	OPCB(0xae): // RES  5,(HL)
	OPCB(0xb6): // RES  6,(HL)
	OPCB(0xbe): // RES  7,(HL)
		adr = zHL;
		res = READ_MEM8(adr);
		res &= ~(1 << ((Opcode >> 3) & 7));
		WRITE_MEM8(adr, res);
		RET(15)

/*-----------------------------------------
 SET
-----------------------------------------*/

	OPCB(0xc0): // SET  0,B
	OPCB(0xc1): // SET  0,C
	OPCB(0xc2): // SET  0,D
	OPCB(0xc3): // SET  0,E
	OPCB(0xc4): // SET  0,H
	OPCB(0xc5): // SET  0,L
	OPCB(0xc7): // SET  0,A

	OPCB(0xc8): // SET  1,B
	OPCB(0xc9): // SET  1,C
	OPCB(0xca): // SET  1,D
	OPCB(0xcb): // SET  1,E
	OPCB(0xcc): // SET  1,H
	OPCB(0xcd): // SET  1,L
	OPCB(0xcf): // SET  1,A

	OPCB(0xd0): // SET  2,B
	OPCB(0xd1): // SET  2,C
	OPCB(0xd2): // SET  2,D
	OPCB(0xd3): // SET  2,E
	OPCB(0xd4): // SET  2,H
	OPCB(0xd5): // SET  2,L
	OPCB(0xd7): // SET  2,A

	OPCB(0xd8): // SET  3,B
	OPCB(0xd9): // SET  3,C
	OPCB(0xda): // SET  3,D
	OPCB(0xdb): // SET  3,E
	OPCB(0xdc): // SET  3,H
	OPCB(0xdd): // SET  3,L
	OPCB(0xdf): // SET  3,A

	OPCB(0xe0): // SET  4,B
	OPCB(0xe1): // SET  4,C
	OPCB(0xe2): // SET  4,D
	OPCB(0xe3): // SET  4,E
	OPCB(0xe4): // SET  4,H
	OPCB(0xe5): // SET  4,L
	OPCB(0xe7): // SET  4,A

	OPCB(0xe8): // SET  5,B
	OPCB(0xe9): // SET  5,C
	OPCB(0xea): // SET  5,D
	OPCB(0xeb): // SET  5,E
	OPCB(0xec): // SET  5,H
	OPCB(0xed): // SET  5,L
	OPCB(0xef): // SET  5,A

	OPCB(0xf0): // SET  6,B
	OPCB(0xf1): // SET  6,C
	OPCB(0xf2): // SET  6,D
	OPCB(0xf3): // SET  6,E
	OPCB(0xf4): // SET  6,H
	OPCB(0xf5): // SET  6,L
	OPCB(0xf7): // SET  6,A

	OPCB(0xf8): // SET  7,B
	OPCB(0xf9): // SET  7,C
	OPCB(0xfa): // SET  7,D
	OPCB(0xfb): // SET  7,E
	OPCB(0xfc): // SET  7,H
	OPCB(0xfd): // SET  7,L
	OPCB(0xff): // SET  7,A
		zR8(Opcode & 7) |= 1 << ((Opcode >> 3) & 7);
		RET(8)

	OPCB(0xc6): // SET  0,(HL)
	OPCB(0xce): // SET  1,(HL)
	OPCB(0xd6): // SET  2,(HL)
	OPCB(0xde): // SET  3,(HL)
	OPCB(0xe6): // SET  4,(HL)
	OPCB(0xee): // SET  5,(HL)
	OPCB(0xf6): // SET  6,(HL)
	OPCB(0xfe): // SET  7,(HL)
		adr = zHL;
		res = READ_MEM8(adr);
		res |= 1 << ((Opcode >> 3) & 7);
		WRITE_MEM8(adr, res);
		RET(15)

#if !CZ80_USE_JUMPTABLE
}
#endif
