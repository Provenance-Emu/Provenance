
// ADDaD
OP_0xD000:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDaD
OP_0xD008:
{
	u32 res;
	pointer dst;
	pointer src;
	// can't read byte from Ax registers !
	CPU->Status |= C68K_FAULTED;
	CCnt = 0;
	goto C68k_Exec_Really_End;
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDaD
OP_0xD010:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD018:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD020:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ADDaD
OP_0xD028:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD030:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ADDaD
OP_0xD038:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD039:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ADDaD
OP_0xD03A:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD03B:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ADDaD
OP_0xD03C:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_BYTE;
	PC += 2;
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ADDaD
OP_0xD01F:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD027:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ADDaD
OP_0xD040:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDaD
OP_0xD048:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->A[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDaD
OP_0xD050:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD058:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD060:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ADDaD
OP_0xD068:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD070:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ADDaD
OP_0xD078:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD079:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ADDaD
OP_0xD07A:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(12)

// ADDaD
OP_0xD07B:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(14)

// ADDaD
OP_0xD07C:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_WORD;
	PC += 2;
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ADDaD
OP_0xD05F:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(8)

// ADDaD
OP_0xD067:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(10)

// ADDaD
OP_0xD080:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// ADDaD
OP_0xD088:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(6)

// ADDaD
OP_0xD090:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, src)
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ADDaD
OP_0xD098:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ADDaD
OP_0xD0A0:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ADDaD
OP_0xD0A8:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ADDaD
OP_0xD0B0:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ADDaD
OP_0xD0B8:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ADDaD
OP_0xD0B9:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(24)

// ADDaD
OP_0xD0BA:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(20)

// ADDaD
OP_0xD0BB:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(22)

// ADDaD
OP_0xD0BC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = FETCH_LONG;
	PC += 4;
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(14)

// ADDaD
OP_0xD09F:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(16)

// ADDaD
OP_0xD0A7:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
	POST_IO
}
RET(18)

// ADDDa
OP_0xD110:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD118:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD120:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ADDDa
OP_0xD128:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ADDDa
OP_0xD130:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ADDDa
OP_0xD138:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(16)

// ADDDa
OP_0xD139:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(20)

// ADDDa
OP_0xD11F:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD127:
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
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(14)

// ADDDa
OP_0xD150:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, dst)
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD158:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD160:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ADDDa
OP_0xD168:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ADDDa
OP_0xD170:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ADDDa
OP_0xD178:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ADDDa
OP_0xD179:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ADDDa
OP_0xD15F:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ADDDa
OP_0xD167:
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
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ADDDa
OP_0xD190:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 9) & 7];
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_LONG_F(adr, dst)
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ADDDa
OP_0xD198:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ADDDa
OP_0xD1A0:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// ADDDa
OP_0xD1A8:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ADDDa
OP_0xD1B0:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(26)

// ADDDa
OP_0xD1B8:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(24)

// ADDDa
OP_0xD1B9:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(28)

// ADDDa
OP_0xD19F:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(20)

// ADDDa
OP_0xD1A7:
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
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(22)

// ADDX
OP_0xD100:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	dst = (u8)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ |= res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDX
OP_0xD140:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	dst = (u16)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)

// ADDX
OP_0xD180:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->D[(Opcode >> 9) & 7];
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(8)

// ADDXM
OP_0xD108:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ADDXM
OP_0xD148:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ADDXM
OP_0xD188:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// ADDX7M
OP_0xD10F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ADDX7M
OP_0xD14F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ADDX7M
OP_0xD18F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// ADDXM7
OP_0xDF08:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ADDXM7
OP_0xDF48:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ADDXM7
OP_0xDF88:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// ADDX7M7
OP_0xDF0F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
}
RET(18)

// ADDX7M7
OP_0xDF4F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ADDX7M7
OP_0xDF8F:
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
	res = (u32)dst + (u32)src + ((CPU->flag_X >> 8) & 1);
	CPU->flag_notZ |= res;
	CPU->flag_X = CPU->flag_C = (((u32)src & dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
}
RET(30)

// ADDA
OP_0xD0C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// ADDA
OP_0xD0C8:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(8)

// ADDA
OP_0xD0D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// ADDA
OP_0xD0D8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// ADDA
OP_0xD0E0:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)

// ADDA
OP_0xD0E8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD0F0:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// ADDA
OP_0xD0F8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD0F9:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// ADDA
OP_0xD0FA:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD0FB:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// ADDA
OP_0xD0FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s16)FETCH_WORD;
	PC += 2;
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(12)

// ADDA
OP_0xD0DF:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(12)

// ADDA
OP_0xD0E7:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(14)

// ADDA
OP_0xD1C0:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)CPU->D[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(6)

// ADDA
OP_0xD1C8:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)CPU->A[(Opcode >> 0) & 7];
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(6)

// ADDA
OP_0xD1D0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD1D8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD1E0:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)

// ADDA
OP_0xD1E8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// ADDA
OP_0xD1F0:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(22)

// ADDA
OP_0xD1F8:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// ADDA
OP_0xD1F9:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(24)

// ADDA
OP_0xD1FA:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(20)

// ADDA
OP_0xD1FB:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(22)

// ADDA
OP_0xD1FC:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (s32)(s32)FETCH_LONG;
	PC += 4;
	dst = (u32)CPU->A[(Opcode >> 9) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
}
RET(14)

// ADDA
OP_0xD1DF:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(16)

// ADDA
OP_0xD1E7:
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
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 9) & 7] = res;
	POST_IO
}
RET(18)
