//Emitting code ;)
#pragma warning(disable:4127)
#pragma warning(disable:4244)
#pragma warning(disable:4245)

#include "../types.h"
#include "x86_emitter.h"
bool IsS8(u32 value)
{
	if (((value&0xFFFFFF80)==0xFFFFFF80) ||
		(value&0xFFFFFF80)==0  )
		return true;
	else
		return false;
}
#include "x86_op_encoder.h"
#include "x86_matcher.h"
//x86_Label 
/*
//x86_ptr/x86_ptr_imm
x86_ptr x86_ptr::create(void* ptr)
{
	x86_ptr rv={ptr};
	return rv;
}*/
x86_ptr x86_ptr::create(unat ptr)
{
#pragma warning(disable:4312)
	x86_ptr rv(0);
	rv.ptr_int=ptr;
	return rv;
#pragma warning(default:4312) 
}
/*
x86_ptr_imm x86_ptr_imm::create(void* ptr)
{
	x86_ptr_imm rv={ptr};
	return rv;
}*/
x86_ptr_imm x86_ptr_imm::create(unat ptr)
{
#pragma warning(disable:4312) 
	x86_ptr_imm rv(0);
	rv.ptr_int=ptr;
	return rv;
#pragma warning(default:4312) 
}
//x86_block
//init things

#ifdef X86_OP_NAMES
const char Names[op_count][64] =
{
	#include "generated_class_names_string.h"
};
#endif


void* x86_Label::GetPtr()
{
	return owner->x86_buff + this->target_opcode;
}

const char* DissasmClass(x86_opcode_class opcode)
{
	#ifdef X86_OP_NAMES
	return Names[opcode];
	#else
	return "No opcode name info included";
	#endif
}
void x86_block::Init(dyna_reallocFP* ral,dyna_finalizeFP* alf)
{
	ralloc=ral;
	allocfin=alf;
	x86_buff=0;
	x86_indx=0;
	x86_size=0;
	do_realloc=true;
}
#define patches (*(vector<code_patch>*) _patches)
#define labels (*(vector<x86_Label*>*) _labels)

//Generates code.if user_data is non zero , user_data_size bytes are allocated after the executable code
//and user_data is set to the first byte of em.Allways 16 byte aligned
void* x86_block::Generate()
{
	if (do_realloc)
	{
		u8* final_buffer=0;

		final_buffer=(u8*)allocfin(x86_buff,x86_size,x86_indx);

		if (final_buffer==0)
			return 0;

		x86_buff=final_buffer;
	}
	ApplyPatches(x86_buff);

	return &x86_buff[0];
}

struct x86_block_externs_i : x86_block_externs
{
	struct extern_entry { u8* dst;u32 offs:28;u32 size:4; };
	vector<extern_entry> externs;

	void Apply(u8* base)
	{
		for (u32 i=0;i<externs.size();i++)
		{
			u8* dest=(u8*)externs[i].dst;

			u8* code_offset=base+externs[i].offs;
			u8* diff_offset=code_offset+externs[i].size;

			u32 diff=(u32)(dest-diff_offset);
			if (externs[i].size==1)
			{
				verify(IsS8(diff));
				*code_offset=(u8)diff;
			}
			else if (externs[i].size==2)
			{
				*(u16*)code_offset=(u16)diff;
			}
			else if (externs[i].size==4)
			{
				*(u32*)code_offset=(u32)diff;
			}
		}
	}
	bool Modify(u32 offs,u8* dst)
	{
		for (u32 i=0;i<externs.size();i++)
		{
			if (externs[i].offs==offs)
			{
				externs[i].dst=dst;
				return true;
			}
		}
		return false;
	}
	void Add(u8* dst,u32 offset,u32 size)
	{
		extern_entry vta={dst,offset,size};
		externs.push_back(vta);
	}
	void Free()
	{
		delete this;
	}
};

x86_block_externs::~x86_block_externs() {}
void x86_block_externs::Apply(void* lolwhut) { ((x86_block_externs_i*)this)->Apply((u8*)lolwhut); }
bool x86_block_externs::Modify(u32 offs,u8* dst) { return ((x86_block_externs_i*)this)->Modify(offs,dst); }
void x86_block_externs::Free() { ((x86_block_externs_i*)this)->Free(); }

x86_block_externs* x86_block::GetExterns()
{
	x86_block_externs_i* rv=new x86_block_externs_i();
	u8* base=x86_buff;
	for (u32 i=0;i<patches.size();i++)
	{
		u8* dest=(u8*)patches[i].dest;

		if (patches[i].type&16)
		{
			if (patches[i].lbl->owner==this)
				dest = base + patches[i].lbl->target_opcode;
			else
				dest = patches[i].lbl->owner->x86_buff + patches[i].lbl->target_opcode;
		}

		u32 start_diff=(u32)(dest-base);
		if (start_diff>=x86_indx)
		{
			rv->Add(dest,patches[i].offset,patches[i].type&0xF);
		}
	}

	return rv;
}

#if 0
#include "windows.h"
/*void x86_block::CopyTo(void* to)
{
	memcpy(to,x86_buff,x86_indx);
	free(x86_buff);
	x86_buff=(u8*)to;

	ApplyPatches(x86_buff);
}
*/

#endif

//wut ?
void x86_block::ApplyPatches(u8* base)
{
	for (u32 i=0;i<patches.size();i++)
	{
		u8* dest=(u8*)patches[i].dest;

		u8* code_offset=base+patches[i].offset;
		u8* diff_offset=code_offset+(patches[i].type&0xF);

		if (patches[i].type&16)
		{
			if (patches[i].lbl->owner==this)
				dest = base + patches[i].lbl->target_opcode;
			else
				dest = patches[i].lbl->owner->x86_buff + patches[i].lbl->target_opcode;

		}

		u32 diff=(u32)(dest-diff_offset);
		if ((patches[i].type&0xF)==1)
		{
			verify(IsS8(diff));
			*code_offset=(u8)diff;
		}
		else if ((patches[i].type&0xF)==2)
		{
			*(u16*)code_offset=(u16)diff;
		}
		else if ((patches[i].type&0xF)==4)
		{
			*(u32*)code_offset=(u32)diff;
		}
	}
}
x86_block::x86_block()
{
	_patches=new vector<code_patch>;
	_labels=new vector<x86_Label*>;
	opcode_count=0;
}
x86_block::~x86_block()
{
	//ensure everything is freed :)
	Free();
	delete &patches;
	delete &labels;
}
//Will free any used resources except generated code
void x86_block::Free()
{
	for (u32 i =0;i<labels.size();i++)
		delete labels[i];
	labels.clear();
}
void x86_block::x86_buffer_ensure(u32 size)
{
	if (this->x86_size<(size+x86_indx))
	{
		verify(do_realloc!=false);
		u32 old_size=x86_size;
		x86_size+=128;
		x86_size*=2;
		x86_buff=(u8*)ralloc(x86_buff,old_size,x86_size);
	}
}
void  x86_block::write8(u32 value)
{
	x86_buffer_ensure(15);
	//printf("%02X ",value);
	x86_buff[x86_indx]=value;
	x86_indx+=1;
}
void  x86_block::write16(u32 value)
{
	x86_buffer_ensure(15);
	//printf("%04X ",value);
	*(u16*)&x86_buff[x86_indx]=value;
	x86_indx+=2;
}
void  x86_block::write32(u32 value)
{
	x86_buffer_ensure(15);
	//printf("%08X ",value);
	*(u32*)&x86_buff[x86_indx]=value;
	x86_indx+=4;
}

//Label related code

//NOTE : Label position in mem must not change
void x86_block::CreateLabel(x86_Label* lbl,bool mark,u32 sz)
{
	memset(lbl,0xFFFFFFFF,sizeof(x86_Label));
	lbl->owner=this;
	lbl->marked=false;
	lbl->patch_sz=sz;
	if (mark)
		MarkLabel(lbl);
}
//Allocate a label and create it :).Will be deleted when calling free and/or destructor
x86_Label* x86_block::CreateLabel(bool mark,u32 sz)
{
	x86_Label* lbl = new x86_Label();
	CreateLabel(lbl,mark,sz);
	labels.push_back(lbl);
	return lbl;
}
//Mark a label so that it points to next emitted opcode
void x86_block::MarkLabel(x86_Label* lbl)
{
	verify(lbl->marked==false);
	lbl->marked=true;
	lbl->target_opcode=x86_indx;
	//lbl->target_opcode=(u32)opcodes.size();
}
//opcode Emitters

x86_mrm_t c_mrm(x86_ptr mem)
{
	return x86_mrm(NO_REG,mem);
}
//no param
void x86_block::Emit(x86_opcode_class op)
{
	ME_op_0(op);
}

//1 param
//reg
void x86_block::Emit(x86_opcode_class op,x86_reg reg)
{
	ME_op_1_nrm(op,reg);
}
//smrm
void x86_block::Emit(x86_opcode_class op,x86_ptr mem)
{
	Emit(op,c_mrm(mem));
}
//mrm
void x86_block::Emit(x86_opcode_class op,x86_mrm_t mrm)
{
	ME_op_1_nrm(op,mrm);
}
//imm
void x86_block::Emit(x86_opcode_class op,u32 imm)
{
	ME_op_1_imm(op,imm);
}
//ptr_imm
void x86_block::Emit(x86_opcode_class op,x86_ptr_imm disp)
{
	ME_op_1_nrm(op,disp);
}
//lbl
void x86_block::Emit(x86_opcode_class op,x86_Label* lbl)
{
	
	ME_op_1_nrm(op,lbl);
}

//2 param
//reg,reg, reg1 is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg1,x86_reg reg2)
{
	ME_op_2_nrm(op,reg1,reg2);
}
//reg,smrm, reg is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg,x86_ptr mem)
{
	Emit(op,reg,c_mrm(mem));
}
//reg,mrm, reg is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg,x86_mrm_t mrm)
{
	ME_op_2_nrm(op,reg,mrm);
}
//reg,imm, reg is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg,u32 imm)
{
	ME_op_2_imm(op,reg,imm);
}

//smrm,reg, mem is written
void x86_block::Emit(x86_opcode_class op,x86_ptr mem,x86_reg reg)
{
	Emit(op,c_mrm(mem),reg);
}
//smrm,imm, mem is written
void x86_block::Emit(x86_opcode_class op,x86_ptr mem,u32 imm)
{
	Emit(op,c_mrm(mem),imm);
}

//mrm,reg, mrm is written
void x86_block::Emit(x86_opcode_class op,x86_mrm_t mrm,x86_reg reg)
{
	ME_op_2_nrm(op,mrm,reg);
}
//mrm,imm, mrm is written
void x86_block::Emit(x86_opcode_class op,x86_mrm_t mrm,u32 imm)
{
	ME_op_2_imm(op,mrm,imm);
}

//3 param
//reg,reg,imm, reg1 is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg1,x86_reg reg2,u32 imm)
{
	ME_op_3_imm(op,reg1,reg2,imm);
}

//reg,mrm,imm, reg1 is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg,x86_ptr mem,u32 imm)
{
	//GCC bitches about using this directly. It doesn't complain for the other uses though
	//go figure ....
	x86_mrm_t mrm = c_mrm(mem);
	ME_op_3_imm(op,reg,mrm,imm);
}

//reg,mrm,imm, reg1 is written
void x86_block::Emit(x86_opcode_class op,x86_reg reg,x86_mrm_t mrm,u32 imm)
{
	ME_op_3_imm(op,reg,mrm,imm);
}

#define make_modrm(mod,rm) ( ((mod)<<6) | ((0)<<3) | (rm) )
#define make_sib(scale,index,base) ( ((scale)<<6) | ((index)<<3) | (base) )

u8 EncodeDisp(u32 disp,x86_mrm_t* to,u8 flags)
{
	//[reg+sdisp8] or [reg+sdisp32]
	//sdisp32 support only for now , sdisp8 for later
	if (flags&1)
	{
		if (IsS8(disp))
		{
			to->flags|=2;
			to->disp=disp;
			if (flags&4)
				return 0;
			else
				return make_modrm(1,0);
		}
	}
	if (flags&2)
	{
		to->flags|=4;
		to->disp=disp;
		if (flags&4)
			return 0;
		else
			return make_modrm(2,0);
	}
	verify(false);
	return 0;
}
/*__declspec(dllexport) */x86_mrm_t x86_mrm(x86_reg base)
{
	return x86_mrm(base,NO_REG,sib_scale_1,0);
}
/*__declspec(dllexport) */x86_mrm_t x86_mrm(x86_reg base,x86_ptr disp)
{
	return x86_mrm(base,NO_REG,sib_scale_1,disp);
}
/*__declspec(dllexport) */x86_mrm_t x86_mrm(x86_reg index,x86_sib_scale scale,x86_ptr disp)
{
	return x86_mrm(NO_REG,index,scale,disp);
}
/*__declspec(dllexport) */x86_mrm_t x86_mrm(x86_reg base,x86_reg index)
{
	return x86_mrm(base,index,sib_scale_1,0);
}

//NEEDS WORK
x86_mrm_t x86_mrm(x86_reg base,x86_reg index,x86_sib_scale scale,x86_ptr disp)
{
	x86_mrm_t rv;
	rv.flags=0;

#ifdef X64
	if (base!=NO_REG && base>EDI)
	{
		rv.flags|=((base>>3)&1)<<2;
		base=(x86_reg)(base&7);
	}
	if (index!=NO_REG && index>EDI)
	{
		rv.flags|=((index>>3)&1)<<3;
		index=(x86_reg)(index&7);
	}
#endif

	verify(index!=ESP);//cant be used

	if(index==NO_REG)
	{
		//no index , ignore scale
		if (base==ESP)
		{
			//special encoding
			//encoded as [none*x + ESP]
			//index ,scale [sib]
			rv.modrm = make_modrm(0,ESP); //ESP means sib
			rv.flags|=1;


			rv.sib=make_sib(0,ESP,base); //none*1+ESP

			if ( disp.ptr_int!=0 )
			{
				rv.modrm |= EncodeDisp(disp.ptr_int,&rv,3);
			}
		}
		else if (base == EBP)
		{
			//special encoding
			//verify(false);
			rv.modrm = make_modrm(0,base);
			//uses [EBP+S8] , or [EBP+S32] forms
			rv.modrm |= EncodeDisp(disp.ptr_int,&rv,3); //32 or 8 bit disp
		}
		else if (base == NO_REG)
		{
			//[disp32]
			//special encoding , will use mode [EBP] (it means disp :p)
			rv.modrm=make_modrm(0,EBP);
			EncodeDisp(disp.ptr_int,&rv,2|4); //only 32b disp allowed , uses form 0
		}
		else
		{
			//[reg] , [reg+disp8/32]
			rv.modrm = make_modrm(0,base);
			if (disp.ptr_int!=0)
			{
				rv.modrm |= EncodeDisp(disp.ptr_int,&rv,3); //32 or 16 bit disp
			}
		}
	}
	else
	{
		//index ,scale [sib]
		rv.modrm = make_modrm(0,ESP);//ESP means sib
		rv.flags|=1;

		bool force_disp=false;
		u8 disp_sz=3;

		
		if (base==EBP)
			force_disp=true;
		
		if (base==NO_REG)
		{
			rv.sib=make_sib(scale,index,EBP);
			disp_sz=2|4; //only 32b disp , return 0 on mrm type
			force_disp=true;
		}
		else
			rv.sib=make_sib(scale,index,base);

		if ( force_disp  || (disp.ptr_int!=0) )
		{
			rv.modrm |= EncodeDisp(disp.ptr_int,&rv,disp_sz);
		}
	}
	return rv;
}
