
#ifdef PICODRIVE_HACK
#define NOT_POLLING g_m68kcontext->not_polling = 1;
#else
#define NOT_POLLING
#endif

// ORI
OPCODE(0x0000)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	res = DREGu8((Opcode >> 0) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(8)
}

// ORI
OPCODE(0x0010)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0018)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0020)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ORI
OPCODE(0x0028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ORI
OPCODE(0x0030)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// ORI
OPCODE(0x0038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ORI
OPCODE(0x0039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// ORI
OPCODE(0x001F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0027)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ORI
OPCODE(0x0040)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 0) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 0) & 7) = res;
RET(8)
}

// ORI
OPCODE(0x0050)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0058)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0060)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ORI
OPCODE(0x0068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ORI
OPCODE(0x0070)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// ORI
OPCODE(0x0078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ORI
OPCODE(0x0079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// ORI
OPCODE(0x005F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ORI
OPCODE(0x0067)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ORI
OPCODE(0x0080)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	res = DREGu32((Opcode >> 0) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(16)
}

// ORI
OPCODE(0x0090)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ORI
OPCODE(0x0098)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ORI
OPCODE(0x00A0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ORI
OPCODE(0x00A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ORI
OPCODE(0x00B0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// ORI
OPCODE(0x00B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ORI
OPCODE(0x00B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// ORI
OPCODE(0x009F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ORI
OPCODE(0x00A7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ORICCR
OPCODE(0x003C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	res &= M68K_CCR_MASK;
	res |= GET_CCR;
	SET_CCR(res)
RET(20)
}

// ORISR
OPCODE(0x007C)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		u32 res;
		FETCH_WORD(res);
		res &= M68K_SR_MASK;
		res |= GET_SR;
		SET_SR(res)
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
#ifdef USE_CYCLONE_TIMING
		RET(0)
#else
		RET(4)
#endif
	}
RET(20)
}

// ANDI
OPCODE(0x0200)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	res = DREGu8((Opcode >> 0) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(8)
}

// ANDI
OPCODE(0x0210)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0218)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0220)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ANDI
OPCODE(0x0228)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ANDI
OPCODE(0x0230)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// ANDI
OPCODE(0x0238)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ANDI
OPCODE(0x0239)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// ANDI
OPCODE(0x021F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0227)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ANDI
OPCODE(0x0240)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 0) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 0) & 7) = res;
RET(8)
}

// ANDI
OPCODE(0x0250)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0258)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0260)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ANDI
OPCODE(0x0268)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ANDI
OPCODE(0x0270)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// ANDI
OPCODE(0x0278)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ANDI
OPCODE(0x0279)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// ANDI
OPCODE(0x025F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ANDI
OPCODE(0x0267)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ANDI
OPCODE(0x0280)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	res = DREGu32((Opcode >> 0) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(16)
#endif
}

// ANDI
OPCODE(0x0290)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ANDI
OPCODE(0x0298)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ANDI
OPCODE(0x02A0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ANDI
OPCODE(0x02A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ANDI
OPCODE(0x02B0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// ANDI
OPCODE(0x02B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ANDI
OPCODE(0x02B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// ANDI
OPCODE(0x029F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ANDI
OPCODE(0x02A7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ANDICCR
OPCODE(0x023C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	res &= M68K_CCR_MASK;
	res &= GET_CCR;
	SET_CCR(res)
RET(20)
}

// ANDISR
OPCODE(0x027C)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_WORD(res);
		res &= M68K_SR_MASK;
		res &= GET_SR;
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(20)
}

// EORI
OPCODE(0x0A00)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	res = DREGu8((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(8)
}

// EORI
OPCODE(0x0A10)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A18)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A20)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// EORI
OPCODE(0x0A28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// EORI
OPCODE(0x0A30)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// EORI
OPCODE(0x0A38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// EORI
OPCODE(0x0A39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// EORI
OPCODE(0x0A1F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A27)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// EORI
OPCODE(0x0A40)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 0) & 7) = res;
RET(8)
}

// EORI
OPCODE(0x0A50)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A58)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A60)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// EORI
OPCODE(0x0A68)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// EORI
OPCODE(0x0A70)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// EORI
OPCODE(0x0A78)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// EORI
OPCODE(0x0A79)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// EORI
OPCODE(0x0A5F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// EORI
OPCODE(0x0A67)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// EORI
OPCODE(0x0A80)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	res = DREGu32((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(16)
}

// EORI
OPCODE(0x0A90)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// EORI
OPCODE(0x0A98)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// EORI
OPCODE(0x0AA0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// EORI
OPCODE(0x0AA8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// EORI
OPCODE(0x0AB0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// EORI
OPCODE(0x0AB8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// EORI
OPCODE(0x0AB9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// EORI
OPCODE(0x0A9F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// EORI
OPCODE(0x0AA7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// EORICCR
OPCODE(0x0A3C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	res &= M68K_CCR_MASK;
	res ^= GET_CCR;
	SET_CCR(res)
RET(20)
}

// EORISR
OPCODE(0x0A7C)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_WORD(res);
		res &= M68K_SR_MASK;
		res ^= GET_SR;
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(0)
	}
RET(20)
}

// SUBI
OPCODE(0x0400)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 0) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(8)
}

// SUBI
OPCODE(0x0410)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0418)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0420)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBI
OPCODE(0x0428)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// SUBI
OPCODE(0x0430)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// SUBI
OPCODE(0x0438)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// SUBI
OPCODE(0x0439)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// SUBI
OPCODE(0x041F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0427)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBI
OPCODE(0x0440)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 0) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(8)
}

// SUBI
OPCODE(0x0450)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0458)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0460)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBI
OPCODE(0x0468)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// SUBI
OPCODE(0x0470)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// SUBI
OPCODE(0x0478)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// SUBI
OPCODE(0x0479)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// SUBI
OPCODE(0x045F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBI
OPCODE(0x0467)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBI
OPCODE(0x0480)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 0) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(16)
}

// SUBI
OPCODE(0x0490)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// SUBI
OPCODE(0x0498)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// SUBI
OPCODE(0x04A0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// SUBI
OPCODE(0x04A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// SUBI
OPCODE(0x04B0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// SUBI
OPCODE(0x04B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// SUBI
OPCODE(0x04B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// SUBI
OPCODE(0x049F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// SUBI
OPCODE(0x04A7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDI
OPCODE(0x0600)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 0) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(8)
}

// ADDI
OPCODE(0x0610)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0618)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0620)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDI
OPCODE(0x0628)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ADDI
OPCODE(0x0630)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// ADDI
OPCODE(0x0638)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ADDI
OPCODE(0x0639)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// ADDI
OPCODE(0x061F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0627)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDI
OPCODE(0x0640)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 0) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(8)
}

// ADDI
OPCODE(0x0650)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0658)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0660)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDI
OPCODE(0x0668)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ADDI
OPCODE(0x0670)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// ADDI
OPCODE(0x0678)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ADDI
OPCODE(0x0679)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// ADDI
OPCODE(0x065F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDI
OPCODE(0x0667)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDI
OPCODE(0x0680)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 0) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(16)
}

// ADDI
OPCODE(0x0690)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ADDI
OPCODE(0x0698)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ADDI
OPCODE(0x06A0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDI
OPCODE(0x06A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ADDI
OPCODE(0x06B0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// ADDI
OPCODE(0x06B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// ADDI
OPCODE(0x06B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// ADDI
OPCODE(0x069F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ADDI
OPCODE(0x06A7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// CMPI
OPCODE(0x0C00)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 0) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
RET(8)
}

// CMPI
OPCODE(0x0C10)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C18)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C20)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(14)
}

// CMPI
OPCODE(0x0C28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(16)
}

// CMPI
OPCODE(0x0C30)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(18)
}

// CMPI
OPCODE(0x0C38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(16)
}

// CMPI
OPCODE(0x0C39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(20)
}

// CMPI
OPCODE(0x0C1F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C27)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(14)
}

// CMPI
OPCODE(0x0C40)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 0) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
RET(8)
}

// CMPI
OPCODE(0x0C50)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C58)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C60)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(14)
}

// CMPI
OPCODE(0x0C68)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(16)
}

// CMPI
OPCODE(0x0C70)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(18)
}

// CMPI
OPCODE(0x0C78)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(16)
}

// CMPI
OPCODE(0x0C79)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(20)
}

// CMPI
OPCODE(0x0C5F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMPI
OPCODE(0x0C67)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(14)
}

// CMPI
OPCODE(0x0C80)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 0) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(14)
}

// CMPI
OPCODE(0x0C90)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPI
OPCODE(0x0C98)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPI
OPCODE(0x0CA0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(22)
}

// CMPI
OPCODE(0x0CA8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(24)
}

// CMPI
OPCODE(0x0CB0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(26)
}

// CMPI
OPCODE(0x0CB8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(24)
}

// CMPI
OPCODE(0x0CB9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(28)
}

// CMPI
OPCODE(0x0C9F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPI
OPCODE(0x0CA7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(22)
}

// BTSTn
OPCODE(0x0800)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
RET(10)
}

// BTSTn
OPCODE(0x0810)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTSTn
OPCODE(0x0818)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTSTn
OPCODE(0x0820)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(14)
}

// BTSTn
OPCODE(0x0828)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(16)
}

// BTSTn
OPCODE(0x0830)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(18)
}

// BTSTn
OPCODE(0x0838)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(16)
}

// BTSTn
OPCODE(0x0839)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(20)
}

// BTSTn
OPCODE(0x083A)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(16)
}

// BTSTn
OPCODE(0x083B)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(18)
}

// BTSTn
OPCODE(0x081F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTSTn
OPCODE(0x0827)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(14)
}

// BCHGn
OPCODE(0x0840)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res ^= src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(12)
}

// BCHGn
OPCODE(0x0850)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCHGn
OPCODE(0x0858)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCHGn
OPCODE(0x0860)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BCHGn
OPCODE(0x0868)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCHGn
OPCODE(0x0870)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// BCHGn
OPCODE(0x0878)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCHGn
OPCODE(0x0879)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// BCHGn
OPCODE(0x085F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCHGn
OPCODE(0x0867)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BCLRn
OPCODE(0x0880)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res &= ~src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(14)
}

// BCLRn
OPCODE(0x0890)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCLRn
OPCODE(0x0898)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCLRn
OPCODE(0x08A0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BCLRn
OPCODE(0x08A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCLRn
OPCODE(0x08B0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// BCLRn
OPCODE(0x08B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCLRn
OPCODE(0x08B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// BCLRn
OPCODE(0x089F)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCLRn
OPCODE(0x08A7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BSETn
OPCODE(0x08C0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res |= src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(12)
}

// BSETn
OPCODE(0x08D0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BSETn
OPCODE(0x08D8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BSETn
OPCODE(0x08E0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BSETn
OPCODE(0x08E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BSETn
OPCODE(0x08F0)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// BSETn
OPCODE(0x08F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BSETn
OPCODE(0x08F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// BSETn
OPCODE(0x08DF)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BSETn
OPCODE(0x08E7)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BTST
OPCODE(0x0100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
RET(6)
}

// BTST
OPCODE(0x0110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(8)
}

// BTST
OPCODE(0x0118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(8)
}

// BTST
OPCODE(0x0120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(10)
}

// BTST
OPCODE(0x0128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTST
OPCODE(0x0130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(14)
}

// BTST
OPCODE(0x0138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTST
OPCODE(0x0139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(16)
}

// BTST
OPCODE(0x013A)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(12)
}

// BTST
OPCODE(0x013B)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(14)
}

// BTST
OPCODE(0x013C)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_BYTE(res);
	flag_NotZ = res & src;
RET(8)
}

// BTST
OPCODE(0x011F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(8)
}

// BTST
OPCODE(0x0127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	POST_IO
RET(10)
}

// BCHG
OPCODE(0x0140)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res ^= src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// BCHG
OPCODE(0x0150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCHG
OPCODE(0x0158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCHG
OPCODE(0x0160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// BCHG
OPCODE(0x0168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCHG
OPCODE(0x0170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BCHG
OPCODE(0x0178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCHG
OPCODE(0x0179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCHG
OPCODE(0x015F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCHG
OPCODE(0x0167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res ^= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// BCLR
OPCODE(0x0180)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res &= ~src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(10)
}

// BCLR
OPCODE(0x0190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCLR
OPCODE(0x0198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCLR
OPCODE(0x01A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// BCLR
OPCODE(0x01A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCLR
OPCODE(0x01B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BCLR
OPCODE(0x01B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BCLR
OPCODE(0x01B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BCLR
OPCODE(0x019F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BCLR
OPCODE(0x01A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res &= ~src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// BSET
OPCODE(0x01C0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	src = 1 << (src & 31);
	res = DREGu32((Opcode >> 0) & 7);
	flag_NotZ = res & src;
	res |= src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// BSET
OPCODE(0x01D0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BSET
OPCODE(0x01D8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BSET
OPCODE(0x01E0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// BSET
OPCODE(0x01E8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BSET
OPCODE(0x01F0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// BSET
OPCODE(0x01F8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// BSET
OPCODE(0x01F9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// BSET
OPCODE(0x01DF)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// BSET
OPCODE(0x01E7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	src = 1 << (src & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_NotZ = res & src;
	res |= src;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEPWaD
OPCODE(0x0108)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr + 0, res)
	READ_BYTE_F(adr + 2, src)
	DREGu16((Opcode >> 9) & 7) = (res << 8) | src;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(24)
#endif
}

// MOVEPLaD
OPCODE(0x0148)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res <<= 24;
	adr += 2;
	READ_BYTE_F(adr, src)
	res |= src << 16;
	adr += 2;
	READ_BYTE_F(adr, src)
	res |= src << 8;
	adr += 2;
	READ_BYTE_F(adr, src)
	DREG((Opcode >> 9) & 7) = res | src;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(24)
#else
RET(32)
#endif
}

// MOVEPWDa
OPCODE(0x0188)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	WRITE_BYTE_F(adr + 0, res >> 8)
	WRITE_BYTE_F(adr + 2, res >> 0)
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(24)
#endif
}

// MOVEPLDa
OPCODE(0x01C8)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res >> 24)
	adr += 2;
	WRITE_BYTE_F(adr, res >> 16)
	adr += 2;
	WRITE_BYTE_F(adr, res >> 8)
	adr += 2;
	WRITE_BYTE_F(adr, res >> 0)
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(24)
#else
RET(32)
#endif
}

// MOVEB
OPCODE(0x1000)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEB
OPCODE(0x1080)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x10C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x1100)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x1140)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1180)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x11C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x13C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1EC0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x1F00)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(8)
}

#if 0
// MOVEB
OPCODE(0x1008)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
*/
RET(4)
}

// MOVEB
OPCODE(0x1088)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(8)
}

// MOVEB
OPCODE(0x10C8)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(8)
}

// MOVEB
OPCODE(0x1108)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(8)
}

// MOVEB
OPCODE(0x1148)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(12)
}

// MOVEB
OPCODE(0x1188)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(14)
}

// MOVEB
OPCODE(0x11C8)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(12)
}

// MOVEB
OPCODE(0x13C8)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(16)
}

// MOVEB
OPCODE(0x1EC8)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(8)
}

// MOVEB
OPCODE(0x1F08)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
*/
RET(8)
}
#endif

// MOVEB
OPCODE(0x1010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x1090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1110)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1150)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1190)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x13D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1ED0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1F10)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x1098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1118)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1158)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1198)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x13D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1ED8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1F18)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// MOVEB
OPCODE(0x10A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x10E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1120)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1160)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x11E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x13E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x1EE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1F20)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x10E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1128)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1168)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x11A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x11E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x13E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x1EE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1F28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x10B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x10F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x1130)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x1170)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x11B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x11F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x13F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(26)
}

// MOVEB
OPCODE(0x1EF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x1F30)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x1038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x10F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1138)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1178)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x11B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x11F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x13F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x1EF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1F38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x10B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x10F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1139)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1179)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x11B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(26)
}

// MOVEB
OPCODE(0x11F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x13F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(28)
}

// MOVEB
OPCODE(0x1EF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1F39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x103A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x10FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x113A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x117A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x11BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x11FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x13FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x1EFA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x1F3A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x103B)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x10BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x10FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x113B)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x117B)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x11BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(24)
}

// MOVEB
OPCODE(0x11FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x13FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(26)
}

// MOVEB
OPCODE(0x1EFB)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x1F3B)
{
	u32 adr, res;
	u32 src, dst;

	adr = (uptr)(PC) - BasePC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x103C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(8)
}

// MOVEB
OPCODE(0x10BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x113C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x117C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x11BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x13FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1EFC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1F3C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x101F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEB
OPCODE(0x109F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x10DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x111F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x115F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x119F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// MOVEB
OPCODE(0x13DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x1EDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1F1F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// MOVEB
OPCODE(0x1027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// MOVEB
OPCODE(0x10A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x10E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1127)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1167)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x11A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// MOVEB
OPCODE(0x11E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_SWORD(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MOVEB
OPCODE(0x13E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	FETCH_LONG(adr);
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(22)
}

// MOVEB
OPCODE(0x1EE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEB
OPCODE(0x1F27)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// MOVEL
OPCODE(0x2000)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEL
OPCODE(0x2080)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x20C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2100)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2140)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x2180)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(18)
}

// MOVEL
OPCODE(0x21C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x23C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2EC0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2F00)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2008)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEL
OPCODE(0x2088)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x20C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2108)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2148)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x2188)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(18)
}

// MOVEL
OPCODE(0x21C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x23C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2EC8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2F08)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x20D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2110)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2150)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2190)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x23D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2ED0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2F10)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x2098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x20D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2118)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2158)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2198)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x23D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2ED8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2F18)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEL
OPCODE(0x20A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x20E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2120)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2160)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x21E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x23E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x2EE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2F20)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x20A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x20E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2128)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2168)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x21A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x21E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x23E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x2EE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2F28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// MOVEL
OPCODE(0x20B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x20F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x2130)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x2170)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x21B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x21F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x23F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// MOVEL
OPCODE(0x2EF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x2F30)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x2038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x20B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x20F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2138)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2178)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x21B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x21F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x23F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x2EF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2F38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x20B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x20F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2139)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2179)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x21B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// MOVEL
OPCODE(0x21F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x23F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(36)
}

// MOVEL
OPCODE(0x2EF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2F39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x203A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEL
OPCODE(0x20BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x20FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x213A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x217A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x21BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x21FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x23FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x2EFA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x2F3A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x203B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// MOVEL
OPCODE(0x20BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x20FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x213B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x217B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x21BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(32)
}

// MOVEL
OPCODE(0x21FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x23FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(34)
}

// MOVEL
OPCODE(0x2EFB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x2F3B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x203C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(12)
}

// MOVEL
OPCODE(0x20BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x20FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x213C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x217C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x21BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x23FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2EFC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2F3C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x201F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEL
OPCODE(0x209F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x20DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x211F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x215F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x219F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// MOVEL
OPCODE(0x23DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x2EDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2F1F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(20)
}

// MOVEL
OPCODE(0x2027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEL
OPCODE(0x20A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x20E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2127)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2167)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x21A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// MOVEL
OPCODE(0x21E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_SWORD(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// MOVEL
OPCODE(0x23E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	FETCH_LONG(adr);
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// MOVEL
OPCODE(0x2EE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7);
	AREG(7) += 4;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVEL
OPCODE(0x2F27)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	WRITE_LONG_DEC_F(adr, res)
	POST_IO
RET(22)
}

// MOVEAL
OPCODE(0x2040)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)DREGs32((Opcode >> 0) & 7);
	AREG((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEAL
OPCODE(0x2048)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)AREGs32((Opcode >> 0) & 7);
	AREG((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEAL
OPCODE(0x2050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAL
OPCODE(0x2058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAL
OPCODE(0x2060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEAL
OPCODE(0x2068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEAL
OPCODE(0x2070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// MOVEAL
OPCODE(0x2078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEAL
OPCODE(0x2079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// MOVEAL
OPCODE(0x207A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEAL
OPCODE(0x207B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// MOVEAL
OPCODE(0x207C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(res);
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// MOVEAL
OPCODE(0x205F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAL
OPCODE(0x2067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READSX_LONG_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3000)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEW
OPCODE(0x3080)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x30C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3100)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3140)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3180)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x31C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x33C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3EC0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3F00)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3008)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEW
OPCODE(0x3088)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x30C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3108)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3148)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3188)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x31C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x33C8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3EC8)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3F08)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3110)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3150)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3190)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x33D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3ED0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3F10)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x3098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3118)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3158)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3198)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x33D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3ED8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3F18)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// MOVEW
OPCODE(0x30A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x30E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3120)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3160)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x31E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x33E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x3EE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3F20)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x30E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3128)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3168)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x31A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x31E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x33E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x3EE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3F28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x30B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x30F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x3130)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x3170)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x31B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x31F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x33F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(26)
}

// MOVEW
OPCODE(0x3EF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x3F30)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x3038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x30F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3138)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3178)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x31B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x31F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x33F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x3EF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3F38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x30B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x30F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3139)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3179)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x31B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(26)
}

// MOVEW
OPCODE(0x31F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x33F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(28)
}

// MOVEW
OPCODE(0x3EF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3F39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x303A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x30FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x313A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x317A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x31BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x31FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x33FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x3EFA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x3F3A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x303B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x30BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x30FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x313B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x317B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x31BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(24)
}

// MOVEW
OPCODE(0x31FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x33FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(26)
}

// MOVEW
OPCODE(0x3EFB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x3F3B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x303C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(8)
}

// MOVEW
OPCODE(0x30BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x313C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x317C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x31BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x33FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3EFC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3F3C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x301F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEW
OPCODE(0x309F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x30DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x311F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x315F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x319F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVEW
OPCODE(0x33DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x3EDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3F1F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVEW
OPCODE(0x3027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// MOVEW
OPCODE(0x30A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x30E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3127)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3167)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 9) & 7);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x31A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG((Opcode >> 9) & 7);
	DECODE_EXT_WORD
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVEW
OPCODE(0x31E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_SWORD(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVEW
OPCODE(0x33E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	FETCH_LONG(adr);
	WRITE_WORD_F(adr, res)
	POST_IO
RET(22)
}

// MOVEW
OPCODE(0x3EE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7);
	AREG(7) += 2;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEW
OPCODE(0x3F27)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEAW
OPCODE(0x3040)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)DREGs16((Opcode >> 0) & 7);
	AREG((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEAW
OPCODE(0x3048)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)AREGs16((Opcode >> 0) & 7);
	AREG((Opcode >> 9) & 7) = res;
RET(4)
}

// MOVEAW
OPCODE(0x3050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEAW
OPCODE(0x3058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEAW
OPCODE(0x3060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// MOVEAW
OPCODE(0x3068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAW
OPCODE(0x3070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEAW
OPCODE(0x3078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAW
OPCODE(0x3079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// MOVEAW
OPCODE(0x307A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// MOVEAW
OPCODE(0x307B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// MOVEAW
OPCODE(0x307C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(res);
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// MOVEAW
OPCODE(0x305F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// MOVEAW
OPCODE(0x3067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, res)
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// NEGX
OPCODE(0x4000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// NEGX
OPCODE(0x4010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NEGX
OPCODE(0x4028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NEGX
OPCODE(0x4030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// NEGX
OPCODE(0x4038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NEGX
OPCODE(0x4039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// NEGX
OPCODE(0x401F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NEGX
OPCODE(0x4040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// NEGX
OPCODE(0x4050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NEGX
OPCODE(0x4068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NEGX
OPCODE(0x4070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// NEGX
OPCODE(0x4078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NEGX
OPCODE(0x4079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// NEGX
OPCODE(0x405F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEGX
OPCODE(0x4067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NEGX
OPCODE(0x4080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(6)
}

// NEGX
OPCODE(0x4090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) | (src >> 1) | (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEGX
OPCODE(0x4098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEGX
OPCODE(0x40A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// NEGX
OPCODE(0x40A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NEGX
OPCODE(0x40B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// NEGX
OPCODE(0x40B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NEGX
OPCODE(0x40B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// NEGX
OPCODE(0x409F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEGX
OPCODE(0x40A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_V = (res & src) >> 24;
flag_X = flag_C = (res?1:0)<<8;
//	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// CLR
OPCODE(0x4200)
{
	u32 adr, res;
	u32 src, dst;

	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// CLR
OPCODE(0x4210)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4218)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4220)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// CLR
OPCODE(0x4228)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// CLR
OPCODE(0x4230)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// CLR
OPCODE(0x4238)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// CLR
OPCODE(0x4239)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// CLR
OPCODE(0x421F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4227)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// CLR
OPCODE(0x4240)
{
	u32 adr, res;
	u32 src, dst;

	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// CLR
OPCODE(0x4250)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4258)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4260)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// CLR
OPCODE(0x4268)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// CLR
OPCODE(0x4270)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// CLR
OPCODE(0x4278)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// CLR
OPCODE(0x4279)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// CLR
OPCODE(0x425F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// CLR
OPCODE(0x4267)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// CLR
OPCODE(0x4280)
{
	u32 adr, res;
	u32 src, dst;

	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	DREGu32((Opcode >> 0) & 7) = res;
RET(6)
}

// CLR
OPCODE(0x4290)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// CLR
OPCODE(0x4298)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// CLR
OPCODE(0x42A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// CLR
OPCODE(0x42A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// CLR
OPCODE(0x42B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// CLR
OPCODE(0x42B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// CLR
OPCODE(0x42B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// CLR
OPCODE(0x429F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// CLR
OPCODE(0x42A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	res = 0;
	flag_N = flag_NotZ = flag_V = flag_C = 0;
	PRE_IO
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// NEG
OPCODE(0x4400)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// NEG
OPCODE(0x4410)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4418)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4420)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NEG
OPCODE(0x4428)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NEG
OPCODE(0x4430)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// NEG
OPCODE(0x4438)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NEG
OPCODE(0x4439)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// NEG
OPCODE(0x441F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4427)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = -src;
	flag_V = res & src;
	flag_N = flag_X = flag_C = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NEG
OPCODE(0x4440)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// NEG
OPCODE(0x4450)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4458)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4460)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NEG
OPCODE(0x4468)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NEG
OPCODE(0x4470)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// NEG
OPCODE(0x4478)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NEG
OPCODE(0x4479)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// NEG
OPCODE(0x445F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NEG
OPCODE(0x4467)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = -src;
	flag_V = (res & src) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NEG
OPCODE(0x4480)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(6)
}

// NEG
OPCODE(0x4490)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEG
OPCODE(0x4498)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEG
OPCODE(0x44A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// NEG
OPCODE(0x44A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NEG
OPCODE(0x44B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// NEG
OPCODE(0x44B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NEG
OPCODE(0x44B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// NEG
OPCODE(0x449F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NEG
OPCODE(0x44A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = -src;
	flag_NotZ = res;
	flag_V = (res & src) >> 24;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// NOT
OPCODE(0x4600)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// NOT
OPCODE(0x4610)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4618)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4620)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NOT
OPCODE(0x4628)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NOT
OPCODE(0x4630)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// NOT
OPCODE(0x4638)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// NOT
OPCODE(0x4639)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// NOT
OPCODE(0x461F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4627)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_N = res;
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// NOT
OPCODE(0x4640)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// NOT
OPCODE(0x4650)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4658)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4660)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NOT
OPCODE(0x4668)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NOT
OPCODE(0x4670)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// NOT
OPCODE(0x4678)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// NOT
OPCODE(0x4679)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// NOT
OPCODE(0x465F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// NOT
OPCODE(0x4667)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res & 0xFFFF;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// NOT
OPCODE(0x4680)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(6)
}

// NOT
OPCODE(0x4690)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NOT
OPCODE(0x4698)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NOT
OPCODE(0x46A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// NOT
OPCODE(0x46A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NOT
OPCODE(0x46B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// NOT
OPCODE(0x46B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// NOT
OPCODE(0x46B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// NOT
OPCODE(0x469F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// NOT
OPCODE(0x46A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = ~src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// MOVESRa
OPCODE(0x40C0)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// MOVESRa
OPCODE(0x40D0)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVESRa
OPCODE(0x40D8)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVESRa
OPCODE(0x40E0)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVESRa
OPCODE(0x40E8)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVESRa
OPCODE(0x40F0)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// MOVESRa
OPCODE(0x40F8)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	FETCH_SWORD(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// MOVESRa
OPCODE(0x40F9)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	FETCH_LONG(adr);
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// MOVESRa
OPCODE(0x40DF)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// MOVESRa
OPCODE(0x40E7)
{
	u32 adr, res;
	u32 src, dst;

	res = GET_SR;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// MOVEaCCR
OPCODE(0x44C0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	SET_CCR(res)
RET(12)
}

// MOVEaCCR
OPCODE(0x44D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(16)
}

// MOVEaCCR
OPCODE(0x44D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(16)
}

// MOVEaCCR
OPCODE(0x44E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(18)
}

// MOVEaCCR
OPCODE(0x44E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(20)
}

// MOVEaCCR
OPCODE(0x44F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(22)
}

// MOVEaCCR
OPCODE(0x44F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(20)
}

// MOVEaCCR
OPCODE(0x44F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(24)
}

// MOVEaCCR
OPCODE(0x44FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(20)
}

// MOVEaCCR
OPCODE(0x44FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(22)
}

// MOVEaCCR
OPCODE(0x44FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(res);
	SET_CCR(res)
RET(16)
}

// MOVEaCCR
OPCODE(0x44DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(16)
}

// MOVEaCCR
OPCODE(0x44E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	SET_CCR(res)
	POST_IO
RET(18)
}

// MOVEaSR
OPCODE(0x46C0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		res = DREGu16((Opcode >> 0) & 7);
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		CHECK_INT_TO_JUMP(12)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(12)
}

// MOVEaSR
OPCODE(0x46D0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG((Opcode >> 0) & 7);
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(16)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(16)
}

// MOVEaSR
OPCODE(0x46D8)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG((Opcode >> 0) & 7);
		AREG((Opcode >> 0) & 7) += 2;
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(16)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(16)
}

// MOVEaSR
OPCODE(0x46E0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG((Opcode >> 0) & 7) - 2;
		AREG((Opcode >> 0) & 7) = adr;
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(18)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(18)
}

// MOVEaSR
OPCODE(0x46E8)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_SWORD(adr);
		adr += AREG((Opcode >> 0) & 7);
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(20)
}

// MOVEaSR
OPCODE(0x46F0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG((Opcode >> 0) & 7);
		DECODE_EXT_WORD
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(22)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(22)
}


// MOVEaSR
OPCODE(0x46F8)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_SWORD(adr);
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(20)
}

// MOVEaSR
OPCODE(0x46F9)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_LONG(adr);
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(24)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(24)
}

// MOVEaSR
OPCODE(0x46FA)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = GET_SWORD + GET_PC;
		PC++;
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(20)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(20)
}

// MOVEaSR
OPCODE(0x46FB)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = GET_PC;
		DECODE_EXT_WORD
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(22)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(22)
}

// MOVEaSR
OPCODE(0x46FC)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		FETCH_WORD(res);
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		CHECK_INT_TO_JUMP(16)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(16)
}

// MOVEaSR
OPCODE(0x46DF)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG(7);
		AREG(7) += 2;
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(16)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(16)
}

// MOVEaSR
OPCODE(0x46E7)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_S)
	{
		adr = AREG(7) - 2;
		AREG(7) = adr;
		PRE_IO
		READ_WORD_F(adr, res)
		SET_SR(res)
		if (!flag_S)
		{
			res = AREG(7);
			AREG(7) = ASP;
			ASP = res;
		}
		POST_IO
		CHECK_INT_TO_JUMP(18)
	}
	else
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
RET(18)
}

// NBCD
OPCODE(0x4800)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
RET(6)
}

// NBCD
OPCODE(0x4810)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(12)
}

// NBCD
OPCODE(0x4818)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(12)
}

// NBCD
OPCODE(0x4820)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(14)
}

// NBCD
OPCODE(0x4828)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(16)
}

// NBCD
OPCODE(0x4830)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(18)
}

// NBCD
OPCODE(0x4838)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(16)
}

// NBCD
OPCODE(0x4839)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(20)
}

// NBCD
OPCODE(0x481F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(12)
}

// NBCD
OPCODE(0x4827)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res = 0x9a - res - ((flag_X >> M68K_SR_X_SFT) & 1);

	if (res != 0x9a)
	{
		if ((res & 0x0f) == 0xa) res = (res & 0xf0) + 0x10;
		res &= 0xFF;
	WRITE_BYTE_F(adr, res)
		flag_NotZ |= res;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_N = res;
	POST_IO
RET(14)
}

// PEA
OPCODE(0x4850)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(12)
}

// PEA
OPCODE(0x4868)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(16)
}

// PEA
OPCODE(0x4870)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(20)
}

// PEA
OPCODE(0x4878)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(16)
}

// PEA
OPCODE(0x4879)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(20)
}

// PEA
OPCODE(0x487A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(16)
}

// PEA
OPCODE(0x487B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	PUSH_32_F(adr)
	POST_IO
RET(20)
}

// SWAP
OPCODE(0x4840)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	res = (res >> 16) | (res << 16);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(4)
}

// MOVEMRa
OPCODE(0x4890)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(12)
#endif
}

// MOVEMRa
OPCODE(0x48A0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &AREGu32(7);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 2;
			WRITE_WORD_F(adr, *psrc)
		}
		psrc--;
	} while (res >>= 1);
	AREG((Opcode >> 0) & 7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (dst - adr) * 2;
RET(8)
}

// MOVEMRa
OPCODE(0x48A8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(20)
#endif
}

// MOVEMRa
OPCODE(0x48B0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(24)
#endif
}

// MOVEMRa
OPCODE(0x48B8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(20)
#endif
}

// MOVEMRa
OPCODE(0x48B9)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_LONG(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(28)
#endif
}

// MOVEMRa
OPCODE(0x48A7)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG(7);
	psrc = &AREGu32(7);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 2;
			WRITE_WORD_F(adr, *psrc)
		}
		psrc--;
	} while (res >>= 1);
	AREG(7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (dst - adr) * 2;
RET(8)
}

// MOVEMRa
OPCODE(0x48D0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(16)
#endif
}

// MOVEMRa
OPCODE(0x48E0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &AREGu32(7);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 4;
			WRITE_LONG_DEC_F(adr, *psrc)
		}
		psrc--;
	} while (res >>= 1);
	AREG((Opcode >> 0) & 7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (dst - adr) * 2;
RET(8)
}

// MOVEMRa
OPCODE(0x48E8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(24)
#endif
}

// MOVEMRa
OPCODE(0x48F0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(28)
#endif
}

// MOVEMRa
OPCODE(0x48F8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(24)
#endif
}

// MOVEMRa
OPCODE(0x48F9)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_LONG(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			WRITE_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(32)
#endif
}

// MOVEMRa
OPCODE(0x48E7)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG(7);
	psrc = &AREGu32(7);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			adr -= 4;
			WRITE_LONG_DEC_F(adr, *psrc)
		}
		psrc--;
	} while (res >>= 1);
	AREG(7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (dst - adr) * 2;
RET(8)
}

// EXT
OPCODE(0x4880)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)DREGs8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// EXT
OPCODE(0x48C0)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)DREGs16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu32((Opcode >> 0) & 7) = res;
RET(4)
}

// TST
OPCODE(0x4A00)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
RET(4)
}

// TST
OPCODE(0x4A10)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A18)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A20)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(10)
}

// TST
OPCODE(0x4A28)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4A30)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(14)
}

// TST
OPCODE(0x4A38)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4A39)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(16)
}

// TST
OPCODE(0x4A1F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A27)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	POST_IO
RET(10)
}

// TST
OPCODE(0x4A40)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu16((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
RET(4)
}

// TST
OPCODE(0x4A50)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A58)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A60)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(10)
}

// TST
OPCODE(0x4A68)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4A70)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(14)
}

// TST
OPCODE(0x4A78)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4A79)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(16)
}

// TST
OPCODE(0x4A5F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(8)
}

// TST
OPCODE(0x4A67)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	POST_IO
RET(10)
}

// TST
OPCODE(0x4A80)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
RET(4)
}

// TST
OPCODE(0x4A90)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4A98)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4AA0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// TST
OPCODE(0x4AA8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// TST
OPCODE(0x4AB0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// TST
OPCODE(0x4AB8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// TST
OPCODE(0x4AB9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// TST
OPCODE(0x4A9F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(12)
}

// TST
OPCODE(0x4AA7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// TAS
OPCODE(0x4AC0)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu8((Opcode >> 0) & 7);
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	res |= 0x80;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// TAS
OPCODE(0x4AD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(8)
#endif
}

// TAS
OPCODE(0x4AD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(8)
#endif
}

// TAS
OPCODE(0x4AE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(10)
#endif
}

// TAS
OPCODE(0x4AE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(22)
#else
RET(12)
#endif
}

// TAS
OPCODE(0x4AF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(24)
#else
RET(14)
#endif
}

// TAS
OPCODE(0x4AF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(22)
#else
RET(12)
#endif
}

// TAS
OPCODE(0x4AF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(26)
#else
RET(16)
#endif
}

// TAS
OPCODE(0x4ADF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(8)
#endif
}

// TAS
OPCODE(0x4AE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;

#ifdef PICODRIVE_HACK
	if (g_m68kcontext == &PicoCpuFS68k) {
		res |= 0x80;
		WRITE_BYTE_F(adr, res);
	}
#endif

	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(8)
#endif
}

// ILLEGAL
OPCODE(0x4AFC)
{
	SET_PC(execute_exception(M68K_ILLEGAL_INSTRUCTION_EX, GET_PC-2, GET_SR));
RET(0)
}

// ILLEGAL A000-AFFF
OPCODE(0xA000)
{
	SET_PC(execute_exception(M68K_1010_EX, GET_PC-2, GET_SR));
RET(0)
}

// ILLEGAL F000-FFFF
OPCODE(0xF000)
{
	SET_PC(execute_exception(M68K_1111_EX, GET_PC-2, GET_SR));
RET(0) // 4 already taken by exc. handler
}

// MOVEMaR
OPCODE(0x4C90)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(16)
#endif
}

// MOVEMaR
OPCODE(0x4C98)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	AREG((Opcode >> 0) & 7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
RET(12)
}

// MOVEMaR
OPCODE(0x4CA8)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(24)
#endif
}

// MOVEMaR
OPCODE(0x4CB0)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(28)
#endif
}

// MOVEMaR
OPCODE(0x4CB8)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(24)
#endif
}

// MOVEMaR
OPCODE(0x4CB9)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	FETCH_LONG(adr);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(32)
#endif
}

// MOVEMaR
OPCODE(0x4CBA)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = GET_SWORD + GET_PC;
	PC++;
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(24)
#endif
}

// MOVEMaR
OPCODE(0x4CBB)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = GET_PC;
	DECODE_EXT_WORD
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(28)
#endif
}

// MOVEMaR
OPCODE(0x4C9F)
{
	u32 adr, res;
	u32 src, dst;

	s32 *psrc;

	FETCH_WORD(res);
	adr = AREG(7);
	psrc = &DREGs32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READSX_WORD_F(adr, *psrc)
			adr += 2;
		}
		psrc++;
	} while (res >>= 1);
	AREG(7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
RET(12)
}

// MOVEMaR
OPCODE(0x4CD0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(20)
#endif
}

// MOVEMaR
OPCODE(0x4CD8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	AREG((Opcode >> 0) & 7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
RET(12)
}

// MOVEMaR
OPCODE(0x4CE8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(28)
#endif
}

// MOVEMaR
OPCODE(0x4CF0)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(32)
#endif
}

// MOVEMaR
OPCODE(0x4CF8)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_SWORD(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(28)
#endif
}

// MOVEMaR
OPCODE(0x4CF9)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	FETCH_LONG(adr);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(36)
#endif
}

// MOVEMaR
OPCODE(0x4CFA)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = GET_SWORD + GET_PC;
	PC++;
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(28)
#endif
}

// MOVEMaR
OPCODE(0x4CFB)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = GET_PC;
	DECODE_EXT_WORD
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(32)
#endif
}

// MOVEMaR
OPCODE(0x4CDF)
{
	u32 adr, res;
	u32 src, dst;

	u32 *psrc;

	FETCH_WORD(res);
	adr = AREG(7);
	psrc = &DREGu32(0);
	dst = adr;
	PRE_IO
	do
	{
		if (res & 1)
		{
			READ_LONG_F(adr, *psrc)
			adr += 4;
		}
		psrc++;
	} while (res >>= 1);
	AREG(7) = adr;
	POST_IO
	m68kcontext.io_cycle_counter -= (adr - dst) * 2;
RET(12)
}

// TRAP
OPCODE(0x4E40)
{
	SET_PC(execute_exception(M68K_TRAP_BASE_EX + (Opcode & 0xF), GET_PC, GET_SR));
RET(4)
}

// LINK
OPCODE(0x4E50)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	PRE_IO
	PUSH_32_F(res)
	res = AREG(7);
	AREG((Opcode >> 0) & 7) = res;
	FETCH_SWORD(res);
	AREG(7) += res;
	POST_IO
RET(16)
}

// LINKA7
OPCODE(0x4E57)
{
	u32 adr, res;
	u32 src, dst;

	AREG(7) -= 4;
	PRE_IO
	WRITE_LONG_DEC_F(AREG(7), AREG(7))
	FETCH_SWORD(res);
	AREG(7) += res;
	POST_IO
RET(16)
}

// ULNK
OPCODE(0x4E58)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu32((Opcode >> 0) & 7);
	AREG(7) = src + 4;
	PRE_IO
	READ_LONG_F(src, res)
	AREG((Opcode >> 0) & 7) = res;
	POST_IO
RET(12)
}

// ULNKA7
OPCODE(0x4E5F)
{
	u32 adr, res;
	u32 src, dst;

	PRE_IO
	READ_LONG_F(AREG(7), AREG(7))
	POST_IO
RET(12)
}

// MOVEAUSP
OPCODE(0x4E60)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_S)
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
	res = AREGu32((Opcode >> 0) & 7);
	ASP = res;
RET(4)
}

// MOVEUSPA
OPCODE(0x4E68)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_S)
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
	res = ASP;
	AREG((Opcode >> 0) & 7) = res;
RET(4)
}

// RESET
OPCODE(0x4E70)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_S)
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
	PRE_IO
	if (m68kcontext.reset_handler) m68kcontext.reset_handler();
//	CPU->Reset_CallBack();
	POST_IO
RET(132)
}

// NOP
OPCODE(0x4E71)
{
RET(4)
}

// STOP
OPCODE(0x4E72)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_S)
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
	FETCH_WORD(res);
	res &= M68K_SR_MASK;
	SET_SR(res)
	if (!flag_S)
	{
		res = AREG(7);
		AREG(7) = ASP;
		ASP = res;
	}
	m68kcontext.execinfo |= FM68K_HALTED;
RET0()
}

// RTE
OPCODE(0x4E73)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_S)
	{
		SET_PC(execute_exception(M68K_PRIVILEGE_VIOLATION_EX, GET_PC-2, GET_SR));
		RET(4)
	}
	PRE_IO
	POP_16_F(res)
	SET_SR(res)
	POP_32_F(res)
	SET_PC(res)
	if (!flag_S)
	{
		res = AREG(7);
		AREG(7) = ASP;
		ASP = res;
	}
	POST_IO
	m68kcontext.execinfo &= ~(FM68K_EMULATE_GROUP_0|FM68K_EMULATE_TRACE|FM68K_DO_TRACE);
	CHECK_INT_TO_JUMP(20)
RET(20)
}

// RTS
OPCODE(0x4E75)
{
	u32 adr, res;
	u32 src, dst;

	PRE_IO
	POP_32_F(res)
	SET_PC(res)
	CHECK_BRANCH_EXCEPTION(res)
	POST_IO
RET(16)
}

// TRAPV
OPCODE(0x4E76)
{
	if (flag_V & 0x80)
		SET_PC(execute_exception(M68K_TRAPV_EX, GET_PC, GET_SR));
RET(4)
}

// RTR
OPCODE(0x4E77)
{
	u32 adr, res;
	u32 src, dst;

	PRE_IO
	POP_16_F(res)
	SET_CCR(res)
	POP_32_F(res)
	SET_PC(res)
	CHECK_BRANCH_EXCEPTION(res)
	POST_IO
RET(20)
}

// JSR
OPCODE(0x4E90)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(16)
}

// JSR
OPCODE(0x4EA8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(18)
}

// JSR
OPCODE(0x4EB0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(22)
}

// JSR
OPCODE(0x4EB8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(18)
}

// JSR
OPCODE(0x4EB9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(20)
}

// JSR
OPCODE(0x4EBA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(18)
}

// JSR
OPCODE(0x4EBB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	{
		u32 oldPC;

		oldPC = GET_PC;
	PRE_IO
		PUSH_32_F(oldPC)
	}
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
	POST_IO
RET(22)
}

// JMP
OPCODE(0x4ED0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(8)
}

// JMP
OPCODE(0x4EE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(10)
}

// JMP
OPCODE(0x4EF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(14)
}

// JMP
OPCODE(0x4EF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(10)
}

// JMP
OPCODE(0x4EF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(12)
}

// JMP
OPCODE(0x4EFA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(10)
}

// JMP
OPCODE(0x4EFB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	SET_PC(adr)
	CHECK_BRANCH_EXCEPTION(adr)
RET(14)
}

// CHK
OPCODE(0x4180)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
RET(10)
}

// CHK
OPCODE(0x4190)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(14)
}

// CHK
OPCODE(0x4198)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(14)
}

// CHK
OPCODE(0x41A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(16)
}

// CHK
OPCODE(0x41A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(18)
}

// CHK
OPCODE(0x41B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(20)
}

// CHK
OPCODE(0x41B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(18)
}

// CHK
OPCODE(0x41B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(22)
}

// CHK
OPCODE(0x41BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(18)
}

// CHK
OPCODE(0x41BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(20)
}

// CHK
OPCODE(0x41BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(14)
}

// CHK
OPCODE(0x419F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(14)
}

// CHK
OPCODE(0x41A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	if (((s32)res < 0) || (res > src))
	{
		flag_N = res >> 8;
		SET_PC(execute_exception(M68K_CHK_EX, GET_PC, GET_SR));
	}
	POST_IO
RET(16)
}

// LEA
OPCODE(0x41D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(4)
}

// LEA
OPCODE(0x41E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// LEA
OPCODE(0x41F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// LEA
OPCODE(0x41F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// LEA
OPCODE(0x41F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// LEA
OPCODE(0x41FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// LEA
OPCODE(0x41FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	res = adr;
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// STCC
OPCODE(0x50C0)
{
	u32 adr, res;
	u32 src, dst;

	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
}

// STCC
OPCODE(0x51C0)
{
	u32 adr, res;
	u32 src, dst;

	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x52C0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x53C0)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x54C0)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x55C0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_C & 0x100)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x56C0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x57C0)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_NotZ)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x58C0)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x59C0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_V & 0x80)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5AC0)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5BC0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_N & 0x80)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5CC0)
{
	u32 adr, res;
	u32 src, dst;

	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5DC0)
{
	u32 adr, res;
	u32 src, dst;

	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5EC0)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x5FC0)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(4)
}

// STCC
OPCODE(0x50D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x51D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x52D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x53D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x54D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x55D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x56D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x57D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x58D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x59D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5AD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5BD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5CD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5DD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5ED0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5FD0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x50D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x51D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x52D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x53D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x54D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x55D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x56D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x57D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x58D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x59D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5AD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5BD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5CD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5DD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5ED8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5FD8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x50E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x51E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x52E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x53E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x54E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x55E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x56E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x57E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x58E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x59E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5AE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5BE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5CE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5DE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5EE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5FE0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x50E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x51E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x52E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x53E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x54E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x55E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x56E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x57E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x58E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x59E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5AE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5BE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5CE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5DE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5EE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5FE8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x50F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x51F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x52F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x53F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x54F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x55F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x56F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x57F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x58F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x59F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5AF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5BF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5CF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5DF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5EF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x5FF0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OPCODE(0x50F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x51F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x52F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x53F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x54F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x55F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x56F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x57F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x58F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x59F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5AF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5BF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5CF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5DF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5EF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x5FF8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OPCODE(0x50F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x51F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x52F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x53F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x54F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x55F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x56F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x57F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x58F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x59F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5AF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5BF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5CF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5DF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5EF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x5FF9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OPCODE(0x50DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x51DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x52DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x53DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x54DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x55DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x56DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x57DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x58DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x59DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5ADF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5BDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5CDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5DDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5EDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x5FDF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OPCODE(0x50E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x51E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x52E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x53E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x54E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (!(flag_C & 0x100))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x55E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_C & 0x100)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x56E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x57E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (!flag_NotZ)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x58E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (!(flag_V & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x59E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_V & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5AE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (!(flag_N & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5BE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_N & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5CE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5DE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if ((flag_N ^ flag_V) & 0x80)
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5EE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OPCODE(0x5FE7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
	}
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// DBCC
OPCODE(0x50C8)
{
	u32 adr, res;
	u32 src, dst;

	PC++;
RET(12)
}

// DBCC
OPCODE(0x51C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x52C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if ((!flag_NotZ) || (flag_C & 0x100))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x53C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_NotZ && (!(flag_C & 0x100)))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x54C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_C & 0x100)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x55C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (!(flag_C & 0x100))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x56C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (!flag_NotZ)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x57C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_NotZ)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x58C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_V & 0x80)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x59C8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (!(flag_V & 0x80))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5AC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_N & 0x80)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5BC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (!(flag_N & 0x80))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5CC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if ((flag_N ^ flag_V) & 0x80)
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5DC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (!((flag_N ^ flag_V) & 0x80))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5EC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// DBCC
OPCODE(0x5FC8)
{
	u32 adr, res;
	u32 src, dst;

	NOT_POLLING

	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
	res = DREGu16((Opcode >> 0) & 7);
	res--;
	DREGu16((Opcode >> 0) & 7) = res;
	if ((s32)res != -1)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	RET(10)
	}
	}
	else
	{
		PC++;
	RET(12)
	}
	PC++;
RET(14)
}

// ADDQ
OPCODE(0x5000)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu8((Opcode >> 0) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// ADDQ
OPCODE(0x5010)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5018)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5020)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ADDQ
OPCODE(0x5028)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDQ
OPCODE(0x5030)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDQ
OPCODE(0x5038)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDQ
OPCODE(0x5039)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ADDQ
OPCODE(0x501F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5027)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ADDQ
OPCODE(0x5040)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu16((Opcode >> 0) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// ADDQ
OPCODE(0x5048)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = AREGu32((Opcode >> 0) & 7);
	res = dst + src;
	AREG((Opcode >> 0) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(4)
#else
RET(8)
#endif
}

// ADDQ
OPCODE(0x5050)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5058)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5060)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ADDQ
OPCODE(0x5068)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDQ
OPCODE(0x5070)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDQ
OPCODE(0x5078)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDQ
OPCODE(0x5079)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ADDQ
OPCODE(0x505F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDQ
OPCODE(0x5067)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ADDQ
OPCODE(0x5080)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu32((Opcode >> 0) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ADDQ
OPCODE(0x5088)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = AREGu32((Opcode >> 0) & 7);
	res = dst + src;
	AREG((Opcode >> 0) & 7) = res;
RET(8)
}

// ADDQ
OPCODE(0x5090)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDQ
OPCODE(0x5098)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDQ
OPCODE(0x50A0)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ADDQ
OPCODE(0x50A8)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ADDQ
OPCODE(0x50B0)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// ADDQ
OPCODE(0x50B8)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ADDQ
OPCODE(0x50B9)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ADDQ
OPCODE(0x509F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDQ
OPCODE(0x50A7)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// SUBQ
OPCODE(0x5100)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu8((Opcode >> 0) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// SUBQ
OPCODE(0x5110)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5118)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5120)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// SUBQ
OPCODE(0x5128)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBQ
OPCODE(0x5130)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBQ
OPCODE(0x5138)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBQ
OPCODE(0x5139)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// SUBQ
OPCODE(0x511F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5127)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// SUBQ
OPCODE(0x5140)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu16((Opcode >> 0) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// SUBQ
OPCODE(0x5148)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = AREGu32((Opcode >> 0) & 7);
	res = dst - src;
	AREG((Opcode >> 0) & 7) = res;
RET(8)
}

// SUBQ
OPCODE(0x5150)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5158)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5160)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// SUBQ
OPCODE(0x5168)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBQ
OPCODE(0x5170)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBQ
OPCODE(0x5178)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBQ
OPCODE(0x5179)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// SUBQ
OPCODE(0x515F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBQ
OPCODE(0x5167)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// SUBQ
OPCODE(0x5180)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = DREGu32((Opcode >> 0) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// SUBQ
OPCODE(0x5188)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = AREGu32((Opcode >> 0) & 7);
	res = dst - src;
	AREG((Opcode >> 0) & 7) = res;
RET(8)
}

// SUBQ
OPCODE(0x5190)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBQ
OPCODE(0x5198)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBQ
OPCODE(0x51A0)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// SUBQ
OPCODE(0x51A8)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// SUBQ
OPCODE(0x51B0)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// SUBQ
OPCODE(0x51B8)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// SUBQ
OPCODE(0x51B9)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// SUBQ
OPCODE(0x519F)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBQ
OPCODE(0x51A7)
{
	u32 adr, res;
	u32 src, dst;

	src = (((Opcode >> 9) - 1) & 7) + 1;
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// BCC
OPCODE(0x6201)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!(flag_C & 0x100)))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6301)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || (flag_C & 0x100))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6401)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_C & 0x100))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6501)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_C & 0x100)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6601)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6701)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_NotZ)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6801)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_V & 0x80))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6901)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_V & 0x80)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6A01)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_N & 0x80))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6B01)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_N & 0x80)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6C01)
{
	u32 adr, res;
	u32 src, dst;

	if (!((flag_N ^ flag_V) & 0x80))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6D01)
{
	u32 adr, res;
	u32 src, dst;

	if ((flag_N ^ flag_V) & 0x80)
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6E01)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC
OPCODE(0x6F01)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
		PC += ((s8)(Opcode & 0xFE)) >> 1;
	m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

// BCC16
OPCODE(0x6200)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!(flag_C & 0x100)))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6300)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || (flag_C & 0x100))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6400)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_C & 0x100))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6500)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_C & 0x100)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6600)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6700)
{
	u32 adr, res;
	u32 src, dst;

	if (!flag_NotZ)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6800)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_V & 0x80))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6900)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_V & 0x80)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6A00)
{
	u32 adr, res;
	u32 src, dst;

	if (!(flag_N & 0x80))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6B00)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_N & 0x80)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6C00)
{
	u32 adr, res;
	u32 src, dst;

	if (!((flag_N ^ flag_V) & 0x80))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6D00)
{
	u32 adr, res;
	u32 src, dst;

	if ((flag_N ^ flag_V) & 0x80)
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6E00)
{
	u32 adr, res;
	u32 src, dst;

	if (flag_NotZ && (!((flag_N ^ flag_V) & 0x80)))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BCC16
OPCODE(0x6F00)
{
	u32 adr, res;
	u32 src, dst;

	if ((!flag_NotZ) || ((flag_N ^ flag_V) & 0x80))
	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
		RET(10)
	}
	PC++;
RET(12)
}

// BRA
OPCODE(0x6001)
{
#ifdef FAMEC_CHECK_BRANCHES
	u32 newPC = GET_PC;
	s8 offs=Opcode;
	newPC += offs;
	SET_PC(newPC);
	CHECK_BRANCH_EXCEPTION(offs)
#else
	PC += ((s8)(Opcode & 0xFE)) >> 1;
#endif
RET(10)
}

// BRA16
OPCODE(0x6000)
{
	u32 adr, res;
	u32 src, dst;

	{
		u32 newPC;

		newPC = GET_PC;
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	}
RET(10)
}

// BSR
OPCODE(0x6101)
{
	u32 adr, res;
	u32 src, dst;
	u32 oldPC;
	s8 offs;

	PRE_IO

	oldPC = GET_PC;
	PUSH_32_F(oldPC)
#ifdef FAMEC_CHECK_BRANCHES
	offs = Opcode;
	oldPC += offs;
	SET_PC(oldPC);
	CHECK_BRANCH_EXCEPTION(offs)
#else
	PC += ((s8)(Opcode & 0xFE)) >> 1;
#endif
	POST_IO
RET(18)
}

// BSR16
OPCODE(0x6100)
{
	u32 adr, res;
	u32 src, dst;

	PRE_IO
	{
		u32 oldPC, newPC;

		newPC = GET_PC;
		oldPC = newPC + 2;
		PUSH_32_F(oldPC)
		newPC += GET_SWORD;
		SET_PC(newPC);
		CHECK_BRANCH_EXCEPTION(newPC)
	}
	POST_IO
RET(18)
}

// MOVEQ
OPCODE(0x7000)
{
	u32 adr, res;
	u32 src, dst;

	res = (s32)(s8)Opcode;
	flag_C = flag_V = 0;
	flag_N = flag_NotZ = res;
	DREGu32((Opcode >> 9) & 7) = res;
RET(4)
}

// ORaD
OPCODE(0x8000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// ORaD
OPCODE(0x8010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ORaD
OPCODE(0x8028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x8030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x8038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x8039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ORaD
OPCODE(0x803A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x803B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x803C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(8)
}

// ORaD
OPCODE(0x801F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ORaD
OPCODE(0x8040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// ORaD
OPCODE(0x8050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ORaD
OPCODE(0x8068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x8070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x8078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x8079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ORaD
OPCODE(0x807A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ORaD
OPCODE(0x807B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x807C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(8)
}

// ORaD
OPCODE(0x805F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ORaD
OPCODE(0x8067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ORaD
OPCODE(0x8080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// ORaD
OPCODE(0x8090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x8098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x80A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ORaD
OPCODE(0x80A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ORaD
OPCODE(0x80B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ORaD
OPCODE(0x80B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ORaD
OPCODE(0x80B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// ORaD
OPCODE(0x80BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ORaD
OPCODE(0x80BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ORaD
OPCODE(0x80BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(16)
}

// ORaD
OPCODE(0x809F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ORaD
OPCODE(0x80A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ORDa
OPCODE(0x8110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ORDa
OPCODE(0x8128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ORDa
OPCODE(0x8130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ORDa
OPCODE(0x8138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ORDa
OPCODE(0x8139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ORDa
OPCODE(0x811F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ORDa
OPCODE(0x8150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ORDa
OPCODE(0x8168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ORDa
OPCODE(0x8170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ORDa
OPCODE(0x8178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ORDa
OPCODE(0x8179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ORDa
OPCODE(0x815F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ORDa
OPCODE(0x8167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ORDa
OPCODE(0x8190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ORDa
OPCODE(0x8198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ORDa
OPCODE(0x81A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ORDa
OPCODE(0x81A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ORDa
OPCODE(0x81B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// ORDa
OPCODE(0x81B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ORDa
OPCODE(0x81B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ORDa
OPCODE(0x819F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ORDa
OPCODE(0x81A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res |= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// SBCD
OPCODE(0x8100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = (dst & 0xF) - (src & 0xF) - ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(6)
}

// SBCDM
OPCODE(0x8108)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SBCD7M
OPCODE(0x810F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SBCDM7
OPCODE(0x8F08)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SBCD7M7
OPCODE(0x8F0F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) - (src & 0xF) - ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res -= 6;
	res += (dst & 0xF0) - (src & 0xF0);
	if (res > 0x99)
	{
		res += 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// DIVU
OPCODE(0x80C0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(140)
#else
RET(10)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(140)
#else
RET(70)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(140)
#else
RET(90)
#endif
}

// DIVU
OPCODE(0x80D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(14)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
	RET(74)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(94)
#endif
}

// DIVU
OPCODE(0x80D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(14)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
	RET(74)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(94)
#endif
}

// DIVU
OPCODE(0x80E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
RET(16)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
	RET(76)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
RET(96)
#endif
}

// DIVU
OPCODE(0x80E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(18)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
	RET(78)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(98)
#endif
}

// DIVU
OPCODE(0x80F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(150)
#else
RET(20)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(150)
#else
	RET(80)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(150)
#else
RET(100)
#endif
}

// DIVU
OPCODE(0x80F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(18)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
	RET(78)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(98)
#endif
}

// DIVU
OPCODE(0x80F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(162)
#else
RET(22)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(162)
#else
	RET(82)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(162)
#else
RET(102)
#endif
}

// DIVU
OPCODE(0x80FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(18)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
	RET(78)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(148)
#else
RET(98)
#endif
}

// DIVU
OPCODE(0x80FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(160)
#else
RET(20)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(160)
#else
	RET(80)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(160)
#else
RET(100)
#endif
}

// DIVU
OPCODE(0x80FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(14)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
	RET(74)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(94)
#endif
}

// DIVU
OPCODE(0x80DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(14)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
	RET(74)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(144)
#else
RET(94)
#endif
}

// DIVU
OPCODE(0x80E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
RET(16)
#endif
	}
	dst = DREGu32((Opcode >> 9) & 7);
	{
		u32 q, r;

		q = dst / src;
		r = dst % src;

		if (q & 0xFFFF0000)
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
	RET(76)
#endif
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
RET(146)
#else
RET(96)
#endif
}

// DIVS
OPCODE(0x81C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs16((Opcode >> 0) & 7);
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81C0;
#endif
		RET(10)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81C0;
#endif
	RET(50)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81C0;
#endif
	RET(80)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81C0: m68kcontext.io_cycle_counter -= 50;
#endif
RET(108)
}

// DIVS
OPCODE(0x81D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D0;
#endif
		RET(14)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D0;
#endif
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D0;
#endif
	RET(84)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81D0: m68kcontext.io_cycle_counter -= 50;
#endif
RET(112)
}

// DIVS
OPCODE(0x81D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D8;
#endif
		RET(14)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D8;
#endif
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81D8;
#endif
	RET(84)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81D8: m68kcontext.io_cycle_counter -= 50;
#endif
RET(112)
}

// DIVS
OPCODE(0x81E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E0;
#endif
		RET(16)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E0;
#endif
	RET(56)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E0;
#endif
	RET(86)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81E0: m68kcontext.io_cycle_counter -= 50;
#endif
RET(114)
}

// DIVS
OPCODE(0x81E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E8;
#endif
		RET(18)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E8;
#endif
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E8;
#endif
	RET(88)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81E8: m68kcontext.io_cycle_counter -= 50;
#endif
RET(116)
}

// DIVS
OPCODE(0x81F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F0;
#endif
		RET(20)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F0;
#endif
	RET(60)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F0;
#endif
	RET(90)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81F0: m68kcontext.io_cycle_counter -= 50;
#endif
RET(118)
}

// DIVS
OPCODE(0x81F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F8;
#endif
		RET(18)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F8;
#endif
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F8;
#endif
	RET(88)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81F8: m68kcontext.io_cycle_counter -= 50;
#endif
RET(116)
}

// DIVS
OPCODE(0x81F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F9;
#endif
		RET(22)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F9;
#endif
	RET(62)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81F9;
#endif
	RET(92)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81F9: m68kcontext.io_cycle_counter -= 50;
#endif
RET(120)
}

// DIVS
OPCODE(0x81FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FA;
#endif
		RET(18)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FA;
#endif
	RET(58)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FA;
#endif
	RET(88)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81FA: m68kcontext.io_cycle_counter -= 50;
#endif
RET(116)
}

// DIVS
OPCODE(0x81FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FB;
#endif
		RET(20)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FB;
#endif
	RET(60)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FB;
#endif
	RET(90)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81FB: m68kcontext.io_cycle_counter -= 50;
#endif
RET(118)
}

// DIVS
OPCODE(0x81FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(src);
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FC;
#endif
		RET(14)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FC;
#endif
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81FC;
#endif
	RET(84)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81FC: m68kcontext.io_cycle_counter -= 50;
#endif
RET(112)
}

// DIVS
OPCODE(0x81DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81DF;
#endif
		RET(14)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81DF;
#endif
	RET(54)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81DF;
#endif
	RET(84)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81DF: m68kcontext.io_cycle_counter -= 50;
#endif
RET(112)
}

// DIVS
OPCODE(0x81E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	if (src == 0)
	{
		SET_PC(execute_exception(M68K_ZERO_DIVIDE_EX, GET_PC, GET_SR));
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E7;
#endif
		RET(16)
	}
	dst = DREGu32((Opcode >> 9) & 7);
	if ((dst == 0x80000000) && (src == (u32)-1))
	{
		flag_NotZ = flag_N = 0;
		flag_V = flag_C = 0;
		res = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E7;
#endif
	RET(56)
	}
	{
		s32 q, r;

		q = (s32)dst / (s32)src;
		r = (s32)dst % (s32)src;

		if ((q > 0x7FFF) || (q < -0x8000))
		{
			flag_V = M68K_SR_V;
#ifdef USE_CYCLONE_TIMING_DIV
goto end81E7;
#endif
	RET(86)
		}
		q &= 0x0000FFFF;
		flag_NotZ = q;
		flag_N = q >> 8;
		flag_V = flag_C = 0;
		res = q | (r << 16);
	DREGu32((Opcode >> 9) & 7) = res;
	}
#ifdef USE_CYCLONE_TIMING_DIV
end81E7: m68kcontext.io_cycle_counter -= 50;
#endif
RET(114)
}

// SUBaD
OPCODE(0x9000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// SUBaD
#if 0
OPCODE(0x9008)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
*/
RET(4)
}
#endif

// SUBaD
OPCODE(0x9010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// SUBaD
OPCODE(0x9028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x9030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x9038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x9039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// SUBaD
OPCODE(0x903A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x903B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x903C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBaD
OPCODE(0x901F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// SUBaD
OPCODE(0x9040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// SUBaD
OPCODE(0x9048)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// SUBaD
OPCODE(0x9050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// SUBaD
OPCODE(0x9068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x9070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x9078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x9079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// SUBaD
OPCODE(0x907A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// SUBaD
OPCODE(0x907B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x907C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBaD
OPCODE(0x905F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// SUBaD
OPCODE(0x9067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// SUBaD
OPCODE(0x9080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBaD
OPCODE(0x9088)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBaD
OPCODE(0x9090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x9098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x90A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// SUBaD
OPCODE(0x90A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBaD
OPCODE(0x90B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// SUBaD
OPCODE(0x90B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBaD
OPCODE(0x90B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// SUBaD
OPCODE(0x90BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBaD
OPCODE(0x90BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// SUBaD
OPCODE(0x90BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(16)
}

// SUBaD
OPCODE(0x909F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBaD
OPCODE(0x90A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// SUBDa
OPCODE(0x9110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// SUBDa
OPCODE(0x9128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBDa
OPCODE(0x9130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBDa
OPCODE(0x9138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// SUBDa
OPCODE(0x9139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// SUBDa
OPCODE(0x911F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// SUBDa
OPCODE(0x9150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// SUBDa
OPCODE(0x9168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBDa
OPCODE(0x9170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBDa
OPCODE(0x9178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// SUBDa
OPCODE(0x9179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// SUBDa
OPCODE(0x915F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// SUBDa
OPCODE(0x9167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// SUBDa
OPCODE(0x9190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBDa
OPCODE(0x9198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBDa
OPCODE(0x91A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// SUBDa
OPCODE(0x91A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// SUBDa
OPCODE(0x91B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// SUBDa
OPCODE(0x91B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// SUBDa
OPCODE(0x91B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// SUBDa
OPCODE(0x919F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// SUBDa
OPCODE(0x91A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// SUBX
OPCODE(0x9100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src - ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ |= res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// SUBX
OPCODE(0x9140)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src - ((flag_X >> 8) & 1);
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// SUBX
OPCODE(0x9180)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBXM
OPCODE(0x9108)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBXM
OPCODE(0x9148)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	READ_WORD_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBXM
OPCODE(0x9188)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	READ_LONG_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// SUBX7M
OPCODE(0x910F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBX7M
OPCODE(0x914F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	READ_WORD_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBX7M
OPCODE(0x918F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	READ_LONG_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// SUBXM7
OPCODE(0x9F08)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBXM7
OPCODE(0x9F48)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_WORD_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBXM7
OPCODE(0x9F88)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7) - 4;
	AREG(7) = adr;
	READ_LONG_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// SUBX7M7
OPCODE(0x9F0F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// SUBX7M7
OPCODE(0x9F4F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_WORD_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// SUBX7M7
OPCODE(0x9F8F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7) - 4;
	AREG(7) = adr;
	READ_LONG_F(adr, dst)
	res = dst - src - ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// SUBA
OPCODE(0x90C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBA
OPCODE(0x90C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// SUBA
OPCODE(0x90D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// SUBA
OPCODE(0x90D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// SUBA
OPCODE(0x90E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(12)
#endif
}

// SUBA
OPCODE(0x90E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// SUBA
OPCODE(0x90F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(16)
#endif
}

// SUBA
OPCODE(0x90F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// SUBA
OPCODE(0x90F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(18)
#endif
}

// SUBA
OPCODE(0x90FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// SUBA
OPCODE(0x90FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(16)
#endif
}

// SUBA
OPCODE(0x90FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// SUBA
OPCODE(0x90DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// SUBA
OPCODE(0x90E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(12)
#endif
}

// SUBA
OPCODE(0x91C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(6)
#endif
}

// SUBA
OPCODE(0x91C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(6)
#endif
}

// SUBA
OPCODE(0x91D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBA
OPCODE(0x91D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBA
OPCODE(0x91E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// SUBA
OPCODE(0x91E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBA
OPCODE(0x91F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// SUBA
OPCODE(0x91F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBA
OPCODE(0x91F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// SUBA
OPCODE(0x91FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// SUBA
OPCODE(0x91FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// SUBA
OPCODE(0x91FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// SUBA
OPCODE(0x91DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// SUBA
OPCODE(0x91E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// CMP
OPCODE(0xB000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
RET(4)
}

// CMP
#if 0
OPCODE(0xB008)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
*/
RET(4)
}
#endif

// CMP
OPCODE(0xB010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(10)
}

// CMP
OPCODE(0xB028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(16)
}

// CMP
OPCODE(0xB03A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB03B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB03C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
RET(8)
}

// CMP
OPCODE(0xB01F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(10)
}

// CMP
OPCODE(0xB040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
RET(4)
}

// CMP
OPCODE(0xB048)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
RET(4)
}

// CMP
OPCODE(0xB050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(10)
}

// CMP
OPCODE(0xB068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(16)
}

// CMP
OPCODE(0xB07A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMP
OPCODE(0xB07B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB07C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
RET(8)
}

// CMP
OPCODE(0xB05F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(8)
}

// CMP
OPCODE(0xB067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(10)
}

// CMP
OPCODE(0xB080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMP
OPCODE(0xB088)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMP
OPCODE(0xB090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB0A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// CMP
OPCODE(0xB0A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMP
OPCODE(0xB0B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMP
OPCODE(0xB0B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMP
OPCODE(0xB0B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(22)
}

// CMP
OPCODE(0xB0BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMP
OPCODE(0xB0BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMP
OPCODE(0xB0BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(14)
}

// CMP
OPCODE(0xB09F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMP
OPCODE(0xB0A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// CMPM
OPCODE(0xB108)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMPM
OPCODE(0xB148)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMPM
OPCODE(0xB188)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMP7M
OPCODE(0xB10F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 1;
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMP7M
OPCODE(0xB14F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 2;
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMP7M
OPCODE(0xB18F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) += 4;
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPM7
OPCODE(0xBF08)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7);
	AREG(7) += 2;
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMPM7
OPCODE(0xBF48)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7);
	AREG(7) += 2;
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMPM7
OPCODE(0xBF88)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7);
	AREG(7) += 4;
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMP7M7
OPCODE(0xBF0F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7);
	AREG(7) += 2;
	READ_BYTE_F(adr, dst)
	res = dst - src;
	flag_N = flag_C = res;
	flag_V = (src ^ dst) & (res ^ dst);
	flag_NotZ = res & 0xFF;
	POST_IO
RET(12)
}

// CMP7M7
OPCODE(0xBF4F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7);
	AREG(7) += 2;
	READ_WORD_F(adr, dst)
	res = dst - src;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 8;
	flag_N = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	POST_IO
RET(12)
}

// CMP7M7
OPCODE(0xBF8F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7);
	AREG(7) += 4;
	READ_LONG_F(adr, dst)
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	res = DREGu8((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(4)
}

// EORDa
OPCODE(0xB110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// EORDa
OPCODE(0xB128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// EORDa
OPCODE(0xB130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// EORDa
OPCODE(0xB138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// EORDa
OPCODE(0xB139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB11F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// EORDa
OPCODE(0xB140)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	res = DREGu16((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 0) & 7) = res;
RET(4)
}

// EORDa
OPCODE(0xB150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// EORDa
OPCODE(0xB168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// EORDa
OPCODE(0xB170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// EORDa
OPCODE(0xB178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// EORDa
OPCODE(0xB179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB15F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// EORDa
OPCODE(0xB167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// EORDa
OPCODE(0xB180)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	res = DREGu32((Opcode >> 0) & 7);
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// EORDa
OPCODE(0xB190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB1A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// EORDa
OPCODE(0xB1A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// EORDa
OPCODE(0xB1B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// EORDa
OPCODE(0xB1B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// EORDa
OPCODE(0xB1B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// EORDa
OPCODE(0xB19F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// EORDa
OPCODE(0xB1A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res ^= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// CMPA
OPCODE(0xB0C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMPA
OPCODE(0xB0C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMPA
OPCODE(0xB0D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(10)
}

// CMPA
OPCODE(0xB0D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(10)
}

// CMPA
OPCODE(0xB0E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(12)
}

// CMPA
OPCODE(0xB0E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB0F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// CMPA
OPCODE(0xB0F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB0F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMPA
OPCODE(0xB0FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB0FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// CMPA
OPCODE(0xB0FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(10)
}

// CMPA
OPCODE(0xB0DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(10)
}

// CMPA
OPCODE(0xB0E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(12)
}

// CMPA
OPCODE(0xB1C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMPA
OPCODE(0xB1C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(6)
}

// CMPA
OPCODE(0xB1D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB1D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB1E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// CMPA
OPCODE(0xB1E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMPA
OPCODE(0xB1F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPA
OPCODE(0xB1F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMPA
OPCODE(0xB1F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(22)
}

// CMPA
OPCODE(0xB1FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(18)
}

// CMPA
OPCODE(0xB1FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(20)
}

// CMPA
OPCODE(0xB1FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
RET(14)
}

// CMPA
OPCODE(0xB1DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(14)
}

// CMPA
OPCODE(0xB1E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst - src;
	flag_NotZ = res;
	flag_C = ((src & res & 1) + (src >> 1) + (res >> 1)) >> 23;
	flag_V = ((src ^ dst) & (res ^ dst)) >> 24;
	flag_N = res >> 24;
	POST_IO
RET(16)
}

// ANDaD
OPCODE(0xC000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// ANDaD
OPCODE(0xC010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ANDaD
OPCODE(0xC028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ANDaD
OPCODE(0xC03A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC03B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC03C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(8)
}

// ANDaD
OPCODE(0xC01F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	res = DREGu8((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ANDaD
OPCODE(0xC040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// ANDaD
OPCODE(0xC050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ANDaD
OPCODE(0xC068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ANDaD
OPCODE(0xC07A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ANDaD
OPCODE(0xC07B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC07C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
RET(8)
}

// ANDaD
OPCODE(0xC05F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ANDaD
OPCODE(0xC067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ANDaD
OPCODE(0xC080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// ANDaD
OPCODE(0xC090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC0A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ANDaD
OPCODE(0xC0A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ANDaD
OPCODE(0xC0B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ANDaD
OPCODE(0xC0B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ANDaD
OPCODE(0xC0B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// ANDaD
OPCODE(0xC0BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ANDaD
OPCODE(0xC0BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ANDaD
OPCODE(0xC0BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(16)
}

// ANDaD
OPCODE(0xC09F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ANDaD
OPCODE(0xC0A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	res = DREGu32((Opcode >> 9) & 7);
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ANDDa
OPCODE(0xC110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ANDDa
OPCODE(0xC128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ANDDa
OPCODE(0xC130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ANDDa
OPCODE(0xC138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ANDDa
OPCODE(0xC139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ANDDa
OPCODE(0xC11F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ANDDa
OPCODE(0xC150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ANDDa
OPCODE(0xC168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ANDDa
OPCODE(0xC170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ANDDa
OPCODE(0xC178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ANDDa
OPCODE(0xC179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ANDDa
OPCODE(0xC15F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ANDDa
OPCODE(0xC167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 8;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ANDDa
OPCODE(0xC190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ANDDa
OPCODE(0xC198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ANDDa
OPCODE(0xC1A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ANDDa
OPCODE(0xC1A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ANDDa
OPCODE(0xC1B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// ANDDa
OPCODE(0xC1B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ANDDa
OPCODE(0xC1B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ANDDa
OPCODE(0xC19F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ANDDa
OPCODE(0xC1A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, res)
	res &= src;
	flag_C = 0;
	flag_V = 0;
	flag_NotZ = res;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ABCD
OPCODE(0xC100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = (dst & 0xF) + (src & 0xF) + ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	DREGu8((Opcode >> 9) & 7) = res;
RET(6)
}

// ABCDM
OPCODE(0xC108)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) + (src & 0xF) + ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ABCD7M
OPCODE(0xC10F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) + (src & 0xF) + ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ABCDM7
OPCODE(0xCF08)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) + (src & 0xF) + ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ABCD7M7
OPCODE(0xCF0F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = (dst & 0xF) + (src & 0xF) + ((flag_X >> M68K_SR_X_SFT) & 1);
	if (res > 9) res += 6;
	res += (dst & 0xF0) + (src & 0xF0);
	if (res > 0x99)
	{
		res -= 0xA0;
		flag_X = flag_C = M68K_SR_C;
	}
	else flag_X = flag_C = 0;
	flag_NotZ |= res & 0xFF;
	flag_N = res;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// MULU
OPCODE(0xC0C0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(54)
#else
RET(50)
#endif
}

// MULU
OPCODE(0xC0D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULU
OPCODE(0xC0D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULU
OPCODE(0xC0E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(60)
#else
RET(56)
#endif
}

// MULU
OPCODE(0xC0E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULU
OPCODE(0xC0F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(64)
#else
RET(60)
#endif
}

// MULU
OPCODE(0xC0F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULU
OPCODE(0xC0F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(66)
#else
RET(62)
#endif
}

// MULU
OPCODE(0xC0FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULU
OPCODE(0xC0FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(64)
#else
RET(60)
#endif
}

// MULU
OPCODE(0xC0FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULU
OPCODE(0xC0DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULU
OPCODE(0xC0E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	res = DREGu16((Opcode >> 9) & 7);
	res *= src;
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(60)
#else
RET(56)
#endif
}

// MULS
OPCODE(0xC1C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs16((Opcode >> 0) & 7);
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(54)
#else
RET(50)
#endif
}

// MULS
OPCODE(0xC1D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULS
OPCODE(0xC1D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULS
OPCODE(0xC1E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(60)
#else
RET(56)
#endif
}

// MULS
OPCODE(0xC1E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULS
OPCODE(0xC1F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(64)
#else
RET(60)
#endif
}

// MULS
OPCODE(0xC1F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULS
OPCODE(0xC1F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(66)
#else
RET(62)
#endif
}

// MULS
OPCODE(0xC1FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(62)
#else
RET(58)
#endif
}

// MULS
OPCODE(0xC1FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(64)
#else
RET(60)
#endif
}

// MULS
OPCODE(0xC1FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(src);
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULS
OPCODE(0xC1DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(58)
#else
RET(54)
#endif
}

// MULS
OPCODE(0xC1E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	res = (s32)DREGs16((Opcode >> 9) & 7);
	res = ((s32)res) * ((s32)src);
	flag_N = res >> 24;
	flag_NotZ = res;
	flag_V = flag_C = 0;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(60)
#else
RET(56)
#endif
}

// EXGDD
OPCODE(0xC140)
{
	u32 adr, res;
	u32 src, dst;

	res = DREGu32((Opcode >> 0) & 7);
	src = DREGu32((Opcode >> 9) & 7);
	DREGu32((Opcode >> 9) & 7) = res;
	res = src;
	DREGu32((Opcode >> 0) & 7) = res;
RET(6)
}

// EXGAA
OPCODE(0xC148)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	src = AREGu32((Opcode >> 9) & 7);
	AREG((Opcode >> 9) & 7) = res;
	res = src;
	AREG((Opcode >> 0) & 7) = res;
RET(6)
}

// EXGAD
OPCODE(0xC188)
{
	u32 adr, res;
	u32 src, dst;

	res = AREGu32((Opcode >> 0) & 7);
	src = DREGu32((Opcode >> 9) & 7);
	DREGu32((Opcode >> 9) & 7) = res;
	res = src;
	AREG((Opcode >> 0) & 7) = res;
RET(6)
}

// ADDaD
OPCODE(0xD000)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// ADDaD
#if 0
OPCODE(0xD008)
{
	u32 adr, res;
	u32 src, dst;

	// can't read byte from Ax registers !
	m68kcontext.execinfo |= M68K_FAULTED;
	m68kcontext.io_cycle_counter = 0;
/*
	goto famec_Exec_End;
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
*/
RET(4)
}
#endif

// ADDaD
OPCODE(0xD010)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD018)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD020)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ADDaD
OPCODE(0xD028)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD030)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD038)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD039)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ADDaD
OPCODE(0xD03A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD03B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD03C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_BYTE(src);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDaD
OPCODE(0xD01F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD027)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ADDaD
OPCODE(0xD040)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// ADDaD
OPCODE(0xD048)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// ADDaD
OPCODE(0xD050)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD058)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD060)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ADDaD
OPCODE(0xD068)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD070)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD078)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD079)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ADDaD
OPCODE(0xD07A)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(12)
}

// ADDaD
OPCODE(0xD07B)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD07C)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_WORD(src);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDaD
OPCODE(0xD05F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(8)
}

// ADDaD
OPCODE(0xD067)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
	POST_IO
RET(10)
}

// ADDaD
OPCODE(0xD080)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDaD
OPCODE(0xD088)
{
	u32 adr, res;
	u32 src, dst;

	src = AREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDaD
OPCODE(0xD090)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD098)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD0A0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ADDaD
OPCODE(0xD0A8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDaD
OPCODE(0xD0B0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ADDaD
OPCODE(0xD0B8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDaD
OPCODE(0xD0B9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// ADDaD
OPCODE(0xD0BA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDaD
OPCODE(0xD0BB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ADDaD
OPCODE(0xD0BC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(16)
}

// ADDaD
OPCODE(0xD09F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDaD
OPCODE(0xD0A7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ADDDa
OPCODE(0xD110)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD118)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 1;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD120)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ADDDa
OPCODE(0xD128)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDDa
OPCODE(0xD130)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDDa
OPCODE(0xD138)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(16)
}

// ADDDa
OPCODE(0xD139)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(20)
}

// ADDDa
OPCODE(0xD11F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD127)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, dst)
	res = dst + src;
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ = res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(14)
}

// ADDDa
OPCODE(0xD150)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD158)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD160)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ADDDa
OPCODE(0xD168)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDDa
OPCODE(0xD170)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDDa
OPCODE(0xD178)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ADDDa
OPCODE(0xD179)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ADDDa
OPCODE(0xD15F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ADDDa
OPCODE(0xD167)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 9) & 7);
	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, dst)
	res = dst + src;
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ = res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ADDDa
OPCODE(0xD190)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDDa
OPCODE(0xD198)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDDa
OPCODE(0xD1A0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ADDDa
OPCODE(0xD1A8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ADDDa
OPCODE(0xD1B0)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(26)
}

// ADDDa
OPCODE(0xD1B8)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_SWORD(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(24)
}

// ADDDa
OPCODE(0xD1B9)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	FETCH_LONG(adr);
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(28)
}

// ADDDa
OPCODE(0xD19F)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(20)
}

// ADDDa
OPCODE(0xD1A7)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 9) & 7);
	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, dst)
	res = dst + src;
	flag_NotZ = res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(22)
}

// ADDX
OPCODE(0xD100)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu8((Opcode >> 0) & 7);
	dst = DREGu8((Opcode >> 9) & 7);
	res = dst + src + ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ |= res & 0xFF;
	DREGu8((Opcode >> 9) & 7) = res;
RET(4)
}

// ADDX
OPCODE(0xD140)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu16((Opcode >> 0) & 7);
	dst = DREGu16((Opcode >> 9) & 7);
	res = dst + src + ((flag_X >> 8) & 1);
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	DREGu16((Opcode >> 9) & 7) = res;
RET(4)
}

// ADDX
OPCODE(0xD180)
{
	u32 adr, res;
	u32 src, dst;

	src = DREGu32((Opcode >> 0) & 7);
	dst = DREGu32((Opcode >> 9) & 7);
	res = dst + src + ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	DREGu32((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDXM
OPCODE(0xD108)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDXM
OPCODE(0xD148)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	READ_WORD_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDXM
OPCODE(0xD188)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	READ_LONG_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDX7M
OPCODE(0xD10F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 1;
	AREG((Opcode >> 9) & 7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDX7M
OPCODE(0xD14F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 2;
	AREG((Opcode >> 9) & 7) = adr;
	READ_WORD_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDX7M
OPCODE(0xD18F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG((Opcode >> 9) & 7) - 4;
	AREG((Opcode >> 9) & 7) = adr;
	READ_LONG_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDXM7
OPCODE(0xDF08)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 1;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDXM7
OPCODE(0xDF48)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_WORD_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDXM7
OPCODE(0xDF88)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7) - 4;
	AREG(7) = adr;
	READ_LONG_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDX7M7
OPCODE(0xDF0F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_BYTE_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_BYTE_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_N = flag_X = flag_C = res;
	flag_V = (src ^ res) & (dst ^ res);
	flag_NotZ |= res & 0xFF;
	WRITE_BYTE_F(adr, res)
	POST_IO
RET(18)
}

// ADDX7M7
OPCODE(0xDF4F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	adr = AREG(7) - 2;
	AREG(7) = adr;
	READ_WORD_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_V = ((src ^ res) & (dst ^ res)) >> 8;
	flag_N = flag_X = flag_C = res >> 8;
	flag_NotZ |= res & 0xFFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ADDX7M7
OPCODE(0xDF8F)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READ_LONG_F(adr, src)
	adr = AREG(7) - 4;
	AREG(7) = adr;
	READ_LONG_F(adr, dst)
	res = dst + src + ((flag_X >> 8) & 1);
	flag_NotZ |= res;
	flag_X = flag_C = ((src & dst & 1) + (src >> 1) + (dst >> 1)) >> 23;
	flag_V = ((src ^ res) & (dst ^ res)) >> 24;
	flag_N = res >> 24;
	WRITE_LONG_F(adr, res)
	POST_IO
RET(30)
}

// ADDA
OPCODE(0xD0C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDA
OPCODE(0xD0C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs16((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
RET(8)
}

// ADDA
OPCODE(0xD0D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// ADDA
OPCODE(0xD0D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// ADDA
OPCODE(0xD0E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(12)
#endif
}

// ADDA
OPCODE(0xD0E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// ADDA
OPCODE(0xD0F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(16)
#endif
}

// ADDA
OPCODE(0xD0F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// ADDA
OPCODE(0xD0F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(20)
#else
RET(18)
#endif
}

// ADDA
OPCODE(0xD0FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// ADDA
OPCODE(0xD0FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(18)
#else
RET(16)
#endif
}

// ADDA
OPCODE(0xD0FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
RET(12)
}

// ADDA
OPCODE(0xD0DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(12)
#else
RET(10)
#endif
}

// ADDA
OPCODE(0xD0E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READSX_WORD_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
#ifdef USE_CYCLONE_TIMING
RET(14)
#else
RET(12)
#endif
}

// ADDA
OPCODE(0xD1C0)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)DREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(6)
#endif
}

// ADDA
OPCODE(0xD1C8)
{
	u32 adr, res;
	u32 src, dst;

	src = (s32)AREGs32((Opcode >> 0) & 7);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(8)
#else
RET(6)
#endif
}

// ADDA
OPCODE(0xD1D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDA
OPCODE(0xD1D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDA
OPCODE(0xD1E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 4;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ADDA
OPCODE(0xD1E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDA
OPCODE(0xD1F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ADDA
OPCODE(0xD1F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDA
OPCODE(0xD1F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(22)
}

// ADDA
OPCODE(0xD1FA)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_SWORD + GET_PC;
	PC++;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(18)
}

// ADDA
OPCODE(0xD1FB)
{
	u32 adr, res;
	u32 src, dst;

	adr = GET_PC;
	DECODE_EXT_WORD
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(20)
}

// ADDA
OPCODE(0xD1FC)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(src);
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
#ifdef USE_CYCLONE_TIMING
RET(16)
#else
RET(14)
#endif
}

// ADDA
OPCODE(0xD1DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 4;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(14)
}

// ADDA
OPCODE(0xD1E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 4;
	AREG(7) = adr;
	PRE_IO
	READSX_LONG_F(adr, src)
	dst = AREGu32((Opcode >> 9) & 7);
	res = dst + src;
	AREG((Opcode >> 9) & 7) = res;
	POST_IO
RET(16)
}

// ASRk
OPCODE(0xE000)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = (s32)DREGs8((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	flag_N = res >> 0;
	flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// ASRk
OPCODE(0xE040)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = (s32)DREGs16((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	flag_N = res >> 8;
	flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// ASRk
OPCODE(0xE080)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = (s32)DREGs32((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	flag_N = res >> 24;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// LSRk
OPCODE(0xE008)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	flag_N = flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = src >> sft;
	flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// LSRk
OPCODE(0xE048)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	flag_N = flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = src >> sft;
	flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// LSRk
OPCODE(0xE088)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_N = flag_V = 0;
	flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = src >> sft;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ROXRk
OPCODE(0xE010)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	src |= (flag_X & M68K_SR_X) << 0;
	res = (src >> sft) | (src << (9 - sft));
	flag_X = flag_C = res >> 0;
	flag_V = 0;
	flag_N = res >> 0;
	flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// ROXRk
OPCODE(0xE050)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	src |= (flag_X & M68K_SR_X) << 8;
	res = (src >> sft) | (src << (17 - sft));
	flag_X = flag_C = res >> 8;
	flag_V = 0;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// ROXRk
OPCODE(0xE090)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	if (sft == 1) res = (src >> 1) | ((flag_X & M68K_SR_X) << (32 - (M68K_SR_X_SFT + 1)));
	else res = (src >> sft) | (src << (33 - sft)) | ((flag_X & M68K_SR_X) << (32 - (M68K_SR_X_SFT + sft)));
	flag_X = flag_C;
	flag_V = 0;
	flag_N = res >> 24;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// RORk
OPCODE(0xE018)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = (src >> sft) | (src << (8 - sft));
	flag_N = res >> 0;
	flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// RORk
OPCODE(0xE058)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = (src >> sft) | (src << (16 - sft));
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// RORk
OPCODE(0xE098)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
	res = (src >> sft) | (src << (32 - sft));
	flag_N = res >> 24;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ASLk
OPCODE(0xE100)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft < 8)
	{
		flag_X = flag_C = src << (0 + sft);
		res = src << sft;
		flag_N = res >> 0;
		flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
		flag_V = 0;
		if ((sft > 7) && (src)) flag_V = M68K_SR_V;
		else
		{
			u32 msk = (((s32)0x80000000) >> (sft + 24)) & 0x000000FF;
			src &= msk;
			if ((src) && (src != msk)) flag_V = M68K_SR_V;
		}
	RET(6)
	}

	if (src) flag_V = M68K_SR_V;
	else flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	flag_N = 0;
	flag_NotZ = 0;
RET(6)
}

// ASLk
OPCODE(0xE140)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
		flag_X = flag_C = src >> (8 - sft);
		res = src << sft;
		flag_N = res >> 8;
		flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
		flag_V = 0;
		{
			u32 msk = (((s32)0x80000000) >> (sft + 16)) & 0x0000FFFF;
			src &= msk;
			if ((src) && (src != msk)) flag_V = M68K_SR_V;
		}
RET(6)
}

// ASLk
OPCODE(0xE180)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
		flag_X = flag_C = src >> (24 - sft);
		res = src << sft;
		flag_N = res >> 24;
		flag_NotZ = res & 0xFFFFFFFF;
	DREGu32((Opcode >> 0) & 7) = res;
		flag_V = 0;
		{
			u32 msk = (((s32)0x80000000) >> (sft + 0)) & 0xFFFFFFFF;
			src &= msk;
			if ((src) && (src != msk)) flag_V = M68K_SR_V;
		}
RET(8)
}

// LSLk
OPCODE(0xE108)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src << (0 + sft);
	res = src << sft;
	flag_N = res >> 0;
	flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// LSLk
OPCODE(0xE148)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src >> (8 - sft);
	res = src << sft;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// LSLk
OPCODE(0xE188)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_V = 0;
	flag_X = flag_C = src >> (24 - sft);
	res = src << sft;
	flag_N = res >> 24;
	flag_NotZ = res & 0xFFFFFFFF;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ROXLk
OPCODE(0xE110)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	src |= (flag_X & M68K_SR_X) << 0;
	res = (src << sft) | (src >> (9 - sft));
	flag_X = flag_C = res >> 0;
	flag_V = 0;
	flag_N = res >> 0;
	flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// ROXLk
OPCODE(0xE150)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	src |= (flag_X & M68K_SR_X) << 8;
	res = (src << sft) | (src >> (17 - sft));
	flag_X = flag_C = res >> 8;
	flag_V = 0;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// ROXLk
OPCODE(0xE190)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_C = src >> ((32 - M68K_SR_C_SFT) - sft);
	if (sft == 1) res = (src << 1) | ((flag_X & M68K_SR_X) >> ((M68K_SR_X_SFT + 1) - 1));
	else res = (src << sft) | (src >> (33 - sft)) | ((flag_X & M68K_SR_X) >> ((M68K_SR_X_SFT + 1) - sft));
	flag_X = flag_C;
	flag_V = 0;
	flag_N = res >> 24;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ROLk
OPCODE(0xE118)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu8((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src << (0 + sft);
	res = (src << sft) | (src >> (8 - sft));
	flag_N = res >> 0;
	flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
RET(6)
}

// ROLk
OPCODE(0xE158)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu16((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src >> (8 - sft);
	res = (src << sft) | (src >> (16 - sft));
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
RET(6)
}

// ROLk
OPCODE(0xE198)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	m68kcontext.io_cycle_counter -= sft * 2;
	src = DREGu32((Opcode >> 0) & 7);
	flag_V = 0;
	flag_C = src >> (24 - sft);
	res = (src << sft) | (src >> (32 - sft));
	flag_N = res >> 24;
	flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
RET(8)
}

// ASRD
OPCODE(0xE020)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = (s32)DREGs8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 8)
		{
			flag_V = 0;
			flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
			res = ((s32)src) >> sft;
			flag_N = res >> 0;
			flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
		}

		if (src & (1 << 7))
		{
			flag_N = M68K_SR_N;
			flag_NotZ = 1;
			flag_V = 0;
			flag_C = M68K_SR_C;
			flag_X = M68K_SR_X;
			res = 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		flag_C = 0;
		flag_X = 0;
		res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// ASRD
OPCODE(0xE060)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = (s32)DREGs16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 16)
		{
			flag_V = 0;
			flag_X = flag_C = (src >> (sft - 1)) << M68K_SR_C_SFT;
			res = ((s32)src) >> sft;
			flag_N = res >> 8;
			flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
		}

		if (src & (1 << 15))
		{
			flag_N = M68K_SR_N;
			flag_NotZ = 1;
			flag_V = 0;
			flag_C = M68K_SR_C;
			flag_X = M68K_SR_X;
			res = 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		flag_C = 0;
		flag_X = 0;
		res = 0;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// ASRD
OPCODE(0xE0A0)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = (s32)DREGs32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 32)
		{
			flag_V = 0;
			flag_X = flag_C = (src >> (sft - 1)) << M68K_SR_C_SFT;
			res = ((s32)src) >> sft;
			flag_N = res >> 24;
			flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
		}

		if (src & (1 << 31))
		{
			flag_N = M68K_SR_N;
			flag_NotZ = 1;
			flag_V = 0;
			flag_C = M68K_SR_C;
			flag_X = M68K_SR_X;
			res = 0xFFFFFFFF;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
		}

		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		flag_C = 0;
		flag_X = 0;
		res = 0;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// LSRD
OPCODE(0xE028)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft <= 8)
		{
			flag_N = flag_V = 0;
			flag_X = flag_C = src << ((M68K_SR_C_SFT + 1) - sft);
			res = src >> sft;
			flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_X = flag_C = 0;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// LSRD
OPCODE(0xE068)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft <= 16)
		{
			flag_N = flag_V = 0;
			flag_X = flag_C = (src >> (sft - 1)) << M68K_SR_C_SFT;
			res = src >> sft;
			flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_X = flag_C = 0;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// LSRD
OPCODE(0xE0A8)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 32)
		{
			flag_N = flag_V = 0;
			flag_X = flag_C = (src >> (sft - 1)) << M68K_SR_C_SFT;
			res = src >> sft;
			flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
		}

		if (sft == 32) flag_C = src >> (31 - M68K_SR_C_SFT);
		else flag_C = 0;
		flag_X = flag_C;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// ROXRD
OPCODE(0xE030)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 9;

		src |= (flag_X & M68K_SR_X) << 0;
		res = (src >> sft) | (src << (9 - sft));
		flag_X = flag_C = res >> 0;
		flag_V = 0;
		flag_N = res >> 0;
		flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// ROXRD
OPCODE(0xE070)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 17;

		src |= (flag_X & M68K_SR_X) << 8;
		res = (src >> sft) | (src << (17 - sft));
		flag_X = flag_C = res >> 8;
		flag_V = 0;
		flag_N = res >> 8;
		flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// ROXRD
OPCODE(0xE0B0)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 33;

		if (sft != 0)
		{
			if (sft == 1) res = (src >> 1) | ((flag_X & M68K_SR_X) << (32 - (M68K_SR_X_SFT + 1)));
			else res = (src >> sft) | (src << (33 - sft)) | (((flag_X & M68K_SR_X) << (32 - (M68K_SR_X_SFT + 1))) >> (sft - 1));
			flag_X = (src >> (32 - sft)) << M68K_SR_X_SFT;
		}
		else res = src;
		flag_C = flag_X;
		flag_V = 0;
		flag_N = res >> 24;
		flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// RORD
OPCODE(0xE038)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft &= 0x07;

		flag_C = src << (M68K_SR_C_SFT - ((sft - 1) & 7));
		res = (src >> sft) | (src << (8 - sft));
		flag_V = 0;
		flag_N = res >> 0;
		flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// RORD
OPCODE(0xE078)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft &= 0x0F;

		flag_C = (src >> ((sft - 1) & 15)) << M68K_SR_C_SFT;
		res = (src >> sft) | (src << (16 - sft));
		flag_V = 0;
		flag_N = res >> 8;
		flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// RORD
OPCODE(0xE0B8)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft &= 0x1F;

		flag_C = (src >> ((sft - 1) & 31)) << M68K_SR_C_SFT;
		res = (src >> sft) | (src << (32 - sft));
		flag_V = 0;
		flag_N = res >> 24;
		flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// ASLD
OPCODE(0xE120)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 8)
		{
			flag_X = flag_C = (src << sft) >> 0;
			res = (src << sft) & 0x000000FF;
			flag_N = res >> 0;
			flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
			flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 24)) & 0x000000FF;
				src &= msk;
				if ((src) && (src != msk)) flag_V = M68K_SR_V;
			}
	RET(6)
		}

		if (sft == 256) flag_C = src << M68K_SR_C_SFT;
		else flag_C = 0;
		flag_X = flag_C;
		if (src) flag_V = M68K_SR_V;
		else flag_V = 0;
		res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
		flag_N = 0;
		flag_NotZ = 0;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// ASLD
OPCODE(0xE160)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 16)
		{
			flag_X = flag_C = (src << sft) >> 8;
			res = (src << sft) & 0x0000FFFF;
			flag_N = res >> 8;
			flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
			flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 16)) & 0x0000FFFF;
				src &= msk;
				if ((src) && (src != msk)) flag_V = M68K_SR_V;
			}
	RET(6)
		}

		if (sft == 65536) flag_C = src << M68K_SR_C_SFT;
		else flag_C = 0;
		flag_X = flag_C;
		if (src) flag_V = M68K_SR_V;
		else flag_V = 0;
		res = 0;
	DREGu16((Opcode >> 0) & 7) = res;
		flag_N = 0;
		flag_NotZ = 0;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// ASLD
OPCODE(0xE1A0)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 32)
		{
			flag_X = flag_C = (src >> (32 - sft)) << M68K_SR_C_SFT;
			res = src << sft;
			flag_N = res >> 24;
			flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
			flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 0)) & 0xFFFFFFFF;
				src &= msk;
				if ((src) && (src != msk)) flag_V = M68K_SR_V;
			}
	RET(CYC)
		}

		if (sft == 0) flag_C = src << M68K_SR_C_SFT;
		else flag_C = 0;
		flag_X = flag_C;
		if (src) flag_V = M68K_SR_V;
		else flag_V = 0;
		res = 0;
	DREGu32((Opcode >> 0) & 7) = res;
		flag_N = 0;
		flag_NotZ = 0;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// LSLD
OPCODE(0xE128)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft <= 8)
		{
			flag_X = flag_C = (src << sft) >> 0;
			res = (src << sft) & 0x000000FF;
			flag_V = 0;
			flag_N = res >> 0;
			flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_X = flag_C = 0;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// LSLD
OPCODE(0xE168)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft <= 16)
		{
			flag_X = flag_C = (src << sft) >> 8;
			res = (src << sft) & 0x0000FFFF;
			flag_V = 0;
			flag_N = res >> 8;
			flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_X = flag_C = 0;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// LSLD
OPCODE(0xE1A8)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft < 32)
		{
			flag_X = flag_C = (src >> (32 - sft)) << M68K_SR_C_SFT;
			res = src << sft;
			flag_V = 0;
			flag_N = res >> 24;
			flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
		}

		if (sft == 32) flag_C = src << M68K_SR_C_SFT;
		else flag_C = 0;
		flag_X = flag_C;
		flag_N = 0;
		flag_NotZ = 0;
		flag_V = 0;
		res = 0;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// ROXLD
OPCODE(0xE130)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 9;

		src |= (flag_X & M68K_SR_X) << 0;
		res = (src << sft) | (src >> (9 - sft));
		flag_X = flag_C = res >> 0;
		flag_V = 0;
		flag_N = res >> 0;
		flag_NotZ = res & 0x000000FF;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// ROXLD
OPCODE(0xE170)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 17;

		src |= (flag_X & M68K_SR_X) << 8;
		res = (src << sft) | (src >> (17 - sft));
		flag_X = flag_C = res >> 8;
		flag_V = 0;
		flag_N = res >> 8;
		flag_NotZ = res & 0x0000FFFF;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// ROXLD
OPCODE(0xE1B0)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		sft %= 33;

		if (sft != 0)
		{
			if (sft == 1) res = (src << 1) | ((flag_X >> ((M68K_SR_X_SFT + 1) - 1)) & 1);
			else res = (src << sft) | (src >> (33 - sft)) | (((flag_X >> ((M68K_SR_X_SFT + 1) - 1)) & 1) << (sft - 1));
			flag_X = (src >> (32 - sft)) << M68K_SR_X_SFT;
		}
		else res = src;
		flag_C = flag_X;
		flag_V = 0;
		flag_N = res >> 24;
		flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = flag_X;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// ROLD
OPCODE(0xE138)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu8((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft &= 0x07)
		{
			flag_C = (src << sft) >> 0;
			res = ((src << sft) | (src >> (8 - sft))) & 0x000000FF;
			flag_V = 0;
			flag_N = res >> 0;
			flag_NotZ = res;
	DREGu8((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_V = 0;
		flag_C = src << M68K_SR_C_SFT;
		flag_N = src >> 0;
		flag_NotZ = src;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 0;
	flag_NotZ = src;
RET(6)
}

// ROLD
OPCODE(0xE178)
{
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu16((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft &= 0x0F)
		{
			flag_C = (src << sft) >> 8;
			res = ((src << sft) | (src >> (16 - sft))) & 0x0000FFFF;
			flag_V = 0;
			flag_N = res >> 8;
			flag_NotZ = res;
	DREGu16((Opcode >> 0) & 7) = res;
	RET(6)
		}

		flag_V = 0;
		flag_C = src << M68K_SR_C_SFT;
		flag_N = src >> 8;
		flag_NotZ = src;
	RET(6)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 8;
	flag_NotZ = src;
RET(6)
}

// ROLD
OPCODE(0xE1B8)
{
#ifdef USE_CYCLONE_TIMING
#define CYC 8
#else
#define CYC 6
#endif
	u32 adr, res;
	u32 src, dst;

	u32 sft;

	sft = DREG((Opcode >> 9) & 7) & 0x3F;
	src = DREGu32((Opcode >> 0) & 7);
	if (sft)
	{
	m68kcontext.io_cycle_counter -= sft * 2;
		if (sft &= 0x1F)
		{
			flag_C = (src >> (32 - sft)) << M68K_SR_C_SFT;
			res = (src << sft) | (src >> (32 - sft));
			flag_V = 0;
			flag_N = res >> 24;
			flag_NotZ = res;
	DREGu32((Opcode >> 0) & 7) = res;
	RET(CYC)
		}

		flag_V = 0;
		flag_C = src << M68K_SR_C_SFT;
		flag_N = src >> 24;
		flag_NotZ = src;
	RET(CYC)
	}

	flag_V = 0;
	flag_C = 0;
	flag_N = src >> 24;
	flag_NotZ = src;
RET(CYC)
#undef CYC
}

// ASR
OPCODE(0xE0D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASR
OPCODE(0xE0D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASR
OPCODE(0xE0E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ASR
OPCODE(0xE0E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ASR
OPCODE(0xE0F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ASR
OPCODE(0xE0F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ASR
OPCODE(0xE0F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ASR
OPCODE(0xE0DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASR
OPCODE(0xE0E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src & (1 << 15));
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// LSR
OPCODE(0xE2D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSR
OPCODE(0xE2D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSR
OPCODE(0xE2E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// LSR
OPCODE(0xE2E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// LSR
OPCODE(0xE2F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// LSR
OPCODE(0xE2F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// LSR
OPCODE(0xE2F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// LSR
OPCODE(0xE2DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSR
OPCODE(0xE2E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_N = flag_V = 0;
	flag_X = flag_C = src << M68K_SR_C_SFT;
	res = src >> 1;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROXR
OPCODE(0xE4D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXR
OPCODE(0xE4D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXR
OPCODE(0xE4E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROXR
OPCODE(0xE4E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROXR
OPCODE(0xE4F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ROXR
OPCODE(0xE4F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROXR
OPCODE(0xE4F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ROXR
OPCODE(0xE4DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXR
OPCODE(0xE4E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src >> 1) | ((flag_X & M68K_SR_X) << 7);
	flag_C = flag_X = src << M68K_SR_C_SFT;
	flag_N = res >> 8;
	flag_NotZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROR
OPCODE(0xE6D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROR
OPCODE(0xE6D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROR
OPCODE(0xE6E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROR
OPCODE(0xE6E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROR
OPCODE(0xE6F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ROR
OPCODE(0xE6F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROR
OPCODE(0xE6F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ROR
OPCODE(0xE6DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROR
OPCODE(0xE6E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src << M68K_SR_C_SFT;
	res = (src >> 1) | (src << 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ASL
OPCODE(0xE1D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASL
OPCODE(0xE1D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASL
OPCODE(0xE1E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ASL
OPCODE(0xE1E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ASL
OPCODE(0xE1F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ASL
OPCODE(0xE1F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ASL
OPCODE(0xE1F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ASL
OPCODE(0xE1DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ASL
OPCODE(0xE1E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_V = (src ^ res) >> 8;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// LSL
OPCODE(0xE3D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSL
OPCODE(0xE3D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSL
OPCODE(0xE3E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// LSL
OPCODE(0xE3E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// LSL
OPCODE(0xE3F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// LSL
OPCODE(0xE3F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// LSL
OPCODE(0xE3F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// LSL
OPCODE(0xE3DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// LSL
OPCODE(0xE3E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_X = flag_C = src >> 7;
	res = src << 1;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROXL
OPCODE(0xE5D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXL
OPCODE(0xE5D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXL
OPCODE(0xE5E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROXL
OPCODE(0xE5E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROXL
OPCODE(0xE5F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ROXL
OPCODE(0xE5F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROXL
OPCODE(0xE5F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ROXL
OPCODE(0xE5DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROXL
OPCODE(0xE5E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	res = (src << 1) | ((flag_X & M68K_SR_X) >> 8);
	flag_X = flag_C = src >> 7;
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROL
OPCODE(0xE7D0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROL
OPCODE(0xE7D8)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	AREG((Opcode >> 0) & 7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROL
OPCODE(0xE7E0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7) - 2;
	AREG((Opcode >> 0) & 7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

// ROL
OPCODE(0xE7E8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	adr += AREG((Opcode >> 0) & 7);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROL
OPCODE(0xE7F0)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG((Opcode >> 0) & 7);
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(18)
}

// ROL
OPCODE(0xE7F8)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_SWORD(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(16)
}

// ROL
OPCODE(0xE7F9)
{
	u32 adr, res;
	u32 src, dst;

	FETCH_LONG(adr);
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(20)
}

// ROL
OPCODE(0xE7DF)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7);
	AREG(7) += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(12)
}

// ROL
OPCODE(0xE7E7)
{
	u32 adr, res;
	u32 src, dst;

	adr = AREG(7) - 2;
	AREG(7) = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	flag_V = 0;
	flag_C = src >> 7;
	res = (src << 1) | (src >> 15);
	flag_N = res >> 8;
	flag_NotZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
RET(14)
}

#ifdef PICODRIVE_HACK
#if 0
#define UPDATE_IDLE_COUNT { \
	extern int idle_hit_counter; \
	idle_hit_counter++; \
}
#else
#define UPDATE_IDLE_COUNT
#endif

// BRA
OPCODE(0x6001_idle)
{
#ifdef FAMEC_CHECK_BRANCHES
	u32 newPC = GET_PC;
	s8 offs=Opcode;
	newPC += offs;
	SET_PC(newPC);
	CHECK_BRANCH_EXCEPTION(offs)
#else
	PC += ((s8)(Opcode & 0xFE)) >> 1;
#endif
	UPDATE_IDLE_COUNT
RET0()
}

// BCC
OPCODE(0x6601_idle)
{
	if (flag_NotZ)
	{
		UPDATE_IDLE_COUNT
		PC += ((s8)(Opcode & 0xFE)) >> 1;
		//if (idle_hit)
		RET0()
	}
RET(8)
}

OPCODE(0x6701_idle)
{
	if (!flag_NotZ)
	{
		UPDATE_IDLE_COUNT
		PC += ((s8)(Opcode & 0xFE)) >> 1;
		//if (idle_hit)
		RET0()
	}
RET(8)
}


extern int SekIsIdleReady(void);
extern int SekIsIdleCode(unsigned short *dst, int bytes);
extern int SekRegisterIdlePatch(unsigned int pc, int oldop, int newop, void *ctx);

OPCODE(idle_detector_bcc8)
{
	int frame_count, cond_true, bytes, ret, newop;
	u16 *dest_pc;

	dest_pc = PC + (((s8)(Opcode & 0xFE)) >> 1);

	if (!SekIsIdleReady())
		goto end;

	bytes = 0 - (s8)(Opcode & 0xFE) - 2;
	ret = SekIsIdleCode(dest_pc, bytes);
	newop = (Opcode & 0xfe) | 0x7100;
	if (!ret) newop |= 0x200;
	if (  Opcode & 0x0100)  newop |= 0x400; // beq
	if (!(Opcode & 0x0f00)) newop |= 0xc00; // bra

	ret = SekRegisterIdlePatch(GET_PC - 2, Opcode, newop, &m68kcontext);
	switch (ret)
	{
		case 0: PC[-1] = newop; break;
		case 1: break;
		case 2: JumpTable[Opcode] = (Opcode & 0x0f00) ?
				((Opcode & 0x0100) ? CAST_OP(0x6701) : CAST_OP(0x6601)) :
				CAST_OP(0x6001); break;
	}

end:
	if ((Opcode & 0xff00) == 0x6000) cond_true = 1;
	else cond_true = (Opcode & 0x0100) ? !flag_NotZ : flag_NotZ; // beq?
	if (cond_true)
	{
		PC = dest_pc;
		m68kcontext.io_cycle_counter -= 2;
	}
RET(8)
}

#endif // PICODRIVE_HACK
