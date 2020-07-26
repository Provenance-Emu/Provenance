
// MOVEL
OP_0x2000:
{
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// MOVEL
OP_0x2080:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x20C0:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2100:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2140:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(16)

// MOVEL
OP_0x2180:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(18)

// MOVEL
OP_0x21C0:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(16)

// MOVEL
OP_0x23C0:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2EC0:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2F00:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2008:
{
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// MOVEL
OP_0x2088:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x20C8:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2108:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2148:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(16)

// MOVEL
OP_0x2188:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(18)

// MOVEL
OP_0x21C8:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(16)

// MOVEL
OP_0x23C8:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2EC8:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2F08:
{
	u32 adr;
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(12)

// MOVEL
OP_0x2010:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEL
OP_0x2090:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x20D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2110:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2150:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2190:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x23D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2ED0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2F10:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2018:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEL
OP_0x2098:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x20D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2118:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2158:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2198:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x23D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2ED8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2F18:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2020:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// MOVEL
OP_0x20A0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x20E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2120:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2160:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21A0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x21E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x23E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x2EE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2F20:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2028:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// MOVEL
OP_0x20A8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x20E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2128:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2168:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x21A8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x21E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x23E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x2EE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2F28:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2030:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// MOVEL
OP_0x20B0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x20F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x2130:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x2170:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x21B0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x21F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x23F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(34)

// MOVEL
OP_0x2EF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x2F30:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x2038:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// MOVEL
OP_0x20B8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x20F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2138:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2178:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x21B8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x21F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x23F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x2EF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2F38:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2039:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// MOVEL
OP_0x20B9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x20F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2139:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2179:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x21B9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(34)

// MOVEL
OP_0x21F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x23F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(36)

// MOVEL
OP_0x2EF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2F39:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x203A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// MOVEL
OP_0x20BA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x20FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x213A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x217A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x21BA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x21FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x23FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x2EFA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x2F3A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x203B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// MOVEL
OP_0x20BB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x20FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x213B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x217B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x21BB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(32)

// MOVEL
OP_0x21FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x23FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(34)

// MOVEL
OP_0x2EFB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x2F3B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x203C:
{
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(12)

// MOVEL
OP_0x20BC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x20FC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x213C:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x217C:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x21BC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21FC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x23FC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2EFC:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2F3C:
{
	u32 adr;
	u32 res;
	res = FETCH_LONG;
	PC += 4;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x201F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// MOVEL
OP_0x209F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x20DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x211F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x215F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x219F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// MOVEL
OP_0x23DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x2EDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2F1F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// MOVEL
OP_0x2027:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// MOVEL
OP_0x20A7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x20E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2127:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2167:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x21A7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[(Opcode >> 9) & 7];
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// MOVEL
OP_0x21E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// MOVEL
OP_0x23E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = (s32)FETCH_LONG;
	PC += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// MOVEL
OP_0x2EE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEL
OP_0x2F27:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVEAL
OP_0x2040:
{
	u32 res;
	res = (s32)(s32)CPU->D[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(4)

// MOVEAL
OP_0x2048:
{
	u32 res;
	res = (s32)(s32)CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(4)

// MOVEAL
OP_0x2050:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// MOVEAL
OP_0x2058:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// MOVEAL
OP_0x2060:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)

// MOVEAL
OP_0x2068:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// MOVEAL
OP_0x2070:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// MOVEAL
OP_0x2078:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// MOVEAL
OP_0x2079:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// MOVEAL
OP_0x207A:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// MOVEAL
OP_0x207B:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// MOVEAL
OP_0x207C:
{
	u32 res;
	res = (s32)(s32)FETCH_LONG;
	PC += 4;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)

// MOVEAL
OP_0x205F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// MOVEAL
OP_0x2067:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READSX_LONG_F(adr, res)
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)
