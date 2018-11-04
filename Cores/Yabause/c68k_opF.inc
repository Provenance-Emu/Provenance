
// 1111
OP_0xF000:
{
	u32 res;
	PC -= 2;
	if (!CPU->flag_S)
	{
		res = CPU->USP;
		CPU->USP = CPU->A[7];
		CPU->A[7] = res;
	}
	res = C68K_1111_EX;
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
