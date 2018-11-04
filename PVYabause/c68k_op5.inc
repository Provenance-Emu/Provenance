
// STCC
OP_0x50C0:
{
	u32 res;
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
}

// STCC
OP_0x51C0:
{
	u32 res;
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x52C0:
{
	u32 res;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x53C0:
{
	u32 res;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x54C0:
{
	u32 res;
	if (!(CPU->flag_C & 0x100))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x55C0:
{
	u32 res;
	if (CPU->flag_C & 0x100)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x56C0:
{
	u32 res;
	if (CPU->flag_notZ)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x57C0:
{
	u32 res;
	if (!CPU->flag_notZ)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x58C0:
{
	u32 res;
	if (!(CPU->flag_V & 0x80))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x59C0:
{
	u32 res;
	if (CPU->flag_V & 0x80)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5AC0:
{
	u32 res;
	if (!(CPU->flag_N & 0x80))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5BC0:
{
	u32 res;
	if (CPU->flag_N & 0x80)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5CC0:
{
	u32 res;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5DC0:
{
	u32 res;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5EC0:
{
	u32 res;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x5FC0:
{
	u32 res;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
	res = 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(6)
	}
	res = 0;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	RET(4)
}

// STCC
OP_0x50D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x51D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x52D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (!(CPU->flag_C & 0x100))
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
OP_0x55D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_C & 0x100)
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
OP_0x56D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_notZ)
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
OP_0x57D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (!CPU->flag_notZ)
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
OP_0x58D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (!(CPU->flag_V & 0x80))
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
OP_0x59D0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_V & 0x80)
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
OP_0x5AD0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BD0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_N & 0x80)
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
OP_0x5CD0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DD0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5ED0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FD0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x51D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x52D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_C & 0x100)
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
OP_0x56D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_notZ)
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
OP_0x57D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (!CPU->flag_notZ)
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
OP_0x58D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59D8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_V & 0x80)
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
OP_0x5AD8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BD8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_N & 0x80)
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
OP_0x5CD8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DD8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5ED8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FD8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	CPU->A[(Opcode >> 0) & 7] += 1;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OP_0x51E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OP_0x52E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_C & 0x100)
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
OP_0x56E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_notZ)
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
OP_0x57E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (!CPU->flag_notZ)
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
OP_0x58E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59E0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_V & 0x80)
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
OP_0x5AE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_N & 0x80)
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
OP_0x5CE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FE0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] - 1;
	CPU->A[(Opcode >> 0) & 7] = adr;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OP_0x51E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OP_0x52E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_C & 0x100)
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
OP_0x56E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ)
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
OP_0x57E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!CPU->flag_notZ)
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
OP_0x58E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59E8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_V & 0x80)
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
OP_0x5AE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_N & 0x80)
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
OP_0x5CE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FE8:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7] + (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OP_0x51F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(18)
}

// STCC
OP_0x52F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (!(CPU->flag_C & 0x100))
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
OP_0x55F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_C & 0x100)
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
OP_0x56F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_notZ)
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
OP_0x57F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (!CPU->flag_notZ)
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
OP_0x58F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (!(CPU->flag_V & 0x80))
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
OP_0x59F0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_V & 0x80)
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
OP_0x5AF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_N & 0x80)
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
OP_0x5CF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FF0:
{
	u32 adr;
	u32 res;
	adr = CPU->A[(Opcode >> 0) & 7];
	DECODE_EXT_WORD
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OP_0x51F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(16)
}

// STCC
OP_0x52F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_C & 0x100)
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
OP_0x56F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ)
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
OP_0x57F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!CPU->flag_notZ)
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
OP_0x58F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59F8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_V & 0x80)
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
OP_0x5AF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_N & 0x80)
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
OP_0x5CF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FF8:
{
	u32 adr;
	u32 res;
	adr = (s32)(s16)FETCH_WORD;
	PC += 2;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OP_0x51F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(20)
}

// STCC
OP_0x52F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_C & 0x100)
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
OP_0x56F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_notZ)
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
OP_0x57F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (!CPU->flag_notZ)
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
OP_0x58F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59F9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_V & 0x80)
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
OP_0x5AF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_N & 0x80)
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
OP_0x5CF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FF9:
{
	u32 adr;
	u32 res;
	adr = (s32)FETCH_LONG;
	PC += 4;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x51DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(12)
}

// STCC
OP_0x52DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_C & 0x100)
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
OP_0x56DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_notZ)
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
OP_0x57DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (!CPU->flag_notZ)
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
OP_0x58DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59DF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_V & 0x80)
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
OP_0x5ADF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_N & 0x80)
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
OP_0x5CDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FDF:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7];
	CPU->A[7] += 2;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	res = 0xFF;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OP_0x51E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	res = 0;
	PRE_IO
	WRITE_BYTE_F(adr, res)
	POST_IO
	RET(14)
}

// STCC
OP_0x52E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
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
OP_0x53E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
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
OP_0x54E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (!(CPU->flag_C & 0x100))
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
OP_0x55E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_C & 0x100)
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
OP_0x56E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_notZ)
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
OP_0x57E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (!CPU->flag_notZ)
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
OP_0x58E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (!(CPU->flag_V & 0x80))
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
OP_0x59E7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_V & 0x80)
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
OP_0x5AE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (!(CPU->flag_N & 0x80))
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
OP_0x5BE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_N & 0x80)
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
OP_0x5CE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x5DE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
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
OP_0x5EE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
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
OP_0x5FE7:
{
	u32 adr;
	u32 res;
	adr = CPU->A[7] - 2;
	CPU->A[7] = adr;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
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
OP_0x50C8:
{
	PC += 2;
}
RET(12)

// DBCC
OP_0x51C8:
{
	u32 res;
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x52C8:
{
	u32 res;
	if ((!CPU->flag_notZ) || (CPU->flag_C & 0x100))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x53C8:
{
	u32 res;
	if (CPU->flag_notZ && (!(CPU->flag_C & 0x100)))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x54C8:
{
	u32 res;
	if (CPU->flag_C & 0x100)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x55C8:
{
	u32 res;
	if (!(CPU->flag_C & 0x100))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x56C8:
{
	u32 res;
	if (!CPU->flag_notZ)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x57C8:
{
	u32 res;
	if (CPU->flag_notZ)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x58C8:
{
	u32 res;
	if (CPU->flag_V & 0x80)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x59C8:
{
	u32 res;
	if (!(CPU->flag_V & 0x80))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5AC8:
{
	u32 res;
	if (CPU->flag_N & 0x80)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5BC8:
{
	u32 res;
	if (!(CPU->flag_N & 0x80))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5CC8:
{
	u32 res;
	if ((CPU->flag_N ^ CPU->flag_V) & 0x80)
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5DC8:
{
	u32 res;
	if (!((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5EC8:
{
	u32 res;
	if ((!CPU->flag_notZ) || ((CPU->flag_N ^ CPU->flag_V) & 0x80))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// DBCC
OP_0x5FC8:
{
	u32 res;
	if (CPU->flag_notZ && (!((CPU->flag_N ^ CPU->flag_V) & 0x80)))
	{
	res = (u16)CPU->D[(Opcode >> 0) & 7];
	res--;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
	if ((s32)res != -1)
	{
		PC += (s32)(s16)FETCH_WORD;
		PC -= CPU->BasePC;
		SET_PC(PC);
	RET(10)
	}
	}
	else
	{
		PC += 2;
	RET(12)
	}
	PC += 2;
}
RET(14)

// ADDQ
OP_0x5000:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u8)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst + src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res));
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// ADDQ
OP_0x5010:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5018:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5020:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5028:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5030:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5038:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5039:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x501F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5027:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5040:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst + src);
	CPU->flag_V = (u32)((src ^ res) & (dst ^ res)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// ADDQ
OP_0x5048:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->A[(Opcode >> 0) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(8)

// ADDQ
OP_0x5050:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5058:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5060:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5068:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5070:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5078:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5079:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x505F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5067:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5080:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst + src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & (u32)dst & 1) + ((u32)src >> 1) + ((u32)dst >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ res) & ((u32)dst ^ res)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// ADDQ
OP_0x5088:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->A[(Opcode >> 0) & 7];
	res = (u32)(dst + src);
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(8)

// ADDQ
OP_0x5090:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x5098:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50A0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50A8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50B0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50B8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50B9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x509F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// ADDQ
OP_0x50A7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5100:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u8)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst - src);
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res;
	CPU->flag_V = ((u32)src ^ (u32)dst) & (res ^ (u32)dst);
	CPU->flag_notZ = res & 0xFF;
	*(BYTE_OFF + (u8*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// SUBQ
OP_0x5110:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5118:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5120:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5128:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5130:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5138:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5139:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x511F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5127:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5140:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u16)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst - src);
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 8;
	CPU->flag_N = CPU->flag_X = CPU->flag_C = res >> 8;
	CPU->flag_notZ = res & 0xFFFF;
	*(WORD_OFF + (u16*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(4)

// SUBQ
OP_0x5148:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->A[(Opcode >> 0) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(8)

// SUBQ
OP_0x5150:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5158:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5160:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5168:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5170:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5178:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5179:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x515F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5167:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5180:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->D[(Opcode >> 0) & 7];
	res = (u32)(dst - src);
	CPU->flag_notZ = res;
	CPU->flag_X = CPU->flag_C = (((u32)src & res & 1) + ((u32)src >> 1) + (res >> 1)) >> 23;
	CPU->flag_V = (((u32)src ^ (u32)dst) & (res ^ (u32)dst)) >> 24;
	CPU->flag_N = res >> 24;
	*((u32*)(&CPU->D[(Opcode >> 0) & 7])) = res;
}
RET(8)

// SUBQ
OP_0x5188:
{
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
	dst = (u32)CPU->A[(Opcode >> 0) & 7];
	res = (u32)(dst - src);
	CPU->A[(Opcode >> 0) & 7] = res;
}
RET(8)

// SUBQ
OP_0x5190:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x5198:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51A0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51A8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51B0:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51B8:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51B9:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x519F:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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

// SUBQ
OP_0x51A7:
{
	u32 adr;
	u32 res;
	pointer dst;
	pointer src;
	src = (((Opcode >> 9) - 1) & 7) + 1;
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
