
//included on x86_emitter.cpp

/*
enum x86_op_params
{
	param_none,
	param_reg,
	param_mem,
	param_imm,

	param_reg_reg,
	param_reg_mem,
	param_reg_imm,

	param_mem_reg,
	param_mem_imm,
};
*/

encoded_type pg_none = {pg_NONE};

encoded_type param_type(x86_Label* lbl)
{
	encoded_type rv;
	//Return pg_MEM_Rel32/pg_MEM_Rel16/pg_MEM_Rel8
	//we do need some more info on this :P
	if (lbl->patch_sz==8)
		rv.type=pg_MEM_Rel8;
	else
		rv.type=pg_MEM_Rel32;
	rv.ptr=lbl;
	rv.ptr_type=1;
	return rv;
}
encoded_type param_type(x86_ptr_imm ptr)
{
	encoded_type rv;
	//Return pg_MEM_Rel32.Due to relocation we cant optimise to 16/8 in one pass ...
	//we do need some more info on this :P
	rv.type=pg_MEM_Rel32;
	rv.ptr=ptr.ptr;
	rv.ptr_type=0;
	return rv;
}
encoded_type param_type(x86_mrm_t& modrm)
{
	encoded_type rv;
	rv.modrm=modrm;
	//Return reg , mem cmplx , mem direct
	rv.type=pg_ModRM;
	return rv;
}
encoded_type param_type(x86_reg reg)
{
	encoded_type rv;
	rv.reg=REG_ID(reg);
	//later : detect R0 :)
	if (reg==EAX ||reg==AX ||reg==AL)
		rv.type=pg_R0;
	else if (reg==CL || reg==ECX)
		rv.type=pg_CL;
	else
		rv.type=pg_REG;
	return rv;
}

encoded_type param_type(u32 imm)
{
	encoded_type rv;
	rv.imm=imm;
	//later : detect u8/s8/s16/s32 encodings :)
	
	if (IsS8(imm))
		rv.type=pg_IMM_S8;
	else if ((imm & (~0xFF))==0)
		rv.type=pg_IMM_U8;
	else if ((imm & (~0xFFFF))==0)
		rv.type=pg_IMM_U16;
	else
		rv.type=pg_IMM_U32;

	return rv;
}
void Match_opcode(x86_block* block,const x86_opcode* ops,encoded_type pg1,encoded_type pg2,encoded_type pg3)
{
	block->opcode_count++;
	const x86_opcode* match=0;
	for (u32 i=0;ops[i].encode!=0;i++)
	{
			if (ENC_PARAM_CONTAINS(ops[i].pg_1,pg1.type) &&
				ENC_PARAM_CONTAINS(ops[i].pg_2,pg2.type) &&
				ENC_PARAM_CONTAINS(ops[i].pg_3,pg3.type)
				)
			{
				match= &ops[i];
				break;
			}
	}
	if (match==0)
	{
		char temp[512];
		sprintf(temp,"Unable to match opcode %s",DissasmClass(ops->opcode));
		die(temp);
		return;
	}
//	printf("Matched opcode %s to %s\n",DissasmClass(ops->opcode),DissasmClass(match->opcode));
	match->encode(block,match,&pg1,&pg2,pg3.imm);
}

#define ME_op_0(opcl)					Match_opcode(this,x86_opcode_list[opcl], pg_none, pg_none, pg_none)

#define ME_op_1_nrm(opcl, pg1)				Match_opcode(this,x86_opcode_list[opcl], param_type(pg1), pg_none, pg_none)
#define ME_op_1_imm(opcl, pg1)				Match_opcode(this,x86_opcode_list[opcl], pg_none, pg_none, param_type(pg1))

#define ME_op_2_nrm(opcl, pg1, pg2)			Match_opcode(this,x86_opcode_list[opcl], param_type(pg1), param_type(pg2), pg_none)
#define ME_op_2_imm(opcl, pg1, pg2)			Match_opcode(this,x86_opcode_list[opcl], param_type(pg1), pg_none,param_type(pg2))

#define ME_op_3_nrm(opcl, pg1, pg2, pg3)	Match_opcode(this,x86_opcode_list[opcl], param_type(pg1), param_type(pg2), param_type(pg3))
#define ME_op_3_imm(opcl, pg1, pg2, pg3)	Match_opcode(this,x86_opcode_list[opcl], param_type(pg1), param_type(pg2), param_type(pg3))