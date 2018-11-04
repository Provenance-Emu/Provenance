
// BCC
OP_0x6201:
{
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6301:
{
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6401:
{
	if (!(CPU->flag_C & 0x100))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6501:
{
	if (CPU->flag_C & 0x100)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6601:
{
	if (CPU->flag_notZ)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6701:
{
	if (!CPU->flag_notZ)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6801:
{
	if (!(CPU->flag_V & 0x80))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6901:
{
	if (CPU->flag_V & 0x80)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6A01:
{
	if (!(CPU->flag_N & 0x80))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6B01:
{
	if (CPU->flag_N & 0x80)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6C01:
{
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6D01:
{
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6E01:
{
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC
OP_0x6F01:
{
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
		PC += (s32)(s8)Opcode;
	CCnt -= 2;
	}
}
RET(8)

// BCC16
OP_0x6200:
{
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6300:
{
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6400:
{
	if (!(CPU->flag_C & 0x100))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6500:
{
	if (CPU->flag_C & 0x100)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6600:
{
	if (CPU->flag_notZ)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6700:
{
	if (!CPU->flag_notZ)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6800:
{
	if (!(CPU->flag_V & 0x80))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6900:
{
	if (CPU->flag_V & 0x80)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6A00:
{
	if (!(CPU->flag_N & 0x80))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6B00:
{
	if (CPU->flag_N & 0x80)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6C00:
{
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6D00:
{
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6E00:
{
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BCC16
OP_0x6F00:
{
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(12)

// BRA
OP_0x6001:
{
	PC += (s32)(s8)Opcode;
}
RET(10)

// BRA16
OP_0x6000:
{
	PC += (s32)(s16)FETCH_WORD;
	PC -= CPU->BasePC;
	SET_PC(PC);
}
RET(10)

// BSR
OP_0x6101:
{
	PRE_IO
	PUSH_32_F((u32)(PC - CPU->BasePC))
	PC += (s32)(s8)Opcode;
	POST_IO
}
RET(18)

// BSR16
OP_0x6100:
{
	u32 res;
	res = (s32)(s16)FETCH_WORD;
	PC -= CPU->BasePC;
	PRE_IO
	PUSH_32_F((u32)PC + 2)
	PC += (s32) res;
	SET_PC(PC);
	POST_IO
}
RET(18)
