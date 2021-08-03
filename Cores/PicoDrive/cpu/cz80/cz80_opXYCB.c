/******************************************************************************
 *
 * CZ80 XYCB opcode include source file
 * CZ80 emulator version 0.9
 * Copyright 2004-2005 Stéphane Dallongeville
 *
 * (Modified by NJ)
 *
 *****************************************************************************/

#if CZ80_USE_JUMPTABLE
	goto *JumpTableXYCB[Opcode];
#else
switch (Opcode)
{
#endif

/*-----------------------------------------
 RLC
-----------------------------------------*/

	OPXYCB(0x00):   // RLC  (Ix+d), B
	OPXYCB(0x01):   // RLC  (Ix+d), C
	OPXYCB(0x02):   // RLC  (Ix+d), D
	OPXYCB(0x03):   // RLC  (Ix+d), E
	OPXYCB(0x04):   // RLC  (Ix+d), H
	OPXYCB(0x05):   // RLC  (Ix+d), L
	OPXYCB(0x07):   // RLC  (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src << 1) | (src >> 7)) & 0xff;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x06):   // RLC  (Ix+d)
		src = READ_MEM8(adr);
		res = ((src << 1) | (src >> 7)) & 0xff;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 RRC
-----------------------------------------*/

	OPXYCB(0x08):   // RRC  (Ix+d), B
	OPXYCB(0x09):   // RRC  (Ix+d), C
	OPXYCB(0x0a):   // RRC  (Ix+d), D
	OPXYCB(0x0b):   // RRC  (Ix+d), E
	OPXYCB(0x0c):   // RRC  (Ix+d), H
	OPXYCB(0x0d):   // RRC  (Ix+d), L
	OPXYCB(0x0f):   // RRC  (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src >> 1) | (src << 7)) & 0xff;
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x0e):   // RRC  (Ix+d)
		src = READ_MEM8(adr);
		res = ((src >> 1) | (src << 7)) & 0xff;
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 RL
-----------------------------------------*/

	OPXYCB(0x10):   // RL   (Ix+d), B
	OPXYCB(0x11):   // RL   (Ix+d), C
	OPXYCB(0x12):   // RL   (Ix+d), D
	OPXYCB(0x13):   // RL   (Ix+d), E
	OPXYCB(0x14):   // RL   (Ix+d), H
	OPXYCB(0x15):   // RL   (Ix+d), L
	OPXYCB(0x17):   // RL   (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src << 1) | (zF & CF)) & 0xff;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x16):   // RL   (Ix+d)
		src = READ_MEM8(adr);
		res = ((src << 1) | (zF & CF)) & 0xff;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 RR
-----------------------------------------*/

	OPXYCB(0x18):   // RR   (Ix+d), B
	OPXYCB(0x19):   // RR   (Ix+d), C
	OPXYCB(0x1a):   // RR   (Ix+d), D
	OPXYCB(0x1b):   // RR   (Ix+d), E
	OPXYCB(0x1c):   // RR   (Ix+d), H
	OPXYCB(0x1d):   // RR   (Ix+d), L
	OPXYCB(0x1f):   // RR   (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src >> 1) | (zF << 7)) & 0xff;
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x1e):   // RR   (Ix+d)
		src = READ_MEM8(adr);
		res = ((src >> 1) | (zF << 7)) & 0xff;
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 SLA
-----------------------------------------*/

	OPXYCB(0x20):   // SLA  (Ix+d), B
	OPXYCB(0x21):   // SLA  (Ix+d), C
	OPXYCB(0x22):   // SLA  (Ix+d), D
	OPXYCB(0x23):   // SLA  (Ix+d), E
	OPXYCB(0x24):   // SLA  (Ix+d), H
	OPXYCB(0x25):   // SLA  (Ix+d), L
	OPXYCB(0x27):   // SLA  (Ix+d), A
		src = READ_MEM8(adr);
		res = (src << 1) & 0xff;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x26):   // SLA  (Ix+d)
		src = READ_MEM8(adr);
		res = (src << 1) & 0xff;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 SRA
-----------------------------------------*/

	OPXYCB(0x28):   // SRA  (Ix+d), B
	OPXYCB(0x29):   // SRA  (Ix+d), C
	OPXYCB(0x2a):   // SRA  (Ix+d), D
	OPXYCB(0x2b):   // SRA  (Ix+d), E
	OPXYCB(0x2c):   // SRA  (Ix+d), H
	OPXYCB(0x2d):   // SRA  (Ix+d), L
	OPXYCB(0x2f):   // SRA  (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src >> 1) | (src & 0x80)) & 0xff;
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x2e):   // SRA  (Ix+d)
		src = READ_MEM8(adr);
		res = ((src >> 1) | (src & 0x80)) & 0xff;
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 SLL
-----------------------------------------*/

	OPXYCB(0x30):   // SLL  (Ix+d), B
	OPXYCB(0x31):   // SLL  (Ix+d), C
	OPXYCB(0x32):   // SLL  (Ix+d), D
	OPXYCB(0x33):   // SLL  (Ix+d), E
	OPXYCB(0x34):   // SLL  (Ix+d), H
	OPXYCB(0x35):   // SLL  (Ix+d), L
	OPXYCB(0x37):   // SLL  (Ix+d), A
		src = READ_MEM8(adr);
		res = ((src << 1) | 0x01) & 0xff;
		zF = SZP[res] | (src >> 7);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x36):   // SLL  (Ix+d)
		src = READ_MEM8(adr);
		res = ((src << 1) | 0x01) & 0xff;
		zF = SZP[res] | (src >> 7);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 SRL
-----------------------------------------*/

	OPXYCB(0x38):   // SRL  (Ix+d), B
	OPXYCB(0x39):   // SRL  (Ix+d), C
	OPXYCB(0x3a):   // SRL  (Ix+d), D
	OPXYCB(0x3b):   // SRL  (Ix+d), E
	OPXYCB(0x3c):   // SRL  (Ix+d), H
	OPXYCB(0x3d):   // SRL  (Ix+d), L
	OPXYCB(0x3f):   // SRL  (Ix+d), A
		src = READ_MEM8(adr);
		res = (src >> 1) & 0xff;
		zF = SZP[res] | (src & CF);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x3e):   // SRL  (Ix+d)
		src = READ_MEM8(adr);
		res = (src >> 1) & 0xff;
		zF = SZP[res] | (src & CF);
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 BIT
-----------------------------------------*/

	OPXYCB(0x40):   // BIT  0,(Ix+d)
	OPXYCB(0x41):   // BIT  0,(Ix+d)
	OPXYCB(0x42):   // BIT  0,(Ix+d)
	OPXYCB(0x43):   // BIT  0,(Ix+d)
	OPXYCB(0x44):   // BIT  0,(Ix+d)
	OPXYCB(0x45):   // BIT  0,(Ix+d)
	OPXYCB(0x47):   // BIT  0,(Ix+d)

	OPXYCB(0x48):   // BIT  1,(Ix+d)
	OPXYCB(0x49):   // BIT  1,(Ix+d)
	OPXYCB(0x4a):   // BIT  1,(Ix+d)
	OPXYCB(0x4b):   // BIT  1,(Ix+d)
	OPXYCB(0x4c):   // BIT  1,(Ix+d)
	OPXYCB(0x4d):   // BIT  1,(Ix+d)
	OPXYCB(0x4f):   // BIT  1,(Ix+d)

	OPXYCB(0x50):   // BIT  2,(Ix+d)
	OPXYCB(0x51):   // BIT  2,(Ix+d)
	OPXYCB(0x52):   // BIT  2,(Ix+d)
	OPXYCB(0x53):   // BIT  2,(Ix+d)
	OPXYCB(0x54):   // BIT  2,(Ix+d)
	OPXYCB(0x55):   // BIT  2,(Ix+d)
	OPXYCB(0x57):   // BIT  2,(Ix+d)

	OPXYCB(0x58):   // BIT  3,(Ix+d)
	OPXYCB(0x59):   // BIT  3,(Ix+d)
	OPXYCB(0x5a):   // BIT  3,(Ix+d)
	OPXYCB(0x5b):   // BIT  3,(Ix+d)
	OPXYCB(0x5c):   // BIT  3,(Ix+d)
	OPXYCB(0x5d):   // BIT  3,(Ix+d)
	OPXYCB(0x5f):   // BIT  3,(Ix+d)

	OPXYCB(0x60):   // BIT  4,(Ix+d)
	OPXYCB(0x61):   // BIT  4,(Ix+d)
	OPXYCB(0x62):   // BIT  4,(Ix+d)
	OPXYCB(0x63):   // BIT  4,(Ix+d)
	OPXYCB(0x64):   // BIT  4,(Ix+d)
	OPXYCB(0x65):   // BIT  4,(Ix+d)
	OPXYCB(0x67):   // BIT  4,(Ix+d)

	OPXYCB(0x68):   // BIT  5,(Ix+d)
	OPXYCB(0x69):   // BIT  5,(Ix+d)
	OPXYCB(0x6a):   // BIT  5,(Ix+d)
	OPXYCB(0x6b):   // BIT  5,(Ix+d)
	OPXYCB(0x6c):   // BIT  5,(Ix+d)
	OPXYCB(0x6d):   // BIT  5,(Ix+d)
	OPXYCB(0x6f):   // BIT  5,(Ix+d)

	OPXYCB(0x70):   // BIT  6,(Ix+d)
	OPXYCB(0x71):   // BIT  6,(Ix+d)
	OPXYCB(0x72):   // BIT  6,(Ix+d)
	OPXYCB(0x73):   // BIT  6,(Ix+d)
	OPXYCB(0x74):   // BIT  6,(Ix+d)
	OPXYCB(0x75):   // BIT  6,(Ix+d)
	OPXYCB(0x77):   // BIT  6,(Ix+d)

	OPXYCB(0x78):   // BIT  7,(Ix+d)
	OPXYCB(0x79):   // BIT  7,(Ix+d)
	OPXYCB(0x7a):   // BIT  7,(Ix+d)
	OPXYCB(0x7b):   // BIT  7,(Ix+d)
	OPXYCB(0x7c):   // BIT  7,(Ix+d)
	OPXYCB(0x7d):   // BIT  7,(Ix+d)
	OPXYCB(0x7f):   // BIT  7,(Ix+d)

	OPXYCB(0x46):   // BIT  0,(Ix+d)
	OPXYCB(0x4e):   // BIT  1,(Ix+d)
	OPXYCB(0x56):   // BIT  2,(Ix+d)
	OPXYCB(0x5e):   // BIT  3,(Ix+d)
	OPXYCB(0x66):   // BIT  4,(Ix+d)
	OPXYCB(0x6e):   // BIT  5,(Ix+d)
	OPXYCB(0x76):   // BIT  6,(Ix+d)
	OPXYCB(0x7e):   // BIT  7,(Ix+d)
		src = READ_MEM8(adr);
		zF = (zF & CF) | HF |
			 (SZ_BIT[src & (1 << ((Opcode >> 3) & 7))] & ~(YF | XF)) |
			 ((adr >> 8) & (YF | XF));
		RET(16)

/*-----------------------------------------
 RES
-----------------------------------------*/

	OPXYCB(0x80):   // RES  0,(Ix+d),B
	OPXYCB(0x81):   // RES  0,(Ix+d),C
	OPXYCB(0x82):   // RES  0,(Ix+d),D
	OPXYCB(0x83):   // RES  0,(Ix+d),E
	OPXYCB(0x84):   // RES  0,(Ix+d),H
	OPXYCB(0x85):   // RES  0,(Ix+d),L
	OPXYCB(0x87):   // RES  0,(Ix+d),A

	OPXYCB(0x88):   // RES  1,(Ix+d),B
	OPXYCB(0x89):   // RES  1,(Ix+d),C
	OPXYCB(0x8a):   // RES  1,(Ix+d),D
	OPXYCB(0x8b):   // RES  1,(Ix+d),E
	OPXYCB(0x8c):   // RES  1,(Ix+d),H
	OPXYCB(0x8d):   // RES  1,(Ix+d),L
	OPXYCB(0x8f):   // RES  1,(Ix+d),A

	OPXYCB(0x90):   // RES  2,(Ix+d),B
	OPXYCB(0x91):   // RES  2,(Ix+d),C
	OPXYCB(0x92):   // RES  2,(Ix+d),D
	OPXYCB(0x93):   // RES  2,(Ix+d),E
	OPXYCB(0x94):   // RES  2,(Ix+d),H
	OPXYCB(0x95):   // RES  2,(Ix+d),L
	OPXYCB(0x97):   // RES  2,(Ix+d),A

	OPXYCB(0x98):   // RES  3,(Ix+d),B
	OPXYCB(0x99):   // RES  3,(Ix+d),C
	OPXYCB(0x9a):   // RES  3,(Ix+d),D
	OPXYCB(0x9b):   // RES  3,(Ix+d),E
	OPXYCB(0x9c):   // RES  3,(Ix+d),H
	OPXYCB(0x9d):   // RES  3,(Ix+d),L
	OPXYCB(0x9f):   // RES  3,(Ix+d),A

	OPXYCB(0xa0):   // RES  4,(Ix+d),B
	OPXYCB(0xa1):   // RES  4,(Ix+d),C
	OPXYCB(0xa2):   // RES  4,(Ix+d),D
	OPXYCB(0xa3):   // RES  4,(Ix+d),E
	OPXYCB(0xa4):   // RES  4,(Ix+d),H
	OPXYCB(0xa5):   // RES  4,(Ix+d),L
	OPXYCB(0xa7):   // RES  4,(Ix+d),A

	OPXYCB(0xa8):   // RES  5,(Ix+d),B
	OPXYCB(0xa9):   // RES  5,(Ix+d),C
	OPXYCB(0xaa):   // RES  5,(Ix+d),D
	OPXYCB(0xab):   // RES  5,(Ix+d),E
	OPXYCB(0xac):   // RES  5,(Ix+d),H
	OPXYCB(0xad):   // RES  5,(Ix+d),L
	OPXYCB(0xaf):   // RES  5,(Ix+d),A

	OPXYCB(0xb0):   // RES  6,(Ix+d),B
	OPXYCB(0xb1):   // RES  6,(Ix+d),C
	OPXYCB(0xb2):   // RES  6,(Ix+d),D
	OPXYCB(0xb3):   // RES  6,(Ix+d),E
	OPXYCB(0xb4):   // RES  6,(Ix+d),H
	OPXYCB(0xb5):   // RES  6,(Ix+d),L
	OPXYCB(0xb7):   // RES  6,(Ix+d),A

	OPXYCB(0xb8):   // RES  7,(Ix+d),B
	OPXYCB(0xb9):   // RES  7,(Ix+d),C
	OPXYCB(0xba):   // RES  7,(Ix+d),D
	OPXYCB(0xbb):   // RES  7,(Ix+d),E
	OPXYCB(0xbc):   // RES  7,(Ix+d),H
	OPXYCB(0xbd):   // RES  7,(Ix+d),L
	OPXYCB(0xbf):   // RES  7,(Ix+d),A
		res = READ_MEM8(adr);
		res &= ~(1 << ((Opcode >> 3) & 7));
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0x86):   // RES  0,(Ix+d)
	OPXYCB(0x8e):   // RES  1,(Ix+d)
	OPXYCB(0x96):   // RES  2,(Ix+d)
	OPXYCB(0x9e):   // RES  3,(Ix+d)
	OPXYCB(0xa6):   // RES  4,(Ix+d)
	OPXYCB(0xae):   // RES  5,(Ix+d)
	OPXYCB(0xb6):   // RES  6,(Ix+d)
	OPXYCB(0xbe):   // RES  7,(Ix+d)
		res = READ_MEM8(adr);
		res &= ~(1 << ((Opcode >> 3) & 7));
		WRITE_MEM8(adr, res);
		RET(19)

/*-----------------------------------------
 SET
-----------------------------------------*/

	OPXYCB(0xc0):   // SET  0,(Ix+d),B
	OPXYCB(0xc1):   // SET  0,(Ix+d),C
	OPXYCB(0xc2):   // SET  0,(Ix+d),D
	OPXYCB(0xc3):   // SET  0,(Ix+d),E
	OPXYCB(0xc4):   // SET  0,(Ix+d),H
	OPXYCB(0xc5):   // SET  0,(Ix+d),L
	OPXYCB(0xc7):   // SET  0,(Ix+d),A

	OPXYCB(0xc8):   // SET  1,(Ix+d),B
	OPXYCB(0xc9):   // SET  1,(Ix+d),C
	OPXYCB(0xca):   // SET  1,(Ix+d),D
	OPXYCB(0xcb):   // SET  1,(Ix+d),E
	OPXYCB(0xcc):   // SET  1,(Ix+d),H
	OPXYCB(0xcd):   // SET  1,(Ix+d),L
	OPXYCB(0xcf):   // SET  1,(Ix+d),A

	OPXYCB(0xd0):   // SET  2,(Ix+d),B
	OPXYCB(0xd1):   // SET  2,(Ix+d),C
	OPXYCB(0xd2):   // SET  2,(Ix+d),D
	OPXYCB(0xd3):   // SET  2,(Ix+d),E
	OPXYCB(0xd4):   // SET  2,(Ix+d),H
	OPXYCB(0xd5):   // SET  2,(Ix+d),L
	OPXYCB(0xd7):   // SET  2,(Ix+d),A

	OPXYCB(0xd8):   // SET  3,(Ix+d),B
	OPXYCB(0xd9):   // SET  3,(Ix+d),C
	OPXYCB(0xda):   // SET  3,(Ix+d),D
	OPXYCB(0xdb):   // SET  3,(Ix+d),E
	OPXYCB(0xdc):   // SET  3,(Ix+d),H
	OPXYCB(0xdd):   // SET  3,(Ix+d),L
	OPXYCB(0xdf):   // SET  3,(Ix+d),A

	OPXYCB(0xe0):   // SET  4,(Ix+d),B
	OPXYCB(0xe1):   // SET  4,(Ix+d),C
	OPXYCB(0xe2):   // SET  4,(Ix+d),D
	OPXYCB(0xe3):   // SET  4,(Ix+d),E
	OPXYCB(0xe4):   // SET  4,(Ix+d),H
	OPXYCB(0xe5):   // SET  4,(Ix+d),L
	OPXYCB(0xe7):   // SET  4,(Ix+d),A

	OPXYCB(0xe8):   // SET  5,(Ix+d),B
	OPXYCB(0xe9):   // SET  5,(Ix+d),C
	OPXYCB(0xea):   // SET  5,(Ix+d),D
	OPXYCB(0xeb):   // SET  5,(Ix+d),E
	OPXYCB(0xec):   // SET  5,(Ix+d),H
	OPXYCB(0xed):   // SET  5,(Ix+d),L
	OPXYCB(0xef):   // SET  5,(Ix+d),A

	OPXYCB(0xf0):   // SET  6,(Ix+d),B
	OPXYCB(0xf1):   // SET  6,(Ix+d),C
	OPXYCB(0xf2):   // SET  6,(Ix+d),D
	OPXYCB(0xf3):   // SET  6,(Ix+d),E
	OPXYCB(0xf4):   // SET  6,(Ix+d),H
	OPXYCB(0xf5):   // SET  6,(Ix+d),L
	OPXYCB(0xf7):   // SET  6,(Ix+d),A

	OPXYCB(0xf8):   // SET  7,(Ix+d),B
	OPXYCB(0xf9):   // SET  7,(Ix+d),C
	OPXYCB(0xfa):   // SET  7,(Ix+d),D
	OPXYCB(0xfb):   // SET  7,(Ix+d),E
	OPXYCB(0xfc):   // SET  7,(Ix+d),H
	OPXYCB(0xfd):   // SET  7,(Ix+d),L
	OPXYCB(0xff):   // SET  7,(Ix+d),A
		res = READ_MEM8(adr);
		res |= 1 << ((Opcode >> 3) & 7);
		zR8(Opcode & 7) = res;
		WRITE_MEM8(adr, res);
		RET(19)

	OPXYCB(0xc6):   // SET  0,(Ix+d)
	OPXYCB(0xce):   // SET  1,(Ix+d)
	OPXYCB(0xd6):   // SET  2,(Ix+d)
	OPXYCB(0xde):   // SET  3,(Ix+d)
	OPXYCB(0xe6):   // SET  4,(Ix+d)
	OPXYCB(0xee):   // SET  5,(Ix+d)
	OPXYCB(0xf6):   // SET  6,(Ix+d)
	OPXYCB(0xfe):   // SET  7,(Ix+d)
		res = READ_MEM8(adr);
		res |= 1 << ((Opcode >> 3) & 7);
		WRITE_MEM8(adr, res);
		RET(19)

#if !CZ80_USE_JUMPTABLE
}
#endif
