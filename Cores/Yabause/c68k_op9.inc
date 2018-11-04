
// SUBaD
OP_0x9000:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBaD
OP_0x9008:
{
	u32 res;
	pointer dst;
	pointer src;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBaD
OP_0x9010:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9018:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9020:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// SUBaD
OP_0x9028:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x9030:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// SUBaD
OP_0x9038:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x9039:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// SUBaD
OP_0x903A:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x903B:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// SUBaD
OP_0x903C:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_BYTE;
	PC += 2;
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// SUBaD
OP_0x901F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9027:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// SUBaD
OP_0x9040:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBaD
OP_0x9048:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->A[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBaD
OP_0x9050:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9058:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9060:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// SUBaD
OP_0x9068:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x9070:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// SUBaD
OP_0x9078:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x9079:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// SUBaD
OP_0x907A:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// SUBaD
OP_0x907B:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// SUBaD
OP_0x907C:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// SUBaD
OP_0x905F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// SUBaD
OP_0x9067:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// SUBaD
OP_0x9080:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// SUBaD
OP_0x9088:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// SUBaD
OP_0x9090:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// SUBaD
OP_0x9098:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// SUBaD
OP_0x90A0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// SUBaD
OP_0x90A8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// SUBaD
OP_0x90B0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// SUBaD
OP_0x90B8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// SUBaD
OP_0x90B9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(24)

// SUBaD
OP_0x90BA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// SUBaD
OP_0x90BB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// SUBaD
OP_0x90BC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_LONG;
	PC += 4;
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(14)

// SUBaD
OP_0x909F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// SUBaD
OP_0x90A7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// SUBDa
OP_0x9110:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9118:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9120:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// SUBDa
OP_0x9128:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// SUBDa
OP_0x9130:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SUBDa
OP_0x9138:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// SUBDa
OP_0x9139:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// SUBDa
OP_0x911F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9127:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// SUBDa
OP_0x9150:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9158:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9160:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// SUBDa
OP_0x9168:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// SUBDa
OP_0x9170:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// SUBDa
OP_0x9178:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// SUBDa
OP_0x9179:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// SUBDa
OP_0x915F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// SUBDa
OP_0x9167:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// SUBDa
OP_0x9190:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// SUBDa
OP_0x9198:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// SUBDa
OP_0x91A0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// SUBDa
OP_0x91A8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// SUBDa
OP_0x91B0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// SUBDa
OP_0x91B8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// SUBDa
OP_0x91B9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// SUBDa
OP_0x919F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// SUBDa
OP_0x91A7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// SUBX
OP_0x9100:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ |= res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBX
OP_0x9140:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// SUBX
OP_0x9180:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// SUBXM
OP_0x9108:
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
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SUBXM
OP_0x9148:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 2;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_WORD_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// SUBXM
OP_0x9188:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_LONG_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// SUBX7M
OP_0x910F:
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
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SUBX7M
OP_0x914F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 2;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_WORD_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// SUBX7M
OP_0x918F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = CPU->A[(Opcode >> 9) & 7] - 4;
	CPU->A[(Opcode >> 9) & 7] = adr;
	READ_LONG_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// SUBXM7
OP_0x9F08:
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
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SUBXM7
OP_0x9F48:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	READ_WORD_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// SUBXM7
OP_0x9F88:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	READ_LONG_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// SUBX7M7
OP_0x9F0F:
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
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// SUBX7M7
OP_0x9F4F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	READ_WORD_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// SUBX7M7
OP_0x9F8F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	READ_LONG_F(adr, dst)
	res = (u32)dst - (u32)src - ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// SUBA
OP_0x90C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// SUBA
OP_0x90C8:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// SUBA
OP_0x90D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// SUBA
OP_0x90D8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// SUBA
OP_0x90E0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)

// SUBA
OP_0x90E8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x90F0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// SUBA
OP_0x90F8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x90F9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// SUBA
OP_0x90FA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x90FB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// SUBA
OP_0x90FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)FETCH_WORD;
	PC += 2;
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)

// SUBA
OP_0x90DF:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// SUBA
OP_0x90E7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)

// SUBA
OP_0x91C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(6)

// SUBA
OP_0x91C8:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(6)

// SUBA
OP_0x91D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x91D8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x91E0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 4;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// SUBA
OP_0x91E8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// SUBA
OP_0x91F0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(22)

// SUBA
OP_0x91F8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// SUBA
OP_0x91F9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(24)

// SUBA
OP_0x91FA:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC) + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// SUBA
OP_0x91FB:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = (u32)(PC - CPU->BasePC);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(22)

// SUBA
OP_0x91FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)FETCH_LONG;
	PC += 4;
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(14)

// SUBA
OP_0x91DF:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// SUBA
OP_0x91E7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[7] - 4;
	CPU->A[7] = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)
