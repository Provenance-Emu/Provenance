//#include "types.h"
//#include "x86_emitter.h"

/*
	--x86 is such a fucked cpu arch--
	->for 32b mode , x64 is not supported atm<-
	opcode encoding :
	[prefix]opcode[opcode][modrm][sib][disp][imm]
*/

/*
	Opcode selection : match parameter types  , then encode based on encoding info.
	encoding types :

	enc_1
	{
		/r		->reg,r/m
		/r_rev	->r/m,reg
		/digit	->r/m , 3 op bits
		/+r		->reg
		fixed	->fixed reg (EAX/AH/AL).Few opcodes have this set (Olny specialised versions of generic ops)
	}

	enc_2
	{
		imm8
		simm8
		imm16
		imm32

		memoffset -> void*

		memrel8		-> op[s8]
		memrel16	-> op[s16]
		memrel32	-> op[s32]
	}

	param_type
	{
		reg={x86_regs}			//a register
		memoffset={void*}		//a memory pointer
		mrm={reg,memoffset,mem}	//a register or memory, including complex mem dereference

		memrel8={8b signed offset}
		memrel16={16b signed offset,memrel8}
		memrel32={32b signed offset,memrel16}
		
		//Labels are higher level constructs , they are converted to memrel*
		defined_label={memrel8 or memrel16 or memrel32}
		undefined_label={memrel32}

		imm_s8={s8}
		imm_u8={u8,imm_s8}
		imm_s16={s16,imm_u8}
		imm_u16={u16,imm_s16}
		imm_s32={s32,imm_u16}
		imm_u32={u32,imm_s32}
	}
*/

#include "build.h"

#if BUILD_COMPILER == COMPILER_GCC
	#define __fastcall BALLZZ!!
#endif


enum enc_param
{
	enc_param_none =0,
	//enc1 group
	// +r
	enc_param_plus_r ,
	// /r
	enc_param_slash_r ,
	enc_param_slash_r_rev ,

	// /digit
	enc_param_slash_0 ,
	enc_param_slash_1 ,
	enc_param_slash_2 ,
	enc_param_slash_3 ,
	enc_param_slash_4 ,
	enc_param_slash_5 ,
	enc_param_slash_6 ,
	enc_param_slash_7 ,

	//diroffset
	enc_param_memdir ,

	//reloffset
	enc_param_memrel_8 ,
	enc_param_memrel_16 ,
	enc_param_memrel_32 ,
};

//enc2 group

enum enc_imm
{
	enc_imm_none=0,
	enc_imm_native,
	enc_imm_8,
	enc_imm_16,
	enc_imm_32,
};
#define ENC_group(id) (1<<id)
#define ENC_PARAM_CONST_FULL(group,index) ( ( (group) <<8 ) | (index) )
#define ENC_PARAM_CONST(group,index) ( ENC_PARAM_CONST_FULL( ENC_group(group),index ) )

//param mode

enum x86_opcode_param
{
	//none , group 0
	pg_NONE = ENC_PARAM_CONST(7,0),

	//reg , group 1
	pg_R0  = ENC_PARAM_CONST(1,0),		//EAX , AX , or AH , depending on encoding mode
	pg_CL  = ENC_PARAM_CONST(1,1),		//CL 
	pg_REG  = ENC_PARAM_CONST(1,2),		//any reg :p

	//imm ,group 3
	pg_IMM_S8  = ENC_PARAM_CONST(3,1),	//sx'd byte imm
	pg_IMM_U8  = ENC_PARAM_CONST(3,2),	//byte imm

	pg_IMM_S16  = ENC_PARAM_CONST(3,3),	//sx'd word imm
	pg_IMM_U16  = ENC_PARAM_CONST(3,4),	//word imm

	pg_IMM_S32  = ENC_PARAM_CONST(3,5),	//sx'd dword imm
	pg_IMM_U32  = ENC_PARAM_CONST(3,6),	//dword imm

	//mem ptr , group 4
	pg_MEM_Dir	= ENC_PARAM_CONST(4,0),	//Absolute mem disp (ie , mov eax,[addr])
	pg_MEM_Cmplx  = ENC_PARAM_CONST(4,1),	//Complex mem disp

	//mem offset , group 5
	pg_MEM_Rel8  = ENC_PARAM_CONST(5,0),	//Relative mem disp (ie call)
	pg_MEM_Rel16  = ENC_PARAM_CONST(5,1),	//Relative mem disp (ie call)
	pg_MEM_Rel32  = ENC_PARAM_CONST(5,2),	//Relative mem disp (ie call)

	//MRM contains : REG,MEM
	//ModRM , group : complex ;)
	pg_ModRM  = ENC_PARAM_CONST_FULL(ENC_group(1) | ENC_group(4),255),	//yay :p
};

enum x86_operand_size
{
	opsz_8 =0,		//8 bit opcode
	opsz_16 ,		//16 bit opcode [needs prefix]
	opsz_32 ,		//32 bit opcode
};
//true if id1 contains id2
#define ENC_PARAM_CONTAINS(id1,id2)  ( ( ( (id1>>8) & (id2>>8) )!=0 ) && ( ( ((u8)id1&0xFF) >= ((u8)id2&0xFF) ) ) )



struct encoded_type
{
	x86_opcode_param type;
	union
	{
		x86_mrm_t modrm;
		u8 reg;
		u32 imm;
		struct
		{
			void* ptr;
			u8 ptr_type;//1 is label
		};
	};
};

struct x86_opcode;

typedef void x86_opcode_encoderFP(x86_block* block,const x86_opcode* op,encoded_type* p1,encoded_type* p2,u32 p3);

//enc_param_none is alower w/ params set to implicit registers (ie , mov eax,xxxx is enc_imm , pg1:pg_EAX , pg2:pg_imm

struct x86_opcode
{
	x86_opcode_class opcode;
	u8 b_data[4];
	x86_opcode_encoderFP* encode;
	
	//note : rm_rev affects only encoding , so other flags are not affected . r/m,r w/ GPR,XMM have p1:GPR and p2: XMM
	x86_opcode_param pg_1;		//param 1 group , valid for any r or r/m encoding.Ignored on m mode of r/m
	x86_opcode_param pg_2;		//param 2 group , valid for any r or r/m encoding.Ignored on m mode of r/m
	x86_opcode_param pg_3;		//param 3 group , either NONE or IMM*
};

//mod|reg|rm
void encode_modrm(x86_block* block,encoded_type* mrm, u32 extra)
{
	if (mrm->type != pg_ModRM)
	{
		verify(mrm->type==pg_REG || mrm->type==pg_CL || mrm->type==pg_R0);
		block->write8((3<<6) | (mrm->reg&7 ) | (extra<<3));
	}
	else
	{
		x86_mrm_t* modr=&mrm->modrm;
		block->write8(modr->modrm | ((extra&7)<<3));

		if (mrm->modrm.flags&1)
			block->write8(modr->sib);

		if (mrm->modrm.flags&2)
			block->write8(modr->disp);
		else if (mrm->modrm.flags&4)
			block->write32(modr->disp);
	}
}
#ifdef X64
//x64 stuff
void encode_rex(x86_block* block,encoded_type* mrm,u32 mrm_reg,u32 ofe=0)
{
	u32 flags = (ofe>>3) & 1; //opcode field extension

	
	flags |= (mrm_reg>>1) & 4;//mod R/M byte reg field extension

	if (mrm)
	{
		if (mrm->type==pg_REG)
			flags|=(mrm->reg>>3) & 1;
		else if (mrm->type==pg_ModRM)
			flags|=mrm->modrm.flags>>2;//mod R/M byte r/m field extension
	}
	if (flags!=0)
	{
		block->write8(0x40|flags);
	}
}
#endif
#define block_patches (*(vector<code_patch>*) block->_patches)

//Encoding function (partially) specialised by templates to gain speed :)
template < enc_param enc_1,enc_imm enc_2,u32 sz,x86_operand_size enc_op_size>
void x86_encode_opcode_tmpl(x86_block* block, const x86_opcode* op, encoded_type* p1,encoded_type* p2,u32 p3)
{
	//printf("Encoding : ");

	if (enc_op_size==opsz_16)
			block->write8(0x66);

	switch(enc_1)
	{
		//enc1 group
		// +r
	case enc_param_plus_r:
	#ifdef X64
		encode_rex(block,0,0,p1->reg);
	#endif
		for (int i=0;i<(sz-1);i++)
			block->write8(op->b_data[i]);
		{
		u32 rv=(p1->reg-EAX)&7;
		block->write8(op->b_data[sz-1] + rv);
		}
		break;
		// /r
	case enc_param_slash_r:
		#ifdef X64
		encode_rex(block,p2,p1->reg);
		#endif
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		encode_modrm(block,p2,p1->reg);
		break;

	case enc_param_slash_r_rev:
		#ifdef X64
		encode_rex(block,p1,p2->reg);
		#endif
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		encode_modrm(block,p1,p2->reg);
		break;

		// /digit
	case enc_param_slash_0:
	case enc_param_slash_1:
	case enc_param_slash_2:
	case enc_param_slash_3:
	case enc_param_slash_4:
	case enc_param_slash_5:
	case enc_param_slash_6:
	case enc_param_slash_7:
#ifdef X64
		encode_rex(block,p1,0);
#endif
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		encode_modrm(block,p1,enc_1-enc_param_slash_0);
		break;

		//diroffset
	case enc_param_memdir:
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		
		code_patch cp;
		
		cp.dest=p1->ptr;
		cp.type=4|0;
		cp.offset=block->x86_indx;
		
		block_patches.push_back(cp);

		block->write32(0x12345678);

		break;

		//reloffset
	case enc_param_memrel_8:
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);

		cp.dest=p1->ptr;
		cp.type=1;
		if (p1->ptr_type)
			cp.type|=16;
		cp.offset=block->x86_indx;
		block_patches.push_back(cp);

		block->write8(0x12);
		break;
	case enc_param_memrel_16:
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		
		cp.dest=p1->ptr;
		cp.type=2;
		if (p1->ptr_type)
			cp.type|=16;
		cp.offset=block->x86_indx;
		block_patches.push_back(cp);

		block->write16(0x1234);
		break;
	case enc_param_memrel_32:
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);

		cp.dest=p1->ptr;
		cp.type=4;
		if (p1->ptr_type)
			cp.type|=16;
		cp.offset=block->x86_indx;
		block_patches.push_back(cp);

		block->write32(0x12345678);
		break;

	default:
		for (int i=0;i<(sz);i++)
			block->write8(op->b_data[i]);
		break;
	}

	switch(enc_2)
	{
	case enc_imm_native :
		if (enc_op_size==opsz_8)
			block->write8(p3);
		else if (enc_op_size==opsz_16)
			block->write16(p3);
		else 
			block->write32(p3);
		break;

	case enc_imm_8 :
		block->write8(p3);
		break;

	case enc_imm_16 :
		block->write16(p3);
		break;

	case enc_imm_32 :
		block->write32(p3);
		break;
	}
}


//macros to make out life easy :)
#define OP_ENCODER(enc1,enc2,sz,op_sz) x86_encode_opcode_tmpl<enc1,enc2,sz,op_sz>
#define OP_ENCODING(pg1,pg2,pg3) pg1,pg2,pg3

#define OP(ocls,opdt,enc1,enc2,dtsz,pg1,pg2,pg3,operand_sz) \
	{ocls,opdt,OP_ENCODER(enc1,enc2,dtsz,operand_sz),OP_ENCODING(pg1,pg2,pg3)}

#define s_LIST_END \
{op_count,{0},0,OP_ENCODING(pg_NONE,pg_NONE,pg_NONE)}

#define OP_0(ocls,opdt,dtsz,operand_sz) \
	OP(ocls,opdt,enc_param_none,enc_imm_none,dtsz,pg_NONE,pg_NONE,pg_NONE,operand_sz)

#define OP_1_rm(ocls,opdt,enc1,dtsz,pg1,operand_sz) \
	OP(ocls,opdt,enc1,enc_imm_none,dtsz,pg1,pg_NONE,pg_NONE,operand_sz)

#define OP_1_imm(ocls,opdt,enc2,dtsz,pg1,operand_sz) \
	OP(ocls,opdt,enc_param_none,enc2,dtsz,pg_NONE,pg_NONE,pg1,operand_sz)

#define OP_2(ocls,opdt,enc1,enc2,dtsz,pg1,pg2,operand_sz) \
	OP(ocls,opdt,enc1,enc2,dtsz,pg1,pg2,pg_NONE,operand_sz)

#define OP_3(ocls,opdt,enc1,enc2,dtsz,pg1,pg2,pg3,operand_sz) \
	OP(ocls,opdt,enc1,enc2,dtsz,pg1,pg2,pg3,operand_sz)

#define s_r_rev(cls,dt,dtsz,sz) \
	OP_2(cls,dt,enc_param_slash_r_rev,enc_imm_none,dtsz,pg_ModRM,pg_REG,sz)

#define s_r(cls,dt,dtsz,sz)\
	OP_2(cls,dt,enc_param_slash_r,enc_param_none,dtsz,pg_REG,pg_ModRM,sz)


#define s_d(digit,cls,dt,dtsz,sz)\
	OP_1_rm(cls,dt,enc_param_slash_##digit,dtsz,pg_ModRM,sz)


#include "x86_op_table.h"
/*
x86_opcode x86_oplist[]=
{
	//MOV reg/mem32, reg32 89 /r Move the contents of a 32-bit register to a 32-bit destination register or memory operand.
	s_r_rev(op_mov32,0x89,1,opsz_16),
	s_r_rev(op_mov32,0x89,1,opsz_32),
	//{op_mov32,1,0x89,OP_ENCODING(enc_slash_r_rev,enc_param_none,pg_ModRM,pg_REG,pg_NONE,opsz_16_32)},

	//MOV reg32, imm32 B8 +rd Move an 32-bit immediate value into a 32-bit register.
	//OP_2(op_mov32,0xB8,enc_plus_r,enc_imm,1,pg_REG,pg_IMM_U32,opsz_32),
	OP(op_mov32,0xB8,enc_param_plus_r,enc_imm_native,1,pg_REG,pg_NONE,pg_IMM_U32,opsz_32),
	//{op_mov32,1,0xB8,OP_ENCODING(enc_plus_r,imm_native,pg_REG,pg_IMM_U32,pg_NONE,opsz_16_32)},
	

	//DEC reg32 48 +rd Decrement the contents of a 32-bit register by 1.
	//{op_dec32,1,0x48,OP_ENCODING(enc_plus_r,enc_param_none,pg_REG,pg_NONE,pg_NONE,opsz_16_32)},
	
	//DEC reg/mem32 FF /1 Decrement the contents of a 32-bit register or memory location by 1.
	s_d(1,op_dec32,0xFF,1,opsz_16),
	s_d(1,op_dec32,0xFF,1,opsz_32),
	//{op_dec32,1,0xFF,OP_ENCODING(enc_slash_1,enc_param_none,pg_ModRM,pg_NONE,pg_NONE,opsz_16_32)},

	//INC reg32 40 +rd Increment the contents of a 32-bit register by 1.
	//{op_inc32,1,0x40,OP_ENCODING(enc_plus_r,enc_param_none,pg_REG,pg_NONE,pg_NONE,opsz_16_32)},
	
	//INC reg/mem32 FF /0 Increment the contents of a 32-bit register or memory location by 1.
	s_d(0,op_inc32,0xFF,1,opsz_16),
	s_d(0,op_inc32,0xFF,1,opsz_32),
	//{op_inc32,1,0xFF,OP_ENCODING(enc_slash_0,enc_param_none,pg_ModRM,pg_NONE,pg_NONE,opsz_16_32)},

	//RET C3 Near return to the calling procedure.
	OP_0(op_ret,0xC3,1,opsz_32),
	//{op_ret,1,0xC3,OP_ENCODING(enc_param_none,enc_param_none,pg_NONE,pg_NONE,pg_NONE,opsz_32)},
	
	//RET imm16 C2 iw Near return to the calling procedure then pop of the specified number of bytes from the stack.
	OP_1_imm(op_reti,0xC3,enc_imm_16,1,pg_IMM_U16,opsz_32),
	//{op_reti,1,0xC2,OP_ENCODING(enc_param_none,imm_u16,pg_IMM_U16,pg_NONE,pg_NONE,opsz_32)},

	{op_count}
};
*/
/*
void Init()
{
	
	for (u32 i=0;x86_oplist[i].opcode!=op_count;i++)
	{
		x86_opcode* op=&x86_oplist[i];
		if (op->encoding.enc_op_size==opsz_16_32)
		{
			op->encoding.enc_op_size=opsz_32;
			ops.push_back(*op);
			op->opcode=(x86_opcode_class)((u32)op->opcode-1);
			op->encoding.enc_op_size=opsz_16;
			ops.push_back(*op);
		}
		else
		{
			ops.push_back(*op);
		}
	}
	
}
*/

/*
x86 system opcodes have 2 sizes :
8 bit
native

native is usually 32b.Using a size override (0x66) makes these opcode(s) 16 bit.Using the Rex prefix makes em 64b.

x86 sse opcodes are similar , but they use 0xf3 prefix for ss versions and other various prefixes :)
*/

/*
	Opcode function groups :

	none,
	r,
	imm,
	mem	(simple/complex),
	r <- r,
	r <- mem,
	r <- imm,

	mem <- r,
	mem <- imm
*/

/*
--lets seee
1 list for each opcode class

*/