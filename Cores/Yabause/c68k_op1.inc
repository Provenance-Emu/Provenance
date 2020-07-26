
// MOVEB
OP_0x1000:
{
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// MOVEB
OP_0x1080:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x10C0:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1100:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1140:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1180:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x11C0:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x13C0:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1EC0:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1F00:
{
	u32 adr;
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1008:
{
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// MOVEB
OP_0x1088:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x10C8:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1108:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1148:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1188:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x11C8:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x13C8:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1EC8:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1F08:
{
	u32 adr;
	u32 res;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// MOVEB
OP_0x1010:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// MOVEB
OP_0x1090:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x10D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1110:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1150:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1190:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x13D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1ED0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1F10:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1018:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// MOVEB
OP_0x1098:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x10D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1118:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1158:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1198:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x13D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1ED8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1F18:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1020:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// MOVEB
OP_0x10A0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x10E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1120:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1160:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11A0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x11E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x13E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x1EE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1F20:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1028:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEB
OP_0x10A8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x10E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1128:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1168:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x11A8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x11E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x13E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x1EE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1F28:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1030:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// MOVEB
OP_0x10B0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x10F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x1130:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x1170:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x11B0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x11F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x13F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(26)

// MOVEB
OP_0x1EF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x1F30:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x1038:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEB
OP_0x10B8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x10F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1138:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1178:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x11B8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x11F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x13F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x1EF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1F38:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1039:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// MOVEB
OP_0x10B9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x10F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1139:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1179:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x11B9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(26)

// MOVEB
OP_0x11F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x13F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(28)

// MOVEB
OP_0x1EF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1F39:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x103A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEB
OP_0x10BA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x10FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x113A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x117A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x11BA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x11FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x13FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x1EFA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x1F3A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x103B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// MOVEB
OP_0x10BB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x10FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x113B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x117B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x11BB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(24)

// MOVEB
OP_0x11FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x13FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(26)

// MOVEB
OP_0x1EFB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x1F3B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x103C:
{
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// MOVEB
OP_0x10BC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x10FC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x113C:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x117C:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x11BC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11FC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x13FC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1EFC:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1F3C:
{
	u32 adr;
	u32 res;
	res = FETCH_BYTE;
	PC += 2;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x101F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// MOVEB
OP_0x109F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x10DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x111F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x115F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x119F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// MOVEB
OP_0x13DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x1EDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1F1F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// MOVEB
OP_0x1027:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// MOVEB
OP_0x10A7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x10E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1127:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1167:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x11A7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// MOVEB
OP_0x11E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MOVEB
OP_0x13E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(22)

// MOVEB
OP_0x1EE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// MOVEB
OP_0x1F27:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)
