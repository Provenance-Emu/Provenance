OP(op_aaa,MA_1(0x37),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_aad,MA_1(0xd5),enc_param_none,enc_imm_8,1,pg_NONE,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_aad,MA_2(0xd5,0xa),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_aam,MA_1(0xd4),enc_param_none,enc_imm_8,1,pg_NONE,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_aam,MA_2(0xd4,0xa),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_aas,MA_1(0x3f),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_adc16,MA_1(0x83),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_adc16,MA_1(0x15),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_adc16,MA_1(0x81),enc_param_slash_2,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_adc16,MA_1(0x11),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_adc16,MA_1(0x13),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_adc32,MA_1(0x83),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_adc32,MA_1(0x15),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_adc32,MA_1(0x81),enc_param_slash_2,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_adc32,MA_1(0x11),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_adc32,MA_1(0x13),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_adc8,MA_1(0x14),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_adc8,MA_1(0x80),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_adc8,MA_1(0x10),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_adc8,MA_1(0x12),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_add16,MA_1(0x83),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_add16,MA_1(0x5),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_add16,MA_1(0x81),enc_param_slash_0,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_add16,MA_1(0x1),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_add16,MA_1(0x3),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_add32,MA_1(0x83),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_add32,MA_1(0x5),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_add32,MA_1(0x81),enc_param_slash_0,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_add32,MA_1(0x1),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_add32,MA_1(0x3),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_add8,MA_1(0x4),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_add8,MA_1(0x80),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_add8,MA_1(0x0),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_add8,MA_1(0x2),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_addpd,MA_3(0x66,0xf,0x58),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_addps,MA_2(0xf,0x58),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_addsd,MA_3(0xf2,0xf,0x58),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_addss,MA_3(0xf3,0xf,0x58),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_addsubpd,MA_3(0x66,0xf,0xd0),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_addsubps,MA_3(0xf2,0xf,0xd0),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_and16,MA_1(0x83),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_and16,MA_1(0x25),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_and16,MA_1(0x81),enc_param_slash_4,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_and16,MA_1(0x21),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_and16,MA_1(0x23),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_and32,MA_1(0x83),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_and32,MA_1(0x25),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_and32,MA_1(0x81),enc_param_slash_4,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_and32,MA_1(0x21),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_and32,MA_1(0x23),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_and8,MA_1(0x24),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_and8,MA_1(0x80),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_and8,MA_1(0x20),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_and8,MA_1(0x22),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_andnpd,MA_3(0x66,0xf,0x55),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_andnps,MA_2(0xf,0x55),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_andpd,MA_3(0x66,0xf,0x54),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_andps,MA_2(0xf,0x54),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_arpl,MA_1(0x63),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_bsf16,MA_2(0xf,0xbc),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_bsf32,MA_2(0xf,0xbc),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_bsr16,MA_2(0xf,0xbd),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_bsr32,MA_2(0xf,0xbd),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_bswap,MA_2(0xf,0xc8),enc_param_plus_r,enc_imm_none,2,pg_REG,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_bt16,MA_2(0xf,0xba),enc_param_slash_4,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
OP(op_bt16,MA_2(0xf,0xa3),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_bt32,MA_2(0xf,0xba),enc_param_slash_4,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_bt32,MA_2(0xf,0xa3),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_btc16,MA_2(0xf,0xbb),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_btc16,MA_2(0xf,0xba),enc_param_slash_7,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_btc32,MA_2(0xf,0xbb),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_btc32,MA_2(0xf,0xba),enc_param_slash_7,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_btr16,MA_2(0xf,0xba),enc_param_slash_6,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
OP(op_btr16,MA_2(0xf,0xb3),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_btr32,MA_2(0xf,0xba),enc_param_slash_6,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_btr32,MA_2(0xf,0xb3),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_bts16,MA_2(0xf,0xba),enc_param_slash_5,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
OP(op_bts16,MA_2(0xf,0xab),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_bts32,MA_2(0xf,0xba),enc_param_slash_5,enc_imm_8,2,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_bts32,MA_2(0xf,0xab),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_call,MA_1(0xe8),enc_param_memrel_32,enc_imm_none,1,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_call32,MA_1(0xff),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cbw,MA_1(0x98),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cdq,MA_1(0x99),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_clc,MA_1(0xf8),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cld,MA_1(0xfc),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_clflush,MA_2(0xf,0xae),enc_param_slash_7,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_cmc,MA_1(0xf5),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmova16,MA_2(0xf,0x47),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmova32,MA_2(0xf,0x47),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovae16,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovae32,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovb16,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovb32,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovbe16,MA_2(0xf,0x46),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovbe32,MA_2(0xf,0x46),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovc16,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovc32,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmove16,MA_2(0xf,0x44),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmove32,MA_2(0xf,0x44),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovg16,MA_2(0xf,0x4f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovg32,MA_2(0xf,0x4f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovge16,MA_2(0xf,0x4d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovge32,MA_2(0xf,0x4d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovl16,MA_2(0xf,0x4c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovl32,MA_2(0xf,0x4c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovle16,MA_2(0xf,0x4e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovle32,MA_2(0xf,0x4e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovna16,MA_2(0xf,0x46),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovna32,MA_2(0xf,0x46),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnae16,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnae32,MA_2(0xf,0x42),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnb16,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnb32,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnbe16,MA_2(0xf,0x47),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnbe32,MA_2(0xf,0x47),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnc16,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnc32,MA_2(0xf,0x43),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovne16,MA_2(0xf,0x45),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovne32,MA_2(0xf,0x45),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovng16,MA_2(0xf,0x4e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovng32,MA_2(0xf,0x4e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnge16,MA_2(0xf,0x4c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnge32,MA_2(0xf,0x4c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnl16,MA_2(0xf,0x4d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnl32,MA_2(0xf,0x4d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnle16,MA_2(0xf,0x4f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnle32,MA_2(0xf,0x4f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovno16,MA_2(0xf,0x41),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovno32,MA_2(0xf,0x41),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnp16,MA_2(0xf,0x4b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnp32,MA_2(0xf,0x4b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovns16,MA_2(0xf,0x49),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovns32,MA_2(0xf,0x49),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovnz16,MA_2(0xf,0x45),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovnz32,MA_2(0xf,0x45),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovo16,MA_2(0xf,0x40),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovo32,MA_2(0xf,0x40),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovp16,MA_2(0xf,0x4a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovp32,MA_2(0xf,0x4a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovpe16,MA_2(0xf,0x4a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovpe32,MA_2(0xf,0x4a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovpo16,MA_2(0xf,0x4b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovpo32,MA_2(0xf,0x4b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovs16,MA_2(0xf,0x48),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovs32,MA_2(0xf,0x48),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmovz16,MA_2(0xf,0x44),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmovz32,MA_2(0xf,0x44),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmp16,MA_1(0x83),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_cmp16,MA_1(0x3d),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_cmp16,MA_1(0x81),enc_param_slash_7,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_cmp16,MA_1(0x39),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_cmp16,MA_1(0x3b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmp32,MA_1(0x83),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_cmp32,MA_1(0x3d),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_cmp32,MA_1(0x81),enc_param_slash_7,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_cmp32,MA_1(0x39),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_cmp32,MA_1(0x3b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmp8,MA_1(0x3c),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_cmp8,MA_1(0x80),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_cmp8,MA_1(0x38),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_cmp8,MA_1(0x3a),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_cmpeqpd,MA_4(0x66,0xf,0xc2,0x0),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpeqps,MA_3(0xf,0xc2,0x0),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpeqsd,MA_4(0xf2,0xf,0xc2,0x0),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpeqss,MA_4(0xf3,0xf,0xc2,0x0),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmplepd,MA_4(0x66,0xf,0xc2,0x2),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpleps,MA_3(0xf,0xc2,0x2),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmplesd,MA_4(0xf2,0xf,0xc2,0x2),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpless,MA_4(0xf3,0xf,0xc2,0x2),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpltpd,MA_4(0x66,0xf,0xc2,0x1),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpltps,MA_3(0xf,0xc2,0x1),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpltsd,MA_4(0xf2,0xf,0xc2,0x1),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpltss,MA_4(0xf3,0xf,0xc2,0x1),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpneqpd,MA_4(0x66,0xf,0xc2,0x4),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpneqps,MA_3(0xf,0xc2,0x4),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpneqsd,MA_4(0xf2,0xf,0xc2,0x4),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpneqss,MA_4(0xf3,0xf,0xc2,0x4),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnlepd,MA_4(0x66,0xf,0xc2,0x6),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnleps,MA_3(0xf,0xc2,0x6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnlesd,MA_4(0xf2,0xf,0xc2,0x6),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnless,MA_4(0xf3,0xf,0xc2,0x6),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnltpd,MA_4(0x66,0xf,0xc2,0x5),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnltps,MA_3(0xf,0xc2,0x5),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnltsd,MA_4(0xf2,0xf,0xc2,0x5),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpnltss,MA_4(0xf3,0xf,0xc2,0x5),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpordpd,MA_4(0x66,0xf,0xc2,0x7),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpordps,MA_3(0xf,0xc2,0x7),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpordsd,MA_4(0xf2,0xf,0xc2,0x7),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpordss,MA_4(0xf3,0xf,0xc2,0x7),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmppd,MA_3(0x66,0xf,0xc2),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_cmpps,MA_2(0xf,0xc2),enc_param_slash_r,enc_imm_8,2,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_cmpsb,MA_1(0xa6),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpsd,MA_3(0xf2,0xf,0xc2),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
OP(op_cmpsd,MA_1(0xa7),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpss,MA_3(0xf3,0xf,0xc2),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_cmpsw,MA_1(0xa7),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpunordpd,MA_4(0x66,0xf,0xc2,0x3),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpunordps,MA_3(0xf,0xc2,0x3),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpunordsd,MA_4(0xf2,0xf,0xc2,0x3),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpunordss,MA_4(0xf3,0xf,0xc2,0x3),enc_param_slash_r,enc_imm_none,4,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpxchg8,MA_2(0xf,0xb0),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_8),
s_LIST_END,

OP(op_cmpxchg16,MA_2(0xf,0xb1),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_cmpxchg32,MA_2(0xf,0xb1),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cmpxchg8b,MA_2(0xf,0xc7),enc_param_slash_1,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_comisd,MA_3(0x66,0xf,0x2f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_comiss,MA_2(0xf,0x2f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cpuid,MA_2(0xf,0xa2),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtdq2pd,MA_3(0xf3,0xf,0xe6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtdq2ps,MA_2(0xf,0x5b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtpd2dq,MA_3(0xf2,0xf,0xe6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtpd2pi,MA_3(0x66,0xf,0x2d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtpd2ps,MA_3(0x66,0xf,0x5a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtpi2pd,MA_3(0x66,0xf,0x2a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtpi2ps,MA_2(0xf,0x2a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtps2dq,MA_3(0x66,0xf,0x5b),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtps2pd,MA_2(0xf,0x5a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtps2pi,MA_2(0xf,0x2d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtsd2si,MA_3(0xf2,0xf,0x2d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtsd2ss,MA_3(0xf2,0xf,0x5a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtsi2sd,MA_3(0xf2,0xf,0x2a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtsi2ss,MA_3(0xf3,0xf,0x2a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtss2sd,MA_3(0xf3,0xf,0x5a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvtss2si,MA_3(0xf3,0xf,0x2d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttpd2dq,MA_3(0x66,0xf,0xe6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttpd2pi,MA_3(0x66,0xf,0x2c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttps2dq,MA_3(0xf3,0xf,0x5b),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttps2pi,MA_2(0xf,0x2c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttsd2si,MA_3(0xf2,0xf,0x2c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cvttss2si,MA_3(0xf3,0xf,0x2c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cwd,MA_1(0x99),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_cwde,MA_1(0x98),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_daa,MA_1(0x27),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_das,MA_1(0x2f),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_dec16,MA_1(0xff),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_dec16,MA_1(0x48),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_dec32,MA_1(0xff),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_dec32,MA_1(0x48),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_dec8,MA_1(0xfe),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_div8,MA_1(0xf6),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_div16,MA_1(0xf7),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_div32,MA_1(0xf7),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_divpd,MA_3(0x66,0xf,0x5e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_divps,MA_2(0xf,0x5e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_divsd,MA_3(0xf2,0xf,0x5e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_divss,MA_3(0xf3,0xf,0x5e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_emms,MA_2(0xf,0x77),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_enter,MA_1(0xc8),enc_param_none,enc_imm_8,1,pg_IMM_U16,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_f2xm1,MA_2(0xd9,0xf0),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fabs,MA_2(0xd9,0xe1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fadd32f,MA_1(0xd8),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fadd64f,MA_1(0xdc),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_faddp,MA_2(0xde,0xc1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fchs,MA_2(0xd9,0xe0),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fclex,MA_3(0x9b,0xdb,0xe2),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcom32f,MA_1(0xd8),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcom,MA_2(0xd8,0xd1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcom64f,MA_1(0xdc),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcomp32f,MA_1(0xd8),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcomp,MA_2(0xd8,0xd9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcomp64f,MA_1(0xdc),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcompp,MA_2(0xde,0xd9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fcos,MA_2(0xd9,0xff),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdecstp,MA_2(0xd9,0xf6),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdiv32f,MA_1(0xd8),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdiv64f,MA_1(0xdc),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdivp,MA_2(0xde,0xf9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdivr32f,MA_1(0xd8),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdivr64f,MA_1(0xdc),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fdivrp,MA_2(0xde,0xf1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fiadd32i,MA_1(0xda),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fiadd16i,MA_1(0xde),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_ficom32i,MA_1(0xda),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ficom16i,MA_1(0xde),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_ficomp32i,MA_1(0xda),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ficomp16i,MA_1(0xde),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fidiv32i,MA_1(0xda),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fidiv16i,MA_1(0xde),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fidivr32i,MA_1(0xda),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fidivr16i,MA_1(0xde),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fild32i,MA_1(0xdb),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fild16i,MA_1(0xdf),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fild64i,MA_1(0xdf),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fimul32i,MA_1(0xda),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fimul16i,MA_1(0xde),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fincstp,MA_2(0xd9,0xf7),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_finit,MA_3(0x9b,0xdb,0xe3),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fist32i,MA_1(0xdb),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fist16i,MA_1(0xdf),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fistp32i,MA_1(0xdb),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fistp16i,MA_1(0xdf),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fistp64i,MA_1(0xdf),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fisttp32i,MA_1(0xdb),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fisttp64i,MA_1(0xdd),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fisttp16i,MA_1(0xdf),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fisub32i,MA_1(0xda),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fisub16i,MA_1(0xde),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fisubr32i,MA_1(0xda),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fisubr16i,MA_1(0xde),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fld32f,MA_1(0xd9),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fld64f,MA_1(0xdd),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fld1,MA_2(0xd9,0xe8),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldl2e,MA_2(0xd9,0xea),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldl2t,MA_2(0xd9,0xe9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldlg2,MA_2(0xd9,0xec),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldln2,MA_2(0xd9,0xed),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldpi,MA_2(0xd9,0xeb),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fldz,MA_2(0xd9,0xee),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fmul32f,MA_1(0xd8),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fmul64f,MA_1(0xdc),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fmulp,MA_2(0xde,0xc9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fnclex,MA_2(0xdb,0xe2),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fninit,MA_2(0xdb,0xe3),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fnop,MA_2(0xd9,0xd0),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fnstsw,MA_2(0xdf,0xe0),enc_param_none,enc_imm_none,2,pg_R0,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fpatan,MA_2(0xd9,0xf3),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fprem,MA_2(0xd9,0xf8),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fprem1,MA_2(0xd9,0xf5),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fptan,MA_2(0xd9,0xf2),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_frndint,MA_2(0xd9,0xfc),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fscale,MA_2(0xd9,0xfd),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsin,MA_2(0xd9,0xfe),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsincos,MA_2(0xd9,0xfb),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsqrt,MA_2(0xd9,0xfa),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fst32f,MA_1(0xd9),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fst64f,MA_1(0xdd),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fstp32f,MA_1(0xd9),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fstp64f,MA_1(0xdd),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fstsw,MA_3(0x9b,0xdf,0xe0),enc_param_none,enc_imm_none,3,pg_R0,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_fsub32f,MA_1(0xd8),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsub64f,MA_1(0xdc),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsubp,MA_2(0xde,0xe9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsubr32f,MA_1(0xd8),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsubr64f,MA_1(0xdc),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fsubrp,MA_2(0xde,0xe1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ftst,MA_2(0xd9,0xe4),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fucom,MA_2(0xdd,0xe1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fucomp,MA_2(0xdd,0xe9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fucompp,MA_2(0xda,0xe9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fwait,MA_1(0x9b),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fxam,MA_2(0xd9,0xe5),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fxch,MA_2(0xd9,0xc9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fxtract,MA_2(0xd9,0xf4),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fyl2x,MA_2(0xd9,0xf1),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_fyl2xp1,MA_2(0xd9,0xf9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_haddpd,MA_3(0x66,0xf,0x7c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_haddps,MA_3(0xf2,0xf,0x7c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_hlt,MA_1(0xf4),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_hsubpd,MA_3(0x66,0xf,0x7d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_hsubps,MA_3(0xf2,0xf,0x7d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_idiv8,MA_1(0xf6),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_idiv16,MA_1(0xf7),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_idiv32,MA_1(0xf7),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_imul32,MA_1(0x6b),enc_param_slash_r,enc_imm_8,1,pg_REG,pg_ModRM,pg_IMM_S8,opsz_32),
OP(op_imul32,MA_1(0x6b),enc_param_slash_r,enc_imm_8,1,pg_REG,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_imul32,MA_1(0x69),enc_param_slash_r,enc_imm_32,1,pg_REG,pg_ModRM,pg_IMM_U32,opsz_32),
OP(op_imul32,MA_1(0x69),enc_param_slash_r,enc_imm_32,1,pg_REG,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_imul32,MA_1(0xf7),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_imul32,MA_2(0xf,0xaf),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_imul16,MA_1(0x6b),enc_param_slash_r,enc_imm_8,1,pg_REG,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_imul16,MA_1(0x6b),enc_param_slash_r,enc_imm_8,1,pg_REG,pg_ModRM,pg_IMM_S8,opsz_16),
OP(op_imul16,MA_1(0xf7),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_imul16,MA_2(0xf,0xaf),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
OP(op_imul16,MA_1(0x69),enc_param_slash_r,enc_imm_16,1,pg_REG,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_imul16,MA_1(0x69),enc_param_slash_r,enc_imm_16,1,pg_REG,pg_ModRM,pg_IMM_U16,opsz_16),
s_LIST_END,

OP(op_imul8,MA_1(0xf6),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_inc16,MA_1(0xff),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_inc16,MA_1(0x40),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_inc32,MA_1(0xff),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_inc32,MA_1(0x40),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_inc8,MA_1(0xfe),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_insb,MA_1(0x6c),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_insd,MA_1(0x6d),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_insw,MA_1(0x6d),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_int3,MA_1(0xcc),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_int,MA_1(0xcd),enc_param_none,enc_imm_8,1,pg_NONE,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_into,MA_1(0xce),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_invd,MA_2(0xf,0x8),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_invlpg,MA_2(0xf,0x1),enc_param_slash_7,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_iret,MA_1(0xcf),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_iretd,MA_1(0xcf),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ja,MA_1(0x77),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_ja,MA_2(0xf,0x87),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jae,MA_1(0x73),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jae,MA_2(0xf,0x83),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jb,MA_1(0x72),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jb,MA_2(0xf,0x82),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jbe,MA_1(0x76),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jbe,MA_2(0xf,0x86),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jc,MA_1(0x72),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jc,MA_2(0xf,0x82),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jcxz,MA_1(0xe3),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_je,MA_1(0x74),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_je,MA_2(0xf,0x84),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jecxz,MA_1(0xe3),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_jg,MA_1(0x7f),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jg,MA_2(0xf,0x8f),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jge,MA_1(0x7d),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jge,MA_2(0xf,0x8d),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jl,MA_1(0x7c),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jl,MA_2(0xf,0x8c),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jle,MA_1(0x7e),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jle,MA_2(0xf,0x8e),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jmp,MA_1(0xeb),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jmp,MA_1(0xe9),enc_param_memrel_32,enc_imm_none,1,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jmp32,MA_1(0xff),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jna,MA_1(0x76),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jna,MA_2(0xf,0x86),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnae,MA_1(0x72),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnae,MA_2(0xf,0x82),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnb,MA_1(0x73),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnb,MA_2(0xf,0x83),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnbe,MA_1(0x77),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnbe,MA_2(0xf,0x87),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnc,MA_1(0x73),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnc,MA_2(0xf,0x83),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jne,MA_1(0x75),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jne,MA_2(0xf,0x85),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jng,MA_1(0x7e),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jng,MA_2(0xf,0x8e),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnge,MA_1(0x7c),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnge,MA_2(0xf,0x8c),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnl,MA_1(0x7d),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnl,MA_2(0xf,0x8d),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnle,MA_1(0x7f),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnle,MA_2(0xf,0x8f),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jno,MA_1(0x71),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jno,MA_2(0xf,0x81),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnp,MA_1(0x7b),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnp,MA_2(0xf,0x8b),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jns,MA_1(0x79),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jns,MA_2(0xf,0x89),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jnz,MA_1(0x75),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jnz,MA_2(0xf,0x85),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jo,MA_1(0x70),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jo,MA_2(0xf,0x80),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jp,MA_1(0x7a),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jp,MA_2(0xf,0x8a),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jpe,MA_1(0x7a),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jpe,MA_2(0xf,0x8a),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jpo,MA_1(0x7b),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jpo,MA_2(0xf,0x8b),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_js,MA_1(0x78),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_js,MA_2(0xf,0x88),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_jz,MA_1(0x74),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
OP(op_jz,MA_2(0xf,0x84),enc_param_memrel_32,enc_imm_none,2,pg_MEM_Rel32,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lahf,MA_1(0x9f),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lar16,MA_2(0xf,0x2),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_lar32,MA_2(0xf,0x2),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lddqu,MA_3(0xf2,0xf,0xf0),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ldmxcsr,MA_2(0xf,0xae),enc_param_slash_2,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lea16,MA_1(0x8d),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_lea32,MA_1(0x8d),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_leave,MA_1(0xc9),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lfence,MA_3(0xf,0xae,0xe8),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lldt,MA_2(0xf,0x0),enc_param_slash_2,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_lmsw,MA_2(0xf,0x1),enc_param_slash_6,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_lock,MA_1(0xf0),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lodsb,MA_1(0xac),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lodsd,MA_1(0xad),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_lodsw,MA_1(0xad),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_loop,MA_1(0xe2),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_loope,MA_1(0xe1),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_loopne,MA_1(0xe0),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_loopnz,MA_1(0xe0),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_loopz,MA_1(0xe1),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_maskmovdqu,MA_3(0x66,0xf,0xf7),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_maskmovq,MA_2(0xf,0xf7),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_maxpd,MA_3(0x66,0xf,0x5f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_maxps,MA_2(0xf,0x5f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_maxsd,MA_3(0xf2,0xf,0x5f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_maxss,MA_3(0xf3,0xf,0x5f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mfence,MA_3(0xf,0xae,0xf0),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_minpd,MA_3(0x66,0xf,0x5d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_minps,MA_2(0xf,0x5d),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_minsd,MA_3(0xf2,0xf,0x5d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_minss,MA_3(0xf3,0xf,0x5d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_monitor,MA_3(0xf,0x1,0xc8),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mov8,MA_1(0xa2),enc_param_memrel_8,enc_imm_none,1,pg_MEM_Rel8,pg_R0,pg_NONE,opsz_8),
OP(op_mov8,MA_1(0xb0),enc_param_plus_r,enc_imm_8,1,pg_REG,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_mov8,MA_1(0xc6),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_mov8,MA_1(0x88),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_mov8,MA_1(0x8a),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
OP(op_mov8,MA_1(0xa0),enc_param_memrel_8,enc_imm_none,1,pg_R0,pg_MEM_Rel8,pg_NONE,opsz_8),
s_LIST_END,

OP(op_mov16,MA_1(0xb8),enc_param_plus_r,enc_imm_16,1,pg_REG,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_mov16,MA_1(0xc7),enc_param_slash_0,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_mov16,MA_1(0x89),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_mov16,MA_1(0x8b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_mov32,MA_1(0xb8),enc_param_plus_r,enc_imm_32,1,pg_REG,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_mov32,MA_1(0xc7),enc_param_slash_0,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_mov32,MA_1(0xa3),enc_param_memrel_32,enc_imm_none,1,pg_MEM_Rel32,pg_R0,pg_NONE,opsz_32),
OP(op_mov32,MA_1(0x89),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_mov32,MA_1(0x8b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_mov32,MA_1(0xa1),enc_param_memrel_32,enc_imm_none,1,pg_R0,pg_MEM_Rel32,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movapd,MA_3(0x66,0xf,0x29),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movapd,MA_3(0x66,0xf,0x28),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movaps,MA_2(0xf,0x29),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movaps,MA_2(0xf,0x28),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movd_mmx_from_r32,MA_2(0xf,0x6e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movd_mmx_to_r32,MA_2(0xf,0x7e),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movd_xmm_from_r32,MA_3(0x66,0xf,0x6e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movd_xmm_to_r32,MA_3(0x66,0xf,0x7e),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movddup,MA_3(0xf2,0xf,0x12),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movdq2q,MA_3(0xf2,0xf,0xd6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movdqa,MA_3(0x66,0xf,0x7f),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movdqa,MA_3(0x66,0xf,0x6f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movdqu,MA_3(0xf3,0xf,0x7f),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movdqu,MA_3(0xf3,0xf,0x6f),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movhlps,MA_2(0xf,0x12),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movhpd,MA_3(0x66,0xf,0x17),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movhpd,MA_3(0x66,0xf,0x16),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movhps,MA_2(0xf,0x17),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movhps,MA_2(0xf,0x16),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movlhps,MA_2(0xf,0x16),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movlpd,MA_3(0x66,0xf,0x13),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movlpd,MA_3(0x66,0xf,0x12),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movlps,MA_2(0xf,0x13),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movlps,MA_2(0xf,0x12),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movmskpd,MA_3(0x66,0xf,0x50),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movmskps,MA_2(0xf,0x50),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movntdq,MA_3(0x66,0xf,0xe7),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movnti,MA_2(0xf,0xc3),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movntpd,MA_3(0x66,0xf,0x2b),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movntps,MA_2(0xf,0x2b),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movntq,MA_2(0xf,0xe7),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movq,MA_3(0x66,0xf,0xd6),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movq,MA_3(0xf3,0xf,0x7e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_movq,MA_2(0xf,0x6f),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_movq,MA_2(0xf,0x7f),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movq2dq,MA_3(0xf3,0xf,0xd6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsb,MA_1(0xa4),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsd,MA_3(0xf2,0xf,0x11),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movsd,MA_3(0xf2,0xf,0x10),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_movsd,MA_1(0xa5),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movshdup,MA_3(0xf3,0xf,0x16),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsldup,MA_3(0xf3,0xf,0x12),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movss,MA_3(0xf3,0xf,0x11),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movss,MA_3(0xf3,0xf,0x10),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsw,MA_1(0xa5),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsx8to16,MA_2(0xf,0xbe),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_movsx8to32,MA_2(0xf,0xbe),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movsx16to32,MA_2(0xf,0xbf),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movupd,MA_3(0x66,0xf,0x11),enc_param_slash_r_rev,enc_imm_none,3,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movupd,MA_3(0x66,0xf,0x10),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movups,MA_2(0xf,0x11),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_movups,MA_2(0xf,0x10),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movzx8to16,MA_2(0xf,0xb6),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_movzx8to32,MA_2(0xf,0xb6),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_movzx16to32,MA_2(0xf,0xb7),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mul8,MA_1(0xf6),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_mul16,MA_1(0xf7),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_mul32,MA_1(0xf7),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mulpd,MA_3(0x66,0xf,0x59),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mulps,MA_2(0xf,0x59),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mulsd,MA_3(0xf2,0xf,0x59),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mulss,MA_3(0xf3,0xf,0x59),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_mwait,MA_3(0xf,0x1,0xc9),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_neg8,MA_1(0xf6),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_neg16,MA_1(0xf7),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_neg32,MA_1(0xf7),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_nop,MA_1(0x90),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_not8,MA_1(0xf6),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_not16,MA_1(0xf7),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_not32,MA_1(0xf7),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_or16,MA_1(0x83),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_or16,MA_1(0xd),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_or16,MA_1(0x81),enc_param_slash_1,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_or16,MA_1(0x9),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_or16,MA_1(0xb),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_or32,MA_1(0x83),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_or32,MA_1(0xd),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_or32,MA_1(0x81),enc_param_slash_1,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_or32,MA_1(0x9),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_or32,MA_1(0xb),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_or8,MA_1(0xc),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_or8,MA_1(0x80),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_or8,MA_1(0x8),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_or8,MA_1(0xa),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_orpd,MA_3(0x66,0xf,0x56),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_orps,MA_2(0xf,0x56),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_outsb,MA_1(0x6e),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_outsd,MA_1(0x6f),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_outsw,MA_1(0x6f),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_packssdw,MA_3(0x66,0xf,0x6b),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_packssdw,MA_2(0xf,0x6b),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_packsswb,MA_3(0x66,0xf,0x63),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_packsswb,MA_2(0xf,0x63),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_packuswb,MA_3(0x66,0xf,0x67),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_packuswb,MA_2(0xf,0x67),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddb,MA_3(0x66,0xf,0xfc),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddb,MA_2(0xf,0xfc),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddd,MA_3(0x66,0xf,0xfe),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddd,MA_2(0xf,0xfe),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddq,MA_3(0x66,0xf,0xd4),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddq,MA_2(0xf,0xd4),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddsb,MA_3(0x66,0xf,0xec),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddsb,MA_2(0xf,0xec),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddsw,MA_3(0x66,0xf,0xed),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddsw,MA_2(0xf,0xed),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddusb,MA_3(0x66,0xf,0xdc),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddusb,MA_2(0xf,0xdc),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddusw,MA_3(0x66,0xf,0xdd),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddusw,MA_2(0xf,0xdd),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_paddw,MA_3(0x66,0xf,0xfd),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_paddw,MA_2(0xf,0xfd),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pand,MA_3(0x66,0xf,0xdb),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pand,MA_2(0xf,0xdb),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pandn,MA_3(0x66,0xf,0xdf),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pandn,MA_2(0xf,0xdf),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pause,MA_2(0xf3,0x90),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pavgb,MA_3(0x66,0xf,0xe0),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pavgb,MA_2(0xf,0xe0),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pavgw,MA_3(0x66,0xf,0xe3),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pavgw,MA_2(0xf,0xe3),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpeqb,MA_3(0x66,0xf,0x74),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpeqb,MA_2(0xf,0x74),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpeqd,MA_3(0x66,0xf,0x76),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpeqd,MA_2(0xf,0x76),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpeqw,MA_3(0x66,0xf,0x75),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpeqw,MA_2(0xf,0x75),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpgtb,MA_3(0x66,0xf,0x64),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpgtb,MA_2(0xf,0x64),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpgtd,MA_3(0x66,0xf,0x66),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpgtd,MA_2(0xf,0x66),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pcmpgtw,MA_3(0x66,0xf,0x65),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pcmpgtw,MA_2(0xf,0x65),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pextrw,MA_3(0x66,0xf,0xc5),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_REG,pg_IMM_U8,opsz_32),
OP(op_pextrw,MA_2(0xf,0xc5),enc_param_slash_r,enc_imm_8,2,pg_REG,pg_REG,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_pmaddwd,MA_3(0x66,0xf,0xf5),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmaddwd,MA_2(0xf,0xf5),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmaxsw,MA_3(0x66,0xf,0xee),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmaxsw,MA_2(0xf,0xee),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmaxub,MA_3(0x66,0xf,0xde),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmaxub,MA_2(0xf,0xde),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pminsw,MA_3(0x66,0xf,0xea),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pminsw,MA_2(0xf,0xea),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pminub,MA_3(0x66,0xf,0xda),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pminub,MA_2(0xf,0xda),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmovmskb,MA_3(0x66,0xf,0xd7),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_REG,pg_NONE,opsz_32),
OP(op_pmovmskb,MA_2(0xf,0xd7),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmulhuw,MA_3(0x66,0xf,0xe4),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmulhuw,MA_2(0xf,0xe4),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmulhw,MA_3(0x66,0xf,0xe5),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmulhw,MA_2(0xf,0xe5),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmullw,MA_3(0x66,0xf,0xd5),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmullw,MA_2(0xf,0xd5),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pmuludq,MA_3(0x66,0xf,0xf4),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pmuludq,MA_2(0xf,0xf4),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pop,MA_1(0x58),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_16),
OP(op_pop,MA_1(0x58),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pop16,MA_1(0x8f),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_pop32,MA_1(0x8f),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_popa,MA_1(0x61),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_popad,MA_1(0x61),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_popf,MA_1(0x9d),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_popfd,MA_1(0x9d),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_por_mmx,MA_2(0xf,0xeb),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_por_xmm,MA_3(0x66,0xf,0xeb),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_prefetchnta,MA_2(0xf,0x18),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_prefetcht0,MA_2(0xf,0x18),enc_param_slash_1,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_prefetcht1,MA_2(0xf,0x18),enc_param_slash_2,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_prefetcht2,MA_2(0xf,0x18),enc_param_slash_3,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_psadbw,MA_3(0x66,0xf,0xf6),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psadbw,MA_2(0xf,0xf6),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pshufd,MA_3(0x66,0xf,0x70),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_pshufhw,MA_3(0xf3,0xf,0x70),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_pshuflw,MA_3(0xf2,0xf,0x70),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_pshufw,MA_2(0xf,0x70),enc_param_slash_r,enc_imm_8,2,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_pslld,MA_3(0x66,0xf,0x72),enc_param_slash_6,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_pslld,MA_3(0x66,0xf,0xf2),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pslld,MA_2(0xf,0x72),enc_param_slash_6,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_pslld,MA_2(0xf,0xf2),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pslldq,MA_3(0x66,0xf,0x73),enc_param_slash_7,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_psllq,MA_3(0x66,0xf,0x73),enc_param_slash_6,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psllq,MA_3(0x66,0xf,0xf3),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psllq,MA_2(0xf,0x73),enc_param_slash_6,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psllq,MA_2(0xf,0xf3),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psllw,MA_3(0x66,0xf,0x71),enc_param_slash_6,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psllw,MA_3(0x66,0xf,0xf1),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psllw,MA_2(0xf,0x71),enc_param_slash_6,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psllw,MA_2(0xf,0xf1),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psrad,MA_3(0x66,0xf,0x72),enc_param_slash_4,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrad,MA_3(0x66,0xf,0xe2),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psrad,MA_2(0xf,0x72),enc_param_slash_4,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrad,MA_2(0xf,0xe2),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psraw,MA_3(0x66,0xf,0x71),enc_param_slash_4,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psraw,MA_3(0x66,0xf,0xe1),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psraw,MA_2(0xf,0x71),enc_param_slash_4,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psraw,MA_2(0xf,0xe1),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psrld,MA_3(0x66,0xf,0x72),enc_param_slash_2,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrld,MA_3(0x66,0xf,0xd2),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psrld,MA_2(0xf,0x72),enc_param_slash_2,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrld,MA_2(0xf,0xd2),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psrldq,MA_3(0x66,0xf,0x73),enc_param_slash_3,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_psrlq,MA_3(0x66,0xf,0x73),enc_param_slash_2,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrlq,MA_3(0x66,0xf,0xd3),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psrlq,MA_2(0xf,0x73),enc_param_slash_2,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrlq,MA_2(0xf,0xd3),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psrlw,MA_3(0x66,0xf,0x71),enc_param_slash_2,enc_imm_8,3,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrlw,MA_3(0x66,0xf,0xd1),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psrlw,MA_2(0xf,0x71),enc_param_slash_2,enc_imm_8,2,pg_REG,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_psrlw,MA_2(0xf,0xd1),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubb,MA_3(0x66,0xf,0xf8),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubb,MA_2(0xf,0xf8),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubd,MA_3(0x66,0xf,0xfa),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubd,MA_2(0xf,0xfa),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubq,MA_3(0x66,0xf,0xfb),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubq,MA_2(0xf,0xfb),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubsb,MA_3(0x66,0xf,0xe8),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubsb,MA_2(0xf,0xe8),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubsw,MA_3(0x66,0xf,0xe9),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubsw,MA_2(0xf,0xe9),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubusb,MA_3(0x66,0xf,0xd8),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubusb,MA_2(0xf,0xd8),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubusw,MA_3(0x66,0xf,0xd9),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubusw,MA_2(0xf,0xd9),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_psubw,MA_3(0x66,0xf,0xf9),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_psubw,MA_2(0xf,0xf9),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpckhbw,MA_3(0x66,0xf,0x68),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpckhbw,MA_2(0xf,0x68),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpckhdq,MA_3(0x66,0xf,0x6a),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpckhdq,MA_2(0xf,0x6a),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpckhqdq,MA_3(0x66,0xf,0x6d),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpckhwd,MA_3(0x66,0xf,0x69),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpckhwd,MA_2(0xf,0x69),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpcklbw,MA_3(0x66,0xf,0x60),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpcklbw,MA_2(0xf,0x60),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpckldq,MA_3(0x66,0xf,0x62),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpckldq,MA_2(0xf,0x62),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpcklqdq,MA_3(0x66,0xf,0x6c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_punpcklwd,MA_3(0x66,0xf,0x61),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_punpcklwd,MA_2(0xf,0x61),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_push,MA_1(0x68),enc_param_none,enc_imm_32,1,pg_NONE,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_push,MA_1(0x68),enc_param_none,enc_imm_16,1,pg_NONE,pg_NONE,pg_IMM_U16,opsz_32),
OP(op_push,MA_1(0x6a),enc_param_none,enc_imm_8,1,pg_NONE,pg_NONE,pg_IMM_U8,opsz_32),
OP(op_push,MA_1(0x50),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_16),
OP(op_push,MA_1(0x50),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_push16,MA_1(0xff),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_push32,MA_1(0xff),enc_param_slash_6,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pusha,MA_1(0x60),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pushad,MA_1(0x60),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pushf,MA_1(0x9c),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pushfd,MA_1(0x9c),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_pxor,MA_3(0x66,0xf,0xef),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
OP(op_pxor,MA_2(0xf,0xef),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rcl8,MA_1(0xd2),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_rcl8,MA_1(0xd0),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_rcl8,MA_1(0xc0),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_rcl16,MA_1(0xd3),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_rcl16,MA_1(0xd1),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_rcl16,MA_1(0xc1),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_rcl32,MA_1(0xd3),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_rcl32,MA_1(0xd1),enc_param_slash_2,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_rcl32,MA_1(0xc1),enc_param_slash_2,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_rcpps,MA_2(0xf,0x53),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rcpss,MA_3(0xf3,0xf,0x53),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rcr8,MA_1(0xd2),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_rcr8,MA_1(0xd0),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_rcr8,MA_1(0xc0),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_rcr16,MA_1(0xd3),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_rcr16,MA_1(0xd1),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_rcr16,MA_1(0xc1),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_rcr32,MA_1(0xd3),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_rcr32,MA_1(0xd1),enc_param_slash_3,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_rcr32,MA_1(0xc1),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_rdmsr,MA_2(0xf,0x32),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rdpmc,MA_2(0xf,0x33),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rdtsc,MA_2(0xf,0x31),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ret,MA_1(0xc3),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
OP(op_ret,MA_1(0xc2),enc_param_none,enc_imm_16,1,pg_NONE,pg_NONE,pg_IMM_U16,opsz_32),
s_LIST_END,

OP(op_retf,MA_1(0xcb),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
OP(op_retf,MA_1(0xca),enc_param_none,enc_imm_16,1,pg_NONE,pg_NONE,pg_IMM_U16,opsz_32),
s_LIST_END,

OP(op_rol8,MA_1(0xd2),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_rol8,MA_1(0xd0),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_rol8,MA_1(0xc0),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_rol16,MA_1(0xd3),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_rol16,MA_1(0xd1),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_rol16,MA_1(0xc1),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_rol32,MA_1(0xd3),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_rol32,MA_1(0xd1),enc_param_slash_0,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_rol32,MA_1(0xc1),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_ror8,MA_1(0xd2),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_ror8,MA_1(0xd0),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_ror8,MA_1(0xc0),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_ror16,MA_1(0xd3),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_ror16,MA_1(0xd1),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_ror16,MA_1(0xc1),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_ror32,MA_1(0xd3),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_ror32,MA_1(0xd1),enc_param_slash_1,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_ror32,MA_1(0xc1),enc_param_slash_1,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_rsm,MA_2(0xf,0xaa),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rsqrtps,MA_2(0xf,0x52),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_rsqrtss,MA_3(0xf3,0xf,0x52),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sahf,MA_1(0x9e),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sal8,MA_1(0xd2),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_sal8,MA_1(0xd0),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_sal8,MA_1(0xc0),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_sal16,MA_1(0xd3),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_sal16,MA_1(0xd1),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_sal16,MA_1(0xc1),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_sal32,MA_1(0xd3),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_sal32,MA_1(0xd1),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_sal32,MA_1(0xc1),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_sar8,MA_1(0xd2),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_sar8,MA_1(0xd0),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_sar8,MA_1(0xc0),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_sar16,MA_1(0xd3),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_sar16,MA_1(0xd1),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_sar16,MA_1(0xc1),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_sar32,MA_1(0xd3),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_sar32,MA_1(0xd1),enc_param_slash_7,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_sar32,MA_1(0xc1),enc_param_slash_7,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_sbb16,MA_1(0x83),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_sbb16,MA_1(0x1d),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_sbb16,MA_1(0x81),enc_param_slash_3,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_sbb16,MA_1(0x19),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_sbb16,MA_1(0x1b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_sbb32,MA_1(0x83),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_sbb32,MA_1(0x1d),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_sbb32,MA_1(0x81),enc_param_slash_3,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_sbb32,MA_1(0x19),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_sbb32,MA_1(0x1b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sbb8,MA_1(0x1c),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_sbb8,MA_1(0x80),enc_param_slash_3,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_sbb8,MA_1(0x18),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_sbb8,MA_1(0x1a),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_scasb,MA_1(0xae),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_scasd,MA_1(0xaf),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_scasw,MA_1(0xaf),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_seta,MA_2(0xf,0x97),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setae,MA_2(0xf,0x93),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setb,MA_2(0xf,0x92),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setbe,MA_2(0xf,0x96),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setc,MA_2(0xf,0x92),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_sete,MA_2(0xf,0x94),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setg,MA_2(0xf,0x9f),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setge,MA_2(0xf,0x9d),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setl,MA_2(0xf,0x9c),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setle,MA_2(0xf,0x9e),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setna,MA_2(0xf,0x96),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnae,MA_2(0xf,0x92),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnb,MA_2(0xf,0x93),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnbe,MA_2(0xf,0x97),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnc,MA_2(0xf,0x93),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setne,MA_2(0xf,0x95),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setng,MA_2(0xf,0x9e),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnge,MA_2(0xf,0x9c),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnl,MA_2(0xf,0x9d),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnle,MA_2(0xf,0x9f),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setno,MA_2(0xf,0x91),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnp,MA_2(0xf,0x9b),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setns,MA_2(0xf,0x99),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setnz,MA_2(0xf,0x95),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_seto,MA_2(0xf,0x90),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setp,MA_2(0xf,0x9a),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setpe,MA_2(0xf,0x9a),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setpo,MA_2(0xf,0x9b),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_sets,MA_2(0xf,0x98),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_setz,MA_2(0xf,0x94),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
s_LIST_END,

OP(op_sfence,MA_3(0xf,0xae,0xf8),enc_param_none,enc_imm_none,3,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sgdt,MA_2(0xf,0x1),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_shl8,MA_1(0xd2),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_shl8,MA_1(0xd0),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_shl8,MA_1(0xc0),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_shl16,MA_1(0xd3),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_shl16,MA_1(0xd1),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_shl16,MA_1(0xc1),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_shl32,MA_1(0xd3),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_shl32,MA_1(0xd1),enc_param_slash_4,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_shl32,MA_1(0xc1),enc_param_slash_4,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_shld16,MA_2(0xf,0xa5),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_CL,opsz_16),
OP(op_shld16,MA_2(0xf,0xa4),enc_param_slash_r_rev,enc_imm_8,2,pg_ModRM,pg_REG,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_shld32,MA_2(0xf,0xa5),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_CL,opsz_32),
OP(op_shld32,MA_2(0xf,0xa4),enc_param_slash_r_rev,enc_imm_8,2,pg_ModRM,pg_REG,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_shr8,MA_1(0xd2),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_8),
OP(op_shr8,MA_1(0xd0),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_8),
OP(op_shr8,MA_1(0xc0),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
s_LIST_END,

OP(op_shr16,MA_1(0xd3),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_16),
OP(op_shr16,MA_1(0xd1),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
OP(op_shr16,MA_1(0xc1),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_shr32,MA_1(0xd3),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_CL,pg_NONE,opsz_32),
OP(op_shr32,MA_1(0xd1),enc_param_slash_5,enc_imm_none,1,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
OP(op_shr32,MA_1(0xc1),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_shrd16,MA_2(0xf,0xad),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_CL,opsz_16),
OP(op_shrd16,MA_2(0xf,0xac),enc_param_slash_r_rev,enc_imm_8,2,pg_ModRM,pg_REG,pg_IMM_U8,opsz_16),
s_LIST_END,

OP(op_shrd32,MA_2(0xf,0xad),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_CL,opsz_32),
OP(op_shrd32,MA_2(0xf,0xac),enc_param_slash_r_rev,enc_imm_8,2,pg_ModRM,pg_REG,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_shufpd,MA_3(0x66,0xf,0xc6),enc_param_slash_r,enc_imm_8,3,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_shufps,MA_2(0xf,0xc6),enc_param_slash_r,enc_imm_8,2,pg_REG,pg_ModRM,pg_IMM_U8,opsz_32),
s_LIST_END,

OP(op_sidt,MA_2(0xf,0x1),enc_param_slash_1,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sldt16,MA_2(0xf,0x0),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_sldt32,MA_2(0xf,0x0),enc_param_slash_0,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_smsw16,MA_2(0xf,0x1),enc_param_slash_4,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_sqrtpd,MA_3(0x66,0xf,0x51),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sqrtps,MA_2(0xf,0x51),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sqrtsd,MA_3(0xf2,0xf,0x51),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sqrtss,MA_3(0xf3,0xf,0x51),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_stc,MA_1(0xf9),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_std,MA_1(0xfd),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sti,MA_1(0xfb),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_stmxcsr,MA_2(0xf,0xae),enc_param_slash_3,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_stosb,MA_1(0xaa),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_stosd,MA_1(0xab),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_stosw,MA_1(0xab),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_str,MA_2(0xf,0x0),enc_param_slash_1,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_sub16,MA_1(0x83),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_sub16,MA_1(0x2d),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_sub16,MA_1(0x81),enc_param_slash_5,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_sub16,MA_1(0x29),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_sub16,MA_1(0x2b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_sub32,MA_1(0x83),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_sub32,MA_1(0x2d),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_sub32,MA_1(0x81),enc_param_slash_5,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_sub32,MA_1(0x29),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_sub32,MA_1(0x2b),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sub8,MA_1(0x2c),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_sub8,MA_1(0x80),enc_param_slash_5,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_sub8,MA_1(0x28),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_sub8,MA_1(0x2a),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_subpd,MA_3(0x66,0xf,0x5c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_subps,MA_2(0xf,0x5c),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_subsd,MA_3(0xf2,0xf,0x5c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_subss,MA_3(0xf3,0xf,0x5c),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sysenter,MA_2(0xf,0x34),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_sysexit,MA_2(0xf,0x35),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_test8,MA_1(0xa8),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_test8,MA_1(0xf6),enc_param_slash_0,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_test8,MA_1(0x84),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_test8,MA_1(0x84),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_test16,MA_1(0xa9),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_test16,MA_1(0xf7),enc_param_slash_0,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_test16,MA_1(0x85),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_test16,MA_1(0x85),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_test32,MA_1(0xa9),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_test32,MA_1(0xf7),enc_param_slash_0,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_test32,MA_1(0x85),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_test32,MA_1(0x85),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ucomisd,MA_3(0x66,0xf,0x2e),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ucomiss,MA_2(0xf,0x2e),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_ud2,MA_2(0xf,0xb),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_unpckhpd,MA_3(0x66,0xf,0x15),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_unpckhps,MA_2(0xf,0x15),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_unpcklpd,MA_3(0x66,0xf,0x14),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_unpcklps,MA_2(0xf,0x14),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_verr,MA_2(0xf,0x0),enc_param_slash_4,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_verw,MA_2(0xf,0x0),enc_param_slash_5,enc_imm_none,2,pg_ModRM,pg_NONE,pg_NONE,opsz_16),
s_LIST_END,

OP(op_wait,MA_1(0x9b),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_wbinvd,MA_2(0xf,0x9),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_wrmsr,MA_2(0xf,0x30),enc_param_none,enc_imm_none,2,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xadd8,MA_2(0xf,0xc0),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_8),
s_LIST_END,

OP(op_xadd16,MA_2(0xf,0xc1),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_16),
s_LIST_END,

OP(op_xadd32,MA_2(0xf,0xc1),enc_param_slash_r_rev,enc_imm_none,2,pg_ModRM,pg_REG,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xchg8,MA_1(0x86),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
OP(op_xchg8,MA_1(0x86),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
s_LIST_END,

OP(op_xchg16,MA_1(0x90),enc_param_plus_r,enc_imm_none,1,pg_R0,pg_REG,pg_NONE,opsz_16),
OP(op_xchg16,MA_1(0x90),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_R0,pg_NONE,opsz_16),
OP(op_xchg16,MA_1(0x87),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_xchg16,MA_1(0x87),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_xchg32,MA_1(0x90),enc_param_plus_r,enc_imm_none,1,pg_R0,pg_REG,pg_NONE,opsz_32),
OP(op_xchg32,MA_1(0x90),enc_param_plus_r,enc_imm_none,1,pg_REG,pg_R0,pg_NONE,opsz_32),
OP(op_xchg32,MA_1(0x87),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_xchg32,MA_1(0x87),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xlatb,MA_1(0xd7),enc_param_none,enc_imm_none,1,pg_NONE,pg_NONE,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xor16,MA_1(0x83),enc_param_slash_6,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_16),
OP(op_xor16,MA_1(0x35),enc_param_none,enc_imm_16,1,pg_R0,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_xor16,MA_1(0x81),enc_param_slash_6,enc_imm_16,1,pg_ModRM,pg_NONE,pg_IMM_U16,opsz_16),
OP(op_xor16,MA_1(0x31),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_16),
OP(op_xor16,MA_1(0x33),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_16),
s_LIST_END,

OP(op_xor32,MA_1(0x83),enc_param_slash_6,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_S8,opsz_32),
OP(op_xor32,MA_1(0x35),enc_param_none,enc_imm_32,1,pg_R0,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_xor32,MA_1(0x81),enc_param_slash_6,enc_imm_32,1,pg_ModRM,pg_NONE,pg_IMM_U32,opsz_32),
OP(op_xor32,MA_1(0x31),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_32),
OP(op_xor32,MA_1(0x33),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xor8,MA_1(0x34),enc_param_none,enc_imm_8,1,pg_R0,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_xor8,MA_1(0x80),enc_param_slash_6,enc_imm_8,1,pg_ModRM,pg_NONE,pg_IMM_U8,opsz_8),
OP(op_xor8,MA_1(0x30),enc_param_slash_r_rev,enc_imm_none,1,pg_ModRM,pg_REG,pg_NONE,opsz_8),
OP(op_xor8,MA_1(0x32),enc_param_slash_r,enc_imm_none,1,pg_REG,pg_ModRM,pg_NONE,opsz_8),
s_LIST_END,

OP(op_xorpd,MA_3(0x66,0xf,0x57),enc_param_slash_r,enc_imm_none,3,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

OP(op_xorps,MA_2(0xf,0x57),enc_param_slash_r,enc_imm_none,2,pg_REG,pg_ModRM,pg_NONE,opsz_32),
s_LIST_END,

