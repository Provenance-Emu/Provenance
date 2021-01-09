switch(Pipe_ID >> 24)
{
 #include "sh7095_opdefs.inc"

 #define PART_OP_NORMIDIF { DoIDIF(false); }
 
 #define BEGIN_OP(x)		OP_##x { PART_OP_NORMIDIF
 #define BEGIN_OP_FUDGEIF(x)	OP_##x { if(EmulateICache) { UCRead_IF_Kludge = false; } DoIDIF(false); if(EmulateICache) { timestamp -= UCRead_IF_Kludge; }
 #define BEGIN_OP_DLYIDIF(x)	OP_##x { 

 // "Interrupt-disabled" instruction(blocks interrupt from being taken for next instruction).
 // Use with BEGIN_OP_DLYIDIF()
 #define PART_OP_INTDIS { DoIDIF(true); }

 #define END_OP } break;

 #define WB_EX_CHECK(r) { if(timestamp < WB_until[(r)]) timestamp = WB_until[(r)]; }
 #define WB_WRITE(r, v) { R[(r)] = (v); WB_until[(r)] = MA_until + 1; }
 #define WB_READ8(r, A) { uint8 memrv; MemRead8(A, memrv); WB_WRITE((r), (int8)memrv); }
 #define WB_READ16(r, A) { uint16 memrv; MemRead16(A, memrv); WB_WRITE((r), (int16)memrv); }
 #define WB_READ32(r, A) { uint32 memrv; MemRead32(A, memrv); WB_WRITE((r), memrv); }
 #define WB_READ16_I(r, A) { uint16 memrv; MemRead16_I(A, memrv); WB_WRITE((r), (int16)memrv); }
 #define WB_READ32_I(r, A) { uint32 memrv; MemRead32_I(A, memrv); WB_WRITE((r), memrv); }
 //
 //
 //
 //
 // MOV #imm,Rn
 //
 BEGIN_OP(MOV_IMM_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(uint32, imm) = (int8)instr;

	WB_EX_CHECK(n)

	R[n] = imm;
 END_OP


 //
 // MOV.W @(disp,PC),Rn
 //
 BEGIN_OP(MOV_W_PCREL_REG)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = PC + (d << 1);

	WB_READ16_I(instr_nyb2, ea);
 END_OP


 //
 // MOV.L @(disp,PC),Rn
 //
 BEGIN_OP(MOV_L_PCREL_REG)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = (PC &~ 0x3) + (d << 2);

	WB_READ32_I(instr_nyb2, ea);
 END_OP


 //
 // MOV Rm,Rn
 //
 BEGIN_OP(MOV_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = R[m];
 END_OP


 //
 // MOV.B Rm,@Rn
 //
 BEGIN_OP(MOV_B_REG_REGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	CONST_VAR(uint32, ea) = R[n];

	MemWrite8(ea, val);
 END_OP


 //
 // MOV.W Rm,@Rn
 //
 BEGIN_OP(MOV_W_REG_REGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	CONST_VAR(uint32, ea) = R[n];

	MemWrite16(ea, val);
 END_OP


 //
 // MOV.L Rm,@Rn
 //
 BEGIN_OP(MOV_L_REG_REGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	CONST_VAR(uint32, ea) = R[n];

	MemWrite32(ea, val);
 END_OP


 //
 // MOV.B @Rm,Rn
 //
 BEGIN_OP(MOV_B_REGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[m];

	WB_READ8(instr_nyb2, ea);
 END_OP


 //
 // MOV.W @Rm,Rn
 //
 BEGIN_OP(MOV_W_REGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[m];

	WB_READ16(instr_nyb2, ea);
 END_OP


 //
 // MOV.L @Rm,Rn
 //
 BEGIN_OP(MOV_L_REGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[m];

	WB_READ32(instr_nyb2, ea);
 END_OP


 //
 // MOV.B Rm,@-Rn
 //
 BEGIN_OP(MOV_B_REG_REGINDIRPD)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	uint32 ea;

	R[n] -= 1;
	ea = R[n];

	MemWrite8(ea, val);
 END_OP


 //
 // MOV.W Rm,@-Rn
 //
 BEGIN_OP(MOV_W_REG_REGINDIRPD)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	uint32 ea;

	R[n] -= 2;
	ea = R[n];

	MemWrite16(ea, val);
 END_OP


 //
 // MOV.L Rm,@-Rn
 //
 BEGIN_OP(MOV_L_REG_REGINDIRPD)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, val) = R[m];
	uint32 ea;

	R[n] -= 4;
	ea = R[n];

	MemWrite32(ea, val);
 END_OP


 //
 // MOV.B @Rm+,Rn
 //
 BEGIN_OP(MOV_B_REGINDIRPI_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	uint32 ea;

	ea = R[m];
	R[m] += 1;

	WB_READ8(instr_nyb2, ea);
 END_OP


 //
 // MOV.W @Rm+,Rn
 //
 BEGIN_OP(MOV_W_REGINDIRPI_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	uint32 ea;

	ea = R[m];
	R[m] += 2;

	WB_READ16(instr_nyb2, ea);
 END_OP


 //
 // MOV.L @Rm+,Rn
 //
 BEGIN_OP(MOV_L_REGINDIRPI_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	uint32 ea;

	ea = R[m];
	R[m] += 4;

	WB_READ32(instr_nyb2, ea);
 END_OP


 //
 // MOV.B R0,@(disp,Rn)
 //
 BEGIN_OP(MOV_B_REG0_REGINDIRDISP)
	CONST_VAR(unsigned, n) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[n] + (d << 0);

	MemWrite8(ea, R[0]);
 END_OP


 //
 // MOV.W R0,@(disp,Rn)
 //
 BEGIN_OP(MOV_W_REG0_REGINDIRDISP)
	CONST_VAR(unsigned, n) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[n] + (d << 1);

	MemWrite16(ea, R[0]);
 END_OP


 //
 // MOV.L Rm,@(disp,Rn)
 //
 BEGIN_OP(MOV_L_REG_REGINDIRDISP)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[n] + (d << 2);

	MemWrite32(ea, R[m]);
 END_OP


 //
 // MOV.B @(disp,Rm),R0
 //
 BEGIN_OP(MOV_B_REGINDIRDISP_REG0)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[m] + (d << 0);

	WB_READ8(0, ea);
 END_OP


 //
 // MOV.W @(disp,Rm),R0
 //
 BEGIN_OP(MOV_W_REGINDIRDISP_REG0)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[m] + (d << 1);

	WB_READ16(0, ea);
 END_OP


 //
 // MOV.L @(disp,Rm),Rn
 //
 BEGIN_OP(MOV_L_REGINDIRDISP_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xf;
	CONST_VAR(uint32, ea) = R[m] + (d << 2);

	WB_READ32(instr_nyb2, ea);
 END_OP


 //
 // MOV.B Rm,@(R0,Rn)
 //
 BEGIN_OP(MOV_B_REG_IDXREGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[n];

	MemWrite8(ea, R[m]);
 END_OP


 //
 // MOV.W Rm,@(R0,Rn)
 //
 BEGIN_OP(MOV_W_REG_IDXREGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[n];

	MemWrite16(ea, R[m]);
 END_OP


 //
 // MOV.L Rm,@(R0,Rn)
 //
 BEGIN_OP(MOV_L_REG_IDXREGINDIR)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[n];

	MemWrite32(ea, R[m]);
 END_OP


 //
 // MOV.B @(R0,Rm),Rn
 //
 BEGIN_OP(MOV_B_IDXREGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[m];

	WB_READ8(instr_nyb2, ea);
 END_OP


 //
 // MOV.W @(R0,Rm),Rn
 //
 BEGIN_OP(MOV_W_IDXREGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[m];

	WB_READ16(instr_nyb2, ea);
 END_OP


 //
 // MOV.L @(R0,Rm),Rn
 //
 BEGIN_OP(MOV_L_IDXREGINDIR_REG)
	CONST_VAR(unsigned, m) = instr_nyb1;
	CONST_VAR(uint32, ea) = R[0] + R[m];

	WB_READ32(instr_nyb2, ea);
 END_OP


 //
 // MOV.B R0,@(disp,GBR)
 //
 BEGIN_OP(MOV_B_REG0_GBRINDIRDISP)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 0);

	MemWrite8(ea, R[0]);
 END_OP


 //
 // MOV.W R0,@(disp,GBR)
 //
 BEGIN_OP(MOV_W_REG0_GBRINDIRDISP)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 1);

	MemWrite16(ea, R[0]);
 END_OP


 //
 // MOV.L R0,@(disp,GBR)
 //
 BEGIN_OP(MOV_L_REG0_GBRINDIRDISP)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 2);

	MemWrite32(ea, R[0]);
 END_OP


 //
 // MOV.B @(disp,GBR),R0
 //
 BEGIN_OP(MOV_B_GBRINDIRDISP_REG0)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 0);

	WB_READ8(0, ea);
 END_OP


 //
 // MOV.W @(disp,GBR),R0
 //
 BEGIN_OP(MOV_W_GBRINDIRDISP_REG0)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 1);

	WB_READ16(0, ea);
 END_OP


 //
 // MOV.L @(disp,GBR),R0
 //
 BEGIN_OP(MOV_L_GBRINDIRDISP_REG0)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = GBR + (d << 2);

	WB_READ32(0, ea);
 END_OP


 //
 // MOVA @(disp,PC),R0
 //
 BEGIN_OP(MOVA_PCREL_REG0)
	CONST_VAR(unsigned, d) = (instr >> 0) & 0xff;
	CONST_VAR(uint32, ea) = (PC &~ 0x3) + (d << 2);

	WB_EX_CHECK(0)

	R[0] = ea;
 END_OP


 //
 // MOVT Rn
 //
 BEGIN_OP(MOVT_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] = GetT();
 END_OP


 //
 // SWAP.B Rm,Rn
 //
 BEGIN_OP(SWAP_B_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (R[m] & 0xFFFF0000) | ((R[m] << 8) & 0xFF00) | ((R[m] >> 8) & 0x00FF);
 END_OP


 //
 // SWAP.W Rm,Rn
 //
 BEGIN_OP(SWAP_W_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (R[m] << 16) | (R[m] >> 16);
 END_OP


 //
 // XTRCT Rm,Rn
 //
 BEGIN_OP(XTRCT_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (R[n] >> 16) | (R[m] << 16);
 END_OP


 //
 // ADD Rm,Rn
 //
 BEGIN_OP(ADD_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = R[n] + R[m];
 END_OP


 //
 // ADD #imm,Rn
 //
 BEGIN_OP(ADD_IMM_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(uint32, imm) = (int8)instr;

	WB_EX_CHECK(n)

	R[n] = R[n] + imm;
 END_OP


 //
 // ADDC Rm,Rn
 //
 BEGIN_OP(ADDC_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint64 result = (uint64)R[n] + R[m] + GetT();

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = result;
	SetT((result >> 32) & 1);
 END_OP


 //
 // ADDV Rm,Rn
 //
 BEGIN_OP(ADDV_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint32 result = R[n] + R[m];

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT(((~(R[n] ^ R[m])) & (R[n] ^ result)) >> 31);
	R[n] = result;
 END_OP


 //
 // CMP/EQ #imm,R0
 //
 BEGIN_OP(CMP_EQ_IMM_REG0)
	CONST_VAR(uint32, imm) = (int8)instr;

	WB_EX_CHECK(0)

	SetT(imm == R[0]);
 END_OP


 //
 // CMP/EQ Rm,Rn
 //
 BEGIN_OP(CMP_EQ_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT(R[n] == R[m]);
 END_OP


 //
 // CMP/HS Rm,Rn
 //
 BEGIN_OP(CMP_HS_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT(R[n] >= R[m]);
 END_OP


 //
 // CMP/GE Rm,Rn
 //
 BEGIN_OP(CMP_GE_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT((int32)R[n] >= (int32)R[m]);
 END_OP


 //
 // CMP/HI Rm,Rn
 //
 BEGIN_OP(CMP_HI_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT(R[n] > R[m]);
 END_OP


 //
 // CMP/GT Rm,Rn
 //
 BEGIN_OP(CMP_GT_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT((int32)R[n] > (int32)R[m]);
 END_OP


 //
 // CMP/PZ Rn
 //
 BEGIN_OP(CMP_PZ_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	SetT((int32)R[n] >= 0);
 END_OP


 //
 // CMP/PL Rn
 //
 BEGIN_OP(CMP_PL_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	SetT((int32)R[n] > 0);
 END_OP


 //
 // CMP/STR Rm,Rn
 //
 BEGIN_OP(CMP_STR_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint32 tmp = R[n] ^ R[m];
	unsigned new_T = 0;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	if(!(tmp & 0x000000FF)) new_T = 1;
	if(!(tmp & 0x0000FF00)) new_T = 1;
	if(!(tmp & 0x00FF0000)) new_T = 1;
	if(!(tmp & 0xFF000000)) new_T = 1;

	SetT(new_T);
 END_OP


 //
 // DIV1 Rm,Rn
 //
 BEGIN_OP(DIV1_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	uint32 tmp;
	bool new_Q;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	new_Q = R[n] >> 31;
	R[n] <<= 1;
	R[n] |= GetT();

	tmp = R[n];
	new_Q ^= GetM();

	if(!(GetQ() ^ GetM()))
	{
	 R[n] -= R[m];
	 new_Q ^= (R[n] > tmp);
	}
	else
	{
	 R[n] += R[m];
	 new_Q ^= (R[n] < tmp);
	}

	SetQ(new_Q);
	SetT(new_Q == GetM());
 END_OP


 //
 // DIV0S Rm,Rn
 //
 BEGIN_OP(DIV0S_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const unsigned new_Q = R[n] >> 31;
	const unsigned new_M = R[m] >> 31;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetQ(new_Q);
	SetM(new_M);
	SetT(new_Q != new_M);
 END_OP


 //
 // DIV0U 
 //
 BEGIN_OP(DIV0U)
	SetQ(false);
	SetM(false);
	SetT(false);
 END_OP


 //
 // DT 
 //
 BEGIN_OP(DT)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n]--;
	SetT(!R[n]);
 END_OP


 //
 // EXTS.B Rm,Rn
 //
 BEGIN_OP(EXTS_B_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (int8)R[m];
 END_OP


 //
 // EXTS.W Rm,Rn
 //
 BEGIN_OP(EXTS_W_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (int16)R[m];
 END_OP


 //
 // EXTU.B Rm,Rn
 //
 BEGIN_OP(EXTU_B_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (uint8)R[m];
 END_OP


 //
 // EXTU.W Rm,Rn
 //
 BEGIN_OP(EXTU_W_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = (uint16)R[m];
 END_OP


 //
 // MAC.L @Rm+,@Rn+
 //
 //  Pipeline: page 188(not implemented right here)
 BEGIN_OP(MAC_L)
	RESUME_VAR(int32, opexec_MAC_L_m0);
	RESUME_VAR(int32, opexec_MAC_L_m1);
	{
	 // Order confirmed.
	 MemRead32(R[instr_nyb1], opexec_MAC_L_m0);
	 R[instr_nyb1] += 4;
	 MemRead32(R[instr_nyb2], opexec_MAC_L_m1);
	 R[instr_nyb2] += 4;
	}
	uint64 a, b, sum;

	a = GetMAC64();
	b = (int64)opexec_MAC_L_m0 * opexec_MAC_L_m1;
	sum = a + b;

	if(GetS() && sum > 0x00007FFFFFFFFFFFULL && sum < 0xFFFF800000000000ULL)
	{
	 if((int32)(opexec_MAC_L_m0 ^ opexec_MAC_L_m1) < 0)
	  sum = 0xFFFF800000000000ULL;
	 else
	  sum = 0x00007FFFFFFFFFFFULL;
	}

	SetMAC64(sum);

	timestamp++;
 END_OP


 //
 // MAC.W @Rm+,@Rn+
 //
 //  Pipeline: page 180(not implemented right here)
 BEGIN_OP(MAC_W)
	RESUME_VAR(int16, opexec_MAC_W_m0);
	RESUME_VAR(int16, opexec_MAC_W_m1);
	{
	 // Order confirmed.
	 MemRead16(R[instr_nyb1], opexec_MAC_W_m0);
	 R[instr_nyb1] += 2;
         MemRead16(R[instr_nyb2], opexec_MAC_W_m1);
	 R[instr_nyb2] += 2;
	}

	if(GetS())
	{
	 int32 b = (int32)opexec_MAC_W_m0 * opexec_MAC_W_m1;
	 uint64 sum = (int64)(int32)MACL + b;

	 if(sum > 0x000000007FFFFFFFULL && sum < 0xFFFFFFFF80000000ULL)
	 {
	  MACH |= 1;

	  if(b < 0)
	   sum = 0x80000000ULL;
	  else
	   sum = 0x7FFFFFFFULL;
	 }

	 MACL = sum;
	}
	else
	 SetMAC64(GetMAC64() + (int64)opexec_MAC_W_m0 * opexec_MAC_W_m1);

	timestamp++;
 END_OP


 //
 // DMULS.L Rm,Rn
 //
 //  Pipeline: page 215 (not implemented here totally correctly)
 BEGIN_OP_DLYIDIF(DMULS_L_REG_REG)
	{
	 timestamp++;

	 MA_until = std::max<sscpu_timestamp_t>(std::max<sscpu_timestamp_t>(MA_until, MM_until), timestamp + 1);
	 MM_until = MA_until + 4;
	 PART_OP_NORMIDIF
	}
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint64 result = (int64)(int32)R[n] * (int32)R[m];

	MACL = result >> 0;
	MACH = result >> 32;
 END_OP


 //
 // DMULU.L Rm,Rn
 //
 //  Pipeline: page 215 (not implemented here totally correctly)
 BEGIN_OP_DLYIDIF(DMULU_L_REG_REG)
	{
	 timestamp++;

	 MA_until = std::max<sscpu_timestamp_t>(std::max<sscpu_timestamp_t>(MA_until, MM_until), timestamp + 1);
	 MM_until = MA_until + 4;
	 PART_OP_NORMIDIF
	}
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint64 result = (uint64)R[n] * R[m];

	MACL = result >> 0;
	MACH = result >> 32;
 END_OP


 //
 // MUL.L Rm,Rn
 //
 //  Pipeline: page 215 (not implemented here totally correctly)
 BEGIN_OP_DLYIDIF(MUL_L_REG_REG)
	{
	 timestamp++;

	 MA_until = std::max<sscpu_timestamp_t>(std::max<sscpu_timestamp_t>(MA_until, MM_until), timestamp + 1);
	 MM_until = MA_until + 4;
	 PART_OP_NORMIDIF
	}
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	MACL = R[n] * R[m];
 END_OP


 //
 // MULS.W Rm,Rn
 //
 //  Pipeline: page 207
 BEGIN_OP(MULS_W_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	MA_until = std::max<sscpu_timestamp_t>(std::max<sscpu_timestamp_t>(MA_until, MM_until), timestamp + 1);
	MM_until = MA_until + 2;

	MACL = (int16)R[n] * (int16)R[m];
 END_OP


 //
 // MULU.W Rm,Rn
 //
 //  Pipeline: page 207
 BEGIN_OP(MULU_W_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	MA_until = std::max<sscpu_timestamp_t>(std::max<sscpu_timestamp_t>(MA_until, MM_until), timestamp + 1);
	MM_until = MA_until + 2;

	MACL = (uint32)(uint16)R[n] * (uint32)(uint16)R[m];
 END_OP


 //
 // NEG Rm,Rn
 //
 BEGIN_OP(NEG_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = -R[m];
 END_OP


 //
 // NEGC Rm,Rn
 //
 BEGIN_OP(NEGC_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint64 result = (uint64)0 - R[m] - GetT();

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = result;
	SetT((result >> 32) & 1);
 END_OP


 //
 // SUB Rm,Rn
 //
 BEGIN_OP(SUB_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = R[n] - R[m];
 END_OP


 //
 // SUBC Rm,Rn
 //
 BEGIN_OP(SUBC_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint64 result = (uint64)R[n] - R[m] - GetT();

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = result;
	SetT((result >> 32) & 1);
 END_OP


 //
 // SUBV Rm,Rn
 //
 BEGIN_OP(SUBV_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;
	const uint32 result = R[n] - R[m];

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT((((R[n] ^ R[m])) & (R[n] ^ result)) >> 31);
	R[n] = result;
 END_OP


 //
 // AND Rm,Rn
 //
 BEGIN_OP(AND_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = R[n] & R[m];
 END_OP


 //
 // AND #imm,R0
 //
 BEGIN_OP(AND_IMM_REG0)
	const unsigned imm = (uint8)instr;

	WB_EX_CHECK(0)

	R[0] = R[0] & imm;
 END_OP


 //
 // AND.B #imm,@(R0,GBR)
 //
 BEGIN_OP(AND_B_IMM_IDXGBRINDIR)
	RESUME_VAR(uint32, opexec_ea);
	opexec_ea = R[0] + GBR;
	uint32 tmp;

	MemRead8(opexec_ea, tmp);
	timestamp++;
	tmp &= (uint8)instr;
	MemWrite8(opexec_ea, tmp);
	timestamp++;
 END_OP


 //
 // NOT Rm,Rn
 //
 BEGIN_OP(NOT_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = ~R[m];
 END_OP


 //
 // OR Rm,Rn
 //
 BEGIN_OP(OR_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] |= R[m];
 END_OP


 //
 // OR #imm,R0
 //
 BEGIN_OP(OR_IMM_REG0)
	const unsigned imm = (uint8)instr;

	WB_EX_CHECK(0)

	R[0] |= imm;
 END_OP


 //
 // OR.B #imm,@(R0,GBR)
 //
 BEGIN_OP(OR_B_IMM_IDXGBRINDIR)
	RESUME_VAR(uint32, opexec_ea);
	opexec_ea = R[0] + GBR;
	uint32 tmp;

	MemRead8(opexec_ea, tmp);
	timestamp++;
	tmp |= (uint8)instr;
	MemWrite8(opexec_ea, tmp);
	timestamp++;
 END_OP


 //
 // TAS.B @Rn
 //
 BEGIN_OP(TAS_B_REGINDIR)
	uint8 tmp;
	RESUME_VAR(uint32, opexec_ea);

	opexec_ea = R[instr_nyb2];

	CHECK_EXIT_RESUME();

	SH7095_BusLock++;
	tmp = ExtBusRead(uint8, false, opexec_ea);	// FIXME: Address error on invalid address(>= 0x40000000 ?).
	timestamp = SH7095_mem_timestamp;

	SetT(!tmp);

	tmp |= 0x80;

	MemWrite8(opexec_ea, tmp);
	SH7095_BusLock--;

	timestamp += 3;
 END_OP


 //
 // TST Rm,Rn
 //
 BEGIN_OP(TST_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	SetT(!(R[n] & R[m]));
 END_OP


 //
 // TST #imm,R0
 //
 BEGIN_OP(TST_IMM_REG0)
	const unsigned imm = (uint8)instr;

	WB_EX_CHECK(0)

	SetT(!(R[0] & imm));
 END_OP


 //
 // TST.B #imm,@(R0,GBR)
 //
 BEGIN_OP(TST_B_IMM_IDXGBRINDIR)
	CONST_VAR(uint32, ea) = R[0] + GBR;
	uint32 tmp;

	MemRead8(ea, tmp);
	timestamp++;
	SetT(!(tmp & (uint8)instr));
	timestamp++;
 END_OP


 //
 // XOR Rm,Rn
 //
 BEGIN_OP(XOR_REG_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	CONST_VAR(unsigned, m) = instr_nyb1;

	WB_EX_CHECK(n)
	WB_EX_CHECK(m)

	R[n] = R[n] ^ R[m];
 END_OP


 //
 // XOR #imm,R0
 //
 BEGIN_OP(XOR_IMM_REG0)
	const unsigned imm = (uint8)instr;

	WB_EX_CHECK(0)

	R[0] = R[0] ^ imm;
 END_OP


 //
 // XOR.B #imm,@(R0,GBR)
 //
 BEGIN_OP(XOR_B_IMM_IDXGBRINDIR)
	RESUME_VAR(uint32, opexec_ea);
	opexec_ea = R[0] + GBR;
	uint32 tmp;

	MemRead8(opexec_ea, tmp);
	timestamp++;
	tmp ^= (uint8)instr;
	MemWrite8(opexec_ea, tmp);
	timestamp++;
 END_OP


 //
 // ROTL Rn
 //
 BEGIN_OP(ROTL_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned rotbit = R[n] >> 31;

	WB_EX_CHECK(n)

	R[n] = (R[n] << 1) | rotbit;
	SetT(rotbit);
 END_OP


 //
 // ROTR Rn
 //
 BEGIN_OP(ROTR_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned rotbit = R[n] & 1;

	WB_EX_CHECK(n)

	R[n] = (R[n] >> 1) | (rotbit << 31);
	SetT(rotbit);
 END_OP


 //
 // ROTCL Rn
 //
 BEGIN_OP(ROTCL_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned rotbit = R[n] >> 31;

	WB_EX_CHECK(n)

	R[n] = (R[n] << 1) | GetT();
	SetT(rotbit);
 END_OP


 //
 // ROTCR Rn
 //
 BEGIN_OP(ROTCR_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned rotbit = R[n] & 1;

	WB_EX_CHECK(n)

	R[n] = (R[n] >> 1) | (GetT() << 31);
	SetT(rotbit);
 END_OP


 //
 // SHAR Rn
 //
 BEGIN_OP(SHAR_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned shbit = R[n] & 1;

	WB_EX_CHECK(n)

	R[n] = (int32)R[n] >> 1;
	SetT(shbit);
 END_OP


 //
 // SHLL Rn
 //
 BEGIN_OP(SHLL_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned shbit = R[n] >> 31;

	WB_EX_CHECK(n)

	R[n] <<= 1;
	SetT(shbit);
 END_OP


 //
 // SHLR Rn
 //
 BEGIN_OP(SHLR_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;
	const unsigned shbit = R[n] & 1;

	WB_EX_CHECK(n)

	R[n] >>= 1;
	SetT(shbit);
 END_OP


 //
 // SHLL2 Rn
 //
 BEGIN_OP(SHLL2_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] <<= 2;
 END_OP


 //
 // SHLR2 Rn
 //
 BEGIN_OP(SHLR2_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] >>= 2;
 END_OP


 //
 // SHLL8 Rn
 //
 BEGIN_OP(SHLL8_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] <<= 8;
 END_OP


 //
 // SHLR8 Rn
 //
 BEGIN_OP(SHLR8_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] >>= 8;
 END_OP


 //
 // SHLL16 Rn
 //
 BEGIN_OP(SHLL16_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] <<= 16;
 END_OP


 //
 // SHLR16 Rn
 //
 BEGIN_OP(SHLR16_REG)
	CONST_VAR(unsigned, n) = instr_nyb2;

	WB_EX_CHECK(n)

	R[n] >>= 16;
 END_OP


 //
 // BF 
 //
 BEGIN_OP_FUDGEIF(BF)
	CondRelBranch(!GetT(), (uint32)(int8)instr << 1);
 END_OP


 //
 // BF/S 
 //
 BEGIN_OP_FUDGEIF(BF_S)
	CondRelDelayBranch(!GetT(), (uint32)(int8)instr << 1);
 END_OP


 //
 // BT 
 //
 BEGIN_OP_FUDGEIF(BT)
	CondRelBranch(GetT(), (uint32)(int8)instr << 1);
 END_OP


 //
 // BT/S 
 //
 BEGIN_OP_FUDGEIF(BT_S)
	CondRelDelayBranch(GetT(), (uint32)(int8)instr << 1);
 END_OP


 //
 // BRA 
 //
 BEGIN_OP_DLYIDIF(BRA)
	UCRelDelayBranch((uint32)sign_x_to_s32(12, instr) << 1);
 END_OP


 //
 // BRAF Rm
 //
 BEGIN_OP_DLYIDIF(BRAF_REG)
	UCRelDelayBranch(R[instr_nyb2]);
 END_OP


 //
 // BSR 
 //
 BEGIN_OP_DLYIDIF(BSR)
	PR = PC;

	UCRelDelayBranch((uint32)sign_x_to_s32(12, instr) << 1);
 END_OP


 //
 // BSRF Rm
 //
 BEGIN_OP_DLYIDIF(BSRF_REG)
	PR = PC;

	UCRelDelayBranch(R[instr_nyb2]);
 END_OP


 //
 // JMP @Rm
 //
 BEGIN_OP_DLYIDIF(JMP_REGINDIR)
	UCDelayBranch(R[instr_nyb2]);
 END_OP


 //
 // JSR @Rm
 //
 BEGIN_OP_DLYIDIF(JSR_REGINDIR)
	PR = PC;

	UCDelayBranch(R[instr_nyb2]);
 END_OP


 //
 // RTS 
 //
 BEGIN_OP_DLYIDIF(RTS)
	UCDelayBranch(PR);
 END_OP


 //
 // CLRT 
 //
 BEGIN_OP(CLRT)
	SetT(false);
 END_OP


 //
 // CLRMAC 
 //
 BEGIN_OP(CLRMAC)
	MACH = 0;
	MACL = 0;
 END_OP


 //
 // LDC 
 //
 BEGIN_OP_DLYIDIF(LDC)
	{
	 CONST_VAR(unsigned, m) = instr_nyb2;
	 const unsigned cri = (instr >> 4) & 0x3;
#ifdef MDFN_ENABLE_DEV_BUILD
	 const uint32 old_SR = SR;
#endif

	 CtrlRegs[cri] = R[m];
	 if(cri == 0)
	 {
	  SR &= 0x3F3;
#ifdef MDFN_ENABLE_DEV_BUILD
	  if((old_SR ^ SR) & 0xF0)
	   SS_DBGTI(SS_DBG_SH2_EXCEPT, "[%s] LDC IMask; 0x%01x->0x%01x, PC=0x%08x", cpu_name, (old_SR >> 4) & 0xF, (SR >> 4) & 0xF, PC);
#endif
	  RecalcPendingIntPEX();
	 }
	}
	PART_OP_INTDIS
 END_OP

 //
 // LDC.L 
 //
 // Pipeline: page 233
 //
 BEGIN_OP_DLYIDIF(LDC_L)
	{
	 uint32 ea;
#ifdef MDFN_ENABLE_DEV_BUILD
	 //static uint32 old_SR;
	 //old_SR = SR;
	 Resume_new_PC = SR;
#endif
	 ea = R[instr_nyb2];
	 R[instr_nyb2] += 4;

	 timestamp++;
	 MemRead32(ea, CtrlRegs[(instr >> 4) & 0x3]);
	 if(((instr >> 4) & 0x3) == 0)
	 {
	  SR &= 0x3F3;
#ifdef MDFN_ENABLE_DEV_BUILD
	 if((/*old_SR*/Resume_new_PC ^ SR) & 0xF0)
	  SS_DBGTI(SS_DBG_SH2_EXCEPT, "[%s] LDC.L IMask; 0x%01x->0x%01x, PC=0x%08x", cpu_name, (/*old_SR*/Resume_new_PC >> 4) & 0xF, (SR >> 4) & 0xF, PC);
#endif
	  RecalcPendingIntPEX();
	 }

	 timestamp++;
	}
	PART_OP_INTDIS
 END_OP


 //
 // LDS 
 //
 BEGIN_OP_DLYIDIF(LDS)
	{
	 CONST_VAR(unsigned, m) = instr_nyb2;
	 const unsigned sri = (instr >> 4) & 0x3;

	 SysRegs[sri] = R[m];
	}
	PART_OP_INTDIS
 END_OP


 //
 // LDS.L 
 //
 BEGIN_OP_DLYIDIF(LDS_L)	// Pipeline same as ordinary load instruction
	{
	 uint32 ea;

	 ea = R[instr_nyb2];
	 R[instr_nyb2] += 4;

	 MemRead32(ea, SysRegs[(instr >> 4) & 0x3]);
	}
	PART_OP_INTDIS
	//printf(" LDS.L: (0x%08x)->0x%08x\n", ea, SysRegs[sri]);
 END_OP


 //
 // NOP 
 //
 BEGIN_OP(NOP)
 END_OP


 //
 // RTE 
 //
 // Pipeline: page 241
 //
 BEGIN_OP(RTE)
	RESUME_VAR(uint32, opexec_new_PC);
	RESUME_VAR(uint32, opexec_new_SR);

	MemRead32(R[15], opexec_new_PC);
	R[15] += 4;

	MemRead32(R[15], opexec_new_SR)
	R[15] += 4;

#ifdef MDFN_ENABLE_DEV_BUILD
	SS_DBGTI(SS_DBG_SH2_EXCEPT, "[%s] RTE; PC: 0x%08x->0x%08x, SR: 0x%03x->0x%03x", cpu_name, PC, opexec_new_PC, SR, opexec_new_SR & 0x3F3);
#endif

	SR = opexec_new_SR & 0x3F3;
	RecalcPendingIntPEX();

	timestamp++;

	DelayBranch(opexec_new_PC);
 END_OP


 //
 // SETT 
 //
 BEGIN_OP(SETT)
	SetT(true);
 END_OP


 //
 // SLEEP 
 //
 BEGIN_OP_DLYIDIF(SLEEP)
	//
	// Standby mode time yay?
	//
	if(MDFN_UNLIKELY(SBYCR & 0x80))
	{
	 SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Entering standby mode.\n", cpu_name);

	 for(unsigned ch = 0; ch < 2; ch++)
	 {
	  DMACH[ch].CHCR = 0x00;
	  DMACH[ch].CHCRM = 0x00;
	 }
	 DMAOR = 0x00;
	 DMA_RecalcRunning();
	 RecalcPendingIntPEX();
	 //
	 //
	 FRT_Reset();
	 //
	 //
	 WDT_StandbyReset();
	 //
	 //
	 SCI_Reset();
	 //
	 //

	 timestamp++;
	 Pipe_ID = (Pipe_ID & 0x00FFFFFF) | (0x7E << 24);

	 Standby = true;

	 goto SkipPCInc;
	}

	if(MDFN_LIKELY(!EPending))
	{
	 timestamp += 3;
	 goto SkipPCInc;
	}
	else
	{
	 DoID(false);
	 FetchIF();
	}
 END_OP

 BEGIN_OP_DLYIDIF(PSEUDO_STANDBY)
	if(MDFN_LIKELY(Standby))
	{
	 timestamp += 7;
	 goto SkipPCInc;
	}
	else 
	{
	 SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Exiting standby mode.\n", cpu_name);

	 FRT_Reset();	// Reset again(for the counter) because we didn't stop clocking it.

	 DoID(false);
	 FetchIF();
	}
 END_OP

 //
 // STC 
 //
 BEGIN_OP_DLYIDIF(STC)
	{
	 CONST_VAR(unsigned, n) = instr_nyb2;
	 const unsigned cri = (instr >> 4) & 0x3;

	 R[n] = CtrlRegs[cri];
	}
	PART_OP_INTDIS
 END_OP


 //
 // STC.L 
 //
 // pipeline: page 234
 BEGIN_OP_DLYIDIF(STC_L)
	{
	 CONST_VAR(unsigned, n) = instr_nyb2;
	 CONST_VAR(unsigned, cri) = (instr >> 4) & 0x3;
	 uint32 ea;

	 R[n] -= 4;
	 ea = R[n];

	 MemWrite32(ea, CtrlRegs[cri]);
	 timestamp++;
	}
	PART_OP_INTDIS
 END_OP


 //
 // STS 
 //
 BEGIN_OP_DLYIDIF(STS)
	{
	 CONST_VAR(unsigned, n) = instr_nyb2;
	 const unsigned sri = (instr >> 4) & 0x3;

	 R[n] = SysRegs[sri];
	}
	PART_OP_INTDIS
 END_OP


 //
 // STS.L 
 //
 BEGIN_OP_DLYIDIF(STS_L)	// Pipeline same as ordinary store instruction
	{
	 CONST_VAR(unsigned, n) = instr_nyb2;
	 CONST_VAR(unsigned, sri) = (instr >> 4) & 0x3;
	 uint32 ea;

	 R[n] -= 4;
	 ea = R[n];

	 //printf(" STS.L: 0x%08x->(0x%08x)\n", SysRegs[sri], ea);

	 MemWrite32(ea, SysRegs[sri]);
	}
	PART_OP_INTDIS
 END_OP


 //
 // TRAPA #imm
 //
 // Saved PC is the address of the instruction after the TRAPA instruction
 //
 BEGIN_OP_DLYIDIF(TRAPA)
	RESUME_VAR(uint32, opexec_new_PC);

	PC -= 2;
	Exception(EXCEPTION_TRAP, (uint8)instr, opexec_new_PC)
	Branch(false, opexec_new_PC);
 END_OP


 /*
 **
 **
 */
 //
 // Illegal Instruction
 //
 // Saved PC is the address of the illegal instruction.
 //
 BEGIN_OP_DLYIDIF(ILLEGAL)
	RESUME_VAR(uint32, opexec_new_PC);

	PC -= 4;
	Exception(EXCEPTION_ILLINSTR, VECNUM_ILLINSTR, opexec_new_PC);
	Branch(false, opexec_new_PC);
 END_OP

 //
 // Illegal Slot Instruction
 //
 // Saved PC is the effective target address of the jump.
 //
 BEGIN_OP_DLYIDIF(SLOT_ILLEGAL)
	RESUME_VAR(uint32, opexec_new_PC);

	PC -= 2;
	Exception(EXCEPTION_ILLSLOT, VECNUM_ILLSLOT, opexec_new_PC);
	Branch(false, opexec_new_PC);
 END_OP

 //
 // Pending exception(address error/interrupt)
 //
 BEGIN_OP_DLYIDIF(PSEUDO_EPENDING)
	RESUME_VAR(uint32, opexec_new_PC);
	RESUME_VAR(uint8, opexec_exnum);
	RESUME_VAR(uint8, opexec_vecnum);

	opexec_new_PC = 0;

	//
	// Priority here(listed highest to lowest):
	//  External halt
	//   Power
	//    Reset
	//     Pseudo DMA burst(hacky abusey thing to stall the CPU, should be above everything but reset/power and ext halt otherwise kaboom!).
	//      CPU address error
	//       DMA address error
	//        NMI
	//         Interrupt (final else, may be called quasi-spuriously)
	//
	#define TPP(x) (Pipe_ID & (1U << ((x) + EPENDING_PEXBITS_SHIFT)))
	//
	// Test against Pipe_ID, reset bits in EPending(if appropriate).
	//
	if(MDFN_UNLIKELY(TPP(PEX_PSEUDO_EXTHALT)))
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Ext halt begin: Pipe_ID=0x%08x PC=0x%08x\n", cpu_name, Pipe_ID, PC);
	 Pipe_ID = (Pipe_ID & 0x00FFFFFF) | (0xFE << 24);
	 goto SkipPCInc;
	}
	else if(MDFN_UNLIKELY(TPP(PEX_POWERON) || TPP(PEX_RESET)))
	{
	 EPending = 0;
	 opexec_exnum = EXCEPTION_POWERON;
	 opexec_vecnum = VECNUM_POWERON;

	 if(TPP(PEX_RESET))
	 {
	  opexec_exnum = EXCEPTION_RESET;
	  opexec_vecnum = VECNUM_RESET;
	 }

	 Exception_ResPow(opexec_exnum, opexec_vecnum, opexec_new_PC);
	}
	else if(MDFN_UNLIKELY(TPP(PEX_PSEUDO_DMABURST)))
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Burst begin: Pipe_ID=0x%08x PC=0x%08x\n", cpu_name, Pipe_ID, PC);
	 Pipe_ID = (Pipe_ID & 0x00FFFFFF) | (0xFE << 24);
	 goto SkipPCInc;
	}
	else if(MDFN_UNLIKELY(TPP(PEX_CPUADDR)))
	{
	 PC -= 4;
	 ClearPEX(PEX_CPUADDR);
	 Exception(EXCEPTION_CPUADDR, VECNUM_CPUADDR, opexec_new_PC);
	 ClearPEX(PEX_CPUADDR);	// Infinite recursive address errors are not good(stack wraparound could clobber backup memory).
	}
	else if(MDFN_UNLIKELY(TPP(PEX_DMAADDR)))
	{
	 PC -= 4;
	 ClearPEX(PEX_DMAADDR);
	 Exception(EXCEPTION_DMAADDR, VECNUM_DMAADDR, opexec_new_PC);
	}
	else if(TPP(PEX_NMI))
	{
	 PC -= 4;
	 ClearPEX(PEX_NMI);
	 Exception(EXCEPTION_NMI, VECNUM_NMI, opexec_new_PC);
	 //
	 //
	 //
	 SR |= 0xF << 4;
	 RecalcPendingIntPEX();
	}
	else	// Int
	{
	 RESUME_VAR(uint8, opexec_ipr);

	 opexec_ipr = GetPendingInt(NULL);

	 if(MDFN_LIKELY(opexec_ipr > ((SR >> 4) & 0xF)))
	 {
	  // Note: GetPendingInt() may call ExIVecFetch(), which may call SetIRL with a new value, so be
	  // careful to use the "old" value here.
	  GetPendingInt(&opexec_vecnum);

	  PC -= 4;
	  Exception(EXCEPTION_INT, opexec_vecnum, opexec_new_PC);
	  //
	  //
	  //
	  SR &= ~(0xF << 4);
	  SR |= opexec_ipr << 4;
	  RecalcPendingIntPEX();
	 }
	 else
	 {
	  // 
	  // Can happen like so(note for future testing):
	  //
	  // (WDT interval timer IRQ pending here)
	  //
	  // WTCSR_R;
	  // asm volatile(
	  //	"ldc %0,SR\n\t"
	  //	"mov.w %2, @%1\n\t"
	  //	:
	  //	:"r"(0), "r"(0xFFFFFE88), "r"(0xA500 | 0x00)
	  // 	: "memory");
	  //
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2 | SS_DBG_SH2_EXCEPT, "[%s] Spurious EPENDING. IPR=0x%02x SR=0x%04x EPending=0x%08x Pipe_ID=0x%08x PC=0x%08x\n", cpu_name, opexec_ipr, SR, EPending, Pipe_ID, PC);

	  Pipe_ID = (uint16)Pipe_ID;
	  Pipe_ID |= InstrDecodeTab[Pipe_ID] << 24;
	  goto SPEPRecover;
	 }
	}
	#undef TPP
	//
	//
	//
	Branch(false, opexec_new_PC);
 END_OP

 BEGIN_OP_DLYIDIF(PSEUDO_DMABURST)
#ifdef SH7095_NEED_RESUME_TABLE_INIT
	if(MDFN_UNLIKELY(!ResumeTableP[DebugMode]))
	{
	 static_assert(__COUNTER__ == ((DebugMode ? 10000 : 5000) + 393), "Unexpected __COUNTER__");

	 static const void* const ResumeTable[512] =
	 {
#if SH7095_DEBUG_MODE
	  #include "sh7095s_ctable_dm.inc"
#else
	  #include "sh7095s_ctable.inc"
#endif
	 };
	 //static_assert(__COUNTER__ <= 11025, "Unexpected __COUNTER__");

	 assert(this == &CPU[1]);

         ResumeTableP[DebugMode] = ResumeTable;
	 return;
	}
#endif
	if(MDFN_LIKELY(DMA_InBurst() || ExtHalt))
	{
	 timestamp += 7;
	 goto SkipPCInc;
	}
	else
	{
	 ClearPEX(PEX_PSEUDO_DMABURST);
	 ClearPEX(PEX_PSEUDO_EXTHALT);

	 //
	 // Recover Pipe_ID opcode field; only use Pipe_ID for this, not EPending, otherwise
	 // we may accidentally allow an interrupt to occur immediately after an interrupt-disabled instruction.
	 //
	 Pipe_ID &= 0x00FFFFFF;
	 Pipe_ID &= ~(1U << (PEX_PSEUDO_DMABURST + EPENDING_PEXBITS_SHIFT));
	 Pipe_ID &= ~(1U << (PEX_PSEUDO_EXTHALT + EPENDING_PEXBITS_SHIFT));
	 Pipe_ID |= InstrDecodeTab[(uint16)Pipe_ID] << 24;
	 if(Pipe_ID & (0xFF << EPENDING_PEXBITS_SHIFT))
	  Pipe_ID |= EPENDING_OP_OR;

	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Burst/External halt end: Pipe_ID=0x%08x PC=0x%08x\n", cpu_name, Pipe_ID, PC);
	 goto SkipPCInc;
	}
 END_OP
}

PC += 2;
SkipPCInc:;

#ifdef SH7095_NEED_RESUME_TABLE_INIT
static_assert(__COUNTER__ == ((DebugMode ? 10000 : 5000) + 393 + 512 + 1), "Unexpected __COUNTER__");
#endif

#undef PART_OP_NORMIDIF
#undef BEGIN_OP
#undef BEGIN_OP_FUDGEIF
#undef BEGIN_OP_DLYIDIF
#undef PART_OP_INTDIS
#undef END_OP
#undef WB_EX_CHECK
#undef WB_WRITE
#undef WB_READ8
#undef WB_READ16
#undef WB_READ32
#undef WB_READ16_I
#undef WB_READ32_I

