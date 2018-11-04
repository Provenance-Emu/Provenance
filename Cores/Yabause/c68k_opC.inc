
// ANDaD
OP_0xC000:
{
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ANDaD
OP_0xC010:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC018:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC020:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ANDaD
OP_0xC028:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC030:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ANDaD
OP_0xC038:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC039:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ANDaD
OP_0xC03A:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC03B:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ANDaD
OP_0xC03C:
{
	u32 res;
	pointer src;
	src = FETCH_BYTE;
	PC += 2;
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ANDaD
OP_0xC01F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC027:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = (u8)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ANDaD
OP_0xC040:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ANDaD
OP_0xC050:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC058:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC060:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ANDaD
OP_0xC068:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC070:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ANDaD
OP_0xC078:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC079:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ANDaD
OP_0xC07A:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ANDaD
OP_0xC07B:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ANDaD
OP_0xC07C:
{
	u32 res;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ANDaD
OP_0xC05F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ANDaD
OP_0xC067:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ANDaD
OP_0xC080:
{
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// ANDaD
OP_0xC090:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ANDaD
OP_0xC098:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ANDaD
OP_0xC0A0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ANDaD
OP_0xC0A8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ANDaD
OP_0xC0B0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ANDaD
OP_0xC0B8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ANDaD
OP_0xC0B9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(24)

// ANDaD
OP_0xC0BA:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ANDaD
OP_0xC0BB:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ANDaD
OP_0xC0BC:
{
	u32 res;
	pointer src;
	src = FETCH_LONG;
	PC += 4;
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(14)

// ANDaD
OP_0xC09F:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ANDaD
OP_0xC0A7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = (u32)CPU->D[(Opcode >> 9) & 7];
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ANDDa
OP_0xC110:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC118:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC120:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ANDDa
OP_0xC128:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ANDDa
OP_0xC130:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ANDDa
OP_0xC138:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ANDDa
OP_0xC139:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// ANDDa
OP_0xC11F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC127:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ANDDa
OP_0xC150:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC158:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC160:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ANDDa
OP_0xC168:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ANDDa
OP_0xC170:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ANDDa
OP_0xC178:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ANDDa
OP_0xC179:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ANDDa
OP_0xC15F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ANDDa
OP_0xC167:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ANDDa
OP_0xC190:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ANDDa
OP_0xC198:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ANDDa
OP_0xC1A0:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// ANDDa
OP_0xC1A8:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ANDDa
OP_0xC1B0:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// ANDDa
OP_0xC1B8:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ANDDa
OP_0xC1B9:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// ANDDa
OP_0xC19F:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ANDDa
OP_0xC1A7:
{
	u32 adr;
	u32 res;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	CPU->flag_C = 0;
	CPU->flag_V = 0;
	CPU->flag_notZ = res;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// ABCD
OP_0xC100:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (dst & 0xF) + (src & 0xF) + ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// ABCDM
OP_0xC108:
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
	res = (dst & 0xF) + (src & 0xF) + ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ABCD7M
OP_0xC10F:
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
	res = (dst & 0xF) + (src & 0xF) + ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ABCDM7
OP_0xCF08:
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
	res = (dst & 0xF) + (src & 0xF) + ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ABCD7M7
OP_0xCF0F:
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
	res = (dst & 0xF) + (src & 0xF) + ((CPU->flag_X >> C68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		CPU->flag_X = CPU->flag_C = C68K_SR_C;
	}
	else CPU->flag_X = CPU->flag_C = 0;
	CPU->flag_notZ |= res & 0xFF;
	CPU->flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// MULU
OP_0xC0C0:
{
	u32 res;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(50)

// MULU
OP_0xC0D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULU
OP_0xC0D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULU
OP_0xC0E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(56)

// MULU
OP_0xC0E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULU
OP_0xC0F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(60)

// MULU
OP_0xC0F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULU
OP_0xC0F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(62)

// MULU
OP_0xC0FA:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULU
OP_0xC0FB:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(60)

// MULU
OP_0xC0FC:
{
	u32 res;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(54)

// MULU
OP_0xC0DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULU
OP_0xC0E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = (u16)CPU->D[(Opcode >> 9) & 7];
	res *= (u32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(56)

// MULS
OP_0xC1C0:
{
	u32 res;
	pointer src;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(50)

// MULS
OP_0xC1D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULS
OP_0xC1D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULS
OP_0xC1E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(56)

// MULS
OP_0xC1E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULS
OP_0xC1F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(60)

// MULS
OP_0xC1F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULS
OP_0xC1F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(62)

// MULS
OP_0xC1FA:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(58)

// MULS
OP_0xC1FB:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(60)

// MULS
OP_0xC1FC:
{
	u32 res;
	pointer src;
	src = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(54)

// MULS
OP_0xC1DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(54)

// MULS
OP_0xC1E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)(s16)CPU->D[(Opcode >> 9) & 7];
	res *= (s32)src;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	CPU->flag_V = CPU->flag_C = 0;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(56)

// EXGDD
OP_0xC140:
{
	u32 res;
	pointer src;
	res = (u32)CPU->D[(Opcode >> 0) & 7];
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	res = (u32)src;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// EXGAA
OP_0xC148:
{
	u32 res;
	pointer src;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	src = (u32)CPU->A[(Opcode >> 9) & 7];
	CPU->A[(Opcode >> 9) & 7] = res;
	res = (u32)src;
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(6)

// EXGAD
OP_0xC188:
{
	u32 res;
	pointer src;
	res = (u32)CPU->A[(Opcode >> 0) & 7];
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	res = (u32)src;
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(6)
