
// ASRk
OP_0xE000:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (s32)(s8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ASRk
OP_0xE040:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ASRk
OP_0xE080:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (s32)(s32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((s32)src) >> sft;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// LSRk
OP_0xE008:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = (u32)src >> sft;
	CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// LSRk
OP_0xE048:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = (u32)src >> sft;
	CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// LSRk
OP_0xE088:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = (u32)src >> sft;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ROXRk
OP_0xE010:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	src |= (CPU->flag_X & C68K_SR_X) << 0;
	res = ((u32)src >> sft) | ((u32)src << (9 - sft));
	CPU->flag_X = CPU->flag_C = res >> 0;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROXRk
OP_0xE050:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	src |= (CPU->flag_X & C68K_SR_X) << 8;
	res = ((u32)src >> sft) | ((u32)src << (17 - sft));
	CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROXRk
OP_0xE090:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	if (sft == 1) res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << (32 - (C68K_SR_X_SFT + 1)));
	else res = ((u32)src >> sft) | ((u32)src << (33 - sft)) | ((CPU->flag_X & C68K_SR_X) << (32 - (C68K_SR_X_SFT + sft)));
	CPU->flag_X = CPU->flag_C;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// RORk
OP_0xE018:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((u32)src >> sft) | ((u32)src << (8 - sft));
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// RORk
OP_0xE058:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((u32)src >> sft) | ((u32)src << (16 - sft));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// RORk
OP_0xE098:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
	res = ((u32)src >> sft) | ((u32)src << (32 - sft));
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ASLk
OP_0xE100:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft < 8)
	{
		CPU->flag_X = CPU->flag_C = (u32)src << (0 + sft);
		res = (u32)src << sft;
		CPU->flag_N = res >> 0;
		CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_V = 0;
		if ((sft > 7) && (src)) CPU->flag_V = C68K_SR_V;
		else
		{
			u32 msk = (((s32)0x80000000) >> (sft + 24)) & 0x000000FF;
			src &= msk;
			if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
		}
	RET(6)
	}

	if (src) CPU->flag_V = C68K_SR_V;
	else CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	CPU->flag_N = 0;
	CPU->flag_notZ = 0;
}
RET(6)

// ASLk
OP_0xE140:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
		CPU->flag_X = CPU->flag_C = (u32)src >> (8 - sft);
		res = (u32)src << sft;
		CPU->flag_N = res >> 8;
		CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_V = 0;
		{
			u32 msk = (((s32)0x80000000) >> (sft + 16)) & 0x0000FFFF;
			src &= msk;
			if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
		}
}
RET(6)

// ASLk
OP_0xE180:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
		CPU->flag_X = CPU->flag_C = (u32)src >> (24 - sft);
		res = (u32)src << sft;
		CPU->flag_N = res >> 24;
		CPU->flag_notZ = res & 0xFFFFFFFF;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_V = 0;
		{
			u32 msk = (((s32)0x80000000) >> (sft + 0)) & 0xFFFFFFFF;
			src &= msk;
			if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
		}
}
RET(8)

// LSLk
OP_0xE108:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << (0 + sft);
	res = (u32)src << sft;
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// LSLk
OP_0xE148:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src >> (8 - sft);
	res = (u32)src << sft;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// LSLk
OP_0xE188:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src >> (24 - sft);
	res = (u32)src << sft;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res & 0xFFFFFFFF;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ROXLk
OP_0xE110:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	src |= (CPU->flag_X & C68K_SR_X) << 0;
	res = ((u32)src << sft) | ((u32)src >> (9 - sft));
	CPU->flag_X = CPU->flag_C = res >> 0;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROXLk
OP_0xE150:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	src |= (CPU->flag_X & C68K_SR_X) << 8;
	res = ((u32)src << sft) | ((u32)src >> (17 - sft));
	CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROXLk
OP_0xE190:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_C = (u32)src >> ((32 - C68K_SR_C_SFT) - sft);
	if (sft == 1) res = ((u32)src << 1) | ((CPU->flag_X & C68K_SR_X) >> ((C68K_SR_X_SFT + 1) - 1));
	else res = ((u32)src << sft) | ((u32)src >> (33 - sft)) | ((CPU->flag_X & C68K_SR_X) >> ((C68K_SR_X_SFT + 1) - sft));
	CPU->flag_X = CPU->flag_C;
	CPU->flag_V = 0;
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ROLk
OP_0xE118:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src << (0 + sft);
	res = ((u32)src << sft) | ((u32)src >> (8 - sft));
	CPU->flag_N = res >> 0;
	CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROLk
OP_0xE158:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src >> (8 - sft);
	res = ((u32)src << sft) | ((u32)src >> (16 - sft));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(6)

// ROLk
OP_0xE198:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = (((Opcode >> 9) - 1) & 7) + 1;
	CCnt -= sft * 2;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	CPU->flag_V = 0;
	CPU->flag_C = (u32)src >> (24 - sft);
	res = ((u32)src << sft) | ((u32)src >> (32 - sft));
	CPU->flag_N = res >> 24;
	CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ASRD
OP_0xE020:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (s32)(s8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 8)
		{
			CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
			res = ((s32)src) >> sft;
			CPU->flag_N = res >> 0;
			CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		if (src & (1 << 7))
		{
			CPU->flag_N = C68K_SR_N;
			CPU->flag_notZ = 1;
			CPU->flag_V = 0;
			CPU->flag_C = C68K_SR_C;
			CPU->flag_X = C68K_SR_X;
			res = 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		CPU->flag_C = 0;
		CPU->flag_X = 0;
		res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ASRD
OP_0xE060:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (s32)(s16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 16)
		{
			CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = ((u32)src >> (sft - 1)) << C68K_SR_C_SFT;
			res = ((s32)src) >> sft;
			CPU->flag_N = res >> 8;
			CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		if (src & (1 << 15))
		{
			CPU->flag_N = C68K_SR_N;
			CPU->flag_notZ = 1;
			CPU->flag_V = 0;
			CPU->flag_C = C68K_SR_C;
			CPU->flag_X = C68K_SR_X;
			res = 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		CPU->flag_C = 0;
		CPU->flag_X = 0;
		res = 0;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ASRD
OP_0xE0A0:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (s32)(s32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 32)
		{
			CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = ((u32)src >> (sft - 1)) << C68K_SR_C_SFT;
			res = ((s32)src) >> sft;
			CPU->flag_N = res >> 24;
			CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
		}

		if (src & (1 << 31))
		{
			CPU->flag_N = C68K_SR_N;
			CPU->flag_notZ = 1;
			CPU->flag_V = 0;
			CPU->flag_C = C68K_SR_C;
			CPU->flag_X = C68K_SR_X;
			res = 0xFFFFFFFF;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
		}

		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		CPU->flag_C = 0;
		CPU->flag_X = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// LSRD
OP_0xE028:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft <= 8)
		{
			CPU->flag_N = CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = (u32)src << ((C68K_SR_C_SFT + 1) - sft);
			res = (u32)src >> sft;
			CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_X = CPU->flag_C = 0;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// LSRD
OP_0xE068:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft <= 16)
		{
			CPU->flag_N = CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = ((u32)src >> (sft - 1)) << C68K_SR_C_SFT;
			res = (u32)src >> sft;
			CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_X = CPU->flag_C = 0;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// LSRD
OP_0xE0A8:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 32)
		{
			CPU->flag_N = CPU->flag_V = 0;
			CPU->flag_X = CPU->flag_C = ((u32)src >> (sft - 1)) << C68K_SR_C_SFT;
			res = (u32)src >> sft;
			CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
		}

		if (sft == 32) CPU->flag_C = (u32)src >> (31 - C68K_SR_C_SFT);
		else CPU->flag_C = 0;
		CPU->flag_X = CPU->flag_C;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// ROXRD
OP_0xE030:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 9;

		src |= (CPU->flag_X & C68K_SR_X) << 0;
		res = ((u32)src >> sft) | ((u32)src << (9 - sft));
		CPU->flag_X = CPU->flag_C = res >> 0;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 0;
		CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROXRD
OP_0xE070:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 17;

		src |= (CPU->flag_X & C68K_SR_X) << 8;
		res = ((u32)src >> sft) | ((u32)src << (17 - sft));
		CPU->flag_X = CPU->flag_C = res >> 8;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 8;
		CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROXRD
OP_0xE0B0:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 33;

		if (sft != 0)
		{
			if (sft == 1) res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << (32 - (C68K_SR_X_SFT + 1)));
			else res = ((u32)src >> sft) | ((u32)src << (33 - sft)) | (((CPU->flag_X & C68K_SR_X) << (32 - (C68K_SR_X_SFT + 1))) >> (sft - 1));
			CPU->flag_X = ((u32)src >> (32 - sft)) << C68K_SR_X_SFT;
		}
		else res = (u32)src;
		CPU->flag_C = CPU->flag_X;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 24;
		CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// RORD
OP_0xE038:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft &= 0x07;
		
		CPU->flag_C = (u32)src << (C68K_SR_C_SFT - ((sft - 1) & 7));
		res = ((u32)src >> sft) | ((u32)src << (8 - sft));
		CPU->flag_V = 0;
		CPU->flag_N = res >> 0;
		CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// RORD
OP_0xE078:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft &= 0x0F;
		
		CPU->flag_C = ((u32)src >> ((sft - 1) & 15)) << C68K_SR_C_SFT;
		res = ((u32)src >> sft) | ((u32)src << (16 - sft));
		CPU->flag_V = 0;
		CPU->flag_N = res >> 8;
		CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// RORD
OP_0xE0B8:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft &= 0x1F;
		
		CPU->flag_C = ((u32)src >> ((sft - 1) & 31)) << C68K_SR_C_SFT;
		res = ((u32)src >> sft) | ((u32)src << (32 - sft));
		CPU->flag_V = 0;
		CPU->flag_N = res >> 24;
		CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// ASLD
OP_0xE120:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 8)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src << sft) >> 0;
			res = ((u32)src << sft) & 0x000000FF;
			CPU->flag_N = res >> 0;
			CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
			CPU->flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 24)) & 0x000000FF;
				src &= msk;
				if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
			}
	RET(6)
		}

		if (sft == 256) CPU->flag_C = (u32)src << C68K_SR_C_SFT;
		else CPU->flag_C = 0;
		CPU->flag_X = CPU->flag_C;
		if (src) CPU->flag_V = C68K_SR_V;
		else CPU->flag_V = 0;
		res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ASLD
OP_0xE160:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 16)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src << sft) >> 8;
			res = ((u32)src << sft) & 0x0000FFFF;
			CPU->flag_N = res >> 8;
			CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
			CPU->flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 16)) & 0x0000FFFF;
				src &= msk;
				if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
			}
	RET(6)
		}

		if (sft == 65536) CPU->flag_C = (u32)src << C68K_SR_C_SFT;
		else CPU->flag_C = 0;
		CPU->flag_X = CPU->flag_C;
		if (src) CPU->flag_V = C68K_SR_V;
		else CPU->flag_V = 0;
		res = 0;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ASLD
OP_0xE1A0:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 32)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src >> (32 - sft)) << C68K_SR_C_SFT;
			res = (u32)(src << sft);
			CPU->flag_N = res >> 24;
			CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
			CPU->flag_V = 0;
			{
				u32 msk = (((s32)0x80000000) >> (sft + 0)) & 0xFFFFFFFF;
				src &= msk;
				if ((src) && (src != msk)) CPU->flag_V = C68K_SR_V;
			}
	RET(8)
		}

		if (sft == 0) CPU->flag_C = (u32)src << C68K_SR_C_SFT;
		else CPU->flag_C = 0;
		CPU->flag_X = CPU->flag_C;
		if (src) CPU->flag_V = C68K_SR_V;
		else CPU->flag_V = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// LSLD
OP_0xE128:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft <= 8)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src << sft) >> 0;
			res = (src << sft) & 0x000000FF;
			CPU->flag_V = 0;
			CPU->flag_N = res >> 0;
			CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_X = CPU->flag_C = 0;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// LSLD
OP_0xE168:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft <= 16)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src << sft) >> 8;
			res = (src << sft) & 0x0000FFFF;
			CPU->flag_V = 0;
			CPU->flag_N = res >> 8;
			CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_X = CPU->flag_C = 0;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// LSLD
OP_0xE1A8:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft < 32)
		{
			CPU->flag_X = CPU->flag_C = ((u32)src >> (32 - sft)) << C68K_SR_C_SFT;
			res = (u32)(src << sft);
			CPU->flag_V = 0;
			CPU->flag_N = res >> 24;
			CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
		}

		if (sft == 32) CPU->flag_C = (u32)src << C68K_SR_C_SFT;
		else CPU->flag_C = 0;
		CPU->flag_X = CPU->flag_C;
		CPU->flag_N = 0;
		CPU->flag_notZ = 0;
		CPU->flag_V = 0;
		res = 0;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// ROXLD
OP_0xE130:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 9;

		src |= (CPU->flag_X & C68K_SR_X) << 0;
		res = ((u32)src << sft) | ((u32)src >> (9 - sft));
		CPU->flag_X = CPU->flag_C = res >> 0;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 0;
		CPU->flag_notZ = res & 0x000000FF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROXLD
OP_0xE170:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 17;

		src |= (CPU->flag_X & C68K_SR_X) << 8;
		res = ((u32)src << sft) | ((u32)src >> (17 - sft));
		CPU->flag_X = CPU->flag_C = res >> 8;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 8;
		CPU->flag_notZ = res & 0x0000FFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROXLD
OP_0xE1B0:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		sft %= 33;

		if (sft != 0)
		{
			if (sft == 1) res = ((u32)src << 1) | ((CPU->flag_X >> ((C68K_SR_X_SFT + 1) - 1)) & 1);
			else res = ((u32)src << sft) | ((u32)src >> (33 - sft)) | (((CPU->flag_X >> ((C68K_SR_X_SFT + 1) - 1)) & 1) << (sft - 1));
			CPU->flag_X = ((u32)src >> (32 - sft)) << C68K_SR_X_SFT;
		}
		else res = (u32)src;
		CPU->flag_C = CPU->flag_X;
		CPU->flag_V = 0;
		CPU->flag_N = res >> 24;
		CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = CPU->flag_X;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// ROLD
OP_0xE138:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u8)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft &= 0x07)
		{
			CPU->flag_C = (u32)((src << sft) >> 0);
			res = (u32)(((src << sft) | (src >> (8 - sft))) & 0x000000FF);
			CPU->flag_V = 0;
			CPU->flag_N = res >> 0;
			CPU->flag_notZ = res;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_V = 0;
		CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
		CPU->flag_N = (u32)src >> 0;
		CPU->flag_notZ = (u32)src;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 0;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROLD
OP_0xE178:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u16)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft &= 0x0F)
		{
			CPU->flag_C = (u32)((src << sft) >> 8);
			res = (u32)(((src << sft) | (src >> (16 - sft))) & 0x0000FFFF);
			CPU->flag_V = 0;
			CPU->flag_N = res >> 8;
			CPU->flag_notZ = res;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
		}

		CPU->flag_V = 0;
		CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
		CPU->flag_N = (u32)src >> 8;
		CPU->flag_notZ = (u32)src;
	RET(6)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 8;
	CPU->flag_notZ = (u32)src;
}
RET(6)

// ROLD
OP_0xE1B8:
{
	u32 res;
	pointer src;
	u32 sft;

	sft = CPU->D[(Opcode >> 9) & 7] & 0x3F;
	src = (u32)CPU->D[(Opcode >> 0) & 7];
	if (sft)
	{
	CCnt -= sft * 2;
		if (sft &= 0x1F)
		{
			CPU->flag_C = (u32)((src >> (32 - sft)) << C68K_SR_C_SFT);
			res = (u32)((src << sft) | (src >> (32 - sft)));
			CPU->flag_V = 0;
			CPU->flag_N = res >> 24;
			CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(8)
		}

		CPU->flag_V = 0;
		CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
		CPU->flag_N = (u32)src >> 24;
		CPU->flag_notZ = (u32)src;
	RET(8)
	}

	CPU->flag_V = 0;
	CPU->flag_C = 0;
	CPU->flag_N = (u32)src >> 24;
	CPU->flag_notZ = (u32)src;
}
RET(8)

// ASR
OP_0xE0D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASR
OP_0xE0D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASR
OP_0xE0E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ASR
OP_0xE0E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ASR
OP_0xE0F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ASR
OP_0xE0F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ASR
OP_0xE0F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ASR
OP_0xE0DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASR
OP_0xE0E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = ((u32)src >> 1) | ((u32)src & (1 << 15));
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// LSR
OP_0xE2D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSR
OP_0xE2D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSR
OP_0xE2E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// LSR
OP_0xE2E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// LSR
OP_0xE2F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// LSR
OP_0xE2F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// LSR
OP_0xE2F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// LSR
OP_0xE2DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSR
OP_0xE2E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_N = CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)src << C68K_SR_C_SFT;
	res = (u32)(src >> 1);
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROXR
OP_0xE4D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXR
OP_0xE4D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXR
OP_0xE4E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROXR
OP_0xE4E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROXR
OP_0xE4F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ROXR
OP_0xE4F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROXR
OP_0xE4F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ROXR
OP_0xE4DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXR
OP_0xE4E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = ((u32)src >> 1) | ((CPU->flag_X & C68K_SR_X) << 7);
	CPU->flag_C = CPU->flag_X = (u32)(src << C68K_SR_C_SFT);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROR
OP_0xE6D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROR
OP_0xE6D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROR
OP_0xE6E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROR
OP_0xE6E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROR
OP_0xE6F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ROR
OP_0xE6F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROR
OP_0xE6F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ROR
OP_0xE6DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROR
OP_0xE6E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src << C68K_SR_C_SFT);
	res = ((u32)src >> 1) | ((u32)src << 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ASL
OP_0xE1D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASL
OP_0xE1D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASL
OP_0xE1E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ASL
OP_0xE1E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ASL
OP_0xE1F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ASL
OP_0xE1F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ASL
OP_0xE1F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ASL
OP_0xE1DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ASL
OP_0xE1E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_V = ((u32)src ^ res) >> 8;
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// LSL
OP_0xE3D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSL
OP_0xE3D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSL
OP_0xE3E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// LSL
OP_0xE3E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// LSL
OP_0xE3F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// LSL
OP_0xE3F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// LSL
OP_0xE3F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// LSL
OP_0xE3DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// LSL
OP_0xE3E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	res = (u32)(src << 1);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROXL
OP_0xE5D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXL
OP_0xE5D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXL
OP_0xE5E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROXL
OP_0xE5E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROXL
OP_0xE5F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ROXL
OP_0xE5F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROXL
OP_0xE5F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ROXL
OP_0xE5DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROXL
OP_0xE5E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	res = (u32)(src << 1) | ((CPU->flag_X & C68K_SR_X) >> 8);
	CPU->flag_X = CPU->flag_C = (u32)(src >> 7);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROL
OP_0xE7D0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROL
OP_0xE7D8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROL
OP_0xE7E0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] - 2;
	CPU->A[(Opcode >> 0) & 7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)

// ROL
OP_0xE7E8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROL
OP_0xE7F0:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(18)

// ROL
OP_0xE7F8:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(16)

// ROL
OP_0xE7F9:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = (s32)FETCH_LONG;
	PC += 4;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(20)

// ROL
OP_0xE7DF:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(12)

// ROL
OP_0xE7E7:
{
	u32 adr;
	u32 res;
	pointer src;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	PRE_IO
	READ_WORD_F(adr, src)
	CPU->flag_V = 0;
	CPU->flag_C = (u32)(src >> 7);
	res = ((u32)src << 1) | ((u32)src >> 15);
	CPU->flag_N = res >> 8;
	CPU->flag_notZ = res & 0x0000FFFF;
	WRITE_WORD_F(adr, res)
	POST_IO
}
RET(14)
