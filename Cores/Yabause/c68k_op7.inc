
// MOVEQ
OP_0x7000:
{
	u32 res;
	res = (s32)(s8)Opcode;
	CPU->flag_C = CPU->flag_V = 0;
	CPU->flag_N = CPU->flag_notZ = res;
	*((u32*)(&CPU->D[(Opcode >> 9) & 7])) = res;
}
RET(4)
