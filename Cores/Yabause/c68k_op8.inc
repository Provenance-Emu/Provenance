
// ORaD
OP_0x8000:
{
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ORaD
OP_0x8010:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8018:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8020:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ORaD
OP_0x8028:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x8030:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ORaD
OP_0x8038:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x8039:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ORaD
OP_0x803A:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x803B:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ORaD
OP_0x803C:
{
	u32 res;
	pointer src;
	src = FETCH_BYTE;
	PC += 2;
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ORaD
OP_0x801F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8027:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ORaD
OP_0x8040:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ORaD
OP_0x8050:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8058:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8060:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ORaD
OP_0x8068:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x8070:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ORaD
OP_0x8078:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x8079:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ORaD
OP_0x807A:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ORaD
OP_0x807B:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ORaD
OP_0x807C:
{
	u32 res;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ORaD
OP_0x805F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ORaD
OP_0x8067:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ORaD
OP_0x8080:
{
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// ORaD
OP_0x8090:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ORaD
OP_0x8098:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ORaD
OP_0x80A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ORaD
OP_0x80A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ORaD
OP_0x80B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ORaD
OP_0x80B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ORaD
OP_0x80B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(24)

// ORaD
OP_0x80BA:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ORaD
OP_0x80BB:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ORaD
OP_0x80BC:
{
	u32 res;
	pointer src;
	src = FETCH_LONG;
	PC += 4;
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(14)

// ORaD
OP_0x809F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ORaD
OP_0x80A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ORDa
OP_0x8110:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8118:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8120:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ORDa
OP_0x8128:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ORDa
OP_0x8130:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ORDa
OP_0x8138:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ORDa
OP_0x8139:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// ORDa
OP_0x811F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8127:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ORDa
OP_0x8150:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8158:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8160:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ORDa
OP_0x8168:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ORDa
OP_0x8170:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ORDa
OP_0x8178:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ORDa
OP_0x8179:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ORDa
OP_0x815F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ORDa
OP_0x8167:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ORDa
OP_0x8190:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ORDa
OP_0x8198:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ORDa
OP_0x81A0:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// ORDa
OP_0x81A8:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ORDa
OP_0x81B0:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// ORDa
OP_0x81B8:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ORDa
OP_0x81B9:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// ORDa
OP_0x819F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ORDa
OP_0x81A7:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// SBCD
OP_0x8100:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (dst & 0xF) - (src & 0xF) - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// SBCDM
OP_0x8108:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SBCD7M
OP_0x810F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 1;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SBCDM7
OP_0x8F08:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SBCD7M7
OP_0x8F0F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// DIVU
OP_0x80C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(10)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(70)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(90)

// DIVU
OP_0x80D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(74)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(94)

// DIVU
OP_0x80D8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(74)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(94)

// DIVU
OP_0x80E0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(16)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(76)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(96)

// DIVU
OP_0x80E8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(78)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(98)

// DIVU
OP_0x80F0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(20)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(80)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(100)

// DIVU
OP_0x80F8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(78)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(98)

// DIVU
OP_0x80F9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(22)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(82)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(102)

// DIVU
OP_0x80FA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(78)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(98)

// DIVU
OP_0x80FB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(20)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(80)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(100)

// DIVU
OP_0x80FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(74)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(94)

// DIVU
OP_0x80DF:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(74)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(94)

// DIVU
OP_0x80E7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(16)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	{
		u32 q, r;

		q = (u32)dst / (u32)src;
		r = (u32)dst % (u32)src;

		if (q & 0xFFFF0000)
		{
			CPU->flag_V = C68K_SR_V;
	RET(76)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(96)

// DIVS
OP_0x81C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(10)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(50)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(80)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(108)

// DIVS
OP_0x81D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(84)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(112)

// DIVS
OP_0x81D8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(84)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(112)

// DIVS
OP_0x81E0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(16)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(56)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(86)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(114)

// DIVS
OP_0x81E8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(88)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(116)

// DIVS
OP_0x81F0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(20)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(60)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(90)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(118)

// DIVS
OP_0x81F8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(88)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(116)

// DIVS
OP_0x81F9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(22)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(62)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(92)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(120)

// DIVS
OP_0x81FA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(18)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(88)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(116)

// DIVS
OP_0x81FB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(20)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(60)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(90)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(118)

// DIVS
OP_0x81FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(84)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(112)

// DIVS
OP_0x81DF:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(14)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(84)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(112)

// DIVS
OP_0x81E7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		if (!CPU->flag_S)
		{
			res = CPU->USP;
			CPU->USP = CPU->A[7];
			CPU->A[7] = res;
		}
		res = C68K_ZERO_DIVIDE_EX;
	POST_IO
	CCnt -= c68k_exception_cycle_table[res];
	PRE_IO
		PUSH_32_F((u32)(PC - CPU->BasePC))
		PUSH_16_F(GET_SR)
		CPU->flag_S = C68K_SR_S;
		READ_LONG_F(res * 4, PC)
		SET_PC(PC)
	POST_IO
	RET(16)
	}
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	if ((dst == 0x80000000) && (src == -1))
	{
		CPU->flag_notZ = CPU->flag_N = 0;
		CPU->flag_V = CPU->flag_C = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	RET(56)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			CPU->flag_V = C68K_SR_V;
	RET(86)
		}
		q &= 0x0000FFFF;
		CPU->flag_notZ = q;
		CPU->flag_N = q >> 8;
		CPU->flag_V = CPU->flag_C = 0;
		res = q | (r << 16);
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	}
}
RET(114)
