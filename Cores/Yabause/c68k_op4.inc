
// NEGX
OP_0x4000:
{
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NEGX
OP_0x4010:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4018:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4020:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NEGX
OP_0x4028:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NEGX
OP_0x4030:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// NEGX
OP_0x4038:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NEGX
OP_0x4039:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// NEGX
OP_0x401F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4027:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NEGX
OP_0x4040:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NEGX
OP_0x4050:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4058:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4060:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NEGX
OP_0x4068:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NEGX
OP_0x4070:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// NEGX
OP_0x4078:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NEGX
OP_0x4079:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// NEGX
OP_0x405F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEGX
OP_0x4067:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NEGX
OP_0x4080:
{
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// NEGX
OP_0x4090:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEGX
OP_0x4098:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEGX
OP_0x40A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// NEGX
OP_0x40A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NEGX
OP_0x40B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// NEGX
OP_0x40B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NEGX
OP_0x40B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// NEGX
OP_0x409F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEGX
OP_0x40A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// CLR
OP_0x4200:
{
	u32 res;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// CLR
OP_0x4210:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4218:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4220:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// CLR
OP_0x4228:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// CLR
OP_0x4230:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// CLR
OP_0x4238:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// CLR
OP_0x4239:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// CLR
OP_0x421F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4227:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// CLR
OP_0x4240:
{
	u32 res;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// CLR
OP_0x4250:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4258:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4260:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// CLR
OP_0x4268:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// CLR
OP_0x4270:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// CLR
OP_0x4278:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// CLR
OP_0x4279:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// CLR
OP_0x425F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// CLR
OP_0x4267:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// CLR
OP_0x4280:
{
	u32 res;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// CLR
OP_0x4290:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// CLR
OP_0x4298:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// CLR
OP_0x42A0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// CLR
OP_0x42A8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// CLR
OP_0x42B0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// CLR
OP_0x42B8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// CLR
OP_0x42B9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// CLR
OP_0x429F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// CLR
OP_0x42A7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	res = 0;
	CPU->flag_N = CPU->flag_notZ = CPU->flag_V = CPU->flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// NEG
OP_0x4400:
{
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NEG
OP_0x4410:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4418:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4420:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NEG
OP_0x4428:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NEG
OP_0x4430:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// NEG
OP_0x4438:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NEG
OP_0x4439:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// NEG
OP_0x441F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4427:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = res & (u32)src;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NEG
OP_0x4440:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NEG
OP_0x4450:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4458:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4460:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NEG
OP_0x4468:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NEG
OP_0x4470:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// NEG
OP_0x4478:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NEG
OP_0x4479:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// NEG
OP_0x445F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NEG
OP_0x4467:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -(u32)src;
	CPU->flag_V = (res & (u32)src) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NEG
OP_0x4480:
{
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// NEG
OP_0x4490:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEG
OP_0x4498:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEG
OP_0x44A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// NEG
OP_0x44A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NEG
OP_0x44B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// NEG
OP_0x44B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NEG
OP_0x44B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// NEG
OP_0x449F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NEG
OP_0x44A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -(u32)src;
	CPU->flag_notZ = res;
	CPU->flag_V = (res & (u32)src) >> 24;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// NOT
OP_0x4600:
{
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NOT
OP_0x4610:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4618:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4620:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NOT
OP_0x4628:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NOT
OP_0x4630:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// NOT
OP_0x4638:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// NOT
OP_0x4639:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// NOT
OP_0x461F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4627:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_N = res;
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// NOT
OP_0x4640:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// NOT
OP_0x4650:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4658:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4660:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NOT
OP_0x4668:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NOT
OP_0x4670:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// NOT
OP_0x4678:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// NOT
OP_0x4679:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// NOT
OP_0x465F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// NOT
OP_0x4667:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res & 0xFFFF;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// NOT
OP_0x4680:
{
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// NOT
OP_0x4690:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NOT
OP_0x4698:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NOT
OP_0x46A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// NOT
OP_0x46A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NOT
OP_0x46B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// NOT
OP_0x46B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// NOT
OP_0x46B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// NOT
OP_0x469F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// NOT
OP_0x46A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~(u32)src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// MOVESRa
OP_0x40C0:
{
	u32 res;
	res = GET_SR;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// MOVESRa
OP_0x40D0:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// MOVESRa
OP_0x40D8:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// MOVESRa
OP_0x40E0:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// MOVESRa
OP_0x40E8:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// MOVESRa
OP_0x40F0:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// MOVESRa
OP_0x40F8:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// MOVESRa
OP_0x40F9:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// MOVESRa
OP_0x40DF:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// MOVESRa
OP_0x40E7:
{
	u32 adr;
	u32 res;
	res = GET_SR;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// MOVEaCCR
OP_0x44C0:
{
	u32 res;
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	SET_CCR(res)
}
RET(12)

// MOVEaCCR
OP_0x44D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(16)

// MOVEaCCR
OP_0x44D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(16)

// MOVEaCCR
OP_0x44E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(18)

// MOVEaCCR
OP_0x44E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(20)

// MOVEaCCR
OP_0x44F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(22)

// MOVEaCCR
OP_0x44F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(20)

// MOVEaCCR
OP_0x44F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(24)

// MOVEaCCR
OP_0x44FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(20)

// MOVEaCCR
OP_0x44FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(22)

// MOVEaCCR
OP_0x44FC:
{
	u32 res;
	res = FETCH_WORD;
	PC += 2;
	SET_CCR(res)
}
RET(16)

// MOVEaCCR
OP_0x44DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(16)

// MOVEaCCR
OP_0x44E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
}
RET(18)

// MOVEaSR
OP_0x46C0:
{
	u32 res;
	if (CPU->flag_S)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 12;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46D0:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 16;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46D8:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 16;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46E0:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 18;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46E8:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 20;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46F0:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 22;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46F8:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 20;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46F9:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 24;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46FA:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 20;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46FB:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 22;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46FC:
{
	u32 res;
	if (CPU->flag_S)
	{
	res = FETCH_WORD;
	PC += 2;
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 16;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46DF:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 16;
goto C68k_Exec_End;

// MOVEaSR
OP_0x46E7:
{
	u32 adr;
	u32 res;
	if (CPU->flag_S)
	{
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
		SET_SR(res)
		if (!CPU->flag_S)
		{
			res = CPU->A[7];
			CPU->A[7] = CPU->USP;
			CPU->USP = res;
		}
	}
	else
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
}
POST_IO
CCnt -= 18;
goto C68k_Exec_End;

// NBCD
OP_0x4800:
{
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
}
RET(6)

// NBCD
OP_0x4810:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(12)

// NBCD
OP_0x4818:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(12)

// NBCD
OP_0x4820:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(14)

// NBCD
OP_0x4828:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(16)

// NBCD
OP_0x4830:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(18)

// NBCD
OP_0x4838:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(16)

// NBCD
OP_0x4839:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(20)

// NBCD
OP_0x481F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(12)

// NBCD
OP_0x4827:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		CPU->flag_notZ |= res;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_N = res;
	POST_IO
}
RET(14)

// PEA
OP_0x4850:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(12)

// PEA
OP_0x4868:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(16)

// PEA
OP_0x4870:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(20)

// PEA
OP_0x4878:
{
	u32 adr;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(16)

// PEA
OP_0x4879:
{
	u32 adr;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(20)

// PEA
OP_0x487A:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(16)

// PEA
OP_0x487B:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
}
RET(20)

// SWAP
OP_0x4840:
{
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	res = (res >> 16) | (res << 16);
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// MOVEMRa
OP_0x4890:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *(u16*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(12)

// MOVEMRa
OP_0x48A0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->A[7]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 2;
			WRITE_WORD_F(adr, *(u16*)src)
		}
		src -= 4;
	} while (res >>= 1);
	CPU->A[(Opcode >> 0) & 7] = adr;
	POST_IO
	CCnt -= ((u32)dst - adr) * 2;
}
RET(8)

// MOVEMRa
OP_0x48A8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *(u16*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(20)

// MOVEMRa
OP_0x48B0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *(u16*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMRa
OP_0x48B8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *(u16*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(20)

// MOVEMRa
OP_0x48B9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)FETCH_LONG;
	PC += 4;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *(u16*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMRa
OP_0x48A7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[7];
	src = (pointer)(&CPU->A[7]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 2;
			WRITE_WORD_F(adr, *(u16*)src)
		}
		src -= 4;
	} while (res >>= 1);
	CPU->A[7] = adr;
	POST_IO
	CCnt -= ((u32)dst - adr) * 2;
}
RET(8)

// MOVEMRa
OP_0x48D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(16)

// MOVEMRa
OP_0x48E0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->A[7]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 4;
			WRITE_LONG_DEC_F(adr, *(u32*)src)
		}
		src -= 4;
	} while (res >>= 1);
	CPU->A[(Opcode >> 0) & 7] = adr;
	POST_IO
	CCnt -= ((u32)dst - adr) * 2;
}
RET(8)

// MOVEMRa
OP_0x48E8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMRa
OP_0x48F0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMRa
OP_0x48F8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMRa
OP_0x48F9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)FETCH_LONG;
	PC += 4;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(32)

// MOVEMRa
OP_0x48E7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[7];
	src = (pointer)(&CPU->A[7]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 4;
			WRITE_LONG_DEC_F(adr, *(u32*)src)
		}
		src -= 4;
	} while (res >>= 1);
	CPU->A[7] = adr;
	POST_IO
	CCnt -= ((u32)dst - adr) * 2;
}
RET(8)

// EXT
OP_0x4880:
{
	u32 res;
	res = (s32)(s8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// EXT
OP_0x48C0:
{
	u32 res;
	res = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// TST
OP_0x4A00:
{
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
}
RET(4)

// TST
OP_0x4A10:
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
	POST_IO
}
RET(8)

// TST
OP_0x4A18:
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
	POST_IO
}
RET(8)

// TST
OP_0x4A20:
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
	POST_IO
}
RET(10)

// TST
OP_0x4A28:
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
	POST_IO
}
RET(12)

// TST
OP_0x4A30:
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
	POST_IO
}
RET(14)

// TST
OP_0x4A38:
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
	POST_IO
}
RET(12)

// TST
OP_0x4A39:
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
	POST_IO
}
RET(16)

// TST
OP_0x4A1F:
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
	POST_IO
}
RET(8)

// TST
OP_0x4A27:
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
	POST_IO
}
RET(10)

// TST
OP_0x4A40:
{
	u32 res;
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
}
RET(4)

// TST
OP_0x4A50:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(8)

// TST
OP_0x4A58:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(8)

// TST
OP_0x4A60:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(10)

// TST
OP_0x4A68:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(12)

// TST
OP_0x4A70:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(14)

// TST
OP_0x4A78:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(12)

// TST
OP_0x4A79:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(16)

// TST
OP_0x4A5F:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(8)

// TST
OP_0x4A67:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	POST_IO
}
RET(10)

// TST
OP_0x4A80:
{
	u32 res;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
}
RET(4)

// TST
OP_0x4A90:
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
	POST_IO
}
RET(12)

// TST
OP_0x4A98:
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
	POST_IO
}
RET(12)

// TST
OP_0x4AA0:
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
	POST_IO
}
RET(14)

// TST
OP_0x4AA8:
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
	POST_IO
}
RET(16)

// TST
OP_0x4AB0:
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
	POST_IO
}
RET(18)

// TST
OP_0x4AB8:
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
	POST_IO
}
RET(16)

// TST
OP_0x4AB9:
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
	POST_IO
}
RET(20)

// TST
OP_0x4A9F:
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
	POST_IO
}
RET(12)

// TST
OP_0x4AA7:
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
	POST_IO
}
RET(14)

// TAS
OP_0x4AC0:
{
	u32 res;
	res = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	res |= 0x80;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// TAS
OP_0x4AD0:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// TAS
OP_0x4AD8:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// TAS
OP_0x4AE0:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(10)

// TAS
OP_0x4AE8:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// TAS
OP_0x4AF0:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// TAS
OP_0x4AF8:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// TAS
OP_0x4AF9:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// TAS
OP_0x4ADF:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(8)

// TAS
OP_0x4AE7:
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
	res |= 0x80;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(10)

// ILLEGAL
OP_0x4AFC:
{
	u32 res;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ILLEGAL_INSTRUCTION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
}
RET(4)

// MOVEMaR
OP_0x4C90:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(16)

// MOVEMaR
OP_0x4C98:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	CPU->A[(Opcode >> 0) & 7] = adr;
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(12)

// MOVEMaR
OP_0x4CA8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMaR
OP_0x4CB0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMaR
OP_0x4CB8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMaR
OP_0x4CB9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)FETCH_LONG;
	PC += 4;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(32)

// MOVEMaR
OP_0x4CBA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(24)

// MOVEMaR
OP_0x4CBB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMaR
OP_0x4C9F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *(s32*)src)
			adr += 2;
		}
		src += 4;
	} while (res >>= 1);
	CPU->A[7] = adr;
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(12)

// MOVEMaR
OP_0x4CD0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(20)

// MOVEMaR
OP_0x4CD8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	CPU->A[(Opcode >> 0) & 7] = adr;
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(12)

// MOVEMaR
OP_0x4CE8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMaR
OP_0x4CF0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(32)

// MOVEMaR
OP_0x4CF8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMaR
OP_0x4CF9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (s32)FETCH_LONG;
	PC += 4;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(36)

// MOVEMaR
OP_0x4CFA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(28)

// MOVEMaR
OP_0x4CFB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(32)

// MOVEMaR
OP_0x4CDF:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	res = FETCH_WORD;
	PC += 2;
	adr = CPU->A[7];
	src = (pointer)(&CPU->D[0]);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *(u32*)src)
			adr += 4;
		}
		src += 4;
	} while (res >>= 1);
	CPU->A[7] = adr;
	POST_IO
	CCnt -= (adr - (u32)dst) * 2;
}
RET(12)

// TRAP
OP_0x4E40:
{
	u32 res;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
	}
	res = C68K_TRAP_BASE_EX + (Opcode & 0xF);
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	PUSH_16_F(GET_SR)
	CPU->flag_S = C68K_SR_S;
	READ_LONG_F(res * 4, PC)
	SET_PC(PC)
	POST_IO
}
RET(4)

// LINK
OP_0x4E50:
{
	u32 res;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	PUSH_32_F(res)
	res = CPU->A[7];
	CPU->A[(Opcode >> 0) & 7] = res;
	CPU->A[7] += (s32)(s16)FETCH_WORD;
	PC += 2;
	POST_IO
}
RET(16)

// LINKA7
OP_0x4E57:
{
	CPU->A[7] -= 4;
	PRE_IO
	WRITE_LONG_DEC_F(CPU->A[7], CPU->A[7])
	CPU->A[7] += (s32)(s16)FETCH_WORD;
	PC += 2;
	POST_IO
}
RET(16)

// ULNK
OP_0x4E58:
{
	u32 res;
	pointer src;
	src = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->A[7] = (u32)src + 4;
	PRE_IO
	READ_LONG_F((u32)src, res)
	CPU->A[(Opcode >> 0) & 7] = res;
	POST_IO
}
RET(12)

// ULNKA7
OP_0x4E5F:
{
	PRE_IO
	READ_LONG_F(CPU->A[7], CPU->A[7])
	POST_IO
}
RET(12)

// MOVEAUSP
OP_0x4E60:
{
	u32 res;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(4)
	}
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	CPU->USP = res;
}
RET(4)

// MOVEUSPA
OP_0x4E68:
{
	u32 res;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(4)
	}
	res = CPU->USP;
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(4)

// RESET
OP_0x4E70:
{
	u32 res;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(4)
	}
	PRE_IO
	CPU->Reset_CallBack();
	POST_IO
}
RET(132)

// NOP
OP_0x4E71:
{
}
RET(4)

// STOP
OP_0x4E72:
{
	u32 res;
	if (!CPU->flag_S)
	{
		PC += 2;
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(4)
	}
	res = FETCH_WORD & C68K_SR_MASK;
	PC += 2;
	SET_SR(res)
	if (!CPU->flag_S)
	{
		res = CPU->A[7];
		CPU->A[7] = CPU->USP;
		CPU->USP = res;
	}
	CPU->Status |= C68K_HALTED;
	CCnt = 0;
}
CCnt -= 4;
goto C68k_Exec_End;

// RTE
OP_0x4E73:
{
	u32 res;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
		res = C68K_PRIVILEGE_VIOLATION_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(4)
	}
	PRE_IO
	POP_16_F(res)
	SET_SR(res)
	POP_32_F(res)
	SET_PC(res)
	if (!CPU->flag_S)
	{
		res = CPU->A[7];
		CPU->A[7] = CPU->USP;
		CPU->USP = res;
	}
}
POST_IO
CCnt -= 20;
goto C68k_Exec_End;

// RTS
OP_0x4E75:
{
	u32 res;
	PRE_IO
	POP_32_F(res)
	SET_PC(res)
	POST_IO
}
RET(16)

// TRAPV
OP_0x4E76:
{
	u32 res;
	if (CPU->flag_V & 0x80)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_TRAPV_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(4)

// RTR
OP_0x4E77:
{
	u32 res;
	PRE_IO
	POP_16_F(res)
	SET_CCR(res)
	POP_32_F(res)
	SET_PC(res)
	POST_IO
}
RET(20)

// JSR
OP_0x4E90:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(16)

// JSR
OP_0x4EA8:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(18)

// JSR
OP_0x4EB0:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(22)

// JSR
OP_0x4EB8:
{
	u32 adr;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(18)

// JSR
OP_0x4EB9:
{
	u32 adr;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(20)

// JSR
OP_0x4EBA:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(18)

// JSR
OP_0x4EBB:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	SET_PC(adr)
	POST_IO
}
RET(22)

// JMP
OP_0x4ED0:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	SET_PC(adr)
}
RET(8)

// JMP
OP_0x4EE8:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	SET_PC(adr)
}
RET(10)

// JMP
OP_0x4EF0:
{
	u32 adr;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	SET_PC(adr)
}
RET(14)

// JMP
OP_0x4EF8:
{
	u32 adr;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	SET_PC(adr)
}
RET(10)

// JMP
OP_0x4EF9:
{
	u32 adr;
	adr = (s32)FETCH_LONG;
	PC += 4;
	SET_PC(adr)
}
RET(12)

// JMP
OP_0x4EFA:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	SET_PC(adr)
}
RET(10)

// JMP
OP_0x4EFB:
{
	u32 adr;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	SET_PC(adr)
}
RET(14)

// CHK
OP_0x4180:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(10)

// CHK
OP_0x4190:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(14)

// CHK
OP_0x4198:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(14)

// CHK
OP_0x41A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(16)

// CHK
OP_0x41A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(18)

// CHK
OP_0x41B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(20)

// CHK
OP_0x41B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(18)

// CHK
OP_0x41B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(22)

// CHK
OP_0x41BA:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(18)

// CHK
OP_0x41BB:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(20)

// CHK
OP_0x41BC:
{
	u32 res;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(14)

// CHK
OP_0x419F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(14)

// CHK
OP_0x41A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	if (((s32)res < 0) || (res > src))
	{
		CPU->flag_N = res >> 8;
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_CHK_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	}
	POST_IO
}
RET(16)

// LEA
OP_0x41D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(4)

// LEA
OP_0x41E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// LEA
OP_0x41F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)

// LEA
OP_0x41F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// LEA
OP_0x41F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)

// LEA
OP_0x41FA:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// LEA
OP_0x41FB:
{
	u32 adr;
	u32 res;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	res = adr;
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)
